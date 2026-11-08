class_name MelonPult
## [P49] Extended by PATH, not by the `PultPlant` name, for the reason potato_mine.gd
## gives: a brand-new `class_name` only resolves after the editor has rescanned it.
extends "res://scripts/units/base/pult_plant.gd"
## [P49] 西瓜投手 - the heaviest ordinary shot in the game: 60 damage where the whole pea
## family sits at 20. The sheet prices that at 300 sun and 6 rounds of cooldown, in the
## gatling's band rather than the repeater's, and the reason is the second half of its
## sentence: 对其上下左右各造成一半伤害. A melon that lands in a crowd is worth several
## peas, so the 300 does not buy a stronger shot, it buys a different question - one
## throw, five bodies.
##
## NOTHING ELSE IS ITS OWN. It throws at the nearest body of its own lane like a
## peashooter, pays the 1 AP its skills.csv row says, charges its bar one point per
## volley, and its 西瓜雨 is the family's shape (own row at the sheet's 80, the rows
## beside it at half). Every one of those numbers comes from a sheet.

const ID := "melon_pult"
## [P30-A] 抛掷西瓜.
const SKILL := "melon_toss"
## [P30-B] 西瓜雨: 80 down the lane, 40 down each neighbour.
const ULTIMATE := "melon_rain"


func _init() -> void:
	## The melon's own green (see BalanceUI.COLOR_MELON). No hit riders: that is the
	## whole difference between this plant and its icy brother, which throws the same
	## melon with a freeze on it.
	shot_tint = BalanceUI.COLOR_MELON
	setup_pult(ID, SKILL, ULTIMATE)
