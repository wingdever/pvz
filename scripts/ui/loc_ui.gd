class_name LocUi
extends RefCounted
## [P20] UI CHROME strings: menu pages, HUD labels, garden / warehouse / shop
## screens. One row per key, both variants always filled.
##
## Key shape is "<screen>.<thing>", e.g. "menu.main.adventure", "hud.end_turn",
## "garden.advice.healthy". Format strings keep the same %-specifiers in both
## variants (Loc.self_check fails the run when they differ).

const TABLE := {
	# ------------------------------------------------------------ language switch
	## The SETTINGS button itself is built by Loc.language_button_text() (it names
	## the language you are IN, so it must not be translated like ordinary text).
	"ui.settings.language_hint": {
		"zh": "语言可在游戏内切换，选择会保存下来",
		"en": "the language switches live and the choice is saved",
	},
	"ui.settings.language_switched": {
		"zh": "语言已切换为 %s",
		"en": "language switched to %s",
	},

	# ------------------------------------------------------------ music (P21)
	## The SETTINGS page has two buttons: the switch names what music is doing RIGHT
	## NOW (like the language button), the volume names the level it is at.
	"menu.settings.music_on": {"zh": "音乐：开", "en": "MUSIC: ON"},
	"menu.settings.music_off": {"zh": "音乐：关", "en": "MUSIC: OFF"},
	"menu.settings.music_volume": {"zh": "音量：%d%%", "en": "VOLUME: %d%%"},
	"ui.settings.music_hint": {
		"zh": "   -   背景音乐会跟着画面切换，音量与开关会保存下来",
		"en": "   -   the background music follows the screen; its volume and switch are saved",
	},

	# ------------------------------------------------------------ sound effects (P50)
	## [P50] The same two-button shape as the music directly above, and a separate switch
	## on purpose: "no theme, but I want to hear the melon land" is a real setting.
	## The volume label must not reuse the music one - the page shows both at once.
	"menu.settings.sfx_on": {"zh": "音效：开", "en": "SFX: ON"},
	"menu.settings.sfx_off": {"zh": "音效：关", "en": "SFX: OFF"},
	"menu.settings.sfx_volume": {"zh": "音效音量：%d%%", "en": "SFX VOLUME: %d%%"},
	"ui.settings.sfx_hint": {
		"zh": "   -   音效是场上正在发生的事，开关与音量同样会保存",
		"en": "   -   the sound effects are the board talking; their switch and volume are saved too",
	},

	# ------------------------------------------------------------ sun on the lawn (P89)
	## [P89] The round's income lands on the lawn and waits to be picked up. These two
	## buttons say whether it gathers itself and after how many rounds; "off" is the classic
	## game, where every sun is a click the player owes the lawn.
	## [B2c] the brawl's enemy-visibility switch (the button names the state that is ON)
	"menu.settings.show_enemy_on": {"zh": "可见敌方单位：开", "en": "SHOW ENEMY PIECES: ON"},
	"menu.settings.show_enemy_off": {"zh": "可见敌方单位：关", "en": "SHOW ENEMY PIECES: OFF"},
	## [B21] the brawl's friendly fire switch: a shot's damage may reach its OWN side
	"menu.settings.friendly_fire_on": {"zh": "射弹友伤：开", "en": "FRIENDLY FIRE: ON"},
	"menu.settings.friendly_fire_off": {"zh": "射弹友伤：关", "en": "FRIENDLY FIRE: OFF"},
	## [W11] the war's lattice switch: deployment table and battlefield draw the grid from one
	## generator, so this one button means both screens (default 开)
	"menu.settings.war_grid_on": {"zh": "战争网格线：开", "en": "WAR GRID LINES: ON"},
	"menu.settings.war_grid_off": {"zh": "战争网格线：关", "en": "WAR GRID LINES: OFF"},
	"menu.settings.sun_auto_on": {"zh": "自动拾取阳光：开", "en": "AUTO SUN: ON"},
	"menu.settings.sun_auto_off": {"zh": "自动拾取阳光：关", "en": "AUTO SUN: OFF"},
	"menu.settings.sun_rounds": {"zh": "落地 %d 回合后自动拾取", "en": "GATHER AFTER %d ROUND(S)"},
	"menu.settings.sun_rounds_off": {"zh": "（自动拾取已关）", "en": "(auto sun is off)"},
	"ui.settings.sun_hint": {
		"zh": "   -   阳光落在草坪上，点一下就收进阳光池；开自动拾取就由它自己收",
		"en": "   -   sun lands on the lawn: click it to gather, or let the auto-collect do it",
	},

	# ------------------------------------------------------------ geometry readout
	## Assembled by Layout.geometry_line() and shown in the SETTINGS hint + the log.
	"ui.geometry.viewport": {"zh": "视口 %dx%d", "en": "viewport %dx%d"},
	"ui.geometry.window": {"zh": "（窗口 %dx%d）", "en": " (window %dx%d)"},
	"ui.geometry.cell": {"zh": "  格子 %d", "en": "  cell %d"},
	"ui.geometry.lawn": {"zh": "  草坪 %dx%d", "en": "  lawn %dx%d"},
	"ui.geometry.origin": {"zh": " @ (%d,%d)", "en": " @ (%d,%d)"},

	# ------------------------------------------------------------ main menu (P20)
	"menu.main.title": {"zh": "植物大战僵尸  回合制", "en": "PVZ  TURN-BASED"},
	"menu.main.subtitle": {
		"zh": "植物大战僵尸 - 网格回合制复刻",
		"en": "Plants vs Zombies - grid turn-based remake",
	},
	"menu.main.hint": {"zh": "地上的东西：花园 / 仓库 / 商店 / 背包 / 图鉴，点它们进去；也可以选下面的选项   -   ESC 返回",
		"en": "On the floor: GARDEN / WAREHOUSE / SHOP / BACKPACK / ALMANAC - click them, or pick an option below   -   ESC goes back"},
	"menu.main.adventure": {"zh": "冒险模式", "en": "ADVENTURE"},
	"menu.main.garden": {"zh": "花园", "en": "GARDEN"},
	"menu.main.warehouse": {"zh": "仓库", "en": "WAREHOUSE"},
	"menu.main.shop": {"zh": "商店", "en": "SHOP"},
	"menu.main.backpack": {"zh": "背包", "en": "BACKPACK"},
	## [P26] The almanac used to be a text option rather than one of the objects on the floor -
	## its page is a reading page, and a fifth object would have meant a fifth piece of art.
	## [D74] The user asked for exactly that picture on 2026-10-05 (in BOTH shells), so the
	## word is now the caption under the book: same string, one owner, whichever door shows it.
	"menu.main.almanac": {"zh": "图鉴", "en": "ALMANAC"},
	"menu.main.survival": {"zh": "生存模式", "en": "SURVIVAL"},
	"menu.main.settings": {"zh": "设置", "en": "SETTINGS"},
	"menu.main.quit": {"zh": "退出游戏", "en": "QUIT"},
	"menu.main.survival_hint": {
		"zh": "生存模式尚未实现 - 已在计划中。",
		"en": "SURVIVAL mode is not implemented yet - it is on the roadmap.",
	},
	## [B2] THE CLASSIC SHELL (docs/prompt/BRAWL.md §10 / D20). Its one entry so far is the
	## brawl; the switcher row names where it GOES rather than where you are, which is why
	## there are two labels for one button.
	"menu.main.brawl": {"zh": "乱斗模式", "en": "BRAWL"},
	"menu.shell.switch_classic": {"zh": "切换到经典模式", "en": "SWITCH TO CLASSIC"},
	"menu.shell.switch_turn": {"zh": "切换到回合模式", "en": "SWITCH TO TURN-BASED"},
	"menu.classic.title": {"zh": "植物大战僵尸  经典", "en": "PVZ  CLASSIC"},
	"menu.classic.subtitle": {"zh": "实时 · 自动 · 连续移动", "en": "REAL-TIME  AUTO  CONTINUOUS"},
	## [B2b] THE BRAWL'S ROUND PAGE. The bout itself is watched, not read: these strings are the
	## offers between fights and the receipt after one.
	"brawl.title": {"zh": "乱斗模式", "en": "BRAWL"},
	## A SHORT row: the offer buttons are one column wide, so the figures live on the page's
	## opponent line (brawl.form.opponent) and only the name and the size fit here.
	## [B28] THREE FACTS, TWO LINES. The card is an opponent's whole line-up at a glance: who, how
	## many, and (the user's call, 2026-10-08: "为操作栏的敌阵选项增加显示敌方战阵所有单位的战力之和")
	## what they add up to in 战力 - the sum of the pieces' own estimates (Balance.unit_power, the same
	## number the unit page prints), over THIS round's roll rather than the sheet's authored list.
	## The break is in the string rather than in the button's wrapping so both languages put the name
	## on top; the short "%d pc" is deliberate - the cards are ~181 px and "piece(s)" was already the
	## half of one line.
	"brawl.offer": {"zh": "%s\n%d 只   战力 %d", "en": "%s\n%d pc   POWER %d"},
	## [B29] THE NAMES OF THE OPPONENTS NOBODY WROTE. A generated formation is not a row of
	## data/brawl/formations.csv, so it has no name / name_zh columns and this list is what identifies
	## it: BrawlFormationGen draws an INDEX with the session's own RNG and the label resolves it here,
	## at the moment the card is drawn - which is what lets a language switch rename an already-dealt
	## round instead of printing the string the other language left behind.
	## The list is COUNTED by probing these keys (BrawlFormationGen._name_count), never numbered by a
	## second constant, so adding an opponent name is one entry here and nothing else. Keep them short
	## - a name shares its line with 只数 and 战力 on a ~181 px card.
	"brawl.gen.name.0": {"zh": "遭遇阵", "en": "Encounter"},
	"brawl.gen.name.1": {"zh": "巡逻队", "en": "Patrol"},
	"brawl.gen.name.2": {"zh": "伏击组", "en": "Ambush"},
	"brawl.gen.name.3": {"zh": "突袭阵", "en": "Raid"},
	"brawl.gen.name.4": {"zh": "残部", "en": "Remnant"},
	"brawl.gen.name.5": {"zh": "援军", "en": "Reinforcement"},
	"brawl.no_offers": {
		"zh": "没有敌阵可打：读不出 data/brawl/formations.csv",
		"en": "no formations to fight: data/brawl/formations.csv could not be read",
	},
	"brawl.no_session": {
		"zh": "没有进行中的乱斗：回主菜单重新开始",
		"en": "no session running: start one from the menu",
	},
	## [S4] THE ARENA'S HEADER (D70): the band both brawl pages wear (BrawlHUD.draw_top_bar), with
	## the four things a SPECTATOR needs - who is left standing on each side, the clock, the speed
	## and the rage level - plus the keys, which used to live in the console log and nowhere else.
	"brawl.hud.score": {"zh": "我方 %d   :   %d 敌阵", "en": "ALLY %d   :   %d ENEMY"},
	"brawl.hud.clock": {
		"zh": "%s   倍速 %s   狂暴 %d 级",
		"en": "%s   speed %s   rage %d",
	},
	"brawl.hud.round": {"zh": "第 %d 轮   -   对 %s", "en": "ROUND %d   -   vs %s"},
	"brawl.hud.hint": {
		"zh": "空格 暂停   F 倍速   ESC 离开本局",
		"en": "SPACE pause   F speed   ESC leave the session",
	},
	"brawl.result.win": {"zh": "胜", "en": "WIN"},
	"brawl.result.lose": {"zh": "败", "en": "LOSE"},
	"brawl.result.draw": {"zh": "平局", "en": "DRAW"},
	"brawl.result.line": {
		"zh": "第 %d 轮   对 %s   -   本轮 %d 金币   -   共 %d",
		"en": "ROUND %d   vs %s   -   %d coin this round   -   %d total",
	},
	"brawl.result.hint": {"zh": "ESC 结束本局", "en": "ESC ends the session"},
	"brawl.next_round": {"zh": "下一轮", "en": "NEXT ROUND"},
	## [B2c] THE FORMATION PAGE: the player's half, their roster, and the three states a click can
	## leave the page in (nothing picked, something in hand, the cap full).
	"brawl.form.title": {"zh": "第 %d 轮   -   编排战阵", "en": "ROUND %d   -   ARRANGE"},
	"brawl.form.cap": {
		"zh": "已上阵 %d / %d   -   金币 %d",
		"en": "%d / %d fielded   -   %d coin",
	},
	"brawl.form.hint": {
		"zh": "拖动候战区的棋子到自己半场的格子；点下方的候选换对手   -   ESC 结束本局",
		"en": "drag a bench piece onto a cell of your half; click an offer below to switch opponent   -   ESC ends the session",
	},
	"brawl.form.opponent": {
		"zh": "对手 %s   -   %d 只   -   %d 生命   -   %d 金币",
		"en": "OPPONENT %s   -   %d piece(s)   -   %d hp   -   %d coin",
	},
	"brawl.form.chosen_mark": {"zh": "已选", "en": "picked"},
	## [B15] TWO SENTENCES FOR THE TWO HANDS, because they do different things with what they
	## hold. They were ONE key until this batch, and the shared wording was the piece's - so
	## picking up an ATTACHMENT used to tell the player to click a cell of their half, which is
	## not a thing an attachment can be dropped on (its own refusal says so, one click later).
	"brawl.form.selected_piece": {
		"zh": "已拿起 %s   -   点自己半场的一格放上去，或点左下的「遣散」把它请走",
		"en": "holding %s   -   click a cell to place it, or DISMISS at the band's left end",
	},
	"brawl.form.selected_gear": {
		"zh": "已拿起 %s   -   拖到一枚棋子上装上（拖回背包就取下）",
		"en": "holding %s   -   drop it on a piece to wear it (drop it on the bag to take it off)",
	},
	"brawl.form.pick_first": {
		"zh": "先在左边的候战区点一个棋子",
		"en": "pick a piece in the bench first",
	},
	"brawl.form.drop_bad": {
		"zh": "只能放到自己半场的空格上（一格一个）",
		"en": "your own half only, and one piece per cell",
	},
	## [B5+] THE HOVER PANEL (候战区与场上棋子的详情). Its wording lives here and its NUMBERS come
	## from the sheets, so a sheet edit moves the panel without touching this table. The bench
	## caption carries the count of pieces still waiting.
	"brawl.info.bench": {"zh": "候战区 %d/%d", "en": "BENCH %d/%d"},
	"brawl.info.stats_piece": {
		"zh": "费用 %d   生命 %d   attack %d",
		"en": "Cost %d   HP %d   Attack %d",
	},
	"brawl.info.stats_move": {
		"zh": "attack距离 %.2f 格   移速 %.2f /秒   attack间隔 %.2f 秒",
		"en": "Reach %.2f   Speed %.2f/s   Every %.2f s",
	},
	"brawl.info.stats_zombie": {
		"zh": "生命 %d   护甲 %d   移动 %d   啃食 %d",
		"en": "HP %d   Armor %d   Move %d   Bite %d",
	},
	"brawl.info.stats_plant": {
		"zh": "生命 %d   attack %d   阳光 %d",
		"en": "HP %d   Attack %d   Sun %d",
	},
	"brawl.info.rarity": {"zh": "rarity %s", "en": "Rarity %s"},
	"brawl.info.skill": {"zh": "技能：%s", "en": "Skill: %s"},
	"brawl.info.special": {"zh": "机制：%s", "en": "Trait: %s"},
	## [B7] What ONE piece wears, listed by name. The three squares drawn on a cell say HOW MANY;
	## this line is the only place the page says WHICH - and the numbers behind them are the
	## sheet's, summed by BrawlSession.mods_for the same way the arena sums them.
	"brawl.info.gear": {"zh": "挂件：%s", "en": "Wearing: %s"},
	"brawl.form.full": {
		"zh": "上阵已满（%d 个）：先把场上的棋子收回",
		"en": "the line-up is full (%d): take a piece back first",
	},
	"brawl.form.engaged": {"zh": "出战", "en": "FIGHT"},
	## [B5+] The two answers a DROP can get, and the bench's own hard limit (nine slots).
	"brawl.form.benched": {"zh": "%s 回到候战区", "en": "%s is back in the bench"},
	"brawl.form.bench_full": {
		"zh": "候战区满了（9 格）：先把一枚棋子放上场",
		"en": "the bench is full (9 slots): field a piece first",
	},
	## [B15] 遣散（D90）: the button, its two answers, and the one refusal. The button acts on the
	## piece IN HAND, so these sentences never have to say WHICH piece - the page's own hint
	## line already named it when it was picked up (brawl.form.selected_piece).
	"brawl.form.dismiss": {"zh": "遣散", "en": "DISMISS"},
	"brawl.form.dismissed": {"zh": "已遣散 %s", "en": "%s dismissed"},
	"brawl.form.dismissed_gear": {
		"zh": "已遣散 %s（%d 件挂件回到背包）",
		"en": "%s dismissed (%d attachment(s) back in the bag)",
	},
	"brawl.form.dismiss_last": {
		"zh": "最后一枚棋子不能遣散：遣散了就没有棋子可上场了",
		"en": "the last piece cannot be dismissed - there would be nothing left to field",
	},
	## [B7] THE BAG AND THE THREE SLOTS. The bag's caption is a count and nothing else (it has no
	## capacity - O38), the "+N" line is what a bag too long for its box shows, and the four
	## answers below are what a gear drop can come back with.
	"brawl.info.bag": {"zh": "背包 %d", "en": "BAG %d"},
	"brawl.bag.empty": {"zh": "背包是空的", "en": "the bag is empty"},
	"brawl.bag.more": {"zh": "+%d 件", "en": "+%d more"},
	"brawl.attach.equipped": {"zh": "%s 装到 %s 上", "en": "%s -> %s"},
	"brawl.attach.removed": {"zh": "%s 回到背包", "en": "%s is back in the bag"},
	"brawl.attach.moved": {"zh": "%s 换到 %s 上", "en": "%s -> %s"},
	"brawl.attach.full": {
		"zh": "%s 的三个装配槽都满了：先取下一件",
		"en": "%s wears three already: take one off first",
	},
	"brawl.attach.bad": {
		"zh": "把挂件拖到一枚棋子上才算装上（拖回背包就取下）",
		"en": "drop it on a piece to wear it (drop it on the bag to take it off)",
	},
	"brawl.retry": {"zh": "重挑对手", "en": "PICK ANOTHER"},
	## [B5] THE WIN'S REWARD (D16): three cards, one taken. Each kind of card has its own
	## sentence, and the piece / augment names come from their sheets.
	"brawl.reward.hint": {"zh": "选一件奖励，本轮到手", "en": "pick one reward for this round"},
	"brawl.reward.piece": {"zh": "新棋子：%s", "en": "NEW PIECE: %s"},
	"brawl.reward.augment": {"zh": "强化：%s（%s）", "en": "AUGMENT: %s (%s)"},
	## [B7] The fifth kind of card. It says "equipment" and not just the name because the two
	## attachment kinds are otherwise spelled identically, and the player takes one card blind.
	"brawl.reward.equipment": {"zh": "装备：%s（%s）", "en": "EQUIPMENT: %s (%s)"},
	"brawl.reward.cap": {"zh": "上阵上限 +%d", "en": "DEPLOY CAP +%d"},
	"brawl.reward.coins": {"zh": "金币 +%d", "en": "COIN +%d"},
	## [B26] THE SHELF (scripts/ui/brawl/brawl_formation.gd). The shop used to be a PAGE with
	## its own title and purse line; it now lies on the board's enemy half, so what is left is the
	## panel's caption, the words a row can wear, and one hint at its foot.
	## [B27] "商店" is that caption AND the band's toggle cell - one word, because they are one thing:
	## the shelf's door and the shelf itself. The hint line teaches the door, since the cover going
	## back down is the half's own state the player has to be able to leave.
	"brawl.shop.caption": {"zh": "商店", "en": "SHOP"},
	"brawl.shop.bench_full": {"zh": "（候战区已满）", "en": "(bench full)"},
	"brawl.shop.hint": {
		"zh": "点一件买下（只花钱）   -   再点商店收起货架",
		"en": "click to buy (coin only)   -   click SHOP to fold the shelf",
	},
	## [B7] The two attachment kinds on the shelf, one word each - see brawl.reward.equipment.
	"brawl.shop.augment": {"zh": "强化：%s（%s）", "en": "AUGMENT: %s (%s)"},
	"brawl.shop.equipment": {"zh": "装备：%s（%s）", "en": "EQUIPMENT: %s (%s)"},
	"brawl.shop.row": {"zh": "%s   -   %d 金币", "en": "%s   -   %d coin"},
	"brawl.shop.sold": {"zh": "%s（已售出）", "en": "%s (sold)"},
	"brawl.shop.cap": {"zh": "上阵上限 +%d", "en": "DEPLOY CAP +%d"},
	## [B5] AN ATTACHMENT'S one-line effect text, one row per key of BalanceBrawl.EFFECT_KEYS.
	## The number in each is the sheet's own 数值, so the wording and the arithmetic cannot drift;
	## a key with no row here shows its raw name instead.
	## [B7] The FIVE MULTIPLIER keys print hundredths ("+15%%"), the TWO FLAT keys print the
	## amount as the sheet wrote it ("+120"): GearDB decides which by asking
	## BalanceBrawl.effect_is_flat(), so a row cannot end up promising a percentage of a number
	## it actually adds.
	"brawl.aug.hp_mult": {"zh": "生命 +%d%%", "en": "Health +%d%%"},
	"brawl.aug.attack_mult": {"zh": "attack +%d%%", "en": "Attack +%d%%"},
	"brawl.aug.speed_mult": {"zh": "移速 +%d%%", "en": "Move speed +%d%%"},
	"brawl.aug.haste": {"zh": "攻速 +%d%%", "en": "Attack speed +%d%%"},
	"brawl.aug.taken_mult": {"zh": "受到伤害 %d%%", "en": "Damage taken %d%%"},
	"brawl.aug.hp_flat": {"zh": "生命 +%d", "en": "Health +%d"},
	"brawl.aug.attack_flat": {"zh": "attack +%d", "en": "Attack +%d"},
	## [D75] THE CLASSIC MODE'S ALMANAC (scripts/ui/brawl/brawl_almanac.gd). Its tabs are NOT
	## the turn page's three (units / items / levels): the classic mode's items are the brawl's
	## gear and its "levels" are the enemy formations a round offers, so every word here is its
	## own. The panel's numeric lines reuse the almanac.line.* keys above where the MEANING is
	## the same (生命 / attack / 天赋 / 技能) and add one only where this mode says something new.
	"brawl.almanac.title": {"zh": "经典图鉴", "en": "CLASSIC ALMANAC"},
	"brawl.almanac.subtitle": {
		"zh": "%d 个单位   -   %d 件挂件   -   %d 支敌阵",
		"en": "%d unit(s)   -   %d gear   -   %d formation(s)",
	},
	"brawl.almanac.hint": {
		"zh": "点格子看详情   -   ESC 返回",
		"en": "click a cell for the details   -   ESC goes back",
	},
	"brawl.almanac.tab.units": {"zh": "单位", "en": "UNITS"},
	"brawl.almanac.tab.gear": {"zh": "挂件", "en": "GEAR"},
	"brawl.almanac.tab.formations": {"zh": "敌阵", "en": "FORMATIONS"},
	"brawl.almanac.race.humans": {"zh": "人类", "en": "HUMANS"},
	## [B24] The classic page's two remaining piece factions (data/units/monsters.csv and
	## machine.csv). These are RACE words, the twins of the humans' line above - not the item
	## group words (almanac.group.*) and not the turn page's almanac.race.* pair, which is why
	## they live in this page's own block.
	"brawl.almanac.race.monsters": {"zh": "怪兽", "en": "MONSTERS"},
	"brawl.almanac.race.machine": {"zh": "机械", "en": "MACHINE"},
	## [B38] ...and its fourth (data/units/pokemon.csv), same shape again.
	"brawl.almanac.race.pokemon": {"zh": "宝可梦", "en": "POKEMON"},
	## [B39] ...and its fifth (data/units/animals.csv), same shape again.
	"brawl.almanac.race.animals": {"zh": "动物", "en": "ANIMALS"},
	"brawl.almanac.note.default": {"zh": "默认", "en": "DEFAULT"},
	"brawl.almanac.note.pieces": {"zh": "%d 枚", "en": "%d piece(s)"},
	"brawl.almanac.kind.augment": {"zh": "强化", "en": "AUGMENT"},
	"brawl.almanac.kind.equipment": {"zh": "装备", "en": "EQUIPMENT"},
	## [B24] There is no 模式 line here any more: the brawl unit panel has nine rows and spent one
	## printing the race you had already clicked the button for. The word lives on as the button's
	## own label (the three race keys above), which is where the player reads it either way.
	"brawl.almanac.line.reach": {"zh": "attack距离  %s", "en": "REACH     %s"},
	"brawl.almanac.line.move_speed": {"zh": "移速      %s", "en": "SPEED     %s"},
	"brawl.almanac.line.interval": {"zh": "attack间隔  %s", "en": "EVERY     %s"},
	"brawl.almanac.line.shot": {"zh": "射弹      %s", "en": "SHOT      %s"},
	"brawl.almanac.line.kind": {"zh": "名称      %s", "en": "KIND      %s"},
	"brawl.almanac.line.tier": {"zh": "等级      %s", "en": "TIER      %s"},
	"brawl.almanac.line.effect": {"zh": "效果      %s", "en": "EFFECT    %s"},
	"brawl.almanac.line.price": {"zh": "价格      %s", "en": "PRICE     %s"},
	"brawl.almanac.line.pieces": {"zh": "棋子数    %d", "en": "PIECES    %d"},
	"brawl.almanac.line.power": {"zh": "战力合计  %d", "en": "POWER     %d"},
	"brawl.almanac.line.coins": {"zh": "奖励      %d 金币", "en": "REWARD    %d coin"},
	"brawl.almanac.line.roster": {"zh": "阵容      %s", "en": "ROSTER    %s"},
	"brawl.almanac.desc.tier": {"zh": "获取  %s", "en": "TIER  %s"},
	"brawl.almanac.desc.tier_line": {"zh": "%s 级 · %d 金币", "en": "%s tier · %d coin"},
	"brawl.almanac.desc.pieces": {"zh": "阵容  %s", "en": "ROSTER  %s"},
	"brawl.almanac.desc.reward": {"zh": "打赢给 %d 金币", "en": "beating it pays %d coin"},
	## [W2] THE WAR MODE'S STRINGS. One block for the mode's three pages (entry button, the
	## deployment table, the arena HUD + result line). The mode itself is watched,
	## not read - so the strings are the offers BEFORE the fight and the receipt AFTER it,
	## exactly like the brawl's; the fight's own drama lives on the field.
	## [W8] the table opens once PER ROUND now, so its strings speak of rounds, not waves.
	"menu.main.war": {"zh": "战争模式", "en": "WAR"},
	"war.no_maps": {
		"zh": "没有可打的战场：读不出 data/war/maps.csv",
		"en": "no battlefield to fight on: data/war/maps.csv could not be read",
	},
	## The deployment table (W4): the map name carries into the title so a second map needs
	## no new strings. The cap line and the two refusals quote WAR_DEPLOY_LIMIT / the map's
	## deploy_cols, so the page never states a number it does not enforce.
	"war.formation.title": {"zh": "战场 %s   -   编排战阵", "en": "FIELD %s   -   ARRANGE"},
	"war.formation.cap": {
		"zh": "已上阵 %d / %d   -   出征后全自动",
		"en": "%d / %d fielded   -   the battle runs itself",
	},
	"war.formation.zone": {
		"zh": "只能摆进左侧 %d 列部署区",
		"en": "only the left %d columns are the deployment zone",
	},
	"war.formation.limit": {
		"zh": "上限 %d：先点掉已上阵的棋子，再摆新的",
		"en": "cap %d: click a fielded piece to lift it before placing another",
	},
	"war.formation.pick": {
		"zh": "先点下方的单位，再点战场落子；放下后手里保留，右键收手",
		"en": "pick a unit below, then click the field; the hand stays armed, right-click frees it",
	},
	"war.formation.start": {"zh": "出征", "en": "MARCH"},
	## [W7] The page's own view controls live in the hint strip's left end (the arena's
	## war.hud.hint says the SAME gestures are NOT there - the page has no WASD, only the
	## mouse), and 清空 is the page's one do-over button.
	"war.formation.view": {
		"zh": "滚轮缩放 · Ctrl+左键拖动平移 · 中键复位",
		"en": "wheel zoom · Ctrl+left-drag pans · wheel-click resets",
	},
	"war.formation.clear": {"zh": "清空", "en": "CLEAR"},
	"war.formation.cleared": {
		"zh": "已撤下 %d 枚",
		"en": "%d piece(s) lifted",
	},
	## [W8] The scout's register line, appended to the cap line when a session exists:
	## which round you are arranging, how many the war holds, what the scouting found.
	"war.formation.round": {
		"zh": "第 %d / %d 回合   ·   敌阵 %d 枚已探明",
		"en": "round %d / %d   ·   %d enemy piece(s) scouted",
	},
	## The arena band (W5, [W8] amended): the round the bout is fighting, who is left, the
	## timer - what a commander with only eyes needs. The band's second slot used to carry
	## the scheduler's countdown; rounds have no countdown, so the arena now pushes ""
	## there (the HUD draws nothing for an empty string) and the key is gone.
	"war.hud.round": {"zh": "第 %d / %d 回合", "en": "ROUND %d / %d"},
	"war.hud.score": {"zh": "我方 %d   :   %d 敌阵", "en": "ALLY %d   :   %d ENEMY"},
	"war.hud.clock": {"zh": "%s   倍速 %s", "en": "%s   speed %s"},
	"war.hud.hint": {
		"zh": "WASD / Ctrl+拖动 平移   Ctrl+滚轮 / ± 缩放   空格 暂停   F 倍速   ESC 离开",
		"en": "WASD / Ctrl-drag pan   Ctrl-wheel / +- zoom   SPACE pause   F speed   ESC leave",
	},
	"war.result.win": {"zh": "胜", "en": "WIN"},
	"war.result.lose": {"zh": "败", "en": "LOSE"},
	"war.result.draw": {"zh": "平局", "en": "DRAW"},
	## [W8] The between-round word: this round's enemy line is cleared and the field goes
	## back to the table to scout the next one - the war is NOT over, so it must not
	## borrow 胜.
	"war.result.round": {"zh": "敌阵肃清", "en": "ENEMY LINE CLEARED"},
	"war.result.line": {
		"zh": "打到第 %d 回合   ·   用时 %s",
		"en": "reached round %d   -   took %s",
	},
	"war.result.hint": {"zh": "ESC 返回", "en": "ESC returns"},
	"menu.classic.hint": {
		"zh": "经典模式：两支队伍自动交战，你只管看   -   地上的书是图鉴   -   ESC 返回",
		"en": "CLASSIC: two armies fight on their own, you just watch   -   the book on the floor is the ALMANAC   -   ESC returns",
	},
	## The same word on every page that has a way out: one key, so the pages agree.
	"menu.back": {"zh": "返回", "en": "BACK"},

	# ------------------------------------------------------------ level select
	"menu.levels.title": {"zh": "冒险模式", "en": "ADVENTURE"},
	"menu.levels.subtitle": {"zh": "%s 里的每个 *.json 都是一个关卡",
		"en": "Every *.json in %s is a level"},
	## [P99] Two steps now: a card click only SELECTS, ENTER LEVEL is what leaves. The chest
	## is on every level that has a first-clear reward - dim for a level not cleared yet.
	"menu.levels.hint": {"zh": "点关卡选中它，再点「进入关卡」开始   -   点宝箱看首通奖励   -   ESC 返回",
		"en": "Click a level to select it, then ENTER LEVEL   -   click a chest for its reward   -   ESC goes back"},
	"menu.levels.enter": {"zh": "进入 %s", "en": "ENTER %s"},
	"menu.levels.enter_none": {"zh": "先点一个关卡", "en": "PICK A LEVEL FIRST"},
	"menu.levels.selected": {"zh": "已选中 %s", "en": "selected %s"},
	"menu.levels.preview_locked": {"zh": "%s · 首通奖励（还没通关）：%s",
		"en": "%s - first-clear reward (not cleared yet): %s"},
	"menu.levels.preview_open": {"zh": "%s · 首通奖励（已领取）：%s",
		"en": "%s - first-clear reward (already taken): %s"},
	"menu.levels.chest_tip_locked": {"zh": "通关后可以领取：%s", "en": "FIRST CLEAR (locked): %s"},
	## [P96] The level page is a GRID of cards, so the two single-line ROW wordings
	## (menu.levels.row / menu.levels.row_broken) are gone with the row: a card prints the
	## name on its own line and the difficulty + numbers on the next one.
	"menu.levels.card_stat": {"zh": "%s · %d 波 / %d 只僵尸", "en": "%s · %d waves / %d zombies"},
	"menu.levels.cleared": {"zh": "已通关", "en": "CLEARED"},
	"menu.levels.last": {"zh": "上次玩过", "en": "LAST"},
	## [P26] A level file that is there but cannot be played (an empty file, broken JSON,
	## no usable wave). The row stays in the list, greyed out, instead of disappearing.
	"menu.levels.broken": {"zh": "数据错误", "en": "BROKEN"},
	## [P93] The first-clear chest: a closed one beside a cleared level can be opened.
	"menu.levels.chest_hint": {
		"zh": "   -   通关的关卡旁边有宝箱：点它收取首通奖励（已开的宝箱不会再给）",
		"en": "   -   a cleared level leaves a chest: click it for the first-clear reward",
	},
	"menu.levels.chest_open_hint": {
		"zh": "   -   宝箱已开过",
		"en": "   -   the chest has been opened",
	},
	"menu.levels.chest_tip": {"zh": "首通奖励：%s", "en": "FIRST CLEAR: %s"},
	"menu.levels.chest_tip_open": {"zh": "首通奖励已领取：%s", "en": "FIRST CLEAR CLAIMED: %s"},
	"menu.levels.empty": {"zh": "- 在 %s 里没有找到关卡文件 -",
		"en": "- no level files found in %s -"},

	# ------------------------------------------------------------ settings page
	"menu.settings.title": {"zh": "设置", "en": "SETTINGS"},
	"menu.settings.subtitle": {"zh": "显示设置 - 保存到 %s", "en": "Display - saved to %s"},
	"menu.settings.window_unknown": {"zh": "窗口模式 ?", "en": "window mode ?"},
	"menu.settings.hint.window": {"zh": "%s   -   窗口 %s", "en": "%s   -   window %s"},
	"menu.settings.hint.windowed": {"zh": "%s   -   窗口尺寸只在窗口模式下生效",
		"en": "%s   -   window sizes apply in windowed mode"},
	"menu.settings.hint.f11": {"zh": "   -   F11 切换全屏   -   ",
		"en": "   -   F11 toggles fullscreen   -   "},
	"menu.settings.fullscreen_on": {"zh": "全屏：开", "en": "FULLSCREEN: ON"},
	"menu.settings.fullscreen_off": {"zh": "全屏：关", "en": "FULLSCREEN: OFF"},
	"menu.settings.reset": {"zh": "重置游戏", "en": "RESET GAME"},
	"menu.settings.reset_confirm": {"zh": "重置游戏   -   确认？", "en": "RESET GAME   -   CONFIRM?"},
	"menu.settings.hint.reset_armed": {"zh": "   -   再次点击重置来确认（无法撤销）",
		"en": "   -   CLICK RESET AGAIN TO CONFIRM (it cannot be undone)"},
	"menu.settings.hint.reset_plain": {
		"zh": "   -   重置游戏会清空花园、金钱和物品（显示设置保留）",
		"en": "   -   RESET GAME wipes the garden, money and items (display settings stay)",
	},

	# ------------------------------------------------------------ item tiles (P22)
	## The cell badge: how many of that item the container holds. The name under the
	## icon is the plain item name, so it needs no key.
	"item.tile.count": {"zh": "x%d", "en": "x%d"},

	# ------------------------------------------------------------ item detail panel (P22)
	## Shared by the WAREHOUSE and the SHOP: three label + value lines, a description
	## block and a status line. "item.panel.empty_title" is what the panel says when
	## nothing (or nothing at all) is in the grid.
	"item.panel.empty_title": {"zh": "没有东西", "en": "NOTHING HERE"},
	"item.panel.empty_desc": {
		"zh": "点击一个格子查看它的详情和可以做的操作。",
		"en": "Click a tile to see its details and what you can do with it.",
	},
	"item.panel.type": {"zh": "名称      %s", "en": "TYPE      %s"},
	"item.panel.count": {"zh": "数量      %s", "en": "COUNT     %s"},
	"item.panel.sell": {"zh": "售价      %s", "en": "SELL      %s"},
	"item.panel.durability": {"zh": "耐久      %s", "en": "DURABILITY %s"},
	"item.panel.use": {"zh": "用途      %s", "en": "USE       %s"},
	"item.panel.price": {"zh": "价格      %s", "en": "PRICE     %s"},
	"item.panel.owned": {"zh": "已拥有    %s", "en": "OWNED     %s"},
	## [P95] A 植物宝箱's third line: WHICH plant is inside it (the tile prints the same
	## name under the picture).
	"item.panel.plant_chest": {"zh": "装的是    %s", "en": "CONTAINS  %s"},

	# ------------------------------------------------------------ warehouse page
	"warehouse.title": {"zh": "仓库", "en": "WAREHOUSE"},
	"warehouse.subtitle": {
		"zh": "金钱 %s   -   钱币也是物品：出售之后才会变成金钱",
		"en": "MONEY %s   -   coins are items: only SELLING them turns them into money",
	},
	"warehouse.hint": {
		## [P42] The wheel / page buttons are worth a word in the hint: one page holds eight
		## kinds and the warehouse has far more, so a player who never finds the bar believes
		## the items are gone.
		"zh": "点击格子查看详情与操作   -   滚轮 / 底部按钮翻页   -   战斗结束时背包会合并到这里   -   ESC 返回",
		"en": "Click a tile for its details and actions   -   the wheel or the buttons below turn the page   -   the backpack merges in here when a battle ends   -   ESC goes back",
	},
	"warehouse.empty": {"zh": "- 仓库是空的 -", "en": "- the warehouse is empty -"},
	"warehouse.sell_all": {"zh": "卖出所有钱币", "en": "SELL ALL COINS"},
	"warehouse.sell_stack": {"zh": "卖出整叠   +%d", "en": "SELL STACK   +%d"},
	"warehouse.no_sell": {"zh": "这个物品不能出售", "en": "This item cannot be sold"},
	## [P95] slot 0's label while a 植物宝箱 is selected: it OPENS instead of selling.
	"warehouse.open": {"zh": "打开宝箱", "en": "OPEN CHEST"},

	# ------------------------------------------------------------ shop page
	"shop.title": {"zh": "商店", "en": "SHOP"},
	"shop.subtitle": {"zh": "金钱 %s   -   购买肥料、经验药水或整株植物",
		"en": "MONEY %s   -   buy fertilizer, EXP potions or whole plants"},
	"shop.hint": {"zh": "点击格子查看详情，再点下面的按钮购买   -   滚轮翻页   -   ESC 返回",
		"en": "Click a tile for its details, then BUY below   -   the wheel turns the page   -   ESC goes back"},
	"shop.too_expensive": {"zh": "（钱不够）", "en": "(too expensive)"},
	"shop.buy": {"zh": "购买   -%d", "en": "BUY   -%d"},
	"shop.detail.plant": {
		"zh": "买下之后这株植物会加入花园（花园满时买不了），之后战斗中可以用卡片召唤它。",
		"en": "Buying it adds one plant to the garden (refused when the garden is full); plant cards summon it in battle.",
	},

	# ------------------------------------------------------------ backpack page (P22)
	## The main menu's BACKPACK picture opens this page. Outside a battle the container
	## is normally EMPTY - the drops it collects land there during a fight and are
	## merged into the warehouse the moment that fight settles - so the page explains
	## the rule instead of just showing an empty grid.
	"backpack.title": {"zh": "背包", "en": "BACKPACK"},
	"backpack.subtitle": {"zh": "%d 种物品，共 %d 件   -   战斗结束时背包会自动并进仓库",
		"en": "%d kind(s), %d item(s)   -   the backpack merges into the warehouse when a battle ends"},
	"backpack.hint": {"zh": "战斗中按 P（或顶栏的背包按钮）打开背包面板   -   点击格子查看详情   -   ESC 返回",
		"en": "Press P in a battle (or the PACK button in the top bar) for the backpack panel   -   click a tile for details   -   ESC goes back"},
	"backpack.empty_desc": {
		"zh": "背包是空的。僵尸掉落的东西（银币 / 肥料袋 / 能量豆）在战斗中先落进背包，一局结束时自动并进仓库，所以战斗外它通常是空的。",
		"en": "The backpack is empty. During a battle the drops (coins, fertilizer, energy beans) land here first and are merged into the warehouse when that battle ends, so outside a battle it is normally empty.",
	},
	"backpack.use_in_battle": {"zh": "在战斗中按 P 使用", "en": "press P in a battle to use it"},

	# ------------------------------------------------------------ HUD buttons
	## Hotkeys stay INSIDE the label ("(R)" / "(P)"), so the Chinese label keeps
	## telling the player which key does the same thing.
	"hud.end_turn": {"zh": "结束回合", "en": "END TURN"},
	"hud.restart": {"zh": "重新开始  (R)", "en": "RESTART  (R)"},
	"hud.main_menu": {"zh": "主菜单  (M)", "en": "MAIN MENU  (M)"},
	"hud.settings": {"zh": "设置", "en": "SETTINGS"},
	"hud.retreat": {"zh": "撤退", "en": "RETREAT"},
	"hud.confirm": {"zh": "确认？", "en": "CONFIRM?"},
	"hud.pack": {"zh": "背包 (P)", "en": "PACK (P)"},
	"hud.close": {"zh": "关闭 (ESC)", "en": "CLOSE (ESC)"},

	# ------------------------------------------------------------ HUD cards
	"hud.card.cost": {"zh": "%d 阳光", "en": "%d sun"},
	"hud.card.sub": {"zh": "%d 阳光，%d 可用", "en": "%d sun, %d free"},
	"hud.card.no_scroll": {"zh": "没有卷轴", "en": "no scroll"},
	## [P31-B] A spirit card has no garden pool to count: its subtitle says what it
	## is instead of "%d free".
	"hud.card.spirit_sub": {"zh": "%d 阳光 · 灵界召唤", "en": "%d sun · spirit summon"},
	"hud.tool.ready": {"zh": "就绪", "en": "READY"},

	# ------------------------------------------------------------ HUD readouts
	"hud.stat.sun": {"zh": "阳光 %d", "en": "SUN %d"},
	"hud.stat.round": {"zh": "回合 %d", "en": "ROUND %d"},
	"hud.stat.bag": {"zh": "背包 %d", "en": "BAG %d"},
	"hud.stat.brain": {"zh": "脑子 %d/%d", "en": "BRAIN %d/%d"},
	"hud.stat.counts": {"zh": "植物 %d   僵尸 %d", "en": "PLANTS %d   ZOMBIES %d"},
	"hud.phase": {"zh": "阶段：%s", "en": "PHASE: %s"},
	## The two row labels of the bottom bar (BalanceUI.ROW_LABEL_* is English-only).
	"hud.row.summons": {"zh": "召唤", "en": "SUMMONS"},
	"hud.row.tools": {"zh": "工具", "en": "TOOLS"},

	# ------------------------------------------------------------ HUD backpack panel
	"hud.pack.title": {"zh": "背包", "en": "BACKPACK"},
	"hud.pack.desc": {
		"zh": "这场战斗里带在身上的东西。点击格子看说明，能量豆只有落到植物上时才会消耗。",
		"en": "Anything carried into this battle. Click a tile to read it; a bean is spent only when it lands on a plant.",
	},
	"hud.pack.pick": {"zh": "点击一个格子查看物品说明。", "en": "Click a tile to read what the item does."},
	"hud.pack.use": {"zh": "使用", "en": "USE"},
	"hud.pack.no_use": {"zh": "这个物品在战斗中不能用", "en": "That item is not usable during a battle"},

	# ------------------------------------------------------------ garden screen
	"garden.title": {"zh": "花园", "en": "GARDEN"},
	## [P95] the third clause names the page bar: the roster is two pages of 16 pots now,
	## and a plant on page 2 is one click away from the page you are standing on.
	"garden.hint": {"zh": "先点右上角道具图标拿在手上，再点一盆植物用下去   -   左上角翻页   -   右键放下   -   ESC 返回主菜单",
		"en": "Pick an item up in the TOP RIGHT bar, then click a plant to use it   -   the TOP LEFT bar turns the page   -   right click drops it   -   ESC goes back"},
	"garden.subtitle": {"zh": "%d 株植物，%d 株受伤，%d 株倒地   -   已保存到 %s",
		"en": "%d plants, %d wounded, %d downed   -   saved to %s"},
	"garden.back": {"zh": "返回", "en": "BACK"},

	# ------------------------------------------------------------ garden tools (P24)
	## [P24] The garden's four care actions are ICON cells now: the picture says what
	## the item IS (watering can / fertilizer bag / EXP potion / talent potion), the
	## name sits under it and the badge in the corner says how many you have. Clicking
	## a cell PICKS THE ITEM UP - the picture then follows the cursor - and the next
	## click on a pot uses it on THAT plant.
	##
	## The long sentence of each action (what it does, what it costs) is the cell's
	## tooltip, and the same sentence is echoed on the status line while the item is
	## in hand - so the wording the old text buttons carried is never lost.
	"garden.tool.water": {"zh": "水壶", "en": "WATERING CAN"},
	"garden.tool.fertilize": {"zh": "肥料", "en": "FERTILIZER"},
	"garden.tool.exp": {"zh": "经验药剂", "en": "EXP POTION"},
	"garden.tool.talent": {"zh": "天赋药剂", "en": "TALENT POTION"},
	"garden.tool.free": {"zh": "免费", "en": "FREE"},
	## Picking an item up and putting it down again. "%s" is the item's own sentence
	## (the same one the cell shows as a tooltip), so both variants carry one "%".
	"garden.tool.armed": {"zh": "%s   -   点一盆植物使用，右键放下",
		"en": "%s   -   click a plant to use it, right click drops it"},
	"garden.tool.cancelled": {"zh": "放下了%s", "en": "Dropped %s"},
	"garden.tool.empty": {"zh": "那盆是空的   -   道具只对有植物的盆有用",
		"en": "That plot is empty   -   items only work on a pot with a plant"},
	"garden.water.heal": {"zh": "浇水   +%d 生命（免费，不限次数）",
		"en": "WATER   +%d hp (free, unlimited)"},
	## [P37-A12] this one goes through Loc.tf, so its literal percent is escaped as
	## "%%"; the no_bag sibling below is a plain Loc.t label and keeps a bare "%".
	"garden.fertilize.bag": {"zh": "施肥   （治疗倒地 +50%% 生命，1 袋，现有 %d）",
		"en": "FERTILIZE   (cure DOWNED, +50%% hp - 1 bag, have %d)"},
	"garden.fertilize.no_bag": {"zh": "施肥   （治疗倒地 +50% 生命，需要 1 袋 - 现在没有）",
		"en": "FERTILIZE   (cure DOWNED, +50% hp - need 1 bag, have 0)"},
	"garden.exp.have": {"zh": "经验药水   （%d 经验，现有 %d）", "en": "EXP POTION   (%d exp, have %d)"},
	"garden.talent.potion": {"zh": "天赋药水   （先选一株植物，才知道是哪种）",
		"en": "TALENT POTION   (select a plant to see which one it needs)"},
	"garden.talent.owned": {"zh": "天赋   （已经有这个天赋）", "en": "TALENT   (already has this talent)"},
	"garden.talent.none": {"zh": "天赋   （这株植物没有天赋）", "en": "TALENT   (no talent for this plant)"},
	"garden.talent.have": {"zh": "天赋   （%s，现有 %d）", "en": "TALENT   (%s, have %d)"},

	# ------------------------------------------------------------ garden plots
	## Balance.GARDEN_STATE_* is English-only, so the words the plots show live here.
	"garden.state.healthy": {"zh": "健康", "en": "HEALTHY"},
	"garden.state.wounded": {"zh": "受伤", "en": "WOUNDED"},
	"garden.state.downed": {"zh": "倒地", "en": "DOWNED"},
	"garden.plot.empty": {"zh": "- 空 -", "en": "- empty -"},
	"garden.plot.slot": {"zh": "格子 %d", "en": "SLOT %d"},
	"garden.plot.empty_tooltip": {"zh": "空格子（第 %d 格）", "en": "Empty plot (slot %d)"},
	"garden.plot.tooltip": {"zh": "%s #%d   L%d %s   %d/%d 生命   %s",
		"en": "%s #%d   L%d %s   %d/%d hp   %s"},

	# ------------------------------------------------------------ garden panel
	"garden.panel.empty_plot": {"zh": "空格子", "en": "EMPTY PLOT"},
	"garden.panel.title": {"zh": "格子 %d   %s", "en": "SLOT %d   %s"},
	## [P25] One label per property, the talent included: it used to hang off the end of
	## the level line, which made that line twice as long as the others.
	"garden.panel.build": {"zh": "L%d   %s   经验 %s", "en": "L%d   %s   exp %s"},
	"garden.panel.talent": {"zh": "%s（%s）", "en": "%s (%s)"},
	"garden.panel.line.type": {"zh": "名称      %s", "en": "TYPE      %s"},
	"garden.panel.line.level": {"zh": "等级      %s", "en": "LEVEL     %s"},
	"garden.panel.line.health": {"zh": "生命      %s", "en": "HEALTH    %s"},
	"garden.panel.line.state": {"zh": "状态      %s", "en": "STATE     %s"},
	"garden.panel.line.talent": {"zh": "天赋      %s", "en": "TALENT    %s"},

	# ------------------------------------------------------------ garden advice
	"garden.advice.empty": {"zh": "这个格子是空的。新植物来自通关奖励。",
		"en": "This plot is empty. New plants come from clearing levels."},
	"garden.advice.downed": {"zh": "倒地：它会自己恢复到 1/10 生命，或者用施肥直接回一半。",
		"en": "DOWNED: it recovers on its own with 1/10 of its health, or FERTILIZE for half."},
	"garden.advice.healthy": {"zh": "状态完美：下一场战斗里它的卡片可以召唤它。",
		"en": "In perfect health: its card can summon it in the next battle."},
	"garden.advice.wounded": {"zh": "受伤：浇水可以回复一半最大生命（免费且不限次数）。",
		"en": "Wounded: WATER restores half of its maximum health (free and unlimited)."},
	"garden.status.downed": {
		"zh": "倒地 - 还有 %s 免费恢复（恢复到 1/10 生命），或者现在施肥回一半（1 袋，现有 %d）。",
		"en": "DOWNED - free recovery in %s (1/10 health), or FERTILIZE now for half (1 bag, have %d).",
	},

	# ------------------------------------------------------------ almanac (P26/P27/P29-UI)
	## The 图鉴 page: three sections over one grid (单位 / 道具 / 关卡), and TWO of them
	## carry a second row of sub-category buttons - 植物 / 僵尸 under UNITS and
	## 道具 / 装备 / 材料 / 货币 under ITEMS. Everything it shows
	## comes from the data the battle itself plays with (data/units/*.csv, data/items.csv
	## and the level pack), so the page can never describe a plant the game does not have.
	"almanac.title": {"zh": "图鉴", "en": "ALMANAC"},
	"almanac.subtitle": {
		"zh": "%d 种植物 / %d 种僵尸 / %d 种道具 / %d 个关卡   -   %s",
		"en": "%d plant(s) / %d zombie(s) / %d item(s) / %d level(s)   -   %s",
	},
	"almanac.hint": {
		"zh": "点击格子看详情；页签切换单位 / 道具 / 关卡，第二行再切子分类（植物 / 僵尸；道具 / 装备 / 材料 / 货币）；一页放不下时用下方按钮或滚轮翻页   -   ESC 返回",
		"en": "Click a cell for its details; the tabs switch UNITS / ITEMS / LEVELS and a second row narrows them (PLANTS / ZOMBIES; TOOLS / EQUIPMENT / MATERIALS / CURRENCY); PREV / NEXT (or the wheel) turn the page   -   ESC goes back",
	},
	"almanac.tab.units": {"zh": "单位", "en": "UNITS"},
	"almanac.tab.items": {"zh": "道具", "en": "ITEMS"},
	"almanac.tab.levels": {"zh": "关卡", "en": "LEVELS"},
	## [P29-UI] The race row inside the UNITS section (was: two of the four tabs).
	"almanac.race.plants": {"zh": "植物", "en": "PLANTS"},
	"almanac.race.zombies": {"zh": "僵尸", "en": "ZOMBIES"},
	## [P29-UI] ... and the group row inside the ITEMS section. The group word is its own
	## (almanac.group.*), NOT the item-kind word (item.kind.*): a scroll is EQUIPMENT
	## here (Balance.ITEM_GROUP_OF_KIND) while its kind line still says 卷轴.
	"almanac.group.tool": {"zh": "道具", "en": "TOOLS"},
	"almanac.group.equip": {"zh": "装备", "en": "EQUIPMENT"},
	"almanac.group.material": {"zh": "材料", "en": "MATERIALS"},
	"almanac.group.currency": {"zh": "货币", "en": "CURRENCY"},
	## [P28] The page bar under the cells. Spelled as words rather than arrow glyphs: the
	## font pairing is only checked for Chinese + Latin, and no other screen uses an arrow.
	## [P42] The page bar belongs to ItemGrid now (the almanac had the first one), so the
	## three strings left the "almanac." namespace: the warehouse, the shop, the backpack
	## page and the in-battle bag all read the SAME labels.
	"grid.page.prev": {"zh": "上一页", "en": "PREV"},
	"grid.page.next": {"zh": "下一页", "en": "NEXT"},
	"grid.page": {"zh": "第 %d / %d 页", "en": "PAGE %d / %d"},
	"almanac.panel.empty_title": {"zh": "没有可看的条目", "en": "NOTHING TO SHOW"},
	"almanac.panel.empty_desc": {
		"zh": "这一页没有数据。植物和僵尸来自 data/units/*.csv，道具来自 data/items.csv，关卡来自关卡目录。",
		"en": "No data on this tab. Plants and zombies come from data/units/*.csv, items from data/items.csv, levels from the level folder.",
	},

	# --- the panel's label lines (same "LABEL   value" shape as the item panel) ------
	"almanac.line.state": {"zh": "状态      %s", "en": "STATE     %s"},
	"almanac.line.hp": {"zh": "生命      %s", "en": "HP        %s"},
	"almanac.line.armor": {"zh": "护甲      %s", "en": "ARMOR     %s"},
	"almanac.line.cost": {"zh": "费用      %s", "en": "COST      %s"},
	"almanac.line.cooldown": {"zh": "冷却      %s", "en": "COOLDOWN  %s"},
	"almanac.line.attack": {"zh": "attack      %s", "en": "ATTACK    %s"},
	## [B24] The two numbers the power estimate is made of. 防御 is a SHARED units.csv column
	## (every faction has a body), so it belongs in the shared line block, not in the brawl's;
	## 战力 is Balance.estimate_power over the same three cells and reads as an integer, which is
	## why both take %d and not the %s the sheet's prose cells use.
	"almanac.line.defence": {"zh": "防御      %d", "en": "DEFENCE   %d"},
	"almanac.line.power": {"zh": "战力      %d", "en": "POWER     %d"},
	"almanac.line.bite": {"zh": "啃食      %s", "en": "BITE      %s"},
	"almanac.line.move": {"zh": "移动      %s", "en": "MOVE      %s"},
	"almanac.line.talent": {"zh": "天赋      %s", "en": "TALENT    %s"},
	"almanac.line.skill": {"zh": "技能      %s", "en": "SKILL     %s"},
	"almanac.line.ultimate": {"zh": "大招      %s", "en": "ULTIMATE  %s"},
	## [P30-A4] the ACTION SEQUENCE line both unit panels show (what is loaded + price)
	"almanac.line.loadout": {"zh": "行动序列  %s", "en": "LOADOUT   %s"},
	"almanac.line.simulation": {"zh": "实装情况  %s", "en": "IN BATTLE %s"},
	## [D78] THE PROJECTILE SUB-ALMANAC (data/projectiles.csv through ProjectileDB): the ONE tab
	## both modes' almanacs share, so its words live in the shared "almanac." domain rather than
	## under either mode's namespace. The sheet writes its own Chinese tokens (直线 / 追踪 / 抛射,
	## and 是 for the two flags); the page prints them in the player's language.
	"almanac.tab.projectiles": {"zh": "射弹", "en": "PROJECTILES"},
	"almanac.shot.straight": {"zh": "直线", "en": "STRAIGHT"},
	"almanac.shot.homing": {"zh": "追踪", "en": "HOMING"},
	"almanac.shot.arc": {"zh": "抛射", "en": "ARC"},
	"almanac.value.default": {"zh": "默认", "en": "DEFAULT"},
	"almanac.value.yes": {"zh": "是", "en": "yes"},
	"almanac.value.no": {"zh": "否", "en": "no"},
	"almanac.value.plant_only": {"zh": "植物", "en": "plants"},
	## [B40] THE SIZE MAGNITUDES. The sheet writes one of these five Chinese words in a row's 体型 cell
	## (data/projectiles.csv, and the same ladder Balance.size_scale() reads), and the page prints the
	## word the player's language has for it - the same three-step pattern 轨迹 above follows.
	"almanac.tier.tiny": {"zh": "微小", "en": "TINY"},
	"almanac.tier.small": {"zh": "小", "en": "SMALL"},
	"almanac.tier.standard": {"zh": "标准", "en": "STANDARD"},
	"almanac.tier.large": {"zh": "大", "en": "LARGE"},
	"almanac.tier.giant": {"zh": "巨大", "en": "GIANT"},
	"almanac.line.trajectory": {"zh": "轨迹      %s", "en": "PATH      %s"},
	"almanac.line.speed": {"zh": "速度      %s", "en": "SPEED     %s"},
	## [B40] The two size facts, printed apart because they answer different questions: 尺寸 is the
	## picture's own pixels (data/projectiles.csv), 体型 is which rung of the ladder that picture is
	## poured into and therefore how big a THING it is on the board.
	"almanac.line.size": {"zh": "尺寸      %s", "en": "SIZE      %s"},
	"almanac.line.tier": {"zh": "体型      %s", "en": "MAGNITUDE %s"},
	"almanac.line.riders": {"zh": "穿透 %d   反弹 %d   溅射 %s", "en": "PIERCE %d   BOUNCE %d   SPLASH %s"},
	"almanac.line.armor_pair": {"zh": "穿甲 %s   穿透伤害 %s", "en": "ARMOR-PIERCE %s   PIERCE-DAMAGE %s"},
	"almanac.line.hit_status": {"zh": "命中状态  %s", "en": "ON HIT    %s"},
	"almanac.line.fired_by": {"zh": "发射单位  %s", "en": "FIRED BY  %s"},
	"almanac.desc.fired_by": {"zh": "发射者  %s", "en": "FIRED BY  %s"},
	"almanac.desc.trajectory": {"zh": "轨迹  %s", "en": "PATH  %s"},
	"almanac.desc.splash": {"zh": "溅射：目标周围也吃伤害", "en": "SPLASH: everything around the target takes it too"},
	"almanac.desc.armor": {"zh": "穿甲：无视护甲", "en": "ARMOR-PIERCE: armor is ignored"},
	"almanac.desc.status": {"zh": "命中附加  %s", "en": "ON HIT  %s"},
	## [B42] THE WHIRLWIND'S OWN KEYS. It is browsed on the 射弹 tab but owns no row of
	## data/projectiles.csv, so nothing here can come from the sheet's labels: 召唤单位 is the twin of
	## 发射单位 (a funnel is called up, not fired), 风环 is the twin of 尺寸 (its size is the ring the
	## sweep judges, in CELLS - the brawl cell in pixels is the window's business, so no px is printed),
	## and 体型 reuses the ladder key above because 大 means the same thing to a shot and to a storm.
	"almanac.tornado.title": {"zh": "旋风", "en": "Whirlwind"},
	"almanac.value.tornado_shape": {"zh": "行走的区域", "en": "walking area"},
	"almanac.value.tornado_owner_cells": {"zh": "%s 走 %.1f 格", "en": "%s walks %.1f cells"},
	"almanac.value.tornado_pace": {"zh": "%.1f 格/秒", "en": "%.1f cells/s"},
	"almanac.value.tornado_ring": {"zh": "直径 %.2f 格（半径 %.2f）", "en": "%.2f cells across (radius %.2f)"},
	"almanac.value.tornado_pulse": {"zh": "每 %.2f 秒 · 普攻的 %d%%", "en": "every %.2fs · %d%% of the blow"},
	"almanac.value.tornado_air": {"zh": "%.1f 格高的空气", "en": "%.1f cells of air"},
	"almanac.value.tornado_painter_frames": {"zh": "序列帧 %d 张 · 每帧 %d 毫秒", "en": "%d FRAMES · %d ms each"},
	"almanac.value.tornado_painter_vector": {"zh": "代码画的柱子", "en": "a column drawn by code"},
	"almanac.line.tornado_shape": {"zh": "形状      %s", "en": "SHAPE     %s"},
	"almanac.line.tornado_owners": {"zh": "召唤单位  %s", "en": "SUMMONER  %s"},
	"almanac.line.tornado_pace": {"zh": "移速      %s", "en": "PACE      %s"},
	"almanac.line.tornado_ring": {"zh": "风环      %s", "en": "RING      %s"},
	"almanac.line.tornado_pulse": {"zh": "每拍      %s", "en": "PULSE     %s"},
	"almanac.line.tornado_air": {"zh": "高度      %s", "en": "AIR       %s"},
	"almanac.line.tornado_painter": {"zh": "画法      %s", "en": "PAINTER   %s"},
	"almanac.desc.tornado_who": {"zh": "召唤者  %s", "en": "SUMMONER  %s"},
	"almanac.desc.tornado_walks": {"zh": "在召唤者身前凭空召出，朝它面对的方向走完表行的距离便散；风环自己没有射程。",
		"en": "Called up in front of its summoner and walked along that body's facing until the distance its row names is gone; the storm owns no range of its own."},
	"almanac.desc.tornado_pays": {"zh": "每一拍对风环里的每个身体收一次接触伤害，伤害是召唤者普攻的一个固定比例。",
		"en": "Each pulse takes one contact blow out of every body inside the ring, worth a fixed share of the summoner's attack."},
	"almanac.desc.tornado_ring": {"zh": "风环画多宽，伤害就判多宽。",
		"en": "The damage is judged exactly as wide as the ring you see."},
	"almanac.line.appears": {"zh": "出场关卡  %s", "en": "APPEARS   %s"},
	"almanac.line.difficulty": {"zh": "难度      %s", "en": "DIFFICULTY %s"},
	"almanac.line.waves": {"zh": "波次      %s", "en": "WAVES      %s"},
	"almanac.line.zombies": {"zh": "僵尸      %s", "en": "ZOMBIES    %s"},
	"almanac.line.last_round": {"zh": "最后回合  %s", "en": "LAST ROUND %s"},
	"almanac.line.sun": {"zh": "起始阳光  %s", "en": "START SUN  %s"},
	"almanac.line.brain": {"zh": "脑子血量  %s", "en": "BRAIN HP   %s"},
	"almanac.line.spawn_cols": {"zh": "入场列    %s", "en": "ENTRY COLS %s"},
	"almanac.line.summons": {"zh": "每回合召唤 %s", "en": "SUMMONS    %s"},
	## [P27] the three lines an item has (see AlmanacView._item_lines)
	"almanac.line.item_kind": {"zh": "分类      %s", "en": "TYPE      %s"},
	"almanac.line.item_value": {"zh": "价值      %s", "en": "VALUE     %s"},
	"almanac.line.item_plant": {"zh": "对应植物  %s", "en": "PLANT     %s"},

	# --- the values those lines carry ------------------------------------------------
	"almanac.value.none": {"zh": "—", "en": "—"},
	"almanac.value.rounds": {"zh": "%d 回合", "en": "%d round(s)"},
	"almanac.value.per_cell": {"zh": "每 %d 回合 1 格", "en": "1 cell per %d round(s)"},
	"almanac.value.per_round": {"zh": "%d 张/回合", "en": "%d per round"},
	"almanac.value.zombies": {"zh": "%d 只", "en": "%d zombie(s)"},
	"almanac.value.waves": {"zh": "%d 波 / %d 个出怪回合", "en": "%d wave(s) / %d spawn round(s)"},
	"almanac.value.summonable": {"zh": "可以召唤", "en": "summonable"},
	"almanac.value.not_implemented": {"zh": "尚未实装", "en": "not implemented yet"},
	"almanac.value.broken": {"zh": "数据错误", "en": "BROKEN"},
	## A zombie whose sheet sentence names a mechanic the battle does not simulate yet:
	## the cell is dimmed and says so, and the panel names the mechanics.
	"almanac.value.shown_only": {"zh": "部分未实装", "en": "partly shown only"},
	## The sheet has no picture that resolves for this id yet: the cell draws the flat
	## placeholder shape (plants) or the base zombie (zombies), and filling the row's svg
	## cell is what removes the label once the sprite exists.
	"almanac.value.no_art": {"zh": "暂无贴图", "en": "no art yet"},
	"almanac.value.shown_only_flags": {"zh": "未实装：%s", "en": "not simulated: %s"},
	"almanac.value.simulated_all": {"zh": "全部已实装", "en": "all simulated"},
	## [P30-A4] The loadout line's values: one sheet skill with its AP price, and the
	## zombie trio whose prices live in Balance (placeholders must match across languages).
	"almanac.value.loadout_skill": {"zh": "%s (%d AP)", "en": "%s (%d AP)"},
	## [P30-B] The same line's ULTIMATE half: name, the global charge rule (+N per
	## charge event, auto-fire at cap) and what fills the bar (the sheet's 大招充能).
	"almanac.value.loadout_ult": {"zh": "大招 %s (充能 +%d/%d · 每次%s)",
		"en": "ULT %s (charge +%d/%d · per %s)"},
	"almanac.value.loadout_sep": {"zh": " · ", "en": " · "},
	"ult.charge.cast": {"zh": "施放", "en": "cast"},
	"ult.charge.hit": {"zh": "受击", "en": "hit"},
	"almanac.value.loadout_zombie": {"zh": "移动 (%d AP) · 啃咬 (%d AP) · 啃脑 (%d AP)",
		"en": "Move (%d AP) · Bite (%d AP) · Eat brain (%d AP)"},
	## [P27] The ITEMS tab's two states: the battle can hand the item out (it has a
	## Balance.ITEM_DEFS row, which the warehouse / shop / rewards read), or the sheet
	## registered it for the page only.
	"almanac.value.wired": {"zh": "战斗内可用", "en": "in use in battle"},
	"almanac.value.sheet_only": {"zh": "仅图鉴", "en": "almanac only"},
	## [P27] An item's 价值, said in the unit that means something for its kind (see
	## AlmanacView._item_value_line). The bare number is what "other" kinds get.
	"almanac.item.value.coin": {"zh": "卖出 %d", "en": "sells for %d"},
	"almanac.item.value.scroll": {"zh": "耐久 %d 次", "en": "%d use(s)"},
	"almanac.item.value.exp": {"zh": "%d 经验", "en": "%d exp"},
	"almanac.value.from_code": {
		"zh": "（代码兜底）",
		"en": " (from Balance, not the sheet)",
	},

	# --- the description block -------------------------------------------------------
	## [P113] The two human labels (units.csv range_type / role) as ONE leading prose line, shown
	## above the skill / special / ultimate text on both almanacs' unit pages. Two %s, same count in
	## each language; the values are the localized words from loc_names (近战/远程, 输出/...). It sits
	## in the prose block, not the fixed-9 line list, because those rows are full and a tenth would be
	## dropped (almanac.gd silently clips past ALMANAC_PANEL_LINES) - the description area wraps instead.
	"almanac.desc.unit_tags": {"zh": "距离  %s   定位  %s", "en": "RANGE  %s   ROLE  %s"},
	"almanac.desc.skill": {"zh": "技能  %s", "en": "SKILL     %s"},
	"almanac.desc.ultimate": {"zh": "大招  %s", "en": "ULTIMATE  %s"},
	"almanac.desc.special": {"zh": "特殊  %s", "en": "SPECIAL   %s"},
	## [P26] The EFFECTIVE per-level numbers of a plant (sheet cell or code default -
	## the page shows what the game applies, not where it was written down).
	"almanac.desc.growth": {"zh": "成长  %s", "en": "GROWTH    %s"},
	"almanac.growth.hp": {"zh": "生命 +%d%%/级", "en": "hp +%d%% per level"},
	"almanac.growth.skill": {"zh": "技能 +%d%%/级", "en": "skill +%d%% per level"},
	"almanac.growth.talent": {"zh": "天赋 +%d%%", "en": "talent +%d%%"},
	## How much of the brain one zombie type eats per bite (the sheet's 啃脑伤害).
	"almanac.desc.brain": {"zh": "啃脑  %d/次", "en": "BRAIN     %d per bite"},
	"almanac.desc.not_simulated": {
		"zh": "（%s 这些机制目前只在图鉴里说明，战斗尚未实装）",
		"en": "(the battle does not simulate %s yet - the sheet is the only place they exist)",
	},
	"almanac.desc.plan": {"zh": "出怪计划  %s", "en": "SPAWN PLAN  %s"},
	"almanac.desc.types": {"zh": "僵尸种类  %s", "en": "TYPES       %s"},
	"almanac.desc.rewards": {"zh": "每次通关  %s", "en": "PER CLEAR   %s"},
	"almanac.desc.first_clear": {"zh": "首次通关  %s", "en": "FIRST CLEAR %s"},
	"almanac.desc.warnings": {"zh": "数据警告  %s", "en": "WARNINGS    %s"},
	## [P27] The two lines of an item's description: what it is for (the language layer's
	## own hint, the same words the warehouse panel shows) and which file its picture
	## came from - the sheet's svg column, or Balance's icon table as the fallback.
	"almanac.desc.usage": {"zh": "用途  %s", "en": "USE   %s"},
	"almanac.desc.art": {"zh": "贴图  %s", "en": "ART   %s"},
	"almanac.desc.broken": {
		"zh": "这个关卡文件无法开始：%s",
		"en": "This level file cannot be started: %s",
	},
}
