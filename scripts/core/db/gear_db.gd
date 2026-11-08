class_name GearDB
extends RefCounted
## [B7] THE GEAR (挂件) - everything a piece can WEAR: the brawl's 强化 (augments) and its
## 装备 (equipment).
##
## ONE SHEET, TWO KINDS (BRAWL.md §8.6 / D42 / D45). B5 shipped data/brawl/augments.csv with
## AugmentDB; B7 both ADDED equipment and changed what an augment IS - from "a multiplier on
## every piece the player owns" to "a thing ONE piece wears" (D43). Once that had happened, an
## augment and a piece of equipment were the SAME OBJECT: a row with an effect key and a value,
## carried by a piece (BrawlSession.pool[i]["attach"]). So the sheet grew a 名称 column and this
## reader grew a kind filter, instead of a second sheet and a second reader that would have to be
## kept in step for as long as the mode lives (AGENTS §2: one fact, one owner).
##
##   data/brawl/gear.csv   name (id) / name_zh / 名称 / 等级 / 效果 / 数值 / svg
##
## 名称 IS augment OR equipment (BalanceBrawl.KIND_*). It decides WHO OFFERS A ROW - a reward card
## and a shop row each draw from one kind - and NOTHING ELSE: the fight cannot tell the two apart,
## which is the whole point of one vocabulary (the five keys a multiplier is spelled with are the
## same five an augment always used).
##
## 等级 IS A TIER TOKEN (silver / gold / prism), not prose: it prices the row and weights the
## draw (both ladders live in BalanceBrawl, one owner each). The NAME follows the language
## through name_zh, exactly as data/brawl/formations.csv does - the sheet owns a reinforcing
## word, the id stays English.
##
## 效果 IS A KEY OF BalanceBrawl.EFFECT_KEYS, written in one of two shapes:
##   a MULTIPLIER key takes a DELTA ("0.15" = +15%, "-0.15" = takes 15% less);
##   a FLAT key ([B7] hp_flat / attack_flat) takes a plain amount ("120" = +120 hit points).
## Both are read with float_of(), NOT rate_of(): the rate reader clamps at 0 and would quietly
## turn "-0.15" into "no change at all".
##
## svg IS OPTIONAL and relative to res://assets/svg/items/ (a cell may spell a full res:// path
## instead). A row without one draws no icon and is NOT a mistake - the seven augments have none.
##
## WHAT THIS READER IS NOT: it applies nothing. It answers "what does row X say"; BrawlSession
## sums what ONE PIECE wears into one dictionary (mods_for) and hands it to the arena through
## BrawlSetup, and BrawlActor is the only thing that applies it. That keeps "what does a row do"
## in one place (the sheet) and "when does it matter" in another (the fight).
##
## No self_check() block: the brawl is accepted by the user's own manual pass, and AGENTS §2
## forbids writing test scripts at all - so this reader reports through status_text() /
## problems() like FormationDB, and an unknown 效果 is a reported problem instead of a no-op.

const PATH := "res://data/brawl/gear.csv"

const COL_NAME := "name"
const COL_NAME_ZH := "name_zh"
const COL_KIND := "名称"
const COL_TIER := "等级"
const COL_EFFECT := "效果"
const COL_VALUE := "数值"
const COL_SVG := "svg"

## [B7] WHERE a row's picture lives. The same rule PlantDB.svg_path / PieceDB.svg_path follow:
## a short cell names a file under this root, a cell that already spells res:// is used as is.
const SVG_ROOT := "res://assets/svg/items/"
const SVG_EXT := ".svg"

