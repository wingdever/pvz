## [P91] THE PROJECTILE TABLE (data/projectiles.csv) - what a shot IS, once it has left.
##
## WHY A TABLE (user design, 2026-09-25): a projectile is a BODY with a handful of properties,
## and those properties were spread over three files - the flight in `Projectile`, the arc and
## the "flies over what stands in the way" rule in `PultProjectile`, and the rest (speed, tint,
## pierce, armour-piercing, splash, the rider, the two cues) in whichever plant happened to
## fire it. Adding a fifth kind of shot therefore meant reading all of them.
##
## THE COLUMNS, and the ONE rule each one follows:
##   * 轨迹 - the SHAPE of the flight, a closed list: 直线 (a straight line from the muzzle),
##     追踪 (re-aims at its target every step, so a walking zombie is followed), 抛射 (rises
##     and falls onto the body it was aimed at, flying OVER whatever stands in between);
##   * 速度 - `—` means "the default for this 轨迹" (BalanceUI.PEA_SPEED / PULT_SPEED): a
##     pixel value belongs to BalanceUI, not to a content sheet. [B7+] The two rows the BRAWL
##     fires (`arrow` / `musket`) are the first to state one, because the arena needs two
##     shots that visibly fly at different speeds and it converts px -> cells with
##     Balance.CELL_SIZE (see scripts/core/brawl/brawl_shot.gd). The column was always the
##     place for it; what changes is that somebody finally needed a number that is not the
##     two defaults;
##   * 穿透 - how many bodies the shot may pass through before it stops (0 = the first one),
##   * 反弹 - how many times the LAWN EDGE turns it around instead of ending the flight,
##   * 穿甲 / 溅射 - the two classic riders on the DAMAGE (armour ignored, neighbours clipped);
##   * 溅射半径 - [B19] how far the blast reaches, in CELLS. A blank cell is not a number: it
##     means "no blast of its own", which is every row that shipped before the lobber, and the
##     brawl then grazes with the body-radius rule it has always used. A STATED cell turns the
##     shot into an explosion - the brawl detonates it where it ARRIVES, even on empty ground
##     (scripts/core/brawl/brawl_shot.gd);
##   * 命中状态 + 状态值 - the status this shot applies, by the status sheet's own id and a
##     default number of rounds (the applier may override it, which is how 寒冰射手's 大招
##     freezes for three while its ordinary shot freezes for one);
##   * 音效 / 落点音效 - cue ids of BalanceAudio.SFX_DEFS (an unknown cue fails at boot),
##   * 外观 - which picture the base draws (a closed list of drawing primitives),
##   * 尺寸 - [B32] HOW BIG that picture is, in the board's PIXELS, and since the user's 2026-10-10
##     ruling ("尺寸作为射弹的csv表的一个基本字段") a BASIC one: every row states its own number, so the
##     page can answer "how big is this shot" without asking an asset file. The values written are the
##     canvases those pictures were already drawn at (豌豆 32, 西瓜 40, 箭 64, 火枪弹 48, 炮弹 18 = the
##     code sphere's own diameter), which is why adopting the rule resized nothing. A BLANK cell keeps
##     its old meaning for anything that has no row yet - "the picture answers for itself": an SVG's own
##     canvas, else a code look's drawn extent (Projectile.shot_box()). DRAW ONLY, like 体型.
##   * 体型 - [B40] HOW BIG the picture reads, as one of five WORDS (Balance.SIZE_WORDS:
##     微小 / 小 / 标准 / 大 / 巨大). This is a magnitude and not a measurement, and it exists
##     because some rows want to say "this shot is a big object" without inventing a pixel count
##     for a picture that has one already: the word MULTIPLIES whatever base won - an authored
##     尺寸, an SVG's own canvas, a code look's drawn extent (Projectile.shot_box()) - so a row
##     stating both gets both, and 暖阳 at 100 px 大 is a 150 px sun. A blank cell is 标准 = 1.0,
##     which is why adopting the ladder resized nothing that had shipped. DRAW ONLY, like 尺寸:
##     the hit box is the flight's own reach, in cells.
##   * 治疗 - [B30] WHICH SIDE the shot looks for, and what its number means when it lands.
##     `是` = a live FRIENDLY body is what this flight is hunting, and the number it carries
##     is PUT BACK on it instead of taken off. The amount still belongs to the shooter (see
##     WHAT IS NOT HERE): the column never holds a number, only the answer to "wound or mend".
##     Such a shot is also never stopped by a body that is not the one it was aimed at - the
##     same reading a 抛射 lob already has about whatever stands in between - which is why the
##     暖阳 is written 轨迹=追踪 as well: it has to leave its lane to find the wounded.
##     ⚠ 治疗 / 尺寸 / 体型 are the three columns appended after the brawl's height block, and they
##     stay at the file's END for that reason: a column inserted in front of the six height cells
##     would move every row that spells one (炮弹's 1.2).
##
## WHAT IS NOT HERE, on purpose:
##   * DAMAGE - it belongs to the plant's own skill value (a snow pea's chill costs the same
##     whether it lands on a cone or a bucket), so a shot carries the number but never owns it;
##   * `straight_shot` - the 铁门 only stops 正面直线射弹, and that is exactly 轨迹 = 直线, so
##     the flag is DERIVED (P77's rule: a shot must not be able to tell the armour one story
##     and the status layer another);
##   * a plant's own volley shape (how many shots, which lanes, how far) - that is what the
##     PLANT is, and it lives in its row of data/units/.
##
## BY PATH, no class_name: same reason as Spawn / StatusDB / Rewards (a brand-new global class
## is invisible to `godot --headless` until the editor rescans).

