class_name ZombieDB
extends RefCounted
## [P26] THE ZOMBIE ROSTER - now [P29] a thin facade over UnitSheet.
##
## The shared machinery (load, the race-layer merge, the generic queries) lives
## in scripts/core/unit_sheet.gd: units.csv owns one row per unit with the
## columns both rosters share (名称 / name / race / HP / 天赋 / 技能 / 特殊机制
## + twins / svg / tscn), the race sheet data/units/zombies.csv owns the
## zombie-only numbers (护甲 / 移动 / attack / 啃脑伤害), and a sub-race sheet named
## by the race path (zombies/mini would look for mini.csv) would override them -
## a missing family layer is simply skipped (user rule: 缺层跳过). The race column
## carries the size class the user asked for: zombies/mini, zombies/normal,
## zombies/huge.
##
## What stays HERE is what only zombies care about: the sheet's mechanic
## sentences and their translation into the flags the battle acts on, the base
## zombie as the yardstick, and this roster's self-check text.
##
## Why flags are derived here instead of being another column: the sheet states the
## mechanics as SENTENCES ("护甲被打掉后变普通僵尸" / "跳过第一株植物…"), which is
## how a designer writes them. PHRASES below is the one place that translates that
## vocabulary into the flags the battle code can act on. A sentence no phrase matches
## costs nothing: the zombie still has all of its numbers, the almanac shows the
## sentence as written, and self_check() reports it instead of hiding it.
##
## [P47] The first exception the sentence-only rule has had to make: a mechanic that
## RELATES two rows (summon) cannot be carried by prose alone, because the words do
## not say which row is the summoner's partner. The three COL_SUMMON_* columns are
## the machine-readable half of "每7回合召唤1只伴舞僵尸"; the sentence stays in the
## sheet for the reader, and simulates() is what keeps the two honest with each
## other - a row that names 召唤 without its columns is still shown as "not
## simulated", because the battle genuinely cannot run it.
##
## What the battle actually SIMULATES today (FLAGS_SIMULATED):
##   execute        hp <= 1/3 of max -> dies at once (the base zombie's own rule)
##   armor_downgrade  its armour breaking turns it into a plain zombie
##   vault          pole vaults over the first plant once, then becomes plain
##   drops_diamond  it always drops a diamond (the snow goblin's pay-out)
##   freeze_immune  [P34] a type whose row says 免疫冻结 refuses the freeze rider
##   blocks_projectiles  [P45] while the 铁门 is up it takes the shot, so a
##                  projectile's riders never land on that zombie - [P77] and it takes
##                  a STRAIGHT shot: an arc, a blast or a spike is not what a door stops
##                  (the shot says which it is, see Projectile.straight_shot)
##   back_attack_ignores_armor  [P45] and the same door only guards the facing
##                  side: a hit from behind skips the armour layer entirely
##   summon         [P47] the dancer calls its backup dancers - but ONLY for a row
##                  that says who and how often (see COL_SUMMON_* below), because
##                  the sentence alone is not enough to run it: 伴舞僵尸's own row
##                  says "被舞王僵尸召唤", which names the same verb in the PASSIVE
##                  voice. simulates() is therefore the row-aware half of this list,
##                  and the almanac still calls a data-less row "not simulated".
##   smash          [P48] the giant raises its hammer for 锤击前摇 rounds, drops it for
##                  the row's full attack (NO bite ratio - the wind-up is what the damage
##                  pays for), then stands recovering for 锤击后摇 rounds. Row-aware for
##                  the same reason: a 锤击 without its columns is a word, not a rule.
##   rage           [P68] the newspaper's paper: losing its armour swaps the row's own
##                  暴怒移动 / 暴怒attack pair in - the SAME zombie with different numbers,
##                  which is why it is NOT the armor_downgrade above (that one hands the
##                  body to the base row, type and name included). Row-aware like the
##                  two before it: 暴怒 without both cells is a word, not a rule.
## Every other mechanic named in the sheet (flight, the thrown imp) is shown in the
## almanac and NOT simulated yet -
## the ids are listed in FLAGS_KNOWN so the gap is explicit rather than a silent lie.

const PATH := "res://data/units/zombies.csv"
## [P29] The race root whose rows this roster lists (UnitSheet filters the shared
## units.csv by it). The svg / tscn roots hang off the same token.
const RACE_ROOT := "zombies"

# ---------------------------------------------------------------- the svg column
## [P28] WHERE a zombie type's sprite lives. The svg cell holds the part AFTER this root
## and WITHOUT the extension ("zombie_cone", "water/zombie_ducky"), the short form a
## designer can read in a spreadsheet - the same rule data/items.csv and plants.csv use
## (see svg_path()). A type whose registered file is not there yet wears the base
## zombie's picture, so a new row never leaves a hole on the board.
const SVG_ROOT := "res://assets/svg/units/zombies/"
const SVG_EXT := ".svg"

# ---------------------------------------------------------------- the tscn column
## [P28] WHERE a zombie type's VIEW SCENE lives. The tscn cell holds the part AFTER this
## root and WITHOUT the "_view.tscn" suffix ("zombie_cone" ->
## res://scenes/units/zombies/zombie_cone_view.tscn), the short form the svg column uses
## (see scene_path()). A full "res://...tscn" cell works too.
const SCENE_ROOT := "res://scenes/units/zombies/"
const SCENE_SUFFIX := "_view.tscn"

