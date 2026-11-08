class_name PultPlant
extends ShooterPlant
## [P49] THE PLANTS THAT THROW - 投手: the same one-action-against-one-zombie shape as
## the pea family, but the shot describes an arc instead of a line, so it passes over
## whatever stands in front (卷心菜 / 玉米 的 越过障碍物) and lands on a body with its
## neighbours taking a share of the hit (西瓜 的 上下左右各一半).
##
## WHY A BASE CLASS AND NOT A PEASHOOTER COPY WITH A BIGGER BULLET: the four pult rows the
## sheet has carried since P26 differ in three things only - what the lob costs (a sheet
## number), whether the shot splashes ( [P51]: also a sheet column now, see splash_ratio),
## and what the 大招's second wave leaves on the rows beside it. The pea family proved that
## shape is worth sharing (see ShooterPlant's header for the argument), and the pults prove
## it again from the other side: this file changes HOW a shot travels, and every one of the
## nine shooters keeps doing what it did before.
##
## WHAT A SUBCLASS HAS TO SAY (and nothing else):
##   shot_tint           what the thrown body looks like;
##   hit_effects         what an ordinary hit leaves on the body it lands on;
##   ult_own_effects     ...  and what the 大招's own row takes;
##   ult_side_effects    ...  and what the rows beside it take.
## The melon says none of the last three (it only throws); the icy melon says all of them
## (freeze 1 on a hit, 2 on the storm's own row, 1 on its neighbours).
##
## WHAT THE SHEET OWNS (AGENTS.md §2): 生命 / attack / 费用 / 卡片冷却 from plants.csv and
## units.csv, the AP price from skills.csv, the 大招数值 from skills.csv too - the half the
## splash and the second wave are computed from is therefore the SAME 80 the sheet wrote,
## never a second number invented here. Only the fraction ( Balance.PULT_SPLASH_RATIO) is
## a global rule, and it lives in Balance for that reason. [P51] adds a third sheet fact to
## the list: WHETHER a given pult splashes at all is the 特殊机制 column's answer, not a
## line in the subclass ( PlantDB.has_splash), and the 大招's second wave follows it.

## [P49/P91] The lobbed body is the `melon` ROW of data/projectiles.csv now (轨迹 = 抛射),
## so 投手 need no projectile class of their own: the arc, the "flies over what stands in
## the way" rule, the door not stopping it and the melon picture all come from the row.
## 卷心菜 differs from 西瓜 by its own row, not by a subclass.

## What the four cells around a landing point take, as a fraction of the shot's own
## damage ( Balance.PULT_SPLASH_RATIO). 0 turns this plant back into a straight thrower.
## [P51] WHO SETS IT: setup_pult() reads the sheet ( PlantDB.has_splash), because the
## 特殊机制 column already wrote the difference - 西瓜 says 溅射伤害, 卷心菜 says only
## 可越过墓碑、屋顶等障碍. A subclass that assigned this by hand would be a second place
## where the same sentence lives, and the day the column is edited it would disagree.
var splash_ratio: float = Balance.PULT_SPLASH_RATIO
## Riders the 大招 leaves on its OWN row and on the rows beside it. Empty = none, and for
## a row that is empty the plant's ordinary `hit_effects` still apply (see
## ShooterPlant.fire_lane_storm: an effects dict handed in REPLACES them for that cast).
var ult_own_effects: Dictionary = {}
var ult_side_effects: Dictionary = {}


func setup_pult(p_id: String, p_default_skill: String, p_default_ult: String) -> void:
	## The shared opening a subclass calls from its own _init(), exactly like
	## setup_shooter(), plus the two things this family says about itself: the body it
	## throws, and the word under its action bar (抛掷, not 开火 - a pult never aims down
	## a lane, it lobs at whatever is nearest).
	setup_shooter(p_id, p_default_skill, p_default_ult)
	## [P91] The family's default row - applied ONLY when the subclass did not name one,
	## because a subclass fills its identity BEFORE calling this (the same rule the header
	## states for SKILL): assigning unconditionally would silently turn 卷心菜 and 冰西瓜
	## into plain 西瓜.
	if shot_id == "pea":
		shot_id = "melon"
	action_label = "TOSS"
	action_key = "action.toss"
	## [P51] The one behaviour parameter the family does NOT leave to the subclass: the
	## sheet's 特殊机制 already said whether this pult's shot spreads, and reading it here
	## is what lets 卷心菜投手 be a three-line file instead of a file that quietly disagrees
	## with its own row. Read AFTER setup_shooter(), which is what plants the id.
	splash_ratio = Balance.PULT_SPLASH_RATIO if PlantDB.has_splash(p_id) else 0.0


