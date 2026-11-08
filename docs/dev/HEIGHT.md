# HEIGHT.md · 高度系统实现计划（`[B17]`）

> 配套规格：**`docs/prompt/HEIGHT.md`**（规则语义在那份里，本文只回答"改哪些文件、按什么顺序、锚点在哪"）。
> 状态：**[已定]（2026-10-06）**——规格经两轮现场核对修订（D100 改口径、D104 新增）后转已定，本文随其同步，**开工中**。
> 纪律：**不开新 `class_name`**（路径 preload，`brawl_shot.gd` 先例）；**不写测试脚本**（AGENTS.md §2）；
> 验收由用户手动跑（§10 那条固定形状）。行号是 2026-10-06 工作区的读数，实现时以函数名重锚。

---

## 0. 总原则

- 权威位置仍是 cell XY；z 是同一 sim 的第二轴；像素只在渲染边界换算（`BrawlField.cell()`）。
- **两把尺子（D100 修订版，规格 §6）**：**素材设计基准 = 128px/格（固定）**，只管"素材 → cell"的缺省推算（`纹理px / 128`），与窗口无关；**`BrawlField.cell()` = 动态**（`BrawlLayout` 从窗口反推，S1 唯一尺子），只管"cell → 像素"的渲染换算（`z_cell × cell()`）。**本期不得改动 `cell()` 的动态性**（§11-9）。
- 第二道门（Z 区间相交）**加在每条命中路径的结算点**，不加进 `land_hit`——
  `land_hit` 是"落地的一击变成伤害"的唯一门（§8.7.2/D58），它的 z 已经由更前面的门选过受害者了。
- 旧表不补值 ⇒ 全员贴地 + `body_*` 走素材推算 ⇒ 一切行为逐帧不变（除新增地面影子视觉）。
  ⚠ **[B37] D113 起这条只剩一半**：`z_thickness` 的缺省改成实测 ink 高、1.0 格地板摘除，
  所以画得不足一格的身体命中窗口**变矮了**——逐条目视在 §11-5 目视项 4 / 5。
- **单位与射弹共用 `HeightBody` 数据结构与 `z_overlap` 静态函数**（规格 D103）。`BrawlActor` / `BrawlShot` 组合持有 `height := HeightBody.new()`。
- ⚠ **旧 96 基准连带的重估**：所有从旧像素基准（96 / 64）推导的 cell 常量（`LOB_APEX_CELLS` 等）必须按新口径重估——`cell()` 本身**保持动态不改**（§11-9），改的是这些常数的 authored 值与换算尺（素材推算一律 ÷128）。实现前先做一次 grep（§11-5）。

---

## 1. 数据层

| # | 文件 | 改动 |
|---|---|---|
| 1 | `data/units/units.csv` | **表头行**追加六列 `z_height` / `z_thickness` / `body_width` / `body_depth` / `body_xoff` / `body_yoff`。114 行数据**全部不动**——`read_table()` 按实际存在的 cell 建行字典，缺尾格读空 = default 链 ⇒ 代码兜底（这不是将就，这是方言里"空着 = 按默认值"的本义） |
| 2 | `data/projectiles.csv` | 表头追加**同名列**（与 units 完全一致）：`z_height` / `z_thickness` / `body_width` / `body_depth` / `body_xoff` / `body_yoff`；9 行留空（⇒ §5 的兜底） |
| 3 | `scripts/core/height_body.gd` | **新增文件**。`extends RefCounted`，**无 class_name**，路径 preload。字段与静态函数见 §1.5 |
| 4 | `scripts/core/unit_sheet.gd` | 六个列名常量 + 六个静态门：`z_height(p_id)`（兜底 0.0）、`z_thickness(p_id, p_fallback)`、`body_width(p_id)`、`body_depth(p_id)`、`body_xoff(p_id)`、`body_yoff(p_id)`——与 `defence()` / `face_left()` 同族：**共用列的门开在 sheet 上**，三个门面不复制 |
| 5 | `scripts/core/db/projectile_db.gd` | 行字典新增键 `z_height` / `z_thickness` / `body_width` / `body_depth` / `body_xoff` / `body_yoff`（float，**-1 = 表没说**，`speed` 列的同款形状）；`_use_fallback()` 的内建行补同名键（-1）。经典模式本期无人读这六键 |

