class_name BrawlRound
extends Control
## [B2b] THE RESULT PAGE - what a bout came to.
##
## It used to have two faces (the three offers and the result). The offers MOVED to the
## formation page (B2c), which is the page that shows the board: choosing an opponent and
## arranging your own half are the same decision, and reading it in two places meant seeing the
## enemy half in neither. What is left here is the receipt and the ONE button it has - the next
## round after a win, another opponent after a loss or a draw (D23) - and BOTH of those buttons
## land back on the formation page.
##
## It is a front-end page like every other one (P107): a scene, built when it is opened and
## FREED when it is left, and it owns no state - everything it shows is read from
## game.brawl_main.session, so reopening it can never desync from the session.

var game = null                      # GameManager autoload；故意不标名称

var _title := ""
var _subtitle := ""
var _hint := ""
var _entries: Array = []             # [{btn: Button}]

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $Title
@onready var _subtitle_label: Label = $Subtitle
@onready var _hint_label: Label = $Hint
@onready var _button_layer: Control = $ButtonLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_style_static()


func _style_static() -> void:
	## Colours and sizes come from code, never from the scene: a number written into a .tscn is
	## a second owner of a fact BalanceUI already has (the rule main_menu.gd follows).
	if _background != null:
		_background.color = BalanceUI.COLOR_MENU_BG
	_style_label(_title_label, BalanceUI.FONT_SIZE_MENU_TITLE, BalanceUI.COLOR_MENU_TITLE)
	_style_label(_subtitle_label, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	_style_label(_hint_label, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)


func _style_label(p_label: Label, p_font_size: int, p_color: Color) -> void:
	if p_label == null:
		return
	p_label.add_theme_font_size_override("font_size", p_font_size)
	p_label.add_theme_color_override("font_color", p_color)
	p_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_label.clip_text = true


# ---------------------------------------------------------------- public API
func open_view() -> void:
	_build()
	visible = true
	on_layout_changed()
	_focus_first()


func hide_view() -> void:
	visible = false


func on_layout_changed() -> void:
	position = Vector2.ZERO
	size = Layout.size
	if _background != null:
		_background.position = Vector2.ZERO
		_background.size = Layout.size
	_layout()
	queue_redraw()


# ---------------------------------------------------------------- page building
func _session() -> BrawlSession:
	## The page reads the round through the session's owner and NEVER keeps a copy: a stale
	## page would be a second answer to "which round is this".
	if game == null or game.brawl_main == null:
		return null
	return game.brawl_main.session


func _build() -> void:
	_clear_entries()
	var session := _session()
	if session == null:
		## Reachable only if the page outlives its session (a bug or a probe): say so instead of
		## drawing an empty screen.
		_title = Loc.t("brawl.title")
		_subtitle = ""
		_hint = Loc.t("brawl.no_session")
		_push_text()
		return
	_build_result(session)
	_push_text()


func _build_result(p_session: BrawlSession) -> void:
	var winner := str(p_session.last.get("winner", ""))
	var won := winner == BalanceBrawl.SIDE_NAMES[BalanceBrawl.SIDE_LEFT]
	if winner == "draw":
		_title = Loc.t("brawl.result.draw")
	elif won:
		_title = Loc.t("brawl.result.win")
	else:
		_title = Loc.t("brawl.result.lose")
	## [B29] The NAME the session filed at settlement, not the id looked up in the formation sheet:
	## one round's opponent may be an opponent no sheet lists, and the string it is called by is the
	## language layer's. The id stays behind it as the last resort for a report nobody filled in.
	var opponent := str(p_session.last.get("opponent_name",
		str(p_session.last.get("opponent", ""))))
	_subtitle = Loc.tf("brawl.result.line", [p_session.round_no, opponent,
		int(p_session.last.get("coin_reward", 0)), p_session.coins])
	## [B5] A WIN opens three reward cards (D16) and the round WAITS for one to be taken; a
	## loss or a draw pays nothing and offers the way back to the same round's offers (D23).
	## The cards are read from the session every time the page is built, so a page that outlived
	## its hand (or a probe) shows the truth rather than a stale copy.
	if won and not p_session.reward_cards.is_empty():
		_hint = Loc.t("brawl.reward.hint")
		for i in p_session.reward_cards.size():
			_add_button(_reward_label(p_session.reward_cards[i] as Dictionary),
				_on_reward.bind(i))
		return
	_hint = Loc.t("brawl.result.hint")
	_add_button(Loc.t("brawl.next_round") if won else Loc.t("brawl.retry"), _on_next)


func _reward_label(p_card: Dictionary) -> String:
	## [B5] One reward card as a button. Every kind reads its own sentence from the language
	## layer and its own NAME from the sheet that owns it, so this page never spells a piece or
	## an attachment itself (and an attachment's effect line is GearDB's, value and all).
	## [B7] An augment card and an equipment card are ONE branch: they differ in which word goes
	## in front of the name (brawl.reward.augment / brawl.reward.equipment) and in nothing else.
	var kind := str(p_card.get("kind", ""))
	var amount := int(p_card.get("amount", 1))
	if kind == BalanceBrawl.REWARD_KIND_PIECE:
		return Loc.tf("brawl.reward.piece", [Balance.unit_name(str(p_card.get("id", "")))])
	if kind == BalanceBrawl.REWARD_KIND_AUGMENT or kind == BalanceBrawl.REWARD_KIND_EQUIPMENT:
		var id := str(p_card.get("id", ""))
		var key := "brawl.reward.augment" if kind == BalanceBrawl.REWARD_KIND_AUGMENT 			else "brawl.reward.equipment"
		return Loc.tf(key, [GearDB.display_name(id), GearDB.effect_text(id)])
	if kind == BalanceBrawl.REWARD_KIND_CAP:
		return Loc.tf("brawl.reward.cap", [amount])
	if kind == BalanceBrawl.REWARD_KIND_COINS:
		return Loc.tf("brawl.reward.coins", [amount])
	return kind


func _clear_entries() -> void:
	for entry in _entries:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn != null and is_instance_valid(btn):
			var parent := btn.get_parent()
			if parent != null:
				parent.remove_child(btn)   # out of the tree at once: no ghost clicks
			btn.queue_free()
	_entries.clear()


func _add_button(p_text: String, p_pressed: Callable) -> Button:
	var btn := UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)
	btn.text = p_text
	btn.add_theme_font_size_override("font_size", BalanceUI.FONT_SIZE_MENU_BUTTON)
	btn.pressed.connect(p_pressed)
	_button_layer.add_child(btn)
	_entries.append({"btn": btn})
	return btn


