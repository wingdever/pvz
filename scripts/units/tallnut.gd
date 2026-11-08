class_name Tallnut
extends WallPlant
## [P34] The wall-nut's thicker cousin: the same "stand there and be bitten" body, a
## deeper pool from its own sheet row and 钢铁壁垒, which braces for TWO rounds instead
## of the wall-nut's one. That difference is the only reason this file exists - and the
## only parameter WallPlant asks a subclass for.

## [P30-B] The ultimate its units.csv row defaults to: 钢铁壁垒 (heal 50% of max HP,
## then refuse every hit for two rounds). Charged 受击 like the wall-nut: a blocker
## with no skill fills its bar by being bitten.
const ULTIMATE := "steel_bulwark"


func _init() -> void:
	immunity_rounds = 2
	setup_wall("tallnut", ULTIMATE)
