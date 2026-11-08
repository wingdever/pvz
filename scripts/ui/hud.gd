extends Control
## [P9] Heads-up display, laid out from Layout so it follows the window.
##
## Top bar    : sun / round / brain / counts on line 1 (the next wave hugs the
##              right edge), phase + level on line 2.
## Bottom bar : "SCROLLS" / "TOOLS" label column, two card rows starting at the
##              lawn's left edge, END TURN spanning both rows on the right.
## Overlay    : dimmed window + result panel + clickable RESTART button.
##
## Every rectangle comes from Layout (see scripts/core/layout.gd); this file owns
## only the drawing and the enable/select state. Built entirely in code.
## [P109] The old `var profile: Profile = null` was never assigned after the board became
## a scene; the one handle the HUD has is `board`, and the scroll gate is its door.
var board: Battle = null             # THIS battle - typed, because the boundary is one class

var _cards: Dictionary = {}           # plant_id -> Button
var _card_labels: Dictionary = {}     # plant_id -> Array[Label]
var _card_style: Dictionary = {}      # plant_id -> Dictionary of StyleBoxFlat
var _card_state: Dictionary = {}      # plant_id -> Dictionary {disabled, selected, cost}
var _card_cd: Dictionary = {}          # [P12] plant_id -> {bg, fill, x, y, w, h}

## [P38] The last readout signature the HUD painted (see _readout_signature).
var _draw_sig := ""

var _tools: Dictionary = {}           # tool_id -> Button
var _tool_labels: Dictionary = {}     # tool_id -> Array[Label]
var _tool_style: Dictionary = {}
var _tool_state: Dictionary = {}

var _end_turn: Button = null
var _end_turn_disabled: int = -1      # -1 unknown, 0 enabled, 1 disabled
var _restart: Button = null
var _main_menu: Button = null
var _restart_visible: int = -1
# [P13] in-battle corner buttons (top right)
var _settings_btn: Button = null
var _retreat_btn: Button = null
var _pack_btn: Button = null
var _retreat_armed: int = -1          # -1 unknown, 0 plain, 1 waiting for a 2nd click
# [P15] in-battle backpack panel. [P22] It shows the same ItemTile grid as the
# warehouse and the shop, so the three screens read alike: click a cell for its
# details, then use the button below.
var _pack_grid: ItemGrid = null
var _pack_detail: Label = null
var _pack_use: Button = null
var _pack_close: Button = null
var _pack_rows: Array = []            # the rows the grid is showing right now
var _pack_selected: String = ""
var _pack_shown: int = -1             # -1 unknown, 0 hidden, 1 shown


func _ready() -> void:
	## [P37-A11] TOP_LEFT rather than FULL_RECT: this overlay's geometry is authored by
	## _apply_layout() out of Layout.size, and full-rect anchors let the viewport write
	## its own size over that right after _ready() - which is exactly what the engine
	## warns about ("size overridden after _ready()").
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cards()
	_build_tools()
	_build_end_turn()
	_build_restart()
	_build_main_menu()
	_build_top_buttons()
	_apply_layout()


func _process(_delta: float) -> void:
	## [P38] OPTIMIZATIONS B1: this used to be `queue_redraw()` + `_sync_states()`, which
	## rebuilt the whole HUD's draw commands 60 times a second - every readout string
	## re-formatted through Loc.tf(), every one re-MEASURED (`_text_width` of the stat flow
	## is what made it visible), for a top bar whose numbers move once per sun tick.
	## The repaint is now gated on the readout signature: the values the DRAWN readouts
	## (not the Control ones) are built from. A resize still repaints on its own, because
	## _apply_layout() ends in queue_redraw().
	_sync_states()
	var sig := _readout_signature()
	if sig != _draw_sig:
		_draw_sig = sig
		queue_redraw()


func _readout_signature() -> String:
	## [P38] Everything _draw() / _draw_top_bar() / _draw_bottom_bar() / the two overlays
	## turn into text, in ONE string. It deliberately repeats the getters the drawers call
	## - they are plain field reads and a few list counts - because the alternative is
	## plumbing a dirty flag into every rule that can move a number, and that is how a HUD
	## ends up stale. The language is part of it: switching it re-labels every drawn word.
	## The result panel's stat lines are only read while the panel is up (it is a list).
	if board == null:
		return ""
	var finished: bool = board.is_finished()
	var stats := ""
	if finished:
		stats = "; ".join(board.result_lines)
	return "%s|%d|%d|%d|%d|%d|%d|%d|%s|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s" % [
		Loc.language, board.sun, board.round_no, board.brain_hp, board.brain_hp_max(),
		board.plant_total(), board.zombie_total(), board.backpack_total(),
		board.summon_scrolls_state(), int(board.can_summon_more()), int(board.is_pack_open()),
		int(finished), board.phase_hint(), board.level_label(), board.next_wave_text(),
		board.status_message, board.hover_text(), board.end_reason, stats]


# ---------------------------------------------------------------- responsive layout
func on_layout_changed() -> void:
	## Called by Game after the window changed the geometry.
	_apply_layout()


