class_name Zombie
extends Unit
## A zombie on the board.
##
## [P26] Every zombie is now a TYPE out of data/units/zombies.csv (ZombieDB): the
## sheet decides its hp, its armour, how many move-skill uses one cell costs (移动,
## [P30-A] now a PROGRESS bar length) and how hard it bites, and the spawner hands
## those numbers over in apply_type().
##
## [P30-A] How a zombie spends its round: it gets BalanceBattle.ROUND_AP action points, it
## re-decides its action before EVERY use (no plant in front -> walk, plant -> bite,
## col 0 -> eat the brain), one walk costs 3 AP and lands +1 move progress, one bite
## costs 1 AP and does 30% of the sheet's value.
##
## What the type also decides, and what that means on the board:
##   armour            a second health layer IN FRONT of hp, drawn as a strip above
##                     the hp bar. Breaking it can downgrade the zombie
##                     ("护甲被打掉后变普通僵尸"): a conehead without its cone IS a
##                     plain zombie, name and numbers included.
##   execute           the base zombie's own rule ("血量低于1/3（90）时立即死亡"):
##                     below a third of its health it simply drops. That is what makes
##                     its effective health 180 instead of 270 (BALANCE.md 2.3), and a
##                     stripped conehead inherits it.
##   vault             the pole vaulter refuses to bite the first plant: it lands on
##                     the far side of it in ONE action point and becomes plain.
##   drops_diamond     the snow goblin's pay-out, read by GameManager's drop roll.
##   freeze            [P34] a rider a hit can leave on this zombie (see
##                     effect_rounds): while it binds, the zombie surrenders its
##                     whole action phase, and a type whose sheet row says 免疫冻结
##                     refuses the rider outright. The snow pea is what applies it.
##   screen door       [P45] the 铁门's rules, all read off the armour that is LEFT on
##                     it: 格挡射弹 - while the door is up it stands between a shot and
##                     the zombie, so a projectile's rider (freeze) never lands; 只挡正面
##                     - a hit from BEHIND walks past the door and lands on hp; [P77]
##                     只挡直线射弹 - and a hit that is not a straight shot at all (the
##                     melon's arc, a one-shot blast, a spike underfoot, the shovel)
##                     walks past it from the FRONT too. Break the door and the rules
##                     stop with it.
##   summon          [P47] the dancer's call: when the round counter it has been
##                     ticking reaches the sheet's 召唤间隔, one SUMMON action brings
##                     召唤数量 zombies of type 召唤单位 into the first free cells BEHIND
##                     it (a zombie walks left, so "behind" is the higher column). The
##                     three cells come from the row, never from this script, and a
##                     row that says 召唤 without them does not summon - which is how
##                     伴舞僵尸, the SUMMONED side of the same sentence, stays harmless.
##   hammer          [P48] the giant's swing, and the only zombie action with a BEFORE
##                     and an AFTER: it stops to raise the hammer for 锤击前摇 rounds
##                     (a WINDUP holds the whole round, so the re-deciding AP loop
##                     cannot rush it), then SMASHES for the row's FULL attack - no
##                     BITE_DAMAGE_RATIO, because that 30% is the price of a quick
##                     bite, not of a hammer - and is then busy for 锤击后摇 rounds.
##                     The recovery rides the generic stand_down_rounds counter that
##                     chewing already uses, so a wind-up that loses its plant before
##                     the hammer falls is simply called off and the giant walks on.
##   rage            [P68] the newspaper's paper: when its armour breaks, the row's own
##                     暴怒移动 / 暴怒attack pair is swapped onto the SAME body - the type,
##                     the name, the sprite and the hp all stay put, which is exactly the
##                     difference from armor_downgrade above (a cone without its cone IS
##                     another zombie; a newspaper without its paper is still the newspaper
##                     zombie, only faster and hungrier). One-way, and needs no clock: the
##                     two numbers ARE the state, plus `enraged` for the tint and the log.
## Mechanics the sheet names that the battle does NOT simulate yet (flight,
## the thrown imp) are listed in the almanac instead of being
## half-implemented here - see ZombieDB.FLAGS_KNOWN.

enum Act { ADVANCE, BITE, EAT_BRAIN, VAULT, SUMMON, WINDUP, SMASH }

## [P90] The statuses this class applies, now spelled by the SHEET's own ids: what each
## one MEANS (a counter or an instant shove, what refuses it, how a second hit stacks,
## and the phrase a log prints) is a row of `data/statuses.csv`, not a map in here. The
## immunity is still the 特殊机制 flag on the TYPE (the table names which flag), which is
## what makes "免疫冻结" a rule instead of prose - ZombieDB has promoted that flag to
## FLAGS_SIMULATED so the almanac stops calling it "not simulated".
const StatusDB := preload("res://scripts/core/db/status_db.gd")
const EFFECT_FREEZE := StatusDB.ID_FREEZE
## [P59] The second kind of thing a hit can do: NOT a counter, the body moves on the hit
## and nothing ticks down. The table says so with `名称 = 瞬时`, which is why
## `apply_hit_effects` can ask instead of hard-coding the id.
const EFFECT_PUSH := StatusDB.ID_PUSH

## [P50] The sound layer, by PATH for the reason pult_plant.gd gives: a brand-new
## `class_name` does not resolve until the editor has rescanned the project, and a
## headless run cannot wait for that. A zombie names a CUE of BalanceAudio.SFX_DEFS, never a
## sample, and a cue nobody imported fails at boot instead of staying quiet.
const SFX := preload("res://scripts/core/sfx.gd")

