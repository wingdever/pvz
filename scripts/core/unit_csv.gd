class_name UnitCsvManager
extends RefCounted
## [P26] The reader behind PlantDB and ZombieDB: ONE tab separated data sheet in,
## a list of header-keyed rows out.
##
## Why a shared class instead of two copies: the two sheets are read exactly the
## same way (BOM stripping, the "no value" mark, integer cells) and the plant and
## zombie tables must not drift apart in how they treat a cell.
##
## The sheets are TAB separated (not comma), because their prose fields are full of
## Chinese commas. The column names are Chinese and are matched BY NAME, never by
## index: adding a column in the middle of a sheet, or reordering the existing ones,
## therefore cannot silently shift a value into the wrong field.
##
## A cell that the designer left blank is written as an em dash ("—"), which is the
## convention both sheets already used. clean()/cell() turn it back into "" so the
## rest of the game only ever sees a real value or nothing.

const DELIMITER := "\t"
## What an empty cell looks like in the sheets (em dash, hyphen, en dash).
const BLANKS: Array[String] = ["—", "-", "–", "n/a", "N/A"]
## The suffix that turns a Chinese prose column into its English twin: "技能" ->
## "技能英文". A sheet may omit the twin; cell_en() then falls back to the Chinese
## text, and self_check() reports how often that happened instead of hiding it.
const EN_SUFFIX := "英文"
## [P86] The key every row of `read_table()` carries, holding the sheet it came from and
## the column names its header declared. It exists for ONE guard (see `_check_column`):
## until now a column name the code asked for but the header did not have answered ""
## exactly like a blank cell, so a renamed or misspelled column was a silent 0 - and
## the sheets are the only owner of these numbers (AGENTS.md §2). The key never reaches
## a value: every merge skips it (see UnitSheet), and it is not a legal column name.
const META_KEY := "__meta__"
## [P29][C3] The columns a row may use as its id, tried in order. This candidate
## list used to be spelled out in PlantDB, ZombieDB AND ItemDB - three copies of
## one rule; the sheets that read it are UnitSheet and ItemDB.
## [P86] "name" is the canonical spelling every sheet writes now; the older ones stay in
## the list, so a sheet (or a test fixture) that still says 英文名称 keeps reading.
const ID_COLUMNS := ["name", "英文名称", "ID", "英文"]

## [P57] (OPTIMIZATIONS D2) One list for everything the READER knows but the game
## silently ignored: a cell that is spelled yet is not the number the column asks
## for, and a column name that appears twice in one header row. Both used to be
## indistinguishable from "the designer left it blank" - `int_of` handed back the
## default and a duplicated header let the right-hand column win, in silence. Since
## the sheets are the only source of unit numbers (AGENTS §2), a silent fallback is a
## number nobody chose, so the fallback now comes with a complaint, and every sheet's
## own self_check refuses to be green while complaints are pending.
##
## A Dictionary, not an Array: `stats()` re-reads a row every time a unit is asked for
## its numbers, so the same broken cell is seen many times a session. Deduplicating by
## the complaint text means one broken cell = one line, whatever reads it.
static var _complaints: Dictionary = {}

## How many complaint lines one block prints before it says "the rest are not shown".
## A whole column of prose where a number belongs is one mistake, not thirty prints.
const COMPLAINT_LIMIT := 12


static func note_complaint(p_text: String) -> void:
	## The only writer of the list - see the header above for why it exists.
	_complaints[p_text] = true


static func complaint_count() -> int:
	return _complaints.size()


static func clear_complaints() -> void:
	## For a caller that audits its own sheets and must not inherit what somebody else
	## read first. The self-checks below never call it: `report_complaints()` does.
	_complaints.clear()


