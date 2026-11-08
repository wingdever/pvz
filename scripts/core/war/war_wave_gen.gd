class_name WarWaveGen
extends RefCounted
## [W8] THE ENEMY ROLLER - one seeded draw that answers "what stands opposite me this round",
## for every round of a session, BEFORE any of them is fought.
##
## BrawlFormationGen's contract copied where it matters (its header line for line): the roller
## is GIVEN the session's seeded RNG and never calls randf() itself, so the war keeps the
## brawl's reproduction promise (BRAWL.md §14): same seed, same map, same rounds - the arena,
## the page's preview and an R-replay all read ONE roll, and nothing re-rolls behind a
## spectator's back.
##
## WHY IT ROLLS UP FRONT, EVERY ROUND AT ONCE: the deployment page must show the NEXT round's
## enemy line-up before 出征 commits to it (the user's ruling - 可以查看每回合敌阵阵容). A
## draw made at spawn time could be previewed by nobody. The whole timeline of rolls is one
## pure function of (seed, map), computed once when the session opens, and every later page
## or arena just reads round k out of it.
##
## WHAT THE SHEET OWNS, WHAT THE ROLLER ADDS: WarDB.piece_pool hands the weighted pieces
## (one entry per authored wave row, 概率 = the weight - a 0.3 body stays the rare body the
## author wrote) and WarDB.wave_starts hands the ROUND LIST and each round's AUTHORED COUNT
## (the distinct wave labels, their row counts). The roller adds exactly what the old timeline
## used to fix by hand: WHERE - random distinct cells in the map's right-most deploy_cols band
## ([W10], the mirror of the player's own deployment zone), never two bodies on one cell.
##
## THE SHAPES: a round is an Array of {piece, col, row} rows - the same row shape the
## deployment page commits and the arena's _fill_side spawns, so the preview, the setup and
## the field never speak two dialects. `roll` returns the Array of rounds; a map with no
## pool, no board or no rounds rolls to [] and the arena runs as the harness it was in F6.

## Determinism: the CONSUMPTION ORDER is the contract - round by round, body by body, one
## weighted die and one cell draw each, off the caller's generator and nothing else. Same
## seed, same map, same army on the same squares, in the manual and in an R-replay alike.
static func roll(p_rng: RandomNumberGenerator, p_map_id: String) -> Array:
	if p_rng == null:
		return []
	var pool := WarDB.piece_pool(p_map_id)
	var starts := WarDB.wave_starts(p_map_id)
	var cols := WarDB.cols_of(p_map_id)
	var rows := WarDB.rows_of(p_map_id)
	if pool.is_empty() or starts.is_empty() or cols <= 0 or rows <= 0:
		print("[WarGen] map '%s' rolls no enemy: pool %d row(s), rounds %d, board %dx%d"
			% [p_map_id, pool.size(), starts.size(), cols, rows])
		return []
	## [W10] THE MIRRORED ZONE (the user's symmetry ruling): the band is the map's own
	## deploy_cols, not a number of the roller's - the enemy stands in the same SHAPE of
	## ground the player deploys in, right end instead of left, and maps.csv stays the single
	## owner of both wings' width. A map the sheet cannot answer (-1) clamps to one column.
	var band := clampi(WarDB.deploy_cols_of(p_map_id), 1, cols)
	var total_weight := 0.0
	for entry in pool:
		total_weight += maxf(0.05, float((entry as Dictionary).get("weight", 1.0)))
	var out: Array = []
	for k in starts.size():
		## [W8] A FRESH band per round: rounds are separate bouts, all of whose bodies
		## spawn together at the round's opening, so a later round owes a round already
		## fought no squares. Rebuilding is not a die - the list is the band, in the
		## same order every round - so the consumption contract (one weighted die and
		## one cell draw per body) is untouched, and a sheet that someday outgrows the
		## band caps ONE round instead of starving every round after it.
		var cells: Array = []
		for col in range(cols - band, cols):
			for row in range(rows):
				cells.append(Vector2i(col, row))
		var count := int((starts[k] as Dictionary).get("count", 0))
		var round_rows: Array = []
		for n in count:
			if cells.is_empty():
				## More bodies than spawn squares is a sheet bigger than its band; the round
				## lands smaller instead of stacking two bodies in one cell (the overlap the
				## deployment page refuses is not something a roller may commit either).
				break
			var picked := _weighted_pick(p_rng, pool, total_weight)
			## Take ONE cell out of the band at random, swap-with-last style: what stays keeps
			## its order relative to the draw, which is exactly what a seed replays - and a
			## body can never share a spawn square with another.
			var i := p_rng.randi_range(0, cells.size() - 1)
			var at: Vector2i = cells[i]
			cells[i] = cells[cells.size() - 1]
			cells.pop_back()
			round_rows.append({"piece": str(picked.get("piece", "")),
				"col": int(at.x), "row": int(at.y)})
		out.append(round_rows)
		print("[WarGen] round %d/%d: %d piece(s) rolled from a pool of %d"
			% [k + 1, starts.size(), round_rows.size(), pool.size()])
	return out


static func _weighted_pick(p_rng: RandomNumberGenerator, p_pool: Array,
		p_total: float) -> Dictionary:
	## The cumulative walk, one die per body: the pool is small (a sheet's rows) and this is
	## called once per body at session birth - no alias table earns its keep here.
	var stop := p_rng.randf() * p_total
	var acc := 0.0
	for entry in p_pool:
		var row := entry as Dictionary
		acc += maxf(0.05, float(row.get("weight", 1.0)))
		if acc >= stop:
			return row
	return p_pool[p_pool.size() - 1] as Dictionary
