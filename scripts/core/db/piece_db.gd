class_name PieceDB
extends RefCounted
## [B5] THE BRAWL'S PIECES - its factions, and the third facade over UnitSheet
## (PlantDB / ZombieDB, then this one; the name is the one docs/prompt/BRAWL.md §7 reserved).
##
## [P110f] IT IS NO LONGER ONLY THE HUMANS. A second faction (the monsters,
## data/units/monsters.csv) arrived, and rather than a second facade reading a second sheet the
## same way, this one reads a LIST of factions - see FACTIONS below. The class name and the file
## name still say "piece", which is what it always was.
##
## THE SHEET LAYOUT IS THE EXISTING ONE (BRAWL.md §8.1, option 甲): the pieces are ROWS of
## data/units/units.csv with race "humans", and their brawl-only columns live in the race
## sheet data/units/humans.csv - the same two layers plants and zombies already use. So the
## shared columns (名称 / name / race / HP / attack / 天赋 / 技能 / 特殊机制 / svg / tscn /
## rarity) are owned by units.csv exactly as they are for a peashooter, and nothing here
## re-spells one of them.
##
## WHAT THIS SHEET OWNS THAT NO OTHER ROSTER HAS: the numbers a REAL-TIME fight needs and the
## turn engine never asked for (BRAWL.md §8.1's missing columns) - attack距离 (cells), 移速
## (cells per second), attack间隔 (seconds between two attacks) and [B7+] 射弹 (the row of
## data/projectiles.csv this piece fires, blank for a body that fights what it can touch).
## They are read by HumanPiece and handed to BrawlActor through the piece's brawl_* accessors;
## a cell the sheet leaves blank falls back to BalanceBrawl, so a new row may state only what
## it cares about - and 射弹's fall-back is "no shot at all", which is what makes "add a
## projectile to a piece" one cell rather than one code branch.
##
## 费用 IS THE PIECE'S COST TIER (1-4), not the turn engine's sun price: this sheet is the
## brawl's, and there 费用 prices a piece in COINS (the shop asks PieceDB.cost()).
##
## WHAT IS NOT HERE: no self_check() block. The brawl's acceptance is the user's own manual
## pass (docs/STATE.md §2), so this reader reports through status_text() / problems() at
## boot exactly like FormationDB does, and adds no PASS/FAIL module.
##
## Failure policy: a missing or broken sheet is NOT fatal - the roster is empty, the boot
## line says so, and a session with no pieces is a page that shows no pieces.

const PATH := "res://data/units/humans.csv"
## The race root whose rows this roster lists (UnitSheet filters units.csv by it).
const RACE_ROOT := "humans"
## [P110f] THE FACTIONS THIS READER SERVES. One row per race, and the ONLY place a faction's
## sheet and its two art roots are spelled: adding a faction is a row here plus its own
## data/units/<race>.csv (the same two-layer shape humans.csv always had), and no other file
## moves. The rows of every faction share one id space - ids are unique across the sheets, and
## every accessor below takes an id and nothing else, which is why no caller changed.
const FACTIONS := {
	"humans": {
		"sheet": PATH,
		## NOTE the folder is "human", not "humans": the picture the user drew predates the
		## race name, and moving it is the user's call (AGENTS.md §1) - see the note below.
		"svg": "res://assets/svg/units/human/",
		"scene": "res://scenes/units/humans/",
	},
	"monsters": {
		"sheet": "res://data/units/monsters.csv",
		"svg": "res://assets/svg/units/monsters/",
		"scene": "res://scenes/units/monsters/",
	},
	## [B19] THE THIRD FACTION (the user's 机械): the first member is the lobber, a shell that
	## arcs over the front row and detonates where it lands. No scene folder exists yet and none
	## is needed - its rows draw their SVG through Unit, the same way the monsters do.
	"machine": {
		"sheet": "res://data/units/machine.csv",
		"svg": "res://assets/svg/units/machine/",
		"scene": "res://scenes/units/machines/",
	},
	## [B38] THE FOURTH FACTION (the user's 宝可梦): its first member is 卡比兽, a body that bumps
	## what it can reach and, at a full bar, jumps into the enemy line. Like the machines it has no
	## scene folder and needs none - its rows draw their SVG through Unit (`tscn = —`).
	"pokemon": {
		"sheet": "res://data/units/pokemon.csv",
		"svg": "res://assets/svg/units/pokemon/",
		"scene": "res://scenes/units/pokemon/",
	},
	## [B39] THE FIFTH FACTION (the user's 动物): the first member is 鸟怪, a body that calls up a
	## whirlwind. The pictures were drawn before the faction existed - the folder also holds a dog, a
	## whale and a wolf, and only bird.svg has an asset today (see `ls assets/svg/units/animals/`).
	## Like the machines and the pokemon it has no scene folder and needs none: its rows draw their SVG
	## through Unit (`tscn = —`), which is D80's trap - a row that inherited a body scene would be
	## drawn with that scene and its own svg would never paint.
	"animals": {
		"sheet": "res://data/units/animals.csv",
		"svg": "res://assets/svg/units/animals/",
		"scene": "res://scenes/units/animals/",
	},
}
## What a cell that says nothing about its faction means - the humans, because they came first
## and every reader that predates FACTIONS still speaks about them.
const FACTION_DEFAULT := "humans"
## [P110f] The two SUFFIXES are shared by every faction; the ROOTS are per-faction and live in
## FACTIONS above, which is the one home for "where a faction's pictures are". NOTE the suffix
## is ".tscn" and not "_view.tscn": human.tscn, the bone-animated figure, is this roster's
## convention and the plants' "_view.tscn" is theirs - and a cell may always spell a full
## res:// path instead, skipping the root entirely.
const SVG_EXT := ".svg"
const SCENE_SUFFIX := ".tscn"

