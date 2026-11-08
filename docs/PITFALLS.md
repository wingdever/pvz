# PITFALLS.md · 踩过的坑与编码规范（**长期有效**）

> 这份文件回答"**哪些做法以前出过事，别再犯**"。它是**活文档**：新的坑落进 §2。
> **[repo-slim] 下文引用的 `docs/history/...` 指向已忽略、本地保留、不追踪的档案**：公开 clone 无此目录，属**已知死链**（详见 `README.md`「已知后果」）。
> 与它并列的文档见 `docs/DEV.md`（开发总览）；这里的内容对**任何一轮**都成立，与阶段无关。
> 它是从历史档案 `docs/history/01-p00-p27-handoff.md` 的 §7 抽出来的——**同一件事在历史里不再留第二份**，
> 而这一份是它唯一继续生长的家。

---

1. **`print` 里的 `%` 格式化必须写在同一个物理行。**
   曾因 `print("..." \n % [...])` 跨行，粘贴时续行丢失，导致日志打出字面 `%s`。
   → 规范：日志要么单行，要么用字符串拼接（`+`），不要跨行写 `%` 表达式。
2. **内嵌类名不得与 Godot 原生类重名。**
   曾用 `class Popup` → 报 `Class "Popup" hides a native class`。
   → 规范：内嵌类统一加业务前缀（`Fx.fx.gd` 里用 `PeaShot` / `HitSpark` / `FloatingText`）。
   避坑清单：`Popup` `PopupMenu` `Panel` `Label` `Line` `Timer` `Sprite` `Node` `Window` `Curve` `Theme` `Texture` `Image` `JSON` `Range` `Environment` `Animation` `Object`。
3. **`String.join()` 在 Godot 4 需要 `PackedStringArray`**，传 `Array[String]` 会解析失败。
4. **同一脚本里 `const` 不能重名**（曾出现 `FAST_FORWARD_ROUNDS` 定义两次 = 30/10，已统一为一次）。
5. **[P107d] 树要么全声明、要么全构建，别一半一半**（本条 2026-09-27 改写，原文是"保持 `main.tscn` 为裸
   Node2D，一切走运行时构建"，已被场景化推翻）。现状：**外壳 + 11 个页面 + 战斗都是场景**，
   `Game` 只**认领**节点。两条硬规矩：
   ① 进场景的只放**个数是常数**的静态骨架（`RUN_MAX_ROWS` 这类 BalanceUI 常数），数据驱动的那部分留在代码里；
   ② `.tscn` **不支持注释**——写 `## ...` 会报 `Parse Error: Expected '['`；解释写进脚本头或文档。
   手写场景时另两条：节点的**名字是契约**（脚本按 `$名字` 找、自检按名字数），改名前先想清楚；
   移动或新建场景后跑一次 `godot --headless --path . --import --quit-after 5`，让 uid 缓存跟上。
6. **只用稳定 API**（`create_tween()`、`@export`、`await`），避开已废弃写法。
7. **升级整文件替换优先**：大段增量粘贴是本项目主要错误来源。
8. **`class_name` 报 `Could not find type` 时**：根因通常是被引用脚本自身有解析错误；看 Errors 面板**第一条**报错的实际文件与行号，修完再 `Project → Reload Current Project`，必要时删 `.godot/` 重开。
9. **单位位置 `position` 是纯视觉量**（格中心 + 槽位偏移 + 滑动/抖动偏移），逻辑一律读 `col/row/hp/action_bar`。
10. **信号用 `died`，死亡走 `play_death()`**（淡出后再 `queue_free`），不要直接 `queue_free()`；重开时 `_start_new_game()` 会额外清掉「正在淡出、已不在 `units` 里」的残留单位。
11. **P9 起：绘制坐标一律来自 `Layout`，不要直接读设计基准常量。**
    `Balance.LAWN_ORIGIN` / `CELL_SIZE` / `CARD_SIZE` 等只是**设计基准 + Layout 启动兜底值**；
    直接拿来画，改窗口后就会错位。规则：**画在哪 → 问 `Layout`；数值平衡 → 改 `Balance`。**
12. **新增「会随窗口变化」的几何时，必须挂到重排链路上**：
    一次性绘制读一下 `Layout` 就够，但**被缓存的矩形**（按钮 position/size、单位 position）
    必须在重排时重算。链路是：`Viewport.size_changed` → `Game._on_viewport_resized()`
    → `Layout.refresh()` 返回 true → `grid.on_layout_changed()` / `hud.on_layout_changed()`。
    **不要自己再连一个 `size_changed`**：多份刷新会互相打架，也容易忘记清缓存。
13. **不要假设逻辑坐标是 1280×720**：它是「不小于 1280×720」，且随窗口比例在一条轴向上变大。
    判断可用空间请用 `Layout.size` / `Layout.top_h` / `Layout.bottom_y`，不要写死数字。
14. **窗口拉伸策略写在两处，以运行时为准**：
    ① `project.godot` 的 `display/window/stretch/*`（给人看的、也是编辑器预览用的）；
    ② **`Game._apply_window_policy()` 在运行时设置 `Window.content_scale_*`**——这才是保证。
    原因见第 15 条。改成 `keep` 会出现黑边；改成 `viewport` 会让文字变糊；`scale` 保持 1。
