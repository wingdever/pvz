class_name LocRun
extends RefCounted
## [P31-A] ADVENTURE RUN strings: the squad page, the roadmap, the node pages
## (event / treasure / rest), the three-stage reward and the run-end panel.
## Same rules as every other table (AGENTS.md §3): both variants always filled,
## format strings keep identical %-placeholders in the same order.

const TABLE := {
	# ------------------------------------------------------------ menu entries
	## [P93] 冒险模式 is the LEVEL LIST now (the original's adventure: one level after
	## another), so the roguelike run - which the code has always called the campaign -
	## took the campaign's own word. The spec's menu order was updated with it.
	"run.menu.adventure": {"zh": "战役模式", "en": "CAMPAIGN"},
	"run.menu.continue": {"zh": "继续战役", "en": "CONTINUE RUN"},
	"run.menu.new": {"zh": "新的战役", "en": "NEW RUN"},
	"run.menu.new_confirm": {"zh": "确认开新局？旧存档将被覆盖", "en": "START A NEW RUN? the saved run is overwritten"},
	"run.menu.levels": {"zh": "冒险模式", "en": "ADVENTURE"},
	"run.msg.no_chapter": {"zh": "没有可用的章节文件", "en": "no chapter file available"},

	# ------------------------------------------------------------ squad page
	"run.squad.title": {"zh": "编队", "en": "PICK YOUR SQUAD"},
	"run.squad.subtitle": {"zh": "已选 %d / 上限 %d", "en": "picked %d / max %d"},
	"run.squad.hint": {"zh": "点选 1~%d 株还站着的植物参战；伤势与经验照旧走花园规则", "en": "click 1-%d standing garden plants to enlist; wounds and exp still follow the garden rules"},
	"run.squad.confirm": {"zh": "出征", "en": "SET OUT"},
	"run.msg.squad_empty": {"zh": "至少选择一株植物", "en": "pick at least one plant"},
	"run.msg.squad_full": {"zh": "编队已满", "en": "the squad is full"},
	"run.msg.squad_downed": {"zh": "倒下的植物无法出征", "en": "a DOWNED plant cannot enlist"},

	# ------------------------------------------------------------ roadmap page
	"run.map.title": {"zh": "战役路线", "en": "CAMPAIGN ROUTE"},
	"run.map.subtitle": {"zh": "章节：%s", "en": "chapter: %s"},
	"run.map.hint": {"zh": "点击亮起的节点前进；每一列是章节的一层", "en": "click a LIT node to move on; each column is one layer of the chapter"},
	"run.map.wallet": {"zh": "随身钱币：%d", "en": "wallet: %d"},
	"run.map.state.done": {"zh": "已通过", "en": "cleared"},
	"run.map.state.open": {"zh": "可前往", "en": "go"},
	"run.map.state.locked": {"zh": "未解锁", "en": "locked"},
	"run.map.fee": {"zh": "再战费用 %d", "en": "retry fee %d"},
	"run.map.mods": {"zh": "本局修正：%s", "en": "run mods: %s"},
	"run.map.pouch": {"zh": "行囊：%s", "en": "pouch: %s"},

	# ------------------------------------------------------------ node types
	"run.node.battle": {"zh": "战斗", "en": "Battle"},
	"run.node.boss": {"zh": "首领", "en": "Boss"},
	"run.node.shop": {"zh": "商店", "en": "Shop"},
	"run.node.event": {"zh": "事件", "en": "Event"},
	"run.node.treasure": {"zh": "宝箱", "en": "Treasure"},
	"run.node.rest": {"zh": "营火", "en": "Campfire"},

	# ------------------------------------------------------------ result panel (run)
	"run.result.claim": {"zh": "领取奖励", "en": "CLAIM REWARDS"},
	"run.result.retry": {"zh": "重整再战", "en": "RALLY AND RETRY"},
	"run.defeat.fee": {"zh": "战败：支付费用 %d / %d，全队倒下", "en": "defeat: paid %d of %d fee, the squad is DOWNED"},

	# ------------------------------------------------------------ reward page
	"run.reward.title": {"zh": "三选一奖励", "en": "PICK ONE REWARD"},
	"run.reward.hint": {"zh": "选一个带走（其余作废）", "en": "take one; the rest is left behind"},
	"run.reward.money": {"zh": "钱币 +%d", "en": "+%d money"},
	"run.reward.exp": {"zh": "全队经验 +%d", "en": "squad +%d exp"},
	"run.reward.item": {"zh": "%s x%d（入行囊）", "en": "%s x%d (to the pouch)"},

	# ------------------------------------------------------------ treasure node
	"run.treasure.text": {"zh": "一只落满灰尘的箱子堵在路上，锁已经锈了，一推就开。", "en": "A dusty chest blocks the road; its lock rusted through and gives way with a push."},
	"run.treasure.open": {"zh": "打开宝箱", "en": "OPEN THE CHEST"},
	"run.treasure.empty": {"zh": "箱子是空的", "en": "the chest was empty"},

	# ------------------------------------------------------------ rest node
	"run.rest.text": {"zh": "一处背风的土坡，适合停下来生一堆火。", "en": "A sheltered slope, good enough to stop and light a fire."},
	"run.rest.heal": {"zh": "休整：治疗一名倒下的队员", "en": "Rest: heal one DOWNED squad member"},
	"run.rest.patrol": {"zh": "巡视：下 %d 个节点阳光产出 +%d%%", "en": "Patrol: the next %d nodes get +%d%% sun"},
	"run.rest.camp": {"zh": "扎营：结算路上捡的钱币 +%d", "en": "Camp: count your coins, +%d money"},
	"run.msg.nobody_downed": {"zh": "没有倒下的队员", "en": "nobody is DOWNED"},

	# ------------------------------------------------------------ event / effects
	"run.effect.gain_money": {"zh": "拾得钱币 +%d", "en": "found +%d money"},
	"run.effect.lose_money": {"zh": "付出钱币 -%d", "en": "paid -%d money"},
	"run.effect.item": {"zh": "获得道具：%s（入行囊）", "en": "gained an item: %s (to the pouch)"},
	"run.effect.plant": {"zh": "获得新植物：%s（花园 %d 号位）", "en": "a new plant joins: %s (garden slot %d)"},
	"run.effect.heal": {"zh": "%s 伤愈归队", "en": "%s stands up, healed"},
	"run.effect.mod": {"zh": "本局修正：%s x%s", "en": "run mod: %s x%s"},
	"run.effect.down": {"zh": "%s 在混乱中倒下了", "en": "%s goes DOWN in the scuffle"},
	"run.msg.no_money": {"zh": "钱币不够", "en": "not enough money"},
	"run.msg.node_done": {"zh": "继续上路", "en": "back on the road"},

	# ------------------------------------------------------------ run end
	"run.end.title": {"zh": "冒险完成", "en": "RUN COMPLETE"},
	"run.end.stats": {"zh": "胜 %d · 败 %d · 节点 %d · 钱币 %d", "en": "wins %d - losses %d - nodes %d - money %d"},
	"run.end.pouch": {"zh": "行囊并入仓库：%s", "en": "the pouch joins the warehouse: %s"},
	"run.end.close": {"zh": "返回主菜单", "en": "BACK TO THE MENU"},

	# ------------------------------------------------------------ deck select (P32)
	# The seed-picking page a FREE level comes through. Same rules as the squad
	# page: a refusal is said in words, and the %d counts match on both sides.
	"deck.title": {"zh": "选择本局卡片", "en": "CHOOSE YOUR CARDS"},
	"deck.subtitle": {"zh": "已选 %d / 上限 %d", "en": "picked %d / max %d"},
	"deck.hint": {"zh": "点卡片放入卡槽，点卡槽移回；最多 %d 张", "en": "click a card to load a slot, click a slot to empty it; up to %d"},
	"deck.confirm": {"zh": "出征", "en": "DEPLOY"},
	"deck.head.slots": {"zh": "出战卡槽", "en": "SEED SLOTS"},
	## [P98] The pool is TWO REGIONS now: the garden scrolls and the spirit scrolls, each one
	## page of tiles with its own heading (the old single "YOUR CARDS" band ran off the page).
	"deck.head.garden": {"zh": "花园卷轴", "en": "GARDEN SCROLLS"},
	"deck.head.spirit": {"zh": "灵界卷轴", "en": "SPIRIT SCROLLS"},
	## [P32-UI] One-character corner chips saying WHICH scroll summons the card:
	## green 园/G = garden scroll, blue 灵/S = spirit scroll (drawn on the tile).
	"deck.badge.garden": {"zh": "园", "en": "G"},
	"deck.badge.spirit": {"zh": "灵", "en": "S"},
	"deck.scroll_state": {"zh": "卷轴耐久 %d/%d", "en": "scroll %d/%d"},
	"deck.scroll_none": {"zh": "未获得卷轴", "en": "no scroll"},
	"deck.msg.deck_empty": {"zh": "至少选择一张卡片", "en": "pick at least one card"},
	"deck.msg.deck_full": {"zh": "卡槽已满（上限 %d）", "en": "the seed slots are full (max %d)"},
	"deck.msg.no_scroll": {"zh": "尚未获得 %s 的卷轴", "en": "you have not gained %s's scroll yet"},
}
