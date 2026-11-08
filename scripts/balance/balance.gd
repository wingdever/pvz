class_name Balance
extends RefCounted
## Single source of truth for the numbers that are NOT one scene's own: the board geometry,
## the unit stats and their sheet fall-backs, the art paths, the item definitions, the plant
## cards and the file paths every scene shares.
## [P28-UI] The pure presentation half (pixels, fonts, drawing colours, animation
## timings) moved to BalanceUI - scripts/balance/balance_ui.gd - at the user's request;
## the split rule is "who reads it": only drawing / layout code reads a constant ->
## it belongs to BalanceUI. Nothing in this file reads BalanceUI, so the two
## classes cannot form a dependency cycle.
## [P69] The same rule took the audio vocabulary (tracks, cues, volumes, fades) out
## to BalanceAudio - scripts/balance/balance_audio.gd - since only the two players, the
## screens that name a track and the save file that holds a volume read those names.
## Nothing here reads BalanceAudio either.
## [P108] THE SCENE TABLES. What a single SCENE runs on moved out, one table per scene,
## split by the same "who reads it" rule as [P28-UI] / [P69] (AGENTS §2):
##   scripts/balance/balance_battle.gd   BalanceBattle   economy, the AP engine, ultimates, the wave
##                                               table, the battle tools and the deck keys
##   scripts/balance/balance_garden.gd   BalanceGarden   the garden: save path, pots and pages, care
##                                               ratios, plant states, the four tools
##   scripts/balance/balance_run.gd      BalanceRun      the campaign: chapter / event data paths,
##                                               the run save, the retry fee, the reward pools
##   scripts/balance/balance_shop.gd     BalanceShop     the shop page: the 26 prices + SHOP_STOCK
## Nothing in this file reads any of them - a table and the code that reads it stay together,
## which is why skill_ap_cost() / plant_ult_value() moved to BalanceBattle. What stays here is
## what no single scene owns.
## Rule: no magic numbers anywhere else in the project.

# ---------------------------------------------------------------- geometry
# WINDOW_SIZE is the DESIGN canvas; it must stay in sync with project.godot's
# display/window/size/viewport_width|height.
# project.godot uses stretch mode "canvas_items" with aspect "expand": the engine
# scales the whole 2D world with the window and EXPANDS the logical coordinate
# space along whichever axis the window is proportionally bigger. The logical
# space is therefore never smaller than this box, so every size below stays valid
# as an absolute pixel value at any resolution / window size.
# Only the LAWN is recomputed at runtime (scripts/core/layout.gd); the values
# here are its design basis and the fallback used before Layout boots.
const WINDOW_SIZE := Vector2i(1280, 720)
const CELL_SIZE := 96
const COLS := 9
const ROWS := 5
const LAWN_ORIGIN := Vector2(240.0, 120.0)   # design top-left corner of cell (0,0)
const MVP_ROW := 2                            # [P34] the row the MVP locked the board to
const HUD_TOP_HEIGHT := 100.0
const HUD_BOTTOM_Y := 600.0
const HUD_BOTTOM_HEIGHT := 120.0              # = WINDOW_SIZE.y - HUD_BOTTOM_Y; the bar is pinned to the bottom edge
const MIN_WINDOW_SIZE := Vector2i(640, 400)   # below this the UI would be unreadable

static func all_rows() -> Array[int]:
	## [P34] Every lawn row. A function and not a const array so it can never drift
	## away from ROWS: the multi-row battlefield made the whole lawn live, while a
	## level may still narrow it with its own `rows` (see LevelData.rows) - which is
	## how the existing packs keep the single-row tuning their waves were balanced on.
	var out: Array[int] = []
	for r in ROWS:
		out.append(r)
	return out

# ---------------------------------------------------------------- layout policy
# Everything the responsive layer needs to place the board in whatever space the
# window gives it. All values are design pixels (see layout.gd).
const BOARD_PAD := 10.0              # breathing room between the lawn and the HUD bars
const BOARD_LEFT_CHROME := 160.0     # brain zone (140) + gap (20), kept left of column 0
const BOARD_RIGHT_PAD := 176.0       # keeps the lawn off the right edge
const BRAIN_ZONE_WIDTH := 140.0
const BRAIN_ZONE_GAP := 20.0         # between the brain zone and column 0
const MIN_CELL_SIZE := 32.0          # floor for absurd windows only; the target range never hits it
const LAYOUT_LOG_RESIZE := true      # print one line whenever the window changes the geometry

# ---------------------------------------------------------------- the Z axis [B17]
# docs/prompt/HEIGHT.md §7: the body's own height on the axis. [B37] D113 retired this as the
# FLOOR under the estimate - a body is now exactly as tall as the ink Unit.read_height() measures
# (D112's ruler), because while this held at 1.0 every sprite painted shorter than a cell was
# silently given reach it does not draw. What is left of it is the ORIGINAL meaning: the whole-cell
# guess for a body whose art cannot be measured at all (no file, no import), so a missing picture
# costs the estimate and never makes a unit a zero-thickness sliver nothing can hit. A row that
# states z_thickness still outranks both. World geometry, read by BOTH modes the day classic wires
# the axis; the brawl's own defaults (cruising height, apex, gravity) are BalanceBrawl's, never here.
const UNIT_Z_THICKNESS_CELLS := 1.0
## [B17] THE ART DESIGN BASELINE (D100 revised, spec §6): assets are authored in a 128 px box
## = 1 cell, so a texture's pixel size converts to cells by / this number. It is a FIXED
## ruler - the live BrawlField.cell() stays dynamic and only converts cells to pixels at the
## draw; the two must never be conflated.
const ART_DESIGN_CELL_PX := 128.0

# ---------------------------------------------------------------- shot body ladder [B40]
## THE COMMON MAGNITUDES A LAUNCHED PICTURE IS POURED INTO. A shot's own row may state an exact
## 尺寸 in pixels (data/projectiles.csv, `ProjectileDB.size_of()`), and that stays the precise
## answer - what this ladder adds is the WORD a sheet and a rule can use when the thing being said
## is not "100 px" but "this one is BIG": 暖阳 is a sun the player is meant to notice, 旋风 is a
## front of air that is meant to be stepped out of, and neither claim survives being drawn at the
## same size as a pea. So the ladder is a MULTIPLIER on whatever base the picture already won
## (`Projectile.shot_box()`), never a replacement for it: 尺寸 × 体型 composes, and a row that
## states both gets both.
## WHY HERE: the vocabulary is read by BOTH engines' flights, by the 图鉴 and by one brawl RULE
## (BalanceBrawl's TORNADO_SIZE_TIER), so it is a global word list - the same reason 轨迹 / 外观 are
## closed lists in the sheet's own reader and nothing looser. Sub-tables may name Balance (the legal
## direction, balance_shop.gd's precedent); balance.gd names none of them.
## WHY THESE GAPS: every step is at least a quarter again bigger than the one below, because a tier
## the eye cannot pick out of two frames is a tier that lies about the piece. 标准 is exactly 1.0
## and is what a blank cell means, so adopting the ladder retroactively resized nothing that shipped.
const SIZE_TINY := "微小"
const SIZE_SMALL := "小"
const SIZE_STANDARD := "标准"
const SIZE_LARGE := "大"
const SIZE_GIANT := "巨大"
const SIZE_TIERS: Dictionary = {
	SIZE_TINY: 0.6,
	SIZE_SMALL: 0.8,
	SIZE_STANDARD: 1.0,
	SIZE_LARGE: 1.5,
	SIZE_GIANT: 2.2,
}
const SIZE_WORDS: Array[String] = [SIZE_TINY, SIZE_SMALL, SIZE_STANDARD, SIZE_LARGE, SIZE_GIANT]


static func size_scale(p_cell: String) -> float:
	## The multiplier one 体型 word is worth; 1.0 for a blank cell and for anything the ladder does
	## not know. The sheet's own reader is what REFUSES an unknown word (ProjectileDB's self-check),
	## so falling through to 标准 here is the "never break a picture for a typo" half of that deal,
	## not a second, sloppier list.
	return float(SIZE_TIERS.get(p_cell, 1.0))


static func is_size_tier(p_cell: String) -> bool:
	## Is this a word the ladder has? Blank is legal (it means 标准) and asked separately.
	return SIZE_WORDS.has(p_cell)


# ---------------------------------------------------------------- colours
# [P28-UI] Only the UNIT palette stays here: PLANT_DEFS below and the unit scripts' body
# colours read this palette (the three TOOL colours went to BalanceBattle with the tools,
# [P108]). Every other drawing colour, the lawn greens, the text and the bars moved to
# BalanceUI.
# [P34] The batch-1 plants join the palette: a placeholder body colour is what shows
# when a sprite cannot be loaded, so every summonable plant needs its own - the
# family tints stay readable apart at a glance (three greens of the pea family, two
# purples of the shroom family).
const COLOR_PEASHOOTER := Color(0.25, 0.75, 0.30)
const COLOR_SUNFLOWER := Color(0.95, 0.80, 0.20)
const COLOR_WALLNUT := Color(0.65, 0.45, 0.25)
const COLOR_ZOMBIE := Color(0.55, 0.52, 0.68)
const COLOR_REPEATER := Color(0.16, 0.62, 0.28)
const COLOR_SPLIT_PEA := Color(0.35, 0.72, 0.42)
const COLOR_GATLING_PEA := Color(0.10, 0.48, 0.26)
const COLOR_THREEPEATER := Color(0.42, 0.78, 0.34)
const COLOR_SNOW_PEA := Color(0.45, 0.78, 1.00)
const COLOR_TWIN_SUNFLOWER := Color(0.98, 0.68, 0.16)
const COLOR_TALLNUT := Color(0.52, 0.34, 0.18)
const COLOR_PUFF_SHROOM := Color(0.66, 0.66, 0.82)
const COLOR_FUME_SHROOM := Color(0.50, 0.36, 0.70)
## [P58] 忧郁菇's body: the deep violet its own head art is drawn in
## (assets/svg/units/plants/mushroom/gloom_shroom.svg, #5A2A7A), one step darker than
## the fume-shroom's - the shroom line gets dearer and bleaker as it grows.
const COLOR_GLOOM_SHROOM := Color(0.35, 0.16, 0.48)
## [P59] 胆小菇's body: the violet its own head art is drawn in
## (assets/svg/units/plants/mushroom/scaredy_shroom.svg, #6A3A8A) - the shroom line's
## palest purple, which is the right reading for a mushroom that hides when anything
## gets close.
const COLOR_SCAREDY_SHROOM := Color(0.42, 0.23, 0.54)
## [P39] The placeholder body of the swallower: the purple-green of its own head art
## (assets/svg/units/plants/chomper.svg), dark enough to read as a mouth.
const COLOR_CHOMPER := Color(0.46, 0.30, 0.55)
## [P39] The two plants that spend themselves. These bodies are only what the card and
## the placeholder shape wear while the art is missing (both have their own svg), so the
## rule is the same as everywhere else here: the plant's own colour, readable at 60 px.
const COLOR_SQUASH := Color(0.55, 0.62, 0.22)
const COLOR_JALAPENO := Color(0.78, 0.20, 0.16)
## [P39] The family's other two, same rule (a body only the card and the placeholder
## shape wear, since both own an svg): potato brown, cherry red-black.
const COLOR_POTATO_MINE := Color(0.60, 0.45, 0.25)
const COLOR_CHERRY_BOMB := Color(0.66, 0.10, 0.14)
## [P43] 寒冰菇: the shroom family's violet-blue pulled toward the frost family's cyan,
## so the card reads as "a mushroom that does what the snow pea does" at a glance. Same
## rule as the rest of its family - only the card and the placeholder body wear it, the
## svg (assets/svg/units/plants/mushroom/ice_shroom) is what shows on the lawn.
const COLOR_ICE_SHROOM := Color(0.58, 0.70, 0.95)
## [P49] The two 投手. Their own sprites exist (assets/svg/units/plants/pult/), so these
## are what the CARD and the placeholder body wear: the melon its rind, the icy melon the
## same shape pulled to the frost family's blue - the pair reads as "one plant, two shots"
## on the rail, which is what they are.
## [P51] The 投手 family's card greens, darkest for the melon that costs 300 and palest for
## the cabbage that costs 100. What the THROWN BODY looks like is a drawing question and
## lives in BalanceUI ( COLOR_MELON / COLOR_CABBAGE); these three are the card's face.
const COLOR_CABBAGE_PULT := Color(0.42, 0.66, 0.40)
const COLOR_MELON_PULT := Color(0.30, 0.52, 0.24)
const COLOR_WINTER_MELON := Color(0.42, 0.66, 0.80)
## [P63] 地刺's body: the straw-gold its own art is drawn with
## (assets/svg/units/plants/spikeweed.svg - #D4B870 spikes over an #A88A4A mound), which is
## the value converted rather than a new one invented. It is the palest card on the rail
## since the two sunflowers, and deliberately not a green: a mat of old thorns is the one
## plant here that is not a head on a stem.
const COLOR_SPIKEWEED := Color(0.83, 0.72, 0.44)

# ---------------------------------------------------------------- economy
# [P108] MOVED to BalanceBattle: START_SUN / SUN_PER_TURN / SUN_MAX / SUN_DROP_MAX /
# SUN_AUTO_ROUNDS_DEFAULT / SUN_AUTO_ROUNDS_CHOICES / BRAIN_MAX_HP. A round's income is the
# battle's own rule; only the settings page reads the auto-collect default back.

# ---------------------------------------------------------------- action points / ultimates (P30-A/B)
# [P108] MOVED to BalanceBattle: the whole AP engine (ACTION_STEP_TIME, ROUND_AP, every
# ZOMBIE_*_COST, BITE_DAMAGE_RATIO, the SKILL_AP_COST fall-back table), the ultimate bar
# (ULT_CHARGE_PER_CAST / ULT_CHARGE_MAX / ULTIMATE_VALUE) and the two look-ups that read
# those tables, skill_ap_cost() and plant_ult_value().

