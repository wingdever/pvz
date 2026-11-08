# 新增植物 / 僵尸角色：完整步骤

> **这份文档写什么**：**加一个角色要动哪些地方**，按"想做到哪一步"分成四条路线，每条给出可照抄的代码片段、
> 漏改会怎样、以及怎么验收。事实来源是 P26 之后的代码（单位数值从 `data/units/*.csv` 读）。
>
> **配套文档**：
>
> | 想找什么 | 去哪 |
> |---|---|
> | **贴图**怎么加 / 怎么改（路径表、尺寸、实心范围） | `docs/UNIT_ART.md` |
> | 数据表**每一列**是什么意思 | 本文件 §8「单位数据表」（列清单与逐列含义）；`units.csv` 的权威列清单是代码 `scripts/core/unit_sheet.gd` 的 `COL_*` 常量 |
> | 数值都有哪些、改哪个 | `docs/BALANCE.md` → 「数值改动地图」 |
> | 文案/名字的规则（中英双语、占位符） | `AGENTS.md` §3 |
>
> **改名有风险的地方**：新增脚本的**公开成员名**可能撞 Godot 原生成员（历史上 `ready` 撞 `Node.ready`
> 让整个文件解析失败）。加完单位脚本先跑一次：
> ```bash
> cd /home/wing/Projects/Games/pvz
> godot --headless --path . --script res://tools/member_name_check.gd 2>&1 | grep -E "\[Names\]|Parse Error"
> ```

---

## 0. 先决定你要哪一档

| 档 | 目标 | 必须改的地方 | 工作量 |
|---|---|---|---|
| **A** | 加一种**僵尸**（按现有机制打架） | `zombies.csv` 1 行 + `loc_names.gd` 1 条 + 关卡 json 里点名（贴图可选） | 5 分钟 |
| **B** | 加一种僵尸 + **新机制**（飞行、暴怒、召唤…） | A 的全部 + `zombie_db.gd`（句子→旗标）+ `zombie.gd` / `game_manager.gd`（行为） | 半天 |
| **C1** | 加一种**植物**，只要**图鉴里有**（还不能召唤） | `plants.csv` 1 行 + `loc_names.gd` 1 条（贴图可选） | 5 分钟 |
| **C2** | 加一种植物并让它**能召唤上场** | C1 的全部 + 3 处表行 + 单位脚本/名字/颜色（见 §C.2） | 半天~一天 |

> **为什么僵尸比植物省**：僵尸没有"单位脚本"，它的行为全由 `zombies.csv` 的数值 + `zombie_db.gd`
> 的机制旗标驱动；植物要"召唤"就得有脚本、卡片、卷轴三件套（见 §4.2）。

---

## 1. 共用前提：id、数据表、生效时机

### 1.1 id 规则
- **id = `data/units/*.csv` 的 `name` 列**（P86 起由 `英文名称` 改名，旧拼写仍认），也是 `loc_names.gd` 的键、`PLANT_ART` / `ZOMBIE_ART` 的键，
  以及 **`svg` 列（贴图路径）所在那一行的身份**。
- 用**小写 + 下划线**，与已有风格一致：`snow_pea`、`zombie_gargantuar`、`mushroom_sun`。
- **一个 id 只能出现一次**；重复行会被忽略并在自检里报 `duplicate id … (kept the first row)`。

### 1.2 两张表怎么改
- **TAB 分隔，按列名读取**（列顺序可以改，可以在中间插列）。
- 一格的**四种写法**（2026-10-05 用户口径，见 `AGENTS.md` §2）：**空着**或写 **`default`** = 按默认值（去问默认行）；
  **`—`（或 ASCII 的 `none`）** = 这个属性就是不存在（默认行不许改口）；**`0`** = 就是 0。
  **别再用 `—` 表示"我懒得填"**——那正是它现在的反面。
  ⚠ 分隔符是 **TAB**：中间的空格子照写两个连续 TAB；**行尾的空格子可以直接省掉**（读取按列名走，
  少一列就是"这一格没说"），所以"少一列"不再是危险，而是"没说"的另一种写法。
- 英文列（`技能英文` 等）可以缺：缺了退回中文原文，自检会统计 `N prose field(s) with no English twin`。
- 新加一行时**照抄同名称已有行**的列数最稳。
- **[B11c] `defence` 是新单位可以直接填的一列**（`units.csv` 的共用列，单位是刻度上的“点数”，不是百分比）：
  **留空 = 跟 `default` 行走**（今天是 **20** ⇒ 挨 86%）；**128 = 减半**、64 ≈ 打七五折、0 = 一点不减伤。
  公式与对照表在 **`docs/NUMBERS.md` §3**——**别按 HP 的量级给值**（盾卫是 50，不是 500）。
- **[B16] `face` 是新单位可以直接填的一列**（`units.csv` 的共用列，说的是**这张画朝哪边**）：
  **留空 = 跟种族的 `default` 行走**（植物 / 人类 / 怪兽都是 `r`，**僵尸是 `l`**），代码兜底也朝右；
  写法是一个**封闭清单**：`r` / `1` / `right` / `右` = 朝右，`l` / `0` / `-1` / `left` / `左` = 朝左，
  写别的词会记一条 complaint 并按朝右读。**画朝左的单位照常按朝左画就行**，不用交两张图：
  站位与画不一致时 `Unit.mirrored` 会把身体翻过来（规则见 **`docs/prompt/BRAWL.md` §8.15**）。
  ⚠ 它**不是**乱斗专属：`Unit.faces_left` 是基类的字段，五个植物基类 / 咬人花 / 僵尸 / 棋子各读一次，
  所以给一株植物写 `l`，它在**回合制**的棋盘上也会翻过来。

### 1.3 改完什么时候生效
| 改了什么 | 怎么生效 |
|---|---|
| `*.csv` | 游戏里按 **`R`**（重开当前关卡）会**重读两张表**；或重启游戏 |
| `data/level/*.json` | 按 **`R`** 重读 |
| `*.gd`（常量、表、脚本） | 重新运行游戏（`R` 不重读代码） |
| `*.svg` | 让编辑器导入完（`Project > Reload Current Project`） |

### 1.34 [P91] 加一个射弹（`data/projectiles.csv`）

**射弹 = 打出去的那个东西**。加一个射弹通常**只加一行表**，然后在植物里写 `shot_id = "<行名>"`：

| 列 | 写什么 | 漏了会怎样 |
|---|---|---|
| `name` | 射弹 id（如 `snow_pea_shot`） | 植物用 `shot_id` 引用它 |
| `轨迹` | `直线` / `追踪` / `抛射` | 清单外的词 ⇒ `[Shot]` FAIL |
| `速度` | 留 `—` 走轨迹默认（`BalanceUI.PEA_SPEED` / `PULT_SPEED`）。`[B8]` **乱斗的两行是例外**：`arrow` / `musket` 写了像素值，因为竞技场要两发**快慢不同**的射弹，而它的坐标是**格**（`BrawlShot.speed_cells()` 用 `Balance.CELL_SIZE` 换算） | — |
| `穿透` / `穿透伤害` | 穿几个 / 穿过的挨不挨打（默认 `—` = 不挨；风暴要靠这个） | — |
| `反弹` | 撞草坪边缘反向几次（0 = 出界即散） | — |
| `穿甲` / `溅射` | `是` / `—`、比例（0.5 = 一半） | — |
| `命中状态` / `状态值` | 引用**状态表**的 id 与默认回合数 | id 不在状态表里 ⇒ `[Shot]` FAIL |
| `音效` / `落点音效` | `BalanceAudio.SFX_DEFS` 的 cue | 写错开机就红 |
| `外观` | `pea` / `melon` / `arrow` / `musket` | 清单外 ⇒ FAIL（新图要在 `Projectile.draw_shot()` 加一条分支——**两种飞行共用同一个画师**：回合制的 `Projectile` 与乱斗的 `BrawlShot`） |
| `尺寸` | **基本字段（2026-10-10 起每行都写）**：这张图在棋盘上占多少**像素**（方框，保长宽）。照素材自己画布写就行：pea **32** / melon **40** / arrow **64** / musket **48** / bomb **18**（代码图就是它的直径）/ warm_sun **100**（`sun.svg` 是 200 px 的道具图标，所以在表里说"这发只当 100 px 用"） | 留空 = 回到旧口径"图自己决定"（贴图 svg 画布 ⇒ 代码 `draw_extent()`）；图鉴那一行会写"默认"而不是一个数。**只管画，命中盒仍是格** |
| `体型` | [B40] 可选的**量级词**：`微小` / `小` / `标准` / `大` / `巨大`（业主 `Balance.SIZE_WORDS`，倍数 0.6 / 0.8 / 1.0 / **1.5** / **2.2**）。它是**乘数**、乘在 `尺寸` 胜出的那个 base 上 ⇒ `100 px` × `大` = 150 px | 清单外的词 ⇒ `[Shot]` 该行 FAIL；留空 = `标准` = 1.0 |

**代码只在两件事上动**：① 要**新的轨迹**或**新的外观**（框架各实现一次）；② 要一个表表达不了的射弹（继承 `Projectile` 写行为）。
**伤害永远不在射弹表里**：它就是**植物的技能值**（乱斗里是 `BrawlActor.blow_value()` 在出膛那一刻算好的那个数），
射弹只负责把它带到落点。

**[B8] 乱斗里的射弹是另一条飞行**（`scripts/core/brawl/brawl_shot.gd`）：竞技场没有泳道、两边都能被打、
目标是**会走的**，所以那里用 `追踪` + 自由二维飞行——但**外观与 cue 读的是同一张表**，
伤害也走同一个业主（`BrawlActor.land_hit()`）。**给一枚人类棋子加射弹 = 在 `data/units/humans.csv` 的 `射弹` 列写一个行名**
（`archer → arrow`、`gunner → musket`，`—` = 近战）；`BrawlActor` 见到非空的名字就把这一击交给射弹，代码一行不用改。

### 1.35 [P90] 加一个状态（`data/statuses.csv`）

**状态 = 会被加在单位身上的东西**（冻结、击退…）。加一个状态通常**只加一行表**：

| 列 | 写什么 | 漏了会怎样 |
|---|---|---|
| `name` | 状态 id（小写英文，代码里也用它） | 自检按 id 判重、判认领 |
| `中文名` / `英文名` | 行动条上那个词（冻结 / FROZEN） | `action.<id>` 找不到键时用它兜底 |
| `显示` / `显示英文` | 日志与面板短语，**带 `%d`**（`冻结 x%d` / `freeze x%d`） | 两边 `%` 个数不一致 ⇒ `[Status]` 红 |
| `名称` | `倒计时`（会被 TURN_START 递减）或 `瞬时`（命中当场结算） | 不认识 ⇒ 红 |
| `持续` | 默认回合数；留 `—` = 由施加者给 | — |
| `叠加` | 第二次命中怎么办：`取大`（刷新、不叠加，冻结就是这条）/ `累加` / `替换` | 不认识 ⇒ 红 |
| `免疫旗标` | 单位用哪个 `特殊机制` 旗标免它（如 `freeze_immune`）；`—` = 谁都免不了 | 写错 ⇒ 免疫失效（旗标来自那句散文） |
| `影响` | **封闭清单**：`禁行动` / `位移` | 写了清单外的词 ⇒ `[Status]` **FAIL 并指名** |
| `数值` | 该影响的默认强度（今天两个状态都由施加者给，留 `—`） | — |

