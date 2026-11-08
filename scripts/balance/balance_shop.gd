class_name BalanceShop
extends RefCounted
## [P108] The SHOP page's half of Balance, split out of scripts/balance/balance.gd at the user's
## request ("a scene's own constants live with that scene"). Same rule as [P28-UI] / [P69]:
## WHO READS IT. Two readers, both of them the shop -
##   the page itself   ui/item_screen/shop.gd (what the shelf shows, what a click buys)
##   the buyer         core/game_manager.gd (the money check and the purchase)
## and one neighbour: core/chapter_map.gd asks this table where a campaign node's shop sits.
## The prices follow ONE rule, written at the head of the block below: roughly 3x the card's
## own sun cost, rounded to the nearest 50. It prices what a card COSTS, never what it does.
## SHOP_STOCK names ITEM ids that Balance owns, so this file READS Balance - never the other
## way round.

# ---------------------------------------------------------------- shop (P15)
# Prices in money. A cleared level pays 5 gold = 500 once they are sold, so a clear
# buys roughly one or two of these.
const SHOP_PRICE_FERTILIZER := 50
const SHOP_PRICE_EXP_POTION := 100
const SHOP_PRICE_SUNFLOWER := 200
const SHOP_PRICE_WALLNUT := 250
const SHOP_PRICE_PEASHOOTER := 300
## [P34] The batch-1 prices follow the same hand-drawn spread as the three originals
## (roughly 3x the plant's own sun cost, rounded to the nearest 50): a cleared level
## pays 5 gold = 500 once sold, so a card is a few levels of saving. The shrooms stay
## the cheap end and the gatling the expensive one, exactly like their sun costs.
const SHOP_PRICE_PUFF_SHROOM := 150
const SHOP_PRICE_FUME_SHROOM := 250
const SHOP_PRICE_SNOW_PEA := 500
const SHOP_PRICE_TWIN_SUNFLOWER := 450
const SHOP_PRICE_TALLNUT := 400
const SHOP_PRICE_REPEATER := 600
const SHOP_PRICE_SPLIT_PEA := 900
const SHOP_PRICE_THREEPEATER := 900
const SHOP_PRICE_GATLING_PEA := 1200
## [P39] 150 sun -> 450 coins, the same 3x rule that priced batch 1.
const SHOP_PRICE_CHOMPER := 450
## [P39] The same 3x rule: 50 sun -> 150, 125 sun -> 400 (rounded up like the snow pea's
## 175 -> 500). A one-shot plant is cheap to keep in the garden and expensive to replace,
## which is the trade its DOWNED-after-every-blast behaviour already makes.
const SHOP_PRICE_SQUASH := 150
const SHOP_PRICE_JALAPENO := 400
## [P39] Same 3x rule: 25 sun -> 100 (rounded up like the others), 150 sun -> 450 - the
## price the chomper already sits at, which is the point of the rule: the shop asks for
## the plant's own sun cost, not for what its mechanism is.
const SHOP_PRICE_POTATO_MINE := 100
const SHOP_PRICE_CHERRY_BOMB := 450
## [P43] The same 500 a 175-sun card already buys (the snow pea), because the rule this
## table follows prices the plant's own sun cost and takes no account of what its
## mechanism is - freezing the lawn is not worth more coins than stopping it is worth sun.
const SHOP_PRICE_ICE_SHROOM := 500
## [P49] Batch 3's two cards, and the 3x rule lands on round numbers for once: 300 sun ->
## 900 coins (where the split pea and the threepeater already sit), 200 sun -> 600 (where
## the repeater sits). That is the rule doing its job rather than a coincidence to explain:
## a melon-pult IS the 300-sun card the threepeater is, and a winter-melon IS the 200-sun
## control card the repeater is, so they buy at the same shelf price.
const SHOP_PRICE_MELON_PULT := 900
const SHOP_PRICE_WINTER_MELON := 600
## [P51] 100 sun -> 300 coins, the same 3x rule that priced every card before it - and the
## roundest number in the family, which is the point of a rule rather than a table: the
## cabbage sits exactly where a 100-sun peashooter sits, because the shop asks for the
## plant's own sun cost and takes no account of what its mechanism is.
const SHOP_PRICE_CABBAGE_PULT := 300
## [P58] 150 sun -> 450 coins: the 3x rule again, landing on the same shelf the chomper,
## the cherry bomb and the twin sunflower already sit on. The rule keeps saying the same
## thing batch after batch - the shop prices a card's sun cost, not its mechanism.
const SHOP_PRICE_GLOOM_SHROOM := 450
## [P59] 25 sun -> 75 coins: the third time the same rule has been asked the same
## question, and it still only reads the plant's own cost. The scaredy is the cheapest
## card on the shelf for the same reason it is the cheapest on the lawn.
const SHOP_PRICE_SCAREDY_SHROOM := 75
## [P63] 100 sun -> 300 coins, and the rule says the same thing it has said every batch:
## the spike buys where the peashooter and the cabbage buy, because the shop asks a card
## what it COSTS and not what it DOES. That is the whole point of pricing by a rule rather
## than by a table - a plant with no shot, no blast and no blocking still has a price, and
## it is the one its own 费用 column wrote.
const SHOP_PRICE_SPIKEWEED := 300
## id -> {kind: "item"|"plant", price, target}
const SHOP_STOCK := [
	{"kind": "item", "id": Balance.ITEM_FERTILIZER, "price": SHOP_PRICE_FERTILIZER},
	{"kind": "item", "id": Balance.ITEM_EXP_POTION, "price": SHOP_PRICE_EXP_POTION},
	{"kind": "plant", "id": "sunflower", "price": SHOP_PRICE_SUNFLOWER},
	{"kind": "plant", "id": "wallnut", "price": SHOP_PRICE_WALLNUT},
	{"kind": "plant", "id": "peashooter", "price": SHOP_PRICE_PEASHOOTER},
	{"kind": "plant", "id": "puff_shroom", "price": SHOP_PRICE_PUFF_SHROOM},
	{"kind": "plant", "id": "fume_shroom", "price": SHOP_PRICE_FUME_SHROOM},
	## [P58] The shroom line's third card, on the shelf beside its two elders.
	{"kind": "plant", "id": "gloom_shroom", "price": SHOP_PRICE_GLOOM_SHROOM},
	## [P59] ... and its fourth, at the very cheap end the puff has always marked.
	{"kind": "plant", "id": "scaredy_shroom", "price": SHOP_PRICE_SCAREDY_SHROOM},
	{"kind": "plant", "id": "snow_pea", "price": SHOP_PRICE_SNOW_PEA},
	{"kind": "plant", "id": "twin_sunflower", "price": SHOP_PRICE_TWIN_SUNFLOWER},
	{"kind": "plant", "id": "tallnut", "price": SHOP_PRICE_TALLNUT},
	{"kind": "plant", "id": "repeater", "price": SHOP_PRICE_REPEATER},
	{"kind": "plant", "id": "split_pea", "price": SHOP_PRICE_SPLIT_PEA},
	{"kind": "plant", "id": "threepeater", "price": SHOP_PRICE_THREEPEATER},
	{"kind": "plant", "id": "gatling_pea", "price": SHOP_PRICE_GATLING_PEA},
	{"kind": "plant", "id": "chomper", "price": SHOP_PRICE_CHOMPER},
	{"kind": "plant", "id": "squash", "price": SHOP_PRICE_SQUASH},
	{"kind": "plant", "id": "jalapeno", "price": SHOP_PRICE_JALAPENO},
	{"kind": "plant", "id": "potato_mine", "price": SHOP_PRICE_POTATO_MINE},
	{"kind": "plant", "id": "cherry_bomb", "price": SHOP_PRICE_CHERRY_BOMB},
	## [P43] Batch 2's last card, in the shop for a garden instance only - the card still
	## needs its scroll, which Lawn_1_9 hands out (see the note above).
	{"kind": "plant", "id": "ice_shroom", "price": SHOP_PRICE_ICE_SHROOM},
	## [P49] Batch 3's two, on the same two-route rule as every card since P34: the shop
	## sells the plant for the garden, the scroll is what lets the deck hold the card at all
	## - and the two new scrolls hang on the two levels that already teach what they do:
	## Lawn_1_8 is where the other expensive lane-clearer (the gatling) is earned, Lawn_1_9
	## is where the other control card (the ice-shroom) is.
	{"kind": "plant", "id": "melon_pult", "price": SHOP_PRICE_MELON_PULT},
	{"kind": "plant", "id": "winter_melon", "price": SHOP_PRICE_WINTER_MELON},
	## [P51] The family's cheap end, on the same two-route rule: this buys the garden
	## instance, the card still needs the scroll Lawn_1_5 hands out - and that level is the
	## one that already drops the cabbage's own card, which is P44's rule for a scroll.
	{"kind": "plant", "id": "cabbage_pult", "price": SHOP_PRICE_CABBAGE_PULT},
	## [P63] The spike joins the same two-route rule: 300 buys the garden instance, while the
	## card itself only enters the deck from scroll_spikeweed. Both halves hang on the SAME
	## level (Lawn_1_2 gives the scroll in `first_clear` and drops the plant in `rewards`),
	## which is P44's rule for a scroll - and the rule is why this batch also added the
	## `potion_spikeweed` row: a bottle the sheet promises but no level hands out is an
	## almanac entry that can never be filled (see the plan's 待决 list for the three
	## potions that are still in exactly that state).
	{"kind": "plant", "id": "spikeweed", "price": SHOP_PRICE_SPIKEWEED},
]
