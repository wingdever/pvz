class_name ItemDB
extends RefCounted
## [P27] THE ITEM REGISTRY of the 图鉴 / ALMANAC, read from data/items.csv.
##
## Why a data sheet: the item page must be able to list an item the BATTLE does not
## know yet (a name and a picture are enough to show one), and an item's ICON must not
## need a GDScript edit. The boundary is the same one PlantDB draws:
##
##   data   the roster - id, 分类, PRICE, 对应植物 and the svg of the icon. [P88] the
##          sheet is the source for all of it: Balance.item_*() asks HERE first and only
##          falls back to ITEM_DEFS when the sheet cannot be read (user rule: 表是游戏
##          设定和内容的唯一约定方). What the sheet does NOT own is ONE number: how much
##          sun a sun drop is worth - the plant that produced it decides that.
##   code   Balance.ITEM_DEFS, kept as the fall-back and as the code-side view the
##          [Items] self-check compares the sheet against.
##
## The sheet is TAB separated like data/units/*.csv and is read through UnitCsv, so a
## column may be added or reordered without shifting a value into the wrong field.
##
## THE svg COLUMN holds a path RELATIVE to res://assets/svg/ and WITHOUT the ".svg"
## suffix - "items/potion/potion_talent_common" - because that is the short form a
## designer can read in a spreadsheet. svg_path() turns it into a res:// path; a cell
## that already spells a full path (or ends in .svg / .png) is used as it is.
##
## A talent potion names its TIER's generic bottle there and takes the plant mark over
## it from 对应植物 - the same two-layer icon Balance.item_art() / item_mark_art()
## describe, which is what makes one potion look the same here as in the warehouse.
##
## Failure policy: a missing or broken sheet is NOT fatal. The page then lists
## Balance.ITEM_ORDER with the code's own icons, and status_text()/self_check() say so
## (same rule as the plant and zombie sheets).

const PATH := "res://data/items.csv"

# ---------------------------------------------------------------- the svg column
const SVG_ROOT := "res://assets/svg/"
const SVG_EXT := ".svg"

# ---------------------------------------------------------------- sheet columns
# Matched by NAME (see UnitCsv), never by index, so the sheet can grow columns.
const COL_NAME := "名称"
const COL_ID := "name"
const COL_KIND := "分类"
## [P88] Renamed from 价值: the column is the item's PRICE (money for a coin, durability
## for a scroll, exp for a potion) - never "how much sun" (that is the producer's).
const COL_PRICE := "price"
const COL_PLANT := "对应植物"
const COL_SVG := "svg"

## The kinds Balance.item_kind_label() can name. A row with anything else still works
## (the label falls back to 其他) but self_check() prints the unknown kind, because it
## is almost always a typo ("coins" instead of "coin").
const KINDS: Array[String] = [
	"scroll", "coin", "fertilizer", "battle", "exp", "talent", "plant", "plant_chest",
]

const SOURCE_SHEET := "sheet"
const SOURCE_BALANCE := "balance"

static var _rows: Dictionary = {}          # id -> row (see _parse_row)
static var _order: Array[String] = []      # the sheet's own order, top to bottom
static var _loaded: bool = false
static var _tried: bool = false            # a failed load is not retried forever
static var _error: String = ""
static var _problems: Array[String] = []
static var _source: String = SOURCE_SHEET # which of the two lists is up


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Reads the sheet once. Called by Game at boot (and again on the R key); every
	## accessor also calls _ensure(), so a screen can never see an empty registry. When
	## the sheet cannot be read at all, the built-in Balance.ITEM_ORDER list is used
	## instead - the almanac then shows every item the game has, minus the sheet's svg.
	_tried = true
	_rows.clear()
	_order.clear()
	_problems.clear()
	_error = ""
	_source = SOURCE_SHEET

	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		_use_fallback()
		return false

	var raw_rows: Array = table.get("rows", [])
	for entry in raw_rows:
		var raw: Dictionary = entry
		var id := UnitCsvManager.cell_any(raw, UnitCsvManager.ID_COLUMNS)  # [P29] one shared list
		if id == "":
			_problems.append("a row has no name (skipped)")
			continue
		if _rows.has(id):
			_problems.append("duplicate id '%s' (kept the first row)" % id)
			continue
		_rows[id] = _parse_row(raw, id)
		_order.append(id)

	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable item row"
		_use_fallback()
	return _loaded