# ---------------------------------------------------------------- sheet columns
# The ZOMBIE-ONLY columns - the shared ones (名称 / name / race / HP / 天赋 /
# 技能 / 特殊机制 / svg / tscn) are named by UnitSheet's COL_* and arrive merged.
const COL_TALENT := UnitSheet.COL_TALENT
const COL_SKILL := UnitSheet.COL_SKILL
const COL_ID := UnitSheet.COL_ID
## [P28] The type's picture, relative to SVG_ROOT and without the ".svg" suffix. A "—"
## cell (or a file nobody has drawn yet) means the base zombie's sprite is drawn.
const COL_SVG := UnitSheet.COL_SVG
## [P28] The type's VIEW SCENE, relative to SCENE_ROOT and without the "_view.tscn"
## suffix. A "—" cell means "this type has no scene": the sprite above is drawn instead.
const COL_TSCN := UnitSheet.COL_TSCN
const COL_HP := UnitSheet.COL_HP
const COL_ARMOR := "护甲"
const COL_MOVE := "移动"
## [P86] The shared attack column, read here as the bite: units.csv owns the name
## (both rosters share it), which is why it comes from UnitSheet.
const COL_BITE := UnitSheet.COL_ATTACK
const COL_SPECIAL := UnitSheet.COL_SPECIAL
## [P26] Optional: how hard this type chews the BRAIN once it reaches column 0. A "—"
## keeps Balance.ZOMBIE_BRAIN_DAMAGE (every type uses the same value today).
const COL_BRAIN_DAMAGE := "啃脑伤害"
## [P110e] WHAT A ZOMBIE'S MELEE BLOW LOOKS LIKE, by the id of a drawing under assets/svg/fx/.
## Read off the FLAT row like every other cell, so it is zombies.csv's own column and that
## sheet's default row answers for every type that leaves it blank - which is all of them:
## "every zombie claws" is ONE cell, not forty-four.
const COL_MELEE_FX := "近战特效"
## [P47] The three columns that turn "每7回合召唤1只伴舞僵尸" into a rule the battle can
## run. They exist because the sentence on its own cannot be trusted: 伴舞僵尸's row says
## "被舞王僵尸召唤" - the same verb, the opposite direction - and a flag read off prose
## alone would hand the summoned unit a summoner's job. A row that carries the 召唤
## flag WITHOUT these cells is not simulated (see simulates()), which is both the honest
## almanac line and the reason a typo in 召唤单位 is reported instead of ignored.
const COL_SUMMON_ROUNDS := "召唤间隔"
const COL_SUMMON_COUNT := "召唤数量"
const COL_SUMMON_UNIT := "召唤单位"
## [P48] The two columns that turn "锤击有3回合前摇和2回合后摇" into a rule the battle can
## run, on the same [P47] reasoning: the sentence names the mechanic, only the cells carry
## its numbers. 前摇 is how many rounds the raised hammer holds before it falls (the plant
## gets that much time to kill the giant); 后摇 is how many rounds it is busy afterwards -
## which `Unit.stand_down_rounds` already knows how to count, so the second number costs
## no new state at all.
const COL_HAMMER_WINDUP := "锤击前摇"
const COL_HAMMER_RECOVERY := "锤击后摇"
## [P68] The two columns that turn "报纸被打掉后暴怒：移动变1，啃食变150" into a rule the
## battle can run, on the same [P47] reasoning as the summon and the hammer: the sentence
## names the mechanic, only the cells carry its numbers - this DB has never read a number
## out of prose, and a hard-coded 1 / 150 in Zombie._enrage() would put the sheet's own
## figures in the code. They OVERRIDE the row's 移动 / attack for as long as the rage lasts,
## so the pair is named after the two columns it replaces (the prose calls the second one
## 啃食, the header has always called it attack).
const COL_RAGE_MOVE := "暴怒移动"
const COL_RAGE_BITE := "暴怒attack"

const TEXT_FIELDS: Array[String] = ["name", "talent", "skill", "special"]
const SOURCE_COLUMNS := {
	"name": UnitSheet.COL_NAME,
	"talent": COL_TALENT,
	"skill": COL_SKILL,
	"special": COL_SPECIAL,
}

## The zombie every other row is measured against: its hp is what a level's
## "zombie_hp" field means, and a row that says "和普通僵尸一样" inherits
## its flags.
const BASE_ID := "zombie"

## The sheet's mechanic vocabulary -> the flags the battle understands. Matched as
## SUBSTRINGS of 特殊机制, so the sentence may carry extra words around the phrase.
##
## "same_as_zombie" is NOT a mechanic: it is the inheritance marker for "和普通僵尸一样"
## (see _inherit_base_flags) and is deliberately never shown to the player.
const PHRASES := {
	"低于1/3": ["execute"],
	## [P46] This key used to start with 护甲, which silently skipped the 垃圾桶 zombie:
	## its row says "垃圾桶护甲，被打掉后变普通僵尸" - the SAME rule, written with the
	## armour's name in front of it. A phrase table matched by substring has to be keyed
	## on the part every wording shares, or the row keeps its numbers and loses its rule
	## (the sheet gave trash-can 800 armour, and breaking it did nothing).
	"被打掉后变普通僵尸": ["armor_downgrade"],
	"护甲打掉后移动变3": ["armor_downgrade"],
	"跳过第一株植物": ["vault"],
	"飞行": ["flying"],
	"免疫冻结": ["freeze_immune"],
	"召唤": ["summon"],
	"锤击": ["smash"],
	"暴怒": ["rage"],
	"投掷": ["thrown"],
	"格挡射弹": ["blocks_projectiles"],
	"无视护甲": ["back_attack_ignores_armor"],
	"替换1只": ["rare_replacement"],
	"走到最右消失": ["walks_off"],
	"钻石": ["drops_diamond"],
	"和普通僵尸一样": ["same_as_zombie"],
}

