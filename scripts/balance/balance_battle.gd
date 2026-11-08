class_name BalanceBattle
extends RefCounted
## [P108] The BATTLE scene's half of Balance, split out of scripts/balance/balance.gd at the user's
## request ("a scene's own constants live with that scene"). The rule is the one [P28-UI] and
## [P69] already use, and it is still WHO READS IT: every constant here is read by the code
## that runs ONE battle -
##   the turn engine   core/battle/battle.gd, core/game_manager.gd, core/unit.gd
##   the board         core/grid.gd, core/battle/sun_field.gd, core/level_data.gd, units/**
##   the rail          ui/hud.gd (tool names, deck / tool hotkeys)
## The almanac and the self-check probes READ these numbers; they do not own them.
## Nothing in balance.gd reads this file, so the direction stays one-way: a table may READ
## Balance (BalanceUI does, and so does BalanceRun for the item ids it names), never the other
## way round, and no two tables read each other. A table and its only reader also moved
## together, which is why skill_ap_cost() and plant_ult_value() are HERE rather than next to
## the other sheet accessors in balance.gd.
##
## What is in here, in file order:
##   economy        a round's sun income, the brain's hp
##   turn engine    the wave table, the spawn columns, the F key, the debug sun, message time
##   action points  ROUND_AP, every zombie action's price, the SKILL_AP_COST fall-backs and
##                  the look-up that reads them
##   ultimates      the charge bar's rule, the 大招数值 fall-backs and their look-up
##   deck           how many cards a battle carries, how many summons one round allows
##   tools          shovel / glove / hammer: ids, thresholds, colours, rail keys
##   confirm        how long RETREAT waits for its second click
## The pure PRESENTATION of these (bar sizes, card pixels) is BalanceUI's, and the sheet
## values that override a fall-back are data/units/*.csv's - same division as before.

# ---------------------------------------------------------------- economy
const START_SUN := 50
const SUN_PER_TURN := 25
const SUN_MAX := 9999
## [P89] THE SUN DROPS. A round's income is not banked on the spot any more: it lands on
## the lawn as a sun the player picks up (or that picks itself up - see
## SettingsStore.auto_collect_sun / sun_auto_rounds). These two are RULES (how many may
## lie around, and the default patience of the auto-collect), so they live here; the sizes,
## speeds and colours are BalanceUI's.
const SUN_DROP_MAX := 12                # more than this on the board -> the oldest is banked
const SUN_AUTO_ROUNDS_DEFAULT := 2      # rounds a landed sun waits before it gathers itself
## What the settings button cycles through: small numbers on purpose - a sun that waits
## five rounds is a sun the player has forgotten about, and one that waits zero is the
## old behaviour with extra steps.
const SUN_AUTO_ROUNDS_CHOICES: Array[int] = [1, 2, 3, 5]
const BRAIN_MAX_HP := 100

# ---------------------------------------------------------------- turn engine
const FAST_FORWARD_ROUNDS := 10        # how many rounds the F key jumps
const DEBUG_SUN_AMOUNT := 100
const MESSAGE_DURATION := 2.5

# round number -> how many zombies enter at TURN_START (fallback when the level file is missing)
const WAVE_TABLE := {1: 1, 4: 1, 7: 1, 10: 1}
# tried left to right until a free cell is found (fallback)
const ZOMBIE_SPAWN_COLS := [6, 7, 8]

# false = faithful to the original: a peashooter never shoots behind itself
const PEASHOOTER_SHOOTS_BACKWARD := false

