# FX.md · 单位特效实现（代码落点与接线）

> 配套规格：**`docs/prompt/FX.md`**（规则语义在那份里：有哪些特效、什么时候放、谁给谁让位；
> 本文只回答"**落在哪个文件、哪个变量、哪条链**"）。
> 状态：**[活文档]（2026-10-08 自旧的单文件特效文档拆分而来，该文件已删除，用户当轮点单）**。
> 纪律：数值全部在 `BalanceUI`，`unit_fx.gd` 里**不许出现字面量**；**不写测试脚本**（AGENTS.md §2）；
> 验收由用户手动跑。行号是 2026-10-08 工作区的读数，实现时以函数名重锚。

---

## 0. 三个业主，别越界

| 事实 | 业主 | 说明 |
|---|---|---|
| 有哪些具名特效、各由哪些通道组成、撞上谁赢 | **`scripts/core/unit_fx.gd`** | 表即代码：`spec(id)` 是行，`priority(id)` 是胜负 |
| 通道怎么落到画面上（红闪 / 倾斜 / 位移 / 游走 / **形变**[B33][B34]） | **`Unit`**（`scripts/core/unit.gd`） | `lean_pose` / `sway_pose` / `push_pose` / `jelly_pose`[B34] / `shake` / `_tick_idle` |
| 有哪些**表演**（同一条特效的几种演法） | **`scripts/core/unit_fx.gd`** | `death_spec(id)` [B25] 与 `idle_spec(id)` [B33]；**选哪个由调用点决定**，单位自己没有这一格（规格 §9） |
| 时长、角度、像素 | **`scripts/balance/balance_ui.gd`** | `FX_*` 与 `ANIM_*` 等，清单见 §11 |
| 谁在什么时候放 | **调用点** | `file:line` 清单在 §2，改触发点不用改表 |

`Unit.play_fx(id) -> bool` 是**唯一的门**：返回"这条特效收下了没有"。
没被收下不是错误（身上正演着更高级的东西，规格 §3），所以调用点**不需要**判空、也不需要看返回值。

---

## 1. 通道 → 变量 → 归宿

| 通道 | 变量 | 归宿（代码） | 两个模式都有效？ |
|---|---|---|---|
| **红闪** | `Unit._flash` | `take_damage()` 自己写、`_process` 自己衰减 | ✅ |
| **倾斜**（前倾 / 后倾） | `Unit._lean`（弧度） | 视图场景转 `BodyPivot`；贴图与色块转 `draw_set_transform` | ✅ 旋转不是 ink，不需要格子 |
| **晃动**（[B33] 眩晕：来回 rocking） | **还是 `Unit._lean`** | `Unit.sway_pose()` 把它连成"一段比一段小"的来回，最后回直立 | ✅ |
| **位移**（前冲 / 后退） | `Unit._shake_offset` | `Unit.shake()` | ❌ 见 §4 |
| **游走**（呼吸的浮动 / 微摆） | `Unit._idle_offset` / `_idle_phase` | `_tick_idle()`（只在 `breath` 表演下，规格 §3b） | ❌（它写的是 `position`） |
| **形变**（[B33] 纵长横扁 + [B34] 受击果冻） | `Unit._idle_stretch`（空闲的每轴缩放）× `Unit._jelly`（受击的阻尼时钟）——画面读的是**两者之积** | 贴图与色块走 `_draw_body` 的画布变换；视图走 `BodyPivot.scale`；脚补偿 `_deform_offset()` | ✅ **与倾斜同一个变换，所以两个模式都生效** |
| **淡出** | `modulate:a` + `scale` | `play_death()` | ✅ |
| **倒点**（[B25] 绕哪儿转） | `Unit._turn_anchor` | `play_death()` 与 `sway_pose()` 会把它挪到脚底，各自在结束时交回原点；平时 0 = 原点 | ✅ |

五条**实现约定**（规则侧的理由在规格 §2 第 1–4 条，第 5 条是本文件自己的通道事实）：

1. **倾斜只转身体**：`_draw_body()` 里设、函数末尾复位——名字、血条、行动条画在它之后，
   永远不跟着歪。视图场景走 `BodyPivot`（挂在单位原点），旋转中心是**单位中心**，
   而不是零件自己的原点（那是**脚底**，见 `UnitArt.fit_view`）。
   **[B25] 倒地例外**：死亡把旋转中心挪到脚底（`Unit._turn_anchor`），并且只用**一处**补偿
   `(anchor − anchor.rotated(lean))`（`Unit._turn_offset()`）：贴图走画布变换的 position、
   视图走 `BodyPivot.position`，**同一个公式**。
   **[B33] 眩晕的晃动用的是同一处补偿、同一个锚点字段**——所以加它没有新增任何公式，
   只是把 `_turn_anchor` 的写手从一个人变成了两个。