### 1.5 `scripts/core/height_body.gd` 最终形状

```gdscript
# scripts/core/height_body.gd
extends RefCounted

var z_height := 0.0
var z_velocity := 0.0
var z_gravity := 0.0
var z_thickness := 1.0
var body_width := 1.0
var body_depth := 0.5
var body_xoff := 0.0
var body_yoff := 0.0

static func z_overlap(p_az, p_ath, p_bz, p_bth) -> bool:
    return p_az < p_bz + p_bth and p_bz < p_az + p_ath

func z_hits(p_other) -> bool:
    return z_overlap(z_height, z_thickness, p_other.z_height, p_other.z_thickness)

func integrate(p_dt: float) -> void:
    z_velocity -= z_gravity * p_dt
    z_height = maxf(0.0, z_height + z_velocity * p_dt)
    if z_height == 0.0:
        z_velocity = 0.0
```

**素材推算缺省**（`HeightBody` 在 `setup()` 时的读表逻辑）：

```text
z_thickness 表值优先；空 ⇒ 实测 ink 高 / 128（D112 的尺子，D113 摘掉地板；**没有素材可量**才答 UNIT_Z_THICKNESS_CELLS）
body_width  表值优先；空 ⇒ 素材纹理宽 / 128
body_depth  表值优先；空 ⇒ body_width / 2
body_xoff   表值优先；空 ⇒ 0
body_yoff   表值优先；空 ⇒ 0
"0" 的位置 = 素材底部中心点
（这里的 128 一律是素材设计基准，不是运行时 cell()，D100 修订版）
```

**射弹无素材时**：`body_width = SHOT_HIT_RADIUS × 2`、`body_depth = 0`，其余同缺省。

---

## 2. 身体层（Unit）

| # | 文件 | 改动 |
|---|---|---|
| 6 | `scripts/core/unit.gd` | `defence` / `faces_left` 旁边加 `var height := HeightBody.new()`（与 actor / shot 同款组合；unit 侧的字段是"墨"，actor 侧是"解算者"） |
| 7 | 六个 apply 点 | 在各自 `faces_left = UnitSheet.face_left(...)` 的下一行读 `height.z_*` 与 `height.body_*`：`scripts/units/zombie.gd::apply_type`（:183 区）、`scripts/units/human_piece.gd::apply_piece`（:60 区）、植物基类 `one_shot_plant.gd` / `producer_plant.gd` / `spike_plant.gd` / `wall_plant.gd`（各自 `defence = Balance.plant_attr_defence(...)` 处）、`chomper.gd`。⚠ `shooter_plant.gd` 的 stats apply 点**实现时现场确认**（它的 defence 不在 grep 命中的行形状里）。厚度兜底六处统一为 **`实测 ink 高 / 128`**（D104 定形 ⇒ D112 换尺子 ⇒ **[B37] D113 摘地板**，见 §8-25d；量不到素材时才是 `Balance.UNIT_Z_THICKNESS_CELLS`；§1.5、§3-8） |

---

## 3. 数值层

| # | 文件 | 新增 |
|---|---|---|
| 8 | `scripts/balance/balance.gd` | `UNIT_Z_THICKNESS_CELLS := 1.0`（全身高，世界几何 = 全局规则，两模式将来共读）。**[B37] D113 改了身份不改值**：它不再是缺省推算下面的地板，而是**"没有素材可量"时的那一份兜底**（贴图文件缺失 / 未导入），所以导入失败的单位仍是全身高而不是厚度 0 的薄片 |
| 9 | `scripts/balance/balance_brawl.gd` | 新开一节 "the height axis [B17]"：`SHOT_Z_CELLS := 0.45`（直线/追踪巡高兜底，齐胸口径，实现时按素材设计基准 128 复核）、`SHOT_Z_THICKNESS_CELLS := 0.25`、**`LOB_APEX_CELLS := 0.5`**（= 旧 64px 顶点按素材设计基准 128 换算；按 cell authored，弧高随棋盘缩放，与弹速同族 D73）、`Z_GRAVITY_CELLS := 4.0`（默认下落重力；行为 Phase 2，积分本期接） |
| 10 | `scripts/balance/balance_ui.gd` | `BRAWL_AIR_Z := 10`（浮空抬层：高于身体 0/1、低于 FX 100）；影子渲染常数 `BRAWL_SHADOW_FALLOFF`（随高缩放的衰减系数）、`BRAWL_SHADOW_DEPTH_SHARE := 0.5`（椭圆纵深 / 宽度，[B36] / D111 补）与 `COLOR_BRAWL_SHADOW`（复用 `COLOR_MENU_PROP_SHADOW` 那一支）——**只有绘制读它们**（AGENTS §2 的 BalanceUI 判据）。**[B36] `BRAWL_SHADOW_RATIO`（宽/格）与 `BRAWL_SHADOW_SQUASH`（压扁比）已删**（D111：影子不再有"自己的大小"，宽取素材实测 ink） |