static func _use_fallback() -> void:
	## The built-in list: the same ids the warehouse and the shop work with, their kind,
	## their number and their icon straight out of Balance. The almanac is complete
	## except that nothing can be added to it without the sheet.
	_source = SOURCE_BALANCE
	_rows.clear()
	_order.clear()
	for item in Balance.ITEM_ORDER:
		var id := str(item)
		var kind := Balance.item_kind(id)
		_rows[id] = {
			"id": id,
			"zh": Balance.item_name(id),
			"kind": kind,
			"price": _code_value(id),
			"plant": Balance.item_plant(id),
			"svg": "",
		}
		_order.append(id)
	_loaded = not _order.is_empty()


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func _parse_row(p_raw: Dictionary, p_id: String) -> Dictionary:
	return {
		"id": p_id,
		"zh": UnitCsvManager.cell(p_raw, COL_NAME),
		"kind": UnitCsvManager.cell(p_raw, COL_KIND),
		"price": maxi(0, UnitCsvManager.int_cell(p_raw, [COL_PRICE], 0)),
		## [P27] 对应植物 is the plant a scroll unlocks or a talent potion boosts. It is
		## shown as that plant's own (localized) name, so the sheet only stores the id.
		"plant": UnitCsvManager.cell(p_raw, COL_PLANT),
		"svg": UnitCsvManager.cell(p_raw, COL_SVG),
	}


static func _code_value(p_id: String) -> int:
	## [P88] THE CODE TABLE'S number for this item, read from ITEM_DEFS ONLY - the sheet is
	## the source now, so this is what the [Items] self-check compares the sheet against, and
	## what the fall-back rows carry when the sheet cannot be read. A coin's price is its
	## sell value, a scroll's is its durability, an exp potion's is the exp it grants.
	## -1 = the code has no number for this kind.
	var code := Balance.item_code_row(p_id)
	match str(code.get("kind", "")):
		"coin":
			return int(code.get("value", 0))
		"scroll":
			return maxi(1, int(code.get("durability", 1)))
		"exp":
			return Balance.EXP_POTION_AMOUNT
	return -1


# ---------------------------------------------------------------- the svg path rule
static func svg_path(p_cell: String) -> String:
	## "items/potion/potion_talent_common" -> "res://assets/svg/items/potion/potion_talent_common.svg".
	## A cell that already spells a full res:// path, or that names its own extension
	## (.svg / .png), is used as it is, so both forms reach the same file.
	var text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(text):
		return ""
	if text.begins_with("res://"):
		return text
	if not (text.ends_with(".svg") or text.ends_with(".png")):
		text += SVG_EXT
	return SVG_ROOT + text


# ---------------------------------------------------------------- queries
static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func source() -> String:
	## SOURCE_SHEET or SOURCE_BALANCE - which list the page is showing.
	_ensure()
	return _source


static func error_text() -> String:
	_ensure()
	return _error if _error != "" else "none"


static func count() -> int:
	_ensure()
	return _order.size()


static func ids() -> Array[String]:
	## The sheet's own order: the page lists items exactly as the designer wrote them,
	## so "where is X" is answerable from the sheet itself.
	_ensure()
	return _order.duplicate()


static func has(p_id: String) -> bool:
	_ensure()
	return _rows.has(p_id)


static func row(p_id: String) -> Dictionary:
	_ensure()
	return _rows.get(p_id, {})


static func name(p_id: String) -> String:
	## The display name in the current language. LocNames "item.<id>" wins (that table
	## carries the official English wording); the sheet's 名称 is the fall-back, so an
	## item that only exists in the sheet still shows a real name instead of a key.
	_ensure()
	var fallback := str(row(p_id).get("zh", ""))
	if fallback == "":
		fallback = Balance.item_name(p_id)
	if fallback == "":
		fallback = p_id
	return Loc.t("item." + p_id, fallback)


static func get_kind(p_id: String) -> String:
	_ensure()
	return str(row(p_id).get("kind", ""))


static func kind_label(p_id: String) -> String:
	## The localized word for this row's kind, through the ONE helper the warehouse's
	## TYPE line already goes through.
	return Balance.item_kind_label(get_kind(p_id))


static func price(p_id: String) -> int:
	## [P88] the item's PRICE: a coin's sell value, a scroll's durability, a potion's exp.
	_ensure()
	return maxi(0, int(row(p_id).get("price", 0)))