static var _rows: Dictionary = {}          # id -> raw row
static var _order: Array[String] = []      # the sheet's order, top to bottom
static var _kinds: Dictionary = {}         # id -> BalanceBrawl.KIND_* (never "")
static var _loaded := false
static var _tried := false
static var _error := ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Read once (Game at boot; BrawlSetup.fixture() when a scene is opened on its own).
	_tried = true
	_rows.clear()
	_order.clear()
	_kinds.clear()
	_problems.clear()
	_error = ""

	var table := UnitCsvManager.read_table(PATH)
	if not bool(table.get("ok", false)):
		_error = str(table.get("error", "unknown error"))
		return false
	for entry in table.get("rows", []):
		var raw := entry as Dictionary
		var id := UnitCsvManager.cell(raw, COL_NAME)
		if id == "":
			_problems.append("a gear row names nothing (skipped)")
			continue
		if _rows.has(id):
			_problems.append("duplicate gear " + id + " (kept the first row)")
			continue
		var kind := UnitCsvManager.cell(raw, COL_KIND)
		if not BalanceBrawl.kind_known(kind):
			## A kind no list has is a row NOBODY CAN BE OFFERED (the reward roll and the shelf
			## both draw by kind) - reported, and read as an augment so the row still does
			## something rather than becoming unreachable data.
			_problems.append("%s: 名称 '%s' is no kind of BalanceBrawl.ATTACH_KINDS (read as %s)"
				% [id, kind, BalanceBrawl.KIND_AUGMENT])
			kind = BalanceBrawl.KIND_AUGMENT
		_kinds[id] = kind
		var tier := UnitCsvManager.cell(raw, COL_TIER)
		if not BalanceBrawl.tier_known(tier):
			## A tier no ladder lists costs the dearest rung and draws like a prism (see
			## BalanceBrawl.gear_price / gear_weight): harmless, and said out loud here so a
			## typo in 等级 does not quietly re-price a row.
			_problems.append("%s: 等级 '%s' is no tier of BalanceBrawl.GEAR_TIERS (priced as %s)"
				% [id, tier, BalanceBrawl.TIER_PRISM])
		var effect := UnitCsvManager.cell(raw, COL_EFFECT)
		if not BalanceBrawl.effect_known(effect):
			## A key nothing applies is a row that does nothing - reported, never run (the same
			## rule a renamed sheet column gets).
			_problems.append("%s: 效果 '%s' is no key of BalanceBrawl.EFFECT_KEYS (it would do nothing)"
				% [id, effect])
		_rows[id] = raw
		_order.append(id)
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable gear row"
	return _loaded


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


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


static func ids_of(p_kind: String) -> Array[String]:
	## Every row of ONE kind, in sheet order. What a reward card and a shelf slot draw from, so
	## "which kind is this" is asked in exactly one place (kind()).
	_ensure()
	var out: Array[String] = []
	for id in _order:
		if kind(id) == p_kind:
			out.append(id)
	return out


static func has(p_id: String) -> bool:
	_ensure()
	return _rows.has(p_id)


static func count() -> int:
	_ensure()
	return _order.size()


static func kind(p_id: String) -> String:
	_ensure()
	return str(_kinds.get(p_id, ""))


static func display_name(p_id: String) -> String:
	## The name in the current language - the rule data/brawl/formations.csv follows: the sheet
	## carries name_zh, the id stays English, and no code changes when a name does.
	_ensure()
	var row: Dictionary = _rows.get(p_id, {})
	if row.is_empty():
		return p_id
	var zh := UnitCsvManager.cell(row, COL_NAME_ZH)
	if zh != "" and Loc.prefer_zh():
		return zh
	return p_id


static func tier(p_id: String) -> String:
	_ensure()
	return UnitCsvManager.cell((_rows.get(p_id, {}) as Dictionary), COL_TIER)


static func effect(p_id: String) -> String:
	_ensure()
	return UnitCsvManager.cell((_rows.get(p_id, {}) as Dictionary), COL_EFFECT)


static func value(p_id: String) -> float:
	## A plain decimal: "+0.15" is a 15% bonus on a multiplier key, "120" is +120 hit points on a
	## flat one. NOT a rate cell - a negative value is legal, and rate_of() clamps at 0.
	_ensure()
	var row: Dictionary = _rows.get(p_id, {})
	if row.is_empty():
		return 0.0
	return UnitCsvManager.float_of(UnitCsvManager.cell(row, COL_VALUE), 0.0, COL_VALUE, row)