15. **别指望直接改 `project.godot` 能留下改动：编辑器会用内存里的设置把它整个重写回去。**
    P9 第一次交付时，AI 写进 `project.godot` 的 autoload `Layout` 和三个 `stretch/*` 键
    被编辑器原样回滚，直接导致 `Identifier "Layout" not declared in the current scope`，
    排查了半天。→ 规范：**凡是「代码行为」的开关，一律用运行时 API 设置**（`Window.content_scale_*`、
    `Window.min_size` 等）；`project.godot` 只当文档与编辑器默认值。反之，要在 `project.godot` 留下
    改动，必须在**编辑器关闭时**改，或用编辑器 UI 改。
16. **`:=` 推不出名称会直接报错，而 `game` 是无名称的。**
    `var game = null`（不写名称是刻意的，避免和 autoload 循环依赖），所以
    `var wave := game.next_wave_text()` 会报
    `Cannot infer the type of "wave" variable because the value doesn't have a set type.`
    → 规范：**凡是 `game.xxx()` / 字典下标 / 无名称变量的返回值，要么显式标名称
    （`var wave: String = game.next_wave_text()`），要么先 `str()` / `int()` / `float()` 包一层。**
    安全写法参考：`var paused: bool = game.is_operation()`、`var rows: Array = LevelList.discover()`、
    `var row: Dictionary = entry`、`var btn := row["btn"] as Button`（`as` 是带名称的，可以 `:=`）。
17. **新增 `class_name` 之前先确认它不与 Godot 原生类重名**（第 2 条同类问题）。
    P10 用 `Menu` / `UiStyle` / `LevelList` / `SettingsStore` 之前都查过：原生只有
    `MenuBar` / `PopupMenu` / `MenuButton` / `NativeMenu`，没有裸 `Menu`。
18. **画面流程只有一个主人**：`Game.screen`（`enum Screen`）。
    菜单按钮不自己切页，只调 `game.show_*()`；游戏按键只在 `screen == GAME` 时生效。
    新增页面时：加进 `enum Screen` + 加一个 `show_*()` + 加一个 `show_*()` 的隐藏钩子。
    **P12 的两种接法都已有先例**：① 塞进 `Menu` 的页面模型（`Page.LEVELS` / `Page.SETTINGS`，适合"一列按钮"）；
    ② **独立 `CanvasLayer` + 独立 `Control`**（花园 `GARDEN` 走这条，适合花圃这种非列表布局）。
    无论哪种，**隐藏都要挂到 `_leave_game()` 上**（花园是 `_hide_garden()`），否则切页时会留着幽灵控件吃点击。
19. **单位美术的两条硬规矩**（P11）：
    ① 「头 + 茎 + 两片叶」的**部件尺寸必须留在 ±30 px 以内**（单位中心 = 格中心，上方 `-50` 是名字、
    `-42` 是血条，下方 `+32` 是行动条）——加部件前先看 `[Art]` 自检的 fit 断言；
    ② **SVG 里写死的颜色要和 `Balance.COLOR_*` 同步**（SVG 读不到 GDScript 常量），
    每个素材文件头都注明了对应常量。
20. **别把回落分支删掉**：`Unit._draw_body()` 的「无贴图 → 画旧色块」、`UnitArt.load_texture()` 的
    null 返回，都是为了「素材没导入/路径写错/新单位还没美术」时游戏照跑。新增有美术的单位时，
    只需给 `art_path` 赋值，不要覆写 `_draw_body()`。
21. **「AI 直接改文件、用户 F5 验证」这个模式下，报错一次只暴露一条**（上一轮实测）：
    `Layout` 未声明 → 静态类方案；`hud.gd:359 Cannot infer the type of "wave"` → `:=` 推断；
    每次都要用户再跑一遍。所以**交付前必须按错误类别自查**，至少过一遍：
    ① 所有 `:=` 右侧是不是 `Variant`（`game.xxx()` / 字典下标 → 显式标名称或 `str()/int()/float()` 包一层）；
    ② 新 `class_name` 是否与 Godot 原生类重名（`Menu`/`UiStyle`/`LevelList`/`SettingsStore`/`UnitArt` 都已查过）；
    ③ 每个 `Balance.*` / `Layout.*` 符号是否真的存在（`grep` 交叉核对）；
    ④ 新增 `static func` 内部只调用 `static` 的兄弟函数（非静态调用会直接报错）；
    ⑤ 多行 `%` 表达式（§7.1）与 `\` 续行要写成单行或字符串拼接。
22. **编辑器会重写 `project.godot`（§7.15），也会「改了文件但没重新导入资源」**：
    新增/修改 `assets/**.svg` 后，Godot 需要重新导入才会在运行期生效。
    排查"素材没变"时先看 `[Art]` 自检与 `assets/svg/**/*.svg.import` 是否存在（P20 起素材在 `assets/svg/`），
    再 `Project → Reload Current Project`。
23. **花园的写回只有一个入口：`Game._settle_garden()`**，而且有 `_garden_settled` 布尔守卫
    （`_start_new_game()` 置 `false`，结算后置 `true`）。**不要**在别的地方直接改 `Garden.live`，
    也不要绕过守卫——`_end_game()` 会先结算再改 `phase`，`_leave_game()` 会先结算再拆棋盘，
    这两个顺序都是刻意的（结算要读场上还活着的单位）。
24. **战斗期间绝不改动花园档案**：场上发生的一切只写 `_garden_ledger`（`slot -> {hp, alive}`）。
    「按 `R` 重开就回滚」这个特性**完全靠这条**——一旦有人图省事在受伤时直接写档案，回滚就没了。
25. **`Garden.slot_at()` 返回的是活引用**（Godot 的 Dictionary 是引用名称），不是副本。
    读没问题；**只有 `water()` / `fertilize()` / `apply_results()` 内部才允许写它**。
    外面想"临时改一下血量做测试"请改存档文件，别改引用（会污染真实花园）。
26. **`Garden` 是实例类，`Garden.live` 是静态持有者**（和 `LevelData` 实例 + `SettingsStore` 静态的混合套路）。
    自检**必须**用 `Garden.new()` 探针实例：`save_to_disk()` 对 `source` 以 `<` 开头的实例会**拒绝写盘并告警**，
    这是防"自检把玩家存档覆盖了"的最后一道闸，别删。
27. **单位现在有两个身份来源**：`garden_slot >= 0` = 这是玩家的花园植物（要回写、名字带 `#n`、被铲走是"收回"）；
    `-1` = 关卡自带的（免费、不回写、被铲被啃都不影响花园）。加新的"造植物"路径时**必须显式决定它属于哪一种**，
    默认的 `-1` 意味着它不会回写。
