# 单位贴图（植物 / 僵尸）：代码结构与我怎么改

> **这份文档写什么**：**已经实现**的单位贴图接线 —— 一张 SVG 从磁盘到棋盘 / 图鉴 / 花园 / 卡片 /
> 药剂瓶，中间经过哪些代码、每个数字在哪个常量里、**想改的时候该动哪一行**。
> **[repo-slim] 下文引用的 `docs/history/...` 指向已忽略、本地保留、不追踪的档案**：公开 clone 无此目录，属**已知死链**（详见 `README.md`「已知后果」）。
>
> **文档分工**（避免翻错页面）：
>
> | 文档 | 定位 |
> |---|---|
> | **本文 `docs/UNIT_ART.md`** | 单位贴图的**代码结构 + 改法**（接线参考，随代码更新） |
> | `docs/history/02-p28-art-pipeline.md` | 当初**选素材管线的评估记录**（AI 矢量 / 手绘 / 程序化怎么选），历史文档，不代表现状 |
> | `README.md` → 「图像素材」 | 素材清单与风格约定（画素材的人看的版本） |
>
> **事实来源**（P28 起）：路径写在**数据表的 `svg` 列**里 —— `data/units/plants.csv` /
> `data/units/zombies.csv` 的那一格写**相对路径**（不含 `.svg`），由 `PlantDB.svg_path()` /
> `ZombieDB.svg_path()` 拼成 `res://assets/svg/units/{plants,zombies}/…`；
> `scripts/balance/balance.gd` 的 `PLANT_ART` / `ZOMBIE_ART` 退为**表读不到时的兜底**。
> 贴图文件在 `assets/svg/units/{plants,zombies}/`；代码阶段标记 **P11 / P26 / P28**。

---

## 1. 一句话

**新贴图 = 放文件 + 在 csv 的 `svg` 格子里写一行**。之后棋盘、图鉴、花园、卡片图标、
药剂瓶上的植物标记**全都自动用上**，没有任何第二处要改。

```tsv
# data/units/plants.csv  （TAB 分隔；"name" 是 id，"svg" 是这张图）
豌豆射手	…	peashooter	pea/peashooter	…
寒冰射手	…	snow_pea	pea/snow_pea	…
# data/units/zombies.csv
路障僵尸	…	zombie_cone	zombie_cone	…
```

格子里的值等价于 `res://assets/svg/units/plants/<值>.svg`（植物）/
`res://assets/svg/units/zombies/<值>.svg`（僵尸）—— **不写 `.svg` 后缀**，所以短、
可以在表格里一眼读完；直接写完整 `res://…` 或带 `.svg` 后缀也认。写 `—` 表示这一行没有自己的图。

---

## 2. 数据流：谁读谁

```
data/units/plants.csv   ─┐  svg 列 = 相对路径（"pea/peashooter"，没有 .svg）
data/units/zombies.csv  ─┘        │
                                  ▼
scripts/core/db/plant_db.gd   /   zombie_db.gd        ← 表里那一格 + SVG_ROOT + ".svg"
   svg_rel(id)  表格里的原样
   svg_path(cell) → "res://assets/svg/units/{plants,zombies}/…"
   svg_file(id)  这一行注册的文件（可能还没画）
   art(id)       真正要画的图        ┐ 数据表层
   has_art(id)   这张图真的能加载吗   ┘
        │
        ├── scripts/balance/balance.gd  plant_art(id) / zombie_art(id)
        │      = 问表（PlantDB.art / ZombieDB.art）；表读不到才退 PLANT_ART / ZOMBIE_ART
        │
        ├── assets/svg/units/**.svg
        │        │  (Godot 导入期栅格化成 Texture2D，见 §6.4)
        │        ▼
        ├── 棋盘单位：scripts/core/unit.gd 的 art_path + UnitArt.load_texture()
        │     ├── plants: peashooter.gd / sunflower.gd / wallnut.gd  → art_path = Balance.plant_art("...")
        │     └── zombies: zombie.gd 的 apply_type() → ZombieDB.art(type)（破甲降级会换回基础僵尸图）
        │
        ├── 图鉴：ui/almanac/almanac.gd 把 art 填进 ItemGrid 的格子（ui/item_tile.gd 画）
        ├── 战斗卡片：ui/hud.gd _make_card_button(..., p_art) → ui/ui_style.gd make_icon()
        ├── 花园：ui/garden/garden_view.gd 自己 load_texture + Balance.plant_art_ink() 按"实心范围"种进花盆
        ├── 药剂瓶 / 卷轴：Balance.item_art() + item_mark_art() → UnitArt.draw_item_icon()
        │     （药剂 = 通用瓶 + 植物标记；[P92] 卷轴 = 共用卷轴图 + 它解锁的那株植物）
        └── 主菜单地上四件 / 花盆：Balance.MENU_ICONS[i].content / GARDEN_POT_CONTENT（另一种"实心范围"）
```

**关键点**：单位脚本**不写死贴图路径**（三个植物脚本调的 `Balance.plant_art()` 也只是转发给数据表），
所以改图只改**表里那一格**。`UnitArt.load_texture()` 对一切都容错（见 §6）。

---

## 3. 代码结构逐处说明

### 3.1 路径规则与兜底表 —— `plant_db.gd` / `zombie_db.gd` / `balance.gd`