2. **姿态是"弹进去、缓回来"**：先摆到姿势、再补间回正（`shake()` 一直就是这个形状）。
   **[B33] `sway_pose()` 是唯一不按这条走的**：它用 `TRANS_SINE / EASE_IN_OUT` 连成一串来回，
   每段乘 `FX_STUN_DAMP`；段的**数量**（`FX_STUN_SWINGS` + 收尾那一段）与 `UnitFx.stun_time()`
   的分母**是同一个式子**，所以优先级到点的那一刻，摆动正好落地。
   **[B34] `jelly_pose()` 守前半条、把后半条换成了公式**：一条 `TRANS_LINEAR` 的**归一时钟**
   （1→0，时长就借 `hit` 行的 `time` = `ANIM_SHAKE_TIME`），振荡与衰减都读在**这一个数**上
   （`FX_JELLY_FREQ` / `FX_JELLY_DAMP` 以"一次受击"为单位）——与眩晕同一个"表与 tween 花
   同一份时间"的手法，只是段链换成了阻尼余弦。
3. **`_flash` 不进特效表**（D2）：它由 `take_damage()` 无条件写，表里只有
   `lean` / `push` / `sway` / `jelly` / `time` 五列可以填。
4. **[B33] 视图零件只有一个写手：`_apply_lean()`** 一次写成 `rotation`（倾斜）+ `position`
   （两处补偿相加）+ `scale`（镜像 × 形变）。`_apply_mirror()` 因此退化成了"重摆一次姿态"。
   ⚠ **`unit.scale`（节点缩放）不是姿态通道**：`play_death()` 补间它、`BrawlActor` 的肚子状态写它，
   形变要是也写在那里就是三方互相改写——所以形变走画布变换 / `BodyPivot.scale`，
   配 `_deform_offset()`（原名 `_stretch_offset()`，[B34] 起它回答的是**合成后**的大小）把脚钉回原地。
5. **[B34] 果冻是"新变量 + 合成读数"，不是新写手**（照 §10 那条判据）：`jelly_pose()` 只拨
   `_jelly` 这一个**阻尼时钟**（`TRANS_LINEAR 1→0`），缩放**不落变量**——画面每帧现算
   `_idle_stretch × _jelly_scale()`（阻尼余弦，业主 `BalanceUI.FX_JELLY_*`）。两个写手因此
   **乘在一起、互不覆盖**：空闲把形变**松开**回 ONE 时果冻照弹；果冻归零时空闲照呼吸。
   它与倾斜同一条 tween 家族、同一个 `_apply_lean()` 出口，两处补偿一个字没改。
   ⚠ 时钟长度就借 `hit` 行的 `time`（`ANIM_SHAKE_TIME`）：优先级到点的那一刻，振荡正好停
   ——与 [B33] 眩晕的"表与 tween 同账"同一个手法。

---

## 2. 触发点（谁在什么时候放，`file:function`）

| 事件 | 调用点 | 放的是 |
|---|---|---|
| 僵尸啃咬 | `scripts/units/zombie.gd` `act()` BITE 分支 | `attack`（自己）+ `hit`（被啃的那株，**含 [B34] 果冻**）+ **图画**（`Fx.spawn_melee_fx(melee_fx_id(), …)`，见 §5） |
| 僵尸吃脑 | 同上 EAT_BRAIN 分支 | `attack` |
| 射弹命中（两套解析路径各一处） | `scripts/projectiles/projectile.gd` `_strike()` / `_resolve_now()` | `hit_shot`（受害者） |
| 乱斗里出手 | `scripts/core/brawl/brawl_actor.gd` `_begin_strike()` | `attack`；**近战**落点 = 火花（人人有）+ 图画（由出手方的表行决定，§5）。**远程命中不在这里**，`BrawlShot._burst` 自己画 |
| **乱斗里命中**（[B12] 伤害漂字） | `scripts/core/brawl/brawl_actor.gd` `land_hit()` | 一个**数字**（`Fx.spawn_popup`，`-N`）——不是具名特效（§7） |
| **乱斗里被吞噬**（[B10]） | `scripts/core/brawl/brawl_actor.gd` `be_swallowed()` | `hit`（进肚子那一帧，**含 [B34] 果冻**）；之后挂的是状态（§8） |
| **乱斗里被击退**（[B9]） | `scripts/core/brawl/brawl_actor.gd` `shove_from()` | `hit`（后倾 + 果冻两半都演，真位移走 `BrawlActor.pos`；后退那一半被网格门拒，§4） |
| 倒下 | `Unit.play_death()`（由 `battle.gd` / `brawl.gd` 调） | `death`，表演默认 `topple`；**铲子**（`battle.gd` 的挖 plant）点名为 `play_death("fade")` |
| **眩晕**（[B33]） | **没有调用点** —— 表与门都在（`UnitFx.spec("stun")` → `Unit.sway_pose()`），等的是"哪个招式会晕人"这条**游戏机制**，不是等特效 | `stun` |
| 空闲 | `Unit._tick_idle()`（每帧自己走，没有触发点） | 基线：默认**形变**，`Unit.set_idle_fx("breath")` 才回到旧的呼吸（§2b） |

