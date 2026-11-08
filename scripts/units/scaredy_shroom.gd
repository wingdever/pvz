class_name ScaredyShroom
extends ShooterPlant
## [P59] 胆小菇 - the shooter that is afraid of what it can see. Its row spells TWO halves
## and they are not the same kind of thing:
##
##   僵尸相邻时停止attack   a GATE on the ordinary volley, read off the sheet's 特殊机制
##                        (PlantDB.fears_adjacent), exactly like P51 made 溅射 a fact: the
##                        rows are the only place the rule is written, so a plant that
##                        ever grows the words gets it without a line of code here.
##   恐惧孢子：对同行所有僵尸造成60伤害，并击退1格
##                        a MECHANIC the battle did not have - displacement. 击退 is the
##                        first rule that moves a body without spending that body's own
##                        action, so it opened two owners on the zombie side (see
##                        Zombie.relocate_to and Zombie.EFFECT_PUSH).
##
## WHAT THIS FILE DOES NOT touch is the rest of being a shooter: the volley's damage, the
## AP price, the bar, the flight and its staggering, the summary - ShooterPlant's, as for
## the other eight. The numbers are the sheet's (attack 20 / 费用 25 / 冷却 3 / HP 300, and
## 60 from the 大招 row); what lives here is geometry only, and the distance of a shove is
## geometry the same way 冻结的回合数 was when ice_shroom arrived (P43).
##
## [P34] Mushrooms sleeping in daylight is still not modelled (no time-of-day field);
## see the note in puff_shroom.gd and the plan's "明确不做".

## [P59] 远程射击: a lane shot like the peashooter's, with the fear gate below on it.
const SKILL := "scaredy_spore"
## [P59] 恐惧孢子: 60 down the whole lane, plus the shove.
const ULTIMATE := "terror_spore"
## 击退1格. Cells, not rounds, and not a tuning knob a designer moves: the sheet's own
## wording says one cell, and the two neighbouring rows of this family already keep their
## geometry (射程、冻结回合) on the script for the same reason.
const PUSH_CELLS := 1
## "相邻（1格内）" - the same one-cell box P58 gave the grid for the ring and the cherry
## bomb. Only its SAME-ROW slice counts here, which is what the sheet's 同行 says.
const NEIGHBOURS := 1

## [P59] The sheet's answer, read ONCE at spawn instead of on every volley - the same
## arrangement P51 gave 溅射 (PultPlant.setup_pult reads has_splash into `splash_ratio`) and
## P45 gave the door (apply_type reads the two 铁门 columns into their flags): the column is
## the writer, this var is the fact the battle asks. Named for what the plant does rather
## than for the cell it came from, so the two ends of the rule stay one sentence apart.
var afraid_up_close: bool = false


func _init() -> void:
	setup_shooter("scaredy_shroom", SKILL, ULTIMATE)
	afraid_up_close = PlantDB.fears_adjacent(plant_id)


# ---------------------------------------------------------------- the fear gate
func zombie_next_to_me() -> bool:
	## [P59] Is there a live body in one of this mushroom's own-lane neighbours? Asked of
	## the box the grid owns rather than a private loop: the ring already needed "who
	## stands within one cell of me", and the only difference here is that this plant
	## looks down its own lane instead of around itself.
	if grid == null:
		return false
	for entry in grid.get_zombies_around(col, row, NEIGHBOURS):
		var body := entry as Unit
		if body != null and body.is_alive() and body.row == row:
			return true
	return false


func volley() -> Array:
	## [P59] 僵尸相邻时停止attack. The gate sits on the ONE list that answers both "is there
	## anything to shoot at" (has_target) and "what does the action do" (act), so holding
	## the volley holds the AP too: the mushroom spends the round doing nothing rather than
	## firing at a zombie it is too frightened to aim at. The 大招 deliberately does not
	## route through here - fear is what makes it want to clear the lane.
	if afraid_up_close and zombie_next_to_me():
		return []
	return super.volley()


# ---------------------------------------------------------------- the shove
func act_ultimate() -> String:
	## [P59] 恐惧孢子: the base's whole-lane storm (storm_lane() with no short breath =
	## 对同行所有僵尸) carrying one extra thing on every hit - the shove. It rides the
	## shot's `effects` because that is the channel a hit's consequence has to reach BOTH
	## impact paths with (a live flight and a fast-forwarded round), which is the same
	## reason P34's freeze and P49's splash are called from both of them.
	return fire_row_storm({Zombie.EFFECT_PUSH: PUSH_CELLS})
