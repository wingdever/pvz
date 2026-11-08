extends RefCounted
## [P105] THE RARITY LADDER - the reader for `data/rarity.csv`.
##
## WHAT THIS SHEET IS FOR. A plant's rarity used to be one word with no appearance and one
## number in the wrong table: `PLANT_DEFS[id]["rarity"]` named the tier and
## `Balance.RARITY_RECOVERY` said how much slower a downed plant of it stands up - while
## nothing anywhere said what 普通 / 优秀 / 稀有 LOOK like. The owner's rule for this batch is
## the layer split: the tier belongs to the UNIT row (`rarity` in data/units/units.csv) and
## what a tier MEANS belongs here - one row per tier, with its colour and its recovery
## factor, so a new tier is a row and never a code change.
##
## WHAT THE COLUMNS MEAN:
##   name       the tier id the rest of the code speaks ("common" ... "mythic"), spelled
##              exactly as the `rarity` cells and user://garden.json spell it.
##   颜色       the tier's colour, written the way the web writes it: "#RRGGBB" (an 8-digit
##              "#RRGGBBAA" reads too). Whoever SHOWS a tier paints with this - the garden
##              draws a plant's name in it today (Balance.rarity_color).
##   恢复倍率   how much longer a plant of this tier stays DOWNED: Balance.recovery_seconds()
##              is `RECOVERY_BASE_SECONDS x this x level factor`. A plain multiplier, NOT a
##              percentage (1.5 = "half again as long") - which is why it is parsed here as a
##              float and NOT through UnitCsvManager.rate_of(), whose "anything above 1 is a percent"
##              rule would read 1.5 as 0.015.
##
## DELIBERATELY WITHOUT `class_name`, DELIBERATELY static - the same reasons as `SafeIO`
## (P37) and `DropDB` (P83): a brand-new global class is invisible to `godot --headless`
## until the editor rescans the project, and being provable headlessly is the whole point.
## Consumers preload this file: `const RarityDB := preload("res://scripts/core/rarity_db.gd")`.
##
## THIS FILE KEEPS NO FALL-BACK TABLE OF ITS OWN. Both accessors take the caller's default
## and answer nothing else, so data/rarity.csv stays the single owner of what a tier is worth
## - a second copy here would be exactly the drift that moving these numbers into a sheet
## removes (AGENTS §2: one owner per number). The defaults the callers pass live in Balance:
## a neutral colour, and the flat factor 1.0 that makes a sheet-less run recover every tier
## at the 60 s baseline.
##
## A cell that is SPELLED but cannot be used (a colour that is not a colour, a factor that is
## not a positive number) is the P57 complaint channel, not a silent default: `[Rarity]` goes
## red and names the cell instead of quietly painting white.

const PATH := "res://data/rarity.csv"

# ---------------------------------------------------------------- sheet columns
# Matched by NAME (see UnitCsv), never by index, so the sheet can grow columns.
const COL_NAME := "name"
const COL_COLOR := "颜色"
const COL_RECOVERY := "恢复倍率"

## The web spelling of a colour cell, minus the prefix that Color.html() wants.
const HASH := "#"
## Hexadecimal digits of the two accepted lengths (RRGGBB / RRGGBBAA).
const HEX_LENGTHS: Array[int] = [6, 8]

static var _rows: Dictionary = {}          # tier -> {"color": Color?, "recovery": float?}
static var _order: Array[String] = []      # sheet order, top to bottom
static var _tried: bool = false            # a failed load is not retried on every read
static var _loaded: bool = false
static var _error: String = ""
static var _problems: Array[String] = []


# ---------------------------------------------------------------- loading
static func load_from_disk() -> bool:
	## Reads the sheet once. Called by Game at boot (and again on the R key); every accessor
	## also `_ensure()`s, so a colour can never be asked of an empty table in silence.
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

	for entry in (table.get("rows", []) as Array):
		var raw: Dictionary = entry
		var tier := UnitCsvManager.cell(raw, COL_NAME)
		if tier == "":
			_problems.append("a row without a %s (skipped)" % COL_NAME)
			continue
		if _rows.has(tier):
			_problems.append("%s: the tier '%s' is written twice (kept the first row)"
				% [PATH.get_file(), tier])
			continue
		_rows[tier] = _parse_row(raw, tier)
		_order.append(tier)

	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable tier row"
	return _loaded