## Flags the battle code really acts on (see the class comment).
## [P34] "freeze_immune" joined the list with the snow pea: a type whose 特殊机制
## says 免疫冻结 now really refuses the freeze rider (Zombie.apply_hit_effects asks
## this table), so the almanac stops calling a working rule "not simulated".
## [P45] The 铁门's two halves joined next: Zombie.apply_hit_effects refuses a
## projectile's riders while the door still stands ("格挡射弹"), and
## Zombie.take_damage lets a hit that arrives from behind skip the armour
## ("只挡正面…背后attack无视护甲"). Both read the flags below through
## Zombie.apply_type(), so a stripped door stops carrying them with its armour.
## [P77] The sentence's "直线" is NOT a flag: which flight a hit belongs to is a fact the
## shot carries (Projectile.straight_shot, false for a lob), because the sheet uses the
## same two words 射弹 for what lands ON the door and for what the door refuses, while the
## answer differs by kind of shot. blocks_projectiles is therefore half of a gate whose
## other half lives on the attacker - and a row that says 格挡射弹 but is never fired at
## still reads as simulated, which is honest: the battle does act on the flag.
## [P47] "summon" joins next: Zombie.act() spawns the unit its own row names, at the
## pace its own row sets. It is the one flag here that a row may carry WITHOUT running
## - simulates() is the row-aware half of the list - because 被舞王僵尸召唤 says the
## verb from the other side, and prose alone cannot tell a summoner from a summonee.
## [P68] "rage" joins with the newspaper's paper: losing the armour swaps the row's
## 暴怒移动 / 暴怒attack pair onto the same body. Row-aware like summon and smash, because
## a 暴怒 without its two cells leaves the battle with a word and no numbers.
const FLAGS_SIMULATED: Array[String] = ["execute", "armor_downgrade", "vault",
	"drops_diamond", "freeze_immune", "blocks_projectiles", "back_attack_ignores_armor",
	"summon", "smash", "rage"]
## Every MECHANIC the sheet can name. The ones missing from FLAGS_SIMULATED are printed
## by the almanac as "not simulated", which is the honest half of the same coin.
const FLAGS_KNOWN: Array[String] = ["flying", "freeze_immune", "summon", "smash", "rage",
	"thrown", "blocks_projectiles", "back_attack_ignores_armor", "rare_replacement",
	"walks_off"]
## Markers that describe the SHEET rather than the zombie and must never be shown.
const FLAGS_INTERNAL: Array[String] = ["same_as_zombie"]

static var _rows: Dictionary = {}
static var _order: Array[String] = []
static var _loaded: bool = false
static var _tried: bool = false
static var _error: String = ""
static var _problems: Array[String] = []
static var _missing_en: int = 0
static var _unmatched: Array[String] = []   # "id: sentence" the phrase table did not know


# ---------------------------------------------------------------- loading
static func _sheet() -> UnitSheet:
	## [P29] The shared roster reader - the SAME instance PlantDB reads.
	return UnitSheet.live()


