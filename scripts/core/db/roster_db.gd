class_name RosterDB
extends RefCounted
## [B5] THE PLAYER'S PIECES - one sheet that answers two questions about a session's roster.
##
##   data/brawl/roster.csv    piece / col / row / 权重 / 起始 / 档位   - one row per piece a
##                          session may own
##
##   WHAT A SESSION STARTS WITH  = the rows in sheet order that are NOT marked 起始 = 否,
##                                placed on the cells they name (a negative cell means "in
##                                reserve"), capped by BalanceBrawl.DEPLOY_CAP_START.
##   WHICH UNITS THE MODE HAS AT ALL = data/units/units.csv's `timed` column - [B31] the ONE
##                                owner, the same switch the classic 图鉴's five race pages read.
##                                This sheet does NOT decide who exists. It decides the FURNITURE
##                                (a cell to stand on, whether a session wakes up holding it, and a
##                                shop tier for the ids PieceDB cannot price) and an OPTIONAL
##                                relative weight for the rows it writes.
##   WHAT REWARDS AND THE SHOP DRAW FROM = every timed unit, weighted by 权重 where a row names it
##                                (a unit with no row draws at the default an empty 权重 cell has;
##                                a row written 0 is never drawn).
##
## [B31] THOSE TWO LISTS USED TO BE THE SAME LIST, because the sheet was exactly as big as the
## furniture: 3 board cells + 9 bench slots = the twelve rows it had, so "in the sheet" and "in
## the opening line-up" answered one question. A row for 暖阳葵 broke that - a fourteenth row is
## DROPPED at every session start (no cell, no slot) and a piece that cannot be seated is a piece
## the shop can never sell either. 起始 = 否 says plainly what such a row is: something you may
## WIN or BUY, never something you WAKE UP with. It costs nothing to keep (only the draw reads
## it), and it is the honest answer; widening the bench to hold a fourteenth piece is a different
## decision that belongs to the user, not to a sheet.
##
## 档位 (the shop TIER, 1-4) exists for the ids this sheet may name that PieceDB cannot price.
## PieceDB still owns the ladder for everything it prices - a row that states a tier for one of
## those is a reported duplicate, never a second owner (AGENTS.md §2).
##
## ONE TABLE, NOT TWO, and it is the reason both of the brawl's stand-ins are gone: before
## B5 the opening line-up lived in BalanceBrawl as a code fixture (STANDIN_POOL /
## STANDIN_ROWS) and the "what can I be given" list did not exist at all. Both are the same
## fact - "which pieces does the player's side consist of" - so they are one sheet with one
## owner, and adding a piece to the draw pool is adding a row.
##
## THE SHAPE OF A ROW IS THE ENEMY'S (data/brawl/formation_pieces.csv): {piece, col, row},
## integer cells of the 9x5 board. So a BrawlSetup carries the two sides as the same thing
## and the arena cannot tell which one is the player (BRAWL.md §6).
##
## THE PIECE IDS WERE THE BRAWL'S OWN (data/units/humans.csv, PieceDB) - until [B31] let a row
## name anything THE ARENA CAN BUILD: a human piece, a campaign plant, or a zombie, the same
## three doors the factory opens (Spawn.is_known, which is create_unit()'s first three tests asked
## without a board). An id none of them implements is a reported problem, never a silently empty
## cell - the arena would otherwise field one piece fewer and say nothing.
##
## [B31] AND THE SHEET IS THE ENEMY'S BODY COUNT TOO - but it is NOT WHO OWNS IT (user decision,
## 2026-10-08). This used to be the mode's ONLY list: 权重 > 0 was the membership test, while
## units.csv's `timed` was a SECOND, independent list - the one the classic 图鉴 reads. Two owners
## of one fact drifted the day 暖阳葵 arrived (its roster row was written, its `timed` cell was
## not), so the shop could sell what the 图鉴 could not show. The user kept one owner and it is not
## this sheet: `timed` says which units the mode has, and drawable_ids() below is that column read
## out. 能买 ⇔ 能出现在敌阵 still holds, because the shelf, the rewards and the random opponent
## generator all walk drawable_ids() - and 图鉴 walks the same column, so the three can no longer
## disagree.
##
## What a row of THIS sheet may still say about the draw is therefore RELATIVE ONLY: 权重 biases
## WHICH of the timed units a shelf shows, never WHETHER one is in the game. A row naming a unit
## that `timed` does not list is reported at boot (load_from_disk) - it names a member the mode
## says it has not.
##
## No self_check() block (the brawl is accepted by the user's own manual pass, docs/STATE.md
## §2): status_text() / problems() report at boot like FormationDB.

const PATH := "res://data/brawl/roster.csv"
## [B31] `scripts/core/spawn.gd` reaches its callers BY PATH (it carries no `class_name`, see its
## header: a global class is invisible to a headless run until the editor rescans), so this sheet
## asks the factory's own door through the same preload alias the seven other readers use.
const Spawn := preload("res://scripts/core/spawn.gd")