var uid: int = 0                  # assigned by GameManager, used in logs
var just_spawned: bool = false    # spawned this turn -> idles once
var current_act: int = Act.ADVANCE
## [P30-A] Moving is a SKILL here: one use costs ZOMBIE_MOVE_COST AP and adds ONE
## point to this progress; at `move_threshold` (the sheet's 移动 column) the zombie
## walks a cell and the progress restarts. A switch of action clears it (the old
## "progress never carries over" rule, moved from the dead action bar to here).
var move_progress: int = 0
## [P34] effect id -> rounds it still binds, e.g. {"freeze": 2}. A frozen zombie
## gives up its whole action phase for those rounds (GameManager skips it) but
## keeps its MOVE PROGRESS, so it walks on from where it stopped instead of being
## back to square one - which is how the original's ice reads to the player.
var effect_rounds: Dictionary = {}
var freeze_immune: bool = false   # the sheet flag, read once per type in apply_type

# [P26] the type the spawner gave us, and the numbers that follow from it
var zombie_type: String = ZombieDB.BASE_ID
var move_threshold: int = Balance.ZOMBIE_ADVANCE_THRESHOLD
var bite_damage: int = Balance.ZOMBIE_BITE_DAMAGE
## [P26] How much of the brain this TYPE eats per EAT_BRAIN (the sheet's 啃脑伤害).
var brain_damage: int = Balance.ZOMBIE_BRAIN_DAMAGE
var armor: int = 0
var armor_max: int = 0
var executes: bool = false
var armored_downgrade: bool = false
var vault_charges: int = 0
var drops_diamond: bool = false
## [P45] The 铁门's rules, out of the same 特殊机制 sentence: 格挡射弹 (the door keeps a
## projectile's rider off the zombie) and 背后attack无视护甲 (only the FRONT is guarded).
## Both are read while the armour is up, so neither needs a column of its own.
## [P77] The sentence's third clause - 只挡正面**直线**射弹 - is not a flag but a question
## the hit answers (`Projectile.straight_shot`), so `blocks_projectiles` is only half of
## the gate: a lobbed shot and a blast are refused by no door.
var blocks_projectiles: bool = false
var back_attack_ignores_armor: bool = false
## [P47] The summon plan, all three numbers out of the row's own cells (ZombieDB):
## the gap in rounds, how many arrive per call, and which type. 0 / "" means the row
## never said, and a zombie that never said it cannot summon - the 召唤 FLAG parsed from
## a sentence is not enough, because the sheet also uses the verb to describe the
## summoned side ("被舞王僵尸召唤"). See ZombieDB.can_summon().
var summon_rounds: int = 0
var summon_count: int = 0
var summon_id: String = ""
## [P47] Rounds left until this zombie's next call is due. Ticked once per round by
## GameManager._do_turn_start (the same hook the freeze riders and the busy plants use)
## and re-armed by act() after a call that actually placed somebody.
var summon_countdown: int = 0
## [P48] The hammer. The two ROUND numbers come from the row (ZombieDB), never from
## here, and `smash_armed` is what makes the swing a state instead of a guess: while
## it is up this zombie does not walk and does not bite, it only keeps raising. The
## fall itself is instant; what happens AFTER it rides the generic
## Unit.stand_down_rounds (the same counter a chomper's chew uses), which is why
## there is no "recovering" field here.
var smash_windup: int = 0
var smash_recovery: int = 0
var smash_armed: bool = false
var smash_countdown: int = 0
## [P68] The rage: the row's OWN numbers for the body it becomes when its armour goes.
## Two cells (暴怒移动 / 暴怒attack) and no more, because the state itself is the swap -
## there is no timer, no action and nothing to tick. `enraged` is what makes it a
## one-way door: the numbers are spent once, and a zombie that never lost its armour
## never shows them.
var rage_move: int = 0
var rage_bite: int = 0
var enraged: bool = false
## True when this zombie was killed by the "below a third of its health" rule rather
## than by the damage itself: GameManager says so in the death line, which is the only
## way a player can tell the two apart in the log.
var executed: bool = false


func _init() -> void:
	## A zombie built without a type is the base one, numbers included: the self-checks
	## and any future caller that just wants "a zombie" get the sheet's own base row.
	set_display_name("unit." + ZombieDB.BASE_ID)
	is_zombie = true
	body_shape = Shape.RECT
	body_color = Balance.COLOR_ZOMBIE
	body_size = BalanceUI.UNIT_BODY_SIZE
	art_path = Balance.ART_ZOMBIE
	apply_type(ZombieDB.BASE_ID, ZombieDB.hp(ZombieDB.BASE_ID), ZombieDB.armor(ZombieDB.BASE_ID))