⚠ `LOB_APEX_CELLS` 从 0.7 改到 **0.5** 是"抛射抬升从像素装饰改为 cell authored 权威"的连带（规格 §6 修订版）：0.5 cell 按素材设计基准 128 对旧 64px 顶点，运行时渲染走动态 `cell()`，弧高随棋盘缩放。`SHOT_Z_CELLS` 的 0.45 是齐胸口径，实现时复核一次视觉高度——若观感偏矮可微调，但不绑定旧 96 基准。

---

## 4. Sim：BrawlActor（`scripts/core/brawl/brawl_actor.gd`）

11. **字段**：`var height := HeightBody.new()`（setup 时从 unit 抄——身体是墨、actor 是解算者，与 `pos` / `facing` 同族）；`height.z_gravity` 默认 `BalanceBrawl.Z_GRAVITY_CELLS`。
12. **积分**（`tick` 内，`held_by` / 击退分支之后、走位之前）：`height.integrate(dt)`——`integrate` 内已处理落地清速度；今天所有身体 z=0 ⇒ 恒零运算，行为不变；Phase 2 的俯冲/跳跃直接骑在这条积分上。
13. **门**：静态 `HeightBody.z_overlap(...)` 与实例 `height.z_hits(other.height)` 均归 `height_body.gd`——**本文件不再自带这两个函数**（规格 D103）。
14. **`_strike_once` 的三种即时形状**（吞噬 :383 区 / 光束 :392 区 / 挥击 :410 区）与 **`_open_ultimate`**（:452）：分支前加一道 `if not height.z_hits(target.height): ...`——不过 ⇒ 只演 fx 不结算（对空挥拳的"徒劳"本身是反馈）。射弹形状不走这道门（它有自己的 `height`）。
15. **`_sync_position`**（:717）：`unit.position = _field.world_of(pos) + Vector2(0.0, -height.z_height * BrawlField.cell())`；z_index 规则：`height.z_height > 0` 时 `unit.z_index = BalanceUI.BRAWL_AIR_Z`，落回 0；**`held_by != null` 时不写**（肚子的 1 由 `_apply_belly_pose` 独有，别制造第二个业主）。
16. **`muzzle()` / 光束画线**：读 `unit.position`（已含抬升）自然正确，不用改。

---

## 5. Sim：Intent（`scripts/core/brawl/brawl_intent.gd`）

17. `separation()`：循环里加 `if not self.height.z_hits(other.height): continue`——字段用未类型化读取（本文件的"全部参数不注类型"纪律不破）。
18. `nearest_enemy()` **本期不改**（索敌口径在 Phase 2 清单里，见 §9-2）。

---

## 6. Sim：BrawlShot（`scripts/core/brawl/brawl_shot.gd`）

19. **字段换代**：`_lift`（px 装饰，:72）删除 ⇒ 组合 `var height := HeightBody.new()`（与 actor 同款）；`height.z_height` 权威、`height.z_thickness` 厚度、`_z_apex` 抛射顶点保留为本文件局部字段（射弹特有，不进共享结构）。
    `launch()` 读 `ProjectileDB` 的六键；-1 ⇒ `BalanceBrawl` 兜底（`SHOT_Z_CELLS` / `SHOT_Z_THICKNESS_CELLS` / `LOB_APEX_CELLS` / `SHOT_HIT_RADIUS × 2`）。
    直线/追踪 `height.z_height = SHOT_Z_CELLS`（恒定巡高）；抛射 `height.z_height = _z_apex * 4 * t * (1 − t)`（沿用 :224-226 的参数化，只换单位与语义：`_z_apex` = `LOB_APEX_CELLS`）。