const UnitCsv := preload("res://scripts/core/unit_csv.gd")
## [P91] the status sheet: a shot's 命中状态 is a status ID, and the default round count
## comes from the status row when the shot row does not state one.
const StatusDB := preload("res://scripts/core/db/status_db.gd")

const PATH := "res://data/projectiles.csv"

## The default row: what a shooter fires when nobody says otherwise.
const ID_PEA := "pea"

## [P91] The closed list of flight shapes. Every value is a primitive the base implements;
## a sheet that spells something else is refused, because a shot whose 轨迹 nobody flies
## would look perfectly healthy in the file and then stand still.
const TRAJ_STRAIGHT := "直线"
const TRAJ_HOMING := "追踪"
const TRAJ_ARC := "抛射"
const TRAJECTORIES: Array[String] = [TRAJ_STRAIGHT, TRAJ_HOMING, TRAJ_ARC]

## The drawing primitives. A new LOOK means touching the painter once
## (`Projectile.draw_shot()`, which the brawl's own flight draws through as well); a new shot
## that reuses an existing look is a table row only.
## [B7+] `arrow` and `musket` are the brawl's two shots: they are drawn here and not in the
## brawl for the reason the list exists at all - "what an arrow looks like" must have ONE
## owner, and the day a turn-engine plant fires one it draws the same picture.
const LOOK_PEA := "pea"
const LOOK_MELON := "melon"
const LOOK_ARROW := "arrow"
const LOOK_MUSKET := "musket"
## [B19] The lobber's shell: a plain BLACK ball owned by no shooter's colour, drawn bigger
## than a musket round because a bomb that reads as a bullet tells the player the wrong story.
const LOOK_BOMB := "bomb"
const LOOKS: Array[String] = [LOOK_PEA, LOOK_MELON, LOOK_ARROW, LOOK_MUSKET, LOOK_BOMB]

const YES := "是"
const COMPLAINT_LIMIT := 12