# ---------------------------------------------------------------- sheet columns
const COL_ID := UnitSheet.COL_ID
const COL_NAME := UnitSheet.COL_NAME
const COL_HP := UnitSheet.COL_HP
const COL_ATTACK := UnitSheet.COL_ATTACK
const COL_TALENT := UnitSheet.COL_TALENT
const COL_SKILL := UnitSheet.COL_SKILL
const COL_SPECIAL := UnitSheet.COL_SPECIAL
const COL_SVG := UnitSheet.COL_SVG
const COL_TSCN := UnitSheet.COL_TSCN
const COL_RARITY := UnitSheet.COL_RARITY
## [B5] The three real-time columns this roster owns (see the header).
const COL_COST := "费用"
const COL_REACH := "attack距离"
const COL_SPEED := "移速"
const COL_INTERVAL := "attack间隔"
## [B7+] The shot a row fires, by the id of data/projectiles.csv. Blank (or "—") = melee: the
## piece swings at what it can touch, which is what every human but the archer and the gunner
## does today. The column is NOT validated here - ProjectileDB owns which ids exist, and a typo
## shows up as the pea's fall-back row rather than as a piece that fires nothing.
const COL_SHOT := "射弹"
## [P110f] THE THIRD ATTACK SHAPE: a row that names a picture HERE does not fire a flying shot
## and does not swing - it hits INSTANTLY (hitscan) and draws the named beam between the two
## bodies. Blank = not this shape, which is what every human row says.
##
## A piece's attack is therefore read off two cells, in this order: 射弹 (a shot that FLIES),
## then 远程特效 (a beam that does not), then 近战特效 (a swing) - and a row that fills none of
## the three is a melee body with the generic spark, which is the shieldman.
const COL_RANGED_FX := "远程特效"
## [P110g] HOW LONG THAT BEAM BURNS, in seconds. Blank (or 0) = it lands ONCE, which is the
## laser eye's 瞬发光束 and the flame eye's 喷射火焰; a number turns the same attack into a
## CHANNEL that keeps dealing damage in ticks for that long (the eye tower's 3 seconds of
## 连续冲击光束). The gap between two channels is not a second cell: attack间隔 is the whole cycle.
const COL_BEAM_SECONDS := "持续"
## [P110e] THE PICTURE A MELEE BLOW LEAVES, by the id of a drawing under assets/svg/fx/ - the
## exact twin of 射弹 one line up, for the other half of the roster: a piece whose 射弹 cell is
## blank fights what it can touch, and THIS cell says what that looks like. Blank = the generic
## impact spark, which is what the shieldman gets today. Not validated here either, for the same
## reason: Fx owns which drawings exist, and a typo costs that piece its picture and nothing else.
const COL_MELEE_FX := "近战特效"
## [B9] 击退: HOW MANY CELLS THIS ROW'S BLOW THROWS THE BODY IT LANDS ON. Blank = 0 = the blow
## only damages, which is what five of the six humans and every monster say. The number is a
## DISTANCE IN CELLS and not a flag, for the same reason attack距离 is a number: "shove it one cell"
## and "shove it two" are two rows of the same rule, and the brawl's own pace for HOW FAST that
## distance is travelled is BalanceBrawl.SHOVE_CELLS_PER_SECOND (the sheet owns the rule, the
## table owns the presentation - the split 近战特效 / MELEE_FX_SIZE already uses).
## A sheet that never mentions the column reads as blank, so a faction that has no pusher does
## not have to declare it - DECLARING IT ANYWAY is what keeps the missing-column complaint quiet
## for the factions that share this reader (see UnitCsvManager._check_column).
const COL_KNOCKBACK := "击退"
## [B10] 吞噬: HOW MANY SECONDS THIS ROW HOLDS WHAT IT SWALLOWS. Blank = 0 = this row's blows are
## ordinary blows. A positive cell does not merely add an effect to a blow - it REPLACES the
## blow: a devourer does no damage on contact at all, it takes the enemy INSIDE and pays the
## damage out while it digests (see BalanceBrawl.GULP_* and scripts/core/brawl/brawl_gulp.gd).
## That is why the cell is a DURATION and not a damage number: the duration is what the piece
## IS, and how hard a second of it bites is one global rule for every devourer.
const COL_GULP := "吞噬"
## [B14] 大招持续: HOW MANY SECONDS THIS ROW'S ULTIMATE HOLDS THE BATTLE. Blank (or 0) = this row
## has no ultimate AT ALL - no energy bar is drawn under it, its blows never bank energy, and it
## attacks with 远程特效 的一闪 exactly like the laser eye.
##
## A positive cell turns the row's own beam into an ULTIMATE: every ordinary blow banks energy
## (BalanceBrawl.ENERGY_PER_STRIKE), the whole bar is spent at ENERGY_MAX, and what it buys is the
## SAME beam HELD for this many seconds - the same channel shape a 持续 cell opens, at
## BalanceBrawl.ULT_TICK_SHARE per tick instead of BEAM_TICK_SHARE (an ultimate is a burst, a
## cadence is a cadence - BRAWL.md §8.13).
## ⚠ It does NOT name a second look: a row's ultimate is its own beam. A row that fills this cell
## and names no 远程特效 has an ultimate it cannot draw, and the arena falls back to ordinary
## blows (the boot line counts the rows that say it, see status_text).
const COL_ULT_SECONDS := "大招持续"
## [B38] 大招范围: HOW MANY CELLS THIS ROW'S ULTIMATE SLAMS, measured from where it lands. Blank (or
## 0) = this row has no area ultimate, and 大招持续 above is the whole of what a full bar buys.
##
## A POSITIVE CELL DOES NOT ADD A RIDER TO THE ULTIMATE - IT CHANGES WHICH ULTIMATE THE ROW HAS.
## BrawlActor._open_ultimate reads this first: a row that states a radius JUMPS (crouch, fly over
## the scrum, land inside the enemy line, pay one blow to everything within this many cells) and
## never touches the beam path, because a leaper has no beam to hold. That is why 大招持续 stays BLANK
## on such a row: writing seconds there would be a lie about a channel that never opens, and the
## energy bar does not need it (HumanPiece.has_ultimate() asks both cells now).
##
## The cell is a RADIUS IN CELLS and not a damage number, for the same reason 击退 is a distance:
## "a small slam" and "a wide one" are two rows of one rule, and how hard it hits is the piece's
## ordinary blow (blow_value) - no second damage table (BRAWL.md §12). The three numbers of the
## FLIGHT (the crouch, the pace, the arc) are the mode's rule and live in BalanceBrawl.LEAP_*.
const COL_ULT_RADIUS := "大招范围"
## [B38] 大招震飞: HOW MANY CELLS THE SLAM THROWS EVERY BODY IT LANDS ON. Blank = 0 = the slam only
## damages, and neighbours stay on their feet. It is a SECOND distance rather than the 击退 cell
## because the two rules are different sentences: 击退 is what a piece's ordinary blow does to the one
## body it touched, this is what the ground does to everybody inside the circle - 卡比兽's bump shoves
## nobody and its landing throws a whole line. The two still ADD when a row fills both, because
## BrawlActor.shove_from's rule is that budgets are distances and distances add.
const COL_ULT_KNOCK := "大招震飞"
## [B39] 旋风: HOW MANY CELLS THE WHIRLWIND THIS ROW SUMMONS WALKS, measured from the body that calls
## it up ([B41] 用户: "准确地说，鸟怪应该是在身前召唤出旋风，而不是发射旋风" - the funnel takes the
## summoner's OWN facing and the arena is handed no target, so this distance is a walk in front of the
## piece rather than a shot at one). Blank
## (or 0) = this row does not summon one, and a blank cell IS that answer rather than a question - the
## passthrough shape 击退 / 吞噬 / 大招范围 already have.
##
## A positive cell does not ADD an effect to a blow, it REPLACES the blow, exactly like 吞噬 does: the
## strike spends itself on the funnel and nothing is landed on the body the piece was aiming at
## (BrawlActor._strike_once's fifth shape). What separates it from the other four is that the damage
## is neither instant nor one hit - it is the BEAM's cadence paid out along the SHOT's path, to every
## body the funnel walks over and not to the one it was aimed at.
##
## The cell is a DISTANCE IN CELLS and not a damage number, for the same reason 击退 is a distance:
## "a gust that goes two cells" and "a front that goes six" are two rows of one rule. The five numbers
## every whirlwind shares - its pace, the funnel's radius, the pulse, the pulse's share and the height
## of the column it occupies - are the mode's and live in BalanceBrawl.TORNADO_*.
##
## ⚠ Its DISPATCH position is beside 射弹 (both put a moving thing on the grass instead of landing a
## blow on one body, and both are checked before the height
## gate, which the moving thing answers for itself); its COLUMN was the sheet's last until [W12c]
## appended 大招击退 and 受击积攒 behind it, because a new column can only ever be appended. One row
## that fills both 射弹 and 旋风 gets the shot - the
## order among the shapes is the order the arena reads them, not the order they are typed.
const COL_TORNADO := "旋风"
## [W12c] 大招击退: HOW MANY CELLS THIS ROW'S ULTIMATE THROWS EVERY ENEMY IN ITS CIRCLE. Blank (or
## 0) = this row's full bar is not a push. A THIRD distance, because the sentence it answers is a
## third sentence: 击退 is what an ordinary blow does to the one body it touched, 大招震飞 is what the
## ground does under a landing, and this is what STANDING ONE'S GROUND AT FULL ENERGY does to
## everybody nearby - so the circle it measures is the 大招范围 cell's, and the pace of the slide
## stays the mode's (BalanceBrawl.SHOVE_CELLS_PER_SECOND, the same borrowed ruler).
const COL_ULT_PUSH := "大招击退"
## [W12c] 受击积攒: HOW MUCH ENERGY THIS ROW BANKS FOR EVERY BLOW THAT LANDS ON IT. Blank = 0 =
## being hit charges nothing. The FIRST energy column asked of the RECEIVER: ENERGY_PER_STRIKE is
## the mode's number for what the row HITS, and 盾卫's wall says the opposite - the shield is paid
## for in cuts taken (BrawlActor.land_hit's victim side, BRAWL.md §8.13).
const COL_HIT_CHARGE := "受击积攒"
## [B16] 朝向 IS NOT THIS SHEET'S ANY MORE. [B14] read it from a 朝向 column of the faction
## sheets; the user moved the fact to units.csv's `face` column, because "which way does this
## body's picture look" is a UNIT fact and not a brawl one - a plant, a zombie and a monster
## all answer it out of the same row now (UnitSheet.face_left -> Unit.faces_left). What this
## reader keeps is everything the brawl ALONE needs: how it moves, how far it reaches, how
## often it strikes, and which of the five attack shapes it uses.