# ---------------------------------------------------------------- unit stats
# [P26] Every number in this block is now a FALL-BACK: the plant and zombie sheets
# (data/units/plants.csv / zombies.csv) own hp / cost / damage / bite / move, and these
# constants are what the game uses when a sheet cannot be read at all (and what the
# self-checks print when the sheet disagrees with them).
# [P29] The sheets are LAYERED now (UnitSheet): HP and the prose/art columns moved to
# the shared data/units/units.csv, the race sheets kept what only they have (plants'
# cost/cooldown/growth, zombies' armor/move/bite/brain); a sub-race sheet (pea.csv ...)
# would override both and is skipped while absent.
# [P30-A] The plants' AP price moved OUT of this block and into the skill sheet
# (data/units/skills.csv, read by SkillDB, fall-back table BalanceBattle.SKILL_AP_COST).
# The zombie costs stay pure code: 移动/啃食/啃脑伤害 are the bars and damage values
# the sheet owns, the PRICES are one global rule.
const PEASHOOTER_HP := 300
const PEASHOOTER_COST := 100
## [P80] D4 deleted PEASHOOTER_DAMAGE from this block. Its own note said "superseded by the
## sheet's attack", which is a claim about a fall-back that no longer has a caller - grep found
## the constant at its definition line and nowhere else. The two above DO still answer: the
## PLANT_DEFS entries for peashooter and its spirit copy spell cost/hp from them, and
## plant_attr_hp() takes PEASHOOTER_HP as the default when a row has no 生命上限.

const SUNFLOWER_HP := 300
const SUNFLOWER_COST := 50
const SUNFLOWER_SUN := 25              # fall-back for the sheet's attack once it is missing

const WALLNUT_HP := 1000
const WALLNUT_COST := 50

const ZOMBIE_HP := 270
const ZOMBIE_ADVANCE_THRESHOLD := 3    # fall-back for the sheet's 移动 (move progress bar length)
const ZOMBIE_BITE_DAMAGE := 100
const ZOMBIE_BRAIN_DAMAGE := 10        # fall-back for the sheet's 啃脑伤害
## [P80] D4 deleted ZOMBIE_SPAWN_COL (was 6) from this block. It had no reader, and it was
## never a per-zombie number anyway: the entry column is a grid rule, and the live one is
## the roll-call list in BalanceBattle.ZOMBIE_SPAWN_COLS, whose first element already IS 6. A second
## spelling of the same column, in the block that promises "these are the base zombie's
## fall-backs", was a lie with two halves - nobody read it, and what it duplicated had a
## different owner.
## [P26] The zombie numbers above are the fall-back for the BASE zombie ("zombie" in
## data/units/zombies.csv). ZombieDB owns them from now on; ZombieDB.self_check()
## reports when the sheet disagrees (that is the intended direction of truth, so a
## difference is printed as "overrides Balance" rather than failed).

# [P28-UI] The armour STRIP (colours, UNIT_ARMOR_BAR_Y / _HEIGHT) and the whole
# "unit visuals" block (body size, name / hp bar / action bar geometry, UNIT_ART_SIZE,
# the idle animation numbers) are drawing quantities and live in BalanceUI now.
# What stays about armour is the gameplay itself: the sheet's 护甲 column and
# ZombieDB.armor.

# ---------------------------------------------------------------- unit art (P11)
# Placeholder art v2: SVG sprites in assets/svg/units/{plants,zombies}/, imported by
# Godot as textures and drawn into a square box centred on the cell centre.
# UnitArt loads them defensively: a missing or not-yet-imported SVG falls back to
# the flat shape drawn by Unit._draw_body(), so art can never break the game.
# The palette lives INSIDE each SVG (SVG cannot read these constants) - when you
# re-colour a sprite, change Balance.COLOR_* and the SVG together.
const ART_PLANT := "res://assets/svg/units/plants/plant.svg"
const ART_ZOMBIE := "res://assets/svg/units/zombies/zombie.svg"

# ---------------------------------------------------------------- unit VIEW scenes (P28)
## [P70] The three numbers that PLACE a view on the lawn (VIEW_ART_CANVAS,
## VIEW_ART_FEET_LINE, VIEW_IDLE_ANIMATION and the rules they encode) are drawing
## quantities and live in BalanceUI now - UnitArt is their only reader. What stays here is
## the data question: WHICH picture a unit draws, in one order, tried top to bottom
## (Unit._load_view / _draw_body):
##   1. tscn  the scene the SHEET registers, i.e. the `tscn` column of
##            data/units/plants.csv / zombies.csv (PlantDB.view / ZombieDB.view)
##   2. svg   the sprite the same sheet registers (PlantDB.art / ZombieDB.art)
##   3. flat  the placeholder shape Unit._draw_body() paints itself
## Each step is a graceful fall-back, so an empty cell, a scene nobody has built yet or a
## sprite nobody has drawn costs the step below it and never breaks the game.

static func plant_view(plant_id: String) -> String:
	## [P28] The scene the BOARD draws for this plant: the tscn cell of its row in
	## data/units/plants.csv ("peashooter" ->
	## res://scenes/units/plants/peashooter_view.tscn, see PlantDB.scene_path()).
	## "" means "this plant has no view scene" - the cell is empty, or it names a scene
	## nobody has built yet - and the plant then draws its sprite (plant_art) and, with
	## no sprite either, the flat placeholder shape.
	##
	## The SHEET is the only source, exactly like the svg column: clearing that cell is
	## how a designer puts a plant back on its sprite, so there is deliberately no code
	## table to override the sheet here.
	if PlantDB.has(plant_id):
		return PlantDB.view(plant_id)
	return ""

static func unit_name(p_unit_id: String) -> String:
	## [B2c] ONE DOOR FOR "what is this unit called", whichever roster owns the id. The almanac
	## asks the plant sheet and the zombie sheet separately because it has a TAB for each; a page
	## that fields BOTH - the brawl's formation page puts a piece roster against zombie
	## formations - cannot afford to guess which one to ask. Zombies first, then [B5] the human
	## pieces, then plants: the order the unit factory uses (Spawn.create_unit).
	if ZombieDB.has(p_unit_id):
		return ZombieDB.name(p_unit_id)
	if PieceDB.has(p_unit_id):
		return PieceDB.name(p_unit_id)
	return plant_name(p_unit_id)


static func unit_art(p_unit_id: String) -> String:
	## The sprite half of the same question, and the one that was actually WRONG: plant_art() on
	## a zombie id finds no row in the plant sheet and answers its bare-plant fall-back
	## (ART_PLANT), so a board that asked the wrong roster drew every enemy zombie as a plant.
	if ZombieDB.has(p_unit_id):
		return ZombieDB.art(p_unit_id)
	## [B5] ...and the same order as unit_name() above. A human id asked of the plant table
	## would answer the bare-plant fall-back, which is the "wrong roster" bug this pair of
	## doors exists to stop - a human piece drawn as a peashooter.
	if PieceDB.has(p_unit_id):
		return PieceDB.art(p_unit_id)
	return plant_art(p_unit_id)


static func zombie_view(zombie_id: String) -> String:
	## The same question for a zombie TYPE, out of the tscn cell of its row in
	## data/units/zombies.csv ("zombie_cone" ->
	## res://scenes/units/zombies/zombie_cone_view.tscn). No zombie view scene exists yet:
	## the column is the hook for the day one is drawn, and until then every type draws
	## its sprite as before.
	if ZombieDB.has(zombie_id):
		return ZombieDB.view(zombie_id)
	return ""

# ---------------------------------------------------------------- roster art (P26/P28)
# [P28] THE SHEETS ARE WHERE A UNIT'S SPRITE IS REGISTERED NOW: [P29] the shared
# data/units/units.csv carries the svg column (a path relative to
# res://assets/svg/units/{plants,zombies}/, without the extension - the race's first
# segment picks the folder), and PlantDB.art() /
# ZombieDB.art() turn it into the path the game draws. Giving a plant or a zombie type a
# picture is therefore one cell in the sheet - the board, the plant cards, the garden,
# the almanac and the potion marks all follow, because they all read those two functions.
#
# The two tables below are the CODE's own answer to the same question: they stand in for
# a sheet that cannot be read, and they are the list of id -> path pairs the code itself
# names (UnitArt's self-check requires those files to resolve). An id with no row in
# either place keeps a graceful fall-back: plants draw the flat shape (Unit._draw_body),
# zombies draw the base zombie's sprite.
#
# NOT listed on purpose: plants/pea/gatling_helmet.svg and plants/pea/pea_leaf.svg.
# Those two are the FUSION ITEM pictures (scaled to fill an item canvas, see their own
# headers), not unit sprites - they belong to the fusion mechanic, which has no items
# yet. Wire them here only if they are ever drawn as a UNIT.

# ---------------------------------------------------------------- item icons (P18)
# One SVG per item kind so the battle HUD, the backpack panel, the warehouse and
# the shop can all show the same picture. Same import rules as the unit sprites:
# 128x128 canvas, pure fills, colours written inside the file (see each file head).
const ART_ICON_SILVER := "res://assets/svg/items/coin_silver.svg"
const ART_ICON_GOLD := "res://assets/svg/items/coin_gold.svg"
const ART_ICON_DIAMOND := "res://assets/svg/items/coin_diamond.svg"
const ART_ICON_SUN := "res://assets/svg/other/sun.svg"
const ART_ICON_FERTILIZER := "res://assets/svg/items/fertilizer.svg"
const ART_ICON_EXP_POTION := "res://assets/svg/items/exp_potion.svg"
const ART_ICON_BEAN := "res://assets/svg/items/energy_bean.svg"
const ART_ICON_SCROLL := "res://assets/svg/items/scroll.svg"

# ---------------------------------------------------------------- talent potion art (P23)
# A talent potion is no longer one hand-drawn bottle per plant: its picture is
# COMPOSED out of two pieces (assets/svg/items/potion/readme.md):
#   bottle  the GENERIC bottle of the potion's tier. Only the LIQUID COLOUR tells
#           tiers apart, and a generic bottle carries no plant mark at all.
#   mark    the matching plant's own unit sprite, scaled into the blank top area
#           of that bottle (BalanceUI.POTION_MARK_AREA) - drawn by ItemTile.
# A new plant therefore needs no new bottle: give its potion row in ITEM_DEFS a
# "plant" and a "tier". The three potions that exist today are all tier I
# ("common"), so they share one grey bottle and differ only by the mark on it.
# The old per-plant bottles (potion_peashooter / _sunflower / _wallnut.svg) are
# deliberately still on disk for reference, but nothing loads them any more.
const ART_POTION_TALENT_COMMON := "res://assets/svg/items/potion/potion_talent_common.svg"
const ART_POTION_TALENT_UNCOMMON := "res://assets/svg/items/potion/potion_talent_uncommon.svg"
const ART_POTION_TALENT_RARE := "res://assets/svg/items/potion/potion_talent_rare.svg"
const ART_POTION_TALENT_EPIC := "res://assets/svg/items/potion/potion_talent_epic.svg"
const ART_POTION_TALENT_LEGENDARY := "res://assets/svg/items/potion/potion_talent_legendary.svg"
const ART_POTION_TALENT_MYTHIC := "res://assets/svg/items/potion/potion_talent_mythic.svg"

## tier name -> generic bottle. The keys are the readme's tier names (I..VI), which
## are NOT Balance.RARITY_* - a potion's tier and a plant's rarity are two separate
## scales that only happen to share their low end.
const POTION_TIER_PATHS := {
	"common": ART_POTION_TALENT_COMMON,
	"uncommon": ART_POTION_TALENT_UNCOMMON,
	"rare": ART_POTION_TALENT_RARE,
	"epic": ART_POTION_TALENT_EPIC,
	"legendary": ART_POTION_TALENT_LEGENDARY,
	"mythic": ART_POTION_TALENT_MYTHIC,
}
## [P70] The mark GEOMETRY of this two-layer picture (POTION_ART_CANVAS,
## POTION_MARK_AREA, POTION_MARK_SCALE) is gone to BalanceUI: which bottle an item shows
## is a data answer that the item DB and `potion_bottle_art()` below both need, while
## where the mark lands is read by UnitArt and nobody else.

## item id -> icon path, for every item whose icon is a single file. Read through
## Balance.item_art(); a talent potion is NOT listed here, because its picture is
## the generic bottle of its tier (POTION_TIER_PATHS) plus a plant mark.
## [P34] The batch-1 items are deliberately NOT added: ItemDB.art() asks the sheet's
## own svg column FIRST and this table only when the row registered nothing, and every
## data/items.csv row spells its svg (items/scroll, items/potion/...). A second copy of
## the same path here could only ever drift away from the sheet.
const ITEM_ART := {
	"coin_silver": ART_ICON_SILVER,
	"coin_gold": ART_ICON_GOLD,
	"coin_diamond": ART_ICON_DIAMOND,
	"fertilizer": ART_ICON_FERTILIZER,
	"exp_potion": ART_ICON_EXP_POTION,
	"energy_bean": ART_ICON_BEAN,
	"scroll_peashooter": ART_ICON_SCROLL,
	"scroll_sunflower": ART_ICON_SCROLL,
	"scroll_wallnut": ART_ICON_SCROLL,
	"scroll_spirit_peashooter": ART_ICON_SCROLL,
}

# [P28-UI] The icon DRAWING sizes (ICON_HUD_SIZE and the gaps) are
# presentation and live in BalanceUI; the paths and tier tables above stay, because
# item_art() resolves them from ITEM_DEFS.

static func potion_bottle_art(p_tier: String) -> String:
	## [P23/P24] The generic bottle of one tier. An empty or unknown tier falls back
	## to tier I, which is what every potion in the game is today (ITEM_DEFS "tier").
	## The garden's talent tool shows this bottle on its own (no plant mark) as long
	## as no plant is selected.
	return str(POTION_TIER_PATHS.get(p_tier, ART_POTION_TALENT_COMMON))

static func item_art(item_id: String) -> String:
	## [P23/P88/P92] SHEET FIRST, like every other item accessor since P88 (the sheet is the
	## one authority on what an item is): the row's own svg cell wins, and the code tables
	## are the fall-back for a sheet that cannot be read. That is also what makes the
	## composite icon work for a row the code never listed - the shared scroll lives in the
	## sheet, so 双发射手花园卷轴 has a picture without an ITEM_ART entry.
	## Behind the sheet: a talent potion resolves through its TIER (the generic bottle),
	## everything else through ITEM_ART.
	if ItemDB.has(item_id):
		var cell := ItemDB.svg_rel(item_id)
		if cell != "":
			return ItemDB.svg_path(cell)
	var tier := item_tier(item_id)
	if tier != "":
		return potion_bottle_art(tier)
	return str(ITEM_ART.get(item_id, ""))

