# ARCHITECTURE.md · 代码实现约定

> 这份文件回答"**怎么用代码把它实现出来**"：工程骨架、模块形状、数值归属、呈现层怎么画、
> 贴图怎么兜底、自检框架长什么样。
> **游戏是什么**见 `PROMPT.md`（体裁、规则、单位与道具、关卡、Meta、素材效果、输入）；
> **开发顺序与验收节奏**见 `docs/DEV.md`；**现状**见 `docs/STATE.md`。
> 冲突时：**规则语义以 `PROMPT.md` 为准，代码结构以本文件为准。**

---
## 1. 工程骨架

### 1.1 `project.godot`（照抄这些值）

| 键 | 值 |
|---|---|
| `config_version` | `5` |
| `config/name` | `PvZ Turn-Based` |
| `config/description` | `Plants vs Zombies, turn-based grid remake.` |
| `config/features` | `PackedStringArray("4.7", "GL Compatibility")` |
| `run/main_scene` | `res://scenes/main.tscn`（**宿主外壳**：`MenuLayer` + 常驻 `Menu` + `GardenLayer`，见 §3.4） |
| `[autoload]` | 只有两个：`Boot="*res://scripts/core/boot.gd"`、`Game="*res://scripts/core/game_manager.gd"` |
| `display/window/size/viewport_width` / `_height` | `1280` / `720`，须与 `Balance.WINDOW_SIZE` 同步 |
| `display/window/stretch/mode` / `aspect` | `canvas_items` / `expand` |
| `rendering/textures/canvas_textures/default_texture_filter` | `0`（Nearest，SVG/像素图） |
| `rendering/renderer/rendering_method` / `.mobile` | 两者都是 `gl_compatibility` |
| `[addons]` | 只有做 `PROMPT.md` §7.5 那个可选的编辑器插件时才需要 |
| `[input]` | **不存在**。没有自定义 action，所有按键用裸 `KEYCODE` 匹配（`PROMPT.md` §8） |

> 这份文件里**没有**最小窗口键 —— `640×400` 是代码里锁的（`Balance.MIN_WINDOW_SIZE`，
> 由 `Game._apply_window_policy()` 在启动时施加）。整份 `[display]` 只有上面那 4 行。

> **不要往 `project.godot` 里加 autoload，也不要靠它设置窗口拉伸策略。**
> 编辑器会用它内存里的设置重写这个文件，所以它只放「必须被编辑器看见」的那几行。
> 拉伸策略在启动时用代码设（`Game._apply_window_policy()`）；
> 需要「全局可访问」的东西一律用 §1.3 的静态模块，而不是 autoload。

### 1.2 目录树

```
scenes/main.tscn          宿主外壳（两个 CanvasLayer + 常驻菜单；页面与战斗按需装载）
project.godot
scripts/
  balance/                [P108] 数值表按**谁读它**分家（见 §2）
    balance.gd            Balance      —— 全局规则数值 + 所有文件路径常量
    balance_ui.gd         BalanceUI    —— 呈现数值（像素/字号/颜色/时长）
    balance_audio.gd      BalanceAudio —— 曲目表 / 音效 cue 表 / 音量阶梯
    balance_battle.gd / balance_garden.gd / balance_run.gd / balance_shop.gd
                          [P108] 四个场景各自的常量
    balance_brawl.gd      BalanceBrawl —— [B1] 实时乱斗自己的常量（第 8 张表，见 §1.5）
  core/                   boot / game_manager / game_self_checks / run_flow / rewards / spawn /
                          grid / unit / unit_sheet / unit_csv / layout / difficulty /
                          level_data / level_list / chapter_map / run_state /
                          music / sfx / loc / loc_names / loc_garden / arch_check / doc_check
  core/db/                [P109] 数据表读者：plant_db / zombie_db / item_db / skill_db /
                          event_db / status_db / projectile_db / drop_db / rarity_db /
                          level_db / piece_db / roster_db / gear_db / formation_db
  core/battle/            [P106] battle（一局的根脚本：世界 + HUD + 回合机）/ battle_setup /
                          battle_main（开局 / 结算 / 奖励账）/ battle_anim / sun_field / sun_drop
  core/brawl/             [B1–B8] 乱斗（实时那一支，见 §1.5）：
                          brawl（一局的根：双方 + 时钟 + 胜负）/ brawl_main（**第二个会话业主**）/
                          brawl_session（会话状态：轮次 / 金币 / 挂件 / 花名册 / 三条敌阵） /
                          brawl_setup（一局的输入，纯数据）/ brawl_clock（定步长）/
                          brawl_field（场地几何 + 画面，**静态**）/ brawl_actor（棋子的驱动器：
                          位置 / 朝向 / 出手）/ brawl_intent（意图，静态无状态）/
                          brawl_shot（[B8] 一发在飞的射弹：三条轨迹 + 拖尾 + 命中爆环）
  core/save/              [P109] 存档层（结构与键见 §8）：save_io（判格式）/ safe_io（原子换入
                          + 坏档归档）/ save_ledger（三道门 + 脏账）/ garden / profile /
                          settings_store
  ui/                     hud / ui_style / ui_font / front_end_flow（[P109] 页面流程） /
                          item_tile / item_grid / main_menu / loc_ui / loc_msgs / loc_run
  ui/brawl/               [B2b–B8] 乱斗三页：brawl_formation（**整块战场** + 背包 + 花名册 +
                          右栏切敌阵 + 出战）/ brawl_round（结果面与三张奖励卡） /
                          brawl_shop（第五格货架）
  ui/run/                 [P107] 战役四页与选卡（同一套池化骨架，五种钩子）：
                          run_screen（共用行为）+ squad / roadmap / reward / choice / deck
  ui/garden/              [P107] 花园页：garden_view（页面）+ garden_plot（一个花盆）+
                          garden_tool（一个照料格）+ cursor_ghost（手里那件东西）
                          —— 页面的节点类各自成文件，因为场景要能声明它们
  ui/item_screen/         [P107] 仓库 / 商店 / 背包：item_screen（三页共用的行为）+
                          warehouse / shop / backpack（各自只多一层"这一页是什么"）
  ui/almanac/             [P107] 图鉴页：almanac（页面；页签记在 settings.cfg 的 [ui] almanac_tab）
  ui/menu/                [P107] 主菜单：menu（页面）+ menu_prop（地上那件可点道具）+
                          levels_page / setting_menu —— 菜单常驻，四个道具由场景声明
scenes/ui/               [P107] 前端页的场景：garden / warehouse / shop / backpack / almanac /
                          menu / levels / settings / squad / roadmap / reward / choice / deck .tscn
                          + [B2b–B8] brawl_formation / brawl_round / brawl_shop .tscn
                          —— 静态骨架在这里，行为在 scripts/ui/ 下的同名脚本里
  units/                  plant_scripts（注册表） / unit_art / zombie / human_piece /
                          24 个植物脚本
    base/                 shooter_plant / producer_plant / wall_plant /
                          pult_plant / one_shot_plant / spike_plant
  fx/fx.gd                Fx           —— 一次性特效（火星、飘字、震屏）
  checks/boot_checks.gd   启动自检（[P109] 的战斗探针已删；探针纪律见 §5.3 与 `AGENTS.md` §2）
  projectiles/            projectile（通用基类；pea_projectile / pult_projectile 现在是空壳）
tools/                    member_name_check.gd / sheet_complaint_probe.gd  —— 两个离机探针
data/                     见 `PROMPT.md` §4~§6
assets/svg/ assets/audio/ assets/fonts/   见 `PROMPT.md` §7
scenes/units/plants/*_view.tscn           单位视图骨骼场景（可选，见 §4）
docs/                     规格之外的长期文档
```

> 目录树里的**文件与类名可以换，职责分工不能换**——规格里出现的路径都是「本版默认形状」。

### 1.3 "静态模块"模式（本项目最重要的一条架构约定）

四种形状，按需要不需要节点、需不需要状态来选：

| 形状 | 用于 | 理由 |
|---|---|---|
| `class_name X extends RefCounted` + 全是 `static func` | `Balance` `Layout` `Difficulty` `Fx` `Loc` `UiStyle` `UnitArt` `PlantDB`… | "故意不是 autoload：不用登记进 `project.godot`，任何脚本都能 `Layout.<name>` 直接够到" |
| **不带** `class_name`，被 `const X := preload(path)` 持有 | `SafeIO` `Rewards` `ScreenFlow` | 见下方陷阱；一个不带 `class_name` 的模块**写完当天就能被无头运行证明**，所以从大文件里搬出来的小块优先用这个形状 |
| autoload 单例 | 只有 `Boot`、`Game` | `Game` 是状态本体 |
| `Node2D` / `Control` 子类 | `Unit` `Grid` `Projectile` 所有页面 | 要进树、要 `_draw`、要收输入 |

