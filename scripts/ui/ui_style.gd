class_name UiStyle
extends RefCounted
## [P10] Shared button / panel styling, so the HUD and the front-end look alike.
## Lifted out of hud.gd when the main menu arrived; every number still lives in
## Balance, this file only assembles StyleBoxFlat objects.

static func make_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = bg.lightened(0.25)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


static func button_styles(bg: Color, hover: Color, pressed: Color, disabled: Color) -> Dictionary:
	return {
		"normal": make_style(bg),
		"hover": make_style(hover),
		"pressed": make_style(pressed),
		"disabled": make_style(disabled),
	}


static func default_button_styles() -> Dictionary:
	## The green action button used by END TURN, RESTART, MAIN MENU and the menu.
	return button_styles(BalanceUI.COLOR_BTN_BG, BalanceUI.COLOR_BTN_BG_HOVER,
		BalanceUI.COLOR_BTN_BG.darkened(0.18), BalanceUI.COLOR_BTN_BG_DISABLED)


static func apply(btn: Button, styles: Dictionary) -> void:
	for k in styles.keys():
		btn.add_theme_stylebox_override(str(k), styles[k])


static func make_button(p_host: Node, p_text: String, p_pressed: Callable,
		p_font_size: int = 0, p_focus: int = -1, p_styles: Dictionary = {},
		p_dim_when_disabled: bool = true) -> Button:
	## [P73] THE button factory. Every screen used to carry its own copy - four of them
	## (almanac, run, item, item grid) were byte-for-byte the same twelve lines, the garden's
	## and the menu's were the same shape with a different colour or no text, and the HUD
	## hand-rolled eight more. One exit now, with the three differences those copies REALLY
	## had left as parameters instead of being quietly averaged away:
	##   p_host    who adopts the button; null means the caller keeps its own add_child()
	##             (the menu adds a row's labels as children first, and the HUD's result
	##             panel holds references before parenting).
	##   p_focus   FOCUS_ALL is the front end's skin (tab key reaches every button); the HUD
	##             still runs FOCUS_NONE on all ten of its buttons - the battle's keyboard
	##             is the hotkey layer, and giving its buttons focus is its own batch
	##             (OPTIMIZATION_PLAN E 组, the last line of P41).
	##   p_dim_when_disabled  the disabled FONT colour. Six screens ask for COLOR_TEXT_DIM;
	##             seven of the HUD's eight buttons and both menu makers never set it, so those
	##             buttons still wear Godot's own default. Averaging that would repaint three
	##             buttons that can and do get disabled (hud.gd:796/803/805), which is a look
	##             change wearing a refactor's clothes.
	## p_styles is the four-state stylebox dict; empty means default_button_styles().
	## p_focus of -1 and p_font_size of 0 are "the caller did not say", and resolve IN THE
	## BODY to this file's own skin (FOCUS_ALL / FONT_SIZE_MENU_ROW). They are not written as
	## default arguments because a default parameter may not read another class's const
	## (docs/HANDOFF.md §7.66 - the same reason fit_text() below takes a floor instead of a
	## default). The one caller that genuinely wants LESS than the skin is the menu's row
	## button, which says so with p_font_size = -1: it draws its text as child Labels and has
	## never put a size override on the button itself.
	## p_pressed is connected only when valid, so a caller that wires the signal later (the
	## menu's row buttons, which are built before their handler exists) can ask for the skin
	## without the click.
	## Why each screen still keeps a one-line `_make_button()` of its own: those wrappers are
	## not copies any more, they are the page's own arguments (`self` as the host, no label,
	## its colour), and rewriting 16 call sites to say that out loud would trade a real
	## reduction for a bigger diff. The point of this function is that the ASSEMBLY happens in
	## one place - which is also where the `ui_click` cue is waiting to be hung (the second
	## of P50's two funnels, still open in OPTIMIZATION_PLAN's P50 section; the pick it needs
	## is whether a button's click and a card slot's selection are one sound or two).
	var btn := Button.new()
	style_button(btn, p_text, p_pressed, p_font_size, p_focus, p_styles, p_dim_when_disabled)
	if p_host != null:
		p_host.add_child(btn)
	return btn


static func style_button(btn: Button, p_text: String, p_pressed: Callable,
		p_font_size: int = 0, p_focus: int = -1, p_styles: Dictionary = {},
		p_dim_when_disabled: bool = true) -> Button:
	## [P107] THE SECOND HALF OF make_button(): dress a button that ALREADY EXISTS. A scene can
	## declare the node (scenes/ui/garden.tscn does), so the assembly has to be callable without
	## `Button.new()`; make_button() is now this plus the new() plus the add_child().
	btn.text = p_text
	btn.focus_mode = (p_focus if p_focus >= 0 else Control.FOCUS_ALL) as Control.FocusMode
	if p_font_size != -1:
		btn.add_theme_font_size_override("font_size",
			p_font_size if p_font_size != 0 else BalanceUI.FONT_SIZE_MENU_ROW)
	btn.add_theme_color_override("font_color", BalanceUI.COLOR_TEXT)
	if p_dim_when_disabled:
		btn.add_theme_color_override("font_disabled_color", BalanceUI.COLOR_TEXT_DIM)
	apply(btn, default_button_styles() if p_styles.is_empty() else p_styles)
	if p_pressed.is_valid():
		btn.pressed.connect(p_pressed)
	return btn