| 名字 | 内容 | 用在哪 |
|---|---|---|
| `PlantDB.SVG_ROOT` / `ZombieDB.SVG_ROOT` | `res://assets/svg/units/plants/` / `…/zombies/`，`SVG_EXT` = `".svg"` | 拼路径的两个根 |
| `PlantDB.svg_path(cell)` / `ZombieDB.svg_path(cell)` | 把一格拼成 `res://` 路径；**已经写全路径或带后缀的原样返回**（和 `ItemDB.svg_path()` 同一条规则） | 下面几个函数的公共出口 |
| `PlantDB.svg_rel(id)` | 表里那一格的原样（相对、无后缀），`""` = 没注册 | 日志 / 自查「这一行写的是什么」 |
| `PlantDB.svg_file(id)` | 这一行注册的文件路径（**可能还没画出来**） | 自检里判 `NOT IMPORTED` |
| `PlantDB.art(id)` / `ZombieDB.art(id)` | **真正要画的那张图**：表的 `svg` 列优先；植物没注册 → 兜底表；**僵尸的文件不在 → 基础僵尸那张图**（不留空） | 棋盘 / 花园 / 图鉴 / 卡片 / 药剂标记 |
| `PlantDB.has_art(id)` / `ZombieDB.has_art(id)` | 这张图**真的能加载**（僵尸那侧 = 穿的是自己的图、不是基础僵尸图） | 图鉴的 `暂无贴图` 标签、每行日志的 `art …` |
| `PlantDB.art_paths()` / `ZombieDB.art_paths()` | 表里注册过的**全部去重路径**（含没画的） | `UnitArt.self_check()` 的统计 |
| `PlantDB.art_count()` / `ZombieDB.art_count()` | 真的有图的行数（= 图鉴不会写 `暂无贴图` 的行数） | `[Art] unit art: N of 49 …` 那一行 |
| `Balance.PLANT_ART` / `ZOMBIE_ART` | `id -> res:// 路径`，**兜底表**（P26 时是唯一来源，P28 起表优先） | 表读不到时；同时是"代码自己点名的路径"清单 |
| `Balance.plant_art(id)` / `zombie_art(id)` | 先问表（`PlantDB.art()` / `ZombieDB.art()`），表里没这一行才查兜底表 | 棋盘 / 花园 / 图鉴 / 卡片 / 药剂标记 |
| `Balance.plant_art_fallback(id)` / `zombie_art_fallback(id)` | **只查代码表**（`PLANT_ART` → `PLANT_DEFS[id]["art"]`；僵尸查不到给 `ART_ZOMBIE`） | 数据库那一侧调它们，**避免两边互相递归** |
| `Balance.roster_art_paths(table)` | 把一张表的值去重成路径数组 | `UnitArt.code_art_paths()` |

> 兜底表里**故意没有**的两张图：`plants/pea/gatling_helmet.svg` 与
> `plants/pea/pea_leaf.svg` —— 它们自己的文件头写着是**融合道具**的图（按道具画布缩放），
> 不是单位贴图。**写进 csv 的 svg 列或 `PLANT_ART` 都会让植物画成一件道具。**

### 3.2 防御式加载 —— `scripts/units/unit_art.gd`

| 函数 | 作用 |
|---|---|
| `load_texture(path)` | 空路径 / 不存在 → `null`（绝不报错）。**唯一的贴图入口** |
| `warn_once(path)` | 同一路径只警告一次：`[Art] cannot load … -> flat placeholder shape` |
| `short_art_path(path)` | 日志里去掉 `res://assets/svg/` 前缀（**保留子目录**，两张同名图才分得清） |
| `code_art_paths()` | **代码自己点名**的路径（4 张基础图 + 两张兜底表 + 物品图标 + 花盆 + 主菜单四件）：**缺一张就是 `FAIL`** |
| `sheet_art_paths()` | 三张 csv 注册的路径（单位两张 + 道具表） |
| `art_paths()` | 上面两者的并集：自检逐张走这一份 |
| `self_check()` | 启动时逐张打印 `名字 WxH px | OK`，**代码点名的缺了才是 `NOT IMPORTED … \| FAIL`**；csv 里"还没画的"只统计一行 `N sprite path(s) named by the sheets are not imported yet (not a failure)`；末尾 `unit art: N of 49 plant(s) … and M of 43 zombie type(s) … draw their own file` |
| `draw_item_icon(ci, box, base, mark, kind, tint)` | **复合图标的唯一合成点**：药剂 = 通用瓶 + 植物标记、卷轴 = 卷轴图 + 该植物（见 §5.10）。落点图**按分类**取（`BalanceUI.mark_geometry`） |
| `BalanceUI.mark_geometry(kind)` | `talent` → `POTION_MARK_AREA/SCALE`；`scroll` → `SCROLL_MARK_AREA/SCALE`；[P95] `plant_chest` → `CHEST_MARK_AREA/SCALE`（盖子上面那条空带）；没有条目的分类 → 空（画平图） |

### 3.3 棋盘单位 —— `scripts/core/unit.gd` + `scripts/units/zombie.gd`

