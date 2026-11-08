class_name Threepeater
extends ShooterPlant
## [P34] The pea that covers three lanes: one shot up, one straight ahead, one down,
## which is the base volley with row_offsets filled in. A plant on the top or bottom
## lawn row simply fires two shots - target_rows() drops the lane that is not there
## instead of aiming off the board.
##
## Its 三线齐射 is the same three lanes storming, so this file replaces the ROWS the
## 大招 covers and lets the base body do the rest.

## [P30-A] 三行发射.
const SKILL := "threepeater_fire"
## [P30-B] 三线齐射: 60 to every zombie of all three lanes.
const ULTIMATE := "triple_volley"


func _init() -> void:
	row_offsets = [-1, 0, 1]
	setup_shooter("threepeater", SKILL, ULTIMATE)


func storm_rows() -> Array:
	## [P34] 对上中下三行所有僵尸: the volley's own lanes, so act_ultimate() and
	## ult_can_fire() both follow the three rows without repeating this list.
	return target_rows()
