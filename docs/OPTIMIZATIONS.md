# OPTIMIZATIONS.md · 优化与完善台账

> **这份文件回答"现在还有哪些优化与完善要做"**（活的台账，见 §0）。
> **[repo-slim] 下文大量 `docs/history/...§N` 引用指向已忽略、本地保留、不追踪的档案**：公开 clone 无此目录，属**已知死链**；现状以 `docs/STATE.md` 为准（详见 `README.md`「已知后果」）。
> 下面的 A–E 组是**历史条目**：哪条债已清、当时的现场是什么、哪些是误报——只在"这笔债到底清没清"时才往下翻。
> **"要不要做"类的问题不在这里**（那是 `docs/OPEN_ITEMS.md`）；现状见 `docs/STATE.md`；
> 开发流程见 `docs/DEV.md`；某一批做了什么见 `docs/history/03-p37-p82-batches.md`。

---


> 生成于 2026-09-21（P28 前后）。来源：对 `scripts/` 下核心玩法、数据层、UI 层约 1.8 万行
> GDScript 的一次**只读审查**（未改任何源文件）。
> 标注方式：每条给 `文件:行号`，可按图索骥复核。**严重度**指"改了之后收益大小 × 出问题的代价"。
> **行号会漂移**：本清单写在 P28 前后，P35（自检搬出）与 P36（run 簇 810 行搬出）之后
> `game_manager.gd` 里未复核过的行号一律偏大，按**函数名**定位比按行号可靠（C1/C2 已复核到 P36）。
> 本文件不属于 §6 约束的 `docs/history/01-p00-p27-plan.md` / `docs/history/01-p00-p27-handoff.md`，是独立新建的审查记录；采纳哪些、何时改，由用户决定。

---

## 0. 当前要做的优化与完善（**活的**）

| # | 要做什么 | 为什么现在做 | 规模 | 判据（怎样算做完） |
|---|---|---|---|---|
| ~~**O1**~~ ✅ **已做（P85）** | `game_self_checks.gd` 2987 行 → **116 行调度壳 + `scripts/checks/` 六份**（boot 237 / board 364 / zombies 734 / plants 776 / economy 604 / levels 286） | "**零外部调用者**"正是 P35 把它搬出管理器的理由；拆完最大的那份 776 行，不再有第二份"god 文件" | 已落地 | 33 个 static func 一个不少；`class_name SelfChecks` 与 16 个探针的**调度顺序**原样保留；`[Arch]` 的大文件上限已从 6 调到 **5**，并**新增第 5 条判据**（用了别处 preload 的常量却没自己声明 ⇒ 点名变红）——这条判据正是被 P83/P85 两次事故逼出来的 |
| **O2** | 27 个模块把自检贴在产品文件里（`plant_db.self_check` 232 行、`garden` 225、`almanac` 175、`unit_art` 143…）：**超过 60 行的搬进 `scripts/checks/<module>_check.gd`** | 产品代码与判据抢同一屏；搬走**不动前缀**，风险最低 | 中 | 每个模块的前缀与判据行数不变 |
| **O3** ⏸ **已冻结** | `game_manager.gd`（**3851 行 / 213 函数**）剩余可搬块：选卡段 579 / 商店段 100 / 物品事务段 / 音频设置段 | 沿用"搬代码、留状态"的老规矩——**但先等 Q1**：真正的问题可能是边界画错，先搬可能白搬（见 `docs/OPEN_ITEMS.md` §0.4） | 中 | 形状定了再搬 |
| **O4** | 三个 UI 大文件里的自检与纯函数外移（`almanac_view` 1493 / `garden_view` 1278 / `hud` 961 行） | 同上；纯函数外移后能被无头单独审计 | 小 | `[Almanac]` / `[GardenUI]` 判据一条不变 |
| ~~**O5**~~ ✅ **已做（P84）** | `[Arch]` 架构棘轮：最大文件行数 / 超过 1000 行的文件个数 / 全仓 GDScript 总行数 / 三张数值表之间没有同名常量 | 让"架构债"从人肉审查变成**每次启动都报账** | 小 | 已落地：`scripts/core/arch_check.gd`。**上限已于 P99 由用户解除**（三个数字继续每次开机打印，但不再判 FAIL；欠账本身仍在本节 §0） |
| ~~**O6**~~ ✅ **已做（P84）** | `[Docs]` 文档审计：① 活文档提到的 `docs/…md`、`scripts/…gd`、`data/…csv\|json` 路径都存在；② `history/` 里每份都在分布表里；③ 每份历史档案都带头部横幅；④ 入口文档都在 | 文档已分层，但"**会不会重新烂掉**"还没有机器看着 | 小 | 已落地：`scripts/core/doc_check.gd`。**不查**的：文章内容对不对——那要人看 |
| **O7** | `[Verify]` 收尾行（机器可读的 `FAILED=<n>`） | 现在的通过标准是 `grep FAILED` 为空（口令）；有了它才能被脚本判定 | 小 | 出现在日志末尾，且**不影响**逐模块 PASSED |
| **O8** | 压缩本文 A–E 组与 `docs/history/03-p37-p82-batches.md` §5 | 历史条目太长——但**这一步必须在提交之后做**：工作区里还有未提交的复核文字，删了找不回 | 小 | 各条压成"状态 + 一句复核 + 指针" |

> 优先建议：**O5 + O6 + O7**（都很小，装上之后 O1–O4 每一步都有机器替你看着），
> 然后按 **O1 → O3 → O2 → O4** 搬。O8 挑一次"这批已提交、工作区干净"的时机做。

---
## 0.1 历史条目（A–E 组）怎么读


> **2026-09-24 全清单复核（P64 收尾时做的）**：下面三条顺序**已经不再描述现状**——
> A 组十条在 P65 关掉 A3 之后**全部落地**；**B 组在 P76 全部结清**
> （B3 第三子弹与 B4 二、三子弹在 P75，B7 第一子弹在 P76 —— 特效有了独立层与统一清理，
> "无池"那半句按原文自己的 remedy 判定为已过期，见 B7 小节），
> C 组的 C1（四刀）、C2、C3、C4、C5（P74：`SelfChecks.item_rows` 钉住三种 item-row 的九枚共用视觉键）、
> C7、C8（两刀：P62 `parse_text` + P67 `_zombies`）、C10 全落；
> **C6 于 P74 复核：其"相位死状态"前提已被 P30-A2 分阶段结算推翻一半**（PLANT/ZOMBIE 两相位现为活的，只剩
> turn_start/turn_end 未加拍），已收窄成一条"要不要给回合首尾各加一拍"的呈现决定（见 C6 小节），不再是架构债；
> **C9 已落四刀（P69 音频 41 名 → `BalanceAudio`；P70 view 摆位与药剂几何 6 常量 → `BalanceUI`；P71 零散 7 绘制常量 → `BalanceUI`；
> P108 **按场景** 110 名 → `BalanceBattle` / `BalanceGarden` / `BalanceRun` / `BalanceShop`）**。
> 所以真正的下一刀不再由这份清单的顺序决定，而在 `docs/history/03-p37-p82-batches.md` §4 的"待用户点单"里。
> 原始顺序保留在下面，它是这份清单**当时**的判断，不要当现状读。

1. **先修 A 组**（正确性 / 数据安全）——尤其 A1（丢档）和 A2（误触清档），代价是玩家资产。
2. **再做 B 组**（每帧性能）——多数是"把轮询改成信号 / 把每帧分配改成启动缓存"，改动局部、风险低。
3. C 组（架构）按需分批，别一次大重构；D/E 组可以随下次功能改动顺手带上。

---


### 0.2 A–E 条目状态索引（一行一条，**状态取自正文**）

> 想查"这笔债清了没有"看这张表；想看"怎么清的"再往下翻那一条的正文。
> 正文里的 `→ ✅ …` 段落是**结算记录**（连证据指针一起），不是重复——所以索引只加不删。
> ⚠ 这张表曾经**只读标题**，于是把 `C1`（正文写着"四条全部落地"）也报成"未清"；
> 现在按"标题或正文出现 ✅"判定，**改条目时别把 ✅ 挪走**。

| 条目 | 状态 | 是什么 | 严重度 |
|---|---|---|---|
| A1 | 已清 | 存档写入非原子，坏档会被静默覆写 | 高  已修（P37 / P56） |
| A2 | 已清 | KEY_N 直通 reset_progress()，绕过两击确认 | 高  已修（P37） |
| A3 | 已清 | 落盘返回值被系统性丢弃 | 中  已修（P65） |
| A4 | 已清 | 花园自然恢复有的路径落盘、有的不落 | 中  已修（P37 · 收尾于 P66） |
| A5 | 已清 | 自检直接改玩家真实数据 | 中  已修（P35） |
| A6 | 已清 | 重复调用会把显示名 "#2" 越接越长 | 中（潜伏） 已修（P37） |
| A7 | 已清 | 豌豆与火花同帧生成，火花永远先到 | 中  已消解（抛射体重构） |
| A8 | 已清 | 能量豆"先结算收益、后扣道具" | 低  已修（P37） |
| A9 | 已清 | 坏关卡文件静默变兜底关 | 低  已修（P37） |
| A10 | 已清 | boot.gd:13 精确匹配 Godot 4.7 | 低  已修（P37） |
| B1 | 已清 | HUD 全轮询驱动 | 高  已修（P38） |
| B2 | 已清 | 单位每帧无条件重绘 | 中  已修（P38） |
| B3 | 已清 | 草坪整张重绘 + 每格数组复制 | 中  已修（P38 前两子弹 / P75 第三子 |
| B4 | 已清 | 贴图与关卡列表反复加载 | 中  已修（P38 第一子弹 / P75 二、三 |
| B5 | 已清 | 花园页 0.5s 全量刷新 | 中  已修（P38） |
| B6 | 已清 | Loc 每次查询重建表数组 | 低  已修（P38） |
| B7 | 已清 | 特效无池且清场漏层 | 中  已修（P38 第二子弹 / P76 第一子 |
| C1 | 已清 | game_manager.gd 是 god object | 高（重构类，分批做） |
| C2 | 已清 | 召唤四道门禁逐字复制两份 | 高  已修（P40） |
| C3 | 已清 | plant_db 与 zombie_db 约 60% 样板同构 | 高 |
| C4 | 已清 | 选择/装备状态手工互斥 | 高 ——  已由 P54 清掉（且修掉一个真 b |
| C5 | 已清 | 三个近 40 行的 row-dict 构造器 | 中 |
| C6 | 收窄 | 相位写了立刻被覆盖 | 中 ——  P74 复核：这条的前提已被 P30 |
| C7 | 已清 | 其它重复 | 低 |
| C9 | 已清 | balance.gd 体量 | 低（已获授权，已落四刀：P69 / P70 / P71 / P108 场景四表） |
| C10 | 已清 | "这一下点下去没成"31 处各写各的 | 中 ——  已由 P55 清掉（清单里没有这一条 |
| D1 | 已清 | 僵尸被装配两次 | 中 |
| D2 | 已清 | 数字单元格写错静默变默认值 | 中 |
| D3 | 已清 | difficulty.gd:34-38 + game_manager.gd:827-828 | 中 |
| D4 | 已清 | 死代码/死常量 | 低 |
| D5 | 已清 | layout.gd:205-246 | 低 |
| D6 | **未清** | garden.gd 三则 | 中 |
| D7 | **未清** | Loc key 拼接 | 低 |
| D8 | **未清** | 豌豆每回合多次全表扫描 | 中 |