static func load_from_disk() -> bool:
	_tried = true
	_rows.clear()
	_order.clear()
	_problems.clear()
	_unmatched.clear()
	_missing_en = 0
	_error = ""

	var sheet := _sheet()
	if not sheet.load_roster():
		_error = sheet.error_text()
		_loaded = false
		return false

	for id in sheet.ids_for(RACE_ROOT):
		_rows[id] = _parse_row(sheet.get_flat(id), id)
		_order.append(id)

	_inherit_base_flags()
	## Roster-level complaints belong to the sheet, so both DBs report them.
	_problems = sheet.problems()
	_problems.append_array(sheet.orphans())

	_loaded = not _order.is_empty()
	if not _loaded:
		_error = "no usable zombie row"
	return _loaded


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
		if field != "name" and zh != "" and not UnitCsvManager.has_en(p_raw, column):
			_missing_en += 1
	var sentence := str((texts["special"] as Dictionary).get("zh", ""))
	## [P47] The summon cells, read here because "what does this row summon" is a
	## property of the ROW, not of the flag: 0 / "" simply means the row never said.
	var summon_rounds: int = maxi(0, UnitCsvManager.int_cell(p_raw, [COL_SUMMON_ROUNDS], 0))
	var summon_count: int = maxi(0, UnitCsvManager.int_cell(p_raw, [COL_SUMMON_COUNT], 0))
	var summon_unit := UnitCsvManager.cell(p_raw, COL_SUMMON_UNIT)
	## [P48] the hammer's two numbers, read the same way (0 = this row never said).
	var hammer_windup: int = maxi(0, UnitCsvManager.int_cell(p_raw, [COL_HAMMER_WINDUP], 0))
	var hammer_recovery: int = maxi(0, UnitCsvManager.int_cell(p_raw, [COL_HAMMER_RECOVERY], 0))
	## [P68] the enraged pair, read the same way (0 = this row never said, so it cannot rage)
	var rage_move: int = maxi(0, UnitCsvManager.int_cell(p_raw, [COL_RAGE_MOVE], 0))
	var rage_bite: int = maxi(0, UnitCsvManager.int_cell(p_raw, [COL_RAGE_BITE], 0))
	var flags := _flags_of(p_id, sentence)
	return {
		"id": p_id,
		"zh": str((texts["name"] as Dictionary).get("zh", "")),
		"texts": texts,
		## [P28] the sheet's own svg cell, kept as written (relative, extension-less);
		## svg_path() / art() are the two places that turn it into a res:// path.
		"svg": UnitCsvManager.cell(p_raw, COL_SVG),
		## [P28] the same for the view scene: scene_path() / view() resolve it.
		"tscn": UnitCsvManager.cell(p_raw, COL_TSCN),
		"hp": maxi(1, UnitCsvManager.int_cell(p_raw, [COL_HP], 1)),
		"armor": maxi(0, UnitCsvManager.int_cell(p_raw, [COL_ARMOR], 0)),
		## [P30-A] 移动 = the LENGTH of the zombie's move-progress bar: the walk is a
		## skill costing BalanceBattle.ZOMBIE_MOVE_COST AP and charging +1 progress, so the
		## zombie crosses a cell after `移动` rounds (the base zombie's 3 is Balance's 3).
		"move": maxi(1, UnitCsvManager.int_cell(p_raw, [COL_MOVE], Balance.ZOMBIE_ADVANCE_THRESHOLD)),
		"bite": maxi(0, UnitCsvManager.int_cell(p_raw, [COL_BITE], Balance.ZOMBIE_BITE_DAMAGE)),
		## [P26] the brain is a resource of its own: a type may chew it faster than the
		## rest (the sheet leaves it at 10 everywhere today).
		"brain": maxi(1, UnitCsvManager.int_cell(p_raw, [COL_BRAIN_DAMAGE], Balance.ZOMBIE_BRAIN_DAMAGE)),
		## [P47] the summon plan as the sheet states it (0 / "" = this row never said)
		"summon_rounds": summon_rounds,
		"summon_count": summon_count,
		"summon_unit": summon_unit,
		## [P48] the hammer's wind-up and recovery, same convention (0 = never said)
		"hammer_windup": hammer_windup,
		"hammer_recovery": hammer_recovery,
		## [P68] the enraged pair, same convention (0 = never said)
		"rage_move": rage_move,
		"rage_bite": rage_bite,
		## [P110e] the melee picture as the sheet spells it (see COL_MELEE_FX)
		"melee_fx": UnitCsvManager.cell(p_raw, COL_MELEE_FX),
		"flags": flags,
	}


static func _flags_of(p_id: String, p_sentence: String) -> Dictionary:
	var flags: Dictionary = {}
	for phrase in PHRASES.keys():
		if p_sentence.contains(str(phrase)):
			for flag in (PHRASES[phrase] as Array):
				flags[str(flag)] = true
	if p_sentence != "" and flags.is_empty():
		_unmatched.append("%s: %s" % [p_id, p_sentence])
	return flags


static func _inherit_base_flags() -> void:
	## "和普通僵尸一样" is the sheet's way of saying "this row is the base zombie with
	## another name": it copies the base row's flags, so the flag zombie is fragile
	## exactly like the plain one without repeating the sentence.
	var base: Dictionary = _rows.get(BASE_ID, {})
	if base.is_empty():
		return
	var base_flags: Dictionary = base.get("flags", {})
	for id in _order:
		var r: Dictionary = _rows[id]
		var flags: Dictionary = r.get("flags", {})
		if not bool(flags.get("same_as_zombie", false)):
			continue
		for flag in base_flags.keys():
			flags[str(flag)] = true
		r["flags"] = flags


# ---------------------------------------------------------------- the svg path rule
static func svg_path(p_cell: String) -> String:
	## [P28] "water/zombie_ducky" -> "res://assets/svg/units/zombies/water/zombie_ducky.svg".
	##
	## The same rule ItemDB.svg_path() applies to data/items.csv: a cell that already
	## spells a full res:// path, or that carries its own extension (.svg / .png), is used
	## as it is - so the short spelling and the full one reach the same file.
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
	## [P28] "zombie_cone" -> "res://scenes/units/zombies/zombie_cone_view.tscn".
	##
	## The same rule svg_path() applies: a cell that already spells a full res:// path, or
	## that carries its own ".tscn", is used as it is.
	var cell_text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(cell_text):
		return ""
	if cell_text.begins_with("res://"):
		return cell_text
	if not cell_text.ends_with(".tscn"):
		cell_text += SCENE_SUFFIX
	return SCENE_ROOT + cell_text


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
	## The base zombie is ALWAYS known, even before (or without) a sheet: the level
	## files and the probes may name it, and a battle with no zombie at all would be
	## worse than a battle with the built-in one.
	_ensure()
	return p_id == BASE_ID or _rows.has(p_id)


