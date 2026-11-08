class_name RunScreen
extends Control
## [P31-A] The shared body of the ADVENTURE pages: squad, roadmap, reward pick
## and the generic node page (event / treasure / rest / run end). All four answer
## the same shape of question - "read what the run says, press one of these" -
## so the header, the stacked ROW GROUPS, the body text, the status line, the
## footer buttons and BACK all live here ONCE.
##
## A page owns no rule and no number: it asks Game (untyped `.game`, HANDOFF 7.18
## like every other view) and re-reads what comes back. Game still owns "which
## screen is up"; this base only ever opens, refreshes and goes back.
##
## Subclass hooks:
##
##   _screen_title() / _screen_subtitle() / _screen_hint()
##   _read_rows()          -> Array of row GROUPS; each group is an Array of
##                            {text, enabled?, color?} dicts drawn on ONE line
##   _on_row_pressed(g, j) -> the (group, index-in-group) button was pressed
##   _body_lines()         -> Array[String] of wrapped lines under the header
##   _footer_specs()       -> up to RUN_MAX_FOOTERS {text, enabled} buttons
##   _on_footer_pressed(i)
##   _wants_back()         -> false on a page the player must decide on
##
## The buttons of both pools are built ONCE and re-labelled on every refresh; a
## row press is routed through _slot_map, which is rebuilt with the rows, so the
## signals never have to be re-connected.

var game = null                        # GameManager autoload; untyped on purpose

var _title := ""
var _subtitle := ""
var _hint := ""
var _status := ""                      # the last action's answer, "" = none yet

## The current row groups, straight from _read_rows() (see hook docs).
var _groups: Array = []
## Pool slot -> {"g": group, "j": index-in-group}; rebuilt with every refresh.
var _slot_map: Array = []

@onready var _row_btns: Array = []              # RunRow0..31 (pooled), in scene order
@onready var _body_labels: Array = []           # BodyLine0..3 (pooled)
@onready var _footer_btns: Array = []           # RunFooter0..1 (pooled)
@onready var _status_label: Label = $StatusLabel
@onready var _back: Button = $Back


# ---------------------------------------------------------------- subclass hooks
func _screen_title() -> String:
	return ""


func _screen_subtitle() -> String:
	return ""


func _screen_hint() -> String:
	return ""


func _read_rows() -> Array:
	return []


func _on_row_pressed(_p_group: int, _p_index: int) -> void:
	pass


func _body_lines() -> Array[String]:
	var out: Array[String] = []
	return out


func _body_line_h() -> float:
	## One body line's height. Pages whose text is prose (the node pages) raise
	## this so an autowrapped paragraph is not clipped.
	return BalanceUI.RUN_BODY_LINE_H


func _footer_specs() -> Array:
	return []


func _on_footer_pressed(_p_index: int) -> void:
	pass


func _wants_back() -> bool:
	return true


# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_collect_and_wire()


func open_view() -> void:
	## Called by Game.show_run_*(): re-read everything, come up. The status line
	## starts empty, so a message from the LAST visit never greets the player as
	## if it had just happened (the ItemScreen rule).
	_status = ""
	refresh()
	visible = true
	on_layout_changed()
	var focus := _back
	if _back == null or _back.disabled or not _wants_back():
		focus = _first_enabled_button()
	if focus != null:
		focus.grab_focus()


func hide_view() -> void:
	visible = false


func on_layout_changed() -> void:
	## Driven by Game after every window size change (HANDOFF 7.12): the page is
	## anchored to the full rect, only its children are re-placed.
	_layout()
	queue_redraw()


func refresh() -> void:
	## Rebuild everything this page says. Safe at any time, including right after
	## a live language switch (Game refreshes the visible run pages for that).
	_apply_static_texts()
	_groups = _read_rows()
	_rebuild_slot_map()
	for i in _row_btns.size():
		var btn := _row_btns[i] as Button
		var m: Dictionary = _slot_map[i] if i < _slot_map.size() else {}
		if m.is_empty():
			btn.visible = false
			continue
		var row: Dictionary = (_groups[int(m["g"])] as Array)[int(m["j"])] as Dictionary
		btn.visible = true
		btn.text = str(row.get("text", ""))
		btn.disabled = not bool(row.get("enabled", true))
		btn.add_theme_color_override("font_color", row.get("color", BalanceUI.COLOR_TEXT))
	var body: Array[String] = _body_lines()
	for i in _body_labels.size():
		var label := _body_labels[i] as Label
		label.visible = i < body.size()
		if i < body.size():
			label.text = body[i]
	var footers := _footer_specs()
	for i in _footer_btns.size():
		var btn := _footer_btns[i] as Button
		if i < footers.size():
			var spec: Dictionary = footers[i]
			btn.visible = true
			btn.text = str(spec.get("text", ""))
			btn.disabled = not bool(spec.get("enabled", false))
		else:
			btn.visible = false
	if _back != null:
		_back.visible = _wants_back()
	if _status_label != null:
		_status_label.text = _status
	queue_redraw()


func _apply_static_texts() -> void:
	_title = _screen_title()
	_subtitle = _screen_subtitle()
	_hint = _screen_hint()
	if _back != null:
		_back.text = Loc.t("menu.back")


func _rebuild_slot_map() -> void:
	_slot_map.clear()
	for g in _groups.size():
		var group: Array = _groups[g]
		for j in group.size():
			_slot_map.append({"g": g, "j": j})


func _first_enabled_button() -> Button:
	for entry in _row_btns:
		var btn := entry as Button
		if btn != null and btn.visible and not btn.disabled:
			return btn
	for entry in _footer_btns:
		var btn := entry as Button
		if btn != null and btn.visible and not btn.disabled:
			return btn
	return null