static func price(p_id: String) -> int:
	## What the shop charges, from the tier ladder (BalanceBrawl.GEAR_PRICES). An unknown tier -
	## a typo in 等级 - gets the most expensive rung and is reported by problems().
	return BalanceBrawl.gear_price(tier(p_id))


static func effect_text(p_id: String) -> String:
	## The one-line description of what this row does, in the player's language. The wording is
	## the language layer's (loc_ui "brawl.aug.<effect>"), the number is the sheet's, and the
	## percentage is computed HERE so the two can never drift. A FLAT key prints its amount as
	## written ("+120 hit points"), a multiplier key prints hundredths ("+15%").
	var key := effect(p_id)
	var raw := value(p_id)
	var amount := int(round(raw)) if BalanceBrawl.effect_is_flat(key) else int(round(raw * 100.0))
	return Loc.tf("brawl.aug." + key, [amount])


static func svg_path(p_cell: String) -> String:
	## "gear_sword" -> "res://assets/svg/items/gear_sword.svg". A cell that already spells a
	## full res:// path, or carries its own extension, is used as it is.
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not (cell_text.ends_with(".svg") or cell_text.ends_with(".png")):
		cell_text += SVG_EXT
	return SVG_ROOT + cell_text


static func svg_rel(p_id: String) -> String:
	_ensure()
	return UnitCsvManager.cell((_rows.get(p_id, {}) as Dictionary), COL_SVG)


static func art(p_id: String) -> String:
	## What the page DRAWS for a row: the registered file when it loads, "" otherwise. A missing
	## picture is never an error (the seven augments have none) - the tile then shows the name.
	var path := svg_path(svg_rel(p_id))
	if path != "" and UnitArt.load_texture(path) != null:
		return path
	return ""


static func art_paths() -> Array:
	## Every picture the sheet names (whether or not it loads yet): what a "does the art exist"
	## report walks, and what a future icon audit would read.
	_ensure()
	var out: Array = []
	for id in _order:
		var path := svg_path(svg_rel(id))
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func draw(p_rng: RandomNumberGenerator, p_exclude: Array = [], p_kind: String = "") -> String:
	## One row id of ONE KIND, weighted by tier (silver is common, prism is rare).
	## p_exclude keeps a draw from repeating something already on the table (the shelf's own
	## rows); p_kind "" means "any kind". When EVERY row of that kind is excluded the exclusion
	## is DROPPED rather than answering "" - a reward screen with nothing on it would be worse
	## than a duplicate.
	_ensure()
	var pool: Array[String] = []
	var weights: Array[int] = []
	for id in _order:
		if p_kind != "" and kind(id) != p_kind:
			continue
		if p_exclude.has(id):
			continue
		pool.append(id)
		weights.append(BalanceBrawl.gear_weight(tier(id)))
	if pool.is_empty():
		for id in _order:
			if p_kind != "" and kind(id) != p_kind:
				continue
			pool.append(id)
			weights.append(BalanceBrawl.gear_weight(tier(id)))
	if pool.is_empty():
		return ""
	var total := 0
	for w in weights:
		total += w
	if total <= 0:
		return pool[p_rng.randi_range(0, pool.size() - 1)]
	var roll := p_rng.randi_range(1, total)
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0:
			return pool[i]
	return pool[pool.size() - 1]


# ---------------------------------------------------------------- reporting
static func status_text() -> String:
	_ensure()
	var line := "gear: %d row(s) (%d augment, %d equipment), %d bad 效果" 		% [_order.size(), ids_of(BalanceBrawl.KIND_AUGMENT).size(),
		   ids_of(BalanceBrawl.KIND_EQUIPMENT).size(), _bad_effects()]
	if _error != "":
		line += "  ERROR: " + _error
	for problem in _problems:
		line += "  [" + problem + "]"
	return line


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func _bad_effects() -> int:
	var n := 0
	for id in _order:
		if not BalanceBrawl.effect_known(effect(id)):
			n += 1
	return n
