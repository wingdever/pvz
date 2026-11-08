class_name MainMenu
extends Control
## [P10] 主菜单页（原 menu.gd 的 MAIN 分支）。
##
## 从 menu.gd 拆出来，理由和 LEVELS 一样（[P22]）：WAREHOUSE / SHOP 从菜单独立
## 成了自己的屏幕，因为"物品网格 + 详情"不是菜单该做的事。主菜单页长出地板、
## 四个可点击的物品、一套随 run_flow 变化的按钮列表之后，它也不再是"菜单容器里
## 的一个分支"。
##
## [P107 的延续] 场景只声明固定骨架（背景、地板、标题、提示、地板物品容器、
## 按钮容器）。按钮仍代码生成，因为它们的数量和文案取决于 run_flow.has_run_save()
## 和语言；地板物品固定四个，所以它们留在场景里。
##
## 它直接调 game：主菜单的按钮本来就是"进哪个屏幕"的路由，和 Game 的职责一致。
## （LEVELS 用 left/entered 信号是因为它有两个清晰语义，主菜单没有这种聚合。）

var game = null                      # GameManager autoload；故意不标名称

var _title := ""
var _subtitle := ""
var _hint := ""
var _entries: Array = []             # [{btn: Button}]
var _run_new_armed := false          # [P31-A] first click of NEW RUN

@onready var _background: ColorRect = $Background
@onready var _floor: ColorRect = $Floor
@onready var _floor_edge: ColorRect = $FloorEdge
@onready var _title_label: Label = $Title
@onready var _subtitle_label: Label = $Subtitle
@onready var _hint_label: Label = $Hint
@onready var _button_layer: Control = $ButtonLayer
## [D74] Five objects: the four meta screens (turn shell only) and the almanac (both shells).
@onready var _props: Array = [$PropLayer/Prop0, $PropLayer/Prop1, $PropLayer/Prop2,
	$PropLayer/Prop3, $PropLayer/Prop4]


func _ready() -> void:
	## [P37-A11] 见 hud.gd 同一行：on_layout_changed() 用 Layout.size 定尺寸，
	## 所以它需要让 size 不受锚点影响的锚点。
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_style_static()


func _style_static() -> void:
	## 场景里声明的节点，颜色 / 字号从代码填：它们住在 BalanceUI / UiStyle，
	## 场景里硬编码等于多一个会悄悄过期的真相来源。
	if _background != null:
		_background.color = BalanceUI.COLOR_MENU_BG
	if _floor != null:
		_floor.color = BalanceUI.COLOR_MENU_FLOOR
	if _floor_edge != null:
		_floor_edge.color = BalanceUI.COLOR_MENU_FLOOR_EDGE
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
	_run_new_armed = false       # [P31-A] re-entry always dis-arms the new-run click
	_build()
	visible = true
	on_layout_changed()
	_focus_first()          # after becoming visible, otherwise focus is refused


func hide_view() -> void:
	visible = false


func on_layout_changed() -> void:
	position = Vector2.ZERO
	size = Layout.size
	_layout()
	queue_redraw()


