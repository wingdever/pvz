class_name BalanceRun
extends RefCounted
## [P108] The ADVENTURE RUN's half of Balance, split out of scripts/balance/balance.gd at the user's
## request ("a scene's own constants live with that scene"). Same rule as [P28-UI] / [P69]:
## WHO READS IT. Every constant here belongs to the campaign mode -
##   the run's save + its rules   core/run_state.gd (user://run.json, the retry fee, run mods)
##   the node graph + the events  core/chapter_map.gd, core/event_db.gd, data/adventure/**
##   the four campaign pages      core/run_flow.gd, ui/run/** (squad, choice, reward, roadmap)
## The chapter GRAPHS and the event TEXTS are data under res://data/adventure/ (the paths to
## them are here, their contents are not); unit and item numbers stay on their own sheets.
## RUN_CHOICE_POOL and RUN_TREASURE_ROLLS name ITEM ids that Balance owns, so this file READS
## Balance - never the other way round, or the two would form a cycle.

# ---------------------------------------------------------------------------
# [P31-A] Adventure run (the campaign mode). GLOBAL rules only - the chapter
# graphs and the event texts are DATA under res://data/adventure/, and unit
# numbers stay on the unit sheets (AGENTS.md §2). Design: README
# 「游戏流程重构设计（P31）」.
# ---------------------------------------------------------------------------
const ADVENTURE_DIR := "res://data/adventure"
const CHAPTER_GLOB := "chapter_"            # chapter_<n>.json, discovered by number
const EVENTS_FILE := "res://data/adventure/events.json"
const RUN_PATH := "user://run.json"         # the ONE run the player is inside
const RUN_VERSION := 1
## Squad size: how many garden plants may be carried into a run. The confirmed
## design number is 4 (chapter files may override per chapter).
const RUN_SQUAD_SLOTS := 4
## Losing a run battle is "retry in place, small price": the wallet pays a fee
## that DOUBLES per consecutive failure on the same node, capped, and every
## squad plant goes DOWNED (garden.real-time recovery then keeps them honest).
const RETRY_COST_BASE := 30
const RETRY_COST_MAX_MULT := 4
## Reward stage 1 (base): node type -> guaranteed money + exp for every squad
## plant. Stage 2 (random) is the level file's own `rewards` rolls, re-directed
## into the run; stage 3 is the pick-one-of-three below.
const RUN_BASE_REWARD := {
	"battle": {"money": 40, "exp": 15},
	"boss": {"money": 120, "exp": 40},
}
## How many candidates the pick-one-of-three offers.
const RUN_CHOICE_ROLLS := 3
## [P31-A] the choice pool is money + items only (plants/run-mods join in
## P31-B, per the design). kind "money" pays the wallet, "item" goes to the pouch.
const RUN_CHOICE_POOL := [
	{"kind": "money", "amount": 50, "weight": 4},
	{"kind": "money", "amount": 120, "weight": 2},
	{"kind": "item", "id": Balance.ITEM_FERTILIZER, "count": 1, "weight": 3},
	{"kind": "item", "id": Balance.ITEM_EXP_POTION, "count": 1, "weight": 2},
	{"kind": "item", "id": Balance.ITEM_COIN_SILVER, "count": 3, "weight": 2},
]
## A treasure node opens one chest: independent rolls, same shape as a level's
## `rewards` but paying into the POUCH (merged into the warehouse when the run ends).
const RUN_TREASURE_ROLLS := [
	{"chance": 0.50, "id": Balance.ITEM_COIN_SILVER, "count": 2},
	{"chance": 0.25, "id": Balance.ITEM_FERTILIZER, "count": 1},
	{"chance": 0.20, "id": Balance.ITEM_EXP_POTION, "count": 1},
	{"chance": 0.05, "id": Balance.ITEM_COIN_GOLD, "count": 1},
	{"chance": 0.10, "id": Balance.ITEM_ENERGY_BEAN, "count": 1},
]
## Rest node, the three confirmed options: heal one plant to full / patrol
## (+15% sun for the next 2 nodes, a run mod) / camp (flat money).
const RUN_REST_PATROL_MOD := {"key": "sun_mult", "value": 1.15, "left": 2}
const RUN_REST_CAMP_MONEY := 50
## Run mod keys the battle already knows how to consume (see Game._start_new_game):
## multiplicative sun/zombie scaling and one additive start-sun bonus. This list is what
## RunState.add_mod accepts, so a key on it that the fold does not name is a mod that can
## be granted, saved and displayed - and change nothing. [P81] boot's `[Diff]` line compares
## it against the three tokens the fold looks mods up by, which is the only way that gap
## shows up as a FAIL instead of a playthrough.
const RUN_MOD_KEYS := ["sun_mult", "zombie_hp_mult", "start_sun_bonus"]