func apply_type(p_type: String, p_hp: int, p_armor: int) -> void:
	## [P26] Everything this zombie's TYPE decides, in one call. The spawner passes the
	## hp and armour it already scaled by the level and the difficulty, so this method
	## never has to know about either.
	zombie_type = p_type
	var stats := ZombieDB.stats(p_type)
	move_threshold = maxi(1, int(stats.get("move", Balance.ZOMBIE_ADVANCE_THRESHOLD)))
	bite_damage = maxi(0, int(stats.get("bite", Balance.ZOMBIE_BITE_DAMAGE)))
	brain_damage = maxi(1, int(stats.get("brain", Balance.ZOMBIE_BRAIN_DAMAGE)))
	## [B11] 防御, the third shared number a type carries. Read off the MERGED units.csv row,
	## like the hp and the armour are (the spawner scales those two and hands them in; this one
	## no level touches, so it is read here). A type whose row says nothing defends with 0 - and
	## a downgrade (_become_base re-runs this) re-reads it off the new type, like every flag.
	defence = UnitSheet.defence(p_type)
	## [B16] ...and WHICH WAY ITS PICTURE LOOKS (units.csv `face`): the zombie race's default
	## row says 左, so every zombie reads "left" off the sheet. The `true` is only the
	## last-resort answer for a sheet that is not there at all - the art has always looked left.
	faces_left = UnitSheet.face_left(p_type, true)
	executes = ZombieDB.has_flag(p_type, "execute")
	armored_downgrade = ZombieDB.has_flag(p_type, "armor_downgrade")
	drops_diamond = ZombieDB.has_flag(p_type, "drops_diamond")
	## [P34] Read the immunity here rather than at the hit: the type is the only
	## input, and a downgrade to the base zombie re-runs this and re-decides it.
	freeze_immune = ZombieDB.has_flag(p_type, "freeze_immune")
	## [P45] Read the door rules the same way the immunity is read - off the TYPE - so a
	## zombie that loses its door to `_become_base()` stops carrying them too.
	blocks_projectiles = ZombieDB.has_flag(p_type, "blocks_projectiles")
	back_attack_ignores_armor = ZombieDB.has_flag(p_type, "back_attack_ignores_armor")
	vault_charges = 1 if ZombieDB.has_flag(p_type, "vault") else 0
	## [P47] The summon plan is read as one decision, not as a flag plus a guess:
	## ZombieDB.can_summon() only says true when this row really named its partner, so
	## a 召唤 sentence on the SUMMONED type ("被舞王僵尸召唤") leaves this zombie with
	## nothing to call. Re-arming the countdown here is also what makes a downgrade
	## (_become_base) drop the plan along with the type that carried it.
	if ZombieDB.can_summon(p_type):
		summon_rounds = ZombieDB.get_summon_rounds(p_type)
		summon_count = ZombieDB.get_summon_count(p_type)
		summon_id = ZombieDB.get_summon_unit(p_type)
		summon_countdown = summon_rounds
	else:
		summon_rounds = 0
		summon_count = 0
		summon_id = ""
		summon_countdown = 0
	## [P48] The hammer is decided all-or-nothing like the summon plan: a row that
	## names 锤击 without saying how long the wind-up takes never swings (ZombieDB
	## .can_smash). Clearing the STATE and not only the numbers is what makes losing
	## the type - the armour downgrade runs this same method - also drop a hammer that
	## is already in the air, instead of leaving a plain zombie stuck mid-swing.
	if ZombieDB.can_smash(p_type):
		smash_windup = ZombieDB.get_hammer_windup(p_type)
		smash_recovery = ZombieDB.get_hammer_recovery(p_type)
	else:
		smash_windup = 0
		smash_recovery = 0
		smash_armed = false
		smash_countdown = 0
	## [P68] The rage pair, read all-or-nothing like the two above: a row that writes 暴怒
	## without both numbers never swaps (ZombieDB.can_rage). The STATE is cleared here too,
	## and on BOTH branches, because this method means "become this type from scratch": the
	## numbers the swap installs are the ones the row carries, so a re-typed zombie is calm
	## whatever it was before. That is also why a rage cannot survive the downgrade below -
	## `_become_base()` runs this method again on a type that has no rage to arm.
	if ZombieDB.can_rage(p_type):
		rage_move = ZombieDB.get_rage_move(p_type)
		rage_bite = ZombieDB.get_rage_bite(p_type)
	else:
		rage_move = 0
		rage_bite = 0
	enraged = false
	var previous_art := art_path
	art_path = ZombieDB.art(p_type)
	if art_path != previous_art:
		_art_tried = false        # a different type may wear a different sprite later
	## [B17] the height axis off the same merged row, through Unit's one read (D103/D104) -
	## and deliberately HERE and not beside the face line above: a blank z_thickness is
	## estimated from the TYPE's own texture, and this is the frame that texture is chosen.
	## (_become_base re-runs apply_type, so the downgrade re-reads the height like every flag.)
	read_height(p_type)
	## [P28] And the type's VIEW SCENE, out of the same row's tscn column: it replaces the
	## sprite as this zombie's body when it resolves. No zombie scene exists yet, so this
	## is "" for every type today and the sprite above is drawn; the moment a row fills
	## that cell in, the board and its "idle" clip follow (Unit._load_view).
	set_view_path(ZombieDB.view(p_type))
	max_hp = maxi(1, p_hp)
	hp = max_hp
	armor_max = maxi(0, p_armor)
	armor = armor_max
	executed = false
	## [P60] The sprite is asked for HERE only when the board can already see this body -
	## the rule `set_view_path` just above has always followed, for the same reason.
	## Off the tree the type is a decision somebody may still take back: `_init()` opens on
	## the base zombie and `spawn_zombie` names the real one afterwards (just not after the
	## board has seen it). `Unit.place()` loads the art the moment the unit lands, so
	## loading here would only dress the guess and throw it away - and since P38 cached the
	## textures, that is all it ever did: this guard buys no IO, it buys the guarantee that
	## no body on the board ever wears a sprite its own type did not choose. A downgrade
	## (a cone losing its cone in front of the player) still changes clothes on the spot,
	## because that call runs with the zombie already in the tree.
	if is_inside_tree():
		_load_art()
	display_key = "unit." + p_type
	refresh_display_name()
	## [P30-A] The action always opens on ADVANCE: its AP price is the move-skill
	## cost, while the bar under the zombie draws the MOVE progress (move_threshold).
	current_act = Act.ADVANCE
	threshold = BalanceBattle.ZOMBIE_MOVE_COST
	action_label = "ADVANCE"
	action_key = "action.advance"
	move_progress = 0


func tag() -> String:
	return "Zombie#%d" % uid


func refresh_display_name() -> void:
	## [P26] The name follows the TYPE, and ZombieDB owns it (language layer first, the
	## sheet's own words second). Overridden because the base class would keep the OLD
	## language's string as its fall-back, which would leave a 路障僵尸 labelled in the
	## previous language after a live switch.
	display_name = ZombieDB.name(zombie_type) + display_tag


func type_label() -> String:
	## The type id as the log spells it ("zombie_cone"), so a spawn line names both what
	## the player sees and what the file asked for.
	return zombie_type


func can_vault() -> bool:
	## A vault needs a charge, a plant to clear and somewhere to land: a plant in the
	## very first column has no "one cell further left" to jump to.
	return vault_charges > 0 and col - 2 >= 0 and is_alive()


func summon_is_due() -> bool:
	## [P47] Does this zombie owe a summon right now? The countdown stops at 0 while a
	## call is owed, so a dancer that finds no free cell behind it does not ALSO lose
	## the summon - it asks again next round (act() re-arms it by one round).
	return summon_count > 0 and summon_countdown <= 0


