class_name SettingMenu
extends Control
## [P10] The SETTINGS screen - the last page of the old menu.gd.
##
## 从 menu.gd 拆出的最后一页。MAIN 去了 main_menu.gd，LEVELS 去了
## scripts/ui/run/levels_page.gd，这一页不再是"菜单容器里的一个分支"，它就是
## 整个屏幕：进入、绘制、构建、自检都由它自己负责。
##
## [P107 的延续] 场景声明固定骨架（Background / Title / Subtitle / Hint /
## ButtonLayer）。按钮仍代码生成：数量取决于 fullscreen 状态（窗口预设只在
## 不全屏时出现）和当前语言，把它们塞进场景只会得到一堆不会被用的样板。
##
## 它直接调 game：设置页的按钮是"改一个持久化设置并重画自己"的路由，和 Game
## 的职责一致（不需要 LEVELS 那样的信号聚合）。
##
## Usage from Game:  setting_menu.open() / setting_menu.hide_menu()

var game = null                      # GameManager autoload; untyped on purpose
var battle: Battle = null          

var _title := ""
var _subtitle := ""
var _hint := ""
var _entries: Array = []             # [{btn: Button}]
var _reset_btn: Button = null        # [P16] RESET GAME, kept for its label

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $Title
@onready var _subtitle_label: Label = $Subtitle
@onready var _hint_label: Label = $Hint
@onready var _button_layer: Control = $ButtonLayer


func _ready() -> void:
	## [P37-A11] see the same line in hud.gd: on_layout_changed() sizes this overlay
	## from Layout.size, so it needs anchors that leave size alone.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_style_static()


