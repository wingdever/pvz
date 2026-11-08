extends RefCounted
## [B1] THE BRAWL'S INTENT - who a piece goes for, and how it keeps its distance.
##
## Static, stateless, preloaded by path (the Spawn / SafeIO / arch_check idiom: a helper
## library is not an owner, so it needs no class_name and no seat in the global registry).
##
## WHY THIS IS NOT THE TURN ENGINE'S DECISION. battle.gd's _decide_zombie_act asks "is
## there a plant in the cell to my left", because over there a LANE IS A DIRECTION and the
## walk is one-way. Here there are no lanes and no left: a piece picks the nearest living
## enemy and walks at it. Those are two different facts about two different worlds - the
## intent is the half that SPLITS, never the half that is shared (BRAWL.md §12 / D10).
##
## WHY EVERY PARAMETER IS UNTYPED (and must stay that way). brawl_actor.gd PRELOADS this
## file, so a single mention of its class here - a parameter type, a return type, or an
## "as BrawlActor" cast - closes a reference cycle and Godot answers with a parse error
## instead of a game. This is the same rule Unit.board carries ("deliberately UNTYPED,
## exactly as game was before: Battle preloads the unit scripts, so typing this would be a
## cycle"). The duck typing is the price of the one-way arrow.
##
## DETERMINISM: every function here walks the array it is handed, in the order it is in. The
## session builds that array once, in a fixed order, so the same bout always plays out the
## same way. Nothing here reads a Dictionary or a random number - which is the whole reason
## a real-time mode can still be reproduced.


static func nearest_enemy(p_self, p_pool: Array):
	## The nearest living piece of the OTHER side. Ties go to whoever comes first in the
	## pool, and the pool is built left to right, so a tie is a stable answer rather than an
	## accident of timing.
	var best = null
	var best_distance := INF
	for entry in p_pool:
		var other = entry
		if other == null or other == p_self or not other.is_alive():
			continue
		## [B10] A body inside somebody's belly is not standing on the board, so it is not something
		## to walk at - and the one who swallowed it is standing right there to be walked at instead.
		if other.is_swallowed():
			continue
		if other.side == p_self.side:
			continue
		var d: float = p_self.pos.distance_squared_to(other.pos)
		if d < best_distance:
			best_distance = d
			best = other
	return best


static func lowest_hp_ally(p_self, p_pool: Array):
	## [B31] THE HEALER'S PATIENT - who a MENDING shot goes for. The twin of nearest_enemy above
	## and the reason this file owns both: the two questions are the same shape (pick one body of
	## the right kind out of this pool, in this order) and only the RIGHT KIND differs - a shot
	## that wounds walks at the nearest enemy, a shot that mends walks at its own side's most
	## damaged body. Which of the two a piece is, is answered by the ROW (data/projectiles.csv
	## 的 治疗 cell) and asked by BrawlActor._hunts_allies(); nothing here guesses from a type.
	##
	## THE SHARE, NOT THE POINTS: a 100/300 wall-nut is a sicker body than a 1/1000 tallnut,
	## because the fraction is what says how close a body is to going. That is the campaign's
	## reading too (WarmSunflower.patient()), and it is the whole reason a mend is worth aiming.
	##
	## SELF COUNTS. A wounded healer that is the most damaged body of its side mends itself - the
	## honest reading of 血量百分比最少的友方单位, and the same argument the turn engine's file makes
	## for the same word.
	##
	## NULL WHEN NOBODY IS HURT: a body at full HP is not a patient (the mend would land 0
	## points). [W-fix] What an idle HEALER does with that answer changed by the user's ruling
	## after the first war bout (widened to both modes): it no longer stops where it is, it
	## walks at its nearest FIGHTING ally - nearest_fighter_ally below - until that ally sits
	## inside its range. The null return itself is unchanged; only tick's null branch moved.
	## UNTYPED on purpose, like every signature in this file (the cycle ban above).
	var best = null
	var best_share := 1.0
	for entry in p_pool:
		var other = entry
		if other == null or not other.is_alive():
			continue
		## In a belly, and nobody can reach it - including a mend. It is also not standing where
		## a healer could walk to it, so counting it would strand the whole side on a meal.
		if other.is_swallowed():
			continue
		if other.side != p_self.side:
			continue
		var body = other.unit
		if body == null or body.max_hp <= 0:
			## The division guard the campaign carries too: a 一次性 body sits at 0 HP by sheet
			## design, and 0/0 is not a percentage.
			continue
		var share: float = float(body.hp) / float(body.max_hp)
		if share < best_share:
			best_share = share
			best = other
	return best


