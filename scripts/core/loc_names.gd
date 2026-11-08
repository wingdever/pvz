class_name LocNames
extends RefCounted
## [P20] Display NAMES: the words a player reads for a thing, not the sentences
## around it. Units, plants, items, tools, talents, rarity and difficulty.
##
## Key shape is "<domain>.<id>", where <id> is the SAME id the code already uses
## (Balance.PLANT_DEFS / ITEM_DEFS / TOOL_DEFS keys, Difficulty.ORDER), so adding a
## plant later means adding one row here and nothing else.
##
## Placeholders: "%%" is a literal percent sign, the "%d" in front of it is the
## number Loc.tf passes in. Both variants must keep the same specifiers in the
## same order - Loc.self_check() enforces that.

const TABLE := {
	# ------------------------------------------------------------ plants / units
	## [P26] One row per row of data/units/plants.csv and data/units/zombies.csv, because
	## a NAME is what the language layer owns (the sheets carry the design's own wording
	## and are the fall-back; see PlantDB.name / ZombieDB.name). That also gives every
	## unit its official English name, which the sheets do not carry: their name
	## column is the ID the code uses.
	"plant.peashooter": {"zh": "豌豆射手", "en": "Peashooter"},
	"plant.sunflower": {"zh": "向日葵", "en": "Sunflower"},
	"plant.wallnut": {"zh": "坚果墙", "en": "Wall-nut"},
	"plant.repeater": {"zh": "双发射手", "en": "Repeater"},
	"plant.split_pea": {"zh": "裂荚射手", "en": "Split Pea"},
	"plant.gatling_pea": {"zh": "机枪射手", "en": "Gatling Pea"},
	"plant.threepeater": {"zh": "三线射手", "en": "Threepeater"},
	"plant.snow_pea": {"zh": "寒冰射手", "en": "Snow Pea"},
	"plant.cherry_bomb": {"zh": "樱桃炸弹", "en": "Cherry Bomb"},
	"plant.potato_mine": {"zh": "土豆地雷", "en": "Potato Mine"},
	"plant.chomper": {"zh": "大嘴花", "en": "Chomper"},
	"plant.tallnut": {"zh": "高坚果", "en": "Tall-nut"},
	"plant.jalapeno": {"zh": "火爆辣椒", "en": "Jalapeno"},
	"plant.squash": {"zh": "窝瓜", "en": "Squash"},
	"plant.mushroom_sun": {"zh": "阳光菇", "en": "Sun-shroom"},
	"plant.hypno_shroom": {"zh": "魅惑菇", "en": "Hypno-shroom"},
	"plant.ice_shroom": {"zh": "寒冰菇", "en": "Ice-shroom"},
	## [P34] The three batch-1 plants whose sheet rows had no name here yet: the
	## almanac / HUD fall back to the sheet's Chinese wording when a key is missing, so
	## in the English UI these three would have stayed 双生向日葵 / 小喷菇 / 大喷菇.
	"plant.twin_sunflower": {"zh": "双生向日葵", "en": "Twin Sunflower"},
	"plant.puff_shroom": {"zh": "小喷菇", "en": "Puff-shroom"},
	"plant.fume_shroom": {"zh": "大喷菇", "en": "Fume-shroom"},
	## [P58] The shroom line's third card. The board names a plant through this key
	## (setup_shooter hands set_display_name a Loc path), so the row belongs here even
	## though units.csv 名称 carries the same three characters for the roster line.
	"plant.gloom_shroom": {"zh": "忧郁菇", "en": "Gloom-shroom"},
	## [P59] The shroom line's fourth card, same two places: this key names the plant on
	## the board, units.csv 胆小菇 names it in the roster line.
	"plant.scaredy_shroom": {"zh": "胆小菇", "en": "Scaredy-shroom"},
	## [P31-B] The spirit copy's card: NO units.csv row on purpose (it is a copy,
	## not a breed), so Balance.plant_name() reaches this entry through its
	## Loc.t("plant.<id>") fall-back. Naming rule (aligned this round): the
	## SUMMONED plant is just the plant ("豌豆射手"), the 灵界/花园 wording lives
	## on the SCROLL name only - the board never shows a "灵界" prefix.
	"plant.spirit_peashooter": {"zh": "豌豆射手", "en": "Peashooter"},
	## [P49] The lobbers (plants/pult family): the English names keep the hyphenated
	## "-pult" the original game uses, the Chinese keeps 投手 as the family word.
	## [P51] The cabbage joins them as the family's cheap end; the naming rule is the same.
	"plant.cabbage_pult": {"zh": "卷心菜投手", "en": "Cabbage-pult"},
	"plant.melon_pult": {"zh": "西瓜投手", "en": "Melon-pult"},
	"plant.winter_melon": {"zh": "冰西瓜投手", "en": "Winter-melon"},
	## [P63] The sixth family's first card: the board names it through this key and the
	## roster line names it through units.csv 地刺. The English is the original game's own
	## single word - there is no hyphenated family word to keep here, because 地刺 is not a
	## "-shroom" or a "-pult"; it is the spike itself.
	"plant.spikeweed": {"zh": "地刺", "en": "Spikeweed"},
	## [B30] The lawn's first healer, and the first card whose whole job is not damage. The
	## English keeps the plant's own picture (a sunflower that throws sunshine) rather than
	## inventing a family word: 暖阳葵 is 向日葵 + 暖, so "Warm Sunflower" says the same thing.
	"plant.warm_sunflower": {"zh": "暖阳葵", "en": "Warm Sunflower"},

	"unit.zombie": {"zh": "普通僵尸", "en": "Zombie"},
	"unit.zombie_flag": {"zh": "旗帜僵尸", "en": "Flag Zombie"},
	"unit.zombie_cone": {"zh": "路障僵尸", "en": "Conehead Zombie"},
	"unit.zombie_bucket": {"zh": "铁桶僵尸", "en": "Buckethead Zombie"},
	"unit.zombie_polevault": {"zh": "撑杆僵尸", "en": "Pole Vaulting Zombie"},
	"unit.zombie_newspaper": {"zh": "读报僵尸", "en": "Newspaper Zombie"},
	"unit.zombie_screendoor": {"zh": "铁门僵尸", "en": "Screen Door Zombie"},
	"unit.zombie_football": {"zh": "橄榄球僵尸", "en": "Football Zombie"},
	"unit.zombie_dancer": {"zh": "舞王僵尸", "en": "Dancing Zombie"},
	"unit.snow_goblin": {"zh": "雪人僵尸", "en": "Zombie Yeti"},
	"unit.zombie_gargantuar": {"zh": "巨人僵尸", "en": "Gargantuar"},
	"unit.zombie_imp": {"zh": "小鬼僵尸", "en": "Imp"},
	"unit.zombie_balloon": {"zh": "气球僵尸", "en": "Balloon Zombie"},
	"unit.zombie_angry": {"zh": "愤怒僵尸", "en": "Angry Zombie"},
	## The base you defend: the label drawn in the brain zone at the left edge of
	## the lawn (Grid.LawnBackdrop._draw) and the "BRAIN %d/%d" top bar readout.
	## 脑子 is the wording the official Chinese PvZ uses ("僵尸吃掉了你的脑子!"),
	## and it is what LocUi's hud.stat.brain says, so the two agree.
	"unit.brain": {"zh": "脑子", "en": "BRAIN"},
	## [B5] THE HUMAN PIECES (data/units/humans.csv, read by PieceDB). A domain of their own
	## ("piece.<id>") rather than "unit.<id>": the brawl's champions are not garden plants and
	## not zombies, and a name is what the language layer owns - the sheet carries the design's
	## own wording (名称) and is only the fall-back, exactly as it is for the other two rosters.
	"piece.militia": {"zh": "民兵", "en": "Militia"},
	"piece.archer": {"zh": "弓手", "en": "Archer"},
	"piece.shieldman": {"zh": "盾卫", "en": "Shieldman"},
	"piece.knight": {"zh": "骑士", "en": "Knight"},
	"piece.gunner": {"zh": "火枪手", "en": "Gunner"},
	"piece.captain": {"zh": "队长", "en": "Captain"},
	## [P110f] THE MONSTER FACTION (data/units/monsters.csv, still read by PieceDB - a brawl
	## piece is a brawl piece whatever race it belongs to). The race is brawl-only, which is
	## what the 0 / 1 in their units.csv turned / timed cells says.
	"piece.laser_eye": {"zh": "激光眼", "en": "Laser Eye"},
	"piece.flame_eye": {"zh": "火焰眼", "en": "Flame Eye"},
	"piece.laser_eye_tower": {"zh": "激光眼球塔", "en": "Laser Eye Tower"},
	"piece.flame_eye_tower": {"zh": "火焰眼球塔", "en": "Flame Eye Tower"},
	"piece.green_slim": {"zh": "绿史莱姆", "en": "Green Slim"},
	## [B14] 雷角兽: the brawl's first ULTIMATE piece - its row's 大招持续 cell is what the energy bar
	## fills towards (BRAWL.md §8.13).
	"piece.thundercorn": {"zh": "雷角兽", "en": "Thundercorn"},
	## [B19] the first of a third faction (the machines) - a shell that arcs over the front
	## row and detonates where it lands (docs/prompt/BRAWL.md §8.17).
	"piece.lobber": {"zh": "抛射炮", "en": "Lobber"},
	## [B38] the first of a fourth faction (the pokemon): a body that bumps what it can reach, and
	## whose full bar is a LEAP rather than a held beam (data/units/pokemon.csv 大招范围).
	"piece.snorlax": {"zh": "卡比兽", "en": "Snorlax"},
	## [B39] the first of a fifth faction (the animals): its strike is not a blow but a WHIRLWIND that
	## walks a distance and pays contact damage along the line (data/units/animals.csv 旋风).
	"piece.bird": {"zh": "鸟怪", "en": "Bird"},

	# ------------------------------------------------------------ items
	## [P31-B] Scroll naming aligned: every scroll is an "xxx花园卷轴" or an
	## "xxx灵界卷轴" - the source word comes AFTER the plant, so the two families
	## sort together and the plant keeps one name everywhere.
	"item.scroll_peashooter": {"zh": "豌豆射手花园卷轴", "en": "Peashooter Garden Scroll"},
	"item.scroll_sunflower": {"zh": "向日葵花园卷轴", "en": "Sunflower Garden Scroll"},
	"item.scroll_wallnut": {"zh": "坚果墙花园卷轴", "en": "Wall-nut Garden Scroll"},
	"item.scroll_spirit_peashooter": {"zh": "豌豆射手灵界卷轴", "en": "Peashooter Spirit Scroll"},
	## [P34] The first batch of plants' garden scrolls (same wording rule: the plant
	## name, then 花园卷轴 / "Garden Scroll").
	"item.scroll_repeater": {"zh": "双发射手花园卷轴", "en": "Repeater Garden Scroll"},
	"item.scroll_split_pea": {"zh": "裂荚射手花园卷轴", "en": "Split Pea Garden Scroll"},
	"item.scroll_gatling_pea": {"zh": "机枪射手花园卷轴", "en": "Gatling Pea Garden Scroll"},
	"item.scroll_threepeater": {"zh": "三线射手花园卷轴", "en": "Threepeater Garden Scroll"},
	"item.scroll_snow_pea": {"zh": "寒冰射手花园卷轴", "en": "Snow Pea Garden Scroll"},
	"item.scroll_twin_sunflower": {"zh": "双生向日葵花园卷轴", "en": "Twin Sunflower Garden Scroll"},
	"item.scroll_puff_shroom": {"zh": "小喷菇花园卷轴", "en": "Puff-shroom Garden Scroll"},
	"item.scroll_fume_shroom": {"zh": "大喷菇花园卷轴", "en": "Fume-shroom Garden Scroll"},
	## [P58] Batch 4's card (see Balance.ITEM_DEFS for why a plant without a scroll is a
	## plant no battle can summon).
	"item.scroll_gloom_shroom": {"zh": "忧郁菇花园卷轴", "en": "Gloom-shroom Garden Scroll"},
	## [P59] And the scaredy one's, same gate: no scroll, no card, no battle.
	"item.scroll_scaredy_shroom": {"zh": "胆小菇花园卷轴", "en": "Scaredy-shroom Garden Scroll"},
	"item.scroll_tallnut": {"zh": "高坚果花园卷轴", "en": "Tall-nut Garden Scroll"},
	## [P39] Batch 2's scrolls so far: the swallower, then the two plants that spend
	## themselves. No 一次性 potion - the item sheet has no potion row for them (P100).
	"item.scroll_chomper": {"zh": "大嘴花花园卷轴", "en": "Chomper Garden Scroll"},
	"item.scroll_squash": {"zh": "窝瓜花园卷轴", "en": "Squash Garden Scroll"},
	"item.scroll_jalapeno": {"zh": "火爆辣椒花园卷轴", "en": "Jalapeno Garden Scroll"},
	## [P39] The 一次性 family's other two cards (see Balance.ITEM_DEFS).
	"item.scroll_potato_mine": {"zh": "土豆地雷花园卷轴", "en": "Potato Mine Garden Scroll"},
	"item.scroll_cherry_bomb": {"zh": "樱桃炸弹花园卷轴", "en": "Cherry Bomb Garden Scroll"},
	## [P43] The family's fifth and last card (see Balance.ITEM_DEFS).
	"item.scroll_ice_shroom": {"zh": "寒冰菇花园卷轴", "en": "Ice-shroom Garden Scroll"},
	## [P49] The two lobbers' scrolls (see Balance.ITEM_DEFS).
	## [P51] The third lobber's, same wording (see Balance.ITEM_DEFS).
	"item.scroll_cabbage_pult": {"zh": "卷心菜投手花园卷轴", "en": "Cabbage-pult Garden Scroll"},
	"item.scroll_melon_pult": {"zh": "西瓜投手花园卷轴", "en": "Melon-pult Garden Scroll"},
	"item.scroll_winter_melon": {"zh": "冰西瓜投手花园卷轴", "en": "Winter-melon Garden Scroll"},
	## [P63] The spike's scroll. Lawn_1_2 hands it out in `first_clear` and drops the plant
	## in the same table, which is P44's rule for a scroll (the level that gives the paper is
	## the level that grows the pot); that level already teaches the same idea with a
	## potato mine waiting in the ground for a walker.
	"item.scroll_spikeweed": {"zh": "地刺花园卷轴", "en": "Spikeweed Garden Scroll"},
	## [B30] The healer's scroll - the card's other half (no scroll, no summon). NO level
	## hands it out yet: chapter 1's 24 lawns already each grant one of the 24 cards that
	## existed before this batch, so the reward is a content decision for a lawn that does
	## not exist yet, not a wiring gap.
	"item.scroll_warm_sunflower": {"zh": "暖阳葵花园卷轴", "en": "Warm Sunflower Garden Scroll"},
	"item.coin_silver": {"zh": "银币", "en": "Silver Coin"},
	"item.coin_gold": {"zh": "金币", "en": "Gold Coin"},
	"item.coin_diamond": {"zh": "钻石", "en": "Diamond"},
	"item.fertilizer": {"zh": "肥料袋", "en": "Fertilizer Bag"},
	"item.energy_bean": {"zh": "能量豆", "en": "Energy Bean"},
	"item.potion_peashooter": {"zh": "豌豆射手药水", "en": "Peashooter Potion"},
	"item.potion_sunflower": {"zh": "向日葵药水", "en": "Sunflower Potion"},
	"item.potion_wallnut": {"zh": "坚果墙药水", "en": "Wall-nut Potion"},
	## [P34] The batch-1 talent potions (the item NAME on the tile; the talent NAME
	## below is what the garden's talent row and the almanac call the perk).
	"item.potion_repeater": {"zh": "双发射手药水", "en": "Repeater Potion"},
	"item.potion_split_pea": {"zh": "裂荚射手药水", "en": "Split Pea Potion"},
	"item.potion_gatling_pea": {"zh": "机枪射手药水", "en": "Gatling Pea Potion"},
	"item.potion_threepeater": {"zh": "三线射手药水", "en": "Threepeater Potion"},
	"item.potion_snow_pea": {"zh": "寒冰射手药水", "en": "Snow Pea Potion"},
	"item.potion_twin_sunflower": {"zh": "双生向日葵药水", "en": "Twin Sunflower Potion"},
	"item.potion_puff_shroom": {"zh": "小喷菇药水", "en": "Puff-shroom Potion"},
	"item.potion_fume_shroom": {"zh": "大喷菇药水", "en": "Fume-shroom Potion"},
	## [P58] Its bottle, so the shroom line reads as one row of bottles too.
	"item.potion_gloom_shroom": {"zh": "忧郁菇药水", "en": "Gloom-shroom Potion"},
	## [P59] The line's fourth bottle.
	"item.potion_scaredy_shroom": {"zh": "胆小菇药水", "en": "Scaredy-shroom Potion"},
	"item.potion_tallnut": {"zh": "高坚果药水", "en": "Tall-nut Potion"},
	"item.potion_chomper": {"zh": "大嘴花药水", "en": "Chomper Potion"},
	## [P49] The lobbers' potions (see Balance.ITEM_DEFS).
	## [P51] The cabbage's with them, so the family's three bottles read as one row.
	"item.potion_cabbage_pult": {"zh": "卷心菜投手药水", "en": "Cabbage-pult Potion"},
	"item.potion_melon_pult": {"zh": "西瓜投手药水", "en": "Melon-pult Potion"},
	"item.potion_winter_melon": {"zh": "冰西瓜投手药水", "en": "Winter-melon Potion"},
	## [P63] The spike's bottle: 技能威力, because a spikeweed's whole job is its skill
	## value - and a plant with a skill number gets a skill potion (P100's derivation).
	"item.potion_spikeweed": {"zh": "地刺药水", "en": "Spikeweed Potion"},
	## [B30] The healer's bottle, and it follows P100's derivation like every other one:
	## 暖阳葵 has a skill NUMBER (its attack, which is what the mend is worth), so the dose
	## lifts 技能威力 - a bigger bottle, not a thicker body.
	"item.potion_warm_sunflower": {"zh": "暖阳葵药水", "en": "Warm Sunflower Potion"},
	"item.exp_potion": {"zh": "经验药水", "en": "EXP Potion"},
	# ------------------------------------------------------------ P95: spirit scrolls + plant chests
	## [P95] TWO families, both generated by the same rule and both keyed by PLANT, so a
	## name can never drift from the plant it belongs to: one 灵界卷轴 per plant (the sheet's
	## scroll_spirit_<plant> rows) and one 植物宝箱 per plant (the sheet's plant_chest_<plant>
	## rows). The sheet carries the CHINESE cell and the id; these are what the ENGLISH
	## screen shows, which is why a sheet-only row still needs a key here.
	"item.scroll_spirit_sunflower": {"zh": "向日葵灵界卷轴", "en": "Sunflower Spirit Scroll"},
	"item.scroll_spirit_wallnut": {"zh": "坚果墙灵界卷轴", "en": "Wall-nut Spirit Scroll"},
	"item.scroll_spirit_repeater": {"zh": "双发射手灵界卷轴", "en": "Repeater Spirit Scroll"},
	"item.scroll_spirit_split_pea": {"zh": "裂荚射手灵界卷轴", "en": "Split Pea Spirit Scroll"},
	"item.scroll_spirit_gatling_pea": {"zh": "机枪射手灵界卷轴", "en": "Gatling Pea Spirit Scroll"},
	"item.scroll_spirit_threepeater": {"zh": "三线射手灵界卷轴", "en": "Threepeater Spirit Scroll"},
	"item.scroll_spirit_snow_pea": {"zh": "寒冰射手灵界卷轴", "en": "Snow Pea Spirit Scroll"},
	"item.scroll_spirit_twin_sunflower": {"zh": "双生向日葵灵界卷轴", "en": "Twin Sunflower Spirit Scroll"},
	"item.scroll_spirit_puff_shroom": {"zh": "小喷菇灵界卷轴", "en": "Puff-shroom Spirit Scroll"},
	"item.scroll_spirit_fume_shroom": {"zh": "大喷菇灵界卷轴", "en": "Fume-shroom Spirit Scroll"},
	"item.scroll_spirit_tallnut": {"zh": "高坚果灵界卷轴", "en": "Tall-nut Spirit Scroll"},
	"item.scroll_spirit_chomper": {"zh": "大嘴花灵界卷轴", "en": "Chomper Spirit Scroll"},
	"item.scroll_spirit_squash": {"zh": "窝瓜灵界卷轴", "en": "Squash Spirit Scroll"},
	"item.scroll_spirit_jalapeno": {"zh": "火爆辣椒灵界卷轴", "en": "Jalapeno Spirit Scroll"},
	"item.scroll_spirit_potato_mine": {"zh": "土豆地雷灵界卷轴", "en": "Potato Mine Spirit Scroll"},
	"item.scroll_spirit_cherry_bomb": {"zh": "樱桃炸弹灵界卷轴", "en": "Cherry Bomb Spirit Scroll"},
	"item.scroll_spirit_ice_shroom": {"zh": "寒冰菇灵界卷轴", "en": "Ice-shroom Spirit Scroll"},
	"item.scroll_spirit_cabbage_pult": {"zh": "卷心菜投手灵界卷轴", "en": "Cabbage-pult Spirit Scroll"},
	"item.scroll_spirit_melon_pult": {"zh": "西瓜投手灵界卷轴", "en": "Melon-pult Spirit Scroll"},
	"item.scroll_spirit_winter_melon": {"zh": "冰西瓜投手灵界卷轴", "en": "Winter-melon Spirit Scroll"},
	"item.scroll_spirit_gloom_shroom": {"zh": "忧郁菇灵界卷轴", "en": "Gloom-shroom Spirit Scroll"},
	"item.scroll_spirit_scaredy_shroom": {"zh": "胆小菇灵界卷轴", "en": "Scaredy-shroom Spirit Scroll"},
	"item.scroll_spirit_spikeweed": {"zh": "地刺灵界卷轴", "en": "Spikeweed Spirit Scroll"},
	## [B30] The healer's spirit copy (P95: every plant has one).
	"item.scroll_spirit_warm_sunflower": {"zh": "暖阳葵灵界卷轴", "en": "Warm Sunflower Spirit Scroll"},
	## The chest a first clear hands over (Rewards pays the ITEM; Game opens it in the
	## warehouse). The name says what is inside, which is the whole point of the mark
	## drawn on the chest's own icon.
	"item.plant_chest_peashooter": {"zh": "豌豆射手植物宝箱", "en": "Peashooter Plant Chest"},
	"item.plant_chest_sunflower": {"zh": "向日葵植物宝箱", "en": "Sunflower Plant Chest"},
	"item.plant_chest_wallnut": {"zh": "坚果墙植物宝箱", "en": "Wall-nut Plant Chest"},
	"item.plant_chest_repeater": {"zh": "双发射手植物宝箱", "en": "Repeater Plant Chest"},
	"item.plant_chest_split_pea": {"zh": "裂荚射手植物宝箱", "en": "Split Pea Plant Chest"},
	"item.plant_chest_gatling_pea": {"zh": "机枪射手植物宝箱", "en": "Gatling Pea Plant Chest"},
	"item.plant_chest_threepeater": {"zh": "三线射手植物宝箱", "en": "Threepeater Plant Chest"},
	"item.plant_chest_snow_pea": {"zh": "寒冰射手植物宝箱", "en": "Snow Pea Plant Chest"},
	"item.plant_chest_twin_sunflower": {"zh": "双生向日葵植物宝箱", "en": "Twin Sunflower Plant Chest"},
	"item.plant_chest_puff_shroom": {"zh": "小喷菇植物宝箱", "en": "Puff-shroom Plant Chest"},
	"item.plant_chest_fume_shroom": {"zh": "大喷菇植物宝箱", "en": "Fume-shroom Plant Chest"},
	"item.plant_chest_tallnut": {"zh": "高坚果植物宝箱", "en": "Tall-nut Plant Chest"},
	"item.plant_chest_chomper": {"zh": "大嘴花植物宝箱", "en": "Chomper Plant Chest"},
	"item.plant_chest_squash": {"zh": "窝瓜植物宝箱", "en": "Squash Plant Chest"},
	"item.plant_chest_jalapeno": {"zh": "火爆辣椒植物宝箱", "en": "Jalapeno Plant Chest"},
	"item.plant_chest_potato_mine": {"zh": "土豆地雷植物宝箱", "en": "Potato Mine Plant Chest"},
	"item.plant_chest_cherry_bomb": {"zh": "樱桃炸弹植物宝箱", "en": "Cherry Bomb Plant Chest"},
	"item.plant_chest_ice_shroom": {"zh": "寒冰菇植物宝箱", "en": "Ice-shroom Plant Chest"},
	"item.plant_chest_cabbage_pult": {"zh": "卷心菜投手植物宝箱", "en": "Cabbage-pult Plant Chest"},
	"item.plant_chest_melon_pult": {"zh": "西瓜投手植物宝箱", "en": "Melon-pult Plant Chest"},
	"item.plant_chest_winter_melon": {"zh": "冰西瓜投手植物宝箱", "en": "Winter-melon Plant Chest"},
	"item.plant_chest_gloom_shroom": {"zh": "忧郁菇植物宝箱", "en": "Gloom-shroom Plant Chest"},
	"item.plant_chest_scaredy_shroom": {"zh": "胆小菇植物宝箱", "en": "Scaredy-shroom Plant Chest"},
	"item.plant_chest_spikeweed": {"zh": "地刺植物宝箱", "en": "Spikeweed Plant Chest"},
	## [B30] And the chest that would carry the healer to a lawn (see the scroll note above:
	## no first clear pays this one out yet).
	"item.plant_chest_warm_sunflower": {"zh": "暖阳葵植物宝箱", "en": "Warm Sunflower Plant Chest"},

	# ------------------------------------------------------------ item kinds (P22)
	## The TYPE line of the detail panel on the warehouse / shop screens. Read
	## through Balance.item_kind_label(), which keeps one literal key per branch.
	"item.kind.scroll": {"zh": "卷轴", "en": "SCROLL"},
	"item.kind.coin": {"zh": "钱币", "en": "COIN"},
	"item.kind.fertilizer": {"zh": "肥料", "en": "FERTILIZER"},
	"item.kind.battle": {"zh": "战斗道具", "en": "BATTLE ITEM"},
	"item.kind.exp": {"zh": "经验", "en": "EXP"},
	"item.kind.talent": {"zh": "天赋药剂", "en": "TALENT POTION"},
	"item.kind.plant": {"zh": "植物", "en": "PLANT"},
	## [P95] the chest a cleared level hands over (Balance.ITEM_KIND_PLANT_CHEST)
	"item.kind.plant_chest": {"zh": "植物宝箱", "en": "PLANT CHEST"},
	"item.kind.other": {"zh": "道具", "en": "ITEM"},

	# ------------------------------------------------------------ item hints (P22)
	## What an item is FOR, shown in the detail panel when a tile is clicked.
	## Balance.item_hint() looks for "item.hint.<id>" first and then for the shared
	## "item.hint.kind.<kind>", so three scrolls need one line, not three.
	##
	## Deliberately NO %-placeholders in here: Balance.item_hint() reads these with
	## Loc.t(), and a stray "%d" would reach the screen unformatted. The two numbers
	## that appear in the prose below are quoted from Balance (ENERGY_BEAN_HITS = 10,
	## EXP_POTION_AMOUNT = 50) - keep them in step, exactly like the "+50% hp" line
	## of garden.fertilize.bag in LocUi.
	"item.hint.kind.scroll": {
		"zh": "解锁对应的植物卡，召唤那张卡时需要它。",
		"en": "Unlocks its plant card: summoning that card needs the scroll.",
	},
	"item.hint.kind.coin": {
		"zh": "在仓库里出售之后才会变成金钱，捡到时不会自动换算。",
		"en": "Only SELLING it in the warehouse turns it into money.",
	},
	"item.hint.fertilizer": {
		"zh": "在花园里对倒地的植物使用：立刻站起来并回复一半生命。",
		"en": "Use it in the GARDEN on a DOWNED plant: it stands up with half its health.",
	},
	"item.hint.energy_bean": {
		"zh": "在战斗中对场上的植物使用，立刻结算它的技能 10 次。",
		"en": "Use it on a plant during a battle to resolve its skill 10 times at once.",
	},
	"item.hint.exp_potion": {
		"zh": "在花园里对选中的植物使用，+50 经验。练哪一株由你决定。",
		"en": "Use it in the GARDEN on the plant you pick: +50 exp.",
	},
	"item.hint.kind.talent": {
		"zh": "在花园里对对应的植物使用，永久强化它的天赋。同一个天赋不能叠加。",
		"en": "Use it in the GARDEN on its plant to permanently boost its talent (never stacks).",
	},

	# ------------------------------------------------------------ tools
	"tool.shovel": {"zh": "铲子", "en": "Shovel"},
	"tool.glove": {"zh": "手套", "en": "Glove"},
	"tool.hammer": {"zh": "锤子", "en": "Hammer"},

	# ------------------------------------------------------------ talent potions
	## The tier is part of the name ("I" = tier 1), same as the English wording.
	"talent.potion_peashooter": {"zh": "硬豌豆 I", "en": "Hard Pea I"},
	"talent.potion_sunflower": {"zh": "大阳光 I", "en": "Big Sun I"},
	"talent.potion_wallnut": {"zh": "厚坚果 I", "en": "Thick Nut I"},
	## [P34] The batch-1 talents, all tier I like the three above (their "I" says so).
	## The wording keeps the pattern 豌豆 / 阳光 / 坚果 + a qualifier: what the potion
	## lifts is the plant's own skill (or hp, for a wall).
	"talent.potion_repeater": {"zh": "双豌豆 I", "en": "Twin Pea I"},
	"talent.potion_split_pea": {"zh": "裂豌豆 I", "en": "Split Pea I"},
	"talent.potion_gatling_pea": {"zh": "连豌豆 I", "en": "Rapid Pea I"},
	"talent.potion_threepeater": {"zh": "三行豌豆 I", "en": "Wide Pea I"},
	"talent.potion_snow_pea": {"zh": "冰豌豆 I", "en": "Frost Pea I"},
	"talent.potion_twin_sunflower": {"zh": "双阳光 I", "en": "Double Sun I"},
	"talent.potion_puff_shroom": {"zh": "小孢子 I", "en": "Small Spore I"},
	"talent.potion_fume_shroom": {"zh": "大孢子 I", "en": "Big Spore I"},
	## [P58] The shroom line's third bottle keeps that line's own pattern (小 / 大 + 孢子):
	## what this one lifts is the ring's damage, so the qualifier says where the spores go.
	"talent.potion_gloom_shroom": {"zh": "环孢子 I", "en": "Ring Spore I"},
	## [P59] The fourth bottle of the line, named the same way: the qualifier says what
	## this one's spores do - 远程射击, i.e. the longest lane shot a shroom has.
	"talent.potion_scaredy_shroom": {"zh": "远孢子 I", "en": "Far Spore I"},
	"talent.potion_tallnut": {"zh": "厚高墙 I", "en": "Thick Wall I"},
	## [P39] The chomper's potion lifts HP, not a skill number (it has none to lift -
	## its bite ignores health), so 厚 / toughness is the right family, on its own mouth.
	"talent.potion_chomper": {"zh": "韧嘴 I", "en": "Tough Maw I"},
	## [P49] Both melons' potions lift the throw's damage (potion_effect "skill"), so
	## they join the 豌豆 pattern - qualifier first, the thing thrown second. 冰西瓜
	## keeps the whole Chinese plant word because 冰 alone would not say which icy plant
	## is meant (the snow pea's talent above already owns 冰豌豆).
	## [P51] The cabbage's bottle follows the same shape: 重 (heavy) is what a skill potion
	## on a lobber does, and 卷心菜 alone would not say which cabbage on the board is meant
	## (the sheet has no other, but the almanac word for the plant is 卷心菜投手).
	"talent.potion_cabbage_pult": {"zh": "重卷心菜 I", "en": "Heavy Cabbage I"},
	"talent.potion_melon_pult": {"zh": "重西瓜 I", "en": "Heavy Melon I"},
	"talent.potion_winter_melon": {"zh": "冰西瓜 I", "en": "Frozen Melon I"},
	## [B30] The healer's talent, on the 阳光 pattern the sunflowers started (大阳光 lifts how
	## much light one plant throws): this bottle lifts the same number, only what it buys back
	## is HP. 暖阳光 keeps 暖阳葵's own word 暖阳 rather than reusing 大阳光, which is taken.
	"talent.potion_warm_sunflower": {"zh": "暖阳光 I", "en": "Warm Light I"},

	# ------------------------------------------------------------ rarity / difficulty
	## [P105] THE SIX TIERS (user design): 普通 / 优秀 / 稀有 / 史诗 / 传说 / 神话, and the
	## colours they are shown in live in data/rarity.csv (white / green / blue / purple / gold /
	## red). The ids here are the ones a `rarity` cell writes; a tier with no key falls back to
	## its own id uppercased (Balance.rarity_label), so adding a tier is a sheet row plus a line
	## here - nothing else.
	"rarity.common": {"zh": "普通", "en": "COMMON"},
	"rarity.uncommon": {"zh": "优秀", "en": "UNCOMMON"},
	"rarity.rare": {"zh": "稀有", "en": "RARE"},
	"rarity.epic": {"zh": "史诗", "en": "EPIC"},
	"rarity.legendary": {"zh": "传说", "en": "LEGENDARY"},
	"rarity.mythic": {"zh": "神话", "en": "MYTHIC"},

	## [P113] THE TWO UNIT LABELS (the `range_type` / `role` cells of units.csv, read through
	## UnitSheet.range_type() / role()). These are the DISPLAY words only - the stored value is the
	## English code and this table is what a person sees. zh keeps the design's own Chinese
	## (近战/远程, 输出/坦克/治疗/辅助); en just uppercases the code the way rarity does, so a tag
	## with no key here would still read as its code rather than break. A blank tag shows no line
	## at all, so these six are the complete set a tagged unit can print.
	"unit.range.melee": {"zh": "近战", "en": "MELEE"},
	"unit.range.range": {"zh": "远程", "en": "RANGE"},
	"unit.role.dps": {"zh": "输出", "en": "DPS"},
	"unit.role.tank": {"zh": "坦克", "en": "TANK"},
	"unit.role.healer": {"zh": "治疗", "en": "HEALER"},
	"unit.role.support": {"zh": "辅助", "en": "SUPPORT"},

	"difficulty.easy": {"zh": "简单", "en": "EASY"},
	"difficulty.normal": {"zh": "普通", "en": "NORMAL"},
	"difficulty.hard": {"zh": "困难", "en": "HARD"},

	# ------------------------------------------------------------ plant attribute text
	## What a talent potion does, shown on the GARDEN page (%d = the boost in %).
	"plant.potion.hp": {"zh": "+%d%% 最大生命", "en": "+%d%% max health"},
	"plant.potion.skill": {"zh": "+%d%% 技能威力", "en": "+%d%% skill value"},

	# ------------------------------------------------------------ board action bars
	## The word drawn under a unit's action bar: the bar is the picture, this is
	## the label the player reads next to it (see Unit.action_text).
	"action.idle": {"zh": "待机", "en": "IDLE"},
	"action.fire": {"zh": "开火", "en": "FIRE"},
	"action.produce": {"zh": "生产", "en": "PRODUCE"},
	"action.block": {"zh": "阻挡", "en": "BLOCK"},
	## [P39] The chomper's two words: 吞噬 is what its bar is FOR (the skill it is
	## charging, same as 开火 for a shooter), 咀嚼 is what it says while the bar is
	## frozen mid-chew - the sheet's own wording (咀嚼3回合), see Chomper.action_text.
	"action.chomp": {"zh": "吞噬", "en": "CHOMP"},
	"action.chewing": {"zh": "咀嚼", "en": "CHEWING"},
	## [P39] One word for the 一次性 family (OneShotPlant.setup_one_shot): the bar under
	## them is only ever the price of the blast they are waiting to land.
	"action.blast": {"zh": "爆炸", "en": "BLAST"},
	## [P49] The lobbers' word (PultPlant.setup_pult): the sheet says 抛掷 for both melons,
	## so the bar says the same thing the almanac does. English stays a verb, not "TOSS"
	## read as a noun - the label is the action the bar is charging towards.
	"action.toss": {"zh": "抛掷", "en": "TOSS"},
	## [P63] The spike's word (SpikePlant.setup_spike), from its own 技能 cell 地刺穿刺: the
	## bar under a 地刺 is the price of the next stab, and 穿刺 is what the sheet calls it.
	## Not 阻挡 - a spike stops nobody (plants.csv says 不阻挡僵尸 outright), so the wall's
	## word would be a lie on this bar.
	"action.spike": {"zh": "穿刺", "en": "PIERCE"},
	## [B30] The healer's word (WarmSunflower): the bar under a 暖阳葵 is the price of the
	## next mend, and 治疗 is what the request called it. Not 开火 - a shooter's word on a
	## body that fires health would tell the player the wrong thing about the shot coming out.
	"action.heal": {"zh": "治疗", "en": "HEAL"},
	## [P39] ...and the word while the fuse burns (土豆地雷 需3回合武装 / 樱桃炸弹 种下后
	## 下回合爆炸), which is the same stand-down a chewing chomper shows.
	"action.arming": {"zh": "武装", "en": "ARMING"},
	"action.advance": {"zh": "前进", "en": "ADVANCE"},
	"action.bite": {"zh": "啃咬", "en": "BITE"},
	"action.vault": {"zh": "跳跃", "en": "VAULT"},
	"action.eat": {"zh": "吃脑", "en": "EAT"},
	## [P47] The dancer's call (Zombie.Act.SUMMON) - the label its action bar wears on
	## the round it summons, same shape as 跳跃 / 吃脑.
	"action.summon": {"zh": "召唤", "en": "SUMMON"},
	## [P48] The giant's hammer (Zombie.Act.WINDUP / Act.SMASH) and the wait after it.
	## 举锤 and 挥锤后 are the words a player sees while the zombie is neither walking nor
	## frozen (Zombie.action_text); 砸锤 is the action label the log and the switch line
	## carry. The English wind-up keeps the "UP" because the state is a wait, not a swing.
	"action.windup": {"zh": "举锤", "en": "WINDING UP"},
	"action.smash": {"zh": "砸锤", "en": "SMASH"},
	"action.recovering": {"zh": "挥锤后", "en": "RECOVERING"},
	"action.none": {"zh": "无动作", "en": "no action"},
	## [P34] The label a FROZEN zombie wears over its move bar: the bar itself keeps
	## showing how close the next step is, this says why it is not filling (the snow
	## pea's rider - see Zombie.is_frozen / action_text).
	"action.frozen": {"zh": "冻结", "en": "FROZEN"},
	## [P30-B] The last-resort label for a plant's ultimate charge bar when neither
	## the unit sheet nor skills.csv names the loaded ultimate (see Unit.ult_name_text).
	"action.ult": {"zh": "大招", "en": "ULTIMATE"},
}
