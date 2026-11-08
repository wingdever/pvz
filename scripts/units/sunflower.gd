class_name Sunflower
extends ProducerPlant
## [P34] One lot of sun per PRODUCE, at the sheet's attack value (25). The behaviour is
## ProducerPlant's - the twin sunflower is the same script with produce_count 2 - so
## this file is the identity only. See README "单位数据表" for where the numbers live.

## [P30-A] The skill this plant defaults to: 技能代码 of its row in
## data/units/skills.csv (阳光汲取). The sheet prices it, act() performs it.
const SKILL := "sunflower_produce"
## [P30-B] The ultimate this plant defaults to: 大招代码 of its units.csv row
## (阳光爆发 - the bank gains the sheet's 大招数值 at once).
const ULTIMATE := "sun_burst"


func _init() -> void:
	setup_producer("sunflower", SKILL, ULTIMATE)