> **陷阱（决定文件写法）**：新写的**全局 `class_name` 在编辑器重扫工程之前对 `godot --headless` 是不可见的**。
> 而"无头能跑自检"正是本项目的验收方式（§5）。所以**每一次"从大文件里搬出一块"的改动，
> 新文件都故意不写 `class_name`，改用 `const X := preload("res://.../x.gd")` 消费**——
> 这样它写出来的当天就能被无头运行证明。
> 另一个陷阱：内部类**不得与 Godot 原生类同名**（`Fx` 里那两个叫 `HitSpark` / `FloatingText`，
> 不叫 `Popup`/`Label`/`Timer`）；`tools/member_name_check.gd` 存在的唯一目的就是抓"脚本成员
> 撞了原生成员"（历史上真撞过 `ready`）。

### 1.4 god object 的处理方式

管理器脚本（autoload `Game`）拥有全部战斗状态，是全工程最大的那个文件。
它的拆法叫**"搬代码、留状态"**：把职责搬出去（自检 → `SelfChecks`、战役流 → `RunFlow`、
掉落 → `Rewards`、前端页面流 → `ScreenFlow`），但状态（`screen`、视图节点、花园账本）**留在 `Game` 里**，
被搬出去的模块通过一个带名称的 `game: GameManager` 参数回去读。
`Game.show_*()` 保留为一行委托，调用方不用改。

**[P106] 这条规则在“战斗”上被改写了**（`docs/OPEN_ITEMS.md` §0.4 的 Q1，用户拍板）：**状态按会话分片**。

- **`Game`** 拥有：存档（`garden` / `profile` / `run`）、战役、12 个前端页与 `screen`、设置与音乐/语言、
  以及“这局结束了**意味着什么**”（`_on_battle_settled`）；
- **`scripts/core/battle/battle.gd`**（`class_name Battle`，`scenes/battle.tscn` 的根）拥有一局的一切：
  棋盘、HUD、回合机、每局状态、花园账本；
- **方向是单向的**：`Game` 认识 `Battle`，`Battle` **一个字都不许提 GameManager**（`battle.gd` 里 grep
  `Game\.|game_manager` 必须为空）。`Battle` 只通过 5 个信号回报，`Game` 通过 9 个门下令；
- **不许有镜像**：同一个名字不许在两个文件里各声明一次——`scripts/core/arch_check.gd` 的
  **第 6 条判据**每局开机检查这件事（白名单只有输入、两扇各自保留的门、以及两个文件读同一份 profile 的问题）。
  为什么是**规则**而不是记性：P35/P36/P61/P64 四刀搬走约 1000 行，`game_manager.gd` 又长回 3972 ⇒
  **搬代码不搬所有权，等于没搬**。

### 1.5 [B1–B2c] 乱斗模式：同一批棋子上的**第二个会话**

`PROMPT.md` §1 把这个游戏定义成"网格回合制战棋 + 实时自动连续移动战棋"两种模式。§1.4 那条
"状态按会话分片"因此在第二种模式上**再走一遍，形状故意和战斗一样**（规则形状见
`docs/prompt/BRAWL.md`，那是它的子文档）：

- **`scripts/core/brawl/brawl.gd`**（`class_name Brawl`，`scenes/brawl.tscn` 的根）拥有**一局**：
  两侧的棋子、时钟、团灭与超时狂暴、胜负。它**不认识**轮次、金币、对手，也不认识 `Game`。
- **`scripts/core/brawl/brawl_main.gd`**（`class_name BrawlMain`）是**第二个会话业主**，与
  `BattleMain` 并列：开会话 / 摆阵页 / 打一局 / 结算 / 拆场景。`Game` 上多一个 `brawl_main` 与一个
  `brawl` 把手——**两个都故意标 `Node`**，理由与 `battle` 一字不差（避免循环 import）。
- **共用"棋子层"，分家"驱动层"**：HP / 伤害 / 护甲 / 处决 / 状态 / 大招 / 贴图 / 表全部沿用
  `Unit` / `Zombie` / 植物脚本；**各自拥有的只有四样**——时钟、意图、棋盘语义、胜负。
  ⇒ **禁令**：`brawl_actor.gd` **永不调用** `Unit.act()` / `resolve_skill_once()` / `act_ultimate()`。
  那些身体读的是回合制的棋盘（`board.damage_brain` / `board.get_zombies_in_row`），在这个世界里不存在。
  它只调**能力**（`take_damage` / `Zombie.bite_value()` / `Spawn.shooter_damage()`），
  所以"这枚棋子打多疼"仍然只有一个业主。
- **`grid == null` 是合法状态**，含义是"这枚棋子的位置归它的驱动者管"：`Unit._apply_position()`
  在 `grid == null` 时早退（`unit.gd:319`），所以驱动器写 `position` 不会被单位自己抢回去。
  `col / row` 由驱动器**派生**——仍有几条命中规则在读列号（铁门的"从背后打来"，`zombie.gd:426`）。
  **R2：乱斗不注册进 `Grid`**——`Grid` 是回合模式的棋盘（整数格 / 泳道 / 可放置性 / 悬停）。
- **场地几何与画面也共用**：`BrawlField` 的 `arena_rect` / `half_rect` / `cell_rect` / `cell_at`
  与 `draw_ground` / `draw_grid` 全是**静态**的，竞技场与编排页画的是同一批矩形；
  "4 列 | 1 列 | 4 列"这条分隔只写在 `brawl_field.gd` 一处（`BalanceBrawl.HALF_COLS`）。
- **敌阵是数据**：`data/brawl/formations.csv`（名册）+ `formation_pieces.csv`（一行一个**可能**上阵的
  棋子 + `概率` 列），读者是 `FormationDB`。**[B8] 掷骰每轮一次、三处共读**：卡片上的棋子数与强度、
  编排页右半场的预览、竞技场真正建出来的那一侧，读的都是 `BrawlSession.chosen_rows()` 里**同一份**
  `offer["rows"]`——三处各掷一次就是三个不同的敌人。
- **[B5/B7] 乱斗自己的三份数据**（都在 `data/brawl/`，各有读者，见 `docs/prompt/BRAWL.md` §8）：
  `roster.csv`（玩家棋子池，`RosterDB`）/ `gear.csv`（[B7] 强化与装备一张表，`GearDB`）/
  `formations.csv` + `formation_pieces.csv`（敌阵）。**棋子的行仍在分层表里**（`data/units/humans.csv`
  + `units.csv`，读者 `PieceDB`），乱斗独有的列（`attack距离` / `移速` / `attack间隔` / `射弹`）
  落在族表那一层。
- **[B7] 挂件（强化 / 装备）长在棋子上，不长在会话上**：`BrawlSession.pool[i]["attach"]` 是最多
  `ATTACH_SLOTS` 条的数组，`mods_for(index)` 是唯一把它变成数字的门；`BrawlSetup` 的**每一行**带
  自己的 `mods`，`BrawlActor` 按行取。⇒ B5 那份"全队一份"的字典已经不存在。
- **[B8] 射弹是竞技场自己的飞行，但伤害与画面共用业主**：`scripts/core/brawl/brawl_shot.gd`
  （**无 `class_name`，按路径 preload**）从 `data/projectiles.csv` 读轨迹 / 外观 / cue，
  **画图走 `Projectile.draw_shot()`**（与回合制的豌豆 / 西瓜同一个画师），
  **伤害走 `BrawlActor.land_hit()`**（与近战挥击同一个门）。
  ⇒ §1.5 那条"不许有第二份伤害规则"在射弹上照旧成立：射弹只是**延迟**。
- **两个模式的门同名是允许的**：`Brawl` 实现 `spawn_zombie()` / `spawn_unit()`，与 `Battle` 同名，
  因为"造一个棋子"是**同一个事实**（`Spawn.create_unit` 是鸭子名称的，见 §2.1）。`[Arch]` 第 6 条判据
  的**下一步**（尚未做）：把它从 `battle ↔ game_manager` 扩成**两对**，白名单里只放这两个工厂门。