func tick_summon() -> bool:
	## [P47] One round off the summon clock, called by GameManager._do_turn_start for
	## every zombie beside the freeze riders and the busy plants. Returns true on the
	## round the clock runs out, which is the only moment a caller may log "due"
	## without digging through the counter itself.
	if summon_countdown <= 0:
		return false
	summon_countdown -= 1
	return summon_countdown == 0


func can_smash() -> bool:
	## [P48] Does this TYPE fight with a hammer? Named like can_vault() so the
	## decider reads as a list of abilities; the number behind it (锤击前摇 > 0) is
	## already checked by ZombieDB.can_smash, so a prose-only 锤击 row says no here too.
	return smash_windup > 0


func begin_smash_windup() -> void:
	## [P48] Raise the hammer. Idempotent on purpose: the AP loop re-decides before
	## every use, so WINDUP can be chosen again in the very round that started it, and
	## each of those has to be the SAME swing rather than a fresh 3-round wind-up.
	if smash_armed:
		return
	smash_armed = true
	smash_countdown = smash_windup


func smash_is_due() -> bool:
	## [P48] The hammer falls on the round its countdown runs out - and only while it
	## is raised, so an unarmed giant is never "due" for a swing it never started.
	return smash_armed and smash_countdown <= 0


func tick_smash() -> bool:
	## [P48] One round off the wind-up clock, called by GameManager._do_turn_start
	## beside the summon clock. True on the round the hammer becomes due, which is the
	## only moment a caller may log "the swing lands this round" without reading the
	## counter itself.
	if not smash_armed or smash_countdown <= 0:
		return false
	smash_countdown -= 1
	return smash_countdown == 0


func cancel_smash_windup() -> void:
	## [P48] Call the swing off (see ZombieDB / the header: the sheet only says the
	## giant raises and drops, so a wind-up whose plant died under someone else's
	## attack is treated as a wasted swing, not as an attack on thin air). The giant
	## goes back to walking; the next plant it meets starts a NEW wind-up.
	smash_armed = false
	smash_countdown = 0


func _draw_body() -> void:
	super._draw_body()
	if has_art() or has_view():
		return          # real art already reaches left; the marker is for the flat shape
	# a darker bar on the left edge marks the facing direction (walks left)
	var half := body_size * 0.5
	draw_rect(Rect2(Vector2(-half - 6.0, -12.0), Vector2(8.0, 24.0)), _body_tint().darkened(0.40))


func _draw_hp_bar() -> void:
	## [P26] The hp bar, plus the armour strip above it when this type wears armour.
	## The strip is only drawn while some armour is LEFT: once it is broken the zombie
	## looks like what it now is.
	super._draw_hp_bar()
	if armor_max <= 0 or armor <= 0:
		return
	var w := BalanceUI.UNIT_BAR_WIDTH
	var h := BalanceUI.UNIT_ARMOR_BAR_HEIGHT
	var top := BalanceUI.UNIT_ARMOR_BAR_Y
	draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w, h)), BalanceUI.COLOR_ARMOR_BG)
	var ratio := clampf(float(armor) / float(armor_max), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-w * 0.5, top), Vector2(w * ratio, h)), BalanceUI.COLOR_ARMOR_FILL)


# ---------------------------------------------------------------- damage + armour
func take_damage(amount: int, p_source: Unit = null, p_opts: Dictionary = {}) -> void:
	## [P26] Armour soaks the hit before hp does. Two rules hang off that:
	##   - breaking it may DOWNGRADE the zombie (conehead / buckethead / screen door /
	##     football helmet), which is why the armour values in the sheet are the real
	##     difficulty knob of those types;
	##   - the base zombie's "below a third" rule is checked after EVERY hit, so a
	##     zombie that is already fragile dies even though the hit did not kill it.
	## [P34] A third: the armour only soaks a hit that has to go through it. A shot
	## fired with "pierce_armor" (the fume-shroom's breath, whose 技能效果 says
	## 无视护甲) skips the soak entirely and lands on hp - armour intact, and no
	## downgrade, because nothing broke it.
	## [P45] A fourth, and it is the door's own half of "铁门只挡正面": a hit that
	## arrives from BEHIND this zombie (the source stands at a higher column, since
	## zombies walk left) walks past the door and lands on hp the same way - again
	## with the door left intact, because nothing had to break it for the hit to pass.
	## [P77] A fifth, which is the OTHER word of that same sentence: the door only stops
	## a shot that flies the STRAIGHT line. Whatever is not one - the melon's arc, a
	## one-shot blast, a spike underfoot, the shovel - never asks the door's leave.
	if amount <= 0 or not is_alive():
		return
	var left := amount
	var pierces: bool = bool(p_opts.get("pierce_armor", false)) \
		or (back_attack_ignores_armor and _struck_from_behind(p_source)) \
		or _door_bypassed(p_opts)
	if armor > 0 and not pierces:
		var soaked := mini(armor, left)
		armor -= soaked
		left -= soaked
		## [P50] The metal is what this hit met, so the metal is what answers - here and
		## not in the projectile, because the shot cannot know whether the armour soaked
		## it, whether it pierced, or whether it came in from behind the door.
		SFX.play("armour")
		if armor <= 0:
			_break_armor()
	if left > 0:
		super.take_damage(left, p_source, p_opts)
		if not is_alive():
			return          # the hit itself was lethal: nothing left to execute
	_check_execute()


func _struck_from_behind(p_source: Unit) -> bool:
	## [P45] Which side a hit came from. Zombies walk LEFT, so anything at a HIGHER
	## column is behind this zombie - the door is carried on the facing side, so a hit
	## from back there never meets it. A source with no cell (not yet on the board, or
	## already gone) is not evidence of a back attack: the door keeps protecting.
	if p_source == null or not is_instance_valid(p_source):
		return false
	return p_source.col > col


