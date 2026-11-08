class_name SkillDB
extends RefCounted
## [P30-A] THE SKILL SHEET - data/units/skills.csv, read at boot and on the R key.
##
## Why a sheet (the user's call): a skill's AP price is design data, not code.
## The table has exactly the four columns the design asked for:
##   技能名称   the prose name of the skill ("豌豆射击")
##   技能描述   one line about what it does
##   技能消耗AP how many of the round's AP ONE use costs
##   技能代码   the id the CODE knows: every plant script declares
##              `const SKILL := "<code>"` and asks BalanceBattle.skill_ap_cost(SKILL)
##              for its threshold, so the code-to-script pairing stays where the
##              behaviour itself lives (the same convention as the "playable"
##              wiring of plants.csv: the sheet names numbers, the code acts).
##
## What deliberately is NOT here: the zombie action prices (move / bite / eat /
## vault). Those are ONE global rule every type shares, and global rules live in
## Balance (AGENTS.md), not in a per-unit sheet.
## [P30-B] The ultimate rows ARE here now: three optional columns (大招名称 /
## 大招描述 / 大招数值) hang off the same 技能代码 the basic skill uses -
## "pea_storm" is the ultimate pea's own row, priced by the charge bar rather
## than by AP. The charge rule itself (每次施放 +1、满 10 自动释放) is one global
## rule and stays in Balance (ULT_CHARGE_PER_CAST / ULT_CHARGE_MAX).
##
## The sheet is TAB separated like data/units/*.csv and read through UnitCsv, so
## a column may be added or reordered without shifting a value into the wrong
## field. A prose column may grow its English twin ("<列名>英文", UnitCsvManager.EN_SUFFIX)
## later; cell_en() already looks for it and falls back to the Chinese text.
##
## Failure policy: a missing or broken sheet is NOT fatal. BalanceBattle.SKILL_AP_COST
## keeps the same prices as fall-backs (and an unknown code costs 1 AP), and
## self_check() prints exactly what happened.

const PATH := "res://data/units/skills.csv"

# ---------------------------------------------------------------- sheet columns
# Matched by NAME (see UnitCsv), never by index, so the sheet can grow columns.
const COL_NAME := "技能名称"
const COL_DESC := "技能描述"
const COL_AP := "技能消耗AP"
const COL_CODE := "技能代码"
## [P30-B] The optional ultimate trio. A row is an ULTIMATE when its 技能代码 is
## the one a units.csv 大招代码 cell names; the basic skill cells of such a row
## read "—" (an ultimate is paid by the charge bar, never by AP). 大招数值 is
## the number the code's ultimate implementation reads (pea storm damage /
## burst sun / iron wall heal percent) - the same "sheet names numbers, code
## acts" convention as 技能消耗AP.
const COL_ULT_NAME := "大招名称"
const COL_ULT_DESC := "大招描述"
const COL_ULT_VALUE := "大招数值"
## [P30-B] How this ultimate CHARGES: the sheet writes a phrase ("施放" / "受击")
## and it is translated here into a flag the engine reads - the same phrase-
## table convention as ZombieDB.PHRASES. Unknown phrases fall back to "cast"
## and are reported by self_check().
const COL_ULT_CHARGE := "大招充能"
const CHARGE_PHRASES := {
	"施放": "cast",   # every cast of the basic skill adds ULT_CHARGE_PER_CAST
	"受击": "hit",    # every hit taken does (the wall-nut: it never casts)
}