| 名字 | 说明 |
|---|---|
| `Unit.art_path: String` | 这张贴图的 `res://` 路径。**空字符串 = 用色块**（`_draw_body()` 画的占位形状） |
| `Unit._load_art()` | 懒加载一次（`_art_tried`）；失败调 `UnitArt.warn_once()`，然后一直走色块 |
| `Unit.has_art()` | `_art_texture != null`。僵尸用它决定"要不要画朝向竖条" |
| `Unit.place()` | 设 `texture_filter`（见 `UNIT_ART_LINEAR_FILTER`）+ 调 `_load_art()` |
| `Unit._draw_art()` | 把贴图画进 `UNIT_ART_SIZE × UNIT_ART_SIZE`（默认 60×60）的方框，**方框中心 = 格子中心**；植物会"呼吸"（`_draw_art()` 里按 `IDLE_*` 做轻微挤压/拉伸），僵尸不呼吸（`_tick_idle()` 遇到 `is_zombie` 直接返回） |
| `Unit._art_tint()` | 受击闪白：贴图从白色 `lerp` 到 `COLOR_FLASH`，而不是替换整体颜色 |
| `Zombie.apply_type(type, hp, armor)` | **僵尸换贴图的地方**：`art_path = ZombieDB.art(type)`；路径变了就 `_art_tried = false` 重新加载 |
| `Zombie._become_base()` | 破甲降级 → `apply_type(基础僵尸)` → **贴图跟着换回 `zombie.svg`**（路障掉了就不该还顶着路障） |
| `Zombie._draw_body()` | `if has_art(): return` —— 有贴图就不画那条"朝左"的竖条 |

### 3.4 数据表层 —— `scripts/core/db/plant_db.gd` / `zombie_db.gd`

| 函数 | 返回 | 谁用 |
|---|---|---|
| `PlantDB.svg_rel(id)` / `ZombieDB.svg_rel(id)` | 表里 `svg` 那一格的原样（`""` = 没注册） | 日志与排查 |
| `PlantDB.svg_file(id)` / `ZombieDB.svg_file(id)` | 这一行注册的 `res://` 路径（可能还没画） | `NOT IMPORTED` 判断 |
| `PlantDB.art(id)` | 表里的文件；没注册 → `Balance.plant_art_fallback(id)` | 图鉴格子 / 花园 / 卡片 / 药剂标记 |
| `PlantDB.has_art(id)` | 这张图**真的能加载** | 图鉴的 `暂无贴图` 标签；`[Plants]` 每行的 `art …` |
| `ZombieDB.art(id)` | 表里的文件；**文件不在 or 没注册 → 基础僵尸那张图**（僵尸那一侧走 `zombie_art_fallback()`） | 僵尸单位 + 图鉴 |
| `ZombieDB.has_art(id)` | 穿的是**自己的图**（不是基础僵尸图） | 图鉴 + `[Zombies]` 每行的 `art …` |

### 3.5 界面消费者

| 文件 | 用什么 | 尺寸/位置常量 |
|---|---|---|
| `ui/item_tile.gd`（仓库 / 商店 / 背包 / **图鉴**的格子） | `setup(id, title, art, …)` → `UnitArt.load_texture(art)`，画在格子上部的方框里；`dimmed` 时叠一层半透明 | `ITEM_TILE_ICON_MAX` 84、`ITEM_TILE_ICON_TOP` 8、`ITEM_TILE_SIZE` 108×130 |
| `ui/hud.gd`（战斗**植物卡**） | `_make_card_button(..., p_art)` → `UiStyle.make_icon(p_art, CARD_ICON_SIZE)`；`_place_card()` 把图标放左边缘、两行文字在剩余宽度里居中 | `CARD_ICON_SIZE` 34、`CARD_ICON_MARGIN` 6、`CARD_SIZE` 170×50 |
| `ui/menu/menu.gd` 的 `LevelChest`（关卡列表**首通宝箱**） | `UnitArt.load_texture(BalanceUI.ART_CHEST_CLOSED/OPEN)`，两种状态各一张图；**能开的那只背后画辉光**（`CHEST_GLOW_*`，代码画的，不进素材） | `ART_CHEST_*`、`CHEST_SIZE`、`CHEST_GLOW_*` |
| `ui/garden/garden_view.gd`（**花园花盆**） | 自己 `load_texture(Balance.plant_art(type))`，再用 `Balance.plant_art_ink()` 的**实心范围**按 `draw_texture_rect_region()` 种进盆里 | `GARDEN_PLANT_INK_H_RATIO` 0.25、`GARDEN_PLANT_SINK` 0.10、`GARDEN_POT_CONTENT`、`PLANT_ART_INK` |
| `ui/menu/menu_prop.gd`（主菜单**地上四件**） | 只画 `Balance.MENU_ICONS[i]["content"]`（实心范围），底边贴地面线 | `MENU_ICONS` 的 `content/wide/lift/x`、`MENU_ART_CANVAS` 128 |
| `ui/ui_style.gd` | `make_icon(path, size)` 造一个 TextureRect（**贴图缺失时自己 `visible = false`**，文字自动占满）；`draw_icon()` 给自绘控件用（**[B16b] 第六个参数 `p_mirror`**：翻的是**图标自己那个方框**，只有“这是一条战线上的身体”时才传 true —— 编阵页的四处传了，卡片不传） | — |
| `Balance.item_mark_art(item_id)` | 盖在底图上的**植物标记**：`talent`（药剂）、`scroll`（卷轴）与 [P95] `plant_chest`（植物宝箱）都答"该物品 `对应植物` 的单位贴图"，其余分类答 `""` | `BalanceUI.mark_geometry(kind)`（药剂 `POTION_MARK_*`、卷轴 `SCROLL_MARK_*`、宝箱 `CHEST_MARK_*`） |

---

## 4. SVG 素材规范（画的时候要遵守）