func spreads() -> bool:
	## [P51] Does this pult's hit reach past the body it landed on? One sheet column
	## answers it, and three places in this file ask: the volley's `splash` option, the
	## landing sound, and whether the 大招 owns the lanes beside it.
	return splash_ratio > 0.0


func adjacent_rows() -> Array:
	## The lanes the second wave covers: this plant's row above and below, still inside
	## the lawn. A pult on the top or bottom row simply has one neighbour instead of two,
	## which is the same rule target_rows() applies to a threepeater's volley.
	var out: Array = []
	for off in [-1, 1]:
		var r: int = row + off
		if r >= 0 and r < Balance.ROWS:
			out.append(r)
	return out


func storm_rows() -> Array:
	## [P49] The lanes this plant's 大招 sweeps, which for a pult is not just its own:
	## 西瓜雨 says 对同行所有僵尸…并对相邻行各造成40伤害. ult_can_fire() reads this list,
	## so a pult whose own lane is empty but whose neighbour is full spends its bar
	## instead of holding it for prey that is not coming.
	## [P51] A pult that does not splash does not storm sideways either: 卷心菜雨 is written
	## as 对同行所有僵尸造成60伤害 and nothing more. The same column answers both - which is
	## a claim about the sheet, not about the code: for all four 投手 rows the 特殊机制 and
	## the 大招效果 wording agree, so one flag carries both. A future row that wants a storm
	## sideways WITHOUT a splash needs its own column before it gets its own rule here.
	if not spreads():
		return [row]
	return [row] + adjacent_rows()


func shot_options(p_row: int, p_dir: int) -> Dictionary:
	## [P49] Two presentation changes to what the pea hands the shot: it leaves the CUP
	## on top of the plant's head, and it travels at the lobbing speed. The collision, the
	## booking and the splash arithmetic are untouched - which is the whole point of
	## overriding the options dictionary instead of the flight.
	var opts := super.shot_options(p_row, p_dir)
	var muzzle := BalanceUI.PULT_MUZZLE_OFFSET
	if p_dir < 0:
		muzzle = Vector2(-muzzle.x, muzzle.y)
	opts["from_offset"] = muzzle
	opts["speed"] = BalanceUI.PULT_SPEED
	return opts


func fire_shot(target: Unit, damage: int, p_row: int, p_dir: int) -> void:
	## [P49] The ORDINARY volley is the thing that splashes. The 大招 deliberately does
	## not: it already spreads over rows by itself (see act_ultimate), so a storm melon
	## that also splashed would make a zombie in a neighbouring lane take the row's 40 AND
	## its own cell's 40 - twice the number the sheet wrote.
	var opts := shot_options(p_row, p_dir)
	if spreads():
		opts["splash"] = splash_ratio
	## [P50] A pult THROWS, so it does not use a pea's launch sound; and which landing it
	## answers with follows the very sheet column that decided the splash - a melon that
	## spreads is a heavy body, while 卷心菜 / 玉米 (splash 0 until the sheet says 溅射)
	## still go flop. Deriving it here means no per-plant sound knob can drift from the data.
	opts["sfx"] = "lob"
	opts["sfx_hit"] = "melon_impact" if spreads() else "impact"
	launch_shot(target, damage, opts)


func act_ultimate() -> String:
	## [P49] 西瓜雨 / 冰冻西瓜雨: the sheet's number down this plant's own row, and HALF
	## of it down the rows beside it - the same 上下左右 shape one melon makes around its
	## landing point, now spread over whole lanes. The half is COMPUTED from the 大招数值
	## (80 -> 40), so editing skills.csv moves both waves at once and this file never
	## writes the 40 that the sheet's own sentence already spells.
	var value := BalanceBattle.plant_ult_value(ult_code)
	var own := fire_lane_storm([row], value, ult_own_effects)
	## [P51] One lane, one wave: 卷心菜雨 says 对同行所有僵尸造成60伤害 and stops there, so a
	## pult whose shot does not spread spends its bar down its own lane alone.
	if not spreads():
		return own
	var sides := adjacent_rows()
	if sides.is_empty():
		return own
	var half := maxi(1, int(round(float(value) * Balance.PULT_SPLASH_RATIO)))
	return own + " | " + fire_lane_storm(sides, half, ult_side_effects)