static var _rows: Dictionary = {}          # code -> row (see _parse_row)
static var _order: Array[String] = []      # the sheet's own order, top to bottom
static var _loaded: bool = false
static var _tried: bool = false            # a failed load is not retried forever
static var _error: String = ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Reads the sheet once. Called by Game at boot; every accessor also calls
	## _ensure(), so a self-check or a battle can never see an empty table.
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
		var raw: Dictionary = entry
		var code := UnitCsvManager.cell(raw, COL_CODE)
		if code == "":
			_problems.append("a row has no 技能代码 (skipped)")
			continue
		if _rows.has(code):
			_problems.append("duplicate skill code '%s' (kept the first row)" % code)
			continue
		## [P30-B] An unknown 大招充能 phrase still charges (the "cast" default),
		## but the sheet meant something else - say so instead of guessing quietly.
		var charge_cell := UnitCsvManager.cell(raw, COL_ULT_CHARGE)
		if charge_cell != "" and not CHARGE_PHRASES.has(charge_cell):
			_problems.append("'%s': unknown 大招充能 '%s' (charging on cast instead)" \
				% [code, charge_cell])
		_rows[code] = _parse_row(raw, code)
		_order.append(code)

	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable skill row"
	return _loaded


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func _parse_row(p_raw: Dictionary, p_code: String) -> Dictionary:
	return {
		"code": p_code,
		"name": UnitCsvManager.cell(p_raw, COL_NAME),
		"desc": UnitCsvManager.cell_en(p_raw, COL_DESC),
		## -1 when the cell is "—": "the code fall-back is in charge", the same
		## deal the optional plant cells have. BalanceBattle.skill_ap_cost() only trusts
		## a value > 0.
		"ap": UnitCsvManager.int_cell(p_raw, [COL_AP], -1),
		## [P30-B] the optional ultimate trio. "" / -1 = "this row says nothing
		## about an ultimate" - a basic-skill row and an ultimate row are told
		## apart by which cell the units.csv columns name, not by fixed lists.
		"ult_name": UnitCsvManager.cell(p_raw, COL_ULT_NAME),
		"ult_desc": UnitCsvManager.cell_en(p_raw, COL_ULT_DESC),
		"ult_value": UnitCsvManager.int_cell(p_raw, [COL_ULT_VALUE], -1),
		## the 大招充能 phrase translated to a flag; "" = the row states no
		## ultimate at all, "cast" = the sheet said nothing usable (reported).
		"ult_charge": _charge_flag(p_raw),
	}


static func _charge_flag(p_raw: Dictionary) -> String:
	## Translate one 大招充能 cell. Only meaningful on an ultimate row - a basic
	## row without 大招名称 answers "" from ult_charge() anyway.
	var text := UnitCsvManager.cell(p_raw, COL_ULT_CHARGE)
	if text == "":
		return "cast"          # the confirmed default: 每次施放 +1
	return str(CHARGE_PHRASES.get(text, "cast"))


# ---------------------------------------------------------------- queries
static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func error_text() -> String:
	_ensure()
	return _error if _error != "" else "none"


static func count() -> int:
	_ensure()
	return _order.size()


static func ids() -> Array[String]:
	## The sheet's own order, so "where is X" is answerable from the file itself.
	_ensure()
	return _order.duplicate()


static func has(p_code: String) -> bool:
	_ensure()
	return _rows.has(p_code)


static func row(p_code: String) -> Dictionary:
	_ensure()
	return _rows.get(p_code, {})


static func name(p_code: String) -> String:
	## The sheet's 技能名称, "" when the row does not exist.
	return str(row(p_code).get("name", ""))


static func description(p_code: String) -> String:
	## The sheet's 技能描述 (English twin when one is ever filled in), "" otherwise.
	return str(row(p_code).get("desc", ""))


static func ap_cost(p_code: String, p_default: int = -1) -> int:
	## The sheet's 技能消耗AP cell, or p_default when the sheet says nothing.
	## -1 = "the code fall-back is in charge"; only a value >= 1 is a real price.
	var r := row(p_code)
	if r.is_empty():
		return p_default
	return int(r.get("ap", p_default))


# ---------------------------------------------------------------- ultimates (P30-B)
static func is_ultimate(p_code: String) -> bool:
	## [P30-B] A row counts as an ultimate when it STATES the 大招名称 cell -
	## the flag the bar, the almanac and BalanceBattle.plant_ult_value() read.
	return ult_name(p_code) != ""