func _door_bypassed(p_opts: Dictionary) -> bool:
	## [P77] The other half of the door's sentence, which the sheet used to state only for
	## peas ("只挡正面豌豆") while the code let ANY hit be soaked by it. The ruling is that
	## the door stops a STRAIGHT shot and nothing else, so the question this asks is not
	## "did this hit come from the front" but "is this hit a shot at all":
	## Projectile answers true for itself, PultProjectile answers false (an arc flies over
	## the door, exactly as it flies over the bodies in front of it), and a one-shot blast,
	## a spike or the shovel never set the key - so all of those land on hp with the door
	## still hanging there, unbroken.
	##
	## The gate is `blocks_projectiles`, NOT `armor > 0`: a cone, a bucket or a newspaper
	## is armour but not a door, and a melon still pays for those. Where the two rules of
	## the same sentence disagree, the difference is deliberate - "只挡正面" is about which
	## side the door faces, "只挡直线射弹" about what kind of hit it is carried to stop.
	return blocks_projectiles and not bool(p_opts.get("straight_shot", false))


# ---------------------------------------------------------------- status effects
func apply_hit_effects(p_effects: Dictionary, p_opts: Dictionary = {}) -> void:
	## [P34] Called by Projectile after the damage, on both impact paths. A rider is
	## a ROUNDS counter, and a fresh hit refreshes rather than stacks: two snow peas
	## in one round leave the zombie frozen for the same number of rounds one of them
	## would have granted, not for twice as long. That is also why repeated hits can
	## never freeze something permanently - the counter only ever counts down.
	## [P45] The other half of the door sentence - "铁门会格挡射弹的特殊效果" - is the
	## gate below: while a door type still HAS its armour, the door is what the shot
	## hit, so the rider the shot carried stays on the far side of it. Break the door
	## and nothing refuses the riders any more, which is why this reads `armor > 0`
	## rather than the type.
	## [P77] One more condition joins the gate, and it is the same one the damage above
	## already asks: a hit the door does not stop is a hit whose rider the door cannot
	## refuse either. So this is computed from the OPTIONS the shot brought, not from the
	## armour alone - a melon's chill lands on a screen door while the door is still up,
	## because that melon never met the door at all.
	var door_stops: bool = blocks_projectiles and armor > 0 \
		and bool(p_opts.get("straight_shot", false))
	var landed := false
	var froze := false
	for key in p_effects:
		var id := str(key)
		var rounds := int(p_effects[key])
		if rounds <= 0:
			continue
		if StatusDB.is_instant(id):
			continue          # [P59/P90] a shove, not a countdown - resolved after this loop
		if carries_status_flag(StatusDB.immune_flag(id)):
			continue          # the sheet says 免疫冻结: the rider never lands
		if door_stops:
			continue          # [P45] the sheet says 格挡射弹: the door takes the shot
		## [P90] What a SECOND hit does to a counter that is still running is a column of
		## the status row (the P34 rule "a fresh hit refreshes, it never stacks" is the
		## `max` value of it, and it is the reason repeated hits can never freeze a body
		## forever: the counter only ever counts down).
		var before := int(effect_rounds.get(id, 0))
		match StatusDB.stack_rule(id):
			StatusDB.STACK_ADD:
				effect_rounds[id] = before + rounds
			StatusDB.STACK_REPLACE:
				effect_rounds[id] = rounds
			_:
				effect_rounds[id] = maxi(before, rounds)
		landed = true
		if id == EFFECT_FREEZE:
			froze = true
	if landed:
		queue_redraw()
	## [P59] 击退 arrives on the same channel as the riders because a hit's effect has to
	## reach both impact paths (a live flight and a fast-forwarded round) and this function
	## is the one place they meet. It is NOT a status, so it does not join the loop above:
	## the body moves here and now, and it moves the way it came - away from the brain.
	## The door refuses a shove exactly as it refuses a freeze (while it is up, the door is
	## what got hit), and a shove with no room left behind it reports itself by not moving.
	## What the push does NOT touch is `move_progress`: ice already taught that a stopped
	## zombie keeps how far it had walked towards its next step, so a knocked-back body
	## starts closing the gap again immediately instead of paying for the cell twice.
	var push := int(p_effects.get(EFFECT_PUSH, 0))
	if push > 0 and not door_stops:
		push_back(push)
	## [P50] The chill sounds like the rider LANDING, which is a different fact from the
	## shot arriving: a snow pea that hits a 铁门 plays its flop and nothing else, and a
	## 免疫冻结 zombie has no counter written, so it stays quiet too. Both impact paths of
	## the projectile already come through this one function, so this single hook covers a
	## live flight and a fast-forwarded round alike.
	if froze:
		SFX.play("freeze")


func has_effect(p_id: String) -> bool:
	return int(effect_rounds.get(p_id, 0)) > 0


func carries_status_flag(p_flag: String) -> bool:
	## [P90] Does this zombie's TYPE carry the 特殊机制 flag the status table names? Asked
	## by flag NAME, so a second immune status needs a sheet flag and no new field here -
	## and the answer can never drift from the sheet ZombieDB parsed.
	return p_flag != "" and ZombieDB.has_flag(zombie_type, p_flag)


func blocked_status() -> String:
	## [P90] Which of the binders actually takes this zombie's action phase, or "" - the
	## question the action gates ask instead of naming one status. A future 禁行动 status
	## therefore works the moment its row exists.
	for key in effect_rounds:
		var id := str(key)
		if StatusDB.blocks_action(id):
			return id
	return ""


func is_frozen() -> bool:
	## Kept as its own question: the ice is what paints the zombie and what the probes ask
	## about. A status that BLOCKS is `blocked_status()`.
	return has_effect(EFFECT_FREEZE)


func tick_effects() -> PackedStringArray:
	## [P34] One round off every rider, called once per round by GameManager at
	## TURN_START (the same place the 铁壁 flag clears). Returns what EXPIRED, so the
	## log can name the zombie that starts walking again.
	var expired := PackedStringArray()
	for key in effect_rounds.keys():
		var left := int(effect_rounds[key]) - 1
		if left > 0:
			effect_rounds[key] = left
			continue
		effect_rounds.erase(key)
		expired.append(str(key))
	return expired


