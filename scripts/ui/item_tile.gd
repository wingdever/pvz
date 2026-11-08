class_name ItemTile
extends Control
## [P22] One cell of an item grid: a large icon, the item's NAME in small text along
## the bottom edge, an optional badge (how many / what it costs) in the corner and a
## selection frame. It draws itself and reports clicks; every piece of game state
## stays with the screen that owns the grid.
##
## The same class backs the WAREHOUSE, the SHOP and the in-battle BACKPACK, which is
## what makes "click an item to see what it does" behave identically in all three.
## The main menu's floor objects are deliberately NOT cells (see ui/menu_prop.gd):
## there the picture is a door, not a thing you own.
##
## Art is loaded defensively (UnitArt.load_texture): a missing or not-yet-imported
## SVG leaves the cell empty but still correctly sized and labelled, so the layout
## never breaks (HANDOFF 7.20).
##
## [P23] A talent potion icon is TWO textures: the generic bottle of the potion's
## tier (Balance.item_art) plus the plant's own unit sprite (Balance.item_mark_art)
## scaled into the bottle's blank top area. UnitArt.draw_potion_icon() does that
## compositing, so the warehouse, the shop, the backpack and the garden's care tool
## cells all draw a potion the same way.

signal picked(id: String)

var id: String = ""
var title: String = ""                 # drawn under the icon
var art: String = ""
var badge: String = ""                 # "x3" / "100"; empty hides the badge
var note: String = ""                  # tiny line under the name (durability ...)
var selected: bool = false
var dimmed: bool = false               # cannot be used right now (unaffordable ...)
var hovered: bool = false
var badge_color: Color = Color.WHITE

var _texture: Texture2D = null
var _mark_texture: Texture2D = null    # [P23] plant mark, null for a plain icon
	## [P92] the item's kind: the composite needs it to pick the mark geometry.
var kind: String = ""


func _init() -> void:
	## Cells are mouse targets: the keyboard is the panel Buttons' job on these
	## screens, so a cell never takes focus (the main menu's objects are the ones that
	## do - see ui/menu_prop.gd).
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _on_hover(p_on: bool) -> void:
	if hovered == p_on:
		return
	hovered = p_on
	queue_redraw()


func setup(p_id: String, p_title: String, p_art: String, p_badge: String = "",
		p_note: String = "", p_dimmed: bool = false,
		p_badge_color: Color = Color.WHITE) -> void:
	## Everything the cell draws, in one call. The grid calls this on every refresh,
	## so nothing here may depend on the previous state.
	id = p_id
	title = p_title
	art = p_art
	badge = p_badge
	note = p_note
	dimmed = p_dimmed
	badge_color = p_badge_color
	_texture = UnitArt.load_texture(p_art)
	## [P23] Talent potions get their plant mark as a second layer; for every other
	## item this stays null and the icon is drawn exactly as before.
	## [P92] and the kind decides WHERE that mark goes (a bottle's cork, a scroll's page).
	kind = Balance.item_kind(p_id)
	_mark_texture = UnitArt.load_texture(Balance.item_mark_art(p_id))
	tooltip_text = p_title
	visible = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(id)
		accept_event()


func _fit_text(font: Font, p_text: String, p_max_w: float, p_base: int, p_min: int) -> Dictionary:
	## A cell is narrow, so a long name is first set a point smaller and only then
	## trimmed: "Fertilizer Bag" has to stay readable, not vanish behind "...".
	## [P53] The trimming half is no longer this file's own loop - it is the one rule in
	## `UiStyle.trim_tail()`, reached with the CELL's floor (three characters still read
	## as a word head; the screen-wide floor of eight would leave a whole column of tiles
	## showing their full label outside the box).
	var font_size := p_base
	while font_size > p_min and UiStyle.width_of(font, p_text, font_size) > p_max_w:
		font_size -= 1
	return {
		"text": UiStyle.trim_tail(font, p_text, font_size, p_max_w,
			BalanceUI.ITEM_TILE_TEXT_MIN_CHARS),
		"size": font_size,
	}