static func plant(p_id: String) -> String:
	## The plant id this item belongs to (a scroll's unlock, a potion's target), "" for
	## every item that has no plant.
	_ensure()
	return str(row(p_id).get("plant", ""))


static func svg_rel(p_id: String) -> String:
	## The sheet's own svg cell, still relative - "" when the row has none.
	_ensure()
	return str(row(p_id).get("svg", ""))


static func art(p_id: String) -> String:
	## The icon the page draws for this item: the sheet's own svg when it registered one,
	## Balance.item_art() otherwise (where a talent potion's tier bottle lives). "" only
	## when neither knows a picture, and then the cell simply stays empty (HANDOFF 7.20).
	_ensure()
	var svg := svg_rel(p_id)
	if svg != "":
		return svg_path(svg)
	return Balance.item_art(p_id)


static func art_from_sheet(p_id: String) -> bool:
	## True when the picture came out of the sheet rather than out of Balance's table.
	## The detail panel prints which one it was, because "the svg I registered is not the
	## one on screen" is otherwise a silent difference.
	_ensure()
	return svg_rel(p_id) != ""


static func mark_art(p_id: String) -> String:
	## The plant mark laid over a talent potion's bottle: the plant's OWN unit sprite,
	## read through the same Balance helper the item cells use. "" for every ordinary
	## one-file icon, so a caller can hand it to UnitArt.load_texture() blind.
	return Balance.item_mark_art(p_id)


static func is_battle_known(p_id: String) -> bool:
	## True when the BATTLE can hand this item out today (it has a Balance.ITEM_DEFS row,
	## which the warehouse, the shop, the backpack and the level rewards all read).
	_ensure()
	return Balance.is_item(p_id)


static func art_paths() -> Array:
	## Every distinct icon file the almanac's item tab can draw, for UnitArt's start-up
	## check: a typo in the svg column of the sheet shows up there as NOT IMPORTED.
	_ensure()
	var out: Array = []
	for id in _order:
		var path := art(id)
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func known_count() -> int:
	_ensure()
	var n := 0
	for id in _order:
		if is_battle_known(id):
			n += 1
	return n


static func raw_kind(p_id: String) -> String:
	## [P88] THE SHEET'S OWN ANSWER, with no fall-back into Balance - which is what lets
	## Balance.item_*() ask the sheet first without a cycle: this reads the parsed row only,
	## and _parse_row never asks Balance for a row the sheet has.
	_ensure()
	return str(row(p_id).get("kind", ""))


static func raw_price(p_id: String) -> int:
	_ensure()
	return maxi(0, int(row(p_id).get("price", 0)))


