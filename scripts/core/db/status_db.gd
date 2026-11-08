## [P90] THE STATUS TABLE (data/statuses.csv) - what a hit can leave ON a unit.
##
## WHY A TABLE (user design, 2026-09-25): a status is the SMALLEST kind of mechanic there
## is, so it is the first place the rule "mechanisms are data + primitives" can be finished
## instead of argued about. Before this file, the six rules a status needs were spread over
## one class: the id constants, the immunity map, the refresh rule, the tick rule, the
## action gate and the log text all lived inside Zombie (see its P34/P59 notes).
##
## WHAT THE TABLE OWNS: the id, the two names, the display phrase, whether it is a COUNTDOWN
## (ticked down at TURN_START) or INSTANT (resolved on the hit and never counted), the default
## duration, the stacking rule (max / add / replace), the sheet flag that refuses it, and what
## it DOES - as a value of the closed IMPACTS list below.
##
## WHAT STAYS CODE (and why):
##   * the IMPACT primitives themselves (禁行动 / 位移 / ... ): the framework implements each
##     one once, and an impact the code does not know is a complaint, never a silent nothing;
##   * the COLOURS a status paints a unit with - they are pixel values whose only reader is
##     the drawing code, so they live in BalanceUI like every other one (STATUS_TINTS below);
##   * a unit's OWN phases (the giant's wind-up, the dancer's countdown, a pole vault charge):
##     they are a script's state machine, not something applied from outside, and their numbers
##     are already sheet columns (锤击前摇 / 召唤间隔 / 移动) - putting them here would give one
##     number two owners (AGENTS.md §2).
##
## BY PATH, no class_name: same reason as Spawn / Rewards / DropDB (a brand-new global class is
## invisible to `godot --headless` until the editor rescans).

const UnitCsv := preload("res://scripts/core/unit_csv.gd")

const PATH := "res://data/statuses.csv"

## The statuses the CODE names by id. A row is what gives them meaning; an id used in code
## with no row is a complaint in self_check (a rider nobody can explain).
const ID_FREEZE := "freeze"
const ID_PUSH := "push"

## [P90] The closed list of what a status may DO. Every value here is a primitive the
## framework implements; a sheet that spells something else is refused, because a status
## whose effect nobody executes would look fine and do nothing.
const IMPACT_BLOCK_ACTION := "禁行动"
const IMPACT_SHIFT := "位移"
const IMPACTS: Array[String] = [IMPACT_BLOCK_ACTION, IMPACT_SHIFT]

## The two kinds. COUNTDOWN statuses live in Unit.effect_rounds and are ticked at TURN_START;
## INSTANT ones are resolved by the hit that carried them and are never stored.
const KIND_COUNTDOWN := "倒计时"
const KIND_INSTANT := "瞬时"
const KINDS: Array[String] = [KIND_COUNTDOWN, KIND_INSTANT]

## The stacking rules, i.e. what a SECOND hit does to a counter that is still running.
## Every closed vocabulary in this file is spelled the way the SHEET spells it (Chinese),
## so a designer reads one language and the code checks the very same strings.
const STACK_MAX := "取大"
const STACK_ADD := "累加"
const STACK_REPLACE := "替换"
const STACKS: Array[String] = [STACK_MAX, STACK_ADD, STACK_REPLACE]

## How many complaint lines one block prints before it says "the rest are not shown".
const COMPLAINT_LIMIT := 12

const COL_ID := "name"
const COL_ZH := "中文名"
const COL_EN := "英文名"
const COL_TEXT := "显示"
const COL_TEXT_EN := "显示英文"
const COL_KIND := "名称"
const COL_ROUNDS := "持续"
const COL_STACK := "叠加"
const COL_IMMUNE := "免疫旗标"
const COL_IMPACT := "影响"
const COL_AMOUNT := "数值"

static var _rows: Dictionary = {}
static var _order: Array[String] = []
static var _problems: Array[String] = []
static var _loaded := false
static var _tried := false
static var _error := ""