func _report(p_result: Dictionary) -> void:
	## An action's answer, shown on the status line until the next one (and gone
	## when the page re-opens). ItemScreen's rule, same shape.
	_status = str(p_result.get("message", ""))
	refresh()


# ---------------------------------------------------------------- construction
func _collect_and_wire() -> void:
	## [P107] THE NODES COME FROM THE PAGE'S SCENE (scenes/ui/{squad,roadmap,reward,choice,deck}.tscn,
	## which share this skeleton because they share this class). This finds them, wires the
	## callbacks a scene cannot bind and dresses what a scene cannot dress (UiStyle).
	##
	## Every count here is a BalanceUI constant - the buttons and body lines are POOLED, sized to
	## the busiest page (RUN_MAX_ROWS / RUN_MAX_BODY / RUN_MAX_FOOTERS) and hidden until a page
	## needs them - which is exactly why they can live in a scene at all.
	for i in BalanceUI.RUN_MAX_BODY:
		var label := get_node("BodyLine%d" % i) as Label
		UiStyle.style_label(label, "", BalanceUI.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT,
			BalanceUI.FONT_SIZE_MENU_SUB)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.visible = false
		_body_labels.append(label)
	for i in BalanceUI.RUN_MAX_ROWS:
		var btn := get_node("RunRow%d" % i) as Button
		_dress_button(btn, _on_any_row.bind(i))
		btn.visible = false
		_row_btns.append(btn)
	for i in BalanceUI.RUN_MAX_FOOTERS:
		var btn := get_node("RunFooter%d" % i) as Button
		_dress_button(btn, _on_any_footer.bind(i))
		btn.visible = false
		_footer_btns.append(btn)
	UiStyle.style_label(_status_label, "", BalanceUI.COLOR_MESSAGE, HORIZONTAL_ALIGNMENT_LEFT,
		BalanceUI.FONT_SIZE_MENU_SUB)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dress_button(_back, _on_back_pressed)


func _dress_button(btn: Button, p_pressed: Callable) -> Button:
	## [P73] The skin is UiStyle.style_button()'s now (see the note there); the TEXT is set by
	## _apply_static_texts(), which runs again after a live language switch.
	return UiStyle.style_button(btn, "", p_pressed)

# ---------------------------------------------------------------- layout
func _layout() -> void:
	if _row_btns.is_empty():
		return          # a resize arriving before _ready() has built the children
	var col_w: float = BalanceUI.RUN_COL_W
	var x := floorf((Layout.size.x - col_w) * 0.5)
	var row_h: float = BalanceUI.RUN_ROW_H
	var y: float = BalanceUI.RUN_TOP
	var body_h: float = _body_line_h()
	for label in _body_labels:
		var lbl := label as Label
		if lbl == null or not lbl.visible:
			continue
		_place(lbl, Vector2(x, y), Vector2(col_w, body_h))
		y += body_h
	if not _body_labels_all_hidden():
		y += BalanceUI.RUN_BODY_GAP
	y = _layout_rows(y)
	_status_label.position = Vector2(x, y)
	_status_label.size = Vector2(col_w, BalanceUI.RUN_STATUS_H)
	_status_label.text = _status
	y += BalanceUI.RUN_STATUS_H + BalanceUI.RUN_FOOTER_GAP
	for btn_v in _footer_btns:
		var btn := btn_v as Button
		if btn == null or not btn.visible:
			continue
		_place(btn, Vector2(x, y), Vector2(col_w, row_h))
		y += row_h + BalanceUI.RUN_ROW_GAP
	if _back != null and _back.visible:
		_place(_back, Vector2(x, y), Vector2(col_w, row_h))


func _layout_rows(p_top: float) -> float:
	## Places the pooled row buttons and returns the y BELOW the last line. The
	## default is the shared centred column; a page that arranges its rows as
	## something else (the roadmap's node graph, [P31-UI]) overrides this hook
	## and owns both the placement and how much height the rows take.
	var col_w: float = BalanceUI.RUN_COL_W
	var x := floorf((Layout.size.x - col_w) * 0.5)
	var y := p_top
	var k := 0
	for group in _groups:
		var cells: Array = group
		var n := maxi(1, cells.size())
		var cell_w := (col_w - BalanceUI.RUN_GROUP_GAP * float(n - 1)) / float(n)
		for j in cells.size():
			if k >= _row_btns.size():
				break   # the pool is the cap; rows past it are not drawn
			var btn := _row_btns[k] as Button
			var bx := x + float(j) * (cell_w + BalanceUI.RUN_GROUP_GAP)
			_place(btn, Vector2(bx, y), Vector2(cell_w, BalanceUI.RUN_ROW_H))
			k += 1
		y += BalanceUI.RUN_ROW_H + BalanceUI.RUN_ROW_GAP
	return y


func _body_labels_all_hidden() -> bool:
	for label in _body_labels:
		if (label as Label).visible:
			return false
	return true


func _place(ctrl: Control, pos: Vector2, box: Vector2) -> void:
	if ctrl == null:
		return
	ctrl.position = pos
	ctrl.custom_minimum_size = box
	ctrl.size = box


# ---------------------------------------------------------------- callbacks
func _on_any_row(p_slot: int) -> void:
	if p_slot >= _slot_map.size():
		return
	var m: Dictionary = _slot_map[p_slot]
	_on_row_pressed(int(m["g"]), int(m["j"]))


func _on_any_footer(p_index: int) -> void:
	_on_footer_pressed(p_index)


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
	draw_string(font, Vector2(0.0, h - BalanceUI.MENU_HINT_BOTTOM_MARGIN),
		UiStyle.fit_text(font, _hint, BalanceUI.FONT_SIZE_MENU_SUB, w - BalanceUI.HUD_SIDE_MARGIN * 2.0),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)