static func item_tier(item_id: String) -> String:
	## [P23] The talent tier ("common" .. "mythic") of an item, "" for everything
	## that is not a talent potion. ITEM_DEFS owns the tier; the bottle follows.
	var def: Dictionary = ITEM_DEFS.get(item_id, {})
	return str(def.get("tier", ""))

static func item_mark_art(item_id: String) -> String:
	## [P23/P92] The plant mark laid over an item's picture: the plant's OWN unit sprite.
	## Two kinds carry one - a TALENT POTION (the plant it strengthens, over the generic
	## bottle of its tier) and, since P92, a SUMMON SCROLL (the plant it unlocks, over the
	## one shared scroll). "" for every ordinary one-file icon, so a caller can hand the
	## result to UnitArt.load_texture() without asking what kind of item it holds; WHERE the
	## mark lands is the kind's business (BalanceUI.mark_geometry).
	var kind := item_kind(item_id)
	if kind != "talent" and kind != "scroll" and kind != ITEM_KIND_PLANT_CHEST:
		return ""
	return plant_art(item_plant(item_id))

static func item_art_paths() -> Array:
	## Every file an item icon can come from - the plain icons AND all six tier
	## bottles, since one of those is what a talent potion actually shows.
	var out: Array = []
	for key in ITEM_ART.keys():
		var path := str(ITEM_ART[key])
		if not out.has(path):
			out.append(path)
	for key in POTION_TIER_PATHS.keys():
		var path := str(POTION_TIER_PATHS[key])
		if not out.has(path):
			out.append(path)
	return out

# [P28-UI] UNIT_ART_SIZE / UNIT_ART_LINEAR_FILTER and the IDLE_* breathing numbers
# moved to BalanceUI with the rest of the drawing quantities.

# ---------------------------------------------------------------- turn engine
# [P108] MOVED to BalanceBattle: FAST_FORWARD_ROUNDS / DEBUG_SUN_AMOUNT / MESSAGE_DURATION /
# WAVE_TABLE / ZOMBIE_SPAWN_COLS / PEASHOOTER_SHOOTS_BACKWARD.

# ---------------------------------------------------------------- splashing shots (P49)
## [P49] What a lobbed melon leaves on the four cells around where it lands, as a
## fraction of its OWN damage: 对其上下左右各造成一半伤害. One number for the whole
## family rather than one per plant, because the sheet's sentences say the same half
## for 西瓜投手 and for the second wave of both 大招 - and because a ratio, unlike a flat
## amount, still means "half" after the plant has been dosed with its talent potion.
## The plant's own attack stays the only damage number on its row: splash is a SHARE of it,
## so it scales with growth and with the potion without either being written twice.
const PULT_SPLASH_RATIO := 0.5

# ---------------------------------------------------------------- same-cell stacking
# That several bodies may share one tile (original PvZ behaviour) is battle code, not a
# number here. [P71] The two numbers that STAGGER them - STACK_OFFSET_STEP and
# STACK_OFFSET_MAX_INDEX - only feed Unit.position (where a body is PAINTED); every rule
# reads the cell, never the pixels. They live in BalanceUI, Unit.stack_offset() is their
# only reader.

# ---------------------------------------------------------------- rarity (P14, sheet-backed P105)
# A plant instance has a rarity and a level; together they decide how long a
# DOWNED plant needs to come back on its own (see recovery_seconds() below) - and the
# rarity is also the colour the garden paints that plant's NAME with.
#
# [P105] WHERE EACH HALF LIVES NOW (user rule: 在 units.csv 增加 rarity 字段，再增加 rarity.csv
# 声明rarity与色彩的对应关系):
#   data/units/units.csv  `rarity`  the TIER of one unit - the only place it is written
#   data/rarity.csv       one row per tier: its 颜色 and its 恢复倍率
#                         (scripts/core/rarity_db.gd reads it; the accessors below are its
#                         only readers in the game)
# The six names below stay in code because they are the VOCABULARY the code speaks
# (PLANT_DEFS' fall-back rows, the garden's save-file guard, RARITY_ORDER) - not a second
# copy of any number. What a tier is WORTH is not here any more: RARITY_RECOVERY, which was a
# second copy of rarity.csv's 恢复倍率 column, was deleted with this batch.
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"
const RARITY_MYTHIC := "mythic"
## The ladder, weakest first - ONE list, answering two questions: the order the almanac or a
## filter reads, and "is this a tier the game knows" when rarity.csv cannot be read (see
## has_rarity). A seventh tier is a row in the sheet AND a name here, which is why the
## [Rarity] self-check reads this list against the sheet's own rows.
const RARITY_ORDER: Array[String] = [RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE,
	RARITY_EPIC, RARITY_LEGENDARY, RARITY_MYTHIC]
## What a tier NOTHING can name is painted with: an unknown tier, or every tier on a run where
## rarity.csv could not be read. Deliberately ONE neutral colour and not a hand-copied ladder -
## the sheet owns the colours (AGENTS §2, one owner per number).
const COLOR_RARITY_NONE := Color(0.85, 0.86, 0.88)
## The tier table itself. Declared here (this file has no other preload) so that the accessors
## below are the only readers of data/rarity.csv - the same "one reader, one loader" shape the
## other sheet tables use.
const RarityDB := preload("res://scripts/core/db/rarity_db.gd")
const RECOVERY_BASE_SECONDS := 60.0     # a common level 1 plant: the 60 s baseline
const RECOVERY_LEVEL_STEP := 0.3        # +30% recovery time per level above 1
const NATURAL_RECOVERY_HP_RATIO := 0.1  # natural recovery leaves 1/10 of max hp
## [P71] How often the garden PAGE repaints those countdowns (GARDEN_TICK) is a paint
## throttle, not a clock, and only GardenView._process reads it - so it lives in BalanceUI.
## The three numbers above stay: they decide WHEN a pot stands up, this one only how often
## the label catches up with that answer.

# ---------------------------------------------------------------- the damage formula [B11]
## WHAT A HIT ACTUALLY TAKES OFF, and the one place the 防御 column is read as a RULE.
##
## THE SPEC (user, 2026-10-05, second pass):
##
##     hurt = attack * 128 / (128 + max(0, defence))
##
## attack is the ATTACKER's number and defence the DEFENDER's, both straight off the sheets
## (units.csv attack / defence). The new shape (B11c) replaced a ratio of (1+A)/(1+D): that one
## was unusable, because a base defence of 20 - which is what the sheets now carry - would have
## cut every blow to a third. This one is a PERCENTAGE-LIKE reduction with a defined scale.
##
## THE THREE THINGS THE FORMULA SAYS, in words:
##   * DEFENCE_SCALE is the defence at which a blow is HALVED (128). Half of 128 is 64 (75%),
##     a quarter is 32 (89%), and the base 20 takes 13.5% off - so 防御 is a smooth dial, not a
##     cliff. `defence = 128` is the number to reach for when a unit should take half damage.
##   * the clamp is at 0 FROM BELOW (max(0, defence)). It stops a NEGATIVE defence (an armour
##     break, a future debuff) from making the denominator smaller than the numerator's scale.
##   * the result is rounded to a whole number and is never 0: a hit that lands always takes at
##     least one point off, so "how hard does this hit" can never answer "nothing".
##
## DEFENCE 0 IS NO DEFENCE: the factor is 128/128 = 1, so a body with no defence takes exactly
## its attacker's attack - unchanged from before this feature existed, which is what makes the
## column an addition to the game instead of a rebalance of it.
##
## WHO RUNS IT: Unit.take_damage(), the one door every hit in the game already walks through -
## a pea in the campaign, a chomp, a brawl swing, an arrow, a beam tick, a digestion tick. That
## is what keeps this the ONLY damage formula (docs/NUMBERS.md §3, BRAWL.md §8.7.2 for the
## brawl's own half of the story).
##
## THE BASE THE SHEETS CARRY (user rule, 2026-10-05): 生命 100 / attack 20 / 防御 20, with 盾卫
## stating 防御 50 of its own. 20 against the 128 scale is a 13.5% cut and 50 is 28%, so the
## shieldman's wall reads as a wall without a second damage table.
const DEFENCE_BASE := 32
const DEFENCE_SCALE := 16

static func hurt_after_defence(p_attack: int, p_defence: int) -> int:
	return int(round(float(p_attack) * float(DEFENCE_BASE)
		/ float(DEFENCE_SCALE + maxi(0, p_defence))))


# ---------------------------------------------------------------- power estimate [B24]
## THE ONE PLACE "how strong is this body, as a single number" is answered. The user's formula
## (2026-10-07, then divided down on 2026-10-08):
##
##     power = HP * attack * (DEFENCE_SCALE + defence) / POWER_SCALE
##
## Four things worth stating before the numbers get argued about:
##   * it is an ORDINAL, not a damage prediction. It multiplies the three things a body is made
##     of, so a unit that is twice as tough AND hits twice as hard reads as four times the
##     power, while two such units standing together read as eight. Nothing in the fight uses
##     it; it exists so a page (and a designer) can put two rosters side by side.
##   * the 16 is NOT a fourth balance constant. It is DEFENCE_SCALE - the very scale the damage
##     formula spends defence on - so the estimate measures defence in the same units the fight
##     does, and the two cannot drift apart when that scale changes. Change DEFENCE_SCALE above
##     and every power figure on every page moves with it, which is the whole point.
##   * POWER_SCALE is only a READING SCALING: the raw product of three sheet cells is six digits
##     (286,720 for a militia), which is a number nobody wants to compare by eye. Divided by 1024
##     the same roster reads in the hundreds. It changes no ordering and no ratio, which is why
##     it is the last operation and not a fourth input.
##   * it reads the SAME merged cells the almanac panel prints (units.csv HP / attack / defence,
##     a blank answered by the race's default row). So the number is always checkable: multiply
##     the three lines on the screen, divide by 1024, and you get the fourth.
##
## THE DIVISION IS AN INTEGER ONE, so the fraction is dropped rather than rounded - "keep the
## whole number" (the user's 保留整数部分) - and a weak unit can therefore read 0. That is the
## estimate saying "this body is a rounding error at this scale", which is true and printable;
## no floor of 1 is applied, because a floor would be a claim the formula does not make.
const POWER_SCALE := 1024

static func estimate_power(p_hp: int, p_attack: int, p_defence: int) -> int:
	return maxi(0, p_hp) * maxi(0, p_attack) * (DEFENCE_SCALE + maxi(0, p_defence)) / POWER_SCALE


static func unit_power(p_unit_id: String) -> int:
	## The estimate for ONE unit, whichever roster owns the id: the three cells are SHARED
	## columns of data/units/units.csv, so UnitSheet answers for plants, zombies, humans,
	## monsters and machines alike and there is no three-facade dispatch to keep in step
	## (the shape UnitSheet.defence() set). An id no sheet knows has no HP and no attack, so
	## it estimates 0 - a page that shows a stranger shows a 0, and nothing else.
	var flat := UnitSheet.live().get_flat(p_unit_id)
	return estimate_power(
		UnitCsvManager.int_cell(flat, [UnitSheet.COL_HP], 0),
		UnitCsvManager.int_cell(flat, [UnitSheet.COL_ATTACK], 0),
		UnitSheet.defence(p_unit_id))


# ---------------------------------------------------------------- plant attributes (P15, sheet-backed since P26)
# ONE plant's numbers, and where each of them lives. plant_attrs() is the single place
# they are merged, and the SHEETS are the source of truth - this file keeps only what a
# sheet cannot carry or what has to survive a sheet that cannot be read:
#
#   sheet  HP      -> hp           base health at level 1     (fall-back: PLANT_DEFS)
#   sheet  attack     -> skill_base   pea damage / sun per PRODUCE; an EMPTY cell is a
#                                  real VALUE ("no numeric skill") and means 0
#   sheet  费用     -> cost         the sun a summon spends (see plant_cost)
#   sheet  卡片冷却  -> cooldown     rounds until the card is ready again
#   sheet  HP成长   -> hp_growth    per level above 1 (fall-back: PLANT_HP_GROWTH)
#   sheet  技能成长  -> skill_growth (fall-back: PLANT_SKILL_GROWTH)
#   sheet  天赋加成  -> potion_boost (fall-back: PLANT_TALENT_BOOST)
#   [B11] units.csv defence -> defence       the BASE a defence growth multiplies; it is a
#         SHARED column (every faction has a body), which is why it is not read here
#   [B11] sheet 防御成长  -> defence_growth (fall-back: PLANT_DEFENCE_GROWTH)
#   items.csv 分类=talent + 对应植物 -> WHICH potion doses this plant (plant_potion_item)
#   the plant's own skill number  -> which NUMBER the dose lifts (hp if it has none)
#   this file's PLANT_DEFS        -> colour, rarity, art + the fall-back numbers
# [P100] PLANT_ATTRS LIVED HERE - 24 hand-written rows of hp / growth / skill / potion
# cells, of which only the potion ones were ever exclusive to it. Every cell has an owner
# somewhere better now:
#   hp / skill_base / cost / cooldown -> the sheets (PLANT_DEFS keeps the fall-back)
#   hp_growth / skill_growth          -> plants.csv HP成长 / 技能成长 (PLANT_*_GROWTH)
#   potion_boost                      -> plants.csv 天赋加成 (PLANT_TALENT_BOOST)
#   which potion a plant has          -> items.csv 对应植物 (plant_potion_item())
#   which number a potion lifts       -> derived from the plant's own skill number
#   skill (the FIRE / PRODUCE label)  -> deleted: nothing has read it since plant_skill_name()
# The table was deleted after a claim proved the derived values equal the written ones for
# every card (0 drift); the reason it had to go is the bug class it created - a code table
# that must be kept in step with a sheet by hand, which is how spirit_ice_shroom once
# inherited 100x the health of the plant it copies.

# ---------------------------------------------------------------- experience (P15)
const ZOMBIE_EXP := 10                  # exp for the plant that lands the killing blow
const EXP_POTION_AMOUNT := 50           # exp a bought potion grants
const EXP_PER_LEVEL := 100              # xp to leave level L = EXP_PER_LEVEL x L (P15's 100 x level)