**红闪不在这张表里**：任何一次 `take_damage()` 都会闪（含工具、掉血、溅射邻居）。

---

## 2b. 两张**表演表**的接线（[B25] 死亡 / [B33] 空闲）

同一套形状，两个主题：**优先级表里只有一行，怎么演是另一张表**，选哪一出由调用点回答。

| | 死亡（[B25]） | 空闲（[B33]） |
|---|---|---|
| 表 | `UnitFx.death_spec(id)` | `UnitFx.idle_spec(id)` |
| 名字 | `topple`（默认）/ `fade` | `stretch`（默认）/ `breath` |
| 默认值常量 | `DEATH_TOPPLE` 被 `death_spec("")` 用作回落 | `UnitFx.IDLE_DEFAULT` |
| 封闭集校验 | 无（回落 + 每次警告） | **`UnitFx.has_idle()`**：`set_idle_fx()` 在门口挡一次，因为 `_tick_idle()` 每帧都要读表，不能每帧警告 |
| 调用点怎么点 | `play_death("fade")` | `unit.set_idle_fx("breath")`（**今天没有调用点**，两种演法都活着等谁要用） |
| 谁读它 | `play_death()` 一次 + `death_time()` 算总时长 | `_tick_idle()` 每帧，读的是 `place()` 时缓存的那一行（`Unit._idle_spec`） |
| 优先级 | **始终只有一条**（100） | **始终只有一条**（0）——换演法不换优先级 |

- ⚠ **`_idle_spec` 是"表行的一份快照"，不是第二个数值业主**：`place()` 与 `set_idle_fx()` 各刷新一次，
  `_tick_idle()` 只读它。缓存的理由是 P38 那条纪律（这个循环里不许每帧分配）。
- **形变这一支不碰 `position`**，所以 `_breath_shown()`（每帧重绘的判据）对它返回 false：
  该重绘的时候由 `_apply_lean()` 自己说。

---

## 3. 让位门的实现（规格 §6）

```
Unit.fx_body_plays(id)  ->  UnitArt.play_view_clip(art_view, id)
```

视图场景的 `AnimationPlayer` 里有同名 clip 就播它、通用姿态一步都不做；没有就按 `UnitFx.spec(id)` 来。

⚠ **今天还没有任何零件带 `hit` / `attack` clip**，所有单位走通用分支。
第一个带 clip 的零件落地时要补的事：**那条 clip 播完之后没人叫它回 `idle`**
（`UnitArt.play_view_clip` 的注释里记着）。

`death` 不走让位门：`play_death()` 的最后一段（淡出）同时是 `queue_free` 的时钟，
一处算总的是 `UnitFx.death_time()`。两种表演的表在 `UnitFx.death_spec(id)`；
改总时长前先读 `BalanceBrawl.BOUT_CURTAIN_SECONDS`（乱斗落幕必须盖过完整死亡，规格 §4）。

**[B33] 新加的 `stun` 不需要在这里登记**：门问的是 id（`fx_body_plays(p_id)`），
哪天某个零件长出 `stun` clip，它当天就被这条问句发现。
**空闲（`idle`）则根本不进这道门**——它不是一个"演一次"的姿态，而是基线，
`play_fx("idle")` 落到 `Unit.fx_settle()`（规格 §3：它没有时长）。

---

## 4. 乱斗侧的实现细节

- `shake()` 对 `grid == null` 的身体**直接返回**，而乱斗单位的 `position` 由
  `BrawlActor._sync_position()` **独占写入**（`BRAWL.md` R1）——所以乱斗里的 `attack`
  是**只有前倾、没有前冲**（约定，规格 §7）。
  顺带：改造之前 `_begin_strike()` 里那句 `unit.shake(facing, ...)` **本来就是空操作**，
  乱斗的出手一直是没有任何位移表现的。
- `_sync_position()` 把 `BrawlActor.facing`（可以是转身的、也可以是斜的）**每帧**写进 `Unit.facing`，
  倾角跟着它走。"瞄哪"与"画朝哪"分离：画的朝向由 `Unit.faces_left` 说、
  站错半场时由 `Unit.mirrored` 翻过来（规则 `docs/prompt/BRAWL.md` §8.15）。
  翻转只动**身体**：贴图走 `_draw_body` 的画布变换、视图走 `BodyPivot` 的 x 缩放——
  名字、血条与两条 bar 画在那个变换之外。
- **[B9] 击退不走 `shake()`**：走 `BrawlActor.pos`（`shove_from` / `_advance_shove`，
  规则 `BRAWL.md` §8.10）。姿态上它借 `play_fx("hit")` 的**后倾 + [B34] 果冻**两半，
  后退那一半照样被 `shake()` 拒掉。
