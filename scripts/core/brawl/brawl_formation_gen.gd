class_name BrawlFormationGen
extends RefCounted
## [B29] THE OPPONENTS NOBODY WROTE - the generator beside the formation sheet.
##
## data/brawl/formations.csv is four rows long, and D35's ramp was a window walking over exactly
## those four: after the fourth round the offers stop changing, so the mode has no fifth round to
## speak of. This module is what lets a run keep going: it assembles an opponent out of the brawl's
## OWN bodies up to a 战力 target the round sets (BalanceBrawl.power_floor), and it tops a written
## formation up to ITS OWN floor - what it rolled plus 100 a round (BalanceBrawl.authored_floor, the
## user's 预设敌阵每回合增长100战力). The sheet stays the SHAPE of a fight, the round sets its SIZE.
##
## IT SPEAKS THE SHEET'S ROW SHAPE and nothing else: {piece, col, row, chance}, integer cells of the
## 9x5 board, exactly what data/brawl/formation_pieces.csv writes and what FormationDB.roll_pieces()
## answers. That is the whole integration - BrawlSession.offers carries rows either way, so the
## card's 只数 and 战力 (FormationDB.count_of / power_total_of), the enemy half's preview, the hover
## panel and the arena's own side all read a generated opponent through the doors a written one
## already used. No page learned that a second kind of opponent exists.
##
## WHO CALLS IT: BrawlSession.roll_offers() only. It is given the SESSION's seeded RNG, never
## randf(), because BRAWL.md §14 promises a run can be reproduced from its seed: same seed, same
## offers, same random opponents.
##
## THE BODIES IT DRAWS FROM are the mode's own list: RosterDB.drawable_ids(), which since [B31] is
## data/units/units.csv's `timed` column read out - the same list the player's shelf and rewards
## draw from and the same list the classic 图鉴's race pages show. The first version of this module
## refused the brawl's sheet on purpose ("an opponent limited to it could never threaten with
## anything the shelf does not sell"), and the user overturned the refusal: 乱斗模式的所有单位，都
## 既能够购买也能够出现在敌阵。所以随机敌阵当然能抽植物。A unit is ONE unit in this mode, sold and
## fought with off the same column; the asymmetric answer is now a bug in the sheets, not a design
## to protect. A body whose merged row says nothing about HP and attack (战力 0) is not a threat and
## is not drawn, and an id the factory cannot build is dropped the same way - so the pool today is
## the fifteen timed units minus nothing: the six humans (captain included), the six monsters, the
## one machine, 暖阳葵 and `zombie`.
##
## HOW IT SPENDS THE TARGET is one loop: draw uniformly among the bodies that still FIT in what is
## left, set one down on the next free cell of the enemy half, stop when the target is reached or the
## piece ceiling is hit. The tail is the exception: when NOTHING fits - a gap smaller than the
## cheapest body - that cheapest body is taken anyway and the loop ends. Without it the climb would
## be lumpy (a formation whose round wants 100 more and whose cheapest figure is worth 120 would
## simply stay short), and the overshoot is bounded by one body, so every opponent lands between the
## floor and one figure above it. That is also why 战力 on the CARD is the floor's first round read as
## 120-455 depending on the draw: the target is an intention, the 战力 line is a measurement.
##
## WHERE IT PUTS THEM is column by column, starting at the enemy's FRONT line (the column nearest the
## no man's land) and working back, with the five rows of a column shuffled. So a two-body opponent
## stands in a line facing the player instead of scattered over twenty cells, and a big one fills the
## half rank by rank - the way the authored rows read (哨兵 and 双人组 in column 6, 精锐队 reaching
## into 7). The cell order is the only shape decision here; a formation that wants to look like
## something (a wedge, a phalanx) is a second table of cell orders, not a change to this loop.
##
## A NAME IT WEARS: a generated opponent is not in the sheet, so it has no name_zh column and the
## language layer's small list of 阵 names is what identifies it (title_of / name_index below). The
## index is drawn with the same RNG and stored on the OFFER, so a language switch mid-session
## re-reads the same entry in the new language instead of printing a stale string.
##
## Failure policy is the mode's own: no timed unit in the sheets, no bodies to draw, and the caller's
## rows come back as they were - a session with an unreadable data/units sheet then simply fields
## fewer opponents rather than crashing, and FormationDB.status_text() / RosterDB.status_text()
## already said why at boot. [B31] An unreadable data/brawl/roster.csv no longer empties this pool:
## the bodies come from units.csv's `timed` column now, and that sheet only ever ADDS furniture.

