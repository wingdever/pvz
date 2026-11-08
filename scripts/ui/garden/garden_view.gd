class_name GardenView
extends Control
## [P12] The garden screen: the plots holding the plants the player owns.
##
## [P107] THE PAGE IS A SCENE NOW: `scenes/ui/garden.tscn` + this file, and the three node
## classes it used to declare (`GardenPlot`, `GardenTool`, `CursorGhost`) are their own files
## next to it - a node the scene declares has to be one. The page is INSTANTIATED when it opens
## and FREED when it is left, so nothing may hold a handle to it while it is down.
##
## Why the screen exists: a plant card summons ONE random instance of its type out
## of this roster, and that instance comes home carrying its wounds. Watering and
## fertilizing are the only ways to repair a plant, so this is where a player comes
## between battles.
##
## The rules shown here live in garden.gd / Balance, never in this file:
##   WATER       +50% of max hp, capped; refused when DOWNED or already full
##   FERTILIZE   cures DOWNED and restores 50% of max hp; refused when healthy
## Both are free and unlimited, and both save immediately - care happens outside a
## battle, so no battle ledger is involved.
##
## [P24] The four care actions are ICON CELLS, not text buttons: the watering can, a
## bag of fertilizer, an EXP potion and a talent potion (the last one drawn exactly
## like the item screens draw it - generic bottle + plant mark, P23). Clicking a cell
## PICKS THE ITEM UP: the picture then follows the cursor and the next click on a pot
## uses it on THAT plant, instead of on whatever was selected before. The pot under
## the cursor is framed while an item is in hand, so it is always clear which plant a
## click is about to hit.
##
## [P25] The page is four blocks now, all of them placed by metrics_for() from
## Layout.size:
##   header    centred title + subtitle (shared with the menu)
##   tool bar  the four care cells, TOP RIGHT, level with the title
##   pots      4 x 4 = 16 cells, each as big a square as the space allows, drawn as an
##             SVG pot (assets/svg/items/garden_pot.svg) with the plant standing in it -
##             see GardenPlot._plant_ink_rect() for the pot -> plant rule
##   panel     right hand column: TYPE / LEVEL / HEALTH / STATE / TALENT values for the
##             selected plant, then the advice, then BACK
##
## Geometry follows Layout exactly like menu.gd does, so the screen survives any
## window size, and Game stays the only owner of "which screen is up" (HANDOFF 7.18).
##
## [P24] NAMING RULE for the members this screen adds: a script may NOT redefine a
## member that a native class already has - Godot refuses to parse the file at all
## ("Member "ready" redefined (original in native class 'Control')", because
## Node.ready is a signal). That is why the tool cell's flag is `in_stock` and the
## pot's click target is `is_target`. tools/member_name_check.gd checks a whole list
## of names against ClassDB in one run, without starting the game.

var game: GameManager = null                    # GameManager autoload; untyped on purpose
var profile: Profile = null
var garden: Garden = null
## [P109] The one injection this page gets is `game` (front_end_flow's `_bring_up`).
## The old local `var profile: Profile = null` was never assigned again after the page
## became a scene (P106/P107) - reading it is the Nil crash. The wallet's owner is Game.

var _title := ""
var _subtitle := ""
var _hint := ""
var _status := ""

@onready var _plots: Array = []            # Plot0..15, in scene order = slot order
var _panel_rect := Rect2()
@onready var _panel_title: Label = $PanelTitle
@onready var _panel_lines: Array = []    # PanelLine0..4, in scene order
@onready var _status_label: Label = $StatusLabel
@onready var _tools: Array = []            # Tool0..3, kind assigned from Balance
## [P24] The item in hand. Typed as Control because CursorGhost is declared below;
## the two places that talk to it cast with `as CursorGhost` (hold / drop).
@onready var _ghost: CursorGhost = $ItemInHand
@onready var _back: Button = $Back
var _selected: int = 0
## [P95] The roster is PAGED (BalanceGarden.GARDEN_PAGES pages of GARDEN_PAGE_SIZE pots): the
## grid on screen always shows ONE page, and `_page` says which. Every slot the roster
## owns is still a plain index 0..GARDEN_CAPACITY-1 - the page only decides which window
## of it the 16 plots look at, through _slot_of()/_index_of() below.
var _page := 0
@onready var _page_prev: Button = $PagePrev
@onready var _page_next: Button = $PageNext
@onready var _page_label: Label = $PageLabel
var _armed: String = ""            # [P24] "" = nothing in hand, else a tool kind
var _ghost_key: String = ""        # icon + mark the ghost currently shows
var _hover_slot: int = -1          # [P24] pot under the cursor while armed
var _recover_tick: float = 0.0      # [P14] countdown refresh accumulator


## ---------------------------------------------------------------- one pot

## ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_collect_and_wire()


func open_view() -> void:
	## Called by Game.show_garden(): re-read the roster, then come up visible.
	refresh()
	visible = true
	on_layout_changed()
	if _back != null and not _back.disabled:
		_back.grab_focus()


func hide_view() -> void:
	## [P24] An item in hand is dropped when the page goes away: coming back to a
	## picture already following the cursor would be a surprise.
	_disarm(false)
	visible = false


func _process(delta: float) -> void:
	## [P14] only while the page is up: refresh the recovery countdowns, and let a
	## plant that finished recovering stand up (the clock is wall-clock based, so
	## this also catches plants whose timer ran out while the game was closed).
	if not visible or Garden.live == null:
		return
	## [P24] every frame, not on the GARDEN_TICK: the frame on the pot under the
	## cursor has to follow the mouse, and half a second of lag would feel broken.
	_tick_armed()
	_recover_tick += delta
	if _recover_tick < BalanceUI.GARDEN_TICK:
		return
	_recover_tick = 0.0
	## [P66] OPTIMIZATIONS A4, the second half: this tick used to OWN the rule - apply the
	## recovery, save it, pick a line - which left TWO copies of "when does a pot stand up"
	## in the project (this one and Game's), and only one of them had ever been wired to the
	## save door. The page now asks the door and keeps what is genuinely its own: which
	## sentence to show, and when to redraw.
	var recovered: Array[String] = garden.recover_garden()
	if not recovered.is_empty():
		_status = recovered[0]
		refresh()
		return
	## [P38] OPTIMIZATIONS B5: a DOWNED plant is the only clock this page has (natural
	## recovery stands a pot up, nothing heals gradually - see Garden.apply_natural_
	## recovery), so with no pot downed there is nothing left to re-read and the whole
	## roster refresh used to run 2x a second for an identical picture. Every other
	## change reaches refresh() at its own site: a care action (_on_plot_picked and the
	## item handlers), a language switch, opening the page.
	if Garden.live.downed_count() > 0:
		refresh()


