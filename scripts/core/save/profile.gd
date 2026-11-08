class_name Profile
extends RefCounted
## [P14] What the player OWNS: money, the warehouse and the backpack.
##
## Kept apart from Garden on purpose:
##   garden.json   "which plants are mine"  (the roster, with hp / level / rarity)
##   profile.json  "what stuff is mine"     (money + items)
##
## The two containers
##   WAREHOUSE  used outside a battle - this is where everything actually lives
##   BACKPACK   used during a battle - drops land here, and the whole backpack is
##              merged into the warehouse when the battle settles
##
## Money and coins are deliberately separate. A coin is an ITEM with a nominal
## value; picking one up does NOT change money. The player has to sell it (the
## SELL button on the warehouse page), which is the only way money ever grows.
##
## Like Garden this class is INSTANCE based so self_check() can run on scratch
## copies and never touch the real save file; Profile.live is the one instance the
## game plays with.

const CONTAINER_WAREHOUSE := "warehouse"
const CONTAINER_BACKPACK := "backpack"

## [P37] `preload` rather than a global class name: see safe_io.gd for why.
const SafeIO := preload("res://scripts/core/save/safe_io.gd")

static var live: Profile = null

var source: String = "<defaults>"
var loaded: bool = false
var problems: Array[String] = []
var money: int = 0
## item_id -> count. A scroll additionally has an entry in `durability`.
var warehouse: Dictionary = {}
var backpack: Dictionary = {}
## item_id -> current durability of the scroll in use (scrolls only)
var durability: Dictionary = {}


# ---------------------------------------------------------------- construction
static func load_or_create() -> Profile:
	if live == null:
		live = Profile.new()
	live.load_from_disk()
	return live


func apply_defaults() -> void:
	## The starting kit the designer asked for: one peashooter, one scroll for it,
	## and nothing else. Every other card has to be earned.
	money = 0
	warehouse = {}
	backpack = {}
	durability = {}
	add_item(Balance.ITEM_SCROLL_PEASHOOTER, 1, CONTAINER_WAREHOUSE, false)


func _reject(msg: String) -> bool:
	problems.append(msg)
	var keep := source
	apply_defaults()
	source = keep
	problems.append("rejected -> rebuilt the starting kit")
	return false


# ---------------------------------------------------------------- loading
func load_from_disk() -> bool:
	problems.clear()
	source = Balance.PROFILE_PATH
	if not FileAccess.file_exists(Balance.PROFILE_PATH):
		apply_defaults()
		loaded = true
		print("[Profile] no profile file yet -> created the starting kit")
		print("[Profile] " + summary_text())
		save_to_disk()
		return true
	var f := FileAccess.open(Balance.PROFILE_PATH, FileAccess.READ)
	if f == null:
		## [P37] The file is there but cannot be read: park it before the defaults
		## are written over the top, or "unreadable" becomes "lost".
		SafeIO.keep_broken(Balance.PROFILE_PATH)
		return _reject("cannot open %s (error %d)" % [Balance.PROFILE_PATH, FileAccess.get_open_error()])
	var text := f.get_as_text()
	f.close()
	var ok := parse_text(text, Balance.PROFILE_PATH)
	if ok:
		print("[Profile] loaded " + Balance.PROFILE_PATH)
		print("[Profile] " + summary_text())
		return true
	for line in problems:
		print("[Profile]   " + line)
	print("[Profile] " + summary_text())
	## [P37] save_to_disk() below would otherwise bury the half-written bytes it just
	## refused, and the player's real progress goes with them (OPTIMIZATIONS A1).
	SafeIO.keep_broken(Balance.PROFILE_PATH)
	save_to_disk()
	return false