# ---------------------------------------------------------------- action points (P30-A)
# [P30-A] The turn engine is ACTION POINT based now. Every unit is handed
# ROUND_AP points at the start of its side's action phase and spends them on its
# skill; unspent points EXPIRE at the end of the round (confirmed rule: AP never
# carry over). A skill costs the unit's `threshold` (plants: the price of their
# skill code in data/units/skills.csv, see skill_ap_cost(); zombies: the
# per-action costs below).
## [P30-A2] The pause the staged resolver takes BETWEEN two unit actions, so the
## player can watch every one of the peashooter's three shots instead of the old
## one-frame blow-up. Short enough that a full round still resolves in about a
## second; fast_forward and the self-checks skip it entirely (sync path).
const ACTION_STEP_TIME := 0.3
const ROUND_AP := 3
## A zombie's skills, priced in AP. MOVING is itself a skill: one use costs
## ZOMBIE_MOVE_COST and adds ONE point to the zombie's move progress (the 移动
## column is that progress bar's LENGTH, not an AP price), so a zombie walks one
## cell per `移动` rounds by default. BITE and EAT_BRAIN are quick and cost one
## point each - which is why a bite only lands BITE_DAMAGE_RATIO of the sheet's
## 啃食 value (3 full bites = 90% of one old bite; accepted trade).
const ZOMBIE_MOVE_COST := 3
const ZOMBIE_BITE_COST := 1
const ZOMBIE_EAT_BRAIN_COST := 1
const ZOMBIE_VAULT_COST := 1           # [P26] a pole vault is one action point
## [P47] The summon's price. The sheet states WHO / HOW MANY / HOW OFTEN in its three
## 召唤 columns but no AP cost, so this is the documented fall-back rather than a
## number read off the sheet: it pays like the cheapest action a zombie has. Any
## higher price would let a countdown steal the dancer's walk, which the sentence
## ("每7回合召唤1只伴舞僵尸") never asks for.
const ZOMBIE_SUMMON_COST := 1
## [P48] The wind-up's price is deliberately the WHOLE round: the zombie phase
## re-decides before every single use (see GameManager._do_zombie_action), so a
## cheap WINDUP would let a giant take three "rounds" of raising in one round and
## drop the hammer the very next turn - which is not what 锤击前摇 3 回合 says.
## Holding the round is exactly what the 移动 skill already does for the same reason.
## The swing itself is instant and pays like a bite.
const ZOMBIE_WINDUP_COST := ROUND_AP
const ZOMBIE_SMASH_COST := 1
const BITE_DAMAGE_RATIO := 0.3
## [P30-A] The AP price of ONE use of each plant skill, keyed by the 技能代码 the
## plant scripts declare (`const SKILL := "..."`). data/units/skills.csv (SkillDB)
## owns these numbers now - this table is only the fall-back for when the sheet
## cannot be read. An unknown code costs 1 AP: the plain-attack default.
const SKILL_AP_COST := {
	"peashooter_fire": 1,
	"sunflower_produce": 3,
	## [P34] The first batch of plants: every shooter's volley costs one point, a
	## producer spends the round (the twin is priced like the sunflower, not like a
	## "bigger" version of it - one PRODUCE either way).
	"repeater_fire": 1,
	"split_pea_fire": 1,
	"gatling_fire": 1,
	"threepeater_fire": 1,
	"snow_pea_fire": 1,
	"twin_sunflower_produce": 3,
	"puff_shroom_fire": 1,
	"fume_shroom_breath": 1,
	## [P39] One swallow is one action, like one volley.
	"chomp": 1,
	## [P39] A blast is one action too, and the plant only gets the one - the AP price
	## is a fall-back for the same 1 that skills.csv now writes for both.
	"squash_stomp": 1,
	"jalapeno_burn": 1,
	## [P39] The two with a fuse: arming is not an action, so the blast still costs the
	## one AP the rest of the family pays.
	"potato_blast": 1,
	"cherry_blast": 1,
	## [P43] Freezing the lawn is one action as well - the AP price is a cost, not a
	## measure of how much the blast is worth; that is the 175 sun on its card.
	"freeze_blast": 1,
	## [P49] One throw, one point: a melon is worth more than a pea because of its 60 and
	## its splash, not because the plant gets to act twice, and the 300 sun on its card is
	## where that difference is actually paid.
	## [P51] The cabbage joins the family line: the whole 投手 row of this table is one
	## point per throw, because the lobbing is paid on the card, not in AP.
	"cabbage_toss": 1,
	"melon_toss": 1,
	"icy_melon_toss": 1,
	## [P58] One ring, one action: 忧郁菇 sprays in all directions at once, which costs
	## the same single point a lane breath does - the AP price counts actions, not bodies
	## (see the note on the gatling's 4 peas and the melon's splash above).
	"gloom_breath": 1,
	## [P59] 胆小菇's frightened shot: one lane spore, one point - the fear is a GATE on
	## the action, never a second charge for it (it either fires the volley or holds the AP).
	"scaredy_spore": 1,
	## [P63] One stab, one point - and this row is the reason the price is REAL rather
	## than the `threshold = 0` a wall uses: 地刺 spends its budget during the ZOMBIE's
	## action (SpikePlant.stab_the_walker), so a walker that takes three bites in a round
	## buys three stabs and the fourth walks free. A plant whose AP nobody paid would leave
	## this cell as silent data, which is the exact state docs/ADD_UNIT.md warns about.
	"spike_pierce": 1,
}

# ---------------------------------------------------------------- skill price (moved with its table)
# [P108] The plant half of the AP price. This look-up READS SKILL_AP_COST above, so it moved with
# it (AGENTS §2 ②: a table and its only reader stay in one file, and balance.gd reads neither).
static func skill_ap_cost(skill_code: String) -> int:
	## [P30-A] The AP one use of a plant skill costs, looked up by its 技能代码
	## (the plant script declares it as `const SKILL`). The skill sheet wins: a
	## designer can price a heavy skill at 2 or 3 AP without touching code (a
	## price ABOVE ROUND_AP simply means the unit can never act, which is the
	## honest consequence of AP not carrying over). A code the sheet does not
	## know keeps the SKILL_AP_COST fall-back, and an unknown code 1 AP. A cost
	## can never be 0 here: 0 belongs to the SCRIPT that wants a permanent
	## blocker (the wall-nut hard-codes threshold = 0, not a free skill).
	if SkillDB.has(skill_code):
		var sheet_cost: int = SkillDB.ap_cost(skill_code)
		if sheet_cost > 0:
			return sheet_cost
	return maxi(1, int(SKILL_AP_COST.get(skill_code, 1)))