const COL_PIECE := "piece"
const COL_COL := "col"
const COL_ROW := "row"
const COL_WEIGHT := "权重"
## [B31] TWO OPTIONAL COLUMNS, both read as "the old sheet's answer" when a row says nothing: an
## absent 起始 means the piece DOES start with the session, an absent 档位 means the piece sheet
## prices it. So the twelve rows written before this batch keep meaning exactly what they did.
const COL_START := "起始"
const COL_TIER := "档位"
## The spelling a "not this" cell takes - the same 是/否 vocabulary the projectile and plant
## sheets write, so a designer never has to learn a second one. Any other cell (empty, 是, a
## stray word) means YES: the sheet's absence is the old answer.
const NO := "否"

static var _rows: Array = []               # [{piece, col, row, weight, starts, tier}], sheet order
static var _loaded := false
static var _tried := false
static var _error := ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	_tried = true
	_rows.clear()
	_problems.clear()
	_error = ""

	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		_loaded = false
		return false
	for entry in table.get("rows", []):
		var raw := entry as Dictionary
		var piece := UnitCsvManager.cell(raw, COL_PIECE)
		if piece == "":
			_problems.append("a roster row names no piece (skipped)")
			continue
		## An id none of the three rosters implements would be FIELD NOTHING: the arena builds what
		## the factory can build and prints nothing when it cannot, so a bout would simply be one
		## piece short. Said here, at boot, where the sheet can still be fixed (see the header).
		if not Spawn.is_known(piece):
			_problems.append("%s names '%s', which no roster implements (the arena would field nothing)"
				% [PATH.get_file(), piece])
		## [B31] THE ONE OWNER (see the header): `timed` in data/units/units.csv says which units the
		## mode has. A row naming a unit that column does not list is the drift that started this -
		## the shop drawing something the 图鉴 will not show - so it is said, not silently allowed to
		## make a second list. (The row still keeps its cell and its tier: the fix is the `timed`
		## cell, and this reader cannot write sheets.)
		if not UnitSheet.timed(piece):
			_problems.append("%s names '%s', which units.csv does not mark timed"
				% [PATH.get_file(), piece]
				+ " (the mode's list is that column; the 图鉴 will not show it)")
		var tier := maxi(0, UnitCsvManager.int_cell(raw, [COL_TIER], 0))
		if tier > 0 and PieceDB.has(piece):
			## Two owners for one number (AGENTS.md §2): the piece sheet prices its own rows, and
			## 档位 is only ever the answer for an id it does not have.
			_problems.append("%s states 档位 %d but %s already prices it (the piece sheet wins)"
				% [piece, tier, PieceDB.PATH.get_file()])
		_rows.append({
			"piece": piece,
			"col": UnitCsvManager.int_cell(raw, [COL_COL], -1),
			"row": UnitCsvManager.int_cell(raw, [COL_ROW], -1),
			"weight": maxi(0, UnitCsvManager.int_cell(raw, [COL_WEIGHT], 1)),
			"starts": UnitCsvManager.cell(raw, COL_START) != NO,
			"tier": tier,
		})
	_loaded = not _rows.is_empty()
	if not _loaded:
		_error = "no usable roster row"
	return _loaded


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


# ---------------------------------------------------------------- queries
static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func error_text() -> String:
	_ensure()
	return _error if _error != "" else "none"


static func count() -> int:
	_ensure()
	return _rows.size()


static func ids() -> Array[String]:
	## The piece ids in sheet order, duplicates kept: two rows naming one piece are two
	## pieces, and the formation page has to be able to tell them apart.
	_ensure()
	var out: Array[String] = []
	for entry in _rows:
		out.append(str((entry as Dictionary).get("piece", "")))
	return out


static func has(p_piece: String) -> bool:
	_ensure()
	for entry in _rows:
		if str((entry as Dictionary).get("piece", "")) == p_piece:
			return true
	return false


static func drawable_ids() -> Array[String]:
	## [B31] EVERY UNIT THE MODE HAS, in units.csv order: the ids whose merged `timed` cell is true.
	## This is NOT a list of this sheet's rows any more - it is the `timed` column read out (see the
	## header), which is why a unit needs no row here to be sellable, winnable or fieldable against
	## the player: captain and zombie are in the mode and were never in this sheet.
	## THE THREE READERS ARE THE POINT: BrawlSession's shelf and rewards, BrawlFormationGen's random
	## opponent, and the classic 图鉴's six race pages - all of them the same column now, so 能买 ⇔
	## 能出现在敌阵 and 图鉴里有这一格 are one fact with one owner, not three lists that can drift.
	## A unit this mode hands out but no roster rows is drawn at draw_weight()'s default; the sheet
	## still decides nothing about whether it exists.
	_ensure()
	var out: Array[String] = []
	for entry in UnitSheet.live().ids():
		var id := str(entry)
		if id != "" and UnitSheet.timed(id):
			out.append(id)
	return out


static func draw_weight(p_piece: String) -> int:
	## [B31] The weight a DRAW gives this unit: its row's 权重 when the sheet writes one, and the
	## SAME default an empty 权重 cell has (1) when it writes none - a unit with no row is a member
	## of the mode, not a member with weight zero. An explicit 0 still means "never drawn": that is
	## the one thing a row may say about a unit the mode has, and it is said in the sheet, not here.
	_ensure()
	return weight(p_piece) if has(p_piece) else 1