20. **第二道门，三处**：`_swept_body`（:231，跳过区间不相交的身体）、`_tick_direct` 追踪到达（:175-181，到达但 `height.z_hits(target.height)` 不过 ⇒ 视为没到、继续飞）、`_nearest_enemy`（:256，落点找身体的 reach 同一条门）；`_clip_splash`（:337）用**落地那一刻的 z 区间**比邻居。
21. **doctrine 注释改写（必须，不留假话）**：头部 doc :19-21、`_tick_arc` 的 :203-206（"PRESENTATION; the ground track is what lands… never hit earlier or later" ⇒ "Z is authoritative; 越顶与被砸由区间决定"）、`_draw` 的 :374。
22. **渲染**：`_draw`（:369）`var at := Vector2(0.0, -height.z_height * BrawlField.cell())`（节点 position 仍是地面航迹——这条不变）。

---

## 7. Beam 与肚子（少改动，防过度设计）

23. `scripts/core/brawl/brawl_beam.gd`：续燃 tick 复用射手门的结论，**不逐 tick 复查 z**（Phase 1 的 z 在通道期间不会变；注释写明"接浮空行为的那一批要补逐 tick 判定"）。
24. `brawl_gulp.gd` / 消化结算：不动（门在 `_strike_once` 的吞噬分支已经拦下"吞不到空中"；prey 在肚子里与 holder 同 XY 同地面）。

---

## 8. 表现：视觉影子

25. 新脚本 `scripts/core/brawl/brawl_shadow.gd`（`extends Node2D`，**无 class_name**，路径 preload）：持 `actors` 池引用（与 `Brawl.shots` 同款交接），`_draw` 遍历活体画贴地椭圆：
    锚点 = `field.world_of(actor.pos)` 加**实测脚底**、x 恒在记号上、椭圆**宽 = 素材 ink 的实测宽**、**纵深 = 宽的一半**（[B36] / D111，见下 25b），宽与透明度同骑一条曲线 `÷ (1 + z × 衰减)`（z 取 `actor.height.z_height`，纵深乘同一个系数 ⇒ 等比）。画法抄 `MENU_PROP` 影子的先例。
    **贴地单位也画**（`z_height == 0` 也画常驻影子）——这是规格 D102 拍板的视觉常量，不是可选项。
25b. **[B36] 影子的锚点与宽度从素材来，纵深是一条算法**（用户当日三句口径："改锚点为实测 ink 底边，且设定 z 厚度是 ink 高度，x 宽度是 ink 宽度"→"影子的 y 轴宽度应当是 x 轴宽度的 1/2"→"ink 的高怎么不读了，ink 的高是 z 轴厚度呀"。第二句管的是**椭圆**的纵深，第三句把第一句里的"z 厚度"**归回高度轴**（下条 25c / D112）——两句各有读者，不是互相取代）：
    - `UnitArt.ink_fractions(path)` = 画布 0..1 的 ink 比例（`BalanceUI.auto_ink_box()` [B35] 的读数换算成比例，按 path 缓存一次）；
      `UnitArt.ink_rect(path, at, size)` = 把比例落到"某个具体方框"的像素里。**量不出来时回创作契约**（整幅画布宽、底边落在 `VIEW_ART_FEET_LINE`）而不是整张画布——契约兜底与 `fit_view()` 放脚的那条线是同一条，所以素材、视图场景、读不到像素的导入三者站在同一片地上。
    - `Unit.art_ink()` = 这只身体**实际画了什么**（`art_box()` 方框的本地像素，三个艺术层级按 `_draw_body()` 的次序答）：视图场景自己答（origin 就是脚线）→ 贴图实测 → 平面占位形画满 `body_size`。
    - `BrawlShadow.draw_ink_shadow(canvas, mark, ink, z)` = 两页共用的那一句：ink 的 y **从 mark 起算**（竞技场的 mark 是身体原点，编阵页的 mark 是图标框顶中点），于是 `ink.end.y` 就是脚底；宽度 = `ink.size.x`，**纵深 = 宽 × `BRAWL_SHADOW_DEPTH_SHARE`**（0.5，与 D99 的 `body_depth = body_width / 2` 同一条占地算法）——**椭圆的纵深不量素材**；ink 的高不是没人读，它的读者是**高度轴**（下条 25c）。曲线只乘宽度，透明度同乘，纵深由宽度算出来 ⇒ 三者天生等比。
    - **代价**：`BRAWL_SHADOW_RATIO`（0.55 = 宽/格）与 `BRAWL_SHADOW_SQUASH`（0.26 = 纵深/宽）**删了**——影子不再有"自己的大小"，宽度归素材、纵深归算法，新常数只有 `BRAWL_SHADOW_DEPTH_SHARE = 0.5`（`BRAWL_SHADOW_FALLOFF` 与颜色留下）。肉眼可见的两处变化：① 宽不再统一是 0.55 格，而跟着身体自己画的宽走（宽植物宽影、瘦身影）；② 形状从 26% 压扁放宽到 50%，且**等比**——旧写法里宽度乘一次曲线、纵深乘两次（`RATIO × curve` 再 `SQUASH × curve`），飞起来的身体会越飞越扁，现在两边同骑一条曲线。
