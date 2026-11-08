class_name AlmanacView
extends Control
## [P26] THE 图鉴 / ALMANAC: one page for the questions a player asks outside a battle -
## "which plants exist", "what am I up against", "what is this thing", "what is in this
## level".
##
## [P29-UI] THREE sections over ONE grid, plus a detail panel on the right - and TWO of
## the sections carry a smaller second row that narrows them further:
##
##   UNITS / PLANTS   data/units/plants.csv   through PlantDB (one cell per plant)
##   UNITS / ZOMBIES  data/units/zombies.csv  through ZombieDB (one cell per type)
##   ITEMS / tools - equipment - materials - currency   data/items.csv through
##          ItemDB ([P27], one cell per item; the group is derived from the row's
##          分类 through Balance.item_group_of_kind)
##   LEVELS           the level pack          through LevelList (every valid *.json)
##   [D78] PROJECTILES data/projectiles.csv    through ProjectileDB (one cell per shot) - the
##          ONE tab both modes' almanacs share: the classic page (BrawlAlmanacView) inherits this
##          section instead of writing its own, because a shot is a shot in both engines (the
##          turn engine's lane shot and the brawl's free-flight one already paint through one
##          routine and read one sheet - D56/D60).
##   [B42] ... and the shared tab carries ONE cell that is not a sheet row: the WHIRLWIND, on the
##          page whose arena can actually summon one (shows_whirlwind()). See _whirlwind_row().
##
## (Before [P29-UI] this was four equal tabs; plants and zombies are the two races of
## one question - "which units exist" - so they moved under a single UNITS section and
## became a row of their own, exactly like the race column of the P29 roster. The item
## roster got the same treatment one step down: four kind-groups on the same row.)
##
## The page owns no game state and no numbers: it asks those data layers and prints what
## comes back. That is also why it stays honest - a plant the battle cannot deploy yet
## is shown as NOT IMPLEMENTED, and a zombie mechanic the battle does not simulate is
## shown as such instead of being quietly invented here (see ZombieDB.FLAGS_SIMULATED /
## PlantDB.is_playable / ItemDB.is_battle_known).
##
## The cells are the SAME ItemGrid the warehouse and the shop use, so a click behaves
## identically on all of them. Game stays the only owner of "which screen is up"
## (HANDOFF 7.18): BACK just asks it to go back.
##
## [P27] Two display rules the page follows on purpose:
##
##   * EIGHT cells per row, in the page's OWN (smaller) cell box - Balance explains the
##     arithmetic. The block fills its band from the top, so the first row always sits
##     right under the tabs whether the tab shows one row (8 levels) or three (a full
##     page of the plant roster).
##   * The SELECTED entry's own picture is drawn in the top right corner of the detail
##     panel (plants, zombies and items; a level has no sprite). The title and the lines
##     that share those rows are narrowed to clear it, and an entry with no art simply
##     hides the box - the cell next to it already says 暂无贴图.
##   * [P28] That picture is the entry's VIEW SCENE when its sheet row registers one (the
##     tscn column, through Balance.plant_view / zombie_view): the panel then draws the
##     same body the BOARD draws, with its idle clip playing, inside a SubViewport (see
##     _set_panel_view). Failing that it draws the sprite, exactly like a board unit does.
##
## [P28] Each tab is PAGED: the cells are laid out at their full size and the page bar
## under them (PREV / "2 / 3" / NEXT, plus the mouse wheel) turns the page, instead of
## the grid shrinking its cells until the whole roster fits a box it cannot fit. How many
## cells a page holds is a property of the WINDOW (ItemGrid.capacity_for), so a smaller
## window shows fewer cells per page rather than unreadable ones; the page count follows
## from the tab's row count. The selection follows the page (see _apply_page), so the
## panel never describes an entry that is not on screen.

## [P29-UI] The page is TWO levels deep: which sub-almanac is up, and - inside UNITS -
## which race, or inside ITEMS - which kind-group. Every dispatch below matches on the
## pair (see _read_rows, _detail_lines). The two enums share the second row: only one
## of them can be up at a time, and both keep their value across section switches.
## [D78] The two sheets the projectile section reads have NO class_name on purpose (the
## "ProjectileDB doctrine": a brand-new global class is invisible to a headless run until the
## editor has rescanned the project, and a sheet reader must not depend on that). They are
## therefore preloaded BY PATH here, exactly as Projectile / BattleMain / Game do.
const ProjectileDB := preload("res://scripts/core/db/projectile_db.gd")
const StatusDB := preload("res://scripts/core/db/status_db.gd")

## [B42] THE WHIRLWIND'S ID ON THE PROJECTILE TAB. It is deliberately NOT a row of
## data/projectiles.csv: a funnel has no 轨迹, no 穿透 and no 命中状态, and writing one there would make
## every one of those cells lie (brawl_tornado.gd's header gives the same reason the object is not a
## shot). So the page gives it a synthetic id the sheet's eleven names can never collide with, and
## every read below branches on it BEFORE ProjectileDB is asked.
const TORNADO_ENTRY := "tornado"

enum Section { UNITS, ITEMS, LEVELS, PROJECTILES }
enum Race { PLANTS, ZOMBIES }
enum Group { TOOL, EQUIP, MATERIAL, CURRENCY }

var game = null                        # GameManager autoload; untyped on purpose

var _section: int = Section.UNITS
var _race: int = Race.PLANTS
var _group: int = Group.TOOL
var _title := ""
var _subtitle := ""
var _hint := ""

var _rows: Array = []
var _selected_id := ""
## [P28] Which page of the tab that is up is on screen (0-based) and how many pages that
## tab has. The capacity behind both comes from metrics_for(), i.e. from the window.
var _page: int = 0
var _page_count: int = 1
## [P75] How many times the page grid, the bar and the panel have been rebuilt. Not used by
## the page itself - it is what `[FrontEnd]` counts to prove one open builds ONE page
## (OPTIMIZATIONS B4's third bullet: refresh() and _layout() each sliced the rows, so every
## open and every tab switch fed the grid twice).
var page_builds := 0
## The level list as of the last refresh (see refresh()): every tab-LEVELS readout and
## the "which levels send this zombie" map come from this one array.
var _levels: Array = []
## type id -> "Lawn 1-1, Lawn 1-8" - which levels send this zombie, rebuilt on every
## refresh (a level file edited on disk is therefore picked up by reopening the page).
var _levels_by_type: Dictionary = {}

@onready var _grid: ItemGrid = $Grid
@onready var _tabs: Array = []                  # SectionTab0..2, in scene order
@onready var _races: Array = []                 # RaceButton0..1
@onready var _groups: Array = []                # GroupButton0..3
@onready var _panel_title: Label = $PanelTitle
@onready var _panel_lines: Array = []           # PanelLine0..8, in scene order
@onready var _desc_label: Label = $DescLabel
@onready var _back: Button = $Back
var _panel_rect := Rect2()
## [P28] The page bar: two buttons and the "2 / 3" between them. Placed and audited
## through metrics_for() like every other box of this page.
@onready var _prev: Button = $Prev
@onready var _next: Button = $Next
@onready var _page_label: Label = $PageLabel
## [P27] The selected entry's picture: its texture plus (for a talent potion) the plant
## mark drawn over it, exactly the two layers the item cells composite.
var _art_texture: Texture2D = null
var _art_mark: Texture2D = null
	## [P92] the kind of the entry the panel is showing (drives the composite geometry).
var _art_kind: String = ""
## [D78] WHICH CODE-DRAWN SHOT THE PANEL IS SHOWING (the selected row's 外观), or "" when the
## selection has a texture / a view instead. A projectile has no sprite file at all, so this is
## the only way the panel can paint one - see _draw.
var _panel_look := ""
## [B32] The selected shot row's 尺寸 (px), -1 = "the picture answers for itself": _shot_zoom() has
## to scale the SAME box the painter draws, so the panel cannot show a size the board does not.
var _panel_size := -1.0
## [B40] ... and the selected row's 体型 magnitude as a multiplier (1.0 = 标准 / no word), carried for
## the same reason: the panel that shows 暖阳 has to show it BIG, or the page contradicts the board.
var _panel_tier := 1.0
## [B42] Whether the panel's picture is drawn at its OWN ratio instead of filling the box. Only the
## whirlwind row asks for it: its canvas is 256x320 while every unit / item / shot picture the panel
## draws is square, and UnitArt.draw_item_icon() stretches whatever box it is handed - a funnel would
## come out as a squashed pea, which is the opposite of what this page has just been made to say.
var _panel_fit := false
var _art_rect := Rect2()               # [P27] its box, painted (and framed) by _draw()
## [P28] ... and, for an entry whose row registers a VIEW SCENE, the scene instead of the
## two textures above. A Node2D needs a viewport of its own for its AnimationPlayer to run,
## so the scene lives in a SubViewport and _draw() paints that viewport's texture into
## _art_rect - the same body the board draws, because UnitArt.fit_view() and
## UnitArt.play_view_idle() place and start it for both.
@onready var _view_port: SubViewport = $PanelView
var _view_stage: Node2D = null         # the viewport's origin, i.e. the centre of the box
var _art_view: Node2D = null           # the loaded scene, null when the texture is drawn
var _art_view_path := ""               # which scene _art_view is, so reselecting it is free


# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_collect_and_wire()


func open_view(p_section: int = -1) -> void:
	## Called by Game.show_almanac(). A section of -1 keeps the one you were on, so
	## leaving the page and coming back does not lose your place (the race, the item
	## group and the page number are kept the same way - switching is what sends you
	## back to page 1).
	## [P107] With no section named the page opens on the one the player left it on: the TAB is
	## remembered in settings.cfg (`[ui] almanac_tab`), which is what makes a page that is freed
	## on the way out feel like it was never gone.
	if p_section >= 0 and p_section < BalanceUI.ALMANAC_TAB_COUNT:
		_section = p_section
	else:
		_section = clampi(SettingsStore.almanac_tab, 0, BalanceUI.ALMANAC_TAB_COUNT - 1)
	_selected_id = ""
	## [P75] `visible` now comes FIRST, because refresh() lays the page out and the panel
	## decides inside that pass whether its scene is being rendered (_sync_panel_view reads
	## visible). Setting it afterwards is what forced the second layout call - and that call
	## was the whole page grid built twice per open.
	visible = true
	refresh()
	## [P28] Still needed after refresh(): _set_panel_view() keeps an unchanged scene by
	## returning BEFORE it syncs the viewport, so re-opening on the same entry has to be
	## picked up here.
	_sync_panel_view()
	if _back != null and not _back.disabled:
		_back.grab_focus()


func hide_view() -> void:
	visible = false
	_sync_panel_view()       # [P28] nothing on screen -> the scene stops being rendered


func current_section() -> int:
	## [P75] Which tab the page would open on. The boot probe asks (see ScreenFlow.self_check)
	## so it can put the same one back instead of assuming UNITS is still the default.
	return _section


func restore_section(p_index: int) -> void:
	## [P75] Put the tab back WITHOUT rebuilding the page - which is the whole point: the
	## probe measures one real open on LEVELS, the one section whose detail panel has no view
	## SCENE, because restoring through open_view() would load a unit scene into a page nobody
	## is looking at and add three engine skeleton warnings to every headless boot.
	if p_index >= 0 and p_index < BalanceUI.ALMANAC_TAB_COUNT:
		_section = p_index


func on_layout_changed() -> void:
	## Driven by Game after every window size change (HANDOFF 7.12): the screen itself
	## is anchored to the full rect, only the children are re-placed.
	_layout()
	queue_redraw()


func refresh() -> void:
	## Rebuild everything this page says. Safe at any time, including right after a live
	## language switch and with no data sheet loaded at all (the rows are simply empty).
	## The level list is read ONCE per refresh and then handed to everything that needs
	## it: parsing eight level files three times per click would be wasteful.
	_levels = LevelList.discover()
	_apply_static_texts()
	_levels_by_type = _collect_levels_by_type()
	_rows = _read_rows()
	if _selected_id != "" and _find_row(_selected_id).is_empty():
		_selected_id = ""
	if _selected_id == "" and not _rows.is_empty():
		_selected_id = str((_rows[0] as Dictionary).get("id", ""))
	## [P28] The page slice, the cells and the page bar come out of ONE call, so the grid
	## can never show a page the bar does not name.
	## [P75] ... and that call lives in the layout pass, not here. It used to be made here
	## AND at the end of _layout(), while every caller of refresh() followed it with
	## on_layout_changed() - so an open, a tab switch and a language switch each fed the grid
	## and rebuilt the panel twice. The rows are now laid out exactly once per refresh, by the
	## one function that knows how many cells a page holds.
	on_layout_changed()