## A. 正确性与数据安全（优先）

### A1 · 存档写入非原子，坏档会被静默覆写 —— 高 ✅ 已修（P37 / P56）
- **复核（2026-09-23）**：`profile.gd:180` / `garden.gd:380` 的 `save_to_disk() -> bool` 现在走
  `SafeIO.write_text_atomic`（先写 `.tmp` 再改名，注释即写着 OPTIMIZATIONS A1），解析失败走
  `keep_broken()` 把坏文件改名留存、**不**覆写。settings.cfg 同一条路径在 P56 接上（`write_config_atomic`）。
- 原文（P28 审查时的现场）：
- `scripts/core/save/profile.gd:171-182`：`FileAccess.open(WRITE)` 直接截断目标文件，中途崩溃 / 断电即产出半截 JSON。
- `scripts/core/save/profile.gd:56-62,81-90`：解析失败走 `_reject()` → `apply_defaults()` 重建初始档；
  `load_from_disk()`（`:87`）在失败分支**照样 `save_to_disk()`**，于是原文件被初始档覆盖，玩家进度彻底丢失。
- 建议：① 写 `.tmp` 成功后 `DirAccess.rename_absolute` 替换正式文件；② 解析失败先把坏文件改名 `.bak` 再重建。
  `settings_store.gd:63-77` 同样非原子，但数据可再生，顺手统一即可（低）。

### A2 · `KEY_N` 直通 `reset_progress()`，绕过两击确认 —— 高 ✅ 已修（P37）
- **复核**：`game_manager.gd:3590` 的注释就是这条（"no way back (OPTIMIZATIONS A2)"）——热键改走
  `request_reset()` 的两击确认。
- 原文：
- `scripts/core/game_manager.gd:2776-2777`：调试热键直接清档，而 UI 路径走 `request_reset()` 有两击确认。
  一次误触 = 全部进度清零（叠加 A1，连回滚都没有）。
- 建议：热键也走 `request_reset()`。

### A3 · 落盘返回值被系统性丢弃 —— 中 ✅ 已修（P65）
- **复核（2026-09-23 全量测量）**：这条比 P28 审查时记在下面的"19 处"**大一倍**——全工程
  `grep -rn "\.save_to_disk()" scripts/` 有 **38 处 / 5 个文件**，横跨**三个**账本
  （garden 14、profile 17、run 7），`game_manager.gd` 自己只占其中 19。所以修的不是"在管理器里
  接一下返回值"，而是**每个账本一道公共门**：`save_garden()` / `save_profile()` / `save_run()`
  三个公开函数（公开是故意的——`run_flow.gd`、`rewards.gd`、`garden/garden.gd` 也在持久化，私有门会把
  三分之二的面挡在外面）+ 一个 `_record_write()`，38 处调用点全部改走门。本批的判据因此是一条
  **可 grep 的不变式**：同一条命令现在只剩门里那 3 行。
- **失败怎么变得可见**：`push_warning`（英文，§2）+ 按账本记 `_unsaved[ledger]`，`_set_message` 把
  `msg.save.alarm` 当**后缀**挂在之后每一条状态行上，直到该账本有一次写入落地。原因：38 处里有一多半
  在写盘之后**同一击里**就把自己的成功文案交给 UI（`buy`、两处出售、三瓶药剂、能量豆），一次性提示
  会被当场盖掉——那正是这条债的"静默"二字。分账本记也是同一个原因：商店先写 garden 再写 profile，
  单一开关会被第二次写入的成功抹掉第一次的失败（新 boot 探针的第 4 条断言锁住这件事）。
- **有意没做**：不给失败配"拒绝音"（P55 的账已经定过——那个声音的含义是"你点了、事情没发生"，而这里
  事情发生了、是磁盘没接上，用它等于把故障算在玩家头上）；也不加 HUD 常驻角标（要开窗口 ⇒ 归 §4-10 那一队）。
- 原文（P28 审查时的现场）：
- `game_manager.gd:822,1403,1613,1882,1911,1980,2809`：`garden.save_to_disk()` / `profile.save_to_disk()`
  一律不接返回值，写盘失败即静默丢进度（与 A1 是同一类风险的两半）。
- 建议：失败时至少 `push_warning`，最好 HUD 状态栏提示。

### A4 · 花园自然恢复有的路径落盘、有的不落 —— 中 ✅ 已修（P37 · 收尾于 P66）
- **复核**：`game_manager.gd:714` 的 `_recover_garden()` 注释就是这条（OPTIMIZATIONS A4）——
  恢复与落盘收成一个出口，各处不再各自调用 `apply_natural_recovery()`。
- **P65 复测发现的另一半（P66 已收）**：`garden/garden.gd` 的 `_process()` 那时仍然**自己**跑
  `apply_natural_recovery()`、自己挑一句当状态、自己落盘——所以"一个出口"只对**菜单页**成立，
  花园页是第二个业主。P66 把那道门改名为公开的 `recover_garden()` 并让它返回**那几句话**
  （页面要的就是句子），`_process()` 从此只问门、不再自己算；新 boot 探针 `[Recover]` 四条断言
  把"时钟站起来"与"同一次调用会去写盘"绑在一起证明（后者靠 scratch 档拒写来闩上 A3 的告警——
  健康机器上唯一能看见"写被试图做过"的办法）。
- **仍然留在 `garden.gd` 类内的两处不是漏网**：`parse_text()` 里那次（读档当场就把到点的植株立起来，
  那时 Game 还没有这个实例）与 `self_check()` 里的 scratch（它自己就不该写盘）。
- 原文：
- `game_manager.gd:519,534,549,1537` 调 `garden.apply_natural_recovery()` 后**不保存**；
  `game_manager.gd:873-877` 同样调用却 print + save。前端页面里恢复的植物状态可能丢。
- 建议：统一走一个 `_recover_garden()`（恢复 + 落盘）。

### A5 · 自检直接改玩家真实数据 —— 中 ✅ 已修（P35）
- **复核**：`Profile` / `Garden` 现在有 `snapshot()` / `restore()`（`tools/member_name_check.gd`
  把这两个名字列进 RefCounted 清单并注明 [P35]），`game_self_checks.gd` 的探针一律
  先 snapshot、跑完 restore——自检中途报错不再留下脏数据。
- 原文：
- `game_manager.gd:3213-3215,3199,3216,3333`：`_run_card_self_check` 等把真实花名册
  `entry["downed"]=false`、整字典换入换出 `profile.warehouse/durability`，无事务保护；
  自检中途报错即留下脏数据。
- 建议：Garden/Profile 加 `snapshot()/restore()`，或自检用探针实例。

### A6 · 重复调用会把显示名 "#2" 越接越长 —— 中（潜伏）✅ 已修（P37）
- **复核**：`unit.gd:333-340` 的 `refresh_display_name()` 注释就是这条——显示名每次从
  `base_display_name` 重算再拼 `display_tag`，不再往上追加。
- 原文：
- `scripts/core/unit.gd:271-275`：`display_key==""` 分支写 `display_name += display_tag`，
  `refresh_display_name()` 每调一次追加一次。当前只有裸 `Unit` 命中，属潜伏 bug。
- 建议：分离 `base_name`，显示名每次从 base 重算。

### A7 · 豌豆与火花同帧生成，火花永远先到 —— 中 ✅ 已消解（抛射体重构）
- **复核（2026-09-23）**：这条描述的两行代码已经不存在——`spawn_pea` 这个入口在 P33/P34 把弹道
  抽成 `scripts/projectiles/projectile.gd` 时就没掉了。现在 `spawn_spark` 的**射击类调用点全在命中
  分支里**（`projectile.gd:218` 是分批结算的弹着、`:282` 是同步/fast_forward 的弹着，两条路径都是
  "打到之后"），开火处（`base/shooter_plant.gd`）只给豌豆一个 muzzle 偏移。即"火花跟着落点"已经是结构上的必然，不需要再修。
- 原文：
- `scripts/units/peashooter.gd:71-74`：`Fx.spawn_pea` 与 `spawn_spark(target.position)` 同时发出，
  豌豆还在飞行路上目标就炸了火花。
- 建议：火花延迟到豌豆到达（tween callback / timer）。

### A8 · 能量豆"先结算收益、后扣道具" —— 低 ✅ 已修（P37）
- **复核**：`game_manager.gd:1936-1941` 的注释就是这条——`_take_bean()` 提到最前面，扣不动直接
  `_refuse`；只有"第一下就没结算成功"（什么都没发生）时才把豆子退回背包。
- 原文：
- `game_manager.gd:1506-1530`：`_apply_energy_bean` 先打 N 下（可能触发击杀与掉落），
  最后才 `_take_bean()`；扣减失败时收益已经发生。建议先扣再结算。

### A9 · 坏关卡文件静默变兜底关 —— 低 ✅ 已修（P37）
- **复核**：`game_manager.gd:910` 的 `start_level` 先解析、解析失败就地拒绝并留在关卡列表
  （注释指着 A9）；`:1167` 是它的下游，那里的分支现在拿到的是"已经解析成功"的关卡。
- 原文：
- `game_manager.gd:604-616`：`start_level` 不检查 `level.load_from_file()` 结果。
  建议：失败时提示并留在关卡列表。

### A10 · `boot.gd:13` 精确匹配 Godot 4.7 —— 低 ✅ 已修（P37）
- **复核**：`boot.gd:13-23` 现在只对 **major** 不同才 `push_warning`；minor 不同降成一行普通
  `print`（注释指着 A10，理由是"每次启动都警告会训练所有人忽略启动日志"）。
- 原文：
- 任何 4.x 升级都刷启动警告。建议只校验 major。

---

## B. 每帧性能（改动局部、收益直接）

### B1 · HUD 全轮询驱动 —— 高 ✅ 已修（P38）
- **复核**：`hud.gd:67-79` — `_process` 的重绘改为**只在"读数签名"变了时**才 `queue_redraw()`
  （注释指着 B1，点名"每秒 60 次重排整块 HUD"）；`hud.gd:706` 把卡片价格改成表加载一次。
  `_sync_states()` 仍每帧跑，但它内部是"值变了才格式化/赋值"（原文第三子弹）。
- 原文：
- `scripts/ui/hud.gd:60-62`：`_process` 无条件 `queue_redraw()` + `_sync_states()`，整块 HUD 每帧重绘重算。
- `hud.gd:605`：每帧对每张植物卡调 `Balance.plant_def(key)`，内部做两次 `duplicate()` 与合并
  （`balance.gd:429,576`）→ 每帧 N 个临时 Dictionary。
- `hud.gd:623,662`：每帧为每张卡 `Loc.tf(...)` / `"%d/%d"` 格式化后才和旧文本比较。
- `hud.gd:800-816`：`_draw_top_bar` 每帧新建 stats 数组 + 5 次 `Loc.tf`；
  `game_manager.gd:2647` `next_wave_text()` 每帧对 `waves.keys()` 排序；`2545-2568,2633`
  `plant_total()/zombie_total()/hover_text()` 每帧建数组排序。
- 建议：值变化才格式化；波次文本按 round 缓存；中长期改成 Game 状态信号驱动的增量刷新。
  最快的改法是给 `_sync_states` 加节流（例如 0.1s）+ 脏标记。