static func ult_name(p_code: String) -> String:
	## The sheet's 大招名称, "" when the row is not an ultimate.
	return str(row(p_code).get("ult_name", ""))


static func ult_description(p_code: String) -> String:
	## The sheet's 大招描述 (English twin when one is ever filled in), "" otherwise.
	return str(row(p_code).get("ult_desc", ""))


static func ult_value(p_code: String) -> int:
	## The sheet's 大招数值: the number the code implementation reads (storm
	## damage / burst sun / wall heal percent). -1 = "the sheet says nothing",
	## which sends the lookup to BalanceBattle.ULTIMATE_VALUE fall-backs.
	return int(row(p_code).get("ult_value", -1))


static func ult_charge(p_code: String) -> String:
	## What FILLS this ultimate's bar: "cast" (every basic-skill use) or "hit"
	## (every hit taken). "" when the row is not an ultimate.
	return str(row(p_code).get("ult_charge", "")) if is_ultimate(p_code) else ""


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func status_text() -> String:
	_ensure()
	if not _loaded:
		return "skills: sheet NOT loaded (%s)" % error_text()
	return "skills: %d row(s) from %s" % [_order.size(), PATH.get_file()]


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game, next to the other sheets: what the skill
	## table gave us. A row without a code or with a price <= 0 cannot be wired to
	## anything, so those are a FAIL; the game itself keeps running on the
	## BalanceBattle.SKILL_AP_COST fall-backs whatever this prints.
	print("[Skills] --- skill sheet from %s (技能代码 -> AP price) ---" % PATH)
	if not is_loaded():
		print("[Skills] sheet not loaded: " + error_text() + " | FAIL")
		print("[Skills] -> BalanceBattle.SKILL_AP_COST fall-backs are being used instead")
		print("[Skills] self-check FAILED")
		return
	print("[Skills] %d skill row(s)" % _order.size())
	var ok := true
	for code in _order:
		var ap := ap_cost(code)
		var ult := is_ultimate(code)
		## An ultimate row is priced by the charge bar, not by AP: a "—" in
		## 技能消耗AP is its normal state (the ap value then simply goes unused),
		## so only a NON-ultimate row demands a real AP price here.
		var good: bool = code != "" and (ult or ap > 0)
		if ult:
			print("[Skills] %-18s ULT  %-10s 数值 %-4d 充能 %-5s %s | %s" % [
				code, ult_name(code), ult_value(code), ult_charge(code),
				ult_description(code), "OK" if good else "FAIL"])
		else:
			print("[Skills] %-18s ap %-2d %-12s %s | %s" % [
				code, ap, name(code), description(code), "OK" if good else "FAIL"])
		ok = ok and good
	for problem in _problems:
		print("[Skills] warning: " + problem)
		ok = ok and false
	## The scripts' side of the wiring: every plant that declares a skill code must
	## find a price SOMEWHERE (the sheet or the fall-back table). Balance answers
	## that itself, so this only lists which side won per row.
	for code in _order:
		if int(BalanceBattle.SKILL_AP_COST.get(code, -1)) < 0:
			print("[Skills] code '%s' has no code fall-back - only the sheet prices it (fine)" % code)
		elif BalanceBattle.SKILL_AP_COST[code] != ap_cost(code):
			print("[Skills] code '%s': sheet %d overrides the fall-back %d" % [
				code, ap_cost(code), int(BalanceBattle.SKILL_AP_COST[code])])
	## [P57] the sheet's own complaints (a spelled cell that is not a number, a header
	## that names one column twice) - see the note in PlantDB.self_check().
	ok = ok and UnitCsvManager.report_complaints("[Skills]")
	print("[Skills] self-check %s" % ("PASSED" if ok else "FAILED"))
