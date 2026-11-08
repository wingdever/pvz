## scripts/ui/front_end_flow.gd
##
## [P64] 前端页面流。是 ScreenFlow 的**独立对象形态**（P36 shape，不是 P61 那种
## 静态工具）——它有自己的状态：
##
##   * `screen`            ——哪个页面在上面（原 P12 规则："Game 是唯一所有者"，
##                            现在所有者改为 FrontEndFlow）
##   * 13 个 view 引用     ——每个页面实例（page 是场景，离开时 free）
##   * `menu_layer` / `garden_layer` ——两个宿主 CanvasLayer 的引用
##   * `_return_to_battle` / `_run_battle` ——两条跨页面的标记
##
## 它和 Game 的关系：
##   * `game` 是构造时注入的引用（循环引用，autoload 场景安全）
##   * 它需要 game 的 battle / run_flow / 几个方法，但那些**留在 Game 里**
##   * 它不碰存档、不碰清档——那是 SaveLedger 和 Game 的事
##
## 页面 is a SCENE（P107）：一个页面打开时实例化，离开时 free，中间图层是空的。
## 所以"哪个页面在上面"和"哪个页面存在"是一个问题。

class_name FrontEndFlow
extends RefCounted

## 哪个屏幕拥有输入。GAME 是唯一接受游戏内按键的屏幕。
## （原 enum 在 GameManager 里；搬进 FrontEndFlow，因为它是"页面流"的事实。）
enum Screen {
	MAIN_MENU, LEVEL_SELECT, SETTINGS, GARDEN, WAREHOUSE, SHOP, BACKPACK, ALMANAC, GAME,
	RUN_SQUAD, RUN_MAP, RUN_NODE, RUN_REWARD, RUN_END,
	DECK,
	## [B2] A live brawl bout: not a page (the arena is its own scene, like the battle board),
	## but a screen the front end must know about - Game's in-game keys stay silent while it is
	## up, exactly as they do for GAME.
	BRAWL,
	## [B2b] The brawl's round page: the mode's own screen (offers / result), a page like any
	## other in this flow - built on open, freed on leave.
	BRAWL_ROUND,
	## [B2c] and the formation page, which is where a session OPENS and where every new round
	## returns: the player's half, their roster, and the cap that decides how many may stand.
	BRAWL_FORMATION,
	## [D75] The classic mode's own 图鉴: the same "a page like any other" shape, opened from
	## the menu's floor object in the CLASSIC shell (the turn shell opens Screen.ALMANAC).
	BRAWL_ALMANAC,
	## [W3] A live war match: not a page (the arena is its own scene, like the brawl's), but a
	## screen the front end must know about - Game's in-game keys stay silent while it is up,
	## and the camera's ctrl gestures reach nobody else. The war's formation page joins this
	## list in W4, as its own page-shaped entry.
	WAR,
	## [W4] The war's deployment table: a PAGE like the brawl's formation (built on open,
	## freed on leave) - the arena only arrives when 出征 commits it.
	WAR_FORMATION,
}

# ---------------------------------------------------------------- 外部引用

## 注：这是循环引用。Game 创建 FrontEndFlow 并注入自己，两者互持。
## autoload 的生命周期与进程同级，不需要担心释放顺序。
var game: GameManager = null
## [P109] 端口时这里留下过三个死字段（`var battle`、`var battle_main`、`var garden`）——
## 从来没人赋值。棋盘、战斗生命周期和花名册的把手业主都是 Game，本文件一律借道
## `game.` 读它们。

# ---------------------------------------------------------------- 状态（原在 Game 里）

var screen: int = Screen.MAIN_MENU

var menu_layer: CanvasLayer = null       # menu-class 页面（主菜单 / 设置 / 关卡列表）
var garden_layer: CanvasLayer = null     # 其它页面

var main_menu_view: Control = null
var settings_view: Control = null
var levels_view: Control = null
var garden_view: Control = null
var warehouse_view: Control = null
var shop_view: Control = null
var backpack_view: Control = null
var almanac_view: Control = null
var roadmap_view: Control = null
var squad_view: Control = null
var reward_view: Control = null
var choice_view: Control = null
var deck_view: Control = null
## [B2b] The brawl's round page (null unless a session is between bouts).
var brawl_round_view: Control = null
## [B2c] The brawl's formation page.
var brawl_formation_view: Control = null
## [D75] The classic mode's almanac (a front-end page like the turn one, opened from the menu's
## floor object in the classic shell - no brawl session has to be running for it).
var brawl_almanac_view: Control = null
## [W4] The war's deployment table (null unless the war door is standing on it).
var war_formation_view: Control = null

## [P13] SETTINGS 从战斗里打开时，BACK 要回到战斗，而不是回主菜单。
var _return_to_battle: bool = false

## [P31-A] 当前屏幕上的棋盘是不是一个"rogue-like run"战斗。
var _run_battle: bool = false

## [P32] 卡组页即将开始的那个关卡路径。它是"页面流"的状态：DECK 页的 open 写它、
## DEPLOY 读它、BACK 离开不提交它。业主是本页面的流，不是棋盘、也不再是 Game。
var _pending_level_path: String = ""

