class_name BalanceGarden
extends RefCounted
## [P108] The GARDEN's half of Balance, split out of scripts/balance/balance.gd at the user's request
## ("a scene's own constants live with that scene"). Same rule as [P28-UI] / [P69]: WHO READS
## IT. Every constant here is read by the garden and by nothing else -
##   the save + the rules   core/garden.gd (user://garden.json, the starting roster)
##   the page               ui/garden/** (pots per page, the grid, the four tool cells)
##   the two that look in   ui/run/squad_view.gd (a run lists garden plants and their state),
##                          core/rewards.gd through Garden (a chest looks for a free pot)
## What a plant LOOKS like in those pots is BalanceUI's (ART_GARDEN_POT, GARDEN_POT_*,
## FONT_SIZE_GARDEN_*); what it is WORTH is data/units/*.csv + data/rarity.csv's. The
## recovery arithmetic (rarity + level -> seconds) stays in balance.gd, because its readers
## are the rarity table's, not the garden page's.
## Nothing in balance.gd reads this file.

# ---------------------------------------------------------------- garden (P12)
# The garden is the persistent, cross-level roster of plants the player owns: the
# thing a plant card summons out of, and the place a plant comes home to with its
# wounds. It lives in user://garden.json (plain JSON so it can be hand-edited
# while balancing) - never in project.godot, which the editor rewrites
# (see HANDOFF 7.15), and never in settings.cfg, which is for display settings.
#
# The roster is NOT touched while a battle runs. Game keeps a battle-scoped
# ledger of what happened and writes it back only when the battle settles
# (WIN / LOSE / leaving to the menu / closing the window), which is what makes
# R (restart) an implicit rollback: no settlement -> no write-back.
const GARDEN_PATH := "user://garden.json"
const GARDEN_VERSION := 1
## [P25] 4 x 4 = 16 pots PER PAGE. GardenView builds GARDEN_COLS *
## GARDEN_ROWS cells, and Garden uses the capacity to find a free slot for a reward
## plant - so the three constants have to agree.
## [P95] The roster grew PAGES: 24 levels now hand out a plant each (as a chest, see
## Rewards), and 16 pots could hold only 16 of them. A page shows GARDEN_PAGE_SIZE pots
## (the 4 x 4 grid) and the page bar turns between them; the capacity a reward plant
## looks for a free slot in is all the pages together.
const GARDEN_PAGE_SIZE := 16
const GARDEN_PAGES := 2
const GARDEN_CAPACITY := GARDEN_PAGE_SIZE * GARDEN_PAGES
const GARDEN_COLS := 4
const GARDEN_ROWS := 4

# ---------------------------------------------------------------- roster + care (P14)
# The garden the player starts with. [P14] It is exactly ONE peashooter now: every
# other plant has to be earned (first-clear scrolls, clear-reward plants), which is
# what makes the whole reward loop mean anything.
const GARDEN_START_ROSTER := ["peashooter"]

# Care actions are FREE and unlimited: the price of a mistake in battle is down
# time in the garden, not a resource. Watering heals half of the MAX hp (capped),
# fertilizing does the same AND cures DOWNED (which is exactly "hp is 0").
const WATER_HEAL_RATIO := 0.5
const FERTILIZE_HEAL_RATIO := 0.5
const GARDEN_STATE_HEALTHY := "HEALTHY"
const GARDEN_STATE_WOUNDED := "WOUNDED"
const GARDEN_STATE_DOWNED := "DOWNED"
## [P20] Not drawn any more either: the garden page says 健康 / 受伤 / 倒地 through
## LocUi ("garden.state.healthy" / "wounded" / "downed"). See the note on
## BalanceUI.ROW_LABEL_SCROLLS.

# ---------------------------------------------------------------- garden tools (P24/P25)
# [P28-UI] The garden PAGE metrics moved to BalanceUI: GARDEN_TITLE_BAND, the plot
# grid sizes, the detail panel numbers, the tool-cell geometry (GARDEN_TOOLBAR_Y ..
# GARDEN_TARGET_FRAME_W), the whole one-plot block (ART_GARDEN_POT / GARDEN_POT_* /
# PLANT_ART_INK / plant_art_ink) and the garden colours + FONT_SIZE_GARDEN_*.
# What stays are the four TOOL IDS - the battle, the garden logic and GardenView all
# key off them, so they are game data, not pixels.
## The four kinds, in the order the cells appear. They are also the ids the tool
## cells report, and GardenView maps each one to its own Loc key and icon.
const GARDEN_TOOL_WATER := "water"
const GARDEN_TOOL_FERTILIZE := "fertilize"
const GARDEN_TOOL_EXP := "exp"
const GARDEN_TOOL_TALENT := "talent"
const GARDEN_TOOL_KINDS := [GARDEN_TOOL_WATER, GARDEN_TOOL_FERTILIZE,
	GARDEN_TOOL_EXP, GARDEN_TOOL_TALENT]
