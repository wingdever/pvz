class_name RunState
extends RefCounted
## [P31-A] The ONE run the player is inside: where on the chapter graph they
## stand, which garden plants are on the squad, what the pouch holds, which run
## mods are active, and what a retry would cost. Persisted to user://run.json
## next to garden/profile (design: README「游戏流程重构设计（P31）」).
##
## The pointer rules the whole flow hangs on:
##   node   = the node the player is standing ON ("" before the first pick);
##            the next choice is always ChapterMap.next_of(node).
##   active = the node ENTERED but not yet completed (fighting a battle,
##            sitting in a shop). While it is set the roadmap offers ONLY it,
##            so a quit-and-resume lands back on the unfinished node.
##   visited[id] = completed. A completed battle advanced `node` to id.
##
## Meta-vs-run split (the "混合" decision): money stays the single profile
## wallet (shops and retry fees pay from it); items FOUND in the run go to the
## pouch and are merged into the warehouse only when the run ENDS; run mods die
## with the run; the squad is a list of GARDEN SLOTS, so their wounds, exp and
## recovery keep using the existing garden ledger untouched.

## [P37] `preload` rather than a global class name: see safe_io.gd for why.
const SafeIO := preload("res://scripts/core/save/safe_io.gd")

var source: String = "<defaults>"
var loaded: bool = false
var problems: Array[String] = []

var mode: String = "adventure"          # adventure | journey | survival (P31-D)
var chapter_id: String = ""
## the node the player stands on ("" = at the start line).
var node: String = ""
## the entered-but-unfinished node ("" = none).
var active: String = ""
var visited: Dictionary = {}            # node id -> true
var squad: Array[int] = []              # garden slot indexes
var pouch: Dictionary = {}              # item id -> count (run-scoped loot)
var mods: Array = []                    # [{key:String, value:float, left:int}]
var retry: Dictionary = {}              # node id -> consecutive failures there
var stats: Dictionary = {"wins": 0, "losses": 0, "nodes": 0, "money": 0}
## set when the whole run paid out (kept one visit for the end screen, then the
## file is deleted - see clear_save).
var finished: bool = false


# ---------------------------------------------------------------- lifecycle
static func has_save() -> bool:
	## True when a parseable, UNFINISHED run file sits in user://. The main menu
	## asks this before offering "继续冒险".
	if not FileAccess.file_exists(BalanceRun.RUN_PATH):
		return false
	var probe := RunState.new()
	var f := FileAccess.open(BalanceRun.RUN_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	probe.parse_text(text, "<probe>")
	return probe.loaded and not probe.finished and not probe.squad.is_empty()


static func load_or_create() -> RunState:
	## The run the game PLAYS with. Returns null when there is no usable save -
	## unlike Garden/Profile a run has no "defaults" meaning: an absent file is
	## simply "no run in progress".
	if not FileAccess.file_exists(BalanceRun.RUN_PATH):
		return null
	var f := FileAccess.open(BalanceRun.RUN_PATH, FileAccess.READ)
	if f == null:
		push_warning("[Run] cannot open %s (error %d)" % [BalanceRun.RUN_PATH, FileAccess.get_open_error()])
		return null
	var text := f.get_as_text()
	f.close()
	var r := RunState.new()
	if not r.parse_text(text, BalanceRun.RUN_PATH):
		for line in r.problems:
			print("[Run]   " + line)
		## [P37] "No run in progress" is about to be written over this file the first
		## time a run starts, so keep the bytes.
		SafeIO.keep_broken(BalanceRun.RUN_PATH)
		push_warning("[Run] save file unusable -> treated as no run in progress")
		return null
	print("[Run] loaded " + BalanceRun.RUN_PATH + ": " + r.summary_text())
	return r


static func clear_save() -> void:
	if not FileAccess.file_exists(BalanceRun.RUN_PATH):
		return
	## DirAccess works on absolute paths, so the user:// URL is globalised first.
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(BalanceRun.RUN_PATH))
	print("[Run] save cleared%s" % ["" if err == OK else " (FAILED: %d)" % err])


func start_new(p_chapter: ChapterMap, p_squad: Array[int]) -> void:
	mode = "adventure"
	chapter_id = p_chapter.chapter_id
	node = ""
	active = ""
	visited = {}
	squad = p_squad.duplicate()
	pouch = {}
	mods = []
	retry = {}
	stats = {"wins": 0, "losses": 0, "nodes": 0, "money": 0}
	finished = false
	loaded = true
	source = BalanceRun.RUN_PATH