func _apply_static_texts() -> void:
	_title = Loc.t("almanac.title")
	_hint = Loc.t("almanac.hint")
	_subtitle = Loc.tf("almanac.subtitle",
		[PlantDB.count(), ZombieDB.count(), ItemDB.count(), _levels.size(), Balance.LEVEL_DIR])
	for i in _tabs.size():
		var btn := _tabs[i] as Button
		if btn != null:
			btn.text = _section_title(i)
	## [P29-UI] The sub-rows speak even while they are hidden (a section switch must not
	## show a wrong-language label for one frame before the text lands): same rule as
	## the tabs.
	for i in _races.size():
		var btn := _races[i] as Button
		if btn != null:
			btn.text = _race_title(i)
	for i in _groups.size():
		var btn := _groups[i] as Button
		if btn != null:
			btn.text = _group_title(i)
	if _back != null:
		_back.text = Loc.t("menu.back")
	if _prev != null:
		_prev.text = Loc.t("grid.page.prev")
	if _next != null:
		_next.text = Loc.t("grid.page.next")
	_update_tab_styles()


func _section_title(p_section: int) -> String:
	## One literal key per branch on purpose: a key built by concatenation would be
	## invisible to a key audit (the rule Balance.item_kind_label already follows).
	match p_section:
		Section.UNITS:
			return Loc.t("almanac.tab.units")
		Section.ITEMS:
			return Loc.t("almanac.tab.items")
		Section.PROJECTILES:
			return Loc.t("almanac.tab.projectiles")
	return Loc.t("almanac.tab.levels")


func _race_title(p_race: int) -> String:
	## [P29-UI] The literal-key rule again, one step down the page.
	if p_race == Race.ZOMBIES:
		return Loc.t("almanac.race.zombies")
	return Loc.t("almanac.race.plants")


func _group_title(p_group: int) -> String:
	## [P29-UI] The ITEMS section's second row: the four kind-groups. Literal keys, and
	## they are the GROUP words (almanac.group.*), not the item-kind words - a scroll is
	## a material here while its TYPE line still says 卷轴.
	match p_group:
		Group.EQUIP:
			return Loc.t("almanac.group.equip")
		Group.MATERIAL:
			return Loc.t("almanac.group.material")
		Group.CURRENCY:
			return Loc.t("almanac.group.currency")
	return Loc.t("almanac.group.tool")


func _group_key() -> String:
	## The Balance.ITEM_GROUPS key of the group button that is up - the data-side twin of
	## _group_title()'s Loc key, again one literal per branch.
	return _group_key_of(_group)


static func _group_key_of(p_group: int) -> String:
	## [P92] The same answer for a group NUMBER, so the boot self-check can walk every
	## group's rows without a page instance (see item_rows_for).
	match p_group:
		Group.EQUIP:
			return "equip"
		Group.MATERIAL:
			return "material"
		Group.CURRENCY:
			return "currency"
	return "tool"


func _update_tab_styles() -> void:
	## The tab you are on is gold and the others are dim: the same "this is the
	## selected one" colour the tile grid uses, so the page reads consistently.
	## [P29-UI] The race row is styled identically - it is the same "which one is up"
	## question, one level deeper.
	for i in _tabs.size():
		var btn := _tabs[i] as Button
		if btn == null:
			continue
		btn.add_theme_color_override("font_color",
			BalanceUI.COLOR_ALMANAC_TAB_ON if i == _section else BalanceUI.COLOR_ALMANAC_TAB_OFF)
		btn.add_theme_color_override("font_hover_color", BalanceUI.COLOR_TEXT)
	for i in _races.size():
		var btn := _races[i] as Button
		if btn == null:
			continue
		btn.add_theme_color_override("font_color",
			BalanceUI.COLOR_ALMANAC_TAB_ON if i == _race else BalanceUI.COLOR_ALMANAC_TAB_OFF)
		btn.add_theme_color_override("font_hover_color", BalanceUI.COLOR_TEXT)
	for i in _groups.size():
		var btn := _groups[i] as Button
		if btn == null:
			continue
		btn.add_theme_color_override("font_color",
			BalanceUI.COLOR_ALMANAC_TAB_ON if i == _group else BalanceUI.COLOR_ALMANAC_TAB_OFF)
		btn.add_theme_color_override("font_hover_color", BalanceUI.COLOR_TEXT)


# ---------------------------------------------------------------- the rows
func _read_rows() -> Array:
	match _section:
		Section.ITEMS:
			return _item_rows()      # [P29-UI] filtered by the group row
		Section.LEVELS:
			return _level_rows()
		Section.PROJECTILES:
			return _projectile_rows()
	## [P29-UI] UNITS is the other section with a second question to answer: which race.
	return _zombie_rows() if _race == Race.ZOMBIES else _plant_rows()


func _plant_rows() -> Array:
	## [D76] ...and a plant the sheet keeps OUT of this mode is not listed here at all: the
	## units.csv `turned` column is what "introduced in the turn mode" means, and it defaults to
	## yes for every plant through the race's own default row (so this filter changes nothing
	## until a row is deliberately flagged 0 - which is exactly what a filter should do).
	var out: Array = []
	for id in PlantDB.ids():
		if not UnitSheet.turned(id):
			continue
		var summonable := PlantDB.is_playable(id)
		var cost := PlantDB.cost(id)
		out.append({
			"id": id,
			"title": PlantDB.name(id),
			"art": PlantDB.art(id),
			## [P28] The row's VIEW SCENE, if it registers one (the tscn column): the detail
			## panel draws that instead of "art" - the same body the board draws. The CELL
			## keeps the sprite, because a cell has room for one small picture.
			"view": Balance.plant_view(id),
			"badge": ("%d" % cost) if cost > 0 else "",
			## [P26] ONE short label per cell, most important first: what the BATTLE can
			## do with it, then whether the art folder has a picture for it yet. Two labels
			## would run past the cell width and get cut off.
			"note": _status_note(not summonable, Loc.t("almanac.value.not_implemented"),
				PlantDB.has_art(id)),
			"dimmed": not summonable,
			"badge_color": BalanceUI.COLOR_ALMANAC_BADGE_PLANT,
		})
	return out


func _zombie_rows() -> Array:
	## [D76] the zombie half of the filter above, on the same column.
	var out: Array = []
	for id in ZombieDB.ids():
		if not UnitSheet.turned(id):
			continue
		var pending := ZombieDB.unsimulated_flags(id)
		out.append({
			"id": id,
			"title": ZombieDB.name(id),
			"art": ZombieDB.art(id),
			## [P28] The type's own view scene, when its row registers one (no zombie scene
			## exists yet): the detail panel draws it instead of the sprite, as on the board.
			"view": Balance.zombie_view(id),
			"badge": str(ZombieDB.hp(id)),
			"note": _status_note(not pending.is_empty(),
				Loc.t("almanac.value.shown_only"), ZombieDB.has_art(id)),
			"dimmed": not pending.is_empty(),
			"badge_color": BalanceUI.COLOR_ALMANAC_BADGE_ZOMBIE,
		})
	return out


func _item_rows() -> Array:
	## [P27] The ITEMS tab's rows, for the group that is currently up.
	return item_rows_for(_group_key())


static func item_rows_for(p_group: String) -> Array:
	## [P27] Every row of data/items.csv (ItemDB) that belongs to ONE group, drawn with the
	## icon that row registered and the item's price as its badge.
	##
	## [P29-UI] The filtering happens here, not inside ItemDB, because the sheet stays the
	## one registry and "which sub-almanac page an item is browsed on" is derived from its
	## 分类 (Balance.item_group_of_kind). One group can legitimately be empty (the sheets
	## have no material rows today) - an empty page is what the panel says.
	##
	## [P92] STATIC, and that is the point: the boot self-check walks these very rows (all
	## four groups), so "a row carries a mark AND the kind that places it" is checked
	## headlessly. The bug this replaced - the detail panel drawing a flat icon while the
	## cells composited - lived exactly here, in a key this function forgot to emit.
	var want := p_group
	var out: Array = []
	for id in ItemDB.ids():
		if Balance.item_group_of_kind(ItemDB.get_kind(id)) != want:
			continue
		## "The battle can hand this item out" plays the part PlantDB.is_playable() has
		## on the plant tab: a row only the sheet knows is shown as 仅图鉴 and dimmed.
		var known := ItemDB.is_battle_known(id)
		var value := ItemDB.price(id)
		out.append({
			"id": id,
			"title": ItemDB.name(id),
			"art": ItemDB.art(id),
			## A talent potion (and, since P92, a summon scroll) is TWO textures everywhere
			## else in the game: the detail panel draws the same two - and it needs the KIND
			## to know WHERE the mark lands, because a bottle's cork and a scroll's page are
			## different geometry (BalanceUI.mark_geometry). Leaving this key out is exactly
			## what made the panel draw a plain icon while the cells composited correctly.
			"mark": ItemDB.mark_art(id),
			"kind": ItemDB.get_kind(id),
			"badge": str(value) if value > 0 else "",
			"note": ItemDB.kind_label(id) if known else Loc.t("almanac.value.sheet_only"),
			"dimmed": not known,
			"badge_color": BalanceUI.COLOR_ALMANAC_BADGE_ITEM,
		})
	return out


func _projectile_rows() -> Array:
	## [D78] THE PROJECTILE SUB-ALMANAC. One cell per row of data/projectiles.csv, in sheet order -
	## the shot's own facts and nothing about who fires it (that is the panel's 发射单位 line).
	## [D79] The cell carries the row's picture (ProjectileDB.art_of - the same answer the two
	## engines and the panel work from), so a cell shows the shot and not only its name; a row with
	## no 贴图 draws none, exactly as before. The badge is the speed and the note is the trajectory -
	## the two things a player compares shots by.
	var out: Array = []
	for id in ProjectileDB.ids():
		var speed := ProjectileDB.speed_of(id)
		out.append({
			"id": id,
			"title": ProjectileDB.name_of(id),
			"art": ProjectileDB.art_of(id),
			"look": ProjectileDB.look_of(id),
			## [B32] Carried like the look, because the panel's zoom has to answer the same question
			## the painter does - see _panel_size.
			"size": ProjectileDB.size_of(id),
			"size_tier": ProjectileDB.size_scale_of(id),
			"badge": str(int(speed)) if speed > 0.0 else Loc.t("almanac.value.none"),
			"note": _trajectory_text(ProjectileDB.trajectory(id)),
			"dimmed": false,
			"badge_color": BalanceUI.COLOR_ALMANAC_BADGE_SHOT,
		})
	## [B42] The whirlwind last: it is the one cell here that the sheet does not own, and the one
	## thing on the board that is bigger than every shot above.
	if shows_whirlwind():
		out.append(_whirlwind_row())
	return out


func shows_whirlwind() -> bool:
	## [B42] Whether THIS page has a whirlwind to list. The rule the page has always followed is that
	## it may only show what the mode it belongs to can actually do (PlantDB.is_playable,
	## ZombieDB.unsimulated_flags, ItemDB.is_battle_known), and the turn engine has no funnel at all -
	## so the base answer is false and only the classic/brawl page turns it on.
	return false


func _whirlwind_row() -> Dictionary:
	## [B42] THE WHIRLWIND'S CELL. Like every cell it needs a FILE to show a picture (the grid's
	## tile.setup() takes a path and has no "look" argument, which is why the eleven code-drawn shots
	## are the only cells here that can come out blank) - and a funnel HAS one since [B41]: the default
	## painter is the artist's own sprite, so the cell shows the same tornado_0 the arena spins rather
	## than an illustration this page invented. The badge is the walk pace, the shots' speed answer for
	## the same question ("how fast does it get there").
	## The picture follows the SWITCH, not the folder: if somebody puts BalanceUI.TORNADO_PAINTER on the
	## vector painter, the board no longer shows a sprite, and a cell that kept showing one would
	## contradict the 画法 line a row later on this very panel.
	var frames := BalanceUI.TORNADO_PAINTER == BalanceUI.TORNADO_PAINTER_FRAMES
	var art := Fx.melee_fx_path(str(BalanceUI.TORNADO_FRAMES[0])) if frames else ""
	return {
		"id": TORNADO_ENTRY,
		"title": Loc.t("almanac.tornado.title"),
		"art": art,
		## Keep its own ratio: this canvas is 4:5 and every other picture on the page is square.
		"fit": true,
		"badge": "%.1f" % BalanceBrawl.TORNADO_CELLS_PER_SECOND,
		"note": _whirlwind_note(art),
		"dimmed": false,
		"badge_color": BalanceUI.COLOR_ALMANAC_BADGE_SHOT,
	}