static func row(p_id: String) -> Dictionary:
	_ensure()
	return _rows.get(p_id, {})


static func name(p_id: String) -> String:
	## LocNames "unit.<id>" first (the language layer's own table), the sheet second.
	_ensure()
	var fallback := text(p_id, "name")
	if fallback == "":
		fallback = p_id
	return Loc.t("unit." + p_id, fallback)


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
	var r := row(p_id)
	return maxi(1, int(r.get("hp", Balance.ZOMBIE_HP)))


static func armor(p_id: String) -> int:
	return maxi(0, int(row(p_id).get("armor", 0)))


static func move(p_id: String) -> int:
	var r := row(p_id)
	return maxi(1, int(r.get("move", Balance.ZOMBIE_ADVANCE_THRESHOLD)))


static func bite(p_id: String) -> int:
	var r := row(p_id)
	return maxi(0, int(r.get("bite", Balance.ZOMBIE_BITE_DAMAGE)))


static func melee_fx(p_id: String) -> String:
	## [P110e] The drawing this type's melee blow leaves, or "" for none of its own. Answered
	## by the default row of zombies.csv today, so every type says "claw"; a type that ever
	## swings something else states it in its own cell and nothing here changes.
	return str(row(p_id).get("melee_fx", ""))


static func brain_damage(p_id: String) -> int:
	## How much of the brain this type eats per EAT_BRAIN. An id the sheet does not have
	## (or a "—" cell) falls back to Balance.ZOMBIE_BRAIN_DAMAGE.
	var r := row(p_id)
	return maxi(1, int(r.get("brain", Balance.ZOMBIE_BRAIN_DAMAGE)))


static func race(p_id: String) -> String:
	## [P29] The type's race path ("zombies/normal", "zombies/mini", "zombies/huge"),
	## straight from units.csv. The size classes are the user's P29 split; the battle
	## does not read them yet, but a future family sheet (mini.csv ...) would supply
	## shared defaults through UnitSheet without this class changing.
	return _sheet().race(p_id)


static func has_flag(p_id: String, p_flag: String) -> bool:
	var flags: Dictionary = row(p_id).get("flags", {})
	return bool(flags.get(p_flag, false))


static func get_summon_rounds(p_id: String) -> int:
	## [P47] How many rounds pass between two summons for this row (0 = never said).
	return maxi(0, int(row(p_id).get("summon_rounds", 0)))


static func get_summon_count(p_id: String) -> int:
	## How many units one summon call brings (0 = never said).
	return maxi(0, int(row(p_id).get("summon_count", 0)))


static func get_summon_unit(p_id: String) -> String:
	## Which type this row summons, as the 召唤单位 cell spells the id ("" = never said).
	return str(row(p_id).get("summon_unit", ""))


static func can_summon(p_id: String) -> bool:
	## [P47] The row-aware half of "does the battle run 召唤 for this zombie". All four
	## parts have to hold: the sentence named it, and the row said WHO, HOW MANY and
	## HOW OFTEN. A typo in 召唤单位 lands here too - an id the roster does not have is
	## not a summon plan, it is a broken reference, and summon_gaps() says so.
	return has_flag(p_id, "summon") and get_summon_rounds(p_id) > 0 and get_summon_count(p_id) > 0 \
		and get_summon_unit(p_id) != "" and has(get_summon_unit(p_id))


static func summon_gaps() -> Array[String]:
	## [P47] Rows whose sentence says 召唤 but which the battle cannot run: the sheet
	## names the verb without naming a partner. Read-only, and reported (never failed)
	## exactly like the unmatched sentences - the point is that the gap stays on record.
	## The two causes are told apart because they need different fixes: a row that
	## never filled the cells in (伴舞僵尸's "被…召唤" is a summonee, not a summoner) and
	## a row whose 召唤单位 names a unit the roster does not have (a typo, i.e. a
	## broken reference of exactly the kind P44 started gate-keeping).
	var out: Array[String] = []
	_ensure()
	for id in _order:
		if not has_flag(id, "summon") or can_summon(id):
			continue
		var target := get_summon_unit(id)
		if target != "" and not has(target):
			out.append("%s: 召唤单位 '%s' is no unit of this roster" % [id, target])
		else:
			out.append("%s: 召唤 without 召唤间隔/召唤数量/召唤单位" % id)
	return out


static func get_hammer_windup(p_id: String) -> int:
	## [P48] Rounds the hammer stays raised before it falls (0 = never said).
	return maxi(0, int(row(p_id).get("hammer_windup", 0)))


static func get_hammer_recovery(p_id: String) -> int:
	## [P48] Rounds the giant is busy after the hammer has fallen (0 = never said).
	return maxi(0, int(row(p_id).get("hammer_recovery", 0)))


static func can_smash(p_id: String) -> bool:
	## [P48] The row-aware half of "does the battle run 锤击 for this zombie": the
	## sentence named the hammer AND the row said how long the wind-up and the
	## recovery take. Only the recovery may be 0 - a hammer that never tires is a
	## design choice the sheet is allowed to make - but a wind-up of 0 would mean
	## "the plant in front dies the instant it is touched", i.e. the old bite with a
	## new name, so it is required.
	return has_flag(p_id, "smash") and get_hammer_windup(p_id) > 0