static func plant_attrs(plant_id: String) -> Dictionary:
	## [P26] ONE plant's attributes: every NUMBER comes from the sheets (data/units/*.csv
	## through PlantDB) and this file's constants + PLANT_DEFS are the fall-back for a sheet
	## that could not be read. This is the single place the merge happens, so "the sheet
	## wins" is written down once instead of in every accessor.
	##
	## An EMPTY attack cell is a VALUE, not a missing one: it says "this plant has no
	## numeric skill" (a wall-nut, a one-shot plant), so it overrides the fall-back with 0.
	## Only an id the sheet does not have keeps the fall-back value.
	## [P95] A spirit copy is the base plant with a different summon path: its numbers come
	## from the base's row (there is no "spirit coefficient" yet - when there is, it is one
	## formula here rather than 24 rows to keep in step).
	## [P100] `potion` is NOT in this dictionary any more: WHICH item doses a plant is the
	## item sheet's business (plant_potion_item()), and WHICH NUMBER the dose lifts is
	## derived from the plant's own skill number - those two used to be ~19 hand-written
	## cells per table (see PLANT_ATTRS' obituary at the head of this section).
	var attr_key := plant_id
	var spirit := spirit_base(plant_id)
	if spirit != "":
		attr_key = spirit
	var def: Dictionary = PLANT_DEFS.get(attr_key, {})
	var code := {
		"hp": maxi(1, int(def.get("hp", PEASHOOTER_HP))),
		"skill_base": maxi(0, int(def.get("skill_base", 0))),
		"cost": maxi(0, int(def.get("cost", 0))),
		"cooldown": maxi(1, int(def.get("cooldown", 1))),
		"hp_growth": PLANT_HP_GROWTH,
		"skill_growth": PLANT_SKILL_GROWTH,
		"potion_boost": PLANT_TALENT_BOOST,
		## [B11] The third dimension. Zero until the sheet says otherwise, and 0 GROWS INTO 0
		## (see plant_attr_defence) - so this key costs nothing on the 24 rows that ignore it.
		"defence": 0,
		"defence_growth": PLANT_DEFENCE_GROWTH,
	}
	## [P95] The sheet branch asks about ATTR_KEY, not about the id handed in: a spirit copy
	## has no row of its own, and testing the raw id would send it down the fall-back path
	## while its base went through the sheet - for a one-shot like the ice-shroom (empty
	## 生命 cell = a real 0) the copy would then inherit PEASHOOTER_HP and be 100x too tough.
	if PlantDB.has(attr_key):
		## An EMPTY 生命 cell is a VALUE too: it says "this plant has no health of its
		## own" (the one-shot family), so a sheet row never inherits the fall-back hp.
		## plant_attr_hp() still floors it at 1, so a hypothetical unit cannot deploy
		## with 0 hp.
		code["hp"] = PlantDB.hp(attr_key)
		code["skill_base"] = PlantDB.attack(attr_key)
		code["cost"] = PlantDB.cost(attr_key)
		code["cooldown"] = PlantDB.cooldown(attr_key)
		code["defence"] = UnitSheet.defence(attr_key)
		## The optional growth cells: only the ones the sheet filled in arrive here, so a
		## "—" leaves this table's own value in charge (0.0 would mean "never grows").
		var sheet_rates := PlantDB.get_rates(attr_key)
		if sheet_rates.has("hp_growth"):
			code["hp_growth"] = float(sheet_rates["hp_growth"])
		if sheet_rates.has("skill_growth"):
			code["skill_growth"] = float(sheet_rates["skill_growth"])
		if sheet_rates.has("talent_boost"):
			code["potion_boost"] = float(sheet_rates["talent_boost"])
		if sheet_rates.has("defence_growth"):
			code["defence_growth"] = float(sheet_rates["defence_growth"])
	## [P100] Which number a dosed talent lifts: a plant with a skill number of its own gets a
	## SKILL potion, everything else an HP one. This was a per-plant `potion_effect` cell; it
	## is one rule now, and the plants it must not apply to (the 一次性 family) are excluded
	## by having no potion ROW at all - see plant_potion_item().
	code["potion_effect"] = "hp" if int(code["skill_base"]) <= 0 else "skill"
	code["id"] = plant_id
	return code

# [P100] The growth / talent fall-backs. They were per-plant cells in the deleted
# PLANT_ATTRS table; as one default each they are the answer for a plant whose sheet row
# leaves the column blank ("写 — 就用这里的默认 10% / 10% / 50%" - docs/BALANCE.md).
const PLANT_HP_GROWTH := 0.10
const PLANT_SKILL_GROWTH := 0.10
const PLANT_TALENT_BOOST := 0.5
## [B11] THE THIRD DIMENSION a level raises: 生命 / attack / 防御 are the three stats a unit has,
## and until this batch only the first two grew. Defence grows GENTLER than the other two on
## purpose: it is a DIVISOR in the damage formula, so +10% a level on a base of 1 would take a
## tenth of every blow away per level (see docs/NUMBERS.md §2/§3). A base of 0 stays 0 at every
## level - the growth multiplies the base, so a plant that states no defence never grows one.
const PLANT_DEFENCE_GROWTH := 0.08

static func get_level_factor(p_level: int, p_growth: float) -> float:
	return 1.0 + p_growth * float(maxi(1, p_level) - 1)

static func plant_skill_value(plant_id: String, p_level: int, p_talent: bool) -> int:
	## What the plant's skill is worth on the board. 0 means "this plant has no
	## skill" (the wall-nut), which is what makes an energy bean refuse to work.
	var d := plant_attrs(plant_id)
	var base := int(d.get("skill_base", 0))
	if base <= 0:
		return 0
	var value := float(base) * get_level_factor(p_level, float(d.get("skill_growth", 0.0)))
	if p_talent and str(d.get("potion_effect", "")) == "skill":
		value *= 1.0 + float(d.get("potion_boost", 0.0))
	return maxi(1, int(round(value)))

static func plant_base_skill(plant_id: String) -> int:
	## The level 1 / no talent value of the plant's skill, straight out of the sheet.
	var d := plant_attrs(plant_id)
	return maxi(0, int(d.get("skill_base", 0)))

static func plant_attr_hp(plant_id: String, p_level: int, p_talent: bool) -> int:
	## The health CEILING of one plant: the sheet's 生命 grown by the level curve and
	## the talent potion. Every health path in the game goes through here (a fresh
	## garden plant, a level-up, a battle summon, the board unit itself), so editing the
	## sheet's HP column moves all of them at once. A plant whose sheet row has no HP at
	## all (a one-shot plant) reports 1 rather than 0, so nothing can divide by it.
	var d := plant_attrs(plant_id)
	var value := float(d.get("hp", PEASHOOTER_HP)) * get_level_factor(p_level, float(d.get("hp_growth", 0.0)))
	if p_talent and str(d.get("potion_effect", "")) == "hp":
		value *= 1.0 + float(d.get("potion_boost", 0.0))
	return maxi(1, int(round(value)))

static func plant_attr_defence(plant_id: String, p_level: int) -> int:
	## [B11] THE THIRD DIMENSION of a level, beside the health ceiling (plant_attr_hp) and the
	## skill number (plant_skill_value): the 防御 of one instance, grown by the sheet's base ×
	## the same level curve. NO TALENT TERM, deliberately - a potion doses either the health
	## ceiling or the skill number (plant_attrs' potion_effect), and there is no third dose.
	##
	## A base of 0 STAYS 0 at every level: the growth multiplies the base, so a plant whose row
	## says nothing about defence never grows one. That is the whole roster today except where
	## the sheet fills the column in (units.csv `defence`), which is why this reads as a no-op
	## until a designer writes a number - it is the PLUMBING of the third dimension, not a
	## claim that anything has one.
	var d := plant_attrs(plant_id)
	var base := float(d.get("defence", 0))
	if base <= 0.0:
		return 0
	return maxi(0, int(round(base * get_level_factor(p_level, float(d.get("defence_growth", 0.0))))))


static func plant_potion_item(plant_id: String) -> String:
	## [P100] The talent potion that doses this plant: the `talent` row of data/items.csv
	## whose 对应植物 is this plant - the same sweep a scroll uses (item_for_plant, P95).
	## "" means the plant has no potion, and the sheet already spells out who that is: the
	## 一次性 family has no potion row, so "no potion" is DATA instead of a hand-written `""`.
	## A spirit copy finds nothing by construction (the row names the base plant, not the
	## copy), which is the P95 rule "a copy owns no potion" for free.
	return item_for_plant(ITEM_KIND_TALENT, plant_id)

static func plant_potion_text(plant_id: String) -> String:
	## [P20] The wording lives in LocNames, so the GARDEN page follows the language.
	var d := plant_attrs(plant_id)
	var boost := int(round(float(d.get("potion_boost", 0.0)) * 100.0))
	if str(d.get("potion_effect", "")) == "hp":
		return Loc.tf("plant.potion.hp", [boost])
	return Loc.tf("plant.potion.skill", [boost])

# [P19] Talent NAMES: 硬豌豆 I / 大阳光 I / 厚坚果 I, the "I" being the tier (later
# tiers are II, III ...). [P20] The table itself moved to LocNames
# ("talent.<item id>") so both languages sit with every other translated name
# instead of in a cn/en pair hidden among the numbers.

static func talent_name(item_id: String) -> String:
	## The display name of a talent potion. Which language is served - and the
	## fall-back to English when the UI font cannot draw Chinese - is Loc's call,
	## so a missing font can never show garbage.
	return Loc.t("talent." + item_id, item_name(item_id))

static func talent_display_name(item_id: String) -> String:
	return talent_name(item_id)

static func exp_to_next_level(p_level: int) -> int:
	## [B11] NAMED, so the doc and the code cannot drift: the price of the NEXT level is
	## EXP_PER_LEVEL x the level you are on, so L1 -> L2 needs 100 and L2 -> L3 needs 200.
	## Unbounded on purpose (no cap): the curve is the cost, and a cap is one more line here
	## plus one guard in Garden.add_exp - add it the day a ceiling is a design decision.
	return EXP_PER_LEVEL * maxi(1, p_level)

# ---------------------------------------------------------------- plant cards
# [P12] A plant card no longer creates a plant: it SUMMONS a random available
# instance of that type out of the garden (scripts/core/garden.gd). The card
# therefore carries a cooldown on top of its sun cost, using the same action-bar
# charge the tools use (see the tool section below for the shared rule).
const PEASHOOTER_CARD_COOLDOWN := 3     # rounds until the card can summon again
const SUNFLOWER_CARD_COOLDOWN := 2
const WALLNUT_CARD_COOLDOWN := 5

# [P31-B] The spirit scroll's card joins the roster as its OWN card id. It is a
# spirit copy (see README "灵界卷轴"): the numbers below are the BASE TEMPLATE of
# its plant, deliberately equal to the sheet's peashooter row - the spirit card is
# NOT a unit row and must never be added to data/units/*.csv (the sheet stays the
# truth for garden plants; a spirit copy reads these constants instead).
## [P102] THE FALL-BACK ROSTER - what the battle plays when data/units/plants.csv cannot be
## read. The sheet is the roster now: a plant row's `卡片` cell carries the position it
## takes (see PlantDB.COL_CARD and Balance.plant_cards()), which is why this list is only
## reached in the no-sheet world. It still spells the spirit cards out because there is no
## sheet to derive them from in that world.
##
## The ORDER doctrine the hand-written list used to carry ("availability order; a new card
## is APPENDED so the default deck - the first BalanceBattle.BATTLE_DECK_SLOTS cards - does not move for
## a level that was tuned on it") moved to the sheet with the roster: the `卡片` numbers
## are the order, and adding a card means giving it the next number.
const PLANT_CARD_FALLBACK := ["peashooter", "sunflower", "wallnut", "spirit_peashooter",
	## [P34] The first batch, appended in family order (the pea line, then the twin
	## producer, then the shrooms and the second wall). The ORDER is not cosmetic: a
	## battle nobody picked cards for plays the first BalanceBattle.BATTLE_DECK_SLOTS of this list,
	## and the picking page pre-fills the same way - the four originals stay first so
	## an early level still opens with the deck it was tuned on.
	"repeater", "split_pea", "gatling_pea", "threepeater", "snow_pea",
	"twin_sunflower", "puff_shroom", "fume_shroom", "tallnut",
	## [P39] Batch 2 opens here, APPENDED for the reason the note above gives: the
	## default deck is the FIRST BalanceBattle.BATTLE_DECK_SLOTS of this list, so a new plant joins
	## the roster without changing the deck an early level was tuned on.
	"chomper",
	## [P39] The 一次性 pair after it - cheap card, immediate answer, no card ever sits
	## on the lawn waiting to be paid back.
	"squash", "jalapeno",
	## [P39] And the pair with a fuse, last because they are the slowest of the family:
	## a default deck that opens with them would spend its sun three rounds before it
	## answers, which is a lesson for a later level, not for round one.
	"potato_mine", "cherry_bomb",
	## [P43] The family's fifth card and the last plant of batch 2, appended for the same
	## reason as its brothers: it joins the roster without moving the deck an early level
	## was tuned on.
	"ice_shroom",
	## [P49] Batch 3 opens here with the 投手 family. APPENDED, for the third time, for the
	## same reason: the default deck is the first BalanceBattle.BATTLE_DECK_SLOTS of this list. Their own
	## position in the roster is last for a gameplay reason too - a melon costs 300 sun and
	## a storm of them is a lesson for a level that can pay for it, not for round one.
	"melon_pult", "winter_melon",
	## [P51] The family's cheapest card, appended after its two elders for the same reason
	## every batch appends: the default deck is the first BalanceBattle.BATTLE_DECK_SLOTS of this list, so
	## a new id anywhere past slot 6 joins the roster without moving the deck an early level
	## was tuned on. It sits LAST in the family rather than first because the roster is
	## ordered by when a plant becomes available, not by price - the almanac and the seed
	## page both follow this list.
	"cabbage_pult",
	## [P58] Batch 4's opening plant and the shroom line's third card. APPENDED, for the
	## fourth time, for the same reason: the default deck is the first BalanceBattle.BATTLE_DECK_SLOTS of
	## this list. It joins after the 投手 rather than next to the other two shrooms because
	## this list marks when a card becomes available, and 忧郁菇 is the last of them: 150 sun
	## and a ring only pays for itself once bodies are standing close enough to touch it.
	"gloom_shroom",
	## [P59] The shroom line's fourth card, APPENDED for the fifth time (the default deck
	## is the first BalanceBattle.BATTLE_DECK_SLOTS of this list, so order marks availability). Cheapest
	## of the four after the free puff - 25 sun - and the one whose own row tells you it
	## may not shoot at all.
	"scaredy_shroom",
	## [P63] Batch 5's opening card and the first id outside the five families, APPENDED
	## for the sixth time for the same reason (the default deck is the first
	## BalanceBattle.BATTLE_DECK_SLOTS of this list, so order marks availability, not price). It sits
	## last for the reason the sheet gives it: a spike is worth nothing on a lawn nobody
	## walks across, so it is a card for a level that sends bodies down its lane rather
	## than one you open with.
	"spikeweed",
	## [B30] The healer closes the fall-back roster the same way it closes the sheet: card 25,
	## last, so the default deck an early level was tuned on does not move. It is also the
	## first card here whose number lands on an ALLY instead of on a zombie.
	"warm_sunflower",
	## [P95] AND one spirit copy per plant, appended for the reason every batch above was:
	## the default deck is the first BalanceBattle.BATTLE_DECK_SLOTS of this list, so a card that joins at
	## the END changes nothing for a level that was tuned on the old opening. (The peashooter
	## spirit sits at slot 4 from P32 and stays there.)
	## What each copy IS comes from its base plant by derivation (see spirit_base() and the
	## three accessors that read it): its numbers, its name, its sprite and its script are the
	## base plant's, which is why this list is the ONLY table a new spirit needs.
	"spirit_sunflower", "spirit_wallnut", "spirit_repeater", "spirit_split_pea", "spirit_gatling_pea", "spirit_threepeater", "spirit_snow_pea", "spirit_twin_sunflower", "spirit_puff_shroom", "spirit_fume_shroom", "spirit_tallnut", "spirit_chomper", "spirit_squash", "spirit_jalapeno", "spirit_potato_mine", "spirit_cherry_bomb", "spirit_ice_shroom", "spirit_melon_pult", "spirit_winter_melon", "spirit_cabbage_pult", "spirit_gloom_shroom", "spirit_scaredy_shroom", "spirit_spikeweed", "spirit_warm_sunflower"]