func _apply_layout() -> void:
	## Called once at start-up and again on every window resize.
	position = Vector2.ZERO
	size = Layout.size

	var x := Layout.cards_x
	## [P32] the rail is laid out with the BATTLE DECK only: cards the seed-picking
	## page left out stay hidden (see _sync_states) and must not reserve an x slot.
	## battle_cards() falls back to the full roster, so an unpicked battle is unchanged.
	for id in board.battle_cards():
		var key := str(id)
		_place_card(key, _cards[key], Vector2(x, Layout.card_y))
		x += Layout.card_size.x + Layout.card_gap
	x = Layout.cards_x
	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		_place_card(key, _tools[key], Vector2(x, Layout.tool_y))
		x += Layout.card_size.x + Layout.card_gap

	_place_button(_end_turn, Layout.end_turn.position, Layout.end_turn.size)
	var top_size: Vector2 = BalanceUI.TOP_BUTTON_SIZE
	var top_count: int = BalanceUI.TOP_BUTTON_COUNT
	_place_button(_settings_btn, Layout.top_button_pos(0, top_count, top_size), top_size)
	_place_button(_pack_btn, Layout.top_button_pos(1, top_count, top_size), top_size)
	_place_button(_retreat_btn, Layout.top_button_pos(2, top_count, top_size), top_size)
	_layout_pack_panel()
	var result_size: Vector2 = BalanceUI.RESTART_SIZE
	var result_count: int = BalanceUI.RESULT_BUTTON_COUNT
	_place_button(_restart, Layout.result_button_pos(0, result_count, result_size), result_size)
	_place_button(_main_menu, Layout.result_button_pos(1, result_count, result_size), result_size)
	queue_redraw()


func _place_button(btn: Button, pos: Vector2, box: Vector2) -> void:
	if btn == null:
		return
	btn.position = pos
	btn.custom_minimum_size = box
	btn.size = box


func _place_card(card_key: String, btn: Button, pos: Vector2) -> void:
	if btn == null:
		return
	_place_button(btn, pos, Layout.card_size)
	## [P26] A card icon (when the unit has art) takes the left edge and the two text
	## lines are centred in what is left. Both numbers come from Balance, and the box is
	## read from Layout at runtime, so a resized window keeps the same proportions.
	## [P37-A11] Godot drops a meta entry whose value is null, so the "icon" key exists
	## only on a card that really has a picture (a tool card has none) - and the
	## two-argument get_meta() logs the missing key all the same, hence has_meta().
	var icon: TextureRect = null
	if btn.has_meta("icon"):
		icon = btn.get_meta("icon") as TextureRect
	var inset := 0.0
	var card_w: float = Layout.card_size.x
	if icon != null and is_instance_valid(icon) and icon.visible:
		var side: float = minf(BalanceUI.CARD_ICON_SIZE,
			maxf(Layout.card_size.y - BalanceUI.CARD_ICON_MARGIN * 2.0, 0.0))
		icon.position = Vector2(BalanceUI.CARD_ICON_MARGIN, (Layout.card_size.y - side) * 0.5)
		icon.size = Vector2(side, side)
		icon.custom_minimum_size = Vector2(side, side)
		inset = BalanceUI.CARD_ICON_MARGIN * 2.0 + side
	for item in [btn.get_meta("title_label"), btn.get_meta("sub_label")]:
		var label := item as Label
		label.position.x = inset
		label.size = Vector2(maxf(card_w - inset, 1.0), BalanceUI.CARD_LABEL_HEIGHT)
	_place_cd_strip(card_key)


func _place_cd_strip(card_key: String) -> void:
	## [P12] Plant cards own a cooldown strip laid along their bottom edge.
	if not _card_cd.has(card_key):
		return
	var strip: Dictionary = _card_cd[card_key]
	var bg := strip["bg"] as ColorRect
	var fill := strip["fill"] as ColorRect
	if bg == null or fill == null:
		return
	var w := Layout.card_size.x - BalanceUI.CARD_CD_STRIP_INSET * 2.0
	var h := BalanceUI.CARD_CD_STRIP_H
	var y := Layout.card_size.y - BalanceUI.CARD_CD_STRIP_BOTTOM - h
	strip["x"] = BalanceUI.CARD_CD_STRIP_INSET
	strip["y"] = y
	strip["w"] = w
	strip["h"] = h
	bg.position = Vector2(BalanceUI.CARD_CD_STRIP_INSET, y)
	bg.size = Vector2(w, h)
	fill.position = bg.position
	fill.size = Vector2(w * _cd_ratio(card_key), h)


func _cd_ratio(plant_id: String) -> float:
	if board == null:
		return 1.0
	var cooldown: int = int(board.plant_cooldown_of(plant_id))
	if cooldown <= 0:
		return 1.0
	return clampf(float(board.plant_charge_of(plant_id)) / float(cooldown), 0.0, 1.0)


func _make_cd_strip(btn: Button) -> Dictionary:
	## The strip has to be a CHILD of the button: a Control's _draw() renders
	## underneath its children, so anything this file painted itself would be
	## hidden behind the card's opaque stylebox.
	var bg := ColorRect.new()
	bg.name = "CooldownBg"
	bg.color = BalanceUI.COLOR_BAR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.name = "CooldownFill"
	fill.color = BalanceUI.COLOR_TOOL_READY
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.visible = false
	btn.add_child(bg)
	btn.add_child(fill)
	return {"bg": bg, "fill": fill}