func _whirlwind_note(p_art: String) -> String:
	## [B42] The cell's one small line. A blank p_art is not 暂无贴图 - the artist's two frames ARE on
	## disk and it is the rule that is not using them - so it names the painter instead, which is also
	## the honest answer to "why is this cell empty while the eleven shots next to it are too".
	if p_art == "":
		return Loc.t("almanac.value.tornado_painter_vector")
	return _status_note(false, "", UnitArt.load_texture(p_art) != null)


static func _trajectory_text(p_trajectory: String) -> String:
	## One literal key per branch, the rule every label on this page follows: the sheet writes the
	## Chinese word and the page prints it in the player's language.
	match p_trajectory:
		ProjectileDB.TRAJ_HOMING:
			return Loc.t("almanac.shot.homing")
		ProjectileDB.TRAJ_ARC:
			return Loc.t("almanac.shot.arc")
	return Loc.t("almanac.shot.straight")


static func _yes_no(p_on: bool) -> String:
	return Loc.t("almanac.value.yes") if p_on else Loc.t("almanac.value.no")


func _status_note(p_limited: bool, p_limited_label: String, p_has_art: bool) -> String:
	## The tiny line under a cell's name: "the battle only partly implements this" wins
	## over "there is no picture for it yet", because the first one changes what happens
	## when you play and the second one is visible as an empty icon anyway.
	if p_limited:
		return p_limited_label
	if not p_has_art:
		return Loc.t("almanac.value.no_art")
	return ""


func _level_rows() -> Array:
	var out: Array = []
	for entry in _levels:
		var row: Dictionary = entry
		var id := str(row.get("id", "?"))
		var playable := bool(row.get("playable", false))
		out.append({
			"id": id,
			"title": str(row.get("name", id)),
			"art": "",
			"badge": str(int(row.get("zombies", 0))) if playable else "",
			"note": Loc.t("almanac.value.broken") if not playable else _level_note(row),
			"dimmed": not playable,
			"badge_color": BalanceUI.COLOR_MENU_MARK,
		})
	return out


func _level_note(p_row: Dictionary) -> String:
	## The tiny line under a level's name: how it ended for this player.
	if bool(p_row.get("cleared", false)):
		return Loc.t("menu.levels.cleared")
	if bool(p_row.get("last_played", false)):
		return Loc.t("menu.levels.last")
	return ""


func _collect_levels_by_type() -> Dictionary:
	## Which levels send which zombie. Built from the level list rather than from the
	## sheet, because "where do I meet a buckethead" is a question about the pack.
	var out: Dictionary = {}
	for entry in _levels:
		var row: Dictionary = entry
		if not bool(row.get("playable", false)):
			continue
		var level_name := str(row.get("name", row.get("id", "?")))
		for id in (row.get("types", []) as Array):
			var key := str(id)
			var list: Array = out.get(key, [])
			list.append(level_name)
			out[key] = list
	return out


func _find_row(p_id: String) -> Dictionary:
	## The DISPLAY row of the tab that is up (what the grid cell and the panel title
	## are built from). A level's numbers and prose live in the level list, not in this
	## row, so the LEVELS tab reads them through _find_level() instead.
	##
	## [P28] Searched over EVERY row of the tab, not only the page on screen: the panel
	## keeps describing the entry the player picked while the pages turn (_apply_page
	## explains when it does move on).
	return _find_in(_rows, p_id)


func _find_in(p_rows: Array, p_id: String) -> Dictionary:
	## The same lookup inside any list of display rows - _apply_page() asks it about the
	## page it is about to show.
	for entry in p_rows:
		var row: Dictionary = entry
		if str(row.get("id", "")) == p_id:
			return row
	return {}


func _find_level(p_id: String) -> Dictionary:
	## The LevelList row of one level: everything the LEVELS panel reads. Kept apart
	## from _find_row() on purpose - a display row is a cell, a level row is the file.
	for entry in _levels:
		var row: Dictionary = entry
		if str(row.get("id", "")) == p_id:
			return row
	return {}


# ---------------------------------------------------------------- the pages
func _apply_page(p_metrics: Dictionary) -> void:
	## [P28] Puts the CURRENT page of the tab on the grid: which cells, which of them is
	## selected, and the state of the two page buttons. Called by refresh() and by every
	## re-layout, because the window decides how many cells one page holds
	## (ItemGrid.capacity_for) - a resize therefore re-slices the same _rows instead of
	## handing the grid the whole roster again.
	##
	## The SELECTION follows the page: when the entry the panel describes is not on the
	## page that is coming up, the page's first entry takes its place. That keeps the rule
	## the page had before paging - a cell you can see is always the selected one - so the
	## panel can never be about something off screen.
	var capacity := maxi(1, int(p_metrics["capacity"]))
	_page_count = maxi(1, int(p_metrics["pages"]))
	page_builds += 1                # [P75] counted for [FrontEnd]; see `page_builds`
	_page = clampi(_page, 0, _page_count - 1)
	var start := _page * capacity
	var page_rows: Array = _rows.slice(start, mini(start + capacity, _rows.size()))
	if not page_rows.is_empty() and _find_in(page_rows, _selected_id).is_empty():
		_selected_id = str((page_rows[0] as Dictionary).get("id", ""))
	if _grid != null:
		_grid.show_items(page_rows, _selected_id)
	_update_page_bar()
	_refresh_panel()


func _update_page_bar() -> void:
	## What the bar says and which of its two buttons can be used. Both are disabled on a
	## tab that fits one page (LEVELS today), which is also how the player sees that the
	## tab is not paged - the label then reads "1 / 1".
	if _page_label != null:
		_page_label.text = Loc.tf("grid.page", [_page + 1, _page_count])
	if _prev != null:
		_prev.disabled = _page <= 0
	if _next != null:
		_next.disabled = _page >= _page_count - 1


func _turn_page(p_delta: int) -> void:
	## Shared by the two buttons and the mouse wheel. Nothing happens at either end: the
	## button is disabled there anyway and the wheel simply stops.
	var want := clampi(_page + p_delta, 0, _page_count - 1)
	if want == _page:
		return
	_page = want
	_apply_page(metrics_for(Layout.size, maxi(_rows.size(), 1)))


# ---------------------------------------------------------------- the panel
func _refresh_panel() -> void:
	if _panel_title == null:
		return
	var row := _find_row(_selected_id)
	if row.is_empty():
		_panel_title.text = Loc.t("almanac.panel.empty_title")
		_panel_title.tooltip_text = _panel_title.text
		for label in _panel_lines:
			(label as Label).text = ""
		_desc_label.text = Loc.t("almanac.panel.empty_desc")
		_panel_look = ""
		_panel_size = -1.0
		_panel_tier = 1.0
		_panel_fit = false
		_set_panel_art("")
		return
	_panel_title.text = str(row.get("title", _selected_id))
	## [P27] The narrowed title may be trimmed; the tooltip always carries the full name.
	_panel_title.tooltip_text = _panel_title.text
	var lines := _detail_lines(_selected_id)
	for i in _panel_lines.size():
		var label := _panel_lines[i] as Label
		label.text = str(lines[i]) if i < lines.size() else ""
	_desc_label.text = _description(_selected_id)
	## [P27] The picture follows the selection: the same "art" the grid cell draws, plus
	## the same plant mark when the entry is a talent potion, so the panel and the cell
	## can never disagree about which sprite an entry has. [P28] "view" is the row's scene,
	## which wins over both when it loads - see _set_panel_art().
	## [D78] The one row key that is not a FILE: a projectile carries the look its painter
	## switches on, and the panel draws that instead of loading anything (see _draw).
	## [B42] "fit" is a second key that is not a path either: it is the picture's own ratio, and
	## _draw() obeys it (see _draw_art_kept_ratio).
	_panel_look = str(row.get("look", ""))
	_panel_size = float(row.get("size", -1.0))
	_panel_tier = float(row.get("size_tier", 1.0))
	_panel_fit = bool(row.get("fit", false))
	_set_panel_art(str(row.get("art", "")), str(row.get("mark", "")), str(row.get("view", "")),
		str(row.get("kind", "")))


func _set_panel_art(p_path: String, p_mark_path: String = "", p_view_path: String = "",
		p_kind: String = "") -> void:
	## [P27] The panel's top right corner: p_path, and p_mark_path drawn over it for a
	## talent potion (two textures, like the cells). An entry with no sprite at all - a
	## level, or a plant the art folder has no file for - hides the box instead of
	## showing an empty frame: the cell already says 暂无贴图 in words.
	##
	## [P28] p_view_path is the entry's VIEW SCENE (the tscn column of its sheet row) and
	## beats the two textures: when it loads, the panel draws the scene the BOARD draws,
	## idle clip and all. Only when there is no scene (or the file is not there) do the
	## textures above get drawn, which is the same order a board unit follows.
	_art_texture = UnitArt.load_texture(p_path)
	_art_mark = UnitArt.load_texture(p_mark_path)
	## [P92] and which geometry the mark lands in: the row's kind (a potion on the cork, a
	## scroll on the parchment). A plant / zombie / level row has no kind and no mark.
	_art_kind = p_kind
	_set_panel_view(p_view_path)
	## The box and the frame around it are drawn in _draw(), so the page has to repaint
	## when the picture appears or disappears.
	queue_redraw()


func _set_panel_view(p_path: String) -> void:
	## [P28] Swap the scene behind the panel's picture. The same path is left alone, so
	## re-opening the page (or re-selecting the same entry) does not restart its idle
	## animation; a different path is rebuilt, and "" drops the scene so the sprite is
	## drawn again. A scene whose root is not a Node2D is refused here exactly like on the
	## board: the picture then falls back to the texture.
	if _view_stage == null:
		return
	if p_path == _art_view_path and _art_view != null:
		_fit_panel_view()
		return
	_art_view_path = p_path
	if _art_view != null and is_instance_valid(_art_view):
		_view_stage.remove_child(_art_view)
		_art_view.queue_free()
	_art_view = null
	var packed := UnitArt.load_scene(p_path)
	if packed != null:
		var node := packed.instantiate()
		_art_view = node as Node2D
		if _art_view == null:
			node.free()
		else:
			_view_stage.add_child(_art_view)
			_fit_panel_view()
			UnitArt.play_view_idle(_art_view)
	_sync_panel_view()


func _fit_panel_view() -> void:
	## [P28] The box centre is the stage's origin and the scene is fitted to the box by the
	## very helper the board uses (UnitArt.fit_view) - that is what makes the plant in this
	## panel the same size as the one on the lawn.
	if _art_view == null:
		return
	_view_stage.position = _art_rect.size * 0.5
	UnitArt.fit_view(_art_view, _art_rect.size.x)


func _sync_panel_view() -> void:
	## [P28] The scene is rendered only while somebody is looking at it: a hidden page, or
	## an entry whose picture is a sprite, switches the viewport off, so this costs nothing
	## while the player is in a battle or on the menu.
	if _view_port == null:
		return
	var live: bool = visible and _art_view != null
	_view_port.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED)


func _detail_lines(p_id: String) -> Array:
	match _section:
		Section.ITEMS:
			return _item_lines(p_id)
		Section.LEVELS:
			return _level_lines(p_id)
		Section.PROJECTILES:
			return _projectile_lines(p_id)
	return _zombie_lines(p_id) if _race == Race.ZOMBIES else _plant_lines(p_id)


func _shot_zoom() -> float:
	## [D78] HOW MUCH BIGGER THE PANEL DRAWS A SHOT than the board does. The picture box is 104 px
	## and a pea is 14 of them, so the true-size drawing first looked like a speck in an empty
	## frame; this scales the SAME drawing to fill ~70% of the box instead. Projectile.draw_extent()
	## owns "how big is this look", so a fifth look needs no change here - and 1.0 is the floor, so
	## a shot that already fills the box is never shrunk below its own size.
	var base := Projectile.draw_extent(_panel_look)
	## [B32] The zoom is measured against the size the BOARD would draw: a row that states a 尺寸
	## grows here exactly as it grows on the lawn, because both ask Projectile.shot_box().
	## [B40] ...and the same is true of the row's 体型 word, which is why it goes in as the fourth
	## argument rather than being multiplied in here - the page must not own a second answer.
	var extent := base * (Projectile.shot_box(_panel_look, _panel_size, Vector2.ZERO,
		_panel_tier).x / maxf(base.x, 1.0))
	var room := _art_rect.size * 0.70
	var zoom := minf(room.x / maxf(extent.x, 1.0), room.y / maxf(extent.y, 1.0))
	return clampf(zoom, 1.0, 8.0)