| 项 | 值 / 要求 | 为什么 |
|---|---|---|
| 画布 | `width="128" height="128" viewBox="0 0 128 128"` | 单位按方框绘制，比例一致才好对齐；**唯一的例外是 `wallnut.svg`（96×96 / viewBox 100）** |
| 背景 | 透明 | 底色由棋盘 / 卡片提供 |
| 元素 | 只用 `fill`：`<rect>` `<polygon>` `<circle>` `<ellipse>` `<path>` | Godot 导入期的 SVG 支持面窄 |
| 禁止 | `<filter>` `<text>` `<image>` `<style>` `<linearGradient>` `<radialGradient>` | 否则**静默缺元素**（见 `ART_PIPELINE.md` 坑 6） |
| 描边 | 本项目风格是**纯色块、不描边** —— `assets/svg/units/` 下的单位贴图**只写 `fill`**（各自文件头都注明 "pure fills, no strokes"）；唯一的例外是**融合道具图** `plants/pea/gatling_helmet.svg`（一个 `stroke="#40BF4D" stroke-width="2.5"` 的轮廓）。若哪天真把它当单位贴图画，先看一眼这条描边在 Godot 里渲染正常 | 小尺寸下色块更清楚；Godot 导入期的 SVG 支持面窄，描边/虚线/圆头笔帽属于"能跑但没验证过"的部分 |
| 颜色 | **写在文件里**（`fill="#40BF4D"`） | SVG 读不到 `Balance.COLOR_*`。**改色时两边一起改**：`COLOR_PEASHOOTER` / `COLOR_SUNFLOWER` / `COLOR_WALLNUT` / `COLOR_ZOMBIE` |
| 绘制范围 | 留在**中心 ±30 px** 内（`UNIT_ART_SIZE / 2`） | 上方要放名字（`UNIT_NAME_Y` −50）、血条（−42）与护甲条（−46）；下方要放行动条（+32） |
| 朝向 | **画的时候一律按“朝右”画**，除非这个单位天生朝另一边 —— 那一行在 `units.csv` 的 **`face`** 格里写 `l`（[B16]）。僵尸整族朝左（靠**手臂姿态**表达，不是靠竖条），所以 `默认僵尸` 那一行写的是 `l`；雷角兽的角在左上，也是 `l` | 豌豆从右边炮口飞出；僵尸向左走。**站位与画的朝向不一致时，代码会把身体镜像**（`Unit.mirrored`，见 `docs/prompt/BRAWL.md` §8.15），所以画的人只需要在 `face` 里说一句真话，不用交两份图 |
| 炮口约定 | 豌豆家族的炮口**必须是竖边 `x=90, y=40..58`** | 豌豆出生点 = `PEA_MUZZLE_OFFSET`（`Vector2(12, −7)`，按纹理→本地坐标换算而来）。**改炮口就要同时改这个常量**，否则豌豆从头中间或下唇冒出来 |
| 空边（留白） | 可以有，但**花园里的植物按"实心范围"种**（见下） | 三张植物贴图的空边差很多（坚果墙几乎填满、豌豆茎下留 12%），不按实心框对齐就会一大一小 |

### 4.0-b 射弹贴图（`assets/svg/shots/`，[D79]，2026-10-05）

**这批图和单位图不是一回事**，因为弹在场上只有 10–20 px，而且**游戏里画什么由 csv 决定**：

| 项 | 值 / 要求 | 为什么 |
|---|---|---|
| 谁决定用不用 | `data/projectiles.csv` 的 **`贴图`** 列（短名 → `res://assets/svg/shots/<名>.svg`；也可以整条写 `res://`）。**空着或文件没导入 ⇒ 回落到 `外观` 列那个图元** | 一张图没画好不该让一发弹消失（缺图不算错） |
| 画布 | **按各自的比例**，不必 128×128（豌豆 32×32、西瓜 40×40、箭 64×16、铅弹 48×32） | 画的时候**画布比例就是画的比例**：绘制时按"外观自己的方框"等比缩放（豌豆 14 px、西瓜 20、箭 29×14、铅弹 23×20），**所以换图不会改变场上的尺寸** |
| **染色** | `外观 = pea / melon` 的图**会被发射者的颜色乘**（冰西瓜 = 西瓜 + 冻结色）⇒ **必须画成白色 + 只比白深的灰**（`modulate` 是乘法，画不出比染色更亮的芯） | 旧的图元画的是"亮芯"，换成贴图之后改成**暗边**——这是这一批唯一有意改掉的观感 |
| 不染色 | `外观 = arrow / musket` 的图**原样画**（自带配色），颜色照 `BalanceUI.COLOR_ARROW_*` / `COLOR_MUSKET_*` 抄 | 木头箭杆不是植物的颜色 |
| 朝向 | **一律朝右**；画的时候按航向旋转（圆形的图转了也看不出来） | 一条规则，不用按外观列清单 |
| 溅射瓜纹 | **不要画进文件**：那两条弧是**玩法提示**（`溅射` 列），由代码画在贴图之上 | 卷心菜与西瓜共用一张图，只靠 `溅射` 区分 |
| 描边 | 同 §4：不用 `stroke` | 同上 |
| 画布 = 墨迹 | **画布边界就是图形的边界**（不要留大片透明空边）——绘制只按画布比例缩放，留白会一起被缩掉 | 单位图那套"128×128 画布 + content 墨迹框"是为**花盆对齐**服务的；射弹按自己的比例画就行（箭 64×16、铅弹 48×32），格子与面板都会按比例放好 |

> 想看某个外观"多大"，**不要自己量**：那份几何是 `Projectile.draw_extent(外观)` 一个人的（图鉴的放大倍数也读它）。

### 4.1 「实心范围」(`ink` / `content`) 是什么

