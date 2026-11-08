class_name UnitSheet
extends RefCounted
## [P29] THE ONE ROSTER READER behind PlantDB and ZombieDB (OPTIMIZATIONS C3,
## the user's race design): the two databases used to copy the same loading,
## merge and query machinery twice; it lives here once.
##
## The sheet layout this reads:
##
##   data/units/units.csv    ONE ROW PER UNIT, and the only source of existence
##                           and order. It owns every column the two rosters
##                           share: 名称 (zh name) / name (id) / race / HP /
##                           天赋 / 技能 / 特殊机制 (+ their 英文 twins) / svg / tscn.
##   data/units/<root>.csv   the RACE sheet, holding the columns only that race
##                           has: plants.csv (技能效果 / 大招 / attack / 费用 / 卡片
##                           冷却 / 成长 ...), zombies.csv (护甲 / 移动 / attack /
##                           啃脑伤害). The zombie "attack" (bite) and the plant
##                           "attack" (skill damage) share a header but not a
##                           meaning - which is exactly why they stay family
##                           columns and units.csv carries no attack at all.
##   data/units/<sub>.csv    an optional SUB-RACE sheet: race "plants/pea" looks
##                           for pea.csv. Most families have no shared numbers
##                           yet, so the file simply does not exist - a missing
##                           layer is the normal state, counted in status_text()
##                           and never an error (user rule: 缺层跳过).
##
## The race column is a "/" path - "plants", "plants/pea", "zombies/normal". A
## unit's final value for a column comes from the DEEPEST sheet that states it
## (sub-race > race > units.csv); "—" / blank means "this layer says nothing,
## inherit". The identity columns (race and every id spelling) are read from
## units.csv ALONE, so a family sheet can never add or rename a unit: a row
## naming no unit is an ORPHAN - reported by the self-checks, never merged -
## and a typo cannot silently create a creature nobody designed.
##
## Every merged cell remembers where it came from ("plants.csv #7"), which
## cell_source() returns: the "字段地址" question - which file, which row do I
## edit to change this number - stays answerable after the split.
##
## Failure policy is UNCHANGED from the two readers this replaces: a missing or
## broken sheet is not fatal, the game keeps running on Balance's defaults, and
## PlantDB / ZombieDB self_check() print exactly what happened.

const ROSTER_PATH := "res://data/units/units.csv"
const FAMILY_DIR := "res://data/units/"

