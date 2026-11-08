class_name GardenTool
extends Control
## [P107] ONE CARE CELL (watering can / fertilizer / EXP potion / talent potion).
## [P24] The four care actions are ICON CELLS, not text buttons. A click PICKS THE ITEM UP -
## the picture then follows the cursor (see CursorGhost) and the next click on a pot uses it on
## THAT plant, instead of on whatever was selected before.
##
## It moved out of garden_view.gd's inner classes when the page became a scene.


## [P24] One care action as an ICON: the watering can, a bag of fertilizer, an EXP
## potion or a talent potion. It reports a click and nothing else - what the item
## DOES is Garden / Game's business, exactly like GardenPlot.
##
## Drawn top to bottom: the icon (dimmed when there is none left), the badge in the
## icon's corner ("FREE" / "x3"), the name along the bottom edge, and a frame that
## turns gold while the item is IN HAND. `tooltip_text` carries the full sentence
## (what it does, what it costs), which is where the old button wording went.
signal picked(kind: String)

var kind: String = ""
var title: String = ""
var badge: String = ""                 # "" hides the badge
## NOT "ready": a script may not redefine a native member (header note, P24).
var in_stock: bool = true              # false = nothing to spend, icon dimmed
var armed: bool = false
var hovered: bool = false

var _texture: Texture2D = null
var _mark_texture: Texture2D = null    # [P23] plant mark of a talent potion


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	## [P24] focusable on purpose: the old text buttons could be reached with the
	## keyboard (TAB + ENTER), and a cell must not take that away.
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_repaint)
	focus_exited.connect(_repaint)


func _repaint() -> void:
	## Same helper menu_prop.gd uses: a focus change only needs a repaint.
	queue_redraw()


func _on_hover(p_on: bool) -> void:
	if hovered == p_on:
		return
	hovered = p_on
	queue_redraw()


func setup(p_kind: String, p_title: String, p_badge: String, p_in_stock: bool,
		p_tooltip: String, p_icon: String, p_mark: String) -> void:
	## Everything the cell shows, in one call; the panel calls it on every refresh,
	## so nothing here may depend on the previous state.
	kind = p_kind
	title = p_title
	badge = p_badge
	in_stock = p_in_stock
	tooltip_text = p_tooltip
	_texture = UnitArt.load_texture(p_icon)
	_mark_texture = UnitArt.load_texture(p_mark)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		picked.emit(kind)
		accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		picked.emit(kind)
		accept_event()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var box := Rect2(Vector2.ZERO, size)
	var bg: Color = BalanceUI.COLOR_GARDEN_TOOL_BG
	if (hovered or has_focus()) and not armed:
		bg = BalanceUI.COLOR_GARDEN_TOOL_HOVER
	draw_rect(box, bg)

	# --- icon: centred, as big as the name strip leaves room for ----------------
	var side := maxf(minf(BalanceUI.GARDEN_TOOL_ICON, size.y - BalanceUI.GARDEN_TOOL_NAME_INSET
		- BalanceUI.FONT_SIZE_GARDEN_TOOL - BalanceUI.GARDEN_TOOL_ICON_TOP), 0.0)
	var icon_box := Rect2(Vector2(floorf((size.x - side) * 0.5), BalanceUI.GARDEN_TOOL_ICON_TOP),
		Vector2(side, side))
	if side > 1.0:
		## [P23/P92] the very same two-layer icon the warehouse / shop / backpack show,
		## so a talent potion (and a scroll) looks identical on every screen.
		var tint: Color = Color.WHITE if in_stock else BalanceUI.COLOR_GARDEN_TOOL_DIM
		## [P92] the tool's own kind is the item kind here (the potion tool arms "talent"),
		## which is what the composite needs to place the plant mark.
		UnitArt.draw_item_icon(self, icon_box, _texture, _mark_texture, kind, tint)

	# --- badge: how many you have (or FREE for the watering can) ----------------
	if badge != "":
		var text_w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1,
			BalanceUI.FONT_SIZE_GARDEN_TOOL_BADGE).x
		var badge_h := float(BalanceUI.FONT_SIZE_GARDEN_TOOL_BADGE) + BalanceUI.GARDEN_TOOL_BADGE_PAD
		var badge_box := Rect2(
			Vector2(icon_box.position.x + icon_box.size.x - text_w
					- BalanceUI.GARDEN_TOOL_BADGE_PAD * 2.0,
				icon_box.position.y + icon_box.size.y - badge_h),
			Vector2(text_w + BalanceUI.GARDEN_TOOL_BADGE_PAD * 2.0, badge_h))
		draw_rect(badge_box, BalanceUI.COLOR_GARDEN_TOOL_BADGE_BG)
		draw_string(font, Vector2(badge_box.position.x + BalanceUI.GARDEN_TOOL_BADGE_PAD,
			badge_box.position.y + badge_h - 3.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1,
			BalanceUI.FONT_SIZE_GARDEN_TOOL_BADGE,
			BalanceUI.COLOR_TEXT if in_stock else BalanceUI.COLOR_TEXT_DIM)

	# --- the name, along the bottom edge ---------------------------------------
	var name_text := UiStyle.fit_text(font, title, BalanceUI.FONT_SIZE_GARDEN_TOOL,
		size.x - BalanceUI.GARDEN_TOOL_NAME_INSET * 2.0)
	draw_string(font, Vector2(0.0, size.y - BalanceUI.GARDEN_TOOL_NAME_BOTTOM), name_text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, BalanceUI.FONT_SIZE_GARDEN_TOOL,
		BalanceUI.COLOR_TEXT if in_stock else BalanceUI.COLOR_TEXT_DIM)

	# --- frame last: gold while the item is in hand, otherwise a thin outline --
	var frame: Color = BalanceUI.COLOR_GARDEN_SELECTED if armed else BalanceUI.COLOR_GARDEN_EMPTY_LINE
	draw_rect(box, frame, false, 3.0 if armed else 1.0)


## ---------------------------------------------------------------- item in hand