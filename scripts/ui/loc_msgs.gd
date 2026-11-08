class_name LocMsgs
extends RefCounted
## [P20] BATTLE MESSAGES + panels: everything the HUD message line, the backpack
## panel and the result panel say. One row per key, both variants always filled.
##
## Key shape is "msg.<area>.<thing>", e.g. "msg.shovel.dug", "msg.card.cooling",
## "panel.result.rounds". Format strings keep the same %-specifiers in both
## variants (Loc.self_check fails the run when they differ).
##
## The wording is deliberately SHORT: most of these are drawn on ONE HUD line, so
## the Chinese aims at roughly the visual length of the English it replaces.

const TABLE := {
	# ------------------------------------------------------------ tool state
	## "Shovel 1/2 READY" - the action-bar readout (Game.tools_state_text).
	"msg.tool.ready": {"zh": "就绪", "en": "READY"},
	"msg.tool.charging": {"zh": "充能中", "en": "charging"},
	"msg.tool.state": {"zh": "%s %d/%d %s", "en": "%s %d/%d %s"},
	"msg.tool.operation_only": {
		"zh": "道具只能在操作阶段使用",
		"en": "Tools can only be used during the operation phase",
	},
	"msg.tool.deselected": {"zh": "已取消选择道具", "en": "Tool deselected"},
	"msg.tool.still_charging": {
		"zh": "%s 仍在充能（%d/%d）",
		"en": "%s is still charging (%d/%d)",
	},

	# ------------------------------------------------------------ tool prompts
	## Game.tool_prompt(): what the message line says once a tool is armed.
	"msg.prompt.shovel": {
		"zh": "铲子就绪 - 点击有植物的格子把它铲掉",
		"en": "SHOVEL ready - click a cell containing a plant to dig it up",
	},
	"msg.prompt.glove_pick": {
		"zh": "手套就绪 - 点击要搬动的植物",
		"en": "GLOVE ready - click the plant you want to move",
	},
	"msg.prompt.glove_drop": {
		"zh": "手套 - 现在点击一个空闲的可用格子放下它",
		"en": "GLOVE - now click an empty active cell to drop it there",
	},
	"msg.prompt.hammer": {
		"zh": "锤子就绪 - 点击有僵尸的格子（%d 点伤害）",
		"en": "HAMMER ready - click a cell containing zombies (%d damage)",
	},

	# ------------------------------------------------------------ shovel / glove / hammer
	"msg.shovel.none": {
		"zh": "铲子：(%d,%d) 没有植物 - 冷却不会被消耗",
		"en": "SHOVEL: no plant at (%d,%d) - cooldown NOT consumed",
	},
	"msg.shovel.note_home": {
		"zh": "（花园槽位 %d 存活回家）",
		"en": " - garden slot %d goes home alive",
	},
	"msg.shovel.dug": {"zh": "铲子：%s 已被铲除%s", "en": "SHOVEL: %s dug up%s"},

	"msg.glove.none": {
		"zh": "手套：(%d,%d) 没有植物 - 点击植物把它拿起",
		"en": "GLOVE: no plant at (%d,%d) - click a plant to pick it up",
	},
	"msg.glove.picked": {
		"zh": "手套：%s 在 (%d,%d) 已拿起 - 现在点击一个空闲的可用格子",
		"en": "GLOVE: %s at (%d,%d) picked - now click an empty active cell",
	},
	"msg.glove.same_cell": {
		"zh": "手套：目标格就是原来那格",
		"en": "GLOVE: destination is the same cell",
	},
	"msg.glove.row_inactive": {
		"zh": "手套：第 %d 行不在本关战场（本关启用行：%s）",
		"en": "GLOVE: row %d is not in this battle (rows %s)",
	},
	"msg.glove.occupied": {
		"zh": "手套：格子 (%d,%d) 已被占用",
		"en": "GLOVE: cell (%d,%d) is occupied",
	},
	"msg.glove.gone": {"zh": "手套：拿起的植物已经不在了", "en": "GLOVE: the picked plant is gone"},
	"msg.glove.moved": {
		"zh": "手套：%s 已移动到 (%d,%d)",
		"en": "GLOVE: %s moved to (%d,%d)",
	},

	"msg.hammer.none": {
		"zh": "锤子：(%d,%d) 没有僵尸 - 冷却不会被消耗",
		"en": "HAMMER: no zombies at (%d,%d) - cooldown NOT consumed",
	},
	"msg.hammer.smashed": {"zh": "锤子：砸中 %d 只僵尸", "en": "HAMMER: %d zombie(s) smashed"},

	# ------------------------------------------------------------ board refusals
	## Short lines shared by the tool path and the summon path.
	"msg.phase.not_operation": {"zh": "不在操作阶段", "en": "Not the operation phase"},
	"msg.turn.end_operation_only": {
		"zh": "只能在操作阶段结束回合",
		"en": "You can only end the turn during the operation phase",
	},
	"msg.cell.outside": {"zh": "在草坪之外", "en": "Outside the lawn"},
	"msg.cell.row_inactive": {
		"zh": "第 %d 行不在本关战场（本关启用行：%s）",
		"en": "Row %d is not in this battle (rows %s)",
	},
	"msg.cell.occupied": {"zh": "格子 (%d,%d) 已被占用", "en": "Cell (%d,%d) is occupied"},
	"msg.sun.not_enough": {"zh": "阳光不足：%d < %d", "en": "Not enough sun: %d < %d"},

	# ------------------------------------------------------------ plant cards
	"msg.card.ready": {"zh": "就绪", "en": "READY"},
	"msg.card.cooling": {"zh": "冷却中", "en": "cooling"},
	"msg.card.state": {"zh": "%s %d/%d %s，可用 %d", "en": "%s %d/%d %s, %d free"},
	"msg.card.operation_only": {
		"zh": "卡牌只能在操作阶段使用",
		"en": "Cards can only be used during the operation phase",
	},
	"msg.card.pick_first": {"zh": "先选一张植物卡", "en": "Pick a plant card first"},
	"msg.card.no_scroll": {
		"zh": "仓库里没有 %s 卷轴 - 这张卡尚未解锁",
		"en": "No %s Scroll in the warehouse - that card is not unlocked yet",
	},
	## [P32] the deck gate: the card is unlocked, just not on this battle's deck
	"msg.card.not_in_deck": {
		"zh": "%s 不在本局卡组中",
		"en": "%s is not in this battle's deck",
	},
	"msg.card.no_summon_left": {
		"zh": "本回合召唤卷轴用完（每回合 %d 个）- 结束回合即可恢复",
		"en": "No summon scroll left this round (%d per round) - END TURN to get it back",
	},
	"msg.card.cooling_down": {
		"zh": "%s 仍在冷却（%d/%d 回合）",
		"en": "%s is still cooling down (%d/%d rounds)",
	},
	"msg.card.none_free": {
		"zh": "花园里没有空闲的 %s - %s",
		"en": "No %s free in the garden - %s",
	},
	"msg.card.selected": {
		"zh": "已选中 %s - 点击一个草坪格子（花费 %d，花园可用 %d）",
		"en": "%s selected - click a lawn cell (cost %d, %d free in the garden)",
	},
	## [P31-B] spirit cards speak for themselves: no garden count to quote
	"msg.card.selected.spirit": {
		"zh": "已选中 %s - 点击一个草坪格子（花费 %d，灵界召唤不经花园）",
		"en": "%s selected - click a lawn cell (cost %d, spirit: no garden needed)",
	},
	"msg.summon.done": {
		"zh": "%s 已召唤，花费 %d（花园可用 %d，剩余 %d 个卷轴）",
		"en": "%s summoned for %d (%d free in the garden, %d scroll(s) left)",
	},
	## [P31-B] the spirit copy's summon line (no garden count)
	"msg.summon.spirit": {
		"zh": "%s 已从卷轴中召唤，花费 %d（本回合剩余 %d 个召唤）",
		"en": "%s summoned from the scroll for %d (%d summon(s) left this round)",
	},
	"msg.selection.cleared": {"zh": "已取消选择", "en": "Selection cleared"},
	"msg.selection.cleared_outside": {
		"zh": "已取消选择（点在草坪外）",
		"en": "Selection cleared (clicked outside the lawn)",
	},

	# ------------------------------------------------------------ garden
	"msg.garden.not_loaded": {"zh": "没有载入花园", "en": "no garden loaded"},
	"msg.garden.none_free": {"zh": "花园里没有空闲的 %s", "en": "No %s free in the garden"},
	"msg.garden.slot_empty": {"zh": "槽位 %d 里没有植物", "en": "There is no plant in slot %d"},
	"msg.garden.available_note": {
		"zh": "%d/%d %s 可用（%d 在草坪上，%d 已倒下）",
		"en": "%d of %d %s free (%d out on the lawn, %d downed)",
	},
	"msg.garden.state": {
		"zh": "花园        %d 株植物，%d 受伤，%d 倒下",
		"en": "GARDEN      %d plants, %d wounded, %d downed",
	},
	"msg.garden.state_none": {"zh": "花园        -", "en": "GARDEN      -"},

	# ------------------------------------------------------------ summon scrolls
	"msg.scroll.none": {"zh": "无卷轴", "en": "no scroll"},
	"msg.scroll.state": {"zh": "卷轴 %s", "en": "scroll %s"},

	# ------------------------------------------------------------ energy bean (P15)
	"msg.bean.operation_only": {
		"zh": "能量豆只能在操作阶段使用",
		"en": "Beans can only be used during the operation phase",
	},
	"msg.bean.none": {"zh": "没有能量豆了", "en": "No Energy Bean left"},
	"msg.bean.armed": {
		"zh": "能量豆已就绪 - 点击一株植物结算它的技能 %d 次",
		"en": "ENERGY BEAN armed - click a plant to resolve its skill %d times",
	},
	"msg.bean.no_plant": {
		"zh": "能量豆：(%d,%d) 没有植物 - 能量豆未被消耗",
		"en": "ENERGY BEAN: no plant at (%d,%d) - the bean was not spent",
	},
	"msg.bean.no_skill": {"zh": "能量豆：%s 没有技能", "en": "ENERGY BEAN: %s has no skill"},
	"msg.bean.idle": {
		"zh": "能量豆：%s 无事可做 - 能量豆未被消耗",
		"en": "ENERGY BEAN: %s had nothing to do - the bean was not spent",
	},
	"msg.bean.resolved": {
		"zh": "能量豆：%s 结算了技能 %d 次",
		"en": "ENERGY BEAN: %s resolved its skill %d time(s)",
	},

	# ------------------------------------------------------------ backpack panel (P15)
	"msg.pack.empty": {"zh": "- 背包是空的 -", "en": "- the backpack is empty -"},
	"msg.pack.closed": {"zh": "背包已关闭", "en": "Backpack closed"},

	# ------------------------------------------------------------ item detail lines (P22)
	## The third line of the detail panel: WHERE the item is used. The tiles and the
	## description come from the item's own hint (Balance.item_hint).
	"msg.item.use_garden": {"zh": "在花园中使用", "en": "use in the GARDEN"},
	"msg.item.use_battle": {"zh": "在战斗中使用", "en": "use in a battle"},
	"msg.item.unlocks_card": {"zh": "解锁一张卡牌", "en": "unlocks a card"},
	"msg.item.sell_warehouse": {"zh": "在仓库中出售", "en": "sell it in the WAREHOUSE"},
	"msg.item.not_in_battle": {"zh": "战斗中不可用", "en": "not usable in battle"},
	## [P95] a plant chest in the BACKPACK: it is opened in the warehouse (where the
	## button appears), so that is what the line says.
	"msg.item.open_warehouse": {"zh": "在仓库里打开", "en": "open it in the WAREHOUSE"},
	## The TYPE line of the detail panel for every non-scroll, non-coin kind.
	"msg.item.kind.battle": {"zh": "战斗道具", "en": "BATTLE ITEM"},
	"msg.item.kind.exp": {"zh": "经验", "en": "EXP"},
	"msg.item.kind.fertilizer": {"zh": "肥料", "en": "FERTILIZER"},
	"msg.item.kind.talent": {"zh": "天赋药剂", "en": "TALENT POTION"},

	# ------------------------------------------------------------ selling / buying (P22)
	## What the warehouse and shop screens report back after an action. The English
	## log lines stay in profile.gd / the [Warehouse] prints; these are the player's.
	"msg.sell.done": {"zh": "卖出 %d 个%s，得到 %d 金钱（现有 %d）",
		"en": "Sold %d x %s for %d money (money %d)"},
	"msg.sell.all_done": {"zh": "卖出全部 %d 枚钱币，得到 %d 金钱（现有 %d）",
		"en": "Sold all %d coin(s) for %d money (money %d)"},
	"msg.sell.none": {"zh": "没有可以卖的东西", "en": "Nothing to sell"},
	"msg.sell.coins_only": {"zh": "只有钱币可以在仓库里出售", "en": "Only coins can be sold in the warehouse"},
	"msg.buy.done": {"zh": "买下 %s，花费 %d（现有 %d 金钱）",
		"en": "Bought %s for %d (money %d)"},
	"msg.buy.done_plant": {"zh": "买下 %s，它已经加入花园，花费 %d（现有 %d 金钱）",
		"en": "Bought %s - it joined the garden - for %d (money %d)"},
	"msg.buy.no_profile": {"zh": "没有载入存档", "en": "No profile loaded"},

	# ------------------------------------------------------------ shop (P15)
	"msg.shop.not_enough_money": {"zh": "金钱不足：%d < %d", "en": "Not enough money: %d < %d"},
	"msg.shop.garden_full": {
		"zh": "花园已满 - 没有空的种植位了",
		"en": "The garden is full - sell nothing, it just has no free plot",
	},

	# ------------------------------------------------------------ garden consumables (P14/P15)
	"msg.potion.no_exp": {
		"zh": "仓库里没有经验药水（在商店购买）",
		"en": "No EXP Potion in the warehouse (buy one in the SHOP)",
	},
	"msg.potion.exp": {"zh": "%s +%d 经验", "en": "%s +%d exp"},
	"msg.potion.level_up": {"zh": " -> 等级 %d", "en": " -> LEVEL %d"},
	"msg.talent.no_potion": {"zh": "%s 没有天赋药水", "en": "%s has no talent potion"},
	"msg.talent.already": {
		"zh": "%s 已经有这个天赋了 - 不能叠加",
		"en": "%s already has this talent - it does not stack",
	},
	"msg.talent.none_in_stock": {
		"zh": "仓库里没有 %s（这是关卡奖励）",
		"en": "No %s in the warehouse (it is a level reward)",
	},
	"msg.fertilize.not_downed": {
		"zh": "这株植物没有倒下 - 用肥料会浪费",
		"en": "That plant is not DOWNED - fertilizer would be wasted",
	},
	"msg.fertilize.none_in_stock": {
		"zh": "仓库里没有肥料袋（植物也会自愈，免费，但只有 1/10 的生命）",
		"en": "No Fertilizer Bag in the warehouse (a plant also recovers on its own, for free, but with only 1/10 of its health)",
	},

	# ------------------------------------------------------------ floating text (P14/P15)
	## Fx popups over the lawn: the sun/kill/drop numbers the player reads there.
	"msg.popup.sun": {"zh": "+%d 阳光", "en": "+%d sun"},
	"msg.popup.silver": {"zh": "+1 银币", "en": "+1 Silver"},
	"msg.popup.fertilizer": {"zh": "+1 肥料袋", "en": "+1 Fertilizer"},
	"msg.popup.energy_bean": {"zh": "+1 能量豆", "en": "+1 Energy Bean"},
	## [P26] A zombie's armour breaking is a board event of its own: the bit that was
	## wearing it (cone / bucket / door / helmet) is gone, and the type may change with it.
	"msg.popup.armor_break": {"zh": "护甲碎了！", "en": "ARMOR BROKEN"},
	## [P39] The chomper's bite: the number that usually pops here is a damage roll, and
	## this plant rolls none (无视HP), so the word takes its place - what the player needs
	## to see is that the zombie is gone, not by how much.
	"msg.popup.chomp": {"zh": "被吞了！", "en": "DEVOURED"},
	"msg.popup.diamond": {"zh": "+1 钻石", "en": "+1 Diamond"},

	# ------------------------------------------------------------ round banner
	"msg.banner.your_turn": {"zh": "回合 %d  -  你的回合", "en": "ROUND %d  -  YOUR TURN"},
	"msg.banner.incoming": {
		"zh": "回合 %d  -  %d 只僵尸来袭",
		"en": "ROUND %d  -  %d ZOMBIE INCOMING",
	},
	## [P26] The round a wave marked "banner": true - the pack's own "一大波僵尸" marker.
	"msg.banner.big_wave": {
		"zh": "回合 %d  -  一大波僵尸正在接近！",
		"en": "ROUND %d  -  A HUGE WAVE IS APPROACHING!",
	},

	# ------------------------------------------------------------ phase + end reason
	"msg.phase.operation": {
		"zh": "操作阶段 - 种植或使用道具，然后结束回合",
		"en": "OPERATION - plant or use a tool, then END TURN",
	},
	"msg.phase.plant_action": {"zh": "植物行动", "en": "PLANT ACTION"},
	"msg.phase.zombie_action": {"zh": "僵尸行动", "en": "ZOMBIE ACTION"},
	"msg.phase.turn_start": {"zh": "回合开始", "en": "TURN START"},
	"msg.phase.turn_end": {"zh": "回合结束", "en": "TURN END"},
	"msg.phase.win": {"zh": "胜利", "en": "VICTORY"},
	"msg.phase.lose": {"zh": "失败", "en": "DEFEAT"},
	"msg.phase.boot": {"zh": "启动", "en": "BOOT"},
	## Game.end_reason: drawn under the VICTORY / DEFEAT overlay.
	"msg.end.all_cleared": {"zh": "所有波次已清除", "en": "all waves cleared"},
	"msg.end.all_cleared_tool": {
		"zh": "所有波次已清除（最后一只僵尸被道具消灭）",
		"en": "all waves cleared (last zombie killed by a tool)",
	},
	"msg.end.brain_eaten": {"zh": "大脑在 T%02d 被吃掉", "en": "brain eaten at T%02d"},

	# ------------------------------------------------------------ HUD side readouts
	"msg.level.none": {"zh": "关卡： -", "en": "LEVEL: -"},
	"msg.level.label": {"zh": "关卡 %s  （%s）", "en": "LEVEL %s  (%s)"},
	"msg.hover.none": {"zh": "悬停: -", "en": "hover: -"},
	"msg.hover.free": {"zh": "空闲", "en": "free"},
	"msg.hover.occupied": {"zh": "被占用", "en": "occupied"},
	"msg.hover.tool_target": {"zh": "道具目标", "en": "tool target"},
	"msg.hover.not_target": {"zh": "不是目标", "en": "not a target"},
	"msg.hover.placeable": {"zh": "可放置", "en": "placeable"},
	"msg.hover.blocked": {"zh": "被阻挡", "en": "blocked"},
	"msg.hover.line": {
		"zh": "悬停 (%d,%d)  %s  %s   植物 %d  僵尸 %d",
		"en": "hover (%d,%d)  %s  %s   plants %d  zombies %d",
	},
	"msg.wave.next": {"zh": "下一波 T%d（%d 只僵尸）", "en": "next wave T%d (%d zombie)"},
	"msg.wave.final": {"zh": "最后一波", "en": "final wave"},
	"msg.backpack.empty": {"zh": "空", "en": "empty"},

	# ------------------------------------------------------------ window mode readout
	## Game.display_status_text(), shown on the SETTINGS page.
	"msg.display.unknown": {"zh": "窗口模式 ?", "en": "window mode ?"},
	"msg.display.borderless": {
		"zh": "无边框回退（该合成器拒绝了真正的全屏）",
		"en": "borderless fallback (this compositor refused real fullscreen)",
	},
	"msg.display.mode": {"zh": "窗口模式 %s", "en": "window mode %s"},

	# ------------------------------------------------------------ confirm prompts
	"msg.retreat.confirm": {
		"zh": "再次点击撤退离开战斗 - 你的植物会保留伤势",
		"en": "Click RETREAT again to leave the battle - your plants keep their wounds",
	},
	"msg.reset.confirm": {
		"zh": "再次点击重置游戏将清空花园、金钱和物品",
		"en": "Click RESET GAME again to wipe your garden, money and items",
	},
	"msg.game.finished": {"zh": "游戏已结束 - 按 R 重新开始", "en": "Game is already finished - press R to restart"},
	"msg.game.fast_forward": {"zh": "快进：最多 %d 回合", "en": "fast forward: up to %d rounds"},
	"msg.debug.sun": {"zh": "调试：+%d 阳光 -> %d", "en": "debug: +%d sun -> %d"},

	# ------------------------------------------------------------ save alarm
	## [P65] OPTIMIZATIONS A3. A SUFFIX the status line carries while the last ledger
	## write was refused, so a success line written after it cannot hide the fact that
	## the change is only in RAM. Phrased as a standing state, not as an event, because
	## it stays on screen until some write lands. No placeholder in either language.
	"msg.save.alarm": {
		"zh": "  （有改动没有存进磁盘）",
		"en": "  (some changes are not on disk)",
	},

	# ------------------------------------------------------------ result panel
	"panel.result.level": {"zh": "关卡        %s   （%s）", "en": "LEVEL       %s   (%s)"},
	"panel.result.rounds": {"zh": "回合数      %d", "en": "ROUNDS      %d"},
	"panel.result.zombies": {"zh": "僵尸        %d / %d 已消灭", "en": "ZOMBIES     %d of %d killed"},
	"panel.result.sun": {"zh": "阳光        %d 剩余，%d 已用", "en": "SUN         %d left, %d spent"},
	"panel.result.brain": {"zh": "大脑        %d / %d", "en": "BRAIN       %d / %d"},
	"panel.result.tools": {
		"zh": "道具        铲子 %d，手套 %d，锤子 %d 次",
		"en": "TOOLS       shovel %d, glove %d, hammer %d uses",
	},
	"panel.result.reward": {"zh": "奖励        %s", "en": "REWARD      %s"},
	"panel.result.backpack": {"zh": "背包        %s  -> 仓库", "en": "BACKPACK    %s  -> warehouse"},
	"panel.result.money": {
		"zh": "金钱        %s   （在仓库中出售钱币）",
		"en": "MONEY       %s   (sell coins in the WAREHOUSE)",
	},

	# ------------------------------------------------------------ reward lines (P14/P15)
	"panel.reward.first_clear": {"zh": "%d x %s  （首次通关）", "en": "%d x %s  (FIRST CLEAR)"},
	## [P93] The first clear no longer pays here: it leaves a chest on the level list.
	"panel.reward.first_clear_pending": {
		"zh": "首次通关奖励已放进关卡的宝箱，回关卡列表点开它",
		"en": "first-clear reward is in the level's chest - open it from the level list",
	},
	"msg.chest.not_cleared": {"zh": "这一关还没通关", "en": "this level has not been cleared yet"},
	"msg.chest.already": {"zh": "这个宝箱已经开过了", "en": "that chest has already been opened"},
	"msg.chest.empty": {"zh": "这个宝箱是空的", "en": "that chest is empty"},
	"msg.chest.broken": {"zh": "关卡文件读不出来：%s", "en": "cannot read the level file: %s"},
	## [P95] The WAREHOUSE side of a chest: the level list's chest hands over a
	## 植物宝箱, and opening THAT is what puts the plant in the garden.
	"msg.chest.opened": {"zh": "打开%s，%s 进了花园第 %d 格",
		"en": "opened %s - %s joined garden slot %d"},
	"msg.chest.none": {"zh": "没有这个宝箱", "en": "no such chest"},
	"msg.chest.full": {"zh": "花园满了，%s 先留在仓库里",
		"en": "the garden is full - %s stays in the warehouse"},
	"panel.reward.no_luck": {"zh": "%.0f%% 的概率没中：%s", "en": "no luck on the %.0f%% roll: %s"},
	"panel.reward.item": {"zh": "%d x %s%s", "en": "%d x %s%s"},
	"panel.reward.plant": {
		"zh": "1 x %s 已加入花园（槽位 %d）%s",
		"en": "1 x %s joined the garden (slot %d)%s",
	},
	"panel.reward.garden_full": {
		"zh": "%s 掉落失败，花园已满",
		"en": "%s dropped, but the garden is full",
	},
	"panel.reward.nothing": {
		"zh": "没有（这个关卡没有配置奖励）",
		"en": "nothing (this level has no rewards configured)",
	},
	"panel.reward.none_on_lose": {"zh": "没有奖励 - 必须赢下关卡", "en": "no reward - the level has to be won"},
	"panel.reward.roll_tag": {"zh": "  (%.0f%% 概率)", "en": "  (%.0f%% roll)"},
	"panel.reward.generic": {"zh": "奖励", "en": "reward"},

	# ------------------------------------------------------------ window mode names
	## What fills the %s of "msg.display.mode". SettingsStore.mode_text() names a
	## Window.mode in English (it is also what the log prints); the SETTINGS page
	## shows the same state to the player, so the name is translated here.
	"msg.display.fullscreen": {"zh": "全屏", "en": "FULLSCREEN"},
	"msg.display.exclusive_fullscreen": {"zh": "独占全屏", "en": "EXCLUSIVE_FULLSCREEN"},
	"msg.display.maximized": {"zh": "最大化", "en": "MAXIMIZED"},
	"msg.display.minimized": {"zh": "最小化", "en": "MINIMIZED"},
	"msg.display.windowed": {"zh": "窗口化", "en": "WINDOWED"},
}