### B2 · 单位每帧无条件重绘 —— 中 ✅ 已修（P38）
- **复核**：`unit.gd:633` 的注释指着 B2——`_process` 末尾的无条件 `queue_redraw()` 去掉，
  改为"闪白 / 行动条比例 / 名字"变化时才重绘。
- 原文：
- `unit.gd:416-429`：`_process` 无条件 `queue_redraw()`（注释自认"单位少不值得了"），
  `_draw_name`/`_draw_action_bar` 每帧做 `%` 格式化与字体取值。
- 建议：仅 flash / 行动条比例 / 名字变化时 `queue_redraw()`。

### B3 · 草坪整张重绘 + 每格数组复制 —— 中 ✅ 已修（P38 前两子弹 / P75 第三子弹）
- **复核**：`grid.gd:34`（草坪本体不再因换格高亮整张重绘）、`grid.gd:326`（绘制路径改问
  `has_zombies_at()`，注释指着 B3）＝前两子弹落地。
  **第三子弹（P75）**：`grid.gd:119-120` 的 `on_layout_changed()`、`:378-379` 的 `all_units()`
  现在把两张表**分别**交给 static 的 `_refresh_unit_layout()`（`:125`）与 `_append_units()`
  （`:383`），`for table in [_plants, _zombies]` 那个每次调用新建的数组没有了；同一处的逐节点
  `has_method("refresh_layout")` 改成 `node as Unit`（`Unit` 是 `class_name`，判定等价且省一次
  方法查表）。`_restack()` 里的 `has_method("set_stack_index")` **故意保留**：它的注释说明那里
  要容忍启动自检塞进来的裸 `Node2D` 桩，换成 `as Unit` 会改变自检语义。
- `grid.gd:30-34,235`：鼠标换格 → 整张 45 格草坪重绘，`Color.lightened/darkened` 每帧重算。
  建议高亮层拆成子 `Node2D`，草坪本体只在格子内容变化时重绘。
- `grid.gd:163,226,290-294`：`is_tool_target` 用 `get_zombies_at()`（内部 `.duplicate()`）判空，
  `_draw_tool_tint` 对 45 格各调一次 → 每次重绘 45 次数组复制。建议加 `has_zombies_at(col,row)`。
- `grid.gd:44-48,137`：`for table in [_plants,_zombies]` 每次分配 + 逐节点 `has_method()`。

### B4 · 贴图与关卡列表反复加载 —— 中 ✅ 已修（P38 第一子弹 / P75 二、三子弹）
- **复核**：① `unit_art.gd:41` 有 static 路径缓存（注释指着 B4）✅。
  ② **P75 落地**：`level_list.gd:19-45` 新增 `_parsed`（路径 → `LevelData` / 坏档原因）+
  `_folder_sig`，`discover()` 先 `_sync_cache()`（`:72`）比对目录签名（`:85`：文件名 + **字节长度**，
  走 `FileAccess.open(READ)` + `get_length()`——Godot 4.7.2 的 `DirAccess` **没有** `get_size()`
  也没有 `get_modification_time()`，探针踩出来的：调不存在的方法是**运行期 SCRIPT ERROR**、函数直接
  中断，签名于是恒为空串，而空签名**永不失效**，缓存在日志里看起来完美）。签名没动 ⇒ 整包零解析；
  缓存里**只有磁盘事实**，玩家/语言相关的**行**仍每次投影（`:131` `_project()`），因为行里引
  `SettingsStore.is_cleared()` 与当前语言——把行缓存进去才会真的说谎。`skipped` 那个可变 public
  static 一并收成 `_skipped` + `skipped()` 出口（`:38`）。**已知盲点**：改动后字节数恰好相同的
  关卡文件要靠重启（`res://` 运行期只读，编辑器里改档本走不到这里；调试键 R 是 `LevelData` 直读，
  不碰缓存）。
  ③ **P75 落地**：网格只切一遍——`refresh()`（`almanac/almanac.gd:192`）末尾不再自己 `_apply_page()`，
  只留 `on_layout_changed()`；`open_view` 与三个 tab 处理程序（section / race / group）去掉多余的
  `on_layout_changed()` 共 4 处；`open_view` 里 `visible = true` 提到 `refresh()` **前面**（`:136`），
  这样 `_sync_panel_view()` 在那一次布局里就读到真相，不需要第二次布局调用。计数器 `page_builds`
  （`:82`、`:491`）由 `[FrontEnd]` 断言读取——**没有计数器，这条优化在日志里是隐形的**：第二次布局
  重建的正是第一次已经显示的东西。
- 原文：
- `scripts/units/unit_art.gd:37`：`load_texture` 每次 `ResourceLoader.exists+load`，无路径缓存；
  `garden/garden.gd:125,324-325`、`almanac/almanac.gd:448-449` 每次刷新都走它。→ 加 static 缓存。
- `scripts/core/level_list.gd:23-43`：`discover()` 每次重扫目录、重解析全部关卡 JSON
  （`menu.gd:143`、`almanac/almanac.gd:139` 都会触发；`almanac/almanac.gd:1128` 甚至只为取 `.size()`）。
  → 包级缓存，按目录内容失效；`skipped` 可变 static 也顺手处理。
- `almanac/almanac.gd:105-114`：打开页面先 `refresh()` 再 `on_layout_changed()→_layout()`，
  同一页网格**重建两次**。→ refresh 末尾只排布局。

### B5 · 花园页 0.5s 全量刷新 —— 中 ✅ 已修（P38）
- **复核**：`garden/garden.gd:116`（"这页每秒为 16 个花盆调两次"→ 改为 diff 后只刷变化的格子）、
  `:517`（只有 DOWNED 植物需要那半个秒的时钟）。
- 原文：
- `garden/garden.gd:480`：每 0.5s 无条件 `refresh()`：16 个 plot 全部 `setup()`（含 tooltip 格式化）。
  → diff 后只刷变化的格子。

### B6 · `Loc` 每次查询重建表数组 —— 低 ✅ 已修（P38）
- **复核**：`loc.gd:58` 的注释指着 B6——四张表在首次查询时合并成一张只读查找表，
  `t()` / `has_key()` 不再每次分配 `_tables()` 那个数组。
- 原文：
- `scripts/core/loc.gd:44-47,124-129`：`t()/has_key()` 每次重建 `_tables()` 再线性查 4 张表，
  而它被自绘文本高频调用。→ 首次构建合并成单张只读查找表（键唯一性已有自检保证）。

### B7 · 特效无池且清场漏层 —— 中 ✅ 已修（P38 第二子弹 / P76 第一子弹）
- **复核**：② `fx.gd` 早已给 `_dur` 设下限（`BalanceUI.MIN_FX_TIME`）。① **P76 关掉**：
  `Fx` 现在自己拥有一个节点（`fx.gd:39` `static var _layer`，`:42 attach(board)` 由
  `_bootstrap` 在建好草坪后立刻调用 —— `game_manager.gd:1060`），三个 spawn 入口
  （`spawn_spark` / `spawn_popup` / `spawn_banner`）**不再收 parent**，一律走
  `:72` 的私有 `_put()` 这一道门；`_teardown_game` 除了原来的 `child is Unit` 循环，
  现在还会 `Fx.clear()`（`game_manager.gd:972`），清场不再漏特效。
  18 个调用点（`projectile.gd` 2 / `zombie.gd` 5 / `chomper.gd` 1 / `producer_plant.gd` 2 /
  `wall_plant.gd` 1 / `rewards.gd` 4 / `game_manager.gd` 3）全部去掉 parent 实参；
  `rewards.gd` 那四处 `if game.grid != null` 的保护随之消失（门的 `_put` 自己会答）。
  **两个不是"照抄原建议"的地方，都记在这里**：
  ① **"无池"没有做** —— 原文针对的 `new() + create_tween()` 形状早就不存在了
  （火花现在是一个在 `_process` 里自转、自己 `queue_free()` 的 `Node2D`），
  而原文自己的 remedy 只写"挂独立层并统一清理"。池会给同一批节点找第二个业主，
  等有人量出理由再说。
  ② **独立层带来的绘制顺序副作用**：特效过去靠"永远最后 add_child"天然盖在单位之上；
  常驻层是草坪的第一个孩子， tree order 反而把它压在最底下 —— 所以给它 `z_index`
  （`balance_ui.gd:276` `FX_Z_INDEX = 100`，单位与射弹从不设 z_index 即为 0）。
  这条是**新增的呈现断言**（`fx.gd` 自检第 2 条读的就是这个数），
  但它仍然只是一张日志收据：**伤害数字是否真的都浮在僵尸之上要目视**（见 PLAN §5.33 ⑥）。
- **P76 的验收形状**：断言**不是**折进已有块，而是**新增一个模块** —— `[Fx]` 五条
  （`fx.gd:163 self_check()`，日志 `:520-525`）⇒ **PASSED 基线 27 → 28**（与 P73/P74 同形，
  与 P75 相反）。另外"装配"这一半折进 `[FrontEnd]` 第 6 条（`screen_flow.gd:421-441`：
  真草坪 + 真 `_teardown_game()`），它同时打出 `[Board] teardown took 1 still-playing
  effect(s) with the board` 这一行 —— 那两行是这一批唯一能证明"调用还在"的东西。
- **同一道 `child is Unit` 筛子的另一个漏网者没在本批处理**：`Projectile extends Node2D`
  （`projectile.gd:2`），所以一发**在飞的豌豆**同样活得过清场。它自己的动画记账靠 `_exit_tree`
  结算、且带代际守卫，所以**不会卡住回合**；`leave_game()` 在拆局后同一帧就把世界藏了，所以
  **离开战斗时看不见它**。要认的是 `_start_new_game()` 那条路：拆局发生在世界仍可见之时，
  而 `_swept_body()` 扫的是 `_game.units`（此刻已是**新一局**的单位）⇒ 一颗上一局的弹
  有可能打在新一局的僵尸身上。这是与本条平级的**另一条**发现，已登记 **PLAN §4-15**
  （含两条候选改法，以及"为什么本批连证据都造不出来"——它要两局相接的现场），不做顺手改。
- 原文：
- `scripts/fx/fx.gd:85-112`：每发豌豆/火花/飘字都 `new()` + `create_tween()`，无对象池；
  特效挂在 `grid` 下，`_teardown_game`（`game_manager.gd:664`）只清 Unit 子节点，
  残留特效会继续在自己的节点上播完整动画。→ 特效挂独立层并统一清理。
- `fx.gd:73`：`_rise/_dur`，配置 `_dur=0` 即除零，clamp 一下。

---

## C. 架构与重复逻辑

### C1 · `game_manager.gd` 是 god object —— 高（重构类，分批做）
一个 autoload 同时管：显示与字体、语言、音乐、5 个前端页面、回合引擎、经济、
掉落/奖励/商店/仓库、花园账本、输入、10 套自检。
体量随阶段增长：写下本条时是 3606 行 / 191 个函数，P26–P34 的内容增量把它推到
**4420 行 / 251 个函数**（P35 后实测）；第 1、4 刀之后 **3615 行 / 203 个函数**（P36 后 `wc -l`）；
第 2 刀之后 **3807 行 / 212 个函数**（P61 后）；第 3 刀之后 **3677 行 / 208 个函数**（P64 后，
`wc -l` + 数 `^func`；搬走的是 210 行 / 5 个私有函数，另 399 行落在 `ui/screen_flow.gd`）。
**这四段数读下来是一课，不是进展**：四刀搬走约 1000 行，而 P37 之后那二十来批（玩法、清债、数据安全混在一起）
又把它长回 3890——所以"清债让 god object 变小"这句在本项目里**只有加功能停下来以后才看得见**。
真正被这一串数证明的是另一件事：**它能被量化**，下一轮不必靠感觉判断 god object 有没有恶化。
建议的几刀（互相独立、可分别验证）：
1. 自检整块搬出 → ✅ **已完成（P35，2026-09-22）**：`scripts/core/game_self_checks.gd`
   （`SelfChecks`，组合对象 + `game` 反向引用，manager 只留构造与 6 个派发点）。