func effect_text() -> String:
	## The riders in one log fragment, in the CURRENT language: "[Status] freeze x2" in
	## English, "冻结 x2" in Chinese - the phrase belongs to the status row (P90), so a
	## new status is translated by writing its row instead of editing this function.
	if effect_rounds.is_empty():
		return ""
	var parts := PackedStringArray()
	for key in effect_rounds:
		parts.append(StatusDB.text(str(key), int(effect_rounds[key])))
	return ", ".join(parts)


func action_text() -> String:
	## [P34] The word under a walking zombie's bar is normally ADVANCE; while frozen
	## it says why the bar is not filling. The move progress itself stays where it
	## was, so the bar still reads "how close the next step is" under the new word.
	## [P48] The hammer's two waits get the same treatment: 举锤 while the wind-up runs
	## and 挥锤后 while the giant recovers, because a zombie that is clearly not walking
	## and is not frozen would otherwise read as a stuck ADVANCE. Frozen still wins -
	## ice takes the action phase and the swing in it with it. The recovery is matched
	## on its note rather than on the counter alone so that any other busy reason a
	## zombie picks up later cannot borrow this label.
	var binder := blocked_status()
	if binder != "":
		## [P90] the bar word comes from the status row through the language layer: the
		## freeze key is the one already written, a new status falls back to its own name.
		return Loc.t("action." + binder, StatusDB.name_of(binder))
	if stand_down_note == "recovering":
		return Loc.t("action.recovering", "RECOVERING")
	if smash_armed:
		return Loc.t("action.windup", "WINDING UP")
	return super.action_text()


func _body_tint() -> Color:
	## [P34] Ice over the flat placeholder shape (see Unit._body_tint).
	## [P68] and the rage under it, with the ice on top: the two states can be up at the
	## same time (a frozen newspaper is still enraged - the paper does not come back), and
	## the freeze is the one the player has to act on, so it takes the colour exactly like
	## it takes the action label in `action_text()`. The red returns with the thaw, because
	## `enraged` is permanent and `effect_rounds` counts down.
	var c := super._body_tint()
	if is_frozen():
		return c.lerp(BalanceUI.COLOR_FREEZE, BalanceUI.FREEZE_TINT)
	return c.lerp(BalanceUI.COLOR_RAGE, BalanceUI.RAGE_TINT) if enraged else c


func _art_tint() -> Color:
	## [P34] and the same over a sprite / view scene, which modulates instead.
	## [P68] same two states, same precedence (see _body_tint).
	var c := super._art_tint()
	if is_frozen():
		return c.lerp(BalanceUI.COLOR_FREEZE, BalanceUI.FREEZE_TINT)
	return c.lerp(BalanceUI.COLOR_RAGE, BalanceUI.RAGE_TINT) if enraged else c


func _check_execute() -> void:
	if not executes or not is_alive():
		return
	if hp > int(max_hp / 3.0):
		return
	executed = true
	hp = 0
	died.emit(self)


func _break_armor() -> void:
	armor = 0
	if grid != null:
		Fx.spawn_popup(position + Vector2(0.0, -BalanceUI.UNIT_BODY_SIZE * 0.6),
			Loc.t("msg.popup.armor_break"), BalanceUI.COLOR_ARMOR_FILL)
	if armored_downgrade:
		_become_base()
	elif can_rage():
		## [P68] The two branches are mutually exclusive BY ORDER, not by the sheet: a row
		## could write both sentences, and then the downgrade wins because it is the one
		## that changes what the zombie IS (`_become_base` re-runs apply_type, which clears
		## the rage pair with the type). A row that only rages keeps its type, its name and
		## its sprite and swaps two numbers instead.
		_enrage()
	queue_redraw()


func can_rage() -> bool:
	## [P68] Does this TYPE have a rage to lose? Named beside can_smash() for the same
	## reason: the numbers being there is already decided by ZombieDB.can_rage(), so a
	## prose-only 暴怒 row answers false here and the battle never invents one.
	return rage_move > 0 and rage_bite > 0


func _enrage() -> void:
	## [P68] "报纸被打掉后暴怒：移动变1，啃食变150" - what this method deliberately does
	## NOT do is the interesting part. `_become_base()` above hands the body to another
	## row, because a cone without its cone genuinely IS a plain zombie; a newspaper
	## without its paper is still the newspaper zombie, only angrier. So the type, the
	## display name, the sprite and the hp all stay exactly where they were and only the
	## two numbers the row names are swapped in - the same 移动 / attack the calm state read
	## out of the same row.
	##
	## MOVE PROGRESS is carried over (clamped under the new, SHORTER bar) for the reason
	## the downgrade gives it: rage makes the zombie faster, so 2 of 3 banked steps now
	## already fill a bar of length 1, and without the clamp the round it enrages would
	## also hand it a free cell.
	##
	## One-way, and the guard is belt-and-braces rather than a fix: `armor` is 0 from the
	## line above, so `_break_armor()` cannot run again on this body unless somebody gives
	## it armour back. What `enraged` really carries is the assertion the probe and the
	## next reader want - "this zombie has already spent its paper".
	if enraged or not can_rage():
		return
	enraged = true
	move_threshold = maxi(1, rage_move)
	bite_damage = rage_bite
	move_progress = mini(move_progress, maxi(move_threshold - 1, 0))
	queue_redraw()


func _become_base() -> void:
	## "护甲被打掉后变普通僵尸": the type AND the name follow the base row, so a stripped
	## zombie behaves - and reads - exactly like a plain one. Its hp is NOT reset: the
	## damage it already took stays on it (only the armour layer is gone), and its MOVE
	## PROGRESS is carried over (clamped under the new 移动 length) so losing a helmet
	## does not also throw away the steps it had already taken towards the next cell.
	var keep_hp := hp
	var keep_max := max_hp
	var keep_progress := move_progress
	apply_type(ZombieDB.BASE_ID, keep_max, 0)
	hp = clampi(keep_hp, 1, max_hp)
	move_progress = mini(keep_progress, maxi(move_threshold - 1, 0))
	queue_redraw()