- **[B34] 果冻在乱斗里是真的**：它和形变空闲写的都是**画的变换**，不是 `position`，
  所以不违反 R1；`jelly_pose()` 因此**没有**网格门（与 `lean_pose`/`sway_pose` 同一族，
  只有 `push_pose` 有）。脚的读数走 `_feet_offset_y()`，与 [B33] 同一条答案。
- **[B33] 眩晕的晃动与形变的空闲在乱斗里都是真的**（[B34] 的受击果冻同条）：它们写的都是**画的变换**
  （`_draw_body` / `BodyPivot`），不是 `position`，所以不违反 R1 那条"位置归驱动器独占"。
  脚的读数也自动对：`_feet_offset_y()` 走 `art_ink()`（[B37] D114 起它是**唯一**那扇门：方框仍是 `art_box()`，
  底边从画布改成**实测墨迹**），而乱斗把棋子画大时改的就是
  `art_scale`（`BrawlLayout.piece_scale`），于是晃动与伸缩绕的是**放大之后**的那只脚。
  ⚠ 与 `hit` 一样，`facing` 只决定**第一下**往哪边歪（`_facing_sign()` 取 x 分量），
  来回本身是对称的，所以斜着跑的棋子不会被它拽歪。

---

## 5. 近战图画的接线（[P110e]）

链路只有一条，四步各管一段、不互相重复：

**表格（`近战特效` 列，哪些表哪一格见规格 §8）→ `PieceDB.melee_fx` / `ZombieDB.melee_fx`
→ `Unit.melee_fx_id()`（由**身体**回答，场地**不再**按 `is_zombie` 猜）→ `Fx.spawn_melee_fx`**。

- 格子写的是**短名**（`slash`），路径由 `Fx.melee_fx_path()` 拼成
  `res://assets/svg/fx/slash.svg`——与 `ProjectileDB.art_path` 同一条规则
  （`res://` 全路径 / 自带后缀 / 短名三种写法都收）。
- ⚠ **写错一个名字不会报错**：那张图画不出来而已，打击照旧结算，
  `UnitArt.warn_once` 只喊一次。排查"斩击没出现"先看两处——
  开机那行 `[Data] pieces: … %d with a 近战特效`，以及格子里那个短名和
  `assets/svg/fx/` 里的文件名**是否一字不差**。
- 素材位置与命名另见 `docs/UNIT_ART.md`；业主是 `scripts/fx/fx.gd` 与它那一层 `FxLayer`
  （P76 定的"一层一门"：唯一 `FxLayer`、唯一 `_put()`、唯一 `clear()`）。

---

## 6. 光束族（[P110f] / [P110h] / [B14]）

| id | attack | 时长 | 形状 |
|---|---|---|---|
| `laser` | 瞬发光束 | 0.14 s | 一道细光（晕 / 身 / 白芯三遍叠画） |
| `flame` | 喷射火焰 | 0.30 s | 一个**锥**（七个三角火舌），**够不到目标中心** |
| `impulse` | 连续冲击光束 | 0.42 s | 粗光柱 + 四个**向外跑的亮环** |
| `thunder` | 雷角电击（**[B14]**） | 0.16 s | **折线雷**：七个折点 + 两条分叉；两端严格落在两个身体上（折幅按 `sin(t·π)` 收敛到 0） |

- **两种用法，一个画师**：**一闪**（`Fx.spawn_beam`，生成即忘，端点只取一次）与**通道**
  （`scripts/core/brawl/brawl_beam.gd`，竞技场持有，跟着两个身体跑满 3 秒）
  都调 **`Fx.draw_beam`**——静态函数、收 `CanvasItem`，与 `Projectile.draw_shot` 同一个形状，
  所以"一条光长什么样"只有一个业主。区别只在**时钟**：一闪让 phase 从 0 走到 1 顺便淡出；
  通道让 phase **循环**、把 fade 留到最后一刻（起手 0.1 s"上电"、收尾 0.22 s"断电"）。
- **循环多快是每种画自己的**（`BEAMS` 每行的 `phase_speed`，经 `Fx.beam_phase_speed` 取用：
  火焰 9 次/秒、光柱 1.8 次/秒）——**速度属于画，不属于通道**
  （[P110h] 加火焰眼球塔时踩到的就是这个）。
- **没有 SVG**：一条光是"两个点之间"的东西，画不出来也缩放不了，所以是**代码画的图元**，
  闭集在 `Fx.BeamLance._draw` 的 `match` 里（与 `Projectile` 的「外观」表同一个形状）。
  数值（时长 / 粗细 / 颜色 / 张角）进 `BalanceUI.BEAMS`。
