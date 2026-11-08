# NUMBERS.md · 数值的形状与公式

> 这份文件回答两件事：**一个数值是怎么算出来的**，以及**它在哪个文件里**。
> **它不回答“为什么是这个数”**——那是 `docs/BALANCE.md`；
> **它也不搬运数值本身**——那永远是表与代码（下面每一条都指到具体那个文件、那个函数）。
>
> 定位与业主关系见 `docs/INDEX.md`（§1 现行文档 / §5 一个事实一个业主）。
> **本文档是活文档**：公式一改就改这里，不要让它和代码分家。

---

## 1. 三个业主，别越界

| 事实 | 业主 | 例子 |
|---|---|---|
| **数值本身**（谁是多少） | `data/units/*.csv`、`data/**/*.csv`、`scripts/balance/balance*.gd` | 盾卫 HP = 800 |
| **数值怎么算**（公式 / 成长曲线 / 派生量） | **本文件** | `hurt = (1+attack) / (1+防御)` |
| **数值为什么是这个数** | `docs/BALANCE.md` | “护甲是血之前的一层” |

一条硬规则（`AGENTS.md` §2）：**单位自己的数值写在它的表行里**，全局规则写在 `Balance` 里，
呈现数值（像素 / 颜色 / 时长）写在 `BalanceUI` 里。本文件只描述，不拥有任何一个数。

---

## 2. 单位有哪几维

`data/units/units.csv` = 每单位一行（**共用列**），下面按 `race` 再叠一层族表（`plants.csv` /
`zombies.csv` / `humans.csv` / `monsters.csv` / `machine.csv` / `pokemon.csv` / `animals.csv`，
还可以再分子族；后三张分别由 [B19]、[B38]、[B39] 新建，五族的**列集合必须相同**，否则 `UnitCsvManager._check_column` 会为每行报一条 "no column"）。取值口径见 `AGENTS.md` §2：
**空着 = 问该层/该种族的 `default` 行 ⇒ 没有就回代码兜底**；`—` / `none` = 该属性不存在；`0` 就是 0。

| 维 | 列名 | 在哪张表 | 谁读它 |
|---|---|---|---|
| 生命 | `HP` | `units.csv` | `UnitSheet` → `PlantDB.hp` / `ZombieDB.hp` / `PieceDB.hp` |
| attack | `attack` | `units.csv` | 同上（植物 = 技能伤害；僵尸 = 啃食；棋子 = 每次出手） |
| **防御** | **`defence`** | **`units.csv`（共用列）** | **`UnitSheet.defence(id)` → `Unit.defence`**，公式见 §3 |
| 天赋 / 技能 / 特殊机制 | `天赋` / `技能` / `特殊机制` | `units.csv` | 散文，图鉴与悬浮面板 |
| rarity | `rarity` | `units.csv` | `rarity.csv` + `RarityDB` |
| 模式旗标 | `turned` / `timed` | `units.csv` | `UnitSheet.turned/timed` |
| **攻击距离类型**（标签） | **`range_type`** | **`units.csv`（共用列）** | **`UnitSheet.range_type(id)` → 图鉴描述**：闭合词表 `melee` / `range`。**纯标签，不驱动行为**（远程判定仍是 `BrawlActor.is_ranged()`=`shot_id()!=""`，见下） |
| **功能定位**（标签） | **`role`** | **`units.csv`（共用列）** | **`UnitSheet.role(id)` → 图鉴描述**：闭合词表 `dps` / `tank` / `healer` / `support`。**纯标签，不驱动行为**（治疗索敌仍是射弹 `治疗` 那一业主） |
| **每秒回复 HP** | **`regen`** | **`units.csv`（共用列）** | **`UnitSheet.regen(id)` → `Unit.regen_per_second`**（`read_realtime` 缓存）：整数，空=0（不回血）。**仅即时模式生效**——唯一读者是 `BrawlActor` 的自愈累加器，落血走 `Unit.heal()`（封顶 max_hp、死体 no-op），**不进 §3 防御公式**。今天只有 `坚果墙=10` |
| **滚动移动** | **`rolling`** | **`units.csv`（共用列）** | **`UnitSheet.rolling(id)` → `Unit.rolls`**（`read_realtime` 缓存）：开关，照 `timed`/`turned` 读法（空/`0`=OFF）。**仅即时模式生效**——`BrawlActor._advance_roll` 按 `BalanceBrawl.ROLL_RADIANS_PER_CELL` 把走过的格数换算成角度，走 `_lean+_roll` 那一条旋转通道。今天只有 `坚果墙=1` |
| 攻速 / 射程 / 移速（乱斗） | `attack间隔` / `attack距离` / `移速` | 族表 | `PieceDB` → `HumanPiece` 的四道门 |
| 护甲（回合制） | `护甲` | `zombies.csv` | `Zombie.armor`，它是血之前的一层 |
| 等级成长 | `HP成长` / `技能成长` / **`防御成长`** | `plants.csv` | `Balance.plant_attrs` → §4 |
| **星级成长** | 无列（星级记在会话里） | —— | 见 **§5**（每星三维 ×2） |

