class_name PlantDB
extends RefCounted
## [P26] THE PLANT ROSTER - now [P29] a thin facade over UnitSheet.
##
## The layout question this class used to answer twice (load, merge, query,
## self-check) is answered once in scripts/core/unit_sheet.gd: the shared columns
## (名称 / name / race / HP / 天赋 / 技能 / 特殊机制 / svg / tscn) come from
## data/units/units.csv, the plant-only columns from the race sheet
## data/units/plants.csv, and a future family sheet (pea.csv, mushroom.csv ...)
## overrides them per unit - a missing family layer is simply skipped.
##
## What stays HERE is what only plants care about:
##   the plant column names and their parsing (cost / cooldown / growth cells),
##   the "playable" wiring (a sheet plant without a unit script cannot be
##   summoned - is_playable() answers that), the one-shot phrase, and this
##   roster's self-check text.
##
## The svg / tscn cells are still relative paths resolved under the plants
## folders (the race's first segment picks the folder, which for this DB is
## always "plants"): art() / has_art() / view() and their self-check lines are
## unchanged from P28, callers included.
##
## Failure policy: a missing or broken sheet is NOT fatal. The game keeps running
## on Balance's built-in defaults, and self_check() prints exactly what happened.

const PATH := "res://data/units/plants.csv"
## [P29] The race root whose rows this roster lists (UnitSheet filters the
## shared units.csv by it). The svg / tscn roots hang off the same token.
const RACE_ROOT := "plants"
## [P105] The tier table behind the rarity column (data/rarity.csv). Read HERE for one claim
## only - every tier a plant row spells must be a tier that sheet knows - so this roster
## cannot ship a rarity nothing can colour or time. The values themselves are read through
## Balance.rarity_color() / Balance.recovery_seconds().
const RarityDB := preload("res://scripts/core/db/rarity_db.gd")

# ---------------------------------------------------------------- the svg column
## [P28] WHERE a plant's sprite lives. The svg cell holds the part AFTER this root and
## WITHOUT the extension ("pea/peashooter", "mushroom/mushroom_sun"), because that is the
## short form a designer can read in a spreadsheet - the same rule data/items.csv uses
## (see svg_path()).
const SVG_ROOT := "res://assets/svg/units/plants/"
const SVG_EXT := ".svg"

# ---------------------------------------------------------------- the tscn column
## [P28] WHERE a plant's VIEW SCENE lives (the thing the board draws when it exists). The
## tscn cell holds the part AFTER this root and WITHOUT the "_view.tscn" suffix
## ("peashooter" -> res://scenes/units/plants/peashooter_view.tscn), the same short form
## the svg column uses. A full "res://...tscn" cell works too (see scene_path()).
const SCENE_ROOT := "res://scenes/units/plants/"
const SCENE_SUFFIX := "_view.tscn"
## [P104] The script path rule's two halves (see script_path()).
const SCRIPT_ROOT := "res://scripts/units/"
const SCRIPT_EXT := ".gd"

# ---------------------------------------------------------------- sheet columns
# The PLANT-ONLY columns - the shared ones (名称 / name / race / HP / 天赋 / 技能 /
# 特殊机制 / svg / tscn) are named by UnitSheet's COL_* and arrive merged in flat().
# Matched by NAME (see UnitCsv), never by index, so the sheet can grow columns.
const COL_TALENT := UnitSheet.COL_TALENT
const COL_SKILL := UnitSheet.COL_SKILL
const COL_SKILL_EFFECT := "技能效果"
const COL_ID := UnitSheet.COL_ID
## [P28] The plant's picture, relative to SVG_ROOT and without the ".svg" suffix. A "—"
## cell means "no picture registered": the plant then draws the flat placeholder shape.
const COL_SVG := UnitSheet.COL_SVG
## [P28] The plant's VIEW SCENE, relative to SCENE_ROOT and without the "_view.tscn"
## suffix. A "—" cell means "this plant has no scene": the sprite above is drawn instead.
const COL_TSCN := UnitSheet.COL_TSCN
const COL_HP := UnitSheet.COL_HP
## [P30-A4] The loaded skill: this plant's row in data/units/skills.csv (see
## UnitSheet.COL_SKILL_CODE). skill_code() is the accessor.
const COL_SKILL_CODE := UnitSheet.COL_SKILL_CODE
## [P30-B] The loaded ultimate: this plant's skills.csv ultimate row (see
## UnitSheet.COL_ULTIMATE_CODE). ult_code() is the accessor.
const COL_ULT_CODE := UnitSheet.COL_ULTIMATE_CODE
const COL_ULTIMATE := "大招"
const COL_ULTIMATE_EFFECT := "大招效果"
## [P86] units.csv owns the attack column now (both rosters share it), so the name
## comes from UnitSheet like COL_HP does - one owner per column.
const COL_ATTACK := UnitSheet.COL_ATTACK
const COL_COST := "费用"
const COL_COOLDOWN := "卡片冷却"
const COL_SPECIAL := UnitSheet.COL_SPECIAL
## [P105] THE TIER, straight off units.csv (a shared column, like COL_HP / COL_ATTACK).
## "" means the sheet said nothing and Balance falls back to PLANT_DEFS' own rarity.
const COL_RARITY := UnitSheet.COL_RARITY
## [P26] Optional per-level growth cells. A "—" leaves the CODE default in charge
## (PLANT_HP_GROWTH / PLANT_SKILL_GROWTH / PLANT_TALENT_BOOST, see Balance), which is why
## they are stored as "what the sheet specified" rather than as plain numbers.
const COL_HP_GROWTH := "HP成长"
const COL_SKILL_GROWTH := "技能成长"
const COL_TALENT_BOOST := "天赋加成"
## [B11] THE THIRD GROWTH CELL. Empty = Balance.PLANT_DEFENCE_GROWTH (0.08/level), written =
## this plant's own rate; a plant whose 防御 (units.csv) is 0 grows 0 whatever this says.
const COL_DEFENCE_GROWTH := "防御成长"
## [P102] THE CARD COLUMN: a NUMBER means "this row is a plant card, and this is where it
## sits in the roster" (1 = the first card the almanac and the seed page show); `—` means
## the row is a sheet-only plant (the design has 55, the battle ships 24). It carries BOTH
## facts on purpose: "is it a card" and "when does it become available" used to live in a
## hand-ordered code list (Balance.plant_cards()), and the numbers stay editable without
## reordering the sheet's rows (leave gaps if you want room to insert later).
const COL_CARD := "卡片"
## [P104] THE SCRIPT COLUMN: which file implements this plant ("peashooter" ->
## res://scripts/units/peashooter.gd). `—` = the plant has no script, i.e. it is
## almanac-only - which is exactly the state `is_playable()` and the [Plants] `wired`
## claim already report. It replaced a 24-entry preload table in PlantScripts (see the
## header there for what that trade cost).
const COL_SCRIPT := "脚本"

# ---------------------------------------------------------------- the four mechanism columns (P101)
## [P101] THE RULES, spelled out. Until this batch the four mechanics below were read by
## MATCHING CHINESE WORDS inside the 特殊机制 sentence - a rule nobody could see without
## reading this file, and one a rewording could switch off silently. The words moved into
## their own columns on data/units/plants.csv, so "what does this plant do" is a cell a
## designer sets and the sentence is what the almanac SHOWS. The PHRASE_* consts below
## still spell the same words: they are now the cross-check that reports a sentence
## promising a mechanic its column does not switch on.
const YES := "是"
const COL_ONE_SHOT := "一次性"
const COL_SPLASH := "溅射"
const COL_ADJACENT_FEAR := "僵尸相邻"
const COL_UNEATABLE := "不会被啃食"
## Column -> the flag name the battle asks about (has_flag / FLAGS_KNOWN).
const FLAG_COLUMNS := {
	COL_ONE_SHOT: "one_shot",
	COL_SPLASH: "splash",
	COL_ADJACENT_FEAR: "adjacent_fear",
	COL_UNEATABLE: "uneatable",
}