static func report_complaints(p_prefix: String) -> bool:
	## Print what has been complained about since the last call, then forget it, so the
	## next sheet only reports its own. True when there was nothing to report - the
	## caller folds that into its own `ok`, which is what turns a bad cell into a red
	## `[Plants]` / `[Zombies]` / `[Skills]` / `[Items]` block.
	if _complaints.is_empty():
		return true
	var keys: Array = _complaints.keys()
	keys.sort()
	var shown := 0
	for key in keys:
		if shown >= COMPLAINT_LIMIT:
			break
		print("%s sheet complaint: %s" % [p_prefix, str(key)])
		shown += 1
	if keys.size() > shown:
		print("%s sheet complaint: ... %d more not listed (cap: %d)"
			% [p_prefix, keys.size() - shown, COMPLAINT_LIMIT])
	## One tail line, phrased for BOTH kinds of complaint (the numeric ones already end
	## with the default they fell back to, and a duplicated header has no default to
	## name). Three lines of prose per block was P56's shape; this channel can fire in
	## four blocks, so it keeps to the one sentence that is true either way.
	print("%s           -> a complaint is a cell the sheet spells but the reader cannot"
		% p_prefix)
	print("%s            use as written: the sheet is the source of these numbers, so fix"
		% p_prefix)
	print("%s            the cell - do not raise the default to match it." % p_prefix)
	_complaints.clear()
	return false


static func read_table(p_path: String) -> Dictionary:
	## {ok: bool, error: String, path: String, headers: PackedStringArray, rows: Array}
	## Every failure is a REPORTED result, never an error: the caller decides whether
	## a missing sheet is fatal (it never is - the game keeps its built-in fallbacks).
	var out := {
		"ok": false,
		"error": "",
		"path": p_path,
		"headers": PackedStringArray(),
		"rows": [],
	}
	if not FileAccess.file_exists(p_path):
		out["error"] = "file not found: " + p_path
		return out
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		out["error"] = "cannot open %s (error %d)" % [p_path, FileAccess.get_open_error()]
		return out

	var headers := PackedStringArray()
	var rows: Array = []
	while not f.eof_reached():
		var line := f.get_csv_line(DELIMITER)
		if line.size() == 0:
			break              # an empty array means the file ended
		if line.size() == 1 and clean(line[0]) == "":
			continue           # a blank line between rows is not a row
		if headers.is_empty():
			## [P57] The row is turned into a Dictionary keyed BY NAME, so a name used
			## twice is not two columns: the second one overwrites the first and the
			## first becomes unreadable - silently, with the value still sitting in the
			## file looking perfectly healthy. Matching by name is the deliberate rule
			## (the header may be reordered without shifting a value into the wrong
			## field), so the fix is to notice the collision, not to start reading by
			## index. Say who wins.
			var seen := {}
			for i in line.size():
				var column := clean(line[i])
				if column != "" and seen.has(column):
					note_complaint("%s: the column \"%s\" is spelled twice (its right-hand copy wins, the left one is unreadable)"
						% [p_path.get_file(), column])
				seen[column] = true
				headers.append(column)
			if headers.size() < 2 or str(headers[0]) == "":
				f.close()
				out["error"] = "the header row is not usable (first cell empty)"
				return out
			continue
		var row: Dictionary = {}
		for i in line.size():
			if i >= headers.size():
				break          # a trailing extra column is ignored, not an error
			row[str(headers[i])] = clean(line[i])
		if row.is_empty():
			continue
		## [P86] The row remembers the sheet and the header it was read against, so
		## `cell()` can tell "this column is not in the sheet" from "this cell is blank".
		row[META_KEY] = {"sheet": p_path.get_file(), "headers": headers}
		rows.append(row)
	f.close()

	if headers.is_empty():
		out["error"] = "no header row (empty file?)"
		return out
	if rows.is_empty():
		out["error"] = "no data rows"
		return out
	out["ok"] = true
	out["headers"] = headers
	out["rows"] = rows
	return out


# ---------------------------------------------------------------- cells
static func clean(p_text: String) -> String:
	## A UTF-8 BOM in front of the first header would make that column unfindable, so
	## it is stripped here rather than in every caller.
	return p_text.replace("\uFEFF", "").strip_edges()


static func is_blank(p_text: String) -> bool:
	## [P80] The ONE question "did this cell say nothing?" - asked by BLANKS, so a sheet
	## may spell the same absence five ways (`\u2014 - \u2013 n/a N/A`) and every reader agrees.
	## Until now the three art-path rules spelled it as `text == "" or text == "\u2014"`,
	## which is a NARROWER rule: a cell written `-` was blank to `cell()` and was a
	## filename to `svg_path()`, so the same sheet answered two different questions
	## depending on which column the caller was reading. Takes CLEANED text (see clean()).
	return p_text == "" or BLANKS.has(p_text)