2. 奖励/掉落结算 → `battle/rewards.gd`；**P36 之后这一刀只剩战斗掉落** `_roll_drop` /
   `_grant_rewards`（run 的三阶段奖励 `_grant_run_base` / `_roll_run_reward_options` /
   `_apply_run_defeat` 已随第 4 刀归 RunFlow）。
   → ✅ **已由 P61 做掉（2026-09-24）**，四处与这条的建议不同，都写在落地处：
   ① 落在 **`scripts/core/rewards.gd`** 而不是新建 `battle/` 目录——P35 的 `SelfChecks`、
   P36 的 `RunFlow` 都在 `core/`，"从 manager 搬出来的东西"共用一个货架，
   为一个文件开新目录是无关的 restructuring（AGENTS §2）。
   ② **故意不写 `class_name`**，消费方 `const Rewards := preload(路径)`：新的全局类名
   在无头里要等编辑器扫过（HANDOFF §7.67），而这一刀的价值恰恰是"无头当场能证"。
   形状也因此是 **static + `game` 形参**（`SafeIO` / `Music` / `Sfx` 的同族），
   不是 P36 那种实例对象。
   ③ **状态一点没搬**：`_reward_lines` / `_backpack_lines` / `_pending_deaths` /
   `_drops_enabled` 仍归 manager——读它们的全不是掉落逻辑（结果面板打印、`_end_game`
   写 LOSE 那行、`RunFlow` 把战役三阶段追加在同一份账单上、自检清死亡账 7 次）。
   这与 P35 / P36 当时"搬代码、留状态"的判断是同一条：**规则只有一个主人，账本另说**。
   ④ `_roll_tag` / `_describe_roll` 变公开的 `roll_tag` / `describe_roll`：探针要能在
   不掷骰子的前提下断言"必中的奖励不挂概率标签""没中的那次由什么命名"。
   **`grant()` 本身无头测不到**（要打完一关），所以这一刀的无头证据是三条纯词汇断言
   + 一条结构断言（"manager 不再有 `_roll_drop`"，防的是"搬完还留一份私有副本"），
   掉落行为则由开局探针 `_rewards()` 管：门禁关着 ⇒ 一分不掉、雪人僵尸必掉钻石**并且跳过**
   那三次骰（`return` 那一层）、普通僵尸按**上下界**断言而不是按结果。
   细节见 `docs/history/03-p37-p82-batches.md` §1 的 P61 一节、判据 §5.18。
   **C1 剩下的**：只有第 3 刀（页面切换 → `ui/screen_flow.gd`）→ **已由 P64 落地，见下一条**。
3. 页面切换流程：`show_*` / `_hide_views` / `_set_world_visible` / `back_from_front_end`
   → `ui/screen_flow.gd`；**通用管线**仍然留在 manager，run 的页面决策已归 RunFlow，
   所以这一刀不再需要绕开战役代码。
   → ✅ **已由 P64 做掉（2026-09-24），C1 的第 3 刀也是审计点名的最后一刀。** 四处与这条的建议不同：
   ① `back_from_front_end` **没有**变成 `ScreenFlow.back` 的调用别名，而是留一个一行委托——
   六个文件调它，公开入口的形状归 manager（`[P12]` "Game 是谁在哪个页面的唯一主人"这条设计规则
   只在**私有管线**那一层被切开）。所有公开 `Game.show_*()` 同样都还在。
   ② 搬的是**四个私有函数**（`_leave_game` / `_hide_views` / `_set_world_visible` /
   `_resume_battle` / `_refresh_front_end_page`），不是 `show_*` 本体；`start_level` 与
   `_start_new_game` **刻意没搬**（进一场战斗不是"换页"）。
   ③ `_recover_garden` / `_settle_garden` / `_teardown_game` 留在 manager：它们写的是账本与棋盘，
   不是页面。④ 状态（`screen` + 那些视图节点：主菜单加上前端自己的十页）一点没搬，
   与 P35/P36/P61 同一条判断。
   **这一刀与前面几刀最大的不同**：搬走的代码**在无头启动里真的会跑**，所以它第一次给出了
   行为证据而不是词汇证据——`[FrontEnd]` 自检开局开一次卡页、`back()` 回一次、再收回主菜单，
   断言"谁开着 / 谁脏了 / 复原没有"，并且把 `hide_views()` 的清单和场景层里真实的 `Control`
   子节点**对数**（10 对 10），以后往 `_bootstrap()` 加页面却忘了 `hide_views()` 会当场红。
   细节见 `docs/history/03-p37-p82-batches.md` §1 的 P64 一节。
   **C1 四条到此全部落地**（第 1/P35、第 2/P61、第 3/P64、第 4/P36）。
4. run / 战役流程（`adventure run (P31-A)` 一整簇 48 个函数、810 行）→ ✅ **已完成
   （P36，2026-09-23）**：`scripts/core/run_flow.gd`（`RunFlow`，与 P35 同形的组合对象）。
   `run` / `chapter` 两个数据对象**刻意留下**（`garden` / `profile` 同一 idiom：存档对象
   归 manager，流程归子对象），页面 scratch（`_squad_pick` 等 5 个）跟着流程走。
   顺手修掉两处本轮发现的债：清档 `reset_progress()` 不清 run 页面缓存（现在走
   `RunFlow.clear_page_state()`）、宝箱节点页每次 `refresh()` 重摇一次奖（现在开场摇一次、
   所见即所得）。

### C2 · 召唤四道门禁逐字复制两份 —— 高 ✅ 已修（P40）
- **复核**：`game_manager.gd:1632` 就是 `summon_blocker(plant_id) -> String`，两处调用点
  （`:2647` 卷轴点击、`:2734` 开局探针路径）只剩"问一次、照着说"；`game_self_checks.gd` 里
  还有三条断言用同一个函数比对状态栏文案。
- 原文：
- `game_manager.gd:2700-2711` 与 `:2787-2795`（P36 后复核过的现行位置；旧记录里的
  `:2208-2223` / `:2288-2303` 是删掉 810 行 run 簇之前的行号）：卷轴/预算/冷却/空位四道检查、
  `Loc` key、参数顺序完全相同。→ 抽 `summon_blocker(plant_id) -> String`，两处共用。
  （已核实：两段除 `plant_id`/`selected_plant` 与 `return`/`return false` 外逐行一致。）

### C3 · `plant_db` 与 `zombie_db` 约 60% 样板同构 —— 高
✅ **已完成（P29，2026-09-21）**：不止共享 reader——按用户设计做成分层花名册。
`scripts/core/unit_sheet.gd`（`UnitSheet`）统一读 `data/units/units.csv`（每单位一行 +
`race` 列，如 `plants/pea`、`zombies/normal`；拥有共用列）+ 族表 `plants.csv` /
`zombies.csv`（各自独有列）+ 按需创建的子族表（缺层跳过）；深层覆盖浅层，族表孤儿行只报告。
`plant_db.gd` / `zombie_db.gd` 变成薄门面（公开 API 不变，外部调用点零改动）；`UnitCsvManager.ID_COLUMNS` 收编了三处硬编码
的 id 列候选（含 item_db）。迁移脚本 `tools/migrate_unit_sheets.py`（一次性，带防重跑护栏）。
- `plant_db.gd:112-194,198-229,233-448` vs `zombie_db.gd:135-204,237-266,270-500`：
  `svg_path()`/`scene_path()` 仅 root/suffix 不同，text 采集循环、`has/row/name/art/has_art/view/...`、
  load 骨架与 self_check 输出全部复制。列名数组 `[COL_ID,"ID","英文"]` 在
  `plant_db.gd:131`、`zombie_db.gd:152`、`item_db.gd:87` 三处硬编码。
- 建议：把 `unit_csv.gd` 升级为带列配置的共享 reader，两个 DB 只声明各自差异。

### C4 · 选择/装备状态手工互斥 —— 高 —— ✅ 已由 P54 清掉（且**修掉一个真 bug**）
- `game_manager.gd:1004-1006,1027,1484,2196,2224,2234,2248`：`selected_plant` / `selected_tool` /
  `_bean_armed` / `glove_source` 四个互斥状态各处手工清零，`clear_selection()` 不清 `_bean_armed`，
  `:1484` 又反向手工清。漏一处就是"同时选中两张卡"类 bug 的温床。
- 建议：收成一个 `selection` 状态对象（含 `clear()` / `set_*()`）。

✅ **P54 落地（2026-09-23），但两点与这条的建议不同，且这条把问题写小了**：
- **数量**：审计列 7 个位置，实测**动手前是 13 个手写清零点、24 行赋值**，其中 6 行是
  `_bean_armed` 单独的（清单没数豆）。现在 = `_disarm_all()` 里 4 行，全场唯一。
- **"温床"不是假设**：`select_plant()` / `select_tool()` 都只清另外两个卡槽、**不清手里的豆**，
  而 `_on_cell_clicked()` 问的顺序是**豆优先** ⇒ "拿起能量豆 → 点一张卡 → 点格子"这条
  纯鼠标路线**实际喂的是豆，卡槽却把那张卡画成已选中**（阳光不扣、卡不进冷却）。
  根因写在 P54 记录里：豆是 P15 加的，三件套的清零名单是 P12/P13 时代写的，**豆从来没进过那张名单**。
- **没做成新 class**（与建议不同，两条理由）：新 `class_name` 无头要等编辑器扫过（HANDOFF §7.67），
  而这一刀的价值正是"无头可证"；且这四个状态没有一件属于自己的行为，包成对象只是多一层跳转。
  落地形状：私有 `_disarm_all()` + 公开 `clear_selection()`（= 它 + 一次 `_sync_grid_hint()`）。
  **`set_*()` 也没做**：自检里有 9 处 `game.selected_plant = ...` 直接赋值（探针在造场景，
  不是玩家动作），走 setter 反而要为探针开后门。四个字段仍是公开 var。
- **一处契约故意变了**：回合开始的 `clear_selection()` 现在连豆一起放下（豆只在落地时才花，
  不丢道具）。`arm_energy_bean()` 因此必须换序（先 clear 后 arm）——这类"扩大 clear 口径"的改动
  **编译器不会红**，它让紧随其后的 arm 变成静默 noop。留档给下一次做同类合并的人。
- 本批之后新留的一条自查 grep（判据与新断言见 `docs/history/03-p37-p82-batches.md` §1 的 P54 一节、§5.11）：
  四个字段的手写清零在本文件里只应命中 `_disarm_all()` 内的 4 行。
- **顺手核实出的一处相关缺口（未做，属呈现层）**：`is_bean_armed()` **零调用者** ——
  "手里有豆"在界面上只有消息行闪现一次，没有任何常驻指示。上面那个 bug 在真机上不可见、
  能活 30 多个批次，根因就在这里。补指示要先定方向（PACK 按钮 armed 态 / 卡槽上方提示），
  已记进 `docs/history/03-p37-p82-batches.md` §5.11 第 5 条等用户点单。