同一张画布上，**图形真正占据的那块区域**。三个地方需要的是**那一块矩形**（下表三处都是 `Rect2` 常量）；
另有三处只要它的**一条边或一个比例**——乱斗脚下的影子要 ink 的底边与宽（**[B36] D111**）、高度轴的厚度要 ink 的竖向占比（**[B36] D112 / [B37] D113**）、
倒地与形变的脚线要 ink 的底边（**[B37] D114**），都在本节末。

| 常量 | 单位 | 谁用 | 不填会怎样 |
|---|---|---|---|
| `PLANT_ART_INK` | **纹理像素**（该 SVG 自己的像素） | 花园里把植物"种"进花盆（`plant_art_ink()`） | **[B35] 不再退回整张画布**：改由 `BalanceUI.auto_ink_box()` 自动实测——纹理读回像素（素材都是 `compress/mode=0` 无损导入，`get_image()` 才有答案），取**非全透明像素的包围矩形**（`Image.get_used_rect`），每张纹理量一次、之后走缓存。**表值仍然优先**：手工量过的三行照旧压过实测值 |
| `MENU_ICONS[i].content` | 128 画布像素 | 主菜单地上四件东西 | 钥匙那种"小而居中"的图会被画成一条缝（**这一处没有自动兜底**，四件都是手工行） |
| `GARDEN_POT_CONTENT` | 128 画布像素 | 花盆 | 花盆位置与泥土线会对不上（同上，手工行） |

> 换素材的顺序：**先量实心范围 → 再谈位置**。这是 P25 得出的结论（`docs/history/01-p00-p27-acceptance.md` 坑 6）。
> ⚠ **[B35] 自动实测量的是"第一个非全透明像素"**：ThorVG 给 SVG 轮廓做抗锯齿，可见墨迹外 1–2 px 会带极淡的 alpha 而被算进去。
> 所以自动值是**下限近似**——某株植物在盆里显得偏大/脚沉得太深，就给它补一行 `PLANT_ART_INK`（表值压过实测），
> 而不是给自动门加阈值。其余两处（`MENU_ICONS` / `GARDEN_POT_CONTENT`）未接自动门，改画法时仍要手工同步。

**[B36] 第二个读者：脚下的影子（D111）**。`UnitArt.ink_fractions(path)`（画布 0..1 的比例，按 path 缓存）与
`UnitArt.ink_rect(path, at, size)`（落到某个具体方框的像素）把同一块 ink 交给绘制端，`Unit.art_ink()` 再按三个艺术层级
（视图场景自答 / 贴图实测 / 平面占位形画满 `body_size`）答"这只身体到底画了哪一块"。影子由此得到**实测脚底**（ink 底边 = 椭圆中心 y）与
**宽度**（ink 宽）；**地面纵深不再量素材**——它是宽的一半（`BRAWL_SHADOW_DEPTH_SHARE`，与 D99 `body_depth = body_width / 2` 同一条占地算法，D111 当日第二次拍板）。⚠ "纵深不量素材"只说到**影子**为止：ink 的**高**不是没人读，它的读者是**高度轴**（下面那条 D112），一条句子里 x 归影子、竖向归 sim。
⚠ 这条路**只问实测、不问 `PLANT_ART_INK`**：影子问的是"素材实际结束在哪"，而那张表是为花盆关系手工量的呈现选择（且按植物 id 索引，
影子的业主是按 path 的 `UnitArt`）。所以补一行 `PLANT_ART_INK` **只会改花园那口盆，不会挪影子**；
量不到像素的素材（缺文件 / 有损导入）在影子这边回**创作契约**（整幅画布宽、底边 = `VIEW_ART_FEET_LINE`）。

**[B36] 第三个读者：高度轴的厚度（D112 定尺，[B37] D113 让它真的答题）**。`UnitArt.ink_span_y(path)` 把同一块实测的**竖向**那半交出来
（= 墨迹占**自己画布**的高，0..1；文件在但读不到像素时答 `1.0`，即"信画布"；**连文件都没有**时这条门根本不被问，`Unit.read_height()`
直接答 `Balance.UNIT_Z_THICKNESS_CELLS` 那个全身高，所以导入失败的单位是"矮不瘦的方块"而不是厚度 0 的薄片）。
读者是 `Unit.read_height()`：`z_thickness` 的缺省 = **画布高 / 128 × ink 高**。
**[B37] 那条 1.0 格地板已经摘掉**（D113，用户拍板"让 ink 高真的当家"）——**画得多高就够多高**，命中窗口第一次真的跟着美术走；
**表值优先照旧**（`data/units/units.csv` 的 `z_thickness` 列写了数就不读素材）。
为什么需要这条门：`z_thickness` 的语义是"身体从脚底**够**多高"，而画布高只是"文件保存时那张纸多高"——素材在头顶留白，判定就被凭空抬高。
⚠ **对画素材的人这意味着什么**：一只身体画得矮，就真的会矮到**吃不到齐胸的平射**（乱斗直行弹道区间 `[0.45, 0.70]` 格）。
不要靠"反正是 1.0 格"——那个保证没了。要它高就画满一点，要它钻过去就**在它自己的表行**写 `z_thickness`（或给那发弹写 `z_height`）。

**[B37] 第四个读者：脚底那条线（D114）**。`Unit._feet_offset_y()` 整条收成为 `art_ink().end.y`——影子锚点、倒地翻倒的轴心
（[B25]）与形变压脚（[B33/34] 空闲拉伸 / 受击果冻）**共用同一次实测**，贴图那一级的脚底从此不再是"半个盒子"那个画布底边的猜测。
所以**脚底下留多少空白，现在同时决定三件事**：影子贴不贴脚、尸体怎么翻、果冻压在哪。

---