static func load_from_disk() -> bool:
	## Called once at boot, next to the other sheets. A sheet that cannot be read is not
	## fatal: the two ids the code knows keep working off the built-in rows below.
	_tried = true
	_rows.clear()
	_order.clear()
	_problems.clear()
	_error = ""
	_loaded = false
	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		_use_fallback()
		return _loaded
	for entry in (table.get("rows", []) as Array):
		var raw: Dictionary = entry
		var id := UnitCsvManager.cell(raw, COL_ID)
		if id == "":
			_problems.append("a row has no name (skipped)")
			continue
		if _rows.has(id):
			_problems.append("duplicate status id '%s' (kept the first row)" % id)
			continue
		_rows[id] = {
			"id": id,
			"zh": UnitCsvManager.cell(raw, COL_ZH),
			"en": UnitCsvManager.cell(raw, COL_EN),
			"text": UnitCsvManager.cell(raw, COL_TEXT),
			"text_en": UnitCsvManager.cell(raw, COL_TEXT_EN),
			"kind": UnitCsvManager.cell(raw, COL_KIND),
			"rounds": UnitCsvManager.int_cell(raw, [COL_ROUNDS], 1),
			"stack": UnitCsvManager.cell(raw, COL_STACK),
			"immune": UnitCsvManager.cell(raw, COL_IMMUNE),
			"impact": UnitCsvManager.cell(raw, COL_IMPACT),
			"amount": UnitCsvManager.int_cell(raw, [COL_AMOUNT], 0),
		}
		_order.append(id)
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable status row"
		_use_fallback()
	return _loaded


static func _use_fallback() -> void:
	## The two statuses the battle really has, straight out of the code constants. The game
	## keeps playing with no sheet; only a NEW status needs the file.
	_rows.clear()
	_order.clear()
	_rows[ID_FREEZE] = {"id": ID_FREEZE, "zh": "冻结", "en": "Frozen", "text": "冻结 x%d",
		"text_en": "freeze x%d", "kind": KIND_COUNTDOWN, "rounds": 1, "stack": STACK_MAX,
		"immune": "freeze_immune", "impact": IMPACT_BLOCK_ACTION, "amount": 0}
	_rows[ID_PUSH] = {"id": ID_PUSH, "zh": "击退", "en": "Knockback", "text": "击退",
		"text_en": "knockback", "kind": KIND_INSTANT, "rounds": 0, "stack": STACK_REPLACE,
		"immune": "", "impact": IMPACT_SHIFT, "amount": 0}
	_order.append(ID_FREEZE)
	_order.append(ID_PUSH)
	_loaded = true


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func source() -> String:
	return "sheet" if FileAccess.file_exists(PATH) and _error == "" else "built-in"


static func error_text() -> String:
	return _error if _error != "" else "none"


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func has(p_id: String) -> bool:
	_ensure()
	return _rows.has(p_id)


static func ids() -> Array[String]:
	_ensure()
	return _order.duplicate()


static func row(p_id: String) -> Dictionary:
	_ensure()
	return _rows.get(p_id, {})


static func kind_of(p_id: String) -> String:
	return str(row(p_id).get("kind", ""))


static func is_instant(p_id: String) -> bool:
	## Instant statuses are resolved by the hit that carried them and never enter a counter.
	return kind_of(p_id) == KIND_INSTANT


static func default_rounds(p_id: String) -> int:
	## What the sheet says one application is worth; <= 0 means "the applier decides".
	return int(row(p_id).get("rounds", 0))


static func stack_rule(p_id: String) -> String:
	return str(row(p_id).get("stack", STACK_MAX))


static func immune_flag(p_id: String) -> String:
	## The 特殊机制 phrase-flag whose presence on a unit refuses this status ("" = nobody
	## is immune). This is the map Zombie.EFFECT_IMMUNE used to spell out in code.
	return str(row(p_id).get("immune", ""))


static func impact_of(p_id: String) -> String:
	return str(row(p_id).get("impact", ""))


static func blocks_action(p_id: String) -> bool:
	## The primitive the action gates ask. "Is this unit unable to act?" is now a question
	## about its ACTIVE STATUSES, not about one hard-coded id.
	return impact_of(p_id) == IMPACT_BLOCK_ACTION


static func shifts(p_id: String) -> bool:
	return impact_of(p_id) == IMPACT_SHIFT


static func text(p_id: String, p_rounds: int = 0) -> String:
	## The phrase a bar or a log line shows, in the CURRENT language (the sheets carry both,
	## like every other prose column). A row with no phrase falls back to the id, so a missing
	## translation can never print an empty line.
	var r := row(p_id)
	if r.is_empty():
		return p_id
	var zh := str(r.get("text", ""))
	var en := str(r.get("text_en", ""))
	var phrase := zh if Loc.prefer_zh() else (en if en != "" else zh)
	if phrase == "":
		phrase = str(r.get("zh", p_id))
	return phrase % p_rounds if phrase.contains("%") else phrase