- **id 接线**：`data/units/monsters.csv` 的 **`远程特效`** 列 → `PieceDB.ranged_fx`
  → `Unit.ranged_fx_id()` → `Fx.spawn_beam(id, from, to)`。与近战图画同一条链，只是多了第二个端点。
  id 写错**不静默**：回落到 `laser` 并打日志（规则在规格 §8）。
- **[B14] 出膛点**：`BEAMS` 每行的 `muzzle` 按**棋子画框的比例**给（默认 `Vector2.ZERO` = 身体中心；
  雷写 `-0.375` = SVG 的 (16,16) 在 128 px 画布上），因为乱斗会把棋子按
  `BrawlLayout.piece_scale` 画大（`Unit.art_box()`）。**一闪与通道共读同一个答案**
  （`Fx.beam_muzzle(kind, box)` ← `BrawlActor.muzzle(kind)`）；通道**每帧重读**，
  于是走着放雷的身体带着角走。
- **[B14] 大招共画**：`大招持续` 有数的棋子开的是同一条通道，
  只是每跳值一整下（`BalanceBrawl.ULT_TICK_SHARE`，节奏型通道是 `BEAM_TICK_SHARE`）。

---

## 6b. 旋风：行走的区域那一族（[B39] 落地 / [B41] 两套画法与白色风痕）

规格侧它是 `docs/prompt/FX.md` §1 的**第五种**（判据仍是寿命），本节只回答它落在哪。

| 事实 | 业主 | 说明 |
|---|---|---|
| 那块范围怎么走、多宽、多久一拍、一拍值多少、占多高的空气 | **`BalanceBrawl.TORNADO_*`** | `CELLS_PER_SECOND`（[B41] 2.2 → 1.4）/ `REACH_CELLS` / `TICK_SECONDS` / `TICK_SHARE` / `HEIGHT_CELLS`；**走多远不在这里**——在表行 |
| 这一行的旋风走几格 | **`data/units/animals.csv` 的 `旋风` 列** → `PieceDB.tornado_cells()` → `HumanPiece.brawl_tornado_cells()`（第十三道门） | `—`/空 = 0.0 = 这一行不召旋风（`brawl_actor._strike_once` 的那一分支就跳过） |
| 画多大、转多快、几层、什么颜色、**用哪套画法** | **`BalanceUI.TORNADO_*` / `COLOR_TORNADO_*`** | 见下面的开关；[B40] 的**体型**那一档来自 `BalanceBrawl.TORNADO_SIZE_TIER`（与 `projectiles.csv` 的 `体型` 同一个词表） |
| 它是什么东西、怎么活、怎么被打死 | **`scripts/core/brawl/brawl_tornado.gd`** | 无 `class_name`，`brawl.gd` 按路径 preload（新全局类在无头跑里看不见） |
| 谁持有它、谁 tick 它、谁清它 | **竞技场**（`Brawl.tornadoes` / `spawn_tornado()` / `_tick_tornadoes()`，`restart()` 与落幕各清一次） | 与 `shots` / `beams` / `gulps` 并列的第四个 timed object |
| 伤害 | **`_sweep()` 逐拍调召唤者的 `land_hit()`** | 绝不另开一张伤害表（`BRAWL.md` §12）；第一拍在**整整一个周期之后**，**到寿先于出拍**，所以总拍数是可数的事实 |
| **[B42] 图鉴里的这一格** | **`AlmanacView._whirlwind_row()`** + 门 `shows_whirlwind()` | 射弹页签的**第十二格**（表里的十一行 + 它）：它**不是** `projectiles.csv` 的行，所以基类答 `false`（回合模式召不出旋风），只有经典/乱斗那页 `BrawlAlmanacView.shows_whirlwind()` 答 `true`——同一份实现，两个页签各说各的实话 |
| [B42] 那一格与那块面板的每个数 | **现读，图鉴一个都不发明** | 面板八行（`_whirlwind_lines()`）：形状 / 召唤单位（**各棋子表行的 `旋风` 列**，`PieceDB.tornado_cells()`）/ 移速·风环·每拍·高度（`BalanceBrawl.TORNADO_*`）/ 体型（`TORNADO_SIZE_TIER`，与射弹的 `体型` 同一把梯子，同一个措辞 `_tier_scale_text()`）/ 画法（`BalanceUI.TORNADO_PAINTER` + 帧时长）。**一个 px 都不印**：乱斗的格子是窗口的（`BrawlField.cell()`），图鉴报的数必须是竞技场此刻真在用的那一个 |

**五个形状里它排第二，而且排在高度门之上**（`_strike_once`）：射弹与旋风是两只**已经离开身体**的
攻击，自带一柱空气、自己每拍回答高度问题；吞噬 / 远程特效 / 近战三种是"在这儿打在这儿"，
才需要那道门。`_strike_once` 里**不给旋风传 target**（[B41]："身前召唤"，方向 = 召唤者自己的 `facing`）。

**两套画法，一把尺子（[B41]）**：