const SPIRIT_CARD_PREFIX := "spirit_"

static var _plant_cards: Array[String] = []
static var _plant_cards_at := -1

static func plant_cards() -> Array[String]:
	## [P102] THE ROSTER: every plants.csv row whose `卡片` cell carries a number, in that
	## number's order, each followed by its SPIRIT copy (P95: every plant has one, and a copy
	## is not a sheet row, so it is derived here).
	##
	## Cached, because the HUD walks this every frame; PlantDB.loads() is the generation it
	## is compared against, so pressing R (which re-reads the sheets) drops it - a cache that
	## is not invalidated is a lie (P75).
	if _plant_cards_at == PlantDB.loads():
		return _plant_cards
	var base: Array[String] = PlantDB.card_ids()
	_plant_cards = []
	if base.is_empty():
		## no sheet: the code list IS the roster, and it already spells its own spirit ids.
		for entry in PLANT_CARD_FALLBACK:
			_plant_cards.append(str(entry))
	else:
		for id in base:
			_plant_cards.append(id)
		for id in base:
			_plant_cards.append(SPIRIT_CARD_PREFIX + id)
	_plant_cards_at = PlantDB.loads()
	return _plant_cards

# [P108] MOVED to BalanceBattle: BATTLE_DECK_SLOTS (the rail's width; DECK_HOTKEY_KEYS went
# with it - a key and the slot it arms are one decision).
const PLANT_DEFS := {
	"peashooter": {
		"name": "Peashooter", "cost": PEASHOOTER_COST, "color": COLOR_PEASHOOTER,
		"hp": PEASHOOTER_HP, "cooldown": PEASHOOTER_CARD_COOLDOWN, "skill_base": 20,
		"rarity": RARITY_COMMON, "art": ART_PLANT,
	},
	"sunflower": {
		"name": "Sunflower", "cost": SUNFLOWER_COST, "color": COLOR_SUNFLOWER,
		"hp": SUNFLOWER_HP, "cooldown": SUNFLOWER_CARD_COOLDOWN, "skill_base": 25,
		"rarity": RARITY_COMMON, "art": ART_PLANT,
	},
	"wallnut": {
		"name": "Wall-nut", "cost": WALLNUT_COST, "color": COLOR_WALLNUT,
		"hp": WALLNUT_HP, "cooldown": WALLNUT_CARD_COOLDOWN, "skill_base": 0,
		"rarity": RARITY_UNCOMMON, "art": ART_PLANT,
	},
	## [P34] The first batch. `name` / `cost` / `hp` / `cooldown` / `skill_base` are the
	## last-resort fall-backs (plant_def() overwrites the first four from the sheet, and
	## plant_name() asks
	## the sheet before this table at all); what this block STILL carries is the presentation
	## the sheet has no column for - `color` (the placeholder body when no sprite is drawn)
	## and `art` - plus the fall-back for every cell above.
	## [P105] `rarity` here is a FALL-BACK too: the tier's owner is the `rarity` cell of
	## units.csv (Balance.plant_rarity), and this copy only answers for a row that leaves the
	## cell blank. How long a downed plant of a tier takes to come back is not in this file at
	## all any more - it is that tier's 恢复倍率 on data/rarity.csv.
	## The rarity ladder here is a design call, not a price: the pea line gets dearer
	## the more peas it fires, the shrooms stay the cheap early options.
	"repeater": {
		"name": "Repeater", "cost": 200, "color": COLOR_REPEATER,
		"hp": 300, "cooldown": 4, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 20,
	},
	"split_pea": {
		"name": "Split Pea", "cost": 300, "color": COLOR_SPLIT_PEA,
		"hp": 300, "cooldown": 5, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 20,
	},
	"gatling_pea": {
		"name": "Gatling Pea", "cost": 400, "color": COLOR_GATLING_PEA,
		"hp": 300, "cooldown": 6, "rarity": RARITY_RARE, "art": ART_PLANT, "skill_base": 20,
	},
	"threepeater": {
		"name": "Threepeater", "cost": 300, "color": COLOR_THREEPEATER,
		"hp": 300, "cooldown": 5, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 20,
	},
	"snow_pea": {
		"name": "Snow Pea", "cost": 175, "color": COLOR_SNOW_PEA,
		"hp": 300, "cooldown": 4, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 20,
	},
	"twin_sunflower": {
		"name": "Twin Sunflower", "cost": 150, "color": COLOR_TWIN_SUNFLOWER,
		"hp": 300, "cooldown": 5, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 25,
	},
	"puff_shroom": {
		"name": "Puff-shroom", "cost": 0, "color": COLOR_PUFF_SHROOM,
		"hp": 200, "cooldown": 2, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 10,
	},
	"fume_shroom": {
		"name": "Fume-shroom", "cost": 75, "color": COLOR_FUME_SHROOM,
		"hp": 300, "cooldown": 4, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 20,
	},
	## [P58] 忧郁菇 150 / 6 from the sheet - the dearest of the three shrooms and the only
	## one whose breath covers the cells behind it, which is the whole reason a level hands
	## a body-lane mushroom to a lawn that gets crowded. RARITY_UNCOMMON sits it with the
	## fume (the same 75-sun step between the free puff and the 150-sun ring is what the
	## ladder has always measured, see the note at the head of this table).
	"gloom_shroom": {
		"name": "Gloom-shroom", "cost": 150, "color": COLOR_GLOOM_SHROOM,
		"hp": 300, "cooldown": 6, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 20,
	},
	## [P59] 胆小菇 25 / 3 from its sheet rows: the SECOND-cheapest shroom (only the free
	## puff is below it) and the quickest to place again. RARITY_COMMON is the price's
	## own answer - the ladder has always read a shroom's rarity off what it costs, and a
	## plant that may hold its fire all round is not the deck's rarest card. What this row
	## really OWNS is the colour (see the note above it).
	"scaredy_shroom": {
		"name": "Scaredy-shroom", "cost": 25, "color": COLOR_SCAREDY_SHROOM,
		"hp": 300, "cooldown": 3, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 20,
	},
	"tallnut": {
		"name": "Tall-nut", "cost": 125, "color": COLOR_TALLNUT,
		"hp": 2000, "cooldown": 6, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 0,
	},
	## [P39] Batch 2's first plant. Same rule as the batch above: the numbers here are
	## the fall-back the sheet overwrites, what this row OWNS is the colour and how long
	## a downed one takes to stand back up.
	"chomper": {
		"name": "Chomper", "cost": 150, "color": COLOR_CHOMPER,
		"hp": 300, "cooldown": 6, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 0,
	},
	## [P39] The 一次性 family. `hp` says 1 because that IS what the sheet says: an empty
	## 生命 cell means "no health of its own" (Balance.plant_attr_hp floors it at 1 so
	## nothing divides by it), and writing 300 here would be a number the sheet then
	## contradicts. The rarity is the sharp end of their cost: a plant that blasts
	## itself to pieces marks its garden slot DOWNED every use, so how fast it gets up
	## again (the tier's 恢复倍率 on data/rarity.csv) is the second half of its price.
	"squash": {
		"name": "Squash", "cost": 50, "color": COLOR_SQUASH,
		"hp": 1, "cooldown": 6, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 9999,
	},
	"jalapeno": {
		"name": "Jalapeno", "cost": 125, "color": COLOR_JALAPENO,
		"hp": 1, "cooldown": 8, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 9999,
	},
	## [P39] The two with a fuse, priced by the sheet (土豆地雷 25 / 7, 樱桃炸弹 150 / 8).
	## The mine is the cheapest card in the game and the only one that answers three
	## rounds later; the cherry is the most expensive of the four and answers next round
	## in a 3x3 - which is the whole trade this family makes.
	"potato_mine": {
		"name": "Potato Mine", "cost": 25, "color": COLOR_POTATO_MINE,
		"hp": 1, "cooldown": 7, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 9999,
	},
	"cherry_bomb": {
		"name": "Cherry Bomb", "cost": 150, "color": COLOR_CHERRY_BOMB,
		"hp": 1, "cooldown": 8, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 9999,
	},
	## [P43] 寒冰菇 175 / 8 from the sheet - the dearest of the five 一次性 cards, and
	## RARE for the reason the header of this table gives: a plant that spends itself
	## marks its garden slot DOWNED every use, so the tier's 恢复倍率 is the second half of
	## what its blast costs, and a card this strong should keep its slot out of the
	## garden the longest (2.5x the baseline against the cherry bomb's 1.5x).
	"ice_shroom": {
		"name": "Ice-shroom", "cost": 175, "color": COLOR_ICE_SHROOM,
		"hp": 1, "cooldown": 8, "rarity": RARITY_RARE, "art": ART_PLANT, "skill_base": 0,
	},
	## [P51] The family's cheapest card: 100 sun / cooldown 4 from the sheet, which is the
	## peashooter's own price for a shot that flies over whatever is in the way and lands
	## 20 instead of 20-into-a-wall. RARITY_COMMON follows that ladder (a 100-sun card sits
	## where the repeater's 200 and the snow pea's 175 sit), and the whole reason this row
	## exists at all is the two fields a sheet cannot carry: the body colour and how fast a
	## downed one comes back.
	"cabbage_pult": {
		"name": "Cabbage-pult", "cost": 100, "color": COLOR_CABBAGE_PULT,
		"hp": 300, "cooldown": 4, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 20,
	},
	## [P49] The two 投手, priced by the sheet (西瓜 300 / 6, 冰西瓜 200 / 8) - note that the
	## icy one is the CHEAPER card and the slower comeback, which is the frost family's
	## standing trade: the snow pea already costs less than the repeater it out-controls.
	## The rarity follows the same ladder as the rest of the table (the 300-sun splash sits
	## where the 300-sun threepeater sits; the control card goes with the other RAREs), and
	## it is the second half of the price: a DOWNED pult is a lane nobody covers while it is
	## in the pot (the tier's 恢复倍率 on data/rarity.csv).
	"melon_pult": {
		"name": "Melon-pult", "cost": 300, "color": COLOR_MELON_PULT,
		"hp": 300, "cooldown": 6, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 60,
	},
	"winter_melon": {
		"name": "Winter-melon", "cost": 200, "color": COLOR_WINTER_MELON,
		"hp": 300, "cooldown": 8, "rarity": RARITY_RARE, "art": ART_PLANT, "skill_base": 60,
	},
	## [P63] 地刺 100 sun / cooldown 4 / HP 300, all from its sheet rows and all only the
	## fall-back this table has always been. What it OWNS is the colour and the comeback:
	## RARITY_COMMON follows the ladder (a 100-sun card sits exactly where the cabbage's 100
	## sits), which is the right reading for a spike - it is not a rare card, it is a card
	## whose value depends on what the level walks down its lane.
	"spikeweed": {
		"name": "Spikeweed", "cost": 100, "color": COLOR_SPIKEWEED,
		"hp": 300, "cooldown": 4, "rarity": RARITY_COMMON, "art": ART_PLANT, "skill_base": 20,
	},
	## [B30] The lawn's first healer, appended for the reason every batch above gives (the
	## `卡片` number is the roster's order now, and this table is only the no-sheet fall-back).
	## The COLOUR is the sunflower's on purpose: the request draws 暖阳葵 with the sunflower's
	## own picture, so a card face and a placeholder body that picked a different yellow would
	## disagree about which plant the lawn is looking at.
	"warm_sunflower": {
		"name": "Warm Sunflower", "cost": 125, "color": COLOR_SUNFLOWER,
		"hp": 300, "cooldown": 4, "rarity": RARITY_UNCOMMON, "art": ART_PLANT, "skill_base": 25,
	},
	## [P95] A spirit copy has no entry here either: plant_def() reads its BASE's row
	## (name, cost, colour, hp, cooldown, rarity, art) through spirit_base(), so the 24
	## copies cannot drift away from the 24 plants they copy.
}

static func spirit_base(card_id: String) -> String:
	## [P31-B] The ONE spirit-card test: a card id that starts with the spirit
	## prefix is the spirit copy of whatever follows the prefix ("" for every
	## normal card). Behaviour, art and numbers of the copy come from the base
	## id; only the summon path (no garden instance, nothing written back) and
	## the presentation differ.
	if card_id.begins_with(SPIRIT_CARD_PREFIX):
		var base := card_id.substr(SPIRIT_CARD_PREFIX.length())
		if base != "" and PLANT_DEFS.has(base):
			return base
	return ""

