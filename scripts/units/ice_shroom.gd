class_name IceShroom
## [P43] Extended by PATH, not by the `OneShotPlant` name, for the reason every plant in
## this family gives: a brand-new `class_name` only resolves once the EDITOR has
## rescanned it (HANDOFF §7.67), so naming it here would make every headless run fail to
## parse this file - and, through the PlantScripts table that preloads it, take the whole
## battle dispatch down with it.
extends "res://scripts/units/base/one_shot_plant.gd"
## [P43] 寒冰菇 - 一次性，全屏冻结3回合. The first plant in the board whose answer deals
## no damage: it does not kill anything, it stops everything, and it is gone afterwards.
##
## That is why the family grew a second hook. `blast_targets()` says which bodies,
## `blast_effects()` says what lands on them, and 寒冰菇 is the case where the two carry
## the whole load: its attack cell is EMPTY (which the merge reads as the value 0, not as a
## missing number - see Balance.plant_attrs), so `detonate()` skips the damage step and
## only rides the frost on. The 3 rounds are the sheet's prose (plants.csv 技能效果), and
## follow the same convention as 寒冰射手's 1 round and its 大招's 3: the rider's length
## belongs to the plant's script, because no column of any sheet holds it.
##
## What the freeze is worth is the engine's existing rule, not a new one: a frozen zombie
## skips its whole action phase with its move progress kept (GameManager), so this card
## buys the lawn three rounds of nothing biting - which is why the sheet prices it at 175
## sun, the dearest of the four 一次性 plants, and why it kills nothing on its own.

const ID := "ice_shroom"
## [P30-A] 全屏冻结.
const SKILL := "freeze_blast"
## plants.csv: 全屏冻结3回合.
const FREEZE_ROUNDS := 3


func _init() -> void:
	setup_one_shot(ID, SKILL)
	## [P50] Silent on purpose: 寒冰菇 deals no damage, so the only thing that lands is
	## the freeze rider, and the rider's own sound is already played where it is written
	## (Zombie.apply_hit_effects). A blast sample here would be an explosion the sheet
	## never said.
	blast_cue = ""


func blast_targets() -> Array:
	## 全屏 = the screen, not the lane: every living zombie on every lane of the lawn,
	## the plant's own row included and the columns behind it included (a body that
	## already walked past the mushroom is still on the board, and the sheet never says
	## "ahead"). `Balance.all_rows()` rather than the level's narrowed `rows`, because
	## "the whole screen" is the lawn a player can see - and on a level that opened one
	## lane only, the two answers are the same bodies anyway.
	## `from_col` -1 switches the query's "strictly ahead of" filter off: no cell of the
	## lawn lies left of column 0.
	if board == null:
		return []
	return board.get_zombies_in_rows(Balance.all_rows(), -1)


func blast_effects() -> Dictionary:
	return {"freeze": FREEZE_ROUNDS}