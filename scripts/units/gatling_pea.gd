class_name GatlingPea
extends ShooterPlant
## [P34] Four peas per action: the pea family's heaviest volley and the priciest card
## of the batch (400 sun, cooldown 6 - the sheet says both). Its 弹幕 is the lane
## storm priced at 240, i.e. the same body again with a bigger number.

## [P30-A] 豌豆连射.
const SKILL := "gatling_fire"
## [P30-B] 弹幕: one 240-damage pea per zombie in the lane.
const ULTIMATE := "bullet_storm"


func _init() -> void:
	shot_count = 4
	setup_shooter("gatling_pea", SKILL, ULTIMATE)