**代码只在两件事上动**：① 要一个**新的影响原语**（今天只有"禁行动"与"位移"，框架各实现一次）；
② 要**新的状态色**（进 `BalanceUI`，像素值的老规矩）。
**不要**把单位自己的阶段（巨人举锤前摇、舞者召唤倒计时、撑杆跳次数）写进这张表：它们不是"被施加"的，
而且数值已经在 `zombies.csv`（锤击前摇 / 召唤间隔 / 移动）——写两处就是同一个数两个业主。

### 1.36 [P110e] 加一个近战特效（`近战特效` 列）

**一张近战图画 = 一个 SVG + 一格表。加一张今天不用写代码。**

1. **画一张 SVG** 放进 `assets/svg/fx/`（128×128，墨迹尽量铺满画布——这一族共用
   `BalanceUI.MELEE_FX_SIZE` **一个**方框，图画会被缩放进那个框）。文件名就是**短名**：
   `slash.svg` ⇒ 格子写 `slash`。
2. **在表里点名**——**谁打的那一下，就写在谁的行上**：

   | 谁 | 哪张表 |
   |---|---|
   | 人类棋子（民兵 / 骑士 / 队长…） | `data/units/humans.csv` 的 **`近战特效`** 列 |
   | 僵尸 | `data/units/zombies.csv` 的 **`近战特效`** 列；**想让所有僵尸一样就只写 `default` 行** |
   | 植物 | 今天**没有**这张表（植物近战只出火花）；真要做，先给它一层 |

   空着 = **只出火花**（不是错误）。想取消某个单位的图画，把那格清空就行。
3. **不用改代码**：链路是 表 → `PieceDB.melee_fx` / `ZombieDB.melee_fx` → `Unit.melee_fx_id()`
   → `Fx.spawn_melee_fx(id, at, facing)`。代码只在两件事上动：**新的时长 / 大小**
   （`BalanceUI.MELEE_FX_*`），**新的"什么时候放"**（今天只有两处：`Zombie.act` 的 BITE 与
   `BrawlActor._begin_strike` 的近战分支）。

**两个坑**：

- **短名要一字不差**（`slash_heavy` ≠ `slashheavy`）：写错**不报错**，只是那张图画不出来、
  打击照旧结算。开机那行 `[Data] pieces: … %d with a 近战特效` 数的是**格子里有字的行数**，
  不是"画得出来的行数"——数字对、图画却没出现，就是名字或文件的问题。
- **新 SVG 要 `--import` 过一次**才读得到（编辑器开着会自动；纯无头见 `docs/ARCHITECTURE.md` §1.3）。
  没导入的图画由 `UnitArt.warn_once` 在日志里喊一次，缺图从来不算错。

### 1.37 [P110f] 加一个乱斗阵营 / 加一个远程光束

**A. 加一个阵营**（例：怪兽 `monsters`）——**四处表 + 一行代码**，没有新脚本：

1. `data/units/units.csv`：每个单位一行，`race` 列写阵营名；再补**一行 `默认XX`**
   （`name` 写 `default`，`race` 写阵营名）。**模式两列**：只进乱斗就写 `turned=0 / timed=1`。
   ⚠ 默认行的 `svg` / `tscn` 写 **`—`**，否则每一行都会继承同一张图（D80 那个坑）。
2. `data/units/<阵营>.csv`（**新**）：这一族**独有**的列。人类/怪兽这一支的列是
   `费用 / attack距离 / 移速 / attack间隔 / 射弹 / 近战特效 / 远程特效 / 持续 / 击退 / 吞噬 / 大招持续`
   （**朝向不在族表里**：它是 `units.csv` 的 `face` 列，见 §1.2 —— [B16] 从族表搬走的。
   最后那一格 `大招持续` 见 §1.37 B 的第 7 条；`humans.csv` 与 `monsters.csv` 的列**集**与列**序**现在是一样的）。
   ⚠ **列集要与 `humans.csv` / `monsters.csv` 一致**（哪怕整列留空）：`PieceDB` 是**逐行**读这些列的，
   某一列在这个表头里不存在时，`UnitCsvManager._check_column` 会为它记一条 complaint（§1.38 那个坑）。
3. `data/units/races.csv`：`<阵营>	<该族的默认单位>`——不写这一行，图鉴与兜底都找不到它。
4. `scripts/core/db/piece_db.gd` 的 **`FACTIONS`**：加一行（族表路径 + 图根 + 场景根）。
   **这是唯一要动的代码**：`PieceDB` 从此按阵营解析图路径，其余一行不改。
5. `data/brawl/roster.csv`：想让玩家抽到就加行（`-1 -1` = 从候战席开始）；想让它是**敌人**，
   改 `data/brawl/formation_pieces.csv`。
6. `scripts/core/loc_names.gd`：每个单位一条 `"piece.<id>": {"zh":…, "en":…}`。

> **[B19] 这张清单被机械阵营（`machine`，抛射炮 `lobber`）第二次原样走通**——四处表 + `FACTIONS`
> 一行，仍然**没有新脚本、没有新场景**（族表 `machine.csv` 的列集与前两张相同、整列留空也行）。

**B. 加一个远程光束**（`远程特效` 列）——**一格表 + 一个分支**：

1. `BalanceUI.BEAMS`：加一行 `{"time":…, "width":…, "color":…}`（id 就是格子里的短名）。
2. `scripts/fx/fx.gd` 的 `draw_beam`：`match` 里加一个分支（**没有 SVG 可放**：
   一条光是两个点之间的东西，画不出来也缩放不了——所以这一族是**代码画的**，见 `docs/dev/FX.md` §6）。
   这个画师**一闪与通道共用**，所以加一次两边都有。
3. 表里点名：该单位的 `远程特效` 格子写那个 id。**代码不用改**。
4. **要"持续烧"就再填一格 `持续`**（秒）：开火那一帧先打一次，之后每 `BalanceBrawl.BEAM_TICK_SECONDS`
   一跳、每跳 `blow_value() × BEAM_TICK_SHARE`，到点收手。
   ⚠ **`attack间隔` 这时是"整个周期"**（烧 + 间歇）：眼球塔 `attack间隔=4.0` + `持续=3.0` = 间歇 1 秒。
   留空 = 只打一次（一闪）。通道的节点是竞技场持有的 `scripts/core/brawl/brawl_beam.gd`，
   **不是** `Fx` 那种一次性的画——不用你新建任何东西，填格就行。
   **实例**：`flame_eye_tower`（火焰眼球塔）= `flame` + `持续 3.0` + `attack间隔 4.0`，
   与 `laser_eye_tower` 共用同一套通道，**代码一行没加**；两者只差 `远程特效` 那一格。
5. **别指望它追人**：光的两个端点只在生成那一刻取一次（理由见 `BRAWL.md` §8.9 ④）。
6. **[B14] 出手点不是身体中心时，在 `BEAMS` 那一行加 `"muzzle"`**：一个**按画框比例**给的偏移
   （负 x = 左、负 y = 上；`Vector2.ZERO` = 身体中心，也是另外三条的写法）。雷角兽的雷从**左上角那只角**
   出去，所以它的格子是 `Vector2(-0.375, -0.375)` = SVG 的 (16,16) 在 128 px 画布上（中心 64）。
   用**比例**不用像素，是因为乱斗会按 `BrawlLayout.piece_scale` 把棋子画大（`Unit.art_box()` 是那个方框）。
   **不用改调用点**：一闪与通道都经 `Fx.beam_muzzle(kind, box)` 取它（`BrawlActor.muzzle`）。
7. **[B14] 要把这一击变成大招，就再填一格 `大招持续`**（秒）：那一行的普攻从此攒能量
   （`BalanceBrawl.ENERGY_PER_STRIKE` / `ENERGY_MAX`，**模式级**的数），攒满的下一次attack不开火、
   而是**把同一条光束按住这么多秒**（每跳 `ULT_TICK_SHARE`，是爆发不是节奏）。
   ⚠ **它是大招的画，也是大招的开关**：留空 = 这一行没有大招（不攒能量、不画能量条）。
   ⚠ **它不指定第二种光束**——大招就是这一行的 `远程特效`；只填 `大招持续` 而 `远程特效` 空着，
   等于给了一个画不出来的大招（场上表现为“条满了却照常普攻”）。

**四条容易踩的**：

- **两张族表的列集必须一样**（`humans.csv` / `monsters.csv`）：`PieceDB` 是**逐行**读那几格的，
  只在其中一张表加列 ⇒ 另一张的每一条行都记一条 `no column … in the header` 的 complaint，
  而那条 complaint 会挂在**下一个跑自检的模块**头上变红（`docs/PITFALLS.md` 第 76 条）。
  ⇒ **加/减一列时，两张表一起改**（新列全空也照加）。
- **`射弹` 与 `远程特效` 是两种不同的attack**：前者飞出去、落地才结算；后者**同一帧**结算并画一条光。
  两格都空 = 近战。顺序是 `射弹` → `远程特效` → 近战。
- **新族的图要 `--import` 一次**（编辑器开着会自动；纯无头见 `ARCHITECTURE.md` §1.3）。
  没导入 = 那件武器/那个单位画不出来，`UnitArt.warn_once` 喊一次，**缺图永远不算错**。
- **开机两行是排查第一站**：`[Data] pieces: N row(s) in 2 faction(s) [humans, monsters] … %d with a 远程特效`。

### 1.38 [B9] 给一个单位加击退（`击退` 列）

**一格表、一个数字：加一个会推人的单位，今天不用写代码。**

1. **在族表的 `击退` 列写格数**：`data/units/humans.csv` / `data/units/monsters.csv`
   （两张族表列集相同；**空 = 这一行不推**）。例：`shieldman` 那一格写 `1`。
   数字是**格**、不是开关——写 `2` 就是这个单位每打中一次推 2 格。
2. **链是四步**：表 → `PieceDB.knockback` → `HumanPiece.brawl_knockback_cells()`（第八道门）
   → `BrawlActor.knockback_cells()` → `land_hit` 把它交给 `shove_from()`。
   植物与僵尸**没有那道门**（`has_method` 答 false = 0），所以今天能推人的只有**乱斗棋子**。
3. **它说的是“我打中别人”，不是“我挨打”**：结算在**attack方**的 `land_hit` 里，方向背离attack者，
   距离就是那一格，**被推的那一 tick 不走路也不出手**（规则与理由见 `BRAWL.md` §8.10）。
4. **手感只有一个旋钮**：`BalanceBrawl.SHOVE_CELLS_PER_SECOND`（6 格/秒 = 一格 0.167 秒）。
   推得太远/太近改**表里的格数**；看着像瞬移才改这个常数。

**两个坑**：

- **别与 `data/statuses.csv` 的 `push` 弄混**：那一行是**回合制**的状态（僵尸被恐惧孢子推开一格，
  `Zombie.push_back`）；乱斗的击退**不写状态、不留计数器**，而且两边连“退”的方向都不同
  （那边是列号变大，这边是背离attack者）。
