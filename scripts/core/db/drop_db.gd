extends RefCounted
## [P83] WHAT A DYING ZOMBIE MAY LEAVE BEHIND - the reader for `data/drops.csv`.
##
## The numbers used to live in three `Balance.*_DROP_CHANCE` constants (P14). The owner
## asked for them to move: "掉落率应当在数据表中说明，一个怪物在被击败后可能掉落的物品".
## `data/drops.csv` is now the only place a drop chance is written; `Balance` keeps the
## same three numbers as the fallback for the day the sheet cannot be read, exactly like
## `Balance.plant_def()` is the fallback for `units.csv`.
##
## DELIBERATELY WITHOUT `class_name`, DELIBERATELY static - same reasons as `SafeIO` (P37)
## and `Rewards` (P61): a brand-new global class is invisible to `godot --headless` until
## the editor rescans the project, and being provable headlessly is the whole point of an
## extraction. Consumers preload this file: `const DropDB := preload("res://scripts/core/drop_db.gd")`.
##
## WHAT THE COLUMNS MEAN:
##   僵尸   a zombie type id (`zombie`, `zombie_cone`, `snow_goblin`...) or `*` = "every
##          zombie that has no rows of its own". A type with rows of its own does NOT also
##          roll the `*` rows - the row set replaces the default, it does not add to it.
##   物品   an item id the item sheet (`data/items.csv`) knows
##   概率   0..1; one `randf() < 概率` per row, and the rows are INDEPENDENT of each other
##   数量   how many to hand out when that row lands
##   专属   `是` = this row is the zombie's IDENTITY, not luck: if a type has any
##          exclusive row, ONLY those rows are rolled - BALANCE 8.2 "先结算专属掉落。
##          如果专属触发，不再结算通用掉落". The snow goblin's diamond is that case.
##
## Failure policy: a missing or broken sheet is NOT fatal - the three P14 chances and the
## diamond are rebuilt from `Balance` in `_use_fallback()`, so a player sees no difference.

const PATH := "res://data/drops.csv"

# ---------------------------------------------------------------- sheet columns
# Matched by NAME (see UnitCsv), never by index, so the sheet can grow columns.
const COL_ZOMBIE := "僵尸"
const COL_ITEM := "物品"
const COL_CHANCE := "概率"
const COL_COUNT := "数量"
const COL_EXCLUSIVE := "专属"

const WILDCARD := "*"
const EXCLUSIVE_YES := "是"

const SOURCE_SHEET := "sheet"
const SOURCE_BALANCE := "balance"

## How a landed drop is SHOWN - the language key of the float-up text and the colour it is
## drawn in. An item that is not listed here still drops: it says its own name (through the
## language layer) in the neutral colour, so adding a drop to the sheet never requires
## touching this file. `dy` is the stacking offset, because two drops can land at once.
const POPUP: Dictionary = {
	Balance.ITEM_COIN_SILVER: {"loc": "msg.popup.silver", "color": BalanceUI.COLOR_COIN_SILVER, "dy": 0.0},
	Balance.ITEM_FERTILIZER: {"loc": "msg.popup.fertilizer", "color": BalanceUI.COLOR_FERTILIZER, "dy": -18.0},
	Balance.ITEM_ENERGY_BEAN: {"loc": "msg.popup.energy_bean", "color": BalanceUI.COLOR_PEA, "dy": -36.0},
	Balance.ITEM_COIN_DIAMOND: {"loc": "msg.popup.diamond", "color": BalanceUI.COLOR_COIN_DIAMOND, "dy": 0.0},
}

## The English name a `[Drop]` log line uses. Logs are English (AGENTS §3) and the item
## sheet is not, which is why this is a table here rather than `Balance.item_name()`.
const LABEL: Dictionary = {
	Balance.ITEM_COIN_SILVER: "Silver Coin",
	Balance.ITEM_FERTILIZER: "Fertilizer Bag",
	Balance.ITEM_ENERGY_BEAN: "Energy Bean",
	Balance.ITEM_COIN_DIAMOND: "Diamond",
}

static var _by_type: Dictionary = {}       # type id -> Array[Dictionary] (its own rows)
static var _wildcard: Array = []           # the rows a type without rows of its own rolls
static var _tried: bool = false            # a failed load is not retried on every death
static var _loaded: bool = false
static var _error: String = ""
static var _problems: Array[String] = []
static var _source: String = SOURCE_BALANCE
static var _row_count: int = 0


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Reads the sheet once. Called by Game at boot (and again on the R key); the accessors
	## also `_ensure()`, so a death can never see an empty table and silently drop nothing.
	_tried = true
	_by_type.clear()
	_wildcard = []
	_problems.clear()
	_error = ""
	_row_count = 0
	_source = SOURCE_SHEET

	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		_use_fallback()
		return false

	for entry in table.get("rows", []):
		var raw: Dictionary = entry
		var type_id := UnitCsvManager.cell(raw, COL_ZOMBIE)
		var item_id := UnitCsvManager.cell(raw, COL_ITEM)
		if type_id == "" or item_id == "":
			_problems.append("a row without a %s or a %s (skipped)" % [COL_ZOMBIE, COL_ITEM])
			continue
		var chance := UnitCsvManager.rate_of(UnitCsvManager.cell(raw, COL_CHANCE), -1.0)
		if chance < 0.0:
			_problems.append("%s / %s: %s is not a rate (row skipped)" % [type_id, item_id, COL_CHANCE])
			continue
		var row := {
			"type": type_id,
			"item": item_id,
			"chance": clampf(chance, 0.0, 1.0),
			"count": maxi(1, UnitCsvManager.int_of(UnitCsvManager.cell(raw, COL_COUNT), 1)),
			"exclusive": UnitCsvManager.cell(raw, COL_EXCLUSIVE) == EXCLUSIVE_YES,
		}
		if type_id == WILDCARD:
			_wildcard.append(row)
		else:
			if not _by_type.has(type_id):
				_by_type[type_id] = []
			_by_type[type_id].append(row)
		_row_count += 1

	_loaded = _row_count > 0
	if not _loaded:
		_error = "no usable drop row"
		_use_fallback()
	return _loaded