# ---------------------------------------------------------------- ultimates (P30-B)
# [P30-B] A plant that LOADS an ultimate (its units.csv 大招代码 cell names a
# skills.csv ultimate row, and the plant script has a matching implementation)
# charges one bar under its hp: every cast of its basic skill adds
# ULT_CHARGE_PER_CAST, and at ULT_CHARGE_MAX the ultimate fires automatically -
# inside the same action phase, right after the cast that filled the bar - and
# the bar resets to 0. The charge never expires with the round and never burns
# while full: a plant at 9/10 that cannot act this round simply waits.
# The bar is the ONLY unit bar a plant draws (the AP budget stays plain
# accounting, Unit.bar_shown). Zombies have no ultimate.
const ULT_CHARGE_PER_CAST := 1
const ULT_CHARGE_MAX := 10
## [P30-B] Fall-back 大招数值 per ultimate code for when skills.csv cannot be
## read (the sheet is the source; SkillDB prints any disagreement). The unit of
## the number belongs to the CODE that consumes it: pea_storm / sun_burst are
## flat amounts, wall_nut_wall is a PERCENT of max hp.
const ULTIMATE_VALUE := {
	"pea_storm": 60,
	"sun_burst": 75,
	"wall_nut_wall": 50,
	## [P34] The batch-1 bars. Flat damage per hit body for the lane storms, sun for
	## the producer's flood, PERCENT of max hp for the two walls (see the unit note
	## above: the consuming code decides, and WallPlant.act_ultimate reads a percent).
	"double_storm": 120,
	"pincer_attack": 80,
	"bullet_storm": 240,
	"triple_volley": 60,
	"deep_freeze": 40,
	"sun_flood": 150,
	"spore_cloud": 30,
	"toxic_cloud": 60,
	"steel_bulwark": 50,
	## [P39] ROUNDS, not an amount: Chomper.act_ultimate() chews for this long after its
	## 暴食 bite (1 = the "咀嚼1回合" its own 大招效果 says). The unit of the number
	## belongs to the code that consumes it, exactly as above.
	"big_chomp": 1,
	## [P49] A flat amount per hit body, like the other lane storms - and ONE number for
	## each rain, not two. The 大招效果 says 对同行所有僵尸造成80伤害，并对相邻行各造成40伤害;
	## the 40 is that 80 at Balance.PULT_SPLASH_RATIO, computed by PultPlant.act_ultimate(), so a
	## designer editing skills.csv moves both waves together.
	## [P51] The cabbage's rain is ONE wave: its units.csv 特殊机制 says 可越过墓碑、屋顶等障碍
	## and NOT 溅射, so PultPlant reads splash_ratio 0 for it and its storm pays only the
	## bodies in its own row - which is why this number is the whole 大招数值 and not a
	## number plus a splash share. 60 is the sheet's own figure (卷心菜雨 对同行所有僵尸造成60伤害).
	"cabbage_rain": 60,
	"melon_rain": 80,
	"frozen_melon_rain": 80,
	## [P58] A flat amount per hit body again, and this time per body IN THE RING:
	## 暗影风暴 is 忧郁菇's own 大招数值 (120), the same reach as its breath.
	"shadow_storm": 120,
	## [P59] 恐惧孢子: the same flat amount per body down its own lane (对同行所有僵尸),
	## plus the shove the sheet spells in the same sentence. The distance is NOT a number
	## here - a shove's cells are the plant's geometry, like a freeze's rounds (P43).
	"terror_spore": 60,
	## [P63] 尖刺风暴: a flat amount per body down its own row (对本行所有僵尸造成60伤害),
	## the same shape as every other lane storm - only delivered from under the feet
	## instead of out of a barrel.
	##
	## NOT shared with 地刺王, which is where this family diverges from the 投手 one: the
	## two melons' rains differ in what a hit leaves behind, and a code carries one NUMBER
	## (see the unit note above), so the 80 can serve both. The sheet gives the elder spike
	## a 120 of its own, so wiring it means a second 大招代码 - a data decision, and one of
	## the three it still owes (see the plan's 待决 list).
	"spike_storm": 60,
}