- **开机读数是排查第一站**：`[Data] pieces: … %d with a 击退` 数的是**格子里写了正数的行数**。
  数字对、场上却没推动，先确认那一行的单位真的出手了（近战要贴进它的 `attack距离`）。

### 1.39 [B10] 给一个单位加吞噬（`吞噬` 列）

**一格表：写个秒数，这个单位从此把敌人吞进肚子里消化，而且接触时不再造成伤害。**

1. **在族表的 `吞噬` 列写消化秒数**（`data/units/humans.csv` / `data/units/monsters.csv`；**空 = 这一行不吞**）。
   例：`green_slim` = `6.0`。它要贴到目标身上才会张口，所以那一行的 `attack距离` 通常就是近战（0.75 左右）。
2. **它是“第四种attack形状”，不是一击的附加效果**：写了这一格，这一行**不再有接触伤害**——伤害改成
   每 `BalanceBrawl.GULP_TICK_SECONDS`（0.5 秒）一次、打在肚子里的目标身上，每次 `blow_value() × GULP_TICK_SHARE`。
   ⇒ **“又咬又吞”今天做不到**，一行只能挑一种attack形状（顺序见 §1.37 那条）。
3. **链是四步**：表 → `PieceDB.gulp_seconds` → `HumanPiece.brawl_gulp_seconds()`（第九道门）→
   `BrawlActor.gulp_seconds()` → `Brawl.swallow()` → `scripts/core/brawl/brawl_gulp.gd`。**不用改代码。**
4. **肚子里那个单位怎么画**由 `BalanceUI.GULP_*` 三个数定（缩小 `GULP_PREY_SCALE` / 染色 `COLOR_GULP_PREY` /
   图层 `GULP_PREY_Z`）。⚠ 吞噬者的画**必须是不透明的一块**：猎物是画在它**上面**的，而画在背后
   （z 更小）等于看不见——这是这套观感的唯一硬要求。

**三个坑**：

- **`吞噬` 与 `attack间隔` 是两件事**：消化期间吞噬者不能出手（`arena.is_digesting`），但可以走。
  所以“多久能吞下一个” = **消化秒数 + attack间隔**，改一个要看另一个。
- **列集要与 `humans.csv` / `monsters.csv` 一致**（哪怕整列留空）：`PieceDB` 逐行读它，缺列会被
  `UnitCsvManager._check_column` 记成 complaint（§1.38 那个坑）。
- **开机读数是排查第一站**：`[Data] pieces: … %d with a 吞噬`。数字对、场上却只掉血不吞人，
  先确认那一行**没有**同时写着 `射弹` / `远程特效`（先读到的形状赢），以及它真的贴到了目标。

### 1.4 [P86] 默认行（`name` 写 `default` 的那一行）

**每一层可以带一行 `default`，它不是单位，是这一层的兜底档。** 你加内容时通常**不用管它**：
只有当某个单位某一格留了 `—` 时，才轮到它说话。

| 表 | 可以写几行 `default` | 覆盖哪些列 | 判别方式 |
|---|---|---|---|
| `units.csv` | **每个 race 一行**（如 `race=plants` / `zombies`；不写 race = race `无`） | 本表的列：`HP` `attack` `技能代码` `大招代码` … | `race` 列 |
| `plants.csv` / `zombies.csv` | **至多一行** | 本表的列：费用 / 冷却 / 成长 / 护甲 / 移动 / 啃脑伤害 … | 表本身就是一族 |
| 子族表（如 `pea.csv`） | **至多一行**（表也可以不存在） | 该子族独有的列 | 同上 |

- **查找顺序**：某一格留了 `—` ⇒ 先问**这一格所属那一层的** `default` 行 ⇒ 那一层没有（或它那格也空）⇒
  按 race 往粗里找（`plants/pea` → `plants` → `无`）⇒ 还是没有 ⇒ **回代码兜底**（`Balance` / 门面里的默认值）。
- **要"就是 0"就写 `0`**：`0` 是一个值，不会被默认行填掉；`—` / 空 / 不存在才会。
  例：坚果的 `attack` 写 `0`（它没有attack），一次性植物的 `HP` 写 `0`（它没有自己的血）。
- **默认行只覆盖自己那张表的列**，所以两层的默认永远不会争同一个数；默认行也可以只写一部分格子，
  剩下的一路走代码兜底。
- 每格都记得来源：`UnitSheet.cell_source(id, 列)` 会答 `plants.csv #13` 或 `units.csv default (plants)`，
  启动日志里 `units: … 4 default row(s) … filling N cell(s)` 会告诉你默认链一共填了多少格。

---

## 2. 路线 A：加一种僵尸（纯数据）

### A.1 两张表各加一行（[P29] 起表是分层的）

- `data/units/units.csv`（**30 列**，权威列清单 = 代码 `scripts/core/unit_sheet.gd` 的 `COL_*` 常量）
  = **每单位一行 + `race` 列**，放**共用**列：
  `名称` `name`(id) `race` `HP` `attack` `defence` `技能` `大招` `天赋` `技能代码` `大招代码` `特殊机制`
  `技能英文` `大招英文` `天赋英文` `特殊机制英文` `svg` `tscn` `timed` `turned` `rarity` `face`
  `z_height` `z_thickness` `body_width` `body_depth` `body_xoff` `body_yoff`
  **[P113]** `range_type` `role`
- `data/units/zombies.csv`（12 列）= **僵尸独有**列：
  `英文名称`(id) `护甲` `移动` `attack` `啃脑伤害` `召唤间隔` `召唤数量` `召唤单位` `锤击前摇` `锤击后摇` `暴怒移动` `暴怒attack`
- 同名列**深层覆盖浅层**（子族表 > `zombies/normal` 族表 > `units.csv`），`—` / 空 = 本层不说话。

照抄一行改值，例如一种"滑板僵尸"（**两张表各一行，id 必须一模一样**）：

```
滑板僵尸	zombie_skater	zombies/normal	300	—	啃食	血量低于1/3时立即死亡	zombie_skater	—	—	Bite	Dies at once below 1/3 of its HP	—	—
zombie_skater	—	2	100	10
```

（第一行进 `units.csv`、第二行进 `zombies.csv`。这个例子故意挑了个**已经有短语、且真的会生效**的机制：
`低于1/3` → `execute` → 血 ≤ 1/3 时立即死亡。
`护甲` 留 `—` 就代表它没有护甲；写了"护甲被打掉后…"这类句子却没填护甲值是没有意义的。
`技能代码` / `大招代码` 僵尸一般留 `—`：`啃食` 与那两个机制都不走 `skills.csv` 的 AP 定价。）

各列的含义（完整逐列说明见本文件 §8「单位数据表」）：

| 列 | 填什么 | 影响 |
|---|---|---|
| `名称` | 中文名（**兜底**用；真名在 `loc_names.gd`） | 图鉴/棋盘的显示名 |
| `天赋` / `技能` | 机制名 / 动作名（`啃食`、`召唤`、`锤击`、`漂浮`…），没有就 `—` | 图鉴的「天赋 / 技能」两行；**不驱动逻辑** |
| `英文名称` | **id**（小写+下划线） | 代码、关卡 json、贴图表的键 |
| `HP` | 基础血量（>0） | 出怪时 × (关卡 `zombie_hp`/270) × 难度 |
| `护甲` | 护甲值，没有就 `—` | 血条上方多一条护甲条；打穿后按 `特殊机制` 决定是否降级 |
| `移动` | **几回合走一格**（= 移动进度条长度；P30-A：移动技能每次花 3 AP、进度 +1，每回合默认攒 1 点） | 数字越小走得越快 |
| `attack` | 每次啃咬伤害 | 咬植物的速度 |
| `特殊机制` | **一句中文规则**（见 A.1.1） | `zombie_db.gd` 的短语表把它翻成旗标 |
| `啃脑伤害` | 走到最左列后每次吃脑子的伤害，默认 10 | 脑子 100 血能撑几回合 |

#### A.1.1 `特殊机制` 这句话怎么写
`scripts/core/db/zombie_db.gd` 的 **`PHRASES`** 用**子串匹配**把句子翻成旗标，目前认识这些说法：

| 句子里出现 | 旗标 | 战斗里真的会做 |
|---|---|---|
| `低于1/3` | `execute` | ✅ 血 ≤ 1/3 时立即死亡 |
| `被打掉后变普通僵尸`（护甲 / 垃圾桶护甲…都行，只要结尾这句）/ `护甲打掉后移动变3` | `armor_downgrade` | ✅ 破甲后变普通僵尸（名字/移速/啃食/处决规则都换）|
| `跳过第一株植物` | `vault` | ✅ 跳过植物一次，跳完变普通僵尸 |
| `钻石` | `drops_diamond` | ✅ 击杀必掉 1 颗钻石 |
| `和普通僵尸一样` | `same_as_zombie` | ✅ 继承基础僵尸的旗标 |
| `免疫冻结` | `freeze_immune` | ✅ P34：射弹的冻结 rider 对它无效 |
| `格挡射弹` | `blocks_projectiles` | ✅ P45：铁门还在（护甲 > 0）时吞掉射弹的 rider；[P77] 但**只对直线射弹有效** —— 抛体、爆炸、地刺、铲子都不是它的对手（那是 `Projectile.straight_shot` 说的，不占表） |
| `无视护甲` | `back_attack_ignores_armor` | ✅ P45：来自**背后**（源单位 col 更大）的命中跳过护甲 |
| `召唤`（+ `召唤间隔 / 召唤数量 / 召唤单位` 三列） | `summon` | ✅ [P47]：每隔几回合在周围放出指定僵尸。`被…召唤` 那种被动写法不算（所以伴舞僵尸仍显示"未实装"） |
| `锤击`（+ `锤击前摇 / 锤击后摇` 两列） | `smash` | ✅ [P48]：举锤占满一回合 → 落锤花表里那份**未过比率**的 `attack` → 砸完歇几回合 |
| `暴怒`（+ `暴怒移动 / 暴怒attack` 两列） | `rage` | ✅ [P68]：破甲后把这两格的数**换到同一个身体上**——名称/名字/贴图/血量都不变（这正是它与 `armor_downgrade` 的区别）。缺任一格 ⇒ 不生效且启动日志打 `rage gap`（读报僵尸的"报纸"就是它的 `护甲`） |
| `飞行` / `投掷` / `替换1只` / `走到最右消失` | 同名旗标 | ❌ **只显示**（图鉴会写明"未实装"） |

> [P46] 为什么 `armor_downgrade` 的关键字不含"护甲"两字：垃圾桶僵尸写的是
> `垃圾桶护甲，被打掉后变普通僵尸`，子串匹配对不上旧的长写法 ⇒ 它有 800 护甲却没有规则。
> **新写一行时，尽量沿用表里已有的说法**；自机会在启动日志里打一行
> `[Zombies] no flag understood for '<id>: <句子>'` 提醒你这句没人懂（那不是 FAIL，但值得回头补 `PHRASES`）。

- **句子没被任何短语命中也不会报错**：那只僵尸照样有全部数值，图鉴原样显示这句话，自检打印一行
  `no flag understood for '<id>: <句子>' (shown in the almanac only)`。