# ---------------------------------------------------------------- page building
func _build() -> void:
	_clear_entries()
	## [B2] THE TWO SHELLS (docs/prompt/BRAWL.md §10 / D20). The turn shell is the game as it
	## has always been; the classic shell is the real-time family's front door. Which one is
	## up is a REMEMBERED setting (settings.cfg [ui] shell), so switching is a rebuild of this
	## page rather than a navigation - and the switch itself is the last row of both lists.
	var classic: bool = SettingsStore.ui_shell == SettingsStore.SHELL_CLASSIC
	_title = Loc.t("menu.classic.title") if classic else Loc.t("menu.main.title")
	_subtitle = Loc.t("menu.classic.subtitle") if classic else Loc.t("menu.main.subtitle")
	_hint = Loc.t("menu.classic.hint") if classic else Loc.t("menu.main.hint")
	# 物品先摆，文字列表后摆：列表是玩家要读的东西，初始键盘焦点落在 ADVENTURE。
	## [B2] 地板上的四件 meta 东西（花园 / 仓库 / 商店 / 背包）只属于回合模式，
	## 所以经典模式不摆它们——上一个 shell 的可见性由 _clear_entries() 收走。
	## [D74] 图鉴不在这四件里：它是两边都摆的那一件（见 MENU_ICONS 的 turn_only）。
	_build_props(not classic)
	if classic:
		_add_button(Loc.t("menu.main.brawl"), _on_brawl)
		## [W3] 战争模式：经典壳的第二个入口（计划在
		## ~/.qoder-cn/plans/tranquil-inlet-widgeon.md）。乱斗是一段 session，战争是一场
		## 单局——WarMain 拥有那场比赛，这一页只说 WHICH door，和 _on_brawl 同一形状。
		_add_button(Loc.t("menu.main.war"), _on_war)
		_add_button(Loc.t("menu.main.settings"), _on_settings)
		_add_button(Loc.t("menu.main.quit"), _on_quit)
	else:
		# ADVENTURE / SURVIVAL / SETTINGS / QUIT 是文字列表——这一页的主菜。
		## [P31-A] ADVENTURE 是战役入口。有存档就分成 CONTINUE 和 NEW RUN 两个
		## （NEW RUN 需要二次点击；旧存档活到新队伍被确认为止）。
		if game != null and bool(game.run_flow.has_run_save()):
			_add_button(Loc.t("run.menu.continue"), _on_run_continue)
			_add_button(Loc.t("run.menu.new"), _on_run_new)
		else:
			_add_button(Loc.t("run.menu.adventure"), _on_adventure)
		_add_button(Loc.t("run.menu.levels"), _on_levels)
		_add_button(Loc.t("menu.main.survival"), _on_survival)
		## [D74] 图鉴的那一行文字列表**撤了**：它现在是地板上的一本书（P26 当年把它当
		## 列表项，理由是"阅读页不该占一件摆设"；用户 2026-10-05 明确要图标，两边都摆，
		## 于是它从列表搬到地板，和另外四件一样有一个画面 + 一个名字）。
		## 键盘没丢：MenuProp 是可聚焦的，TAB + ENTER 照样进得去。
		_add_button(Loc.t("menu.main.settings"), _on_settings)
		_add_button(Loc.t("menu.main.quit"), _on_quit)
	_add_button(Loc.t("menu.shell.switch_turn") if classic else Loc.t("menu.shell.switch_classic"),
		_on_switch_shell)
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
	## 地板物品属于这一页，但每次重建都要重置可见性和悬停，否则上一次离开时
	## 悬停的那个会留着一圈高亮。
	for prop in _props:
		var item := prop as MenuProp
		if item != null and is_instance_valid(item):
			item.visible = false
			item.hovered = false
			item.queue_redraw()


func _build_props(p_turn: bool) -> void:
	## [P22] 地板上的物品：洒水壶、木箱、钥匙、背包，[D74] 还有书（图鉴）。
	## BalanceUI.MENU_ICONS 拥有每个物品的位置、大小、SVG 的哪一块是画面，
	## 以及它属于哪个 shell（turn_only）；MenuProp 只知道怎么画一个。
	for i in BalanceUI.MENU_ICONS.size():
		if i >= _props.size():
			break
		var row: Dictionary = BalanceUI.MENU_ICONS[i]
		## [D74] 经典模式只摆不属于回合 meta 的那一件（今天就是图鉴）。
		if not p_turn and bool(row.get("turn_only", false)):
			continue
		var id := str(row.get("id", ""))
		var content: Rect2 = row.get("content", Rect2())
		var prop := _props[i] as MenuProp
		prop.setup(id, BalanceUI.menu_icon_title(id), str(row.get("art", "")), content,
			float(row.get("wide", 64.0)), float(row.get("lift", 0.0)),
			float(row.get("x", 0.5)))
		if not prop.picked.is_connected(_on_prop_picked):
			prop.picked.connect(_on_prop_picked)
		prop.visible = true


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
	## [P73] UiStyle.make_button() 配菜单自己的形状：暂时无文本（按钮自己写）、
	## 按钮无字号、无禁用变暗、也不指定父节点。
	return UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)