## The prose columns the almanac-style readers ask for by name. A human row may leave any
## of them blank; the sheet's Chinese wording is the fall-back for the English one.
## [P112] "ultimate" joins them: the NEW shared 大招 column on units.csv is the shout-name for a
## piece whose full bar is real (the shieldman's 盾墙冲击, 卡比兽's slam). A plant answers its ult
## name from plants.csv and never comes through this door (it is not a piece), and a row that
## leaves the cell blank simply shouts nothing - PieceDB.text(id, "ultimate") reads "".
const TEXT_FIELDS: Array[String] = ["name", "talent", "skill", "special", "ultimate"]
const SOURCE_COLUMNS := {
	"name": COL_NAME,
	"talent": COL_TALENT,
	"skill": COL_SKILL,
	"special": COL_SPECIAL,
	"ultimate": "大招",
}

static var _rows: Dictionary = {}          # id -> parsed row (see _parse_row)
static var _order: Array[String] = []      # the roster's own order, top to bottom
static var _loaded := false
static var _tried := false
static var _error := ""
static var _problems: Array[String] = []
static var _missing_en := 0                # prose fields served in Chinese


# ---------------------------------------------------------------- loading
static func _sheet() -> UnitSheet:
	return UnitSheet.live()


static func load_from_disk() -> bool:
	## Reads the roster once (Game at boot; every accessor also calls _ensure()).
	_tried = true
	_rows.clear()
	_order.clear()
	_problems.clear()
	_missing_en = 0
	_error = ""

	var sheet := _sheet()
	if not sheet.load_roster():
		_error = sheet.error_text()
		_loaded = false
		return false
	## [P110f] ONE PASS PER FACTION, in the table's order: the sheet itself is loaded once (it
	## carries units.csv plus every race table), and ids_for() is what separates the factions.
	for race in FACTIONS:
		for id in sheet.ids_for(str(race)):
			var parsed := _parse_row(sheet.get_flat(id), id, str(race))
			if parsed.is_empty():
				continue
			_rows[id] = parsed
			_order.append(id)
	## The roster-level complaints belong to the sheet, so every reader reports them.
	_problems = sheet.problems()
	_problems.append_array(sheet.orphans())
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable human row"
	return _loaded


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func _parse_row(p_raw: Dictionary, p_id: String, p_race: String) -> Dictionary:
	var texts: Dictionary = {}
	for field in TEXT_FIELDS:
		var column := str(SOURCE_COLUMNS[field])
		var zh := UnitCsvManager.cell(p_raw, column)
		var en := UnitCsvManager.cell_en(p_raw, column)
		texts[field] = {"zh": zh, "en": en}
		if field != "name" and zh != "" and not UnitCsvManager.has_en(p_raw, column):
			_missing_en += 1
	## [B5] The three real-time cells are kept as the sheet spells them ("—" -> ""), so
	## "the sheet said nothing" stays distinguishable from "the sheet said 0" - the readers
	## below are what turn a blank into BalanceBrawl's fall-back.
	return {
		"id": p_id,
		## [P110f] which faction this row came from. Written once here so the two art resolvers
		## below never have to guess it from the id (an id is a name, not a faction).
		"race": p_race,
		"texts": texts,
		"svg": UnitCsvManager.cell(p_raw, COL_SVG),
		"tscn": UnitCsvManager.cell(p_raw, COL_TSCN),
		"hp": UnitCsvManager.int_cell(p_raw, [COL_HP], 0),
		"attack": UnitCsvManager.int_cell(p_raw, [COL_ATTACK], 0),
		"cost": UnitCsvManager.int_cell(p_raw, [COL_COST], 0),
		"rarity": UnitCsvManager.cell(p_raw, COL_RARITY),
		## [B5] Read with float_cell(), NOT rate_cell(): a reach of 3 cells is 3.0, and the
		## rate reader would take anything above 1 for a percentage. 0.0 = the sheet said
		## nothing, which is the callers' cue to use BalanceBrawl's fall-back.
		"reach": UnitCsvManager.float_cell(p_raw, [COL_REACH], 0.0),
		"speed": UnitCsvManager.float_cell(p_raw, [COL_SPEED], 0.0),
		"interval": UnitCsvManager.float_cell(p_raw, [COL_INTERVAL], 0.0),
		"shot": UnitCsvManager.cell(p_raw, COL_SHOT),
		"melee_fx": UnitCsvManager.cell(p_raw, COL_MELEE_FX),
		"ranged_fx": UnitCsvManager.cell(p_raw, COL_RANGED_FX),
		"beam_seconds": UnitCsvManager.float_cell(p_raw, [COL_BEAM_SECONDS], 0.0),
		## [B9] int_cell and not float_cell: a shove is a whole number of CELLS, and "half a
		## cell" would be a distance no rule here can express (the body would stop between two
		## cells, which the lattice this mode is read against cannot show).
		"knockback": UnitCsvManager.int_cell(p_raw, [COL_KNOCKBACK], 0),
		## [B10] float_cell and not rate_cell(): 6 seconds is 6.0, and the rate reader would take
		## anything above 1 for a percentage (the same trap the reach/speed/持续 cells have).
		"gulp": UnitCsvManager.float_cell(p_raw, [COL_GULP], 0.0),
		## [B14] float_cell for the same trap the 持续 / reach / speed cells have: 3 seconds is
		## 3.0, and the rate reader would take anything above 1 for a percentage.
		"ult_seconds": UnitCsvManager.float_cell(p_raw, [COL_ULT_SECONDS], 0.0),
		## [B38] float_cell for the radius (1.5 cells is 1.5) and int_cell for the throw (a body
		## stops on a cell, the same argument 击退 has): both are DISTANCES on the board's own ruler,
		## and rate_cell() would read anything above 1 as a percentage.
		"ult_radius": UnitCsvManager.float_cell(p_raw, [COL_ULT_RADIUS], 0.0),
		"ult_knock": UnitCsvManager.int_cell(p_raw, [COL_ULT_KNOCK], 0),
		## [B39] float_cell, for the fourth time: six cells is 6.0 and rate_cell() would read it as
		## six hundred percent. A DISTANCE on the board's own ruler, like 击退 and 大招范围.
		"tornado": UnitCsvManager.float_cell(p_raw, [COL_TORNADO], 0.0),
		## [W12c] int_cell for both, and neither can be anything else: a shove is a whole number of
		## CELLS (击退's stated argument), and energy is a whole number of BAR POINTS -
		## Unit.charge_ultimate speaks integers, so "12.5 per hit" would round every landing.
		"ult_push": UnitCsvManager.int_cell(p_raw, [COL_ULT_PUSH], 0),
		"hit_charge": UnitCsvManager.int_cell(p_raw, [COL_HIT_CHARGE], 0),
	}