static func smash_gaps() -> Array[String]:
	## [P48] Rows that write 锤击 without a 锤击前摇. Reported, never failed, exactly
	## like the summon gaps and the unmatched sentences: the gap has to stay on
	## record, because the almanac is still showing those rows a rule they do not run.
	var out: Array[String] = []
	_ensure()
	for id in _order:
		if has_flag(id, "smash") and not can_smash(id):
			out.append("%s: 锤击 without 锤击前摇" % id)
	return out


static func get_rage_move(p_id: String) -> int:
	## [P68] The length of the move bar once this row is enraged (0 = never said).
	return maxi(0, int(row(p_id).get("rage_move", 0)))


static func get_rage_bite(p_id: String) -> int:
	## [P68] The 啃食 this row chews with once enraged (0 = never said).
	return maxi(0, int(row(p_id).get("rage_bite", 0)))


static func can_rage(p_id: String) -> bool:
	## [P68] The row-aware half of "does the battle run 暴怒 for this zombie": the
	## sentence named the rage AND the row gave both numbers. One of the two is not
	## enough - a row that only says how fast the enraged body walks would leave the
	## bite at its calm value and the almanac would still promise "啃食变150", so the
	## swap is all-or-nothing like the summon plan and the hammer.
	##
	## What this does NOT check is whether the row HAS armour to lose: the rage needs a
	## layer to break, and 护甲 is the cell that carries it (the newspaper's 150 is the
	## paper). That half is asserted by the probe rather than by this gate, because a
	## row could also rage off a mechanic that spends the armour another way, and
	## inventing a second condition here would hide exactly the drift P46 had to fix.
	return has_flag(p_id, "rage") and get_rage_move(p_id) > 0 and get_rage_bite(p_id) > 0


static func rage_gaps() -> Array[String]:
	## [P68] Rows that write 暴怒 without the two numbers, reported and never failed -
	## the same record the summon and smash gaps keep. Today this is empty, and it is
	## the reason 愤怒僵尸's row can be left alone: its sentence says 愤怒状态, not 暴怒,
	## so the phrase table never hands it the flag and it owes nothing.
	var out: Array[String] = []
	_ensure()
	for id in _order:
		if has_flag(id, "rage") and not can_rage(id):
			out.append("%s: 暴怒 without 暴怒移动/暴怒attack" % id)
	return out


static func simulates(p_id: String, p_flag: String) -> bool:
	## [P47] "Would the battle act on this mechanic FOR THIS ROW?" The almanac and the
	## self-check ask this instead of is_simulated(), so promoting a flag cannot quietly
	## upgrade a row that never gave the data the mechanic needs.
	## [P48] 锤击 joins the row-aware list for the same reason 召唤 did: a row that
	## writes the word without its two columns cannot be run, and saying "simulated"
	## about it would be the lie P40-C2 named.
	if not has_flag(p_id, p_flag):
		return false
	if p_flag == "summon":
		return can_summon(p_id)
	if p_flag == "smash":
		return can_smash(p_id)
	if p_flag == "rage":
		return can_rage(p_id)
	return is_simulated(p_flag)


static func is_simulated(p_flag: String) -> bool:
	return FLAGS_SIMULATED.has(p_flag)


static func unsimulated_flags(p_id: String) -> Array[String]:
	## The mechanics this zombie's sentence names that the battle does NOT act on.
	## The almanac prints them so a player (and the next developer) can tell "the
	## sheet says so" from "the game does it". The sheet's own markers
	## (FLAGS_INTERNAL, e.g. "same as a normal zombie") are never listed: they describe
	## the sheet, not a mechanism.
	var out: Array[String] = []
	var flags: Dictionary = row(p_id).get("flags", {})
	for flag in FLAGS_KNOWN:
		if bool(flags.get(flag, false)) and not simulates(p_id, str(flag)):
			out.append(flag)
	return out


static func svg_rel(p_id: String) -> String:
	## [P28] The sheet's own svg cell, still relative - "" when the row registers none.
	_ensure()
	return str(row(p_id).get("svg", ""))


static func svg_file(p_id: String) -> String:
	## [P28] The file the SHEET registers for this type, as a res:// path - whether or not
	## the editor has imported it yet. "" when the row registers no picture.
	return svg_path(svg_rel(p_id))


static func art(p_id: String) -> String:
	## [P28] The sprite this TYPE draws: the file the sheet's svg column registers, and the
	## base zombie's picture (Balance.ART_ZOMBIE) whenever that file is not there (yet). A
	## type whose cell names a file nobody has drawn therefore still looks like a zombie
	## instead of an empty cell, and has_art() says which of the two a type wears.
	var path := svg_file(p_id)
	if path != "" and UnitArt.load_texture(path) != null:
		return path
	return Balance.ART_ZOMBIE


static func has_art(p_id: String) -> bool:
	## [P28] True when this type wears a sprite of its OWN rather than the base zombie's
	## (the almanac draws either way; this is the answer to "why do these two look the
	## same"). Compared against what the BASE row resolves to, so a sheet that moved the
	## base zombie's picture cannot make every other type look like it has art.
	return art(p_id) != art(BASE_ID)


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
	## [P28] How many types really draw a file of their own instead of the base zombie's
	## picture - the number UnitArt's self-check prints next to the roster size.
	_ensure()
	var n := 0
	for id in _order:
		if has_art(id):
			n += 1
	return n