static func _parse_row(p_raw: Dictionary, p_tier: String) -> Dictionary:
	## One tier row. A cell that is spelled but unusable leaves its KEY OUT of the row, which
	## is what makes color_of() / recovery_of() answer the caller's default for it - so the
	## failure mode is the documented one ("the sheet says nothing usable") and the complaint
	## below is what makes it visible instead of silent.
	var row := {}
	var color := _parse_color(UnitCsvManager.cell(p_raw, COL_COLOR), p_tier)
	if bool(color["ok"]):
		row["color"] = color["color"]
	var recovery := _parse_factor(UnitCsvManager.cell(p_raw, COL_RECOVERY), p_tier)
	if recovery > 0.0:
		row["recovery"] = recovery
	return row


static func _parse_color(p_cell: String, p_tier: String) -> Dictionary:
	## "#4CD137" -> {"ok": true, "color": Color(0.298, 0.82, 0.216)}. A BLANK cell is
	## {"ok": false} with no complaint (the designer said nothing); a cell that IS spelled and
	## is not a colour is {"ok": false} WITH one, which is what turns it into a red [Rarity]
	## line instead of a tier nobody can paint.
	var out := {"ok": false, "color": Color(0, 0, 0, 0)}
	var text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(text):
		return out
	if text.begins_with(HASH):
		text = text.substr(HASH.length())
	if not HEX_LENGTHS.has(text.length()) or not text.is_valid_hex_number(false):
		_problems.append('%s: tier %s, %s = %s is not a colour (#RRGGBB expected) -> the caller default is used'
			% [PATH.get_file(), p_tier, COL_COLOR, p_cell])
		return out
	out["ok"] = true
	out["color"] = Color.html(text)
	return out


static func _parse_factor(p_cell: String, p_tier: String) -> float:
	## A plain multiplier, parsed as a float ON PURPOSE - see the header for why
	## UnitCsvManager.rate_of() must not be used on this column.
	var text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(text):
		return 0.0
	if not text.is_valid_float():
		_problems.append('%s: tier %s, %s = %s is not a number -> the caller default is used'
			% [PATH.get_file(), p_tier, COL_RECOVERY, text])
		return 0.0
	var value := text.to_float()
	if value <= 0.0:
		_problems.append('%s: tier %s, %s = %s is not a positive multiplier -> the caller default is used'
			% [PATH.get_file(), p_tier, COL_RECOVERY, text])
		return 0.0
	return value


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


# ---------------------------------------------------------------- queries
static func ids() -> Array[String]:
	## Every tier, in the sheet's own order (weakest first is a design convention, not a rule
	## this reader enforces: the order that matters is the one a designer reads).
	_ensure()
	return _order.duplicate()


static func has(p_rarity: String) -> bool:
	_ensure()
	return _rows.has(p_rarity)


static func count() -> int:
	_ensure()
	return _order.size()


static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func error_text() -> String:
	_ensure()
	return _error if _error != "" else "none"


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func color_of(p_rarity: String, p_default: Color) -> Color:
	## The tier's colour, or the caller's default when this sheet has no such tier (or its
	## 颜色 cell was unusable). The default is REQUIRED rather than defaulted here, so every
	## caller has to say what a tier nobody can name looks like.
	_ensure()
	var row: Dictionary = _rows.get(p_rarity, {})
	return row.get("color", p_default)


static func recovery_of(p_rarity: String, p_default: float) -> float:
	## The tier's downed-time multiplier, or the caller's default - same contract as
	## color_of().
	_ensure()
	var row: Dictionary = _rows.get(p_rarity, {})
	return float(row.get("recovery", p_default))