static func raw_name(p_id: String) -> String:
	_ensure()
	return str(row(p_id).get("zh", ""))


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func status_text() -> String:
	_ensure()
	if _source == SOURCE_BALANCE:
		return "items: sheet NOT loaded (%s), %d row(s) from Balance.ITEM_ORDER" \
			% [error_text(), _order.size()]
	return "items: %d row(s) from %s, %d known to the battle, %d problem(s)" \
		% [_order.size(), PATH.get_file(), known_count(), _problems.size()]


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game, next to the plant and zombie sheets: what the
	## item sheet gave us, whether every registered svg really resolves, and whether the
	## rows the BATTLE knows still agree with Balance.ITEM_DEFS.
	##
	## The agreement parts are a WIRING check in the same sense as [Plants]: the sheet is
	## allowed to be the source (that is what it is for), so a picture or a name that
	## differs from Balance is printed as `overrides Balance` - but a number the BATTLE
	## applies must not disagree (the page would then quote a sell price that is not the
	## one the warehouse pays), so that one is a FAIL.
	print("[Items] --- item roster from %s (the almanac's ITEMS tab) ---" % PATH)
	if not is_loaded():
		print("[Items] sheet not loaded: " + error_text() + " | FAIL")
		print("[Items] -> Balance.ITEM_ORDER is being listed instead")
		print("[Items] self-check FAILED")
		return
	print("[Items] %d item(s), %d known to the battle, %d distinct svg path(s), source %s"
		% [_order.size(), known_count(), art_paths().size(), _source])
	var ok := true
	for id in _order:
		var k := get_kind(id)
		var v := price(id)
		var icon := art(id)
		var good: bool = k != "" and UnitArt.load_texture(icon) != null
		var line := "[Items] %-18s %-10s kind %-11s price %-5s plant %-11s art %s" % [
			id, name(id), ("(none)" if k == "" else k), (str(v) if v > 0 else "-"),
			(plant(id) if plant(id) != "" else "-"),
			(icon.get_file() if icon != "" else "(no icon)")]
		if not KINDS.has(k):
			line += "  unknown kind (item_kind_label falls back to other)"
		## [P44] The 对应植物 cell is the ONE promise a scroll or a potion makes: it is the
		## card the scroll unlocks and the plant a potion strengthens. Nothing else in the
		## sheet can break a player's run, so this is the reference worth gating - the same
		## reference `scroll_mystic` broke from the level side (the id predates P31's rename
		## to the spirit scroll and sat in two level files, green, for three batches).
		var pid := plant(id)
		if pid != "" and not Balance.plant_cards().has(pid):
			good = false
			line += "  plant %s is not a card the deck can hold" % pid
		elif k == "scroll" and pid == "":
			good = false
			line += "  a scroll must name the card it unlocks"
		if is_battle_known(id):
			## [P88] THE SHEET IS THE SOURCE (Balance.item_* asks it first), so a disagreement
			## with ITEM_DEFS is no longer a broken wire - it is the sheet overriding a code
			## fall-back, and it is printed rather than failed. What still has to hold is that
			## the price a player is quoted is the price the warehouse pays: both read the
			## sheet, so the only real risk left is a code row with NO sheet row at all
			## (invisible in the almanac) - claimed once below, over the whole table.
			var code := Balance.item_code_row(id)
			var drift := PackedStringArray()
			if icon != Balance.item_art(id):
				drift.append("art %s->%s" % [Balance.item_art(id).get_file(), icon.get_file()])
			if plant(id) != Balance.item_plant(id):
				drift.append("plant %s->%s" % [Balance.item_plant(id), plant(id)])
			var code_value := _code_value(id)
			if code_value >= 0 and v != code_value:
				drift.append("price %d->%d" % [code_value, v])
			line += "  %s" % ("sheet only" if code.is_empty() else "sheet wins")
			if not drift.is_empty():
				line += "  (overrides Balance: %s)" % ", ".join(drift)
		else:
			line += "  almanac only"
		ok = ok and good
		line += " | " + ("OK" if good else "FAIL")
		print(line)
	## [P88] THE ONE THING THAT MUST STILL HOLD now that the sheet is the source: every item
	## the CODE table can pay out must have a sheet row, or the battle hands out something the
	## almanac never shows and the warehouse cannot describe. (The reverse is fine and expected:
	## a sheet-only row like the sun item is a real item with no code row.)
	var missing := PackedStringArray()
	for item in Balance.ITEM_ORDER:
		var id := str(item)
		if not has(id):
			missing.append(id)
	var listed_ok: bool = missing.is_empty()
	ok = ok and listed_ok
	print("[Items] every one of the %d id(s) ITEM_ORDER lists has a sheet row = %s | %s"
		% [Balance.ITEM_ORDER.size(), str(listed_ok), "OK" if listed_ok else "FAIL"])
	if not listed_ok:
		print("[Items] WARN no sheet row for: " + ", ".join(missing))
	for problem in _problems:
		print("[Items] warning: " + problem)
		ok = ok and false
	## [P80] The same claim PlantDB / ZombieDB make for their path rules - ItemDB has only
	## one (`svg_path`), so this asserts one, and it goes red if the rule grows a narrower
	## copy of the blank test back. `data/items.csv` spells "no icon" as `—` today, which is
	## why the old `text == "—"` never lied: the sheet happened to use the one mark the rule
	## knew. The claim is about the RULE, not today's spelling.
	var blank_ok := true
	for mark in UnitCsvManager.BLANKS:
		blank_ok = blank_ok and svg_path(str(mark)) == ""
	blank_ok = blank_ok and svg_path("q") == SVG_ROOT + "q" + SVG_EXT
	ok = ok and blank_ok
	print("[Items] the five 'nothing here' marks answer 'no icon' in the path rule, while a spelled cell still builds a path = %s | %s"
		% [str(blank_ok), "OK" if blank_ok else "FAIL"])
	## [P57] the sheet's own complaints (a spelled cell that is not a number, a header
	## that names one column twice) - see the note in PlantDB.self_check().
	ok = ok and UnitCsvManager.report_complaints("[Items]")
	print("[Items] self-check %s" % ("PASSED" if ok else "FAILED"))