static func melee_fx_count() -> int:
	## [P110e] How many types name a melee picture of their own. Answered by the sheet's DEFAULT
	## row today, so this equals the roster size - which is the point: a reading that would drop
	## in the boot line the day the default row stops answering is a reading worth having, since
	## a zombie that stops clawing is otherwise invisible until somebody watches a fight.
	_ensure()
	var n := 0
	for id in _order:
		if melee_fx(id) != "":
			n += 1
	return n


static func scene_rel(p_id: String) -> String:
	## [P28] The sheet's own tscn cell, still relative - "" when the row registers none.
	_ensure()
	return str(row(p_id).get("tscn", ""))


static func scene_file(p_id: String) -> String:
	## [P28] The VIEW SCENE the sheet registers for this type, as a res:// path - whether
	## or not the file exists yet. "" when the row registers no scene. This is what the
	## SHEET asks for (what self_check() reports); view() is what the board draws.
	return scene_path(scene_rel(p_id))


static func view(p_id: String) -> String:
	## [P28] The scene the BOARD draws for this type, or "" when it has none - which is
	## every type today. A scene the cell names but nobody has built yet leaves the type on
	## its sprite (art()), so the column may be filled in before the part exists.
	var path := scene_file(p_id)
	if path != "" and UnitArt.load_scene(path) != null:
		return path
	return ""


static func has_view(p_id: String) -> bool:
	## [P28] True when this type really draws a scene on the board (i.e. view() != "").
	return view(p_id) != ""


static func view_count() -> int:
	## [P28] How many types really draw a SCENE on the board - the number UnitArt's
	## self-check prints next to the sprite count.
	_ensure()
	var n := 0
	for id in _order:
		if has_view(id):
			n += 1
	return n


static func stats(p_id: String) -> Dictionary:
	## Everything the spawner needs, in one dictionary, so a caller never reaches into
	## the row layout.
	return {
		"hp": hp(p_id),
		"armor": armor(p_id),
		"move": move(p_id),
		"bite": bite(p_id),
		"brain": brain_damage(p_id),
		"flags": row(p_id).get("flags", {}).duplicate(),
	}


static func base_hp() -> int:
	## The hp a level's "zombie_hp" field refers to. Falls back to Balance when the
	## sheet is unavailable, so the scaling never divides by zero.
	var value := hp(BASE_ID) if has(BASE_ID) else Balance.ZOMBIE_HP
	return maxi(1, value)


static func problems() -> Array[String]:
	_ensure()
	return _problems.duplicate()


