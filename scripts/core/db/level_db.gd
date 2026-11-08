class_name LevelDB
extends RefCounted
## [P97] THE LEVEL SHEET - data/levels.csv is what says a level EXISTS.
##
## Before this, "the pack" was a FOLDER SCAN (LevelList played every Lawn_*.json it found).
## The folder still holds a level's CONTENT; the sheet decides that the level is real: it
## lists every level in the page's own order, a *.json nobody lists is not a level, and a
## row whose file is missing becomes a BROKEN row. The item sheet has worked this way since
## P88 - one list owns the roster, the files own the numbers.
##
## Columns (by NAME, never by index): `name` / `name_zh` are the display names (blank name =
## the id); `json` is the file that carries the level, and ITS BASENAME IS THE LEVEL'S ID
## (what a save file, a chest and `--battle=` key on), so a file is renamed only together
## with its row here; `difficulty` / `music` are checked here, and a blank cell means "no
## value" (the code default then applies). These four cells are the sheet's ONLY home.
## An unreadable sheet is NOT fatal (LevelList falls back to the folder scan) but
## self_check() still FAILs, like a missing item sheet.

const PATH := "res://data/levels.csv"

# ---------------------------------------------------------------- sheet columns
const COL_NAME := "name"
const COL_NAME_ZH := "name_zh"
const COL_JSON := "json"
const COL_DIFFICULTY := "difficulty"
const COL_MUSIC := "music"
const EXT := ".json"

static var _rows: Dictionary = {}          # id -> row (see _read_row)
static var _order: Array[String] = []      # the sheet's own order, top to bottom
static var _loaded := false
static var _tried := false                 # a failed load is not retried forever
static var _error := ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Read once (Game at boot, and on the R key); every accessor also calls _ensure().
	_tried = true
	_rows.clear()
	_order.clear()
	_problems.clear()
	_error = ""

	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		return false
	for entry in table.get("rows", []):
		_read_row(entry as Dictionary)
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable level row"
	return _loaded


static func _read_row(p_raw: Dictionary) -> String:
	## One row -> one level, or "" when the row cannot name one (the reason goes to
	## _problems and is printed by self_check()).
	var cell := UnitCsvManager.cell(p_raw, COL_JSON)
	var path := resolve_path(cell)
	var id := path.get_file().get_basename()
	if id == "":
		_problems.append("a row names no json file ('%s', skipped)" % cell)
		return ""
	if _rows.has(id):
		_problems.append("duplicate level id '%s' (kept the first row)" % id)
		return ""
	var shown := UnitCsvManager.cell(p_raw, COL_NAME)
	_rows[id] = {
		"name": shown if shown != "" else id,   # a level with no name still has its id
		"name_zh": UnitCsvManager.cell(p_raw, COL_NAME_ZH),
		"path": path,
		"difficulty": _known_key(UnitCsvManager.cell(p_raw, COL_DIFFICULTY), id),
		"music": _known_music(UnitCsvManager.cell(p_raw, COL_MUSIC), id),
	}
	_order.append(id)
	return id


static func _known_key(p_cell: String, p_id: String) -> String:
	## Checked HERE, because the sheet is what fills the field: an unknown word would otherwise
	## reach the battle unread. Unknown -> "" (the code default then applies).
	if p_cell == "" or Difficulty.has_key(p_cell.to_lower()):
		return p_cell.to_lower()
	_problems.append("'%s': unknown difficulty '%s' (ignored, the code default applies)" % [p_id, p_cell])
	return ""


static func _known_music(p_cell: String, p_id: String) -> String:
	## Same rule for the music cell; the ids are BalanceAudio.MUSIC_DEFS's keys.
	if p_cell == "" or BalanceAudio.is_music(p_cell):
		return p_cell
	_problems.append("'%s': unknown music '%s' (ignored, the default theme plays)" % [p_id, p_cell])
	return ""


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func resolve_path(p_cell: String) -> String:
	## The json cell -> a res:// path (bare name = inside Balance.LEVEL_DIR, .json added when
	## left out), the rule ItemDB.svg_path follows for its svg column.
	var text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(text):
		return ""
	if not text.ends_with(EXT):
		text += EXT
	if text.begins_with("res://"):
		return text
	return Balance.LEVEL_DIR + "/" + text


# ---------------------------------------------------------------- queries
static func is_loaded() -> bool:
	_ensure()
	return _loaded



static func error_text() -> String:
	_ensure()
	return _error if _error != "" else "none"



static func ids() -> Array[String]:
	## The sheet's own order: the level page lists the pack exactly as the designer wrote it,
	## so "where is my level" is answerable from the sheet itself.
	_ensure()
	return _order.duplicate()


static func has(p_id: String) -> bool:
	_ensure()
	return _rows.has(p_id)


static func row(p_id: String) -> Dictionary:
	_ensure()
	return _rows.get(p_id, {})


static func path_of(p_id: String) -> String:
	_ensure()
	return str(_rows.get(p_id, {}).get("path", ""))


static func id_for_path(p_path: String) -> String:
	## LevelData's own lookup, BY BASENAME (what the id is, and what a save file, a chest and
	## --battle= already hold). "" for a source no row names (the parser-contract probes).
	_ensure()
	var id := p_path.get_file().get_basename()
	return id if _rows.has(id) else ""


# ---------------------------------------------------------------- self check
static func self_check() -> bool:
	## [P97] The sheet's own two promises (LevelList prints this under its banner): the
	## COLUMNS it says it has, and one id per level whose json file is really there. What a
	## level CONTAINS is the file's business, audited by the [Levels] rows below this block.
	print("[Levels] --- the level sheet (%s) ---" % PATH)
	var table := UnitCsvManager.read_table(PATH)
	var headers: PackedStringArray = table.get("headers", PackedStringArray())
	var missing := PackedStringArray()
	for column in [COL_NAME, COL_NAME_ZH, COL_JSON, COL_DIFFICULTY, COL_MUSIC]:
		if not headers.has(str(column)):
			missing.append(str(column))
	var columns_ok: bool = bool(table.get("ok", false)) and missing.is_empty()
	if not columns_ok:
		print("[Levels] sheet: %d column(s), missing %s (%s) - the game is on the folder scan | FAIL"
			% [headers.size(), (", ".join(missing) if not missing.is_empty() else "none"), error_text()])
		return false
	var listed := ids()
	var gone := PackedStringArray()
	for id in listed:
		if not FileAccess.file_exists(path_of(id)):
			gone.append(id)
	var files_ok: bool = gone.is_empty() and not listed.is_empty()
	print("[Levels] sheet: %d column(s), %d row(s), %d naming a file that is not there%s = %s | %s"
		% [headers.size(), listed.size(), gone.size(),
		   ("  gone: " + ", ".join(gone)) if not gone.is_empty() else "",
		   str(files_ok), "OK" if files_ok else "FAIL"])
	for problem in _problems:
		print("[Levels] sheet: warning: " + problem)
	return files_ok