const COL_ID := "name"
const COL_ZH := "中文名"
const COL_TRAJ := "轨迹"
const COL_SPEED := "速度"
const COL_PIERCE := "穿透"
const COL_BOUNCE := "反弹"
## [P91] the classic pierce, as its own column: see pierce_damage().
const COL_PIERCE_DAMAGE := "穿透伤害"
const COL_ARMOR := "穿甲"
const COL_SPLASH := "溅射"
## [B19] The blast's OWN reach, in cells - see the header. Read like the height columns:
## -1.0 = "the sheet says nothing", which is the brawl's cue to keep the old graze rule.
const COL_SPLASH_REACH := "溅射半径"
const COL_STATUS := "命中状态"
const COL_STATUS_VALUE := "状态值"
const COL_CUE := "音效"
const COL_CUE_HIT := "落点音效"
const COL_LOOK := "外观"
## [D79] THE PICTURE COLUMN. 外观 stays what it always was - the CLOSED list of drawing
## primitives, and the shot's geometry - while 贴图 optionally names an SVG to draw instead.
## A filled cell WINS; a blank one (or a file the import has not produced) falls back to the
## primitive, which is why adding a picture can never break a shot (the rule units.csv's
## svg/tscn pair already follows).
const COL_ART := "贴图"
## [B30] WHICH SIDE this shot hunts, and whether its number mends or wounds - see the header.
## Written `是` / left blank; it sits at the file's END, not a neighbour of these ones.
const COL_HEAL := "治疗"
## [B32] HOW BIG THE PICTURE IS, in the board's PIXELS. A BASIC column since 2026-10-10: the user's
## ruling is that every row states its own 尺寸, and the eleven shots now do - each at exactly the
## canvas its picture was already drawn at (pea 32, melon 40, arrow 64, musket 48, 炮弹 18 = the code
## look's own diameter), so stating it changed no pixel and bought the 图鉴 a number to print.
## A BLANK cell still means "the picture answers for itself" (an SVG at its own canvas, a code look at
## its own radius - Projectile.shot_box()), which is the reading a row is written into when its art
## later changes size; the column exists because one file may be authored larger than the board wants
## (assets/svg/items/sun.svg is a 200 px ITEM icon reused as a shot, and the row says 100).
## This is DRAW ONLY: a shot's hit box is projectile.gd's own reach and the brawl's collision reads
## body_width, in cells.
const COL_SIZE := "尺寸"
## [B40] The MAGNITUDE word this picture is poured into (微小 / 小 / 标准 / 大 / 巨大) - see the header.
## A closed list owned by Balance.SIZE_WORDS, because the brawl's whirlwind names the same tier from
## its own rule table and one word must not mean two sizes in one project. Blank = 标准.
const COL_SIZE_TIER := "体型"
## [B17] THE HEIGHT-AXIS COLUMNS, spelled in CELLS and named exactly like units.csv's six
## (spec §7 / D99: one reading path, one shared HeightBody). A blank cell is NOT a number
## here: these rows carry -1 ("the sheet says nothing"), the same shape `speed` uses, and the
## BRAWL's launch() turns -1 into the BalanceBrawl cruising / apex / thickness defaults. The
## classic mode reads none of them this phase (docs/dev/HEIGHT.md §10-1).
const COL_Z_HEIGHT := "z_height"
const COL_Z_THICKNESS := "z_thickness"
const COL_BODY_WIDTH := "body_width"
const COL_BODY_DEPTH := "body_depth"
const COL_BODY_XOFF := "body_xoff"
const COL_BODY_YOFF := "body_yoff"
## Where a short 贴图 cell points. A cell that already spells res:// is used as it is.
const SVG_ROOT := "res://assets/svg/shots/"
const SVG_EXT := ".svg"

static var _rows: Dictionary = {}
static var _order: Array[String] = []
static var _problems: Array[String] = []
static var _loaded := false
static var _tried := false
static var _error := ""