- 开关 = `BalanceUI.TORNADO_PAINTER`（闭集两个词：`TORNADO_PAINTER_FRAMES` / `TORNADO_PAINTER_VECTOR`），
  节点在 `summon()` 里**读一次**并落进 `_painter`——飞行中途换画法等于换了个东西（与 `_tier` 冻结同理）。
- **默认是序列帧**：`_draw_frames()` 取 `BalanceUI.TORNADO_FRAMES = ["tornado_0", "tornado_1"]`，
  每 `TORNADO_FRAME_SECONDS`（0.08 s）翻一格，时钟就是 `_age`（定步长 ⇒ 回放读到同一帧）。
  路径**不在这里拼**：`Fx.melee_fx_path()` 是全工程唯一拼 `assets/svg/fx/` 的地方，
  纹理走 `UnitArt.load_texture()`（缓存），一局召六次也只读盘一次。
- **环钉在实测墨迹上**：`UnitArt.ink_fractions()` 量出的 ink 宽 = **2 × `TORNADO_REACH_CELLS`**，
  于是素材自己的空白边**不能**替伤害改口（[B36] 那套"形状归素材"的手法，用在特效上）。
  ink 底边钉在局部 `y = 0`（节点的位置就是环心、就是这一拍量身体的那一点）；
  高度 = 素材自己的比例，**再夹到 `height.z_thickness`**：可以画矮、不可画高。
- **备选是代码画的柱子**：`_draw_vector()`，就是 [B39]/[B40] 那套 band/wall/debris，一个字没改。
  ⚠ **两套画法在文件里是两个函数**，一个表达式写错只丢那一套——[B40] 之前 `_draw` 是一条
  语句清单，画错一行**整幅画**没（就是那次 `brawl_tornado.gd:276` 的形状）。
- ⚠ **素材读不到 ⇒ 当场退回 `_draw_vector()`**（`_load_frames()` 清空、`summon()` 降级）。
  这一批要杀的是"完全看不到旋风"，一个缺文件不许变成它的第二次发作。

**图鉴跟着这把尺子（[B42]）**：

- **格子只能显示文件**：`ItemGrid` 的 `tile.setup()` 收的是**路径**，没有"look"这个参数——那十一发代码画的
  弹在格子里也就是"有贴图才看得见"。所以旋风这一格的画 = **开关点名的那一套**的**第一帧**
  （`Fx.melee_fx_path(TORNADO_FRAMES[0])`，与节点用的是同一条拼路径的路）；开关切到柱子时这一格**不给图**，
  小字写"代码画的柱子"而不是"暂无贴图"——素材在盘上，是规则没在用它们。
- **面板按画布自己的比例画**（`AlmanacView._draw_art_kept_ratio()`，行键 `fit`）：`tornado_0.svg` 是
  **256×320**，而这一页每一张别的画都是方的，`UnitArt.draw_item_icon()` 会把它**拉满方框**——把一个高个子的
  旋风压成一颗豌豆，正好把这一格要说的两件事（`体型`、`高度`）自己推翻。
- **面板上没有一个数来自贴图文件**：尺寸那一行**不给**（`尺寸` 是表行点名的像素框，旋风的框是**量出来的
  ink**），改由 `风环` 那一行说它在草地上的宽度，单位是**格**。

**白色风痕**（`_draw_trace()`，[B41]，用户点名"通过白色风痕表现旋风"）：从 `_born`（召唤那一点）
量回节点当前的位置，**宽度 = 环的直径**、alpha 按平方衰减到 0，只记得最后
`TORNADO_TRACE_CELLS` 格——是彗尾不是马路。**两套画法都画它**，因为它说的是规则（哪些草地已经被扫过），
不是长相。

**图层**：`BalanceUI.BRAWL_TORNADO_Z`（20）——§9 那条"谁拥有坐标，谁拥有图层"在这里成立：
它不在 `Fx` 那一层上，`Fx.clear()` 也清不到它，因为它由竞技场持有、跟着定步长走。

**一局一行的日志**（`Brawl.spawn_tornado()`，`_tornado_logged` 在 `restart()` 里重新装填）：
"没生成"与"生成了但没画上"是两个问题，日志把它们分开，而**不写探针脚本**（AGENTS.md §2）。
[B41] 起这一行还报 `painter=frames|vector` —— `vector` 就是"素材没导入"的那只鸟。

---

## 7. 飘字（数字）一族（`Fx.spawn_popup`）

- 业主 `Fx.FloatingText`：0.9 秒里往上飘 40 px 并淡出（`BalanceUI.POPUP_*`）。
  **跟着那一块地方**，不跟着身体——判据与图画完全一样（规格 §1）。
- 回合制：太阳、破甲、啃脑、吞噬各一处。**乱斗：`BrawlActor.land_hit()` 里读
  `take_damage()` 前后的 hp 差**，每次命中冒一个 `-N`（[B12]）。