**三维的基础值（用户 2026-10-05）：生命 100 / attack 20 / 防御 20**，写在 `units.csv` 的四行
`default` 里（各族一行），所以**任何留空的格子都按这三个数走**；**盾卫自己写 `defence = 50`**（约 28% 减伤）。
⚠ 今天只有 14 行没写 HP、24 行没写 attack，它们改跟新的基础值（HP 300/270/280 → 100）；
**其余每一行都写着自己的数**（240–800 HP），所以这是**基础值**的调整，不是全表重标定。

⚠ **整数值写成浮点（`300.0`）也算那个整数**：表格工具重新导出时会这么写，`UnitCsvManager.int_of()`
接受它（真有小数 `300.5` 才报 complaint），开关列按**数值**读（`0` / `0.0` = OFF）。
踩过的坑见 `docs/PITFALLS.md` 第 75 条。

**开机那行就是这一列的读数**：`[Data] units: … | turned 98, timed 7, defence 1 | range … , role … | regen N, rolling M`——
`defence` 那个数就是“填了防御的行数”，是排查“列名写错 / 值落在别人那一行”的第一站。
（[P113] 起 `defence` 后面还跟了 `range` / `role` 两组标签计数，见上；
[P114] 起再跟 `regen` / `rolling` 两个即时模式 trait 计数——今天两个都应是 `1`（都只有坚果墙填了），
一眼确认"没串到别的行"。`timed` 那格因坚果墙进即时模式而 +1。）

⚠ **今天全表只有 `盾卫` 一行的 `defence` 不是 0**（首版示例值）：这一列是**加法**，
填别的单位就是改一格表；是否给植物 / 僵尸也加防御，是平衡决定（`docs/OPEN_ITEMS.md` §0.8）。

**`range_type` / `role` 是 [P113] 新建的两列「人对单位的分类」标签**：英文码存储（与 `rarity` 同族，
中文显示走 `Loc`，`unit.range.*` / `unit.role.*`），**每条单位行都填**、8 行 `default` 留空。
读取器照 `face` 那套闭合词表（`UnitSheet.range_type` / `role`：命中返回词、空格返回 `""`、
拼错 `note_complaint` 后返回 `""`），并进了开机读数：
`[Data] units: … | range melee/range M/R, role dps/tank/healer/support a/b/c/d`。
⚠ **这两列绝不夺走行为业主**：远程判定仍归 `BrawlActor.is_ranged()`（=`shot_id()!=""`，真实是三形状
`射弹`/`远程特效`/`近战特效`），治疗索敌仍归 `projectiles.csv 治疗`——所以一束 `远程特效` 光束可以被
**标**为 `range`，即便引擎把它判成近战，标签跟人读的距离一致即可。
**显示接线在图鉴单位页的描述块**（`almanac.desc.unit_tags`：「距离 … 定位 …」），不是固定面板行——
面板只有 9 行且已到呼吸下限（`ALMANAC_PANEL_LINES`=9 / `ALMANAC_PANEL_LINE_STEP`=22，见 `balance_ui.gd`），
再加行会顶到 BACK 按钮，所以标签落在会换行的描述里。

---

## 3. 伤害公式（唯一的一条）

### 3.1 规格

```
hurt = attack * 32 / (16 + max(0, defence))
```

**attack方**的 `attack` 与**挨打方**的 `defence` 都直接来自 `units.csv`；`16` 是**刻度**：
**防御等于 16 时，伤害减半**。

### 3.2 实现

代码在 **`scripts/balance/balance.gd` 的 `Balance.DEFENCE_SCALE`（= 128）与
`hurt_after_defence(attack, defence)`**，跑在 **`scripts/core/unit.gd` 的 `Unit.take_damage()`** 里
（**排在几个 no-op 守卫之后、无敌判断之前**）——**全游戏每一击都走这一扇门**，
所以乱斗与回合制、近战与射弹**共用同一条公式**。