static func load_from_disk() -> bool:
	## Called once at boot next to the other sheets (and again on the R-key reload). A sheet
	## that cannot be read is not fatal: the built-in rows below cover the shots that ship.
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
			_problems.append("duplicate shot id '%s' (kept the first row)" % id)
			continue
		_rows[id] = {
			"id": id,
			"zh": UnitCsvManager.cell(raw, COL_ZH),
			"traj": UnitCsvManager.cell(raw, COL_TRAJ),
			## px/s, and NOT a rate: a speed of 1100 must not be read as a percentage.
			"speed": float(UnitCsvManager.int_of(UnitCsvManager.cell(raw, COL_SPEED), -1)),
			"pierce": UnitCsvManager.int_cell(raw, [COL_PIERCE], 0),
			"bounce": UnitCsvManager.int_cell(raw, [COL_BOUNCE], 0),
			"armor": UnitCsvManager.cell(raw, COL_ARMOR) == YES,
			"splash": UnitCsvManager.rate_of(UnitCsvManager.cell(raw, COL_SPLASH), 0.0),
			"splash_reach": UnitCsvManager.float_cell(raw, [COL_SPLASH_REACH], -1.0),
			"status": UnitCsvManager.cell(raw, COL_STATUS),
			"status_value": UnitCsvManager.int_cell(raw, [COL_STATUS_VALUE], 0),
			"pierce_damage": UnitCsvManager.cell(raw, COL_PIERCE_DAMAGE) == YES,
			"cue": UnitCsvManager.cell(raw, COL_CUE),
			"cue_hit": UnitCsvManager.cell(raw, COL_CUE_HIT),
			"look": UnitCsvManager.cell(raw, COL_LOOK),
			"art": UnitCsvManager.cell(raw, COL_ART),
			## [B30] the ONE cell that says which side this flight hunts and what its number
			## does on arrival; every row that shipped before the 暖阳 leaves it blank.
			"heals": UnitCsvManager.cell(raw, COL_HEAL) == YES,
			## [B32] -1.0 = "the row says nothing, the picture decides" (see COL_SIZE).
			"size": UnitCsvManager.float_cell(raw, [COL_SIZE], -1.0),
			## [B40] the magnitude WORD as spelled; "" = 标准. The self-check is what refuses a word
			## the ladder does not have, and size_scale() below is where the word becomes a number.
			"size_tier": UnitCsvManager.cell(raw, COL_SIZE_TIER),
			## [B17] the six height keys, -1 = "the table says nothing" (the reader's fallback
			## is BalanceBrawl's, not a number invented here).
			"z_height": UnitCsvManager.float_cell(raw, [COL_Z_HEIGHT], -1.0),
			"z_thickness": UnitCsvManager.float_cell(raw, [COL_Z_THICKNESS], -1.0),
			"body_width": UnitCsvManager.float_cell(raw, [COL_BODY_WIDTH], -1.0),
			"body_depth": UnitCsvManager.float_cell(raw, [COL_BODY_DEPTH], -1.0),
			"body_xoff": UnitCsvManager.float_cell(raw, [COL_BODY_XOFF], -1.0),
			"body_yoff": UnitCsvManager.float_cell(raw, [COL_BODY_YOFF], -1.0),
		}
		_order.append(id)
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable shot row"
		_use_fallback()
	return _loaded