## The prose columns, in the order the almanac reads them. The English twin of each
## one is "<name>英文" (UnitCsvManager.EN_SUFFIX); a sheet without the twin still works and
## the Chinese text is served instead.
const TEXT_FIELDS: Array[String] = [
	"name", "talent", "skill", "skill_effect", "ultimate", "ultimate_effect", "special",
]
const SOURCE_COLUMNS := {
	"name": UnitSheet.COL_NAME,
	"talent": COL_TALENT,
	"skill": COL_SKILL,
	"skill_effect": COL_SKILL_EFFECT,
	"ultimate": COL_ULTIMATE,
	"ultimate_effect": COL_ULTIMATE_EFFECT,
	"special": COL_SPECIAL,
}

## [P101] The 特殊机制 words the CROSS-CHECK reads. The rule itself is the `一次性`
## COLUMN on plants.csv ("this plant is spent when it acts", the cherry bomb family) - the
## sentence explains the missing HP / ATTACK cells to a reader, and this probe is how a
## sentence that still spells the word with the column off gets reported.
const PHRASE_ONE_SHOT := "一次性"
## [P51] The second prose mechanic the battle reads: 溅射伤害 / 溅射+冻结. It is the
## 投手 family's whole difference - a shot that pays the four cells around where it
## lands, and a 大招 that therefore also spreads into the lanes beside it. Read off the
## sheet rather than written in the subclass because the sheet ALREADY says it: 卷心菜投手
## and 玉米投手 spell their 特殊机制 as 越过障碍物 with no 溅射, and a code default of
## "everyone in the family splashes" would hand those two rows a rule nobody wrote.
const PHRASE_SPLASH := "溅射"
## [P59] The third prose mechanic the battle reads, on the same cell: 胆小菇's
## `僵尸相邻时停止attack` - a shooter that holds its fire while a body stands in one of the
## cells beside it. It is read off the sheet for the same reason P51 made 溅射 a fact: the
## subclass may not decide which plants it applies to, or a future shroom would inherit
## the cowardice. The phrase is deliberately FOUR characters and not just 相邻: 南瓜's row
## spells its own mechanic as `给相邻一格植物附加护甲`, and a two-character probe would
## hand that wall a rule nobody wrote for it.
const PHRASE_ADJACENT_FEAR := "僵尸相邻"
## [P63] The fourth prose mechanic the battle reads, and the first that changes what
## ANOTHER race may do with this plant: 地刺's `不会被啃食` - a body standing on the spike
## never bites it, because a spike is not something you can eat. Same arrangement as the
## two probes above (the row is the only place the rule is written, so a future plant that
## grows the words gets it without a line of code).
##
## The probe is deliberately the sheet's own FIVE characters and not 啃食: 大蒜's row
## spells its own mechanic as `被啃食时僵尸换行` - the same two characters, the OPPOSITE
## fact (a garlic is eaten AND pushes the biter sideways), and a short probe would hand it
## immunity. 火炬树桩 / 高坚果 and every other prose row are the same risk. It is also NOT
## a loose match for spikerock's wording: 地刺王 spells the same idea as `不被啃食`, which
## this string does not contain - so wiring the elder spike means adding its row's words to
## the table (a data decision, recorded in the plan), not widening a probe by one character.
const PHRASE_UNEATABLE := "不会被啃食"
## [P72] The four probes above as ONE table, so "did any probe read this sentence at all"
## has an answer (see prose_audit()). [P101] They no longer DECIDE anything: the four
## mechanism COLUMNS do, and this table is the reading the [Plants] cross-check compares
## them against (a sentence that spells a word whose column is off is a red line). The
## words stay owned by the PHRASE_* consts, with the reason each one is that exact length
## written next to it - that reasoning is why the cross-check does not false-positive on
## 大蒜's 被啃食 or 南瓜's 相邻. Only the CHINESE cell is read: the English twin is free
## prose and may say "splash" without meaning the mechanic.
const PHRASES := {
	PHRASE_ONE_SHOT: ["one_shot"],
	PHRASE_SPLASH: ["splash"],
	PHRASE_ADJACENT_FEAR: ["adjacent_fear"],
	PHRASE_UNEATABLE: ["uneatable"],
}
## [P72] Which gates a rule OUTSIDE this file asks about. Three of the four; the missing one
## is documented on is_simulated(). A gate joins this list the day battle code starts
## reading it, and prose_audit() shrinks by exactly those rows.
const FLAGS_READ_BY_BATTLE: Array[String] = ["splash", "adjacent_fear", "uneatable"]
## [P72] Every gate the plant sheet can open. What is missing from FLAGS_READ_BY_BATTLE is
## named by unsimulated_flags() instead of being quietly believed.
const FLAGS_KNOWN: Array[String] = ["one_shot", "splash", "adjacent_fear", "uneatable"]

static var _rows: Dictionary = {}          # id -> row (see _parse_row)
## [P102] The card roster, sorted by the 卡片 column: what Balance.plant_cards() reads.
static var _cards: Array[String] = []
## [P102] How many times the sheet has been read. Callers that CACHE something derived from
## it (Balance.plant_cards) compare this and drop the cache when it moves - the P75 rule that
## a cache which is not invalidated is a lie.
static var _loads := 0
static var _order: Array[String] = []      # the roster's own order, top to bottom
static var _loaded: bool = false
static var _tried: bool = false            # a failed load is not retried forever
static var _error: String = ""
static var _problems: Array[String] = []
static var _missing_en: int = 0            # prose fields served in Chinese


# ---------------------------------------------------------------- loading
static func _sheet() -> UnitSheet:
	## [P29] The shared roster reader. ZombieDB reads the SAME instance (the
	## units.csv parse happens twice at boot - two 20 KB files, free); the R-key
	## reload is a full re-read, which is exactly what it promised.
	return UnitSheet.live()


static func load_from_disk() -> bool:
	## Reads the roster once. Called by Game at boot; every accessor also calls
	## _ensure(), so a self-check or a screen can never see an empty table.
	_tried = true
	_rows.clear()
	_order.clear()
	_cards.clear()
	_problems.clear()
	_missing_en = 0
	_error = ""

	var sheet := _sheet()
	if not sheet.load_roster():
		_error = sheet.error_text()
		_loaded = false
		return false

	for id in sheet.ids_for(RACE_ROOT):
		## [P109] `parsed`, not `row` (a local `row` shadowed this class's `row()` getter).
		var parsed := _parse_row(sheet.get_flat(id), id)
		if parsed.is_empty():
			continue
		_rows[id] = parsed
		_order.append(id)

	## Roster-level complaints (a skipped row, an orphan family entry) belong to
	## the sheet, so both DBs report them: whoever prints, prints the truth.
	_problems = sheet.problems()
	_problems.append_array(sheet.orphans())

	## [P102] The card roster: the rows whose 卡片 cell is a number, ordered by it. Sorted
	## here (not in an accessor) so the answer is stable for every reader and the cache in
	## Balance.plant_cards() has one thing to compare against.
	var numbered: Array = []
	for id in _order:
		var n := int((_rows[id] as Dictionary).get("card", -1))
		if n > 0:
			numbered.append([n, id])
	numbered.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for pair in numbered:
		_cards.append(str((pair as Array)[1]))
	_loads += 1
	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable plant row"
	return _loaded