## [P109] 卡组页的两张名单，跟着 `_pending_level_path` 一起从 Game 搬来：DECK 页场景
## 每次进出都会重建/释放，所以这份"未提交的选择"必须由流保管，而不是页面自己。
## `_deck_pick` = 玩家挑中的卡（未提交），`_battle_deck` = DEPLOY 提交给下一局的那副。
var _deck_pick: Array[String] = []
var _battle_deck: Array[String] = []


# ---------------------------------------------------------------- 页面场景

const GARDEN_SCENE := preload("res://scenes/ui/garden.tscn")
const WAREHOUSE_SCENE := preload("res://scenes/ui/warehouse.tscn")
const SHOP_SCENE := preload("res://scenes/ui/shop.tscn")
const BACKPACK_SCENE := preload("res://scenes/ui/backpack.tscn")
const ALMANAC_SCENE := preload("res://scenes/ui/almanac.tscn")
const SQUAD_SCENE := preload("res://scenes/ui/squad.tscn")
const ROADMAP_SCENE := preload("res://scenes/ui/roadmap.tscn")
const REWARD_SCENE := preload("res://scenes/ui/reward.tscn")
const CHOICE_SCENE := preload("res://scenes/ui/choice.tscn")
const DECK_SCENE := preload("res://scenes/ui/deck.tscn")
const LEVELS_SCENE := preload("res://scenes/ui/levels.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
## [B2b] The brawl's round page. It is loaded through the same door as every other page, so
## there is exactly one place that knows how a page comes up.
const BRAWL_ROUND_SCENE := preload("res://scenes/ui/brawl_round.tscn")
## [B2c] The formation page: the board the player arranges their pieces on.
const BRAWL_FORMATION_SCENE := preload("res://scenes/ui/brawl_formation.tscn")
## [D75] The classic mode's almanac: the turn page's machinery reading the classic mode's
## sheets (see scripts/ui/brawl/brawl_almanac.gd). Its own scene because its race row has three
## buttons where the turn page has two.
const BRAWL_ALMANAC_SCENE := preload("res://scenes/ui/brawl_almanac.tscn")
## [W4] The war's deployment table: plan section C's shared geometry made structural - the
## scene carries a DISABLED WarField/WarCamera pair as children, so the page draws and
## hit-tests through the arena's own classes rather than a second copy of the maths.
const WAR_FORMATION_SCENE := preload("res://scenes/ui/war_formation.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings.tscn")


# ---------------------------------------------------------------- 装配

## Game 在启动时调用一次：注入自己，并把宿主场景声明的两个图层交过来。
func setup(p_game: GameManager, p_menu_layer: CanvasLayer, p_garden_layer: CanvasLayer) -> void:
	game = p_game
	menu_layer = p_menu_layer
	garden_layer = p_garden_layer


# ---------------------------------------------------------------- 页面流转

func leave_game() -> void:
	## 前端：把战斗欠花园的账结算掉，然后拆掉棋盘，不让它留在菜单后面。
	game._settle_garden("left the battle")
	## [P109] 拆棋盘的业主是 BattleMain（scripts/core/battle/battle_main.gd）；
	game.battle_main._teardown_board()
	## [B2] 同一个道理：拆竞技场的业主是 BrawlMain。乱斗不欠花园任何账（D5），
	## 所以上面那句 _settle_garden 对它是空转——留着是因为这个函数是"离开一局"的
	## 唯一出口，两种会话都必须从它走出去。
	game.brawl_main._teardown_arena()
	## [W3] The same rule a third time: the war arena's owner is WarMain, and "leave the
	## world" means whichever of the three worlds was up.
	game.war_main._teardown_arena()
	set_world_visible(false)
	hide_views()
	_return_to_battle = false
	if game.battle != null:
		game.battle._retreat_timer = 0.0     # [P106] 撤退确认是棋盘的时钟
	## [P31-A] 刚才在屏幕上的棋盘一秒前还是 run 战斗；离开它就是
	## "run 战斗"和"纯菜单"之间的那条线。
	_run_battle = false


func hide_views() -> void:
	## [P107] 是场景的页面在离开时被 FREE，不是隐藏：它的真相来自打开时读的存档，
	## 所以不需要在内存里保留任何东西，"哪个页面在上面"和"哪个页面存在"就是同一个问题。
	## 句柄仍然在原处（这里置空），所以所有 `if game.garden_view != null:` 的守卫照旧工作。
	_free_view(garden_view);    garden_view = null
	_free_view(warehouse_view); warehouse_view = null
	_free_view(shop_view);      shop_view = null
	_free_view(backpack_view);  backpack_view = null
	_free_view(almanac_view);   almanac_view = null
	_free_view(roadmap_view);   roadmap_view = null
	_free_view(squad_view);     squad_view = null
	_free_view(reward_view);    reward_view = null
	_free_view(choice_view);    choice_view = null
	_free_view(deck_view);      deck_view = null
	_free_view(levels_view);    levels_view = null
	_free_view(main_menu_view); main_menu_view = null
	_free_view(brawl_round_view); brawl_round_view = null
	_free_view(brawl_formation_view); brawl_formation_view = null
	_free_view(brawl_almanac_view); brawl_almanac_view = null
	_free_view(war_formation_view); war_formation_view = null
	_free_view(settings_view);  settings_view = null


func _free_view(view: Node) -> void:
	## 一个页面离开内存：先让它放下持有的东西，再释放它。
	## 从父节点摘下来要在 queue_free() 之前：free 在帧末才落地，
	## "页面一离开图层就空"正是启动声明检查的那个不变式。
	if view == null or not is_instance_valid(view):
		return
	if view.has_method("hide_view"):
		view.hide_view()
	if view.get_parent() != null:
		view.get_parent().remove_child(view)
	view.queue_free()


func set_world_visible(p_on: bool) -> void:
	## 棋盘和它的 HUD，升起或落下。落下是每个前端页面做的；
	## 升起发生在两条回到战斗的路上（start_level / resume_battle）。
	## [P106] 棋盘作为一个整体显示/隐藏：世界和 HUD 一起走，
	## 拥有两者的节点是战斗场景的根。
	if game.battle != null:
		game.battle.set_board_visible(p_on)


# ---------------------------------------------------------------- 页面打开

func _inject_handles(node: Node) -> void:
	## [P109] 页面实例的唯一注入口：`game` 加上页面脚本自己声明的影子句柄
	## （profile / garden / save / battle）。旧 HEAD 里这些是 Game 每次开页手工
	## 赋的行；场景化后没人再赋，读它们就是 "on a base object of type 'Nil'"。
	## `prop in node` 让没有该字段的页面安静跳过；页面离开即释放（`_free_view`），
	## 所以每次重开拿到的都是 Game 当下的值，不存在陈副本。
	node.set("game", game)
	for prop in ["profile", "garden", "save", "battle"]:
		if prop in node:
			node.set(prop, game.get(prop))


func _bring_up(p_slot: StringName, p_scene: PackedScene, p_layer: CanvasLayer = null) -> void:
	## [P107] 一个加载器，服务于从多处打开的页面。已经在上面的页面只是重新打开；
	## 句柄在中间是 null，这正是"哪个页面在上面"和"哪个页面存在"成为一个问题的原因。
	##
	## [P107d] 图层是参数：三个 menu-class 页面走 menu_layer，其它走 garden_layer。
	var page: Control = get(p_slot)
	if page == null:
		var host: CanvasLayer = p_layer if p_layer != null else garden_layer
		if host == null:
			push_warning("[FrontEnd] no layer to bring up %s on" % p_slot)
			return
		var node: Node = p_scene.instantiate()
		## 首先要验证的：场景的根有页面脚本。这里是个裸 Control 意味着 .tscn 丢了脚本——
		## 下一行（`set("game")`）会在一个从未有过该属性的 Node 上静默失败。
		if not node.has_method("open_view"):
			push_error("[FrontEnd] %s's root has no open_view(); the scene is missing its script (%s)"
				% [p_slot, p_scene.resource_path])
			node.free()
			return
		## `Node.set()` 绕过 `Control` 静态名称，在运行时赋值；页面自己的 `var game = null` 接收它。
		_inject_handles(node)
		host.add_child(node)
		page = node as Control
		set(p_slot, page)
	if page == null:
		return
	page.open_view()


func open_main_menu() -> void:
	leave_game()
	screen = Screen.MAIN_MENU
	_bring_up(&"main_menu_view", MAIN_MENU_SCENE, menu_layer)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_brawl_formation() -> void:
	## [B2c] The brawl's formation page: same door as its round page, same rules (P107 - a page is
	## built when it is opened and freed when it is left).
	leave_game()
	screen = Screen.BRAWL_FORMATION
	_bring_up(&"brawl_formation_view", BRAWL_FORMATION_SCENE, garden_layer)


func open_brawl_round() -> void:
	## [B2b] The brawl's round page: the mode's own screen, but it lives in this flow for the
	## reasons every page does - built on open, freed on leave, and Game's ESC handling knows
	## the screen it is on. It is opened by BrawlMain (never by the menu directly).
	leave_game()
	screen = Screen.BRAWL_ROUND
	_bring_up(&"brawl_round_view", BRAWL_ROUND_SCENE, garden_layer)


func open_war_formation() -> void:
	## [W4] The war's deployment table: the mode's own page, opened by WarMain.start() (never
	## by the menu directly) - the same door shape the brawl's formation page uses, and for
	## the same reasons: built on open, freed on leave, ESC routed by screen.
	leave_game()
	screen = Screen.WAR_FORMATION
	_bring_up(&"war_formation_view", WAR_FORMATION_SCENE, garden_layer)


func open_settings() -> void:
	leave_game()
	screen = Screen.SETTINGS
	_bring_up(&"settings_view", SETTINGS_SCENE, menu_layer)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_settings_overlay() -> void:
	## [P13] 从战斗里打开 SETTINGS：棋盘只是隐藏，从不拆掉，也不结算——
	## 战斗还在底下继续。BACK 之后原样回到它停下的地方。
	## [P21] 战斗主题在这里刻意继续播放。
	##
	## 这一条刻意不调 leave_game()：棋盘必须活下来，而 _bring_up() 可以安全地再次调用——
	## 它会重新打开已经在上面的页面，而不是实例化第二个。
	_return_to_battle = game.battle != null
	if game.battle != null:
		game.battle._retreat_timer = 0.0
	set_world_visible(false)
	screen = Screen.SETTINGS
	_bring_up(&"settings_view", SETTINGS_SCENE, menu_layer)


func resume_battle() -> void:
	## overlay 的另一半：把同一个活着的棋盘放回去，带着它自己的音乐。
	## hide_views() 会释放设置页（和任何可能在上面的页面）。
	_return_to_battle = false
	screen = Screen.GAME
	hide_views()
	set_world_visible(true)
	game._update_battle_music()


func open_squad() -> void:
	_bring_up(&"squad_view", SQUAD_SCENE)

func open_roadmap() -> void:
	_bring_up(&"roadmap_view", ROADMAP_SCENE)

func open_reward() -> void:
	_bring_up(&"reward_view", REWARD_SCENE)

func open_choice() -> void:
	_bring_up(&"choice_view", CHOICE_SCENE)

func open_deck() -> void:
	_bring_up(&"deck_view", DECK_SCENE)


func open_level_select() -> void:
	leave_game()
	screen = Screen.LEVEL_SELECT
	_bring_up(&"levels_view", LEVELS_SCENE, menu_layer)
	## [P107e] 页面用信号说话，所以得有人听。levels_page.gd 刻意不认 Game；
	## 页面变成场景时丢了这个接线。幂等：页面已经在上时 _bring_up() 复用它。
	if levels_view != null and not levels_view.entered.is_connected(game.pick_level):
		levels_view.entered.connect(game.pick_level)
		levels_view.left.connect(game.back_from_front_end)
	Music.play(BalanceAudio.MUSIC_LEVEL_SELECT)


func open_garden() -> void:
	## [P12] 花园是自己的屏幕：它复用按钮和标签样式，Game 保持"哪个屏幕在上面"的唯一所有者
	## ——现在是 FrontEndFlow。
	leave_game()
	screen = Screen.GARDEN
	_bring_up(&"garden_view", GARDEN_SCENE)
	Music.play(BalanceAudio.MUSIC_GARDEN)


func open_warehouse() -> void:
	## [P14] 钱 + 物品。[P22] 它现在是一块自己的屏幕。
	leave_game()
	game.garden.recover_garden()
	screen = Screen.WAREHOUSE
	_bring_up(&"warehouse_view", WAREHOUSE_SCENE)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_backpack() -> void:
	## [P22] 主菜单的 BACKPACK 图。[P22] 战斗中的背包面板是只读的同一个容器；
	## 战斗外没有东西可用它，而且背包通常是空的——_settle_garden() 在战斗结束那一刻就把它并入仓库了。
	leave_game()
	game.garden.recover_garden()
	screen = Screen.BACKPACK
	_bring_up(&"backpack_view", BACKPACK_SCENE)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_almanac() -> void:
	## [P26] 图鉴页：单位名单、道具注册表和关卡包，全部读自战斗用的同一份数据。
	leave_game()
	game.garden.recover_garden()
	screen = Screen.ALMANAC
	_bring_up(&"almanac_view", ALMANAC_SCENE)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_brawl_almanac() -> void:
	## [D75] 经典模式的图鉴：同一扇门、同一条规矩（打开就建、离开就释放），读的是经典模式
	## 自己的表（units.csv 的 timed 列 / gear.csv / formations.csv），不碰关卡包。
	leave_game()
	game.garden.recover_garden()
	screen = Screen.BRAWL_ALMANAC
	_bring_up(&"brawl_almanac_view", BRAWL_ALMANAC_SCENE)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_shop() -> void:
	## [P22] 和仓库同形：自己的屏幕，自己的格子。
	leave_game()
	game.garden.recover_garden()
	screen = Screen.SHOP
	_bring_up(&"shop_view", SHOP_SCENE)
	Music.play(BalanceAudio.MUSIC_MENU)


func open_deck_select(p_path: String) -> void:
	## 免费关卡进草坪前经过的页面。旧的一键开始的一切都搬到 DEPLOY 页脚之后；
	## 离开页面不提交任何东西（RunFlow._squad_pick 规则）。
	leave_game()
	_pending_level_path = p_path
	_battle_deck = []
	_deck_pick.clear()
	for entry in Balance.plant_cards():
		var key := str(entry)
		if _deck_pick.size() >= BalanceBattle.BATTLE_DECK_SLOTS:
			break
		## [P106] 拥有一个卷轴是 BACKPACK 问题——前端问 Profile 对象，不问棋盘。
		if game.profile.has_scroll_for(key):
			_deck_pick.append(key)
	screen = Screen.DECK
	open_deck()
	Music.play(BalanceAudio.MUSIC_LEVEL_SELECT)


func back() -> void:
	## [P13] 每个 BACK 按钮和 ESC 的唯一入口：页面后面有活棋盘时回战斗，
	## 否则回主菜单。
	## [P31-A] run 的 SHOP 节点借用真实商店屏；在那里离开它就是结束该节点，
	## 所以 BACK 意味着"回到路上"，不是"退出到菜单"。
	if _return_to_battle and game.battle != null:
		resume_battle()
		return
	if screen == Screen.DECK:
		## [P32] 卡组页的 BACK 不是"退出到菜单"，是"选另一个关卡"。
		open_level_select()
		return
	if game.run != null and game.chapter != null and game.run.active != "" \
			and str(game.chapter.node_at(game.run.active).get("type", "")) == "shop":
		game.run_flow.return_to_run_map()
		return
	open_main_menu()


func refresh_page() -> void:
	## 重建屏幕上那个前端页面，让从页面里做的改动（重置、卖出、买入）立刻显示出来。
	match screen:
		Screen.SETTINGS:
			_bring_up(&"settings_view", SETTINGS_SCENE, menu_layer)
		Screen.WAREHOUSE:
			if warehouse_view != null: warehouse_view.open_view()
		Screen.SHOP:
			if shop_view != null: shop_view.open_view()
		Screen.BACKPACK:
			if backpack_view != null: backpack_view.open_view()
		Screen.LEVEL_SELECT:
			_bring_up(&"levels_view", LEVELS_SCENE, menu_layer)
		Screen.GARDEN:
			if garden_view != null: garden_view.open_view()
		Screen.ALMANAC:
			if almanac_view != null: almanac_view.refresh()
		Screen.BRAWL_ALMANAC:
			if brawl_almanac_view != null: brawl_almanac_view.refresh()


# ---------------------------------------------------------------- 语言 / 缩放

func apply_language() -> void:
	## 把当前语言重新应用到屏幕上所有东西。任何屏幕、无战斗时都可以安全调用。
	_refresh_unit_names()
	if game.battle != null and is_instance_valid(game.battle.hud):
		game.battle.hud.refresh_texts()
	if _page_up(garden_view):    garden_view.refresh()
	if _page_up(warehouse_view): warehouse_view.refresh()
	if _page_up(shop_view):      shop_view.refresh()
	if _page_up(backpack_view):  backpack_view.refresh()
	if _page_up(almanac_view):   almanac_view.refresh()
	if _page_up(brawl_almanac_view): brawl_almanac_view.refresh()
	if _page_up(squad_view):     squad_view.refresh()
	if _page_up(roadmap_view):   roadmap_view.refresh()
	if _page_up(reward_view):    reward_view.refresh()
	if _page_up(choice_view):    choice_view.refresh()
	if _page_up(deck_view):      deck_view.refresh()
	if _page_up(main_menu_view): main_menu_view.open_view()
	if _page_up(settings_view):  settings_view.open_view()
	if _page_up(levels_view):    levels_view.open_view()
	## [B5+] The brawl's pages were missing from this list (B2b/B2c never added them). They
	## are open_view() pages rather than refresh() ones - their text is built once, when the page
	## is built - so a language switch has to REBUILD them, exactly as the menu and the settings
	## page above do. [B5+] also put more language into the formation page (the bench caption and
	## the hover panel), which is what turned this from cosmetic into visible.
	if _page_up(brawl_formation_view): brawl_formation_view.open_view()
	if _page_up(brawl_round_view):     brawl_round_view.open_view()
	## [W4] The war's page is the same shape: its text is built when the page is built, so a
	## language switch REBUILDS it (open_view keeps the placed rows - the page's own promise).
	if _page_up(war_formation_view):   war_formation_view.open_view()


func on_viewport_resized() -> void:
	## [P9] 窗口缩放 → 重算几何，再让棋盘和 HUD 重排它们缓存的东西。
	## [P109] RefCounted 没有 viewport：借宿主的——autoload 挂在根上，
	## `game.get_viewport()` 拿到的正是 Game 当年自己调的那个根视口。
	if not Layout.refresh(game.get_viewport().get_visible_rect().size, _window_size()):
		return
	if game.battle != null:
		game.battle.on_layout_changed()
	if main_menu_view != null: main_menu_view.on_layout_changed()
	if settings_view != null:  settings_view.on_layout_changed()
	if levels_view != null:    levels_view.on_layout_changed()
	if garden_view != null:    garden_view.on_layout_changed()
	if warehouse_view != null: warehouse_view.on_layout_changed()
	if shop_view != null:      shop_view.on_layout_changed()
	if backpack_view != null:  backpack_view.on_layout_changed()
	if almanac_view != null:   almanac_view.on_layout_changed()
	if brawl_almanac_view != null: brawl_almanac_view.on_layout_changed()
	if roadmap_view != null:   roadmap_view.on_layout_changed()
	if squad_view != null:     squad_view.on_layout_changed()
	if reward_view != null:    reward_view.on_layout_changed()
	if choice_view != null:    choice_view.on_layout_changed()
	if deck_view != null:      deck_view.on_layout_changed()
	## [S2] THE BRAWL'S PAGES WERE MISSING FROM THIS LIST, and the formation page is the one
	## that showed it: it draws BrawlField.arena_rect() (which followed the window) while its
	## buttons and bench stayed where the old layout had put them - a resize moved the board out
	## from under its own UI. They are on_layout_changed() pages like every other view here, and
	## BrawlLayout is refreshed inside that call (the arena is not up while a page is).
	if brawl_formation_view != null: brawl_formation_view.on_layout_changed()
	if brawl_round_view != null:     brawl_round_view.on_layout_changed()
	## [W4] Same door for the war's page: its strips are window maths, its board is a fixed
	## world - on_layout_changed() re-fits the camera and moves the button, and the world
	## itself does not move a pixel.
	if war_formation_view != null:   war_formation_view.on_layout_changed()


func refresh_settings_screen() -> void:
	## [P107] 只刷新设置页，绝不动它背后的世界。玩家从战斗内的 SETTINGS overlay
	## 切换全屏时，棋盘必须还活着。
	if screen == Screen.SETTINGS and settings_view != null:
		settings_view.open_view()


# ---------------------------------------------------------------- 内部辅助

func _page_up(page: Node) -> bool:
	## [P53] "这个页面到底在不在屏幕上"的唯一答案。
	## 条件容易写一半：`!= null and .visible` 少了 `is_instance_valid()` 就会读已释放的内存。
	return page != null and is_instance_valid(page) and page.visible


func _refresh_unit_names() -> void:
	## [P20] "Peashooter #2" 就地变成 "豌豆射手 #2"：不重建任何单位。
	## 单位自己带着显示名，所以语言切换要给站在草坪上的那些改名并重画。
	if game.battle == null:
		return
	for node in game.battle.grid.all_units():
		var unit := node as Unit
		if unit != null and is_instance_valid(unit):
			unit.refresh_display_name()
			unit.queue_redraw()


func _window_size() -> Vector2i:
	## [P109] HEAD 的 Game `_window_size` 原样，只是 `get_window()` 借宿主——
	## RefCounted 不在场景树上，Game 也从来没有 "get_window_size" 这个方法。
	var win := game.get_window()
	return win.size if win != null else Vector2i.ZERO


# ---------------------------------------------------------------- 自检

func views_of() -> Array:
	## [P64] hide_views() 走的同一份清单，作为数据。
	return [garden_view, warehouse_view, shop_view, backpack_view,
		almanac_view, brawl_almanac_view, roadmap_view, squad_view, reward_view,
		choice_view, deck_view, levels_view, main_menu_view,
		settings_view]


func visible_views() -> int:
	var count := 0
	for view in views_of():
		if view != null and view.visible:
			count += 1
	return count


func self_check() -> void:
	## [P64] What a headless run can see of the front-end, walked through the REAL page
	## switches. The safest part of this probe is that everything it calls, `_bootstrap()`
	## has already called once: it ends the same way boot does (on the main menu), it
	## opens only the deck page - the one own-screen that does NOT run `recover_garden()`
	## (only its name changed in P66; the claim is untouched - no clock ticks here, so there
	## is nothing to persist) - and it puts the page's scratch back. [P75] adds a second
	## page (the almanac) for the same reason: the view's own `open_view()` is what is
	## measured. Deliberately NOT probed: `open_settings_overlay()` outside a battle (it
	## would set `_return_to_battle` off a board that is not a fight) and the run SHOP
	## node's BACK branch (it needs a save file with a shop node active, i.e. RunFlow's).
	var ok := true
	# 0. [P107d] THE HOST SHELL IS DECLARED, NOT BUILT: scenes/main.tscn owns the two
	#    CanvasLayers and Game ADOPTS them at boot, handing them to this object. A name that
	#    drifted leaves Game with nothing to adopt (it bails with a push_error), so this
	#    counts what the shell declares; the main menu is a scene now, instantiated by
	#    `open_main_menu()`, so `main_menu_view` is the live proof that the menu layer works.
	var shell: Node = null
	if game.get_tree() != null:
		shell = game.get_tree().current_scene
	var shell_menu_layer: CanvasLayer = null
	var shell_garden_layer: CanvasLayer = null
	if shell != null:
		shell_menu_layer = shell.get_node_or_null("MenuLayer") as CanvasLayer
		shell_garden_layer = shell.get_node_or_null("GardenLayer") as CanvasLayer
	var shell_ok: bool = shell != null and shell_menu_layer != null and shell_garden_layer != null \
		and shell_menu_layer.layer == 20 and shell_garden_layer.layer == 20 \
		and menu_layer == shell_menu_layer and garden_layer == shell_garden_layer \
		and main_menu_view != null and main_menu_view.get_parent() == shell_menu_layer
	ok = ok and shell_ok
	print("[FrontEnd] the host scene declares the shell (MenuLayer + GardenLayer, layer 20) = %s | %s"
		% [str(shell_ok), "OK" if shell_ok else "FAIL"])
	# 1. The cut itself: the manager kept the page API and handed over the pipeline. A
	#    "delegate that still carries the old body" would pass every other line here, so
	#    this is the one assertion that proves the code actually moved - P61's structural
	#    check, reversed: here the five helpers are gone from the manager because they are
	#    THIS object's now.
	var gone_ok: bool = not game.has_method("_leave_game") and not game.has_method("_hide_views") \
		and not game.has_method("_set_world_visible") and not game.has_method("_resume_battle") \
		and not game.has_method("_refresh_front_end_page")
	ok = ok and gone_ok
	print("[FrontEnd] the board-teardown / page-hiding pipeline is front_end_flow.gd's, not the manager's = %s | %s"
		% [str(gone_ok), "OK" if gone_ok else "FAIL"])
	# 2. [P107] EVERY PAGE THAT IS A SCENE IS FREED, NOT HIDDEN. The claim walks each one
	#    through its REAL opener: opening puts exactly one more page on the layer, leaving
	#    takes it away again. A page that lingered would be a ghost for the next one to
	#    open on top of, and a handle left behind would be a stale pointer nobody could see.
	var layer: Node = null
	if game.get_tree() != null and game.get_tree().current_scene != null:
		layer = game.get_tree().current_scene.get_node_or_null("GardenLayer")
	var openers := {"garden": open_garden, "warehouse": open_warehouse, "shop": open_shop,
		"backpack": open_backpack}
	var pages_ok: bool = layer != null
	for page_name in openers:
		var before_n: int = layer.get_child_count()
		(openers[page_name] as Callable).call()
		var up: bool = layer.get_child_count() == before_n + 1
		hide_views()
		var down: bool = layer.get_child_count() == before_n
		if not (up and down):
			pages_ok = false
			print("[FrontEnd] WARN the %s page did not open/close cleanly (up = %s, down = %s)"
				% [page_name, str(up), str(down)])
	ok = ok and pages_ok
	print("[FrontEnd] every page that is a scene opens onto the layer and is freed again when left (%d page(s)) = %s | %s"
		% [openers.size(), str(pages_ok), "OK" if pages_ok else "FAIL"])
	# 2b. [P107] THE FIVE CAMPAIGN PAGES ARE NEVER OPENED AT BOOT (they need a run to show),
	#     so their scenes are built BARE: add_child runs _ready -> _collect_and_wire, which
	#     is where every get_node() lives. A node name that drifted from the scene fails
	#     HERE instead of in a campaign nobody can reach from a headless boot.
	var run_scenes := {"squad": SQUAD_SCENE, "roadmap": ROADMAP_SCENE, "reward": REWARD_SCENE,
		"choice": CHOICE_SCENE, "deck": DECK_SCENE}
	var builds_ok: bool = layer != null
	for page_name in run_scenes:
		var bare: Control = (run_scenes[page_name] as PackedScene).instantiate()
		_inject_handles(bare)          # [P109] 与 _bring_up 同一注入口
		layer.add_child(bare)
		## the pooled skeleton is the claim: every page declares RUN_MAX_ROWS row buttons
		if bare.get_child_count() < BalanceUI.RUN_MAX_ROWS:
			builds_ok = false
			print("[FrontEnd] WARN the %s page built %d child(ren), expected at least %d"
				% [page_name, bare.get_child_count(), BalanceUI.RUN_MAX_ROWS])
		bare.free()
	ok = ok and builds_ok
	print("[FrontEnd] every campaign page scene builds its pooled skeleton (%d page(s)) = %s | %s"
		% [run_scenes.size(), str(builds_ok), "OK" if builds_ok else "FAIL"])
	open_main_menu()
	# 3. One page at a time, on the real path. The deck page puts its own screen up
	#    and the board down; BACK from it lands on the LEVEL LIST (P32's rule
	#    - "pick another level", not "quit to the menu") with nothing left over.
	#    [P109] The deck page's level travels with the flow now: `_pending_level_path` is
	#    THIS object's field, and the boot level it is seeded from is Balance.LEVEL_PATH.
	#    [P109-2] The counts changed when the MENU became a page (P108): MAIN_MENU is no
	#    longer "nothing up", it is exactly ONE page up - the menu. The claim stays the
	#    same shape ("the page under test is the only one on screen"), it just counts the
	#    menu now: idle = the menu alone, deck = the deck alone (open_deck_select's
	#    leave_game frees it), back = the LEVEL LIST, and the deck handle is gone.
	var path_before: String = _pending_level_path
	var deck_before: Array[String] = _battle_deck.duplicate()
	var pick_before: Array[String] = _deck_pick.duplicate()
	var idle_ok: bool = visible_views() == 1 and main_menu_view != null and main_menu_view.visible
	open_deck_select(Balance.LEVEL_PATH)
	var up_ok: bool = screen == Screen.DECK and visible_views() == 1 \
		and deck_view != null and deck_view.visible \
		and (game.battle == null or not game.battle.grid.visible)
	back()
	## [P107] ... and leaving it FREES the page, so the handle is null: a stronger claim
	## than "it is hidden" - nothing is left behind to be shown again by accident.
	var back_ok: bool = screen == Screen.LEVEL_SELECT and visible_views() == 1 \
		and deck_view == null and levels_view != null and levels_view.visible
	var round_ok: bool = idle_ok and up_ok and back_ok
	ok = ok and round_ok
	print("[FrontEnd] the deck page is the only screen up, and BACK from it goes to the level list (nothing lingers) = %s | %s"
		% [str(round_ok), "OK" if round_ok else "FAIL"])
	# 4. That page switch committed SOMETHING, which is the half worth printing: it is what
	#    proves the probe ran the real `open_deck_select()` rather than a no-op. The deck
	#    page's scratch is then restored unconditionally, P35's transaction rule.
	var dirtied_ok: bool = _pending_level_path != path_before and _pending_level_path != ""
	ok = ok and dirtied_ok
	print("[FrontEnd] opening the deck page really re-prepared a pick ('%s' -> '%s', %d card(s) owned) = %s | %s"
		% [path_before, _pending_level_path, _deck_pick.size(),
			str(dirtied_ok), "OK" if dirtied_ok else "FAIL"])
	open_main_menu()
	_pending_level_path = path_before
	_battle_deck = deck_before
	_deck_pick = pick_before
	# 5. [P75] The almanac builds its page grid ONCE per open. It is the only screen that
	#    owns a grid whose page slice depends on the window, and refresh() and _layout()
	#    each used to slice it - which is invisible from the outside, because the second
	#    pass rebuilds exactly what the first one showed. So the log has to count.
	#    Measured on the LEVELS tab: the page puts its first entry in the detail panel, and
	#    on UNITS that entry is a plant whose view scene the engine then complains about
	#    (3 Bone2D warnings per open) - a boot probe must not add noise to the log it is
	#    judging. The tab is read back afterwards, so the restore is part of the claim.
	## [P107] The page is a SCENE, so the probe OPENS it through the real door first (which
	## also proves the door) and measures the open it just caused.
	open_almanac()
	var almanac := almanac_view as AlmanacView
	if almanac != null:
		var prior: int = almanac.current_section()
		var builds_before: int = almanac.page_builds
		almanac.open_view(AlmanacView.Section.LEVELS)
		var builds: int = almanac.page_builds - builds_before
		var was_visible: bool = almanac.visible
		almanac.hide_view()                    # [P28] also stops rendering the panel scene
		almanac.restore_section(prior)
		var build_ok: bool = builds == 1 and was_visible \
			and almanac.current_section() == prior and not almanac.visible
		ok = ok and build_ok
		print("[FrontEnd] opening the almanac builds its page grid once (%d build(s), visible = %s, tab %d -> %d restored = %s, hidden again = %s) = %s | %s"
			% [builds, str(was_visible), AlmanacView.Section.LEVELS, prior,
				str(almanac.current_section() == prior), str(not almanac.visible),
				str(build_ok), "OK" if build_ok else "FAIL"])
	else:
		ok = false
		print("[FrontEnd] the almanac view the bootstrap promised = false | FAIL")
	## [P107] the page is a SCENE: the probe opened it through the real door, so it leaves
	## the same way boot does - which also frees it before the last claim counts what is
	## on screen.
	open_main_menu()
	var fx_layer := Fx.layer()
	var on_board: bool = fx_layer != null and game.battle != null \
		and fx_layer.get_parent() == game.battle.grid
	var played := false
	var left := -1
	if on_board:
		Fx.spawn_popup(Vector2(20.0, 20.0), "wired", BalanceUI.COLOR_MESSAGE)
		played = fx_layer.get_child_count() == 1
		game.battle_main._teardown_board()            # [P109] 业主见 leave_game 的注
		left = Fx.clear()              # 0 = the teardown already took everything
	## [P106] THE BOARD IS NOT BUILT AT BOOT ANY MORE: it is a scene a battle brings with
	## it, and this probe runs on the main menu. With no board there is nothing to wire, so
	## the claim is DEFERRED (and says so) instead of failing; with a board it is the same
	## claim as before.
	var wire_ok: bool = (game.battle == null) or (on_board and played and left == 0)
	ok = ok and wire_ok
	print("[FrontEnd] the lawn owns the effect layer and a battle teardown takes a playing effect with it (on the board = %s, spawned into it = %s, still running after teardown = %d) = %s | %s"
		% [str(on_board), str(played), left, str(wire_ok), "OK" if wire_ok else "FAIL"])
	## [P109-2] "no page behind it" became "the MENU is the only page on screen" when the
	## menu itself became a scene (P108): the claim is still "nothing the probe opened is
	## left over", with the menu now counted among the pages.
	var clean_ok: bool = screen == Screen.MAIN_MENU and visible_views() == 1 \
		and main_menu_view != null and main_menu_view.visible \
		and not _return_to_battle and not _run_battle \
		and _pending_level_path == path_before and _battle_deck == deck_before \
		and _deck_pick == pick_before
	if not clean_ok:
		## A page the probe itself forgot to close is the likeliest cause, so say which
		## one instead of only that the state is dirty.
		for view in views_of():
			if view != null and view.visible:
				print("[FrontEnd]   still on screen after the probe: " + str((view as Node).name))
	ok = ok and clean_ok
	print("[FrontEnd] the probe leaves the front-end on the main menu, with the menu the only page up and no pick half-made = %s | %s"
		% [str(clean_ok), "OK" if clean_ok else "FAIL"])
	print("[FrontEnd] self-check %s" % ("PASSED" if ok else "FAILED"))
