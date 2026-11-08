class_name FormationDB
extends RefCounted
## [B2b] THE ENEMY FORMATIONS - two sheets that together describe "a team to fight".
##
## Two files, one reader, the same division data/levels.csv + data/level/*.json already uses
## (P97): the ROSTER owns which formations exist and in what order, the CONTENT owns what
## stands in them.
##
##   data/brawl/formations.csv         one row per formation: name (the id) / name_zh / 金币
##   data/brawl/formation_pieces.csv   one row per POSSIBLE piece: formation / piece / col / row / 概率
##
## [B8+] 概率 IS THE DICE (O43: "敌阵概率出现可远程attack的单位"). Blank or 1 = the piece always
## stands there; anything below 1 means the row is rolled ONCE PER ROUND - the roster the offer
## card describes, the half the formation page previews and the side the arena fields are all the
## SAME roll, taken with the session's own seeded RNG (BrawlSession.roll_offers). So a formation is
## a list of things that MAY stand in it, and "which of them showed up" is decided when the round
## is dealt rather than when the fight starts.
##
## Columns are read BY NAME, never by index, and an unknown column is a complaint
## (UnitCsvManager), so a renamed header is loud instead of silent.
##
## THE PIECES ARE STAND-INS. data/units/humans.csv does not exist yet (the brawl's own roster
## is B5), so every row here names an EXISTING unit - a plant or a zombie - purely so the loop
## can be played and measured. This sheet is the first thing that changes when the human
## pieces land; nothing in the code depends on which ids appear.
##
## The STRENGTH a formation shows (D34) is NOT authored: it is the sum of its pieces' hit
## points read from the unit sheets, so the number on the offer card cannot drift from the
## pieces it stands for. 金币 IS authored - it is a reward, not a derived quantity.
##
## An unreadable sheet is not fatal (the arena falls back to an empty enemy side and says so),
## but it is never silent: load_from_disk() records why and status_text() prints it.

const ROSTER_PATH := "res://data/brawl/formations.csv"
const PIECES_PATH := "res://data/brawl/formation_pieces.csv"

const COL_NAME := "name"
const COL_NAME_ZH := "name_zh"
const COL_COINS := "金币"
const COL_FORMATION := "formation"
const COL_PIECE := "piece"
const COL_COL := "col"
const COL_ROW := "row"
## [B8+] How often this row is part of the line-up, 0..1. Blank = 1 (always).
const COL_CHANCE := "概率"