static func color_text(p_rarity: String) -> String:
	## The colour as the sheet writes it, for the [Rarity] readout ("#4CD137"); "" when the
	## tier is unknown or its cell was unusable.
	_ensure()
	var row: Dictionary = _rows.get(p_rarity, {})
	if not row.has("color"):
		return ""
	return (row["color"] as Color).to_html(false)


# ---------------------------------------------------------------- self check
static func self_check(p_vocabulary: Array = []) -> void:
	## One physical line per claim (ARCHITECTURE §5.3). What is worth proving is the WIRING:
	## every tier a designer writes has both halves (a colour and a factor), the tiers are
	## distinguishable from each other, and the six names the CODE speaks are all rows here -
	## a missing one would leave the garden painting the neutral colour and the recovery probe
	## quietly timing a tier that does not exist.
	var ok := true
	_ensure()
	print("[Rarity] source = %s, %d tier(s) = %s | %s"
		% [PATH.get_file(), _order.size(), str(_loaded), "OK" if _loaded else "FAIL"])
	if not _loaded:
		print("[Rarity] sheet not loaded: " + error_text() + " | FAIL")
		print("[Rarity] -> every tier falls back to Balance's neutral colour and the 60 s baseline")
		print("[Rarity] self-check FAILED")
		return
	var incomplete := PackedStringArray()
	for tier in _order:
		var row: Dictionary = _rows[tier]
		if not row.has("color"):
			incomplete.append(tier + " (no 颜色)")
		if not row.has("recovery"):
			incomplete.append(tier + " (no 恢复倍率)")
	var halves_ok: bool = incomplete.is_empty()
	ok = ok and halves_ok
	var census := PackedStringArray()
	for tier in _order:
		census.append("%s %s x%s" % [tier, color_text(tier), str(recovery_of(tier, 0.0))])
	print("[Rarity] %s" % "  ".join(census))
	print("[Rarity] every tier states both a %s and a %s = %s%s | %s"
		% [COL_COLOR, COL_RECOVERY, str(halves_ok),
		   ("  incomplete: " + ", ".join(incomplete)) if not incomplete.is_empty() else "",
		   "OK" if halves_ok else "FAIL"])
	var worn: Dictionary = {}
	var twins := PackedStringArray()
	for tier in _order:
		var hex := color_text(tier)
		if hex == "":
			continue
		if worn.has(hex):
			twins.append("%s = %s = %s" % [str(worn[hex]), tier, hex])
		worn[hex] = tier
	var distinct_ok: bool = twins.is_empty()
	ok = ok and distinct_ok
	print("[Rarity] the %d tier(s) wear %d distinct colour(s) = %s%s | %s"
		% [_order.size(), worn.size(), str(distinct_ok),
		   ("  shared: " + ", ".join(twins)) if not twins.is_empty() else "",
		   "OK" if distinct_ok else "FAIL"])
	var missing := PackedStringArray()
	for entry in p_vocabulary:
		if not _rows.has(str(entry)):
			missing.append(str(entry))
	var vocabulary_ok: bool = missing.is_empty() and not p_vocabulary.is_empty()
	ok = ok and vocabulary_ok
	print("[Rarity] every tier the code names (%d) has a row here = %s%s | %s"
		% [p_vocabulary.size(), str(vocabulary_ok),
		   ("  missing: " + ", ".join(missing)) if not missing.is_empty() else "",
		   "OK" if vocabulary_ok else "FAIL"])
	## The complaints raised while parsing go on THIS block and not through UnitCsv's shared
	## channel: a bad rarity cell is only ever read by this file, and the shared channel prints
	## under whichever sheet happens to read first (PlantDB asks this table whether the tiers
	## exist) - "rarity.csv: 颜色 = #FFFF is not a colour" under a [Plants] banner is a line
	## nobody can trace. Both ways are red; this one is red in the right place.
	for problem in _problems:
		print("[Rarity] warning: " + problem)
		ok = ok and false
	print("[Rarity] self-check %s" % ("PASSED" if ok else "FAILED"))