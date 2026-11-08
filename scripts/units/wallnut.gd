class_name Wallnut
extends WallPlant
## [P34] The pure blocker: no skill, no target, a big health pool and 铁壁. The
## behaviour is WallPlant's now (the tall-nut is the same body with a longer brace and
## a deeper pool from its own sheet row), so this file is the identity only.

## [P30-B] The ultimate this plant defaults to: 大招代码 of its units.csv row
## (铁壁). It has no basic skill to cast, so the sheet charges the bar per HIT
## (大招充能 = 受击) - every bite it survives brings the wall down the lane to
## the 50% self-heal that is its own.
const ULTIMATE := "wall_nut_wall"


func _init() -> void:
	setup_wall("wallnut", ULTIMATE)