### C5 · 三个近 40 行的 row-dict 构造器 —— 中
- `game_manager.gd:1444-1473,1546-1577,1763-1808`：键集重叠且已开始漂移
  （`count_text`/`value_key` 只有一家有）。→ 共用 `_item_row(id,n,kind,extra)`。

⚠️ **P53 之后复核：这条已经不像它写的那么大了**（行号也是审计当时的）。今天这三个位置上是
`shop_tiles()`（`:2106`）、`_container_tiles(p_which)`（`:2332`）与 `pack_rows()`（`:1998`）：
**仓库页与背包页那两份早在某轮合成了同一个 `_container_tiles`**（`count_text`/`value_key` 因此只剩一处，
清单点名的那次漂移已经不存在了）。剩下的"重复"是**三处手抄同一个行形状**：9 个键三家共用
（`id`/`kind`/`title`/`art`/`badge`/`note`/`dimmed`/`badge_color`/`desc`），`kind_label` 有两家，
其余各自专属（商店 `price`/`price_text`/`owned_text`/`affordable`；容器 `count_text`/`count`/
`value_key`/`value_text`/`stack_value`；战斗内背包 `usable`/`count`）。而读这些行的视图一律
`p_row.get("key", 默认值)`（例：`warehouse_view.gd:43` 的 `"-"`）——**取不到就用默认值**，
所以少写一个键不会报错，只会静默显示成 `-`。
⇒ 建议的下一刀**不是** `_item_row(id,n,kind,extra)` 那种"把三家并成一个构造器"（各自的负载确实不同），
而是 ① 共用视觉键收成一个 `ItemRow.visual(...)` + `.merge(extra)`，或 ② 照 P53 对 `LevelList` 的做法，
只在 `ItemGrid` 的自检里断言"三种行的共用键集相等"。**② 更便宜且不藏语义**，与 P53 判断 3 同一条路。

✅ **本条已由 P74（2026-09-24）按 ② 收尾。** 构造器**一个字没改**（三家的负载确实不同，合并会藏语义）。
新增开机自检 `SelfChecks.item_rows(game)`（前缀 `[ItemRow]`）：`snapshot()` → 往背包与仓库各塞一件 →
调用**三个公开入口** `shop_tiles()` / `warehouse_tiles()`（→ `_container_tiles` 形状）/ `pack_rows()` →
断言九枚共用视觉键 `id`/`kind`/`title`/`art`/`badge`/`note`/`dimmed`/`badge_color`/`desc` 在每一种行里都在，
`restore()` 还原。**实测**：shop 14 键 / container 15 键 / pack 11 键，九枚共用键全部命中（`absent=[]`）——
与上面那段"9 共用 + kind_label 两家 + 各自专属"的复核逐字对上。任一家漂移 ⇒ 该行缺键 ⇒ `[ItemRow] self-check FAILED`
（且某家返回空行 = 播种失效，也判 FAIL，绝不因"没东西可检"而假绿）。基线 **26 → 27 PASSED**。

### C6 · 相位写了立刻被覆盖 —— 中 —— ⚠️ P74 复核：**这条的前提已被 P30-A2 分阶段结算推翻一半**
- `game_manager.gd:2337-2350`：一次调用内 `phase` 连写 PLANT/ZOMBIE/TURN_END 后覆盖，
  `phase_hint()` 对应三条文案与 `PHASE_NAME` 项是死状态。→ 要么真异步化回合，要么删掉无用相位。

⚠️ **P74 复核（2026-09-24，行号已再漂移）**：审计那句"要么真异步化回合"的补救**其实早就做了**——
`end_turn(p_staged=true)`（`:2808`，交互默认 staged）在写完 `phase=PLANT_ACTION`（`:2834`）后有
`await _wait_animations()`（`:2844`）、写完 `ZOMBIE_ACTION`（`:2858`）后有 `await _beat()`（`:2863`），
**两处 await 就是帧边界**，HUD 在这中间会重绘并读到这两个相位 ⇒ `phase_hint()` 的
`msg.phase.plant_action` / `msg.phase.zombie_action` **不是死状态**（只有 `fast_forward`/`end_turn(false)` 那条同步路径
才会一闪而过，那条是给快进用的，本就不该显示相位）。
**仍然成立的一半**：`TURN_START`（`:2927`）与 `TURN_END`（`:2878`）后面**没有** await，被紧跟的
`OPERATION`/`_begin_round` 在同一同步段覆盖 ⇒ 这两条文案对 HUD 仍是死的。
⇒ 本条**不再是"删死相位"**（该删的没几条了），收窄成一个**呈现决定**：要不要给 turn_start/turn_end 也各加一拍
（会改每局首尾的节奏=手感，需用户点单）。与 `ui_click` 同属"要用户先定呈现"的一类，故 P74 不动它、只把话记在这儿。

### C7 · 其它重复 —— 低
✅ **本组已由 P53（2026-09-23）处理完 6 条：5 条清掉（其中 1 条改用断言而非抽表），1 条核实后判定不做。**
下面每条**前面**是审计当时的行号（现已漂移，保留原文），**后面**的箭头是核实时看到的实际状态。

- `game_manager.gd:962-968` vs `:1193-1199`：`_charge_tools` 与 `_charge_plant_cards` 同体。
  → ✅ **已做**：两份循环体收成一个 `_charge_list(roster, thresholds, charges)`（字典按引用传入，
  就地更新），两个对外名字保留——自检是按名调用它们的。
- `game_manager.gd:2695-2709`：三个倒计时块同构；`:2702-2703` `<=0` 再赋 `0.0` 是空操作。
  → ❌ **不做，并且原判断有一处说反了**。三块现在在 `_process`（`:3622-3635`）：`_message_timer`
  到点清 `status_message`、`_retreat_timer` 到点钳零、`_reset_timer` 钳零外加"停在 SETTINGS 就刷新"。
  **钳零不是空操作**：外层写的是 `if x > 0.0`，值一旦转负就再也进不了这个分支，所以不钳的话
  计时器会**永久停在一个小负数**上。只是按今天的所有读方（`:1793`、`:1805`、`:3734`、`:3741`
  一律 `> 0.0` / `<= 0.0`）两者行为相同，它保护的是"下一个把这个字段当**时长**读的人"。
  三块的**到点动作各不相同**，合并就要引入回调或 `match`，代价高于三行副本，故保留原样。
- `garden/garden.gd:141-143` vs `:721-723`：`_countdown_text` 与静态 `_mmss` 完全重复。
  → ✅ **已做，实际比清单里还多一处**：同一个 `int(ceil(maxf(0.0, x)))` 舍入在文件里有**三处**
  （第三处是 `set_visual` 的"这帧要不要重绘"比较，它必须与显示口径一致，否则 DOWNED 花盆会
  为了一个不会变的数字每秒重绘两次）。现在统一为 `GardenPlot._secs_left()` + `_mmss()`，
  `GardenView` 那份静态删除。**命名是 `_secs_left` 而不是 `_recover_secs`**：这个类已经有一个
  叫 `_recover_secs` 的成员变量，同名静态函数会在解析期就被拒。这是 §7.53 那条坑的**自家版本**
  ——那里撞的是原生类的成员（`tools/member_name_check.gd` 查得到），这里撞的是本类自己的变量
  （私有名、且不在那张名单上，探针帮不上），是读文件时看到的。
- `menu.gd:519-528`、`item_screen.gd:299-308`：各自复制了 `UiStyle.fit_text`（`ui_style.gd:83`），
  且逐字符回退裁剪每次迭代调 `get_string_size`（O(n) 次测量）→ 统一调 UiStyle 并改二分。
  → ✅ **重复已做** / ❌ **二分不做**。副本实际是**四份**（`ui_style` / `menu` / `item_screen` /
  `item_tile`）且**已经漂移**：界面那三份的下限是 8 个字符，格子里那份是 3。现在两个下限都是
  `BalanceUI` 常量（`TEXT_FIT_MIN_CHARS`、`ITEM_TILE_TEXT_MIN_CHARS`），测量收进 `UiStyle.width_of()`、
  裁剪收进 `UiStyle.trim_tail()`，`fit_text()` 退化成"取默认下限"的一行壳。
  拒绝二分的理由：**它假设"前缀更长 ⇒ 一定不更窄"，而 kerning / 连字可以打破这个前提**；
  这些字符串（关卡名、提示行、格子标题）都短到不值得为省几次测量去承担裁错字的风险。
- `level_list.gd:60-137`：好行与 `_broken()` 两份 28 键表手抄 → 抽 `_blank_row()`。
  → ⚠️ **不抽表，改成自检断言**（键数其实是 **32** 不是 28）。抽 `_blank_row()` 会让"某个键在坏行里
  到底是什么值"从阅读面上消失，而 `_broken()` 手抄全部键的**唯一目的**就是那句"调用方不用测两种
  形状"。折中：`self_check()` 里新增 `_shape_drift()`，两边键集一旦不再相等就打印差集并 **FAILED**
  ——手抄的代价留着，手抄漂移的风险没了。
- `game_manager.gd:373-390`：六条 `x != null and is_instance_valid(x) and x.visible` 复制。
  → ✅ **已做，且早已长到十一条**：`apply_language()` 里每建一个页面就多抄一条（P22 仓库/商店/背包、
  P26 图鉴、P31 编队/路线图/奖励/选择、P32 卡组）。现在统一走 `_page_up(page)`。
  `hud` 那一条**故意不并入**——它不看 `visible`（为什么写在旁边的注释里）。
- **P55 顺路核出的第 7 条（清单里没有，属本组同一种病）**：`core/safe_io.gd:25`
  与 `core/settings_store.gd:88-95` **两份"写临时文件 + flush + rename"**。
  → ✅ **已由 P56 清掉（2026-09-23）**。当时拦路的"形状不合"用一条新函数解决，而不是硬塞：
  `SafeIO.write_config_atomic(cfg, path)`（`safe_io.gd:50`）把那份五行副本搬了家，
  `settings_store.gd` 的 `save_to_disk()` 从此只有一行换入调用。
  **刻意没有 `flush()`**——`cfg.save()` 自己 open/write/close，函数返回时字节已不在进程里。
  同时补了 P56 那份 `SettingsStore.self_check()` 探针（写 → 读回 → 故意喂坏字节 → 验证 park），
  所以这条账不是"改了没验"，是**第一次有东西证明 `settings.cfg` 读坏了会备份**。
  细节与验收判据见 `docs/history/03-p37-p82-batches.md` §1 的 P56 一节、§5.13。
  随下一次真正碰到存档代码的批次带走（P55 的账是"拒绝出口"，§2 不许批内混第二刀）。

