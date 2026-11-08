class_name EventDB
extends RefCounted
## [P31-A] THE EVENT REGISTRY of the adventure roadmap, read from
## data/adventure/events.json.
##
## An event is one card the ROADMAP can hand the player: a title, a paragraph of
## flavour text and 2-3 options, each option carrying a line of effects in a tiny
## mini-language. This class is the DATA half only - it loads the file, validates
## every id and every effect token and answers lookups. APPLYING an effect is
## Game's job (it owns the wallet, the garden and the run), which keeps the same
## boundary ChapterMap draws between "what the sheet says" and "what the battle does".
##
## The effect mini-language, one `key=value` per token, tokens split by ';':
##   money=+40 / money=-25   wallet delta (the run's shared money)
##   item=coin_silver        one item into the run pouch (must be a Balance.ITEM_DEFS id)
##   plant=wallnut           one plant into the garden (must be a PlantDB id)
##   heal=1 / heal=all       cure DOWNED squad members, one (first) or every
##   mod=sun_mult:1.15:3     a run modifier: key:value[:nodes-left], key must be in
##                           BalanceRun.RUN_MOD_KEYS, the left part omitted = permanent
##   down=peashooter         the FIRST squad slot growing this plant goes DOWNED
##
## Failure policy (the same rule as every other sheet): a missing or broken file is
## NOT fatal - the roadmap then simply never rolls an event it cannot show, and
## status_text()/self_check() say what went wrong.

## One event option parsed out of its effects string: {kind, ...payload}.
## kinds: money / item / plant / heal / mod / down.