func on_layout_changed() -> void:
	## Driven by Game after every window size change (HANDOFF 7.12). The control
	## itself is anchored to the full rect, so only the children are re-placed.
	_layout()
	queue_redraw()


func _collect_and_wire() -> void:
	## [P107] THE NODES COME FROM `scenes/ui/garden.tscn`. This finds them, wires what a scene
	## cannot wire (signals and data) and dresses what a scene cannot dress (UiStyle). Every one
	## of them is a CONSTANT count - GARDEN_PAGE_SIZE pots, four care cells, GARDEN_PANEL_LINES
	## property lines - which is exactly why they can live in a scene at all.
	##
	## The pots stay the page's DIRECT children on purpose: `_slot_at_point()` maps a click
	## through the page's own coordinate space (docs/PITFALLS.md), and a container in between
	## would move that origin. In both lists SCENE ORDER IS THE CONTRACT: pot order is slot
	## order, and the care cells take their kind from Balance rather than from the scene.
	for child in get_children():
		if child is GardenPlot:
			var plot := child as GardenPlot
			plot.picked.connect(_on_plot_picked)
			plot.drop_requested.connect(_on_drop_requested)
			_plots.append(plot)
		elif child is GardenTool:
			var tool := child as GardenTool
			tool.kind = str(BalanceGarden.GARDEN_TOOL_KINDS[_tools.size()])
			tool.picked.connect(_on_tool_picked)
			_tools.append(tool)
	for i in BalanceUI.GARDEN_PANEL_LINES:
		_panel_lines.append(get_node("PanelLine%d" % i) as Label)
	## the labels and buttons the scene declares, dressed once (they were built by hand before)
	UiStyle.style_label(_panel_title, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_GARDEN_TITLE)
	UiStyle.style_label(_page_label, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER,
		BalanceUI.FONT_SIZE_BUTTON)
	UiStyle.style_label(_status_label, "", BalanceUI.COLOR_MESSAGE, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_GARDEN_LINE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for line in _panel_lines:
		UiStyle.style_label(line as Label, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			BalanceUI.FONT_SIZE_GARDEN_LINE)
	_dress_button(_back, _on_back)
	_dress_button(_page_prev, func() -> void: _turn_page(-1))
	_dress_button(_page_next, func() -> void: _turn_page(1))
	_ghost.visible = false
	_apply_static_texts()

func _dress_button(btn: Button, p_pressed: Callable) -> Button:
	## [P73] UiStyle.style_button() wears this page's colour; the 0.12 hover lift is this page's
	## own and stays here (the HUD's RETREAT lifts by 0.14 - see UiStyle.colored_styles). [P107]
	## the TEXT is not set here: _apply_static_texts() owns every word this page says, and it
	## runs again after a live language switch.
	return UiStyle.style_button(btn, "", p_pressed, BalanceUI.FONT_SIZE_BUTTON,
		Control.FOCUS_ALL, UiStyle.colored_styles(BalanceUI.COLOR_BTN_BG, 0.12, 0.16))

## ---------------------------------------------------------------- content
func _apply_static_texts() -> void:
	## [P20] Everything this page says that does NOT depend on the selected plot.
	## It is re-applied on every refresh() (and therefore also after a live language
	## switch) instead of being assigned once in _ready(); _refresh_panel() then
	## refines the four tool cells with their current state.
	_title = Loc.t("garden.title")
	_hint = Loc.t("garden.hint")
	if _back != null:
		_back.text = Loc.t("garden.back")
	for entry in _tools:
		var tool := entry as GardenTool
		if tool != null:
			tool.title = _tool_title(tool.kind)
	## [P95] the page bar is chrome too, and both of its labels are localized
	if _page_prev != null:
		_page_prev.text = Loc.t("grid.page.prev")
		_page_prev.tooltip_text = Loc.t("grid.page.prev")
	if _page_next != null:
		_page_next.text = Loc.t("grid.page.next")
		_page_next.tooltip_text = Loc.t("grid.page.next")
	_update_page_bar()


func refresh() -> void:
	## Re-reads Garden.live into the plots. Called on open, after every care action
	## and after a live language switch, so the screen can never show a stale roster
	## or a stale language.
	_apply_static_texts()
	if Garden.live == null:
		return
	for i in _plots.size():
		var plot := _plots[i] as GardenPlot
		if plot == null:
			continue
		var slot := _slot_of(i)          # [P95] the plot shows the slot, not the position
		var info: Dictionary = Garden.live.slot_at(slot)
		var filled: bool = not info.is_empty()
		var type_id := ""
		var plant_label := ""
		var hp := 0
		var max_hp := 1
		var downed := false
		var level := 1
		var rarity := Balance.RARITY_COMMON
		var recover_left := 0.0
		if filled:
			type_id = str(info["type"])
			plant_label = Balance.plant_name(type_id)
			hp = int(info["hp"])
			max_hp = int(info["max_hp"])
			downed = bool(info["downed"])
			level = int(info["level"])
			rarity = str(info["rarity"])
			if downed:
				recover_left = Garden.live.recover_seconds_remaining(i)
		plot.setup(i, type_id, plant_label, hp, max_hp, downed, filled, recover_left, level, rarity)
		plot.selected = (i == _selected)
	_subtitle = Loc.tf("garden.subtitle", [Garden.live.total(),
		Garden.live.wounded_count(), Garden.live.downed_count(), BalanceGarden.GARDEN_PATH])
	_refresh_panel()
	queue_redraw()


func _refresh_panel() -> void:
	if _panel_title == null:
		return
	var info: Dictionary = {}
	if Garden.live != null:
		info = Garden.live.slot_at(_selected)
	var filled: bool = not info.is_empty()
	var plant_label := Loc.t("garden.panel.empty_plot")
	var type_id := ""
	var hp := 0
	var max_hp := 1
	var downed := false
	var level := 1
	var rarity := Balance.RARITY_COMMON
	var _recover_left := 0.0
	if filled:
		type_id = str(info["type"])
		plant_label = Balance.plant_name(type_id)
		hp = int(info["hp"])
		max_hp = int(info["max_hp"])
		downed = bool(info["downed"])
		level = int(info["level"])
		rarity = str(info["rarity"])
		if downed and Garden.live != null:
			_recover_left = Garden.live.recover_seconds_remaining(_selected)

	_panel_title.text = Loc.tf("garden.panel.title", [_selected + 1, plant_label.to_upper()])
	var type_text := "-"
	if filled:
		type_text = plant_label
	var health_text := "-"
	if filled:
		health_text = "%d / %d" % [hp, max_hp]
	## [P25] LEVEL is level + rarity + exp now, and the TALENT moved to a line of its
	## own (it is the one property that changes what the plant DOES in battle, so it
	## should not be hidden behind the level and the exp in one long line).
	var build_text := "-"
	var talent_text := "-"
	var talent_item := ""
	if filled:
		var exp_line := "-"
		if Garden.live != null:
			exp_line = Garden.live.exp_text(_selected)
		build_text = Loc.tf("garden.panel.build",
			[level, Balance.rarity_label(rarity), exp_line])
		## [P19] the talent line names it and repeats what it does (hard pea = +50% skill)
		talent_item = Balance.plant_potion_item(type_id)
		if talent_item != "" and Garden.live != null and Garden.live.has_talent(_selected, talent_item):
			talent_text = Loc.tf("garden.panel.talent",
				[Balance.talent_display_name(talent_item), Balance.plant_potion_text(type_id)])
	_panel_lines[0].text = Loc.tf("garden.panel.line.type", [type_text])
	_panel_lines[1].text = Loc.tf("garden.panel.line.level", [build_text])
	_panel_lines[2].text = Loc.tf("garden.panel.line.health", [health_text])
	_panel_lines[3].text = Loc.tf("garden.panel.line.state", [_state_word(filled, hp, max_hp, downed)])
	_panel_lines[4].text = Loc.tf("garden.panel.line.talent", [talent_text])
	_status_label.text = _status_text()

	var bags := game.profile.count_of("fertilizer")
	var exp_potions := _item_count(Balance.ITEM_EXP_POTION)
	var talent_count := 0
	var talent_owned := false
	if filled:
		## the potion this plant needs, and whether it already has it
		talent_item = Balance.plant_potion_item(type_id)
		talent_count = _item_count(talent_item)
		talent_owned = Garden.live != null and Garden.live.has_talent(_selected, talent_item)

	## [P24] Feed the four cells. `in_stock` only greys an icon whose STOCK is empty: an
	## action the selected plant refuses (already full, already has the talent) is
	## explained by the status line after the click, because the click may well be
	## aimed at a different pot.
	var heal: int = maxi(1, int(round(float(max_hp) * BalanceGarden.WATER_HEAL_RATIO)))
	_set_tool(BalanceGarden.GARDEN_TOOL_WATER, Loc.t("garden.tool.free"),
		Loc.tf("garden.water.heal", [heal]) if filled else Loc.t("garden.advice.wounded"),
		true)
	_set_tool(BalanceGarden.GARDEN_TOOL_FERTILIZE,
		Loc.tf("item.tile.count", [bags]) if bags > 0 else "",
		Loc.tf("garden.fertilize.bag", [bags]) if bags > 0 else Loc.t("garden.fertilize.no_bag"),
		bags > 0)
	_set_tool(BalanceGarden.GARDEN_TOOL_EXP,
		Loc.tf("item.tile.count", [exp_potions]) if exp_potions > 0 else "",
		Loc.tf("garden.exp.have", [Balance.EXP_POTION_AMOUNT, exp_potions]),
		exp_potions > 0)
	var talent_tip := Loc.t("garden.talent.potion")
	if filled:
		if talent_item == "":
			talent_tip = Loc.t("garden.talent.none")
		elif talent_owned:
			talent_tip = Loc.t("garden.talent.owned")
		else:
			talent_tip = Loc.tf("garden.talent.have", [Balance.talent_display_name(talent_item), talent_count])
	_set_tool(BalanceGarden.GARDEN_TOOL_TALENT,
		Loc.tf("item.tile.count", [talent_count]) if talent_count > 0 else "",
		talent_tip, talent_count > 0)


func _state_word(filled: bool, hp: int, max_hp: int, downed: bool) -> String:
	if not filled:
		return "-"
	if downed:
		return Loc.t("garden.state.downed")
	if hp < max_hp:
		return Loc.t("garden.state.wounded")
	return Loc.t("garden.state.healthy")


func _advice_text(filled: bool, hp: int, max_hp: int, downed: bool) -> String:
	if not filled:
		return Loc.t("garden.advice.empty")
	if downed:
		return Loc.t("garden.advice.downed")
	if hp >= max_hp:
		return Loc.t("garden.advice.healthy")
	return Loc.t("garden.advice.wounded")


func _item_count(p_item: String) -> int:
	return int(profile.count_of(p_item, Profile.CONTAINER_WAREHOUSE))


## ---------------------------------------------------------------- the four tools
func _tool_title(p_kind: String) -> String:
	## One literal key per branch on purpose (a key built by concatenation would be
	## invisible to a key audit - same rule as Balance.item_kind_label).
	match p_kind:
		BalanceGarden.GARDEN_TOOL_WATER:
			return Loc.t("garden.tool.water")
		BalanceGarden.GARDEN_TOOL_FERTILIZE:
			return Loc.t("garden.tool.fertilize")
		BalanceGarden.GARDEN_TOOL_EXP:
			return Loc.t("garden.tool.exp")
		BalanceGarden.GARDEN_TOOL_TALENT:
			return Loc.t("garden.tool.talent")
	return p_kind


func _tool_icon(p_kind: String) -> String:
	## The picture the cell (and the item in hand) shows. The talent cell is the only
	## composite one: the generic bottle of the potion the SELECTED plant needs, or -
	## with no plant selected - the tier I bottle on its own (P23).
	match p_kind:
		BalanceGarden.GARDEN_TOOL_WATER:
			return BalanceUI.ART_ICON_GARDEN
		BalanceGarden.GARDEN_TOOL_FERTILIZE:
			return Balance.ART_ICON_FERTILIZER
		BalanceGarden.GARDEN_TOOL_EXP:
			return Balance.ART_ICON_EXP_POTION
		BalanceGarden.GARDEN_TOOL_TALENT:
			return _potion_art(_talent_plant(_selected))
	return ""


func _tool_mark(p_kind: String) -> String:
	## The plant mark over that bottle: "" for the three ordinary tools.
	if p_kind != BalanceGarden.GARDEN_TOOL_TALENT:
		return ""
	return _potion_mark(_talent_plant(_selected))


func _potion_art(p_plant_id: String) -> String:
	var item := Balance.plant_potion_item(p_plant_id)
	if item == "":
		return Balance.potion_bottle_art("")     # tier I bottle, no mark
	return Balance.item_art(item)


func _potion_mark(p_plant_id: String) -> String:
	return Balance.item_mark_art(Balance.plant_potion_item(p_plant_id))


func _talent_plant(p_slot: int) -> String:
	## Which plant's talent potion the cell shows: the one in that slot, "" when the
	## slot is empty (the bottle then stands alone, which is still recognisable).
	if Garden.live == null:
		return ""
	var info: Dictionary = Garden.live.slot_at(p_slot)
	if info.is_empty():
		return ""
	return str(info.get("type", ""))


func _set_tool(p_kind: String, p_badge: String, p_tooltip: String, p_in_stock: bool) -> void:
	for entry in _tools:
		var tool := entry as GardenTool
		if tool == null or tool.kind != p_kind:
			continue
		tool.setup(p_kind, _tool_title(p_kind), p_badge, p_in_stock, p_tooltip,
			_tool_icon(p_kind), _tool_mark(p_kind))
		tool.armed = (_armed == p_kind)
		return


func _status_text() -> String:
	## The status line doubles as the advice line: an explicit action result wins,
	## otherwise it explains what the selected plot needs right now (P14: that now
	## includes how long the free recovery still takes).
	if _status != "":
		return _status
	if Garden.live == null:
		return ""
	var info: Dictionary = Garden.live.slot_at(_selected)
	if info.is_empty():
		return _advice_text(false, 0, 1, false)
	var downed := bool(info["downed"])
	var advice := _advice_text(true, int(info["hp"]), int(info["max_hp"]), downed)
	if downed:
		advice = Loc.tf("garden.status.downed",
			[GardenPlot._mmss(Garden.live.recover_seconds_remaining(_selected)), game.profile.count_of("fertilizer")])
	return advice


## ---------------------------------------------------------------- layout
static func metrics_for(p_page: Vector2) -> Dictionary:
	## [P25] The whole garden layout as PURE arithmetic: page size in, every rect out.
	## _layout() places the children from this and self_check() audits it, so the numbers
	## cannot drift apart - the same idea as ItemGrid.fit_for().
	##
	##   * the plot CELL is the biggest square that fits GARDEN_COLS x GARDEN_ROWS into
	##     the box left of the panel, clamped to GARDEN_PLOT_MIN .. GARDEN_PLOT_MAX.
	##     A fixed cell size is what kept the grid at 3 rows: a 150 px cell needs 642 px
	##     of height and a 4th row does not fit a 720 px window.
	##   * the panel is a fixed-width column pinned to the right margin, as tall as the
	##     band between the page header and the hint line.
	##   * the tool bar is pinned to the TOP RIGHT, inside the header band.
	var gap: float = BalanceUI.GARDEN_PLOT_GAP
	var cols: int = maxi(1, BalanceGarden.GARDEN_COLS)
	var rows: int = maxi(1, BalanceGarden.GARDEN_ROWS)
	var top: float = BalanceUI.GARDEN_TITLE_BAND
	var band_h: float = maxf(p_page.y - BalanceUI.GARDEN_BOTTOM_BAND - top, 1.0)
	var panel_x: float = p_page.x - BalanceUI.GARDEN_SIDE_MARGIN - BalanceUI.GARDEN_PANEL_W
	var room_x: float = panel_x - BalanceUI.GARDEN_PANEL_GAP - BalanceUI.GARDEN_SIDE_MARGIN
	var by_w := (room_x - gap * float(cols - 1)) / float(cols)
	var by_h := (band_h - gap * float(rows - 1)) / float(rows)
	var side := floorf(clampf(minf(by_w, by_h), BalanceUI.GARDEN_PLOT_MIN, BalanceUI.GARDEN_PLOT_MAX))
	var cell := Vector2(side, side)
	var grid := Vector2(float(cols) * side + float(cols - 1) * gap,
		float(rows) * side + float(rows - 1) * gap)
	var kinds := BalanceGarden.GARDEN_TOOL_KINDS.size()
	var bar_w := (float(kinds) * BalanceUI.GARDEN_TOOL_SIZE.x
		+ float(maxi(kinds - 1, 0)) * BalanceUI.GARDEN_TOOL_GAP)
	return {
		"cell": cell,
		"gap": gap,
		"cols": cols,
		"rows": rows,
		"grid": grid,
		"grid_at": Vector2(floorf(BalanceUI.GARDEN_SIDE_MARGIN + (room_x - grid.x) * 0.5),
			floorf(top + (band_h - grid.y) * 0.5)),
		"panel": Rect2(Vector2(panel_x, top), Vector2(BalanceUI.GARDEN_PANEL_W, band_h)),
		"tools_at": Vector2(p_page.x - BalanceUI.GARDEN_SIDE_MARGIN - bar_w, BalanceUI.GARDEN_TOOLBAR_Y),
		"tools_size": Vector2(bar_w, BalanceUI.GARDEN_TOOL_SIZE.y),
		## [P95] the page bar sits on the LEFT of that same header row, vertically centred
		## on the tool cells. The tools are right-aligned, so the two bars grow towards
		## each other from opposite margins and cannot meet at any window width.
		"page_bar_at": Vector2(BalanceUI.GARDEN_SIDE_MARGIN,
			floorf(BalanceUI.GARDEN_TOOLBAR_Y
				+ (BalanceUI.GARDEN_TOOL_SIZE.y - BalanceUI.GARDEN_PAGE_BAR_H) * 0.5)),
		"page_bar_size": Vector2(BalanceUI.GARDEN_PAGE_BTN_W * 2.0 + BalanceUI.GARDEN_PAGE_LABEL_W
			+ BalanceUI.GARDEN_PAGE_GAP * 2.0, BalanceUI.GARDEN_PAGE_BAR_H),
	}


func _layout() -> void:
	## [P25] Only placement here: every number comes from metrics_for(), so the layout
	## and its self-check can never disagree.
	var m := metrics_for(Layout.size)
	var cell: Vector2 = m["cell"]
	var gap: float = m["gap"]
	var cols: int = m["cols"]
	var grid_at: Vector2 = m["grid_at"]
	var panel: Rect2 = m["panel"]

	for i in _plots.size():
		var plot := _plots[i] as GardenPlot
		if plot == null:
			continue
		var row: int = floori(float(i) / float(cols))
		var column: int = i % cols
		plot.position = Vector2(grid_at.x + float(column) * (cell.x + gap),
			grid_at.y + float(row) * (cell.y + gap))
		plot.custom_minimum_size = cell
		plot.size = cell

	var inset: float = BalanceUI.GARDEN_PANEL_INSET
	var inner := BalanceUI.GARDEN_PANEL_W - inset * 2.0
	_panel_rect = panel
	_place_label(_panel_title, Vector2(panel.position.x + inset,
		panel.position.y + BalanceUI.GARDEN_PANEL_TITLE_Y), Vector2(inner, 28.0))
	for i in _panel_lines.size():
		var at := (panel.position.y + BalanceUI.GARDEN_PANEL_LINES_Y
			+ float(i) * BalanceUI.GARDEN_PANEL_LINE_STEP)
		_place_label(_panel_lines[i] as Label, Vector2(panel.position.x + inset, at),
			Vector2(inner, 22.0))
	## [P25] The advice fills everything between the number lines and BACK - the tools
	## used to live down here, and this block is where their room went.
	var button_h: float = BalanceUI.GARDEN_BUTTON_HEIGHT
	var back_y := panel.position.y + panel.size.y - BalanceUI.GARDEN_PANEL_BOTTOM - button_h
	var status_y := panel.position.y + BalanceUI.GARDEN_PANEL_STATUS_Y
	_place_label(_status_label, Vector2(panel.position.x + inset, status_y),
		Vector2(inner, maxf(back_y - BalanceUI.GARDEN_BUTTON_GAP - status_y, 0.0)))
	_place_button(_back, Vector2(panel.position.x + inset, back_y), Vector2(inner, button_h))

	## [P95] The page bar: same header row, pinned to the LEFT margin.
	var page_at: Vector2 = m["page_bar_at"]
	var page_h: float = BalanceUI.GARDEN_PAGE_BAR_H
	_place_button(_page_prev, page_at, Vector2(BalanceUI.GARDEN_PAGE_BTN_W, page_h))
	_place_button(_page_next,
		Vector2(page_at.x + BalanceUI.GARDEN_PAGE_BTN_W * 2.0
			+ BalanceUI.GARDEN_PAGE_LABEL_W + BalanceUI.GARDEN_PAGE_GAP * 2.0, page_at.y),
		Vector2(BalanceUI.GARDEN_PAGE_BTN_W, page_h))
	_place_label(_page_label,
		Vector2(page_at.x + BalanceUI.GARDEN_PAGE_BTN_W + BalanceUI.GARDEN_PAGE_GAP, page_at.y),
		Vector2(BalanceUI.GARDEN_PAGE_LABEL_W, page_h))

	## [P24/P25] The tool bar: one row of cells, top right, level with the page title.
	## Right-aligned, so a fifth kind would grow it leftwards and never into the panel.
	var tools_at: Vector2 = m["tools_at"]
	for i in _tools.size():
		var tool := _tools[i] as GardenTool
		if tool == null:
			continue
		tool.position = Vector2(tools_at.x
			+ float(i) * (BalanceUI.GARDEN_TOOL_SIZE.x + BalanceUI.GARDEN_TOOL_GAP), tools_at.y)
		tool.custom_minimum_size = BalanceUI.GARDEN_TOOL_SIZE
		tool.size = BalanceUI.GARDEN_TOOL_SIZE


func _place_label(label: Label, pos: Vector2, box: Vector2) -> void:
	if label == null:
		return
	label.position = pos
	label.size = box


func _place_button(btn: Button, pos: Vector2, box: Vector2) -> void:
	if btn == null:
		return
	btn.position = pos
	btn.custom_minimum_size = box
	btn.size = box


## ---------------------------------------------------------------- callbacks
func _on_plot_picked(p_slot: int) -> void:
	## [P24] With an item in hand a click on a pot USES it there; otherwise the click
	## only selects the pot and the panel follows it.
	if _armed != "":
		_apply_armed(p_slot)
		return
	_selected = p_slot
	_status = ""
	for i in _plots.size():
		var plot := _plots[i] as GardenPlot
		if plot != null:
			plot.selected = (_slot_of(i) == p_slot)
			plot.queue_redraw()
	_refresh_panel()
	queue_redraw()


func _on_tool_picked(p_kind: String) -> void:
	## [P24] Pick the item up (or put it back down when it is already in hand). The
	## picture then follows the cursor until it is used or dropped.
	if _armed == p_kind:
		_disarm(true)
		return
	_armed = p_kind
	_ghost_key = ""
	_hover_slot = -1
	## The status line says what to do next, using the very sentence the cell shows as
	## its tooltip: the picture is already in hand, the click that USES it has to come
	## from the player.
	_status = Loc.tf("garden.tool.armed", [_tool_sentence(p_kind)])
	_refresh_panel()
	_tick_armed()
	queue_redraw()


func _tool_sentence(p_kind: String) -> String:
	## The full sentence of one action, as the panel last wrote it on the cell's
	## tooltip (bag counts, stock, the plant's talent ...). Read back from the cell so
	## there is exactly ONE place that composes it: _refresh_panel's _set_tool calls.
	for entry in _tools:
		var tool := entry as GardenTool
		if tool != null and tool.kind == p_kind:
			return tool.tooltip_text
	return _tool_title(p_kind)


func _on_drop_requested() -> void:
	## Right click on a pot: put the item back (a pot stops the mouse, so it forwards
	## this instead of the page receiving it - see GardenPlot._gui_input).
	if _armed != "":
		_disarm(true)


func _gui_input(event: InputEvent) -> void:
	## Right click on the empty page around the pots does the same as on a pot.
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and _armed != "":
		_disarm(true)
		accept_event()


func _disarm(p_say: bool) -> void:
	## Puts the item down: the ghost disappears, no pot is a target any more.
	var was := _tool_title(_armed)
	_armed = ""
	_ghost_key = ""
	_hover_slot = -1
	var ghost := _ghost as CursorGhost
	if ghost != null:
		ghost.drop()
	if p_say and was != "":
		_status = Loc.tf("garden.tool.cancelled", [was])
	for entry in _tools:
		var tool := entry as GardenTool
		if tool != null and tool.armed:
			tool.armed = false
			tool.queue_redraw()
	_clear_targets()
	_refresh_panel()
	queue_redraw()


func _apply_armed(p_slot: int) -> void:
	## Uses the item in hand on the pot that was clicked. The pot is selected first so
	## the panel and the status line describe the plant that was just treated.
	if _armed == "":
		return
	_select_slot(p_slot)
	## An empty pot is refused HERE rather than by the action, because the actions
	## answer with a bare slot number and this one can say what is actually wrong.
	if not _plot_filled(p_slot):
		_status = Loc.t("garden.tool.empty")
		_refresh_panel()
		return
	var kind := _armed
	var result: Dictionary = _use(kind, p_slot)
	var line := str(result.get("message", ""))
	if bool(result.get("ok", false)):
		## the item is spent (or the free water was poured), so the hand is empty
		_status = line
		_disarm(false)
	else:
		## refused: the plant was wrong, not the item - keep holding it, so the next
		## click can go to another pot without picking it up again.
		_status = line
		_refresh_panel()
	refresh()


func _select_slot(p_slot: int) -> void:
	## Selects a pot WITHOUT touching _status (the caller is about to set it from the
	## action's own result line): the panel and the highlighted frame follow the plant
	## that was just treated.
	_selected = p_slot
	for i in _plots.size():
		var plot := _plots[i] as GardenPlot
		if plot != null:
			plot.selected = (_slot_of(i) == p_slot)
			plot.queue_redraw()


## ---------------------------------------------------------------- pages (P95)
func _slot_of(p_index: int) -> int:
	## The roster slot a plot on screen stands for. Slots stay 0..GARDEN_CAPACITY-1
	## (that is what Garden and the save file use); the page only picks the window of
	## them the 16 plots look at.
	return _page * BalanceGarden.GARDEN_PAGE_SIZE + p_index


func _index_of(p_slot: int) -> int:
	## The plot that shows this slot, or -1 when the slot lives on another page.
	var first := _page * BalanceGarden.GARDEN_PAGE_SIZE
	if p_slot < first or p_slot >= first + BalanceGarden.GARDEN_PAGE_SIZE:
		return -1
	return p_slot - first


func _turn_page(p_delta: int) -> void:
	## Walks the roster pages. The selection follows the page, because the panel must
	## always describe a pot the player can SEE; an item in hand stays in hand, since a
	## watering can picked up on page 1 may well be meant for a plant on page 2.
	_page = wrapi(_page + p_delta, 0, maxi(1, BalanceGarden.GARDEN_PAGES))
	if _index_of(_selected) < 0:
		_selected = _slot_of(0)
	_clear_targets()
	_hover_slot = -1
	_update_page_bar()
	refresh()


func _update_page_bar() -> void:
	## The bar is chrome for the whole page, so it answers with Balance, not with the
	## roster: one page means the buttons have nothing to do and disappear.
	if _page_label != null:
		_page_label.text = Loc.tf("grid.page", [_page + 1, maxi(1, BalanceGarden.GARDEN_PAGES)])
	var many: bool = BalanceGarden.GARDEN_PAGES > 1
	if _page_prev != null:
		_page_prev.visible = many
		_page_prev.disabled = not many
	if _page_next != null:
		_page_next.visible = many
		_page_next.disabled = not many


func _use(p_kind: String, p_slot: int) -> Dictionary:
	## The four actions, each on ONE pot. Water is free and saves here; the other
	## three cost an item, so Game owns those transactions (P14/P15).
	if game == null or Garden.live == null:
		return {"ok": false, "message": Loc.t("msg.garden.not_loaded")}
	match p_kind:
		BalanceGarden.GARDEN_TOOL_WATER:
			var roster: Garden = Garden.live
			var poured: Dictionary = roster.water(p_slot)
			if bool(poured.get("ok", false)):
				game.save_garden()    # [P65] A3: through Game's door, so a refused write shows
			return poured
		BalanceGarden.GARDEN_TOOL_FERTILIZE:
			return game.fertilize_plant(p_slot)
		BalanceGarden.GARDEN_TOOL_EXP:
			return game.use_exp_potion(p_slot)
		BalanceGarden.GARDEN_TOOL_TALENT:
			return game.use_talent_potion(p_slot)
	return {"ok": false, "message": ""}


## ---------------------------------------------------------------- item in hand
func _tick_armed() -> void:
	## Runs every frame while an item is in hand: frames the pot under the cursor and
	## keeps the picture in the ghost in step with it (for a talent potion that means
	## the plant mark of the plant being pointed at, which is the one you would dose).
	if _armed == "" or _ghost == null:
		return
	var ghost := _ghost as CursorGhost
	if ghost == null:
		return
	var slot := _slot_at_point(get_local_mouse_position())
	var want := slot if (slot >= 0 and _plot_filled(slot)) else -1
	if want != _hover_slot:
		_hover_slot = want
		_clear_targets()
		if want >= 0:
			var plot := _plots[_index_of(want)] as GardenPlot   # [P95] slot -> plot on this page
			if plot != null:
				plot.is_target = true
				plot.queue_redraw()
	var plant := _talent_plant(_hover_slot) if _hover_slot >= 0 else _talent_plant(_selected)
	var icon := _tool_icon(_armed)
	var mark := ""
	if _armed == BalanceGarden.GARDEN_TOOL_TALENT:
		icon = _potion_art(plant)
		mark = _potion_mark(plant)
	## [P92] the kind travels with the picture: the ghost composites exactly like the cell.
	var ghost_kind: String = "talent" if _armed == BalanceGarden.GARDEN_TOOL_TALENT else ""
	var key := icon + "|" + mark + "|" + ghost_kind
	if key != _ghost_key:
		_ghost_key = key
		ghost.hold(icon, mark, ghost_kind)


func _clear_targets() -> void:
	for entry in _plots:
		var plot := entry as GardenPlot
		if plot != null and plot.is_target:
			plot.is_target = false
			plot.queue_redraw()


func _plot_filled(p_slot: int) -> bool:
	if Garden.live == null or p_slot < 0 or p_slot >= BalanceGarden.GARDEN_CAPACITY:
		return false
	return not Garden.live.slot_at(p_slot).is_empty()


func _slot_at_point(p_at: Vector2) -> int:
	## Which pot the cursor is over, or -1. The pots are plain Controls, so this is
	## just a rect test - no per-pot mouse signals needed while an item is in hand.
	for i in _plots.size():
		var plot := _plots[i] as GardenPlot
		if plot != null and plot.get_rect().has_point(p_at):
			return _slot_of(i)     # [P95] the SLOT under the cursor, not the plot's position
	return -1


func _on_back() -> void:
	if game != null:
		game.back_from_front_end()


## ---------------------------------------------------------------- self check
static func self_check() -> void:
	## [P25] The garden page is arithmetic on Balance constants, so the whole layout can
	## be audited at start-up without opening the screen (same idea as ItemGrid). What
	## would go wrong silently:
	##   1. the 4 x 4 grid or the tool bar not fitting the design window,
	##   2. the tool bar reaching into the plot area, the panel or the panel's column,
	##   3. the five property lines running into the advice block or into BACK,
	##   4. the pot or the plant standing ON the plot's own text.
	## [P52] [GardenUI] and not [Garden]: `Garden.self_check()` audits the persistent
	## roster (money, pots, save round-trip) under [Garden], and the two blocks used to
	## close with the same "[Garden] self-check PASSED". Rules there, pixels here - the
	## banner says which one to go read.
	print("[GardenUI] --- layout: 4x4 pots, tools top right, pot + plant (P25) ---")
	var m := metrics_for(Vector2(Balance.WINDOW_SIZE))
	var cell: Vector2 = m["cell"]
	var grid: Vector2 = m["grid"]
	var grid_at: Vector2 = m["grid_at"]
	var panel: Rect2 = m["panel"]
	var tools_at: Vector2 = m["tools_at"]
	var tools_size: Vector2 = m["tools_size"]
	print("[GardenUI] window %dx%d, %d x %d pots, cell %dx%d, grid %dx%d at (%d,%d)"
		% [int(Balance.WINDOW_SIZE.x), int(Balance.WINDOW_SIZE.y), int(m["cols"]), int(m["rows"]),
		   int(cell.x), int(cell.y), int(grid.x), int(grid.y), int(grid_at.x), int(grid_at.y)])
	print("[GardenUI] panel %dx%d at (%d,%d), tool bar %dx%d at (%d,%d)"
		% [int(panel.size.x), int(panel.size.y), int(panel.position.x), int(panel.position.y),
		   int(tools_size.x), int(tools_size.y), int(tools_at.x), int(tools_at.y)])

	var ok := true
	## 1 + 2: the grid stays left of the panel and inside the band, and the tool bar
	## stays in the header band, clear of the panel's column.
	var grid_fits: bool = (grid_at.x >= BalanceUI.GARDEN_SIDE_MARGIN - 0.5
		and grid_at.x + grid.x <= panel.position.x - BalanceUI.GARDEN_PANEL_GAP + 0.5)
	var cell_ok: bool = cell.x >= BalanceUI.GARDEN_PLOT_MIN and cell.x <= BalanceUI.GARDEN_PLOT_MAX
	var grid_rows: bool = m["rows"] * m["cols"] == BalanceGarden.GARDEN_PAGE_SIZE
	var bar_clear: bool = (tools_at.y + tools_size.y <= BalanceUI.GARDEN_TITLE_BAND
		and tools_at.x >= BalanceUI.GARDEN_SIDE_MARGIN
		and tools_at.x + tools_size.x <= Balance.WINDOW_SIZE.x - BalanceUI.GARDEN_SIDE_MARGIN + 0.5)
	## [P95] the page bar shares that header row from the LEFT margin, so the two bars
	## cannot meet, and the arithmetic of the paging has to close: one page is one grid,
	## and the capacity a reward plant looks for a free slot in is all the pages together.
	var page_at: Vector2 = m["page_bar_at"]
	var page_size: Vector2 = m["page_bar_size"]
	var pages_ok: bool = (BalanceGarden.GARDEN_CAPACITY == BalanceGarden.GARDEN_PAGE_SIZE * BalanceGarden.GARDEN_PAGES
		and BalanceGarden.GARDEN_COLS * BalanceGarden.GARDEN_ROWS == BalanceGarden.GARDEN_PAGE_SIZE)
	var page_clear: bool = (page_at.y >= 0.0
		and page_at.y + page_size.y <= BalanceUI.GARDEN_TITLE_BAND
		and page_at.x >= BalanceUI.GARDEN_SIDE_MARGIN
		and page_at.x + page_size.x <= tools_at.x - BalanceUI.GARDEN_PAGE_GAP + 0.5)
	ok = ok and grid_fits and cell_ok and grid_rows and bar_clear and pages_ok and page_clear
	print("[GardenUI] grid fits left of the panel = %s, cell %d in %d..%d = %s, cells == one page %d = %s | %s"
		% [grid_fits, int(cell.x), int(BalanceUI.GARDEN_PLOT_MIN), int(BalanceUI.GARDEN_PLOT_MAX),
		   cell_ok, BalanceGarden.GARDEN_PAGE_SIZE, grid_rows, "OK" if (grid_fits and cell_ok and grid_rows) else "FAIL"])
	print("[GardenUI] tool bar inside the header band and the margins = %s | %s"
		% [bar_clear, "OK" if bar_clear else "FAIL"])
	print("[GardenUI] page bar %dx%d at (%d,%d) clear of the tools, %d page(s) x %d pots == capacity %d = %s | %s"
		% [int(page_size.x), int(page_size.y), int(page_at.x), int(page_at.y),
		   BalanceGarden.GARDEN_PAGES, BalanceGarden.GARDEN_PAGE_SIZE, BalanceGarden.GARDEN_CAPACITY,
		   str(pages_ok and page_clear), "OK" if (pages_ok and page_clear) else "FAIL"])

	## 3: the property lines, the advice block and BACK, from the top of the panel down.
	var lines_bottom: float = (panel.position.y + BalanceUI.GARDEN_PANEL_LINES_Y
		+ float(BalanceUI.GARDEN_PANEL_LINES - 1) * BalanceUI.GARDEN_PANEL_LINE_STEP)
	var status_top: float = panel.position.y + BalanceUI.GARDEN_PANEL_STATUS_Y
	var back_top: float = (panel.position.y + panel.size.y - BalanceUI.GARDEN_PANEL_BOTTOM
		- BalanceUI.GARDEN_BUTTON_HEIGHT)
	var panel_ok: bool = (lines_bottom <= status_top
		and status_top + BalanceUI.GARDEN_PANEL_STATUS_H <= back_top - BalanceUI.GARDEN_BUTTON_GAP + 0.5
		and back_top + BalanceUI.GARDEN_BUTTON_HEIGHT <= panel.position.y + panel.size.y + 0.5)
	ok = ok and panel_ok
	print("[GardenUI] %d lines end at %d, advice %d..%d, BACK at %d inside the panel = %s | %s"
		% [BalanceUI.GARDEN_PANEL_LINES, int(lines_bottom), int(status_top),
		   int(status_top + BalanceUI.GARDEN_PANEL_STATUS_H), int(back_top),
		   panel_ok, "OK" if panel_ok else "FAIL"])

	## 4: the pot and the plant against the plot's own text - the one relationship that
	## is easy to get wrong by a few pixels, and invisible until someone looks at it.
	var name_y: float = cell.y * BalanceUI.GARDEN_NAME_Y_RATIO
	var pot_w: float = cell.x * BalanceUI.GARDEN_POT_W_RATIO
	var pot_h: float = pot_w * BalanceUI.GARDEN_POT_CONTENT.size.y / BalanceUI.GARDEN_POT_CONTENT.size.x
	var pot_top: float = cell.y - BalanceUI.GARDEN_POT_BOTTOM_PAD - pot_h
	var soil: float = pot_top + pot_h * BalanceUI.GARDEN_POT_SOIL_RATIO
	var ink_h: float = cell.y * BalanceUI.GARDEN_PLANT_INK_H_RATIO
	var ink_top: float = soil + ink_h * BalanceUI.GARDEN_PLANT_SINK - ink_h
	var art_ok: bool = (pot_top > name_y
		and pot_top + pot_h <= cell.y - BalanceUI.GARDEN_POT_BOTTOM_PAD + 0.5
		and soil < pot_top + pot_h
		and ink_top > name_y
		and soil + ink_h * BalanceUI.GARDEN_PLANT_SINK <= cell.y)
	ok = ok and art_ok
	print("[GardenUI] pot %dx%d at y %d, soil %d, plant ink %d..%d, name baseline %d = %s | %s"
		% [int(pot_w), int(pot_h), int(pot_top), int(soil), int(ink_top),
		   int(soil + ink_h * BalanceUI.GARDEN_PLANT_SINK), int(name_y),
		   art_ok, "OK" if art_ok else "FAIL"])
	print("[GardenUI] self-check %s" % ("PASSED" if ok else "FAILED"))


## ---------------------------------------------------------------- drawing
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := Layout.size.x
	var h := Layout.size.y
	draw_rect(Rect2(0.0, 0.0, w, h), BalanceUI.COLOR_MENU_BG)
	draw_string(font, Vector2(0.0, BalanceUI.MENU_TITLE_Y), _title, HORIZONTAL_ALIGNMENT_CENTER, w,
		BalanceUI.FONT_SIZE_MENU_TITLE, BalanceUI.COLOR_MENU_TITLE)
	draw_string(font, Vector2(0.0, BalanceUI.MENU_TITLE_Y + BalanceUI.MENU_SUB_OFFSET),
		UiStyle.fit_text(font, _subtitle, BalanceUI.FONT_SIZE_MENU_SUB, w - BalanceUI.HUD_SIDE_MARGIN * 2.0),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	# the detail panel is painted here, i.e. UNDER its own labels and buttons
	draw_rect(_panel_rect, BalanceUI.OVERLAY_PANEL_BG)
	draw_rect(_panel_rect, BalanceUI.OVERLAY_PANEL_BORDER, false, BalanceUI.OVERLAY_PANEL_BORDER_WIDTH)
	draw_string(font, Vector2(0.0, h - BalanceUI.MENU_HINT_BOTTOM_MARGIN),
		UiStyle.fit_text(font, _hint, BalanceUI.FONT_SIZE_MENU_SUB, w - BalanceUI.HUD_SIDE_MARGIN * 2.0),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