static func colored_styles(p_bg: Color, p_hover_lighten: float, p_pressed_darken: float) -> Dictionary:
	## [P73] The one shape of a coloured button both the garden and the HUD were building by
	## hand. The hover factor is a PARAMETER, not a shared constant, because the two callers
	## do not agree on it today (garden 0.12, HUD's RETREAT 0.14) and picking a winner is a
	## visual decision, not a cleanup.
	return button_styles(p_bg, p_bg.lightened(p_hover_lighten),
		p_bg.darkened(p_pressed_darken), BalanceUI.COLOR_BTN_BG_DISABLED)


static func make_label(p_text: String, p_color: Color, p_align: int, p_font_size: int) -> Label:
	return style_label(Label.new(), p_text, p_color, p_align, p_font_size)


static func style_label(label: Label, p_text: String, p_color: Color, p_align: int,
		p_font_size: int) -> Label:
	## [P107] THE SECOND HALF OF make_label(), for the same reason style_button() exists: the
	## scene declares the node, this dresses it.
	## Labels inside a Button must ignore the mouse, otherwise they eat its clicks.
	label.text = p_text
	label.horizontal_alignment = p_align as HorizontalAlignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", p_color)
	label.add_theme_font_size_override("font_size", p_font_size)
	return label


# ---------------------------------------------------------------- icons (P18)
static func draw_icon(ci: CanvasItem, p_path: String, p_at: Vector2, p_size: float,
		p_alpha: float = 1.0, p_mirror: bool = false) -> void:
	## Draws an item / unit SVG at a fixed size. Missing art (or an import the editor
	## has not finished) draws nothing at all - never a broken layout (HANDOFF 7.20).
	##
	## [B16b] p_mirror flips the picture about its own BOX, which is what a page previewing a
	## line-up needs: a body drawn looking the wrong way for the camp it is shown in is drawn
	## mirrored on the board (Unit.mirrored, BRAWL.md §8.15) and has to look the same here.
	## It is OPT-IN because a card is not a body standing in a camp: the shop, the rewards and
	## the almanac draw the art as it was authored, and only a battle line-up flips.
	## ⚠ The transform is put back before returning - callers draw other things after an icon.
	if ci == null or p_path == "":
		return
	var tex := UnitArt.load_texture(p_path)
	if tex == null:
		return
	var box := Vector2(p_size, p_size)
	if p_mirror:
		## Translate to the box's centre, flip x there and draw the box centred on it: the same
		## negative-scale trick the melee marks use (Fx.MeleeMark.setup), moved onto an icon.
		ci.draw_set_transform(p_at + box * 0.5, 0.0, Vector2(-1.0, 1.0))
		ci.draw_texture_rect(tex, Rect2(-box * 0.5, box), false, Color(1.0, 1.0, 1.0, p_alpha))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	ci.draw_texture_rect(tex, Rect2(p_at, box), false,
		Color(1.0, 1.0, 1.0, p_alpha))


static func make_icon(p_path: String, p_size: float) -> TextureRect:
	## A TextureRect child for buttons / rows. Invisible when the art is missing, so
	## the text simply starts where the icon would have been.
	var textrect := TextureRect.new()
	textrect.texture = UnitArt.load_texture(p_path)
	textrect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textrect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	textrect.custom_minimum_size = Vector2(p_size, p_size)
	textrect.size = Vector2(p_size, p_size)
	textrect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textrect.visible = textrect.texture != null
	if BalanceUI.UNIT_ART_LINEAR_FILTER:
		textrect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return textrect


# ---------------------------------------------------------------- text (P24)
static func width_of(font: Font, p_text: String, p_size: int) -> float:
	## One way to measure a string, so "does it fit" means the same thing everywhere.
	return font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_size).x


static func trim_tail(font: Font, p_text: String, p_size: int, p_max_w: float,
		p_min_len: int) -> String:
	## [P53] The ONE tail-trim: cut characters off the end until the label plus "..."
	## fits, and stop at p_min_len rather than reduce a word to an initial.
	## This loop used to exist four times (here, menu.gd, item_screen.gd, item_tile.gd)
	## and the copies had already drifted - the three screen ones floor at 8 characters,
	## the cell one at 3, because a narrow cell legitimately needs a shorter remainder.
	## Both floors are now arguments, and both are named constants in BalanceUI.
	## NOTE: it measures once per cut character (O(n) get_string_size calls). That is
	## deliberate: a binary search would assume a longer prefix is never narrower, which
	## kerning and ligatures can break, and none of these strings is long enough to pay
	## for it (labels are trimmed inside _draw(), and the B-group hot path is the board).
	if width_of(font, p_text, p_size) <= p_max_w:
		return p_text
	var cut := p_text
	while cut.length() > p_min_len and width_of(font, cut + "...", p_size) > p_max_w:
		cut = cut.substr(0, cut.length() - 1)
	return cut + "..."