static func nearest_fighter_ally(p_self, p_pool: Array):
	## [W-fix] THE HEALER'S ANCHOR - the nearest living body of my OWN side that FIGHTS, asked
	## only when the patient search above came back empty (nobody hurt). The rule the user set
	## after the first war bout, GLOBAL by the user's follow-up ruling (乱斗同样适用): an idle
	## healer's DEFAULT MOVEMENT is to keep its nearest combat ally inside its own mending
	## range - it walks at that body the way a gunner walks at an enemy, and stops where a mend
	## would already land. Both grounds run the same rule, so there is no field gate to ask
	## and no second opinion to keep in step.
	##
	## WHAT COUNTS AS A FIGHTER: my side, alive, not inside a belly, and NOT another mender -
	## asked through is_healer(), the public face of the same row question tick() already pays
	## (the 治疗 cell of data/projectiles.csv), never guessed from a unit type. A huddle of
	## healers therefore has no anchor in it and its idle members simply hold, which is the
	## old answer.
	##
	## Ties walk the pool in its fixed order, like every search in this file. UNTYPED on
	## purpose (the cycle ban in the header).
	var best = null
	var best_distance := INF
	for entry in p_pool:
		var other = entry
		if other == null or other == p_self or not other.is_alive():
			continue
		if other.is_swallowed():
			continue
		if other.side != p_self.side:
			continue
		if other.is_healer():
			continue
		var d: float = p_self.pos.distance_squared_to(other.pos)
		if d < best_distance:
			best_distance = d
			best = other
	return best


static func separation(p_self, p_pool: Array) -> Vector2:
	## The soft push that keeps a scrum readable (D14 / D31: there is NO blocking, so pieces
	## may pass through their own side - "through" means being shoved aside on the way).
	## Returned in cell units, to be ADDED to the step direction rather than replacing it.
	var reach := BalanceBrawl.BODY_RADIUS_CELLS * BalanceBrawl.SEPARATION_RANGE
	var push := Vector2.ZERO
	for entry in p_pool:
		var other = entry
		if other == null or other == p_self or not other.is_alive():
			continue
		## [B10] Neither does a meal push: it is drawn at its holder's centre, and counting it here
		## would make one slime shove a scrum twice as hard as any other body of the same size.
		if other.is_swallowed():
			continue
		var off: Vector2 = p_self.pos - other.pos
		var d := off.length()
		if d >= reach:
			continue
		## [B17] A body within push reach but at a height this one shares nothing with is not
		## scrummed with - it is OVER or UNDER, and the whole point of the axis is that the
		## two never touch (docs/prompt/HEIGHT.md §3). Ask the pair through z_hits, never
		## spell out their intervals here: the strict-both-sides rule has one owner.
		if not p_self.height.z_hits(other.height):
			continue
		if d < 0.001:
			## Exactly on top of each other: pick a side and mean it, so the answer does
			## not depend on who happened to be ticked first.
			off = Vector2.RIGHT
			d = 0.001
		push += off.normalized() * (1.0 - d / reach)
	return push * BalanceBrawl.SEPARATION_STRENGTH


static func shot_lane_blocker(p_self, p_pool: Array):
	## [B22] ONE OF MY OWN, STANDING IN THE ROAD MY SHOT WOULD TAKE. The lane is the SEGMENT
	## from this body to its target, and it is measured with the SAME two radii and the SAME
	## z_hits door that BrawlShot._swept_body lives by - so "this lane is blocked" answered
	## here and "that flight would hit them" answered in the shot cannot disagree, because
	## both read BalanceBrawl.BODY_RADIUS_CELLS + SHOT_BODY_RADIUS_CELLS and nothing else.
	## Only own-side bodies count: an enemy in the road is not a reason to step aside, it is
	## what the shot is FOR (and whichever one stands nearest along the lane is the flight's
	## business, not this one's). The nearest blocker along the lane wins; ties walk the pool
	## in its fixed order, like everything else in this file.
	##
	## Returns the blocking body, or null when the lane is clear. Requires a target - the one
	## caller asks from the in-range branch, where the null target was already re-picked or
	## the tick returned. UNTYPED and duck-typed like the two functions above (the cycle ban
	## in the header: naming BrawlActor anywhere in this file is a parse error, not a style).
	var to: Vector2 = p_self.target.pos - p_self.pos
	var span := to.length()
	if span < 0.001:
		return null
	var dir: Vector2 = to / span
	var reach := BalanceBrawl.BODY_RADIUS_CELLS + BalanceBrawl.SHOT_BODY_RADIUS_CELLS
	var best = null
	var best_t := INF
	for entry in p_pool:
		var other = entry
		if other == null or other == p_self or not other.is_alive():
			continue
		if other.is_swallowed():
			continue
		if other.side != p_self.side:
			continue
		## The same height door the flight pays: a friendly FLOATING over (or under) the lane
		## does not block a cruising shot, and stepping aside for one would move the body for
		## nothing - the two answers must come from the same z_hits, not from two spellings.
		if not p_self.height.z_hits(other.height):
			continue
		var t: float = (other.pos - p_self.pos).dot(dir)
		if t <= 0.0 or t >= span:
			continue
		var lateral: Vector2 = (other.pos - p_self.pos) - dir * t
		if lateral.length() > reach:
			continue
		if t < best_t:
			best_t = t
			best = other
	return best