func _projectile_lines(p_id: String) -> Array:
	## [D78] The numbers of ONE shot, every one of them read from its sheet row through
	## ProjectileDB (the page invents none): what it flies like, how big it is, what it does on the
	## way, what it leaves behind, and who fires it. Eight lines - the panel holds nine.
	## [B40] The two SIZE lines come first among the numbers because they are the two the sheet can
	## state and the painter must obey: 尺寸 is the picture's pixels, 体型 the rung of the ladder those
	## pixels are poured into. [B42] The whirlwind that made those two lines necessary now has its own
	## cell on this tab - and its own eight lines below, because it answers to none of the cells above.
	if p_id == TORNADO_ENTRY:
		return _whirlwind_lines()
	var splash := ProjectileDB.splash_of(p_id)
	var speed := ProjectileDB.speed_of(p_id)
	return [
		Loc.tf("almanac.line.trajectory", [_trajectory_text(ProjectileDB.trajectory(p_id))]),
		Loc.tf("almanac.line.speed",
			["%d px/s" % int(speed) if speed > 0.0 else Loc.t("almanac.value.default")]),
		Loc.tf("almanac.line.size", [_size_text(p_id)]),
		Loc.tf("almanac.line.tier", [_tier_text(p_id)]),
		Loc.tf("almanac.line.riders", [ProjectileDB.pierce_of(p_id), ProjectileDB.bounce_of(p_id),
			("%d%%" % int(splash * 100.0)) if splash > 0.0 else Loc.t("almanac.value.no")]),
		Loc.tf("almanac.line.armor_pair", [_yes_no(ProjectileDB.armor_piercing(p_id)),
			_yes_no(ProjectileDB.pierce_damage(p_id))]),
		Loc.tf("almanac.line.hit_status", [_hit_status_text(p_id)]),
		Loc.tf("almanac.line.fired_by", [_fired_by(p_id)]),
	]


func _whirlwind_lines() -> Array:
	## [B42] THE WHIRLWIND'S EIGHT LINES: the same shape as a shot's, because it is browsed as one
	## thing among them, and the same rule - every number belongs to somebody else and this page only
	## asks. How far a funnel walks is each piece row's own 旋风 cell (a rule table cannot own a per-unit
	## distance); the pace, the ring, the cadence, the share and the air are BalanceBrawl's; the
	## magnitude is the very ladder a projectiles.csv 体型 cell writes; the picture is BalanceUI's.
	## [D78] There is deliberately no 尺寸 line: 尺寸 is the pixel box of a picture a SHEET registers,
	## and this funnel's size is measured from the sprite's own ink (UnitArt.ink_fractions) against the
	## ring - which is what the 风环 line below states, in CELLS. No px is printed anywhere here,
	## because the brawl cell is the window's (BrawlField.cell()) and the page must not quote a number
	## the arena is not currently using.
	var reach := BalanceBrawl.TORNADO_REACH_CELLS
	var tier := Balance.size_scale(BalanceBrawl.TORNADO_SIZE_TIER)
	return [
		Loc.tf("almanac.line.tornado_shape", [Loc.t("almanac.value.tornado_shape")]),
		Loc.tf("almanac.line.tornado_owners", [_tornado_owners()]),
		Loc.tf("almanac.line.tornado_pace",
			[Loc.tf("almanac.value.tornado_pace",
				[BalanceBrawl.TORNADO_CELLS_PER_SECOND])]),
		Loc.tf("almanac.line.tornado_ring",
			[Loc.tf("almanac.value.tornado_ring", [reach * 2.0, reach])]),
		Loc.tf("almanac.line.tier", [_tier_scale_text(BalanceBrawl.TORNADO_SIZE_TIER)]),
		Loc.tf("almanac.line.tornado_pulse",
			[Loc.tf("almanac.value.tornado_pulse", [BalanceBrawl.TORNADO_TICK_SECONDS,
				int(round(BalanceBrawl.TORNADO_TICK_SHARE * 100.0))])]),
		Loc.tf("almanac.line.tornado_air",
			[Loc.tf("almanac.value.tornado_air",
				[BalanceBrawl.TORNADO_HEIGHT_CELLS * tier])]),
		Loc.tf("almanac.line.tornado_painter", [_tornado_painter_text()]),
	]


func _tornado_owners() -> String:
	## WHO CALLS ONE UP, and with it how far THIS one walks: the distance is the row's own 旋风 cell and
	## the funnel owns none, so the honest answer to "which units summon this" has to carry a number per
	## body. The twin of _fired_by() above - which is why the walk is stated here and nowhere else.
	var names: Array = []
	for id in PieceDB.ids():
		var cells := PieceDB.tornado_cells(id)
		if cells <= 0.0:
			continue
		names.append(Loc.tf("almanac.value.tornado_owner_cells", [PieceDB.name(id), cells]))
	if names.is_empty():
		return Loc.t("almanac.value.not_implemented")
	return _joined(names)


static func _tornado_painter_text() -> String:
	## WHICH PAINTER the switch names today, and the one number that makes it a moving picture instead
	## of a still. The page prints the RULE's answer (BalanceUI.TORNADO_PAINTER) and not some node's:
	## the only way a live funnel ever ends up on the other painter is the two frames not importing,
	## and the arena's one line per bout says that out loud (docs/dev/FX.md §6b).
	if BalanceUI.TORNADO_PAINTER == BalanceUI.TORNADO_PAINTER_FRAMES:
		return Loc.tf("almanac.value.tornado_painter_frames",
			[BalanceUI.TORNADO_FRAMES.size(),
			 int(round(BalanceUI.TORNADO_FRAME_SECONDS * 1000.0))])
	return Loc.t("almanac.value.tornado_painter_vector")


static func _size_text(p_id: String) -> String:
	## HOW BIG THE PICTURE IS, in the pixels the sheet states. -1.0 is ProjectileDB's own "this row
	## says nothing", which since [B40] should only ever mean a row that has not been filled in yet:
	## every shot today states its number, so the fallback is the honest word for the asset deciding
	## (the picture is drawn at its own SVG canvas), and never a number the page invented.
	var size := ProjectileDB.size_of(p_id)
	if size <= 0.0:
		return Loc.t("almanac.value.default")
	return "%d px" % int(size)


static func _tier_text(p_id: String) -> String:
	## WHICH RUNG, and the multiplier that rung is worth - because "大" alone is a word and ×1.5 is the
	## fact the board acts on. A blank cell is not a missing number, it is the middle rung (标准 ×1.0,
	## which is why no ratio is printed beside it); an unknown word never reaches the page, the sheet's
	## own self_check() reports it at boot.
	var word := ProjectileDB.size_tier_of(p_id)
	return _tier_scale_text(word)


static func _tier_scale_text(p_word: String) -> String:
	## [B42] The wording itself, for ANY magnitude word - whoever owns it. A shot's 体型 cell and the
	## whirlwind's BalanceBrawl.TORNADO_SIZE_TIER name the same rung of the same ladder, so they have to
	## read identically; one phrase owner here is what keeps the two from drifting apart.
	var label := _size_tier_word(p_word)
	var scale := Balance.size_scale(p_word)
	return label if absf(scale - 1.0) < 0.001 else "%s ×%.2f" % [label, scale]


static func _size_tier_word(p_cell: String) -> String:
	## One literal key per rung, the rule every label on this page follows: the sheet writes the
	## Chinese word and the page prints it in the player's language.
	match p_cell:
		Balance.SIZE_TINY:
			return Loc.t("almanac.tier.tiny")
		Balance.SIZE_SMALL:
			return Loc.t("almanac.tier.small")
		Balance.SIZE_LARGE:
			return Loc.t("almanac.tier.large")
		Balance.SIZE_GIANT:
			return Loc.t("almanac.tier.giant")
	return Loc.t("almanac.tier.standard")


func _hit_status_text(p_id: String) -> String:
	## What the shot leaves ON the body it hit (a freeze, a push): the status sheet's own word plus
	## how many rounds it lasts - computed here from the same two cells ProjectileDB.effects_of()
	## hands the hit layer, so the page and the battle agree about the duration.
	var id := ProjectileDB.status_of(p_id)
	if id == "":
		return Loc.t("almanac.value.none")
	var rounds := ProjectileDB.status_value_of(p_id)
	if rounds <= 0:
		rounds = StatusDB.default_rounds(id)
	return "%s (%d)" % [StatusDB.name_of(id), rounds]


func _fired_by(p_id: String) -> String:
	## WHO FIRES IT, from the sheets that say so: every human piece whose 射弹 column names this
	## shot. Plants declare theirs in their own scripts (ShooterPlant.shot_id) and no sheet states
	## it, so a shot only the plants fire says THAT instead of pretending to have no owner
	## (BRAWL.md §11 O49 asks whether plants.csv wants the same column humans.csv has).
	var names: Array = []
	for id in PieceDB.ids():
		if PieceDB.shot(id) == p_id:
			names.append(PieceDB.name(id))
	if names.is_empty():
		return Loc.t("almanac.value.plant_only")
	return _joined(names)


func _range_type_text(p_id: String) -> String:
	## [P113] The unit's 攻击距离标签 as a localized word, "" when its row says nothing (the panel
	## then shows no line). The code stored on units.csv is melee / range; loc_names owns the word.
	var code := UnitSheet.range_type(p_id)
	if code == "":
		return ""
	return Loc.t("unit.range." + code)


func _role_text(p_id: String) -> String:
	## ...and the 功能定位标签, same blank-hides rule. dps / tank / healer / support -> loc word.
	var code := UnitSheet.role(p_id)
	if code == "":
		return ""
	return Loc.t("unit.role." + code)


func _unit_tags_text(p_id: String) -> String:
	## [P113] The two labels as ONE prose line, for the panel's DESCRIPTION block (not its
	## fixed-9 line list - those rows are full and adding two would drop 大招/行动序列). The prose
	## area wraps, so this is the layout-safe home. "" when the unit carries neither tag, so the
	## caller skips the line rather than printing a dash against an untagged row (today: the
	## reserved `default` rows only, and those are not units the panel opens on anyway).
	var rt := _range_type_text(p_id)
	var rl := _role_text(p_id)
	if rt == "" and rl == "":
		return ""
	return Loc.tf("almanac.desc.unit_tags",
		[rt if rt != "" else Loc.t("almanac.value.none"),
		 rl if rl != "" else Loc.t("almanac.value.none")])


func _plant_lines(p_id: String) -> Array:
	var summonable := PlantDB.is_playable(p_id)
	var lines: Array = []
	lines.append(Loc.tf("almanac.line.state",
		[Loc.t("almanac.value.summonable") if summonable else Loc.t("almanac.value.not_implemented")]))
	lines.append(Loc.tf("almanac.line.hp", [_number(PlantDB.hp(p_id))]))
	lines.append(Loc.tf("almanac.line.cost", [_number(PlantDB.cost(p_id))]))
	lines.append(Loc.tf("almanac.line.cooldown",
		[Loc.tf("almanac.value.rounds", [PlantDB.cooldown(p_id)])]))
	lines.append(Loc.tf("almanac.line.attack", [_number(PlantDB.attack(p_id))]))
	lines.append(Loc.tf("almanac.line.talent", [_text_or_dash(p_id, "talent")]))
	lines.append(Loc.tf("almanac.line.skill", [_text_or_dash(p_id, "skill")]))
	lines.append(Loc.tf("almanac.line.ultimate", [_text_or_dash(p_id, "ultimate")]))
	lines.append(Loc.tf("almanac.line.loadout", [_plant_loadout(p_id)]))
	return lines


func _zombie_lines(p_id: String) -> Array:
	var appears := _levels_by_type.get(p_id, []) as Array
	var pending := ZombieDB.unsimulated_flags(p_id)
	var lines: Array = []
	lines.append(Loc.tf("almanac.line.hp", [_number(ZombieDB.hp(p_id))]))
	lines.append(Loc.tf("almanac.line.armor", [_number(ZombieDB.armor(p_id))]))
	lines.append(Loc.tf("almanac.line.move",
		[Loc.tf("almanac.value.per_cell", [ZombieDB.move(p_id)])]))
	lines.append(Loc.tf("almanac.line.bite", [_number(ZombieDB.bite(p_id))]))
	lines.append(Loc.tf("almanac.line.talent", [_text_or_dash(p_id, "talent")]))
	lines.append(Loc.tf("almanac.line.skill", [_text_or_dash(p_id, "skill")]))
	lines.append(Loc.tf("almanac.line.loadout", [_zombie_loadout()]))
	lines.append(Loc.tf("almanac.line.appears", [_joined(appears)]))
	lines.append(Loc.tf("almanac.line.simulation",
		[Loc.t("almanac.value.simulated_all") if pending.is_empty()
			else Loc.tf("almanac.value.shown_only_flags", [_joined(pending)])]))
	return lines