| 规格里的写法 | 实现 | 说明 |
|---|---|---|
| `max(0, defence)` | 照抄 | 负数防御（破甲、将来的减益）不许把分母压到刻度以下 |
| —— | `round(...)` | 结果是**整数**：全工程的 HP 都是整数，半个血点没人看得见 |
| —— | `maxi(1, ...)` | **至少 1 点**：“这一击多疼”永远不能回答“不疼” |

**防御 0 = 没有防御**：系数是 `128/128 = 1`，伤害**恰好等于攻击值**——
也就是说这一列对“没有防御的单位”是**零影响**，加防御只会往下削。

### 3.3 一张对照表（`attack = 20` 的基础单位打下去）

| 挨打方 defence | 0 | 20（基础） | 50（盾卫） | 64 | 128 | 256 |
|---|---|---|---|---|---|---|
| 系数 | 1.00 | 0.865 | 0.719 | 0.667 | **0.500** | 0.333 |
| 实际掉血 | **20** | **17** | **14** | **13** | **10** | **7** |

⇒ **防御是一把平滑的尺子**：刻度写在公式里（`DEFENCE_SCALE`），表里填的是同一个刻度上的点数。
“减半”就是 128，“四分之一（75%）”是 64 上下；`0 / 20 / 50 / 128` 是常用的四档。
（旧版 `(1+A)/(1+D)` 的比值写法已作废：基础防御 20 会把每一击削到三分之一。）

### 3.4 一击的完整链路

```
回合制：植物技能值 / 僵尸啃食 …  →  Unit.take_damage()  →  护甲（僵尸）→  HP
乱斗：  BrawlActor.blow_value()  →  land_hit()  →  Unit.take_damage()  →  HP
```

1. **乱斗的出膛价**（`BrawlActor.blow_value`，`scripts/core/brawl/brawl_actor.gd`）：
   `这一击的底价 × (1 + 狂暴等级 × 0.08) × (1 + 狂暴等级 × 0.08) × (1 + attack挂件)`；
   底价 = 僵尸的 `啃食 × 0.3`（`BITE_DAMAGE_RATIO`）/ 植物的技能值 / 棋子表里的 `attack`，再加装备的加算attack。
2. **落地**（`BrawlActor.land_hit`）：`max(1, round(出膛价 × 受害者的 厚皮 系数))`，然后交给 `take_damage`。
3. **受害者那一层**（`Unit.take_damage`）：**先过 §3.2 的防御公式**；僵尸再走 `Zombie.take_damage`
   的护甲层（护甲先吸、吸穿了才掉血、破甲降级、HP 低于 `max/3` 立刻处决）；
   `铁壁` 这类无敌直接拒绝整击。
4. **同一个门的五个入口**：近战挥击、命中即中的光束、射弹落地（溅射 = `伤害 × 溅射`）、
   通道与吞噬的每一跳（`blow_value × BEAM_TICK_SHARE / GULP_TICK_SHARE`；**[B14] 大招的通道同理，
   只是每跳 `ULT_TICK_SHARE`**）、**[B39] 旋风的每一脉冲**（`blow_value × TORNADO_TICK_SHARE`，
   节奏 `TORNADO_TICK_SECONDS`，每一脉冲都走**召唤者自己**的 `land_hit()`）——**没有第二张伤害表**
   （`docs/prompt/BRAWL.md` §8.7.2 / D58 / §8.13）。

---

### 3.5 战力估算（一个读数，不是第二条公式）[B24]

```
power = HP * attack * (DEFENCE_SCALE + defence) / 1024     （整数除，取整数部分）
```

业主：**`scripts/balance/balance.gd` 的 `Balance.estimate_power(hp, attack, defence)`**
与按 id 取数的 `Balance.unit_power(id)`；`1024` 是同一份文件里的 `Balance.POWER_SCALE`。
三个输入**全部来自 §2 的那三格**（`units.csv` 的 `HP / attack / defence`，空格由该种族的
`default` 行回答），所以图鉴面板把输入印在上面、把乘积印在第四行：**当场手算就能核对**。

