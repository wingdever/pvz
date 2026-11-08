class_name RaceDB
extends RefCounted
## [D75] THE RACE SHEET - one row per race, and what that race IS by default.
##
##   data/units/races.csv    race | 默认单位
##
## "The default plant is the peashooter" is a fact about a RACE, not about a unit: units.csv's
## reserved `default` rows answer COLUMN VALUES (HP, attack...) for every row of a race, and they
## must not name a unit (a default that named one would be identity, which _fill_from_default
## refuses on purpose). So the answer lives here, in a sheet that has exactly one job.
##
## WHO READS IT: the classic-mode almanac lists each race's default unit and says so (BRAWL.md
## §10.3). That is the thin end of it - "which unit stands for this race" is the question a
## formation, a reward card or a preview asks the day one of them names a race instead of a unit.
##
## THE race COLUMN IS A PATH, exactly like units.csv's: "plants", "plants/pea". default_unit()
## walks UP the path, so a sub-race only writes a row when it disagrees with its parent, and a
## race nobody wrote a row for simply has no default (callers fall back - 缺层跳过 is the normal
## state of this project's tables).
##
## No self_check() block (AGENTS §2 forbids writing test scripts): the reader reports through
## status_text() / problems() like GearDB and FormationDB, and every complaint it can raise is a
## row that names nothing, names a unit twice, or names a unit that does not exist.

const PATH := "res://data/units/races.csv"

const COL_RACE := "race"
const COL_UNIT := "默认单位"

static var _rows: Dictionary = {}          # race -> the unit id its row names
static var _order: Array[String] = []      # sheet order, top to bottom
static var _loaded := false
static var _tried := false
static var _error := ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Read once, by Game at boot (and lazily by anyone who asks first).
	_tried = true
	_rows.clear()
	_order.clear()
	_problems.clear()
	_error = ""

	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		_loaded = false
		return false
	for entry in table.get("rows", []):
		var raw := entry as Dictionary
		var race := UnitCsvManager.cell(raw, COL_RACE)
		if race == "":
			_problems.append("a races.csv row names no race (skipped)")
			continue
		if _rows.has(race):
			_problems.append("duplicate race '" + race + "' (kept the first row)")
			continue
		var unit := UnitCsvManager.cell(raw, COL_UNIT)
		if unit == "":
			_problems.append("%s: no 默认单位 (the race has no default)" % race)
		elif not UnitSheet.live().has(unit):
			## A typo here would otherwise be an empty answer that looks like "no default".
			_problems.append("%s: 默认单位 '%s' is not a unit of units.csv" % [race, unit])
			unit = ""
		elif not race_belongs(race, unit):
			## A default picks the unit that STANDS FOR its race: naming another race's unit
			## is not a typo the reader may repair silently (plants -> zombie would look fine).
			_problems.append("%s: 默认单位 '%s' belongs to race '%s'"
				% [race, unit, UnitSheet.live().get_race(unit)])
		_rows[race] = unit
		_order.append(race)
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable race row"
	return _loaded


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func race_belongs(p_race: String, p_unit: String) -> bool:
	## Does this unit stand under this race? A root row ("plants") must be answered by a unit of
	## that root; a sub-race row ("plants/pea") by a unit whose race path STARTS there.
	var unit_race := UnitSheet.live().get_race(p_unit)
	return unit_race == p_race or unit_race.begins_with(p_race + "/")


# ---------------------------------------------------------------- queries
static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func error_text() -> String:
	_ensure()
	return _error if _error != "" else "none"


static func ids() -> Array[String]:
	_ensure()
	return _order.duplicate()


static func has(p_race: String) -> bool:
	_ensure()
	return _rows.has(p_race)


static func count() -> int:
	_ensure()
	return _order.size()


static func default_unit(p_race: String) -> String:
	## The unit that stands for this race, or "" when neither it nor any parent has a row.
	## Walks the "/" path upwards, so "plants/pea" answers with the plants row until a pea row
	## of its own exists - the same deepest-wins chain every other table in this project uses.
	_ensure()
	var lookup := p_race
	while lookup != "":
		if _rows.has(lookup):
			return str(_rows[lookup])
		var cut := lookup.rfind("/")
		if cut < 0:
			break
		lookup = lookup.substr(0, cut)
	return ""


static func status_text() -> String:
	## One boot line, in the shape the other [Data] lines use.
	_ensure()
	if not _loaded:
		return "races: NOT loaded (%s)" % error_text()
	var parts := PackedStringArray()
	for race in _order:
		var unit := str(_rows[race])
		parts.append("%s -> %s" % [race, unit if unit != "" else "—"])
	return "races: %d row(s) from %s (%s)" % [_order.size(), PATH.get_file(), ", ".join(parts)]


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()
