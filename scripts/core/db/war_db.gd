class_name WarDB
extends RefCounted
## [W2] THE WAR MAPS AND THEIR WAVES - two sheets that together describe "a battlefield and
## the reinforcements that march onto it".
##
## Two files, one reader, the same division FormationDB ([B2b]) established: the MAP sheet
## owns which arenas exist and how big they are, the WAVE sheet owns what steps out and when.
##
##   data/war/maps.csv    one row per map: map / name / name_zh / rows / cols / deploy_cols
##   data/war/waves.csv   one row per spawn: map / wave / delay / piece / col / row / 概率
##
## THE TIMELINE IS ABSOLUTE. `delay` counts seconds from the moment the battle starts, not
## from the previous wave (a "delay after the last wave" would make one mistyped early row
## shift every later one - an absolute clock cannot drift). `wave` is a LABEL, not a gate:
## rows sharing it form the group the HUD counts ("第 3 / 5 波"), and the engine never waits
## for a wave to die before the next delay arrives - that is what makes the line PUSH.
##
## 概率 IS THE DICE, copied row-for-row from formation_pieces.csv: blank or 1 always steps
## out, anything below 1 is rolled once per match with the session's own seeded RNG, so the
## HUD's unit count, the plan the scheduler holds and the bodies on the field are one roll.
##
## [W8] THE SHEET OUTLIVED THE SCHEDULER, and one paragraph of this header is now history:
## the war runs in ROUNDS, and the timed line-up the paragraphs above describe is what the
## arena stopped doing. What the rows still OWN, through new doors: `wave` labels the rounds
## (the distinct labels are the round list, `wave_starts` their counts), and every row of a
## map is one weighted entry of `piece_pool` (概率 = the weight) that WarWaveGen draws each
## round's composition from. `delay`/`col`/`row` keep their old validation - the rows stay
## well-formed history of where the old timeline dropped them - but no live body reads them
## for a position anymore: the roller picks the cells, the page previews them.
##
## Columns are read BY NAME, never by index, and an unknown column is a complaint
## (UnitCsvManager), so a renamed header is loud instead of silent.
##
## VALIDATION happens at READ time, on the same doors every other sheet uses: a piece must be
## summonable (Spawn.is_known - the [P86] rule), col/row must land inside THAT map's board,
## the map column must name a map the roster listed (the orphan policy RaceDB and FormationDB
## both obey). A bad row is SKIPPED and counted in problems(), never guessed at - an arena
## missing two reinforcements is playable, an arena fielding a body nothing implements is not.
##
## An unreadable sheet is not fatal (the war page says there is nothing to fight and stays
## put), but it is never silent: load_from_disk() records why and status_text() prints it.

const MAPS_PATH := "res://data/war/maps.csv"
const WAVES_PATH := "res://data/war/waves.csv"
## [W2] spawn.gd has NO class_name by design (P87: "by path"), so the summonable-door is
## borrowed the same way every other caller borrows it - a file-scoped preload alias.
const Spawn := preload("res://scripts/core/spawn.gd")

const COL_MAP := "map"
const COL_NAME := "name"
const COL_NAME_ZH := "name_zh"
const COL_ROWS := "rows"
const COL_COLS := "cols"
const COL_DEPLOY := "deploy_cols"

const COL_WAVE := "wave"
const COL_DELAY := "delay"
const COL_PIECE := "piece"
const COL_COL := "col"
const COL_ROW := "row"
## Same column name, same 0..1 semantics as data/brawl/formation_pieces.csv.
const COL_CHANCE := "概率"

