class_name PuffShroom
extends ShooterPlant
## [P34] The cheap short-range shroom: free to plant, one target, and a breath only
## three cells long - which the base turns into "the nearest body inside reach()"
## through range_cells alone. Its 孢子云 is that same breath, paid out to everything
## standing in it instead of only the nearest.
##
## [P34] Mushrooms sleeping in daylight is NOT modelled here (the level data has no
## time-of-day field yet); that waits for the one-shot-plant batch, see the plan's
## "明确不做".

## [P30-A] 短程孢子.
const SKILL := "puff_shroom_fire"
## [P30-B] 孢子云: 30 to every zombie inside the same 3 cells.
const ULTIMATE := "spore_cloud"


func _init() -> void:
	range_cells = 3
	setup_shooter("puff_shroom", SKILL, ULTIMATE)