# ---------------------------------------------------------------- layout
func _list_bottom() -> float:
	## 这一页永远有地板，列表的下限永远要躲开地板带。
	return Layout.size.y - BalanceUI.MENU_FLOOR_H - BalanceUI.MENU_LIST_BOTTOM_GAP


func _layout() -> void:
	_layout_labels()
	_layout_props()
	_layout_entries()


func _layout_labels() -> void:
	var w := Layout.size.x
	var h := Layout.size.y
	var horizon := h - BalanceUI.MENU_FLOOR_H
	if _floor != null:
		_floor.position = Vector2(0.0, horizon)
		_floor.size = Vector2(w, h - horizon)
	if _floor_edge != null:
		_floor_edge.position = Vector2(0.0, horizon)
		_floor_edge.size = Vector2(w, BalanceUI.MENU_FLOOR_EDGE_H)
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
		## 这一页的底部归地板和物品，所以提示行在标题下方，不在页脚。
		_hint_label.position = Vector2(0.0,
			BalanceUI.MENU_TITLE_Y + BalanceUI.MENU_SUB_OFFSET * 2.0 - BalanceUI.FONT_SIZE_MENU_SUB)
		_hint_label.size = Vector2(w, BalanceUI.FONT_SIZE_MENU_SUB * 1.6)


func _layout_props() -> void:
	## [P22] 每个物品按它的表项给的 CENTRE 摆放（窗口宽度的一个比例），
	## 共享一条地平线：纵向错落来自每个物体的 `lift`，不是每个物体不同的基线。
	var count := _props.size()
	if count == 0:
		return
	var box: Vector2 = BalanceUI.MENU_PROP_SIZE
	var floor_y := Layout.size.y - BalanceUI.MENU_PROP_BOTTOM - box.y
	for i in count:
		var prop := _props[i] as MenuProp
		if prop == null:
			continue
		var center_x := floorf(prop.spot_x * Layout.size.x)
		prop.position = Vector2(center_x - box.x * 0.5, floor_y)
		prop.custom_minimum_size = box
		prop.size = box


func _layout_entries() -> void:
	## 竖排按钮列表。搬自 menu.gd 的 _layout_entries()，去掉两件事：
	##   - `_on_main_page()` 判断（这一页永远是主菜单，恒真，删掉）
	##   - `cell` 分支（那是选关页的网格，已经搬走了）
	var count := _entries.size()
	if count == 0:
		return
	var gap := BalanceUI.MENU_BUTTON_GAP
	var bottom := _list_bottom()
	var top: float = BalanceUI.MENU_LIST_TOP
	var avail := maxf(bottom - top, BalanceUI.MENU_ROW_MIN_HEIGHT)
	var natural := gap * float(count - 1) + float(count) * BalanceUI.MENU_BUTTON_SIZE.y
	var needed := gap * float(count - 1) + float(count) * BalanceUI.MENU_ROW_MIN_HEIGHT
	if natural <= avail:
		## [P22] 列表在这一页拥有的空间里居中，而不是吊在顶部让物品抢注意力。
		top += floorf((avail - natural) * 0.5)
		avail = maxf(bottom - top, BalanceUI.MENU_ROW_MIN_HEIGHT)
	elif needed > avail:
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
func _on_prop_picked(p_id: String) -> void:
	## [P22] 整个地板一个入口：id 决定去哪，Game（不是本文件）仍然负责切屏。
	match p_id:
		"garden":
			_on_garden()
		"warehouse":
			_on_warehouse()
		"shop":
			_on_shop()
		"backpack":
			_on_backpack()
		"almanac":
			_on_almanac()


func _on_adventure() -> void:
	## [P31-A] 没有存档：直接进队伍页（RunFlow 决定）。
	if game != null:
		game.run_flow.start_adventure()


func _on_run_continue() -> void:
	## [P31-A] 有存档：从 run.json 说的位置继续。
	if game != null:
		game.run_flow.continue_run()


