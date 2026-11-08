class_name Jalapeno
## [P39] By path, for the same reason as squash.gd: a new `class_name` is invisible to
## a headless run until the editor rescans it.
extends "res://scripts/units/base/one_shot_plant.gd"
## [P39] 火爆辣椒 - the same spend-yourself shape as the squash, down a whole lane:
## 一次性，整行9999伤害. It is the family's proof that `blast_targets()` is the only
## real question a 一次性 plant answers, because everything else about these two files
## is the setup call.
##
## No 大招 row on its sheet, so it carries no charge bar at all (Unit.has_ultimate
## says a plant with no code has no bar) - which also means the engine never offers
## it a way to fire twice, and 整行 is not a number that needs a second helping.

const ID := "jalapeno"
## [P30-A] 火燃一线.
const SKILL := "jalapeno_burn"


func _init() -> void:
	setup_one_shot(ID, SKILL)
	## [P50] 整行火: the lane burns, it does not blow up - hence a fire sample.
	blast_cue = "blast_jalapeno"


func blast_targets() -> Array:
	## The whole lane, front to back - 整行 says the row, not "the row ahead of it", so
	## a zombie that already walked past the pepper burns with the rest (the same
	## reading the pea storms use: see ShooterPlant.storm_lane).
	if board == null:
		return []
	return board.get_zombies_in_row(row)