func _style_static() -> void:
	## 场景里声明的节点，颜色 / 字号从代码填：它们住在 BalanceUI / UiStyle，
	## 场景里硬编码等于多一个会悄悄过期的真相来源。
	if _background != null:
		_background.color = BalanceUI.COLOR_MENU_BG
	_style_label(_title_label, BalanceUI.FONT_SIZE_MENU_TITLE, BalanceUI.COLOR_MENU_TITLE)
	_style_label(_subtitle_label, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	_style_label(_hint_label, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true


# ---------------------------------------------------------------- public API
func open_view() -> void:
	_build()
	visible = true
	on_layout_changed()
	_focus_first()          # after becoming visible, otherwise focus is refused


func hide_view() -> void:
	visible = false


func back() -> bool:
	## ESC in the front-end. Returns true when it actually moved somewhere.
	## [P13] Game decides where "back" goes: into the running battle when this
	## page was opened on top of one (SETTINGS from the board), else the menu.
	if game != null:
		game.back_from_front_end()
	return true


func on_layout_changed() -> void:
	position = Vector2.ZERO
	size = Layout.size
	_layout()


# ---------------------------------------------------------------- page building
func _build() -> void:
	_clear_entries()
	_title = Loc.t("menu.settings.title")
	_subtitle = Loc.tf("menu.settings.subtitle", [Balance.SETTINGS_PATH])
	var status := Loc.t("menu.settings.window_unknown")
	if game != null:
		status = str(game.display_status_text())   # what the window manager really did
	_hint = Loc.tf("menu.settings.hint.window", [status, _current_window_text()])
	_hint += Loc.t("menu.settings.hint.f11") + Layout.geometry_line()
	_add_button(Loc.t("menu.settings.fullscreen_on") if SettingsStore.fullscreen
		else Loc.t("menu.settings.fullscreen_off"), _on_toggle_fullscreen)
	# [P20] Language switch: the button names the language you are IN, so it reads
	# correctly whichever way round it is clicked.
	_add_button(Loc.language_button_text(), _on_toggle_language)
	# [P21] Background music: an ON/OFF switch plus a volume button that walks fixed
	# steps. Both are saved with the other display settings, and both are reachable
	# mid-battle through the in-game SETTINGS overlay.
	_add_button(_music_text(), _on_toggle_music)
	_add_button(_music_volume_text(), _on_cycle_music_volume)
	# [P50] The cues get the same two buttons next to the music's, and the same reason:
	# reachable mid-battle through the SETTINGS overlay, saved with the display settings.
	_add_button(_sfx_text(), _on_toggle_sfx)
	_add_button(_sfx_volume_text(), _on_cycle_sfx_volume)
	## [P89] How the BATTLE plays: whether a landed sun gathers itself, and after how many
	## rounds. Both are saved (the [battle] section), both are reachable mid-battle through
	## this same overlay - a player who wants the lawn to tidy itself should not have to
	## leave the battle to say so.
	_add_button(_auto_sun_text(), _on_toggle_auto_sun)
	_add_button(_auto_sun_rounds_text(), _on_cycle_auto_sun_rounds)
	## [B2c] The brawl's visibility switch: does the formation page name the enemy's pieces, or
	## only mark the cells they stand on. Same [battle] section, same right to be changed without
	## leaving the game.
	_add_button(_show_enemy_text(), _on_toggle_show_enemy)
	## [B21] And the brawl's damage-politeness switch: does a shot that meets its OWN side pay
	## for it. Same [battle] family, same one-click reach.
	_add_button(_friendly_fire_text(), _on_toggle_friendly_fire)
	## [W11] The war's lattice switch: the deployment table and the battlefield draw from ONE
	## generator (WarField.for_each_grid_segment), so one button honestly means both screens.
	_add_button(_war_grid_text(), _on_toggle_war_grid)
	if SettingsStore.fullscreen:
		_hint = Loc.tf("menu.settings.hint.windowed", [status])
		_hint += "   -   " + Layout.geometry_line()
	else:
		for preset in BalanceUI.SETTINGS_WINDOW_PRESETS:
			var preset_size: Vector2i = preset
			_add_button(_preset_text(preset_size), _on_preset.bind(preset_size))
	# [P20] Appended AFTER that branch on purpose: the fullscreen branch REASSIGNS
	# _hint (it does not append), so a hint added before it vanishes whenever
	# fullscreen is ON - and ON is the normal state for a saved profile.
	_hint += "   -   " + Loc.t("ui.settings.language_hint")
	_hint += "   -   " + Loc.t("ui.settings.music_hint")
	## [P50] Appended in the same place for the same reason as the music hint: the
	## fullscreen branch above REASSIGNS _hint, so anything added before it disappears
	## whenever fullscreen is ON - which is the normal state of a saved profile.
	_hint += "   -   " + Loc.t("ui.settings.sfx_hint")
	## [P89] Same place, same reason as the two hints above (the fullscreen branch reassigns).
	_hint += "   -   " + Loc.t("ui.settings.sun_hint")
	# [P16] wipe the save. It asks for a second click, so the hint line says so.
	var reset_armed: bool = game != null and game.is_reset_armed()
	_reset_btn = _add_button(Loc.t("menu.settings.reset_confirm") if reset_armed
		else Loc.t("menu.settings.reset"), _on_reset)
	if reset_armed:
		_hint += Loc.t("menu.settings.hint.reset_armed")
	else:
		_hint += Loc.t("menu.settings.hint.reset_plain")
	_add_button(Loc.t("menu.back"), _on_back)
	_push_text()


func _clear_entries() -> void:
	for entry in _entries:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn != null and is_instance_valid(btn):
			var parent := btn.get_parent()
			if parent != null:
				parent.remove_child(btn)   # 立刻出树：不留幽灵点击
			btn.queue_free()
	_entries.clear()


func _push_text() -> void:
	## 场景里的 Label 收下运行时算出来的文本。离树时（自检）Label 可能为空。
	if _title_label != null:
		_title_label.text = _title
	if _subtitle_label != null:
		_subtitle_label.text = _subtitle
	if _hint_label != null:
		_hint_label.text = _hint


func _add_button(p_text: String, p_pressed: Callable) -> Button:
	var btn := _make_button()
	btn.text = p_text
	btn.add_theme_font_size_override("font_size", BalanceUI.FONT_SIZE_MENU_BUTTON)
	btn.pressed.connect(p_pressed)
	_button_layer.add_child(btn)
	_entries.append({"btn": btn})
	return btn


func _make_button() -> Button:
	## [P73] UiStyle.make_button() with the menu's own shape: no text yet (the caller
	## writes it), no font size on the button, no disabled dim, and no parent, because
	## _add_button() hands it to _button_layer.
	return UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)


func _process(_delta: float) -> void:
	## [P16] keep the RESET GAME label honest while its confirm window runs: the
	## button has to say "CONFIRM?" only while the second click would actually fire.
	if not visible or _reset_btn == null or game == null:
		return
	if not is_instance_valid(_reset_btn):
		_reset_btn = null
		return
	var armed: bool = game.is_reset_armed()
	var want := Loc.t("menu.settings.reset_confirm") if armed else Loc.t("menu.settings.reset")
	if _reset_btn.text != want:
		_reset_btn.text = want


# ---------------------------------------------------------------- layout
func _list_bottom() -> float:
	## 这一页没有地板，列表的下限只受页脚提示行约束。
	return Layout.size.y - BalanceUI.MENU_HINT_BOTTOM_MARGIN - BalanceUI.MENU_LIST_BOTTOM_GAP


func _layout() -> void:
	_layout_labels()
	_layout_entries()


func _layout_labels() -> void:
	## 场景里的标签随窗口走，因为 Layout.size 是布局的唯一真相。
	var w := Layout.size.x
	var h := Layout.size.y
	if _title_label != null:
		## Label 的 position.y 是顶部，原 _draw 里 MENU_TITLE_Y 是 baseline，
		## 所以减掉一个字号近似对齐。
		_title_label.position = Vector2(0.0,
			BalanceUI.MENU_TITLE_Y - BalanceUI.FONT_SIZE_MENU_TITLE)
		_title_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_TITLE * 1.6)
	if _subtitle_label != null:
		_subtitle_label.position = Vector2(0.0,
			BalanceUI.MENU_TITLE_Y + BalanceUI.MENU_SUB_OFFSET - BalanceUI.FONT_SIZE_MENU_SUB)
		_subtitle_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_SUB * 1.6)
	if _hint_label != null:
		_hint_label.position = Vector2(0.0, h - BalanceUI.MENU_HINT_BOTTOM_MARGIN)
		_hint_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_SUB * 1.6)