## [D80] THE TWO WAYS A CELL CAN BE EMPTY, AND THE ONE QUESTION THAT TELLS THEM APART
## (user rule, 2026-10-05):
##
##   EMPTY ("")      this row says nothing here  -> the DEFAULT CHAIN answers it
##   `—` or `none`   this row HAS no such thing  -> the chain stops here, and every reader
##                                                 still sees an empty cell
##
## Both read as "" wherever a VALUE is wanted (cell() folds either into ""), so not one reader
## had to learn a new word - the whole difference lives in UnitSheet._fill_from_default. `-`,
## `–`, `n/a` are the same "no value" spellings `—` always was (see BLANKS); `none` is the ASCII
## way to write the same thing, for a cell where a real em dash is awkward to type.
##
## WHY IT MATTERS: a race's `default` row answers every cell that asks for it, which is what lets
## one `默认人类` row say "humans cost 2" for the whole family. Without the absent token a row had
## no way to say "no THANKS, I really have none" - a path column has no `0` to write - which is
## how six human pieces ended up wearing their race's single body scene (BRAWL.md D80).
##
## [D80] ...and the word `default` IN A VALUE CELL is the fourth spelling: it asks for the default
## value explicitly ("按默认值取值"), the same answer an empty cell gets. It exists so a row can
## SAY it inherits instead of leaving a hole nobody can read, and it is what makes the four
## spellings a closed set a designer can pick from on purpose. (In the NAME column the same word
## is the reserved ROW - that check runs before any of this, on the id, and is untouched.)
const ABSENT_TOKEN := "none"
const DEFAULT_TOKEN := "default"


static func is_absent(p_text: String) -> bool:
	## "This row has no such attribute" (the chain must not answer it). Takes CLEANED text.
	return is_blank(p_text) or p_text.to_lower() == ABSENT_TOKEN


static func is_default(p_text: String) -> bool:
	## "Take the default value" written out. Takes CLEANED text.
	return p_text.to_lower() == DEFAULT_TOKEN


static func is_unset(p_text: String) -> bool:
	## "This row says nothing here" - a bare hole in the sheet. Takes CLEANED text.
	return p_text == ""


static func wants_default(p_text: String) -> bool:
	## THE ONE QUESTION THE DEFAULT CHAIN ASKS (user rule, 2026-10-05): does this cell want the
	## default value? An empty cell does, and so does one that spells `default`; a cell holding a
	## value does not, and neither does one that says "there is none" (`—` / `none`). Takes
	## CLEANED text - which is why every caller cleans the raw cell before asking.
	return is_unset(p_text) or is_default(p_text)


static func is_meta_key(p_key: String) -> bool:
	## [P86] True for the one bookkeeping key a row carries (see META_KEY). Every pass
	## that treats a row's keys as columns must skip it.
	return p_key == META_KEY


static func _cell_raw(p_row: Dictionary, p_header: String) -> String:
	## The value of one column, with the "nothing here" marks turned into "", and
	## WITHOUT the missing-column guard: the "try these spellings in turn" readers
	## (cell_hit / cell_any / row_label) ask for names a sheet is allowed not to use,
	## so a complaint from them would be about the caller, not about the sheet.
	var text := clean(str(p_row.get(p_header, "")))
	return "" if is_blank(text) else text


static func _check_column(p_row: Dictionary, p_header: String) -> void:
	## [P86] THE MISSING-COLUMN GUARD: a name the caller asks for that this sheet's
	## header does not declare is a complaint, never a silent blank. This is what makes
	## a column rename or a column moved between sheets survivable: without it the read
	## answers "" and, with blanks meaning "0 / not set", the number nobody wrote wins.
	##
	## A missing ENGLISH TWIN is exempt on purpose: the sheets are allowed to omit
	## "…英文" and fall back to the Chinese prose (see has_en / the missing-twin count).
	## A row that carries no meta (built by hand in a probe, say) is not checked.
	if p_header.ends_with(EN_SUFFIX):
		return
	var meta: Variant = p_row.get(META_KEY)
	if meta == null or not (meta is Dictionary):
		return
	var sheet: String = str((meta as Dictionary).get("sheet", "a sheet"))
	var headers: Variant = (meta as Dictionary).get("headers")
	if headers == null or (headers as PackedStringArray).has(p_header):
		return
	note_complaint("%s: no column \"%s\" in the header (read as blank)" % [sheet, p_header])