### C8 · 超长函数清单（可读性）—— 中
- `level_data.gd` `parse_text`：**✅ 已拆开（P62，2026-09-24）**。审查时它是 256 行 / 14 个字段块，
  P62 动手前实测 **277 行**（`:144-420`，全工程最长）。落地形状比处方多做了一件：
  十一个方法（十个字段块 + 把 pack 波形的 `spawns` 列表单独抽出），
  `parse_text` 只剩 **34 行**——它现在只说**顺序**，内容各归其主。
  留在这个文件里、**没有**搬去新模块，因为它不需要新 `class_name`（⇒ 不欠扫单），
  而"最长的函数"这条病要的是**读得下去**，不是**文件变多**。
  代价与证据记在 `docs/history/03-p37-p82-batches.md` §1 的 P62 一节（两条 `[Levels] parser contract` 判决，
  它们是唯一**不用开局**就能证明"某个块不再被调用"的地方）。
  **同一份清单里 `game_manager.gd` 那五条：2026-09-24 重新量过，结论是"跟着代码搬走了、没有拆开"。**
  四条本来就是自检函数，P35 已经把它们搬进 `game_self_checks.gd`；剩下的 `_start_new_game`
  今天还在（`:1130`，**165 行**）。而搬走的那四条在新家里**更长**：实测
  `_zombies` **462 行**（:378，全工程最长，比审查当时最长的那条还长一倍）、`_cards` 216、
  `_pults` 183、`_one_shots` 177、`_levels` 169、`_spikes` 150。
  ⇒ C1 的四刀证明的是"**谁**拥有这段规则"，从来没有证明"这段规则变短了"；C8 这一条要动，
  动的地方现在是 `game_self_checks.gd`，不是 manager。**下一轮请重新跑这条测量**（形状见下），
  别信这里的行号——它们每批都会右移。
- `game_self_checks.gd` `_zombies`：**✅ 已拆开（P67，2026-09-24）**。上面那句"债跟着代码搬进了新家"
  到此结清：462 行（P67 动手前实测 507–970 = **463 行**，全工程最长）切成**一个只说顺序的父函数
  （71 行）+ 七段探针**（sheet 52 / freeze 34 / door 56 / words 26 / summon 106 / hammer 147 /
  arrival 35），十段的**顺序、列号、收尾**都留在父函数——因为在这份探针里顺序本身就是契约。
  与 P62 同一个形状，也**不新增文件**（⇒ 不欠扫单）。判据不是"全绿"而是
  **拆前后 `[SelfCheck]` 输出逐行等价**（`diff` 两份日志，零输出）：断言与 print 一行没动。
  **C8 至此在账上清零**（两处测量各自成立）：剩下的 `_cards` 217 / `_pults` 184 / `_one_shots` 178 /
  `_levels` 170 / `_spikes` 151 都是**一个函数讲一个机制**，长但不耦合，不在这一条的账上；
  `_start_new_game`（`game_manager.gd:1130`，165 行）要动得连玩法一起动，也不归 C8。
  ⚠ 行号同上：**每批都会右移**。
- 复审用的量法（一次跑出某文件最长的几个函数，只读；就是本次量出上面那串数用的）：
  `awk` 按 `^func ` / `^static func ` 切段、数段内行数、`sort -rn | head`。
- 原文（2026-09-21 的现场，行号已失效）：
- `game_manager.gd:3154-3345` `_run_card_self_check` 191 行；`:799-934` `_start_new_game`；
  `:2965-3085`、`:3347-3494`、`:3497-3565` 自检同样超长。
  ⚠ 这四组行号是 2026-09-21 那次审查留下的，P37–P62 之后**已经整体右移**，按号去找会找错——
  要动的时候先用 `grep -n "^func "` 重新对一遍。


### C9 · `balance.gd` 体量 —— 低（**已获授权，已落两刀：P69 + P70**）
1637 行里约 60% 是纯 UI 度量（HUD/menu/garden/almanac/tile），与平衡数值混在一处。
可拆 `balance_ui.gd`；但"数值集中在 balance.gd"是既有约定（AGENTS §2），**动前先征求同意**。
> **2026-09-24 更新（两条都已成立）**：① 第一步已经做了——`balance_ui.gd` 存在（现量 **797 行**），
> 归属规则"谁读它"也写进了 AGENTS §2；② **同意已经拿到**（用户原话：`balance.gd 可以进一步拆分，
> 可以修改 §2 约定`），§2 已随之补一条"按读者分组、`balance.gd` 不反向引用新表、每个常量唯一归属"
> 的例外。本条因此**不再是"待确认"，而是待做**：`balance.gd` 现量 **2326 行**（比审查当时还长，
> 因为 P26 之后又不断往里加规则常量），排为 **P69**。
> **✅ 2026-09-24 第一刀已落地（P69），本条**留开**。** 切走的是**音频**那一族：
> `MUSIC_DEFS`（29 首）+ `SFX_DEFS`（21 个 cue）+ 音量阶梯 / 淡入淡出 = **25 个常量 + 16 个读取函数**，
> 整块搬进 `scripts/balance/balance_audio.gd`（`class_name BalanceAudio`，**308 行**）；
> `balance.gd` **2326 → 2050 行**。11 个读取方、93 处引用改名，`Balance.` 后接 music/sfx 现在是 **0**。
> 选音频当第一刀**不是因为它最大**（植物卡那 394 行更长），而是因为它**读者最纯**：
> 那两个播放器 + 点名的画面 + 存音量的存档，是同一族读者，所以可以纯搬运。
> 剩下四组候选（美术路径 `:323–550` / 植物卡 `:915–1308` / 道具+商店+图鉴 `:1691–2216` / 花园 `:2217–2326`）
> 的读者都**跨族**，下一刀要先回答"这个名字归谁读"，别按行数切。判据在 `docs/history/03-p37-p82-batches.md` §5.26。
> **✅ 2026-09-24 第二刀已落地（P70），本条仍**留开**。** 这次先做的是**普查**、不是搬运：
> 对上面那四组逐个 `grep` 读者，结果写在 `docs/history/03-p37-p82-batches.md` §1 的 P70 第 3 条那张表里。
> 美术那一组**搬不动整块，但里面藏着一个纯子族**——把 view **摆**在草地上的三个数
> （`VIEW_ART_CANVAS` / `VIEW_ART_FEET_LINE` / `VIEW_IDLE_ANIMATION`）与药剂标记的**几何**三个数
> （`POTION_ART_CANVAS` / `POTION_MARK_AREA` / `POTION_MARK_SCALE`）**只被 `unit_art.gd` 读**
> （15 处 / 1 个文件），于是整块搬进 `balance_ui.gd`：`balance.gd` **2050 → 2027**、
> `balance_ui.gd` **809 → 853**。留下的部分各有各的跨族证据：`plant_view()` 10 处 / **9** 个文件、
> `item_art()` **8 处 / 4 个文件**（再加只有 1 个读者的 `item_art_paths()`，两个函数合计 9 处）、
> `POTION_TIER_PATHS` 是"用哪个瓶子"的
> 数据答案、`GARDEN_*` 53 处 / 6 个文件（**绘制那一半早在 P25 / P28-UI 就搬走了**）。
> ⇒ **剩下三组没有一组可以纯搬运**；下一刀要的是"把一个名字拆成两个读者"的**设计点单**，不在 C9 里顺手做。
> **📋 2026-09-24 第三刀已普查完、**未执行**（卡在 P69 那次扫描，不是卡在设计）**：
> 把剩下的规则块也照第 ① 条数了一遍读者，结果分三堆。
> - **可以直接搬的 7 个（11 处、4 个文件）**：`COLOR_TOOL_TARGET` / `COLOR_TOOL_TARGET_LINE` /
>   `COLOR_TOOL_SOURCE`（只有 `grid.gd:428-445` 画高亮框时读，5 处）、`COLOR_TOOL_READY`（只有 `hud.gd`，3 处）、
>   `GARDEN_TICK`（只有 `garden/garden.gd:508`，1 处）、`STACK_OFFSET_STEP` / `STACK_OFFSET_MAX_INDEX`
>   （只有 `unit.gd:297-298` 的 `_stack_offset()`，2 处；那个函数按 HANDOFF §7.9 是**纯视觉量**，
>   从不碰 col/row/hp/ap）。⇒ 这一堆是 P71 的完整范围，**不需要任何决定**，只等能验收。
> - **两条"规则说可以、但搬了会更糟"的反例**（已回写进 AGENTS §2 那条例外）：
>   ① **一个字典的两列属于不同读者**——`TOOL_DEFS` 里 `threshold` 是规则、`color` 是绘制，
>   而 `hud.gd:357` 是**整包取走** `BalanceBattle.TOOL_DEFS[key]`；同一形状的还有道具图标那一块——
>   `ART_ICON_SILVER` / `_GOLD` / `_DIAMOND` / `_BEAN` / `_SCROLL` 这五个**外部零读者**，
>   它们只是 `ITEM_ART` 这张表的列（`balance.gd:463-472`）。拆开等于把一张表劈成两半，两边都得改。
>   （剩下三个 `ART_ICON_SUN`（`hud.gd:938`）/ `_FERTILIZER` / `_EXP_POTION`（`garden/garden.gd:805/807`）
>   各只有 **1 处**绘制侧读取，纯度其实够——但它们和上面那五个是同一段注释里的同一块，
>   搬三个留五个会让那段话两头都不完整，所以**也不进 P71**，宁可整块留着。）
>   ② **一对必须同长的孪生数组**——`DECK_HOTKEY_KEYS`（`game_manager.gd:3632` 数按键）与
>   `DECK_HOTKEY_LABELS`（`hud.gd:316-318` 画角标，且**用它自己的 `size()` 当下标上界**）。
>   KEYS 归规则、LABELS 归绘制，按规则该分家——可一分家，"按键表和角标表悄悄错开"就再也数不清了。
>   ⇒ 这两处**保持原样**，别在下一轮"顺手补完"。
> - **剩下三组的账没变**：植物卡那 394 行的核心 `PLANT_CARDS` 实测 **20+ 处 / 9 个文件**
>   （`game_manager` 8、`hud` 3、自检 3、`plant_db` 2、`garden` / `item_db` / `level_data` / `run_flow` / `screen_flow` 各 1；
>   `plant_scripts.gd` 那两处是**注释**，没算进来）——
>   它是"哪些植物能打"这条**规则**本身，P69 当年那句判断到此**已被实测坐实**。

