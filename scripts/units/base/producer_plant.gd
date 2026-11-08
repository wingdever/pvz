class_name ProducerPlant
extends Unit
## [P34] THE PLANT THAT PAYS OUT SUN - the sunflower's body, shared with anything
## that produces instead of shooting (today: twin_sunflower; the marigold's coins and
## the coffee bean join this shape when those mechanics arrive).
##
## One action spends the round's whole budget (the skill sheet prices
## sunflower_produce at 3 of 3 AP) and banks `produce_count` lots of the plant's own
## skill value. The twin is therefore NOT a second script: it is this one with
## produce_count = 2, which is exactly what its 技能效果 column says and the reason
## the number lives in the sheet rather than in code.

## How many lots of sun one PRODUCE pays out (the sheet's 技能效果 wording).
var produce_count: int = 1
## The sheet id this instance reads its numbers through (see ShooterPlant.plant_id).
var plant_id: String = ""

## [P50] The sound layer, by PATH for the reason pult_plant.gd gives (a brand-new
## `class_name` does not resolve until the editor has rescanned the project).
const SFX := preload("res://scripts/core/sfx.gd")
## [P89] the item factory: a producer CREATES sun instead of banking it (see gain_sun).
const Spawn := preload("res://scripts/core/spawn.gd")


func setup_producer(p_id: String, p_default_skill: String, p_default_ult: String) -> void:
	## The shared opening a subclass calls from its own _init(), after its parameters.
	plant_id = p_id
	set_display_name("plant." + p_id)        # [P20] follows the language
	is_zombie = false
	body_shape = Shape.CIRCLE
	body_size = BalanceUI.UNIT_BODY_SIZE
	body_color = Balance.plant_def(p_id).get("color", Balance.COLOR_SUNFLOWER)
	## [P26] The sheet's attack column is the sun one lot is worth, which is why a
	## producer has no attack field of its own to explain it.
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
	skill_code = Balance.plant_skill_code(p_id, p_default_skill)
	threshold = BalanceBattle.skill_ap_cost(skill_code)
	ult_id = p_id
	ult_code = Balance.plant_ult_code(p_id, p_default_ult)
	action_label = "PRODUCE"
	action_key = "action.produce"
	# [P15] the base skill value; a garden plant overwrites it with its own
	skill_value = Balance.plant_base_skill(p_id)


func skill_sun() -> int:
	## [P15] How much sun ONE lot is worth for this instance. The last fall-back is
	## the level's own rate (which the difficulty scales), so a sheet with an empty
	## attack cell still produces something instead of a silent 0.
	if skill_value > 0:
		return skill_value
	return board.sunflower_sun_value() if board != null else Balance.SUNFLOWER_SUN


func produce_amount() -> int:
	## What one PRODUCE banks: the lot times how many this plant pays out.
	return maxi(1, skill_sun()) * maxi(1, produce_count)


func has_skill() -> bool:
	return true


func resolve_skill_once() -> bool:
	## [P15] One instant PRODUCE, for the energy bean.
	act()
	return true


func gain_sun(p_amount: int) -> int:
	## [P89] The plant no longer banks the sun itself: it CREATES it through the item factory,
	## which drops it on the lawn next to this plant (落地) and lets the player pick it up.
	## What comes back is the pool as it stands - which is what both act() and the 大招 log,
	## and the honest answer is now "nothing yet": the sun is on the ground, not in the bank.
	## [P50] The chime moved with the collection (Game._collect_sun_drop): the sound belongs
	## to the moment the sun is GATHERED, which is also the only moment the pool moves.
	if board != null:
		Spawn.create_items(board, "sun", 1, Spawn.WHERE_FIELD, Spawn.SOURCE_SUNFLOWER,
			position, p_amount)
	return board.sun if board != null else 0


func act() -> String:
	var amount := produce_amount()
	var after := gain_sun(amount)
	## [P30-B] producing is the cast that fills the burst bar (when the sheet charges
	## it by cast, which 阳光爆发 and 阳光洪流 both do).
	if ult_charge_source() == "cast":
		charge_ultimate()
	return "-> PRODUCE +%d sun (now %d)" % [amount, after]


func ult_implemented() -> bool:
	## [P30-B] this script runs the bank-in-one-go 大招 (阳光爆发 / 阳光洪流).
	return true


func act_ultimate() -> String:
	## [P30-B] The bank gains the sheet's 大招数值 at once. No target is needed, so
	## the bar simply pays out the moment it is full (Unit.ult_can_fire only asks for
	## a value above 0).
	var amount := BalanceBattle.plant_ult_value(ult_code)
	var after := gain_sun(amount)
	return "-> ULT sun burst +%d sun (now %d)" % [amount, after]
