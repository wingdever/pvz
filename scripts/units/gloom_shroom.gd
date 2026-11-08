class_name GloomShroom
extends ShooterPlant
## [P58] 忧郁菇 - the mushroom whose breath goes EVERY way at once. The two shrooms of
## batch 1 aim down a lane (the puff at its nearest body, the fume at all of them);
## this one's 环形喷射 is a ring, so the question it asks the lawn is not "how far ahead
## of me" but "who stands within one cell of me" - a different question, and the reason
## the box finally got its own owner (Grid.get_zombies_around, which 樱桃炸弹's 3×3 moved
## into in the same batch because it had been asking the same thing privately).
##
## WHAT THIS FILE REPLACES is only WHERE prey comes from: three functions, all queries
## (ring_bodies / volley / storm_lane). The volley's damage, the AP price, the ultimate
## bar, the shot's flight and its staggering, the summary the log prints - all of that
## stays in ShooterPlant, exactly as it does for the other seven shooters, because a new
## reach is not a new mechanic (docs/ADD_UNIT.md C.3: a subclass says WHO it is).
##
## The sheet spells both halves of it and nothing else (plants.csv 忧郁菇): attack 20,
## 费用 150, 冷却 6, HP 300 from units.csv, and 暗影风暴 120 对周围8格内所有僵尸 - the
## same ring, a bigger number, so the 大招 overrides no action at all.
##
## [P34] Mushrooms sleeping in daylight is still not modelled (no time-of-day field);
## see the note in puff_shroom.gd and the plan's "明确不做".

## [P58] 环形喷射.
const SKILL := "gloom_breath"
## [P58] 暗影风暴: 120 to every zombie in the ring.
const ULTIMATE := "shadow_storm"
## 周围8格 = the eight cells touching this one, i.e. one cell in every direction. The
## centre rides along in the query and costs nothing (see Grid.get_zombies_around).
const REACH := 1


func _init() -> void:
	setup_shooter("gloom_shroom", SKILL, ULTIMATE)


# ---------------------------------------------------------------- targeting
func ring_bodies() -> Array:
	## [P58] The live bodies inside the ring - the ONE place this plant asks the grid
	## where its prey is, so the volley and the 大招 cannot disagree about the reach and
	## neither of them re-implements the box. Alive-only because the lane queries the
	## base uses are: a fading body counted here would make has_target() answer true on
	## a lawn nobody is left to shoot.
	var out: Array = []
	if grid == null:
		return out
	for entry in grid.get_zombies_around(col, row, REACH):
		var target := entry as Unit
		if target != null and target.is_alive():
			out.append(target)
	return out


func volley() -> Array:
	## [P58] 环形喷射: one spore per body in the ring, each flying the way that body
	## stands from this mushroom (a ring has prey on both sides, and a lane-only `dir`
	## would fire every shot of it to the right). `row` per shot is the victim's own
	## lane, which is the threepeater's rule with a shorter reach. The base's lane
	## knobs - row_offsets, range_cells, targets_all_in_range, back_shots - all answer
	## "ahead of me", so this is the one function the ring replaces; has_target() and
	## act() follow it for free because they only ever read this list.
	var out: Array = []
	for entry in ring_bodies():
		var target := entry as Unit
		out.append({"target": target, "row": target.row, "dir": _storm_dir(target)})
	return out


func storm_rows() -> Array:
	## [P58] The lanes the 大招 covers: the three the ring stands across, still inside
	## the lawn - a mushroom on the top row has no row above it, and its ring is simply
	## the six cells that exist (the same clamping target_rows() does for a volley).
	var out: Array = []
	for off in [-1, 0, 1]:
		var r: int = row + off
		if r >= 0 and r < Balance.ROWS:
			out.append(r)
	return out


func storm_lane(p_row: int) -> Array:
	## [P58] 暗影风暴's swept "lane" is the ring's slice of it: the base fires its
	## whole storm through this query, so replacing the query rather than act_ultimate()
	## is what makes ult_can_fire() hold a full bar over an empty ring and spend it the
	## moment a body walks into it (the fume-shroom's 毒雾 got that for free the same way).
	var out: Array = []
	for entry in ring_bodies():
		var target := entry as Unit
		if target.row == p_row:
			out.append(target)
	return out