- **为什么不是"两套引擎"**：棋子层对棋盘的依赖实测只有 **6 个方法 / 12 处调用**
  （全仓 `scripts/units/**`，而且四分之三在乱斗里没有对应物）。写第二套引擎 = 拥有第二份伤害、
  护甲、处决与状态规则——那正是第 6 条判据存在的原因。

## 2. 数值归属总表

**一个数值只有一个业主，按"谁读它"归属。** 本表只规定**归属与文件**，
**具体取值一律看业主本身**（文档里不抄数——抄一份就多一个业主）。

| 数值 | 业主 | 读者 |
|---|---|---|
| 全局规则数值（棋盘尺寸、每回合自然阳光、脑子 HP、召唤额度、卡片槽位数、罚金与恢复时长…） | `scripts/balance/balance.gd`（`Balance`） | 规则层 |
| 纯呈现数值（像素尺寸、字号、绘制颜色、动画时长） | `scripts/balance/balance_ui.gd`（`BalanceUI`） | 只有绘制 / 布局代码 |
| 音频（曲目表、cue 表、音量阶梯、淡入淡出） | `scripts/balance/balance_audio.gd`（`BalanceAudio`） | 两个播放器 + 设置页 |
| 单位数值（HP / **attack** / 费用 / 技能价 / 成长 / 护甲 / 移动 / 啃食 / 技能效果 / 贴图路径） | `data/units/*.csv` | `PlantDB` / `ZombieDB` / `SkillDB` |
| **某一层的默认行**（`name=default`：`units.csv` 按 race 一行，族表/子族表各至多一行） | 该层自己的表 | `UnitSheet` 的默认链 |
| **首通宝箱的两份事实**：`cleared`（通关了）与 `claimed`（领过了） | `user://settings.cfg` 的 `[progress]` 段 | `SettingsStore` / 关卡列表页 / `Rewards.claim_first_clear` |
| 道具价格（`price`：卖价 / 耐久 / 经验）与图标路径 | `data/items.csv` | `ItemDB`（**表优先**，`Balance.item_*` 先问它，`ITEM_DEFS` 只是兜底） |
| **掉落表**（每个僵尸被击败后可能掉什么 / 概率 / 数量 / 是否专属） | `data/drops.csv` | `DropDB` |
| 关卡数值（起始阳光、脑子 HP、僵尸基准 HP、出场列、启用行、波次、卡冷却、工具阈值、奖励、耐久消耗） | `data/level/*.json` | `LevelData` |
| **乱斗自己的规则数值**（tick 频率、一回合值几秒、棋子半径 / 分离力、移速与射程的兜底、狂暴曲线、上阵上限、替身夹具） | `scripts/balance/balance_brawl.gd`（`BalanceBrawl`，**第 8 张数值表**，[Arch] 的 `TABLES` 里） | `scripts/core/brawl/**`，别处一律不读 |
| **敌阵**（名册：`name` / `name_zh` / `金币`；阵容：一行一个上阵棋子 `formation` / `piece` / `col` / `row`） | `data/brawl/formations.csv` + `data/brawl/formation_pieces.csv` | `FormationDB`；**强度不是手写的**——它是棋子 HP 之和，从单位表算出来 |
| **乱斗的两条设置** | `user://settings.cfg`：`[battle] show_enemy_pieces`（编排页是否显示敌方**具体单位**）、`[ui] shell`（主菜单在哪一层） | `SettingsStore` / 设置页 / 编排页 / 主菜单 |
| 存档 | `user://` 四份：`garden.json` / `profile.json` / `run.json` / `settings.cfg` | 各自的账本；**结构、段名与键见 §8** |

- `balance.gd` 里的**单位常量只是读不到表时的兜底**，不得反向引用 `BalanceUI` / `BalanceAudio`（避免循环依赖）。
- **禁止把"某局、某株"的数值散进调用点的字面量**：一个数没人读就删掉，不要"先留着"。
- 两种**不要拆**的情形（历史结论）：① 一个字典的两列分属不同读者（劈开等于把一张表撕成两半）；
  ② 一对**必须同长**的孪生数组（分家之后"两张悄悄错开"就再也数不清）。
- `data/drops.csv` 读不到时回 `Balance` 的三条概率兜底（`DropDB._use_fallback()`），玩家看不出差别。

### 2.1 [P87] 三个工厂（`scripts/core/spawn.gd`）

**一切"产生"都走工厂**：产物是物品、射弹还是单位，都从这三个入口出去。它们只拥有**产生什么、落到哪里**，
不拥有文案（调用方自己打印与飘字）、不拥有规则（"能不能召唤"留在 `Game.try_place_at`）、不拥有数值（数值在表里）。

| 工厂 | 默认 | 边界 |
|---|---|---|
| `create_items(game, item := "coin_silver", count := 1, where := AUTO, source := "player", at, amount := 0)` | 一枚银币、从玩家、落进**当前活着的那个账本**（战斗中是背包，其余是仓库） | `source` 是**封闭清单**（`SOURCES`），不认识的记 problem；返回 `landed`（**实际落地**，上限/未知物品会吞掉一部分）；`Profile.add_item` 拒收时它**量得出来**。**[P89] `WHERE_FIELD` 是第五个落点**：payload 变成躺在草坪上的一颗阳光（只有 `sun` 能这样落地，`amount` 由产出者给），**它不填池**——拾取是另一个事件（`SunField.collect`） |
| `create_projectile(shooter, target, damage := -1, opts, cls := null)` | 直射豌豆、伤害取射手自己的技能值 | 它**只是 `Projectile.fire` 的外壳**，绝不开第三条路径（staged / 同步那两条已在 `projectile.gd` 里）。子类**不许**自己声明 `Spawn`（`const` 是继承的，子类重复声明会 parse error —— 见 `ShooterPlant.launch_shot()`） |
| `create_unit(game, type := "", at, opts)` | 名称 id 进、棋盘上一个节点出 | **只管造对象，不管能不能召唤**；表里有、但没有脚本的植物 → **拒绝并报账**（不再退回豌豆射手）；`spirit_*` 走 `PlantScripts.is_registered` 的基名规则 |

自检前缀 **`[Spawn]`**：逐条**故意触发**每一种拒绝（未知 source / count ≤ 0 / 未知物品 / 未知落点 / 未知名称 / 没脚本的植物），
每条必须恰好记下一条 problem —— 没人踩过的守卫等于没有守卫。

### 2.2 [P90] 状态表（`data/statuses.csv` + `scripts/core/db/status_db.gd`）

**状态 = 最小的那种机制**，所以它是"机制数据化"这条路线第一个走完的样例：一张表、三个封闭词汇表、一组原语。

- **表拥有**：id（`name`）、中英名、**行动条/日志上的短语**（`显示` / `显示英文`，带 `%d`）、`名称`（`倒计时`/`瞬时`）、
  `持续`（默认回合，留空 = 施加者给）、`叠加`（`取大`/`累加`/`替换`）、`免疫旗标`（单位用哪个 `特殊机制` 旗标免它）、
  `影响`（封闭清单）、`数值`（默认强度）。
- **代码拥有**：① `影响` 的**原语实现**（今天 `禁行动` / `位移`，清单外的值记问题并变红）；② 状态给单位上的**颜色**
  （像素值 ⇒ `BalanceUI`，老规矩）；③ **单位自己的阶段**（巨人举锤前摇、舞者召唤倒计时、撑杆跳次数）——它们不是
  "被施加的"，数值也已经在 `zombies.csv`，进状态表就是第二个业主。
- **读者**：`Zombie.apply_hit_effects`（免疫 / 叠加 / 瞬时 vs 倒计时）、`tick_effects`、`effect_text()`（短语走表、跟着语言走）、
  `blocked_status()`（行动闸门问"哪个绑定状态禁行动"，不再点名 `freeze`）。
- **加一个状态 = 表里一行 + 一个已实现的原语**；只有要新原语时才动代码。
- 自检前缀 **`[Status]`**：封闭词汇表逐条判（错字 ⇒ FAIL 并指名）、代码点名的 id 必须在表里、中英短语 `%` 个数一致。

### 2.3 [P91] 射弹表（`data/projectiles.csv` + `scripts/core/db/projectile_db.gd`）

**射弹 = 一个"已经打出去的东西"**：它的飞行形状与属性是表，飞它、撞它、画它的是**通用基类 `Projectile`**。
植物只管"**怎么打**"（几发、哪几行、多远，`plants.csv`），射弹管"**打出去的是什么**"。