static func _use_fallback() -> void:
	## The three P14 chances, plus the diamond for whichever zombies the sheet flags with
	## `drops_diamond` - the flag is read rather than a type id hardcoded here, so the
	## fallback cannot drift away from the zombie sheet.
	_source = SOURCE_BALANCE
	_wildcard = [
		{"type": WILDCARD, "item": Balance.ITEM_COIN_SILVER, "chance": Balance.SILVER_DROP_CHANCE, "count": 1, "exclusive": false},
		{"type": WILDCARD, "item": Balance.ITEM_FERTILIZER, "chance": Balance.FERTILIZER_DROP_CHANCE, "count": 1, "exclusive": false},
		{"type": WILDCARD, "item": Balance.ITEM_ENERGY_BEAN, "chance": Balance.ENERGY_BEAN_DROP_CHANCE, "count": 1, "exclusive": false},
	]
	_by_type = {}
	_row_count = _wildcard.size()
	for id in ZombieDB.ids():
		if ZombieDB.has_flag(id, "drops_diamond"):
			_by_type[id] = [{"type": id, "item": Balance.ITEM_COIN_DIAMOND, "chance": 1.0, "count": 1, "exclusive": true}]
			_row_count += 1


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


# ---------------------------------------------------------------- what a death rolls
static func entries_for(p_type_id: String) -> Array:
	## The rows this zombie rolls: its own if the sheet gives it any, otherwise the `*`
	## rows. An empty type id (a unit that is not a zombie at all) gets the `*` rows -
	## that is what P14 did for every non-snow death, and it is what the probes rely on.
	_ensure()
	if _by_type.has(p_type_id):
		return _by_type[p_type_id]
	return _wildcard


static func has_exclusive(p_type_id: String) -> bool:
	## True when this type's payout is its identity rather than luck - then ONLY the
	## exclusive rows are rolled, and the ordinary ones are skipped entirely.
	for entry in entries_for(p_type_id):
		if bool(entry.get("exclusive", false)):
			return true
	return false


# ---------------------------------------------------------------- presentation
static func label(p_item_id: String) -> String:
	## The English word a `[Drop]` line uses; an item this file does not know says its id,
	## which is still English and still points at the row that needs a label.
	return str(LABEL.get(p_item_id, p_item_id))


static func popup(p_item_id: String) -> Dictionary:
	## {loc, color, dy} for the float-up text. Unknown items get no language key (the
	## caller then uses the item's own localized name) and the neutral text colour.
	return POPUP.get(p_item_id, {"loc": "", "color": BalanceUI.COLOR_TEXT, "dy": 0.0})


# ---------------------------------------------------------------- reporting
static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func source() -> String:
	_ensure()
	return _source


static func error_text() -> String:
	return _error if _error != "" else "none"


static func count() -> int:
	_ensure()
	return _row_count


static func type_ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for id in _by_type.keys():
		out.append(str(id))
	return out


static func problems() -> Array[String]:
	return _problems


static func _all_rows() -> Array:
	var out: Array = []
	for id in _by_type.keys():
		out.append_array(_by_type[id])
	out.append_array(_wildcard)
	return out


static func self_check() -> void:
	## One physical line per claim (ARCHITECTURE §5.3). What is worth proving here is the
	## WIRING, not the numbers: every drop must name an item and a zombie the other sheets
	## know, and the exclusive rule must have exactly the users the zombie sheet says it has.
	var ok := true
	_ensure()
	print("[Drops] source = %s, %d row(s) over %d zombie type(s) plus %d wildcard row(s) = %s | %s"
		% [_source, _row_count, _by_type.size(), _wildcard.size(), str(_loaded), "OK" if _loaded else "FAIL"])
	ok = ok and _loaded
	var unknown_items: Array[String] = []
	for entry in _all_rows():
		var item_id := str(entry["item"])
		if not ItemDB.has(item_id):
			unknown_items.append(item_id)
	var items_ok: bool = unknown_items.is_empty()
	print("[Drops] every drop names an item the item sheet knows = %s | %s"
		% [str(items_ok), "OK" if items_ok else "FAIL"])
	ok = ok and items_ok
	var unknown_types: Array[String] = []
	for id in type_ids():
		if not ZombieDB.has(id):
			unknown_types.append(id)
	var types_ok: bool = unknown_types.is_empty()
	print("[Drops] every %s row names a zombie the zombie sheet knows = %s | %s"
		% [COL_ZOMBIE, str(types_ok), "OK" if types_ok else "FAIL"])
	ok = ok and types_ok
	var flagged: Array[String] = []
	for id in ZombieDB.ids():
		if ZombieDB.has_flag(id, "drops_diamond"):
			flagged.append(id)
	var exclusive_types := type_ids().filter(func(i): return has_exclusive(i))
	var same_users: bool = exclusive_types.size() == flagged.size()
	var exclusive_ok: bool = same_users and not has_exclusive(ZombieDB.BASE_ID)
	print("[Drops] the exclusive rule has the same %d user(s) as the zombie sheet's diamond flag, and never the base zombie = %s | %s"
		% [flagged.size(), str(exclusive_ok), "OK" if exclusive_ok else "FAIL"])
	ok = ok and exclusive_ok
	for line in _problems:
		print("[Drops] WARN " + line)
	print("[Drops] self-check %s" % ("PASSED" if ok else "FAILED"))