> **✅ 2026-09-27 第四刀已落地（P108），本条仍**留开**。** 这一次的问题不是"这一段是谁的"，而是
> "**这一块是哪个场景的**"（用户当场的话：*一些场景单独相关的常量不再编辑在 balance.gd 中，提取并
> 编写在对应的文件中；代码的组织关系是按功能进行解耦和组合*）。判据还是"谁读它"，只是先把读者
> 聚成一个**场景**再搬：一场战斗（`core/battle/battle.gd` + `game_manager` + `unit` + 棋盘 +
> `units/**` + `hud`）、花园、战役、商店。四张新表合计 **110 个名字**（战斗 46+4 / 花园 18 / 战役 15 / 商店 27）：
> - `scripts/balance/balance_battle.gd`（`BalanceBattle`，315 行）：经济（`START_SUN` … `BRAIN_MAX_HP`）、
>   回合引擎（`WAVE_TABLE` / `ZOMBIE_SPAWN_COLS` / `FAST_FORWARD_ROUNDS` / `MESSAGE_DURATION` …）、
>   AP 引擎（`ROUND_AP` / 每个 `ZOMBIE_*_COST` / `BITE_DAMAGE_RATIO` / `SKILL_AP_COST`）、
>   大招（`ULT_CHARGE_*` / `ULTIMATE_VALUE`）、牌轨与工具（`BATTLE_DECK_SLOTS` / `SUMMONS_PER_TURN` /
>   `TOOL_*` / `TOOL_DEFS` / 热键表 / `RETREAT_CONFIRM_TIME`）；
> - `scripts/balance/balance_garden.gd`（`BalanceGarden`，74 行）：`GARDEN_PATH` / `GARDEN_VERSION` /
>   `GARDEN_PAGE_*` / `GARDEN_COLS` / `GARDEN_ROWS` / 起始花名册 / 浇水与施肥比 / 三个状态 / 四个工具 id；
> - `scripts/balance/balance_run.gd`（`BalanceRun`，70 行）：`data/adventure` 的三个路径 / `user://run.json` /
>   队位 / 重试费 / 三档奖励池 / `RUN_MOD_KEYS`；
> - `scripts/balance/balance_shop.gd`（`BalanceShop`，128 行）：26 个 `SHOP_PRICE_*` + `SHOP_STOCK`。
> **唯一的判断题是"两个函数跟着表走"**：`skill_ap_cost()` 与 `plant_ult_value()` 读的正是搬走的那两张
> 兜底表，留在 `balance.gd` 就会让 `Balance` 反向引用新表（AGENTS §2 ②）——**规则②优先于"函数按主题归类"**。
> 另外三个 accessor（`plant_skill_code` / `plant_ult_code` / `plant_ult_charge`）读的是**表列**，留在原处。
> **三条账**：① `balance.gd` **2139 → 1635 行**；② 引用改名 **289 处 / 39 个文件**，
> `Balance.` 后接这 110 个名字现在 = **0**；③ `[Arch]` 的 `TABLES` **3 → 7 张**（第 4 条判据因此继续
> 覆盖新表，实测同名常量 **0**）。
> **依赖方向没变**：`balance.gd` 里对新表的引用**只在注释里**（代码 0 处）；反向只有设计要的那两处——
> `BalanceRun` 的两个奖池与 `BalanceShop.SHOP_STOCK` 用 `Balance.ITEM_*` 的 id，所以它们**读 Balance**，不成环。
> **有意没搬的**：`PULT_SPLASH_RATIO`（一株植物自己的机制）、`ITEM_ART` / `ART_ICON_*`（P70 已判过的一段整块）、
> `PROFILE_PATH`（跨场景存档）、rarity与恢复（读者是 `rarity.csv` 那一族）、`LEVEL_DIR` / `SETTINGS_PATH`（每个场景都读）。



### C10 · "这一下点下去没成"31 处各写各的 —— 中 —— ✅ 已由 P55 清掉（清单里没有这一条）
> 这条**不是 2026-09-21 那次审查发现的**，是 P50（音效层）想给"操作被拒"挂一声时撞出来的：
> 结论是"缺的不是音频而是漏斗"，当时记进 `docs/history/03-p37-p82-batches.md` §1 的 P40 账上，P55 才做掉。
> 放在这里是为了让下一轮审查这份清单的人知道：**这件事已经做完了，别照着旧行号再找**。

- 症状：`_set_message(拒绝理由)` + `return` 这一对在 `game_manager.gd` 里有 **31 份**，
  分布在 11 个入口（`select_plant` / `select_tool` / `try_place_at` / `_use_tool_at` /
  三个 `_apply_*` 工具 / `arm_energy_bean` / `_apply_energy_bean` / `buy` / `end_turn`）。
  代价不是"啰嗦"，是**任何一次跨切面的改动都要做 31 遍**：P50 要加一声、
  将来要加"拒绝时的轻微抖动"或"教学提示"都要 31 遍，而每一遍都是一个会漏的地方。
- ✅ **落地形状**：`_refuse(text)` = `_set_message(text)` + `SFX.play("refused")`（`game_manager.gd:3599`）。
  **只有 31 处被收**，另外 22 个消息点**刻意没动**：它们分别是"事办成了 / 取消 / 征求二次确认 /
  与玩家点击无关"——给这些响一声"不"，比不响更糟。四类分账在 `docs/history/03-p37-p82-batches.md` §1 的 P55 一节。
- 自查 grep（两条要一起看，只数第一条看不出"有没有把成功也收进来"）：
  `_refuse(` 应命中 **32**（31 调用 + 1 定义）、`_set_message(` 应命中 **25**
  （22 个非拒绝站点 + 定义 + `_refuse` 内那一行 + 注释里那一行）。
- **两条故意留在漏斗外**，别当漏网之鱼补掉：`end_turn` 的 `_resolving` 守卫（同一帧重复点击是程序
  自己撞自己，响给玩家听等于指责他）与 `_report_window_mode()` 那句 `[Settings] ... REFUSED`
  （print-only、且在编辑器和无头里天天触发）。
- `_refuse()` **不打印日志**：它说的话是 `Loc` 本地化的，而 §2 定死"日志永远英文"。

---

## D. 数据层细节

- **D1 · 僵尸被装配两次 —— 中**：`scripts/units/zombie.gd:58,88` `_init` 里跑一遍
  `apply_type(BASE_ID,...)`（含 `_load_art` / `set_view_path`），生成时
  `game_manager.gd:2163` 再跑一遍真实名称；视图场景可能刚 `instantiate` 就被 `_drop_view`。
  → `_init` 不做数据装配，名称由 spawn 传入。
  → ✅ **顺序已经倒过来（2026-09-24，P60），但没有照原处方做**——`_init` 那次装配**故意留着**。
  这条审计的三句账逐句对：① "**视图场景可能刚 `instantiate` 就被 `_drop_view`**" —— 这一半
  **P28 当时就堵住了**：`set_view_path` 只在 `is_inside_tree()` 时才 `_load_view()`，
  off-board 从来没有实例化过场景，所以这句 today 已经不成立（本批把它当成**规则的样子**抄了一遍）。
  ② "（含 `_load_art`）" —— 本批补上这条规则的**另一半**：`apply_type` 现在同样只在场上单位身上
  才 `_load_art()`，off-board 交给 `Unit.place()`。贴图自 P38 起有缓存，所以这一刀省的**不是 IO**，
  是"先穿上基础僵尸的皮、下一行再脱掉"这个**状态**。③ "→ 名称由 spawn 传入" ——
  `GameManager.spawn_zombie(type, col, row)` 现在是**僵尸到场的唯一一道门**（波次 `_place_zombie`
  与舞王 `summon_children` 原本各抄七行、且**先上场后定型**，如今两处都问它，`type` 在身体被棋盘
  看见之前就定了）。为什么不走" `_init` 不装配"：开局自检有 **49 处** `spawn_unit(ZOMBIE_SCRIPT, …)`
  要的是"**随便一个僵尸**"（不该被迫点名），而"**当场改型**"正是破甲降级 `_become_base()` 的运行期
  路径——删掉 `_init` 那次装配等于给那 49 处各补一行，和 C4 那笔"98 处引用 ⇒ 单独一批"是同一种账。
  细节见 `docs/history/03-p37-p82-batches.md` §1 的 P60 一节、判据 §5.17。
- **D2 · 数字单元格写错静默变默认值 —— 中**：`unit_csv.gd:119-129` 容错是好的（不崩），
  但 `hp="三百"` 这类错误无痕迹。→ 统计 bad-cell 数供 self_check 打印。
  另 `:63-69` header 重名列静默覆盖，应计入 problems。
  → ✅ **两半都已由 P57 清掉（2026-09-24）**：`UnitCsv` 现在只有一条抱怨通道
  （`note_complaint()` 写、`report_complaints()` 打印并清空、按文本去重、每块最多 12 行），
  两种来源都接了进去：**数字格子写了字但解析不出来**（连同"读成了哪个默认值 / 哪一行"一起报），
  以及**同一表头名拼两次**（并说明右边那份赢）。`[Plants]` / `[Zombies]` / `[Skills]` /
  `[Items]` 四块 self-check 各自 `ok = ok and UnitCsvManager.report_complaints(...)` 收尾，
  所以"有抱怨"就是那块 **FAIL**，不再只是打印。**行为一字未改**（照样回默认值），只是不再无声。
  实测四张表 0 抱怨；"规则确实会响"由 `tools/sheet_complaint_probe.gd` 故意喂坏格子证明
  （P56 那条"绿不等于对"的教训反向用了一遍）。细节见 `docs/history/03-p37-p82-batches.md` §1 的 P57 一节、判据 §5.14。
  **D2 没覆盖的那一半**：现在仍分不开"**整列不存在**"和"格子空着（`—`）"——两者都是合法的默认值，
  要区分得先有一份"必填列清单"，并决定它归谁拥有（表？`UnitSheet`？`Balance`？），这是另一个决定。
- **D3 · `difficulty.gd:34-38` + `game_manager.gd:827-828` —— 中**：~~`preset()` 每次深拷贝字典，
  取值用无默认中括号 `float(diff["sun_mult"])`（`:2085` 另一处却用 `.get(...,1.0)`），拼错即运行期崩。
  → 名称化字段。~~
  → ✅ **已由 P81 清掉，而这一条只说出了一半的症状（2026-09-24）**：那两处**行号已经过期**
  （真实现场是 `_start_new_game()` 的折叠与那条经济日志，以及 `zombie_hp_for()`/`zombie_armor_for()`），
  更要紧的是"拼错即崩"不是最坏的那一份。同一个问题——"一个没人拼对的键答什么"——在**同一局战斗里**
  有两份答案：折叠那一份 `float(diff["sun_mult"])` 会崩，`zombie_hp_for()` 那一份
  `float(diff.get("zombie_hp_mult", 1.0))` **永远不报错**。而后者更糟：`1.0` 恰好就是
  `PRESETS["normal"].zombie_hp_mult`，所以那个兜底值**从来没有机会被证伪**——它是第二个业主，
  而不是一个错误。三件事随之落地：
  ① **表格不再以字典外流**——`preset()` 收成私有 `_preset()`（GDScript 无法强制私有，真正守住它的是
  下面这条：外面再没有"要一整行"的读者），并去掉 `duplicate(true)`（调用方可改的副本 = 又一处数字的家）；
  三个**带名称的取值函数** `zombie_hp_mult()`/`sun_mult()`/`start_sun_bonus()` 各自只答一个数。
  ② **`GameManager` 只留一个字段**：`difficulty_zombie_hp_mult: float`——它是唯一活得过关卡开始的数，
  另两个收成局部变量（P80"没有读者就不留字段"的反向应用），字段初始化直接读
  `Difficulty.zombie_hp_mult(Difficulty.DEFAULT_KEY)` 而不是裸 `1.0`。
  ③ **本条没列出的那半个业主**是这轮顺手查出来的：**mod 的键名**曾有三份各自拼写——
  `BalanceRun.RUN_MOD_KEYS`（`RunState.add_mod` 实际强制的那张白名单）、折叠里的裸字符串、
  `data/adventure/events.json` 的 `"effects": "mod=sun_mult:1.15"`。改其中一处 ⇒
  "mod 被发出、被存档、被 `mods_text()` 打印，**但在战斗里什么都不改**"，仍然静默。
  现在折叠和启动判据共用 `Difficulty.*_KEY` 那三个常量，`[Diff]` 第三条红线钉住两边等长。
  另有第四处收成 `Difficulty.DEFAULT_KEY`：字面量 `"normal"` 原本拼了 7 遍
  （`difficulty.gd` 内部 3 遍 + `LevelData.difficulty_key` 两处 + `GameManager.difficulty_key` +
  `almanac/almanac.gd` 的 `.get` 默认值）；`level_list.gd` 里 `"hard"`/`"normal"` 那两个**探针期望值**
  故意留成字面量——换成常量就把断言写成了同义反复。
  判据与反向验证（故意改坏一格 `PRESETS.easy`，看它红**且不给 SCRIPT ERROR**）见
  `docs/history/03-p37-p82-batches.md` §1 的 P81 一节、判据 §5.38。