- 想要新机制**真的生效** → 走路线 B。

### A.2 `scripts/core/loc_names.gd` 加一条名字（中英双语）

```gdscript
	"unit.zombie_skater": {"zh": "滑板僵尸", "en": "Skater Zombie"},
```

- 漏了会怎样：名字退回 csv 的 `名称`（英文界面下会显示中文），日志出现 `[Loc] no string for key 'unit.zombie_skater'`。
- **占位符规则**：两条都必须有（`Loc.self_check()` 会查）。

### A.3 在关卡里点名它

`data/level/Lawn_*.json` 的 `waves[].spawns[]` 里用 `"type"`：

```jsonc
{ "id": 2, "start_round": 8, "spawns": [
    { "round": 8,  "type": "zombie_skater", "count": 1 },
    { "round": 12, "type": "zombie",        "count": 3 }
]}
```

- **写错的 id 不会让关卡坏掉**：会被替换成 `zombie` 并在日志/图鉴里报
  `wave …: unknown zombie type 'zombie_skate' -> 'zombie'`。
- 关卡里的 `zombie_hp` 会**按比例缩放所有名称**（`405` = 全部 ×1.5）。

### A.4 贴图（可选）
- 在 `units.csv` 那一行的 **`svg` 格子写上文件名**（`zombie_skater`，不带 `.svg`；
  文件放 `assets/svg/units/zombies/zombie_skater.svg`）→ 完事。（`svg` / `tscn` 是**共用**列，
  所以它在 `units.csv` 那半行里，不在 `zombies.csv`。）
- 格子是 `—`、或文件还没画：它画**基础僵尸那张图**，图鉴格子上写 `暂无贴图`，
  那一行自检标 `NOT IMPORTED (base zombie)`。细节见 **`docs/UNIT_ART.md`**。

### A.5 验收
```bash
timeout 300 godot --headless --path . --quit-after 400 2>&1 \
  | grep -E "\[Zombies\]|\[Data\]|\[Levels\]|unknown zombie|FAILED"
```
- `[Zombies] zombie_skater … hp 300 armor 0 move 2 bite 100 brain 10 sim[…] art (base zombie) | OK`
- 进游戏按 `R`，在对应回合看到它入场（日志 `[SPAWN] … type=zombie_skater hp=… armor=… move=… bite=…`）。

---

## 3. 路线 B：给僵尸加一个新机制

以**气球僵尸（`zombie_balloon`，表里已经有"飞行"这句话）**为例 —— 它的旗标现在只是"显示"，
我们要让它真的飞起来（简化版：**地面射手打不到它**）。

### B.1 第一步：把"要实现"这件事登记进短语表

`scripts/core/db/zombie_db.gd`：

```gdscript
## 旗标本身已经能从"飞行"解析出来（PHRASES 里已有），所以要动的是这两张名单：
const FLAGS_SIMULATED: Array[String] = ["execute", "armor_downgrade", "vault",
	"drops_diamond", "flying"]          # ← 加 "flying"：从此它是"已实装"
```
> 上面是**示例**，不是现状照抄。截至 P46，工程里那张名单的真实内容是
> `execute, armor_downgrade, vault, drops_diamond, freeze_immune, blocks_projectiles, back_attack_ignores_armor`。
- **`FLAGS_KNOWN`** = 能从句子解析出来的机制（图鉴会显示"未实装"的那些）；
- **`FLAGS_SIMULATED`** = 代码真的会做的；加进去以后，图鉴的「实装情况」行和自检的 `sim[…]` 都会变。
- 如果这句话**还没有对应的短语**，先在 `PHRASES` 里加一条：`"悬浮": ["flying"],`。

### B.2 第二步：把旗标搬到单位身上

`scripts/units/zombie.gd`：

```gdscript
# 1) 加成员（照抄 execute / armored_downgrade 那几行的写法）
var flying: bool = false

# 2) apply_type() 里读旗标
flying = ZombieDB.has_flag(p_type, "flying")
```

**然后接行为** —— "地面射手打不到它"这件事发生在**射手选目标**的地方，不在僵尸自己身上：

```gdscript
# scripts/core/game_manager.gd —— 所有射手都从这里取目标（豌豆射手也是）
func get_closest_zombie_in_row(p_row: int, from_col: int, allow_behind: bool) -> Unit:
	…
	for u in units:
		if not u.is_zombie or not u.is_alive() or u.row != p_row:
			continue
		## [P26 示例] 飞行单位只有能打空中的射手才锁得到
		var z := u as Zombie
		if z != null and z.flying and not p_can_hit_air:
			continue
		…
```
- 想给"能打空中的射手"开个口：给 `get_closest_zombie_in_row()` 加一个参数（例如 `p_can_hit_air: bool`），
  或者更简单：在**植物脚本**里判断（`Peashooter.find_target()` 自己过滤），这样不用动公共函数。
- 另外别忘了：飞行单位的**入场列**、以及它走到最左列时**照样吃脑子**（`_decide_zombie_act` 不用改）。

其他常见挂钩点：

| 想做什么 | 改哪里 |
|---|---|
| 换一个**新的动作**（跳跃、锤击…） | `Zombie.Act` 枚举加一项 + `set_act()` 的 `match` 加分支（`threshold` / `action_label` / `action_key`）+ `act()` 加实现 + `loc_names.gd` 加 `action.<新动作>` |
| 决定它**下一步做什么** | `GameManager._decide_zombie_act(z)`（现有：吃脑 / 啃 / 跳过 / 前进） |
| 影响**受伤 / 死亡** | `Zombie.take_damage()` / `_check_execute()` / `_break_armor()` |
| 影响**出怪**（额外召唤、投掷） | `GameManager._spawn_wave()` / `_place_zombie()` |
| 影响**掉落** | `GameManager._roll_drop()`（对着 `unit as Zombie` 的名称/旗标判断） |
| 免疫某个状态（例如冻结） | 在状态生效的地方查 `ZombieDB.has_flag(type, "freeze_immune")` |

### B.3 第三步：新状态要自己想清楚"谁在什么时候清掉它"
僵尸没有"每回合重置"的通用钩子，新增状态（冻结回合数、前摇计数…）要自己选时机：
`GameManager._do_turn_start()`（回合开始）、`_do_zombie_action()`（行动前）、`_do_turn_end()`（回合结束）。

### B.4 验收
```bash
timeout 300 godot --headless --path . --quit-after 400 2>&1 | grep -E "\[Zombies\]|zombie data|FAILED"
```
- `[Zombies] zombie_balloon … sim[execute, flying] … | OK`（`sim[]` 里出现新旗标 = 已登记为实装）
- 目视：那一关里气球僵尸**确实不被地面射手打中**（按你的设计）。

---

## 4. 路线 C：加一种植物

### C.1 C1：只进图鉴（5 分钟）
1. `data/units/plants.csv` 加一行（列共 13，照抄一行改值；HP/名称/技能名等共用列在
   `units.csv`，见 P29 分层说明）：
   ```
   寒冰射手	—	冰豌豆	发射冰豌豆，伤害=attack并冻结目标1回合	snow_pea	300	冰封	对同行所有僵尸造成40伤害，并冻结3回合	20	175	4	—	Frozen Pea	…	Deep Freeze	…	—	10%	10%	—
   ```
2. `loc_names.gd` 加 `"plant.snow_pea": {"zh": "寒冰射手", "en": "Snow Pea"},`（**17 种植物现在就都有名字了**，
   只有你新造 id 时才要加）。
3. 贴图可选（在那一行的 `svg` 格子里写相对路径，`docs/UNIT_ART.md` §5.3）。
- 结果：图鉴里出现它，格子上标 **`尚未实装`**，卡片不出现。**不需要碰任何代码。**
- 它的 HP / attack 若留 `—`，会由 `units.csv` 的默认行（`race=plants`）给出；`费用` / `卡片冷却` / 成长若留 `—`，
  由 `plants.csv` 的默认行给出。**要"就是 0"就写 `0`**（见 §1.4）。

### C.2 C2：让它能召唤上场 —— 3 处表行 + 2 处代码

> [P100]/[P102]/[P104] 之前这里是 **8 处**，其中三处是**手抄的代码表**：`PLANT_ATTRS`（成长/药剂/技能字段）、
> `PLANT_CARDS`（卡池与顺序）、`plant_scripts.gd` 的注册表（哪个 id 跑哪个脚本）—— 现已全部删除，改成
> **表派生**（成长读 `plants.csv` 三列、药剂由 `items.csv` 的 `对应植物` 派生、卡池由 `卡片` 列派生、脚本由
> `脚本` 列点名）。所以现在只需要：

| # | 改哪里 | 具体内容 | 漏了会怎样 |
|---|---|---|---|
| 1 | `data/units/plants.csv` | 一行：费用 / 卡片冷却 / 成长 / 技能效果与大招文案 / **[P101] 四个机制列** / **[P102] `卡片` 列写一个数字**（= 它在卡池里的位置） | 图鉴里没有它；不写 `卡片` 数字 ⇒ 只进图鉴、**不能被召唤** |
| 2 | `data/units/units.csv` | 同一单位的行：`HP` / `attack` / **`rarity`** / `技能代码` / `大招代码` / `特殊机制`（`race` 写 `plants/<族>`） | 没有 HP/attack的兜底数值；技能与大招找不到价格与数值；不写 `rarity` ⇒ 该株退回 `PLANT_DEFS` 的级别（`common`），花园名字也就没有自己的颜色 |
| 3 | `data/items.csv` | **卷轴**一行（`分类=scroll`、`对应植物=<id>`）＋ 天赋**药剂**一行（`分类=talent`）。**不用**改 `ITEM_DEFS` / `ITEM_ORDER` / `ITEM_ART` | 卡片永远"没有卷轴"、不能召唤；或这株没有药剂可用 |
| 4 | **新单位脚本** `scripts/units/<id>.gd` | `class_name` + `extends` **基类**（`ShooterPlant` / `ProducerPlant` / `WallPlant` / `PultPlant` / `OneShotPlant` / `SpikePlant`）+ `_init()` 里 `setup_*()` | 没有脚本就只能"数据层存在"（C1）；直接 `extends Unit` 也能跑，但等于把基类写好的开火/索敌/大招/充能再抄一遍（C.3） |
| 5 | ~~`scripts/units/plant_scripts.gd` 注册表~~ | **[P104] 这一处也没有了**：脚本由 `plants.csv` 的 **`脚本` 列**点名（写 `peashooter` → `res://scripts/units/peashooter.gd`；`—` = 没有脚本） | 写错/写空 ⇒ 启动自检 `[Plants] card <id> … \| wired false \| FAIL` 并点名，召唤时回退成豌豆射手（`[WARN]`） |
| 6 | `scripts/core/loc_names.gd` | `plant.<id>`（+ 卷轴/药剂的名字，见 C.4） | 名字显示成 key，日志警告 |
| 7 | `scripts/balance/balance.gd` → `PLANT_DEFS[id]` | `{name, color, art}`：**表里没有的那格**——卡片底色/占位体颜色 `color`，其余是读不到表时的兜底。**[P105] `rarity` 归表了**（`units.csv` 的 `rarity` 列），这里那份只是兜底 | 占位体颜色缺失（有兜底，但很难看）；`rarity` 留空 ⇒ 该株级别退回 `common` |

