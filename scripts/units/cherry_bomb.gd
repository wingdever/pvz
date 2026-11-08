class_name CherryBomb
## [P39] Extended by PATH, for the reason squash.gd gives.
extends "res://scripts/units/base/one_shot_plant.gd"
## [P39] 樱桃炸弹 - the area answer: 种下后下回合爆炸，3×3区域9999伤害. It is the family's
## third shape, and the only one whose blast leaves its own cell: 窝瓜 hits one body,
## 火爆辣椒 hits one lane, this hits the nine cells around itself.
##
## The sheet gives the two numbers this plant is made of, and nothing else: the wait is
## 下回合 (one round - it is planted, it sits, it goes off), and the reach is 3×3. The
## damage is the same 9999 the attack column now carries.

const ID := "cherry_bomb"
## [P30-A] 范围爆炸.
const SKILL := "cherry_blast"
## [P39] 种下后下回合爆炸: one round of fuse. Owned by the script for the reason given
## in potato_mine.gd (the sheet has no column for a fuse).
const ARM_ROUNDS := 1
## [P39] 3×3 means the planted cell plus its eight neighbours, so the reach is one cell
## in every direction.
const REACH := 1


func _init() -> void:
	setup_one_shot(ID, SKILL, ARM_ROUNDS)
	## [P50] The family's default blast is the generic crater; this plant IS the crater.
	blast_cue = "blast_cherry"


func blast_targets() -> Array:
	## Every body in the nine cells around this plant, collected row by row so the log
	## reads top lane to bottom lane. Cells outside the lawn simply miss in the grid's
	## dictionary, so a cherry planted on the edge burns the strip that exists.
	## [P58] That whole box is Grid.get_zombies_around's now - 忧郁菇's 周围8格 asked the
	## same question one batch later and was about to write the same nine-cell loop a
	## second time, which is the sign the loop was never this plant's to own. What stays
	## here is the one thing a cherry does decide: its reach.
	if grid == null:
		return []
	return grid.get_zombies_around(col, row, REACH)
