class_name LevelsPage
extends Control
## 选关页面（从 menu.gd 的 LEVELS 页拆出）。
##
## 拆分的理由，代码库自己在 [P22] 里写过一次：WAREHOUSE 和 SHOP 从菜单独立
## 成了自己的屏幕，因为"物品网格 + 选中项详情"不是 menu.gd 该做的事。LEVELS
## 长成了同一形状——卡片网格，每张卡带选中态和首通宝箱——所以它按同样的规矩
## 独立。
##
## [P107 的延续] 这是项目里第一个用 .tscn 声明的屏幕级 UI（HANDOFF 7.5 的
## 例外，和 warehouse_view / shop_view 同类）。场景只声明固定骨架（背景、
## 标题、提示、按钮、卡片容器）；卡片和宝箱仍由代码生成，因为它们的数量来自
## LevelList.discover()——把动态内容塞进场景只会得到一个空壳。
##
## 它不知道 Game 是谁：BACK 发 left，ENTER 发 entered(path)，路由由
## Menu / Game 决定。

signal left                      ## BACK / ESC：去哪由 Game 决定（战斗还在跑就退回）
signal entered(path: String)     ## ENTER：Game.pick_level(path)

## [P93] 首通宝箱通过路径调用 reward 模块（项目里"没有 class_name 的模块"的规矩）。
const Rewards := preload("res://scripts/core/rewards.gd")
## self_check 里用 load() 而不是 preload()：场景还没建好时整个脚本不该拒绝编译。
const SCENE_PATH := "res://scenes/ui/levels.tscn"

var level_path: String = Balance.LEVEL_PATH

var game = null                  ## GameManager autoload；故意不标名称

var _title := ""
var _subtitle := ""
var _hint := ""
var _entries: Array = []         ## [{btn, title, stat, mark, cell, path, level_name, chest_text, chest, chest_open}]
var _selected_path := ""
var _selected_name := ""

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $Title
@onready var _subtitle_label: Label = $Subtitle
@onready var _hint_label: Label = $Hint
@onready var _card_layer: Control = $CardLayer
@onready var _enter_btn: Button = $EnterBtn
@onready var _back_btn: Button = $BackBtn


func _ready() -> void:
	## [P37-A11] 见 hud.gd 同一行：on_layout_changed() 用 Layout.size 定尺寸，
	## 所以它需要让 size 不受锚点影响的锚点。
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_style_static()
	_enter_btn.pressed.connect(_on_enter_level)
	_back_btn.pressed.connect(func() -> void: left.emit())