> **`卡片` 那个数字就是卡池顺序**（[P102]）：1 是图鉴与选卡页里的第一张，默认卡组 = 前 `BATTLE_DECK_SLOTS`（6）张，
> 所以"新卡接在末尾"= 给它下一个数字（想在中途插队就给中间的数，留空隙也行——排序按数字，不按行序）。
> 每张卡后面自动跟着它的**灵界副本**（P95），不用另写。

> 数值（HP / attack / 费用 / 冷却）**不用重复写在 `PLANT_DEFS` 里** ——
> 它们从 csv 读（`Balance.plant_attrs()` 合并），代码里那份只是读不到表时的兜底。
> `PLANT_DEFS` 里**唯一必须写的是 `color`**（卡片底色/占位体颜色，表里没有这一列）；
> **[P105] rarity不在这儿了**：级别写在 `units.csv` 的 `rarity` 格，级别值多少写在 `data/rarity.csv`
> （每级一行：`颜色` + `恢复倍率`，读者 `scripts/core/db/rarity_db.gd`）。留空 = 退回 `PLANT_DEFS` 的 `rarity`（兜底）。
>
> **`rarity` 里写什么**：`common / uncommon / rare / epic / legendary / mythic` 六个 id 之一
> （普通 / 优秀 / 稀有 / 史诗 / 传说 / 神话 ↔ 白 / 绿 / 蓝 / 紫 / 金 / 红）。
> **要加第七级** = 三处、都不碰逻辑：`data/rarity.csv` 加一行、`balance.gd` 的 `RARITY_ORDER` 加一个名字、
> `loc_names.gd` 加一条 `rarity.<id>` 文案；`[Rarity]` 自检会核对"代码说的每一级表里都有行"。
> 药剂两件事都不用写代码：**哪一种药剂**由 `items.csv` 的 `对应植物` 决定，
> **提升哪个数值**由这株自己的技能数值决定（有技能数值 → 技能药剂，没有 → 生命药剂）；
> 也因此"这株没有药剂"= **表里没有它的药剂行**——一次性家族就是这么表达的（P100）。
>
> **[P30-A] 技能的 AP 价格在技能表 `data/units/skills.csv`**（`技能名称` `技能描述`
> `技能消耗AP` `技能代码`）：新技能要加一行，并在脚本里 `const SKILL := "<技能代码>"`。
> 忘了加行不会坏（未知代码默认 1 AP），但价格就只能改代码了；改格子后按 `R` 重读。
>
> **植物机制是 `plants.csv` 末尾那四列，不是散文**（[P101]）。`特殊机制` 那句话是给玩家看的
> 文案，**决定玩法的是四个格子**（写 `是` 打开，`—` 关闭）：

| 列 | 打开的规则 | 谁读它 |
|---|---|---|
| `一次性` | 行动一次就下场（血量与卡冷却另算，见 §6 的坑） | `PlantDB.is_one_shot()` + 一次性脚本族 |
| `溅射` | 投手的落点波及上下左右四格（伤害按 `PULT_SPLASH_RATIO`） | `PultPlant` |
| `僵尸相邻` | 有僵尸贴在同一行相邻一格时停止attack（胆小菇） | `ScaredyShroom` |
| `不会被啃食` | 站在它格子上的僵尸不会啃它（地刺） | `SpikePlant` → `Unit.ignores_biting` |

> **规则与散文必须一致**：`[Plants]` 启动自检会把两边对一遍，凡是"句子写了这四个词、列却没打开"
> 或反过来（列打开了、句子没写）都会**报 FAIL 并点名那一行**——这条红线就是 [P101] 存在的理由
> （以前一句话被改写，机制就静默消失）。想表达"不溅射"就别在中文句子里用「溅射」这两个字
> （英文孪生列随便写，交叉检查只读中文那句）。
> 卷心菜投手仍是现例子：它与西瓜同族、同一套基类，但那一行的 `溅射` 是 `—`，于是它不溅射、
> 大招也只落本行。

### C.3 [P34] 能用基类的植物：只填参数（照抄这个）

先看看"一个会开枪的新植物"现在到底要写多少行 —— 真的寒冰射手（`scripts/units/snow_pea.gd`，全文 27 行）：

```gdscript
class_name SnowPea
extends ShooterPlant

const SKILL := "snow_pea_fire"          # skills.csv 的 技能代码
const ULTIMATE := "deep_freeze"

func _init() -> void:
	hit_effects = {"freeze": 1}         # 命中 rider：射弹替你把冻结带给僵尸
	shot_tint = BalanceUI.COLOR_FREEZE  # 纯呈现，所以来自 BalanceUI
	setup_shooter("snow_pea", SKILL, ULTIMATE)

func act_ultimate() -> String:
	return fire_row_storm({"freeze": 3})   # 还是那条横扫，只是冰层更厚
```

`ShooterPlant` 让子类填的就是这几个**身份**参数（数值一个都不在这张表里 —— HP/attack/费用/冷却/AP/大招数值全在 `data/units/*.csv`，AGENTS.md §2）：

| 参数 | 含义 | 这一批里谁用了 |
|---|---|---|
| `shot_count` | 一次行动朝前打几发 | repeater 2 / gatling 4 |
| `back_shots` | 反向几发（`Projectile` 的 `dir`） | split_pea 1 |
| `row_offsets` | 覆盖哪几条行（相对自己；越界的行自动少打一发） | threepeater `[-1, 0, 1]` |
| `range_cells` | 射程几格，`0` = 整行 | 两个喷菇 `3` |
| `targets_all_in_range` | 打范围内**全部**（真）还是最近 1 只（假） | fume_shroom `true` |
| `hit_effects` | 命中挂的状态 riders：`{"freeze": 回合数}` | snow_pea |
| `pierce_armor` | 伤害直接吃血量，护甲不吸收 | fume_shroom（无视铁门） |
| `shot_tint` | 弹色 | snow_pea / 三株投手各一节 |
| `shot_class` | 用哪个射弹类（默认 `PeaProjectile`）；[P77] 换类同时换了"铁门挡不挡它"的答案 —— `PultProjectile` 自带 `straight_shot = false` | 投手的 `setup_pult()` 替你换 |
| `ult_own_effects` / `ult_side_effects` | 大招本道 / 邻道挂的 riders | winter_melon（2 / 1 回合冻结） |

五个基类各管一摊（`scripts/units/base/`）：
- **`ShooterPlant`**（`scripts/units/base/shooter_plant.gd`）：索敌、齐射、大招横扫、充能。
- **`ProducerPlant`**：每回合产出 × `produce_count`（阳光/物品），例 `twin_sunflower.gd` 只写了一行 `produce_count = 2`。
- **`WallPlant`**：不还手、靠挨打充能；唯一要填的是 `immunity_rounds`（大招无敌几回合），例 `tallnut.gd`。
- **`PultPlant`**（[P49]，`pult_plant.gd`）：抛掷家族 = `ShooterPlant` + 抛物线弹体 + 溅射落点。
  子类只说 `shot_tint` / `hit_effects` / `ult_own_effects` + `ult_side_effects`。
  **注意"溅不溅射"不在这张参数表里**（[P51]/[P101]）：它由 `plants.csv` 那一行的 `溅射` **列**（不是
  `units.csv` 那句散文）决定（`PlantDB.has_splash()`），于是卷心菜投手 `cabbage_pult.gd` 连一个机制都没写。
- **`OneShotPlant`**（[P39]，`one_shot_plant.gd`）：一次性植物（放下去、炸掉、自己下场）。
  `setup_one_shot(ID, SKILL, ARM_ROUNDS)` 之后必答一题 **`blast_targets()`**（打谁），
  可答两题 **`blast_effects()`**（挂什么状态）与 **`blast_cue`**（哪一声，`""` = 静音），
  例 `cherry_bomb.gd` 答"九格全炸 + 专用 crater 声"、`ice_shroom.gd` 答"零伤害 + 全屏冻结 + 静音"。

**大招想多扫几行、或比普攻打得更远**时，改查询而不是抄 `act_ultimate()`：

```gdscript
func storm_rows() -> Array:                    # 我扫哪几条行
	return target_rows()                         #   三线射手 = 自己那三条

func storm_lane(p_row: int) -> Array:          # 一条行里打谁
	return game.get_zombies_in_row(p_row) if game != null else []
                                               #   大喷菇的毒雾 = 整行，不是那 3 格
```

这两个钩子同时被 `ult_can_fire()` 用着，所以只改它们就顺带修好了"条满了却喊没目标"的判断。

`Projectile.fire(cls, shooter, target, damage, opts)` 的 `opts` 现在认识
`row` / `dir` / `tint` / `effects` / `pierce_armor` / `pierce` / `from_offset` / `speed`
（[P49] 抛掷用的两个）/ `splash`（[P49] 落点四邻各吃几成）/ `sfx` + `sfx_hit`（[P50] 起飞与命中各一声）；
命中有**两条路径**（回合动画的 `_strike()` 与 fast-forward/自检的同步 `_resolve_now()`），
两条都会应用 `effects` 与 `splash`，所以新 rider 只要在 `opts` 里递进去，不用碰射弹代码。

### C.3b 基类表达不了时，才从 `Unit` 写起

> 下面这份是抽基类**之前**的模板（`extends Unit` + 手写 `_init()` 的每一行）。今天加一个射手**不要**照它抄；
> 而且"基类没有的参数"这份名单本身在缩短：一次性植物（[P39] `OneShotPlant`）与抛物线溅射
> （[P49]/[P51] `PultPlant`）如今**都有了基类**。目前真的还得从 `Unit` 自己写的，
> 是南瓜套种这类"改变格子本身规则"的植物（它不在 `Unit` 上加参数，而是动 `grid` / `garden`）。
> 注意其中关于 **freeze 的 ★ 说明已经过时**：`Zombie.effect_rounds` / `apply_hit_effects()` /
> `_do_zombie_action()` 里的跳过与递减、以及 `opts.effects` 这条命中挂钩，[P34] 都已经实装了。

