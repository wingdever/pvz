class_name WinterMelon
## [P49] Extended by PATH, not by the `PultPlant` name, for the reason potato_mine.gd
## gives: a brand-new `class_name` only resolves after the editor has rescanned it.
extends "res://scripts/units/base/pult_plant.gd"
## [P49] 冰西瓜投手 - the melon again, with the frost on it: the same arc, the same
## splash, and a body it lands on frozen for a round (the snow pea's rider, on the
## heaviest shot in the game). Cheaper than the melon it upgrades (200 sun against 300)
## and twice as long to bring back (8 rounds), which is the trade every member of the
## frost family makes: control is bought in patience, not in damage.
##
## WHAT MAKES THIS FILE FOUR LINES OF IDENTITY: the deepening of the freeze is the only
## thing its 大招 does differently from the melon's, and even that is not a new shape -
## 对同行所有僵尸造成80伤害并冻结2回合，相邻行各40伤害并冻结1回合 is the family's two
## waves with a per-wave rider, which is exactly what PultPlant's two effect
## dictionaries exist to carry. So the icy melon says WHEN it freezes and for how long,
## and never HOW a lob, a splash or a storm works.

const ID := "winter_melon"
## [P30-A] 抛掷冰西瓜.
const SKILL := "icy_melon_toss"
## [P30-B] 冰冻西瓜雨: the melon's rain, deeper.
const ULTIMATE := "frozen_melon_rain"


func _init() -> void:
	## [P49] 并冻结1回合 on the body it lands on. The four cells it splashes keep taking
	## damage only: the rider is spent on the target alone, both in the code and in the
	## sheet's own sentence. [2026-09-24, 决定 A] the splash half (对其上下左右各造成一半伤害)
	## used to live ONLY in 特殊机制 (溅射+冻结) and in the 大招, so the almanac read as if the
	## icy melon were a single-target shooter while the battle splashed; the table now says
	## what the battle does, and this row still invents no riders the prose never asked for.
	shot_id = "winter_melon_shot"        # [P91] its row carries the freeze rider
	ult_own_effects = {"freeze": 2}
	ult_side_effects = {"freeze": 1}
	## The same cold the snow pea's shot wears; the melon is bigger, not another colour.
	shot_tint = BalanceUI.COLOR_FREEZE
	setup_pult(ID, SKILL, ULTIMATE)