# ---------------------------------------------------------------- actions
func set_act(new_act: int) -> bool:
	## Switching the action clears the MOVE progress: progress never carries over
	## across a switch (the confirmed rule, [P30-A] re-homed from the dead action bar).
	## Returns true when the action actually changed.
	if current_act == new_act:
		return false
	current_act = new_act
	move_progress = 0
	queue_redraw()
	match current_act:
		Act.ADVANCE:
			## [P30-A] one use of the move skill costs ZOMBIE_MOVE_COST AP; the walk
			## itself is paid for by the sheet's 移动 column (the base zombie's 3,
			## a football zombie's 2 is faster, an imp's 1 is fastest), which the bar
			## under the zombie draws as the MOVE progress.
			threshold = BalanceBattle.ZOMBIE_MOVE_COST
			action_label = "ADVANCE"
			action_key = "action.advance"
		Act.BITE:
			threshold = BalanceBattle.ZOMBIE_BITE_COST
			action_label = "BITE"
			action_key = "action.bite"
		Act.EAT_BRAIN:
			threshold = BalanceBattle.ZOMBIE_EAT_BRAIN_COST
			action_label = "EAT"
			action_key = "action.eat"
		Act.VAULT:
			threshold = BalanceBattle.ZOMBIE_VAULT_COST
			action_label = "VAULT"
			action_key = "action.vault"
		Act.SUMMON:
			## [P47] The sheet prices no AP for 召唤, so it pays the cheapest zombie
			## action there is - the same 1 a bite costs - and a dancer never loses its
			## walk to calling its backup (it has 3 AP in a round).
			threshold = BalanceBattle.ZOMBIE_SUMMON_COST
			action_label = "SUMMON"
			action_key = "action.summon"
		Act.WINDUP:
			## [P48] The wind-up is priced as the WHOLE round on purpose (see
			## BalanceBattle.ZOMBIE_WINDUP_COST): the zombie phase re-decides after every use,
			## and a 1-AP wind-up would let one giant take its three raising rounds in a
			## single round and drop the hammer on the next turn.
			threshold = BalanceBattle.ZOMBIE_WINDUP_COST
			action_label = "WINDUP"
			action_key = "action.windup"
		Act.SMASH:
			threshold = BalanceBattle.ZOMBIE_SMASH_COST
			action_label = "SMASH"
			action_key = "action.smash"
	return true


# ---------------------------------------------------------------- the bar (P30-A)
func bar_shown() -> bool:
	## [P30-A] A zombie draws a bar ONLY while it walks: the bar is the MOVE
	## progress (the sheet's 移动 length). Biting, eating and vaulting are plain
	## AP spends with nothing to progress towards, so - like a plant's firing -
	## they draw no bar.
	return current_act == Act.ADVANCE


func action_bar_ratio() -> float:
	## A walking zombie shows its MOVE progress on the bar, not its AP. The
	## super() line keeps the function total for the moment a switch to another
	## action lands between redraws - that bar is not drawn (see bar_shown).
	if current_act == Act.ADVANCE:
		return clampf(float(move_progress) / float(maxi(1, move_threshold)), 0.0, 1.0)
	return super.action_bar_ratio()


func bar_text() -> String:
	if current_act == Act.ADVANCE:
		return "%s %d/%d" % [action_text(), move_progress, move_threshold]
	return super.bar_text()


func bite_value() -> int:
	## [P30-A] What ONE bite costs now: BITE_DAMAGE_RATIO of the sheet's 啃食, floored
	## at 1 so a weak type cannot be neutered into a harmless zombie by the rounding.
	return maxi(1, int(round(float(bite_damage) * BalanceBattle.BITE_DAMAGE_RATIO)))


func melee_fx_id() -> String:
	## [P110e] WHAT A ZOMBIE'S BLOW LEAVES ON THE BODY IT OPENS - the same door a human piece
	## answers (HumanPiece.melee_fx_id), read off this type's own sheet row. The cell lives in
	## zombies.csv and that sheet's DEFAULT row says "claw", so every type answers the same thing
	## until one of them states otherwise - "every zombie claws" is one cell, not forty-four.
	return ZombieDB.melee_fx(zombie_type)


func brain_value() -> int:
	## [P30-A] The same ratio on the sheet's 啃脑伤害 (the user confirmed the 30% rule
	## for the bite; eating the brain is the identical action, priced identically).
	return maxi(1, int(round(float(brain_damage) * BalanceBattle.BITE_DAMAGE_RATIO)))


func relocate_to(p_col: int, p_row: int) -> void:
	## [P59] THE ONE WAY a zombie changes cell. The dance is three lines - come off the
	## lane registry, move, register again UNDER THE NEW CELL - and doing it in the wrong
	## order (or with the old coordinates on the way back in) leaves the grid holding a
	## stale entry, which reads to every lane query as a zombie sitting in two cells at
	## once. Until this batch the ADVANCE and VAULT branches each wrote those three lines
	## by hand; 击退 would have been the third copy, so they are one function now.
	if grid != null:
		grid.unregister_zombie(col, row, self)
	move_to_cell(p_col, p_row)
	if grid != null:
		grid.register_zombie(col, row, self)


func push_back(cells: int) -> bool:
	## [P59] 击退: shoved back the way it came, i.e. to a HIGHER column (a zombie walks
	## left towards the brain, so "back" is the spawn side). False when there is no room
	## left - a body already on the last column cannot be pushed off the board, and the
	## sheet's sentence ends at the lawn. Sharing the destination cell with another zombie
	## is fine: the occupancy lists stack bodies in one cell already, which is what two
	## walkers in the same column have always meant.
	var to := mini(col + cells, Balance.COLS - 1)
	if to == col:
		return false
	relocate_to(to, row)
	return true