| 列 | 含义 | 代码侧 |
|---|---|---|
| `轨迹` | **封闭清单**：`直线` / `追踪`（每步重瞄目标，能跟到隔壁行）/ `抛射`（抛物线，越过挡路的一切，只落在瞄准的那个身上） | 基类的 `_process` 各一条分支 |
| `速度` | 留 `—` = 按轨迹取默认（`BalanceUI.PEA_SPEED` / `PULT_SPEED`）；**像素值原则上不进表**。⚠ **[B8] 两个例外**：乱斗的 `arrow` / `musket` 写了像素值（620 / 950），因为它要两发**快慢不同**的射弹，而竞技场的坐标是**格**（`BrawlShot.speed_cells()` 用 `Balance.CELL_SIZE` 换算） | — |
| `穿透` / `穿透伤害` | 能穿过几个身体 / 穿过时它们是否**也挨这一下**（默认否 —— 风暴靠"穿过不打"才不抢近身那个的伤害，P33） | `_stops_for` / `_strike` |
| `反弹` | 撞到草坪边缘反向几次（0 = 出界即销毁）；穿过的身体记在 `_passed` 里，**反弹不会把同一个身体打成无限伤害** | `_process` |
| `穿甲` / `溅射` | 两个经典的伤害 rider | `_hit_opts` / `_clip_splash` |
| `命中状态` / `状态值` | 命中的状态（引用**状态表**的 id）与默认回合数；施加者可覆盖（寒冰射手大招冻 3、普攻冻 1） | `apply_hit_effects` |
| `音效` / `落点音效` | `BalanceAudio.SFX_DEFS` 的 cue（写错开机就红） | `SFX.play` |
| `外观` | **封闭清单**：`pea` / `melon` / `arrow` / `musket`（[B8] 后两个是乱斗的箭与铅弹）；新图 = `Projectile.draw_shot()` 加一条分支，新射弹复用现成外观 = 只加一行表 | `draw_shot()` |

- **不进表的**：`伤害`（属植物技能值）、`straight_shot`（由 `轨迹` **派生**：只有直线才被铁门挡，P77 那条"两个 flag 必须同行"的规矩靠派生实现）、植物的齐射形状。
- **子类**：`PeaProjectile` / `PultProjectile` 现在是**空壳**（只留 `class_name` 与说明）——抛物线的三条差异全被 `轨迹 = 抛射` 吸收了。要一个**表表达不了**的射弹，才继承基类写行为。
- 自检前缀 **`[Shot]`**：`轨迹` / `外观` 逐条判封闭清单、`命中状态` 必须是状态表里真有的 id、默认行 `pea` 必须在。

### 2.4 [P89] 草坪上的阳光（`scripts/core/battle/sun_field.gd` + `sun_drop.gd`）

**收入看得见**：自然阳光与植物产出都不再直接进池，而是**落在草坪上等玩家收**（`PROMPT.md` §3）。

- **`sun_drop.gd`** 是那一颗太阳本身：两个**样式**（`落地` 从植株旁跳出 / `天际` 从草坪上方缓缓落下）、
  自己画自己（有素材用 `items/sun`，没有就画个圆盘）、**用半径命中回答"这一点是不是我"**
  （全工程没有 `Area2D`；手写命中还能无头验证）。它在 grid 之下、**不进任何格子登记**：不是单位，不能被啃、也不挡种植。
- **`sun_field.gd`** 是行为：`spawn` / `collect_at` / `tick` / `clear`。**状态留在 `Game`**
  （`_sun_drops` 列表 + `sun_collected_manual/auto` 两个计数器），这是 §1.4 的"搬代码、留状态"——
  它是被 `[Arch]` 抓出来的：这一批刚落地时 `game_manager.gd` 到了 **4012 行**，上限 4000，于是把行为搬走而不是把上限抬高。
- **点击优先于草坪**：`Game._unhandled_input` 里先做太阳命中（autoload 在主场景之前，所以它先拿到事件），
  命中就吞掉这个点击，`Grid.cell_clicked` 不会再把选中的卡片种在那颗太阳底下。
- **回合时钟**：`_begin_round()` 里 tick 一次 ⇒ 落地满 `SettingsStore.sun_auto_rounds` 回合自动入池，
  **F 快进与慢慢看走同一条路径**（这是 P86 那条"看与快进必须同结果"的延续）。
- **两个设置**（`user://settings.cfg` 的 `[battle]` 段，设置页两个按钮）：`自动拾取阳光：开/关`、`落地 N 回合后自动拾取`。
  默认**开、2 回合**——没被捡的阳光就是没拿到的收入，而这个开关存在的意义正是被关掉。
- **上限与退出**：同时最多 `Balance.SUN_DROP_MAX` 个，超了**把最老的入池**（不丢）；离开战斗 / 重开 / 结算时
  **没捡的阳光一律不结算**（原版规则）。
- 非判决前缀 **`[Sun]`**：每一颗落地都会打一行（样式、数量、来源、场上还剩几颗）。
- **飞行本身**：启动自检与战斗探针跑的是**同步**结算（打完即结算），所以"飞"这件事由 `[SelfCheck] shots` 那一节**手动步进**（`_launch` / `_step_until_gone`）——它也是这条 staged 飞行路径唯一的覆盖。

## 3. 呈现层（这个项目长什么样）

### 3.1 世界是 `_draw()` 画出来的

不是 Control + theme。`Unit`、`Grid`、`hud`、每个前端页、`ItemTile`、每个 `Projectile` 都自己实现 `_draw()`；
只有**可点的控件**才是真 `Button`，由**唯一的按钮工厂** `UiStyle.make_button(host, text, callable, font_size,
focus, styles, dim_when_disabled)` 造出来，每页只留一个一行委托的 `_make_button`。
战斗中按钮 `FOCUS_NONE`（键盘归热键层），前端 `FOCUS_ALL`。

### 3.2 几何全部来自 `Layout`（纯函数 + 静态变量）

`Layout.compute_for(logical_size) -> 带名称的 Geometry` 是**纯函数**（不碰节点），
`Layout.refresh()` 把结果复制进一组静态变量供消费者读，`Layout._audit()` 用
`EPSILON=0.5` 的容差断言一批不变式（草地不出界、卡片不撞 END TURN、角按钮留在顶栏内…）。
纯函数 + 可审计 ⇒ 启动时能对 5:4 / 4:3 / 16:10 / 16:9 / 2:1 / 21:9 **六个采样比例**逐一验几何，
而不需要真开窗口。同理，页面内部的格子排布也走纯函数（`metrics_for` / `fit_for`）。
消费者只读静态变量（`Layout.size` / `Layout.cell` / `Layout.top_h` / `Layout.bottom_y` / …），
**不要**在别处写死像素。

### 3.3 一页一场景：开着即建、离开即释放（菜单常驻）

**[P107] 前端页是场景，不是常驻节点。** `ScreenFlow.open_*(game)` 实例化对应页面、挂到
`GardenLayer(layer=20)`、调它的 `open_view()`；`hide_views()` 反过来 **`remove_child` +
`queue_free`** 并清空把手。所以**“哪一页在台上”与“哪一页存在”成了同一个问题**：
页内状态一律来自它打开时读的存档（`garden.json` / `profile.json` / 数据表；唯一例外是图鉴页签，
记在 `settings.cfg` 的 `[ui] almanac_tab`）。

**唯一的常驻页是菜单**：它是所有前端页的入口，boot 之后就在 `MenuLayer` 上，`open(page)` 只重建页体。
`Game` 是 `screen` 状态的**唯一所有者**；UI 只调 `Game.show_*()`。
不变式：**每次换页都必须先 `leave_game()`**（结算花园 → 拆战斗 → 藏世界 → 释放页面）；
唯一例外是"设置作为浮层"，它藏而不拆（棋盘是活的会话）。

**[P107d] 外壳也是场景**：`scenes/main.tscn` 声明 `MenuLayer` / `Menu` / `GardenLayer`，`Game._bootstrap()`
**认领**它们（名字漂了就 `push_error` 并停下）。它仍然等 `current_scene`，但含义变了：
**等它要去找的那棵树**，不是等它要建的那棵树。