25c. **[B36] `z_thickness` 的尺子从画布换成实测 ink（D112，同批的第二半）**：`UnitArt.ink_span_y(path)` = ink 占**自己画布高**的比例（`ink_fractions()` 的读数，量不到答 **1.0** = 照旧信画布，缺文件的身体绝不因"没量到"而变薄）→ `Unit.read_height()`（`scripts/core/unit.gd:303-308`）把 `画布高 / 128` 改成 `画布高 / 128 × ink_span_y`，**其余两层优先级一字未动**：表值仍压过它（`UnitSheet.z_thickness()`），`max(…, Balance.UNIT_Z_THICKNESS_CELLS = 1.0)` 那条过渡地板仍压过它（D104 的"逐帧不变"承诺）。
    - **所以今天一条读数都没变**：在册的 58 张单位素材全是 128×128 画布（`reyi.svg` 那张 256×384 没有被任何表行引用），而 ink 高**恒 ≤ 画布高** ⇒ 量出来都 < 1 格 ⇒ 地板全部接走、答案仍是 1.0。**这条改动改的是口径不是数**——身体够到多高从此由身体自己答，画布尺寸降级成"量不到时的兜底"。
    - ⚠ **地板与这条实测是相向的**：D104 原本写"128 基准素材进场后 `纹理高/128 ≥ 1.0` 自然失效"，改量 ink 之后那个失效条件**变成"ink 高 > 1 格"**（画布再高，只要 ink 不越出一格就仍被夹住）。**要 ink 高立刻当家，必须另拍一条降/摘 `UNIT_Z_THICKNESS_CELLS`**——那是同时改两种模式的命中窗口（`z_hits` 的读者：`brawl_actor.gd:452/:558`、`brawl_shot.gd:299/404/427/558`、`brawl_intent.gd:115/160`；回合制现在不读这条轴），本轮没有点，所以没动。**⚠ 本条记录的"地板仍在"当天就被推翻了：用户接着点了这一条 ⇒ 见 25d。**
    - **同一条猜测还留在别处**：`Unit._feet_offset_y()` 的贴图分支当时照旧答 `art_box() * 0.5`（[B25] 倒地轴心、[B33/34] 形变压脚都读它）。**本批收尾那天用户点了它 ⇒ 见 25e**。
