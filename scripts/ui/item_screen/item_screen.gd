class_name ItemScreen
extends Control
## [P22] The shared body of the two item screens: WAREHOUSE and SHOP.
##
## Both are "a grid of things you own or can buy, plus a detail panel with the
## actions for the selected cell". The grid, the panel, the six labels, the three
## buttons, the ESC path and the window-resize path therefore live here ONCE, and a
## subclass only answers:
##
##   _read_rows()      which cells to show (the ItemGrid row shape)
##   _action_specs()   which two action buttons are up, what they say, enabled?
##   _on_action(i)     what pressing them does
##   _detail_lines()   what the three detail lines say about the selected row
##
## Game stays the only owner of "which screen is up" (HANDOFF 7.18): BACK just asks
## it to go back, exactly like the garden page does.

var game = null                        # GameManager autoload; untyped on purpose

var _title := ""
var _subtitle := ""
var _hint := ""
var _status := ""                      # the last action's answer, "" = none yet

var _rows: Array = []
var _selected_id := ""

@onready var _grid: ItemGrid = $Grid
var _panel_rect := Rect2()
@onready var _panel_title: Label = $PanelTitle
@onready var _panel_lines: Array = []    # PanelLine0..2, in scene order
@onready var _desc_label: Label = $DescLabel
@onready var _status_label: Label = $StatusLabel
@onready var _actions: Array = [$Action0, $Action1]   # primary, secondary
@onready var _back: Button = $Back


# ---------------------------------------------------------------- subclass hooks
func _screen_title() -> String:
	return ""


func _screen_subtitle() -> String:
	return ""


func _screen_hint() -> String:
	return ""


func _read_rows() -> Array:
	## The ItemGrid rows to show, refreshed on open, after every action and after a
	## live language switch.
	return []


func _detail_lines(_p_row: Dictionary) -> Array:
	## The three lines above the description: type / count / value.
	return []


func _action_specs() -> Array:
	## [{text, enabled}, {text, enabled}] - the two buttons ABOVE BACK. An empty text
	## hides that button; the slot keeps its space, so BACK never moves.
	return []


func _on_action(_p_index: int) -> void:
	pass


func _empty_desc() -> String:
	## What the description block says when the grid is empty.
	return Loc.t("item.panel.empty_desc")


# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_collect_and_wire()


func open_view() -> void:
	## Called by Game.show_warehouse() / show_shop(): re-read the rows, come up.
	## The status line starts empty, so a message from the LAST visit never greets the
	## player as if it had just happened.
	_status = ""
	refresh()
	visible = true
	on_layout_changed()
	if _back != null and not _back.disabled:
		_back.grab_focus()


func hide_view() -> void:
	visible = false


func on_layout_changed() -> void:
	## Driven by Game after every window size change (HANDOFF 7.12). The screen
	## itself is anchored to the full rect, so only the children are re-placed.
	_layout()
	queue_redraw()


func refresh() -> void:
	## Rebuild everything this screen says. Safe to call at any time, including with
	## no profile loaded and right after a language switch.
	_apply_static_texts()
	_rows = _read_rows()
	if _selected_id != "" and _find_row(_selected_id).is_empty():
		_selected_id = ""
	if _selected_id == "" and not _rows.is_empty():
		_selected_id = str((_rows[0] as Dictionary).get("id", ""))
	if _grid != null:
		_grid.show_items(_rows, _selected_id)
	_refresh_panel()
	queue_redraw()


func _apply_static_texts() -> void:
	_title = _screen_title()
	_subtitle = _screen_subtitle()
	_hint = _screen_hint()
	if _back != null:
		_back.text = Loc.t("menu.back")


func _find_row(p_id: String) -> Dictionary:
	for entry in _rows:
		var row: Dictionary = entry
		if str(row.get("id", "")) == p_id:
			return row
	return {}


func _report(p_result: Dictionary) -> void:
	## An action's answer, shown on the status line until the next one.
	_status = str(p_result.get("message", ""))
	refresh()


func _clear_status() -> void:
	_status = ""