- ⚠ **漂字挂在 `land_hit` 而不是 `take_damage()`**：百分比流血（狂暴）不进屏幕
  ——理由与"糊满屏幕"同条（规格 §1；`docs/OPEN_ITEMS.md` 也记了）。

---

## 8. 被吞状态的实现（[B10]，规格 §1 那一族）

身体在肚子里是**缩小 + 染色 + 画在本体之上**，挂多久由消化决定，
由 `BrawlGulp` 结束时撤销（`BrawlActor.be_swallowed` / `release_held`）。

| 项 | 值 | 谁读 |
|---|---|---|
| 大小 | `BalanceUI.GULP_PREY_SCALE`（0.5） | `BrawlActor._apply_belly_pose` |
| 颜色（含 alpha） | `BalanceUI.COLOR_GULP_PREY` | 同上 |
| 图层 | `BalanceUI.GULP_PREY_Z`（1，画在吞噬者之上） | 同上 |

- **进肚子那一帧仍然播一次 `hit`**（§2 表里的一行）：那一次才是具名特效，之后挂着的是状态。
- ⚠ **画在背后等于看不见**：吞噬者的画（`assets/svg/units/monsters/slim/*.svg`）是一块**不透明**的色块，
  所以猎物必须画在它上面。想让"从肚子里透出来"更好看，改的是**素材**（半透明的身体），不是这里的 z。
- **不还原尸体**：身体一旦开始淡出（`play_death`），大小与颜色归它自己管——
  把一个正在消失的身体恢复成原样，是这类状态最容易留下的 bug。

---

## 9. 图层挂在哪：**谁拥有坐标，谁拥有图层**

`Fx` 只有**一个**静态图层，`attach(board)` 决定它挂在谁下面：

| 棋盘 | 挂给谁 | 为什么是它 |
|---|---|---|
| 回合制 | `battle.gd` → `grid`（草坪） | 单位的父亲是 grid，调用点传的就是单位坐标 |
| 乱斗 | `brawl.gd` `_ready()` → `field`（`BrawlField`） | 单位的父亲是 field（`_attach_piece`），`BrawlActor._sync_position` 写进去的就是 field 本地坐标 |

**[P110d] 乱斗这一层是后补的。** 在它之前 `Fx.attach()` 全仓只在 `battle.gd` 调过一次，
于是乱斗里 `_put()` 把每一张图画**静默丢掉**——不报错、也不显示，最难查的那种丢法。

- 两个棋盘不会同时在台上，所以那**一个**静态图层不会打架：谁在台上谁挂的算数；
  棋盘拆掉时图层随它一起走，`_put()` 见到失效的图层就把新图画丢掉（`is_instance_valid` 那道门）。
- 乱斗重开一局（`Brawl.restart()`）**不重建 field**，所以那里另有一句 `Fx.clear()`——
  重赛不该继承上一局的爪痕。
- `z_index = FX_Z_INDEX`（100）是**唯一**让图画压住单位的东西：单位自己不设 `z_index`，
  而这一层总是在单位**之前**加进树里的，树序帮不上忙（P76 把它设成常驻图层时要解决的就是这个）。
- 光束通道**不在这层**：它是竞技场的节点（`brawl_beam.gd`），跟着两个身体走（§6）。

---

## 10. 怎么加

### 加一条新特效（六步）

1. **`balance_ui.gd`**：加它要读的数值（角度 / 时长 / 像素），名字以 `FX_` 开头。
2. **`unit_fx.gd`**：加一个 `const ID_*`、在 `priority()` 与 `spec()` 里各加一行。
   通道只有 `lean` / `push` / `sway` / `jelly` / `time` 五样可以填（红闪与淡出不在表里，§1）。
3. **调用点**：`something.play_fx("新 id")`。
4. **规格 `docs/prompt/FX.md`**：§3 的表加一行、§5 的触发时机加一行。
5. **`docs/STATE.md`**：这一批收尾时记一行。
6. 新 `class_name` 才需要编辑器扫一次（`docs/ARCHITECTURE.md` §1.3，无头也能扫，AGENTS §1.4）；
   **加一条特效不需要**。

### 加一条新通道

先在 `Unit` 里把它实现成一个变量 + 一个 `*_pose()` 门，再回第 2 步把它写进表。
**表里不许出现没人在画的通道名。**
⚠ **[B33] 两个先例值得照抄**：`sway_pose()` 用的还是 `_lean` 这个变量（只是把它连成一串来回），
所以它**不是**新通道；而空闲的形变是**新变量 + 新补偿函数**（`_idle_stretch` / `_deform_offset()`），
因为它要的是"缩放也绕脚底"。**能不能复用现有变量，取决于它写的是同一个数还是同一个数轴。**
⚠ **[B34] 是这条判据的第三种答案**：果冻既有自己的变量（`_jelly`，一个阻尼时钟）又**复用**
形变的补偿与出口——它不写 `_idle_stretch`（那是空闲的数），只在读的时候**相乘合成**。
"两个活物要同时动同一个数轴"时，抄这一条：**各留各的变量，画面读合成**。