func _layout_entries() -> void:
	## 竖排按钮列表。搬自 menu.gd 的 _layout_entries()，去掉两件事：
	##   - `_on_main_page()` 判断（这一页没有地板，永远 false，删掉）
	##   - 居中分支（那是 MAIN 页的规矩，SETTINGS 从来没有）
	##   - `cell` 分支（那是选关页的网格，已经搬走了）
	var count := _entries.size()
	if count == 0:
		return
	var gap := BalanceUI.MENU_BUTTON_GAP
	var bottom := _list_bottom()
	var top: float = BalanceUI.MENU_LIST_TOP
	var avail := maxf(bottom - top, BalanceUI.MENU_ROW_MIN_HEIGHT)
	var needed := gap * float(count - 1) + float(count) * BalanceUI.MENU_ROW_MIN_HEIGHT
	if needed > avail:
		# 行多了？先往上顶再挤压行高
		top = BalanceUI.MENU_LIST_TOP_MIN
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
func _on_toggle_fullscreen() -> void:
	if game != null:
		game.set_fullscreen(not SettingsStore.fullscreen)


func _on_toggle_language() -> void:
	## [P20] Game owns the switch (it persists the choice and re-draws the screens).
	if game != null:
		game.toggle_language()


func _on_toggle_music() -> void:
	## [P21] Same reason as the language: Game persists it and pushes it into Music.
	if game != null:
		game.toggle_music()