static func _use_fallback() -> void:
	## The shots that ship, spelled here so a missing sheet is not a game without shots.
	## A NEW shot needs the file (that is the point of the table).
	_rows.clear()
	_order.clear()
	var built := [
		[ID_PEA, "豌豆", TRAJ_STRAIGHT, 0, 0, false, 0.0, "", 0, "shoot", "impact", LOOK_PEA],
		["snow_pea_shot", "寒冰豌豆", TRAJ_STRAIGHT, 0, 0, false, 0.0, "freeze", 1, "shoot", "impact", LOOK_PEA],
		["spore", "孢子", TRAJ_STRAIGHT, 0, 0, false, 0.0, "", 0, "shoot", "impact", LOOK_PEA],
		["fume_breath", "毒雾", TRAJ_STRAIGHT, 0, 0, true, 0.0, "", 0, "shoot", "impact", LOOK_PEA],
		["cabbage", "卷心菜", TRAJ_ARC, 0, 0, false, 0.0, "", 0, "lob", "impact", LOOK_MELON],
		["melon", "西瓜", TRAJ_ARC, 0, 0, false, 0.5, "", 0, "lob", "melon_impact", LOOK_MELON],
		["winter_melon_shot", "冰西瓜", TRAJ_ARC, 0, 0, false, 0.5, "freeze", 1, "lob", "melon_impact", LOOK_MELON],
	]
	for b in built:
		## [P109] `vals`, not `row`: a local `row` here shadowed the class's own `row()`
		## getter and the editor compiled a SHADOWED_VARIABLE warning for it.
		var vals := b as Array
		var id := str(vals[0])
		## [D79] ...and the picture that ships with each look, spelled HERE too: a sheet that
		## cannot be read must not cost the game the art it already has (draw_shot still falls back
		## to the primitive when a file is missing).
		_rows[id] = {"id": id, "zh": str(vals[1]), "traj": str(vals[2]), "speed": -1.0,
			"pierce": int(vals[3]), "bounce": int(vals[4]), "armor": bool(vals[5]),
			"pierce_damage": false,
			"splash": float(vals[6]), "status": str(vals[7]), "status_value": int(vals[8]),
			"cue": str(vals[9]), "cue_hit": str(vals[10]), "look": str(vals[11]),
			"art": str(vals[11]),
			## [B17] same six keys, same -1: the built-ins leave the height axis to the
			## reader's BalanceBrawl defaults, exactly like the blank sheet cells do.
			"z_height": -1.0, "z_thickness": -1.0, "body_width": -1.0,
			"body_depth": -1.0, "body_xoff": -1.0, "body_yoff": -1.0}
		_order.append(id)
	_loaded = true


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func is_loaded() -> bool:
	_ensure()
	return _loaded


static func source() -> String:
	return "sheet" if _error == "" else "built-in"


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
	## The shot's row, or the plain pea when the id is unknown - a shot nobody described
	## must still fly (the alternative is a plant that fires nothing).
	_ensure()
	if _rows.has(p_id):
		return _rows[p_id]
	return _rows.get(ID_PEA, {})


static func name_of(p_id: String) -> String:
	return str(row(p_id).get("zh", p_id))


static func trajectory(p_id: String) -> String:
	return str(row(p_id).get("traj", TRAJ_STRAIGHT))


static func is_straight(p_id: String) -> bool:
	return trajectory(p_id) == TRAJ_STRAIGHT


static func pierce_damage(p_id: String) -> bool:
	## [P91] The classic pierce: a body the shot goes THROUGH takes the damage as well (see
	## Projectile._strike). The shipped rows all say no on purpose - the storms read a plain
	## `穿透` count as "passed, untouched", which is the rule that keeps a pea aimed at a
	## farther zombie from stealing the nearer one's own hit.
	return bool(row(p_id).get("pierce_damage", false))


static func pierce_of(p_id: String) -> int:
	## [D78] How many bodies the shot passes THROUGH before it stops (0 = the first one it meets).
	## Read here rather than out of row() by each caller, so "what does 穿透 mean" has one answer.
	return int(row(p_id).get("pierce", 0))


static func bounce_of(p_id: String) -> int:
	## ...and how many times it may bounce off the board's edge.
	return int(row(p_id).get("bounce", 0))


static func splash_of(p_id: String) -> float:
	## The fraction of the blow that also lands on everything AROUND the target (0 = single
	## target). A rate, not a count - which is why the sheet writes 0.5.
	return float(row(p_id).get("splash", 0.0))


static func splash_reach_of(p_id: String) -> float:
	## [B19] The blast's reach in CELLS, or -1.0 when the row says nothing (= no blast of its
	## own; the caller keeps the graze rule it always had). Read with float_cell and not
	## rate_cell, the trap the reach/speed cells of the piece sheets have: 1.6 is a distance.
	return float(row(p_id).get("splash_reach", -1.0))


static func armor_piercing(p_id: String) -> bool:
	## 穿甲: the shot ignores the target's armor instead of being reduced by it.
	return bool(row(p_id).get("armor", false))