## The columns units.csv owns. Each DB reads the rest through get_flat().
const COL_ID := "name"
const COL_NAME := "名称"
const COL_RACE := "race"
const COL_HP := "HP"
const COL_TALENT := "天赋"
const COL_SKILL := "技能"
const COL_SPECIAL := "特殊机制"
const COL_SVG := "svg"
const COL_TSCN := "tscn"
## [P30-A4] The 技能代码 column: which row of data/units/skills.csv this unit
## loads as its action (its "行动序列"). units.csv owns the column like every
## shared one; a blank cell means "the unit script's own const SKILL is in
## charge" (Balance.plant_skill_code). Family layers may override it per unit.
const COL_SKILL_CODE := "技能代码"
## [P86] THE ATTACK COLUMN - the number a unit's action deals (a pea's damage, the
## sun a sunflower banks, a zombie's bite). It used to sit in BOTH race sheets, which
## made it the only column two sheets shared; it is a column the two rosters share, so
## units.csv owns it now (AGENTS.md §2: units.csv owns the shared columns).
const COL_ATTACK := "attack"
## [P86] THE RESERVED ROW. A row whose name column says `default` is not a unit: it is
## the fallback for every cell its layer's units leave blank. It may appear in units.csv
## once per race (the race column tells them apart; a blank race means RACE_NONE) and at
## most once in a race sheet, because a race sheet IS a race. It never enters the roster,
## the order, the roots or the orphan list - see _roster_defaults / _apply_defaults.
const RESERVED_DEFAULT := "default"
## [P86] The race of a row that names none (user rule: 没有 race = race 为无). It is a
## real race whose chain is just units.csv, so its units merge no family sheet.
const RACE_NONE := "无"
## [P30-B] The 大招代码 column, same rule one step further: it names the
## skills.csv ULTIMATE row this unit's charge bar resolves to. A blank cell
## means "the script's own const ULTIMATE (when it has one)"; a code the sheet
## does not know is not loaded at all (Balance.plant_ult_code).
const COL_ULTIMATE_CODE := "大招代码"
## [P105] THE rarity COLUMN (user design, P105): a unit's tier ("common" ...
## "mythic"), written on units.csv because both rosters share the file - a zombie
## row writes "—". What a tier IS (its colour, how much longer a downed plant of
## it stays down) is NOT here: that is one row per tier in data/rarity.csv, read
## by scripts/core/rarity_db.gd. This column is the only place a unit's tier is
## written; Balance.plant_rarity() reads it and PLANT_DEFS' own rarity is the
## fall-back for a row that leaves the cell blank.
const COL_RARITY := "rarity"
## [D75] THE TWO MODE COLUMNS (user design, 2026-10-05): is this unit introduced in that mode?
##   turned  the TURN mode - the campaign / adventure family, everyone's default
##   timed   the CLASSIC mode - the real-time family whose front door is 乱斗
## They are authored on units.csv like every other shared column, and a blank cell is answered
## by the race's reserved `default` row (see _apply_defaults), which is what lets "every plant
## is in the turn mode, no plant is in the classic one yet" be written ONCE instead of 90 times.
## The flags are read through turned() / timed() below - one door, so the almanac, a formation
## and whatever asks next cannot disagree about what "in this mode" means.
const COL_TURNED := "turned"
const COL_TIMED := "timed"
## [B11] 防御, and the ONE unit-facing number that is not an amount of anything: it is a
## DIVISOR in the damage formula (docs/NUMBERS.md §3). It sits in units.csv rather than in a
## race sheet because every faction has a body, and a blank cell is a real 0 - "this unit has
## no defence" is the answer for the whole roster today except 盾卫 (see the sheet).
const COL_DEFENCE := "defence"
## [B16] 朝向, written `face`: WHICH WAY THIS UNIT'S PICTURE LOOKS. It is a units.csv column
## for the same reason defence is one - every faction has a body, and the two drawings that
## differ from the family rule are one row each (雷角兽 is drawn facing left; the zombie race
## is the one family whose whole roster faces left, so its default row says so once).
## The spellings are a CLOSED LIST (FACE_RIGHT / FACE_LEFT below), and the reader is
## face_left() - one door, so the board, the almanac and whatever asks next cannot disagree
## about which way a body looks.
const COL_FACE := "face"
## What a `face` cell may say. `r` / `1` / `right` are the DEFAULT (right, the direction every
## drawing in this project was authored in) and `l` / `0` / `left` are the other one; -1 and
## the two Chinese characters are accepted because a designer types what they mean, and the
## faction sheets write their own columns in Chinese. A cell that is BLANK is not an error:
## it is answered by the race default row, exactly like every other shared column.
const FACE_RIGHT: Array[String] = ["r", "1", "right", "右"]
const FACE_LEFT: Array[String] = ["l", "0", "-1", "left", "左"]
## [B17] THE HEIGHT AXIS COLUMNS, authored in CELLS (docs/prompt/HEIGHT.md §6, D100/D99):
## z_height / z_thickness are the body's interval on the Z axis, body_width / body_depth /
## body_xoff / body_yoff are its footprint on the XY ground. All six sit in units.csv because
## all six are shared the way face and defence are - every faction has a body, and the columns
## are ASCII on purpose (the closed family this batch authored; the pixel-speaking 速度 column
## of the projectiles sheet is the historical other dialect and nothing new follows it).
## Every row is blank today and must stay blank until someone wants flight: a blank travels
## the default chain, lands on the caller's fall-back, and the caller's fall-back is the
## texture estimate - which is why the sheet answers floats, never "-1 sentinels", here.
const COL_Z_HEIGHT := "z_height"
const COL_Z_THICKNESS := "z_thickness"
const COL_BODY_WIDTH := "body_width"
const COL_BODY_DEPTH := "body_depth"
const COL_BODY_XOFF := "body_xoff"
const COL_BODY_YOFF := "body_yoff"
## [P113] THE TWO LABEL COLUMNS (user design, 2026-10-11): how a HUMAN classifies this unit,
## authored on units.csv like every other shared column so both rosters see the same tag.
##   range_type  this unit's reach as a person reads it: melee (only what it touches) or range
##   role        what it is FOR on the team, one of dps / tank / healer / support
## ⚠ THESE ARE LABELS, NOT BEHAVIOUR. They drive no fight. "is this unit ranged in combat?"
## stays owned by BrawlActor.is_ranged() (= it has a 射弹); "does it heal?" stays owned by the
## 治疗 column of projectiles.csv -> is_healer(). So a 远程特效 beam can be LABELLED range while
## is_ranged() answers false: the tag agrees with the distance a person reads, the engine keeps
## its own owner. One reader each (range_type() / role() below), the same single-door reason
## defence() and face_left() have, so the almanac and a formation cannot drift about a tag.
const COL_RANGE_TYPE := "range_type"
const COL_ROLE := "role"
## The two spellings are CLOSED LISTS. A cell that is BLANK is not an error (a row no sheet
## tags - today only the reserved `default` rows - reads as ""), and the almanac hides the line
## for a blank. A cell that is SPELLED but off the list is a complaint and reads as "" (loud and
## harmless), exactly the way face_left() treats a non-side.
const RANGE_TYPES: Array[String] = ["melee", "range"]
const ROLES: Array[String] = ["dps", "tank", "healer", "support"]
## [P114] THE TWO REAL-TIME BEHAVIOUR COLUMNS (user design, 2026-10-12). Unlike the P113 labels,
## these DO drive something - but ONLY inside the real-time engine (BrawlActor), never the turn
## mode, so a plants / zombies row that leaves them blank is bit-for-bit unchanged.
##   regen     HP recovered per second while the body is alive (an int; blank / absent = the code
##             fall-back 0). The one door that puts HP back is Unit.heal(); regen only feeds it,
##             so healing keeps that owner and never touches the 防御 damage formula in §3.
##   rolling   1 = this body's movement reads as a ROLL (its art spins about its centre as it
##             walks), the same switch shape turned() / timed() use (0 / blank = off).
## Today only 坚果墙 sets both, so it self-heals and rolls into the classic-mode line.
const COL_REGEN := "regen"
const COL_ROLLING := "rolling"

