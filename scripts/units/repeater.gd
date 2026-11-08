class_name Repeater
extends ShooterPlant
## [P34] Two peas where the peashooter fires one - which is the whole difference, so
## the whole difference is one parameter. Its 双重风暴 is the same lane storm with
## the sheet's higher number (120) behind it.
##
## The 融合 wording in data/units/units.csv (豌豆+豌豆) is the plant's design story;
## fusion as a mechanic is not implemented, so this card is bought or rewarded like
## every other (see docs/ADD_UNIT.md "出场途径").

## [P30-A] 豌豆双射: the skill sheet prices this volley's AP.
const SKILL := "repeater_fire"
## [P30-B] 双重风暴: one 120-damage pea per zombie in the lane.
const ULTIMATE := "double_storm"


func _init() -> void:
	shot_count = 2
	setup_shooter("repeater", SKILL, ULTIMATE)