func act() -> String:
	match current_act:
		Act.ADVANCE:
			if col <= 0:
				return "-> ADVANCE blocked at col 0"
			var from_col := col
			relocate_to(col - 1, row)
			return "-> ADVANCE (%d,%d) -> (%d,%d)" % [from_col, row, col, row]

		Act.BITE:
			var target: Unit = grid.get_plant_at(col - 1, row) if grid != null else null
			if target == null:
				return "-> BITE but no plant at (%d,%d) (skipped)" % [col - 1, row]
			var before := target.hp
			## [P110] Named effects: the chomp is an "attack" (a forward lean plus the old
			## lunge) and the plant's answer is a "hit" - the direction of both is resolved
			## against each body's own facing, so neither number is spelled here.
			play_fx("attack")
			target.take_damage(bite_value(), self)
			## [P50] After the null guard above: a chomp is the bite HAPPENING, not the
			## zombie deciding to chew, and a skipped action has already returned.
			SFX.play("bite")
			if grid != null:
				Fx.spawn_spark(target.position, BalanceUI.COLOR_HP_FILL)
				## [P110] This used to shake the victim RIGHT, i.e. towards the mouth that
				## was biting it. "Backward" now means away from the biter, which is what the
				## projectile path always meant and what the lean is drawn for.
				target.play_fx("hit")
				## [P110b/P110e] And the picture the ZOMBIE'S OWN ROW names, on the body it just
				## opened: the spark says "something happened here", the picture says WHAT
				## happened. Asked of the body, never chosen from is_zombie here - a type whose
				## cell named something else would show that instead. Facing is the attacker's,
				## so a body that had to turn around gets a mark trailing the other way; a body
				## with no picture of its own ("" or an id nobody drew) keeps the spark alone.
				Fx.spawn_melee_fx(melee_fx_id(), target.position, facing_dir())
			return "-> BITE %s(%d,%d) hp %d -> %d" % [target.display_name,
				target.col, target.row, before, target.hp]

		Act.VAULT:
			## [P26] "跳过第一株植物（不咬，直接越过1格），跳过之后变普通僵尸"
			var plant: Unit = grid.get_plant_at(col - 1, row) if grid != null else null
			if plant == null or not can_vault():
				vault_charges = 0
				return "-> VAULT but there is nothing to vault over (charge spent)"
			var from_col := col
			vault_charges = 0
			relocate_to(maxi(plant.col - 1, 0), row)
			_become_base()
			return "-> VAULT over %s: (%d,%d) -> (%d,%d), now a plain zombie" % [
				plant.display_name, from_col, row, col, row]

		Act.SUMMON:
			## [P47] "每7回合召唤1只伴舞僵尸". GameManager does the placing (it owns the
			## uid, the level's hp scaling and the grid), so this branch spends the action
			## and re-arms the clock ONLY for the calls that really landed: a lawn that is
			## full behind the dancer keeps the summon owed and asks again next round.
			var called: PackedStringArray = board.summon_children(self)
			if called.is_empty():
				summon_countdown = 1
				return "-> SUMMON owed but no free cell behind it (ask again next round)"
			summon_countdown = summon_rounds
			return "-> SUMMON %d x %s: %s" % [called.size(), summon_id, ", ".join(called)]

		Act.WINDUP:
			## [P48] Raising the hammer: this branch starts the swing and reports where
			## it stands - the countdown itself is run by GameManager._do_turn_start, so
			## the rounds are rounds of the WHOLE board, not of this zombie's turns to
			## act (a giant that is frozen mid-wind-up still loses rounds, which is the
			## point of ice against a hammer).
			begin_smash_windup()
			return "-> WINDUP hammer raised (%d round(s) until it falls)" % smash_countdown

		Act.SMASH:
			## [P48] The hammer drops on the plant in front for the row's FULL attack - no
			## BITE_DAMAGE_RATIO here, because that 30% is the price a QUICK 1-AP bite
			## pays, and this swing has spent three whole rounds getting here. Then the
			## giant is busy for 锤击后摇 rounds on the generic counter the chew uses, so
			## the recovery costs it the next one or two action phases of its own.
			var victim: Unit = grid.get_plant_at(col - 1, row) if grid != null else null
			if victim == null:
				cancel_smash_windup()
				return "-> SMASH but no plant at (%d,%d) (hammer lowered)" % [col - 1, row]
			var before_hit := victim.hp
			smash_armed = false
			smash_countdown = 0
			if smash_recovery > 0:
				stand_down_rounds = smash_recovery
				stand_down_note = "recovering"
			shake(Vector2.DOWN, BalanceUI.ANIM_LUNGE_DIST)
			victim.take_damage(bite_damage, self)
			## [P50] The giant's own answer to the chomp: the sheet gave it a hammer, so
			## it gets the sample that ends a plant instead of the one that chews it.
			SFX.play("smash")
			if grid != null:
				Fx.spawn_spark(victim.position, BalanceUI.COLOR_HP_FILL)
				victim.shake(Vector2.UP, BalanceUI.ANIM_SHAKE_DIST)
			return "-> SMASH %s(%d,%d) hp %d -> %d%s" % [victim.display_name, victim.col,
				victim.row, before_hit, victim.hp,
				("" if smash_recovery <= 0 else ", then %d round(s) recovering" % smash_recovery)]

		Act.EAT_BRAIN:
			var before_brain: int = board.brain_hp
			var value := brain_value()      # [P30-A] 30% of the sheet's value, like the bite
			play_fx("attack")       # [P110] the brain is to the left, so this is the same lean
			board.damage_brain(value)
			if grid != null:
				var center: Vector2 = grid.brain_zone_rect().get_center()
				Fx.spawn_spark(center, BalanceUI.COLOR_BRAIN)
				Fx.spawn_popup(center + Vector2(0.0, -20.0),
					"-%d" % value, BalanceUI.COLOR_BRAIN)
			return "-> EAT_BRAIN %d -> %d" % [before_brain, board.brain_hp]

	return "(idle)"