func save_to_disk() -> bool:
	if source.begins_with("<"):
		## [P37] Same rule Garden and Profile have always had: a probe instance must
		## not be able to write the player's one run file.
		push_warning("[Run] refusing to save a scratch run (" + source + ")")
		return false
	## [P37] Written through SafeIO so an interrupted write cannot leave a half file
	## that load_or_create() would then read as "no run in progress" (OPTIMIZATIONS A1).
	return SafeIO.write_text_atomic(BalanceRun.RUN_PATH, to_json_text())


# ---------------------------------------------------------------- graph flow
func choices(map: ChapterMap) -> Array:
	## What the roadmap may offer RIGHT NOW: the unfinished node, else the entry
	## line, else the doors of the node the player stands on.
	if active != "":
		return [active]
	if node == "":
		return map.entry_ids()
	return map.next_of(node)


func enter(id: String) -> void:
	active = id


func complete(id: String) -> void:
	## The node is DONE: it becomes the standing position, and every timed mod
	## spends one of its remaining nodes (design: 巡视 = "the next 2 nodes").
	active = ""
	node = id
	visited[id] = true
	stats["nodes"] = int(stats.get("nodes", 0)) + 1
	tick_mods()


func is_completed(id: String) -> bool:
	return bool(visited.get(id, false))


func in_progress() -> bool:
	return not finished and (not squad.is_empty())


# ---------------------------------------------------------------- retry cost
func retry_attempts(id: String) -> int:
	return int(retry.get(id, 0))


func retry_cost(id: String) -> int:
	## 30 -> 60 -> 120 capped at 4x base (the design's "翻倍封顶 4 倍").
	var mult := clampi(int(pow(2.0, float(retry_attempts(id)))), 1, BalanceRun.RETRY_COST_MAX_MULT)
	return BalanceRun.RETRY_COST_BASE * mult


func note_defeat(id: String) -> int:
	## Charges nothing by itself: it records the attempt and reports what THIS
	## defeat costs (Game moves the money, then downs the squad).
	var cost := retry_cost(id)
	retry[id] = retry_attempts(id) + 1
	return cost


# ---------------------------------------------------------------- run mods
func add_mod(p_key: String, p_value: float, p_left: int) -> void:
	## left = 0 keeps the mod for the whole run; > 0 counts DOWN per completed node.
	if not BalanceRun.RUN_MOD_KEYS.has(p_key):
		push_warning("[Run] unknown mod key '%s' (ignored)" % p_key)
		return
	mods.append({"key": p_key, "value": p_value, "left": maxi(0, p_left)})


func mod_product(p_key: String) -> float:
	## The multiplier a multiplicative mod key folds into the difficulty preset.
	var out := 1.0
	for entry in mods:
		var m: Dictionary = entry
		if str(m["key"]) == p_key:
			out *= float(m["value"])
	return out


func mod_bonus(p_key: String) -> int:
	## The flat sum an additive mod key contributes.
	var out := 0
	for entry in mods:
		var m: Dictionary = entry
		if str(m["key"]) == p_key:
			out += int(m["value"])
	return out


func tick_mods() -> void:
	var kept: Array = []
	for entry in mods:
		var m: Dictionary = entry
		var left := int(m["left"]) - 1
		if left > 0:
			m["left"] = left
			kept.append(m)
	mods = kept


func mods_text() -> String:
	var parts: PackedStringArray = []
	for entry in mods:
		var m: Dictionary = entry
		var left := int(m["left"])
		parts.append("%s x%g%s" % [str(m["key"]), float(m["value"]),
			"" if left <= 0 else " (%d)" % left])
	return "none" if parts.is_empty() else ", ".join(parts)


# ---------------------------------------------------------------- pouch
func pouch_add(item_id: String, p_amount: int) -> void:
	if p_amount <= 0:
		return
	pouch[item_id] = int(pouch.get(item_id, 0)) + p_amount


func pouch_count(item_id: String) -> int:
	return int(pouch.get(item_id, 0))


func pouch_is_empty() -> bool:
	return pouch.is_empty()


func pouch_text() -> String:
	var parts: PackedStringArray = []
	for key in pouch.keys():
		parts.append("%s x%d" % [Balance.item_name(str(key)), int(pouch[key])])
	return "empty" if parts.is_empty() else ", ".join(parts)