## 5. 我怎么改：具体操作

> 通用前提：改完 **`.svg`** 后，Godot 编辑器重新导入即可（`Project > Reload Current Project`）；
> 改完 **`.gd` 常量/表** 后，重新运行游戏（`R` 只重读关卡 json 与两张单位 csv，**不重读 `.gd`**）。

### 5.1 改一张已有贴图的形状 / 颜色
- **只改** `assets/svg/units/.../*.svg`，代码不动。
- 若改了**颜色**：同步 `scripts/balance/balance.gd` 里对应的 `COLOR_*`（棋盘色块兜底、卡片底色用它派生）。
- 若改了**绘制范围**：同步 §4.1 里对应的 `ink` / `content` 常量，否则花园/菜单里的位置会漂。

### 5.2 把某个 id 指向另一个文件
- 改**表里那一格**（`svg` 列）即可（棋盘 / 图鉴 / 花园 / 卡片 / 药剂标记都跟着变）。
- 只想临时盖住数据表？改 `PLANT_ART` / `ZOMBIE_ART` **不管用**（表优先），要先把那一行的 `svg` 格清成 `—`。

### 5.3 给还没有贴图的植物 / 僵尸加贴图
1. 画一张 128×128 的 SVG，放进 `assets/svg/units/plants/`（豌豆家族建议放 `plants/pea/`）或 `assets/svg/units/zombies/`。
2. 在 `data/units/plants.csv` / `zombies.csv` 的那一行 **`svg` 格子里写上相对路径**（不带 `.svg`）。
3. 跑一次启动自检（§6.3）：那一行的 `art …` 不再带 `NOT IMPORTED`，`[Art]` 里那张图是 `OK`。
- **路径写错 / 文件还没画**：植物画色块（`Unit._draw_body()`），僵尸画**基础僵尸那张图**，
  图鉴格子上写 `暂无贴图` / `no art yet`，`[Plants]` / `[Zombies]` 那一行标 `NOT IMPORTED`。
  **不会崩、不会空白**，启动自检也**不会因此 FAIL**（表注册的是整个设计，素材要慢慢补）。
- 改完不用改代码：`R` 重开一关就会重新读表（**贴图文件本身**还是要等编辑器导入完）。

### 5.4 做一个全新单位（新脚本）怎么接贴图
```gdscript
# 植物：新脚本里一行（值就是 csv 那一行 "name" 列的 id）
art_path = Balance.plant_art("snow_pea")     # → PlantDB.art("snow_pea") → csv 的 svg 格子

# 僵尸：不用写——spawner 调 apply_type()，里面已经 art_path = ZombieDB.art(type)
```
- 植物的**卡片、图鉴、花园**都走 `Balance.plant_art(id)`，所以只要那行 csv 的 `svg` 格子有值，新脚本就自动有图。
- **贴图之外**的步骤（数据表一行、名字、卡片、卷轴、`_script_for()` 分支…）在 **`docs/ADD_UNIT.md`**。

### 5.5 改棋盘上贴图的大小
- `UNIT_ART_SIZE`（默认 **60**，方框边长，与 `CELL_SIZE` 96 配套）。
- 注意：名字 / 血条 / 护甲条 / 行动条的 Y 是**独立常量**（`UNIT_NAME_Y` −50、`UNIT_HP_BAR_Y` −42、
  `UNIT_ARMOR_BAR_Y` −46、`UNIT_ACTION_BAR_Y` +32）；贴图变大就可能压到它们。
- `[Art]` 自检里有一条断言：贴图半宽必须**同时**小于血条 Y（42）与行动条 Y（32）的绝对值（半宽默认 30），
  改大 `UNIT_ART_SIZE` 会 `FAIL` 并告诉你。

### 5.6 想让贴图更锐利 / 更平滑
- `UNIT_ART_LINEAR_FILTER`（默认 **true** = 线性过滤）。
- 项目全局是"最近邻"（为色块风设的），单位贴图在 `Unit.place()` 里**按节点覆盖**成线性 —— 所以别去动
  `project.godot` 的全局过滤。

### 5.7 想让贴图更清晰（分辨率）
- **不是代码的事**：Godot 在**导入期**就把 SVG 栅格化成纹理。选中 SVG → Import 面板 → `svg/scale`
  （例如 2.0 → 256×256）→ Reimport。运行时是位图，放大一样会糊。

### 5.8 改战斗卡片上的图标大小 / 位置
- `CARD_ICON_SIZE`（默认 **34**）、`CARD_ICON_MARGIN`（默认 **6**，左右各算一次）。
- 布局在 `hud.gd._place_card()`：图标占左边缘，两行文字在剩余宽度里居中；窗口缩放时按 `Layout.card_size` 重算。
- 卡片只有 170×50，图标超过 ~40 就会挤到文字。

### 5.9 改花园里的植物大小 / 落位
- `GARDEN_PLANT_INK_H_RATIO`（植物实心高度 / 格子高度，默认 0.25）、`GARDEN_PLANT_SINK`（脚陷进土的比例，0.10）。
- 上下关系全在 `GardenPlot._plant_ink_rect()`（`garden/garden.gd`）一个函数里：**以花盆中心对齐、按实心高度定尺寸、
  实心底边陷进土里**。
- 换花盆素材 → 同步 `GARDEN_POT_CONTENT`；换植物素材 → 同步 `PLANT_ART_INK[id]`。

### 5.10 改复合图标上的植物标记（药剂 / 卷轴 / 植物宝箱）
- **天赋药剂** = 档位通用瓶 + 该植物贴图缩到 `POTION_MARK_SCALE`（0.3），落在
  `POTION_MARK_AREA`（`Rect2(44, 10, 40, 28)`，瓶子留白区）。