func _item_lines(p_id: String) -> Array:
	## [P27] At most four lines, because an item has far less to say than a plant: what
	## it is, what its number means, which plant it belongs to and whether the battle
	## really knows it. A row with no number ("—" in the sheet) gets no value line at
	## all instead of a zero.
	var known := ItemDB.is_battle_known(p_id)
	var lines: Array = []
	lines.append(Loc.tf("almanac.line.state",
		[Loc.t("almanac.value.wired") if known else Loc.t("almanac.value.sheet_only")]))
	lines.append(Loc.tf("almanac.line.item_kind", [ItemDB.kind_label(p_id)]))
	var value_line := _item_price_line(p_id)
	if value_line != "":
		lines.append(Loc.tf("almanac.line.item_value", [value_line]))
	var plant_id := ItemDB.plant(p_id)
	if plant_id != "":
		lines.append(Loc.tf("almanac.line.item_plant", [PlantDB.name(plant_id)]))
	return lines


func _item_price_line(p_id: String) -> String:
	## The sheet's 价值, said in the unit that means something for THIS kind of item: a
	## coin is worth money, a scroll is spent by uses, an exp potion grants experience.
	## Anything else shows the bare number under the VALUE label.
	var value := ItemDB.price(p_id)
	if value <= 0:
		return ""
	match ItemDB.get_kind(p_id):
		"coin":
			return Loc.tf("almanac.item.value.coin", [value])
		"scroll":
			return Loc.tf("almanac.item.value.scroll", [value])
		"exp":
			return Loc.tf("almanac.item.value.exp", [value])
	return str(value)


func _level_lines(p_id: String) -> Array:
	var row := _find_level(p_id)
	if row.is_empty():
		return []
	if not bool(row.get("playable", false)):
		return [Loc.tf("almanac.line.state", [Loc.t("almanac.value.broken")])]
	var lines: Array = []
	lines.append(Loc.tf("almanac.line.difficulty",
		## [P81] The preset a level row did not name is difficulty.gd's answer, not one
		## this page spells: DEFAULT_KEY is now the only place "normal" is written.
		[Difficulty.label(str(row.get("difficulty", Difficulty.DEFAULT_KEY)))]))
	lines.append(Loc.tf("almanac.line.waves",
		[Loc.tf("almanac.value.waves", [int(row.get("wave_ids", 0)), int(row.get("waves", 0))])]))
	lines.append(Loc.tf("almanac.line.zombies",
		[Loc.tf("almanac.value.zombies", [int(row.get("zombies", 0))])]))
	lines.append(Loc.tf("almanac.line.last_round", ["T%d" % int(row.get("last_round", 0))]))
	lines.append(Loc.tf("almanac.line.sun", [str(int(row.get("sun", 0)))]))
	lines.append(Loc.tf("almanac.line.brain", [str(int(row.get("brain_hp", 0)))]))
	lines.append(Loc.tf("almanac.line.spawn_cols", [str(row.get("spawn_cols", "-"))]))
	lines.append(Loc.tf("almanac.line.summons",
		[Loc.tf("almanac.value.per_round", [int(row.get("summons", 0))])]))
	return lines


func _description(p_id: String) -> String:
	match _section:
		Section.ITEMS:
			return _item_description(p_id)
		Section.LEVELS:
			return _level_description(p_id)
		Section.PROJECTILES:
			return _projectile_description(p_id)
	return _zombie_description(p_id) if _race == Race.ZOMBIES else _plant_description(p_id)


func _item_description(p_id: String) -> String:
	## [P27] What the item is FOR (the language layer's own hint, the same one the
	## warehouse panel shows) and WHICH file its picture came from - the second line is
	## there because "the svg I put in the sheet is not the one on screen" would
	## otherwise be a silent difference (ItemDB falls back to Balance's icon table).
	var parts: PackedStringArray = []
	var hint := Balance.item_hint(p_id)
	parts.append(Loc.tf("almanac.desc.usage",
		[hint if hint != "" else Loc.t("almanac.value.none")]))
	var icon := ItemDB.art(p_id)
	var art_text := icon if icon != "" else Loc.t("almanac.value.none")
	if icon != "" and not ItemDB.art_from_sheet(p_id):
		art_text += " " + Loc.t("almanac.value.from_code")
	parts.append(Loc.tf("almanac.desc.art", [art_text]))
	return "\n".join(parts)


func _projectile_description(p_id: String) -> String:
	## [D78] What the shot DOES, in one sentence built from its own cells: the units that fire it,
	## where it goes and what it leaves behind. Nothing is invented - a plain pea reads as a plain
	## pea, which is the point of an almanac.
	if p_id == TORNADO_ENTRY:
		return _whirlwind_description()
	var parts := PackedStringArray()
	parts.append(Loc.tf("almanac.desc.fired_by", [_fired_by(p_id)]))
	parts.append(Loc.tf("almanac.desc.trajectory",
		[_trajectory_text(ProjectileDB.trajectory(p_id))]))
	if ProjectileDB.splash_of(p_id) > 0.0:
		parts.append(Loc.t("almanac.desc.splash"))
	if ProjectileDB.armor_piercing(p_id):
		parts.append(Loc.t("almanac.desc.armor"))
	if ProjectileDB.status_of(p_id) != "":
		parts.append(Loc.tf("almanac.desc.status", [_hit_status_text(p_id)]))
	return "   ".join(parts)


func _whirlwind_description() -> String:
	## [B42] What the funnel DOES, assembled the same way a shot's sentence is - out of its owners'
	## cells and constants, with no number this page made up. Four lines because four things are
	## surprising about it and a player should be told each: it is CALLED UP and not fired (the distance
	## therefore belongs to the body's row, not to the storm), it walks that distance and then stops,
	## every pulse is paid by the summoner's own blow, and the ring on the grass is exactly as wide as
	## what it hits (docs/prompt/FX.md §8).
	var parts := PackedStringArray()
	parts.append(Loc.tf("almanac.desc.tornado_who", [_tornado_owners()]))
	parts.append(Loc.t("almanac.desc.tornado_walks"))
	parts.append(Loc.t("almanac.desc.tornado_pays"))
	parts.append(Loc.t("almanac.desc.tornado_ring"))
	return "\n".join(parts)


func _plant_description(p_id: String) -> String:
	var parts: PackedStringArray = []
	## [P113] The two human labels first, so they are the headline of the prose and never the
	## part clipped at the bottom: 攻击距离 / 功能定位, straight from units.csv through the sheet.
	var tags := _unit_tags_text(p_id)
	if tags != "":
		parts.append(tags)
	parts.append(Loc.tf("almanac.desc.skill", [_name_and_effect(p_id, "skill", "skill_effect")]))
	parts.append(Loc.tf("almanac.desc.ultimate",
		[_name_and_effect(p_id, "ultimate", "ultimate_effect")]))
	parts.append(Loc.tf("almanac.desc.growth", [_growth_text(p_id)]))
	var special := PlantDB.text(p_id, "special")
	if special != "":
		parts.append(Loc.tf("almanac.desc.special", [special]))
	## [P72] The plant twin of the zombie page's line just below: the sentence above is what
	## the sheet PROMISED, this one is which of those promises the battle does not keep. The
	## items are the code's own names for the gates (PlantDB.FLAGS_KNOWN), not new copy - the
	## same choice the zombie page made with its sheet words, so the report adds no language
	## entry and cannot drift from the table it reports on. Only rows whose gate nobody runs
	## appear: unprobed prose is a developer note for the self-check log, not a claim to show
	## a player as missing.
	var pending := PlantDB.unsimulated_flags(p_id)
	if not pending.is_empty():
		parts.append(Loc.tf("almanac.desc.not_simulated", [_joined(pending)]))
	return "\n".join(parts)


func _growth_text(p_id: String) -> String:
	## [P26] The EFFECTIVE per-level numbers of a plant - what the game really applies,
	## whether it came from the sheet (HP成长 / 技能成长 / 天赋加成) or from the code
	## defaults. Only the parts that mean something to this plant are listed: a wall-nut
	## has no skill to grow and a plant without a talent potion has no boost.
	var attrs := Balance.plant_attrs(p_id)
	var parts := PackedStringArray()
	parts.append(Loc.tf("almanac.growth.hp",
		[_percent(attrs.get("hp_growth", 0.0))]))
	if int(attrs.get("skill_base", 0)) > 0:
		parts.append(Loc.tf("almanac.growth.skill",
			[_percent(attrs.get("skill_growth", 0.0))]))
	if Balance.plant_potion_item(p_id) != "":
		parts.append(Loc.tf("almanac.growth.talent",
			[_percent(attrs.get("potion_boost", 0.0))]))
	return " / ".join(parts)


func _percent(p_rate: Variant) -> int:
	return int(round(float(p_rate) * 100.0))


func _zombie_description(p_id: String) -> String:
	var parts: PackedStringArray = []
	## [P113] The two human labels first, same headline reason as the plant page above.
	var tags := _unit_tags_text(p_id)
	if tags != "":
		parts.append(tags)
	## [P26] How hard this type chews the brain, straight out of the sheet's 啃脑伤害.
	parts.append(Loc.tf("almanac.desc.brain", [ZombieDB.brain_damage(p_id)]))
	var special := ZombieDB.text(p_id, "special")
	if special != "":
		parts.append(special)
	## The sheet's own sentence vs what the battle does with it: the gap is spelled out
	## instead of being hidden, which is the whole point of listing the flags.
	var pending := ZombieDB.unsimulated_flags(p_id)
	if not pending.is_empty():
		parts.append(Loc.tf("almanac.desc.not_simulated", [_joined(pending)]))
	return "\n".join(parts)


func _level_description(p_id: String) -> String:
	var row := _find_level(p_id)
	if row.is_empty():
		return ""
	if not bool(row.get("playable", false)):
		return Loc.tf("almanac.desc.broken", [str(row.get("broken", "?"))])
	var parts: PackedStringArray = []
	parts.append(Loc.tf("almanac.desc.plan", [str(row.get("spawn_plan", "-"))]))
	parts.append(Loc.tf("almanac.desc.types", [str(row.get("types_text", "-"))]))
	parts.append(Loc.tf("almanac.desc.rewards", [str(row.get("rewards", "-"))]))
	parts.append(Loc.tf("almanac.desc.first_clear", [str(row.get("first_clear", "none"))]))
	parts.append(Loc.tf("almanac.desc.warnings", [str(row.get("warnings_text", "none"))]))
	parts.append(str(row.get("path", "")))
	return "\n".join(parts)


func _name_and_effect(p_id: String, p_name_field: String, p_effect_field: String) -> String:
	## "Pea Shot - Fires 1 pea ...", or just the effect when the sheet has no name for
	## it (a wall-nut has no skill at all, and then the line says so).
	var skill_name := PlantDB.text(p_id, p_name_field)
	var effect := PlantDB.text(p_id, p_effect_field)
	if skill_name == "" and effect == "":
		return Loc.t("almanac.value.none")
	if skill_name == "":
		return effect
	if effect == "":
		return skill_name
	return "%s - %s" % [skill_name, effect]


func _plant_loadout(p_id: String) -> String:
	## [P30-A4] The ACTION SEQUENCE a plant loads: its units.csv 技能代码 resolved
	## through Balance (the same code the live unit runs on) and priced by the
	## skill sheet. The day the player can re-fit skills, this line follows - it
	## reads the loadout, never the script.
	## [P30-B] The loaded 大招 rides the SAME line: the sheet's 大招代码, its
	## charge rule and the global cap (Balance.ULT_CHARGE_*), so the almanac says
	## exactly what the board's gold bar will do.
	var parts: PackedStringArray = []
	var code := Balance.plant_skill_code(p_id, "")
	if code != "" and SkillDB.has(code):
		parts.append(Loc.tf("almanac.value.loadout_skill",
			[SkillDB.name(code), BalanceBattle.skill_ap_cost(code)]))
	var ult := Balance.plant_ult_code(p_id, "")
	if ult != "":
		var src_key := "ult.charge.hit" if Balance.plant_ult_charge(ult) == "hit" \
			else "ult.charge.cast"
		parts.append(Loc.tf("almanac.value.loadout_ult",
			[SkillDB.ult_name(ult), BalanceBattle.ULT_CHARGE_PER_CAST, BalanceBattle.ULT_CHARGE_MAX,
				Loc.t(src_key)]))
	if parts.is_empty():
		return Loc.t("almanac.value.none")
	return Loc.t("almanac.value.loadout_sep").join(parts)


