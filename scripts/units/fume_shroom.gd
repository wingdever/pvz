class_name FumeShroom
extends ShooterPlant
## [P34] The puff-shroom's bigger breath: the same three cells, but every body inside
## them takes the hit and armour does not absorb any of it (the sheet's 无视铁门).
## Those two differences are the base's `targets_all_in_range` and `pierce_armor`,
## which is exactly why the two shrooms are one family and not two scripts.
##
## Its 毒雾 drops the short breath entirely: 对同行所有僵尸 - the whole lane, still
## armour-blind. That is the one line this file has to say beyond the parameters.

## [P30-A] 孢子喷射.
const SKILL := "fume_shroom_breath"
## [P30-B] 毒雾: 60 down the whole lane, armour ignored.
const ULTIMATE := "toxic_cloud"


func _init() -> void:
	range_cells = 3
	targets_all_in_range = true
	shot_id = "fume_breath"              # [P91] its row carries 穿甲
	setup_shooter("fume_shroom", SKILL, ULTIMATE)


func storm_lane(p_row: int) -> Array:
	## [P34] The 大招 reaches further than the breath does - the sheet words 毒雾 as
	## the whole row, not "the same 3 cells, all of them". Overriding the query (rather
	## than act_ultimate) also fixes ult_can_fire() for free: a full bar on a lane whose
	## only zombie stands five cells away is a real target for this cloud.
	return board.get_zombies_in_row(p_row) if board != null else []