static func status_text() -> String:
	_ensure()
	if not _loaded:
		return "zombies: sheet NOT loaded (%s)" % error_text()
	return "zombies: %d row(s) under race '%s', base hp %d, %d with their own sprite, %d with a view scene, %d with a 近战特效, %d prose field(s) with no English twin" \
		% [_order.size(), RACE_ROOT, base_hp(), art_count(), view_count(), melee_fx_count(), _missing_en]


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	print("[Zombies] --- roster for race '%s' (%s + %s) ---" % [RACE_ROOT, UnitSheet.ROSTER_PATH.get_file(), PATH.get_file()])
	if not is_loaded():
		print("[Zombies] sheet not loaded: " + error_text() + " | FAIL")
		print("[Zombies] -> the built-in Balance zombie is being used instead")
		print("[Zombies] self-check FAILED")
		return
	print("[Zombies] %d type(s), base id '%s' hp %d, %d prose field(s) with no English twin"
		% [_order.size(), BASE_ID, base_hp(), _missing_en])
	var ok := true
	for id in _order:
		var r := row(id)
		var flags: Array = (r.get("flags", {}) as Dictionary).keys()
		flags.sort()
		## join() needs a PackedStringArray in Godot 4 (HANDOFF 7.3), so the two lists
		## are built as one from the start. "same_as_zombie" is a marker of the SHEET
		## (it means "copy the base row's flags"), not a mechanic, so it is left out of
		## both lists.
		var simulated := PackedStringArray()
		for flag in flags:
			## [P47] simulates() and not is_simulated(): a promoted flag still has to be
			## runnable for THIS row, or the line would claim a rule the game never fires.
			if simulates(id, str(flag)):
				simulated.append(str(flag))
		var pending := PackedStringArray()
		for flag in unsimulated_flags(id):
			pending.append(flag)
		var line := "[Zombies] %-17s %-10s hp %-5d armor %-4d move %d bite %-5d brain %-4d" % [
			id, name(id), int(r.get("hp", 0)), int(r.get("armor", 0)),
			int(r.get("move", 0)), int(r.get("bite", 0)), brain_damage(id)]
		var good := int(r.get("hp", 0)) > 0 and int(r.get("move", 0)) > 0
		ok = ok and good
		## [P28] Which sprite this type wears, as the sheet's svg cell spells it. A cell
		## naming a file nobody has drawn yet is marked, together with what stands in for
		## it (ZombieDB.art() draws the base zombie, never an empty cell).
		var sprite := svg_file(id)
		if sprite == "":
			line += "  art (base zombie)"
		elif UnitArt.load_texture(sprite) != null:
			line += "  art %s" % UnitArt.short_art_path(sprite)
		else:
			line += "  art %s NOT IMPORTED (base zombie)" % UnitArt.short_art_path(sprite)
		## [P28] And the VIEW SCENE the row registers on top of that sprite: the board
		## draws the scene when it loads, the sprite when it does not. "NOT FOUND" is the
		## ordinary state of a cell filled in before the part exists (counted, not failed).
		var scene := scene_file(id)
		if scene == "":
			line += "  view (none)"
		elif UnitArt.load_scene(scene) != null:
			line += "  view %s" % scene.get_file()
		else:
			line += "  view %s NOT FOUND (sprite in use)" % scene.get_file()
		line += "  sim[%s]" % ("-" if simulated.is_empty() else ", ".join(simulated))
		if not pending.is_empty():
			line += " shown-only[%s]" % ", ".join(pending)
		line += "  | " + ("OK" if good else "FAIL")
		print(line)
	## The base zombie is the yardstick of the balance sheet: its hp is what a level's
	## "zombie_hp" means and its bite is what the brain is chewed with. Checked as
	## WIRING - the spawner must read the SHEET - rather than as agreement: the sheet is
	## allowed to disagree with Balance (that is what "data driven" means), and a
	## difference is printed instead of failed.
	var drift := PackedStringArray()
	if hp(BASE_ID) != Balance.ZOMBIE_HP:
		drift.append("hp %d->%d" % [Balance.ZOMBIE_HP, hp(BASE_ID)])
	if bite(BASE_ID) != Balance.ZOMBIE_BITE_DAMAGE:
		drift.append("bite %d->%d" % [Balance.ZOMBIE_BITE_DAMAGE, bite(BASE_ID)])
	if move(BASE_ID) != Balance.ZOMBIE_ADVANCE_THRESHOLD:
		drift.append("move %d->%d" % [Balance.ZOMBIE_ADVANCE_THRESHOLD, move(BASE_ID)])
	var base_ok: bool = has(BASE_ID) and hp(BASE_ID) > 0 and move(BASE_ID) > 0 \
		and bite(BASE_ID) >= 0 and base_hp() == hp(BASE_ID)
	print("[Zombies] base row wired to the spawner (hp %d, bite %d, move %d) = %s | %s%s"
		% [hp(BASE_ID), bite(BASE_ID), move(BASE_ID), str(base_ok),
		   "OK" if base_ok else "FAIL",
		   (" (overrides Balance: " + ", ".join(drift) + ")") if not drift.is_empty() else ""])
	ok = ok and base_ok
	for problem in _problems:
		print("[Zombies] warning: " + problem)
		ok = false
	## A sentence the phrase table did not understand is NOT a failure - it only means
	## that mechanic is not simulated. It is printed so nobody has to guess why a
	## zombie "does nothing special".
	for note in _unmatched:
		print("[Zombies] no flag understood for '" + note + "' (shown in the almanac only)")
	## [P47] The other half of the same honesty: a row that names 召唤 in its sentence
	## but did not say WHO / HOW MANY / HOW OFTEN. Printed, not failed - the almanac
	## still calls that row "not simulated", so nothing lies - but the sheet carries a
	## summon sentence the game cannot run, and that must not be a silent gap either.
	for gap in summon_gaps():
		print("[Zombies] summon gap: " + gap)
	## [P48] The same report for the hammer (0 lines today: both 锤击 rows carry their
	## two columns). Kept as a separate line rather than merged into the summon report
	## because the two need different fixes - one wants a partner id, the other a number.
	for gap in smash_gaps():
		print("[Zombies] smash gap: " + gap)
	## [P68] The same report for the rage (0 lines today: the newspaper carries both of
	## its numbers). Three separate reports rather than one, because each wants a
	## different cell filled in and the line says which.
	for gap in rage_gaps():
		print("[Zombies] rage gap: " + gap)
	## [P80] The same claim PlantDB.self_check() makes, for THIS reader's two path rules:
	## "nothing here" has one owner (UnitCsvManager.BLANKS), so a sheet may spell absence as
	## `— - – n/a N/A` in an svg or tscn cell and still mean "no art". Before this, both
	## rules asked the narrower `text == "—"`, which made a `-` cell a FILENAME - and this
	## roster has one row per zombie, so the gap would be lived by every card on screen.
	var blank_ok := true
	for mark in UnitCsvManager.BLANKS:
		blank_ok = blank_ok and svg_path(str(mark)) == "" and scene_path(str(mark)) == ""
	blank_ok = blank_ok and svg_path("q") == SVG_ROOT + "q" + SVG_EXT \
		and scene_path("q") == SCENE_ROOT + "q" + SCENE_SUFFIX
	ok = ok and blank_ok
	print("[Zombies] the five 'nothing here' marks answer 'no art' in both path rules, while a spelled cell still builds a path = %s | %s"
		% [str(blank_ok), "OK" if blank_ok else "FAIL"])
	## [P57] the sheet's own complaints (a spelled cell that is not a number, a header
	## that names one column twice) - see the note in PlantDB.self_check().
	ok = ok and UnitCsvManager.report_complaints("[Zombies]")
	print("[Zombies] self-check %s" % ("PASSED" if ok else "FAILED"))