# ---------------------------------------------------------------- path rules
static func _roots(p_race: String) -> Dictionary:
	## [P110f] One faction's three roots, with the default answering for an unknown name - so a
	## typo in a race can never leave a caller holding a null dictionary.
	return FACTIONS[p_race] if FACTIONS.has(p_race) else FACTIONS[FACTION_DEFAULT]


static func race_of(p_id: String) -> String:
	## [P110f] Which faction a piece belongs to. Its readers are the pair of resolvers below: a
	## row's picture lives under ITS OWN faction's root, never under the first faction's.
	_ensure()
	return str(row(p_id).get("race", FACTION_DEFAULT))


static func svg_path(p_cell: String, p_race: String = FACTION_DEFAULT) -> String:
	## "militia" -> "res://assets/svg/units/human/militia.svg"; "laser_eye" ->
	## "res://assets/svg/units/monsters/laser_eye.svg". The root is the FACTION's, the rule is
	## otherwise unchanged: a cell that already spells a full res:// path, or carries its own
	## extension, is used as it is - the same rule PlantDB.svg_path / ZombieDB.svg_path follow,
	## so the short and the long spelling reach the same file.
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not (cell_text.ends_with(".svg") or cell_text.ends_with(".png")):
		cell_text += SVG_EXT
	return str(_roots(p_race)["svg"]) + cell_text