**[P106] 战斗是一个“可装载的子树”**：`Battle`（`scenes/battle.tscn`，根脚本 `battle.gd`）在开局时 `instantiate()` +
`add_child()` 到宿主场景，结束时 `queue_free()`——**不是 `change_scene`**（前端要活在棋盘之外，
设置浮层要能盖在活棋盘上）。三态：不在战斗（节点不存在）／战斗中（在树上、可见）／
设置盖住活棋盘（**在树上、藏起来、不释放**）。按 R 重开是“先拆再建”，绝不复用同一个节点——
“按 R 花园回滚”依赖这局的账本从未落地。

### 3.4 运行时场景树（外壳是场景，页面按需装载）

**外壳**（`scenes/main.tscn`）声明常驻的那几样：两个 `CanvasLayer` 和菜单。**页面**是一个个场景，
由 `ScreenFlow` 实例化进 `GardenLayer`、离开即释放；**战斗**（`scenes/battle.tscn`）同理，由
`_start_new_game()` 装、`_teardown_game()` 卸。**节点名照抄**——自检、日志、`--preview` 都按名字点名：

```
root (Window)
├─ Boot        (Node, autoload)              # scripts/core/boot.gd：只印启动横幅 + 核对引擎版本 4.7.x
├─ Game        (Node, autoload)              # scripts/core/game_manager.gd：全部状态的本体（§1.4）
└─ Shell       (Node2D, scenes/main.tscn = get_tree().current_scene，下面统称"宿主场景")
   ├─ MusicPlayer0 / MusicPlayer1   (AudioStreamPlayer)   # Music.setup(宿主)：两轨做交叉淡入（代码创建）
   ├─ SfxPlayer0 … SfxPlayer7       (AudioStreamPlayer)   # SFX.setup(宿主)：固定池（BalanceAudio.SFX_POOL）
   ├─ MenuLayer     (CanvasLayer, layer=20)              # ★ 场景声明
   │  └─ Menu       (Control, scenes/ui/menu.tscn 的实例)  # ★ 常驻页：主菜单 / 关卡列表 / 设置
   │     └─ Prop0 … Prop3 (MenuProp)                     # 地上那四件可点道具（场景声明）
   ├─ GardenLayer   (CanvasLayer, layer=20)              # ★ 场景声明；**一次只有一个孩子**
   │  └─ <当前页>   以下场景之一，打开即建、离开即释放：
   │       garden / warehouse / shop / backpack / almanac / squad / roadmap / reward / choice / deck
   │       + [B2b/B2c] brawl_formation（摆阵 + 选敌阵）/ brawl_round（一局的结果）
   ├─ Battle        (Node2D, scenes/battle.tscn)          # ★ [P106] 一局的根：**只在战斗中存在**
      ├─ LawnGrid    (Node2D, scripts/core/grid.gd)      # 战斗世界本体，所有格子坐标以它为原点
      │  ├─ LawnBackdrop (Node2D)                        # 必须是【第一个孩子】：静态草坪画，永远在单位背后
      │  ├─ FxLayer      (Node2D, z_index=100)           # Fx.attach(grid)：特效唯一挂靠点，靠 z_index 浮在最上
      │  ├─ 单位 ×N      (Unit / Zombie 子类, Node2D)     # 名字 = "<显示名去掉->_<col>_<row>"，如 Peashooter_3_2
      │  └─ 射弹 ×N      (Projectile 子类, Node2D)       # 同为 grid 的孩子（沿 lane 飞，坐标与单位同源）
      └─ HudLayer    (CanvasLayer, layer=10)
         └─ Hud      (Control)                           # 战斗 HUD：阳光/回合/卡轨/工具条/END TURN/结果面板
   └─ Brawl         (Node2D, scenes/brawl.tscn)          # ★ [B1] 乱斗一局的根：**只在打的时候存在**
      └─ BrawlField (Node2D, scripts/core/brawl/brawl_field.gd)
                                                         # 世界：棋子挂这里；两个半场与网格画在这里
```

- **[P106/P107] 节点名是契约**：`Battle` / `LawnGrid` / `HudLayer` / `Hud`（战斗）、
  `Shell` / `MenuLayer` / `Menu` / `GardenLayer`（外壳）与 `Brawl` / `BrawlField`（乱斗，[B1]）
  都被日志、自检与 `--preview` 按名点名；`@onready` 路径就是它们，改名等于当场断线。
  外壳那条由 `[FrontEnd]` 收据逐项核对（名字、父子关系、层号）。
- **[B2b/B2c] 乱斗的页面走同一套装载器**（`Screen.BRAWL_FORMATION` / `BRAWL_ROUND`），
  `Brawl`（一局）不是页面：它由 `BrawlMain` 挂到 `current_scene` 上，与 `Battle` 同一种活法。
- **层号是契约**：世界在默认层 0、HUD 在 10、前端页在 20。`MenuLayer` 与 `GardenLayer` **同为 20**，
  所以谁盖住谁由**可见性**决定、不由层序决定（这就是 §3.3 的切页方式）。
- **两处顺序/挂靠点是"画错了不报错"的坑**：`LawnBackdrop` 必须是 grid 的第一个孩子；
  特效必须挂 `FxLayer` 而不是直接挂 grid——两条都是为了"永远在单位之下 / 之上"，
  写反了界面会静默错层。`FxLayer` 的 `z_index` 只有一个来源：`BalanceUI.FX_Z_INDEX`。
- **`_bootstrap()` 的顺序**（有意义，照抄）：等 `current_scene` 就位 → `Layout.refresh()` → UI 字体 →
  `Music.setup` / `SFX.setup` + 应用存档里的音量 → **全部数据/规则自检** →
  **[P107d] 认领外壳**（`MenuLayer` / `Menu` / `GardenLayer`，缺一个就报错停下）→ `_boot_done = true` →
  `show_main_menu()` → **最后**才是 `ScreenFlow.self_check()` 与 `--battle=` 覆写。
  ⚠ 那句“等 `current_scene`”**不能删**：autoload 的 `_ready` 早于主场景实例化，它等的是**要去找的树**。
- **`_boot_done` 同时是输入闸门**：`_unhandled_input()` 在它之前直接返回 ⇒
  自检跑到一半时键盘打不进一个还没建好的世界；`--preview` 的旁路也靠它（下一条）。
- **F6 / `--preview` 的旁路**：`_bootstrap()` 开头判断"当前场景是不是某个 `*_view.tscn`"，
  是就**只让那块零件自己活着**，在音频与自检之前就 return，且**不置 `_boot_done`**。
  ⚠ [P107d] 这个旁路**必须先于认领外壳**：F6 时主场景根本不是 `scenes/main.tscn`，外壳不存在。

### 3.4 单位姿态：具名特效（`[P110]`）

**"一个单位在什么时候摆什么姿态"是一件有业主的事**，四个业主各管一段：
**表**在 `scripts/core/unit_fx.gd`（`Unit.play_fx(id)` 是唯一的门，返回"收下了没有"），
**规则**在 `docs/prompt/FX.md`（代码落点与调用点清单在 `docs/dev/FX.md`），**数值**在 `BalanceUI`（`FX_*`，`unit_fx.gd` 里不许有字面量），
**通道**由 `Unit` 自己拥有：红闪（`_flash`）、倾斜（`_lean`）、位移（`_shake_offset`）、
空闲游走（`_idle_offset`）。优先级是 `死亡 > 受击 > attack > 空闲`，**同级重启**。

两条不变式，动这些通道时必须一起守：

- **倾斜只转身体**。它由 `_draw_body()` 设置、在同一函数末尾复位，所以名字 / 血条 / 行动条
  （画在它之后）永远不跟着歪；视图场景那条路走 `BodyPivot`——**旋转中心必须是单位中心**，
  而视图场景自己的原点是**脚底**（`UnitArt.fit_view`，见 §4），让它自己转会与贴图歪得不一样。
- **姿态一律"弹进去、缓回来"**，与 `Unit.shake()` 一直以来的形状相同。

⚠ 别把这件事和 `scripts/fx/fx.gd` 混了：`FxLayer` 是**棋盘上一次性的画面**（火花 / 爆环 / 飘字）
的业主，它的寿命是一次动画；单位姿态的寿命是**一个身体**——它要活过那次动画、要随身体一起倒下、
还要在身体自己会演这件事时让位。两者因此是两个业主，**不要合并**。

## 4. 单位贴图与三级兜底