static func cell(p_row: Dictionary, p_header: String) -> String:
	## The value of one column, with BOTH kinds of empty turned into "": `—` / `-` / `n/a` come
	## out of _cell_raw already, and [D80]'s ASCII `none` is folded in here. To everyone asking
	## for a VALUE, "this row has no such attribute" and "this row says nothing" are the same
	## answer - they differ in exactly one place, UnitSheet._fill_from_default.
	##
	## The ID readers go through _cell_raw instead (see cell_hit's quiet path), so a unit that
	## happens to be NAMED `none` is still a unit - the word is only special as a value.
	_check_column(p_row, p_header)
	var text := _cell_raw(p_row, p_header)
	## Both "ask the default" and "there is none" reach a reader as an empty cell: the first one is
	## empty because the chain answers it (or the code fall-back does), the second because there is
	## nothing to answer WITH. Only a value survives this function as itself.
	var lower := text.to_lower()
	return "" if lower == ABSENT_TOKEN or lower == DEFAULT_TOKEN else text


static func cell_en(p_row: Dictionary, p_header: String) -> String:
	## The English twin of a prose column ("技能" -> "技能英文"). Missing or blank
	## falls back to the Chinese text, so the English UI shows the designer's own
	## words instead of an empty line.
	var text := cell(p_row, p_header + EN_SUFFIX)
	return text if text != "" else cell(p_row, p_header)


static func has_en(p_row: Dictionary, p_header: String) -> bool:
	return cell(p_row, p_header + EN_SUFFIX) != ""


static func cell_hit(p_row: Dictionary, p_headers: Array, p_quiet: bool = false) -> Dictionary:
	## [P57] The same search `cell_any()` does, but it keeps the NAME that answered:
	## a complaint nobody can trace back to a column is worthless, and by name is the
	## only way this reader ever addresses a cell. `{"column": "", "text": ""}` when
	## none of the candidates is there - which is "the sheet says nothing", not damage.
	## [P86] `p_quiet` is for the spelling-list readers (cell_any / row_label): they ask
	## for names a sheet is ALLOWED not to use ("英文名称" / "ID" / "英文"), so they must
	## not raise the missing-column complaint. A caller naming ONE column (int_cell /
	## rate_cell, every number the game reads) is checked - that is what turns a renamed
	## column from a silent 0 into a boot complaint.
	for h in p_headers:
		var text := _cell_raw(p_row, str(h)) if p_quiet else cell(p_row, str(h))
		if text != "":
			return {"column": str(h), "text": text}
	return {"column": "", "text": ""}


static func cell_any(p_row: Dictionary, p_headers: Array) -> String:
	## The first non-empty of several candidate column names - the sheets spell a few
	## things two ways ("英文名称" / "ID"), and a sheet that uses either one works.
	return str(cell_hit(p_row, p_headers, true)["text"])


static func row_label(p_row: Dictionary) -> String:
	## How a complaint names the row it came from. The id column, because that is what
	## a designer searches for in the sheet; the file and line number would be better
	## but they belong to `UnitSheet`, and this reader must not reach up into it.
	var id := cell_any(p_row, ID_COLUMNS)
	return id if id != "" else "a row naming no unit"