static func name_of(p_id: String) -> String:
	var r := row(p_id)
	if r.is_empty():
		return p_id
	var zh := str(r.get("zh", ""))
	var en := str(r.get("en", ""))
	return zh if Loc.prefer_zh() else (en if en != "" else zh)

static func status_text() -> String:
	return "status text of status db"

# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## One physical line per claim, like every other sheet block. The teeth are at the end:
	## a row whose 影响 / 名称 / 叠加 is not one of the closed values, or a status the CODE
	## names that the sheet does not have, makes this block FAIL - a status nobody can
	## execute would otherwise look perfectly healthy in the file.
	print("[Status] --- status sheet from %s ---" % PATH)
	_ensure()
	var ok := true
	print("[Status] %d status(es), source %s%s"
		% [_order.size(), source(), (" (sheet error: %s)" % _error) if _error != "" else ""])
	var impacts_ok := true
	var kinds_ok := true
	var stacks_ok := true
	for id in _order:
		var r := row(id)
		var impact := impact_of(id)
		var kind := kind_of(id)
		var stack := stack_rule(id)
		if not IMPACTS.has(impact):
			impacts_ok = false
			_problems.append("%s: \"%s\" is not one of the impacts the battle implements (%s)"
				% [id, impact, ", ".join(IMPACTS)])
		if not KINDS.has(kind):
			kinds_ok = false
			_problems.append("%s: \"%s\" is not a kind (%s)" % [id, kind, ", ".join(KINDS)])
		if not STACKS.has(stack):
			stacks_ok = false
			_problems.append("%s: \"%s\" is not a stacking rule (%s)" % [id, stack, ", ".join(STACKS)])
		print("[Status] %-8s %-6s kind %-8s rounds %-3d stack %-8s immune %-14s impact %-6s%s"
			% [id, str(r.get("zh", "")), kind, default_rounds(id), stack,
			   (immune_flag(id) if immune_flag(id) != "" else "-"), impact,
			   (" | OK" if IMPACTS.has(impact) and KINDS.has(kind) and STACKS.has(stack) else " | FAIL")])
	ok = ok and impacts_ok and kinds_ok and stacks_ok
	print("[Status] every 影响 / 名称 / 叠加 value is one the framework implements = %s | %s"
		% [str(impacts_ok and kinds_ok and stacks_ok), "OK" if (impacts_ok and kinds_ok and stacks_ok) else "FAIL"])
	## The ids the code applies by name must exist, and the two primitives they need must be
	## the ones they ask for: a sheet edit that turns 冻结 into a 位移 would be caught here
	## rather than in a battle.
	var freeze_ok: bool = has(ID_FREEZE) and blocks_action(ID_FREEZE) \
		and not is_instant(ID_FREEZE) and immune_flag(ID_FREEZE) != ""
	var push_ok: bool = has(ID_PUSH) and shifts(ID_PUSH) and is_instant(ID_PUSH)
	ok = ok and freeze_ok and push_ok
	print("[Status] the code's two ids are wired: %s = 禁行动/倒计时/可免疫 (%s), %s = 位移/瞬时 (%s) | %s"
		% [ID_FREEZE, str(freeze_ok), ID_PUSH, str(push_ok), "OK" if (freeze_ok and push_ok) else "FAIL"])
	## The phrase is prose: both languages must carry the SAME placeholders (Loc's rule).
	var text_ok := true
	for id in _order:
		var zh := str(row(id).get("text", ""))
		var en := str(row(id).get("text_en", ""))
		if zh.count("%") != en.count("%"):
			text_ok = false
			_problems.append("%s: the zh and en phrases carry a different number of placeholders" % id)
	ok = ok and text_ok
	print("[Status] zh and en phrases carry the same placeholders = %s | %s"
		% [str(text_ok), "OK" if text_ok else "FAIL"])
	for problem in _problems:
		print("[Status] warning: " + problem)
	ok = ok and _problems.is_empty()
	if _problems.size() > COMPLAINT_LIMIT:
		print("[Status] warning: ... %d more not listed (cap: %d)" % [_problems.size() - COMPLAINT_LIMIT, COMPLAINT_LIMIT])
	print("[Status] self-check %s" % ("PASSED" if ok else "FAILED"))