static func heals(p_id: String) -> bool:
	## [B30] 治疗: this flight hunts a LIVE FRIENDLY body and its number MENDS rather than
	## wounds. Asked here and not read out of row() at each call site, for the same reason
	## pierce_of() is: "what does this column mean" must have one answer.
	return bool(row(p_id).get("heals", false))


static func size_of(p_id: String) -> float:
	## [B32] 尺寸: the pixel box this shot's picture is drawn in, or -1.0 when the row states none -
	## which is NOT "no size", it is "the picture itself answers" (Projectile.shot_box()). Asked here
	## rather than read out of row() at each of the three callers (the two flights and the 图鉴) so
	## "what does this column mean" keeps one answer, exactly like heals().
	return float(row(p_id).get("size", -1.0))


static func size_tier_of(p_id: String) -> String:
	## [B40] 体型 as the row spells it, "" when it spells nothing (= 标准). The WORD and not the
	## multiplier, for the reason look_of() returns the word: a caller that wants to REPORT the row
	## (the boot line, the 图鉴) must print what the sheet says and not a number it derived.
	_ensure()
	return str(row(p_id).get("size_tier", ""))


static func size_scale_of(p_id: String) -> float:
	## [B40] The MULTIPLIER this row's 体型 word is worth - the one door every drawer goes through,
	## so "大 means 1.5×" has exactly one owner (Balance.SIZE_TIERS) and no call site can quietly
	## decide that a big shot is only a bit big. 1.0 for a blank cell. Composes with size_of(): the
	## row's pixels first, then the magnitude, in Projectile.shot_box().
	_ensure()
	return Balance.size_scale(size_tier_of(p_id))


static func is_arc(p_id: String) -> bool:
	return trajectory(p_id) == TRAJ_ARC


static func speed_of(p_id: String) -> float:
	## <= 0 means "the default for this trajectory", which the projectile applies: pixel
	## values belong to BalanceUI, so a sheet never writes one.
	return float(row(p_id).get("speed", -1.0))


static func look_of(p_id: String) -> String:
	return str(row(p_id).get("look", LOOK_PEA))


static func art_rel(p_id: String) -> String:
	## The 贴图 CELL of one row as written (a short name, or a full res:// path), "" when the row
	## names no picture at all - the same answer gear_db.svg_rel() gives for a piece of gear.
	_ensure()
	return str(row(p_id).get("art", ""))


static func art_path(p_cell: String) -> String:
	## "pea" -> "res://assets/svg/shots/pea.svg". A cell that spells res:// or carries its own
	## extension is used as it is (gear_db.svg_path's rule, one door down).
	var text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(text):
		return ""
	if text.begins_with("res://"):
		return text
	if not (text.ends_with(".svg") or text.ends_with(".png")):
		text += SVG_EXT
	return SVG_ROOT + text


static func art_of(p_id: String) -> String:
	## WHAT BOTH THE BATTLE AND THE 图鉴 DRAW for this shot: the registered SVG when there is one
	## AND it really loads, "" otherwise. This is the one question the renderer asks, so the board
	## and the page can never disagree about which picture a row has (and a file that is missing
	## is not an error - the primitive the row's 外观 names draws instead).
	var path := art_path(art_rel(p_id))
	if path != "" and UnitArt.load_texture(path) != null:
		return path
	return ""


static func art_paths() -> Array:
	## Every picture the sheet names, whether or not it is imported yet: what UnitArt's start-up
	## art report walks (a sheet-named path that does not resolve is COUNTED, never failed).
	_ensure()
	var out: Array = []
	for id in _order:
		var path := art_path(art_rel(id))
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func status_of(p_id: String) -> String:
	return str(row(p_id).get("status", ""))


static func status_value_of(p_id: String) -> int:
	return int(row(p_id).get("status_value", 0))


