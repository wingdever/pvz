class_name MenuProp
extends Control
## [P22] One object LYING ON THE FLOOR of the main menu: the picture, a soft shadow
## under it and its name in small dim text. No frame, no background, no badge - on
## this screen the centred list of text options is what the menu is FOR, and these
## four are what you find lying on the ground next to it.
##
## Deliberately NOT an ItemTile: a cell means "a thing you own" on the item screens,
## while here the picture is a door you click.
##
## The art files do not share one content box (the key is a flat 76x30 shape in the
## middle of its 128x128 canvas, the crate is 88x72), so the host passes the rect the
## SVG really fills together with the width that rect should be drawn at. That is what
## makes five different pictures look like five objects of comparable size standing on
## one floor, and what puts every shadow exactly under its object's feet.
##
## Clicking it - or ENTER / SPACE while it has focus - reports `picked`; where that
## leads is the menu's business (HANDOFF 7.18).

signal picked(id: String)

var id: String = ""
var title: String = ""                  # the caption under the object
var art: String = ""
var art_content := Rect2()              # the SVG's filled area, in canvas pixels
var art_wide: float = 0.0               # how wide that area is drawn, in screen px
var lift: float = 0.0                   # how far above the floor line it sits
var spot_x: float = 0.5                 # its centre, as a fraction of the window width
var hovered: bool = false

var _texture: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	## Focusable on purpose: these objects replaced four text Buttons, so TAB +
	## ENTER has to keep working or the keyboard would lose those screens.
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_repaint)
	focus_exited.connect(_repaint)


func setup(p_id: String, p_title: String, p_art: String, p_content: Rect2,
		p_wide: float, p_lift: float, p_spot_x: float) -> void:
	id = p_id
	title = p_title
	art = p_art
	art_content = p_content
	art_wide = p_wide
	lift = p_lift
	spot_x = p_spot_x
	_texture = UnitArt.load_texture(p_art)
	tooltip_text = p_title
	queue_redraw()


func _on_hover(p_on: bool) -> void:
	if hovered == p_on:
		return
	hovered = p_on
	queue_redraw()


func _repaint() -> void:
	queue_redraw()


func lit() -> bool:
	## Mouse hover and keyboard focus light an object up the same way.
	return hovered or has_focus()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(id)
			accept_event()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			picked.emit(id)
			accept_event()


func _floor_y() -> float:
	## Where this object's feet are, inside its own box.
	return size.y - BalanceUI.MENU_PROP_CAPTION_H - BalanceUI.MENU_PROP_FLOOR_PAD - lift


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var up := lit()
	var floor_y := _floor_y()

	## The texture is drawn REGION by region: `art_content` is what the SVG really
	## fills, so a mostly empty canvas (the key!) does not shrink the picture to a
	## sliver, and it is the bottom of the CONTENT that lands on the floor line.
	var has_art: bool = _texture != null and art_content.size.x > 0.0 and art_content.size.y > 0.0
	var src := Rect2()
	var drawn := Vector2.ZERO
	var at := Vector2.ZERO
	if has_art:
		var tex_size := Vector2(float(_texture.get_width()), float(_texture.get_height()))
		var unit := tex_size / BalanceUI.MENU_ART_CANVAS   # canvas px -> texture px
		src = Rect2(art_content.position * unit, art_content.size * unit)
		var arm_scale := art_wide / art_content.size.x
		drawn = art_content.size * arm_scale
		at = Vector2(floorf((size.x - drawn.x) * 0.5), floorf(floor_y - drawn.y))

	# 1. a halo, not a frame: a box would make the object look like a grid cell, which
	#    is exactly what these must not look like (only while hovered / focused)
	if has_art and up:
		var half := drawn.x * BalanceUI.MENU_PROP_GLOW_RATIO * 0.5
		draw_set_transform(Vector2(size.x * 0.5, floor_y - drawn.y * 0.5), 0.0,
			Vector2(1.0, BalanceUI.MENU_PROP_GLOW_SQUASH))
		draw_circle(Vector2.ZERO, half, BalanceUI.COLOR_MENU_PROP_GLOW)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. the shadow it casts on the floor (nothing to cast one if the art is missing)
	if has_art:
		var shadow_w := drawn.x * BalanceUI.MENU_PROP_SHADOW_RATIO
		draw_set_transform(Vector2(size.x * 0.5, floor_y), 0.0,
			Vector2(1.0, BalanceUI.MENU_PROP_SHADOW_SQUASH))
		draw_circle(Vector2.ZERO, shadow_w * 0.5, BalanceUI.COLOR_MENU_PROP_SHADOW)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3. the object itself, standing on the shadow
	if has_art:
		var tint := Color(1.0, 1.0, 1.0, (1.0 if up else BalanceUI.MENU_PROP_IDLE_ALPHA))
		draw_texture_rect_region(_texture, Rect2(at, drawn), src, tint)

	# 4. the caption, small and dim until you point at it
	var color: Color = BalanceUI.COLOR_TEXT if up else BalanceUI.COLOR_TEXT_DIM
	draw_string(font, Vector2(0.0, size.y - 5.0), title, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, BalanceUI.FONT_SIZE_MENU_PROP, color)