# ---------------------------------------------------------------- squad
func summary_text() -> String:
	return "run %s @ %s (node '%s', active '%s', squad %d, pouch %s, mods %s, wins %d, losses %d)" % [
		mode, chapter_id, node, active, squad.size(), str(pouch.size()) + " stacks",
		mods_text(), int(stats.get("wins", 0)), int(stats.get("losses", 0))]


# ---------------------------------------------------------------- serialising
func to_json_text() -> String:
	var d := {
		"version": BalanceRun.RUN_VERSION,
		"mode": mode,
		"chapter": chapter_id,
		"node": node,
		"active": active,
		"visited": visited,
		"squad": squad,
		"pouch": pouch,
		"mods": mods,
		"retry": retry,
		"stats": stats,
		"finished": finished,
	}
	return JSON.stringify(d, "  ")


func parse_text(text: String, p_source: String) -> bool:
	## Defensive like every other save here: a bad FIELD is dropped with a note,
	## a broken ROOT is a refused file (the caller treats it as "no run").
	problems.clear()
	source = p_source
	loaded = false
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		problems.append("JSON parse error at line %d: %s"
			% [json.get_error_line(), json.get_error_message()])
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		problems.append("root element must be a JSON object")
		return false
	var d: Dictionary = json.data

	mode = str(d.get("mode", "adventure"))
	if mode != "adventure":
		## [P31-D] journey/survival are not implemented yet: a hand-edited file
		## must not put the player into a mode the code cannot run.
		problems.append("mode '%s' is not implemented -> adventure" % mode)
		mode = "adventure"
	chapter_id = str(d.get("chapter", ""))
	node = str(d.get("node", ""))
	active = str(d.get("active", ""))
	visited = _dict_of_true(d.get("visited", {}))
	squad = []
	var raw_squad: Variant = d.get("squad", [])
	if typeof(raw_squad) == TYPE_ARRAY:
		for item in (raw_squad as Array):
			## [P37] A hostile entry has to be DROPPED, not coerced: int("x") is 0, so
			## a junk string used to smuggle in a real slot 0 (and self_check's
			## "junk squad entries degrade loudly" assertion was failing on it).
			if typeof(item) != TYPE_INT and typeof(item) != TYPE_FLOAT:
				problems.append("squad entry '%s' is not a slot number (dropped)" % str(item))
				continue
			var slot := int(item)
			if slot >= 0 and not squad.has(slot):
				squad.append(slot)
	else:
		problems.append("'squad' is not an array (ignored)")
	pouch = {}
	var raw_pouch: Variant = d.get("pouch", {})
	if typeof(raw_pouch) == TYPE_DICTIONARY:
		for key in (raw_pouch as Dictionary).keys():
			var id := str(key)
			var count := int((raw_pouch as Dictionary)[key])
			if count > 0 and Balance.is_item(id):
				pouch[id] = count
			elif count > 0:
				problems.append("pouch item '%s' is not an item (dropped)" % id)
	mods = []
	var raw_mods: Variant = d.get("mods", [])
	if typeof(raw_mods) == TYPE_ARRAY:
		for item in (raw_mods as Array):
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var m: Dictionary = item
			var key := str(m.get("key", ""))
			if not BalanceRun.RUN_MOD_KEYS.has(key):
				problems.append("unknown mod key '%s' (dropped)" % key)
				continue
			mods.append({"key": key, "value": float(m.get("value", 1.0)),
				"left": maxi(0, int(m.get("left", 0)))})
	retry = _int_map(d.get("retry", {}))
	stats = {"wins": 0, "losses": 0, "nodes": 0, "money": 0}
	var raw_stats: Variant = d.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for key in (raw_stats as Dictionary).keys():
			var k := str(key)
			if stats.has(k):
				stats[k] = int((raw_stats as Dictionary)[key])
	finished = bool(d.get("finished", false))
	loaded = true
	return true


static func _dict_of_true(raw: Variant) -> Dictionary:
	## id -> true from either {"a":true} or ["a","b"] (the writer uses the object
	## form; a hand-edit may reach for the array one).
	var out: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		for key in (raw as Dictionary).keys():
			if bool((raw as Dictionary)[key]):
				out[str(key)] = true
		return out
	if typeof(raw) == TYPE_ARRAY:
		for item in (raw as Array):
			out[str(item)] = true
		return out
	return out