static func opening_pool() -> Array:
	## [B5] What a session starts with, in sheet order: [{piece, col, row}] with the negative
	## cells kept - the CALLER (BrawlSession) is what turns "beyond the deploy cap" into
	## reserve, because the cap is a session fact and this sheet is not.
	## [B31] A row marked 起始 = 否 is NOT here: the shelf and the rewards still draw it (the draw
	## reads the mode's `timed` pool and this sheet's 权重, not this column), but no session wakes up
	## holding it.
	_ensure()
	var out: Array = []
	for entry in _rows:
		var row := entry as Dictionary
		if not bool(row.get("starts", true)):
			continue
		out.append({
			"piece": str(row.get("piece", "")),
			"col": int(row.get("col", -1)),
			"row": int(row.get("row", -1)),
		})
	return out


static func weight(p_piece: String) -> int:
	## The draw weight of a piece (the first row naming it wins - a duplicate row is another
	## COPY of the piece, not another weight for it).
	_ensure()
	for entry in _rows:
		var row := entry as Dictionary
		if str(row.get("piece", "")) == p_piece:
			return int(row.get("weight", 0))
	return 0


static func cost_tier(p_piece: String) -> int:
	## [B31] THE SHOP'S TIER for a row of this sheet - the number the shelf multiplies by
	## BalanceBrawl.PIECE_PRICE_PER_COST. The piece sheet (PieceDB.cost) owns the 1-4 ladder for
	## every id it prices, and 档位 answers ONLY the ids it cannot: a campaign plant's 费用 is sun
	## on a lawn, not coins on a shelf. The floor is PieceDB's own maxi(1, ...) - a tier nobody
	## stated is the cheapest rung, never a free row.
	_ensure()
	if PieceDB.has(p_piece):
		return PieceDB.cost(p_piece)
	for entry in _rows:
		var row := entry as Dictionary
		if str(row.get("piece", "")) == p_piece:
			return maxi(1, int(row.get("tier", 0)))
	return 1


static func draw_piece(p_rng: RandomNumberGenerator, p_exclude: Array = []) -> String:
	## One of the mode's units (drawable_ids(): the `timed` column, [B31]) weighted by 权重 where a
	## row names it. A row written 0 is never drawn; when EVERY weight comes out 0 the weights are
	## dropped rather than answering "" - an empty reward or an empty shop shelf would be worse than
	## a uniform draw.
	##
	## p_exclude keeps a DRAW of several pieces from offering the same one twice: a shelf with
	## two identical champions on it wastes a slot the player can see. When everything is
	## excluded the exclusion is dropped, exactly as GearDB.draw() does - a shorter shelf or
	## a duplicate is better than an empty one.
	_ensure()
	var ids := drawable_ids()
	var pool: Array = []
	var total := 0
	for entry in ids:
		var piece := str(entry)
		if p_exclude.has(piece):
			continue
		var weight := draw_weight(piece)
		pool.append({"piece": piece, "weight": weight})
		total += weight
	if pool.is_empty():
		for entry in ids:
			var piece := str(entry)
			var weight := draw_weight(piece)
			pool.append({"piece": piece, "weight": weight})
			total += weight
	if pool.is_empty():
		return ""
	if total <= 0:
		return str((pool[p_rng.randi_range(0, pool.size() - 1)] as Dictionary).get("piece", ""))
	var roll := p_rng.randi_range(1, total)
	for entry in pool:
		roll -= int((entry as Dictionary).get("weight", 0))
		if roll <= 0:
			return str((entry as Dictionary).get("piece", ""))
	return str((pool[pool.size() - 1] as Dictionary).get("piece", ""))


# ---------------------------------------------------------------- reporting
static func status_text() -> String:
	_ensure()
	var placed := 0
	var draw_only := 0
	for entry in _rows:
		var row := entry as Dictionary
		if not bool(row.get("starts", true)):
			draw_only += 1
		if int(row.get("col", -1)) >= 0 and int(row.get("row", -1)) >= 0:
			placed += 1
	## [B31] "in reserve" counts the rows a session actually SEATS (opening_pool), not
	## `_rows.size() - placed`: a draw-only row belongs to neither half of that subtraction, and
	## reporting it as a bench piece would be exactly the lie this column exists to stop.
	## The POOL, though, is the `timed` column - so the line says how many units the mode has and how
	## many of them this sheet does not name at all (the honest way to show a unit that is in the
	## mode on the strength of units.csv alone: captain and zombie today, drawing at the default).
	var seats := opening_pool().size()
	var pool := drawable_ids()
	var unrowed := 0
	for entry in pool:
		if not has(str(entry)):
			unrowed += 1
	var line := ("roster: %d piece row(s), %d placed / %d in reserve, %d draw-only,"
		+ " %d timed unit(s) drawable (%d of them no row names)") \
		% [_rows.size(), placed, seats - placed, draw_only, pool.size(), unrowed]
	if _error != "":
		line += "  ERROR: " + _error
	for problem in _problems:
		line += "  [" + problem + "]"
	return line


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()