static func card_ids() -> Array[String]:
	## [P102] The roster in card order (see COL_CARD). Balance.plant_cards() turns this into
	## the battle roster by adding each card's SPIRIT copy.
	_ensure()
	return _cards.duplicate()


static func is_card(p_id: String) -> bool:
	_ensure()
	return _cards.has(p_id)


static func loads() -> int:
	## [P102] A generation counter for caches derived from this sheet (see Balance).
	_ensure()
	return _loads


static func rarity(p_id: String) -> String:
	## [P105] The rarity cell of this row, exactly as written - "" when the sheet left it
	## blank, which is Balance.plant_rarity()'s cue to fall back to PLANT_DEFS. The word is
	## NOT validated here: the [Plants] rarity claim in self_check() is where "this sheet
	## names a tier nothing knows" is reported.
	_ensure()
	return str(row(p_id).get("rarity", ""))


static func _ensure() -> void:
	if not _tried:
		load_from_disk()


static func _parse_row(p_raw: Dictionary, p_id: String) -> Dictionary:
	var texts: Dictionary = {}
	for field in TEXT_FIELDS:
		var column := str(SOURCE_COLUMNS[field])
		var zh := UnitCsvManager.cell(p_raw, column)
		var en := UnitCsvManager.cell_en(p_raw, column)
		texts[field] = {"zh": zh, "en": en}
		## "name" is deliberately not counted: its English wording comes from the
		## language layer (the sheet's own name column IS the id), so it would be
		## reported as missing on every single row.
		if field != "name" and zh != "" and not UnitCsvManager.has_en(p_raw, column):
			_missing_en += 1
	var special_zh := str((texts["special"] as Dictionary).get("zh", ""))
	## [P101] The four gates come from their own COLUMNS now (cells the designer sets); the
	## 特殊机制 sentence is prose. `flags_prose` is what that sentence WOULD open by wording
	## alone - the [Plants] cross-check compares the two, so a sentence promising a mechanic
	## its column forgot is reported instead of silently not happening.
	var flags := _flag_cells(p_raw)
	var flags_prose := _flags_of(special_zh)
	## [P26] Only the growth cells the sheet really filled: a "—" must NOT become 0.0, or it
	## would silently mean "this plant never grows" instead of "the code value applies".
	var rates: Dictionary = {}
	if UnitCsvManager.cell(p_raw, COL_HP_GROWTH) != "":
		rates["hp_growth"] = UnitCsvManager.rate_cell(p_raw, [COL_HP_GROWTH])
	if UnitCsvManager.cell(p_raw, COL_SKILL_GROWTH) != "":
		rates["skill_growth"] = UnitCsvManager.rate_cell(p_raw, [COL_SKILL_GROWTH])
	if UnitCsvManager.cell(p_raw, COL_TALENT_BOOST) != "":
		rates["talent_boost"] = UnitCsvManager.rate_cell(p_raw, [COL_TALENT_BOOST])
	if UnitCsvManager.cell(p_raw, COL_DEFENCE_GROWTH) != "":
		rates["defence_growth"] = UnitCsvManager.rate_cell(p_raw, [COL_DEFENCE_GROWTH])
	## [P109] `entry`, not `row` (a local `row` shadowed this class's `row()` getter).
	var entry := {
		"id": p_id,
		"zh": str((texts["name"] as Dictionary).get("zh", "")),
		"texts": texts,
		## [P28] the sheet's own svg cell, kept as written (relative, extension-less);
		## svg_path() / art() are the two places that turn it into a res:// path.
		"svg": UnitCsvManager.cell(p_raw, COL_SVG),
		## [P28] the same for the view scene: scene_path() / view() resolve it.
		"tscn": UnitCsvManager.cell(p_raw, COL_TSCN),
		"hp": UnitCsvManager.int_cell(p_raw, [COL_HP], 0),
		"attack": UnitCsvManager.int_cell(p_raw, [COL_ATTACK], 0),
		"cost": UnitCsvManager.int_cell(p_raw, [COL_COST], 0),
		## [P105] The tier as the sheet spells it ("" when the cell is blank - the
		## fall-back is then PLANT_DEFS' rarity for this plant, see Balance.plant_rarity).
		"rarity": UnitCsvManager.cell(p_raw, COL_RARITY),
		## [P102] The card cell as the sheet spells it ("1".."24", or "" when the row is not a
		## card): load_from_disk() sorts the roster by the number.
		"card": UnitCsvManager.int_of(UnitCsvManager.cell(p_raw, COL_CARD), -1),
		## [P104] The script cell, as written (script_file() resolves it to a res:// path).
		"script": UnitCsvManager.cell(p_raw, COL_SCRIPT),
		"cooldown": maxi(1, UnitCsvManager.int_cell(p_raw, [COL_COOLDOWN], 1)),
		## [P39] Whether the sheet WROTE these two cells, as opposed to leaving them "—"
		## and letting the fall-backs above answer. The self-check needs the difference:
		## 费用 0 is a design decision (小喷菇 and 海蘑菇 are free, the imitater copies
		## another card's cost), while a blanked 费用 is the same 0 by accident.
		"cost_written": UnitCsvManager.cell(p_raw, COL_COST) != "",
		"cooldown_written": UnitCsvManager.cell(p_raw, COL_COOLDOWN) != "",
		## [P72] Whether the sheet WROTE 特殊机制 at all. prose_audit() needs the difference
		## between "the cell is empty" and "the cell says something no probe understood":
		## the second is a sentence the sheet is on the hook for, the first is nobody's
		## promise yet. (BLANKS is what turns a "—" cell into "" above.)
		"special_written": special_zh != "",
		## [P101] What the SENTENCE promises, kept beside what the COLUMNS say (see the
		## cross-check in self_check()). Only the columns open a gate.
		"flags_prose": flags_prose,
		## [P72] The four gates this row opened, as one dictionary - it used to be four flat
		## keys, each filled by its own .contains(), which could all answer "no" without
		## anybody noticing. What each key MEANS, and which rule reads it:
		##   one_shot      一次性     - the plant is spent by acting [P39]; the battle does
		##                             not ask (see is_simulated()), its family runs on the
		##                             script it extends
		##   splash        溅射       - [P51] a shot that reaches the cells around its
		##                             landing point; PultPlant asks the row, so the four
		##                             投手 rows are the only place the rule is written
		##   adjacent_fear 僵尸相邻    - [P59] a shooter that freezes its own trigger while a
		##                             body stands next to it; the row decides which plants
		##                             are cowards, so a future shroom cannot inherit it
		##   uneatable     不会被啃食  - [P63] a body standing on this cell walks over it
		##                             instead of biting; SpikePlant reads it once at spawn
		## The wording risk of every one of those four strings is on its PHRASE_* const.
		"flags": flags,
		"rates": rates,
		## [P30-A4] the skills.csv row this plant loads ("" = its script's const SKILL)
		"skill_code": UnitCsvManager.cell(p_raw, COL_SKILL_CODE),
		## [P30-B] the skills.csv ULTIMATE row this plant's charge bar loads
		## ("" = its script's const ULTIMATE, if it declares one)
		"ult_code": UnitCsvManager.cell(p_raw, COL_ULT_CODE),
	}
	## [P102] A plant is PLAYABLE exactly when its 卡片 cell carries a number - the sheet owns
	## the roster now (Balance.plant_cards() is the same fact with the spirit copies added).
	## It used to ask Balance.plant_cards(), i.e. the code list was the owner of "is this a
	## card"; the `wired` half of the [Plants] claim is what still catches a card whose
	## script is missing from the registry.
	entry["playable"] = int(entry["card"]) > 0
	return entry