# ---------------------------------------------------------------- construction
func _collect_and_wire() -> void:
	## [P107] THE NODES COME FROM THE PAGE'S SCENE (scenes/ui/warehouse.tscn and its two siblings,
	## which share this skeleton because they share this class). This finds them, wires what a
	## scene cannot wire (the grid's signal and its paging) and dresses what a scene cannot dress.
	##
	## The three pages keep their own `.tscn` instead of an inherited scene on purpose: Godot
	## cannot swap the ROOT script of an inherited scene, and the root script is exactly what
	## tells the three apart. What they share is the behaviour, and that is `extends ItemScreen`.
	for i in BalanceUI.ITEM_PANEL_LINES:
		_panel_lines.append(get_node("PanelLine%d" % i) as Label)
	## [P42] The item kinds outgrew this box (37 of them against 12 cells), so the grid pages
	## instead of shrinking past the readable floor. The grid owns the bar, the slicing and
	## which page holds what is selected; this screen keeps owning WHAT is selected.
	_grid.paged = true
	_grid.picked.connect(_on_tile_picked)
	UiStyle.style_label(_panel_title, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_ITEM_PANEL_TITLE)
	for line in _panel_lines:
		UiStyle.style_label(line as Label, "", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			BalanceUI.FONT_SIZE_ITEM_PANEL_LINE)
	UiStyle.style_label(_desc_label, "", BalanceUI.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_ITEM_PANEL_LINE)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UiStyle.style_label(_status_label, "", BalanceUI.COLOR_MESSAGE, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_ITEM_PANEL_LINE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# The two action slots plus BACK: three buttons, laid out bottom-up so BACK is always the
	# last row whatever the actions above it say.
	for i in _actions.size():
		UiStyle.style_button(_actions[i] as Button, "", _on_action.bind(i))
	UiStyle.style_button(_back, "", _on_back_pressed)

# ---------------------------------------------------------------- the panel
func _refresh_panel() -> void:
	if _panel_title == null:
		return
	var row := _find_row(_selected_id)
	if row.is_empty():
		_panel_title.text = Loc.t("item.panel.empty_title")
		for label in _panel_lines:
			(label as Label).text = ""
		_desc_label.text = _empty_desc()
	else:
		_panel_title.text = str(row.get("title", _selected_id))
		var lines := _detail_lines(row)
		for i in _panel_lines.size():
			var label := _panel_lines[i] as Label
			label.text = str(lines[i]) if i < lines.size() else ""
		_desc_label.text = str(row.get("desc", ""))
	_status_label.text = _status
	var specs := _action_specs()
	for i in _actions.size():
		var btn := _actions[i] as Button
		if btn == null:
			continue
		if i < specs.size():
			var spec: Dictionary = specs[i]
			btn.text = str(spec.get("text", ""))
			btn.disabled = not bool(spec.get("enabled", false))
			btn.visible = btn.text != ""
		else:
			btn.visible = false


# ---------------------------------------------------------------- layout
func _layout() -> void:
	if _grid == null:
		return          # a resize arriving before _ready() has built the children
	var grid_area := ItemGrid.design_area()
	var panel_w: float = BalanceUI.ITEM_PANEL_W
	var gap: float = BalanceUI.ITEM_PANEL_GAP
	var group_w := grid_area.x + gap + panel_w
	var x0 := floorf((Layout.size.x - group_w) * 0.5)
	var y0 := floorf(maxf(BalanceUI.ITEM_SCREEN_TOP, (Layout.size.y - grid_area.y) * 0.5 - 26.0))

	_grid.position = Vector2(x0, y0)
	_grid.size = grid_area
	_grid.relayout()

	# --- the detail panel, right of the grid ----------------------------------
	var px := x0 + grid_area.x + gap
	_panel_rect = Rect2(Vector2(px, y0), Vector2(panel_w, grid_area.y))
	var inset: float = BalanceUI.ITEM_PANEL_INSET
	var inner := panel_w - inset * 2.0
	_place_label(_panel_title, Vector2(px + inset, y0 + BalanceUI.ITEM_PANEL_TITLE_Y),
		Vector2(inner, BalanceUI.ITEM_PANEL_TITLE_H))
	for i in _panel_lines.size():
		var at := y0 + BalanceUI.ITEM_PANEL_LINES_Y + float(i) * BalanceUI.ITEM_PANEL_LINE_STEP
		_place_label(_panel_lines[i] as Label, Vector2(px + inset, at),
			Vector2(inner, BalanceUI.ITEM_PANEL_LINE_H))
	# bottom-up: the buttons, then the status line, then the description
	var button_h: float = BalanceUI.ITEM_PANEL_BUTTON_H
	var button_gap: float = BalanceUI.ITEM_PANEL_BUTTON_GAP
	var slots: int = BalanceUI.ITEM_PANEL_BUTTONS
	var buttons_top := y0 + grid_area.y - BalanceUI.ITEM_PANEL_BOTTOM \
		- (button_h * float(slots) + button_gap * float(slots - 1))
	var status_top := buttons_top - BalanceUI.ITEM_PANEL_STATUS_GAP - BalanceUI.ITEM_PANEL_STATUS_H
	var desc_top := status_top - BalanceUI.ITEM_PANEL_DESC_GAP - BalanceUI.ITEM_PANEL_DESC_H
	_place_label(_desc_label, Vector2(px + inset, desc_top),
		Vector2(inner, BalanceUI.ITEM_PANEL_DESC_H))
	_place_label(_status_label, Vector2(px + inset, status_top),
		Vector2(inner, BalanceUI.ITEM_PANEL_STATUS_H))
	var buttons: Array = _actions.duplicate()
	buttons.append(_back)
	for i in buttons.size():
		var btn := buttons[i] as Button
		if btn == null:
			continue
		var box := Vector2(inner, button_h)
		btn.position = Vector2(px + inset, buttons_top + float(i) * (button_h + button_gap))
		btn.custom_minimum_size = box
		btn.size = box


func _place_label(label: Label, pos: Vector2, box: Vector2) -> void:
	if label == null:
		return
	label.position = pos
	label.size = box


# ---------------------------------------------------------------- callbacks
func _gui_input(p_event: InputEvent) -> void:
	## [P42] The grid stays click-transparent (a click in the gap between the cells must
	## reach the screen behind it), so the wheel is caught here and handed to the paging:
	## inside a grid of cells "wheel down = further down the list" is what a player tries
	## first, and the two buttons stay the discoverable way. Same rule the almanac set.
	var mb := p_event as InputEventMouseButton
	if mb == null or not mb.pressed or _grid == null:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_grid.turn_page(1)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_grid.turn_page(-1)
		accept_event()


func _on_tile_picked(p_id: String) -> void:
	_selected_id = p_id
	_clear_status()
	if _grid != null:
		_grid.select(p_id)
	_refresh_panel()


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
	## The hint line is long by design; the important half is at the FRONT, so the tail
	## is what gets trimmed. [P53] This page used to carry its own copy of that rule.
	draw_string(font, Vector2(0.0, h - BalanceUI.MENU_HINT_BOTTOM_MARGIN),
		UiStyle.fit_text(font, _hint, BalanceUI.FONT_SIZE_MENU_SUB, w - BalanceUI.HUD_SIDE_MARGIN * 2.0),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)