- 单位图是**位图**：本版用 `svg` 经引擎自带的导入器栅格化，运行时用 `_draw()` 画出来。
- **路径的唯一来源是表的 `svg` / `tscn` 两列**：格子写**相对路径且不写后缀**（例 `peashooter`），
  代码把它拼成实际文件路径（根目录与分族由你定）；格子里写完整 `res://…` 或带后缀也认。
  战斗棋盘、卡面图标、花盆里的植株、图鉴格子、药水瓶上的植物标记**全走这一条** ⇒ 加一张贴图 = 改一个格子。
- **三级兜底**：① `tscn` 视图骨骼场景（实例化为子节点、`show_behind_parent`、按 128 画布/112 脚线
  缩放落进 60px 框、找 `AnimationPlayer` 播 `idle`，没有就试 autoplay，都没有也合法）→
  ② `svg` 贴图（画进同一个 60×60 框，植物有"呼吸"待机）→
  ③ **色块占位**（`Unit._draw_body()`：`Shape.CIRCLE` 或 `RECT`，用每个单位的 `body_color`）。
- **缺图永不崩**：查得到路径但文件还没画 ⇒ **只计数不判失败**（`[Art] N sprite path(s) … not imported yet`），
  只有**代码点名的**路径（花盆、道具图标、菜单图标）缺失才 FAIL；`[Art]` 每行会写清单元指向哪个文件。
  受击闪白 = 贴图 modulate 往 `COLOR_FLASH` 插值。
- **复合图标是运行时合成**的，两种物品都走同一套：**天赋药剂** = 通用瓶（按rarity 6 档）+ 植物标记画进
  `POTION_MARK_AREA`；**[P92] 召唤卷轴** = 共用的卷轴图 + 它解锁的那株植物画进 `SCROLL_MARK_AREA`。
  合成点只有 `UnitArt.draw_item_icon()` 一个，标记落点由图鉴/物品的**分类**决定（`BalanceUI.mark_geometry(kind)`），
  所以同一件东西在 HUD/仓库/商店/背包/图鉴/花园里长得一模一样；[P88] 底图与标记的路径都**以表为准**
  （`Balance.item_art` / `item_mark_art` 先问 `data/items.csv`，代码表只是兜底）。
- SVG 风格硬约束：**128×128 画布、纯色 `fill`、不描边、不用渐变/滤镜/文字**
  （引擎的矢量导入器只吃基本形状，高级特性**静默失败**；细节见 `PROMPT.md` §7.1）。
  命名 = 表的英文 id、按族分文件夹；**叠加件（头盔、叶片一类"融合素材"）永远不许进 `svg` 列**——
  那一列只放"这个单位完整的样子"。

## 5. 自检框架（本项目的验收方式，不可省）

### 5.1 两阶段启动

1. `Boot` autoload：打印 `=== PvZ turn-based boot OK ===`、Godot 版本、工程名、主场景、工程路径、
   版本不符的提示，然后 `=== boot check finished ===`。
2. `Game._ready()`：读设置 → 应用 `--lang=` → 装字体 → `load_from_disk()` 六个数据表并各打一行
   `[Data] <name>: <status_text>` → `Garden/Profile.load_or_create()` → 章节图 → `RunState` →
   建 `RunFlow` → 应用窗口策略与显示设置 → `call_deferred(_bootstrap)`。

### 5.2 `_bootstrap()` 的自检调用顺序（照抄）

`Loc` → `SelfChecks.self_check(Game)`（P85 起它只是**调度壳**：`class_name SelfChecks` 保留、
四条 boot 判据转发给 `scripts/checks/boot_checks.gd`）→ `Layout` → `LevelList` → `PlantDB` → `ZombieDB` →
`ItemDB` → `DropDB` → `SkillDB` → `EventDB` → `ArchCheck` → `DocCheck` → `UnitArt` → `Music` → `SFX` → `UiStyle` → `Fx` → `ItemGrid` →
`Menu` → `GardenView` → `AlmanacView` → `Garden` → `Profile` → `ChapterMap` → `RunState` →
`Difficulty` → `SettingsStore` → `SelfChecks.persist` → `SelfChecks.recover` → `SelfChecks.item_rows` →
`Rewards.self_check`；**然后**才建网格/层/页面，最后（依赖节点已存在）`ScreenFlow.self_check` 与
`_apply_battle_override()`。

日志前缀清单（每个都有自己的 `self-check PASSED/FAILED`）——**boot 与战斗是两批，别混着数**：

**启动自检（boot 那条命令能看到的，31 条 + `[Levels]` 那条特殊形状 = 32）**：
`[Loc] [Layout] [Plants] [Zombies] [Items] [Drops] [Arch] [Docs] [Skills] [Events] [Art] [Music] [Sfx]
[UiStyle] [Fx] [ItemUI] [Menu] [GardenUI] [Almanac] [Garden] [Profile] [Chapter] [Run] [Diff] [Settings]
[Save] [Recover] [ItemRow] [Reward] [FrontEnd] [Spawn] [Status] [Shot]`，外加 `[Grid]`；
`[Levels]` 的判决行形状是 `9 level(s), 0 skipped, 0 data warning(s) | PASSED`（**不带 `self-check` 字样**）。

**战斗探针（只有 `-- --battle=<关卡>` 才跑，16 段各一条 = 16）**：全部打在 **`[SelfCheck]`** 这一个前缀下。
⚠ **`[SelfCheck]` 不是 boot 模块**——boot 里没有任何一行叫 `[SelfCheck]`；
而 `SelfChecks.self_check()` 虽然名字像，打印的是 **`[Loc]`**（名字接线检查，P20）。
这两个名字撞在一起过一次，数读数时按"boot 32 / 战斗 48"记，别按前缀名猜。
非判决性前缀：`[Data] [Font] [Battle] [SafeIO] [Grid] [Sun] [WARN]`。

`[Arch]` 是**架构棘轮**（P84/P85）：最大文件行数 / 超过 1000 行的文件个数 / 全仓 GDScript 总行数 /
三张数值表之间无同名常量 / **每个用到别处 `preload` 常量的文件都自己声明了它**。
前三条的上限是"实测值 + 余量"，只许随重构**调低**；第 5 条是 P83 与 P85 两次事故的产物
（GDScript 的 `const` 只在一个脚本的作用域里，见 `docs/PITFALLS.md` 第 68 条）。
**没有"全局 all passed"这一行**——通过标准是"每个 `self-check PASSED`、没有一个 `FAILED`"。

### 5.3 house 输出格式与探针纪律

- 一条判据 = **一物理行**：`print("[<Prefix>] <claim> = <value> | " + ("OK" if ok else "FAIL"))`；
  模块收尾 `print("[<Prefix>] self-check %s" % ("PASSED" if ok else "FAILED"))`。
- 判据**取证时不许崩**：探针死在半路就丢掉判决行（所以判据里要「先 `has` 再读」，不要让取证动作本身崩掉）。
  ⇒ 绿不等于对：**每条新判据都要被反向验证一次**（故意把数据改坏一格，确认它红、且不给 SCRIPT ERROR，然后改回来）。
- **一个日志前缀 = 一个模块**，不许撞名。
- 战斗探针（`run_battle_probes`）顺序是契约：
  `_targeting → _stack → _tools → _zombies → _rewards → _ults → _one_shots → _pults → _shots → _ring →
   _scaredy → _spikes → _cards → _spirit → _refusals → _levels → _language`，收尾 `_close_transaction`。
  （`_shots` 是 [P91] 加的：它**手动步进飞行**，因为其余探针都跑在同步结算下，那是 staged 飞行路径唯一的覆盖。）
  它们走**真路径**（`spawn_unit` / `_remove_unit` / `try_place_at` / `_use_tool_at`），
  在 `grid.refused_row()`（战斗区域之外）上跑，`_drops_enabled=false`，
  并且**前后快照/还原 `profile` 与 `garden` 的 JSON 文本**（GDScript 的 error 是返回不是抛出，
  探针中途出错不能渗进玩家存档）。`--battle=` 会记住并放回 `SettingsStore.last_level`。
- ⚠ **[P106 起的现状 + 2026-10-04 的口径] 这一节描述的是"已经存在的那套东西"，不是待办清单**：
  ① 战斗探针的调用点随 `_start_new_game` 的尾部一起被 `set_up_battle()` 取代，
  `SelfChecks.run_battle_probes()` **现在没有调用者**（去留待用户拍板，见 `docs/STATE.md` §3）；
  ② **用户 2026-10-04 明令：AI 不许再编写测试脚本——连临时探针也不行**（`AGENTS.md` §2）。
  ⇒ 遇到"判据数掉了 / 有模块没说话"这类问题时，**先问用户**，不要靠新写一条判据去把它补回来。