func _on_cycle_music_volume() -> void:
	if game != null:
		game.cycle_music_volume()


func _on_toggle_sfx() -> void:
	## [P50] Game owns the switch (it persists the choice and re-draws the page), so the
	## label, the saved value and the running pool cannot disagree.
	if game != null:
		game.toggle_sfx()


func _on_cycle_sfx_volume() -> void:
	if game != null:
		game.cycle_sfx_volume()


func _on_preset(p_size: Vector2i) -> void:
	if game != null:
		game.set_window_size(p_size)


func _on_reset() -> void:
	## [P16] Destructive and irreversible, so Game asks for a second click.
	if game != null:
		game.request_reset()


func _on_back() -> void:
	## BACK 按钮和 ESC 走同一条逻辑：都是 Game 决定"退回哪"。
	back()


# ---------------------------------------------------------------- helpers
## [P89] THE TWO SUN BUTTONS. The switch names the state that is ON, like the audio ones,
## and the second button walks BalanceBattle.SUN_AUTO_ROUNDS_CHOICES rather than taking a
## number: a saved setting a player can only reach with the keyboard is not a setting.
func _on_toggle_auto_sun() -> void:
	SettingsStore.set_auto_collect_sun(not SettingsStore.auto_collect_sun)
	if game != null:
		game.apply_language()          # relabel this page, the same door the language uses


func _on_cycle_auto_sun_rounds() -> void:
	var choices: Array[int] = BalanceBattle.SUN_AUTO_ROUNDS_CHOICES
	var i: int = choices.find(SettingsStore.sun_auto_rounds)
	SettingsStore.set_sun_auto_rounds(choices[(i + 1) % choices.size()])
	if game != null:
		game.apply_language()


func _on_toggle_show_enemy() -> void:
	SettingsStore.set_show_enemy_pieces(not SettingsStore.show_enemy_pieces)
	if game != null:
		game.apply_language()          # relabel this page, the same door the language uses


func _on_toggle_friendly_fire() -> void:
	## [B21] The store owns the persistence; the arena picks the new value up on the NEXT shot
	## (BrawlShot captures it at launch), so a mid-bout flip is a policy change, not a reweld.
	SettingsStore.set_friendly_fire(not SettingsStore.friendly_fire)
	if game != null:
		game.apply_language()


func _on_toggle_war_grid() -> void:
	## [W11] A display choice: flip, persist, relabel this page - the two war screens read the
	## variable themselves the next time they open, so nothing here has to know they exist.
	SettingsStore.set_war_grid(not SettingsStore.war_grid)
	if game != null:
		game.apply_language()


func _war_grid_text() -> String:
	return Loc.t("menu.settings.war_grid_on" if SettingsStore.war_grid
		else "menu.settings.war_grid_off")


func _friendly_fire_text() -> String:
	return Loc.t("menu.settings.friendly_fire_on" if SettingsStore.friendly_fire
		else "menu.settings.friendly_fire_off")


func _show_enemy_text() -> String:
	return Loc.t("menu.settings.show_enemy_on" if SettingsStore.show_enemy_pieces
		else "menu.settings.show_enemy_off")


func _auto_sun_text() -> String:
	return Loc.t("menu.settings.sun_auto_on" if SettingsStore.auto_collect_sun
		else "menu.settings.sun_auto_off")


func _auto_sun_rounds_text() -> String:
	## The second button is only meaningful while the first one says ON, and it says so:
	## a greyed number next to "自动拾取：关" would be a control that does nothing.
	if not SettingsStore.auto_collect_sun:
		return Loc.t("menu.settings.sun_rounds_off")
	return Loc.tf("menu.settings.sun_rounds", [SettingsStore.sun_auto_rounds])


func _music_text() -> String:
	## [P21] Read through Game so the label, the saved value and the running music can
	## never disagree; the fallback keeps the page working before Game is wired up.
	if game != null:
		return str(game.music_button_text())
	return Loc.t("menu.settings.music_on" if SettingsStore.music_on else "menu.settings.music_off")