static var _events: Dictionary = {}        # id -> event dict (see _parse_event)
static var _order: Array[String] = []
static var _loaded: bool = false
static var _tried: bool = false
static var _error: String = ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Reads the JSON once. Called by Game at boot; every accessor also calls
	## _ensure(), so a screen can never see an empty registry.
	_tried = true
	_events.clear()
	_order.clear()
	_problems.clear()
	_error = ""

	if not FileAccess.file_exists(BalanceRun.EVENTS_FILE):
		_error = "file not found: " + BalanceRun.EVENTS_FILE
		return false
	## [P109] `raw`, not `text` (a local `text` shadowed this class's `text()` getter).
	var raw := FileAccess.get_file_as_string(BalanceRun.EVENTS_FILE)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		_error = "expected a JSON array of events, got " + _type_name(parsed)
		return false
	for entry in (parsed as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			_problems.append("a top-level entry is not an object (skipped)")
			continue
		var battle_event := _parse_event(entry as Dictionary)
		var id := str(battle_event.get("id", ""))
		if id == "":
			_problems.append("an event has no id (skipped)")
			continue
		if _events.has(id):
			_problems.append("duplicate event id '%s' (kept the first)" % id)
			continue
		## [P109] `battle_event`, not `event`: the local used to be named `event`, which
		## shadowed this class's `static func event()`. A partial rename left the bare
		## `event` below bound to the FUNCTION (a Callable stores happily in a Dictionary)
		## and the roster only blew up at runtime when `event()` returned it.
		_events[id] = battle_event
		_order.append(id)
	_loaded = not _order.is_empty()
	if not _loaded and _error == "":
		_error = "no usable event"
	return _loaded


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func _type_name(p_value: Variant) -> String:
	return type_string(typeof(p_value))


static func _parse_event(p_raw: Dictionary) -> Dictionary:
	## One event, validated as far as a DATA class can: the ids inside the effect
	## strings are checked against Balance/PlantDB here so a typo shows up in the
	## start-up log instead of silently doing nothing mid-run.
	var id := str(p_raw.get("id", "")).strip_edges()
	var battle_event := {
		"id": id,
		"title_zh": str(p_raw.get("title_zh", "")),
		"title_en": str(p_raw.get("title_en", "")),
		"text_zh": str(p_raw.get("text_zh", "")),
		"text_en": str(p_raw.get("text_en", "")),
		"options": [],
	}
	if id != "" and (battle_event["title_zh"] == "" or battle_event["title_en"] == ""):
		_problems.append("event '%s' is missing a title (both title_zh and title_en are required)" % id)
	if id != "" and (battle_event["text_zh"] == "" or battle_event["text_en"] == ""):
		_problems.append("event '%s' is missing text (both text_zh and text_en are required)" % id)
	var raw_options: Variant = p_raw.get("options", [])
	if typeof(raw_options) != TYPE_ARRAY:
		if id != "":
			_problems.append("event '%s' has no options array" % id)
		return battle_event
	var index := 0
	for entry in (raw_options as Array):
		index += 1
		if typeof(entry) != TYPE_DICTIONARY:
			_problems.append("battle_event '%s' option %d is not an object (skipped)" % [id, index])
			continue
		var raw: Dictionary = entry
		var option := {
			"text_zh": str(raw.get("text_zh", "")),
			"text_en": str(raw.get("text_en", "")),
			"effects": parse_effects(str(raw.get("effects", "")), id, index),
		}
		if option["text_zh"] == "" or option["text_en"] == "":
			_problems.append("event '%s' option %d is missing a label" % [id, index])
		if (option["effects"] as Array).is_empty():
			## An option that does nothing is a dead button; refuse to keep it silent.
			_problems.append("event '%s' option %d carries no effects" % [id, index])
		(battle_event["options"] as Array).append(option)
	if id != "" and (battle_event["options"] as Array).size() < 2:
		_problems.append("event '%s' has fewer than 2 usable options" % id)
	return battle_event


# ---------------------------------------------------------------- effect strings
static func parse_effects(p_text: String, p_event_id: String = "", p_option: int = 0) -> Array:
	## "money=30;item=coin_silver" -> [{kind:"money",amount:30}, {kind:"item",id:"coin_silver"}].
	## A token that does not parse is REPORTED and dropped (where the context allows,
	## p_event_id/p_option say who said it); the rest of the line still applies,
	## because half an event is better than a crashed one.
	var where := ""
	if p_event_id != "":
		where = "event '%s' option %d: " % [p_event_id, p_option]
	elif p_text != "":
		where = "effects '" + p_text + "': "
	var out: Array = []
	for token in p_text.split(";"):
		var piece := str(token).strip_edges()
		if piece == "":
			continue
		var eq := piece.find("=")
		if eq < 0:
			_problems.append(where + "token '" + piece + "' has no '=' (dropped)")
			continue
		var key := piece.substr(0, eq).strip_edges()
		var value := piece.substr(eq + 1).strip_edges()
		match key:
			"money":
				var amount := value.strip_edges()
				if amount.begins_with("+"):
					amount = amount.substr(1)
				out.append({"kind": "money", "amount": int(amount)})
			"item":
				if not Balance.is_item(value):
					_problems.append(where + "unknown item id '" + value + "' (dropped)")
				else:
					out.append({"kind": "item", "id": value})
			"plant":
				if not PlantDB.has(value):
					_problems.append(where + "unknown plant id '" + value + "' (dropped)")
				else:
					out.append({"kind": "plant", "id": value})
			"heal":
				if value != "1" and value != "all":
					_problems.append(where + "heal must be 1 or all, got '" + value + "' (dropped)")
				else:
					out.append({"kind": "heal", "all": value == "all"})
			"mod":
				var mod := _parse_mod(value)
				if mod.is_empty():
					_problems.append(where + "bad mod token '" + piece + "' (dropped)")
				else:
					out.append(mod)
			"down":
				## Not an existence CHECK: an event may name a plant the squad does not
				## have, and then it simply finds no slot. Only the shape is validated.
				if value == "":
					_problems.append(where + "down= without a plant id (dropped)")
				else:
					out.append({"kind": "down", "id": value})
			_:
				_problems.append(where + "unknown effect key '" + key + "' (dropped)")
	return out


static func _parse_mod(p_value: String) -> Dictionary:
	## "sun_mult:1.15:3" -> {kind:"mod", key, value, left}. The third part is the
	## number of NODES the modifier keeps paying off; omitted = permanent for the run.
	var parts := p_value.split(":")
	if parts.size() < 2 or parts.size() > 3:
		return {}
	var key := str(parts[0]).strip_edges()
	if not BalanceRun.RUN_MOD_KEYS.has(key):
		return {}
	var mod := {"kind": "mod", "key": key, "value": float(str(parts[1])), "left": 0}
	if parts.size() == 3:
		var left := int(str(parts[2]).strip_edges())
		if left < 1:
			return {}
		mod["left"] = left
	return mod


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
	_ensure()
	return _order.duplicate()


static func has(p_id: String) -> bool:
	_ensure()
	return _events.has(p_id)


static func event(p_id: String) -> Dictionary:
	_ensure()
	return _events.get(p_id, {})


static func option_count(p_id: String) -> int:
	_ensure()
	return (event(p_id).get("options", []) as Array).size()


static func options(p_id: String) -> Array:
	_ensure()
	return event(p_id).get("options", [])


static func title(p_id: String) -> String:
	return _pick(p_id, "title")


static func text(p_id: String) -> String:
	return _pick(p_id, "text")


static func option_text(p_id: String, p_index: int) -> String:
	_ensure()
	var event_options: Array = event(p_id).get("options", [])
	if p_index < 0 or p_index >= event_options.size():
		return ""
	var event_option: Dictionary = event_options[p_index]
	if Loc.prefer_zh():
		var zh := str(event_option.get("text_zh", ""))
		if zh != "":
			return zh
	return str(event_option.get("text_en", ""))


static func option_effects(p_id: String, p_index: int) -> Array:
	_ensure()
	var event_options: Array = event(p_id).get("options", [])
	if p_index < 0 or p_index >= event_options.size():
		return []
	return (event_options[p_index] as Dictionary).get("effects", [])


static func _pick(p_id: String, p_field: String) -> String:
	## Bilingual cell picker: the current language first, the other one rather than
	## an empty label (the same fallback rule Loc.t() uses for half-filled entries).
	_ensure()
	var battle_event := event(p_id)
	if Loc.prefer_zh():
		var zh := str(battle_event.get(p_field + "_zh", ""))
		if zh != "":
			return zh
		return str(battle_event.get(p_field + "_en", ""))
	var en := str(battle_event.get(p_field + "_en", ""))
	if en != "":
		return en
	return str(battle_event.get(p_field + "_zh", ""))


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func status_text() -> String:
	_ensure()
	if not _loaded:
		return "events: NOT loaded (%s)" % (_error if _error != "" else "never tried")
	return "events: %d event(s) from %s, %d problem(s)" \
		% [_order.size(), BalanceRun.EVENTS_FILE.get_file(), _problems.size()]


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game: what the file gave us, and whether the
	## promises the roadmap makes on top of it still hold (an option that parses to
	## zero effects would render a dead button).
	print("[Events] --- event roster from %s ---" % BalanceRun.EVENTS_FILE)
	if not is_loaded():
		print("[Events] " + status_text() + " | FAIL")
		print("[Events] -> adventure event nodes will be refused by ChapterMap")
		for problem in _problems:
			print("[Events] warning: " + problem)
		return
	var ok := true
	for id in _order:
		var battle_event := event(id)
		var event_options: Array = battle_event.get("options", [])
		var good: bool = (title(id) != "" and text(id) != "" and event_options.size() >= 2)
		for option in event_options:
			if (option as Dictionary).get("effects", []).is_empty():
				good = false
		ok = ok and good
		print("[Events] %-18s %-24s %d option(s) | %s"
			% [id, title(id), event_options.size(), "OK" if good else "FAIL"])
	for problem in _problems:
		print("[Events] warning: " + problem)
		ok = false
	print("[Events] self-check %s" % ("PASSED" if ok else "FAILED"))