- **D4 · 死代码/死常量 —— 低**：~~`balance.gd:79,97,717-718`（`PEASHOOTER_DAMAGE`、`ZOMBIE_SPAWN_COL`
  ——真正在用的是 `ZOMBIE_SPAWN_COLS`——`ROW_LABEL_SCROLLS/_TOOLS`）全工程无引用；
  `level_data.gd:67,107` `reward_items` 自陈 "no longer used" 且无人读取；
  `plant_db.gd:206`、`zombie_db.gd:244,260` `text == "—"` 是死分支（`UnitCsvManager.cell()` 已把占位符
  归一为 `""`，且 `—` 与 `-`/`n/a` 规则不一致）；`level_data.gd:70` `hammer_dmg=9999` 与
  `apply_defaults()` 的 `BalanceBattle.HAMMER_DAMAGE` 不一致，`:597` 与 `:170` 重复 clamp。~~
  → ✅ **四步已由 P80 清掉，第五步（`ROW_LABEL_*`）是这张表自己写错的一列（2026-09-24）**：
  ① **空白格子收成一个业主**——新增 `UnitCsvManager.is_blank()`（`unit_csv.gd:172`），8 处判断全部走它
  （`cell()` / `int_of()` / `rate_of()` + 四条路径规则 `plant_db.gd` `svg_path`/`scene_path`、
  `zombie_db.gd` 同两条、`item_db.gd` `svg_path`）。原来那四处是**更窄的规则**（只认 `—`），
  于是同一张表回答两个问题：一格写 `-`，对 `cell()` 是"没说话"、对 `svg_path()` 是**一个文件名**。
  ② 三份"一条规则一个业主"各留一行启动判据：`[Plants]` / `[Zombies]` / `[Items]`
  各打印"五种记号都答'没有贴图'，而拼出来的格子仍然建路径"——**控制组用各自文件的常量拼**，
  所以路径规则一改它就红。`[Items]` 只有一条路径规则，于是只断言一条（不假装和另两块一样）。
  ③ 删掉两个真没人读的兜底：`PEASHOOTER_DAMAGE`、`ZOMBIE_SPAWN_COL`（在用的是复数
  `ZOMBIE_SPAWN_COLS`，它首元素本来就是 6 —— 单数那份是"同一列的第二个拼法"，
  还住在承诺"这些是基础僵尸各自的兜底"的那个块里）。同块的 `PEASHOOTER_HP/COST`、
  `SUNFLOWER_*`、`ZOMBIE_HP/BITE/ADVANCE/BRAIN` **都在被读**（`balance.gd` 自己的 `PLANT_DEFS`
  两条 peashooter 条目、`plant_attr_hp()` 的默认值，以及 `zombie_db.gd`、`zombie.gd`、`game_manager.gd`），
  没跟着删——**"这块看起来像兜底"不等于"这块没人读"**。
  ④ `reward_items` 删（`level_data.gd` 字段 + `apply_defaults()` 各一处）。它的注释说
  "kept for old files"，而**没有任何解析路径写过它**，所以老文件的键本来就已被忽略——
  那句注释是它唯一的遗言。锤子伤害的数字归一：字段初始化改读 `BalanceBattle.HAMMER_DAMAGE`
  （两份 9999 今天恰好相等，而解析路径总会覆盖字面量，所以它**从来没机会露出症状**——
  这正是它能活到现在的原因），并删掉 `_parse_stats` 里与 `hammer_damage()` 重复的那层 clamp：
  同块另外三个数（`initial_sun`/`brain_hp`/`zombie_hp`）是被**裸读**的，clamp 是它们唯一的地板；
  锤子只有 getter 一个读者，所以留 getter、去 parse。**行为一字未改**（`0` 与负数照旧答 1），
  只是现在"地板"和"文件说了什么"分得开。判据 = `[SelfCheck] the hammer number has one owner,
  and its floor has one place`。
  ⑤ **`ROW_LABEL_SCROLLS/_TOOLS` 不该列进 D4**：它们确实无引用，但 `balance_ui.gd:180` 的
  `[P20]` 注释写明了是**有意保留的参考措辞**（真正的行标签走 `LocUi`，因为英文常量跟不上语言），
  并交代"若要再显示，显示 Loc 那份、别为同样的词加第二个键"。删常量等于把那条注释的指着的东西拆了。
  **本条不动。**
  **顺带一条别处要改的（未动）**：`docs/history/01-p00-p27-handoff.md:2473` 仍把 `LevelData.reward_items` 与
  `reward_plant` 并列成"通关奖励"三个字段——`reward_items` 本轮已删，`reward_plant`
  **在代码里根本不存在**（只有 `rewards[]` 里的 `"plant"`）。§6 规定 HANDOFF 默认不改，等点单。
- **D5 · `layout.gd:205-246` —— 低**：~~`compute_for()` 返回无名称 Dictionary，`_apply()/_audit()`
  靠字符串键取值，打错键即崩。→ 显式内部类或 typed 字段。~~
  → ✅ **已由 P82 清掉，而这一条只写了症状的一半（2026-09-24）**："打错键即崩"是第一种坏法，
  更该修的是第二种——**一个没有任何读者要过的键，在这份字典里存在与否完全不可见**。
  于是"多一个没人用的值"和"少一个本该复制出来的值"这两种事故，日志都一个字不多说。
  `compute_for() -> Geometry`（内部类，**不带** `class_name`）：20 个字段**全部声明在哨兵上**
  （float/Vector2/Rect2 取 `NAN`、唯一的 int `card_rows` 取 `UNSET_INT := -1`，因为它不可能为负），
  `_apply()` 复制 17 个，`play`/`lawn_size`/`card_rows` 故意不复制——那三个是审计自己要用的中间事实，
  **而这正是旧字典说不出来的那句话**。`unset_fields()` 走 `get_property_list()` 枚举声明字段
  （不是手写名单：P81 刚清掉的就是"手工镜像的名单 = 第二个主人"），任何没有哨兵形状的名称直接进报告；
  `_audit()` 把它排在**所有几何断言之前**，因为其余判据读的都是**一对数**，
  一个没人算过的值可能落在 `EPSILON = 0.5` 容差里看起来没问题。
  注意上名称**本身会引入**新的坏法（`var x := 0.0` 伪装成"算过了"），所以哨兵不是可选的；
  而被否掉的替代方案是给个别字段补下限断言——那是一户一钉，哨兵加这道门是二十户一次。
  判据与反向验证（删掉三个赋值，六档采样各报三行 `was never derived` 而**没有任何几何断言跟着响**）
  见 `docs/history/03-p37-p82-batches.md` §1 的 P82 一节、判据 §5.39。
- **D6 · `garden.gd` 三则 —— 中**：① `:394-399` `slot_at()` 返回活字典且被 6 个外部方法直接写
  （`s["hp"]=...`），花名册无不变式 → 提供 `mutate_slot()`/写回 API；
  ② `:641-644,733,758,781,814-822` self_check 把 60/90/78/150/... 写成字面量、注释却说"数值来自 Balance"，
  改表即假 FAIL → 期望值从 `Balance.recovery_seconds`/`plant_attr_hp` 推导；
  ③ `:1876-1886`（game_manager 侧）同一 slot 连查 `slot_at()` 4 次、`:200-219` 每次构 `used` 字典。
- **D7 · `Loc` key 拼接 —— 低**：`difficulty.gd:46`、`zombie.gd:52`、`game_manager.gd:1349`
  用 `"difficulty." + k` 拼 key，与 `game_manager.gd:326` 自己注释的"禁止拼接"冲突（自检扫不到拼出来的 key）。
- **D8 · 豌豆每回合多次全表扫描 —— 中**：`peashooter.gd:39,51,62` `has_target()`→`find_target()`
  →`act()`/`resolve_skill_once()` 各扫一遍 units，`_do_plant_action` 每株 2-3 次 O(n)。
  单位量小暂不痛，但回合开始算一次 lane 目标缓存即可消除。

---

## E. 小清理（随改动顺手带上）

- 魔法数字：`hud.gd:754,865`（`*0.6`、`-3`）、`garden/garden.gd:897,902,372`（28.0/22.0/-3.0）、
  `almanac/almanac.gd:845,900`（96.0/60.0）、`item_screen.gd:236`（-26.0）、`item_tile.gd:136,143,153`
  （-3.0/-4.0）、`wallnut.gd:16`（`threshold=0` 硬编码）、`spikerock_view.gd:23-27`
  （`Vector2(0,-100)`，且中文注释违反 AGENTS §2 + 注释掉的死代码）。
- `unit.gd:16` `var game = null` 无名称 → 失去静态检查（`hud.gd:800` 还为此写了 workaround）。
- `unit.gd:99-108` vs `zombie.gd:75-77`：`art_path`/`_art_tried` 必须子类手工成对重置（`_view_tried` 就漏在外面）
  → `Unit.set_art_path()`；`unit.gd:137` 用 `free()`、`:174` 用 `queue_free()`，风格不一。
- `game_manager.gd:244-251,272`：`vp.size_changed` 连接后从不 disconnect。
- `sunflower.gd:43,48`、`zombie.gd:280,288`：直接读 `game.sun`/`game.brain_hp`
  （写走 `add_sun`/`damage_brain`）→ 补只读接口统一。
- `game_manager.gd:1476`：文档注释挤在函数签名同一行。
- `menu.gd:211-223`：`_process` 每帧轮询 `is_reset_armed()` + `Loc.t`，可 0.2s 节流。
- `hud.gd:187,294,307,340`：战斗期按钮全部 `FOCUS_NONE`，键盘/手柄无法操作（menu、garden 均 `FOCUS_ALL`），
  体验不一致——是设计选择的话至少在文档里记一笔。

## 做得好的地方（不必动）

- 启动 IO 集中：三张 CSV + settings/garden/profile JSON 在 `game_manager.gd:163-179` 一次性读入，
  `_tried` 防重复，R 键才热重载。
- 抽查 plants.csv / zombies.csv 若干行，CSV 值与 `balance.gd` 兜底常量**未漂移**，且自检有
  "overrides Balance" 报告机制。
- 语言层：zh/en 条数一致（212/148），UI 代码未发现绕过 `Loc` 的硬编码中文；
  `loc.gd:148-175` 自检会审计 `%` 占位符数量。
- 信号连接未发现泄漏或重复 connect；`item_tile`/ItemGrid 的格子池复用是正确做法。
- 存档保存时机健康：全部事件驱动，无每帧写盘。

## 本轮已核实为**误报**的两条（不要再照着"修"）

1. ~~`garden/garden.gd:1134` 花盆命中坐标系错误~~ —— 已核实：`GardenPlot` 是页面直接子节点
   （`:497` `add_child`），`_layout()` 在 `:888-891` 设置 `plot.position/size`，
   `Control.get_rect()` 含 position，与 `get_local_mouse_position()` 同坐标系，**判定正确**。
2. ~~`balance.gd` 同一兜底值三处字面量重复~~ —— 已核实：`:439,498,552` 均引用常量
   `PEASHOOTER_HP`（`:77`），并非字面量三份。
