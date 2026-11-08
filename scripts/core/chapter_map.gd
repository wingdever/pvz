class_name ChapterMap
extends RefCounted
## [P31-A] ONE chapter of the adventure run: a layered, branching node graph
## loaded from res://data/adventure/chapter_<n>.json (design: README
## 「游戏流程重构设计（P31）」).
##
## The file shape (data, so levels stay untouched and only get REFERENCED):
##
##   { "id": "chapter_1", "name": "Front Yard", "name_zh": "前院攻势",
##     "starting_slots": 4,
##     "layers": [
##       [ {"id":"n1","type":"battle","level":"Lawn_1_1","next":["n2","n3"]} ],
##       [ {"id":"n2","type":"shop","stock":[...]},
##         {"id":"n3","type":"event","event":"e_fallen_seed","next":["n4"]} ],
##       ...
##     ] }
##
## A layer is one COLUMN of the roadmap; edges only ever point to the next
## column(s), which is what makes the graph a forward path map instead of a maze.
## Node types: battle / boss / shop / event / treasure / rest. `boss` is a
## battle node with a flag for the screen and the end-of-chapter hook; `shop`
## carries an optional per-node `stock` ([{kind,id,price}] — absent = the global
## BalanceShop.SHOP_STOCK until P31-B makes every node explicit).
##
## Like Garden and Profile this is INSTANCE based with scratch copies for the
## self-check, so nothing here can ever touch a save file or the real chapter.

const TYPES := ["battle", "boss", "shop", "event", "treasure", "rest"]
## The types that run a real battle (and therefore pay out the three-stage reward).
const BATTLE_TYPES := ["battle", "boss"]

var source: String = "<defaults>"
var loaded: bool = false
var problems: Array[String] = []

var chapter_id: String = ""
var chapter_name: String = ""
var chapter_name_zh: String = ""
## 0 = "the chapter says nothing" -> BalanceRun.RUN_SQUAD_SLOTS decides.
var starting_slots: int = 0
## layer index -> Array[String] of node ids (declaration order = draw order).
var layers: Array = []
## node id -> the parsed row: {id, type, level, event, next: Array[String],
## stock: Array, name}. Treat it as READ-ONLY (like Garden.slot_at).
var nodes: Dictionary = {}


# ---------------------------------------------------------------- construction
static func load_from_file(path: String) -> ChapterMap:
	## Returns a loaded map, or an UNLOADED one with the reason in `problems`
	## (never null, never fatal — the menu greys the adventure out on a bad file).
	var m := ChapterMap.new()
	m.load_path(path)
	return m