static func scene_path(p_cell: String, p_race: String = FACTION_DEFAULT) -> String:
	## "human" -> "res://scenes/units/humans/human.tscn" (see SCENE_SUFFIX), and the root is the
	## FACTION's exactly like svg_path above.
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not cell_text.ends_with(".tscn"):
		cell_text += SCENE_SUFFIX
	return str(_roots(p_race)["scene"]) + cell_text


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
	return _rows.has(p_id)


static func row(p_id: String) -> Dictionary:
	_ensure()
	return _rows.get(p_id, {})


static func name(p_id: String) -> String:
	## LocNames "piece.<id>" first (the language layer owns the NAME), the sheet second -
	## the same order PlantDB.name / ZombieDB.name use.
	_ensure()
	var fallback := text(p_id, "name")
	if fallback == "":
		fallback = p_id
	return Loc.t("piece." + p_id, fallback)


static func text(p_id: String, p_field: String) -> String:
	_ensure()
	var r := row(p_id)
	if r.is_empty():
		return ""
	var texts: Dictionary = r.get("texts", {})
	var d: Dictionary = texts.get(p_field, {})
	var want := "zh" if Loc.prefer_zh() else "en"
	var out := str(d.get(want, ""))
	if out == "":
		out = str(d.get("en" if want == "zh" else "zh", ""))
	return out