# ---------------------------------------------------------------- 样式
func _style_static() -> void:
	## 场景骨架里声明的节点，颜色 / 字号 / 皮肤从代码填：它们住在
	## BalanceUI / UiStyle，场景里硬编码等于多一个会悄悄过期的真相来源。
	if _background != null:
		_background.color = BalanceUI.COLOR_MENU_BG
	_style_label(_title_label, BalanceUI.FONT_SIZE_MENU_TITLE, BalanceUI.COLOR_MENU_TITLE)
	_style_label(_subtitle_label, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	_style_label(_hint_label, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	_style_button(_enter_btn)
	_style_button(_back_btn)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_font_size_override("font_size", BalanceUI.FONT_SIZE_MENU_BUTTON)
	## 皮来自 UiStyle，和菜单其他按钮同一套：make_button 造一个临时按钮取皮
	## 再还给真实按钮，好过在场景里硬编码颜色（常量改了就会跟不上）。
	var skin := UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := skin.get_theme_stylebox(key)
		if sb != null:
			btn.add_theme_stylebox_override(key, sb)
	skin.free()


# ---------------------------------------------------------------- public API
func open_view() -> void:
	## 每次进来都清空选中：'点一张卡，再按 ENTER' 是这一页的规矩，上次留下的
	## 选中会悄悄破坏它（原 menu.open() 的 [P99]）。
	_selected_path = ""
	_selected_name = ""
	_build()
	visible = true
	on_layout_changed()
	_focus_first()          # 可见之后才能抢焦点，否则 grab_focus 会被拒


func hide_view() -> void:
	visible = false


func back() -> void:
	## ESC 的统一入口；真正的路由留给 Game（战斗还在跑就退回战斗）。
	left.emit()


func on_layout_changed() -> void:
	position = Vector2.ZERO
	size = Layout.size
	_layout()
	queue_redraw()


# ---------------------------------------------------------------- 页面构建
func _build() -> void:
	_clear_entries()
	_title = Loc.t("menu.levels.title")
	_subtitle = Loc.tf("menu.levels.subtitle", [Balance.LEVEL_DIR])
	_hint = Loc.t("menu.levels.hint")

	var rows: Array = LevelList.discover()
	## [P93] 有几个宝箱等着、有没有已经开过：列表下的提示行说的是玩家正在看哪一种。
	var waiting := 0
	var opened_any := false
	for entry in rows:
		var row: Dictionary = entry
		var id := str(row.get("id", "?"))
		var level_name := str(row.get("name", id))
		var waves := int(row.get("waves", 0))
		var zombies := int(row.get("zombies", 0))
		## [P96] 数字行以关卡解析到的难度开头（关卡文件可以不写，那就用
		## difficulty.gd 的默认值，和 almanac 的 LEVELS 页一致）。
		var stat := Loc.tf("menu.levels.card_stat",
			[Difficulty.label(str(row.get("difficulty", Difficulty.DEFAULT_KEY))), waves, zombies])
		var mark := ""
		var enabled := true
		if not bool(row.get("playable", false)):
			## [P26] 存在但不可玩的关卡留在页面上，画成暗的、把原因写在卡片上。
			enabled = false
			mark = Loc.t("menu.levels.broken")
			stat = str(row.get("broken", "?"))
		elif bool(row.get("cleared", false)):
			mark = Loc.t("menu.levels.cleared")
		elif bool(row.get("last_played", false)):
			mark = Loc.t("menu.levels.last")
		var path := str(row.get("path", ""))
		var card := _add_level_card(level_name, stat, mark,
			_on_level_selected.bind(path, level_name), enabled)
		## [P99] 每张卡记住自己的 PATH、名字和宝箱里有什么。
		var card_entry: Dictionary = _entries[_entries.size() - 1]
		card_entry["path"] = path
		card_entry["level_name"] = level_name
		card_entry["chest_text"] = str(row.get("first_clear", ""))
		## [P93/P99] 首通宝箱，在卡片右下角，三态之一。
		var can_open: bool = bool(row.get("claimable", false))
		var opened: bool = bool(row.get("claimed", false))
		if str(row.get("first_clear", "none")) != "none":
			var chest := LevelChest.new()
			chest.name = "Chest_" + id
			var state := LevelChest.STATE_LOCKED
			if can_open:
				state = LevelChest.STATE_READY
			elif opened:
				state = LevelChest.STATE_OPEN
			chest.setup(path, state, str(row.get("first_clear", "")))
			chest.opened.connect(_on_chest_opened)
			chest.previewed.connect(_on_chest_previewed)
			card.add_child(chest)
			card_entry["chest"] = chest
			card_entry["chest_open"] = opened
			if can_open:
				waiting += 1
			elif opened:
				opened_any = true

	## 循环之后，不在循环里：提示描述的是整页。
	if waiting > 0:
		_hint = Loc.t("menu.levels.chest_hint")
	elif opened_any:
		_hint = Loc.t("menu.levels.chest_open_hint")
	if rows.is_empty():
		_hint = Loc.tf("menu.levels.empty", [Balance.LEVEL_DIR])

	## [P99] BACK 是场景里固定的按钮，但文本跟语言走，所以在这里写。
	if _back_btn != null:
		_back_btn.text = Loc.t("menu.back")
	_push_text()
	## [P99] 点击卡片只是 SELECT，ENTER 才离开。
	_select_card(_selected_index())


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


func _add_level_card(p_name: String, p_stat: String, p_mark: String,
		p_pressed: Callable, p_enabled: bool = true) -> Button:
	## [P96] 冒险网格里的一关。三部分纵向堆叠：名字在上、数字在下、底行两个
	## 事实（左状态词、右首通宝箱）。
	##
	## 文本 TRIM 而不溢出：卡片比旧的全宽行窄得多，关卡名压到邻居身上是网格
	## 比列表更容易踩到的坑。
	var btn := _make_button()
	btn.disabled = not p_enabled
	btn.pressed.connect(p_pressed)
	var title := UiStyle.make_label(p_name,
		BalanceUI.COLOR_TEXT if p_enabled else BalanceUI.COLOR_TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER, BalanceUI.FONT_SIZE_MENU_ROW)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.add_child(title)
	var stat := UiStyle.make_label(p_stat,
		BalanceUI.COLOR_MENU_SUB if p_enabled else BalanceUI.COLOR_LOCKED,
		HORIZONTAL_ALIGNMENT_CENTER, BalanceUI.FONT_SIZE_MENU_SUB)
	stat.clip_text = true
	stat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.add_child(stat)
	var mark: Label = null
	if p_mark != "":
		mark = UiStyle.make_label(p_mark,
			BalanceUI.COLOR_MENU_MARK if p_enabled else BalanceUI.COLOR_LOCKED,
			HORIZONTAL_ALIGNMENT_LEFT, BalanceUI.FONT_SIZE_MENU_SUB)
		mark.clip_text = true
		mark.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.add_child(mark)
	## 卡片挂到场景里的 CardLayer，不是 self：_layout_grid() 用它算相对坐标。
	_card_layer.add_child(btn)
	_entries.append({"btn": btn, "title": title, "stat": stat, "mark": mark, "cell": true})
	## [P93] 返回给调用方，让它能在卡上挂别的东西（本页挂首通宝箱）。
	return btn


func _make_button() -> Button:
	## [P73] UiStyle.make_button() 配菜单自己的形状：暂时无文本（每行用子
	## Label 写标题）、按钮无字号、无禁用变暗、也不指定父节点。
	return UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)


# ---------------------------------------------------------------- 回调
func _on_level_selected(p_path: String, p_name: String) -> void:
	## [P99] 卡片点击只是 SELECT，不是启动。
	_selected_path = p_path
	_selected_name = p_name
	_select_card(_selected_index())
	_hint = Loc.tf("menu.levels.selected", [p_name]) + _chest_line()
	_push_text()
	queue_redraw()


func _on_enter_level() -> void:
	## [P32] ENTER 打开选种子页；真正的路由由 Game 拥有。
	if _selected_path != "":
		entered.emit(_selected_path)


func _on_chest_opened(p_path: String) -> void:
	## [P93] 打开一关的首通宝箱并说出开出了什么。页面随后重建。
	if game == null:
		return
	var lines: Array[String] = Rewards.claim_first_clear(game, p_path)
	var text := ", ".join(lines)
	_hint = text if text != "" else Loc.t("msg.chest.empty")
	_build()
	_hint = text if text != "" else Loc.t("msg.chest.empty")
	_push_text()
	_layout()
	queue_redraw()


func _on_chest_previewed(p_path: String) -> void:
	## [P99] 还不能拿（或已拿过）的宝箱：点击只 SHOW 里面是什么。
	for row in _entries:
		var entry: Dictionary = row
		if str(entry.get("path", "")) != p_path:
			continue
		var key := "menu.levels.preview_open" if bool(entry.get("chest_open", false)) \
			else "menu.levels.preview_locked"
		_hint = Loc.tf(key, [str(entry.get("level_name", "")), str(entry.get("chest_text", ""))])
		_push_text()
		queue_redraw()
		return


func _selected_index() -> int:
	## [P99] 哪张卡戴着选中，或 -1。
	if _selected_path == "":
		return -1
	for i in _entries.size():
		var row: Dictionary = _entries[i]
		if str(row.get("path", "")) == _selected_path:
			return i
	return -1


func _select_card(p_index: int) -> void:
	## [P99] 把选中画出来：一张卡戴金框，其他卡是普通皮。
	for i in _entries.size():
		var row: Dictionary = _entries[i]
		var btn := row["btn"] as Button
		if btn != null and bool(row.get("cell", false)):
			UiStyle.apply(btn, _card_styles(i == p_index))
	if _enter_btn != null:
		var has_pick: bool = _selected_path != ""
		_enter_btn.disabled = not has_pick
		_enter_btn.text = Loc.tf("menu.levels.enter", [_selected_name]) if has_pick \
			else Loc.t("menu.levels.enter_none")


func _card_styles(p_selected: bool) -> Dictionary:
	## 普通皮，或金框（物品格和路线图用的同一个选中色）。
	if not p_selected:
		return UiStyle.colored_styles(BalanceUI.COLOR_BTN_BG, 0.12, 0.16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BalanceUI.COLOR_BTN_BG.lightened(0.10)
	sb.border_color = BalanceUI.COLOR_ITEM_TILE_SELECTED
	sb.set_border_width_all(int(BalanceUI.RUN_TILE_BORDER_W))
	sb.set_corner_radius_all(int(BalanceUI.RUN_NODE_CORNER))
	return {"normal": sb, "hover": sb, "pressed": sb, "focus": sb, "disabled": sb}


func _chest_line() -> String:
	## [P99] 选中关卡的宝箱里有什么，给提示行用。
	for row in _entries:
		var entry: Dictionary = row
		if str(entry.get("path", "")) == _selected_path and entry.has("chest"):
			return "   -   " + str(entry.get("chest_text", ""))
	return ""


# ---------------------------------------------------------------- 布局
func _layout() -> void:
	_layout_labels()
	_layout_grid()


func _layout_labels() -> void:
	## 场景里的标签随窗口走，因为 Layout.size 是布局的唯一真相。
	var w := Layout.size.x
	var h := Layout.size.y
	if _title_label != null:
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


static func level_grid_metrics(p_page: Vector2, p_count: int, p_buttons: int = 2) -> Dictionary:
	## [P96] 冒险网格的纯算术：页尺寸和卡片数进，每个矩形出。_layout_grid()
	## 从这里摆，self_check() 用同一套数字在 Balance.WINDOW_SIZE 审计。
	##
	## 列数是 CHOOSE 出来的，不是写死的：每个 (cols, rows) 对，只要卡片还守着
	## LEVEL_GRID_MIN_*，就按它最紧的一边打分（并封顶在 LEVEL_GRID_MAX_*），
	## 最高的赢。24 关落在 6 x 4；关包长大长出网格，不是挤小卡片。
	var gap: float = BalanceUI.LEVEL_GRID_GAP
	var top: float = BalanceUI.LEVEL_GRID_TOP
	var bottom: float = p_page.y - BalanceUI.MENU_HINT_BOTTOM_MARGIN \
		- BalanceUI.MENU_LIST_BOTTOM_GAP - BalanceUI.LEVEL_GRID_BACK_H \
		- BalanceUI.LEVEL_GRID_BACK_GAP
	var avail := Vector2(maxf(p_page.x - BalanceUI.HUD_SIDE_MARGIN * 2.0, 1.0),
		maxf(bottom - top, 1.0))
	var count := maxi(p_count, 1)
	var best: Dictionary = {}
	var best_score := -1.0
	var fallback: Dictionary = {}
	var fallback_area := -1.0
	for rows in range(1, count + 1):
		var cols := int(ceil(float(count) / float(rows)))
		var wide := (avail.x - gap * float(cols - 1)) / float(cols)
		var tall := (avail.y - gap * float(rows - 1)) / float(rows)
		var natural := Vector2(maxf(wide, 1.0), maxf(tall, 1.0))
		## 什么都不满足最小尺寸时最接近的布局：还能塞进页面的最大卡片。
		if natural.x * natural.y > fallback_area:
			fallback_area = natural.x * natural.y
			fallback = {"cols": cols, "rows": rows, "cell": Vector2(floorf(natural.x), floorf(natural.y))}
		if wide < BalanceUI.LEVEL_GRID_MIN_W or tall < BalanceUI.LEVEL_GRID_MIN_H:
			continue
		var grid_size := Vector2(floorf(minf(wide, BalanceUI.LEVEL_GRID_MAX_W)),
			floorf(minf(tall, BalanceUI.LEVEL_GRID_MAX_H)))
		var score := minf(grid_size.x / BalanceUI.LEVEL_GRID_MIN_W, grid_size.y / BalanceUI.LEVEL_GRID_MIN_H)
		if score > best_score:
			best_score = score
			best = {"cols": cols, "rows": rows, "cell": grid_size}
	var fits := not best.is_empty()
	if not fits:
		best = fallback
	var cols_final := int(best.get("cols", 1))
	var rows_final := int(best.get("rows", 1))
	var cell: Vector2 = best.get("cell", Vector2(BalanceUI.LEVEL_GRID_MIN_W, BalanceUI.LEVEL_GRID_MIN_H))
	var grid := Vector2(float(cols_final) * cell.x + float(cols_final - 1) * gap,
		float(rows_final) * cell.y + float(rows_final - 1) * gap)
	var grid_at := Vector2(floorf((p_page.x - grid.x) * 0.5), floorf(top))
	## [P99] 网格下的按钮行：ENTER 和 BACK 并排居中。
	var row_w: float = float(maxi(p_buttons, 1)) * BalanceUI.MENU_BUTTON_SIZE.x \
		+ float(maxi(p_buttons - 1, 0)) * BalanceUI.MENU_BUTTON_GAP
	var back_at := Vector2(floorf((p_page.x - row_w) * 0.5),
		floorf(grid_at.y + grid.y + BalanceUI.LEVEL_GRID_BACK_GAP))
	return {"cols": cols_final, "rows": rows_final, "cell": cell, "gap": gap,
		"grid": grid, "grid_at": grid_at, "back_at": back_at, "row_w": row_w, "fits": fits}


func _layout_grid() -> void:
	## [P96] 卡片从 level_grid_metrics() 摆；ENTER / BACK 从同一份结果里摆，
	## 这样布局和自检不会互相打架。
	##
	## 场景里的 CardLayer position 应保持 (0,0)，让本函数里的绝对坐标等于
	## 相对本页的坐标。若移动它，请一并减去它的 position。
	var cards: Array = _entries
	var m := level_grid_metrics(Layout.size, cards.size(), 2)
	var cell: Vector2 = m["cell"]
	var gap: float = m["gap"]
	var cols: int = m["cols"]
	var at: Vector2 = m["grid_at"]
	var inset: float = BalanceUI.LEVEL_CARD_INSET
	var chest_side: float = BalanceUI.LEVEL_CARD_CHEST
	for i in cards.size():
		var card: Dictionary = cards[i]
		var btn := card["btn"] as Button
		if btn == null:
			continue
		btn.position = Vector2(at.x + float(i % cols) * (cell.x + gap),
			at.y + floorf(float(i) / float(cols)) * (cell.y + gap))
		btn.custom_minimum_size = cell
		btn.size = cell
		var title := card["title"] as Label
		if title != null:
			title.position = Vector2(inset, inset)
			title.size = Vector2(cell.x - inset * 2.0, BalanceUI.LEVEL_CARD_TITLE_H)
		var stat := card.get("stat") as Label
		if stat != null:
			stat.position = Vector2(inset, inset + BalanceUI.LEVEL_CARD_TITLE_H)
			stat.size = Vector2(cell.x - inset * 2.0, BalanceUI.LEVEL_CARD_STAT_H)
		## 宝箱占右下角，状态词左移它一个宽度。
		var chest := card.get("chest") as Control
		if chest != null and is_instance_valid(chest):
			chest.position = Vector2(cell.x - inset - chest_side, cell.y - inset - chest_side)
			chest.size = Vector2(chest_side, chest_side)
		var mark := card["mark"] as Label
		if mark != null:
			mark.position = Vector2(inset, cell.y - inset - BalanceUI.LEVEL_CARD_STAT_H)
			mark.size = Vector2(cell.x - inset * 2.0 - chest_side, BalanceUI.LEVEL_CARD_STAT_H)
	## [P99] 两个按钮共一行，居中在网格下面。
	var row_at: Vector2 = m["back_at"]
	var box := Vector2(BalanceUI.MENU_BUTTON_SIZE.x, BalanceUI.LEVEL_GRID_BACK_H)
	if _enter_btn != null:
		_enter_btn.position = row_at
		_enter_btn.custom_minimum_size = box
		_enter_btn.size = box
	if _back_btn != null:
		_back_btn.position = Vector2(
			row_at.x + BalanceUI.MENU_BUTTON_SIZE.x + BalanceUI.MENU_BUTTON_GAP, row_at.y)
		_back_btn.custom_minimum_size = box
		_back_btn.size = box


func _focus_first() -> void:
	for entry in _entries:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn != null and is_instance_valid(btn) and btn.visible and not btn.disabled:
			btn.grab_focus()
			return


# ---------------------------------------------------------------- 首通宝箱
class LevelChest extends Control:
	## [P93] 关卡卡上的首通宝箱。它是 Control 不是 Button，因为它住在卡片按钮
	## 里面：一个 mouse_filter = STOP 的 Control 会在父节点之前被命中测试，所以
	## 点宝箱是宝箱的事，点卡片其他地方才是选中关卡。
	##
	## [P99] 三态，都从同一对图里画：LOCKED（关着，无光晕，点击只是 SHOW）、
	## READY（关着 + 脉动光晕，点击领走）、OPEN（已领取）。
	signal opened(p_path: String)        # READY: 玩家在拿走
	signal previewed(p_path: String)     # LOCKED / OPEN: 只展示内容，不拿

	const STATE_LOCKED := 0
	const STATE_READY := 1
	const STATE_OPEN := 2

	var _path := ""
	var _state := STATE_LOCKED
	var _closed_tex: Texture2D = null
	var _open_tex: Texture2D = null
	var _phase := 0.0

	func setup(p_path: String, p_state: int, p_reward: String = "") -> void:
		_path = p_path
		_state = p_state
		_closed_tex = UnitArt.load_texture(BalanceUI.ART_CHEST_CLOSED)
		_open_tex = UnitArt.load_texture(BalanceUI.ART_CHEST_OPEN)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var key := "menu.levels.chest_tip"
		if p_state == STATE_OPEN:
			key = "menu.levels.chest_tip_open"
		elif p_state == STATE_LOCKED:
			key = "menu.levels.chest_tip_locked"
		tooltip_text = Loc.tf(key, [p_reward if p_reward != "" else Loc.t("msg.chest.empty")])
		set_process(p_state == STATE_READY)     # 只有光晕需要时钟
		queue_redraw()

	func _process(delta: float) -> void:
		_phase = fmod(_phase + delta * BalanceUI.CHEST_GLOW_PULSE_SPEED, TAU)
		queue_redraw()

	func state() -> int:
		## [P99] 这个宝箱建的时候是哪一态。被 [Menu] 声明读取，用 SAVE FILE
		## （cleared / claimed）跟状态比，不是跟页面随手传进来的布尔比。
		return _state

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		## 下面的卡片是 Button：在这里吃掉事件，才不会让点宝箱也等于"选这关"。
		accept_event()
		if _state == STATE_READY:
			opened.emit(_path)
		else:
			previewed.emit(_path)

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		if _state == STATE_READY:
			## 光晕：三圈半径随 phase 呼吸，画在图片后面。
			var centre := size * 0.5
			for ring in BalanceUI.CHEST_GLOW_RINGS:
				var t := float(ring + 1) / float(BalanceUI.CHEST_GLOW_RINGS)
				var pulse := 0.85 + 0.15 * sin(_phase + t * PI)
				var r := BalanceUI.CHEST_GLOW_RADIUS * t * pulse
				var a := BalanceUI.CHEST_GLOW_ALPHA * (1.0 - t * 0.55) * pulse
				draw_circle(centre, r, Color(BalanceUI.CHEST_GLOW_COLOR.r,
					BalanceUI.CHEST_GLOW_COLOR.g, BalanceUI.CHEST_GLOW_COLOR.b, a))
		var tex := _open_tex if _state == STATE_OPEN else _closed_tex
		if tex != null:
			draw_texture_rect(tex, box, false)
		else:
			## 没有 import：画成宝箱自己的棕色方块，不是空洞。
			draw_rect(Rect2(size * 0.22, size * 0.56), Color(0.55, 0.35, 0.17))


# ---------------------------------------------------------------- 自检
static func self_check() -> void:
	## [P96] 冒险网格，不开菜单也能审计。
	##
	## 这一页现在用 .tscn：骨架是静态节点，动态卡片仍代码生成。自检走两条
	## 路——网格算术（纯函数）和离树 probe 的构建断言。
	print("[Levels] --- adventure card grid (P96) ---")
	var cards: int = LevelList.discover().size()
	var gm := level_grid_metrics(Vector2(Balance.WINDOW_SIZE), cards)
	var gcell: Vector2 = gm["cell"]
	var ggrid: Vector2 = gm["grid"]
	var gat: Vector2 = gm["grid_at"]
	var gback: Vector2 = gm["back_at"]
	var gcols: int = gm["cols"]
	var grows: int = gm["rows"]
	var gpage := Vector2(Balance.WINDOW_SIZE)
	var fits: bool = bool(gm["fits"])
	var row_w: float = gm["row_w"]
	var room_ok: bool = fits and gcols * grows >= cards \
		and gcell.x >= BalanceUI.LEVEL_GRID_MIN_W and gcell.y >= BalanceUI.LEVEL_GRID_MIN_H \
		and gat.x >= BalanceUI.HUD_SIDE_MARGIN - 0.5 \
		and gat.x + ggrid.x <= gpage.x - BalanceUI.HUD_SIDE_MARGIN + 0.5 \
		and gat.y + ggrid.y <= gback.y - BalanceUI.LEVEL_GRID_BACK_GAP + 0.5 \
		and gback.x >= BalanceUI.HUD_SIDE_MARGIN - 0.5 \
		and gback.x + row_w <= gpage.x - BalanceUI.HUD_SIDE_MARGIN + 0.5 \
		and gback.y + BalanceUI.LEVEL_GRID_BACK_H <= gpage.y - BalanceUI.MENU_HINT_BOTTOM_MARGIN + 0.5
	## 卡片是名字 + 数字 + 底行（状态词和宝箱）。网格可以挤到的最小卡高至少
	## 得有那么多，否则两块会重叠。
	var min_card: float = BalanceUI.LEVEL_CARD_INSET * 2.0 + BalanceUI.LEVEL_CARD_TITLE_H \
		+ BalanceUI.LEVEL_CARD_STAT_H + maxf(BalanceUI.LEVEL_CARD_CHEST, BalanceUI.LEVEL_CARD_STAT_H)
	var parts_ok: bool = gcell.y + 0.5 >= min_card and BalanceUI.LEVEL_GRID_MIN_H + 0.5 >= min_card \
		and gcell.x - BalanceUI.LEVEL_CARD_INSET * 2.0 - BalanceUI.LEVEL_CARD_CHEST > 0.0
	print("[Levels] %d level card(s) -> %d x %d grid, cell %dx%d at (%d,%d), 2 button(s) %d wide at (%d,%d), card needs %d px vs floor %d = %s | %s"
		% [cards, gcols, grows, int(gcell.x), int(gcell.y), int(gat.x), int(gat.y),
		   int(row_w), int(gback.x), int(gback.y), int(min_card), int(BalanceUI.LEVEL_GRID_MIN_H),
		   str(room_ok and parts_ok), "OK" if (room_ok and parts_ok) else "FAIL"])

	## 页面在离树状态下构建：数字看不到的，是两个 Label 是不是卡片的子节点。
	##
	## 离树 probe 不会跑 _ready()，所以 @onready 变量是空的：手动填一遍
	## （等价于引擎在进树时做的事），然后手动 _build()。
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		print("[Levels] scene missing: %s | FAIL" % SCENE_PATH)
		print("[Levels] self-check FAILED")
		return
	var probe: LevelsPage = scene.instantiate()
	probe._background = probe.get_node_or_null("Background")
	probe._title_label = probe.get_node_or_null("Title")
	probe._subtitle_label = probe.get_node_or_null("Subtitle")
	probe._hint_label = probe.get_node_or_null("Hint")
	probe._card_layer = probe.get_node_or_null("CardLayer")
	probe._enter_btn = probe.get_node_or_null("EnterBtn")
	probe._back_btn = probe.get_node_or_null("BackBtn")
	if probe._card_layer == null or probe._enter_btn == null or probe._back_btn == null \
			or probe._title_label == null:
		print("[Levels] scene skeleton missing: Title / CardLayer / EnterBtn / BackBtn must exist | FAIL")
		probe.free()
		print("[Levels] self-check FAILED")
		return
	probe._build()
	var built := 0
	var bad := 0
	for entry in probe._entries:
		var row: Dictionary = entry
		if not bool(row.get("cell", false)):
			continue
		built += 1
		var card_btn := row["btn"] as Button
		var label := row["title"] as Label
		var numbers := row.get("stat") as Label
		if label == null or numbers == null or label.text == "" or numbers.text == "" \
			or label.get_parent() != card_btn or numbers.get_parent() != card_btn:
			bad += 1
	## [P99] 每一关凡是欠着首通奖励的，都带宝箱，状态按 SAVE FILE 来。自检读
	## SettingsStore 本身，所以它不是在把页面跟自己的输入比。
	var chests := 0
	var wrong := 0
	for entry2 in probe._entries:
		var card_row: Dictionary = entry2
		if not card_row.has("chest"):
			continue
		chests += 1
		var id := str(card_row.get("path", "")).get_file().get_basename()
		var want := LevelChest.STATE_LOCKED
		if SettingsStore.is_claimed(id):
			want = LevelChest.STATE_OPEN
		elif SettingsStore.is_cleared(id):
			want = LevelChest.STATE_READY
		if (card_row["chest"] as LevelChest).state() != want:
			wrong += 1
	## 新的两步门：ENTER 存在，一开始是禁用的，并且说出了原因。
	var enter_ok: bool = probe._enter_btn != null and probe._enter_btn.disabled \
		and probe._enter_btn.text == Loc.t("menu.levels.enter_none") \
		and probe._selected_path == ""
	var build_ok: bool = built == cards and bad == 0 and chests == cards and wrong == 0 and enter_ok
	probe.free()
	print("[Levels] the page builds %d card(s), %d missing a label, %d chest(s) matching the save (%d wrong), ENTER starts disabled = %s | %s"
		% [built, bad, chests, wrong, str(build_ok), "OK" if build_ok else "FAIL"])
	var ok := room_ok and parts_ok and build_ok
	print("[Levels] self-check %s" % ("PASSED" if ok else "FAILED"))
