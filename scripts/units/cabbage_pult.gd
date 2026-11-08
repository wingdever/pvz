class_name CabbagePult
## [P51] Extended by PATH, not by the `PultPlant` name, for the reason potato_mine.gd
## gives: a brand-new `class_name` only resolves after the editor has rescanned it.
extends "res://scripts/units/base/pult_plant.gd"
## [P51] 卷心菜投手 - the family's first row and the cheapest card in it: 100 sun for a
## 20-damage lob, which is a peashooter's bullet on an arc. That is the whole design
## sentence the sheet wrote for it (units.csv 特殊机制 = 可越过墓碑、屋顶等障碍, and NOT
## 溅射伤害 like its two melon brothers), and it is why this file is three lines long:
## a cabbage answers every one of the family's questions with the default.
##
## WHAT IT DOES NOT SAY, AND WHERE THAT DECISION LIVES INSTEAD:
##   no splash        - PlantDB.has_splash() reads 溅射 out of the sheet's 特殊机制 column,
##                      and this row does not contain the word ( [P51]: the column, not a
##                      line here, is what makes a 投手 spread or not);
##   one-wave 大招     - 卷心菜雨 is 对同行所有僵尸造成60伤害 with no 相邻行 clause, which
##                      follows from that same flag (PultPlant.storm_rows / act_ultimate);
##   the arc itself    - the family's; the projectile is the same thrown body, because
##                      PultProjectile says plainly that a pult which does not splash needs
##                      no change to its file.
##
## So the cabbage is the family's proof that the shape is right: the melon needed nothing
## to say either, and the difference between the two - one fifth the damage, half the
## price, no spread - is written entirely in data/units/*.csv.

const ID := "cabbage_pult"
## [P30-A] 抛掷卷心菜.
const SKILL := "cabbage_toss"
## [P30-B] 卷心菜雨: 60 down the lane, and only down the lane.
const ULTIMATE := "cabbage_rain"


func _init() -> void:
	## A paler, bluer green than the melon's (see BalanceUI.COLOR_CABBAGE): same thrown
	## ball, smaller harvest. No hit riders - the sheet gives this plant nothing to leave
	## on a body beyond its damage.
	shot_tint = BalanceUI.COLOR_CABBAGE
	setup_pult(ID, SKILL, ULTIMATE)
	## [P91] its own SHOT ROW: the family default is 西瓜 (which splashes), and a cabbage
	## that inherited it would spread damage its sheet never asked for.
	shot_id = "cabbage"