- `/1024` 只是**把尺子缩短**（原始乘积是六位数字，除完读三位），不改排序、不改比例；
- `DEFENCE_SCALE` 与伤害公式共用：改刻度 = 同时改减伤曲线和战力读数（见 §3.2 / §6）；
- **战斗里没有任何东西读它**：它存在的唯一理由是让两个阵容能并排比一眼；
- 求和版：`FormationDB.power_total_of(rows)`（乱斗图鉴的“战力合计”行）。

| 单位 | HP | attack | defence | 战力 |
|---|---|---|---|---|
| 民兵 | 320 | 28 | 16 | 280 |
| 盾卫 | 800 | 12 | 32 | 450 |
| 弓手 | 240 | 32 | 0（默认） | 120 |
| 雷角兽 | 340 | 30 | 16 | 318 |
| 抛射炮 | 380 | 55 | 0（默认） | 326 |

---

## 4. 等级与经验

等级是**花园植物**的属性（乱斗棋子今天不升级，表里也没有这一列）。

### 4.1 一条曲线，三维成长

```
属性(L) = 基础值 × (1 + 成长率 × (L - 1))          # Balance.get_level_factor
```

| 维 | 基础值来自 | 成长率（每级） | 表的列 | 代码兜底 |
|---|---|---|---|---|
| 生命上限 | `units.csv` 的 `HP` | **+10%** | `plants.csv` `HP成长` | `Balance.PLANT_HP_GROWTH` |
| attack（技能值） | `units.csv` 的 `attack` | **+10%** | `plants.csv` `技能成长` | `Balance.PLANT_SKILL_GROWTH` |
| **防御** | `units.csv` 的 **`defence`** | **+8%** | `plants.csv` **`防御成长`** | **`Balance.PLANT_DEFENCE_GROWTH`** |

- **先只有这三样**（用户 2026-10-05 的口径）：移速、攻速、冷却、恢复时间**都不随等级变**。
- 防御那条**故意比另外两条缓**：它在伤害公式里是**分母**，+10%/级 会让每级都削掉一成伤害。
- **基础值是 0 就永远是 0**：成长是乘在基础上的，所以没填 `defence` 的植物不会凭空长防御。
- 天赋药剂只加生命或技能二者之一（`plant_attrs` 的 `potion_effect`），**没有第三种药**。

### 4.2 经验

```
升到 L+1 需要：EXP_PER_LEVEL × L     （Balance.exp_to_next_level，EXP_PER_LEVEL = 100）
经验来源：补刀 +10（ZOMBIE_EXP） / 天赋经验药剂 +50（EXP_POTION_AMOUNT）
```

| 目标等级 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| 这一级要 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 |
| 累计要 | 100 | 300 | 600 | 1000 | 1500 | 2100 | 2800 | 3600 | 4500 |

- **没有等级上限**（曲线本身就是代价）：要封顶就是 `Balance` 加一个常量 + `Garden.add_exp` 加一道门。
- **谁补刀谁拿经验**：经验跟着“最后一击”走（`Unit.last_attacker` → 战斗账本 → `Garden.apply_results`）。
  所以一次战斗里经验可以攒着不发，按 R 重开会连同整本账一起回滚。
- **升级时发生什么**：生命上限按新等级重算并**补上差额**（`Garden.refresh` / `add_exp`），
  技能值与防御**下一次上阵时**按新等级现算（它们是每株实例的属性，不是全局常数）。

---

## 5. 升星（星级）【规则已定，用户 2026-10-05；**代码尚未落地**】

**一句话：三个相同单位合成一个，星级 +1，三维（生命 / attack / 防御）**各 ×2**。**

```
属性(星) = 基础值 × 2^(星 - 1)        # 1★ = ×1、2★ = ×2、3★ = ×4
合成     ：同 id 的三个 ⇒ 星级 +1（三个 2★ ⇒ 一个 3★，以此类推）
上限     ：3★（首版；金铲铲的形状，D21 的总口径）
```

| 星 | 生命 | attack | 防御 | 怎么来的 |
|---|---|---|---|---|
| 1★ | 128 | 16 | 16 | 基础值（§1） |
| 2★ | 256 | 32 | 32 | 三个 1★ |
| 3★ | 512 | 64 | 64 | 三个 2★ |

- **乘的是“三维”**：生命 / attack / 防御——**不含**攻速、射程、移速、费用、冷却。
- **乘在基础值上，乘法顺序**：`基础值 × 星级 × 挂件(gear) × 狂暴`——所以星级与挂件互不干扰，
  谁先谁后都不改变结果（都是乘算）。