static func fit_text(font: Font, p_text: String, p_size: int, p_max_w: float) -> String:
	## Trims the TAIL of a label that does not fit: the important part of these strings
	## is at the front ("EXP POTION ..." beats "... have 3").
	## The floor is read from BalanceUI **here, not as a default argument** - HANDOFF
	## §7.66: a default parameter must not reach into another class's const.
	## [P53] The menu's and the item screen's private copies of this rule are gone; both
	## now call through to here, so a hint line and a cell title cannot trim differently.
	return trim_tail(font, p_text, p_size, p_max_w, BalanceUI.TEXT_FIT_MIN_CHARS)


# ---------------------------------------------------------------- self-check (P73)
static func _verdict(p_what: String, p_ok: bool) -> bool:
	print("[UiStyle] %s = %s | %s" % [p_what, str(p_ok), "OK" if p_ok else "FAIL"])
	return p_ok


static func self_check() -> void:
	## [P73] The button factory, proven in the only channel that runs before a window opens:
	## build one of each REAL skin in memory and read back what the engine would draw. This
	## check exists because nothing else here constructs a button - the boot scan never opens
	## a page, and the six screens and the HUD's eight buttons are built in _ready(), so a
	## factory that returned the wrong skin, or forgot to parent / forgot to wire the click,
	## would reach a player's eyes before it reached a log. That is the same blind spot P72
	## found on the battle-probe side, on the front-end side.
	## What is pinned is exactly what the six copies used to disagree about: focus, the
	## disabled font colour, the font size, the four stylebox states, who adopts the node and
	## whether the signal is connected.
	print("[UiStyle] --- the button factory (P73) ---")
	var host := Control.new()
	var tint: Color = BalanceUI.COLOR_BTN_RETREAT
	var ok := true

	## 1. the front-end skin (almanac / run / item screen / item grid): focusable, dimmed
	##    when disabled, the shared size, parented, and ONE connection on `pressed`.
	var front := make_button(host, "F", Callable(host, "queue_free"))
	ok = _verdict("front-end skin: FOCUS_ALL, %d px font, dim when disabled, parented, wired"
		% int(BalanceUI.FONT_SIZE_MENU_ROW),
		front.focus_mode == Control.FOCUS_ALL and front.text == "F" \
		and int(front.get_theme_font_size("font_size")) == int(BalanceUI.FONT_SIZE_MENU_ROW) \
		and bool(front.has_theme_color_override("font_disabled_color")) \
		and bool(front.has_theme_stylebox_override("hover")) \
		and front.get_parent() == host \
		and front.pressed.get_connections().size() == 1) \
		and ok

	## 2. the HUD skin: not focusable (the hotkeys own the keyboard today), no disabled dim
	##    (three of these buttons DO get disabled - hud.gd:796/803/805 - and have always worn
	##    Godot's own grey), and NOT parented here: the HUD names it first.
	var small := make_button(null, "H", Callable(host, "queue_free"),
		BalanceUI.FONT_SIZE_BUTTON, Control.FOCUS_NONE, {}, false)
	ok = _verdict("HUD skin: FOCUS_NONE, %d px font, no disabled override, no parent yet"
		% int(BalanceUI.FONT_SIZE_BUTTON),
		small.focus_mode == Control.FOCUS_NONE \
		and int(small.get_theme_font_size("font_size")) == int(BalanceUI.FONT_SIZE_BUTTON) \
		and not bool(small.has_theme_color_override("font_disabled_color")) \
		and small.get_parent() == null \
		and small.pressed.get_connections().size() == 1) \
		and ok

	## 3. the menu's row button: an empty label, no size override at all, and a skin without
	##    a click (the caller wires it after it has added its own child labels).
	var row := make_button(null, "", Callable(), -1)
	ok = _verdict("menu row skin: no text, no font-size override, no connection, no parent",
		not bool(row.has_theme_font_size_override("font_size")) \
		and row.text == "" and row.pressed.get_connections().is_empty() \
		and row.get_parent() == null) \
		and ok

	## 4. a coloured button keeps the lift factors the caller asked for - the garden's 0.12
	##    and the HUD's RETREAT 0.14 are NOT averaged into one number.
	var col := make_button(null, "C", Callable(host, "queue_free"),
		BalanceUI.FONT_SIZE_HUD_SMALL, Control.FOCUS_NONE, colored_styles(tint, 0.14, 0.16),
		false)
	ok = _verdict("colored styles: hover lifts 0.14, pressed sinks 0.16, disabled stays shared",
		(col.get_theme_stylebox("hover") as StyleBoxFlat).bg_color == tint.lightened(0.14) \
		and (col.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color == tint.darkened(0.16) \
		and (col.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color \
			== BalanceUI.COLOR_BTN_BG_DISABLED) \
		and ok

	## Everything above is off-tree, so the check has to hand its nodes back or it would join
	## the exit-leak count this project already tracks (task #4). host.free() takes `front`.
	host.free()
	small.free()
	row.free()
	col.free()
	print("[UiStyle] self-check %s" % ("PASSED" if ok else "FAILED"))