static func _flag_cells(p_raw: Dictionary) -> Dictionary:
	## [P101] The four gates, read from their own columns: `是` opens one, anything else
	## (a "—", an empty cell, a missing cell) leaves it shut. Same convention as the
	## projectile sheet's 穿甲 / 命中状态 columns (ProjectileDB.YES).
	var flags: Dictionary = {}
	for column in FLAG_COLUMNS.keys():
		if UnitCsvManager.cell(p_raw, str(column)) == YES:
			flags[str(FLAG_COLUMNS[column])] = true
	return flags


static func prose_flags(p_id: String) -> Dictionary:
	## [P101] What this row's 特殊机制 SENTENCE would open by wording alone - nothing
	## reads it to decide anything; the [Plants] cross-check prints the rows where it and
	## the columns disagree ("the sentence promises a mechanic the column forgot").
	return (row(p_id).get("flags_prose", {}) as Dictionary).duplicate()


static func _flags_of(p_sentence: String) -> Dictionary:
	## [P72] The plant twin of ZombieDB._flags_of(): ONE pass over PHRASES answers both
	## questions the four probes used to answer separately - which gates this row opens, and
	## whether ANY probe understood the sentence at all. The second answer is what
	## prose_audit() counts, so a sentence no probe recognised is now on the report instead of
	## being four silent "no"es. It is not a failure: a sheet may describe more than the
	## engine runs (see the print for the three different reasons a row can be on that list).
	var flags: Dictionary = {}
	for phrase in PHRASES.keys():
		if p_sentence.contains(str(phrase)):
			for flag in (PHRASES[phrase] as Array):
				flags[str(flag)] = true
	return flags


# ---------------------------------------------------------------- the svg path rule
static func svg_path(p_cell: String) -> String:
	## [P28] "pea/peashooter" -> "res://assets/svg/units/plants/pea/peashooter.svg".
	##
	## The same rule ItemDB.svg_path() applies to data/items.csv: a cell that already
	## spells a full res:// path, or that carries its own extension (.svg / .png), is used
	## as it is - so the short spelling and the full one reach the same file, and a
	## designer never has to know where the art folder hangs.
	## [P109] `cell_text`, not `text` (a local `text` shadowed this class's `text()` getter).
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not (cell_text.ends_with(".svg") or cell_text.ends_with(".png")):
		cell_text += SVG_EXT
	return SVG_ROOT + cell_text


# ---------------------------------------------------------------- the tscn path rule
static func scene_path(p_cell: String) -> String:
	## [P28] "peashooter" -> "res://scenes/units/plants/peashooter_view.tscn".
	##
	## The same rule svg_path() applies: a cell that already spells a full res:// path, or
	## that carries its own ".tscn" (e.g. "scenes/units/plants/foo.tscn"), is used as it
	## is - so the short spelling and the full one reach the same file.
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not cell_text.ends_with(".tscn"):
		cell_text += SCENE_SUFFIX
	return SCENE_ROOT + cell_text


# ---------------------------------------------------------------- the script path rule
static func script_path(p_cell: String) -> String:
	## [P104] "peashooter" -> "res://scripts/units/peashooter.gd".
	##
	## The same rule svg_path() and scene_path() apply: a cell that already spells a full
	## res:// path, or that carries its own ".gd", is used as it is - so the short spelling
	## and the full one reach the same file.
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not cell_text.ends_with(SCRIPT_EXT):
		cell_text += SCRIPT_EXT
	return SCRIPT_ROOT + cell_text


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
	## The roster's own order: the almanac lists the plants exactly as the designer
	## wrote them, so "where is X" is answerable from the sheet itself.
	_ensure()
	return _order.duplicate()


static func has(p_id: String) -> bool:
	_ensure()
	return _rows.has(p_id)


static func row(p_id: String) -> Dictionary:
	_ensure()
	return _rows.get(p_id, {})


static func name(p_id: String) -> String:
	## The display name in the current language. LocNames "plant.<id>" wins (it is the
	## language layer's own name table and carries the official English wording);
	## the sheet's 名称 / its English twin is the fall-back, so a plant added to the
	## sheet alone still shows a real name instead of a key.
	_ensure()
	var fallback := text(p_id, "name")
	if fallback == "":
		fallback = p_id
	return Loc.t("plant." + p_id, fallback)


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
	return maxi(0, int(row(p_id).get("hp", 0)))


static func attack(p_id: String) -> int:
	return maxi(0, int(row(p_id).get("attack", 0)))


static func cost(p_id: String) -> int:
	return maxi(0, int(row(p_id).get("cost", 0)))


static func cooldown(p_id: String) -> int:
	return maxi(1, int(row(p_id).get("cooldown", 1)))


static func has_flag(p_id: String, p_flag: String) -> bool:
	## [P72] One reader for "this row's 特殊机制 opened this gate". Before this batch every
	## gate had its own flat key on the row, so the four probes and the audit below would
	## each have to re-derive the same answer.
	return bool((row(p_id).get("flags", {}) as Dictionary).get(p_flag, false))


static func is_one_shot(p_id: String) -> bool:
	return has_flag(p_id, "one_shot")


static func has_splash(p_id: String) -> bool:
	## [P51] Whether this plant's shot reaches the cells around where it lands, as the
	## sheet's own 特殊机制 spells it (PHRASE_SPLASH). PultPlant reads this instead of
	## carrying a per-species constant, so the four 投手 rows are the only place the rule
	## is written. A non-pult that ever grows the word gets the same answer for free.
	return has_flag(p_id, "splash")


static func fears_adjacent(p_id: String) -> bool:
	## [P59] Whether this plant holds its fire while a zombie stands in a cell next to it,
	## as the sheet's own 特殊机制 spells it (PHRASE_ADJACENT_FEAR). Same arrangement as
	## has_splash(): the row is the only place the rule is written, and a plant that ever
	## grows the words 僵尸相邻 gets it for free instead of needing a line of code.
	return has_flag(p_id, "adjacent_fear")


static func is_uneatable(p_id: String) -> bool:
	## [P63] Whether a body that walks onto this plant's cell bites it at all, as the
	## sheet's own 特殊机制 spells it (PHRASE_UNEATABLE). SpikePlant reads it once at spawn
	## into the instance flag the battle asks (`Unit.ignores_biting`), so the answer comes
	## from the row and not from which class a script happens to extend: 大蒜 already has a
	## cell that says 被啃食, and a future plant that grows 不会被啃食 gets the immunity without
	## anybody having to remember to teach a second family about it.
	return has_flag(p_id, "uneatable")


static func get_rates(p_id: String) -> Dictionary:
	## [P26] ONLY the growth cells the sheet filled in ("hp_growth" / "skill_growth" /
	## "talent_boost"). Balance.plant_attrs() merges exactly these over its own table, so
	## a "—" cell keeps the code value in charge instead of meaning "zero growth".
	return (row(p_id).get("rates", {}) as Dictionary).duplicate()


static func get_rate(p_id: String, p_field: String, p_default: float) -> float:
	## One growth rate, with the caller's default when the sheet says nothing.
	return float(get_rates(p_id).get(p_field, p_default))


static func is_playable(p_id: String) -> bool:
	## True when the BATTLE can deploy this plant today: [P102] its sheet row carries a card
	## number (the roster), which is also what the almanac shows the rest of the sheet against.
	return bool(row(p_id).get("playable", false))


static func is_simulated(p_flag: String) -> bool:
	## [P72] Does any rule OUTSIDE this file ask the sheet about this gate? Three do
	## (FLAGS_READ_BY_BATTLE). `one_shot` does not, and the reason is worth keeping in words:
	## the two readers it has are both in this file - the `[Plants]` tag and the HP exemption
	## that lets a spent body stand on the lawn for the round it needs - while the family's
	## real switch is the script it extends
	## (scripts/units/base/one_shot_plant.gd). So the flag is a label here, not a lever, and
	## this function is the one place that says so.
	return FLAGS_READ_BY_BATTLE.has(p_flag)