25d. **[B37] 地板摘掉（D113，用户 2026-10-09："要降/摘 `Balance.UNIT_Z_THICKNESS_CELLS`，让 ink 高真的当家"）**：`Unit.read_height()`（`scripts/core/unit.gd:306-313`）里那条 `maxf(texture_h, Balance.UNIT_Z_THICKNESS_CELLS)` 删除，缺省推算就是**实测 ink 高 ÷ 素材设计基准**。
    - `Balance.UNIT_Z_THICKNESS_CELLS = 1.0` **不删、值不改**：它从"地板"降级为**"没有素材可量"那一格的答案**（贴图文件不存在 ⇒ `texture_h` 直接取它），所以一只导入失败的单位仍是全身高，绝不会是厚度 0、谁都打不中的薄片。这条降级写在 `balance.gd:71-79` 那段注释里，`UnitSheet.z_thickness()` 的门与表值优先**一字未动**。
    - **它把 D112 的口径兑现成数**：25c 那天"今天一条读数都没变"就是因为这条地板在答题；现在每一只身体的 `z_thickness` = `画布高/128 × ink 比例`。**能确定的只有上界**：ink 恒 ≤ 画布、画布按 128 基准 ⇒ 答案 **≤ 1.0 格**，而契约要求脚底下留 16 px（`VIEW_ART_FEET_LINE`）⇒ 守契约的素材**最多** 0.875 格。**具体每只多高没人量过**（地板把这条轴抹平了，全仓也没有过量它的脚本），所以 D113 之后的第一次目视（§11-5 目视项 5）才是真读数。
    - ⚠ **代价与读者**：命中窗口第一次真的跟着美术走。`z_hits` 的读者全在乱斗——`brawl_actor.gd:452/:558`、`brawl_shot.gd:299/404/427/558`、`brawl_intent.gd:115/160`（**回合制现在不读这条轴** ⇒ 今天只有乱斗的命中受影响）。乱斗直行弹道的区间是 `BalanceBrawl.SHOT_Z_CELLS 0.45 + SHOT_Z_THICKNESS_CELLS 0.25` ⇒ **一只画得不足 ~0.45 格的身体会被平射从头顶飞过**。这段高度原来写的是"必然与 `[0, ≥1]` 相交"（地板给的保证），地板没了那句就重写成"看它画多高"（`balance_brawl.gd:132-138`）。**要一只身体矮到钻过去，用它自己的表行说**（`z_thickness`，或给那发弹写 `z_height`），不要再把地板放回去。
    - **射弹侧不受影响**：`brawl_shot.gd:191-193` 的厚度走 `projectiles.csv` 的 `z_thickness` 列，没写就答 `BalanceBrawl.SHOT_Z_THICKNESS_CELLS`，从来没接过这条地板。
25e. **[B37] 脚底线归实测（D114，用户 2026-10-09："`Unit._feet_offset_y()` 的贴图分支要也改用实测 ink 底边"）**：那个四行函数（视图场景答 `art_view.position.y` / 贴图答 `art_box() * 0.5` / 占位形答 `body_size * 0.5`）**整条收成一行** `return art_ink().end.y`——[B36] 为影子建的那扇门从此是**唯一**的脚底业主。
    - **三个层级的答案与旧写法比**：视图场景**一模一样**（`art_ink()` 的视图分支 `end.y` 代数上就是 `art_view.position.y`）、平面占位形**一模一样**（画满方框 ⇒ `body_size/2`）、只有**贴图**从画布底边抬到墨迹底边（守契约的素材恰好抬 `art_box()/8`，即 `VIEW_ART_FEET_LINE` 之下那 16 px 的余量）。
    - **读者与影响面**：`unit.gd:1046` 的倒地翻倒轴心、`unit.gd:723` 的眩晕晃轴心、`unit.gd:790` 的形变压脚（空闲拉伸 × 受击果冻共用同一条线）。**两种模式都读**（`Unit` 是共用身体，`BrawlActor` 组合持有它）⇒ 尸体翻倒的杠杆与压脚点同时上移；影子与脚线现在**同一个数**，所以"脚不动胸动"和"影子贴脚"再也不会互相矛盾。
    - ⚠ `art_ink()` 现在进了**每帧**路径（`_deform_offset()` 在形变非单位大小时每帧问一次）。业主是 `UnitArt._ink` 那张按 path 缓存的比例表（[B36] 建），所以一次调用 = 一次字典查表 + 若干次乘法，不需要再加缓存。
26. 挂点：`Brawl._begin()` 里把影子节点加进 `field`（**在 pieces 之前**，靠树序垫底）；`Brawl._process` 已每帧 `queue_redraw`，影子节点跟着 redraw 一次。
27. ~~图鉴/编阵页**不画影子**~~ **改口（用户 2026-10-06："增加在编排战阵阶段就显示视觉影子"）**：**编阵页画**——它的地盘就是竞技场同一套 `BrawlField` 几何（D66），站在格上的身体（己方摆位 + 敌阵可见预览）经 `BrawlShadow.draw_ink_shadow()`（[B36] 之前叫 `draw_shadow()`）**同一个静态画师**落影，图鉴仍是无影（卡片不是站场的身体；候战席 / 候选带 / 背包 / 拖动鬼影同样不画）。