28. **卡片冷却与工具充能共用同一套规则，但起点不同**：工具从 0 开始充能，**卡片开局即 READY**（`_reset_plant_cards()`）。
    两者都遵守「**目标非法不消耗充能**」。
29. **想画在按钮上，必须做成按钮的子节点**：`Control._draw()` 渲染在**自己的子节点之下**，
    所以父节点里 `draw_rect` 出来的东西会被按钮的不透明 stylebox 盖住。卡片冷却条就是这么做的
    （两个 `ColorRect` 子节点 + `MOUSE_FILTER_IGNORE`，否则会吃掉卡片的点击）。
30. **UI 里别用非 ASCII 字符做分隔符**：默认字体没有中文字形，`·` 之类的符号也有缺字形风险。
    本轮卡片副标题用的是 `"%d sun, %d free"`（逗号），刻意避开了 `·`。
31. **自检要走"真实路径"就得先把前置条件造出来**：召唤一株豌豆射手要 100 阳光，而关卡开局只有 50，
    所以 `_run_card_self_check()` 会临时把 `sun` 抬到 1000。**抬了就必须把 `sun` 与 `sun_spent` 一起还原**，
    否则结尾的 `economy check` 会 `FAIL`（这是本项目最强的回归断言，别让它因为自检而误报）。
    同理：自检里造的探针单位一律用 `_remove_unit()`（不发 `died`），否则会污染账本与 `zombies_killed`。
32. **新增页面走"独立 CanvasLayer + `Screen` 枚举 + `show_*()`"**，不要塞进 `Menu` 的页面模型里
    （`Menu` 的模型是"一列按钮"，花圃不是）。花园页 `garden/garden.gd` 就是这么接进去的；
    同时别忘了在 `_on_viewport_resized()` 的重排链路里调用 `garden_view.on_layout_changed()`（§7.12）。
33. **花园页不要手动设 `size`**：只 `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` 就够了。
    `hud.gd:57` / `menu.gd:59` 那种"先 FULL_RECT 再手写 size"会触发引擎警告
    （`Nodes with non-equal opposite anchors will have their size overridden after _ready()`），
    `garden/garden.gd` 已经刻意避开了这个坑。
34. **`summon_limit` 必须是运行时值，不许写死 1**：用户明确的规则是"每回合 1 次，**除非**后续肉鸽冒险给道具"。
    所以判断额度一律走 `summons_left()` / `can_summon_more()`，加成只改 `Game.summon_limit`。
    关卡 JSON 的 `summons_per_turn` 只决定**开局值**。
35. **前端页面可能"叠在战局之上"**（P13 的 `SETTINGS` 按钮）：这种情况下**绝不能**调 `_leave_game()`——
    它会结算花园并拆掉棋盘，等于把战局毁掉。判断"该回战局还是回菜单"的唯一入口是 `back_from_front_end()`，
    它看的是 `_return_to_battle`（由 `show_settings_overlay()` 置位、`_leave_game()` 清除）。
    新增任何"从战局里打开某页"的入口时，照抄这两步。
36. **新增顶栏/底栏上的控件时，几何一律先加进 `Layout`**（§7.11）：`top_buttons` 就是这么加的，
    并且顺手在 `Layout._audit()` 里加了"不出屏 / 不超出顶栏"的断言——断言比肉眼可靠，
    而且它会在**六种窗口比例**下自动跑。别把按钮的坐标算在 `hud.gd` 里。
37. **顶栏右对齐的读数会画到新控件底下**：`_draw_top_bar()` 的 `right_x` 必须来自
    `Layout.top_bar_text_right()`，不是 `w - HUD_SIDE_MARGIN`。同理，底部行标签的左边界是 `Layout.label_x + label_w`。