static func hp(p_id: String) -> int:
	## The attack/HP cells come from units.csv (shared columns) and a blank one has already
	## been answered by the default chain (units.csv's "default" row for race humans, then
	## humans.csv's own), so the 1 below is the last resort of a sheet that states neither.
	return maxi(1, int(row(p_id).get("hp", 1)))


static func attack(p_id: String) -> int:
	return maxi(0, int(row(p_id).get("attack", 0)))


static func cost(p_id: String) -> int:
	## The cost TIER (1-4). The shop turns it into coins (BalanceBrawl.PIECE_PRICE_PER_COST);
	## the two are kept apart because "what tier is this champion" and "what does the shop
	## charge today" are different questions - the turn engine's 费用 is a third one.
	return maxi(1, int(row(p_id).get("cost", 1)))


static func rarity(p_id: String) -> String:
	return str(row(p_id).get("rarity", ""))


static func reach(p_id: String) -> float:
	## Attack reach in CELLS. 0.0 means "the sheet said nothing", which is the caller's cue
	## to use BalanceBrawl's fall-back - this reader never invents a number of its own.
	return maxf(0.0, float(row(p_id).get("reach", 0.0)))


static func move_speed(p_id: String) -> float:
	## Cells per second. Same rule as reach(): 0.0 means "the sheet said nothing".
	return maxf(0.0, float(row(p_id).get("speed", 0.0)))


static func strike_seconds(p_id: String) -> float:
	## Seconds between two attacks. Same rule as reach(): 0.0 means "the sheet said nothing".
	return maxf(0.0, float(row(p_id).get("interval", 0.0)))


static func shot(p_id: String) -> String:
	## [B7+] The projectile row this piece fires, or "" for a body that fights what it can
	## touch. NOT validated against ProjectileDB here on purpose (see COL_SHOT): which shots
	## exist is the shot sheet's fact, and a piece whose cell names a row that is not there
	## fires the pea fall-back - visible in the log, never a piece that attacks with nothing.
	return str(row(p_id).get("shot", ""))


static func melee_fx(p_id: String) -> String:
	## [P110e] The drawing this row's melee blow leaves where it lands, or "" for no picture of
	## its own (the arena then draws the generic spark). Not validated against the fx folder for
	## the same reason shot() is not validated against ProjectileDB: which drawings exist is the
	## fx layer's fact, and a cell that names one nobody drew costs a picture, not a blow.
	return str(row(p_id).get("melee_fx", ""))


static func ranged_fx(p_id: String) -> String:
	## [P110f] The BEAM this row attacks with, or "" for a row that does not attack that way -
	## the third attack shape, alongside shot() (a projectile that flies) and melee_fx() (a
	## swing). Not validated here either: Fx owns which beams exist, and a name nobody drew
	## costs the picture, not the blow.
	return str(row(p_id).get("ranged_fx", ""))


static func beam_seconds(p_id: String) -> float:
	## [P110g] How long this row's beam BURNS, or 0.0 for a row whose attack lands once - either
	## because it is not a beam at all or because it is the flashing kind. Read with float_cell()
	## and not rate_cell(), for the reason the reach/speed cells are: 3 seconds is 3.0, and the
	## rate reader would take anything above 1 for a percentage.
	return maxf(0.0, float(row(p_id).get("beam_seconds", 0.0)))


