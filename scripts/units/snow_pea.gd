class_name SnowPea
extends ShooterPlant
## [P34] The pea that slows: the same single shot, painted cold and carrying the
## freeze rider that GameManager's zombie phase honours (a frozen body skips its
## whole action, its move progress kept for when it thaws).
##
## [P30-A] and [P30-B] are the base's again - what this plant adds is one Dictionary
## of hit riders and a colder 大招 that freezes for three rounds instead of one. The
## damage itself stays the sheet's attack, so freezing is never a hidden damage buff.

## [P30-A] 冰豌豆.
const SKILL := "snow_pea_fire"
## [P30-B] 冰封: 40 to the lane and every hit body frozen for 3 rounds.
const ULTIMATE := "deep_freeze"


func _init() -> void:
	## [P34/P91] The freeze this plant's ordinary shot leaves behind is its SHOT ROW's
	## 命中状态 + 状态值 (one round, the sheet's 技能效果); the 大招 below overrides it.
	shot_id = "snow_pea_shot"
	shot_tint = BalanceUI.COLOR_FREEZE
	setup_shooter("snow_pea", SKILL, ULTIMATE)


func act_ultimate() -> String:
	## [P34] 冰封: the row storm with deeper frost on it - `p_effects` replaces this
	## plant's own rider for this cast only (see ShooterPlant.fire_row_storm).
	return fire_row_storm({"freeze": 3})