static func simulates(p_id: String, p_flag: String) -> bool:
	## [P72] The ROW-aware half, in the shape ZombieDB.simulates() set: a gate that no rule
	## reads may still be run by this row's own body. 一次性 WITH a script is a plant that
	## spends itself (the five blast cards), so calling that row "not simulated" would make
	## the almanac lie about a working feature - the one thing this report may not do.
	if is_simulated(p_flag):
		return true
	if p_flag == "one_shot":
		## The script registry owns this answer: a playable one-shot row is, by
		## construction, one of the files that extend one_shot_plant.gd. A future 一次性 card
		## wired WITHOUT that base is what this line would have to learn about.
		return is_playable(p_id)
	return false


static func unsimulated_flags(p_id: String) -> Array[String]:
	## [P72] The plant twin of ZombieDB.unsimulated_flags(): the gates this row opens that
	## nothing runs. The almanac shows them on the plant's own page so that "the sheet says
	## so" and "the game does it" stop being the same sentence. Five rows today: the 一次性
	## cards with no script behind them (hypno / doom shroom, tangle kelp, blover, coffee
	## bean).
	_ensure()
	var out: Array[String] = []
	for flag in FLAGS_KNOWN:
		if has_flag(p_id, flag) and not simulates(p_id, str(flag)):
			out.append(str(flag))
	return out


static func prose_state(p_id: String) -> String:
	## [P72] Which audit bucket this row's 特殊机制 sentence falls into, or "" when the row
	## did not write that cell at all. ONE classifier, so the per-card tag, prose_audit() and
	## the almanac can never disagree about a row. The buckets, strongest claim first:
	##   battle_read      a gate the BATTLE acts on is ON (see FLAGS_READ_BY_BATTLE)
	##   script_run       the only gate ON is one_shot and this row has a script: the sheet's
	##                    promise is kept by the family's base, not by the flag
	##   gated_unrun      a gate is ON and nothing keeps that promise
	##   live_unprobed    prose, no gate matched, and the card IS summonable - the engine may
	##                    do the thing by another route (cabbage_pult's arc, gloom_shroom's
	##                    ring) or not at all (fume_shroom's 穿透铁门 = the open §4-14
	##                    decision). This report cannot tell those two apart, and saying so
	##                    out loud is the whole point of the list.
	##   sheet_unprobed   the same sentence on a card the almanac shows and the battle cannot
	##                    summon
	_ensure()
	if not bool(row(p_id).get("special_written", false)):
		return ""
	for flag in FLAGS_READ_BY_BATTLE:
		if has_flag(p_id, flag):
			return "battle_read"
	if not unsimulated_flags(p_id).is_empty():
		return "gated_unrun"
	var gated := false
	for flag in FLAGS_KNOWN:
		if has_flag(p_id, flag):
			gated = true
	if gated:
		return "script_run"
	return "live_unprobed" if is_playable(p_id) else "sheet_unprobed"


static func prose_audit() -> Dictionary:
	## [P72] Every row that wrote 特殊机制, grouped by prose_state() - so the five lists
	## together cover the whole column and the counts add up to it. Report-only, never a
	## failure: a sheet may describe more than the engine runs, and the honest answer to that
	## is a list rather than a quieter sheet. A row is counted ONCE, by its strongest claim,
	## so doom_shroom's 留下弹坑 is not listed separately - its row is already in gated_unrun
	## for 一次性. Per-promise bookkeeping needs a probe per clause, which is exactly what
	## §4-11 第 6 条 measured and what this batch reports instead of inventing.
	_ensure()
	var out := {
		"battle_read": [], "script_run": [], "gated_unrun": [],
		"live_unprobed": [], "sheet_unprobed": [],
	}
	for id in _order:
		var state := prose_state(id)
		if state != "":
			(out[state] as Array).append(id)
	return out


static func race(p_id: String) -> String:
	## [P29] The plant's race path ("plants/pea"), straight from units.csv. The
	## battle does not read it yet; the family screens and future rules may.
	return _sheet().race(p_id)


static func skill_code(p_id: String) -> String:
	## [P30-A4] The 技能代码 this plant LOADS from units.csv - the sheet's answer to
	## "which skill is in this unit's action bar". "" when the cell is blank, which
	## means the unit script's own const SKILL is in charge (Balance.plant_skill_code).
	return str(row(p_id).get("skill_code", ""))


static func ult_code(p_id: String) -> String:
	## [P30-B] The 大招代码 this plant LOADS from units.csv: the skills.csv ultimate
	## row its charge bar resolves to. "" when the cell is blank (Balance.
	## plant_ult_code then asks the script's const ULTIMATE); a code the skill
	## sheet does not know loads NOTHING - an ultimate the battle cannot run
	## must not light a bar that never pays out.
	return str(row(p_id).get("ult_code", ""))


static func svg_rel(p_id: String) -> String:
	## [P28] The sheet's own svg cell, still relative - "" when the row registers none.
	_ensure()
	return str(row(p_id).get("svg", ""))


static func svg_file(p_id: String) -> String:
	## [P28] The file the SHEET registers for this plant, as a res:// path - whether or
	## not the editor has imported it yet. "" when the row registers no picture.
	return svg_path(svg_rel(p_id))


static func script_rel(p_id: String) -> String:
	## [P104] The sheet's own 脚本 cell, still as written - "" when the row registers none.
	_ensure()
	return str(row(p_id).get("script", ""))


static func script_file(p_id: String) -> String:
	## [P104] The file the SHEET registers for this plant, as a res:// path. "" when the
	## row registers no script (an almanac-only plant). PlantScripts loads this.
	return script_path(script_rel(p_id))


static func art(p_id: String) -> String:
	## [P28] The plant's sprite, straight out of the sheet's svg column: that column is
	## where a plant's picture is registered now. A row that registers none (or names a file
	## nobody has drawn) draws the bare plant.svg (Balance.ART_PLANT) instead, and that one
	## is the last step before the flat shape Unit._draw_body() paints itself.
	var path := svg_file(p_id)
	if path != "" and UnitArt.load_texture(path) != null:
		return path
	return Balance.ART_PLANT


static func has_art(p_id: String) -> bool:
	## [P28] True when that sprite really LOADS, i.e. when the almanac may draw it. The
	## sheet registers a picture for every plant of the design while the art folder only
	## holds a file for part of them: a cell pointing at a file nobody has drawn yet is an
	## ordinary state on the way to a full roster, not an error - the almanac keeps its
	## "no art yet" label and the board draws the flat shape.
	var path := art(p_id)
	return path != "" and UnitArt.load_texture(path) != null


static func art_paths() -> Array:
	## [P28] Every distinct sprite the SHEET registers, imported or not, for UnitArt's
	## start-up check: the ones nobody has drawn yet are counted there, which is also how a
	## typo in an svg cell shows up. Balance's own table is NOT part of this list - those
	## paths are named by the code and are checked as such (UnitArt.code_art_paths()).
	_ensure()
	var out: Array = []
	for id in _order:
		var path := svg_file(id)
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func art_count() -> int:
	## [P28] How many plants really draw a file of their own - the number UnitArt's
	## self-check prints next to the roster size (PlantDB.count()).
	_ensure()
	var n := 0
	for id in _order:
		if has_art(id):
			n += 1
	return n


static func scene_rel(p_id: String) -> String:
	## [P28] The sheet's own tscn cell, still relative - "" when the row registers none.
	_ensure()
	return str(row(p_id).get("tscn", ""))