static func knockback(p_id: String) -> int:
	## [B9] HOW MANY CELLS THIS PIECE'S BLOW SHOVES ITS VICTIM, or 0 for a body whose blows only
	## damage. There is no fall-back to choose here - unlike reach / speed / interval, a blank
	## cell is not "the sheet said nothing, ask BalanceBrawl", it is the answer itself: this row
	## does not push. So the reader is a passthrough and the door on the body is one line.
	return maxi(0, int(row(p_id).get("knockback", 0)))


static func gulp_seconds(p_id: String) -> float:
	## [B10] HOW LONG THIS PIECE DIGESTS WHAT IT SWALLOWS, in seconds; 0.0 = its blows do not
	## swallow at all. The same shape as knockback() above: no fall-back to choose, because a
	## blank cell IS the answer ("this row does not devour"), and the pace of the damage that
	## runs while the prey is inside is one rule for every devourer (BalanceBrawl.GULP_*).
	return maxf(0.0, float(row(p_id).get("gulp", 0.0)))


static func ult_seconds(p_id: String) -> float:
	## [B14] How long this row's ULTIMATE holds, in seconds; 0.0 = the row has no ultimate. The
	## same shape as beam_seconds() above and read with the same reader, for the same reason: it is
	## a duration, not a percentage. No fall-back to choose - a blank cell IS the answer ("this row
	## does not have one"), exactly like 击退 and 吞噬.
	return maxf(0.0, float(row(p_id).get("ult_seconds", 0.0)))


static func ult_radius(p_id: String) -> float:
	## [B38] How many cells this row's ultimate SLAMS, in cells; 0.0 = the row has no area ultimate
	## and 大招持续 (if it states one) is the whole of what its bar buys. The same passthrough shape
	## as ult_seconds() / knockback(): a blank cell IS the answer, there is no fall-back to choose -
	## BalanceBrawl owns how a leap TRAVELS, never how wide its landing is.
	return maxf(0.0, float(row(p_id).get("ult_radius", 0.0)))


static func ult_knock(p_id: String) -> int:
	## [B38] How many cells this row's slam THROWS the bodies it lands on; 0 = nobody leaves their
	## feet. A passthrough for the same reason as above.
	return maxi(0, int(row(p_id).get("ult_knock", 0)))


static func tornado_cells(p_id: String) -> float:
	## [B39] How many cells this row's WHIRLWIND walks; 0.0 = the row summons nothing and its strike
	## is one of the other four shapes. A passthrough for the fourth time (like 击退 / 吞噬 / 大招范围):
	## a blank cell IS the answer, there is no fall-back to choose - BalanceBrawl owns how a funnel
	## travels and how its pulse is priced, never how far this bird's storm reaches.
	return maxf(0.0, float(row(p_id).get("tornado", 0.0)))


static func ult_push(p_id: String) -> int:
	## [W12c] How many cells this row's ultimate THROWS the enemies standing in its circle;
	## 0 = the row's full bar is not a push. A passthrough for the fifth time (like 击退 / 吞噬 /
	## 大招范围): a blank cell IS the answer - the circle is measured by 大招范围 and the slide is
	## paced by BalanceBrawl, so this cell owns the distance and nothing else.
	return maxi(0, int(row(p_id).get("ult_push", 0)))


static func hit_charge(p_id: String) -> int:
	## [W12c] How much energy a blow LANDED ON this row banks it; 0 = being hit charges nothing.
	## The passthrough shape again - and note whose sentence this one is: the VICTIM's, on the
	## receiver's row, which is why BrawlActor.land_hit asks it of the body it just struck and
	## never of the striker.
	return maxi(0, int(row(p_id).get("hit_charge", 0)))


static func svg_rel(p_id: String) -> String:
	_ensure()
	return str(row(p_id).get("svg", ""))


static func svg_file(p_id: String) -> String:
	return svg_path(svg_rel(p_id), race_of(p_id))


static func art(p_id: String) -> String:
	## The picture this piece wears. A row with no usable file falls back to the FIRST row's
	## art (every human is the one figure today) and, with no art at all, to the flat
	## placeholder shape Unit draws - never to a plant's or a zombie's sprite, which is the
	## wrong-roster bug Balance.unit_art() was written to end.
	var path := svg_file(p_id)
	if path != "" and UnitArt.load_texture(path) != null:
		return path
	## [P110f] The fall-back stays INSIDE the piece's own faction. Before this it walked every
	## id, so a monster with no picture of its own would have borrowed a HUMAN's - which is the
	## wrong-roster bug this function was written to end in the first place.
	for id in ids():
		if race_of(str(id)) != race_of(p_id):
			continue
		var other := svg_file(str(id))
		if other != "" and UnitArt.load_texture(other) != null:
			return other
	return ""


static func has_art(p_id: String) -> bool:
	return art(p_id) != ""


static func art_paths() -> Array:
	_ensure()
	var out: Array = []
	for id in _order:
		var path := svg_file(id)
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func scene_rel(p_id: String) -> String:
	_ensure()
	return str(row(p_id).get("tscn", ""))