- **它是乱斗的轴，不是回合制的轴**：星级靠“同名棋子凑三个”而来（商店 / 胜局奖励），
  花园植物走的是**等级**（§4）；一个单位不会同时吃两条成长。
- ⚠ **今天只有规则，没有实现**：表里没有“星级”列、`BrawlSession` 不管合成、编阵页不画星。
  要落地的是三件事（登记在 `docs/OPEN_ITEMS.md` §0.8）：
  ① 棋子池 / 候战区的每一条记录带一个 `star`；② 得手之后自动检查“同 id 满 3 个 ⇒ 升星”（递归到 3★ 为止）；
  ③ 三维按 `2^(星-1)` 施加——加在**现算数值**的那一层（`HumanPiece.apply_piece` / `BrawlActor.setup`），
  与 §4 的三维成长同一个位置，将来两者都只改那一处。

---

## 6. 手感旋钮（哪一层该动）

| 想改什么 | 动哪里 |
|---|---|
| 某个单位太硬 / 太脆 | 它那一行的 `defence`（刻度：**20 = 基础 / 50 = 盾卫 / 64 ≈ 打七五折 / 128 = 减半**）或 `HP` |
| 全局“防御值多少钱” | `Balance.DEFENCE_SCALE`（**16** = 减半点）：改它=改整条曲线；只想调一个单位就动表 |
| 战力读数太长 / 太短 | `Balance.POWER_SCALE`（**1024**）：只缩短尺子，不改排序（§3.5）。**动它不要动 `DEFENCE_SCALE`**——后者连着伤害公式 |
| 某个单位打得疼不疼 | 它那一行的 `attack`（基础 20） |
| 升级给多少 | `plants.csv` 的三列成长（或 `Balance.PLANT_*_GROWTH` 兜底） |
| 升级要多快 | `Balance.EXP_PER_LEVEL`（以及 `ZOMBIE_EXP` / `EXP_POTION_AMOUNT`） |
| 乱斗的节奏（攻速 / 狂暴 / 通道 / 吞噬 / 击退） | `scripts/balance/balance_brawl.gd`（每个常量都写了它是干什么的） |
| 战争的手感（[W6] 幕布时长 / 相机梯子与平移速度 / 出征上限 / HUD 与布阵页版面） | `scripts/balance/balance_war.gd`（常量一律带 `WORLD_CELL` / `CAMERA_` / `WAR_` 前缀，防与乱斗表重名） |
| 画面上多大 / 多快 / 什么颜色 | `scripts/balance/balance_ui.gd` |

---

## 7. 数值在哪（索引）