```gdscript
class_name SnowPea
extends Unit
## 寒冰射手：豌豆射手的冰版，额外给目标上"冻结 N 回合"。（[P26] 示例骨架）
##
## 命中伤害走 Balance.plant_skill_value/plant_base_skill（数值来自 plants.csv 的「attack」列），
## 所以这里不再写死任何伤害数字。

## [P30-A] 技能代码 = skills.csv 的 技能代码 列（表里要配套加一行；未知代码兜底 1 AP）
const SKILL := "snow_pea_fire"

func _init() -> void:
	set_display_name("plant.snow_pea")           # [P20] 语言层的键
	is_zombie = false
	body_shape = Shape.CIRCLE
	body_color = Balance.COLOR_SNOW_PEA          # ★ 需要在 balance.gd 里定义这个颜色
	body_size = Balance.UNIT_BODY_SIZE
	art_path = Balance.plant_art("snow_pea")     # 贴图（见 docs/UNIT_ART.md）
	max_hp = Balance.plant_max_hp("snow_pea")    # 生命上限（来自 csv，随等级/天赋变）
	hp = max_hp
	threshold = BalanceBattle.skill_ap_cost(SKILL)     # [P30-A] 每次施放花的 AP（读技能表，兜底 1；3 点 AP/回合 → 每回合最多 3 次；植物下方不画条）
	action_label = "FIRE"
	action_key = "action.fire"
	skill_value = Balance.plant_base_skill("snow_pea")


func has_target() -> bool:
	## 没有目标就不施放（同豌豆射手；AP 记账，没有条要攒）
	return find_target() != null


func has_skill() -> bool:
	return true


func resolve_skill_once() -> bool:
	## 能量豆用：立刻结算一次技能
	if find_target() == null:
		return false
	act()
	return true


func find_target() -> Unit:
	if game == null:
		return null
	return game.get_closest_zombie_in_row(row, col, BalanceBattle.PEASHOOTER_SHOOTS_BACKWARD)


func act() -> String:
	var target := find_target()
	if target == null:
		return "-> FIRE but no target (should not happen)"
	var before := target.hp
	var damage := skill_value if skill_value > 0 else Balance.plant_base_skill("snow_pea")
	## [P33] 调参即开火：飞行、沿线碰撞、伤害、回合动画记账全在射弹类里
	## （scripts/projectiles/）。冷色只需要递一个 tint。
	Projectile.fire(PeaProjectile, self, target, damage,
		{"from_offset": BalanceUI.PEA_MUZZLE_OFFSET, "tint": BalanceUI.COLOR_SNOW_PEA})  # ★ 自己加的呈现常量
	# ★ 冻结是"新机制"：豌豆现在把伤害带在碰撞瞬间结算，freeze 也必须搭在
	#   同一击上——给 Projectile._strike() 加一个命中挂钩（或射弹 rider 字段），
	#   不要在 act() 里同步调用；还需要 Zombie 上的 frozen_rounds 成员，
	#   并在 GameManager._do_zombie_action() 里跳过被冻结的僵尸、回合开始递减。
	return "-> FROZEN FIRE %d -> %s(%d,%d) hp %d (damage on impact)" % [damage,
		target.tag(), target.col, target.row, before]
```

配套的数据改动（[P104] 起注册表就是表里那一格）：
```csv
name	…	脚本
snow_pea	…	snow_pea
```
`GameManager._script_for()` 查 `PlantScripts.script_for()`（它按 `脚本` 格 `load()`，带缓存）；
查不到时打 `[WARN] no script registered for '<id>'` 再回退豌豆，而启动自检
`[Plants] card <id> … | wired false | FAIL` 会先把漏接线喊出来。

### C.4 卷轴（必须）与天赋药剂（可选）

**[P100] 只改 data/items.csv，两行**（代码一处都不用动）：

```csv
名称	name	分类	price	对应植物	svg
寒冰射手花园卷轴	scroll_snow_pea	scroll	3	snow_pea	items/scroll
寒冰射手药水	potion_snow_pea	talent	—	snow_pea	items/potion/potion_talent_common
```

- `分类=scroll` 的那行是**卷轴**（`price` 格是耐久，见 `ItemDB`）：`Balance.scroll_item_for("snow_pea")`\
  与 `plant_potion_item("snow_pea")` 都按 `对应植物` **扫表**找，仓库/商店列的是 `Balance.item_ids()`。
- `分类=talent` 的那行是**天赋药剂**：有这行 = 这株能吃药；没有 = 花园里对它用药会被拒（一次性家族就是没有）。
- 图标：卷轴共用 `items/scroll`，药剂共用档位通用瓶 —— 都写在 `svg` 列里，**不用**碰 `ITEM_ART`。
- 药剂**提升哪个数值**不用写：有技能数值的给技能药剂，没有的给生命药剂（`PLANT_TALENT_BOOST` 是 50% 的兜底）。

再补两三条文案（`loc_names.gd`）：`item.scroll_snow_pea`、`item.potion_snow_pea`、（有天赋的话）`talent.potion_snow_pea`。

### C.5 让它有出场途径（至少给一条，否则玩家永远拿不到它）
| 途径 | 改哪里 |
|---|---|
| **关卡奖励** | `data/level/Lawn_*.json` 的 `rewards` 里 `{ "chance": 0.25, "plant": "snow_pea" }`（走 `garden.add_plant`，要求 `PLANT_DEFS` 有它） |
| **首通奖励（物品）** | 同文件的 `first_clear`: `{ "scroll_snow_pea": 1 }` —— **P93 起不再当场发**：它进关卡列表上那只**宝箱**，点开才拿到 |
| **首通奖励（植物）** | 同文件的 `first_clear_plant`: `"snow_pea"` —— [P94] 一株植物进**花园名册**（不是仓库），所以它有自己一个键；名字必须是 `PLANT_CARDS` 里的卡，否则关卡自检报 problem 并忽略 |
| **商店** | `BalanceShop.SHOP_STOCK` 加 `{"kind": "plant", "id": "snow_pea", "price": 300}` |
| **开局就有** | `BalanceGarden.GARDEN_START_ROSTER`（慎用，会改新玩家的开局体验） |

### C.6 卡片数量与热键的边界（[P34] 起：热键认卡位，不认植物）
- HUD 底部一行放的**不是整个 `PLANT_CARDS`**，而是这一战的**出战卡组** `Game.battle_cards()`：
  选卡页确认的那几张；没人选过时，回退**卡池的前 `BalanceBattle.BATTLE_DECK_SLOTS` 张**（= 6）。
  卡池以后有一二十张卡，而 `layout.gd` 压窄卡片有下限（`MIN_CARD_WIDTH` = 96px），
  全塞进去就会挤爆 1280，所以这条上限是**卡栏的宽度**，`DECK_HOTKEY_KEYS` 也是这几个键。
- **键 = 卡位**：`KEY_1..6` 依次武装 `battle_cards()` 里的第 1..6 张（`Game._select_deck_card`），
  工具栏挪到 `KEY_8` / `KEY_9` / `KEY_0`（`BalanceBattle.TOOL_HOTKEY_KEYS`，按 `TOOL_CARDS` 顺序）。
  卡片标题上那个数字由 `hud.gd._plant_hotkey()` 现算，**不再存在 `PLANT_DEFS` 里** ——
  同一张卡在不同卡组里可以是 1 也可以是 4。新植物**不需要**也**不能**给自己声明一个键。
- 想超过 6 张的宽度：同时改 `BATTLE_DECK_SLOTS`、`DECK_HOTKEY_KEYS` / `DECK_HOTKEY_LABELS`，
  并确认 1280 宽还放得下（`Layout.card_size` 的下限）。
- 战役（run）战斗的卡组由**编队**决定：`Game._squad_deck()` 把编队里的植物名称（含它们的灵界复制卡）
  交给 `battle_cards()`，所以 squad 上限 `RUN_SQUAD_SLOTS` 必须 ≤ `BATTLE_DECK_SLOTS`。
- 每次 `TURN_START` 卡片充能 +1（`_charge_plant_cards`），充满才可召唤；**一回合的召唤总额度**由关卡
  `summons_per_turn` 决定（默认 1 张）。

### C.7 验收
```bash
cd /home/wing/Projects/Games/pvz
godot --headless --path . --script res://tools/member_name_check.gd 2>&1 | grep -E "\[Names\]|Parse Error"

timeout 300 godot --headless --path . --quit-after 400 2>&1 \
  | grep -E "\[Plants\]|\[Data\]|\[Loc\]|self-check|zombie data|level data|FAILED|SCRIPT ERROR"
```
期望：
- `[Names] … 0 collision(s) | OK`（新脚本的成员名没撞原生成员）；
- `[Plants] snow_pea … art … | OK` 与 `[Plants] card snow_pea sheet cost 175 cd 4 hp 300 atk 20 | wired True | OK`；
- `[Loc] … PASSED`（新词条中英双语齐全、占位符一致）；
- 进游戏后：卡片出现、有卷轴、能召唤、技能按 `plants.csv` 的数值生效。

---

## 5. 一张打勾表（C2 全流程）

```
□ data/units/plants.csv            新增一行（费用/冷却/HP/attack/成长…）
□ data/units/units.csv             同一单位的行：技能代码 / 大招代码 两格（[P30-A]/[P30-B]）
□ data/units/skills.csv            技能行（AP 价格）＋ 大招行（数值/充能来源）
□ data/items.csv                   卷轴与药剂各一行（svg 格子 = 图标来源）
□ loc_names.gd                     plant.<id>（+ item.scroll_<id> / talent.potion_<id>）
□ scripts/units/<id>.gd            新单位脚本：extends 基类 + setup_*（见 C.3）；没基类能表达才 extends Unit（C.3b）
□ plants.csv → 卡片 列              写一个数字（= 卡池位置）；不写就只进图鉴
□ plants.csv → 脚本 列              写脚本名（= scripts/units/<名字>.gd）；不写就只进图鉴
□ units.csv → rarity 列             写 common / uncommon / rare / epic / legendary / mythic
                                   之一；留空 = 退回 PLANT_DEFS 的兜底级别（[P105]）
□ balance.gd → PLANT_DEFS[id]      color（占位体颜色；数值会从 csv 覆盖，rarity 也归表了）
□ data/items.csv                   卷轴（必须）＋ 天赋药剂（可选）两行：[P100] 起不用再动 ITEM_DEFS /
                                    ITEM_ORDER / ITEM_ART，也不用写成长与药剂字段（表派生）
□ balance.gd → 颜色常量            新植物的 COLOR_*（卡片底色、色块兜底）
□ （可选）贴图                     assets/svg/units/... + csv 的 svg 格子写相对路径
□ （可选）出场途径                 关卡 rewards / first_clear / SHOP_STOCK
□ 跑 member_name_check + 启动自检
□ 目视：卡片 / 召唤 / 技能 / 图鉴 / 花园
```

僵尸只要第 1、2、□（贴图）、（关卡点名）四步，机制另算（路线 B）。

---

## 6. 常见坑（都踩过或很容易踩）