static func int_of(p_text: String, p_default: int = 0,
	p_column: String = "", p_row: Dictionary = {}) -> int:
	## The sheets write a number or a dash; a dash means "not specified", which is
	## what the default is for (0 for a stat, -1 for "unlimited").
	## [P57] A cell that IS spelled but will not parse is the third case, and it used
	## to be indistinguishable from the second one: `hp = 三百` handed back the default
	## exactly like `hp = —` did, so the battle ran on `balance.gd` while the sheet
	## looked like the source. Same answer, one complaint.
	var text := clean(p_text)
	if is_blank(text) or is_default(text):     # [D80] `default` asks for the default value
		return p_default
	if text.is_valid_int():
		return text.to_int()
	## [B11b] A SPREADSHEET'S INT IS STILL AN INT, and this is the batch that learned it the hard
	## way: a sheet re-exported by Excel / Numbers / any table tool spells 300 as "300.0", and
	## this reader used to refuse it, hand back the default 0 and complain. On units.csv's HP and
	## attack cells that is the loudest failure the dialect can produce - every unit in the game
	## came out with 1 hit point (DBs floor a 0 at maxi(1, ...)) and every blow with 1 point of
	## damage, i.e. "one hit kills and the number is always 1". A WHOLE-number float is the same
	## number written the other way, so it is read as itself; a value with a real fraction
	## (300.5) is still a complaint, because these columns are whole numbers by design.
	if text.is_valid_float():
		var value := text.to_float()
		if is_equal_approx(value, roundf(value)):
			return int(roundf(value))
	note_complaint("%s = \"%s\" is not a whole number (%s) -> read as the default %d"
		% [p_column if p_column != "" else "a column", text,
		   row_label(p_row) if not p_row.is_empty() else "caller passed no row", p_default])
	return p_default


static func int_cell(p_row: Dictionary, p_headers: Array, p_default: int = 0) -> int:
	## The column that answered travels with the value, so the complaint can name it.
	var hit := cell_hit(p_row, p_headers)
	return int_of(str(hit["text"]), p_default, str(hit["column"]), p_row)


static func float_of(p_text: String, p_default: float = 0.0,
		p_column: String = "", p_row: Dictionary = {}) -> float:
	## [B5] A plain DECIMAL cell ("0.75" cells of reach, "1.3" seconds between two attacks).
	## It exists because rate_of() below reads a >1 value as a PERCENTAGE - right for a growth
	## cell, wrong for a distance: attack距离 = 3 would silently become 0.03 cells. Same complaint
	## discipline as int_of(): a spelled cell that will not parse is a complaint, never a
	## silent default, because the sheets are the only source of these numbers.
	var text := clean(p_text)
	if is_blank(text) or is_default(text):     # [D80] `default` asks for the default value
		return p_default
	if not text.is_valid_float():
		note_complaint("%s = \"%s\" is not a number (%s) -> read as the default %s"
			% [p_column if p_column != "" else "a column", text,
			   row_label(p_row) if not p_row.is_empty() else "caller passed no row",
			   str(p_default)])
		return p_default
	return text.to_float()


static func float_cell(p_row: Dictionary, p_headers: Array, p_default: float = 0.0) -> float:
	## The column that answered travels with the value, so the complaint can name it.
	var hit := cell_hit(p_row, p_headers)
	return float_of(str(hit["text"]), p_default, str(hit["column"]), p_row)


static func rate_of(p_text: String, p_default: float = 0.0,
	p_column: String = "", p_row: Dictionary = {}) -> float:
	## A growth / boost cell ("10%" per level, "+50%" from a potion). Both spellings are
	## accepted because a designer may write either:
	##   "10%"  or  "10"   -> 0.10   (a % sign, or a number above 1, is a PERCENTAGE)
	##   "0.1"  or  "1"    -> 0.10 / 1.0  (anything else is a fraction; 1 = +100%)
	##   "—"    or  ""     -> the default, i.e. "the code value stays in charge"
	## [P57] and, as above, anything else -> the default WITH a complaint.
	var text := clean(p_text)
	if is_blank(text) or is_default(text):     # [D80] `default` asks for the default value
		return p_default
	var percent := text.ends_with("%")
	if percent:
		text = text.substr(0, text.length() - 1).strip_edges()
	if not text.is_valid_float():
		note_complaint("%s = \"%s\" is not a rate (%s) -> read as the default %s"
			% [p_column if p_column != "" else "a column", clean(p_text),
			   row_label(p_row) if not p_row.is_empty() else "caller passed no row",
			   str(p_default)])
		return p_default
	var value := text.to_float()
	if percent or value > 1.0:
		value /= 100.0
	return maxf(value, 0.0)


static func rate_cell(p_row: Dictionary, p_headers: Array, p_default: float = 0.0) -> float:
	var hit := cell_hit(p_row, p_headers)
	return rate_of(str(hit["text"]), p_default, str(hit["column"]), p_row)