static func has_plant(plant_id: String) -> bool:
	## [P95] "Is this a plant the game can field?" - asked with the CARD in hand, so a
	## spirit copy counts (its base exists and it is summoned through the same path).
	## The sheet answers first and the code table is the fall-back, exactly like the
	## accessors below; PLANT_DEFS.has() alone would reject every spirit card, which is
	## how the rail's READY claim and select_plant() used to gate them out.
	## The GARDEN keeps asking PLANT_DEFS.has() on purpose: a spirit card owns no garden
	## instance, so it must not be plantable there.
	if PlantDB.has(plant_id):
		return true
	if PLANT_DEFS.has(plant_id):
		return true
	return spirit_base(plant_id) != ""

static func plant_def(plant_id: String) -> Dictionary:
	## [P26] One card's definition, with every NUMBER taken from plant_attrs() (i.e.
	## from the plant sheet, see data/units/plants.csv) and this file's constant table
	## as the fall-back for a sheet that could not be read. Art, colour and rarity
	## stay here on purpose: those are presentation, not balance.
	## [P34] The old "hotkey" field is gone: a card is armed by its DECK SLOT, which
	## is a fact about the battle, not about the plant (see BalanceBattle.DECK_HOTKEY_KEYS).
	##
	## Callers that used to read Balance.PLANT_DEFS[id]["cost"] read this instead, so
	## there is exactly one place where "the sheet wins" is written down.
	## [P95] A spirit copy reads its BASE plant's row: colour, rarity, card cooldown and art
	## are the base's, and the name is the base's too (the copy is "just the plant on the
	## board", which is what the P31-B note always said). Deriving beats listing 24 rows that
	## would have to be kept equal by hand.
	var def_key := plant_id
	var spirit := spirit_base(plant_id)
	if spirit != "":
		def_key = spirit
	var base: Dictionary = PLANT_DEFS.get(def_key, {}).duplicate()
	if base.is_empty():
		base = {
			"name": plant_id, "cost": 0, "color": COLOR_PEASHOOTER,
			"hp": 0, "cooldown": 1, "rarity": RARITY_COMMON, "art": "",
		}
	var attrs := plant_attrs(plant_id)
	base["cost"] = int(attrs.get("cost", base.get("cost", 0)))
	base["cooldown"] = int(attrs.get("cooldown", base.get("cooldown", 1)))
	base["hp"] = int(attrs.get("hp", base.get("hp", 0)))
	base["attack"] = int(attrs.get("skill_base", 0))
	base["id"] = plant_id
	base["name"] = plant_name(plant_id)
	return base

static func plant_cost(plant_id: String) -> int:
	## The sun a summon costs. Read through plant_def() so a card, the HUD and the
	## battle can never disagree about the price.
	return maxi(0, int(plant_def(plant_id).get("cost", 0)))

# [P108] MOVED to BalanceBattle: SUMMONS_PER_TURN.

static func plant_name(plant_id: String) -> String:
	## [P20] Display name follows the language (LocNames "plant.<id>").
	## [P26] The plant sheet is asked first: it carries all 17 plants of the design,
	## so a plant that has no card yet still has a name. PLANT_DEFS "name" is the
	## last-resort fall-back for a sheet that could not be read.
	## [P95] A spirit copy answers with its BASE plant's name: the copy is the same plant
	## (only the scroll has 花园/灵界 wording), and there is no sheet row for it to read.
	var spirit := spirit_base(plant_id)
	if spirit != "":
		return plant_name(spirit)
	if PlantDB.has(plant_id):
		return PlantDB.name(plant_id)
	var d: Dictionary = PLANT_DEFS.get(plant_id, {})
	return Loc.t("plant." + plant_id, str(d.get("name", plant_id)))

static func plant_max_hp(plant_id: String) -> int:
	## A level 1 plant at full health. Kept as the "fresh instance" shortcut; the
	## real ceiling is plant_attr_hp(type, level, talent).
	return plant_attr_hp(plant_id, 1, false)

static func plant_card_cooldown(plant_id: String) -> int:
	## [P26] Rounds the card needs to charge, straight out of the sheet (plant attrs).
	## The constant in PLANT_DEFS stays on as the fall-back, and PlantDB.self_check()
	## checks the WIRING at start-up (what the battle resolves == what the sheet says).
	return maxi(1, int(plant_attrs(plant_id).get("cooldown", 1)))

# [P108] MOVED to BalanceBattle: skill_ap_cost() - it reads SKILL_AP_COST there.

static func plant_skill_code(plant_id: String, p_fallback: String) -> String:
	## [P30-A4] WHICH skill a plant loads: the 技能代码 column of its units.csv row
	## wins (this is the hook a future "change the loadout" feature will write to),
	## and the unit script's own `const SKILL` is the fall-back - both for a blank
	## cell and for a code the skill sheet does not know (a loadout the battle has
	## no implementation for must not silently price a skill that never fires).
	var sheet_code := PlantDB.skill_code(plant_id)
	if sheet_code != "" and SkillDB.has(sheet_code):
		return sheet_code
	return p_fallback

static func plant_ult_code(plant_id: String, p_fallback: String) -> String:
	## [P30-B] WHICH ultimate a plant loads: the 大招代码 column of its units.csv
	## row wins; the script's own `const ULTIMATE` (where one exists) is the
	## fall-back for a blank cell. A code the skill sheet has no ULTIMATE row for
	## loads NOTHING, whatever either said - the honest "no bar" state beats a
	## bar that can fill but never fire.
	var sheet_code := PlantDB.ult_code(plant_id)
	if sheet_code != "" and SkillDB.is_ultimate(sheet_code):
		return sheet_code
	if p_fallback != "" and SkillDB.is_ultimate(p_fallback):
		return p_fallback
	return ""

# [P108] MOVED to BalanceBattle: plant_ult_value() - it reads ULTIMATE_VALUE there.

static func plant_ult_charge(ult_code: String) -> String:
	## [P30-B] What fills the bar: the sheet's 大招充能 phrase translated by
	## SkillDB ("cast" / "hit"). Every unknown answer is "cast" - the confirmed
	## default rule.
	var flag := SkillDB.ult_charge(ult_code)
	return flag if flag != "" else "cast"

static func plant_art(plant_id: String) -> String:
	## Used by the board units, the plant cards, the garden screen and the almanac, which
	## all draw the same sprite. [P28] The PLANT SHEET is asked first: its svg column is
	## where a plant's picture is registered now - including the ones that are not
	## summonable yet. A row that registers no picture (or names a file nobody has drawn
	## yet) falls back to the bare plant.svg, whatever the id is.
	## [P31-B] A spirit copy wears its BASE PLANT's sprite (the card icon tints it;
	## the board unit does the same), never the bare fall-back.
	var spirit := spirit_base(plant_id)
	if spirit != "":
		return plant_art(spirit)
	if PlantDB.has(plant_id):
		return PlantDB.art(plant_id)
	else:
		return ART_PLANT

# ---------------------------------------------------------------- tools (P8)
# [P108] MOVED to BalanceBattle: the three tool ids, their thresholds, HAMMER_DAMAGE, the
# three identity colours, TOOL_CARDS, the deck / tool hotkey tables and TOOL_DEFS with
# tool_name() / tool_default_threshold().

# ---------------------------------------------------------------- HUD layout
# [P28-UI] The whole HUD metric block moved to BalanceUI: bar and button colours,
# CARD_*, ROW_LABEL_*, END_TURN_*, TOP_BUTTON_*, the text baselines and every
# FONT_SIZE_HUD/CARD/BUTTON/OVERLAY. What stays is the SETTINGS confirm below - the RETREAT
# one moved to BalanceBattle with the rest of the battle scene ([P108]); both gate game
# actions, not pixels.
# [P108] The RETREAT confirm moved to BalanceBattle with the battle scene; the one below
# stays - the SETTINGS page is its only reader.
# [P16] the same idea for SETTINGS -> RESET GAME, which wipes the whole save
const RESET_CONFIRM_TIME := 3.0

# ---------------------------------------------------------------- presentation (P5)
# [P28-UI] All of it moved to BalanceUI: the ANIM_* timings, FLASH_DECAY, the pea
# flight (PEA_SPEED / PEA_RADIUS / PEA_MUZZLE_OFFSET), SPARK/POPUP/
# BANNER sizes and FONT_SIZE_POPUP/BANNER, COLOR_FLASH. They decide how the battle
# LOOKS; nothing in the game rules reads them.

# ---------------------------------------------------------------- external level data (P6)
# [P26] The level pack lives in its own folder now: LEVEL_DIR holds every level of the
# adventure, and the pack's naming is `Lawn_<world>_<stage>.json` (Lawn_1_1 .. Lawn_1_8).
# LEVEL_PATH is the single-file fall-back the game still opens when the folder cannot
# be read at all, so there is always something to start.
const LEVEL_PATH := "res://data/level/Lawn_1_1.json"

# ---------------------------------------------------------------- result panel (P7)
# [P28-UI] The OVERLAY_* / RESTART_SIZE / RESULT_BUTTON_* metrics moved to BalanceUI.

# ---------------------------------------------------------------- front-end (P10)
# [P26] Every level is one *.json in this folder (LevelList.discover). The pack's own
# files are named Lawn_<world>_<stage>.json; when at least one of them exists, the
# files that do NOT follow that naming are skipped (and listed in the log), which is
# what keeps the superseded level_0x.json files out of the level list. Delete every
# Lawn_*.json and the folder is read as "any *.json in here" again.
const LEVEL_DIR := "res://data/level"
const LEVEL_PACK_PREFIX := "Lawn_"
const SETTINGS_PATH := "user://settings.cfg"   # never project.godot: the editor rewrites that

# [P28-UI] The menu METRICS (MENU_TITLE_Y / MENU_SUB_OFFSET / MENU_LIST_TOP(_MIN),
# the whole main-menu-props block incl. MENU_ICONS and menu_icon_paths()/
# menu_icon_title(), the menu colours/fonts and SETTINGS_WINDOW_PRESETS) live in
# BalanceUI now. The paths above are data and stay.

# ---------------------------------------------------------------- audio (P21 / P50)
# [P69] Gone: the whole background-music and sound-effect vocabulary - MUSIC_DIR,
# MUSIC_DEFS, the six screen track ids, the volume steps and fades, SFX_DIR, SFX_DEFS,
# SFX_POOL / SAME_CUE_MS / PITCH_JITTER / MAX_LENGTH and the sixteen reader helpers -
# moved to BalanceAudio (scripts/balance/balance_audio.gd) as C9's first cut. The rule is
# [P28-UI]'s: a constant lives with the code that reads it, and every one of those
# names is read only by the audio layer, by the screens that name a track, or by the
# save file that holds a volume - never by a game rule. Nothing here reads BalanceAudio.

# ---------------------------------------------------------------- items + economy (P14)
# Everything the player can own, as an id -> definition table. Items live in two
# containers owned by Profile (scripts/core/profile.gd):
#   WAREHOUSE  used outside a battle
#   BACKPACK   used during a battle; merged into the warehouse when it settles
#
# Money is a plain number. COINS ARE ITEMS: getting a coin does NOT add money -
# you have to SELL the coin in the warehouse page, which is why money can only
# grow through an explicit player action.
const ITEM_SCROLL_PEASHOOTER := "scroll_peashooter"
const ITEM_SCROLL_SUNFLOWER := "scroll_sunflower"
const ITEM_SCROLL_WALLNUT := "scroll_wallnut"
# [P31-B] the first SPIRIT scroll: it unlocks the spirit copy's card, not a garden
# plant (see spirit_base() and README "灵界卷轴").
const ITEM_SCROLL_SPIRIT_PEASHOOTER := "scroll_spirit_peashooter"
const ITEM_COIN_SILVER := "coin_silver"
const ITEM_COIN_GOLD := "coin_gold"
const ITEM_COIN_DIAMOND := "coin_diamond"
const ITEM_FERTILIZER := "fertilizer"
# [P15] battle consumable + talent potions
const ITEM_ENERGY_BEAN := "energy_bean"
const ITEM_POTION_PEASHOOTER := "potion_peashooter"
const ITEM_POTION_SUNFLOWER := "potion_sunflower"
const ITEM_POTION_WALLNUT := "potion_wallnut"
const ITEM_EXP_POTION := "exp_potion"
## [P95] The kind (分类) of a PLANT CHEST: the item a cleared level hands over instead
## of the plant itself. Opening it in the warehouse is what puts the plant in the
## garden - so the reward is something the player can SEE, carry and choose when to
## spend, and a level's plant can wait in the warehouse while the garden is full.
const ITEM_KIND_PLANT_CHEST := "plant_chest"
## [P100] The kind (分类) of a TALENT POTION: one row per plant that has one, and the absence
## of a row is how the sheet says "this plant has no potion" (the 一次性 family).
const ITEM_KIND_TALENT := "talent"

const COIN_SILVER_VALUE := 10
const COIN_GOLD_VALUE := 100
const COIN_DIAMOND_VALUE := 1000

# [P14] A scroll is NOT spent by a summon: it has DURABILITY, and how much a
# summon costs is decided per level (`scroll_durability_cost` in the level file).
# Every level that exists today is a NORMAL challenge with cost 0, so a summon
# currently spends nothing - the scroll just proves you unlocked the card.
# A future hard/elite challenge sets the cost to 1, and a scroll that runs out of
# durability breaks and falls back to the next one you own.
const SCROLL_MAX_DURABILITY := 3
# [P31-B] A SPIRIT scroll carries 50 (docs/BALANCE.md 4.4 "神秘召唤卷轴"): like a
# garden scroll it spends nothing in a normal challenge, but the deep pools exist
# for the spirit-challenge levels that will consume them.
const SCROLL_SPIRIT_MAX_DURABILITY := 50
const SILVER_DROP_CHANCE := 0.15        # normal zombie -> 1 silver coin
const FERTILIZER_DROP_CHANCE := 0.02    # normal zombie -> 1 bag of fertilizer
# [P15] reward chances now live in each level's `rewards` array (independent rolls),
# so there is no global "clear plant" chance any more.

