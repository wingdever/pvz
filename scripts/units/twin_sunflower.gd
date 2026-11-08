class_name TwinSunflower
extends ProducerPlant
## [P34] Two lots of sun where the sunflower banks one - the sheet's 技能效果 says
## exactly that ("每3回合获得2个阳光"), which is why the twin is not a second script
## with its own arithmetic but this body with produce_count 2. The lot's value stays
## the plant's own attack, so a garden upgrade raises both plants from the sheets.
##
## Its 阳光洪流 is ProducerPlant's bank-in-one-go 大招 with the twin's own number
## (150, where the sunflower's 阳光爆发 has 75); nothing here adds behaviour.

## [P30-A] 阳光双汲取: the same one-action-per-produce skill, priced like the
## sunflower's at 3 of the round's 3 AP.
const SKILL := "twin_sunflower_produce"
## [P30-B] 阳光洪流: +150 sun right away.
const ULTIMATE := "sun_flood"


func _init() -> void:
	produce_count = 2
	setup_producer("twin_sunflower", SKILL, ULTIMATE)