func _fit_art_box(p_box: Rect2) -> Rect2:
	## [D79] A PICTURE KEEPS ITS OWN PROPORTIONS inside the square icon box. Every unit, item and
	## level picture in the game is a square canvas, so for all of them this returns the box it was
	## given - not one existing cell moves. A 射弹 is the exception that made it necessary: an arrow
	## is five to one, and drawing it into a square would show a fat blob instead of an arrow.
	## The FILE decides the shape; the cell only decides how much room there is.
	if _texture == null:
		return p_box
	var canvas := Vector2(float(_texture.get_width()), float(_texture.get_height()))
	if canvas.x <= 0.0 or canvas.y <= 0.0:
		return p_box
	var drawn := canvas * minf(p_box.size.x / canvas.x, p_box.size.y / canvas.y)
	return Rect2(p_box.position + (p_box.size - drawn) * 0.5, drawn)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var box := Rect2(Vector2.ZERO, size)
	var bg: Color = BalanceUI.COLOR_ITEM_TILE_HOVER if (hovered and not selected) else BalanceUI.COLOR_ITEM_TILE_BG
	draw_rect(box, bg)

	# --- icon box: square, as large as the footer leaves room for ----------------
	var note_h: float = BalanceUI.ITEM_TILE_NOTE_H if note != "" else 0.0
	var footer: float = BalanceUI.ITEM_TILE_FOOTER_PAD * 2.0 + BalanceUI.ITEM_TILE_NAME_H + note_h
	var room := Vector2(size.x - BalanceUI.ITEM_TILE_PAD * 2.0,
		size.y - BalanceUI.ITEM_TILE_ICON_TOP - footer)
	var side := maxf(minf(minf(room.x, room.y), BalanceUI.ITEM_TILE_ICON_MAX), 0.0)
	var icon_box := Rect2(Vector2(floorf((size.x - side) * 0.5), BalanceUI.ITEM_TILE_ICON_TOP),
		Vector2(side, side))
	if side > 1.0:
		## [P23/P92] A potion = generic bottle + plant mark, a scroll = the shared scroll +
		## the plant it unlocks; every other item has no mark and the helper draws the plain
		## icon. UnitArt owns that geometry, so the garden's tool icons composite the same way.
		var tint := Color(1.0, 1.0, 1.0, (BalanceUI.ITEM_TILE_DIM_ALPHA if dimmed else 1.0))
		UnitArt.draw_item_icon(self, _fit_art_box(icon_box), _texture, _mark_texture, kind, tint)
	if dimmed:
		draw_rect(icon_box, BalanceUI.COLOR_ITEM_TILE_DIM)

	# --- badge: the count, or what the thing costs ------------------------------
	if badge != "":
		var text_w := UiStyle.width_of(font, badge, BalanceUI.FONT_SIZE_ITEM_BADGE)
		var badge_h := float(BalanceUI.FONT_SIZE_ITEM_BADGE) + BalanceUI.ITEM_TILE_BADGE_PAD
		var badge_box := Rect2(
			Vector2(icon_box.position.x + icon_box.size.x - text_w - BalanceUI.ITEM_TILE_BADGE_PAD * 2.0
					- BalanceUI.ITEM_TILE_BADGE_INSET,
				icon_box.position.y + icon_box.size.y - badge_h - BalanceUI.ITEM_TILE_BADGE_INSET),
			Vector2(text_w + BalanceUI.ITEM_TILE_BADGE_PAD * 2.0, badge_h))
		draw_rect(badge_box, BalanceUI.COLOR_ITEM_TILE_BADGE_BG)
		draw_string(font, Vector2(badge_box.position.x + BalanceUI.ITEM_TILE_BADGE_PAD,
			badge_box.position.y + badge_h - 3.0), badge,
			HORIZONTAL_ALIGNMENT_LEFT, -1, BalanceUI.FONT_SIZE_ITEM_BADGE, badge_color)

	# --- the name, along the bottom edge ---------------------------------------
	var name_bottom := size.y - BalanceUI.ITEM_TILE_FOOTER_PAD - note_h
	var fitted := _fit_text(font, title, size.x - BalanceUI.ITEM_TILE_PAD * 2.0,
		BalanceUI.FONT_SIZE_ITEM_TILE, BalanceUI.FONT_SIZE_ITEM_TILE_MIN)
	draw_string(font, Vector2(BalanceUI.ITEM_TILE_PAD, name_bottom - 4.0), str(fitted["text"]),
		HORIZONTAL_ALIGNMENT_CENTER, size.x - BalanceUI.ITEM_TILE_PAD * 2.0, int(fitted["size"]),
		BalanceUI.COLOR_TEXT)

	if note != "":
		## [P27] The note is fitted like the name: the almanac's cells are narrower (eight
		## per row) and "not implemented yet" would otherwise spill into the cell next to
		## it. Shrink the font first, trim the tail only if that is not enough.
		var fitted_note := _fit_text(font, note, size.x - BalanceUI.ITEM_TILE_PAD * 2.0,
			BalanceUI.FONT_SIZE_ITEM_NOTE, BalanceUI.FONT_SIZE_ITEM_TILE_MIN)
		draw_string(font, Vector2(BalanceUI.ITEM_TILE_PAD, size.y - BalanceUI.ITEM_TILE_FOOTER_PAD - 3.0),
			str(fitted_note["text"]), HORIZONTAL_ALIGNMENT_CENTER, size.x - BalanceUI.ITEM_TILE_PAD * 2.0,
			int(fitted_note["size"]), BalanceUI.COLOR_TEXT_DIM)

	# --- frame last, so it is never covered by the icon ------------------------
	var frame: Color = BalanceUI.COLOR_ITEM_TILE_SELECTED if selected else BalanceUI.COLOR_ITEM_TILE_BORDER
	var frame_w: float = BalanceUI.ITEM_TILE_SELECTED_W if selected else BalanceUI.ITEM_TILE_BORDER_W
	draw_rect(box, frame, false, frame_w)