static func scene_file(p_id: String) -> String:
	## What the SHEET registers (whether or not the file exists yet).
	return scene_path(scene_rel(p_id), race_of(p_id))


static func view(p_id: String) -> String:
	## What the board DRAWS: the registered scene when it loads, "" otherwise (the piece then
	## draws its sprite - Unit's three-step chain, see docs/ARCHITECTURE.md §4).
	var path := scene_file(p_id)
	if path != "" and UnitArt.load_scene(path) != null:
		return path
	return ""


static func has_view(p_id: String) -> bool:
	return view(p_id) != ""


# ---------------------------------------------------------------- reporting
static func faction_names() -> String:
	## [P110f] The factions this reader loaded, in the table's order, for the boot line. Built by
	## hand rather than by stringifying the dictionary: the line has to be readable in a log.
	var names: PackedStringArray = []
	for race in FACTIONS:
		names.append(str(race))
	return ", ".join(names)


static func status_text() -> String:
	_ensure()
	if not _loaded:
		return "pieces: sheet NOT loaded (%s)" % error_text()
	var speeds := 0
	var reaches := 0
	var shots := 0
	var melee_fxs := 0
	var ranged_fxs := 0
	var knockbacks := 0
	var gulps := 0
	var ultimates := 0
	## [P112] How many rows have a shoutable 大招 NAME ([B14]'s beam-ults name the shout too):
	## the line to look at when a piece was meant to shout its ultimate and stays silent - a blank
	## 大招 cell on units.csv is invisible in play, so it is counted here.
	var ult_names := 0
	## [B38] Counted apart from `ultimates`: the two ultimate CELLS are two different ultimates.
	var leaps := 0
	## [B39] And the fifth attack shape, counted by itself for the same reason the leap is: a 旋风 cell
	## REPLACES the blow, so a row that was meant to summon a whirlwind and instead swings is exactly
	## the silent symptom this line exists to catch - a column the sheet lost, or a number typed into
	## the 吞噬 cell beside it.
	var tornadoes := 0
	for id in _order:
		if move_speed(id) > 0.0:
			speeds += 1
		if reach(id) > 0.0:
			reaches += 1
		## [B7+] How many rows carry a projectile: the one number the manual pass wants when a
		## piece was meant to be ranged and is swinging instead (a blank 射弹 cell is silent).
		if shot(id) != "":
			shots += 1
		## [P110e] And its twin: how many rows say what a MELEE blow looks like. A blank cell is
		## not a fault (the shieldman keeps the generic spark), so this is a reading rather than
		## a complaint - and it is the line to look at when a slash does not appear.
		if melee_fx(id) != "":
			melee_fxs += 1
		## [P110f] And the third shape: how many rows attack with a BEAM rather than a swing or
		## a flying shot (the monsters). Same reading, same purpose.
		if ranged_fx(id) != "":
			ranged_fxs += 1
		## [B9] And how many rows SHOVE what they hit. This is the line to look at when a piece
		## was meant to knock its target back and is only bruising it: a blank 击退 cell, a value
		## typed into the wrong column, or a header the sheet lost are all invisible otherwise.
		if knockback(id) > 0:
			knockbacks += 1
		## [B10] And how many rows SWALLOW what they touch. Same purpose: a piece that was meant to
		## devour and is only bruising its target has a blank 吞噬 cell, or a number in the wrong
		## column - and nothing else in the log would say so.
		if gulp_seconds(id) > 0.0:
			gulps += 1
		## [B14] And how many rows say their attack is not the whole of it (大招持续 = seconds). This
		## is the line to look at when a piece was meant to build an energy bar and never does: a
		## blank cell, a number in the wrong column, or a column the sheet lost are all silent.
		if ult_seconds(id) > 0.0:
			ultimates += 1
		## [B38] ...and how many rows answer that same bar with a LEAP instead of a beam (大招范围).
		## The two are counted APART because they are the two answers a full bar can buy, and the
		## symptom this exists to catch is the opposite of a silent one: a row that states BOTH cells
		## jumps and never holds a beam, so the 大招持续 number would be invisible in play.
		if ult_radius(id) > 0.0:
			leaps += 1
		## [B39] ...and how many rows summon a whirlwind instead of landing their blow.
		if tornado_cells(id) > 0.0:
			tornadoes += 1
		## [P112] ...and how many rows name their ultimate (the shout reads this cell).
		if text(str(id), "ultimate") != "":
			ult_names += 1
	return "pieces: %d row(s) in %d faction(s) [%s], %d with a 移速, %d with an attack距离, %d with a 射弹, %d with a 近战特效, %d with a 远程特效, %d with a 击退, %d with a 吞噬, %d with a 大招 beam, %d with a 大招 leap, %d with a 旋风, %d with a 大招名称, %d prose field(s) with no English twin" 		% [_order.size(), FACTIONS.size(), faction_names(),
		   speeds, reaches, shots, melee_fxs, ranged_fxs, knockbacks, gulps, ultimates, leaps, tornadoes, ult_names, _missing_en]


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()
