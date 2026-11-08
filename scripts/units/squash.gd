class_name Squash
## [P39] Extended by PATH, not by the `OneShotPlant` name, for one reason: a brand-new
## `class_name` only resolves once the EDITOR has rescanned it (HANDOFF §7.67), so
## naming it here would make every headless run fail to parse this file - and, through
## the PlantScripts table that preloads it, take the whole battle dispatch down with it.
## The path always resolves; the class_name on the base stays for readers and for the
## typed checks that will work as soon as the cache knows it.
extends "res://scripts/units/base/one_shot_plant.gd"
## [P39] 窝瓜 - the family's smallest member: one zombie, one cell, one squash, and
## the plant is used up. It exists as its own file for the same reason every other
## plant does: the ONE thing this family varies in is which bodies the blast covers,
## and that answer is a sentence per plant (see OneShotPlant.blast_targets).
##
## The sheet's two halves say it together: units.csv 技能 calls it 单格压杀 (a stomp of
## ONE cell) and plants.csv 技能效果 calls it 最近1只僵尸9999伤害 (the nearest single
## zombie) - so the reach is one cell in front, and one body of whatever stands there.

const ID := "squash"
## [P30-A] 压杀.
const SKILL := "squash_stomp"


func _init() -> void:
	setup_one_shot(ID, SKILL)
	## [P50] The squash's own landing: it is the one blast in this family with no fire and
	## no crater, just weight.
	blast_cue = "squash"


func blast_targets() -> Array:
	## The cell in front, the nearest body in it. A zombie that reached this plant is
	## standing exactly there (it bites the plant at its own col - 1), so a squash that
	## was walked onto squashes the thing that walked onto it, which is the one case
	## where the two sentences could have disagreed.
	if grid == null:
		return []
	var bodies: Array = grid.get_zombies_at(col + 1, row)
	return [bodies[0]] if not bodies.is_empty() else []