static func effects_of(p_id: String) -> Dictionary:
	## The rider this shot carries, as the dict the hit layer wants: {} when it carries none.
	var id := status_of(p_id)
	if id == "":
		return {}
	var rounds := status_value_of(p_id)
	if rounds <= 0:
		rounds = StatusDB.default_rounds(id)
	return {id: rounds} if rounds > 0 else {}


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## One physical line per claim. The teeth: a 轨迹 or 外观 the base cannot fly / draw, or a
	## 命中状态 the status sheet does not have, makes this FAIL and names the row - a shot
	## whose shape nobody implements would otherwise look healthy in the file.
	print("[Shot] --- projectile sheet from %s ---" % PATH)
	_ensure()
	var ok := true
	print("[Shot] %d shot(s), source %s%s"
		% [_order.size(), source(), (" (sheet error: %s)" % _error) if _error != "" else ""])
	var traj_ok := true
	var look_ok := true
	var status_ok := true
	## [B40] The magnitude is checked the same way: a row that says a word the ladder does not have
	## is a row whose picture will be drawn at 标准 while the sheet claims it is big - the exact
	## half-said sentence the 轨迹 / 外观 checks exist to refuse.
	var tier_ok := true
	for id in _order:
		var traj := trajectory(id)
		var look := look_of(id)
		var status := status_of(id)
		var tier := size_tier_of(id)
		if not TRAJECTORIES.has(traj):
			traj_ok = false
			_problems.append("%s: \"%s\" is not a trajectory the base can fly (%s)"
				% [id, traj, ", ".join(TRAJECTORIES)])
		if not LOOKS.has(look):
			look_ok = false
			_problems.append("%s: \"%s\" is not a look the base can draw (%s)" % [id, look, ", ".join(LOOKS)])
		if status != "" and not StatusDB.has(status):
			status_ok = false
			_problems.append("%s: 命中状态 \"%s\" is not a status the status sheet has" % [id, status])
		if tier != "" and not Balance.is_size_tier(tier):
			tier_ok = false
			_problems.append("%s: 体型 \"%s\" is not a magnitude the ladder has (%s)"
				% [id, tier, ", ".join(Balance.SIZE_WORDS)])
		print("[Shot] %-18s %-6s 轨迹 %-4s pierce %d bounce %d armor %-5s splash %-4s status %-14s look %s 体型 %-4s x%.2f%s"
			% [id, name_of(id), traj, int(row(id).get("pierce", 0)), int(row(id).get("bounce", 0)),
			   str(bool(row(id).get("armor", false))), str(float(row(id).get("splash", 0.0))),
			   (status if status != "" else "-"), look, (tier if tier != "" else "-"),
			   size_scale_of(id),
			   (" | OK" if (TRAJECTORIES.has(traj) and LOOKS.has(look)
					and (status == "" or StatusDB.has(status))
					and (tier == "" or Balance.is_size_tier(tier))) else " | FAIL")])
	ok = ok and traj_ok and look_ok and status_ok and tier_ok
	print("[Shot] every 轨迹 / 外观 / 体型 is one the base implements, and every 命中状态 is a real status = %s | %s"
		% [str(traj_ok and look_ok and status_ok and tier_ok),
		   "OK" if (traj_ok and look_ok and status_ok and tier_ok) else "FAIL"])
	## The default row must exist: every shooter that says nothing fires THIS.
	var default_ok: bool = has(ID_PEA) and is_straight(ID_PEA)
	ok = ok and default_ok
	print("[Shot] the default row \"%s\" exists and is a straight line = %s | %s"
		% [ID_PEA, str(default_ok), "OK" if default_ok else "FAIL"])
	for problem in _problems:
		print("[Shot] warning: " + problem)
	ok = ok and _problems.is_empty()
	if _problems.size() > COMPLAINT_LIMIT:
		print("[Shot] warning: ... %d more not listed (cap: %d)" % [_problems.size() - COMPLAINT_LIMIT, COMPLAINT_LIMIT])
	print("[Shot] self-check %s" % ("PASSED" if ok else "FAILED"))