| 现象 | 原因 | 处理 |
|---|---|---|
| 新植物召唤出来是**豌豆射手** | `plants.csv` 的 `脚本` 列写错或留空（找不到文件就回退豌豆） | 填对 `脚本` 格（启动自检 `[Plants] ... wired False` 会先报，日志里还会有一行 `Attempt to open script … File not found`） |
| 卡片一直是**"没有卷轴"**（灰的） | `data/items.csv` 里没有它的卷轴行（或 `对应植物` 写错） | 加一行 `分类=scroll`、`对应植物=<id>` |
| 仓库/商店里**看不到**那张卷轴 | 同上：列表读的是**表**（`Balance.item_ids()`） | 确认那一行的 id 拼写与 `分类` |
| 花园里对这株用药被拒（"没有天赋药水"） | `data/items.csv` 里没有它的 `分类=talent` 行 | 加一行（一次性家族**故意**没有，别补） |
| 名字显示成 `plant.snow_pea` 这种 key | `loc_names.gd` 少了词条 | 补中英两条 |
| 图鉴/日志说 `overrides Balance: hp …` | 你在 csv 里改了数值，代码常量还是旧值 | **这是正常的**（表覆盖代码）；只有 `wired True` 才算接线正常 |
| 改了 csv 但**游戏里没变** | 没重读表 | 按 `R`（或重启） |
| 关卡里某只僵尸变成普通僵尸 | 关卡里 `type` 写错 | 看 `unknown zombie type … -> 'zombie'` 那行，改成正确的 id |
| 图鉴写 `尚未实装` / `部分未实装` | 植物没有单位脚本 / 僵尸的机制没实现 | 走路线 B、C2 |
| 图鉴写 `暂无贴图` / 那行自检标 `NOT IMPORTED` | csv 的 `svg` 格子空着（`—`），或写错了、或文件还没画出来 | 见 `docs/UNIT_ART.md` §5.3（格子里写相对路径，不带 `.svg`） |
| 脚本一加载就 **Parse Error: Member "ready" redefined** | 公开成员名撞了 Godot 原生成员 | 改名，并用 `tools/member_name_check.gd` 先验 |
| 整个文件读不出来 / 列**错位** | csv 里某格**留空**而不是写 `—` | 补 `—`；数一下每行的列数是否一致：<br>`awk -F'\t' '{print NR": "NF}' data/units/plants.csv`（表头宽度：[P113] 起 **units 30**（权威列清单看 `unit_sheet.gd` 的 `COL_*`）；⚠ **行尾空格子可省**，所以短行的 NF 小于表头宽是**正常**的，读按列名走） |
| 僵尸/植物**数值**改了但图鉴对不上 | 图鉴读的是 csv，战斗也读 csv —— 两边本来就一致；若不一致说明表没读到 | 看启动的 `[Data] plants: … row(s)` 与 `[Plants] sheet not loaded` |

---

## 7. 一句话总结

- **加僵尸**：csv 一行 + 名字一条（+ 关卡点名）；机制从"只显示"到"真生效"才需要碰代码。
- **加植物**：先决定要不要能召唤；要能召唤就是"**数据 + 脚本 + 卡片 + 卷轴**"四件套，一张打勾表（§5）。
- **数值与贴图永远写在 csv**（数值列 + `svg` 列），代码里的同名常量与 `PLANT_ART` / `ZOMBIE_ART`
  只是读不到表时的兜底。

---

## 8. 关卡与数据表（原 README 的「加一个关卡 / 波次格式 / 单位数据表 / 道具表 / 僵尸护甲」）

> **形状**（字段清单、列名、解析容错）在 `PROMPT.md` §5（关卡）与 §4（单位 / 道具）；
> 这一节只讲"怎么动手加"。

### 加一个关卡

关卡包放在 **`data/level/`**，命名是 **`Lawn_<大关>_<小关>.json`**（现在是 `Lawn_1_1` … `Lawn_1_8`）。
往这个目录里丢一个新的 `Lawn_*.json`，重进 **ADVENTURE** 就会多一行 —— 不需要改代码，也不需要清单文件。

- 目录里**只要有一个 `Lawn_*.json`**，其它不按这个命名的 `*.json` 就会被**跳过**（原因见启动日志的
  `[Levels] skipped:` 行）。所以旧的 `level_01.json` / `level_02.json` / `level_03.json`
  还留在磁盘上、但**不会出现在关卡列表里**；把 `Lawn_*.json` 全部删掉，目录又会变回"任何 `*.json` 都算关"。
- **解析不了的关卡不会被藏起来**：它照样出现在列表里，灰色、右边标 `数据错误` / `BROKEN`，行里写着原因
  （空文件、JSON 语法错、`waves` 里没有一条能用的出怪…），图鉴的「关卡」页会写得更详细。
- `waves` 不能是空数组；每一关的写法见下面「关卡的波次格式」。

### 关卡的波次格式

```jsonc
"waves": [
  { "id": 1, "start_round": 1, "spawns": [
      { "round": 1, "type": "zombie", "count": 1 }
  ]},
  { "id": 4, "start_round": 20, "spawns": [
      { "round": 20, "type": "zombie_cone",  "count": 2 },
      { "round": 24, "type": "zombie",       "count": 3, "cols": [7, 8] }
  ], "banner": true }
]
```

| 字段 | 含义 |
|---|---|
| `id` | 波次编号（只用于报错信息与图鉴显示） |
| `start_round` | 这一波从第几回合开始（**只用于说明**；真正决定出怪时刻的是每条 `spawns[].round`） |
| `spawns[].round` | 第几回合放这批僵尸 |
| `spawns[].type` | **僵尸名称 id**，取值来自 `data/units/zombies.csv` 的 `name` 列（`zombie` / `zombie_cone` / `zombie_bucket` …）。**写错会被替换成 `zombie` 并在日志与图鉴里报出来** |
| `spawns[].count` | 这批几只 |
| `spawns[].cols` | 可选：这批**从哪些列入场**（覆盖关卡顶层的 `spawn_cols`） |
| `banner` | 可选：`true` = 这一波显示「一大波僵尸正在接近！」而不是普通的「N 只僵尸来袭」 |

- **同一回合可以有多条 `spawns`**，也可以两条波次重叠 —— 这就是关卡加压的方式。
- **格子不够就顺延**：某一列被占满时，这一批**剩下的僵尸延后到下一回合**（名称不变），日志里写
  `delayed to the next round`。
- 顶层还有一个 **`zombie_hp`** 字段（老文件里叫"僵尸血量"）：它现在表示**普通僵尸的血量基准**，
  关卡里所有僵尸的血量与护甲都按 `本关 zombie_hp ÷ 270` 等比缩放，再乘难度系数。
  要整关加厚就改这一个数（例：`405` = 全部僵尸与护甲 ×1.5）。
- 旧格式 `{ "round": 3, "zombies": 2 }` **仍然能读**（等价于 `type: "zombie"`），老文件不用改。

### 单位数据表（`data/units/plants.csv` / `zombies.csv`）

植物的**数值与文案**来自 `data/units/plants.csv`，僵尸的来自 `data/units/zombies.csv`。
两张表都是 **TAB 分隔**，带中文表头，**按列名读取**（列顺序可以改、可以在中间插列）：

| 文件 | 列 |
|---|---|
| `plants.csv` | `name`（= 代码里的 id） `技能效果` `大招` `大招效果` `费用` `卡片冷却` + 英文孪生列 + `HP成长` `技能成长` `天赋加成` + **[P101] 四个机制列 `一次性` `溅射` `僵尸相邻` `不会被啃食`（`是`/`—`）** + **[P102] `卡片`（卡池位置数字，`—` = 只进图鉴）** + **[P104] `脚本`（实现它的文件，`—` = 只有图鉴）**（`HP` / `attack` / `天赋` / `技能` / `svg` / `tscn` 在 `units.csv`） `特殊机制` + 每段文案的英文列（`技能英文` `技能效果英文` `大招英文` `大招效果英文` `特殊机制英文`）+ 三个可选的成长列 `HP成长` `技能成长` `天赋加成` |
| `zombies.csv` | `name` `护甲` `移动` `啃脑伤害` `召唤间隔` `召唤数量` `召唤单位` `锤击前摇` `锤击后摇` `暴怒移动` `暴怒attack`（`HP` / `attack` / `天赋` / `技能` / `特殊机制` / `svg` / `tscn` 在 `units.csv`） + 可选的 `啃脑伤害` + 机制的机器可读格：`召唤间隔` `召唤数量` `召唤单位`（P47）、`锤击前摇` `锤击后摇`（P48）、`暴怒移动` `暴怒attack`（P68） |

- **`svg` 列（P28）= 这个单位的贴图**：写**相对路径**，等价于
  `res://assets/svg/units/plants/<值>.svg`（植物）/ `res://assets/svg/units/zombies/<值>.svg`（僵尸），
  **不写 `.svg` 后缀**：`pea/peashooter`、`sunflower`、`mushroom/mushroom_sun`、`zombie_cone`、
  `water/zombie_ducky`。格子里直接写完整 `res://…` 或带 `.svg` 后缀也认。
  写 `—` 表示"这一行没有自己的图"（植物画色块、僵尸画普通僵尸那张图）。
  文件还没画出来**不算错**：图鉴写 `暂无贴图`，启动日志里那行标 `NOT IMPORTED`（细则见「单位贴图怎么被选中的」）。

- **`tscn` 列（P28）= 这个单位的「场景」，比 `svg` 更优先**：写**相对路径**，等价于
  `res://scenes/units/plants/<值>_view.tscn`（植物）/ `res://scenes/units/zombies/<值>_view.tscn`（僵尸），
  **不写 `_view.tscn` 后缀**：`peashooter` → `res://scenes/units/plants/peashooter_view.tscn`。
  格子里直接写完整 `res://…tscn` 也认；写 `—` 表示"这一行没有场景"，就用 `svg` 列的贴图。
  场景**加载成功就用场景**（并尝试播它的 `idle` 动画），**加载不到就退回贴图**、再退回色块 ——
  见「单位场景（`tscn` 列，P28）」。

- **`range_type` / `role` 列（[P113]，`units.csv` 的共用列）= 人对单位的两个分类标签**：
  闭合词表 `range_type` ∈ `melee` / `range`，`role` ∈ `dps` / `tank` / `healer` / `support`，
  存英文码（与 `rarity` 同族），中文显示走 `Loc`（`unit.range.*` / `unit.role.*`），**每条单位行都填、`default` 留空**。
  ⚠ **它们是标签、不驱动行为**：远程判定仍归 `BrawlActor.is_ranged()`（=`shot_id()!=""`）、
  治疗索敌仍归 `projectiles.csv 治疗`。读取器 `UnitSheet.range_type()` / `role()` 照 `face` 那套闭合表，
  拼错就 `note_complaint` 并安全兜底；开机 `[Data] units` 那行带两组计数。**显示只在图鉴单位页的描述块**
  （`almanac.desc.unit_tags`，「距离 … 定位 …」），不是面板固定行（9 行已到呼吸下限）。
- **空格子写 `—`**（破折号），不要留空 —— 留空会让列数对不上，而那是最难查的一类数据错误。
- 英文列可以缺：缺了就退回中文原文，启动日志会统计 `N prose field(s) with no English twin`。
- **可选列写 `—` = "按代码默认值走"**：`HP成长`/`技能成长`/`天赋加成`/`啃脑伤害` 留 `—` 时分别用
  `balance.gd` 的 10% / 10% / 50% / 10（`ZOMBIE_BRAIN_DAMAGE`）。成长类格子写 `10%` 或 `0.1` 都行
  （带 `%` 或大于 1 的数字按百分比算）。

#### 技能表（`data/units/skills.csv`，P30-A）

技能自己的数据，TAB 分隔，**八列**：`技能名称` `技能描述` `技能消耗AP` `技能代码`，
以及 P30-B 的大招四列 `大招名称` `大招描述` `大招数值` `大招充能`。

- **技能代码**是代码与表的接头：植物脚本在 `scripts/units/<id>.gd` 里写
  `const SKILL := "<技能代码>"` 作为**默认装载**；单位表 `data/units/units.csv` 另有
  **`技能代码` 列（P30-A4）**，写了就以表为准（空格子或表里没有的代码回退脚本默认，
  见 `Balance.plant_skill_code`）。改一格的 `技能消耗AP` 就能给某个技能重新定价
  （价格 > 3 等于"永不行动"，因为 AP 不跨回合）。