func _zombie_loadout() -> String:
	## [P30-A4] Zombies act from one fixed trio (walk / bite / eat brain); the AP
	## prices are the global rules in Balance, shown here so both rosters answer
	## the same question the same way.
	return Loc.tf("almanac.value.loadout_zombie", [
		BalanceBattle.ZOMBIE_MOVE_COST, BalanceBattle.ZOMBIE_BITE_COST, BalanceBattle.ZOMBIE_EAT_BRAIN_COST])


func _text_or_dash(p_id: String, p_field: String) -> String:
	## [P29-UI] Reached only from the unit builders (_plant_lines / _zombie_lines), so
	## the race - not the section - decides which sheet the field comes from.
	var text := ""
	if _section == Section.UNITS:
		text = ZombieDB.text(p_id, p_field) if _race == Race.ZOMBIES \
			else PlantDB.text(p_id, p_field)
	return text if text != "" else Loc.t("almanac.value.none")


func _number(p_value: int) -> String:
	## The sheets write "—" for a stat that does not apply (a one-shot plant has no hp),
	## and 0 would read as "it dies at once" instead of "not applicable".
	return str(p_value) if p_value > 0 else Loc.t("almanac.value.none")


func _joined(p_items: Array) -> String:
	if p_items.is_empty():
		return Loc.t("almanac.value.none")
	var packed := PackedStringArray()
	for item in p_items:
		packed.append(str(item))
	return ", ".join(packed)


# ---------------------------------------------------------------- construction
func _collect_and_wire() -> void:
	## [P107] THE NODES COME FROM `scenes/ui/almanac.tscn`. This finds them, wires what a scene
	## cannot wire (the callbacks bound to their index) and dresses what a scene cannot dress
	## (UiStyle). Every count here is a BalanceUI constant - 3 tabs, 2 races, 4 groups, 9 panel
	## lines - which is exactly why they can live in a scene at all.
	for i in BalanceUI.ALMANAC_TAB_COUNT:
		var tab := get_node("SectionTab%d" % i) as Button
		_dress_button(tab, _on_section_pressed.bind(i))
		_tabs.append(tab)
	for i in BalanceUI.ALMANAC_RACE_COUNT:
		var race := get_node("RaceButton%d" % i) as Button
		_dress_button(race, _on_race_pressed.bind(i))
		_races.append(race)
	for i in BalanceUI.ALMANAC_GROUP_COUNT:
		var group := get_node("GroupButton%d" % i) as Button
		_dress_button(group, _on_group_pressed.bind(i))
		_groups.append(group)
	for i in BalanceUI.ALMANAC_PANEL_LINES:
		_panel_lines.append(get_node("PanelLine%d" % i) as Label)
	## [P27] This page's own cells (smaller, eight per row) and its top-aligned block: the
	## warehouse / shop / backpack keep ItemGrid's shared defaults.
	_grid.tile_size = BalanceUI.ALMANAC_TILE_SIZE
	_grid.max_cols = BalanceUI.ALMANAC_GRID_COLS
	_grid.top_align = true
	_grid.picked.connect(_on_tile_picked)
	## the labels, dressed once
	UiStyle.style_label(_panel_title, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_ITEM_PANEL_TITLE)
	## [P27] The title shares its row with the picture, so it is trimmed with an ellipsis rather
	## than allowed to run under it (the cell's tooltip keeps the whole name available).
	_panel_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for line in _panel_lines:
		UiStyle.style_label(line as Label, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			BalanceUI.FONT_SIZE_ITEM_PANEL_LINE)
	UiStyle.style_label(_desc_label, "", BalanceUI.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_ITEM_PANEL_LINE)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UiStyle.style_label(_page_label, "", BalanceUI.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER,
		BalanceUI.FONT_SIZE_MENU_SUB)
	_dress_button(_back, _on_back_pressed)
	_dress_button(_prev, _on_page_pressed.bind(-1))
	_dress_button(_next, _on_page_pressed.bind(1))
	## [P28] The panel's picture can be a SCENE (an entry whose sheet row registers a view): a
	## Node2D needs a viewport of its own for its AnimationPlayer to run, so the scene renders
	## here and _draw() paints this viewport's texture into the picture's box.
	_view_port.disable_3d = true
	_view_port.transparent_bg = true          # the cell background must show through
	_view_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view_port.size = Vector2i(int(BalanceUI.ALMANAC_PANEL_ART_SIZE),
		int(BalanceUI.ALMANAC_PANEL_ART_SIZE))


func _dress_button(btn: Button, p_pressed: Callable) -> Button:
	## [P73] The skin is UiStyle.style_button()'s now (see the note there); the TEXT is set by
	## _apply_static_texts(), which runs again after a live language switch.
	return UiStyle.style_button(btn, "", p_pressed)


# ---------------------------------------------------------------- layout
static func design_area() -> Vector2:
	## The nominal block of cells at the design window size: ALMANAC_GRID_COLS wide (the
	## [P27] eight per row the page promises, in the page's own cell box) and
	## ALMANAC_GRID_ROWS tall. metrics_for() takes only its WIDTH: the grid is handed the
	## whole band under the tabs and fills it from the top, so a tab of one row does not
	## float down the middle of the page.
	return Vector2(
		float(BalanceUI.ALMANAC_GRID_COLS) * BalanceUI.ALMANAC_TILE_SIZE.x
			+ float(BalanceUI.ALMANAC_GRID_COLS - 1) * BalanceUI.ITEM_TILE_GAP,
		float(BalanceUI.ALMANAC_GRID_ROWS) * BalanceUI.ALMANAC_TILE_SIZE.y
			+ float(BalanceUI.ALMANAC_GRID_ROWS - 1) * BalanceUI.ITEM_TILE_GAP)


static func metrics_for(p_window: Vector2, p_count: int) -> Dictionary:
	## PURE: window size and how many cells in, every box of this page out. _layout()
	## and self_check() both call it, so the audit cannot drift from the drawing
	## (the same rule GardenView.metrics_for follows).
	var area := design_area()
	var grid_top: float = BalanceUI.ALMANAC_GRID_TOP
	## [P27] The band under the tab row, i.e. the box BOTH the grid and the panel take:
	## the cells fill it from the top (ItemGrid.top_align), the panel gets its full
	## height for the eight readouts, the prose and BACK.
	var band := maxf(p_window.y - grid_top - BalanceUI.ALMANAC_BOTTOM_BAND, 96.0)
	## [P28] The page bar is carved out of that band for the GRID only, so the panel keeps
	## the band's full height and its own layout does not move. What is left decides how
	## many cells a page holds - the cells themselves stay at ALMANAC_TILE_SIZE.
	var bar_h: float = BalanceUI.ALMANAC_PAGE_BAR_H
	var grid_size := Vector2(area.x,
		maxf(band - bar_h - BalanceUI.ALMANAC_PAGE_GAP, BalanceUI.ALMANAC_TILE_SIZE.y))
	var capacity := ItemGrid.capacity_for(grid_size, BalanceUI.ALMANAC_TILE_SIZE,
		BalanceUI.ALMANAC_GRID_COLS)
	## [P28] How many pages the tab needs, i.e. how many entries it can hold - the number
	## the bar prints and the buttons clamp against. Never zero: an empty tab is "1 / 1".
	var alive := maxi(p_count, 1)
	var pages := maxi(1, int(ceil(float(alive) / float(maxi(capacity, 1)))))
	## The grid is asked to lay out ONE PAGE, never the whole roster: that is what keeps
	## the cells at their full size instead of shrinking them (see the class comment).
	var fit := ItemGrid.fit_for(grid_size, mini(alive, capacity), BalanceUI.ALMANAC_TILE_SIZE,
		BalanceUI.ALMANAC_GRID_COLS)
	var panel_w: float = BalanceUI.ITEM_PANEL_W
	var gap: float = BalanceUI.ITEM_PANEL_GAP
	var x0 := floorf((p_window.x - (grid_size.x + gap + panel_w)) * 0.5)
	var tab_w := float(BalanceUI.ALMANAC_TAB_COUNT) * BalanceUI.ALMANAC_TAB_SIZE.x \
		+ float(BalanceUI.ALMANAC_TAB_COUNT - 1) * BalanceUI.ALMANAC_TAB_GAP
	## [P29-UI] The race row: same centring rule as the tab row, one window below it. It
	## is placed whether or not UNITS is up (the row's band is reserved on every section,
	## so switching never moves the grid); only its VISIBILITY follows the section.
	var race_w := float(BalanceUI.ALMANAC_RACE_COUNT) * BalanceUI.ALMANAC_RACE_SIZE.x \
		+ float(BalanceUI.ALMANAC_RACE_COUNT - 1) * BalanceUI.ALMANAC_RACE_GAP
	## [P29-UI] The ITEMS group row: the same line as the race row (only one sub-row is
	## ever up), the same centring rule, four buttons instead of two.
	var group_w := float(BalanceUI.ALMANAC_GROUP_COUNT) * BalanceUI.ALMANAC_RACE_SIZE.x \
		+ float(BalanceUI.ALMANAC_GROUP_COUNT - 1) * BalanceUI.ALMANAC_RACE_GAP
	var panel := Rect2(Vector2(x0 + grid_size.x + gap, grid_top), Vector2(panel_w, band))
	var inset: float = BalanceUI.ITEM_PANEL_INSET
	var inner_w := panel_w - inset * 2.0
	var lines_top := grid_top + BalanceUI.ITEM_PANEL_LINES_Y
	var lines_bottom := lines_top \
		+ float(BalanceUI.ALMANAC_PANEL_LINES) * BalanceUI.ALMANAC_PANEL_LINE_STEP
	var back_h: float = BalanceUI.ITEM_PANEL_BUTTON_H
	var back_top := panel.position.y + band - BalanceUI.ITEM_PANEL_BOTTOM - back_h
	var desc_top := lines_bottom + BalanceUI.ITEM_PANEL_DESC_GAP
	var desc_h := maxf(back_top - BalanceUI.ITEM_PANEL_STATUS_GAP - desc_top,
		BalanceUI.ALMANAC_PANEL_DESC_H)
	## [P27] The selected entry's picture, in the panel's top right corner, and how much
	## of the text column it takes: the title plus every detail line that shares a row
	## with it stop at the picture's left edge. text_w is that narrowed width, floored by
	## ALMANAC_PANEL_TEXT_MIN_W so a wider picture can never squeeze the readouts away.
	var art_side: float = BalanceUI.ALMANAC_PANEL_ART_SIZE
	var art := Rect2(Vector2(panel.position.x + panel_w - inset - art_side,
		panel.position.y + BalanceUI.ALMANAC_PANEL_ART_TOP), Vector2(art_side, art_side))
	var art_bottom := art.position.y + art.size.y
	var art_rows := 0
	while art_rows < BalanceUI.ALMANAC_PANEL_LINES:
		if lines_top + float(art_rows) * BalanceUI.ALMANAC_PANEL_LINE_STEP >= art_bottom:
			break
		art_rows += 1
	var text_w := maxf(inner_w - (art_side + BalanceUI.ALMANAC_PANEL_ART_GAP),
		BalanceUI.ALMANAC_PANEL_TEXT_MIN_W)
	## [P28] The page bar: the strip sits on the SAME line as the panel's BACK button -
	## ITEM_PANEL_BOTTOM above the bottom of the band - so the two bottom controls of the
	## page line up. The label is centred between the two buttons and narrows with them
	## rather than running under them.
	var bar_top := grid_top + band - BalanceUI.ITEM_PANEL_BOTTOM - bar_h
	var btn_w: float = BalanceUI.ALMANAC_PAGE_BTN_W
	var label_w := minf(BalanceUI.ALMANAC_PAGE_LABEL_W,
		maxf(grid_size.x - btn_w * 2.0 - BalanceUI.ALMANAC_PAGE_GAP * 2.0, 60.0))
	return {
		"x0": x0,
		"y0": grid_top,
		"grid": grid_size,
		"fit": fit,
		"capacity": capacity,
		"pages": pages,
		"tab_x": floorf(x0 + (grid_size.x - tab_w) * 0.5),
		"tab_y": BalanceUI.ALMANAC_TAB_Y,
		"tab_w": tab_w,
		"tab_h": BalanceUI.ALMANAC_TAB_SIZE.y,
		"race_x": floorf(x0 + (grid_size.x - race_w) * 0.5),
		"race_y": BalanceUI.ALMANAC_RACE_Y,
		"race_w": race_w,
		"race_h": BalanceUI.ALMANAC_RACE_SIZE.y,
		"group_x": floorf(x0 + (grid_size.x - group_w) * 0.5),
		"group_w": group_w,
		"panel": panel,
		"inner_w": inner_w,
		"text_w": text_w,
		"art": art,
		"art_rows": art_rows,
		"lines_top": lines_top,
		"lines_bottom": lines_bottom,
		"page_prev": Rect2(Vector2(x0, bar_top), Vector2(btn_w, bar_h)),
		"page_next": Rect2(Vector2(x0 + grid_size.x - btn_w, bar_top), Vector2(btn_w, bar_h)),
		"page_label": Rect2(Vector2(x0 + (grid_size.x - label_w) * 0.5, bar_top),
			Vector2(label_w, bar_h)),
		"desc": Rect2(Vector2(panel.position.x + inset, desc_top), Vector2(inner_w, desc_h)),
		"back": Rect2(Vector2(panel.position.x + inset, back_top), Vector2(inner_w, back_h)),
	}


