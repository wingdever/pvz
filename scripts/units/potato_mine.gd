class_name PotatoMine
## [P39] Extended by PATH, not by the `OneShotPlant` name, for the reason squash.gd
## gives: a brand-new `class_name` only resolves after the editor has rescanned it.
extends "res://scripts/units/base/one_shot_plant.gd"
## [P39] 土豆地雷 - the cheapest answer in the game (25 sun) and the slowest to arm:
## 需3回合武装，单体9999伤害. The two one-shot plants that answer at once (窝瓜 / 火爆辣椒)
## are cards you PLAY when the zombie is already there; the mine is a card you play
## BEFORE it arrives, and the three rounds are what that difference costs.
##
## WHAT THE SHEET LEAVES OPEN is only the reach: 单体爆炸 names a count (one zombie), not
## a distance. The cell in front is the reading every other part of the engine already
## uses - a zombie that reaches a plant stands in that cell and bites it from there (see
## Squash.blast_targets for the same argument) - so the mine takes the first body to
## walk into its reach, which is what a land mine does.

const ID := "potato_mine"
## [P30-A] 单体爆炸.
const SKILL := "potato_blast"
## [P39] 需3回合武装, in the sheet's own words. There is no column for a fuse, so this
## is the one number of this plant that the script owns - and the [Plants] / [Skills]
## checks still see every other number coming from the sheet.
const ARM_ROUNDS := 3


func _init() -> void:
	setup_one_shot(ID, SKILL, ARM_ROUNDS)
	## [P50] A mine is a small charge under one body, not a cherry: the sample says so.
	blast_cue = "blast_potato"


func blast_targets() -> Array:
	## One body: the nearest zombie in the cell in front. `get_zombies_at` keeps the
	## order the grid registered them in, and a mine that has two bodies on top of each
	## other still only spends itself on the first - 单体 says so.
	if grid == null:
		return []
	var bodies: Array = grid.get_zombies_at(col + 1, row)
	return [bodies[0]] if not bodies.is_empty() else []