func _push_text() -> void:
	if _title_label != null:
		_title_label.text = _title
	if _subtitle_label != null:
		_subtitle_label.text = _subtitle
	if _hint_label != null:
		_hint_label.text = _hint


# ---------------------------------------------------------------- layout
func _layout() -> void:
	var w := Layout.size.x
	var h := Layout.size.y
	if _title_label != null:
		_title_label.position = Vector2(0.0, BalanceUI.MENU_TITLE_Y - BalanceUI.FONT_SIZE_MENU_TITLE)
		_title_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_TITLE * 1.6)
	if _subtitle_label != null:
		_subtitle_label.position = Vector2(0.0,
			BalanceUI.MENU_TITLE_Y + BalanceUI.MENU_SUB_OFFSET - BalanceUI.FONT_SIZE_MENU_SUB)
		_subtitle_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_SUB * 1.6)
	if _hint_label != null:
		_hint_label.position = Vector2(0.0, h - BalanceUI.FONT_SIZE_MENU_SUB * 2.5)
		_hint_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_SUB * 1.6)
	_layout_entries()


func _layout_entries() -> void:
	## A centred column, with the same arithmetic main_menu uses (gap, row height clamped
	## between a minimum and the button's natural height) so the two pages cannot drift apart.
	var count := _entries.size()
	if count == 0:
		return
	var gap := BalanceUI.MENU_BUTTON_GAP
	var top := BalanceUI.MENU_LIST_TOP
	var bottom := Layout.size.y - BalanceUI.MENU_LIST_BOTTOM_GAP
	var avail := maxf(bottom - top, BalanceUI.MENU_ROW_MIN_HEIGHT)
	var natural := gap * float(count - 1) + float(count) * BalanceUI.MENU_BUTTON_SIZE.y
	if natural <= avail:
		top += floorf((avail - natural) * 0.5)
		avail = maxf(bottom - top, BalanceUI.MENU_ROW_MIN_HEIGHT)
	var row_h := clampf((avail - gap * float(count - 1)) / float(count),
		BalanceUI.MENU_ROW_MIN_HEIGHT, BalanceUI.MENU_BUTTON_SIZE.y)
	var width := minf(BalanceUI.MENU_BUTTON_SIZE.x, Layout.size.x - 2.0 * BalanceUI.HUD_SIDE_MARGIN)
	var x := (Layout.size.x - width) * 0.5
	for i in count:
		var row: Dictionary = _entries[i]
		var btn := row["btn"] as Button
		if btn == null:
			continue
		btn.position = Vector2(x, top + float(i) * (row_h + gap))
		btn.custom_minimum_size = Vector2(width, row_h)
		btn.size = Vector2(width, row_h)


func _focus_first() -> void:
	for entry in _entries:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn != null and is_instance_valid(btn) and btn.visible and not btn.disabled:
			btn.grab_focus()
			return


# ---------------------------------------------------------------- callbacks
func _on_reward(p_index: int) -> void:
	## [B5] The card is APPLIED and the round advanced by one door (BrawlMain.take_reward), so
	## this page cannot leave the session holding a card it has already paid for.
	if game != null:
		game.brawl_main.take_reward(p_index)


func _on_next() -> void:
	if game == null:
		return
	var session := _session()
	if session == null:
		return
	if str(session.last.get("winner", "")) == BalanceBrawl.SIDE_NAMES[BalanceBrawl.SIDE_LEFT]:
		game.brawl_main.next_round()
	else:
		game.brawl_main.repick()