func _layout() -> void:
	if _grid == null:
		return          # a resize arriving before _ready() has built the children
	var m := metrics_for(Layout.size, maxi(_rows.size(), 1))
	var area: Vector2 = m["grid"]
	var x0 := float(m["x0"])
	var y0 := float(m["y0"])

	_grid.position = Vector2(x0, y0)
	_grid.size = area
	_grid.relayout()

	var tab_box := Vector2(BalanceUI.ALMANAC_TAB_SIZE.x, float(m["tab_h"]))
	for i in _tabs.size():
		var btn := _tabs[i] as Button
		if btn == null:
			continue
		var at := Vector2(float(m["tab_x"]) + float(i) * (tab_box.x + BalanceUI.ALMANAC_TAB_GAP),
			float(m["tab_y"]))
		btn.position = at
		btn.custom_minimum_size = tab_box
		btn.size = tab_box

	## [P29-UI] The race row under the tabs - placed on every section (its band is
	## reserved), visible only on UNITS.
	var race_box := Vector2(BalanceUI.ALMANAC_RACE_SIZE.x, float(m["race_h"]))
	var races_up: bool = _section == Section.UNITS
	for i in _races.size():
		var btn := _races[i] as Button
		if btn == null:
			continue
		btn.visible = races_up
		var at := Vector2(float(m["race_x"]) + float(i) * (race_box.x + BalanceUI.ALMANAC_RACE_GAP),
			float(m["race_y"]))
		btn.position = at
		btn.custom_minimum_size = race_box
		btn.size = race_box
	## [P29-UI] ... and the ITEMS group row on the SAME line (the two sub-rows share the
	## band, so only one of them is ever visible).
	var groups_up: bool = _section == Section.ITEMS
	for i in _groups.size():
		var btn := _groups[i] as Button
		if btn == null:
			continue
		btn.visible = groups_up
		var at := Vector2(float(m["group_x"]) + float(i) * (race_box.x + BalanceUI.ALMANAC_RACE_GAP),
			float(m["race_y"]))
		btn.position = at
		btn.custom_minimum_size = race_box
		btn.size = race_box

	_panel_rect = m["panel"]
	var panel: Rect2 = _panel_rect
	var inset: float = BalanceUI.ITEM_PANEL_INSET
	var inner_w := float(m["inner_w"])
	## [P27] The title and the detail lines that share a row with the picture stop at
	## its left edge (m["text_w"]); the lines BELOW it may use the whole panel width.
	var text_w := float(m["text_w"])
	var art_rows := int(m["art_rows"])
	_place_label(_panel_title, Vector2(panel.position.x + inset, panel.position.y + BalanceUI.ITEM_PANEL_TITLE_Y),
		Vector2(text_w, BalanceUI.ITEM_PANEL_TITLE_H))
	for i in _panel_lines.size():
		var at := Vector2(panel.position.x + inset,
			float(m["lines_top"]) + float(i) * BalanceUI.ALMANAC_PANEL_LINE_STEP)
		var line_w: float = text_w if i < art_rows else inner_w
		_place_label(_panel_lines[i] as Label, at, Vector2(line_w, BalanceUI.ITEM_PANEL_LINE_H))
	_art_rect = m["art"]
	## [P28] The panel's scene is rendered into a box of exactly this size: setting it here
	## keeps the picture and the viewport in step (and re-fits a scene that is already up)
	## if that box ever stops being a fixed constant.
	if _view_port != null:
		_view_port.size = Vector2i(maxi(1, int(_art_rect.size.x)), maxi(1, int(_art_rect.size.y)))
		_fit_panel_view()
	var desc: Rect2 = m["desc"]
	_place_label(_desc_label, desc.position, desc.size)
	var back: Rect2 = m["back"]
	if _back != null:
		_back.position = back.position
		_back.custom_minimum_size = back.size
		_back.size = back.size

	## [P28] The page bar, then the page itself: a resized window changes how many cells
	## one page holds, so _apply_page() re-slices the rows here as well as on refresh.
	var prev: Rect2 = m["page_prev"]
	var next: Rect2 = m["page_next"]
	var page_label: Rect2 = m["page_label"]
	_place_button(_prev, prev)
	_place_button(_next, next)
	_place_label(_page_label, page_label.position, page_label.size)
	_apply_page(m)


func _place_button(btn: Button, p_box: Rect2) -> void:
	if btn == null:
		return
	btn.position = p_box.position
	btn.custom_minimum_size = p_box.size
	btn.size = p_box.size


func _place_label(label: Label, pos: Vector2, box: Vector2) -> void:
	if label == null:
		return
	label.position = pos
	label.size = box


# ---------------------------------------------------------------- callbacks
func _on_tile_picked(p_id: String) -> void:
	_selected_id = p_id
	if _grid != null:
		_grid.select(p_id)
	_refresh_panel()


func _on_section_pressed(p_index: int) -> void:
	## Switching sub-almanac. Neither sub-row is reset with it: coming back to UNITS
	## puts you on the race you were reading, and coming back to ITEMS on the group you
	## were reading - exactly like the section itself is remembered.
	if p_index == _section:
		return
	_section = p_index
	SettingsStore.set_almanac_tab(p_index)     # [P107] the tab outlives the page object
	## The selection is NOT carried across sections: a plant id means nothing in the
	## level list, and refresh() would have dropped it anyway. The PAGE is reset with it -
	## a plant tab on page 3 must not open the item tab on page 3 of twelve.
	_selected_id = ""
	_page = 0
	refresh()


func _on_race_pressed(p_index: int) -> void:
	## [P29-UI] The same reset, one level down: plants on page 3 must not open the
	## zombie race on page 3 of two.
	if p_index == _race:
		return
	_race = p_index
	_selected_id = ""
	_page = 0
	refresh()


func _on_group_pressed(p_index: int) -> void:
	## [P29-UI] ... and the ITEMS twin of it: the group row narrows the item roster the
	## way the race row narrows the units.
	if p_index == _group:
		return
	_group = p_index
	_selected_id = ""
	_page = 0
	refresh()


func _on_page_pressed(p_delta: int) -> void:
	_turn_page(p_delta)


func _gui_input(p_event: InputEvent) -> void:
	## [P28] The wheel turns the page too: inside a grid of cells "wheel down = further
	## down the list" is what a player tries first, and the two buttons stay the
	## discoverable way (they are also what the keyboard reaches through focus).
	var mb := p_event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_turn_page(1)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_turn_page(-1)
		accept_event()


