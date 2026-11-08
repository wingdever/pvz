class_name Peashooter
extends ShooterPlant
## [P34] The plant every other shooter is cut from: one pea, its own lane, the whole
## length of it - and a 大招 that pays that lane back at every zombie standing in it.
## All of that behaviour is ShooterPlant's now, so this file is the identity only: the
## two codes the sheet may override, and nothing else. The repeater, the gatling pea
## and the snow pea are this same four lines with different parameters and a
## different ultimate code, whose value the sheet - not the script - decides.

## [P30-A] The skill this plant defaults to: 技能代码 of its row in
## data/units/skills.csv (豌豆射击). The sheet prices it, act() performs it.
const SKILL := "peashooter_fire"
## [P30-B] The ultimate this plant defaults to: 大招代码 of its row in
## data/units/units.csv (豌豆风暴). Same split as the skill: the sheet carries
## the value (大招数值) and the charge phrase (大招充能), the base performs it.
const ULTIMATE := "pea_storm"


func _init() -> void:
	setup_shooter("peashooter", SKILL, ULTIMATE)