func _on_run_new() -> void:
	## [P31-A] 两次点击：第一次改提示，第二次才真的出发（旧存档活到新队伍被
	## 确认为止——Game 的 begin_new_run 规则——但玩家必须真的想这么做）。
	if not _run_new_armed:
		_run_new_armed = true
		_hint = Loc.t("run.menu.new_confirm")
		_push_text()
		return
	_run_new_armed = false
	if game != null:
		game.run_flow.begin_new_run()


func _on_levels() -> void:
	## [P31-A] 关卡包的入口，保留自己的名字。
	if game != null:
		game.show_level_select()


func _on_survival() -> void:
	_hint = Loc.t("menu.main.survival_hint")
	_push_text()


func _on_brawl() -> void:
	## [B2] The classic shell's one entry. BrawlMain owns the session and its rounds exactly as
	## BattleMain owns a battle's (scripts/core/brawl/brawl_main.gd) - this page only says WHICH
	## door, the same way _on_adventure() says run_flow.start_adventure().
	## [B2b] START A SESSION, not a bout: a bout is one round of a session, and which round it is
	## belongs to the round page. This line used to call start_bout() with no argument - the door
	## that took none back then; B2b gave that door the offer's index and left this caller behind.
	## GDScript only reports that at the click, because the game handle here is untyped.
	if game != null:
		game.brawl_main.start_session()


func _on_war() -> void:
	## [W3] The classic shell's second entry. WarMain owns the match the way BrawlMain owns a
	## session (scripts/core/war/war_main.gd) - one match, no rounds, and from W4 this door
	## opens the deployment page instead of the board directly. `game` is untyped here, the
	## same door-lookup _on_brawl documents above.
	if game != null:
		game.war_main.start()


func _on_switch_shell() -> void:
	## [B2] D20: the switcher is not a navigation. The page is rebuilt in place, so the other
	## shell's entries (and its props) appear without a transition.
	SettingsStore.set_ui_shell(SettingsStore.flipped_shell())
	_build()
	on_layout_changed()
	_focus_first()


func _on_garden() -> void:
	## [P12] 花园是它自己的视图（ui/garden/garden_view.gd）；菜单只请 Game 把它带上来。
	if game != null:
		game.show_garden()


func _on_warehouse() -> void:
	## [P14/P22] 仓库是它自己的视图；主菜单只请 Game 把它带上来。
	if game != null:
		game.show_warehouse()


func _on_almanac() -> void:
	## [P26] 图鉴（植物 / 僵尸 / 关卡）。它和花园、仓库一样是自己的屏幕。
	## [D75] ONE object, TWO pages: the book on the floor opens the almanac of the shell you are
	## standing in - the turn one reads the campaign's sheets, the classic one the brawl's
	## (timed units / gear / formations). "Which shell is up" is a front-end fact, so Game picks.
	if SettingsStore.ui_shell == SettingsStore.SHELL_CLASSIC:
		if game != null:
			game.show_brawl_almanac()
		return
	if game != null:
		game.show_almanac()


func _on_shop() -> void:
	## [P22] 和仓库同款路由：Game 拥有"哪个屏幕在最上面"。
	if game != null:
		game.show_shop()


func _on_backpack() -> void:
	## [P22] 背包有自己的画面和页面。战斗外容器通常是空的（见 Game.show_backpack）。
	if game != null:
		game.show_backpack()


func _on_settings() -> void:
	if game != null:
		game.show_settings()