38. **新增 `class_name` 之前先确认它不与 Godot 原生类重名**（§7.2/§7.17 同类）：
    P13 没有新增 `class_name`；**P14 新增了 `Profile` 一个**，已核对无同名原生类
    （刻意避开了 `Item` / `Inventory` 这类高危名）。另外 `Screen` 枚举新增成员时，
    `menu.gd` 与 `_unhandled_input()` 都要跟着处理（P14 加的 `WAREHOUSE` 两处都改了）。
39. **钱币是物品，不是钱**（P14 的核心不变量）：`money` **只**在 `Profile.sell()` / `sell_all_coins()` 里增长。
    任何"捡到金币就 `money += 100`"的写法都是 bug。加新的奖励来源时**先决定它落进哪个容器**
    （战斗中 → 背包；战斗外 → 仓库），不要直接改 `money`。
40. **两个容器只有一个迁移方向**：`merge_backpack_into_warehouse()`（结算时）。反向（仓库 → 背包）**没有**实现，
    因为战斗开始时背包必然是空的。要做"带物品进战场"就得先加这一步与它的存档语义。
41. **`profile.json` 与 `garden.json` 是两个文件，别合并**：植物是"实体"（有 hp/等级/时钟），
    物品是"计数堆"，两者的坏档处理方式完全不同（前者重建起始花园、后者重建起始套件）。
42. **自然回归的时钟是绝对时间戳**（`Garden.now_unix()`），**不要在 `_process` 里累加 delta**：
    那个做法一关游戏就停表，与"1 分钟就是 1 分钟"的设计冲突。`apply_natural_recovery()` 是**幂等**的，
    可以在加载、开页、开战前随便多调几次。
43. **`downed == true` ⇔ `hp == 0` ⇔ `downed_at > 0`** 这三者必须同时成立：
    `parse_text()` 会强制修正不一致的存档（包括给旧存档补一个 `downed_at`，让回归从"现在"开始而不是立刻）。
44. **自检不得污染真实存档**：`Garden.save_to_disk()` 与 `Profile.save_to_disk()` 都会**拒绝**来源以 `<` 开头的
    探针实例。自检改真实对象（比如把玩家的豌豆射手强行治活、临时塞一张卷轴）时，**必须原样还原**
    （`_run_card_self_check()` 里有完整示范：快照 → 改 → 断言 → 还原）。
45. **掉落只在僵尸真正死亡时结算**，且由 `_drops_enabled` 兜住自检：工具自检会用锤子杀两只探针僵尸，
    如果不关掉落，每次启动都会凭空多出钱币（数值不大，但会让"经济"难以推理）。
46. **`ROW_LABEL_SCROLLS` 的文案是 `SUMMONS` 不是 `SCROLLS`**：P14 之后"卷轴（scroll）"是**物品**，
    而底栏那一行是**每回合召唤额度**。两个概念别再用同一个词。
47. **`PLAN.md` 与 `HANDOFF.md` 不随时改**（P21 轮用户明确要求；现已在 `docs/history/` 归档，规则见 `AGENTS.md` §6）：
    **默认不动这两份文件**，只有用户**在一轮对话结束时明确要求"写文档 / 更新文档 / 交接"**，才在**那一轮**编辑；
    下一轮自动恢复为"不编辑"（与 §1 第 3.1 条的当轮例外同构，不要推广）。
    没被要求时，改动说明与验收命令**写在对话回复里**；若认为某条内容非落进这两份文档不可，**先问用户**。
    边界：`README.md`、源码/数据文件、新建文档、`AGENTS.md` 本身**不受**这条约束；
    `ART_PIPELINE.md` 等未点名的长期文档暂按"可以改"处理。
    > 本轮（P21）我在用户提出这条规则**之前**已经写过这两份文档；用户随后明确要求"关于本轮对话编写相关文档"，
    > 所以 §4.20 / §5.16 / §7.47 与 `PLAN.md` v1.23 属于**当轮被授权**的写入。
    > 本轮（P22）同样：用户说了「根据本次会话编写相关文档，然后结束本轮会话」，
    > 所以 §4.21 / §5.17 / §7.48~52 与 `PLAN.md` v1.24 是**当轮被授权**的写入。
48. **`Loc.t()` 读的词条里不要写 `%` 占位符**（P22 教训）：`Loc.t()` **不做格式化**，`%d` 会原样印到屏幕上；
    只有 `Loc.tf()` 会替换。`Balance.item_hint()` 之类"用 `Loc.t()` 读的表"（`item.hint.*` / `item.kind.*`）
    因此一律写成散文数字，并在表里写了警示注释；**要带数字就用 `Loc.tf()` 并传参**。
49. **给一个类加"只有某个宿主用得上"的旋钮之前，先想清楚它是不是另一个类**（P22 教训）：
    我一度把主菜单需要的"大图标 + 大字号"塞进 `ItemTile`（`icon_max` / `font_size`），
    还给它加了键盘支持；需求改成"菜单图标不要格子外观"之后这些全成了死代码，只能回退。
    最后是 `MenuProp`（新类）承担了菜单那四件东西。**判据：如果两个宿主要的行为差一个"有没有边框"，
    那就是两个类，不是一个类加开关。**