- **[P92] 召唤卷轴** = 共用的卷轴图 + 该植物贴图缩到 `SCROLL_MARK_SCALE`（0.26），落在
  `SCROLL_MARK_AREA`（`Rect2(30, 36, 40, 32)`，羊皮纸的空白面；数字量在卷轴 svg 自己的 0..100 视图框里，
  纸body 是 `x 20..80, y 14..86`）——所以 25 张卷轴不再长得一模一样，一眼能认出解锁的是哪一株。
- **[P95] 植物宝箱** = 共用的箱子图（`ui/chest_closed`）+ 该植物贴图缩到 `CHEST_MARK_SCALE`（0.30），落在
  `CHEST_MARK_AREA`（`Rect2(34, 2, 32, 28)`）。箱子自己那张 0..100 的画布在 y 30 以下全是硬件（箱体、两条金带、锁扣），
  所以标记放在**盖子上方那条空带**里——"站在箱子上的那株"，不是压着五金件画。只有 `area` 的**中心**会被读
  （`draw_item_icon` 按 `center/canvas` 折算），所以那个 rect 是位置而不是框。
- 合成代码只有一处：`UnitArt.draw_item_icon()`；仓库 / 商店 / 背包 / 图鉴 / 花园道具栏都走它。
- ⚠ **喂给它的 `kind` 不能少**：`mark_geometry("")` 是空的 ⇒ 图只剩一层、而且**不会报错**。
  图鉴详情栏曾经就是这样（它的行少发了 `kind`，格子却自己问 `ItemDB`，于是"格子是复合的、大图是平的"）。
  现在有两道网：`[Almanac]` 启动判据**走页面真正生成的那 44 行**（每个带标记的行都必须给得出几何），
  以及 `draw_item_icon()` 在"有标记但没几何"时打一条 warning（每种分类只打一次，不会刷屏）。
- **新增一株植物的药剂/卷轴/宝箱**：表里那行写好 `对应植物` 就会自动套用（药剂还要 `分类 = talent` 与档位；
  卷轴认 `分类 = scroll`，宝箱认 `分类 = plant_chest`，各自带自己的 `svg`）。
  要改**落点**：动 `BalanceUI.mark_geometry()` 里那个分类的条目。

### 5.11 改主菜单地上四件东西的外观 / 位置
- `MENU_ICONS` 的 `content`（实心范围）/ `wide`（画多宽）/ `lift`（离地多高）/ `x`（横向位置比例）；
  图放哪由 `menu.gd._layout_props()` 统一算，`menu_prop.gd` 只负责画。
- 自检 `[Menu]` 会报每个 `content` 是否落在画布内、四件会不会互相压到。

### 5.12 让某个单位"不用贴图"（回到色块）
- **最直接**：在它的单位脚本里别设 `art_path`（或设成 `""`）—— `Unit._load_art()` 遇到空路径直接返回，
  于是画 `_draw_body()` 的色块，连警告都不会打。记得让 `body_color` / `body_shape` / `body_size` 合理。
- **只把 csv 的 `svg` 格清成 `—` 不够**：`plant_art()` 还会退到 `PLANT_ART` / `PLANT_DEFS[id]["art"]`
  （三张卡片有兜底路径）；僵尸会退到**基础僵尸那张图**（不是色块）。
- 想查"这一行到底画的是哪个文件"：看 `[Plants]` / `[Zombies]` 自检里那一行的 `art …`。
- 这条**只影响显示**，与数值 / CSV 的其它列无关。

---

## 6. 缺图、没导入、改错了会怎样

### 6.1 失败策略（永不崩）
| 情况 | 现象 | 日志 |
|---|---|---|
| **csv 的 `svg` 格子指向一个还没画的文件** | 植物 = 色块；僵尸 = 基础僵尸图；图鉴写 `暂无贴图` | `[Plants]` / `[Zombies]` 那行 `art xxx.svg NOT IMPORTED`；`[Art]` 里汇总一行 `N sprite path(s) named by the sheets are not imported yet (not a failure)` |
| 路径写错（打错一个字母） | 同上 —— **所以看那一行的 `art …` 就能发现拼错** | 同上（不会 FAIL，需要人眼看一眼拼写） |
| 文件在，但编辑器还没导入 | 同上（`ResourceLoader.exists()` 为假） | 同上 |
| **代码自己点名的路径**（`ART_PEASHOOTER` / 两张兜底表 / 物品图标 / 花盆 / 主菜单四件）不存在 | 对应界面缺图或退回色块 | `[Art] xxx NOT IMPORTED … \| FAIL` + `[Art] self-check FAILED` |
| csv 的 `svg` 格子是 `—` | 植物 = 色块；僵尸 = 基础僵尸图；图鉴写 `暂无贴图` | `[Plants]` / `[Zombies]` 那行 `art (flat shape)` / `art (base zombie)` |
| 单位脚本里 `art_path = ""` | 色块（连警告都不打） | 无 |
| 表读不到（文件被删/改名） | 走 `Balance.PLANT_ART` / `ZOMBIE_ART` 兜底表 | `[Plants] sheet not loaded: … \| FAIL`（这一条**是真的 FAIL**） |
| SVG 里用了 `<filter>`/渐变/文字 | 那张图**可能少元素**（不报错） | 无 —— 所以素材规范里禁用它 |