---

## 9. Phase 2 清单（本期只留形状，不写代码）

1. 俯冲 / 跳跃 / 降落 = 给 `height.z_velocity` 赋值的攻击行为 + 窗口期判定（俯冲中可被反击）；
2. 空中索敌：`nearest_enemy` 按"够得着的区间"过滤 + 地对空优先级（否则地面僵尸绕圈）；
3. 浮空射手的射弹继承发射高度；浮空被砸落地的瞬间结算细节；
4. 经典模式接法（格子 XY 重叠 = 列判定，z 门加在 `Spawn` / `Projectile` 的会合点，另批设计）；
5. 测试单位开飞（用户点 1–2 枚写表，手动测手感）；
6. 光束通道逐 tick z 复查（见 §23 注释）。

---

## 10. 回归与验收（用户手动）

- 一条固定形状（AGENTS §1.7.7 已登记 allow）：
  `godot --headless --path . --quit-after 240 > /tmp/pvz_check.txt 2>&1`
  **期望**：`[Shot]` / 各 sheet 自检块无新增 complaint（新列留空**不**触发 `_check_column`——列在表头里；
  只有读错列名才会报），无红 FAIL。
- 开一局乱斗目视：
  1. **卷心菜/西瓜抛射弧线与改前视觉等高**（`LOB_APEX_CELLS = 0.5` 按素材设计基准 128 对旧 64px 顶点；默认窗口下 live cell ≈ 104，弧线随棋盘略缩——若观感偏差 ⇒ 回查 §3-9）；
  2. 弓手/火枪命中照旧；`SHOT_Z_CELLS` 的 0.45 复核视觉高度；
  3. **贴地单位脚下常驻小影子**（规格 D102）；影子随高度缩小变淡；
  4. ~~老单位行为逐帧不变（全表空 ⇒ 全 z=0 + `body_*` 走素材推算）。~~ **[B37] D113 起这条不再成立**：
     全表空 ⇒ 全 z=0 没变，但 `z_thickness` 从"地板 1.0 格"改成"实测 ink 高"，**命中窗口对每一只画得不足一格的身体都变矮了**。
     这正是用户点单要的（"让 ink 高真的当家"），所以目视要看的是**新的正确**而不是旧的一致：矮身体该被齐胸弹打中的仍然打中、
     跳起来的身体该钻过去的确实钻得过去。
  5. ~~**矮素材不躲平射**：现有素材（按 96 基准画）在 `max()` 兜底后 `z_thickness ≥ 1.0 cell`，
     直线弹区间 `[0.45, 0.70]` 必然与贴地单位的 `[0, ≥1.0]` 相交；平射命中与改前逐帧一致。~~
     **⚠ 这条承诺已由 [B37] D113 撤销**：地板一摘，`z_thickness` 就是实测 ink 高，**够不到 0.45 格的身体会被平射从头顶飞过**——
     这不是漏洞而是这次拍板的代价（"让 ink 高真的当家"）。所以目视项换了问题：
     **每一只贴地单位都该吃到每一发直行弹道**；若某只单位**看起来被擦过头**，先看它画得够不够高（`ink 高/128` 是否 < 0.45），
     要它矮就**给它的表行写 `z_thickness`**（或给那发弹写 `z_height`），**不要**再把地板放回去。
     注意 roster 从没在这条轴上被量过（地板把问题抹平了），所以这一条是**第一次真看**。
- **确认点 B**：表头列名——单位表与射弹表**统一用** `z_height` / `z_thickness` / `body_width` / `body_depth` / `body_xoff` / `body_yoff`（ASCII 族），
  与各自表既有方言（`速度` 历史遗留像素列）**明确不同族**；要改名现在改，一列名一个业主、后续不折腾。

---

## 11. 风险与已核对事实