static var _maps: Dictionary = {}          # map id -> raw maps.csv row
static var _order: Array[String] = []      # the map sheet's own order, top to bottom
static var _waves: Dictionary = {}         # map id -> Array of plan rows, sorted
static var _loaded := false
static var _tried := false
static var _error := ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Read once (Game at boot; a scene opened on its own calls it through _ensure()).
	## Every accessor also calls _ensure(), so an unread sheet answers empty instead of
	## crashing - the same failure policy every other sheet has.
	_tried = true
	_maps.clear()
	_order.clear()
	_waves.clear()
	_problems.clear()
	_error = ""

	var table := UnitCsvManager.read_table(MAPS_PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		return false
	for entry in table.get("rows", []):
		_read_map(entry as Dictionary)
	_read_waves()
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable map row"
	return _loaded


static func _read_map(p_raw: Dictionary) -> void:
	## [W6-fix] ID columns read through cell_any (the quiet ID-door, same one row_label
	## uses), never through cell(): the VALUE reader folds the reserved spellings - and the
	## first map is NAMED `default`, which is DEFAULT_TOKEN. As a value-reader door that id
	## came back "" and every row looked like "names no map". unit_csv.gd:286's rule, this
	## time with the map that happens to be NAMED default proving it.
	var id := UnitCsvManager.cell_any(p_raw, [COL_MAP])
	if id == "":
		_problems.append("a map row names no map (skipped)")
		return
	if _maps.has(id):
		_problems.append("duplicate map " + id + " (kept the first row)")
		return
	var rows := UnitCsvManager.int_cell(p_raw, [COL_ROWS], -1)
	var cols := UnitCsvManager.int_cell(p_raw, [COL_COLS], -1)
	var deploy := UnitCsvManager.int_cell(p_raw, [COL_DEPLOY], -1)
	if rows <= 0 or cols <= 0:
		_problems.append("map " + id + " has no usable rows/cols (skipped)")
		return
	if deploy < 0 or deploy > cols:
		_problems.append("map " + id + " deploy_cols outside the board (skipped)")
		return
	_maps[id] = p_raw
	_order.append(id)


static func _read_waves() -> void:
	var table := UnitCsvManager.read_table(WAVES_PATH)
	if not bool(table.get("ok", false)):
		_problems.append("no wave sheet: " + str(table.get("error", "unknown error")))
		return
	for entry in table.get("rows", []):
		var raw := entry as Dictionary
		## ID doors, quiet like _read_map's: a map NAMED default and a piece NAMED none are
		## still a map and a piece (unit_csv.gd:286's rule for every id reader).
		var map_id := UnitCsvManager.cell_any(raw, [COL_MAP])
		var piece := UnitCsvManager.cell_any(raw, [COL_PIECE])
		if map_id == "" or piece == "":
			_problems.append("a wave row names no map or no piece (skipped)")
			continue
		if not _maps.has(map_id):
			## An ORPHAN, on the same rule a piece row cannot invent a formation.
			_problems.append("wave row for unknown map " + map_id + " (skipped)")
			continue
		if not Spawn.is_known(piece):
			_problems.append("wave row " + map_id + " fields unimplemented piece "
				+ piece + " (skipped)")
			continue
		var wave := UnitCsvManager.int_cell(raw, [COL_WAVE], -1)
		var delay := UnitCsvManager.float_of(UnitCsvManager.cell(raw, COL_DELAY), -1.0,
			COL_DELAY, raw)
		var col := UnitCsvManager.int_cell(raw, [COL_COL], -1)
		var row := UnitCsvManager.int_cell(raw, [COL_ROW], -1)
		if wave < 0 or col < 0 or row < 0:
			_problems.append("wave row " + map_id + "/" + piece
				+ " has a negative cell (skipped)")
			continue
		if delay < 0.0:
			## Blank also lands here: float_of answers the -1.0 default, and a wave row
			## without a time is not a spawn the scheduler could ever place on the clock.
			_problems.append("wave row " + map_id + "/" + piece
				+ " has no usable delay (skipped)")
			continue
		if col >= cols_of(map_id) or row >= rows_of(map_id):
			_problems.append("wave row " + map_id + "/" + piece
				+ " lands outside the " + str(cols_of(map_id)) + "x" + str(rows_of(map_id))
				+ " board (skipped)")
			continue
		## Clamped exactly like FormationDB: a chance above 1 or below 0 is a typo and the
		## only two sensible readings of a typo are "always" and "never".
		var chance := clampf(UnitCsvManager.float_of(UnitCsvManager.cell(raw, COL_CHANCE),
			1.0, COL_CHANCE, raw), 0.0, 1.0)
		if not _waves.has(map_id):
			_waves[map_id] = []
		var seq := (_waves[map_id] as Array).size()
		(_waves[map_id] as Array).append({"wave": wave, "delay": delay, "piece": piece,
			"col": col, "row": row, "chance": chance, "seq": seq})
	for key in _waves.keys():
		(_waves[key] as Array).sort_custom(_row_before)


static func _row_before(p_a: Dictionary, p_b: Dictionary) -> bool:
	## The timeline order: by wave label, then by the absolute delay inside it, then by the
	## row's own sheet position. A stable third key so two rows sharing a delay keep the
	## order the author wrote.
	if int(p_a.get("wave", 0)) != int(p_b.get("wave", 0)):
		return int(p_a.get("wave", 0)) < int(p_b.get("wave", 0))
	if float(p_a.get("delay", 0.0)) != float(p_b.get("delay", 0.0)):
		return float(p_a.get("delay", 0.0)) < float(p_b.get("delay", 0.0))
	return int(p_a.get("seq", 0)) < int(p_b.get("seq", 0))


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


# ---------------------------------------------------------------- the maps
static func map_ids() -> Array[String]:
	_ensure()
	return _order.duplicate()


static func has_map(p_id: String) -> bool:
	_ensure()
	return _maps.has(p_id)


static func is_empty() -> bool:
	_ensure()
	return _order.is_empty()


static func _row(p_id: String) -> Dictionary:
	_ensure()
	return _maps.get(p_id, {})


static func display_name(p_id: String) -> String:
	## The name in the current language, the rule FormationDB and data/levels.csv already
	## follow: the sheet carries name_zh, the id stays English.
	var row := _row(p_id)
	if row.is_empty():
		return p_id
	var zh := UnitCsvManager.cell(row, COL_NAME_ZH)
	if zh != "" and Loc.prefer_zh():
		return zh
	var name := UnitCsvManager.cell(row, COL_NAME)
	return name if name != "" else p_id


static func rows_of(p_id: String) -> int:
	var row := _row(p_id)
	return UnitCsvManager.int_cell(row, [COL_ROWS], -1) if not row.is_empty() else -1


static func cols_of(p_id: String) -> int:
	var row := _row(p_id)
	return UnitCsvManager.int_cell(row, [COL_COLS], -1) if not row.is_empty() else -1


static func deploy_cols_of(p_id: String) -> int:
	var row := _row(p_id)
	return UnitCsvManager.int_cell(row, [COL_DEPLOY], -1) if not row.is_empty() else -1


# ---------------------------------------------------------------- the timeline
static func spawn_plan(p_id: String) -> Array:
	## The match's whole enemy timeline, ALREADY SORTED: [{wave, delay, piece, col, row,
	## chance}] with integer col/row cells of that map's board. The scheduler walks this with
	## one index; the sheet order never has to be trusted again.
	_ensure()
	return (_waves.get(p_id, []) as Array).duplicate()


static func wave_starts(p_id: String) -> Array:
	## One entry per DISTINCT wave label, in timeline order: [{wave, delay, count}]. The HUD
	## reads "第 x/N 波" and the next-wave countdown straight off this - N is its size, the
	## current wave's start is the first entry whose delay has passed. `count` is the
	## AUTHORED count (before 概率 rolls), which is what the label promises before the dice.
	var out: Array = []
	var last := -1
	for entry in spawn_plan(p_id):
		var row := entry as Dictionary
		var wave := int(row.get("wave", 0))
		if wave != last:
			out.append({"wave": wave, "delay": float(row.get("delay", 0.0)), "count": 1})
			last = wave
		else:
			var tail: Dictionary = out[out.size() - 1]
			tail["count"] = int(tail["count"]) + 1
	return out


static func unit_count(p_id: String) -> int:
	_ensure()
	return (_waves.get(p_id, []) as Array).size()


static func piece_pool(p_id: String) -> Array:
	## [W8] THE ROLLER'S POOL, for the round generator: one {piece, weight} entry per
	## authored row of this map, in timeline order (a seed walks the same cumulative line
	## every time). A body the sheet lists twice is drawn twice as often, and 概率 is the
	## weight - the dice that used to ROLL A ROW OUT became the bias the draw respects, so
	## warm_sunflower at 0.3 stays the rare body the author meant.
	_ensure()
	var out: Array = []
	for entry in (_waves.get(p_id, []) as Array):
		var row := entry as Dictionary
		out.append({"piece": str(row.get("piece", "")),
			"weight": float(row.get("chance", 1.0))})
	return out


# ---------------------------------------------------------------- reporting
static func status_text() -> String:
	_ensure()
	var line := "war: %d map(s), %d wave row(s), %d rolled by 概率" % [
		_order.size(), _count_rows(), _count_chance()]
	if _error != "":
		line += "  ERROR: " + _error
	for problem in _problems:
		line += "  [" + problem + "]"
	return line


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func _count_rows() -> int:
	var n := 0
	for key in _waves.keys():
		n += (_waves[key] as Array).size()
	return n


static func _count_chance() -> int:
	## How many wave rows are NOT certain - the one number the manual pass wants when a match
	## fields fewer bodies than the sheet lists.
	var n := 0
	for key in _waves.keys():
		for entry in (_waves[key] as Array):
			if float((entry as Dictionary).get("chance", 1.0)) < 1.0:
				n += 1
	return n
