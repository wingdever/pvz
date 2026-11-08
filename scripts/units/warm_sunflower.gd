class_name WarmSunflower
extends ShooterPlant
## [B30] 暖阳葵 - the plant that shoots HEALTH. Everything the pea family already knows
## how to do stays in ShooterPlant (the volley, the AP price, the muzzle, the cue, the
## "hold the AP when there is nothing to do" rule); what this file adds is the question it
## asks the lawn. Every shooter so far asks "which ZOMBIE can I reach"; a healer asks
## "which of OURS is closest to dying", and that one different question is why the family's
## first non-damage shot got its own script instead of another row of parameters.
##
## THE THREE RULES the request names, and where each one lives:
##   * the patient is the living friendly body with the LOWEST share of its own HP -
##     `patient()` below, the only targeting code in the file;
##   * the shot PASSES THROUGH everybody who is not the patient and HOMES onto the one who
##     is - `data/projectiles.csv`'s warm_sun row (轨迹=追踪, 治疗=是), which the flight
##     obeys in Projectile._swept_body()/_stops_for(). No number for it here on purpose: a
##     reach is a property of the flight, not of the plant that booked it;
##   * the amount MENDS by this plant's own attack - `skill_damage()`, the base's own door,
##     which reads the sheet's attack cell (and a garden plant's grown skill value). That is
##     why the projectile sheet carries no damage column and this file carries no number: the
##     shot is a courier, the plant owns the amount. (docs/ADD_UNIT.md §1.34.)
##
## SELF IS A PATIENT. The scan does not skip this plant: at 300 HP a wounded 暖阳葵 that is
## the most damaged body on the lawn mends itself, which is the honest reading of "血量百分比
## 最少的友方单位" - a plant that starves itself to keep healing neighbours would heal nobody
## for long. It is also the cheap case a designer can tune around, because the sheet owns the
## attack cell that decides how much comes back.
##
## NOBODY HURT = NO ACTION. When every ally on the lawn stands at full HP the volley is
## empty, has_target() says false and the battle holds this plant's AP rather than spending
## it on nothing (see the "AP held -> no target" path in Battle's plant phase). A healer with
## a whole lawn in front of it is a healer waiting, not a healer firing.
##
## NO 大招. plants.csv leaves this row's 大招代码 empty, so ult_code is "" and Unit.has_
## ultimate() draws no bar at all - a bar that fills and never pays out is the failure
## P30-B's wiring check exists to prevent. A future 大招 is a sheet row plus one override.

## [B30] 暖阳普照 - the heal's own code in data/units/skills.csv, where its AP price lives.
const SKILL := "warm_sun_heal"
## [B30] This plant's shot: the warm_sun row of data/projectiles.csv. The row says 追踪 +
## 治疗; this line only says WHICH row.
const SHOT := "warm_sun"


func _init() -> void:
	## [B30] The tint is the sun's own yellow (the same colour a fallen sun is drawn in), so
	## the flight reads as sunshine rather than as a pea that went wrong.
	shot_id = SHOT
	shot_tint = BalanceUI.COLOR_SUN_DROP
	## The third argument is the ultimate fall-back: "" because this plant has no 大招.
	setup_shooter("warm_sunflower", SKILL, "")
	action_label = "HEAL"
	action_key = "action.heal"


# ---------------------------------------------------------------- targeting
func patient() -> Unit:
	## [B30] The ONE body this plant can help: the living ally whose HP is the smallest
	## FRACTION of its own max - a 100/300 wall-nut before a 1/1000 tallnut, because the
	## fraction is what says how close a body is to going. Null when nothing on the lawn is
	## hurt (every ally at full HP), which is what makes the volley empty and the AP held.
	##
	## The scan walks the whole board rather than a lane: a 追踪 flight reaches any row, so
	## this plant's help is not bounded by the lane it stands in. Only living bodies count
	## (a body already falling is beyond a mend), and `max_hp > 0` guards the division -
	## the 一次性 family sits at 0 HP by sheet design.
	##
	## On a tie the body the board lists first wins, and the comparison is strictly-less: a
	## stable order is what lets a re-run of the same round pick the same patient.
	var best: Unit = null
	var best_share := 1.0
	if board == null:
		return null
	for u in board.units:
		if u.is_zombie or not u.is_alive() or u.max_hp <= 0:
			continue
		var share := float(u.hp) / float(u.max_hp)
		if share < best_share:
			best_share = share
			best = u
	return best


func find_target() -> Unit:
	## [B30] docs/ADD_UNIT.md teaches this name as "the body my next shot goes to", so a
	## healer answers it with its patient - the same body, not a zombie. The base's lane
	## query would here say "nearest zombie ahead", which is a true sentence about a shot
	## this plant never fires.
	return patient()


func volley() -> Array:
	## [B30] One shot, one patient. `row` is the PATIENT's lane, not this plant's (the ring
	## batch's rule - a flight that leaves toward a body in another row names that row), and
	## `dir` is which side of this plant that body stands on, so the muzzle leaves the right
	## end of the head. The homing flight re-aims every step and ignores both once it is
	## airborne, but the launch still obeys them.
	var target := patient()
	if target == null:
		return []
	return [{"target": target, "row": target.row, "dir": _storm_dir(target)}]


# ---------------------------------------------------------------- action
func act() -> String:
	## [B30] The base's act() is the right SHAPE here and the wrong WORDS: it sums a volley
	## of shots and prints "-> FIRE %d dmg". A mend is not damage, so the same three steps
	## (pick, book the flight, summarise) repeat with the number named for what it does. The
	## flight itself is still the base's fire_shot(), so nothing about how a shot works is
	## decided here.
	var shots := volley()
	if shots.is_empty():
		return "-> HEAL but no patient (should not happen)"
	var amount := skill_damage()
	var staged: bool = board != null and board.resolution_staged and grid != null
	var summary := PackedStringArray()
	for shot in shots:
		var target: Unit = shot["target"]
		if not target.is_alive():
			continue          # the synchronous path can finish it before this shot lands
		fire_shot(target, amount, int(shot["row"]), int(shot["dir"]))
		summary.append("%s(%d,%d) hp %d" % [target.tag(), target.col, target.row, target.hp])
	var suffix := " (mend on impact)" if staged else ""
	return "-> HEAL %d x %d shot(s) -> %s%s" % [amount, summary.size(), "; ".join(summary), suffix]