## [B31] The factory is reached BY PATH (spawn.gd carries no `class_name`, see its header), so the
## filter below asks `is_known()` through the preload alias the other readers use.
const Spawn := preload("res://scripts/core/spawn.gd")

## The mode's timed units whose 战力 is above 0 and whose id the factory can build: [{piece, power}].
## Built once (the sheets never change mid-session) and shared by every session, because a draw takes
## the RNG, not a copy of this list.
static var _pool: Array = []
static var _pool_built := false
## How many names the language layer offers (brawl.gen.name.0, .1, …). Counted, not authored as a
## second constant: a count and a table kept in step by hand is the twin-list failure AGENTS.md §2
## refuses to maintain.
static var _names := -1


# ---------------------------------------------------------------- the two doors
static func make(p_rng: RandomNumberGenerator, p_target: int) -> Array:
	## A whole opponent, built to the round's target: the rows, in the order they were set down.
	return _fill(p_rng, [], p_target)


static func top_up(p_rng: RandomNumberGenerator, p_rows: Array, p_floor: int) -> Array:
	## [B29] A WRITTEN FORMATION, RAISED TO ITS ROUND'S FLOOR. The sheet's own roll stands where the
	## author put it; whatever the round still wants arrives through the same loop, on cells the
	## sheet left free. The incoming rows are the sheet's DICTIONARIES - this function appends, never
	## edits - so the preview and the arena keep seeing one array.
	## Rows already at or over the floor come back untouched, which is the whole of what a floor is
	## for: the increment is a MINIMUM and not a ceiling, thinning a written formation would be
	## editing the sheet at run time, and at round 1 every authored row is exactly that answer - its
	## own 战力 is its floor, so the ladder opens as its author wrote it.
	if p_floor <= FormationDB.power_total_of(p_rows):
		return p_rows
	return _fill(p_rng, p_rows.duplicate(), p_floor)


# ---------------------------------------------------------------- the parts of an offer
static func round_target(p_rng: RandomNumberGenerator, p_round_no: int) -> int:
	## The target one GENERATED offer builds to: the round's floor, moved either way by up to
	## GEN_TARGET_JITTER of itself. The draw happens here, and on the caller's RNG, so a seed replays
	## the size of the fight - and the random card is never the exact arithmetic of the curve, which
	## is what keeps it a different offer from the round before.
	var floor_power := BalanceBrawl.power_floor(p_round_no)
	var jitter := float(p_rng.randf_range(-BalanceBrawl.GEN_TARGET_JITTER,
		BalanceBrawl.GEN_TARGET_JITTER))
	return maxi(1, int(round(float(floor_power) * (1.0 + jitter))))


static func reward(p_power: int) -> int:
	## What a win over an opponent of this much 战力 pays, in the authored ladder's own ratio (see
	## BalanceBrawl.GEN_COINS_PER_POWER). Measured over the ROLLED rows, exactly like the card's
	## number, so a player who overshoots a small target is paid for the fight they actually had.
	return maxi(1, p_power / maxi(1, BalanceBrawl.GEN_COINS_PER_POWER))


static func name_index(p_rng: RandomNumberGenerator) -> int:
	## Which of the language layer's generated names this opponent wears. Drawn inside the count, so
	## the index title_of() reads back is always an entry that exists.
	var n := _name_count()
	return 0 if n <= 0 else p_rng.randi_range(0, n - 1)


static func title_of(p_index: int) -> String:
	## The name in the CURRENT language - resolved at label time, which is why the offer carries the
	## index and not the string.
	return Loc.t("brawl.gen.name." + str(p_index))


# ---------------------------------------------------------------- the loop
static func _fill(p_rng: RandomNumberGenerator, p_rows: Array, p_target: int) -> Array:
	if p_rng == null or p_target <= 0:
		return p_rows
	var pool := _get_pool()
	if pool.is_empty():
		return p_rows
	var cells := _free_cells(p_rng, p_rows)
	var total := FormationDB.power_total_of(p_rows)
	while total < p_target and p_rows.size() < BalanceBrawl.GEN_MAX_PIECES and not cells.is_empty():
		var body := _draw_body(p_rng, pool, p_target - total)
		if body.is_empty():
			break
		var cell: Vector2i = cells.pop_front()
		p_rows.append({"piece": str(body.get("piece", "")), "col": cell.x, "row": cell.y,
			"chance": 1.0})
		total += int(body.get("power", 0))
	return p_rows