func _on_quit() -> void:
	if game != null:
		game.quit_game()
	else:
		get_tree().quit()


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## [P22] 主菜单地板上的四个物品，不开菜单也能审计。每个数字都住在 Balance
	## （SVG 的哪一块是画面、画多宽、躺在地板哪里），错一个就会悄悄裁图或让物品
	## 掉出屏幕——这种错误在日志里找比用眼睛找便宜得多。
	print("[MainMenu] --- main menu floor (P22) ---")
	print("[MainMenu] %d objects, floor %d px tall, object box %dx%d, art canvas %d"
		% [BalanceUI.MENU_ICONS.size(), int(BalanceUI.MENU_FLOOR_H),
		   int(BalanceUI.MENU_PROP_SIZE.x), int(BalanceUI.MENU_PROP_SIZE.y),
		   int(BalanceUI.MENU_ART_CANVAS)])
	var ok := true
	var seen: Dictionary = {}
	var centers: Array = []
	var canvas: float = BalanceUI.MENU_ART_CANVAS
	var min_w: float = float(Balance.WINDOW_SIZE.x)
	for entry in BalanceUI.MENU_ICONS:
		var row: Dictionary = entry
		var id := str(row.get("id", ""))
		var art := str(row.get("art", ""))
		var content: Rect2 = row.get("content", Rect2())
		var wide := float(row.get("wide", 0.0))
		var spot := float(row.get("x", -1.0))
		var lift := float(row.get("lift", 0.0))
		var caption := BalanceUI.menu_icon_title(id)
		var key := str(row.get("key", ""))
		## content 矩形必须落在 canvas 里，否则画面被裁。
		var inside: bool = content.size.x > 0.0 and content.size.y > 0.0 \
			and content.position.x >= 0.0 and content.position.y >= 0.0 \
			and content.position.x + content.size.x <= canvas + 0.5 \
			and content.position.y + content.size.y <= canvas + 0.5
		## "menu." 抓缺 caption 的情况：Loc.t() 那时把 KEY 原样还回来。
		var good: bool = id != "" and art != "" and wide > 0.0 and lift >= 0.0 \
			and spot >= 0.0 and spot <= 1.0 and inside \
			and caption != id and not caption.begins_with("menu.") \
			and (key == "" or Loc.t(key) == caption) and not seen.has(id)
		ok = ok and good
		seen[id] = true
		centers.append(spot * min_w)
		print("[MainMenu] %s: %s  content %dx%d at (%d,%d) drawn %d wide, centre %d%% of the width, lift %d | %s"
			% [id, art.get_file(), int(content.size.x), int(content.size.y),
			   int(content.position.x), int(content.position.y), int(wide),
			   int(spot * 100.0), int(lift), "OK" if good else "FAIL"])

	## 两个物品在最小合法窗口上永远不能挨着，也不能有谁挂到屏幕边缘外。
	centers.sort()
	var closest := 9999.0
	for i in range(1, centers.size()):
		closest = minf(closest, float(centers[i]) - float(centers[i - 1]))
	var box_w: float = BalanceUI.MENU_PROP_SIZE.x
	var spaced: bool = centers.is_empty() or closest >= box_w
	var on_screen: bool = true
	for x in centers:
		var center := float(x)
		if center - box_w * 0.5 < 0.0 or center + box_w * 0.5 > min_w:
			on_screen = false
	ok = ok and spaced and on_screen
	print("[MainMenu] closest pair %d px apart at %d wide (box %d), all on screen = %s | %s"
		% [int(closest), int(min_w), int(box_w), str(spaced and on_screen),
		   "OK" if (spaced and on_screen) else "FAIL"])

	## 场景骨架必须在（一个节点改名 = @onready 静默 null）。
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	if scene == null:
		print("[MainMenu] scene missing | FAIL")
		print("[MainMenu] self-check FAILED")
		return
	var probe: MainMenu = scene.instantiate()
	var skeleton_ok: bool = probe.get_node_or_null("Background") != null \
		and probe.get_node_or_null("Floor") != null \
		and probe.get_node_or_null("FloorEdge") != null \
		and probe.get_node_or_null("Title") != null \
		and probe.get_node_or_null("Subtitle") != null \
		and probe.get_node_or_null("Hint") != null \
		and probe.get_node_or_null("PropLayer") != null \
		and probe.get_node_or_null("ButtonLayer") != null \
		and probe.get_node_or_null("PropLayer/Prop0") != null \
		and probe.get_node_or_null("PropLayer/Prop3") != null
	ok = ok and skeleton_ok
	print("[MainMenu] scene skeleton complete = %s | %s"
		% [str(skeleton_ok), "OK" if skeleton_ok else "FAIL"])
	probe.free()
	print("[MainMenu] self-check %s" % ("PASSED" if ok else "FAILED"))