const ITEM_DEFS := {
	ITEM_SCROLL_PEASHOOTER: {
		"name": "Peashooter Garden Scroll", "kind": "scroll", "plant": "peashooter",
		"durability": SCROLL_MAX_DURABILITY,
	},
	ITEM_SCROLL_SUNFLOWER: {
		"name": "Sunflower Garden Scroll", "kind": "scroll", "plant": "sunflower",
		"durability": SCROLL_MAX_DURABILITY,
	},
	ITEM_SCROLL_WALLNUT: {
		"name": "Wall-nut Garden Scroll", "kind": "scroll", "plant": "wallnut",
		"durability": SCROLL_MAX_DURABILITY,
	},
	ITEM_SCROLL_SPIRIT_PEASHOOTER: {
		"name": "Peashooter Spirit Scroll", "kind": "scroll", "plant": "spirit_peashooter",
		"durability": SCROLL_SPIRIT_MAX_DURABILITY,
	},
	ITEM_COIN_SILVER: {"name": "Silver Coin", "kind": "coin", "value": COIN_SILVER_VALUE},
	ITEM_COIN_GOLD: {"name": "Gold Coin", "kind": "coin", "value": COIN_GOLD_VALUE},
	ITEM_COIN_DIAMOND: {"name": "Diamond", "kind": "coin", "value": COIN_DIAMOND_VALUE},
	ITEM_FERTILIZER: {"name": "Fertilizer Bag", "kind": "fertilizer"},
	ITEM_ENERGY_BEAN: {
		"name": "Energy Bean", "kind": "battle",
		"hint": "use on a plant to resolve its skill 10 times at once",
	},
	ITEM_POTION_PEASHOOTER: {
		"name": "Peashooter Potion", "kind": "talent",
		## [P23] "plant" is whose mark sits on the bottle, "tier" picks the generic
		## bottle (Balance.POTION_TIER_PATHS). All three potions are tier I today.
		"plant": "peashooter", "tier": "common",
	},
	ITEM_POTION_SUNFLOWER: {
		"name": "Sunflower Potion", "kind": "talent",
		"plant": "sunflower", "tier": "common",
	},
	ITEM_POTION_WALLNUT: {
		"name": "Wall-nut Potion", "kind": "talent",
		"plant": "wallnut", "tier": "common",
	},
	ITEM_EXP_POTION: {"name": "EXP Potion", "kind": "exp", "exp": EXP_POTION_AMOUNT},
	"scroll_repeater": {"name": "Repeater Garden Scroll", "kind": "scroll",
		"plant": "repeater", "durability": SCROLL_MAX_DURABILITY},
	"scroll_split_pea": {"name": "Split Pea Garden Scroll", "kind": "scroll",
		"plant": "split_pea", "durability": SCROLL_MAX_DURABILITY},
	"scroll_gatling_pea": {"name": "Gatling Pea Garden Scroll", "kind": "scroll",
		"plant": "gatling_pea", "durability": SCROLL_MAX_DURABILITY},
	"scroll_threepeater": {"name": "Threepeater Garden Scroll", "kind": "scroll",
		"plant": "threepeater", "durability": SCROLL_MAX_DURABILITY},
	"scroll_snow_pea": {"name": "Snow Pea Garden Scroll", "kind": "scroll",
		"plant": "snow_pea", "durability": SCROLL_MAX_DURABILITY},
	"scroll_twin_sunflower": {"name": "Twin Sunflower Garden Scroll", "kind": "scroll",
		"plant": "twin_sunflower", "durability": SCROLL_MAX_DURABILITY},
	"scroll_puff_shroom": {"name": "Puff-shroom Garden Scroll", "kind": "scroll",
		"plant": "puff_shroom", "durability": SCROLL_MAX_DURABILITY},
	"scroll_fume_shroom": {"name": "Fume-shroom Garden Scroll", "kind": "scroll",
		"plant": "fume_shroom", "durability": SCROLL_MAX_DURABILITY},
	## [P58] Batch 4's card, and the same gate: without this scroll the ring stays a line
	## of the almanac. A scroll per summonable plant is what makes "own the card" and
	## "have unlocked it" the same fact in the garden.
	"scroll_gloom_shroom": {"name": "Gloom-shroom Garden Scroll", "kind": "scroll",
		"plant": "gloom_shroom", "durability": SCROLL_MAX_DURABILITY},
	## [P59] 胆小菇's unlock, same durability as every other scroll (a scroll's price is
	## in how often it drops, not in how many times it can be spent).
	"scroll_scaredy_shroom": {"name": "Scaredy-shroom Garden Scroll", "kind": "scroll",
		"plant": "scaredy_shroom", "durability": SCROLL_MAX_DURABILITY},
	"scroll_tallnut": {"name": "Tall-nut Garden Scroll", "kind": "scroll",
		"plant": "tallnut", "durability": SCROLL_MAX_DURABILITY},
	## [P39] Batch 2 joins one plant at a time, and a plant without its scroll is a
	## plant that cannot be brought to a battle at all (same gate as above).
	"scroll_chomper": {"name": "Chomper Garden Scroll", "kind": "scroll",
		"plant": "chomper", "durability": SCROLL_MAX_DURABILITY},
	"scroll_squash": {"name": "Squash Garden Scroll", "kind": "scroll",
		"plant": "squash", "durability": SCROLL_MAX_DURABILITY},
	"scroll_jalapeno": {"name": "Jalapeno Garden Scroll", "kind": "scroll",
		"plant": "jalapeno", "durability": SCROLL_MAX_DURABILITY},
	## [P39] The family's other two cards, same gate as the rest: no scroll, no card.
	"scroll_potato_mine": {"name": "Potato Mine Garden Scroll", "kind": "scroll",
		"plant": "potato_mine", "durability": SCROLL_MAX_DURABILITY},
	"scroll_cherry_bomb": {"name": "Cherry Bomb Garden Scroll", "kind": "scroll",
		"plant": "cherry_bomb", "durability": SCROLL_MAX_DURABILITY},
	## [P43] The family's last card, and the same gate: without this scroll the frost
	## stays a line of the almanac. It owns NO potion, like the rest of the family.
	"scroll_ice_shroom": {"name": "Ice-shroom Garden Scroll", "kind": "scroll",
		"plant": "ice_shroom", "durability": SCROLL_MAX_DURABILITY},
	## [P49] Batch 3's two cards, one scroll and one potion each (the 投手 are ordinary
	## plants, so they grow and get dosed like the pea family does - unlike the 一次性
	## above them). No scroll, no card: see the gate this block exists for.
	## [P51] The cabbage's scroll opens the same pair: without it the lobber stays a line of
	## the almanac, and its potion is the "shooter gets a skill potion" rule again.
	"scroll_cabbage_pult": {"name": "Cabbage-pult Garden Scroll", "kind": "scroll",
		"plant": "cabbage_pult", "durability": SCROLL_MAX_DURABILITY},
	"scroll_melon_pult": {"name": "Melon-pult Garden Scroll", "kind": "scroll",
		"plant": "melon_pult", "durability": SCROLL_MAX_DURABILITY},
	"scroll_winter_melon": {"name": "Winter-melon Garden Scroll", "kind": "scroll",
		"plant": "winter_melon", "durability": SCROLL_MAX_DURABILITY},
	## [P63] Batch 5's card and the scroll group's first entry outside the five families.
	## The gate is the same one every scroll here exists for: no scroll, no card - a spike
	## the almanac can describe but no battle can summon is a line of prose.
	"scroll_spikeweed": {"name": "Spikeweed Garden Scroll", "kind": "scroll",
		"plant": "spikeweed", "durability": SCROLL_MAX_DURABILITY},
	## The potions stay tier I ("common") like the three originals: the tier ladder is
	## a design that has not been drawn yet, and the bottle follows the tier (see
	## POTION_TIER_PATHS), so a tier nobody designed would show a bottle nobody filled.
	"potion_repeater": {"name": "Repeater Potion", "kind": "talent",
		"plant": "repeater", "tier": "common"},
	"potion_split_pea": {"name": "Split Pea Potion", "kind": "talent",
		"plant": "split_pea", "tier": "common"},
	"potion_gatling_pea": {"name": "Gatling Pea Potion", "kind": "talent",
		"plant": "gatling_pea", "tier": "common"},
	"potion_threepeater": {"name": "Threepeater Potion", "kind": "talent",
		"plant": "threepeater", "tier": "common"},
	"potion_snow_pea": {"name": "Snow Pea Potion", "kind": "talent",
		"plant": "snow_pea", "tier": "common"},
	"potion_twin_sunflower": {"name": "Twin Sunflower Potion", "kind": "talent",
		"plant": "twin_sunflower", "tier": "common"},
	"potion_puff_shroom": {"name": "Puff-shroom Potion", "kind": "talent",
		"plant": "puff_shroom", "tier": "common"},
	"potion_fume_shroom": {"name": "Fume-shroom Potion", "kind": "talent",
		"plant": "fume_shroom", "tier": "common"},
	## [P58] A shooter's potion lifts its skill, so a dosed ring sprays 30 instead of 20
	## into every one of the eight cells - the same one-number rule the whole family has.
	"potion_gloom_shroom": {"name": "Gloom-shroom Potion", "kind": "talent",
		"plant": "gloom_shroom", "tier": "common"},
	## [P59] And the scaredy one: dosing it lifts 远程射击 to 30, the same one-number rule -
	## and a scared plant that dares to fire hits harder for it.
	"potion_scaredy_shroom": {"name": "Scaredy-shroom Potion", "kind": "talent",
		"plant": "scaredy_shroom", "tier": "common"},
	"potion_tallnut": {"name": "Tall-nut Potion", "kind": "talent",
		"plant": "tallnut", "tier": "common"},
	"potion_chomper": {"name": "Chomper Potion", "kind": "talent",
		"plant": "chomper", "tier": "common"},
	## [P49] The 投手' talent potions: both lift the throw's damage, which is the same
	## "shooter gets a skill potion" rule the whole pea family follows - and because
	## PULT_SPLASH_RATIO is a share of the shot, the splash grows with it. The tier stays
	## "common" (tier I) like every potion shipped so far; see the note above.
	## [P51] The cabbage's potion lifts the throw like the other two (it has a skill number
	## of its own, which is what [P100] derives "skill" from), one pair per card.
	"potion_cabbage_pult": {"name": "Cabbage-pult Potion", "kind": "talent",
		"plant": "cabbage_pult", "tier": "common"},
	"potion_melon_pult": {"name": "Melon-pult Potion", "kind": "talent",
		"plant": "melon_pult", "tier": "common"},
	"potion_winter_melon": {"name": "Winter-melon Potion", "kind": "talent",
		"plant": "winter_melon", "tier": "common"},
	## [P63] The spike's talent potion rides the same rule the shooters' do: a plant whose
	## skill has a NUMBER gets a skill potion (a dosed spike stabs for 30), and only the
	## cards with no skill number of their own - the two walls, the chomper - buy HP
	## instead. Tier "common", like every potion shipped so far.
	"potion_spikeweed": {"name": "Spikeweed Potion", "kind": "talent",
		"plant": "spikeweed", "tier": "common"},
}

# Display order in the warehouse page: scrolls, then coins (by value), then the rest.
# [P34] The batch-1 items join their own group (the fall-back roster only - when
# data/items.csv loads, ItemDB lists the SHEET's order).
const ITEM_ORDER := [
	ITEM_SCROLL_PEASHOOTER, ITEM_SCROLL_SUNFLOWER, ITEM_SCROLL_WALLNUT,
	ITEM_SCROLL_SPIRIT_PEASHOOTER,
	"scroll_repeater", "scroll_split_pea", "scroll_gatling_pea", "scroll_threepeater",
	"scroll_snow_pea", "scroll_twin_sunflower", "scroll_puff_shroom",
	"scroll_fume_shroom", "scroll_tallnut",
	## [P39] Batch 2's first plant (see ITEM_DEFS).
	"scroll_chomper",
	## [P39] The two 一次性 plants. They own NO potion on purpose - a blast that already
	## exceeds every health pool on the board has nothing for a talent to lift, which
	## [P100] the item sheet now says by having no potion row for them at all.
	"scroll_squash", "scroll_jalapeno",
	## [P39] The other two members of that family, for the same reason and with the same
	## no-potion rule.
	"scroll_potato_mine", "scroll_cherry_bomb",
	## [P43] And its fifth, which closes batch 2: the scroll group now holds one card per
	## summonable plant, and the potion group still holds none of the 一次性 family.
	"scroll_ice_shroom",
	## [P49] Batch 3's opening. These two rejoin the potion group as well: a 投手 is an
	## ordinary plant that grows, so the scroll/potion pair is complete for it.
	## [P51] The cabbage's scroll, in front of its two elders because the sheet lists the
	## family in that order (units.csv 卷心菜 / 玉米 / 西瓜 / 冰西瓜) and this is the list the
	## warehouse page falls back to.
	"scroll_cabbage_pult",
	"scroll_melon_pult", "scroll_winter_melon",
	## [P58] Batch 4's card closes the scroll group - one scroll per summonable plant.
	"scroll_gloom_shroom",
	## [P59] The fourth shroom joins it at the end, in sheet order.
	"scroll_scaredy_shroom",
	## [P63] Batch 5's card closes the scroll group again - one scroll per summonable
	## plant, and the spike is the first of them outside the five families.
	"scroll_spikeweed",
	ITEM_COIN_SILVER, ITEM_COIN_GOLD, ITEM_COIN_DIAMOND,
	ITEM_FERTILIZER, ITEM_ENERGY_BEAN,
	ITEM_POTION_PEASHOOTER, ITEM_POTION_SUNFLOWER, ITEM_POTION_WALLNUT,
	"potion_repeater", "potion_split_pea", "potion_gatling_pea", "potion_threepeater",
	"potion_snow_pea", "potion_twin_sunflower", "potion_puff_shroom",
	"potion_fume_shroom", "potion_tallnut",
	"potion_chomper",
	## [P49] The 投手 pair, in the same order as their scrolls above.
	## [P51] The cabbage's potion rejoins them there, same order.
	"potion_cabbage_pult",
	"potion_melon_pult", "potion_winter_melon",
	## [P58] And its potion, same place in the group as its scroll has above.
	"potion_gloom_shroom",
	## [P59] The scaredy pair closes the group the same way.
	"potion_scaredy_shroom",
	## [P63] Its pair, and the potion group's first entry that is not one of the five
	## families - same place in the group as its scroll has above.
	"potion_spikeweed",
	ITEM_EXP_POTION,
]

# ---------------------------------------------------------------- shop (P15)
# [P108] MOVED to BalanceShop (scripts/balance/balance_shop.gd): the 26 SHOP_PRICE_* numbers and
# SHOP_STOCK, the row list the shelf draws. The ITEM_* ids those rows name stay here -
# they are item data, not shop data.
const ENERGY_BEAN_HITS := 10            # a bean resolves the base skill this many times
const ENERGY_BEAN_DROP_CHANCE := 0.05   # normal zombie -> 1 energy bean