func _on_back_pressed() -> void:
	if game != null:
		game.back_from_front_end()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := Layout.size.x
	var h := Layout.size.y
	draw_rect(Rect2(0.0, 0.0, w, h), BalanceUI.COLOR_MENU_BG)
	draw_string(font, Vector2(0.0, BalanceUI.MENU_TITLE_Y), _title, HORIZONTAL_ALIGNMENT_CENTER,
		w, BalanceUI.FONT_SIZE_MENU_TITLE, BalanceUI.COLOR_MENU_TITLE)
	draw_string(font, Vector2(0.0, BalanceUI.MENU_TITLE_Y + BalanceUI.MENU_SUB_OFFSET), _subtitle,
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	# the detail panel is painted here, i.e. UNDER its own labels and buttons
	draw_rect(_panel_rect, BalanceUI.OVERLAY_PANEL_BG)
	draw_rect(_panel_rect, BalanceUI.OVERLAY_PANEL_BORDER, false, BalanceUI.OVERLAY_PANEL_BORDER_WIDTH)
	## [P27] The selected entry's picture, in the panel's top right corner: the cell's
	## own background and frame, then the icon inside them. A talent potion is the tier
	## bottle PLUS the plant mark, which is what UnitArt.draw_potion_icon() composites -
	## the very helper the warehouse / shop / backpack / garden icons go through, so one
	## potion looks the same everywhere. An entry with no sprite draws no box at all.
	##
	## [P28] An entry whose row registers a VIEW SCENE draws the SCENE here instead: the
	## panel's SubViewport texture, stretched over the same box (its size is the box's), so
	## the panel shows the very body the board shows - and, because a ViewportTexture keeps
	## updating under a retained draw command, its idle animation plays without this page
	## having to repaint. Items and levels have no scene and keep the texture path.
	if _art_view != null and _view_port != null:
		draw_rect(_art_rect, BalanceUI.COLOR_ITEM_TILE_BG)
		draw_texture_rect(_view_port.get_texture(), _art_rect, false)
		draw_rect(_art_rect, BalanceUI.COLOR_ITEM_TILE_BORDER, false, BalanceUI.ITEM_TILE_BORDER_W)
	elif _art_texture != null:
		draw_rect(_art_rect, BalanceUI.COLOR_ITEM_TILE_BG)
		## [P92] the almanac composes the very same two layers the cells do, with the kind's
		## own geometry - so the big picture of a scroll shows the plant it unlocks.
		## [B42] ... unless the row says its picture is not square, in which case the same texture is
		## drawn at its own ratio (a whirlwind is the only such row today).
		if _panel_fit:
			_draw_art_kept_ratio()
		else:
			UnitArt.draw_item_icon(self, _art_rect, _art_texture, _art_mark, _art_kind)
		draw_rect(_art_rect, BalanceUI.COLOR_ITEM_TILE_BORDER, false, BalanceUI.ITEM_TILE_BORDER_W)
	elif _panel_look != "":
		## [D78] A SHOT HAS NO PICTURE FILE - it is drawn by code, and the page draws it with the
		## very routine the two flights paint through (Projectile.draw_shot), so what the panel
		## shows IS the arrow the game fires rather than an illustration of one. The tint is the
		## page's neutral (the board uses the shooter's own colour) and the heading is "right",
		## the direction a lane shot always flies.
		draw_rect(_art_rect, BalanceUI.COLOR_ITEM_TILE_BG)
		Projectile.draw_shot(self, _panel_look, BalanceUI.COLOR_ALMANAC_SHOT_TINT, Vector2.RIGHT,
			ProjectileDB.splash_of(_selected_id), _art_rect.get_center(), _shot_zoom(),
			ProjectileDB.art_of(_selected_id), _panel_size, _panel_tier)
		draw_rect(_art_rect, BalanceUI.COLOR_ITEM_TILE_BORDER, false, BalanceUI.ITEM_TILE_BORDER_W)
	draw_string(font, Vector2(0.0, h - BalanceUI.MENU_HINT_BOTTOM_MARGIN),
		UiStyle.fit_text(font, _hint, BalanceUI.FONT_SIZE_MENU_SUB, w - BalanceUI.HUD_SIDE_MARGIN * 2.0),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)


func _draw_art_kept_ratio() -> void:
	## [B42] THE PANEL'S PICTURE AT ITS OWN RATIO: the largest box of the same shape that still fits
	## _art_rect, centred in it. UnitArt.draw_item_icon() FILLS the box it is handed, which is right for
	## every square canvas on this page and wrong for the whirlwind's 256x320 - squashing a funnel into
	## a square is the one thing this entry must not do, because being tall is the whole claim its 体型
	## and its 高度 lines make. Requires _art_texture, which the caller has just checked.
	var side := _art_texture.get_size()
	var zoom := minf(_art_rect.size.x / maxf(side.x, 1.0), _art_rect.size.y / maxf(side.y, 1.0))
	var want := side * zoom
	draw_texture_rect(_art_texture, Rect2(_art_rect.get_center() - want * 0.5, want), false)


## ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game, next to the other self-checks: the page's
	## arithmetic without opening it. It answers "does the whole roster fit its grid
	## EIGHT PER ROW", "does the tab row clear the subtitle and the grid", "do the
	## eight lines, the prose block and BACK all stay inside the panel" and [P27] "does
	## the selected entry's picture fit the panel's top right corner without covering a
	## readout" - the ways this layout could quietly break when a constant is nudged.
	##
	## [P28] It also audits PAGING: every entry of a tab is on some page (capacity x
	## pages >= rows), a page of the design window holds ALMANAC_GRID_COLS x
	## ALMANAC_GRID_ROWS cells, those cells really fit the box they are drawn in and are
	## NOT shrunk (the bug the paging replaced: 49 plants at scale 0.55 overflowed the
	## clipped grid), and the page bar sits between the cells and the bottom of the band.
	##
	## [P29-UI] ... and the SECOND header row: the race buttons must sit between the tab
	## row and the grid and fit the cell column, on every section (the band is reserved
	## even where the row is hidden, so switching never moves the grid).
	print("[Almanac] --- three sections, two sub-rows, one grid, one panel (P26-P29-UI) ---")
	print("[Almanac] design grid %dx%d, cell %dx%d, window %dx%d, tabs %d x %dx%d, sub row %dx%d: races %d, groups %d"
		% [int(design_area().x), int(design_area().y),
		   int(BalanceUI.ALMANAC_TILE_SIZE.x), int(BalanceUI.ALMANAC_TILE_SIZE.y),
		   Balance.WINDOW_SIZE.x, Balance.WINDOW_SIZE.y,
		   BalanceUI.ALMANAC_TAB_COUNT, int(BalanceUI.ALMANAC_TAB_SIZE.x),
		   int(BalanceUI.ALMANAC_TAB_SIZE.y),
		   int(BalanceUI.ALMANAC_RACE_SIZE.x), int(BalanceUI.ALMANAC_RACE_SIZE.y),
		   BalanceUI.ALMANAC_RACE_COUNT, BalanceUI.ALMANAC_GROUP_COUNT])
	print("[Almanac] page bar %d px + %d gap under the cells, buttons %d wide"
		% [int(BalanceUI.ALMANAC_PAGE_BAR_H), int(BalanceUI.ALMANAC_PAGE_GAP),
		   int(BalanceUI.ALMANAC_PAGE_BTN_W)])
	## [P28] How many entries can put a SCENE in the panel's picture instead of a sprite.
	## The same count the board reports ([Art] unit views: ...): an entry with one is drawn
	## by the tscn of its own row, here and on the lawn alike, and the rest falls back to
	## the sprite. Informational - "no scene yet" is the ordinary state, not a failure.
	print("[Almanac] panel picture: %d plant(s) and %d zombie type(s) have a view scene, the rest draw their sprite"
		% [PlantDB.view_count(), ZombieDB.view_count()])
	var ok := true
	## [P92] A composite icon is TWO textures and the KIND that says where the second one
	## lands. The cells ask the item DB themselves, so they composited correctly while the
	## DETAIL PANEL drew a plain icon - its rows simply did not carry the kind. This claim
	## is that bug class rather than that bug: any row that carries a mark must name a kind
	## whose geometry exists, or the mark is loaded and never drawn.
	## Walk the rows the PAGE really builds, all four groups of them: a row that carries a
	## mark must name a kind whose geometry exists, or the panel loads a texture it can
	## never draw (that was P92's bug, one missing key in item_rows_for()).
	var marks := 0
	var unplaced := PackedStringArray()
	for group_index in BalanceUI.ALMANAC_GROUP_COUNT:
		for entry in item_rows_for(_group_key_of(group_index)):
			var row: Dictionary = entry
			if str(row.get("mark", "")) == "":
				continue
			marks += 1
			if BalanceUI.mark_geometry(str(row.get("kind", ""))).is_empty():
				unplaced.append(str(row.get("id", "?")))
	var marks_ok: bool = unplaced.is_empty()
	ok = ok and marks_ok
	print("[Almanac] %d item row(s) carry a plant mark, and every one names a kind its geometry knows (%s) = %s | %s"
		% [marks, ("all placed" if marks_ok else ", ".join(unplaced)), str(marks_ok),
		   "OK" if marks_ok else "FAIL"])
	var window := Vector2(Balance.WINDOW_SIZE)
	var subtitle_bottom: float = BalanceUI.MENU_TITLE_Y + BalanceUI.MENU_SUB_OFFSET
	## Every count the page can really show: the biggest is a roster, the smallest is
	## the one-cell case (a broken level list).
	var counts: Array = [
		{"label": "plants ", "count": PlantDB.count()},
		{"label": "zombies", "count": ZombieDB.count()},
		{"label": "items  ", "count": ItemDB.count()},
		{"label": "levels ", "count": LevelList.discover().size()},
	]
	for entry in counts:
		var row: Dictionary = entry
		var count := int(row["count"])
		var m := metrics_for(window, maxi(count, 1))
		var grid: Vector2 = m["grid"]
		var fit: Dictionary = m["fit"]
		var panel: Rect2 = m["panel"]
		var back: Rect2 = m["back"]
		var desc: Rect2 = m["desc"]
		var art: Rect2 = m["art"]
		var cols := int(fit["cols"])
		var rows := int(fit["rows"])
		var tile: Vector2 = fit["tile"]
		var block: Vector2 = fit["block"]
		var capacity := int(m["capacity"])
		var pages := int(m["pages"])
		var prev: Rect2 = m["page_prev"]
		var next: Rect2 = m["page_next"]
		var page_label: Rect2 = m["page_label"]
		var fits: bool = float(m["x0"]) >= 0.0 \
			and float(m["x0"]) + grid.x + BalanceUI.ITEM_PANEL_GAP + panel.size.x <= window.x + 0.5
		var on_screen: bool = float(m["y0"]) + grid.y <= window.y - BalanceUI.ALMANAC_BOTTOM_BAND + 0.5
		## [P28] EVERY entry is reachable: the pages together hold the whole tab. The old
		## "the cells fit one box" test is now split in two - the page's own cells must fit
		## the grid box they are drawn in (block), and the cells must still be FULL size
		## (scale 1), which is exactly what paging buys over shrinking the whole roster.
		var holds: bool = capacity * pages >= maxi(count, 1)
		var full_size: bool = is_equal_approx(float(fit["scale"]), 1.0)
		var block_fits: bool = block.x <= grid.x + 0.5 and block.y <= grid.y + 0.5
		## The page bar: below the page's own cells, inside the band (i.e. above the hint
		## line), with both buttons inside the cell column and the label between them.
		var bar_ok: bool = prev.position.y >= float(m["y0"]) + block.y - 0.5 \
			and prev.position.y >= float(m["y0"]) \
			and prev.position.y + prev.size.y <= panel.position.y + panel.size.y + 0.5 \
			and prev.position.x >= float(m["x0"]) - 0.5 \
			and next.position.x + next.size.x <= float(m["x0"]) + grid.x + 0.5 \
			and page_label.position.x >= prev.position.x + prev.size.x - 0.5 \
			and page_label.position.x + page_label.size.x <= next.position.x + 0.5
		## [P29-UI] Both header rows in one test: tabs under the subtitle, the sub-row
		## (race or group - they share the line) under the tabs, the grid under both -
		## and each row narrow enough for the cell column.
		var tabs_clear: bool = float(m["tab_y"]) >= subtitle_bottom \
			and float(m["tab_y"]) + float(m["tab_h"]) <= float(m["race_y"]) \
			and float(m["race_y"]) + float(m["race_h"]) <= float(m["y0"])
		var tabs_fit: bool = float(m["tab_x"]) >= 0.0 \
			and float(m["tab_x"]) + float(m["tab_w"]) <= window.x \
			and float(m["tab_w"]) <= grid.x + 0.5 \
			and float(m["race_x"]) >= 0.0 \
			and float(m["race_x"]) + float(m["race_w"]) <= window.x \
			and float(m["race_w"]) <= grid.x + 0.5 \
			and float(m["group_x"]) >= 0.0 \
			and float(m["group_x"]) + float(m["group_w"]) <= window.x \
			and float(m["group_w"]) <= grid.x + 0.5
		var panel_ok: bool = float(m["lines_bottom"]) <= desc.position.y \
			and desc.position.y + desc.size.y <= back.position.y \
			and back.position.y + back.size.y <= panel.position.y + panel.size.y
		## [P27] ALMANAC_GRID_COLS cells per row (fewer only when the tab - or the page it
		## fits on - really holds fewer entries).
		var page_cells := mini(maxi(count, 1), capacity)
		var per_row: bool = cols == mini(page_cells, BalanceUI.ALMANAC_GRID_COLS)
		## [P28] ... and the design promise behind the capacity: a page of the DESIGN
		## window holds ALMANAC_GRID_COLS x ALMANAC_GRID_ROWS cells.
		var design_page: bool = capacity == BalanceUI.ALMANAC_GRID_COLS * BalanceUI.ALMANAC_GRID_ROWS
		var art_ok: bool = art.position.x >= panel.position.x \
			and art.position.x + art.size.x <= panel.position.x + panel.size.x \
			and art.position.y >= panel.position.y \
			and art.position.y + art.size.y <= desc.position.y \
			and float(m["text_w"]) >= BalanceUI.ALMANAC_PANEL_TEXT_MIN_W - 0.5 \
			and int(m["art_rows"]) <= BalanceUI.ALMANAC_PANEL_LINES
		var good: bool = fits and on_screen and holds and tabs_clear and tabs_fit \
			and panel_ok and per_row and art_ok \
			and full_size and block_fits and bar_ok and design_page
		ok = ok and good
		print("[Almanac] %s %2d cell(s) -> %d page(s) of %d, %dx%d of %dx%d at (%d,%d), scale %.2f, art %dpx | %s"
			% [row["label"], count, pages, capacity, cols, rows, int(tile.x), int(tile.y),
			   int(m["x0"]), int(m["y0"]), float(fit["scale"]), int(art.size.x),
			   "OK" if good else "FAIL"])
		if not good:
			print("[Almanac]   fits=%s on_screen=%s holds=%s tabs=%s/%s panel=%s per_row=%s art=%s"
				% [str(fits), str(on_screen), str(holds), str(tabs_clear), str(tabs_fit),
				   str(panel_ok), str(per_row), str(art_ok)])
			print("[Almanac]   full_size=%s block_fits=%s bar=%s design_page=%s"
				% [str(full_size), str(block_fits), str(bar_ok), str(design_page)])
	## The buttons of ALL header rows must not read as their own keys: that is what a
	## missing Loc entry looks like, and three tabs saying "almanac.tab.units" is
	## exactly the bug this catches. Two buttons OF THE SAME ROW sharing a word is the
	## other half of the check - within a row the words must differ. Across rows a
	## repeat is fine, and [P29-UI] one is even intended: the ITEMS tab and the item
	## group row's first button both say 道具 (the section IS the catch-all group).
	var sections := PackedStringArray()
	var races := PackedStringArray()
	var groups := PackedStringArray()
	var tabs_ok := true
	for i in BalanceUI.ALMANAC_TAB_COUNT:
		var key := ""
		match i:
			Section.UNITS:
				key = "almanac.tab.units"
			Section.ITEMS:
				key = "almanac.tab.items"
			_:
				key = "almanac.tab.levels"
		var text := Loc.t(key)
		sections.append(text)
		tabs_ok = tabs_ok and text != key and not sections.slice(0, sections.size() - 1).has(text)
	for i in BalanceUI.ALMANAC_RACE_COUNT:
		var key := "almanac.race.zombies" if i == Race.ZOMBIES else "almanac.race.plants"
		var text := Loc.t(key)
		races.append(text)
		tabs_ok = tabs_ok and text != key and not races.slice(0, races.size() - 1).has(text)
	for i in BalanceUI.ALMANAC_GROUP_COUNT:
		var key := ""
		match i:
			Group.EQUIP:
				key = "almanac.group.equip"
			Group.MATERIAL:
				key = "almanac.group.material"
			Group.CURRENCY:
				key = "almanac.group.currency"
			_:
				key = "almanac.group.tool"
		var text := Loc.t(key)
		groups.append(text)
		tabs_ok = tabs_ok and text != key and not groups.slice(0, groups.size() - 1).has(text)
	ok = ok and tabs_ok
	print("[Almanac] tabs %s | races %s | groups %s | %s"
		% [", ".join(sections), ", ".join(races), ", ".join(groups),
		   "OK" if tabs_ok else "FAIL"])
	print("[Almanac] self-check %s" % ("PASSED" if ok else "FAILED"))