static var _rows: Dictionary = {}          # formation id -> raw row
static var _order: Array[String] = []      # the roster's own order, top to bottom
static var _pieces: Dictionary = {}        # formation id -> Array of {piece, col, row}
static var _loaded := false
static var _tried := false
static var _error := ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Read once (Game at boot; BrawlSetup.fixture() when a scene is opened on its own).
	## Every accessor also calls _ensure(), so an unread sheet answers empty instead of
	## crashing - the same failure policy every other sheet has.
	_tried = true
	_rows.clear()
	_order.clear()
	_pieces.clear()
	_problems.clear()
	_error = ""

	var table := UnitCsvManager.read_table(ROSTER_PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		return false
	for entry in table.get("rows", []):
		_read_row(entry as Dictionary)
	_read_pieces()
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable formation row"
	return _loaded


static func _read_row(p_raw: Dictionary) -> void:
	var id := UnitCsvManager.cell(p_raw, COL_NAME)
	if id == "":
		_problems.append("a roster row names no formation (skipped)")
		return
	if _rows.has(id):
		_problems.append("duplicate formation " + id + " (kept the first row)")
		return
	_rows[id] = p_raw
	_order.append(id)


static func _read_pieces() -> void:
	var table := UnitCsvManager.read_table(PIECES_PATH)
	if not bool(table.get("ok", false)):
		_problems.append("no piece sheet: " + str(table.get("error", "unknown error")))
		return
	for entry in table.get("rows", []):
		var raw := entry as Dictionary
		var formation := UnitCsvManager.cell(raw, COL_FORMATION)
		var piece := UnitCsvManager.cell(raw, COL_PIECE)
		if formation == "" or piece == "":
			_problems.append("a piece row names no formation or no piece (skipped)")
			continue
		if not _rows.has(formation):
			## An ORPHAN, on the same rule a race sheet obeys: a piece row cannot invent a
			## formation the roster never listed.
			_problems.append("piece row for unknown formation " + formation + " (skipped)")
			continue
		if not _pieces.has(formation):
			_pieces[formation] = []
		var col := UnitCsvManager.int_cell(raw, [COL_COL], -1)
		var row := UnitCsvManager.int_cell(raw, [COL_ROW], -1)
		## [B8+] float_of, not rate_of: 0.5 is "half the time", and the rate reader would take a
		## >1 value for a percentage. Clamped, because a chance above 1 or below 0 is a typo and
		## the only two sensible readings of a typo are "always" and "never".
		var chance := clampf(UnitCsvManager.float_of(UnitCsvManager.cell(raw, COL_CHANCE), 1.0,
			COL_CHANCE, raw), 0.0, 1.0)
		(_pieces[formation] as Array).append({"piece": piece, "col": col, "row": row,
			"chance": chance})


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


# ---------------------------------------------------------------- the roster
static func ids() -> Array[String]:
	_ensure()
	return _order.duplicate()


static func has(p_id: String) -> bool:
	_ensure()
	return _rows.has(p_id)


static func is_empty() -> bool:
	_ensure()
	return _order.is_empty()


static func display_name(p_id: String) -> String:
	## The name in the current language, the rule data/levels.csv already follows: the sheet
	## carries name_zh, the id stays English, and no code changes when a name does.
	_ensure()
	var row: Dictionary = _rows.get(p_id, {})
	if row.is_empty():
		return p_id
	var zh := UnitCsvManager.cell(row, COL_NAME_ZH)
	if zh != "" and Loc.prefer_zh():
		return zh
	return p_id


static func coins(p_id: String) -> int:
	## What a WIN against this formation pays (D4). Authored, unlike the strength below.
	_ensure()
	var row: Dictionary = _rows.get(p_id, {})
	if row.is_empty():
		return 0
	return maxi(0, UnitCsvManager.int_cell(row, [COL_COINS], 0))


# ---------------------------------------------------------------- the line-up
static func pieces(p_id: String) -> Array:
	## The deployed pieces, in sheet order: [{piece, col, row}]. col and row are INTEGER cells
	## of the 9x5 board - the arena converts them to a float centre, and a row the sheet does
	## not place (a negative cell) is skipped rather than guessed at.
	_ensure()
	var out: Array = []
	for entry in (_pieces.get(p_id, []) as Array):
		var row := entry as Dictionary
		if int(row.get("col", -1)) < 0 or int(row.get("row", -1)) < 0:
			continue
		out.append(row)
	return out


static func roll_pieces(p_id: String, p_rng: RandomNumberGenerator) -> Array:
	## [B8+] THE ROSTER THIS ROUND ACTUALLY FIELDS: every row of the formation whose 概率 passes,
	## in sheet order. Called ONCE per round per offer (BrawlSession.roll_offers), because the card
	## the player reads, the half the page previews and the side the arena builds must be one roll -
	## three separate rolls would be three different enemies.
	## A null rng means "no dice": every row with a real chance is kept, which is what a caller
	## with no session seed (the F6 fixture) wants.
	_ensure()
	var out: Array = []
	for entry in pieces(p_id):
		var row := entry as Dictionary
		var chance := clampf(float(row.get("chance", 1.0)), 0.0, 1.0)
		if chance >= 1.0 or (p_rng != null and p_rng.randf() < chance):
			out.append(row)
	return out


static func count_of(p_rows: Array) -> int:
	## How many pieces a (already rolled) roster holds - the offer card's "%d 只".
	return p_rows.size()


static func hp_total_of(p_rows: Array) -> int:
	## D34's strength figure over a ROLLED roster: the sum of the pieces' own hit points, read
	## from the unit sheets. Zero for a piece no sheet implements - the arena then refuses to build
	## that body, loudly.
	var total := 0
	for entry in p_rows:
		total += _hp_of(str((entry as Dictionary).get("piece", "")))
	return total


static func _hp_of(p_piece: String) -> int:
	## [B5] THREE rosters now: a formation may field a zombie, a plant or a human piece, and
	## the strength figure has to count whichever it is (a piece nothing implements answers 0,
	## which is how the offer card and the arena both end up saying so out loud).
	if ZombieDB.has(p_piece):
		return ZombieDB.hp(p_piece)
	if PieceDB.has(p_piece):
		return PieceDB.hp(p_piece)
	if Balance.has_plant(p_piece):
		return Balance.plant_max_hp(p_piece)
	return 0


static func power_total_of(p_rows: Array) -> int:
	## [B24] The ESTIMATE over a rolled roster (docs/NUMBERS.md §3's formula, Balance.estimate_power):
	## what the 战力 line on the almanac's formation page counts now, in place of the plain HP sum
	## it always mislabelled. Like hp_total_of() it is over the ROLL, not the authored list.
	## [B29] This door takes ROWS, not a formation id, which is why the GENERATOR can use it too:
	## BrawlFormationGen measures an opponent it assembled the same way the card measures a sheet's -
	## and a round's power floor is only meaningful if the number it is compared against is the number
	## the player is shown.
	var total := 0
	for entry in p_rows:
		total += _power_of(str((entry as Dictionary).get("piece", "")))
	return total


static func _power_of(p_piece: String) -> int:
	## [B24] One piece's term in that sum, and deliberately NOT a second strength rule: it is the
	## sheet row handed to Balance.unit_power(), i.e. the very number the unit page prints for the
	## same body. A formation's total is therefore the sum of its pieces' cells, which is what
	## makes the two pages checkable against each other. A piece no sheet knows answers 0, exactly
	## as _hp_of() does.
	return Balance.unit_power(p_piece)


# ---------------------------------------------------------------- reporting
static func status_text() -> String:
	_ensure()
	var line := "formations: %d row(s), %d piece row(s), %d rolled by 概率" % [
		_order.size(), _count_pieces(), _count_chance()]
	if _error != "":
		line += "  ERROR: " + _error
	for problem in _problems:
		line += "  [" + problem + "]"
	return line


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func _count_pieces() -> int:
	var n := 0
	for key in _pieces.keys():
		n += (_pieces[key] as Array).size()
	return n


static func _count_chance() -> int:
	## How many piece rows are NOT certain - the one number the manual pass wants when a
	## formation fields fewer bodies than its sheet lists.
	var n := 0
	for key in _pieces.keys():
		for entry in (_pieces[key] as Array):
			if float((entry as Dictionary).get("chance", 1.0)) < 1.0:
				n += 1
	return n