50. **新增带 `class_name` 的脚本后，Godot 需要知道它**（P22）：全局类名靠
    `.godot/global_script_class_cache.cfg` 解析，该文件平时由**编辑器扫描**生成。只跑 `--headless`
    不开编辑器时，新类名可能解析不到（`Could not find type X in the current scope`）。
    处理：让用户在编辑器里 `Project → Reload Current Project`（或 `godot --headless --editor --quit`）跑一次。
    AI 可以**手动补条目**（格式与编辑器一致、按类名排序、**改前先 `read`**，因为编辑器可能刚重写过它）；
    但**绝不要**为了绕开这个问题去改源码（比如把 `extends ItemScreen` 改成路径字符串）。
51. **删翻译词条之前先 `grep` 反查引用**（P22）：`Loc.self_check()` 只审"表本身"
    （两语齐全 + 占位符数量一致），**查不出"代码里还在用一条已被删掉的键"**——
    那种情况要等玩家点开那个界面才会看到 `Loc` 警告或键名直接上屏。
52. **`edit` 工具改完一段要 `read` 回来确认**（P22 真实踩到）：`old_string` 若以换行结尾，
    一次替换可能把**下一行吸上来**，产生 `var x := f(id)		if x < 0:` 这种**同一行粘连**的语法错误。
    本轮发生一次并当场修掉。**规则：任何跨行/带空行结尾的替换，改完立刻 `read` 那一段。**
    > P23/P24/P25 轮又踩到两次**同一类**问题，但换了个形式：`old_string` 只写了半行标题
    > （例如 `#### 5.17.3 ...`），替换后**把小节的标题整行吃掉了**。改标题/小节头时，
    > `old_string` 要包含整行，改完 `grep -n "^#### "` 数一遍小节还在不在。
53. **脚本不得重定义原生成员（P24 真实事故，最贵的一条）**：`GardenTool` 里写了 `var ready: bool`
    → Godot **拒绝解析整个 `garden/garden.gd`**：
    `Member "ready" redefined (original in native class 'Control')`，
    花园页直接起不来（**不是警告，是解析错误**）。`ready` 之所以被占，是因为它是 **`Node` 的信号**。
    同类的"普通英文词"还有 `name`、`owner`、`title`(Window)、`visible`、`position`、`size`…
    **做法**：给自绘 Control / Node 加成员前先跑 `tools/member_name_check.gd`（§5.18.1 第①条，
    ClassDB 反射、不用启动游戏）；改完再 `grep` 一遍新成员名。**修法**：改名
    （`ready → in_stock`、`target → is_target`、`dropped → drop_requested`）。
54. **命令白名单只有"只读查找"（P23 用户放宽 + AI 违规记录）**：`AGENTS.md` §1 现在允许
    `ls` / `find` / `pwd` / `file` / `stat` / `wc`，**其余全部仍由用户执行**。
    P24 轮 AI 还用 `python3` 跑了一批机械改名（`target`/`dropped`），**这属于越界**：
    批量改名也应该用 `edit` 一条条改，或先问用户"这一轮能不能跑"。下次不要重犯。