# [P108] The ultimate half of the same rule: this look-up READS ULTIMATE_VALUE above, same reason.
static func plant_ult_value(ult_code: String) -> int:
	## [P30-B] The 大招数值 of one ultimate code: the sheet first, the
	## ULTIMATE_VALUE fall-back table after (0 = "nobody knows", which the code
	## implementations treat as "refuse to fire", never as a free 0-damage ult).
	if SkillDB.has(ult_code):
		var sheet_value: int = SkillDB.ult_value(ult_code)
		if sheet_value >= 0:
			return sheet_value
	return int(ULTIMATE_VALUE.get(ult_code, 0))

# ---------------------------------------------------------------- deck + summons (P13/P32)
## [P32] The deck-select page's seed-slot cap (like the original PvZ's 6/7 slots):
## a free level asks you to carry at most this many plant cards into the battle.
## A RULE number (what the page enforces), so it lives here, not in BalanceUI.
## [P34] It is also the rail's width: an UNPICKED battle falls back to exactly this
## many cards (Game.battle_cards), and DECK_HOTKEY_KEYS has one key per slot - keep
## the two in step if the cap ever grows.
const BATTLE_DECK_SLOTS := 6

# [P13] How many SUMMON SCROLLS (= plant cards) may be used in one round, counted
# across ALL types, not per card. One is the design default: the scrolls are the
# scarce resource, a rogue-like reward is expected to raise it later, which is why
# the limit is a plain runtime value (Game.summon_limit) instead of a hard-coded 1.
# The per-card cooldown below still applies ON TOP of this.
const SUMMONS_PER_TURN := 1

# ---------------------------------------------------------------- tools (P8)
# Tools are free and gated by an ACTION-BAR style charge, exactly like units:
#   charge starts at 0, +1 at every TURN_START, capped at `threshold`.
#   charge == threshold  -> READY (selectable during the operation phase)
#   using it             -> charge resets to 0
const TOOL_SHOVEL := "shovel"
const TOOL_GLOVE := "glove"
const TOOL_HAMMER := "hammer"

const SHOVEL_THRESHOLD := 2
const GLOVE_THRESHOLD := 5
const HAMMER_THRESHOLD := 7
const HAMMER_DAMAGE := 9999            # placeholder: "instant kill" tier

const COLOR_TOOL_SHOVEL := Color(0.74, 0.68, 0.52)
const COLOR_TOOL_GLOVE := Color(0.55, 0.70, 0.86)
const COLOR_TOOL_HAMMER := Color(0.86, 0.45, 0.34)
## [P70/P71] The four STATE tints that used to sit here (COLOR_TOOL_READY / _TARGET /
## _TARGET_LINE / _SOURCE) are gone to BalanceUI: they only paint the cell a tool is being
## aimed at. The three IDENTITY colours above stay because `TOOL_DEFS` carries them as a
## column of the same row as the rule data (AGENTS §2 ④: one dict, two readers - splitting
## it would tear a table in half), and callers take the whole dict entry.

const TOOL_CARDS := [TOOL_SHOVEL, TOOL_GLOVE, TOOL_HAMMER]
## [P34] THE BATTLE RAIL'S KEYS. A plant card is armed by its DECK SLOT (its
## position in Game.battle_cards(): keys 1..6) and a tool by its position in
## TOOL_CARDS (8/9/0) - the roster outgrew three hard-coded ids long ago, and the
## seed-picking page can order a deck any way the player picks. The LABEL lists are
## those same keys' digits for the card titles, kept next to the keys so the number
## a card shows and the number that actually arms it are one decision.
const DECK_HOTKEY_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const DECK_HOTKEY_LABELS := ["1", "2", "3", "4", "5", "6"]
const TOOL_HOTKEY_KEYS := [KEY_8, KEY_9, KEY_0]
const TOOL_HOTKEY_LABELS := ["8", "9", "0"]
const TOOL_DEFS := {
	TOOL_SHOVEL: {"name": "Shovel", "threshold": SHOVEL_THRESHOLD, "color": COLOR_TOOL_SHOVEL},
	TOOL_GLOVE: {"name": "Glove", "threshold": GLOVE_THRESHOLD, "color": COLOR_TOOL_GLOVE},
	TOOL_HAMMER: {"name": "Hammer", "threshold": HAMMER_THRESHOLD, "color": COLOR_TOOL_HAMMER},
}


static func tool_name(tool_id: String) -> String:
	## [P20] Display name follows the language (LocNames "tool.<id>").
	var d: Dictionary = TOOL_DEFS.get(tool_id, {})
	return Loc.t("tool." + tool_id, str(d.get("name", tool_id)))


static func tool_default_threshold(tool_id: String) -> int:
	var d: Dictionary = TOOL_DEFS.get(tool_id, {})
	return maxi(1, int(d.get("threshold", 1)))

# ---------------------------------------------------------------- retreat confirm (P13)
# [P13] how long RETREAT waits for its confirming second click
const RETREAT_CONFIRM_TIME := 3.0