static func scene_file(p_id: String) -> String:
	## [P28] The VIEW SCENE the sheet registers for this plant, as a res:// path - whether
	## or not the file exists yet. "" when the row registers no scene. This is the answer
	## to "what does the sheet ASK for", which is what self_check() reports; view() is the
	## answer to "what does the board actually DRAW".
	return scene_path(scene_rel(p_id))


static func view(p_id: String) -> String:
	## [P28] The scene the BOARD draws for this plant, or "" when it has none. The tscn
	## cell is the only source: a scene it names but nobody has built yet leaves the plant
	## on its sprite (art()) instead of leaving a hole on the lawn, which is why a cell
	## may be filled in before the part exists.
	var path := scene_file(p_id)
	if path != "" and UnitArt.load_scene(path) != null:
		return path
	return ""


static func has_view(p_id: String) -> bool:
	## [P28] True when this plant really draws a scene on the board (i.e. view() != "").
	## The almanac and the garden still draw the SPRITE, so this is about the board only.
	return view(p_id) != ""


static func view_count() -> int:
	## [P28] How many plants really draw a SCENE on the board - printed next to the sprite
	## count, so "the new plant still looks flat" is answerable from the log.
	_ensure()
	var n := 0
	for id in _order:
		if has_view(id):
			n += 1
	return n


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func status_text() -> String:
	_ensure()
	if not _loaded:
		return "plants: sheet NOT loaded (%s)" % error_text()
	return "plants: %d row(s) under race '%s', %d playable, %d with their own sprite, %d with a view scene, %d prose field(s) with no English twin" \
		% [_order.size(), RACE_ROOT, playable_count(), art_count(), view_count(), _missing_en]


