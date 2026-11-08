class_name Chomper
extends Unit
## [P39] THE PLANT THAT SWALLOWS - 大嘴花: it does not damage anything. One zombie
## standing in the cell directly in front is gone, whatever its health, and the plant
## then spends its 技能效果 rounds chewing.
##
## Why this one stands alone instead of joining a base class (AGENTS "先想清楚再抽象"):
## ShooterPlant owns a volley, ProducerPlant owns sun, WallPlant owns a health pool.
## The bite is none of those - no projectile, no damage number, no lane - and today
## only data/units/plants.csv:16 describes a plant that eats bodies whole. The moment a
## second one arrives (tangle_kelp's 拖入水下 is the same 无视HP shape), the shared half
## is this file's `devour()` and moves to scripts/units/base/.
##
## WHAT THE SHEET OWNS (AGENTS.md §2), same split as every other plant:
##   plants.csv 费用 / 卡片冷却 / HP  -> the card and the health pool
##   skills.csv 技能消耗AP            -> how much of the round the bite costs
##   skills.csv 大招数值              -> how many rounds a 暴食 bite chews for
## and what this file owns is the IDENTITY: that it bites one body one cell ahead, that
## the bite ignores health, and how long an ordinary chew lasts (3 - its own 技能效果
## sentence, which no column can carry; the shooter family keeps its own numbers the
## same way, see ShooterPlant.range_cells).

const ID := "chomper"
## [P30-A] 吞噬.
const SKILL := "chomp"
## [P30-B] 暴食: the same bite, and the chew of one round instead of three.
const ULTIMATE := "big_chomp"

## Rounds the ordinary bite chews for (its 技能效果 says 咀嚼3回合). The engine ticks
## it down at TURN_START, so the chew covers this round plus (chew_rounds - 1) more.
var chew_rounds: int = 3

## [P50] The sound layer, by PATH for the reason pult_plant.gd gives (a brand-new
## `class_name` does not resolve until the editor has rescanned the project).
const SFX := preload("res://scripts/core/sfx.gd")


func _init() -> void:
	## The same opening setup_shooter() does for its family, spelled out here because
	## there is no shared body to put it in yet. Every number goes through Balance,
	## which reads the plant's own sheet row.
	set_display_name("plant." + ID)          # [P20] follows the language
	is_zombie = false
	body_shape = Shape.CIRCLE
	body_size = BalanceUI.UNIT_BODY_SIZE
	body_color = Balance.plant_def(ID).get("color", Balance.COLOR_CHOMPER)
	art_path = Balance.plant_art(ID)
	view_path = Balance.plant_view(ID)
	max_hp = Balance.plant_max_hp(ID)
	hp = max_hp
	## [B11] 防御 at LEVEL 1 - a garden summon re-derives it from the slot's level
	## (Battle._attach_garden_slot), exactly like the health ceiling above it.
	defence = Balance.plant_attr_defence(ID, 1)
	# [B16] units.csv's `face` column: which way this body's picture looks (every plant: right).
	faces_left = UnitSheet.face_left(ID)
	## [B17] the height axis off the same merged row, through Unit's one read (D103/D104).
	read_height(ID)
	skill_code = Balance.plant_skill_code(ID, SKILL)
	threshold = BalanceBattle.skill_ap_cost(skill_code)
	ult_id = ID
	ult_code = Balance.plant_ult_code(ID, ULTIMATE)
	action_label = "CHOMP"
	action_key = "action.chomp"


# ---------------------------------------------------------------- targeting
func prey() -> Unit:
	## The ONE body this plant can reach: whatever stands in the cell directly in
	## front. Nothing behind, nothing further down the lane, and no reaching past a
	## zombie that is already eating it (that one IS the cell in front).
	if grid == null:
		return null
	return grid.get_zombie_at(col + 1, row) as Unit


func has_target() -> bool:
	## [P39] The chew is part of the answer here, not only of can_act(): the engine's
	## per-plant loop re-asks has_target() before every AP it spends, so a chomper with
	## a mouth full and two zombies stacked in front still takes exactly one bite.
	return stand_down_rounds <= 0 and prey() != null


# ---------------------------------------------------------------- action
func has_skill() -> bool:
	return true


func act() -> String:
	return devour(prey(), chew_rounds)


func resolve_skill_once() -> bool:
	## The energy bean gets ONE bite, not ten: the first sets the chew, and every
	## further hit finds has_target() false and refuses (the bean is spent on what it
	## did, like every other plant).
	if not has_target():
		return false
	act()
	return true


func devour(victim: Unit, p_chew: int) -> String:
	## The whole attack: 无视HP means the bite is not a damage roll, so health, armour
	## and a giant's pool are simply never consulted. What it does keep is the engine's
	## own death path - last_attacker plus died - so the kill is credited here (exp,
	## coin drop) exactly like a pea's killing blow, and the zombie fades out like one.
	if victim == null or not victim.is_alive():
		return "-> CHOMP but nothing stands in front (should not happen)"
	var was_hp := victim.hp
	victim.last_attacker = self
	victim.hp = 0
	victim.died.emit(victim)
	stand_down_rounds = maxi(1, p_chew)
	stand_down_note = "chewing"
	if grid != null:
		Fx.spawn_popup(position + Vector2(0.0, -34.0),
			Loc.t("msg.popup.chomp"), BalanceUI.COLOR_CHEW)
	## [P50] One swallow per body actually taken: the guard at the top of this function is
	## the "nothing stands in front" case, i.e. a bite that never happened.
	SFX.play("chomp")
	queue_redraw()
	return "-> CHOMP %s(%d,%d) hp %d swallowed - health ignored, chewing %d round(s)" % [
		victim.tag(), victim.col, victim.row, was_hp, stand_down_rounds]


# ---------------------------------------------------------------- ultimate
func ult_implemented() -> bool:
	## [P30-B] 暴食 is a bite with a shorter chew, and this script runs it.
	return true


func ult_can_fire() -> bool:
	## Same rule as the ordinary bite: a full bar with nothing in front - or with the
	## mouth full - is HELD, not spent. 暴食 is still a bite, so it waits for the chew
	## that came before it the same way.
	return super.ult_can_fire() and has_target()


func act_ultimate() -> String:
	## [P30-B] The sheet's 大招数值 is the chew this one leaves behind (暴食: 咀嚼1回合).
	return devour(prey(), BalanceBattle.plant_ult_value(ult_code))


# ---------------------------------------------------------------- presentation
func action_text() -> String:
	## [P39] The word under the bar while it chews, the same trick as a frozen zombie's
	## (Zombie.action_text): the bar keeps showing how close the next bite is, this
	## says why it is not filling. Without it a chewing chomper reads as a plant that
	## broke - and the 3-round chew is the whole cost of what it just ate.
	return Loc.t("action.chewing", "CHEWING") if stand_down_rounds > 0 else super.action_text()


# ---------------------------------------------------------------- drawing
func _body_tint() -> Color:
	## [P39] A chewing chomper reads as stuffed, the way a frozen zombie reads as cold
	## (Zombie._body_tint). The note in the log says it; the colour says it to someone
	## watching the lawn, who otherwise sees a plant do nothing for three rounds.
	var c := super._body_tint()
	return c.lerp(BalanceUI.COLOR_CHEW, BalanceUI.CHEW_TINT) if stand_down_rounds > 0 else c


func _art_tint() -> Color:
	var c := super._art_tint()
	return c.lerp(BalanceUI.COLOR_CHEW, BalanceUI.CHEW_TINT) if stand_down_rounds > 0 else c