func load_path(path: String) -> bool:
	problems.clear()
	source = path
	if not FileAccess.file_exists(path):
		return _reject("file not found: " + path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _reject("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
	var text := f.get_as_text()
	f.close()
	return parse_text(text, path)


func _reject(msg: String) -> bool:
	problems.append(msg)
	loaded = false
	return false


func parse_text(text: String, p_source: String) -> bool:
	problems.clear()
	source = p_source
	loaded = false
	layers = []
	nodes = {}
	starting_slots = 0

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return _reject("JSON parse error at line %d: %s"
			% [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _reject("root element must be a JSON object")
	var d: Dictionary = json.data

	chapter_id = str(d.get("id", p_source.get_file().get_basename()))
	chapter_name = str(d.get("name", chapter_id))
	chapter_name_zh = str(d.get("name_zh", ""))
	if d.has("starting_slots"):
		var s := int(d["starting_slots"])
		if s <= 0:
			problems.append("starting_slots %d invalid (kept 0 = use the Balance default)" % s)
		else:
			starting_slots = s

	var raw_layers: Variant = d.get("layers", null)
	if typeof(raw_layers) != TYPE_ARRAY or (raw_layers as Array).is_empty():
		return _reject("'layers' must be a non-empty array of node arrays")
	for li in (raw_layers as Array).size():
		var raw_layer: Variant = (raw_layers as Array)[li]
		var ids: Array[String] = []
		if typeof(raw_layer) != TYPE_ARRAY:
			problems.append("layer %d is not an array (skipped)" % li)
			layers.append(ids)
			continue
		for entry in (raw_layer as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				problems.append("layer %d: a node is not an object (ignored)" % li)
				continue
			var node := _parse_node(entry as Dictionary, li)
			if node.is_empty():
				continue
			var id := str(node["id"])
			if nodes.has(id):
				problems.append("layer %d: duplicate node id '%s' (ignored)" % [li, id])
				continue
			nodes[id] = node
			ids.append(id)
		layers.append(ids)

	_resolve_edges()
	_validate()
	loaded = not nodes.is_empty()
	if not loaded:
		problems.append("no usable nodes: chapter rejected")
	return loaded


func _parse_node(e: Dictionary, p_layer: int) -> Dictionary:
	var id := str(e.get("id", "")).strip_edges()
	if id == "":
		problems.append("layer %d: a node has no id (ignored)" % p_layer)
		return {}
	var type_id := str(e.get("type", "")).to_lower()
	if not TYPES.has(type_id):
		problems.append("node '%s': unknown type '%s' (ignored)" % [id, type_id])
		return {}
	var node := {
		"id": id,
		"type": type_id,
		"level": str(e.get("level", "")),
		"event": str(e.get("event", "")),
		"next": [] as Array[String],
		"stock": [] as Array,
	}
	var raw_next: Variant = e.get("next", [])
	if typeof(raw_next) == TYPE_ARRAY:
		for item in (raw_next as Array):
			var target := str(item)
			if target != "" and not (node["next"] as Array).has(target):
				(node["next"] as Array).append(target)
	elif typeof(raw_next) == TYPE_STRING and str(raw_next) != "":
		problems.append("node '%s': 'next' must be an array (ignored)" % id)
	if BATTLE_TYPES.has(type_id):
		if str(node["level"]) == "":
			problems.append("node '%s' is a %s but names no level" % [id, type_id])
		elif not FileAccess.file_exists("%s/%s.json" % [Balance.LEVEL_DIR, str(node["level"])]):
			problems.append("node '%s': level file '%s' not found in %s"
				% [id, str(node["level"]), Balance.LEVEL_DIR])
	if type_id == "event" and str(node["event"]) == "":
		problems.append("node '%s' is an event but names no event id" % id)
	if e.has("stock"):
		var raw_stock: Variant = e["stock"]
		if typeof(raw_stock) == TYPE_ARRAY:
			node["stock"] = raw_stock
		else:
			problems.append("node '%s': 'stock' must be an array (ignored)" % id)
	return node


func _resolve_edges() -> void:
	## Edges are names first and indexes second: a typo must not create a phantom
	## corridor, so every unknown target is dropped (loudly) before the graph runs.
	for id in nodes.keys():
		var node: Dictionary = nodes[id]
		var clean: Array[String] = []
		for target in (node["next"] as Array):
			var t := str(target)
			if not nodes.has(t):
				problems.append("node '%s': next -> unknown node '%s' (edge dropped)" % [id, t])
				continue
			clean.append(t)
		node["next"] = clean


func _validate() -> void:
	## The two structural promises the roadmap screen leans on: everything is
	## REACHABLE from the entries, and the BOSS is.
	var seen := reachable_ids()
	for id in nodes.keys():
		if not seen.has(id):
			problems.append("node '%s' is not reachable from the chapter entry" % id)
	var bosses: Array[String] = []
	for id in nodes.keys():
		if str((nodes[id] as Dictionary).get("type", "")) == "boss":
			bosses.append(str(id))
	if bosses.is_empty():
		problems.append("the chapter has no boss node (the run can never end)")
	for id in bosses:
		if not seen.has(id):
			problems.append("boss node '%s' is not reachable" % id)


# ---------------------------------------------------------------- queries
func node_count() -> int:
	return nodes.size()


func node_at(id: String) -> Dictionary:
	return nodes.get(id, {})


func next_of(id: String) -> Array:
	var node := node_at(id)
	if node.is_empty():
		return []
	return node["next"]


func entry_ids() -> Array:
	var out: Array = []
	if layers.is_empty():
		return out
	for id in (layers[0] as Array):
		out.append(str(id))
	return out


func layer_of(id: String) -> int:
	for li in layers.size():
		if (layers[li] as Array).has(id):
			return li
	return -1


func last_layer_index() -> int:
	return layers.size() - 1


func is_last_layer(id: String) -> bool:
	return layer_of(id) == last_layer_index()


func squad_slots() -> int:
	return starting_slots if starting_slots > 0 else BalanceRun.RUN_SQUAD_SLOTS


func reachable_ids() -> Dictionary:
	## id -> true over the forward graph from the entry layer.
	var out: Dictionary = {}
	var queue: Array = entry_ids()
	while not queue.is_empty():
		var id := str(queue.pop_front())
		if out.has(id):
			continue
		out[id] = true
		for target in next_of(id):
			queue.append(str(target))
	return out


func display_name() -> String:
	## [P20] Same rule as LevelData: `name_zh` wins when the game is Chinese and
	## the font can draw it.
	if chapter_name_zh != "" and Loc.prefer_zh():
		return chapter_name_zh
	return chapter_name


func summary_text() -> String:
	if not loaded:
		return "chapter <broken: %s>" % (problems[0] if not problems.is_empty() else "?")
	return "%s: %d nodes in %d layers, entries [%s], squad %d" % [
		chapter_id, node_count(), layers.size(), ", ".join(PackedStringArray(entry_ids())),
		squad_slots()]


# ---------------------------------------------------------------- discovery
static func discover() -> Array:
	## [{chapter_id, path}] in file-name order, everything matching
	## res://data/adventure/chapter_*.json. Directory order is undefined, so the
	## trailing number decides (chapter_2 before chapter_10).
	var out: Array = []
	var dir := DirAccess.open(BalanceRun.ADVENTURE_DIR)
	if dir == null:
		return out
	var files: Array[String] = []
	for f in dir.get_files():
		var name := str(f)
		if name.begins_with(BalanceRun.CHAPTER_GLOB) and name.ends_with(".json"):
			files.append(name)
	files.sort()
	for name in files:
		var base := str(name).get_basename()
		var number := base.substr(BalanceRun.CHAPTER_GLOB.length()).to_int()
		out.append({"chapter_id": base, "path": "%s/%s" % [BalanceRun.ADVENTURE_DIR, name],
			"order": number})
	out.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
	return out


static func load_first() -> ChapterMap:
	## The chapter the game boots with: the lowest-numbered loadable file. Returns
	## an UNLOADED map when there is none (adventure greys out, no crash).
	for entry in discover():
		var m := load_from_file(str((entry as Dictionary)["path"]))
		if m.loaded:
			return m
		print("[Chapter] %s" % str((entry as Dictionary)["path"]) + " unusable: " \
			+ "; ".join(PackedStringArray(m.problems)))
	var empty := ChapterMap.new()
	empty.problems.append("no chapter_*.json found in " + BalanceRun.ADVENTURE_DIR)
	return empty


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## [P31-A] Runs on parsed scratch data only; the real files are only READ.
	print("[Chapter] --- adventure chapters (P31-A) ---")
	var found := discover()
	var ok := not found.is_empty()
	print("[Chapter] %d chapter file(s) in %s | %s" % [found.size(), BalanceRun.ADVENTURE_DIR,
		"OK" if ok else "FAIL"])
	var first := load_first()
	ok = ok and first.loaded
	print("[Chapter] boot chapter: " + first.summary_text() + " | %s" \
		% ("OK" if first.loaded else "FAIL"))
	for line in first.problems:
		print("[Chapter]   note: " + line)
	## Every declared node reachable, a boss exists, and battle nodes name a real
	## level file - the structural promises the roadmap and the flow rely on.
	var struct_ok := true
	for id in first.nodes.keys():
		var node: Dictionary = first.nodes[id]
		if not first.reachable_ids().has(id):
			struct_ok = false
		if BATTLE_TYPES.has(str(node["type"])):
			var lvl := str(node["level"])
			if lvl == "" or not FileAccess.file_exists("%s/%s.json" % [Balance.LEVEL_DIR, lvl]):
				struct_ok = false
	var has_boss := false
	for id in first.nodes.keys():
		if str((first.nodes[id] as Dictionary)["type"]) == "boss":
			has_boss = true
	ok = ok and struct_ok and has_boss
	print("[Chapter] %d/%d nodes reachable, every battle names a real level, boss present = %s | %s"
		% [first.reachable_ids().size(), first.node_count(), str(struct_ok and has_boss),
		   "OK" if (struct_ok and has_boss) else "FAIL"])
	## A broken file must FAIL LOUD instead of half-loading (the roadmap trusts
	## `loaded` as "this graph is walkable").
	var broken := ChapterMap.new()
	var broken_ok: bool = not broken.parse_text('{"layers":[[{"id":"a","type":"warp"}]]}', "<probe>")
	print("[Chapter] unknown node type -> chapter refused: " + str(broken_ok) + " | %s" \
		% ("OK" if broken_ok else "FAIL"))
	ok = ok and broken_ok
	print("[Chapter] self-check %s" % ("PASSED" if ok else "FAILED"))