static func playable_count() -> int:
	_ensure()
	var n := 0
	for id in _order:
		if is_playable(id):
			n += 1
	return n


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game: what the plant sheet gave us, and whether the
	## numbers the BATTLE uses still agree with it. The three summonable plants are the
	## only ones that matter for the board, so a disagreement there is a FAIL - it
	## means a card would show one cost and spend another.
	print("[Plants] --- roster for race '%s' (%s + %s) ---" % [RACE_ROOT, UnitSheet.ROSTER_PATH.get_file(), PATH.get_file()])
	if not is_loaded():
		print("[Plants] sheet not loaded: " + error_text() + " | FAIL")
		print("[Plants] -> the built-in Balance tables are being used instead")
		print("[Plants] self-check FAILED")
		return
	print("[Plants] %d plant(s), %d playable in battle, %d prose field(s) with no English twin"
		% [_order.size(), playable_count(), _missing_en])
	var ok := true
	var stubs := 0
	for id in _order:
		var r := row(id)
		## [P39] WHAT this gate is for: a row that BROKE, not a row nobody designed yet.
		## The old rule was `cost > 0 and cooldown > 0`, which called every free plant a
		## failure (小喷菇, 海蘑菇 cost 0 on purpose; the imitater copies another card's
		## price) and never failed on a blanked cooldown, because `_parse_row` floors it
		## at 1 - nine permanent red rows on a healthy sheet, which is how a real break
		## stops being read. So ask the sheet instead: did it SPELL the two price cells?
		## A row that spells one of them and not the other is a blanked cell (FAIL), a row
		## that spells neither is art without design (a STUB, counted below), and a row the
		## battle can summon is never excused for missing either.
		var priced := bool(r.get("cost_written", false))
		var timed := bool(r.get("cooldown_written", false))
		var stub := not priced and not timed
		var tags := "summonable" if is_playable(id) else "-"
		if is_one_shot(id):
			tags += " one-shot"
		## [P72] The tag this batch exists for: the row wrote a 特殊机制 sentence and none of
		## the four probes recognised a word of it. Both kinds get the same tag here, and the
		## audit after the list separates them (a LIVE card with this tag is the interesting
		## case - see prose_state()).
		var state := prose_state(id)
		if state == "live_unprobed" or state == "sheet_unprobed":
			tags += " prose unprobed"
		if stub:
			tags += " stub"
			stubs += 1
		var line := "[Plants] %-13s %-12s hp %-5d atk %-4d cost %-4d cd %d  %s" % [
			id, name(id), int(r.get("hp", 0)), int(r.get("attack", 0)),
			int(r.get("cost", 0)), int(r.get("cooldown", 0)), tags]
		var good: bool = (priced and timed) if not stub else not is_playable(id)
		## [P26] the optional growth cells, or "code defaults" when the sheet left them
		## as "—" (which is what the shipped sheet does for most plants).
		var sheet_rates := get_rates(id)
		var growth := PackedStringArray()
		if sheet_rates.has("hp_growth"):
			growth.append("hp +%d%%/lv" % int(round(float(sheet_rates["hp_growth"]) * 100.0)))
		if sheet_rates.has("skill_growth"):
			growth.append("skill +%d%%/lv" % int(round(float(sheet_rates["skill_growth"]) * 100.0)))
		if sheet_rates.has("talent_boost"):
			growth.append("talent +%d%%" % int(round(float(sheet_rates["talent_boost"]) * 100.0)))
		line += "  growth %s" % ("code defaults" if growth.is_empty() else ", ".join(growth))
		## [P28] Which sprite this plant draws, as the sheet's svg column spells it: the
		## registered file, or the flat placeholder shape when the row registers none. A
		## file the editor has not imported yet is marked - that is where a typo in an svg
		## cell shows up, and UnitArt.self_check() counts how many there are.
		var sprite := art(id)
		if sprite == "":
			line += "  art (flat shape)"
		else:
			line += "  art %s" % UnitArt.short_art_path(sprite)
			if not has_art(id):
				line += " NOT IMPORTED"
		## [P28] And which VIEW SCENE the row registers on top of that sprite. The board
		## draws the scene when it loads, the sprite when it does not: a cell naming a part
		## nobody has built yet is the ordinary "not yet" state (counted, not failed - the
		## same treatment the sprites of this sheet get), and a typo shows up here.
		var scene := scene_file(id)
		if scene == "":
			line += "  view (none)"
		elif UnitArt.load_scene(scene) != null:
			line += "  view %s" % scene.get_file()
		else:
			line += "  view %s NOT FOUND (sprite in use)" % scene.get_file()
		## A playable plant must also have hp: a summonable plant with no HP row would
		## deploy on 1 hp and die to a single bite.
		## [P39] One exception, and the sheet itself names it: a 一次性 plant spends its
		## own body with its skill, so it carries NO 生命 cell by design (the row is
		## written 生命 —, and Balance.plant_attr_hp() is what floors it at 1 so it can
		## stand on the lawn for the round it needs). Demanding an HP number from those
		## rows would fail the only two one-shot plants this game can currently summon -
		## i.e. the gate would punish exactly the plants that finished the feature.
		if is_playable(id) and int(r.get("hp", 0)) <= 0 and not is_one_shot(id):
			good = false
		ok = ok and good
		line += " | " + ("OK" if good else "FAIL")
		print(line)
	## [P39] The stubs used to be nine FAILs; saying "all clear" over them without
	## naming them would hide the work list instead of reporting it.
	if stubs > 0:
		print("[Plants] %d stub row(s): art only, no price written yet (listed above, not a failure)"
			% stubs)
	for problem in _problems:
		print("[Plants] warning: " + problem)
		print("[Plants]          -> the battle keeps using its built-in defaults")
		ok = ok and false
	## The card numbers, checked as WIRING rather than as agreement: what the BATTLE
	## resolves for a card (cost, cooldown, health, skill) must be the sheet's number.
	## The built-in constant is ALLOWED to differ - "the sheet is the source" is exactly
	## that - so a difference is reported as `overrides Balance`, not as a failure, and
	## only a broken wire is a FAIL.
	for id in Balance.plant_cards():
		var card := str(id)
		## [P31-B] A spirit copy deliberately owns NO sheet row (it is a copy, not
		## a breed): its wiring is the base plant's plus Balance.spirit_base(),
		## which game_manager's spirit self-check exercises.
		if Balance.spirit_base(card) != "":
			continue
		if not has(card):
			print("[Plants] card '%s' has no row in the sheet | FAIL" % card)
			ok = false
			continue
		## [P100] The code-table reference for the drift line below is PLANT_DEFS now: it is the
		## only code table left (PLANT_ATTRS is gone - see its obituary in balance.gd).
		var attrs: Dictionary = Balance.PLANT_DEFS.get(card, {})
		## [P34] The numbers are only half of "wired": a card whose script is missing
		## from PlantScripts still summons - as a peashooter. That used to be invisible.
		var scripted := PlantScripts.is_registered(card)
		## [P39] The health clause needs one documented exception: a 一次性 row owns no
		## 生命 cell, so the sheet says 0 while the battle says 1 - and that gap is not a
		## broken wire, it is Balance.plant_attr_hp() flooring a bodyless plant at 1 "so
		## nothing can divide by it". Accept ONLY that step (0 -> 1): a row whose health
		## resolves to anything else is still a wire that does not reach the sheet.
		var sheet_hp := hp(card)
		var battle_hp := Balance.plant_attr_hp(card, 1, false)
		var hp_wired := battle_hp == sheet_hp \
			or (is_one_shot(card) and sheet_hp <= 0 and battle_hp == 1)
		var wired: bool = scripted \
			and Balance.plant_cost(card) == cost(card) \
			and Balance.plant_card_cooldown(card) == cooldown(card) \
			and hp_wired \
			and Balance.plant_base_skill(card) == attack(card)
		ok = ok and wired
		## Where the sheet disagrees with the code constant, say so - that is the
		## intended direction of truth, and seeing it in the log is how a designer knows
		## the edit took effect.
		var drift := PackedStringArray()
		if int(attrs.get("hp", -1)) != hp(card):
			drift.append("hp %d->%d" % [int(attrs.get("hp", -1)), hp(card)])
		if int(attrs.get("skill_base", -1)) != attack(card):
			drift.append("attack %d->%d" % [int(attrs.get("skill_base", -1)), attack(card)])
		## [P105] The tier is sheet-first too now, so where the sheet and PLANT_DEFS disagree
		## the sheet wins and this is the line that shows the edit took effect. A blank cell is
		## not drift: it means the code row is still in charge (see Balance.plant_rarity).
		var sheet_tier := rarity(card)
		if sheet_tier != "" and str(attrs.get("rarity", "")) != sheet_tier:
			drift.append("rarity %s->%s" % [str(attrs.get("rarity", "")), sheet_tier])
		print("[Plants] card %-11s sheet cost %d cd %d hp %d atk %d | wired %s | %s%s"
			% [card, cost(card), cooldown(card), hp(card), attack(card), str(wired),
			   "OK" if wired else "FAIL",
			   (" (overrides Balance: " + ", ".join(drift) + ")") if not drift.is_empty() else ""])
		if not scripted:
			print("[Plants]        -> no script for '%s' in PlantScripts: the battle would"
				% card + " summon a peashooter under this name")
	## [P72] The audit this batch exists for: everything the 特殊机制 column promises,
	## grouped by what actually keeps that promise. REPORT-ONLY, deliberately - a sheet may
	## describe more than the engine runs, and the honest answer to that is a list rather than
	## a failing gate (the zombie side's "no flag understood" report set this precedent, and
	## the same reason holds: failing here would make the whole self-check red for a designer
	## note). The counts come first as one line, because they are the census; then the two
	## kinds of gap that want a DIFFERENT fix - a gate nobody runs wants a rule, an unprobed
	## sentence on a live card wants a probe (or means the engine already does it another way),
	## and an unprobed sentence on an almanac-only card wants nothing yet. The sentences
	## themselves are printed for the live rows only: those are the plants a player can put on
	## the board, so they are the ones where "the sheet says so" could silently differ from
	## "the game does it".
	var audit := prose_audit()
	var written := 0
	for bucket in audit:
		written += (audit[bucket] as Array).size()
	print("[Plants] 特殊机制 audit: %d of %d row(s) write the column - battle_read %d / script_run %d / gated_unrun %d / live_unprobed %d / sheet_unprobed %d"
		% [written, _order.size(), (audit["battle_read"] as Array).size(),
		   (audit["script_run"] as Array).size(), (audit["gated_unrun"] as Array).size(),
		   (audit["live_unprobed"] as Array).size(), (audit["sheet_unprobed"] as Array).size()])
	if not (audit["gated_unrun"] as Array).is_empty():
		print("[Plants] gate ON, nothing runs it: "
			+ ", ".join(PackedStringArray(audit["gated_unrun"])))
	if not (audit["live_unprobed"] as Array).is_empty():
		print("[Plants] prose no probe recognised, card IS summonable: "
			+ ", ".join(PackedStringArray(audit["live_unprobed"])))
		for id in (audit["live_unprobed"] as Array):
			print("[Plants]        -> %s: %s" % [str(id), text(str(id), "special")])
	if not (audit["sheet_unprobed"] as Array).is_empty():
		print("[Plants] prose no probe recognised, almanac only: "
			+ ", ".join(PackedStringArray(audit["sheet_unprobed"])))
	## [P72] The lists above are a REPORT and stay a report; this line is the GATE, and the
	## difference is the one claim this file makes about its own lists: a promise somebody
	## actually keeps is never shown as a gap. Deliberately here rather than in a battle probe
	## because it is pure table data - the boot scan is the channel that really runs it, and a
	## probe behind `open a level` would leave this batch's acceptance blind to it. Two halves:
	##   * cherry_bomb (一次性 WITH a script) keeps no gap, while doom_shroom (the same word,
	##     no script) does report one_shot - if simulates() ever stopped asking the roster the
	##     plant page would start calling five working cards broken, and this is the line that
	##     says so;
	##   * the two unprobed buckets split on the playable line, which is the whole difference
	##     between a designer note and a live card whose prose nobody has checked.
	## The rows are named on purpose: when somebody finally wires doom_shroom, THIS is the line
	## that tells them the report changed shape and the example has to move to another row.
	var doom_gaps := unsimulated_flags("doom_shroom")
	var split_ok := true
	for pid in (audit["live_unprobed"] as Array):
		split_ok = split_ok and is_playable(str(pid))
	for pid in (audit["sheet_unprobed"] as Array):
		split_ok = split_ok and not is_playable(str(pid))
	var report_ok: bool = unsimulated_flags("cherry_bomb").is_empty() \
		and doom_gaps.size() == 1 and str(doom_gaps[0]) == "one_shot" \
		and prose_state("cherry_bomb") == "script_run" \
		and prose_state("doom_shroom") == "gated_unrun" \
		and prose_state("melon_pult") == "battle_read" \
		and prose_state("peashooter") == "" \
		and split_ok
	ok = ok and report_ok
	print("[Plants] report gate: a scripted 一次性 card is not a gap, an unscripted one reports 'one_shot', and the unprobed rows split on the playable line = %s | %s"
		% [str(report_ok), "OK" if report_ok else "FAIL"])
	## [P80] D4 gave the blank-cell rule ONE owner (`UnitCsvManager.is_blank`), and this is the line
	## that goes red if a path rule grows its own narrower copy back. The sheets spell
	## "nothing here" five ways and all five must answer 'no art' here, exactly as `cell()`
	## already reads them: before this, the two rules below knew only `—`, so a cell written
	## `-` was blank to one reader and a FILENAME to this one - the same sheet said two
	## different things depending on which column the caller was reading. The second half is
	## the control, built from this file's OWN constants so it cannot drift from the rule.
	var blank_ok := true
	for mark in UnitCsvManager.BLANKS:
		blank_ok = blank_ok and svg_path(str(mark)) == "" and scene_path(str(mark)) == ""
	blank_ok = blank_ok and svg_path("q") == SVG_ROOT + "q" + SVG_EXT \
		and scene_path("q") == SCENE_ROOT + "q" + SCENE_SUFFIX
	ok = ok and blank_ok
	print("[Plants] the five 'nothing here' marks answer 'no art' in both path rules, while a spelled cell still builds a path = %s | %s"
		% [str(blank_ok), "OK" if blank_ok else "FAIL"])
	## [P57] Whatever the sheet read as a number on the way to this line, including the
	## rows and columns the walk above touched. A cell that is spelled but will not
	## parse used to land on Balance's default in silence, which is the one state this
	## file's whole contract ("the sheet is the source") cannot afford.
	## [P101] THE MECHANISM COLUMNS vs the 特殊机制 sentence. The columns are the RULE (they
	## are what the battle asks); the sentence is what the almanac shows. This counts the
	## cells that are ON and reports every row where the two disagree - a sentence promising
	## a mechanic its column does not switch on is exactly the state the old word-matching
	## reader would have turned into a silent "no", so it is said out loud here. REPORT-ONLY:
	## prose may legitimately say more than the four words (or say the opposite, e.g. a row
	## that spells 不溅射), and a report is what the two other prose audits already are.
	var flagged := 0
	var disagree := PackedStringArray()
	for entry in _order:
		var key := str(entry)
		var from_cells: Dictionary = row(key).get("flags", {})
		var from_prose := prose_flags(key)
		for flag in FLAGS_KNOWN:
			var on_cell: bool = bool(from_cells.get(str(flag), false))
			var on_prose: bool = bool(from_prose.get(str(flag), false))
			if on_cell:
				flagged += 1
			if on_cell != on_prose:
				disagree.append("%s %s(column %s, sentence %s)"
					% [key, flag, str(on_cell), str(on_prose)])
	ok = ok and disagree.is_empty()
	print("[Plants] %d mechanism cell(s) set across %d row(s); the four columns and the 特殊机制 sentence agree = %s%s | %s"
		% [flagged, _order.size(), str(disagree.is_empty()),
		   ("  disagree: " + ", ".join(disagree)) if not disagree.is_empty() else "",
		   "OK" if disagree.is_empty() else "FAIL"])
	## [P102] THE ROSTER IS THE SHEET'S NOW. Three things have to hold: the 卡片 numbers are
	## distinct (two rows sharing one would make the roster order an accident), the roster is
	## exactly the cards plus their spirit copies, and the code fall-back list spells the SAME
	## set - if it did not, a plant would be summonable or not depending on whether the sheet
	## happened to be readable that run.
	var cards := card_ids()
	var seen_numbers: Dictionary = {}
	var repeated := PackedStringArray()
	var not_in_sheet := PackedStringArray()
	for id in cards:
		var n := int(row(id).get("card", -1))
		if seen_numbers.has(n):
			repeated.append(str(n))
		seen_numbers[n] = true
	for entry in Balance.PLANT_CARD_FALLBACK:
		var fid := str(entry)
		if Balance.spirit_base(fid) == "" and not cards.has(fid):
			not_in_sheet.append(fid)
	var roster_ok: bool = repeated.is_empty() and not_in_sheet.is_empty() and not cards.is_empty() \
		and Balance.plant_cards().size() == cards.size() * 2 \
		and Balance.PLANT_CARD_FALLBACK.size() == cards.size() * 2
	ok = ok and roster_ok
	print("[Plants] %d card number(s), all distinct, roster = cards + spirit copies (%d), the code fall-back spells the same set = %s%s%s | %s"
		% [cards.size(), Balance.plant_cards().size(), str(roster_ok),
		   ("  repeated: " + ", ".join(repeated)) if not repeated.is_empty() else "",
		   ("  missing from the sheet: " + ", ".join(not_in_sheet)) if not not_in_sheet.is_empty() else "",
		   "OK" if roster_ok else "FAIL"])
	## [P105] THE TIER COLUMN vs THE TIER TABLE. `rarity` (units.csv) writes a unit's tier; the
	## tier's colour and its recovery factor live in data/rarity.csv (RarityDB). A row naming a
	## tier that table does not have would be a plant nothing can paint and whose downed time
	## falls to the code default, so the two are read against each other here - the same shape as
	## the `wired` claim above. Blank cells are NOT a failure: most plant rows are almanac-only
	## and owe no tier yet (the same "stub" state the price cells already report), and their
	## rarity falls back to PLANT_DEFS.
	var tiered := 0
	var tiers: Dictionary = {}
	var unknown_tiers := PackedStringArray()
	for entry in _order:
		var key := str(entry)
		var tier := rarity(key)
		if tier == "":
			continue
		tiered += 1
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		if not RarityDB.has(tier):
			unknown_tiers.append("%s=%s" % [key, tier])
	var census_names: Array = tiers.keys()
	census_names.sort()
	var census := PackedStringArray()
	for tier_name in census_names:
		census.append("%s %d" % [str(tier_name), int(tiers[tier_name])])
	var tiers_ok: bool = not tiers.is_empty() and unknown_tiers.is_empty()
	ok = ok and tiers_ok
	print("[Plants] %d of %d row(s) write %s (%s), %d leave it blank (code fall-back); every one names a tier rarity.csv knows = %s%s | %s"
		% [tiered, _order.size(), COL_RARITY, ", ".join(census), _order.size() - tiered,
		   str(tiers_ok),
		   ("  unknown: " + ", ".join(unknown_tiers)) if not unknown_tiers.is_empty() else "",
		   "OK" if tiers_ok else "FAIL"])
	ok = ok and UnitCsvManager.report_complaints("[Plants]")
	## [P100] The POTION wiring, checked the way the potion is now built: a plant that has a
	## `talent` row in the item sheet must resolve that row as its potion, and a plant that
	## has none must resolve "" - the 一次性 family is the case that rule exists for, and
	## "no potion" is now the ABSENCE of a row rather than an empty cell in a code table.
	var potion_ok := true
	var potioned := 0
	var no_potion := PackedStringArray()
	for entry in Balance.plant_cards():
		var id := str(entry)
		if Balance.spirit_base(id) != "":
			continue
		var item := Balance.plant_potion_item(id)
		var item_row := ItemDB.has(item) if item != "" else true
		var effect := str(Balance.plant_attrs(id).get("potion_effect", ""))
		var good: bool = item_row and (item == "" or effect != "")
		if item != "":
			potioned += 1
		elif not PlantDB.is_one_shot(id):
			no_potion.append(id)
		potion_ok = potion_ok and good
	## Every card that is NOT a one-shot owes the player a potion: a plant nobody can dose is
	## a talent the garden silently refuses.
	potion_ok = potion_ok and no_potion.is_empty()
	ok = ok and potion_ok
	print("[Plants] %d of %d card(s) resolve a potion from the item sheet, every non-一次性 card has one%s = %s | %s"
		% [potioned, Balance.plant_cards().size(),
		   ("  missing: " + ", ".join(no_potion)) if not no_potion.is_empty() else "",
		   str(potion_ok), "OK" if potion_ok else "FAIL"])
	print("[Plants] self-check %s" % ("PASSED" if ok else "FAILED"))