55. **多行表达式不要用 `\` 续行**（P25）：本项目风格里没有反斜杠续行（GDScript 也不推荐），
    改用**括号**包住表达式。手写完多行算式后 `grep -n '\\$' <文件>` 扫一遍，
    有剩余就改成括号（本轮抓到 5 处）。
56. **界面盒子随窗口变时，内部偏移不许写死像素**（P25 的根因）：花园页原来
    `GARDEN_PLOT_SIZE = 150` / `GARDEN_TOP = 168` / `GARDEN_POT_TOP = 106` 全是绝对值，
    于是"4×4 放不下"只能靠改窗口尺寸解决。现在：**盒子大小由纯函数算**
    （`GardenView.metrics_for()`，可被自检审计），**格子内部全部用比例**（`GARDEN_*_RATIO`）。
    新增界面时照这个来：先写 `metrics_for()` 一类的纯函数，再让 `_layout()` 摆、`self_check()` 审。
57. **素材接入先看"实心范围"，再谈位置**（P23/P25 的通用钥匙）：花盆用 `GARDEN_POT_CONTENT`、
    植物用 `PLANT_ART_INK`（**量在各自的贴图像素里**，坚果墙是 96×96 对 100 viewBox，要 ×0.96）、
    菜单四件东西用 `MENU_ICONS.content`。**只画实心范围**，SVG 留白就永远影响不到版式；
    植物更要用 `draw_texture_rect_region()` 按实心框裁，否则三种留白不同的植物会"大小不一、
    离盆远近不一"。
58. **常量速查表会过期**（P25 发现）：§10 里 `GARDEN_START_ROSTER` 一直写着 P12 时代的三株
    （实际 P14 就缩成 1 株）、`GARDEN_CAPACITY/ROWS` 还是 12/3。**改常量时顺手扫一眼 §10 有没有它**，
    不然下一轮会照着错的表去改代码。
59. **TAB 数据表：空值一律写 `—`，不要留"连续空列"**（P26）。手写 CSV 时最容易在
    "连续几个空字段"处**少打一个 TAB**（本轮 `plants.csv` 的 `jalapeno` 那几行就是这样，
    16 列 vs 17 列），后果是**整行数值右移**。核对命令：
    `awk -F'\t' '{print NR": "NF}' data/units/plants.csv`（**每行都必须一样**：植物 20、僵尸 13）。
60. **"显示行"不是"数据行"**（P26）：图鉴最初用给 `ItemGrid` 的显示行（只有 id/title/art/badge）
    去读 `playable` / `spawn_plan`，于是**每个关卡都显示"数据错误"**。
    → 规范：一个页面同时有"格子行"和"数据行"时，**两个查找函数分开写**（`_find_row()` / `_find_level()`），
    别图省事复用同一个。
61. **"真源"换了，自检的不变量也要跟着换**（P26）：表和常量本来是一份数据，加表之后变成两份；
    自检若还断言"表和常量一致"，**用户每改一次 csv 就会看到一片 FAIL**。
    → 规范：自检断言**接线**（"战斗解析出的值 == 表里的值"），把"表和常量不一致"当**正常**打印
    （`overrides Balance: hp 300->500`）。同理适用于任何"数据文件覆盖代码默认值"的改造。
62. **别在 `.godot/` 里做大范围 `grep`**（P26）：查"新素材有没有导入"时顺手 grep 了整个
    `.godot/imported`，输出 14 KB 被截断、还把上下文挤掉。→ 只用 `find <具体目录>` /
    `grep <具体文件>`，或直接 `ls .godot/imported | grep <名字前缀>`。
63. **bash 里 `grep '\t'` 要写 `$'\t'`**（P26）：`grep -o '^\t"key":' ...` 会被 grep 当成字面 `t`
    （stderr 只有一句 `stray \ before t`，**不报错**），于是"没有重复"是**假结论**。
    改用 `$'\t'` 或 `grep -P`（本工程的 CSV 列数核对用 `awk -F'\t'` 更省事）。
64. **写进文档的数字要顺手核一遍**（P26）：我在 `docs/UNIT_ART.md` 里写"20 张图都是纯色块"，
    实测 `gatling_helmet.svg` 有**一条 `stroke`**（其余 19 张确实是纯 `fill`）。
    → 规范：文档里的"全部 / 都 / 一定"这类断言，落笔前 grep 一次。

---

65. **布尔参数在调用点写全 `not`，别把"正向"传进"反向"位**（P27，**用户发现的真 bug**）。
    图鉴的 `_status_note(p_limited, p_limited_label, p_has_art)` 第一个参数语义是"**没**实装"，
    植物那行却传了 `summonable`（正向），于是**唯一三个实装的植物反而被标成"尚未实装"**；
    同格的 `dimmed` 传的是 `not summonable`（对的），画面就变成"亮着的格子写着未实装"。
    **为什么自检没抓到**：`[Almanac]` 只审几何、`[Plants]` 只审数值接线，**没有一条断言看文案**。
    → 规范：① 参数名带 `p_incomplete` / `p_limited` 这种极性词，调用点一律写 `not xxx`；
    ② **成对出现的信号（标签 + 变暗 + 是否可选）必须同源**，能从同一个局部变量派生；
    ③ 页面级自检如果能顺手断言"标签与变暗一致"，就加一条（P27 未加，属可选）。
66. **GDScript 默认参数不要读别的类的 `const`**（P27）：`ItemGrid.fit_for(p_tile = Balance.ITEM_TILE_SIZE)`
    这种写法不稳（默认值必须是常量表达式）。P27 的写法是**用 0 当哨兵**：
    `p_tile_size: Vector2 = Vector2.ZERO, p_max_cols: int = 0`，函数体里 `if p_tile_size.x > 0.0` 才覆盖，
    否则退回共享常量 —— 老调用点一个都不用改，行为与改造前完全一致。
67. **新建带 `class_name` 的脚本要"让编辑器先扫一遍"**（P27 踩到）：全局类名登记在
    `.godot/global_script_class_cache.cfg`，**`godot --headless --path .` 直接跑不会重新扫描文件系统**。
    没扫到就会报 `Identifier "ItemDB" not declared in the current scope` / `Parse Error`，
    看起来像代码写错了，其实是缓存旧。→ 交付时**先让编辑器 reload 一次**（顺便生成 `.uid` 与 `.import`），
    或手工往缓存里补一条（P27 就是这么做的，编辑器下次扫描会写成同样的内容）。
    **同理**：新的 `.csv` 表也要让编辑器扫一次才会生成 `*.csv.import`。

---
68. **GDScript 的 `const` 是「按脚本」作用域，不是「按工程」**：A 脚本里写 `const X := preload("res://a/x.gd")`，B 脚本**看不见** X —— 每个用到 X 的脚本都要自己 preload 一份（本工程所有"不带 `class_name`、用 preload 消费"的模块都是这个道理）。
   **踩过一次（P83）**：`game_manager.gd` 声明了 `DropDB`，`rewards.gd` 直接用 → `rewards.gd` 编译失败 → 依赖它的
   `game_manager.gd` 也失败（`Failed to compile depended scripts`）。
   **症状很隐蔽**：不是几条 FAIL，而是**整块判决行消失**（`Rewards.self_check` / `SelfChecks` / `FrontEnd` 三个模块的
   `self-check PASSED` 行全没了，`PASSED` 计数从 29 掉到 27），另外会有一句
   `Invalid call. Nonexistent function 'self_check' in base 'GDScript'`。
   **所以计数是必须看的**：`grep -c PASSED` 掉了就是有模块没说话，去日志头找 `Parse Error` / `Compilation failed`。
   **同一类坑在 P85 又踩了一次**：一个 `scripts/checks/` 下的探针用了 `SUNFLOWER_SCRIPT` 而没自己声明，
   症状一模一样（`[SelfCheck]` 整个模块的判决行消失、boot 的 PASSED 从应有的 33 掉到 32，而 `FAILED` 仍是 0）。
   ⇒ **数读数时还有一个陷阱**：boot 里**没有** `[SelfCheck]` 这个前缀——`SelfChecks.self_check()` 打印的是 `[Loc]`，
   而 `[SelfCheck]` 是**战斗探针**的前缀。第一次排查时我把它当成"boot 缺了一个模块"，白追一轮。
   ⇒ **现在有机器盯着了**：`[Arch]` 的第 5 条判据会遍历全仓——凡是"用了别处 `preload` 的常量却没在自己文件里声明"
   的文件，逐个点名并让那一条变红（扫描前会剥掉注释与字符串内容，免得把 `"[SafeIO] …"` 这类消息算成使用）。

---

### 2.1 [B2b/B2c] 三连坑：三件"只有点下去才知道"的错误（2026-10-04）

> 这一批（乱斗 B2b/B2c）**用户手动测出了三次同一个家族的错误**：门改签名、门不存在、门问错了业主。
> 三次 GDScript 都**没有**在编译期或 `--import` 时报错，因为**页面里的 `game` 故意不标名称**
> （所有页面都这样，为的是避开循环 import）——于是整条调用链是动态的，只有真的点下去那一刻才检查。

69. **改了被调用方，忘了调用方**：`BrawlMain.start_bout()`（无参）在 B2b 变成 `start_bout(p_index)`，
    而 B2a 写的 `main_menu._on_brawl()` 还在调无参版 ⇒ 点"乱斗模式"当场
    `Invalid call to function 'start_bout' in base 'RefCounted (BrawlMain)'. Expected 1 argument(s).`
    → 规范：**改一个门的签名时，先 grep 全仓调用点**（`grep -n "start_bout" -r scripts` 一行就够）；
    这也是"每次改门之后跑一次开机自检"最便宜的理由。
70. **门在另一个对象上，根本不存在**：设置页有 **6 处** `game.apply_language()`（语言按钮、音乐、
    音效、自动拾取两个按钮…），而 `apply_language()` **只存在于 `FrontEndFlow`**；P109 把页面搬到
    `front_end_flow` 时漏了那一行转发。症状很轻：设置**存下来了**（那一句在前），紧接着报
    `Invalid call to function 'apply_language' in base 'Node (GameManager)'`，**页面标签不刷新**——
    不点那个按钮就永远发现不了。→ 规范：页面只认识 `game`，所以**每个被页面调用的能力都必须在
    `Game` 上有一行转发**（`show_*` 那一族就是范本）；搬走一个方法的业主时，把它的门一起搬。
71. **问错了业主，"兜底"会把错误伪装成正常**：编排页的敌阵预览用 `Balance.plant_art(id)` 取图，
    而敌阵是**僵尸**——`plant_art()` 查不到植物行时**不返回空**，而是回它的兜底 `ART_PLANT`
    （光板植物），于是每只敌方僵尸都被画成了植物素材，看起来"像是素材放错了"，其实是**问错了表**。
    → 规范：一个画面上**可能同时出现两个花名册**时，一律走 `Balance.unit_name()` / `Balance.unit_art()`
    （[B2c] 新增的两个门，顺序与工厂一致：**先僵尸后植物**）。判据：
    `plant_art()` 的兜底是**为植物设计的**，拿非植物 id 去问它，答案永远是"合法但错的"。
72. **子节点画在父节点 `_draw()` 之上**（这一个不是"门"的问题，是 Godot 的绘制顺序）：
    编排页把整块战场画在自己的 `_draw()` 里，而场景里有一个不透明的 `Background`（ColorRect）
    子节点铺满屏幕 ⇒ **父节点先画、子节点后画**，战场被盖得干干净净，用户看到的是
    "黑乎乎一片 + 几个飘着的按钮"。主菜单/结算页没暴露这个坑，只因为它们**不**在自己的 `_draw()` 里画东西。
    → 规范：**页面自己画内容时，底色也在自己的 `_draw()` 里画第一个矩形**，不要用不透明的子节点当底
    （`brawl_formation.tscn` 是这么做的，并在脚本里留了注释说明"这一页故意没有 Background"）。
73. **场景给自己准备的"默认夹具"，会在业主递上真配置之前先跑一遍**（**[B5]** 发现；症状玩家看得见）：
    `scenes/brawl.tscn` 的 `_ready()` 无条件跑 `begin(BrawlSetup.fixture())`（那是给 F6 单开场景用的），
    而 `BrawlMain._set_up_arena()` 是**先 `add_child`、下一行才 `begin(真 setup)`** ⇒ 每次开打都
    **先造出一整队替身棋子、连素材与视图场景一起实例化，再被 `restart()` 全部丢掉**。
    日志里的证据是**两行** `[Brawl] bout started`（B5 起人类棋子每次实例化还带 9 条 `Bone2D` 警告，
    所以那一晚的日志里同一个警告出现了 54 次而不是 27 次）。
    → 规范：**"没人管我时我自己来一套"的场景，那一手要延后一帧，并先问"这一帧里有人给我配置了吗"**——
    现在写成 `_deferred_fixture.call_deferred()` + `if setup == null`。
    判据：一次开打只该有**一行** `bout started`（这条不需要自检模块，看日志就够）。
74. **页面的脚本加载失败时，它会静默变成一个空壳**（**[B5+]** 自己踩到，比第 73 条更值得记）：
    `brawl_shop.gd` 里我写了两个同名的局部变量（`var row` 两遍 → `Parse Error: There is already a
    variable named "row" declared in this scope`）。后果不是崩溃，而是：**整个游戏照常启动、照常跑完一整局**，
    因为 `FrontEndFlow._bring_up()` 装页面用的是 `if page.has_method("open_view")`——
    脚本没加载 ⇒ 那个 `.tscn` 就是一个**没有脚本的 Control** ⇒ 点进商店**什么都不发生，也不报错**。
    更阴的是：我的冒烟探针那一轮**照样"通过"**，因为它直接驱动 `BrawlSession`（页面背后的数据对象），
    根本没经过页面自己的代码。
    → 规范：① 老规矩照旧——**每次改完先看日志头有没有 `Parse Error` / `Failed to load script`**
    （它在日志第 3 行，很容易被几百行自检淹掉）；② **"页面能打开"不等于"页面的代码在跑"**：
    验收一条界面路径时要从**页面自己的方法**进去（探针里至少断言 `page.get_script() != null`，
    或者干脆调用页面上的函数，而不是绕过它）。

---

75. **表格工具把整数重新导出成浮点，`int_cell` 只认 `is_valid_int()` ⇒ 全表整数读成 0**（**[B11b]** 被用户当场发现，症状最唬人）：
    `data/units/units.csv` 被重新导出后，HP / attack / defence 都写成了 **`300.0` / `20.0` / `1.0`**。
    读取链是 `UnitCsvManager.int_of()`：它只放行 `text.is_valid_int()`，于是 `"300.0"` 被判成
    “拼了但不是整数” ⇒ **记一条 complaint 并回落到默认值 0**。后果按列放大：
    · `HP` = 0 ⇒ 每个数据库都写 `maxi(1, hp)` ⇒ **全游戏每个单位只有 1 点血** ⇒ 打一下就死；
    · `attack` = 0 ⇒ 一击的底价是 0 ⇒ 乱斗的 `land_hit` 钳到 1（再过一个防御公式）⇒ **伤害永远是 1**；
    · `defence` = 0 ⇒ 刚加的防御整列失效（盾卫也不硬了）；
    · `turned`/`timed` 里的 `0.0` 被 `flag_on()` 的**字符串**比较当成“不是 `0`” ⇒ **0 被读成 ON**。
    → 规范：① **整数值的浮点写法（`300.0`）就是整数**，`int_of()` 现在接受它（`is_equal_approx(v, roundf(v))`），
    真有小数（`300.5`）仍然报 complaint；② **开关列按数值读**（`flag_on`：`0` / `0.0` = OFF）；
    ③ 症状是“**伤害恒为 1 + 打一下就死**”时，第一站是**日志里那一片 complaint**
    （`HP = "300.0" is not a whole number … -> read as the default 0`），不是伤害公式。
---

76. **两张族表少了一列，红的是别人的模块**（**[B14]** 顺手发现的一笔老账，症状与改的东西毫无关系）：
    `data/units/humans.csv` 与 `data/units/monsters.csv` 是**同一个读者**（`PieceDB`）逐行读的两张表——
    P110f/P110g 给 `monsters.csv` 加了 `远程特效` / `持续` 两列，**没有同步加给 `humans.csv`**（它一直是 9 列）。
    后果不是“某个怪兽不发光束”，而是：`PieceDB._parse_row` 对**每一条人类行**都问那两格 ⇒
    `UnitCsvManager._check_column` 记一条 `units.csv, humans.csv: no column "远程特效" in the header (read as blank)`
    ⇒ 那条 complaint 是**全局排队**的，而**第一个跑来 `report_complaints()` 的自检模块会把它的账清掉**：
    开机顺序里 `PieceDB.load_from_disk()`（game_manager 第 96 行）在 `PlantDB.self_check()`（第 475 行）之前 ⇒
    **红的是 `[Plants]`**（一个跟乱斗毫无关系的模块），而 `[Plants]` 的读数本来是全绿的。
    → 规范：① **加列/减列时，共享同一个读者的两张表一起改**（`ADD_UNIT.md` §1.37 已经写成一条）；
    ② 看到**与改动无关的模块**变红时，先看那句 complaint 点的是**哪个文件**——`_check_column` 会把文件名写进去；
    ③ 判断标准仍然是 `FAILED = 0`，所以这条在用户跑验收前**不会自己消失**。