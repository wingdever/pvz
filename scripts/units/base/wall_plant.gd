class_name WallPlant
extends Unit
## [P34] THE PLANT THAT ONLY STANDS THERE - the wall-nut's body, shared with the
## tall-nut: no skill to cast, no target to look for, a big health pool and a 大招
## that heals it and shrugs off damage for a round or two.
##
## The one thing a subclass of this class has to say is which ultimate its sheet row
## means and how long that immunity lasts: the wall-nut's 铁壁 holds for the round it
## was cast in, the tall-nut's 钢铁壁垒 for two (their 大招效果 columns), and the value
## healed is the sheet's 大招数值 in both cases. Everything else - the threshold 0 that
## keeps the engine from looping a free skill, the "BLOCK" label, the heal - is the
## same lines repeated, which is what this base exists to stop.

## How many round-starts the immunity survives, once fired. 1 = "本回合内免疫伤害".
var immunity_rounds: int = 1
## The sheet id this instance reads its numbers through (see ShooterPlant.plant_id).
var plant_id: String = ""


func setup_wall(p_id: String, p_default_ult: String) -> void:
	## The shared opening a subclass calls from its own _init().
	plant_id = p_id
	set_display_name("plant." + p_id)        # [P20] follows the language
	is_zombie = false
	body_shape = Shape.RECT
	body_size = BalanceUI.UNIT_BODY_SIZE
	body_color = Balance.plant_def(p_id).get("color", Balance.COLOR_WALLNUT)
	## [P26] Health from the plant's own sheet row; the wall-nut has no attack cell,
	## which is exactly why it has no skill at all.
	art_path = Balance.plant_art(p_id)
	view_path = Balance.plant_view(p_id)
	max_hp = Balance.plant_max_hp(p_id)
	hp = max_hp
	## [B11] 防御 at LEVEL 1 - a garden summon re-derives it from the slot's level
	## (Battle._attach_garden_slot), exactly like the health ceiling above it.
	defence = Balance.plant_attr_defence(p_id, 1)
	# [B16] units.csv's `face` column: which way this body's picture looks (every plant: right).
	faces_left = UnitSheet.face_left(p_id)
	## [B17] the height axis off the same merged row, through Unit's one read (D103/D104).
	read_height(p_id)
	## [P114] the two REAL-TIME traits off the same row (regen/rolling). Only the live brawl driver
	## reads these fields, so a turn-based wall-nut carries them and simply ignores them - the plain
	## blocker behaves exactly as before on the lawn, while the SAME body in 即时模式 self-heals and rolls.
	read_realtime(p_id)
	threshold = 0          # [P30-A] never acts (pure blocker): a 0 price would spin
	## the engine's AP loop forever, so "never" is spelled threshold 0, NOT cost 0.
	## [P30-B] The bar it does carry is filled by take_damage (the "hit" source)
	## rather than by casts it can never make.
	ult_id = p_id
	ult_code = Balance.plant_ult_code(p_id, p_default_ult)
	action_label = "BLOCK"
	action_key = "action.block"


func ult_implemented() -> bool:
	## [P30-B] every wall in this build runs the heal-and-brace 大招.
	return true


func act_ultimate() -> String:
	## [P30-B] Heal the sheet's 大招数值 PERCENT of max HP and refuse every hit for
	## `immunity_rounds` rounds (Unit.take_damage returns early while ult_immune
	## stands; GameManager counts the rounds down at each TURN_START).
	var percent := BalanceBattle.plant_ult_value(ult_code)
	var before := hp
	hp = mini(max_hp, hp + maxi(1, int(round(max_hp * percent / 100.0))))
	ult_immune = true
	immune_rounds = maxi(1, immunity_rounds)
	queue_redraw()
	if grid != null:
		Fx.spawn_popup(position + Vector2(0.0, -34.0), "+%d" % (hp - before),
			BalanceUI.COLOR_ULT_FILL)
	return "-> ULT iron wall hp %d -> %d + immune %d round(s)" % [
		before, hp, immune_rounds]