### 5.4 验收命令的形状

- 自检必须**无头可跑、自行退出**：一条命令跑完启动自检；需要节点已存在的那批探针
  由命令行参数进入（不能拿"开个窗口看看"当验收）。
- 输出重定向到一个文本文件，再用 `grep` 数 `PASSED` / `FAILED`。
- **通过标准只有一个：`FAILED` 一个都没有**——不是某个固定读数。
  判据行数会随内容增长；把每批的读数登记下来，读数变了就要说清是谁改的。
- 具体的命令形状、每批的验收节奏与交付清单见 **`docs/DEV.md`**。


---

## 6. 音频层（原 README「背景音乐」）

> 音频的**数值**（曲目表 / cue 表 / 音量阶梯 / 淡入淡出）业主是 `scripts/balance/balance_audio.gd`；
> 这里讲的是**机制**：谁点名哪首曲子、怎么淡入淡出、怎么排错。


音乐不是写死的播放列表，而是「**一张表** + **每个画面自己点名**」：

| 画面 | 点名的 id | 文件 |
|---|---|---|
| 主菜单 / 设置 / 仓库 / 商店 | `MainMenu` | `assets/audio/MainMenu.wav` |
| 关卡列表（冒险模式） | `SelectCard` | `assets/audio/SelectCard.wav` |
| 花园 | `Garden` | `assets/audio/Garden.wav` |
| 战斗 | 关卡 JSON 的 `music`（默认 `Day`） | `assets/audio/Day.wav` |
| 战斗·**最后一波** | 上面那条的 `_drum` 变调（存在才换） | `assets/audio/Day_drum.wav` |
| 胜利结算 | `winmusic`（**只放一遍**） | `assets/audio/winmusic.wav` |
| 战败结算 | `LoseMusic`（**只放一遍**） | `assets/audio/LoseMusic.wav` |

- 素材放在 **`assets/audio/`**：清单与中文说明见 **`assets/audio/readme.md`** 的 `[背景音乐]` 段
  （27 首曲子；`winmusic.wav` 也在那一段里，`LoseMusic.wav` 被写在 `[音效]` 段、实际是战败曲）。
  **音频是外部资产、不打包进 git**（见 `README.md`「外部资产」）：clone 后需按此清单自备 `.wav`，
  下表这些文件名是映射用的 id→文件名对应关系，不是仓库里现成可点的链接。
  代码里唯一的映射表是 `scripts/balance/balance_audio.gd` 的 **`MUSIC_DEFS`**（`id → 文件名 + 是否循环`，共 **29 条**），
  播放逻辑全在 `scripts/core/music.gd`（静态类，不是 autoload）。
- **每个关卡可以点自己的曲子**：关卡 JSON 加一行 `"music": "Night"`，值必须是 `MUSIC_DEFS` 的 id
  （`Night` / `NightSnow` / `Pool` / `Fog` / `Roof` / `RoofPool` / `Snow` / `Boss` / `Boss2` / `HorseBoss` /
  `Snow_boss` / `Dancer` / `IZ` / `loon` / `UltimateBattle` …）。写错**只会**打印一条 warning 并回落到默认的 `Day`。
- **最后一波换战鼓**（`BalanceAudio.MUSIC_DRUMS_ON_FINAL_WAVE`，默认开）：只对**多于一波**的关卡生效，
  否则单波关卡会从头到尾都在打鼓。
- **开关与音量在设置页**：`音乐：开 / 关` 一键静音，`音量：70%` 每点一下走
  100 → 80 → 60 → 40 → 20 → 100（想静音用开关，不用把音量拧到 0）。
  两者都存在 `user://settings.cfg` 的 `[audio]` 段，**重置游戏不会动它们**。
  **战斗中按右上角 `设置` 也能改**：那时音乐继续放（棋盘还在后面跑），不会切成菜单曲。
- **循环**：优先让引擎自己循环（代码把音频流设成 `LOOP_FORWARD`，循环点覆盖整首）；
  万一某个导入设置或编码让循环点失效，`finished` 会兜底把这首曲子再接一遍，
  控制台会打一行 `[Music] … does not loop natively (…)` —— 看到这行说明**是兜底在循环**（有极小接缝），不是 bug。
- **素材没导入也不会崩**：找不到文件只打印一次 `[Music] cannot load …`，游戏照常跑（和贴图同一条规则）。
- 启动时的 **`[Music]` 自检**：29 条曲目的文件是否都在，外加游戏自己会用到的那 6 首的**时长与循环点**，
  最后一行 `[Music] self-check PASSED`。


---

## 7. 语言层（原 README「语言与中文」）

> 规则只有两条：**玩家可见文案一律走语言层**；**日志与自检输出永远是英文**。
> 这里讲的是机制与排错。


**游戏默认中文**：单位、道具、工具、天赋、rarity、难度、关卡名，以及主菜单 / 关卡列表 / HUD / 花园 / 仓库 / 商店 / 战斗提示**全部**跟随语言。切换到英文时同一套界面变英文，不需要重启。

| 项 | 说明 |
|---|---|
| **切换入口** | `SETTINGS` 页的语言按钮，按钮上写的就是**当前语言**（`语言：中文` / `LANGUAGE: English`），点一下即切换 |
| **生效时机** | 立刻。**战斗中也能切**：棋盘上单位名字、HUD 按钮、面板文字都会当场重画，**不需要重开这一局** |
| **保存位置** | `user://settings.cfg` 的 `[display] language`，下次启动自动恢复（和窗口设置一样，刻意不写 `project.godot`） |
| **默认值** | `zh`。设置文件缺失、被改坏、或写了不认识的语言代码，都回落到中文 |
| **临时覆盖（调试）** | `godot --path . -- --lang=en` 只对这一次运行生效，**不写回存档**，方便中英对照截图 |

### 字体

中文需要**中文字体**（Godot 内置字体没有汉字）。字体是**外部资产、不打包进 git 仓库**
（见 `README.md` 的「外部资产」段）：本机示例为 `assets/fonts/hanyi-summer-w.ttf`
（原中文名已改为 ASCII 名），**clone 后需自备**一个 CJK `.ttf`/`.otf` 放进该目录。
放好后启动会打印：

```
[Font] using res://assets/fonts/hanyi-summer-w.ttf   CJK glyphs: true
[Loc] --- language: zh (中文) ---
```

- 想换字体：把新的 `.ttf` / `.otf`（思源黑体、Noto Sans SC 等）放进 **`assets/fonts/`**，
  让编辑器导入一次即可（目录里取**字母序第一个**可用字体；换掉旧的记得删掉旧文件）。
  该目录的字体文件与 `*.import` 均被 `.gitignore` 忽略，不会进仓库。
- **不放字体也不会出现豆腐块**：检测不到汉字字形时，所有文案**整体回落英文**（`Loc.prefer_zh()` 为 false），
  启动会打印 `[Font] ... built-in font` 与 `[Loc] Chinese is selected but the font cannot draw it`。
- 天赋药剂名（**硬豌豆 I** / **大阳光 I** / **厚坚果 I**，`I` 是阶数，以后有 II、III）也走同一套语言层。

### 词条放在哪

实现只有一条链路：**`scripts/core/loc.gd`**（语言状态 + `Loc.t()` / `Loc.tf()` + 启动自检），
词条按域分成四个文件，方便单独增删：

| 文件 | 内容 |
|---|---|
| `core/loc_names.gd` | 名称：植物 / 僵尸 / 脑子 / 道具 / 工具 / 天赋 / rarity / 难度 / 行动条文字 |
| `ui/loc_ui.gd` | 界面文案：主菜单、关卡列表、设置页、HUD 按钮、花园页 |
| `ui/loc_msgs.gd` | 战斗提示（HUD 消息行、工具与卡片提示）与结算 / 统计面板 |
| `core/loc_garden.gd` | 花园操作提示（浇水 / 施肥 / 天赋药剂的结果文字） |

- 每个词条**必须同时有 `zh` 与 `en`**，且**格式串的占位符（`%s` / `%d`）两种语言必须完全一致、顺序相同**
  （Godot 的 `%` 没有 `%1$s` 这种位置写法，两种语言共用同一个参数数组）。