func _make_card_button(card_name: String, body: Color, title: String, subtitle: String,
		hotkey_size: int, p_art: String = "") -> Button:
	var btn := Button.new()
	btn.name = card_name
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	# geometry is applied by _apply_layout(), never here
	## [P26] A card may carry the unit's own sprite on its left edge (the plant cards do,
	## the tool cards do not - a tool is a colour, not a unit). The picture is loaded
	## defensively: a plant with no art yet draws no icon at all and the text keeps the
	## full width (UiStyle.make_icon hides itself when the texture is missing).
	## [P37-A11] "icon" is therefore a meta key that EXISTS only on a card with a
	## picture: Godot discards an entry whose value is null, so storing null would
	## leave the readers below reaching for a key that was never there.
	var icon: TextureRect = null
	if p_art != "":
		icon = UiStyle.make_icon(p_art, BalanceUI.CARD_ICON_SIZE)
		btn.add_child(icon)
		btn.set_meta("icon", icon)

	var title_label := Label.new()
	title_label.text = title
	title_label.position = Vector2(0.0, BalanceUI.CARD_TITLE_Y)
	title_label.size = Vector2(BalanceUI.CARD_SIZE.x, BalanceUI.CARD_LABEL_HEIGHT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", hotkey_size)

	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.position = Vector2(0.0, BalanceUI.CARD_SUB_Y)
	sub_label.size = Vector2(BalanceUI.CARD_SIZE.x, BalanceUI.CARD_LABEL_HEIGHT)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_label.add_theme_font_size_override("font_size", hotkey_size - 2)

	btn.add_child(title_label)
	btn.add_child(sub_label)
	btn.set_meta("title_label", title_label)
	btn.set_meta("sub_label", sub_label)

	var styles := {
		"normal": UiStyle.make_style(body.darkened(0.45)),
		"hover": UiStyle.make_style(body.darkened(0.28)),
		"pressed": UiStyle.make_style(body.darkened(0.18)),
		"selected": UiStyle.make_style(body.lightened(0.12)),
		"disabled": UiStyle.make_style(BalanceUI.COLOR_CARD_BG_DISABLED),
	}
	btn.set_meta("styles", styles)
	return btn


func _apply_card_style(btn: Button, styles: Dictionary, selected: bool, enabled: bool,
		label_color_normal: Color) -> void:
	var base: StyleBoxFlat = styles["selected"] if selected else styles["normal"]
	var hover: StyleBoxFlat = base if selected else styles["hover"]
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("disabled", styles["disabled"])
	var label_color: Color = Color(0.10, 0.10, 0.10) if selected else label_color_normal
	if not enabled:
		label_color = BalanceUI.COLOR_TEXT_DIM
	(btn.get_meta("title_label") as Label).add_theme_color_override("font_color", label_color)
	btn.queue_redraw()


# ---------------------------------------------------------------- construction
func _card_title(p_hotkey: String, p_name: String) -> String:
	## [P20] "1  Peashooter" / "1  豌豆射手": the hotkey digit stays in front of the
	## language aware name. Shared by _build_cards() and refresh_texts().
	return "%s  %s" % [p_hotkey, p_name]


func _plant_hotkey(p_key: String) -> String:
	## [P34] The digit a plant card wears is its DECK SLOT, because the number keys
	## arm slots and not fixed plants (Game._select_deck_card) - so the same card
	## can read 1 in one battle and 4 in another, and a card the battle does not
	## carry wears nothing.
	if board == null:
		return ""
	return _slot_label(board.battle_cards(), p_key)


static func _slot_label(p_deck: Array, p_key: String) -> String:
	## The same lookup, on a deck the caller already has (the state sync runs every
	## frame and battle_cards() builds a list).
	var idx: int = p_deck.find(p_key)
	if idx < 0 or idx >= BalanceBattle.DECK_HOTKEY_LABELS.size():
		return ""
	return str(BalanceBattle.DECK_HOTKEY_LABELS[idx])


func _tool_hotkey(p_key: String) -> String:
	## [P34] The tool rail is fixed (8/9/0 in TOOL_CARDS order) - the plants took the
	## number row's 1..6 when the roster outgrew three cards.
	var idx: int = BalanceBattle.TOOL_CARDS.find(p_key)
	if idx < 0 or idx >= BalanceBattle.TOOL_HOTKEY_LABELS.size():
		return ""
	return str(BalanceBattle.TOOL_HOTKEY_LABELS[idx])


func _build_cards() -> void:
	for id in Balance.plant_cards():
		var key := str(id)
		## [P26] Balance.plant_def() merges the plant sheet's numbers over the built-in
		## constants, so a card shows exactly what a summon will cost and cool down for.
		var def: Dictionary = Balance.plant_def(key)
		# [P20] the name comes from Balance.plant_name() (language aware), never from
		# the PLANT_DEFS "name" field, which is the English fall-back only
		var btn := _make_card_button("Card_" + key, def["color"],
			_card_title(_plant_hotkey(key), Balance.plant_name(key)),
			Loc.tf("hud.card.cost", [int(def["cost"])]), BalanceUI.FONT_SIZE_CARD,
			Balance.plant_art(key))          # [P26] the plant's own sprite
		## [P31-B] a spirit card borrows its base plant's picture and tints it cold
		if Balance.spirit_base(key) != "" and btn.has_meta("icon"):
			(btn.get_meta("icon") as TextureRect).modulate = BalanceUI.COLOR_SPIRIT_TINT
		btn.pressed.connect(_on_card_pressed.bind(key))
		_card_labels[key] = [btn.get_meta("title_label"), btn.get_meta("sub_label")]
		_card_style[key] = btn.get_meta("styles")
		_card_state[key] = {"disabled": false, "selected": false}
		_card_cd[key] = _make_cd_strip(btn)
		_cards[key] = btn
		add_child(btn)


func _build_tools() -> void:
	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		var def: Dictionary = BalanceBattle.TOOL_DEFS[key]
		# [P20] same rule as the plant cards: BalanceBattle.tool_name() is the display name
		var btn := _make_card_button("Tool_" + key, def["color"],
			_card_title(_tool_hotkey(key), BalanceBattle.tool_name(key)),
			"", BalanceUI.FONT_SIZE_CARD)
		btn.pressed.connect(_on_tool_pressed.bind(key))
		_tool_labels[key] = [btn.get_meta("title_label"), btn.get_meta("sub_label")]
		_tool_style[key] = btn.get_meta("styles")
		_tool_state[key] = {"disabled": false, "selected": false}
		_tools[key] = btn
		add_child(btn)


func _build_end_turn() -> void:
	## [P73] The eight HUD buttons now come from UiStyle.make_button() like every button on
	## the front-end screens. `null` as the host keeps the order this file has always used:
	## build, name it, then adopt it. FOCUS_NONE and the missing disabled dim are the HUD's
	## own two differences (see UiStyle.make_button's note on both).
	var btn := UiStyle.make_button(null, Loc.t("hud.end_turn"), _on_end_turn_pressed,
		BalanceUI.FONT_SIZE_BUTTON, Control.FOCUS_NONE, {}, false)
	btn.name = "EndTurn"
	_end_turn = btn
	add_child(btn)


func _build_restart() -> void:
	var btn := UiStyle.make_button(null, Loc.t("hud.restart"), _on_restart_pressed,
		BalanceUI.FONT_SIZE_BUTTON, Control.FOCUS_NONE, {}, false)
	btn.name = "Restart"
	btn.visible = false
	_restart = btn
	add_child(btn)


func _build_main_menu() -> void:
	## Second button of the result panel: leave the board and go back to the menu.
	var btn := UiStyle.make_button(null, Loc.t("hud.main_menu"), _on_main_menu_pressed,
		BalanceUI.FONT_SIZE_BUTTON, Control.FOCUS_NONE, {}, false)
	btn.name = "MainMenu"
	btn.visible = false
	_main_menu = btn
	add_child(btn)


func _build_top_buttons() -> void:
	## [P13] Two small buttons in the top right corner of the board: SETTINGS opens
	## the settings page ON TOP of the running battle (BACK returns to the fight),
	## and RETREAT leaves the battle for good (it writes the garden back, so it asks
	## for a second click).
	var settings_btn := UiStyle.make_button(null, Loc.t("hud.settings"), _on_settings_pressed,
		BalanceUI.FONT_SIZE_HUD_SMALL, Control.FOCUS_NONE, {}, false)
	settings_btn.name = "SettingsButton"
	_settings_btn = settings_btn
	add_child(settings_btn)

	var retreat_color: Color = BalanceUI.COLOR_BTN_RETREAT
	var retreat_btn := UiStyle.make_button(null, Loc.t("hud.retreat"), _on_retreat_pressed,
		BalanceUI.FONT_SIZE_HUD_SMALL, Control.FOCUS_NONE,
		UiStyle.colored_styles(retreat_color, 0.14, 0.16), false)
	retreat_btn.name = "RetreatButton"
	_retreat_btn = retreat_btn
	add_child(retreat_btn)

	# [P15] PACK opens the in-battle backpack: items you carried in or picked up
	var pack_btn := UiStyle.make_button(null, Loc.t("hud.pack"), _on_pack_pressed,
		BalanceUI.FONT_SIZE_HUD_SMALL, Control.FOCUS_NONE, {}, false)
	pack_btn.name = "PackButton"
	_pack_btn = pack_btn
	add_child(pack_btn)

	_pack_grid = ItemGrid.new()
	_pack_grid.name = "PackGrid"
	## [P42] Same paging as the warehouse / shop: the bag box holds four kinds at a readable
	## size, and the item roster is far past that now. No mouse wheel here on purpose - this
	## panel floats over a battle, and stealing the wheel from the lawn would be a worse bug
	## than a player clicking PREV once.
	_pack_grid.paged = true
	_pack_grid.picked.connect(_on_pack_tile_picked)
	_pack_grid.visible = false
	add_child(_pack_grid)

	_pack_detail = UiStyle.make_label("", BalanceUI.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER,
		BalanceUI.FONT_SIZE_HUD_SMALL)
	_pack_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pack_detail.visible = false
	add_child(_pack_detail)

	## PACK USE is the one HUD button that does ask for the dim colour: it is disabled on
	## every click that has no usable item behind it (see _refresh_pack).
	_pack_use = UiStyle.make_button(null, Loc.t("hud.pack.use"), _on_pack_use_pressed,
		BalanceUI.FONT_SIZE_BUTTON, Control.FOCUS_NONE, {}, true)
	_pack_use.name = "PackUse"
	_pack_use.visible = false
	add_child(_pack_use)

	_pack_close = UiStyle.make_button(null, Loc.t("hud.close"), _on_pack_pressed,
		BalanceUI.FONT_SIZE_BUTTON, Control.FOCUS_NONE, {}, false)
	_pack_close.name = "PackClose"
	_pack_close.visible = false
	add_child(_pack_close)


# ---------------------------------------------------------------- language (P20)
func refresh_texts() -> void:
	_apply_button_texts()
	_sync_states()          # this is what picks CONFIRM? / the tool charge labels
	# [P22] the backpack panel carries item NAMES in its cells, so the open panel has
	# to be rebuilt from the tables as well (its buttons are done above).
	if _pack_shown == 1:
		_rebuild_pack()
	queue_redraw()


func _refresh_restart_text() -> void:
	## [P31-A] One primary result button, two vocabularies: an ordinary level asks
	## for a RESTART, a run battle asks to CLAIM its reward or to RALLY after the
	## fee was already paid (RunFlow.run_result_action_text owns the choice).
	if _restart == null or not is_instance_valid(_restart):
		return
	if board != null and board.result_action != "":
		_restart.text = board.result_action
	else:
		_restart.text = Loc.t("hud.restart")


func _apply_button_texts() -> void:
	if _end_turn != null and is_instance_valid(_end_turn):
		_end_turn.text = Loc.t("hud.end_turn")
	if _restart != null and is_instance_valid(_restart):
		_refresh_restart_text()
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.text = Loc.t("hud.main_menu")
	if _settings_btn != null and is_instance_valid(_settings_btn):
		_settings_btn.text = Loc.t("hud.settings")
	if _retreat_btn != null and is_instance_valid(_retreat_btn):
		## [P20] RETREAT may be sitting on CONFIRM? while its timeout runs; the
		## label it arms with is re-applied by _sync_states() right after this.
		_retreat_btn.text = Loc.t("hud.retreat")
	if _pack_btn != null and is_instance_valid(_pack_btn):
		_pack_btn.text = Loc.t("hud.pack")
	if _pack_close != null and is_instance_valid(_pack_close):
		_pack_close.text = Loc.t("hud.close")
	if _pack_use != null and is_instance_valid(_pack_use):
		_pack_use.text = Loc.t("hud.pack.use")
	# [P20] the card titles carry the plant / tool names, which follow the language,
	# so they have to be re-applied as well (their SUB labels are handled by
	# _sync_states(), which is called right after this).
	for id in Balance.plant_cards():
		var key := str(id)
		if _card_labels.has(key):
			var title := (_card_labels[key] as Array)[0] as Label
			## [P34] the digit is the card's DECK SLOT, not a property of the plant,
			## so it is re-read here exactly like the name beside it.
			title.text = _card_title(_plant_hotkey(key), Balance.plant_name(key))
	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		if _tool_labels.has(key):
			var title := (_tool_labels[key] as Array)[0] as Label
			title.text = _card_title(_tool_hotkey(key), BalanceBattle.tool_name(key))


func _layout_pack_panel() -> void:
	## The panel borrows the result panel's box (Layout already keeps it centred
	## and inside the screen at every window size): the tile grid on top, the detail
	## line under it, then USE + CLOSE side by side at the bottom.
	var box := Rect2(Layout.overlay_pos, BalanceUI.OVERLAY_PANEL_SIZE)
	var inset := BalanceUI.PACK_PANEL_INSET
	var width := box.size.x - inset * 2.0
	if _pack_grid != null:
		_pack_grid.position = Vector2(box.position.x + inset, box.position.y + BalanceUI.PACK_PANEL_GRID_Y)
		_pack_grid.size = Vector2(width, BalanceUI.PACK_PANEL_GRID_H)
		_pack_grid.relayout()
	_place_label(_pack_detail, Vector2(box.position.x + inset, box.position.y + BalanceUI.PACK_PANEL_DETAIL_Y),
		Vector2(width, BalanceUI.PACK_PANEL_DETAIL_H))
	var button_w: float = BalanceUI.PACK_BUTTON_W
	var button_h: float = BalanceUI.PACK_BUTTON_H
	var gap: float = BalanceUI.PACK_BUTTON_GAP
	var row_w := button_w * 2.0 + gap
	var row_x := box.position.x + (box.size.x - row_w) * 0.5
	var row_y := box.position.y + box.size.y - button_h - BalanceUI.OVERLAY_RESTART_BOTTOM_MARGIN
	_place_button(_pack_use, Vector2(row_x, row_y), Vector2(button_w, button_h))
	_place_button(_pack_close, Vector2(row_x + button_w + gap, row_y), Vector2(button_w, button_h))


func _place_label(label: Label, pos: Vector2, box: Vector2) -> void:
	if label == null:
		return
	label.position = pos
	label.size = box


func _rebuild_pack() -> void:
	## [P22] Re-read the backpack into the grid. Called when the panel opens and on a
	## live language switch, never every frame (a Button keeps its text until someone
	## sets it again; the tiles work the same way).
	_pack_rows = []
	if board != null:
		_pack_rows = board.pack_rows()
	# Default selection: the first item that can actually be used right now, else
	# the first one there is, so the panel always explains something.
	_pack_selected = ""
	for entry in _pack_rows:
		var row: Dictionary = entry
		if bool(row.get("usable", false)):
			_pack_selected = str(row.get("id", ""))
			break
	if _pack_selected == "" and not _pack_rows.is_empty():
		_pack_selected = str((_pack_rows[0] as Dictionary).get("id", ""))
	if _pack_grid != null:
		_pack_grid.show_items(_pack_rows, _pack_selected)
	_refresh_pack_detail()


func _refresh_pack_detail() -> void:
	var row := _pack_row(_pack_selected)
	if _pack_detail != null:
		if _pack_rows.is_empty():
			_pack_detail.text = Loc.t("msg.pack.empty")
		elif row.is_empty():
			_pack_detail.text = Loc.t("hud.pack.pick")
		else:
			_pack_detail.text = str(row.get("title", "")) + "   -   " + str(row.get("desc", ""))
	if _pack_use != null:
		var usable: bool = not row.is_empty() and bool(row.get("usable", false))
		_pack_use.visible = usable
		_pack_use.disabled = not (usable and board != null and board.is_operation())
		_pack_use.text = Loc.t("hud.pack.use")


func _pack_row(p_id: String) -> Dictionary:
	if p_id == "":
		return {}
	for entry in _pack_rows:
		var row: Dictionary = entry
		if str(row.get("id", "")) == p_id:
			return row
	return {}


# ---------------------------------------------------------------- callbacks
func _on_card_pressed(plant_id: String) -> void:
	if board != null:
		board.select_plant(plant_id)


func _on_tool_pressed(tool_id: String) -> void:
	if board != null:
		board.select_tool(tool_id)


func _on_end_turn_pressed() -> void:
	if board != null:
		board.end_turn()


func _on_restart_pressed() -> void:
	if board != null:
		board.left.emit(board.result_action_id)


func _on_main_menu_pressed() -> void:
	if board != null:
		board.left.emit("menu")


func _on_settings_pressed() -> void:
	if board != null:
		## [P109] Ask the board through its own door, like every handler above does - the
		## HUD no longer fires the board's signal for it.
		board.request_settings()


func _on_retreat_pressed() -> void:
	if board != null:
		board.retreat()


func _on_pack_pressed() -> void:
	if board != null:
		board.toggle_pack()


func _on_pack_tile_picked(p_id: String) -> void:
	## [P22] Clicking a cell only SELECTS it: the detail line and the USE button
	## appear underneath, which is the "click an item to see what it does" rule the
	## warehouse and the shop follow too. Nothing is consumed by a click.
	_pack_selected = p_id
	if _pack_grid != null:
		_pack_grid.select(p_id)
	_refresh_pack_detail()


func _on_pack_use_pressed() -> void:
	## The one usable thing today: arming an energy bean. Game decides whether it
	## works (phase, stock) and says so on the battle message line.
	if board != null:
		board.arm_energy_bean()


# ---------------------------------------------------------------- state sync
func _sync_states() -> void:
	if board == null:
		return
	var operation: bool = board.is_operation()
	## [P34] read ONCE per sync: it is both the visibility rule and the deck slot the
	## card's key digit comes from (and it builds a list, so do not call it per card).
	var deck: Array = board.battle_cards()

	for id in Balance.plant_cards():
		var key := str(id)
		var btn: Button = _cards[key]
		var st: Dictionary = _card_state[key]
		## [P38] OPTIMIZATIONS B1: the price is sheet data and the sheet is loaded once, so
		## going through plant_def() per frame rebuilt (and duplicated) a whole definition
		## Dictionary per card for a number that never moves. A run system that DOES change
		## a price has to clear this key; the HUD itself only ever reads it.
		if not st.has("cost"):
			st["cost"] = Balance.plant_cost(key)
		var cost := int(st["cost"])
		## [P32] a card the seed-picking page left out of the deck is not part of
		## this battle: hide the button outright (the rail re-compacts without it,
		## see _apply_layout) instead of showing a permanently greyed slot.
		if not deck.has(key):
			btn.visible = false
			continue
		btn.visible = true
		## [P34] the digit in front of the name is the deck slot, so a NEW deck has
		## to relabel the card - the name line is refreshed the same way.
		var title: Label = (_card_labels[key] as Array)[0] as Label
		var want_title := _card_title(_slot_label(deck, key), Balance.plant_name(key))
		if title != null and title.text != want_title:
			title.text = want_title
		# [P12] three things gate a plant card now: the phase, the sun cost, and
		# whether the garden can actually hand over an instance of this type
		# [P13] plus the round's summon budget, [P14] plus owning the scroll item
		var is_ready: bool = board.is_plant_card_ready(key)
		var has_scroll: bool = board.has_scroll_for(key)
		var scrolls_ok: bool = board.can_summon_more()
		## [P31-B] a spirit card draws from no garden pool: neither its gate nor
		## its subtitle may count one
		var spirit: bool = Balance.spirit_base(key) != ""
		var free_count: int = board.garden_available_count(key)
		var pool_ok: bool = spirit or free_count > 0
		var enabled: bool = operation and has_scroll and is_ready and pool_ok and scrolls_ok and board.sun >= cost
		var selected: bool = board.selected_plant == key
		if bool(st["disabled"]) != (not enabled) or bool(st["selected"]) != selected:
			st["disabled"] = not enabled
			st["selected"] = selected
			btn.disabled = not enabled
			_apply_card_style(btn, _card_style[key], selected, enabled, BalanceUI.COLOR_TEXT)
		var sub: Label = _card_labels[key][1]
		var want_sub := Loc.tf("hud.card.sub", [cost, free_count])
		var sub_color: Color = BalanceUI.COLOR_TEXT
		if not has_scroll:
			want_sub = Loc.t("hud.card.no_scroll")
			sub_color = BalanceUI.COLOR_LOCKED
		elif spirit:
			want_sub = Loc.tf("hud.card.spirit_sub", [cost])
		elif free_count <= 0:
			sub_color = BalanceUI.COLOR_GARDEN_DOWNED
		if sub.text != want_sub:
			sub.text = want_sub
			sub.add_theme_color_override("font_color", sub_color)
		elif sub.get_theme_color("font_color") != sub_color:
			sub.add_theme_color_override("font_color", sub_color)
		var strip: Dictionary = _card_cd[key]
		var fill := strip["fill"] as ColorRect
		if fill != null:
			var bar_w: float = float(strip.get("w", 0.0))
			var bar_h: float = float(strip.get("h", BalanceUI.CARD_CD_STRIP_H))
			var box := Vector2(bar_w * _cd_ratio(key), bar_h)
			if fill.size != box:
				fill.size = box
			var want_color: Color = BalanceUI.COLOR_TOOL_READY if is_ready else BalanceUI.COLOR_BAR_FILL
			if fill.color != want_color:
				fill.color = want_color
			if not fill.visible:
				fill.visible = true

	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		var btn: Button = _tools[key]
		var is_ready: bool = board.is_tool_ready(key)
		var enabled: bool = operation and is_ready
		var selected: bool = board.selected_tool == key
		var st: Dictionary = _tool_state[key]
		if bool(st["disabled"]) != (not enabled) or bool(st["selected"]) != selected:
			st["disabled"] = not enabled
			st["selected"] = selected
			btn.disabled = not enabled
			_apply_card_style(btn, _tool_style[key], selected, enabled, BalanceUI.COLOR_TEXT)
		var sub: Label = _tool_labels[key][1]
		var charge := "%d/%d" % [board.tool_charge_of(key), board.tool_threshold_of(key)]
		var want_text := Loc.t("hud.tool.is_ready") if is_ready else charge
		if sub.text != want_text:
			sub.text = want_text
			sub.add_theme_color_override("font_color",
				BalanceUI.COLOR_TOOL_READY if is_ready else BalanceUI.COLOR_TEXT_DIM)

	var want_disabled := 0 if operation else 1
	if _end_turn_disabled != want_disabled:
		_end_turn_disabled = want_disabled
		_end_turn.disabled = (want_disabled == 1)
		_end_turn.queue_redraw()

	var want_visible := 1 if board.is_finished() else 0
	if _restart_visible != want_visible:
		_restart_visible = want_visible
		_restart.visible = (want_visible == 1)
		_restart.disabled = (want_visible == 0)
		_main_menu.visible = (want_visible == 1)
		_main_menu.disabled = (want_visible == 0)
		## [P31-A] a run battle's panel speaks the run's words (CLAIM REWARDS /
		## RALLY AND RETRY): re-decided exactly when the panel appears.
		_refresh_restart_text()

	# [P13] RETREAT asks for a second click while it is armed
	var want_armed := 1 if board.is_retreat_armed() else 0
	if _retreat_armed != want_armed:
		_retreat_armed = want_armed
		_retreat_btn.text = Loc.t("hud.confirm") if want_armed == 1 else Loc.t("hud.retreat")
		_retreat_btn.queue_redraw()

	# [P22] the in-battle backpack panel. The rows are rebuilt when the panel opens
	# (and on a live language switch), never every frame; the USE button's enabled
	# state does follow the phase, which can change while the panel is still up.
	var want_pack := 1 if board.is_pack_open() else 0
	if _pack_shown != want_pack:
		_pack_shown = want_pack
		_pack_grid.visible = (want_pack == 1)
		_pack_detail.visible = (want_pack == 1)
		_pack_close.visible = (want_pack == 1)
		if want_pack == 1:
			_rebuild_pack()
		else:
			_pack_selected = ""
			_pack_use.visible = false
	if want_pack == 1 and _pack_use != null and _pack_use.visible:
		_pack_use.disabled = not board.is_operation()


# ---------------------------------------------------------------- text helpers
func _text_width(font: Font, text: String, font_size: int) -> float:
	## [P53] The measurement rule itself lives in UiStyle now, so "how wide is this label"
	## has one answer in the project. The name stays because the four callers below are
	## layout (right-aligning and flowing the stats line), not trimming.
	return UiStyle.width_of(font, text, font_size)


func _draw_text_right(font: Font, right_x: float, y: float, text: String, font_size: int,
		color: Color) -> void:
	## Godot's draw_string() only honours `alignment` together with a positive
	## width, so right-aligned text is placed by measuring it and drawing left.
	draw_string(font, Vector2(right_x - _text_width(font, text, font_size), y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _flow_width(font: Font, stats: Array, font_size: int, gap: float) -> float:
	## [P18] a stat with an icon is wider by the icon plus its gap.
	var total := 0.0
	for i in stats.size():
		total += _text_width(font, str(stats[i]["text"]), font_size)
		if str(stats[i].get("icon", "")) != "":
			total += BalanceUI.ICON_HUD_SIZE + BalanceUI.ICON_HUD_GAP
		if i > 0:
			total += gap
	return total


func _draw_stat_flow(font: Font, stats: Array, x0: float, y: float, font_size: int,
		room: float) -> void:
	## Left-to-right readouts: shrink to the small font when they do not fit, and
	## drop the tail rather than overlap the right-aligned text.
	var size_now := font_size
	var gap := Layout.hud_gap
	if _flow_width(font, stats, size_now, gap) > room:
		size_now = BalanceUI.FONT_SIZE_HUD_SMALL
		gap = Layout.hud_gap * 0.6
	var x := x0
	for entry in stats:
		var text := str(entry["text"])
		var icon_path := str(entry.get("icon", ""))
		var icon_w := 0.0
		if icon_path != "":
			icon_w = BalanceUI.ICON_HUD_SIZE + BalanceUI.ICON_HUD_GAP
		var tw := _text_width(font, text, size_now)
		if x + tw + icon_w > x0 + room:
			return                    # no room left: the tail readouts are dropped
		if icon_path != "":
			UiStyle.draw_icon(self, icon_path,
				Vector2(x, y - BalanceUI.ICON_HUD_SIZE + BalanceUI.TEXT_BASELINE_NUDGE * 0.6),
				BalanceUI.ICON_HUD_SIZE)
			x += icon_w
		draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, entry["color"])
		x += tw + gap


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := Layout.size.x
	var h := Layout.size.y
	draw_rect(Rect2(0.0, 0.0, w, Layout.top_h), BalanceUI.HUD_TOP_BG)
	draw_rect(Rect2(0.0, Layout.bottom_y, w, h - Layout.bottom_y), BalanceUI.HUD_BOTTOM_BG)
	if board == null:
		return
	_draw_top_bar(font, w)
	_draw_bottom_bar(font, w)
	if board.is_finished():
		_draw_result_panel(font, w, h)
	if board.is_pack_open():
		_draw_pack_panel(font, w, h)


func _draw_pack_panel(font: Font, w: float, h: float) -> void:
	## [P15] The in-battle backpack. It reuses the result panel's box; the tile grid,
	## the detail line and the USE / CLOSE buttons are real Controls placed by
	## _layout_pack_panel(), so only the frame and the two headings are drawn here.
	draw_rect(Rect2(0.0, 0.0, w, h), BalanceUI.OVERLAY_DIM)
	var pos := Layout.overlay_pos
	var panel := Rect2(pos, BalanceUI.OVERLAY_PANEL_SIZE)
	draw_rect(panel, BalanceUI.OVERLAY_PANEL_BG)
	draw_rect(panel, BalanceUI.OVERLAY_PANEL_BORDER, false, BalanceUI.OVERLAY_PANEL_BORDER_WIDTH)
	draw_string(font, Vector2(0.0, pos.y + BalanceUI.OVERLAY_TITLE_Y), Loc.t("hud.pack.title"),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_OVERLAY, BalanceUI.COLOR_MENU_TITLE)
	draw_string(font, Vector2(0.0, pos.y + BalanceUI.OVERLAY_REASON_Y),
		Loc.t("hud.pack.desc"),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_OVERLAY_SUB, BalanceUI.COLOR_TEXT)


func _draw_top_bar(font: Font, _w: float) -> void:
	var small := BalanceUI.FONT_SIZE_HUD_SMALL
	var margin := BalanceUI.HUD_SIDE_MARGIN
	# [P13] the right aligned readouts stop short of the corner buttons
	var right_x := Layout.top_bar_text_right()

	var wave: String = board.next_wave_text()   # explicit for symmetry with the draws above
	var room := right_x - margin - _text_width(font, wave, small) - BalanceUI.HUD_LINE_GAP
	# [P14] the backpack sits right after ROUND: it is the one readout that changes
	# mid-battle and must never be the one the flow drops for lack of room
	# [P18] the sun readout carries the sun icon, so the currency is recognisable
	# without reading the label
	var stats := [
		{"text": Loc.tf("hud.stat.sun", [board.sun]), "color": Balance.COLOR_SUNFLOWER,
			"icon": Balance.ART_ICON_SUN},
		{"text": Loc.tf("hud.stat.round", [board.round_no]), "color": BalanceUI.COLOR_TEXT},
		{"text": Loc.tf("hud.stat.bag", [board.backpack_total()]), "color": BalanceUI.COLOR_COIN_SILVER},
		{"text": Loc.tf("hud.stat.brain", [board.brain_hp, board.brain_hp_max()]),
			"color": BalanceUI.COLOR_BRAIN},
		{"text": Loc.tf("hud.stat.counts", [board.plant_total(), board.zombie_total()]),
			"color": BalanceUI.COLOR_TEXT},
	]
	_draw_stat_flow(font, stats, margin, BalanceUI.HUD_TOP_LINE1_Y, BalanceUI.FONT_SIZE_HUD, room)
	_draw_text_right(font, right_x, BalanceUI.HUD_TOP_LINE1_Y, wave, small, BalanceUI.COLOR_TEXT_DIM)

	draw_string(font, Vector2(margin, BalanceUI.HUD_TOP_LINE2_Y),
		Loc.tf("hud.phase", [board.phase_hint()]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, small, BalanceUI.COLOR_TEXT)
	_draw_text_right(font, right_x, BalanceUI.HUD_TOP_LINE2_Y, board.level_label(), small,
		BalanceUI.COLOR_TEXT_DIM)


func _draw_bottom_bar(font: Font, w: float) -> void:
	var small := BalanceUI.FONT_SIZE_HUD_SMALL
	var label_right := Layout.label_x + Layout.label_w
	var label_dy := Layout.card_size.y * 0.5 + BalanceUI.TEXT_BASELINE_NUDGE
	# [P13] the scroll row label doubles as the per-round summon budget, and turns
	# red once it is spent - that is what explains the whole row going grey
	# [P20] the label comes from the table: BalanceUI.ROW_LABEL_SCROLLS is English-only
	var scrolls_text := Loc.t("hud.row.summons") + "  " + str(board.summon_scrolls_state())
	var scrolls_color: Color = BalanceUI.COLOR_TEXT_DIM
	if not board.can_summon_more():
		scrolls_color = BalanceUI.COLOR_GARDEN_DOWNED
	_draw_text_right(font, label_right, Layout.card_y + label_dy, scrolls_text, small, scrolls_color)
	_draw_text_right(font, label_right, Layout.tool_y + label_dy, Loc.t("hud.row.tools"), small,
		BalanceUI.COLOR_TEXT_DIM)

	var y := Layout.bottom_y - BalanceUI.HUD_STATUS_BOTTOM_MARGIN
	if board.status_message != "":
		draw_string(font, Vector2(BalanceUI.HUD_SIDE_MARGIN, y), board.status_message,
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, BalanceUI.COLOR_MESSAGE)
	_draw_text_right(font, w - BalanceUI.HUD_SIDE_MARGIN, y, board.hover_text(), small,
		BalanceUI.COLOR_TEXT_DIM)


func _draw_result_panel(font: Font, w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 0.0, w, h), BalanceUI.OVERLAY_DIM)
	var pos := Layout.overlay_pos
	var panel := Rect2(pos, BalanceUI.OVERLAY_PANEL_SIZE)
	draw_rect(panel, BalanceUI.OVERLAY_PANEL_BG)
	draw_rect(panel, BalanceUI.OVERLAY_PANEL_BORDER, false, BalanceUI.OVERLAY_PANEL_BORDER_WIDTH)

	var accent: Color = BalanceUI.COLOR_MESSAGE if board.phase == Battle.Phase.WIN else BalanceUI.COLOR_BRAIN
	draw_string(font, Vector2(0.0, pos.y + BalanceUI.OVERLAY_TITLE_Y), board.phase_hint(),
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_OVERLAY, accent)
	draw_string(font, Vector2(0.0, pos.y + BalanceUI.OVERLAY_REASON_Y), board.end_reason,
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_OVERLAY_SUB, BalanceUI.COLOR_TEXT)

	var y := pos.y + BalanceUI.OVERLAY_STATS_Y
	for line in board.result_lines:
		draw_string(font, Vector2(pos.x + BalanceUI.OVERLAY_STATS_X, y), str(line),
			HORIZONTAL_ALIGNMENT_LEFT, -1, BalanceUI.FONT_SIZE_OVERLAY_SUB - 3, BalanceUI.COLOR_TEXT)
		y += BalanceUI.OVERLAY_STATS_STEP