| 数值 | 业主 |
|---|---|
| 单位（HP / attack / defence / 旗帜列） | `data/units/units.csv` |
| 族与子族列（费用 / 攻速 / 射程 / 移速 / 成长 / 护甲 / 脚本…） | `data/units/{plants,zombies,humans,monsters}.csv` |
| 技能与大招的价与数值 | `data/units/skills.csv` |
| 射弹（速度 / 轨迹 / 穿透 / 外观 / 贴图 / **尺寸** / **体型**…） | `data/projectiles.csv` |
| **射弹画多大**：`尺寸`（第 24 列）自 2026-10-10 起是**基本字段**——用户的口径是"尺寸作为射弹的 csv 表的一个基本字段"，所以**每一行都自己写一个像素方框**：现有 11 行写的就是它们**原本隐含**的画布（pea **32** / melon **40** / arrow **64** / musket **48** / bomb **18** = 那枚代码球的两倍半径 / warm_sun **100**），因此这一改动**一个像素都没动**，只是让图鉴能报出一个数（不再去问素材文件）。留空仍保留旧含义"图自己决定"：取**贴图 svg 自己的画布**（`assets/svg/shots/*.svg` 就是按战斗像素画的），没有贴图才回到「外观」那套代码半径（`BalanceUI.{PEA,MELON,BOMB}_RADIUS`…）。一条门回答三处：`Projectile.shot_box()`（两个飞行 + 图鉴缩放）。**只管画、不管命中** | `data/projectiles.csv` + `scripts/balance/balance_ui.gd` |
| **旋风（会走的一块地方）**：它是**第五种攻击形状**、不是 `projectiles.csv` 的一行（[B39]），所以数值分两个业主。**距离**在表里：`data/units/animals.csv` 的 `旋风` 列（鸟怪 = **5.0 格**，空/`—` = 这一行不召旋风）。⚠ **[B42b]：`旋风` 是这份表头的第 15 格 ⇒ 每一行都必须写满 15 格**——制表符按位置对齐，行少一格 = **尾列读成"这一格不存在"**（比 `—` 更彻底，`unit_csv.gd:396` 直接给 `0.0`），于是门永久关着而表看起来"写了 5.0"。实测踩过：`bird` 行漏一个制表符 ⇒ `5.0` 落进 `大招震飞`、`旋风` 读成空 ⇒ **旋风从 [B39] 起一次都没被召出**，四轮"看不见"都不是画的问题。唯一的仪器就是开机那句 `… %d with a 旋风`（`PieceDB.status_text()`，`game_manager.gd:110` 打印）——**加了列就回头读一次那串计数**。→ `PieceDB.tornado_cells()` → `HumanPiece.brawl_tornado_cells()`。**规则**在 `BalanceBrawl`：`TORNADO_CELLS_PER_SECOND`（**[B41] 2.2 → 1.4** 格/s，用户"降低旋风移速"）/ `TORNADO_REACH_CELLS` **0.8**（地面环 = 判据，**画得宽一寸都不行**，B20）/ `TORNADO_TICK_SECONDS` **0.5** / `TORNADO_TICK_SHARE` **0.35** / `TORNADO_HEIGHT_CELLS` **2.2** × `TORNADO_SIZE_TIER`（= `Balance.SIZE_LARGE`，买风柱高度不买环）。⚠ **降速是 buff**：同一具站着不动的身体在环两侧各 1.2 格 ⇒ 走 2.4 格 = 1.71 s = **三跳**（原来两跳 0.7 击 ≈28 点 ⇒ 现在 1.05 击 ≈42 点），补偿的旋钮是 `TORNADO_TICK_SHARE`（0.35 → 0.25 就回到两跳的量级）——**没有偷偷改**，见 `docs/STATE.md` §3 第 22 条。**画法**在 `BalanceUI`：`TORNADO_PAINTER`（**默认 `frames`** = 序列帧；`vector` = 代码画的柱）/ `TORNADO_FRAMES`（`tornado_0`、`tornado_1`，在 `assets/svg/fx/`，走 `Fx.melee_fx_path()` 那一族）/ `TORNADO_FRAME_SECONDS` **0.08**（用户点名的 80 ms 切换）/ 白色风痕 `TORNADO_TRACE_SEGMENTS` **9** + `TORNADO_TRACE_CELLS` **2.2** + `COLOR_TORNADO_TRACE`（白 α0.26）/ 诚实环 `COLOR_TORNADO_RING`（白 α0.55）+ `TORNADO_RING_SHARE` **0.05**。**两套画法共用同一把尺子**：序列帧按 `UnitArt.ink_fractions()` 量到的**墨迹**放大到"墨宽 = 环直径"，且高度被 `minf(想要的高, z_thickness × fade)` 夹住 ⇒ 缺图自动退回 `vector`，永远不可能"完全没有画面"。全部只管画与风柱高度，**不碰伤害数字与命中半径**。**[B42] 图鉴读的就是这一行点名的这几个数**：射弹页签从此有一格合成条目 `tornado`（`AlmanacView._whirlwind_row()` + 门 `shows_whirlwind()` —— 基类 `false`，经典/乱斗那页 `true`），面板八行 = 形状 / 召唤单位（**各棋子表行的 `旋风` 距离**）/ 移速 / 风环（`2 × TORNADO_REACH_CELLS` 格）/ 体型 / 每拍 / 高度 / 画法，**全部现读、一个数都不发明，并且一个 px 都不印**（乱斗的格子是窗口的） | `data/units/animals.csv` + `scripts/balance/{balance_brawl,balance_ui}.gd` + `scripts/core/brawl/brawl_tornado.gd` + `scripts/ui/almanac/almanac.gd` |
| **射弹有多大只（体型）**：[B40] `体型` 是**每行可选的量级词**（第 25 列，追加在 `尺寸` 之后），词表封闭：微小 **0.6** / 小 **0.8** / 标准 **1.0** / 大 **1.5** / 巨大 **2.2**，业主 `Balance.SIZE_TIERS`（`size_scale()` 折倍数、`is_size_tier()` 给自检判），写错词 = 该行 FAIL，空 = 标准（所以引入阶梯**没回头改过任何一行**）。它是**乘数、不是第四个 base**：`shot_box(look, 尺寸, canvas, tier)` 把阶梯乘在胜出的那一个 base 上 ⇒ `尺寸 × 体型` 同时生效（`warm_sun` = 100 px × 大 = **150 px**）。三个读者都传这一维：回合飞行 / 乱斗飞行 / 图鉴面板。**乱斗里唯一不用表写的射弹**是旋风——它不是 `projectiles.csv` 的行（[B39]），量级写在 `BalanceBrawl.TORNADO_SIZE_TIER := Balance.SIZE_LARGE`，买的是**风柱高度**（2.2 → ≈3.3 格空气，`height.z_thickness` 跟着乘）与画面分量，**不买地上那圈半径**（那圈 = 伤害付过的范围，见 §B39 的 `TORNADO_REACH_CELLS`）。仍然只管画 + 风柱高度，**不碰伤害数字与命中半径** | `data/projectiles.csv` + `scripts/balance/balance.gd` + `scripts/balance/balance_brawl.gd` |
| **射弹飞多快**：`速度` 一格写的是 **像素/秒**，`—`/`0` = "这一行没话说，按轨迹默认"。默认与换算各有两扇门：回合制 `projectile.gd:177`（`—` ⇒ `BalanceUI.PEA_SPEED 1100`，抛射 ⇒ `PULT_SPEED 480`）、乱斗 `brawl_shot.gd:139`（`—` ⇒ `BalanceBrawl.SHOT_CELLS_PER_SECOND 9.0 格/s`，写了 ⇒ `px/s ÷ Balance.CELL_SIZE 96`，地板 `maxf(1.0, …)`）。所以"每格几秒"就乘 96 写进表：1 格/s = `96`、3 格/s = `288`、9 格/s = `864`。现有显式行：`arrow 620` / `musket 950` / `bomb 420` / `warm_sun 96`。⚠ **表里写多慢都要过两条"飞太久"保险**：乱斗 `BalanceBrawl.SHOT_MAX_SECONDS 4.0`（超过就把这发**丢掉**，日志 `never arrived - dropped`）、回合制 `BalanceUI.ANIM_RESOLVE_TIMEOUT 3.0`（该回合的动画等待上限，射弹在 `projectile.gd:229` 的 `_ready()` 里记账）。想 1 格/s 横穿全场 ⇒ 同时抬这两条 | `data/projectiles.csv` + `scripts/balance/{balance_ui,balance_brawl,balance}.gd` |
| 挂件（强化 / 装备） | `data/brawl/gear.csv` |
| 敌阵与阵容 | `data/brawl/formations.csv` / `formation_pieces.csv` |
| 玩家棋子池 | `data/brawl/roster.csv` |
| rarity（颜色 / 恢复倍率） | `data/rarity.csv` |
| 掉落概率 | `data/drops.csv` |
| 关卡与波次 | `data/level/*.json` + `data/levels.csv` |
| 战场尺寸与部署区（每图一行：rows / cols / deploy_cols） | `data/war/maps.csv`（读者 `WarDB`，[W2]） |
| 波次时间表（每行 = 一具身体：wave / delay 绝对秒 / piece / col / row / 概率） | `data/war/waves.csv`（读者 `WarDB.spawn_plan()`，投放者 `war.gd` 的调度器，[W5]；骰子只在 `概率 < 1.0` 的行上摇，种子在 `WarSetup.roll_seed` ⇒ R 重开必重现同一支军） |
| 全局规则（回合制） | `scripts/balance/balance.gd` + `balance_{battle,garden,run,shop}.gd` |
| 全局规则（乱斗） | `scripts/balance/balance_brawl.gd` |
| 全局规则（战争）[W6] | `scripts/balance/balance_war.gd`：`WORLD_CELL` 96（固定世界格，缩放全交相机）/ `WAR_DEFAULT_MAP` / `WAR_DEPLOY_LIMIT` 12 / `WAR_CURTAIN_SECONDS` 2.0 / `CAMERA_*`（fit 留边、HUD 预留带、缩放梯子、平移速度）/ `WAR_HUD_*` / `WAR_PAGE_*`（结算遮罩与布阵页条带） |
| 呈现数值（像素 / 颜色 / 时长） | `scripts/balance/balance_ui.gd` |
| 音频（曲目 / cue / 音量） | `scripts/balance/balance_audio.gd` |