### 6.2 三个自检会替你把关（启动时打印）
- **`[Art]`** —— 代码点名的路径逐张 `名字 WxH px | OK` / `NOT IMPORTED | FAIL`；
  csv 注册但还没画的只汇总一行（**不算失败**）；末尾一行
  `[Art] unit art: N of 49 plant(s) from plants.csv and M of 43 zombie type(s) from zombies.csv draw their own file`。
- **`[Plants]` / `[Zombies]`** —— 每行数据末尾带 `art units/plants/pea/peashooter.svg`（表里的那一格）
  或 `art (flat shape)` / `art (base zombie)`；注册了但没画的会多标一个 `NOT IMPORTED`。
- **`[Almanac]`** —— 图鉴页的几何自检（格子放得下、面板不重叠）。

### 6.3 验收命令（**由你执行**，AI 不跑）
```bash
cd /home/wing/Projects/Games/pvz
timeout 300 godot --headless --path . --quit-after 400 2>&1 \
  | grep -E "\[Art\]|\[Plants\]|\[Zombies\]|NOT IMPORTED|Parse Error|SCRIPT ERROR"
```
- 期望：每张已就绪的贴图一行 `… px  drawn at 60 px  | OK`；一行 `N sprite path(s) named by the sheets are not imported yet`；
  一行 `[Art] unit art: 29 of 49 plant(s) … and 9 of 43 zombie type(s) … draw their own file`
  （P28 交付时的数字，**以这行日志为准**）；最后 `[Art] self-check PASSED`。
- `[Art] self-check FAILED` + 某张 `NOT IMPORTED` → 那张是**代码点名**的图：让编辑器导入完
  `assets/svg/**/*.svg`，再 `Project > Reload Current Project`。
- 出现 `cannot load` → 某个**正在被使用**的路径拼错了，或文件被移走
  （**这就是 P23 那轮踩过的坑：文件搬了位置，代码还指旧路径**）。
- 想知道"某一株植物现在指向哪个文件"：`grep -E "\[Plants\] (peashooter|snow_pea) " `，看那行的 `art …`。

### 6.4 为什么"矢量"在游戏里仍是位图
Godot 4 用 ThorVG 在**导入阶段**把 SVG 渲染成 `Texture2D`（倍率写在 `.svg.import` 的 `svg/scale`）。
所以"改清晰度 = 改导入倍率后重新导入"，**不是**改代码，也不能指望运行时无限缩放。

---

## 7. 素材放在哪、如何分布

**素材按目录分层存放；文档不列清单、不写数量**——谁有哪些图由数据表决定，
目录里实际有什么才是事实（表里点了名但没有文件 = 计数并降级，见 §6.1）。

```
assets/svg/
  units/plants/<族>/<单位>.svg   单位贴图，按族分子目录（族名同 units.csv 的 race 后一段）
  units/zombies/<僵尸>.svg
  items/…                        道具图标；药剂的通用瓶按档位单独放，植物标记用单位贴图
  other/…                        场景件（阳光、脑子一类）
assets/audio/…                   音效与音乐（扁平一层，由 cue 表 / 曲目表点名，不按目录分类）—— 外部资产，不入库
assets/fonts/…                   字体（扫目录取第一个可导入的）—— 外部资产，不入库
```

- 音频 `.wav` 与字体 `.ttf`/`.otf` 是**外部资产、不打包进 git**（见 `README.md`「外部资产」）；
  仓库只留 `assets/audio/readme.md` 清单，clone 后自备。
- **每个素材旁边有 `.import` sidecar**（引擎的导入设置）；漏了它会"文件在、图不出现"。
  `.import` 是可确定性重建的派生物、**不入库**（见 `README.md`）：clone 后用 Godot 打开工程
  导入一次即自动重建，无需手工补。
- **路径的唯一来源是表的 `svg` 列**（写相对路径、不写后缀），代码拼成实际路径 ⇒ 加一张图 = 改一个格子。
- **数量不写进文档**：目录在长，写死的数字只会先烂。要查现在有哪些，看目录或表。


- **颜色有两个地方**：SVG 里写死的颜色，与 `scripts/balance/balance.gd` 里对应的 `COLOR_*` 常量——
  改一个要同步另一个（棋盘上的色块兜底、卡片角标、粒子用的是后者）。
- **想更清晰**：抬 SVG 导入设置里的 `svg/scale` 后重新导入（不是改代码）。
- **导入设置写在 `.import` sidecar 里**；这个文件丢了 = "文件在、图不出现"。
## 8. 改完素材的检查表

1. csv 那一行的 `art …` 后面**没有** `NOT IMPORTED`，`[Art]` 里那张图是 `OK`；
2. 棋盘上看一眼：**没压到名字 / 血条 / 护甲条 / 行动条**（§4 的 ±30 px 规则）；
3. 花园里那株**种在盆里**（脚陷进土），大小与其它植株一致（不行就调 `PLANT_ART_INK`）；
4. 图鉴格子里的图**没被裁**（`ITEM_TILE_ICON_MAX` 84 的方框内）；
5. 战斗卡片上的图标**没挤到两行文字**（`CARD_ICON_SIZE` / `CARD_ICON_MARGIN`）；
6. 豌豆家族：**豌豆从炮口出来**（炮口在 `x=90, y=40..58`，与 `PEA_MUZZLE_OFFSET` 配套）；
7. 僵尸：破甲降级后**贴图变回基础僵尸**（`Zombie._become_base()`）；
8. 天赋药剂 / 召唤卷轴：底图上的植物标记**是这一株**（`item_mark_art()` → `plant_art()`；[P92] 卷轴也开始合成）。

---