### 加一种死亡表演 / 加一种空闲表演（§2b）

都不走上面六步，也不动优先级表（**一条特效始终只有一行**）：

- 死亡：`UnitFx.death_spec()` 加一行、`BalanceUI` 加它读的数、调用点写 `play_death("新名字")`。
- 空闲 [B33]：`UnitFx.idle_spec()` 加一行（`kind` 必填，需要数就带 `amp` / `speed`）、
  `has_idle()` 的封闭集加那个名字、`BalanceUI` 加它读的数，然后
  **`Unit._tick_idle()` 里必须有人画它**——今天的分支只有 `stretch` 与"其余都按呼吸走"，
  第三种演法要在那里加第三条腿（这是唯一一处 Unit 会问"是哪一种"的地方）。
  调用点写 `unit.set_idle_fx("新名字")`。
- ⚠ **默认值只有一个业主**：`UnitFx.DEATH_TOPPLE` / `UnitFx.IDLE_DEFAULT`。换默认就改这一颗，
  别在调用点各写一遍。

### 加一张近战图画

`assets/svg/fx/` 放图 → 表格里那一格写**短名**（§5）。

### 加一种光束

`Fx.BeamLance._draw` 的 `match` 加一支、`BalanceUI.BEAMS` 加一行
（时长 / 粗细 / 颜色 / 张角 / `phase_speed` / `muzzle`）→ `monsters.csv` 的 `远程特效` 点名它。

---

## 11. 数值都在哪

**全部在 `scripts/balance/balance_ui.gd`**（归属规则见 AGENTS.md §2："只有绘制代码读的进 `BalanceUI`"）：

| 前缀 / 表 | 服务谁 |
|---|---|
| `FX_*`（`FX_HIT_LEAN` / `FX_ATTACK_LEAN` / `FX_PELLET_SCALE` / `FX_IDLE_STANDDOWN` …） | 具名特效的姿态量 |
| `FX_STUN_*`（`_LEAN` / `_SWINGS` / `_SWING_TIME` / `_DAMP`，[B33]） | 眩晕的来回：第一下的角度、段数、每段多长、每段缩多少 |
| `FX_JELLY_*`（`_AMP` / `_FREQ` / `_DAMP`，[B34]） | 受击的果冻：第一下压扁的比例、ring 多快（rad/s）、e^−λt 衰减多狠；时钟长度借 `ANIM_SHAKE_TIME`，射弹幅度乘 `FX_PELLET_SCALE` |
| `ANIM_*`（`ANIM_SHAKE_DIST` / `ANIM_SHAKE_TIME` / `ANIM_LUNGE_DIST` / `ANIM_DEATH_TIME` …） | 补间时长与位移像素 |
| `DEATH_*`（`DEATH_TOPPLE_ANGLE` / `_TIME` / `_OVERSHOOT` / `_SETTLE_TIME` / `DEATH_FADE_SHRINK`） | 两种死亡表演（§2b） |
| `IDLE_*`（`IDLE_BOB` / `IDLE_SWAY` / `IDLE_BREATHE` / `IDLE_SPEED` / `IDLE_PHASE_STEP`） | 呼吸那一支（**旧基线**，[B33] 之后不再是默认） |
| `IDLE_STRETCH_*`（`_AMP` / `_SPEED`，[B33]） | 形变那一支（**默认基线**）：伸长的幅度（比例）与快慢（弧度/秒） |
| `BEAMS`（每行一个 id） | 光束（§6） |
| `TORNADO_*`（`_PAINTER` / `_FRAMES` / `_FRAME_SECONDS` / `_TRACE_*` / `_RING_*` / `COLOR_TORNADO_*`，[B41]） | 旋风的**画法与开关**（§6b）：两套画家里哪一套、帧名与 80 ms、白色风痕的段数/长度/颜色、诚实环的颜色与粗细。**规则数不在这里**（走速 / 半径 / 脉冲 / 份额 / 风柱高在 `BalanceBrawl.TORNADO_*`，距离在 `data/units/animals.csv` 的 `旋风` 列）；**[B42] 图鉴的射弹页读的就是这一族**（`_whirlwind_row()` / `_whirlwind_lines()`，见 §6b 末） |
| `GULP_*` / `COLOR_GULP_PREY` | 被吞状态（§8） |
| `POPUP_*` | 飘字（§7） |
| `FX_Z_INDEX` | 图层（§9） |

`unit_fx.gd` 里不许出现字面量；乱斗落幕 `BalanceBrawl.BOUT_CURTAIN_SECONDS` 与死亡总时长的
牵制见 §3。红闪的量在 `Unit` / `take_damage()` 一侧（它不在表里，D2）。