static var _live: UnitSheet = null


static func live() -> UnitSheet:
	## The one instance both DBs read. Built on first use, never in a static
	## initialiser, so class load order can not see a half-built sheet.
	if _live == null:
		_live = UnitSheet.new()
	return _live


var _units: Dictionary = {}       # id -> {"race": String, "flat": {}, "src": {}}
var _order: Array[String] = []    # units.csv order, top to bottom
var _roots: Dictionary = {}       # race root -> Array of ids, in the same order
var _loaded := false
var _tried := false
var _error := ""
var _problems: Array[String] = []
var _orphans: Array[String] = []  # "zombies.csv: some_id" family rows with no unit
var _families: Dictionary = {}    # family csv path -> read result + usage count
## [P86] race -> the reserved default row of units.csv, and how many cells the whole
## default chain filled (a boot line reports both, so "the default answered" is visible).
var _roster_defaults: Dictionary = {}
var _default_fills := 0


# ---------------------------------------------------------------- loading
func load_roster() -> bool:
	## Reads units.csv and every race layer it names. Called through
	## PlantDB/ZombieDB load_from_disk() at boot and on the R-key reload.
	_tried = true
	_units.clear()
	_order.clear()
	_roots.clear()
	_problems.clear()
	_orphans.clear()
	_families.clear()
	_roster_defaults.clear()
	_default_fills = 0
	_error = ""

	var table := UnitCsvManager.read_table(ROSTER_PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		_loaded = false
		return false
	## [P86] The roster header, kept so every merged row can answer "is this column
	## part of the sheet at all?" after the race layers have been folded in.
	var roster_headers: PackedStringArray = table.get("headers", PackedStringArray())

	var line := 0
	for entry in (table.get("rows", []) as Array):
		line += 1
		var raw: Dictionary = entry
		var id := UnitCsvManager.cell_any(raw, UnitCsvManager.ID_COLUMNS)
		if id == "":
			_problems.append("a units.csv row has no name (skipped)")
			continue
		var race := UnitCsvManager.cell(raw, COL_RACE)
		if race == "":
			## [P86] A row that names no race belongs to the race 无 (user rule), which is a
			## real race: its chain is units.csv alone, so it merges no family sheet.
			race = RACE_NONE
		if id == RESERVED_DEFAULT:
			## [P86] Not a unit: the roster's fallback for this race. Keyed by race, which is
			## what lets units.csv hold one per race. Judged here, so a second row for the
			## same race is a complaint instead of a silent "the last one wins".
			if _roster_defaults.has(race):
				_problems.append("units.csv: a second default row for race '%s' (kept the first)" % race)
				continue
			_roster_defaults[race] = {"raw": raw, "line": line}
			continue
		if _units.has(id):
			_problems.append("duplicate id '%s' in units.csv (kept the first row)" % id)
			continue
		var flat := {}
		var src := {}
		for key in raw.keys():
			var column := str(key)
			if UnitCsvManager.is_meta_key(column):
				continue           # [P86] bookkeeping, not a column
			flat[column] = str(raw[key])
			src[column] = "%s #%d" % [ROSTER_PATH.get_file(), line]
		## [P86] The merged row keeps the union of the headers of every sheet that fed
		## it (a race layer adds its own names in _apply_layer), so cell() can still tell
		## "this column is not in the sheet" from "this cell is blank" AFTER the merge -
		## which is the only place PlantDB/ZombieDB ever read a row.
		flat[UnitCsvManager.META_KEY] = {
			"sheet": ROSTER_PATH.get_file(),
			"headers": roster_headers.duplicate(),
			"sheets": [ROSTER_PATH.get_file()],
		}
		_units[id] = {"race": race, "flat": flat, "src": src}
		_order.append(id)

	# The race layers, shallow to deep: race "plants/pea" merges plants.csv and
	# then pea.csv over the units.csv base. Deeper layers win.
	for id in _order:
		var segments: PackedStringArray = str((_units[id] as Dictionary)["race"]).split("/")
		for seg in segments:
			_apply_layer(seg, id)
		## [P86] ...and then whatever is STILL blank is asked of the default chain.
		_apply_defaults(id)
		var root := str(segments[0])
		if not _roots.has(root):
			_roots[root] = []
		(_roots[root] as Array).append(id)

	# Family rows naming no unit: a typo in name, not a unit.
	for path in _families.keys():
		var fam: Dictionary = _families[path]
		if not bool(fam.get("ok", false)):
			# An ABSENT layer is the normal case (缺层跳过); a file that exists but
			# cannot be read is a broken sheet and must not pass unnoticed.
			if not bool(fam.get("missing", false)):
				_problems.append("%s: race sheet not usable (%s)" \
					% [str(path).get_file(), str(fam.get("error", "unknown error"))])
			continue
		for fid in (fam["rows"] as Dictionary).keys():
			if not _units.has(str(fid)):
				_orphans.append("%s: %s" % [str(path).get_file(), str(fid)])

	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable unit row"
	return _loaded


func ensure_loaded() -> void:
	if not _tried:
		load_roster()


func _family(p_segment: String) -> Dictionary:
	## One race layer's sheet, read once per load and remembered - including the
	## answer for "the file does not exist", which is the ordinary state of a
	## family that shares no numbers.
	var path := FAMILY_DIR + p_segment + ".csv"
	if _families.has(path):
		var seen: Dictionary = _families[path]
		seen["used"] = int(seen["used"]) + 1
		return seen
	var fam := {"ok": false, "error": "", "rows": {}, "used": 1, "missing": false,
		"headers": PackedStringArray(), "default": {}}
	var table := UnitCsvManager.read_table(path)
	if not bool(table.get("ok", false)):
		fam["error"] = str(table.get("error", "unknown error"))
		fam["missing"] = not FileAccess.file_exists(path)
		_families[path] = fam
		return fam
	## [P30-A5] BUGFIX: the success path used to forget this assignment, so every
	## readable race sheet was remembered with ok=false and an EMPTY error -
	## "plants.csv: race sheet not usable ()" in the boot log, 0 layers merged,
	## and every family column (attack/费用/护甲/移动) silently stayed at Balance's
	## fallback (peashooter FIRE 0). The read succeeded; say so.
	fam["ok"] = true
	fam["headers"] = table.get("headers", PackedStringArray())
	var line := 0
	for entry in (table.get("rows", []) as Array):
		line += 1
		var raw: Dictionary = entry
		var fid := UnitCsvManager.cell_any(raw, UnitCsvManager.ID_COLUMNS)
		if fid == "":
			_problems.append("%s: a row has no name (ignored)" % path.get_file())
			continue
		if fid == RESERVED_DEFAULT:
			## [P86] The layer's fallback row, kept OUT of fam["rows"]: a race sheet holds
			## no race column, so it may carry exactly one, and it must not be mistaken for
			## a unit (which would list it as an orphan - it names nobody) nor merged as one.
			if not (fam["default"] as Dictionary).is_empty():
				_problems.append("%s: a second default row (kept the first)" % path.get_file())
				continue
			fam["default"] = {"raw": raw, "line": line}
			continue
		if (fam["rows"] as Dictionary).has(fid):
			_problems.append("%s: duplicate id '%s' (kept the first row)" % [path.get_file(), fid])
			continue
		fam["rows"][fid] = {"raw": raw, "line": line}
	_families[path] = fam
	return fam


func _apply_layer(p_segment: String, p_id: String) -> void:
	## Merges one race layer over one unit: a column this layer states (non-blank)
	## replaces the shallower value, a blank one says nothing and the value the
	## layer above gave stays. Identity columns are units.csv's alone (see header).
	if p_segment == RACE_NONE:
		return                 # [P86] no sheet can ever be named after the race 无
	var fam := _family(p_segment)
	if not bool(fam.get("ok", false)):
		return
	var found: Variant = (fam["rows"] as Dictionary).get(p_id)
	if found == null:
		return
	var entry: Dictionary = found
	var raw: Dictionary = entry["raw"]
	var unit: Dictionary = _units[p_id]
	var flat: Dictionary = unit["flat"]
	var src: Dictionary = unit["src"]
	var mark := "%s #%d" % [(FAMILY_DIR + p_segment + ".csv").get_file(), int(entry["line"])]
	for key in raw.keys():
		var column := str(key)
		if UnitCsvManager.is_meta_key(column):
			continue           # [P86] bookkeeping, not a column
		if column == COL_RACE or UnitCsvManager.ID_COLUMNS.has(column):
			continue
		if UnitCsvManager.cell(raw, column) == "":
			continue
		flat[column] = str(raw[key])
		src[column] = mark
	## [P86] This layer's header names join the row's set (and its file, the sheet list),
	## so a column only THIS sheet declares stays readable after the merge - and a name
	## nobody declares is still a complaint rather than a silent blank.
	var meta: Dictionary = flat.get(UnitCsvManager.META_KEY, {})
	if not meta.has("headers"):
		meta["headers"] = PackedStringArray()
	var headers: PackedStringArray = meta["headers"]
	for h in (fam["headers"] as PackedStringArray):
		if not headers.has(h):
			headers.append(h)
	meta["headers"] = headers
	var sheets: Array = meta.get("sheets", [])
	var fam_file: String = (FAMILY_DIR + p_segment + ".csv").get_file()
	if not sheets.has(fam_file):
		sheets.append(fam_file)
	meta["sheets"] = sheets
	meta["sheet"] = ", ".join(PackedStringArray(sheets))
	flat[UnitCsvManager.META_KEY] = meta


func _apply_defaults(p_id: String) -> void:
	## [P86] THE DEFAULT CHAIN (user design, 2026-09-25). Whatever the unit's own rows left
	## blank is asked of the DEFAULTS, deepest layer first:
	##   pea.csv's default > plants.csv's default > units.csv's default for this race
	##                              (race "plants/pea" -> "plants" -> "无")
	## A layer's default covers THE COLUMNS THAT LAYER DECLARES (its own header), which is
	## what keeps the layers from ever arguing about the same number: units.csv's default
	## answers HP/attack, plants.csv's answers 费用/卡片冷却/成长. A default may be partial or
	## absent - the code fall-backs behind the reader (Balance / the DBs) stay in charge of
	## the rest, so a sheet that says nothing still boots (user rule: 默认只是为了兜底).
	## Every filled cell keeps its provenance in `src`, so cell_source() answers "plants.csv
	## default #12" instead of leaving "why is this 300?" to a search.
	var unit: Dictionary = _units[p_id]
	var flat: Dictionary = unit["flat"]
	var src: Dictionary = unit["src"]
	var race := str(unit["race"])
	var segments: PackedStringArray = race.split("/")
	for i in range(segments.size() - 1, -1, -1):
		var seg := str(segments[i])
		if seg == RACE_NONE:
			continue
		var fam := _family(seg)
		if not bool(fam.get("ok", false)):
			continue
		_default_fills += _fill_from_default(fam["default"], flat, src,
			"%s default" % (FAMILY_DIR + seg + ".csv").get_file())
	## The roster's own defaults are keyed by race, so they are looked up along the same
	## chain, ending at the race 无 (the row that named no race).
	var lookup := race
	while true:
		if _roster_defaults.has(lookup):
			_default_fills += _fill_from_default(_roster_defaults[lookup], flat, src,
				"%s default (%s)" % [ROSTER_PATH.get_file(), lookup])
			break
		var cut := lookup.rfind("/")
		if cut >= 0:
			lookup = lookup.substr(0, cut)
			continue
		if lookup != RACE_NONE:
			lookup = RACE_NONE
			continue
		break


func _fill_from_default(p_entry: Dictionary, p_flat: Dictionary, p_src: Dictionary,
		p_mark: String) -> int:
	## One layer's default row over one unit: fills the cells that are still blank, and
	## only the columns that row's own sheet declares. Returns how many it filled.
	if p_entry.is_empty():
		return 0
	var raw: Dictionary = p_entry["raw"]
	var line := int(p_entry.get("line", 0))
	var filled := 0
	for key in raw.keys():
		var column := str(key)
		if UnitCsvManager.is_meta_key(column) or column == COL_RACE \
				or UnitCsvManager.ID_COLUMNS.has(column):
			continue           # identity is the unit's own; a default must not name one
		## [D80] THE ONE QUESTION THE WHOLE DIALECT HANGS ON (user rule, 2026-10-05): the chain
		## answers a cell that WANTS the default - an empty one, or one that spells `default` - and
		## nothing else. A cell holding a value has spoken; a cell holding `—` / `none` has spoken
		## TOO ("this row has no such attribute"), and the default row must not overrule it.
		var own := UnitCsvManager.clean(str(p_flat.get(column, "")))
		if p_flat.has(column) and not UnitCsvManager.wants_default(own):
			continue
		var value := UnitCsvManager.cell(raw, column)
		if value == "":
			continue
		p_flat[column] = value
		p_src[column] = "%s #%d" % [p_mark, line]
		filled += 1
	return filled


# ---------------------------------------------------------------- queries
func is_loaded() -> bool:
	ensure_loaded()
	return _loaded


func error_text() -> String:
	ensure_loaded()
	return _error if _error != "" else "none"


func problems() -> Array[String]:
	## Structural complaints about the ROSTER (a row without id / race, a family
	## row nobody names). Both DBs fold this into their own problems list.
	ensure_loaded()
	return _problems.duplicate()


func orphans() -> Array[String]:
	## "zombies.csv: some_id" - a family row whose name matches no unit.
	ensure_loaded()
	return _orphans.duplicate()


func ids() -> Array[String]:
	## Every unit, units.csv order. The per-race view is ids_for().
	ensure_loaded()
	return _order.duplicate()


func has(p_id: String) -> bool:
	ensure_loaded()
	return _units.has(p_id)


func count() -> int:
	ensure_loaded()
	return _order.size()


func get_race(p_id: String) -> String:
	ensure_loaded()
	return str((_units.get(p_id, {}) as Dictionary).get("race", ""))


func get_root(p_id: String) -> String:
	var segments: PackedStringArray = get_race(p_id).split("/")
	return str(segments[0]) if not segments.is_empty() else ""


func ids_for(p_root: String) -> Array[String]:
	## The roster of one race root, in units.csv order - what PlantDB.ids() and
	## ZombieDB.ids() list (roots "plants" and "zombies").
	ensure_loaded()
	var out: Array[String] = []
	for id in (_roots.get(p_root, []) as Array):
		out.append(str(id))
	return out


func get_flat(p_id: String) -> Dictionary:
	## The merged raw cells of one unit (column -> text, "—" still to be cleaned
	## by UnitCsvManager.cell), deepest race layer winning. The dictionary is the
	## sheet's own: read it, do not write it.
	ensure_loaded()
	return (_units.get(p_id, {}) as Dictionary).get("flat", {})


func cell(p_id: String, p_column: String) -> String:
	## One merged cell, already cleaned ("—" / blank -> "").
	return UnitCsvManager.cell(get_flat(p_id), p_column)


func cell_source(p_id: String, p_column: String) -> String:
	## Where the merged value came from: "plants.csv #7", "units.csv #3", or ""
	## when no sheet states that column.
	ensure_loaded()
	return str(((_units.get(p_id, {}) as Dictionary).get("src", {}) as Dictionary).get(p_column, ""))


static func turned(p_id: String) -> bool:
	## Is this unit part of the TURN mode's roster? False for a unit no sheet knows - a mode
	## asking about a stranger is not an error.
	return flag_on(live().cell(p_id, COL_TURNED))


static func timed(p_id: String) -> bool:
	## ...and the CLASSIC (real-time) twin of it. Both read the merged cell, so the race
	## default row answers for every unit that leaves the column blank.
	return flag_on(live().cell(p_id, COL_TIMED))


static func defence(p_id: String) -> int:
	## [B11] A UNIT'S 防御: the page's own number, read the way every other merged cell is (the
	## race default row answers a blank, the code's fall-back is 0). A stranger no sheet knows
	## answers 0 as well - a caller asking about an id that is not there is not an error.
	##
	## A DOOR ON THE SHEET rather than on the three facades, exactly like turned() / timed()
	## above: defence is a SHARED column (units.csv), so one reader is enough and the three
	## rosters cannot drift about it.
	return maxi(0, UnitCsvManager.int_cell(live().get_flat(p_id), [COL_DEFENCE], 0))


static func face_left(p_id: String, p_fallback: bool = false) -> bool:
	## [B16] WHICH WAY THIS UNIT'S PICTURE LOOKS: true when its row says the art was drawn
	## facing LEFT. Read the way every merged cell is - the row's own `face` cell wins, a blank
	## one has already been answered by the race default row (see _apply_defaults), and the
	## caller hands in the last resort for a row that says nothing at all (`p_fallback`),
	## because only the family knows what its own drawings do: a zombie looks left, everything
	## else looks right.
	##
	## A STRANGER ID (a unit no sheet knows) answers the fall-back too - asking about an id that
	## is not there is not an error, the same rule defence() follows. A cell that is SPELLED but
	## is not a side is a complaint and reads as right: a typo must be loud and harmless.
	var row := live().get_flat(p_id)
	var text := UnitCsvManager.cell(row, COL_FACE).strip_edges().to_lower()
	if text == "":
		return p_fallback
	if FACE_LEFT.has(text):
		return true
	if FACE_RIGHT.has(text):
		return false
	UnitCsvManager.note_complaint("%s = \"%s\" is not a side (%s) -> read as facing right"
		% [COL_FACE, text, UnitCsvManager.row_label(row)])
	return false


## [P113] THE TWO LABEL DOORS - one reader each for the two tag columns, opened on the SHEET
## exactly like defence() and face_left() do (the columns are shared, so one door is enough and
## the three facades cannot drift about a tag). Both return the WORD, matched against a closed
## list; a blank answers "" and a misspelling is a boot complaint that also answers "". The
## almanac shows the line only for a non-empty tag, so a row nobody tagged prints no air. These
## are DISPLAY labels - see the COL_RANGE_TYPE / COL_ROLE notes above for why they never touch
## is_ranged() / is_healer() / the three-shape dispatch.

static func range_type(p_id: String) -> String:
	## melee / range as a person reads the unit's reach, or "" when its row says nothing.
	var row := live().get_flat(p_id)
	var text := UnitCsvManager.cell(row, COL_RANGE_TYPE).strip_edges().to_lower()
	if text == "":
		return ""
	if RANGE_TYPES.has(text):
		return text
	UnitCsvManager.note_complaint("%s = \"%s\" is not a range type (%s) -> read as blank (%s)"
		% [COL_RANGE_TYPE, text, ", ".join(RANGE_TYPES), UnitCsvManager.row_label(row)])
	return ""


static func role(p_id: String) -> String:
	## dps / tank / healer / support as a person reads the unit's job, or "" when nothing is said.
	var row := live().get_flat(p_id)
	var text := UnitCsvManager.cell(row, COL_ROLE).strip_edges().to_lower()
	if text == "":
		return ""
	if ROLES.has(text):
		return text
	UnitCsvManager.note_complaint("%s = \"%s\" is not a role (%s) -> read as blank (%s)"
		% [COL_ROLE, text, ", ".join(ROLES), UnitCsvManager.row_label(row)])
	return ""


static func regen(p_id: String) -> int:
	## [P114] HP recovered per SECOND, read like defence(): the row's own cell wins, a blank one
	## falls to the code's 0 (so most units never heal). Only BrawlActor consumes this, and only
	## through Unit.heal() - the one door that puts HP back, which already caps at max_hp and
	## no-ops a fallen body. A stranger no sheet knows answers 0 too.
	return maxi(0, UnitCsvManager.int_cell(live().get_flat(p_id), [COL_REGEN], 0))


static func rolling(p_id: String) -> bool:
	## [P114] Does this body ROLL while it moves? The switch reads the same way timed() / turned()
	## read theirs (0 / blank = off, the race default row answers a blank). Real-time only: the
	## walk in BrawlActor turns it into Unit.set_roll() each step; a body nobody flips never spins.
	return flag_on(live().cell(p_id, COL_ROLLING))


## [B17] THE HEIGHT DOORS - six readers for the six height-axis columns (docs/prompt/HEIGHT.md
## §7). They open on the SHEET exactly like defence() and face_left() do: the columns are
## shared, so one reader each is enough and the three facades cannot drift about them. Every
## door answers the way every merged cell does - the row's own cell wins, a blank one has been
## answered by the race default row already, and `p_fallback` is the last resort for a row
## that says nothing at all (the caller hands in the texture estimate; a stranger id gets the
## same answer - asking about an id no sheet knows is not an error).

static func z_height(p_id: String) -> float:
	## The feet's authored height above the ground, in cells. Blank answers 0.0 - "everyone
	## stands on the grass" is this column's regression promise (D100 / spec §7).
	return UnitCsvManager.float_cell(live().get_flat(p_id), [COL_Z_HEIGHT], 0.0)


static func z_thickness(p_id: String, p_fallback: float) -> float:
	## The body's height along the axis, in cells. The caller's fall-back is the measured ink
	## height / the art design baseline (D112's ruler) - [B37] without the old 1.0-cell floor, so
	## this door is the ONLY thing a stated row has to beat. Balance.UNIT_Z_THICKNESS_CELLS is what
	## answers when there is no picture to measure (no file at all), not a minimum any more.
	return UnitCsvManager.float_cell(live().get_flat(p_id), [COL_Z_THICKNESS], p_fallback)


static func body_width(p_id: String, p_fallback: float) -> float:
	## The footprint's authored width in cells; blank asks the texture (px / 128), the caller's
	## fall-back. Stored this batch, WIRED into no XY gate yet (spec §7: Phase 1 keeps the
	## existing reach maths, frame-identical).
	return UnitCsvManager.float_cell(live().get_flat(p_id), [COL_BODY_WIDTH], p_fallback)


static func body_depth(p_id: String, p_fallback: float) -> float:
	## ...and its depth. The fall-back the family hands in is body_width / 2 (spec §2.1.1).
	return UnitCsvManager.float_cell(live().get_flat(p_id), [COL_BODY_DEPTH], p_fallback)


static func body_xoff(p_id: String) -> float:
	## Footprint offset along the art's own x, cells; blank answers 0.0 (the art's bottom-centre
	## IS the footprint's centre until somebody says otherwise).
	return UnitCsvManager.float_cell(live().get_flat(p_id), [COL_BODY_XOFF], 0.0)


static func body_yoff(p_id: String) -> float:
	## ...and along Godot's y-down second axis, cells.
	return UnitCsvManager.float_cell(live().get_flat(p_id), [COL_BODY_YOFF], 0.0)


static func flag_on(p_value: String) -> bool:
	## What counts as "on" in a mode column: anything a designer would write for yes. A blank
	## cell ("—" already cleaned to "") is OFF - and it is the ordinary state of a row whose
	## race default said nothing either, not a mistake to report.
	var text := p_value.strip_edges().to_lower()
	if text == "":
		return false
	## [B11b] A NUMBER is a flag too, and it has to be read BY VALUE: a sheet re-exported with
	## floats spells the old `0` as `0.0`, and the string tests below see "0.0" as neither ""
	## nor "0" - i.e. ON. 0 / 0.0 are OFF, anything else numeric is ON (the column is 0/1).
	if text.is_valid_float():
		return not is_zero_approx(text.to_float())
	return text != "no" and text != "false"


func mode_count(p_column: String) -> int:
	## How many units one mode column flags. Reported on the roster's boot line, because
	## "the column is spelled right but nothing is flagged" is the failure this catches.
	## An INSTANCE method like the rest of the roster's own readouts (status_text reads it),
	## while turned()/timed() below are static because a caller asks about ONE unit.
	ensure_loaded()
	var total := 0
	for id in _order:
		if flag_on(cell(str(id), p_column)):
			total += 1
	return total


func status_text() -> String:
	## The roster's own boot line - printed by Game between the [Data] lines of
	## the two DBs that share it.
	ensure_loaded()
	if not _loaded:
		return "units: roster NOT loaded (%s)" % error_text()
	var applied := 0
	var absent := 0
	var absent_names := PackedStringArray()
	for path in _families.keys():
		var fam: Dictionary = _families[path]
		if bool(fam.get("ok", false)):
			applied += 1
		elif bool(fam.get("missing", false)):
			absent += 1
			absent_names.append(str(path).get_file())
	## [P86] The default rows are reported here rather than folded into the row count: a
	## reader of this line must be able to tell "the sheet states it" from "a default
	## answered" - that is the whole point of keeping the chain traceable.
	var defaults := 0
	for path in _families.keys():
		var fam: Dictionary = _families[path]
		if not (fam.get("default", {}) as Dictionary).is_empty():
			defaults += 1
	## [D75] ...and how many units each MODE column flags: the two numbers a designer checks
	## right after editing turned / timed, on the one line that already reports this sheet.
	## [B11] ...and how many rows carry a DEFENCE, which is the one number a designer wants right
	## after filling that column in: "0" means the column is spelled right and nothing was read
	## from it, exactly like the two mode counts above.
	var defended := 0
	for id in _order:
		if defence(str(id)) > 0:
			defended += 1
	## [B16] ...and how many rows resolve to "this picture looks LEFT". Walking the whole
	## roster here is deliberate: it is also what turns a misspelled `face` cell into a boot
	## complaint (face_left notes one) instead of a silence nobody notices until that unit
	## happens to be spawned. The fall-back is false, i.e. a row that says nothing counts as
	## right - the count is "how many rows SAY left", which is the number to check after
	## editing that column.
	var facing_left := 0
	for id in _order:
		if face_left(str(id)):
			facing_left += 1
	## [P113] ...and the two LABEL tallies. Walking the whole roster here is deliberate, the same
	## reason face_left() above is: it turns a misspelled `range_type` / `role` cell into a boot
	## complaint (the readers note one) instead of a silence. _order already excludes the reserved
	## `default` rows (they never enter the roster), so these counts are "how many UNITS carry a
	## tag" - the number to check right after filling the two columns in. melee + range and
	## dps/tank/healer/support should each sum to the unit count; a tag left blank lands in neither.
	var melee := 0
	var ranged := 0
	var r_dps := 0
	var r_tank := 0
	var r_healer := 0
	var r_support := 0
	var with_regen := 0
	var with_roll := 0
	for id in _order:
		match range_type(str(id)):
			"melee": melee += 1
			"range": ranged += 1
			_: pass
		match role(str(id)):
			"dps": r_dps += 1
			"tank": r_tank += 1
			"healer": r_healer += 1
			"support": r_support += 1
			_: pass
		if regen(str(id)) > 0:
			with_regen += 1
		if rolling(str(id)):
			with_roll += 1
	return "units: %d row(s) from %s, %d race sheet(s) merged, %d absent layer(s)%s, %d orphan row(s), %d default row(s) (%d roster + %d race) filling %d cell(s) | turned %d, timed %d, defence %d, face left %d | range melee/range %d/%d, role dps/tank/healer/support %d/%d/%d/%d | regen %d, rolling %d" \
		% [_order.size(), ROSTER_PATH.get_file(), applied,
		   absent, (" [" + ", ".join(absent_names) + "]") if absent > 0 else "",
		   _orphans.size(), defaults + _roster_defaults.size(),
		   _roster_defaults.size(), defaults, _default_fills,
		   mode_count(COL_TURNED), mode_count(COL_TIMED), defended, facing_left,
		   melee, ranged, r_dps, r_tank, r_healer, r_support, with_regen, with_roll]