static func _int_map(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in (raw as Dictionary).keys():
		out[str(key)] = int((raw as Dictionary)[key])
	return out


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## [P31-A] Scratch instances only; the real run.json is never touched here.
	## A scratch object has source "<defaults>", and save_to_disk is NEVER called
	## on it - the round trip runs through parse_text(to_json_text()) in memory.
	print("[Run] --- run state (P31-A) ---")
	var ok := true

	var map := ChapterMap.new()
	var made : bool= map.parse_text(JSON.stringify({
		"id": "probe_ch", "name": "Probe",
		"layers": [
			[{"id": "a", "type": "battle", "level": "Lawn_1_1", "next": ["b", "c"]}],
			[{"id": "b", "type": "rest", "next": ["z"]},
			 {"id": "c", "type": "shop", "next": ["z"]}],
			[{"id": "z", "type": "boss", "level": "Lawn_1_1"}]]}), "<defaults>")
	ok = ok and made
	print("[Run] probe chapter parsed: %s | %s" % [str(made), "OK" if made else "FAIL"])

	var r := RunState.new()
	r.start_new(map, [0, 1])
	var flow_ok: bool = r.choices(map) == map.entry_ids()
	r.enter(str(map.entry_ids()[0]))
	flow_ok = flow_ok and r.choices(map) == ["a"]
	r.complete("a")
	flow_ok = flow_ok and r.node == "a" and r.active == "" \
		and r.choices(map) == ["b", "c"]
	print("[Run] enter/complete moves the pointer and the choices: %s | %s" \
		% [str(flow_ok), "OK" if flow_ok else "FAIL"])
	ok = ok and flow_ok

	## Retry fee: 30 -> 60 -> 120, capped at 4x = 120.
	var fee1 := r.note_defeat("b")
	var fee2 := r.note_defeat("b")
	var fee3 := r.note_defeat("b")
	var fee4 := r.note_defeat("b")
	var fee_ok: bool = fee1 == BalanceRun.RETRY_COST_BASE and fee2 == fee1 * 2 \
		and fee3 == fee2 * 2 and fee4 == fee3
	print("[Run] retry fee doubles and caps at %dx: %d/%d/%d/%d | %s" % [
		BalanceRun.RETRY_COST_MAX_MULT, fee1, fee2, fee3, fee4,
		"OK" if fee_ok else "FAIL"])
	ok = ok and fee_ok

	## Mods: the patrol mod survives exactly its node count and nothing longer.
	var m: Dictionary = BalanceRun.RUN_REST_PATROL_MOD
	r.add_mod(str(m["key"]), float(m["value"]), int(m["left"]))
	var mod_ok: bool = r.mod_product("sun_mult") > 1.0
	r.complete("b")
	mod_ok = mod_ok and r.mod_product("sun_mult") > 1.0
	r.complete("z")
	mod_ok = mod_ok and r.mod_product("sun_mult") == 1.0
	print("[Run] a timed mod pays out for its node count and then leaves: %s | %s" \
		% [str(mod_ok), "OK" if mod_ok else "FAIL"])
	ok = ok and mod_ok

	## Save -> load round trip through the exact text the file would hold.
	r.enter("z")
	r.pouch_add(Balance.ITEM_FERTILIZER, 2)
	var back := RunState.new()
	var trip_ok: bool = back.parse_text(r.to_json_text(), "<probe>") \
		and back.node == r.node and back.active == "z" \
		and back.squad == r.squad and back.pouch_count(Balance.ITEM_FERTILIZER) == 2 \
		and int(back.retry.get("b", 0)) == 4 and back.mods.size() == r.mods.size()
	print("[Run] save -> load keeps pointer/squad/pouch/retry/mods: %s | %s" \
		% [str(trip_ok), "OK" if trip_ok else "FAIL"])
	ok = ok and trip_ok

	## A hostile file degrades LOUD instead of crashing: unknown mode -> adventure,
	## junk squad entries -> dropped, unknown item -> dropped.
	var hostile := RunState.new()
	var hostile_ok: bool = hostile.parse_text(
		'{"mode":"survival","squad":[-3,"x",5],"pouch":{"unobtainium":1,"fertilizer":2},' \
		+ '"mods":[{"key":"gravity","value":9}]}', "<probe>")
	hostile_ok = hostile_ok and hostile.mode == "adventure" and hostile.squad == [5] \
		and hostile.pouch_count(Balance.ITEM_FERTILIZER) == 2 and hostile.mods.is_empty()
	print("[Run] unknown mode/squad junk/phantom items degrade loudly: %s | %s" \
		% [str(hostile_ok), "OK" if hostile_ok else "FAIL"])
	ok = ok and hostile_ok

	print("[Run] self-check %s" % ("PASSED" if ok else "FAILED"))