func _music_volume_text() -> String:
	if game != null:
		return str(game.music_volume_text())
	return Loc.tf("menu.settings.music_volume", [Music.volume_percent()])


func _sfx_text() -> String:
	## [P50] Same shape as _music_text(): read through Game so the button and the saved
	## value cannot drift, with a SettingsStore fallback for the page built before Game
	## is wired up.
	if game != null:
		return str(game.sfx_button_text())
	return Loc.t("menu.settings.sfx_on" if SettingsStore.sfx_on else "menu.settings.sfx_off")


func _sfx_volume_text() -> String:
	if game != null:
		return str(game.sfx_volume_text())
	return Loc.tf("menu.settings.sfx_volume", [int(round(SettingsStore.sfx_volume * 100.0))])


func _current_window_text() -> String:
	var win := get_window()
	if win == null:
		return "?"
	return "%d x %d" % [win.size.x, win.size.y]


func _preset_text(p_size: Vector2i) -> String:
	var win := get_window()
	var current := win != null and win.size == p_size
	return ("%d x %d   *" % [p_size.x, p_size.y]) if current else ("%d x %d" % [p_size.x, p_size.y])


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## 设置页自己的审计：场景骨架必须在（一个节点改名 = @onready 静默 null），
	## 窗口预设必须非空且为正（负尺寸在运行时才炸，比在日志里炸贵得多）。
	print("[SettingMenu] --- settings page ---")
	var ok := true

	var presets: Array = BalanceUI.SETTINGS_WINDOW_PRESETS
	var preset_ok: bool = not presets.is_empty()
	for p in presets:
		var s: Vector2i = p
		if s.x <= 0 or s.y <= 0:
			preset_ok = false
	ok = ok and preset_ok
	print("[SettingMenu] %d window preset(s), all positive = %s | %s"
		% [presets.size(), str(preset_ok), "OK" if preset_ok else "FAIL"])

	var scene: PackedScene = load("res://scenes/ui/settings.tscn")
	if scene == null:
		print("[SettingMenu] scene missing: res://scenes/ui/settings.tscn | FAIL")
		print("[SettingMenu] self-check FAILED")
		return
	var probe: SettingMenu = scene.instantiate()
	var skeleton_ok: bool = probe.get_node_or_null("Background") != null \
		and probe.get_node_or_null("Title") != null \
		and probe.get_node_or_null("Subtitle") != null \
		and probe.get_node_or_null("Hint") != null \
		and probe.get_node_or_null("ButtonLayer") != null
	ok = ok and skeleton_ok
	print("[SettingMenu] scene skeleton complete = %s | %s"
		% [str(skeleton_ok), "OK" if skeleton_ok else "FAIL"])
	probe.free()

	print("[SettingMenu] self-check %s" % ("PASSED" if ok else "FAILED"))


# ---------------------------------------------------------------- language (P20)
func set_language(p_code: String) -> void:
	## Switch the language of the whole game: persist it, then re-draw the text that
	## is already on screen. The battle is NOT rebuilt - unit names and every panel
	## label are read while drawing, so refreshing them is enough, and a player who
	## switches mid-battle keeps their board.
	if not SettingsStore.set_language(p_code):
		return                               # already in that language: nothing to do
	game.apply_language()
	game.set_message(Loc.tf("ui.settings.language_switched",
		[str(Loc.LABELS.get(Loc.language, Loc.language))]))


func toggle_language() -> void:
	## The SETTINGS button: 中文 -> English -> 中文 ...
	set_language(Loc.next_language())


func _refresh_unit_names() -> void:
	## "Peashooter #2" becomes "豌豆射手 #2" in place: no unit is recreated.
	if battle == null:
		return
	for node in battle.grid.all_units():
		var unit := node as Unit
		if unit != null and is_instance_valid(unit):
			unit.refresh_display_name()
			unit.queue_redraw()