static func _draw_body(p_rng: RandomNumberGenerator, p_pool: Array, p_remaining: int) -> Dictionary:
	## One body to spend on what the opponent still needs: uniformly among the members whose own 战力
	## fits inside the gap, so the target is approached from below and a big round is many bodies
	## rather than one expensive one.
	## When NOTHING fits - the gap is smaller than the cheapest body the mode knows - the cheapest is
	## taken anyway. Stopping there instead would make the floor unreachably lumpy: a formation one
	## zombie short of its round's floor would simply stay short, and the growth the round promised
	## would arrive in jumps the player cannot predict. The overshoot is bounded by that one body (the
	## loop's own test ends after it), so an opponent lands between the floor and one body above it -
	## and the card prints the SUM IT MEASURED, never the target, so the promise is never the lie.
	var fits: Array = []
	var cheapest: Dictionary = {}
	for entry in p_pool:
		var body := entry as Dictionary
		if cheapest.is_empty() or int(body.get("power", 0)) < int(cheapest.get("power", 0)):
			cheapest = body
		if int(body.get("power", 0)) > p_remaining:
			continue
		fits.append(body)
	if not fits.is_empty():
		## Uniform over the ones that fit, NOT weighted by 费用: the target is the only budget this
		## mode gives an opponent, and weighting by tier would make a deep round spend it on fewer,
		## dearer bodies for no reason the player can see.
		return fits[p_rng.randi_range(0, fits.size() - 1)] as Dictionary
	return cheapest


static func _free_cells(p_rng: RandomNumberGenerator, p_rows: Array) -> Array:
	## The enemy half's unused cells, front line first (see the header). The authored rows are read
	## for what they already occupy, so a topped-up formation never buries a written body under a
	## generated one - two bodies on one cell field as one, and the preview would show a single
	## piece while the 只数 line counted two.
	var taken: Dictionary = {}
	for entry in p_rows:
		var row := entry as Dictionary
		taken["%d,%d" % [int(row.get("col", -1)), int(row.get("row", -1))]] = true
	var out: Array = []
	for col in range(BalanceBrawl.HALF_COLS + BalanceBrawl.GAP_COLS, Balance.COLS):
		var rows: Array = []
		for r in Balance.ROWS:
			rows.append(r)
		## Shuffled with the caller's RNG: which rank of the line-up a round fills first is part of
		## what makes two rounds of the same size look different.
		for i in range(rows.size() - 1, 0, -1):
			var j := p_rng.randi_range(0, i)
			var swap = rows[i]
			rows[i] = rows[j]
			rows[j] = swap
		for r in rows:
			if taken.has("%d,%d" % [col, int(r)]):
				continue
			out.append(Vector2i(col, int(r)))
	return out


static func _get_pool() -> Array:
	## [B31] THE MODE'S LIST IS THE ENEMY'S BODY PARTS: RosterDB.drawable_ids() - units.csv's
	## `timed` column, the same list the shelf and the rewards draw from and the same one the classic
	## 图鉴 shows, so a random opponent can field a campaign plant and the player can buy any of the
	## bodies that stand against them. The ids and the figures both come from the sheets
	## (Balance.unit_power reads the same merged row the almanac prints), so a body re-numbered in
	## data/units is a different opponent without a line of code moving.
	## Two bodies are dropped: a 战力 of 0 is not a threat, and an id no roster implements would be
	## fielded as nothing (Spawn.is_known is the door the sheet validator now also reports through at
	## boot - an opponent silently one body short is not how it should arrive in the arena).
	if _pool_built:
		return _pool
	for id in RosterDB.drawable_ids():
		var power := Balance.unit_power(id)
		if power <= 0 or not Spawn.is_known(id):
			continue
		_pool.append({"piece": id, "power": power})
	_pool_built = true
	return _pool


static func _name_count() -> int:
	## How many brawl.gen.name.N entries the language tables carry, counted by probing (Loc.has_key
	## never warns on a miss, which is what makes the probe quiet). Cached: this walks a dozen keys
	## once, per session, not per label.
	if _names >= 0:
		return _names
	var n := 0
	while Loc.has_key("brawl.gen.name." + str(n)):
		n += 1
	_names = n
	return n