1. `UnitCsvManager._check_column`（unit_csv.gd:259）只对"**表头没有**却被读的列"提 complaint ⇒ 先加表头再读，安全；
2. 无新 `class_name` ⇒ **不需要** `--import` 工程维护跑（§1.4）；
3. 确定性：所有新门都是纯比较（字段读序不变），`separation` / `nearest_enemy` 的池遍历顺序不动；
4. `BrawlActor` ↔ `BrawlField`：`cell()` 是 `BrawlField` 的**静态**函数（brawl_field.gd:61），实例与静态两处都能拿，渲染统一走静态；
5. **旧 96/64 像素基准的存量常量普查**（`cell()` 本身不改，见 §11-9）——实现前先 grep 一次：
   ```bash
   grep -rn "96\b" scripts/ --include="*.gd" | grep -v "font_size\|line_height"
   grep -rn "64\b" scripts/ --include="*.gd" | grep -v "color\|alpha"
   grep -rn "基准格\|cell()" scripts/core/brawl/
   ```
   凡是从旧 96 基准推出来的值，都在 §3-9 一节里集中重估。实测锚点（2026-10-06）：默认窗口 1280×720 下
   `BrawlLayout.compute_for` 反推出 live cell ≈ **104**（高向受限），既不是 96 也不是 128——"逐帧不变"的
   验收不能拿像素等式做标准，只能拿行为做标准；这是本轮唯一容易翻车的隐藏依赖；
6. `_lift` 删除后，任何残留的 `brawl_shot.gd:72` 引用都要清掉；
7. 本计划未逐行读过 `brawl_beam.gd` / `brawl_gulp.gd` / `shooter_plant.gd`——实现时按 §23 / §24 / §2 标注的锚点现场核对，与计划不符先报告再动手；
8. `HeightBody` 在 `_strike_once` / `separation` 里的类型化读取：GDScript 静态类型下 `self.height.z_hits(other.height)` 需要 `other` 有 `height` 字段——若某处 `other` 是裸字典或未类型化，退回 `HeightBody.z_overlap(a.z_height, a.z_thickness, b.z_height, b.z_thickness)` 的静态形式。
9. **`cell()` 动态性不得在本期改动**（D100 修订版）：`BrawlField.cell()` 是 `BrawlLayout` 从窗口反推的动态唯一尺子（S1/S2/D73 业主）；**素材侧 128 是设计基准**（固定换算尺），两者不得混称。任何"顺手把 cell 钉成常数"的改动都是另一批布局改革，不进本期。

---

**改动摘要（相对 2026-10-06 提案版，本轮转【已定】）**：

1. **D100 修订落地**：§0 / §1.5 / §3-9 / §10 / §11-5 的"cell() = 128"字样全部改为
   "素材设计基准 = 128px/格（固定）；`cell()` = `BrawlField.cell()`（动态）"两把尺口径；
   新增 §11-9（本期不得改动 `cell()` 动态性）；实测 live cell ≈ 104 登记进 §11-5；
2. **D104 落地**：§1.5 与 §2-7 的 `z_thickness` 缺省统一为 `max(素材推算, UNIT_Z_THICKNESS_CELLS)`，
   消除了旧版 §1.5（素材推算）与 §2-7（传 1.0 兜底）的口径冲突；§10 新增目视项 5"矮素材不躲平射"；
3. 状态转【已定】，开工中。

**改动摘要（相对 2026-10-06 上一版）**：

1. §0 加入 `cell() = 128` 总原则与连带提示；
2. §1 数据层扩为六列（units 与 projectiles 同名列），新增 `scripts/core/height_body.gd`（§1.5）；
3. §2 `unit.gd` 组合持有 `HeightBody`；
4. §3-9 `LOB_APEX_CELLS` 0.7 → **0.5**；`SHOT_Z_CELLS` 注明按 128 基准复核；
5. §4 字段换代：`height := HeightBody.new()`；`z_overlap` / `z_hits` 归 `height_body.gd`；
6. §5 separation 用 `height.z_hits`；
7. §6 `_lift` → `height.z_height`；三处门改用共享静态函数；
8. §8 视觉影子读 `actor.height.z_height`；贴地单位常驻（规格 D102）；
9. §10 验收更新：加 `LOB_APEX_CELLS` 复核项、`SHOT_Z_CELLS` 复核项；确认点 A 已删（规格拍板贴地画影子）；
10. §11 加 `cell()` 96→128 的 grep 清单与 `HeightBody` 类型化注意点。