- 启动时的 **`[Loc]` 自检**会检查：中英是否齐全、占位符是否一致、有没有重名 key、当前语言能不能画出来，
  最后一行是 `[Loc] self-check PASSED`。它旁边还有一行 **`[Loc] name helpers … = OK`**：
  那是**接线**自检，确认 `Balance.plant_name()` 这类名称函数真的走了语言层
  （"中文界面里植物名还是英文"就是靠这行报警，见「自检与排错 → 语言层排错」）。
- **关卡名**：`data/*.json` 里加一个可选的 **`"name_zh"`**（`"name"` 仍是英文名）。
  没写的关卡照旧显示英文名，不需要改代码。
- **日志永远是英文**：`print()` / `_log()` / 自检输出不参与翻译，方便贴日志排错。

---
## 8. 持久化存储（存档层）

> **[P109] 这一节是"存档存成什么样"的唯一业主。** 游戏规则见 `PROMPT.md`，数值归属见 §2，
> 删档与坏档的**行为**写在代码里（`scripts/core/save/save_ledger.gd` + `Game` 上那三道转发门）；本节只声明**结构**：
> 哪几份文件、谁读写它、里面有哪些段与键。**改存档形状 = 改这一节。**

### 8.1 三层分工（一次写盘穿过的三层）

| 层 | 业主 | 管什么 |
|---|---|---|
| **低层 · 字节** | `scripts/core/save/safe_io.gd`（`SafeIO`，无 `class_name`，`preload` 消费） | 原子换入（`.tmp` + rename）、坏档归档（`.bak`）、以及"文件在不在" |
| **账本层 · 内容** | 四份存档各自的类 | 自己的键、自己的 `parse_text()` / `to_json_text()`、自己的 `source` 拒写守卫 |
| **门层 · 对局** | `scripts/core/save/save_ledger.gd`（`SaveLedger`，注入式行为对象）+ `Game` 上那三道转发 | 三道门 `save_garden()` / `save_profile()` / `save_run()`、脏账 `is_dirty()`、告警 `_record_write`；清档三件仍在 `Game` 上 |

三条纪律：

1. **任何地方都不许自己 `FileAccess.open(..., WRITE)`**。写盘只有两个入口
   （`SafeIO.write_text_atomic()` / `SafeIO.write_config_atomic()`），它们回答同一个契约：
   **返回 false 时，磁盘上还是写之前那份文件。**
2. **任何地方都不许"接一下返回值"**（OPTIMIZATIONS A3）。账本写盘只有 `Game` 的三道门，
   门里调 `_record_write()`：成功清掉**该账本**的告警，失败 `push_warning` 一次，
   并把 `msg.save.alarm` 挂到**之后每一条状态行**上，直到该账本有一次写入落地。
3. **路径不集中**：每份存档的位置归**读它的那张表**（§2 "一个数值一个业主"）——
   `Balance.PROFILE_PATH` / `Balance.SETTINGS_PATH`、`BalanceGarden.GARDEN_PATH`、`BalanceRun.RUN_PATH`。
   `save_ledger.gd` 里**一个路径字面量都没有**。

### 8.2 四份存档

| 文件 | 业主（读写它的类） | 格式 | 版本键 |
|---|---|---|---|
| `user://garden.json` | `scripts/core/save/garden.gd`（`Garden`） | JSON | `version` = `BalanceGarden.GARDEN_VERSION` |
| `user://profile.json` | `scripts/core/save/profile.gd`（`Profile`） | JSON | `version` = `Balance.PROFILE_VERSION` |
| `user://run.json` | `scripts/core/run_state.gd`（`RunState`） | JSON | `version` = `BalanceRun.RUN_VERSION` |
| `user://settings.cfg` | `scripts/core/save/settings_store.gd`（`SettingsStore`） | ConfigFile | **无**——键名即版本口径 |

三份 JSON 的键：

| 文件 | 键 |
|---|---|
| `garden.json` | `version` / `capacity` / `plants[]`：每株 `slot` · `type` · `hp` · `max_hp` · `downed` · `level` · `rarity` · `downed_at`（绝对 unix 秒）· `exp` · `talents{}` |
| `profile.json` | `version` / `money` / `warehouse{}` / `backpack{}`（道具 id → 数量）/ `durability{}`（卷轴 id → 当前耐久，非卷轴不进这里） |
| `run.json` | `version` / `mode` / `chapter` / `node`（站着的位置）/ `active`（进了没打完的节点）/ `visited{}` / `squad[]`（**花园槽位号**，不是植物 id）/ `pouch{}` / `mods[]`（`{key, value, left}`）/ `retry{}` / `stats{wins,losses,nodes,money}` / `finished` |

`settings.cfg` 的段（段名是常量：`SettingsStore.SECTION_*`）：

| 段 | 键 |
|---|---|
| `[window]` | `width` / `height` / `fullscreen` |
| `[display]` | `language`（`zh` / `en`，认不出回落中文） |
| `[audio]` | `music` / `volume` / `sfx` / `sfx_volume`（读进来一律夹到 0–1） |
| `[battle]` | `auto_collect_sun` / `sun_auto_rounds`（下限 1） |
| `[ui]` | `almanac_tab`（夹到页签数） |
| `[progress]` | `last_level` / `cleared[]` / `claimed[]`（关卡 id 数组；`cleared` = 通关了，`claimed` = 首通宝箱领过了，**两份事实**） |

> `settings.cfg` 是四份里唯一**没有门**的：`SettingsStore.save_to_disk()` 是 static、
> 不带告警，装的也不是"进度"（唯一的进度是 `[progress]`，由 §8.4 的清档一起清）。

### 8.3 读入纪律（坏档不许静默）

三份 JSON 是同一个形状，顺序固定：

1. **文件不在** = 首次启动：`garden` / `profile` 建初始档并立刻写盘；
   `run.json` 不在 = **没有进行中的一局**（不是坏档，`RunState.load_or_create()` 回 `null`）。
2. **文件在却读不出来 / 解析失败** = 先把字节挪到 `<文件>.bak`（`SafeIO.keep_broken()`，
   **只保留第一份**坏档），再写默认值——否则"读不出来"会在几秒内变成"进度没了"。
3. **某个字段坏**只丢那个字段并在 `problems` 里点名，**不牵连整份存档**；**根坏了**才拒绝整份。
4. **探针实例不许写盘**：`Garden` / `Profile` / `RunState` 的 `source` 以 `<` 开头时
   `save_to_disk()` 直接 `push_warning` 返回 false。启动自检因此能在**真类**上跑真路径而不碰玩家进度。

### 8.4 清档（SETTINGS → RESET GAME、调试键 N）

`request_reset()` **两次点击**后才调 `reset_progress()`（`Balance.RESET_CONFIRM_TIME` 内算第一次）。
清什么、留什么是规则：

| 清 | 留 |
|---|---|
| 花园（回到初始那一株豌豆射手）、钱、仓库与背包、`durability` | `settings.cfg` 的 `[window]` / `[display]` / `[audio]` / `[battle]` / `[ui]`（那是"窗口"，不是"进度"） |
| `settings.cfg` 的 `[progress]`：`last_level` / `cleared` / `claimed`（首通宝箱必须能再开一次） | `run.json`（结束一局只归 `run_flow._close_run_end()` 管） |
| 正在跑的那一局棋盘（`_discard_battle_without_settling()`——**故意不结算**，否则刚重建的花园会被这一局写脏） | |

### 8.5 门与自检

- 三道门是 `Game` 的**公开**成员（`Game` 是 `Node`：公开名会撞引擎词汇，所以名字里必须带账本名词
  ——`tools/member_name_check.gd` 登记了这三个名字）。**40 处调用点**全部走它们
  （实测于 P109：`garden` 15 / `profile` 18 / `run` 7；`run_flow.gd` 15 处最多，
  另有 `rewards.gd` / `view/garden.gd` / 仓库与商店两个道具页 / 自检 / 清档）。
  **没有任何一个调用点自己 `save_to_disk()`**——那正是这道门存在的理由。
- **`[Save]` 启动自检**证明的就是上面三条纪律，五条判据：干净时状态行一字不改 · 被拒的写点名一次后
  **随行** · 记账的是下一次**落地**的写而不是时钟 · 告警**按账本**分开 · 三道门都在。
  它要求 `game.battle` 存在，所以主菜单上打印 `deferred (no board at boot)`。
- `_record_write()` / `_unsaved` / `_sync_unsaved_note()` 是**私有**的；
  `_unsaved` 被自检直接读写，**名字不许改**。