# ---------------------------------------------------------------- item tiles / screens / backpack / almanac
# [P28-UI] The four pure-layout blocks moved to BalanceUI verbatim: ITEM_TILE_* /
# ITEM_GRID_* / their fonts and colours (P22), the ITEM_SCREEN / ITEM_PANEL metrics,
# the PACK_* backpack panel box, and the whole ALMANAC_* + COLOR_ALMANAC_* set (P26).
# They are read only by item_tile.gd / item_grid.gd / item_screen.gd / the views /
# almanac_view.gd. The item DATA (ITEM_DEFS, the drop chances) is above/below and stays here;
# what the SHOP asks for it moved to BalanceShop ([P108]).

static func is_item(item_id: String) -> bool:
	## [P88] THE GATE every acquisition goes through (Profile.add_item, the level rewards,
	## the drop table) and it must agree with where items come from now: THE SHEET. A row
	## only the sheet has (the sun item) is a real item - the code table is the fall-back
	## for a sheet that cannot be read, not a second owner (user rule: 表是游戏设定和内容
	## 的唯一约定方). ItemDB is reached inside a function body, like PlantDB below, so the
	## two-way reference resolves (Balance -> ItemDB -> Balance is a call cycle, not a
	## parse-time one).
	return ITEM_DEFS.has(item_id) or ItemDB.has(item_id)

static func item_name(item_id: String) -> String:
	## [P20] Display name follows the language (LocNames "item.<id>"). [P88] and behind the
	## language layer the SHEET answers before the code table does.
	var sheet := ItemDB.raw_name(item_id)
	var d: Dictionary = ITEM_DEFS.get(item_id, {})
	return Loc.t("item." + item_id, sheet if sheet != "" else str(d.get("name", item_id)))

static func item_kind(item_id: String) -> String:
	## [P88] the sheet wins (see is_item).
	var sheet := ItemDB.raw_kind(item_id)
	if sheet != "":
		return sheet
	var d: Dictionary = ITEM_DEFS.get(item_id, {})
	return str(d.get("kind", ""))

static func item_code_row(item_id: String) -> Dictionary:
	## [P88] THE CODE TABLE'S OWN VIEW of one item, with no sheet in it. The sheet is the
	## source now, so the [Items] self-check needs a way to say "the sheet says X, the code
	## table says Y" without asking the sheet twice - and "" means the sheet is the only
	## owner of this id (the sun item today).
	return ITEM_DEFS.get(item_id, {})

static func item_kind_label(p_kind: String) -> String:
	## [P22] The word shown on the detail panel's TYPE line of the warehouse and the
	## shop. One literal key per branch on purpose: a key built by concatenation
	## would be invisible to the key audit (same rule as Game._item_kind_mark had).
	match p_kind:
		"scroll":
			return Loc.t("item.kind.scroll")
		"coin":
			return Loc.t("item.kind.coin")
		"fertilizer":
			return Loc.t("item.kind.fertilizer")
		"battle":
			return Loc.t("item.kind.battle")
		"exp":
			return Loc.t("item.kind.exp")
		"talent":
			return Loc.t("item.kind.talent")
		"plant":
			return Loc.t("item.kind.plant")
		"plant_chest":
			## [P95] the chest a cleared level hands over (see ITEM_KIND_PLANT_CHEST)
			return Loc.t("item.kind.plant_chest")
	return Loc.t("item.kind.other")

## [P29-UI] The four sub-categories the almanac's ITEMS section splits its roster
## into (道具 / 装备 / 材料 / 货币), shown as a second row under the tabs - the same
## pattern the UNITS section uses for its two races. The group is DERIVED from the
## row's 分类 (kind), not a new items.csv column: the sheet already says what each
## item is, and a second column would only be able to contradict it.
## "tool" is the catch-all on purpose: an unknown kind is still a thing you can use,
## and no item may end up in a group nobody can click open (ItemDB.self_check()
## already prints unknown kinds, so a real new category shows up in the log first).
## Current mapping of the sheet's kinds: coin -> currency, scroll and plant_chest -> equip
## (the two ways a plant joins the roster: the scroll that unlocks its card and the chest
## it arrives in), everything else (fertilizer, battle, exp, talent) -> tool; material has
## no member yet - the almanac row is simply empty until craft-style rows exist.
const ITEM_GROUPS: Array[String] = ["tool", "equip", "material", "currency"]
const ITEM_GROUP_OF_KIND := {
	"coin": "currency",
	"scroll": "equip",
	## [P95] the chest a plant gift arrives in (Balance.ITEM_KIND_PLANT_CHEST)
	"plant_chest": "equip",
	"equipment": "equip",
	"gear": "equip",
	"weapon": "equip",
	"armor": "equip",
}

static func item_group_of_kind(p_kind: String) -> String:
	## Which of ITEM_GROUPS a sheet kind belongs to. Unknown -> "tool" (see above);
	## a mapped-but-typo group value also falls back, so the answer is always one of
	## the four keys the almanac has a button (and a Loc key) for.
	var group := str(ITEM_GROUP_OF_KIND.get(p_kind, "tool"))
	return group if ITEM_GROUPS.has(group) else "tool"

static func item_hint(item_id: String) -> String:
	## [P22] One short "what is this for" line for the detail panel. The wording
	## lives in the language table: "item.hint.<id>" first, then the shared
	## "item.hint.kind.<kind>", so a new item costs a table row and no code change.
	## The English "hint" field of ITEM_DEFS is only the last-resort fallback.
	var exact := "item.hint." + item_id
	if Loc.has_key(exact):
		return Loc.t(exact)
	var by_kind := "item.hint.kind." + item_kind(item_id)
	if Loc.has_key(by_kind):
		return Loc.t(by_kind)
	var d: Dictionary = ITEM_DEFS.get(item_id, {})
	return str(d.get("hint", ""))

static func sun_drop_art() -> String:
	## [P89] The icon a sun on the lawn is drawn with: the `sun` row of data/items.csv, which
	## is the same picture the almanac and the warehouse show. An empty answer means the
	## sheet (or its import) is not there yet - the drop falls back to a flat disc.
	if not ItemDB.has("sun"):
		return ""
	return ItemDB.art("sun")

static func item_price(item_id: String) -> int:
	## [P88] RENAMED from item_value and sheet-first: the item's PRICE - a coin's sell
	## value, a scroll's durability, a potion's exp. It is NOT "how much sun a sun drop is
	## worth": the plant that produced the drop decides that (PROMPT §4).
	if ItemDB.has(item_id):
		return ItemDB.raw_price(item_id)
	var d: Dictionary = ITEM_DEFS.get(item_id, {})
	return int(d.get("price", d.get("value", 0)))

static func item_plant(item_id: String) -> String:
	## Scrolls name the plant they unlock; everything else returns "". [P88] sheet first.
	if ItemDB.has(item_id):
		return ItemDB.plant(item_id)
	var d: Dictionary = ITEM_DEFS.get(item_id, {})
	return str(d.get("plant", ""))

static func item_max_durability(item_id: String) -> int:
	## [P88] a scroll's durability IS its price cell (that is what 分类 decides the column
	## means), so the sheet answers first here too.
	if ItemDB.has(item_id):
		return maxi(1, ItemDB.raw_price(item_id))
	var d: Dictionary = ITEM_DEFS.get(item_id, {})
	return maxi(1, int(d.get("durability", 1)))

static func item_for_plant(p_kind: String, p_plant_id: String) -> String:
	## [P95] The item of ONE KIND that belongs to ONE plant: the survey behind both
	## scroll_item_for() and plant_chest_item_for(). The SHEET is swept in its own order
	## (the designer decides the id and the order decides which of two matches wins), and
	## ItemDB.ids() falls back to ITEM_DEFS when the sheet cannot be read, so one sweep is
	## correct in both worlds. "" means this plant has no item of that kind.
	for id in ItemDB.ids():
		if item_kind(id) == p_kind and item_plant(id) == p_plant_id:
			return id
	return ""

static func plant_chest_item_for(plant_id: String) -> String:
	## [P95] The chest a level's first clear hands over for this plant, "" when the
	## sheet has no such row. Rewards pays THIS id instead of the plant itself.
	return item_for_plant(ITEM_KIND_PLANT_CHEST, plant_id)

static func item_ids() -> Array[String]:
	## [P95] EVERY item id the game knows, in the order a warehouse page should list them:
	## the sheet's own order first (data/items.csv is the designer's list), then any id the
	## code table still owns that the sheet does not have. ITEM_ORDER alone is the fall-back
	## roster: it stops being the whole list the moment the sheet can add a row, and a reward
	## that pays a sheet-only item must not become invisible in the warehouse.
	var out: Array[String] = ItemDB.ids()
	for entry in ITEM_ORDER:
		var id := str(entry)
		if not out.has(id):
			out.append(id)
	return out

static func scroll_item_for(plant_id: String) -> String:
	## Which item unlocks this plant's card ("" when the plant has no scroll).
	## [P95] One sweep of the ITEM SHEET (item_for_plant), not of this file's ITEM_DEFS:
	## every plant now owns a SECOND (spirit) scroll and 23 of those exist only as csv rows,
	## so the code table would answer "" for them and their card could never be armed.
	return item_for_plant("scroll", plant_id)

static func plant_rarity(plant_id: String) -> String:
	## [P95] A spirit copy wears its base's rarity (it is the same plant; only the summon
	## path differs), so the lookup goes through the same de-prefixed key plant_def() uses.
	## [P105] THE SHEET IS THE SOURCE: the tier is the `rarity` cell of the plant's row on
	## units.csv. A row that leaves the cell blank falls back to PLANT_DEFS' own `rarity`, and a
	## plant with no row there at all (an almanac-only plant) is common - the [Plants] self-check
	## prints where the sheet and the code row disagree ("overrides Balance").
	var key := plant_id
	var spirit := spirit_base(plant_id)
	if spirit != "":
		key = spirit
	var from_sheet := PlantDB.rarity(key)
	if from_sheet != "":
		return from_sheet
	var d: Dictionary = PLANT_DEFS.get(key, {})
	return str(d.get("rarity", RARITY_COMMON))

static func has_rarity(p_rarity: String) -> bool:
	## Is this a tier the game knows? TWO sources, both real: the SHEET (what a `rarity` cell or
	## a saved garden slot may spell) and the code VOCABULARY above - so a save file read on a
	## machine whose data/rarity.csv is missing still loads. garden.gd asks this before it
	## trusts the rarity stored in user://garden.json.
	return RarityDB.has(p_rarity) or RARITY_ORDER.has(p_rarity)

static func rarity_color(p_rarity: String) -> Color:
	## The colour of a tier, out of data/rarity.csv. Anything the sheet cannot name - a tier
	## nobody declared, a blank 颜色 cell, a sheet that did not load - is painted
	## COLOR_RARITY_NONE, so "the sheet is the source" never turns into a hole on screen.
	return RarityDB.color_of(p_rarity, COLOR_RARITY_NONE)

static func rarity_recovery_factor(p_rarity: String) -> float:
	## How much longer a plant of this tier stays DOWNED - the sheet's 恢复倍率 column, read as
	## the plain multiplier it is (1.5 = half again as long). 1.0 for a tier the sheet cannot
	## name, i.e. the 60 s baseline: "the code value stays in charge" when the sheet says nothing.
	return RarityDB.recovery_of(p_rarity, 1.0)

static func rarity_label(rarity: String) -> String:
	## [P20] 普通 / 优秀 / 稀有 / 史诗 / 传说 / 神话 in Chinese, COMMON / UNCOMMON / RARE / ... in
	## English. scripts/core/loc_names.gd owns the words; a tier with no key shows its own id.
	return Loc.t("rarity." + rarity, rarity.to_upper())

static func recovery_seconds(p_level: int, p_rarity: String) -> float:
	## How long a DOWNED plant needs to come back on its own:
	##   base x rarity factor x (1 + 0.3 per level above 1)
	## [P105] The rarity factor is the SHEET's 恢复倍率 (data/rarity.csv), so the ladder the
	## garden probe prints - 60 / 90 / 150 s for common / uncommon / rare at level 1 - is a
	## number in the sheet now, not a table in this file.
	## A common level 1 plant (the peashooter, the sunflower) is the 60 s baseline.
	var rarity_factor := rarity_recovery_factor(p_rarity)
	var level_factor := 1.0 + RECOVERY_LEVEL_STEP * float(maxi(1, p_level) - 1)
	return RECOVERY_BASE_SECONDS * rarity_factor * level_factor

# ---------------------------------------------------------------- garden (P12)
# [P108] MOVED to BalanceGarden (scripts/balance/balance_garden.gd): GARDEN_PATH / GARDEN_VERSION /
# the pages and pots (GARDEN_PAGE_SIZE, GARDEN_PAGES, GARDEN_CAPACITY, GARDEN_COLS,
# GARDEN_ROWS) and, further down this file's old layout, the starting roster, the care
# ratios, the three states and the four tool ids.

# [P14] Money + items live in their own file, next to the plant roster.
const PROFILE_PATH := "user://profile.json"
const PROFILE_VERSION := 1

# ---------------------------------------------------------------------------
# [P108] MOVED to BalanceRun (scripts/balance/balance_run.gd): ADVENTURE_DIR / CHAPTER_GLOB /
# EVENTS_FILE / RUN_PATH / RUN_VERSION / RUN_SQUAD_SLOTS / RETRY_COST_BASE /
# RETRY_COST_MAX_MULT / RUN_BASE_REWARD / RUN_CHOICE_ROLLS / RUN_CHOICE_POOL /
# RUN_TREASURE_ROLLS / RUN_REST_PATROL_MOD / RUN_REST_CAMP_MONEY / RUN_MOD_KEYS.
# ---------------------------------------------------------------------------

# [P108] MOVED to BalanceGarden: GARDEN_START_ROSTER / WATER_HEAL_RATIO /
# FERTILIZE_HEAL_RATIO / GARDEN_STATE_HEALTHY / GARDEN_STATE_WOUNDED / GARDEN_STATE_DOWNED.

# [P108] MOVED to BalanceGarden: GARDEN_TOOL_WATER / GARDEN_TOOL_FERTILIZE /
# GARDEN_TOOL_EXP / GARDEN_TOOL_TALENT / GARDEN_TOOL_KINDS.
