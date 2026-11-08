class_name SpikeWeed
## [P63] By path, for the reason squash.gd gives: a new `class_name` is invisible to a
## headless run until the editor rescans it.
extends "res://scripts/units/base/spike_plant.gd"
## [P63] 地刺 - the family's first member and the cheapest thing on the lawn that a
## zombie cannot eat: 费用 100 / 冷却 4 / HP 300 / attack 20, and a 大招 (尖刺风暴) that puts
## 60 through the whole lane it lies in.
##
## This file says THREE things and every one of them is a cell of the sheet: which id it
## is, which skill row that id means, which ultimate row. Both halves of its own sentence
## - hurt the walker, refuse the bite - are the base's, and 20 / 60 / 100 / 4 / 300 are the
## table's (AGENTS.md §2). What is NOT here is a射程, a方向 or a count: a spike covers the
## cell it is planted on and nothing else, which is why the family has no geometry consts
## at all where the pults and the shrooms have them.
##
## Why the elder spike (地刺王) is not in this batch: it owes THREE data decisions before
## it can owe a script. Its 特殊机制 adds two clauses the engine has nothing to negate yet -
## `对巨人僵尸不减伤` (no damage-reduction rule exists to be immune to) and `可免疫一次碾压`
## (which of the hammer's two halves does it refuse?) - 强化穿刺 is the same stab with a 2×
## written in prose rather than in the attack column, and its 大招效果 numbers the storm at 120
## where 地刺's says 60, which a single shared 大招代码 cannot hold. Those are table questions,
## not scripts; see the plan's 待决 list.

const ID := "spikeweed"
## [P63] 地刺穿刺.
const SKILL := "spike_pierce"
## [P63] 尖刺风暴 - the sheet's own 大招代码 cell. The elder spike cannot ride it: a skill
## code carries ONE number and 地刺王's 大招效果 says 120 where this row says 60, so wiring
## that row means a second ultimate code (a data decision, below).
const ULTIMATE := "spike_storm"


func _init() -> void:
	setup_spike(ID, SKILL, ULTIMATE)