- **大招是独立的行（P30-B）**：一个 `技能代码` 一行，`大招名称` 有值的行就是**大招行**
  （它的 `技能消耗AP` 等三格写 `—`，大招不吃 AP，由充能条计价）。植物装载哪个大招，
  看 `units.csv` 的 **`大招代码` 列**（脚本的 `const ULTIMATE` 只是兜底，见
  `Balance.plant_ult_code`；表里查无此码 = 不装载、不画条）。`大招数值` 给数、
  `大招充能` 说"施放还是受击来充"，具体效果仍由代码执行（规则见「大招进度条」）。
- 图鉴的单位详情面板有**「行动序列」行（P30-A4）**：植物显示装载中的技能名 + 每次 AP
  价格，后面接大招名 + 充能规则（`充能 +1/10 · 每次施放`，P30-B）；僵尸显示固定的
  移动/啃咬/啃脑 三动作价格。这是"查看"；将来玩家**改装载**写的就是 units.csv 这两列
  （同一入口 `Unit.skill_code` / `Unit.ult_code`）。
- 读表由 `scripts/core/db/skill_db.gd`（`SkillDB`）负责，启动与 `R` 键都会重读，
  日志前缀 `[Skills]` / `[Data] skills:`；表读不到时退回 `balance.gd` 的
  `SKILL_AP_COST` 兜底表（未知代码 = 1 AP）与 `ULTIMATE_VALUE` 兜底数值，不致命。
- **僵尸不入表**：移动 3 / 啃咬 1 / 啃脑 1 / 撑杆 1 AP 是所有僵尸共用的一条全局规则，
  留在 `balance.gd`（`ZOMBIE_*_COST`）；僵尸也**暂不做大招**（P30-B 确认范围）。

#### 哪些数值真的进了游戏（P26 起）

| 表里的列 | 战斗里用它做什么 | 代码里还剩什么 |
|---|---|---|
| 植物 `HP` | **生命上限**：棋盘单位、花园初始值、每级 +成长、天赋加成，全部经 `Balance.plant_attr_hp()` | `PEASHOOTER_HP` 等常量退为**读不到表时的兜底** |
| 植物 `attack` | **技能值**：豌豆每发伤害、向日葵每次产阳光（`Balance.plant_base_skill()`） | 同上；**空格子 = 这株植物没有技能**（坚果墙） |
| 植物 `费用` / `卡片冷却` | 卡片标签、召唤扣费、冷却回合（`plant_def()` / `plant_cost()` / `plant_card_cooldown()`） | 同上（关卡 json 的 `cards` 仍可覆盖冷却） |
| 植物 `HP成长` / `技能成长` / `天赋加成` | 升级曲线与天赋药剂强度 | 兜底是 `PLANT_HP_GROWTH` / `PLANT_SKILL_GROWTH` / `PLANT_TALENT_BOOST`（P100 起没有 `PLANT_ATTRS` 了） |
| 植物 `脚本` | **这行由哪个文件实现**（`peashooter` → `scripts/units/peashooter.gd`）；`—` = 没有脚本 | 卡池里没有它；`[Plants] wired false` 判据报红（P104） |
| 植物 `卡片` | **这行是不是卡、在卡池里排第几**（数字越大越靠后；`—` = 只进图鉴） | 卡池 = 有数字的行 + 每张的灵界副本（P102；代码兜底 `PLANT_CARD_FALLBACK`） |
| 植物 `技能` / `大招` / `大招效果` / `特殊机制` | 图鉴文案（散文，不决定机制） | 机制看 **`plants.csv` 那四列**（P101）；技能**名称**（FIRE/PRODUCE/无）与一次性植物的行为仍是代码 |
| 僵尸 `HP` / `护甲` / `移动` / `attack` | 出怪时的血量（按关卡 `zombie_hp` × 难度缩放）、护甲层、前进条长度、啃食伤害 | `ZOMBIE_HP` / `ZOMBIE_BITE_DAMAGE` / `ZOMBIE_ADVANCE_THRESHOLD` 退为兜底 |
| 僵尸 `啃脑伤害` | 走到最左列后每次吃脑子的伤害 | `ZOMBIE_BRAIN_DAMAGE` 是 `—` 时的默认值 |
| 僵尸 `召唤间隔/召唤数量/召唤单位`（P47）、`锤击前摇/锤击后摇`（P48）、`暴怒移动/暴怒attack`（P68） | 机制的**数字**：句子里有这个词而这几格没填 ⇒ 该机制**不生效**（`simulates()` 按行判定），启动日志另打 `summon/smash/rage gap` | 数值全在表里，代码里没有对应常量——所以填了格子就换了规则 |
| 僵尸 `特殊机制` | 短语表翻译成机制旗标（处决 / 破甲降级 / 撑杆跳 / 掉钻石 / 免疫冻结 / 铁门两条 / 召唤 / 锤击 / 暴怒） | 机制的**实现**是代码；没实装的在图鉴里写明 |
| 两张表的 `svg` | **这个单位的贴图路径**（棋盘 / 卡片图标 / 花园 / 图鉴 / 药剂标记全走它），经 `Balance.plant_art()` / `zombie_art()` | 表读不到时退回 `Balance.ART_PLANT` / `ART_ZOMBIE`（通用的植物 / 僵尸图） |
| 两张表的 `tscn` | **棋盘上这个单位画哪个场景**（有场景就不再画贴图），经 `Balance.plant_view()` / `zombie_view()`；场景里的 `idle` 动画会被播起来 | 空 `—` 或场景文件还没做 → 回到 `svg`；都没有 → `Unit._draw_body()` 的色块 |

- `scripts/balance/balance.gd` 的同名常量现在**只是兜底**，两张表各自的自检检查的是**接线**：
  战斗解析出来的值必须等于表里的值；表和常量不一致时会打印 `overrides Balance: hp 300->500`（**不是** `FAIL`，
  因为"表覆盖代码"正是设计意图）。
- **改了表要让它生效**：游戏里按 **`R`**（重开当前关卡）会**重新读两张表**，并把花园里每株植物的生命上限
  按新数值重算（满血的保持满血、受伤的保留伤势）；不按 R 的话表只在启动时读一次。
- **加一种植物**：在 `plants.csv` 加一行 + 在 `scripts/core/loc_names.gd` 加一条名字（中英双语）。
  如果战斗里还没有它的单位脚本，它会在**图鉴里标成"尚未实装"**、卡片也不会出现 —— 不会出现"游戏崩了"。
- **加一种僵尸**：在 `zombies.csv` 加一行 + 一条名字；**立刻就能在关卡 json 里用 `type` 点名**。
  它的**机制**（跳跃 / 破甲 / 飞行…）要看 `scripts/core/db/zombie_db.gd` 的 `PHRASES` 与
  `FLAGS_SIMULATED`：没实装的机制图鉴会写明"未实装"，战斗里只按数值走。
- **完整的「加一个角色」步骤在 `docs/ADD_UNIT.md`**：僵尸（只加数据 / 加新机制两条路线）、
  植物（只进图鉴 / **能召唤上场**的完整清单）、可照抄的单位脚本模板、打勾表、常见坑与验收命令。

### 道具表（`data/items.csv`，P27）

**图鉴的「道具」页**由 `data/items.csv` 提供，同一张 TAB 分隔、带中文表头的表，**按列名读取**：

| 列 | 作用 |
|---|---|
| `名称` | 中文名（**兜底**用；真名在 `loc_names.gd` 的 `item.<id>`） |
| `name` | **= 代码里的 id**（`scroll_peashooter` / `coin_gold` / `potion_wallnut`…） |
| `分类` | `scroll` / `coin` / `fertilizer` / `battle` / `exp` / `talent`（图鉴的「分类」行，也决定「价值」怎么念） |
| `price`（P88 起由 `价值` 改名） | 一个数字：钱币=**卖出价**、卷轴=**耐久**、经验药水=**经验值**；其它分类写 `—`（图鉴就不显示这一行，角标也空着）。**它不是"阳光值几个点"**——一个阳光掉落值多少由产出它的植物决定（向日葵的 `attack` 列） |
| `对应植物` | 卷轴解锁的 / 药剂强化的植物 id，写 `—` 表示没有 |
| `svg` | **贴图路径，相对 `res://assets/svg/`、不写后缀**：`items/coin_gold` → `res://assets/svg/items/coin_gold.svg`（写全路径或写 `.svg` 也认） |

- **天赋药剂的 `svg` 写它那一档的通用瓶**（`items/potion/potion_talent_common`），瓶上的**植物标记**由
  `对应植物` 决定 —— 和仓库/背包里那张图是同一套两层画法。
- 图鉴的**大标题、用途说明、名字**仍然走语言层（`item.<id>` / `item.hint.*`），表里只登记 id、数值和贴图。
- **P88 起表是道具的唯一约定方**：`Balance.item_*` 一律**先问表**，代码里的 `ITEM_DEFS` 只是读不到表时的兜底，
  所以表里的数字**就是**战斗里用的数字（表里改了，卖出价/耐久当场跟着变）；跑 `[Items]` 时若你的行显示
  `overrides Balance: price …`，那是提醒你代码兜底那份旧数字已经过时，不是错误。
- 旧版的"`价值` 必须和战斗里真正用的数字一致"这条 FAIL 判据**已作废**（同一个数不再有两个业主）；
  `Balance.ITEM_DEFS` 里，自检会把不一致判成 `FAIL`（否则图鉴会报一个仓库并不给的价钱）；
  贴图与 `对应植物` 不一致只打印 `overrides Balance`，因为**表就是这两样的来源**。
- **战斗能发给你的道具**（仓库/商店/背包/关卡奖励）仍然由 `Balance.ITEM_DEFS` 决定：只在表里登记、
  代码不认识的条目在图鉴里显示 **`仅图鉴`** 并变暗（和"尚未实装的植物"同一套规矩）。
- **改了表要让它生效**：和两张单位表一样，游戏里按 **`R`** 会重读；重开图鉴也会重读。

### 僵尸：护甲与"1/3 处决"

- **护甲**是 hp 前面的一层：伤害**先扣护甲**，扣穿之后多余的伤害才进 hp；护甲条画在血条正上方，
  碎掉时会弹一次 `护甲碎了！` / `ARMOR BROKEN`。
- **破甲降级**：路障 / 铁桶 / 橄榄球僵尸的护甲被打碎后会**变成普通僵尸**（名字、移动、啃食、
  甚至"低血处决"规则都跟着变），身上剩的血**保留**。铁门僵尸**不在**这份名单里——它的
  `特殊机制` 那句没写"被打掉后变普通僵尸"，破甲只是门没了，名称、移动、啃食都不变。
- **1/3 处决**：普通僵尸（以及破甲后变回普通的那些）**血量 ≤ 最大血的 1/3** 时立即死亡，
  所以它的"有效血量"是 180 而不是 270（`docs/BALANCE.md` §2.3 的算法就是这么来的）。
  日志里的死亡行会注明 `(below 1/3 hp: executed)`，别把它当 bug。
- **撑杆僵尸**跳过第一株植物（不咬，直接落到植物左边一格），**跳完变普通僵尸**。