func parse_text(text: String, p_source: String) -> bool:
	problems.clear()
	apply_defaults()
	source = p_source
	loaded = false

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return _reject("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _reject("root element must be a JSON object")
	var d: Dictionary = json.data

	money = maxi(0, int(d.get("money", 0)))
	warehouse = _parse_container(d.get("warehouse", {}))
	backpack = _parse_container(d.get("backpack", {}))
	durability = {}
	var raw_dur: Variant = d.get("durability", {})
	if typeof(raw_dur) == TYPE_DICTIONARY:
		for key in (raw_dur as Dictionary).keys():
			var id := str(key)
			if Balance.item_kind(id) != "scroll":
				problems.append("durability for non-scroll '%s' (ignored)" % id)
				continue
			durability[id] = clampi(int((raw_dur as Dictionary)[key]), 0, Balance.item_max_durability(id))

	# a scroll in the warehouse without a durability entry starts full
	for id in warehouse.keys():
		var key := str(id)
		if Balance.item_kind(key) == "scroll" and not durability.has(key):
			durability[key] = Balance.item_max_durability(key)
	loaded = true
	return true


func _parse_container(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("an inventory container is not an object (ignored)")
		return out
	for key in (raw as Dictionary).keys():
		var id := str(key)
		var count := int((raw as Dictionary)[key])
		if count <= 0:
			continue
		if not Balance.is_item(id):
			problems.append("unknown item '%s' (ignored)" % id)
			continue
		out[id] = count
	return out


func to_json_text() -> String:
	var d := {
		"version": Balance.PROFILE_VERSION,
		"money": money,
		"_comment": "money is earned by SELLING coins in the warehouse page. warehouse = outside a battle, backpack = during one (merged into the warehouse when the battle settles).",
		"warehouse": _sorted_copy(warehouse),
		"backpack": _sorted_copy(backpack),
		"durability": _sorted_copy(durability),
	}
	return JSON.stringify(d, "  ")


func _sorted_copy(p_src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		if p_src.has(key):
			out[key] = int(p_src[key])
	for key in p_src.keys():
		var extra := str(key)
		if not out.has(extra):
			out[extra] = int(p_src[key])
	return out


func save_to_disk() -> bool:
	if source.begins_with("<"):
		push_warning("[Profile] refusing to save a scratch profile (" + source + ")")
		return false
	## [P37] Through SafeIO: the previous profile stays readable until the new text
	## has been written in full and swapped in (OPTIMIZATIONS A1).
	return SafeIO.write_text_atomic(Balance.PROFILE_PATH, to_json_text())


func snapshot() -> Dictionary:
	## [P35] A deep copy of exactly what save_to_disk() writes, so a caller can put the
	## player's data back after exercising the real paths (the startup probes do). The
	## field list is copied from to_json_text(), not from memory.
	return {
		"money": money,
		"warehouse": warehouse.duplicate(true),
		"backpack": backpack.duplicate(true),
		"durability": durability.duplicate(true),
	}


func restore(p_snap: Dictionary) -> void:
	## [P35] The other half of snapshot(). Both ends duplicate, so one snapshot stays
	## reusable: restoring twice cannot hand the same dictionary out twice, and an
	## empty snapshot is a no-op rather than a wipe.
	if p_snap.is_empty():
		return
	money = int(p_snap.get("money", money))
	warehouse = (p_snap.get("warehouse", {}) as Dictionary).duplicate(true)
	backpack = (p_snap.get("backpack", {}) as Dictionary).duplicate(true)
	durability = (p_snap.get("durability", {}) as Dictionary).duplicate(true)


# ---------------------------------------------------------------- item access
func _container(p_which: String) -> Dictionary:
	if p_which == CONTAINER_BACKPACK:
		return backpack
	return warehouse


func count_of(item_id: String, p_which: String = CONTAINER_WAREHOUSE) -> int:
	return int(_container(p_which).get(item_id, 0))


func has_item(item_id: String, p_amount: int = 1, p_which: String = CONTAINER_WAREHOUSE) -> bool:
	return count_of(item_id, p_which) >= maxi(1, p_amount)


func add_item(item_id: String, p_amount: int = 1, p_which: String = CONTAINER_WAREHOUSE,
		p_log: bool = true) -> void:
	if p_amount <= 0 or not Balance.is_item(item_id):
		return
	var box := _container(p_which)
	box[item_id] = int(box.get(item_id, 0)) + p_amount
	if Balance.item_kind(item_id) == "scroll" and not durability.has(item_id):
		durability[item_id] = Balance.item_max_durability(item_id)
	if p_log:
		print("[Item] +%d %s -> %s" % [p_amount, Balance.item_name(item_id), p_which])


func take_item(item_id: String, p_amount: int = 1,
		p_which: String = CONTAINER_WAREHOUSE) -> bool:
	## All or nothing: a refused take never half-consumes a stack.
	var want := maxi(1, p_amount)
	if count_of(item_id, p_which) < want:
		return false
	var box := _container(p_which)
	var left := int(box.get(item_id, 0)) - want
	if left > 0:
		box[item_id] = left
	else:
		box.erase(item_id)
	return true


func loadout_for_battle() -> Array[String]:
	## [P15] Everything of kind "battle" (the energy bean) is carried from the
	## warehouse into the backpack when a battle starts: the rule stays "the backpack
	## is what you use during a battle", and this is how the bean gets in there.
	var lines: Array[String] = []
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		if Balance.item_kind(key) != "battle":
			continue
		var n := count_of(key, CONTAINER_WAREHOUSE)
		if n <= 0:
			continue
		take_item(key, n, CONTAINER_WAREHOUSE)
		add_item(key, n, CONTAINER_BACKPACK, false)
		lines.append("%d x %s" % [n, Balance.item_name(key)])
	return lines


func merge_backpack_into_warehouse() -> Array[String]:	## Called when a battle settles: the backpack is emptied into the warehouse.
	var lines: Array[String] = []
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		var n := count_of(key, CONTAINER_BACKPACK)
		if n <= 0:
			continue
		take_item(key, n, CONTAINER_BACKPACK)
		add_item(key, n, CONTAINER_WAREHOUSE, false)
		lines.append("%d x %s" % [n, Balance.item_name(key)])
	# anything not in ITEM_ORDER (future items) still moves
	for key in backpack.keys():
		var extra := str(key)
		var n2 := count_of(extra, CONTAINER_BACKPACK)
		if n2 <= 0:
			continue
		take_item(extra, n2, CONTAINER_BACKPACK)
		add_item(extra, n2, CONTAINER_WAREHOUSE, false)
		lines.append("%d x %s" % [n2, Balance.item_name(extra)])
	return lines


func backpack_text() -> String:
	var parts: PackedStringArray = []
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		var n := count_of(key, CONTAINER_BACKPACK)
		if n > 0:
			parts.append("%s x%d" % [Balance.item_name(key), n])
	if parts.is_empty():
		return "empty"
	return ", ".join(parts)


func backpack_total() -> int:
	var total := 0
	for key in backpack.keys():
		total += int(backpack[key])
	return total


func _container_tiles(p_which: String) -> Array:
	## One entry per item kind the container holds.
	var rows: Array = []
	var selling: bool = p_which == Profile.CONTAINER_WAREHOUSE
	## [P95] Balance.item_ids(), not ITEM_ORDER.
	for id in Balance.item_ids():
		var key := str(id)
		var n := count_of(key, p_which)
		if n <= 0:
			continue
		var kind := Balance.item_kind(key)
		var value_key := "item.panel.use"
		var value_text := "item value text"
		var note := ""
		if kind == "coin" and selling:
			value_key = "item.panel.sell"
			value_text = str(sell_price(key, n))
		elif kind == "scroll":
			value_key = "item.panel.durability"
			value_text = durability_text(key)
			note = durability_text(key)
		elif kind == Balance.ITEM_KIND_PLANT_CHEST:
			var inside := Balance.plant_name(Balance.item_plant(key))
			value_key = "item.panel.plant_chest"
			value_text = inside
			note = inside
		var stack_value := 0
		if selling:
			stack_value = sell_price(key, n)
		rows.append({
			"id": key,
			"kind": kind,
			"title": Balance.item_name(key),
			"art": Balance.item_art(key),
			"badge": Loc.tf("item.tile.count", [n]),
			"note": note,
			"dimmed": false,
			"badge_color": BalanceUI.COLOR_TEXT,
			"desc": Balance.item_hint(key),
			"kind_label": Balance.item_kind_label(kind),
			"count_text": "x%d" % n,
			"count": n,
			"value_key": value_key,
			"value_text": value_text,
			"stack_value": stack_value,
		})
	return rows


# ---------------------------------------------------------------- scrolls
func durability_of(item_id: String) -> int:
	if Balance.item_kind(item_id) != "scroll":
		return 0
	return int(durability.get(item_id, Balance.item_max_durability(item_id)))


func durability_text(item_id: String) -> String:
	return "%d/%d" % [durability_of(item_id), Balance.item_max_durability(item_id)]

func has_scroll_for(plant_id: String) -> bool:
	var item := Balance.scroll_item_for(plant_id)
	if item == "":
		return false
	return count_of(item) > 0 and durability_of(item) > 0


# ---------------------------------------------------------------- garden
func fertilizer_count() -> int:
	return count_of("fertilizer")


# ---------------------------------------------------------------- selling
func sell_price(item_id: String, p_amount: int = 1) -> int:
	## Only coins can be sold; everything else returns 0.
	if Balance.item_kind(item_id) != "coin":
		return 0
	return Balance.item_price(item_id) * maxi(1, p_amount)


func sell(item_id: String, p_amount: int = 1) -> Dictionary:
	## Coin stack -> money. Returns {ok, message} like the garden care actions.
	var want := maxi(1, p_amount)
	if Balance.item_kind(item_id) != "coin":
		return {"ok": false, "message": "%s cannot be sold" % Balance.item_name(item_id)}
	if not has_item(item_id, want, CONTAINER_WAREHOUSE):
		return {"ok": false, "message": "No %s left to sell" % Balance.item_name(item_id)}
	var gain := sell_price(item_id, want)
	take_item(item_id, want, CONTAINER_WAREHOUSE)
	money += gain
	return {"ok": true, "message": "Sold %d x %s for %d money (money %d)"
		% [want, Balance.item_name(item_id), gain, money]}


func sell_all_coins() -> Dictionary:
	var sold := 0
	var gain := 0
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		var n := count_of(key, CONTAINER_WAREHOUSE)
		if n <= 0 or Balance.item_kind(key) != "coin":
			continue
		gain += sell_price(key, n)
		sold += n
		take_item(key, n, CONTAINER_WAREHOUSE)
	money += gain
	if sold == 0:
		return {"ok": false, "message": "Nothing to sell - coins are the only thing the warehouse buys"}
	return {"ok": true, "message": "Sold %d coin(s) for %d money (money %d)" % [sold, gain, money]}


# ---------------------------------------------------------------- text
func money_text() -> String:
	return str(money)


func summary_text() -> String:
	var line := "money %d" % money
	line += " | warehouse " + str(warehouse.size()) + " stacks"
	line += " | backpack " + str(backpack_total()) + " item(s)"
	return line


func warehouse_lines() -> Array[String]:
	## One line per owned item, in ITEM_ORDER, for the warehouse page and logs.
	var lines: Array[String] = []
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		var n := count_of(key, CONTAINER_WAREHOUSE)
		if n <= 0:
			continue
		var line := "%s  x%d" % [Balance.item_name(key), n]
		if Balance.item_kind(key) == "scroll":
			line += "   durability " + durability_text(key)
		if Balance.item_kind(key) == "coin":
			line += "   SELL %d" % sell_price(key, n)
		lines.append(line)
	return lines


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Runs on scratch copies only: the player's profile.json is never touched.
	print("[Profile] --- money / warehouse / backpack (P14) ---")
	var ok := true

	var start := Profile.new()
	start.apply_defaults()
	print("[Profile] starting kit: " + start.summary_text())
	var kit_ok: bool = start.money == 0
	kit_ok = kit_ok and start.count_of(Balance.ITEM_SCROLL_PEASHOOTER) == 1
	kit_ok = kit_ok and start.count_of(Balance.ITEM_SCROLL_SUNFLOWER) == 0
	kit_ok = kit_ok and start.count_of(Balance.ITEM_SCROLL_WALLNUT) == 0
	ok = ok and kit_ok
	print("[Profile] starting kit = 1 peashooter scroll, no money, no other scroll: "
		+ str(kit_ok) + " | " + ("OK" if kit_ok else "FAIL"))

	# a coin is an item, not money: it only becomes money when it is SOLD
	var sale := Profile.new()
	sale.apply_defaults()
	sale.add_item(Balance.ITEM_COIN_GOLD, 5, Profile.CONTAINER_BACKPACK, false)
	var before_sale: int = sale.money
	var carried: bool = sale.money == before_sale and sale.count_of(Balance.ITEM_COIN_GOLD,
		Profile.CONTAINER_BACKPACK) == 5
	var merged: Array[String] = sale.merge_backpack_into_warehouse()
	var merge_ok: bool = carried and merged.size() == 1
	merge_ok = merge_ok and sale.count_of(Balance.ITEM_COIN_GOLD) == 5
	merge_ok = merge_ok and sale.backpack_total() == 0
	var sale_result: Dictionary = sale.sell(Balance.ITEM_COIN_GOLD, 5)
	var sale_ok: bool = merge_ok and bool(sale_result["ok"]) and sale.money == 500
	sale_ok = sale_ok and sale.count_of(Balance.ITEM_COIN_GOLD) == 0
	ok = ok and sale_ok
	print("[Profile] 5 gold coins (backpack -> warehouse) sell for 500 money, not before: "
		+ str(sale_ok) + " | " + ("OK" if sale_ok else "FAIL"))

	# denomination values
	var worth_ok: bool = Balance.item_price(Balance.ITEM_COIN_SILVER) == 10
	worth_ok = worth_ok and Balance.item_price(Balance.ITEM_COIN_GOLD) == 100
	worth_ok = worth_ok and Balance.item_price(Balance.ITEM_COIN_DIAMOND) == 1000
	worth_ok = worth_ok and sale.sell_price(Balance.ITEM_COIN_DIAMOND, 2) == 2000
	ok = ok and worth_ok
	print("[Profile] silver 10 / gold 100 / diamond 1000 = " + str(worth_ok)
		+ " | " + ("OK" if worth_ok else "FAIL"))

	# selling is all-or-nothing and refuses non-coins
	var refuse := Profile.new()
	refuse.apply_defaults()
	var sell_bad: Dictionary = refuse.sell(Balance.ITEM_FERTILIZER, 1)
	var sell_empty: Dictionary = refuse.sell(Balance.ITEM_COIN_SILVER, 1)
	var refuse_ok: bool = not bool(sell_bad["ok"]) and not bool(sell_empty["ok"])
	refuse_ok = refuse_ok and refuse.take_item(Balance.ITEM_SCROLL_PEASHOOTER, 3) == false
	refuse_ok = refuse_ok and refuse.count_of(Balance.ITEM_SCROLL_PEASHOOTER) == 1
	ok = ok and refuse_ok
	print("[Profile] fertilizer is not sellable, empty stacks refuse, take is all-or-nothing: "
		+ str(refuse_ok) + " | " + ("OK" if refuse_ok else "FAIL"))

	# save -> load round trip keeps money, both containers and durability
	var saved := Profile.new()
	saved.apply_defaults()
	saved.money = 1370
	saved.add_item(Balance.ITEM_COIN_SILVER, 3, Profile.CONTAINER_WAREHOUSE, false)
	saved.add_item(Balance.ITEM_FERTILIZER, 2, Profile.CONTAINER_BACKPACK, false)
	saved.durability[Balance.ITEM_SCROLL_PEASHOOTER] = 1
	var reloaded := Profile.new()
	var parsed: bool = reloaded.parse_text(saved.to_json_text(), "<probe>")
	var trip_ok: bool = parsed and reloaded.money == 1370
	trip_ok = trip_ok and reloaded.count_of(Balance.ITEM_COIN_SILVER) == 3
	trip_ok = trip_ok and reloaded.count_of(Balance.ITEM_FERTILIZER, Profile.CONTAINER_BACKPACK) == 2
	trip_ok = trip_ok and reloaded.durability_of(Balance.ITEM_SCROLL_PEASHOOTER) == 1
	ok = ok and trip_ok
	print("[Profile] save -> load keeps money 1370, both containers and durability 1: "
		+ str(trip_ok) + " | " + ("OK" if trip_ok else "FAIL"))

	# a broken file rebuilds the starting kit instead of crashing
	var broken := Profile.new()
	var broken_ok: bool = not broken.parse_text("{ not json", "<probe>")
	broken_ok = broken_ok and broken.count_of(Balance.ITEM_SCROLL_PEASHOOTER) == 1
	broken_ok = broken_ok and broken.count_of(Balance.ITEM_COIN_GOLD) == 0
	ok = ok and broken_ok
	print("[Profile] broken json rejected, starting kit rebuilt: " + str(broken_ok)
		+ " | " + ("OK" if broken_ok else "FAIL"))

	# unknown items are dropped, and a scroll without a durability entry is full
	var mixed := Profile.new()
	var mixed_ok: bool = mixed.parse_text('{"money":40,"warehouse":{"coin_silver":2,"unobtainium":9,"scroll_wallnut":1}}', "<probe>")
	mixed_ok = mixed_ok and mixed.count_of(Balance.ITEM_COIN_SILVER) == 2
	mixed_ok = mixed_ok and not mixed.warehouse.has("unobtainium")
	mixed_ok = mixed_ok and mixed.durability_of(Balance.ITEM_SCROLL_WALLNUT) == Balance.SCROLL_MAX_DURABILITY
	ok = ok and mixed_ok
	print("[Profile] unknown item dropped, scroll durability defaults to full: " + str(mixed_ok)
		+ " | " + ("OK" if mixed_ok else "FAIL"))

	print("[Profile] self-check %s" % ("PASSED" if ok else "FAILED"))
