class_name SplitPea
extends ShooterPlant
## [P34] The pea that watches its back: two shots forward, one backward per action,
## which the base volley builds from shot_count / back_shots alone (a rear shot is
## just a shot with dir -1 - Projectile already flies both ways).
##
## Its 前后夹击 is the ONE ultimate of this batch that is not a plain lane storm: the
## sheet asks for the lane AND the body standing in the cell directly behind the
## plant, so act_ultimate() adds that one extra shot to the storm below it.

## [P30-A] 豌豆裂射.
const SKILL := "split_pea_fire"
## [P30-B] 前后夹击: 80 down the lane, 80 to the zombie one cell behind.
const ULTIMATE := "pincer_attack"


func _init() -> void:
	shot_count = 2
	back_shots = 1
	setup_shooter("split_pea", SKILL, ULTIMATE)


func act_ultimate() -> String:
	## [P34] 前后夹击: the lane storm, then the one shot at whoever stands in the cell
	## behind the plant (get_zombies_ahead asked from col-2 with a window of 1 is
	## exactly "the cell behind", not "anything further back").
	var line := fire_row_storm()
	var damage := BalanceBattle.plant_ult_value(ult_code)
	var behind: Array = board.get_zombies_ahead([row], col - 2, 1)
	if behind.is_empty():
		return line + " | behind: nobody one cell back"
	var target: Unit = behind[0]
	var before := target.hp
	launch_shot(target, damage, shot_options(row, -1))   # [P91] its own row decides the rest
	return line + " | behind %s(%d,%d) hp %d" % [target.tag(), target.col, target.row, before]
