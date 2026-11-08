class_name SpikePlant
extends Unit
## [P63] THE PLANTS THAT HURT FROM BELOW - 地刺: a low mat of spikes the zombie walks
## ONTO instead of up against. The sheet spells the family in one sentence apiece
## (units.csv 特殊机制 `僵尸踩过时造成伤害，不会被啃食`), and that sentence holds two rules
## that belong to two different owners, which is the whole reason this is a sixth family
## rather than one more row of an existing one:
##
##   踩过时造成伤害   a stab that happens during the ZOMBIE's action, because that is when
##                    the step is - so the plant pays AP out of its own round budget at a
##                    moment that is not its own action slot (see `_stab_walkers` in
##                    GameManager, the one call site).
##   不会被啃食       a fact about what a body sharing the cell may DO, read off the row
##                    once at spawn into `Unit.ignores_biting` (PlantDB.is_uneatable), which
##                    the zombie's decision consults instead of stopping to eat.
##
## Neither of the five existing families covers this. A shooter fires a projectile at a
## target it aims at; a 一次性 plant spends itself on one blast; a wall only stands there
## with `threshold = 0`. The spike shoots nothing, is not spent, and DOES act - it is the
## first plant whose ordinary action has no aim at all: it hurts whatever is standing on it.
##
## WHAT A SUBCLASS HAS TO SAY is its id and which skill / ultimate its sheet row means.
## Everything else - the AP price, the 大招's whole-lane erupt, the bar, the names - is the
## same lines the other families keep out of their leaves.
##
## [P34] Mushrooms sleeping in daylight is still not modelled; irrelevant here, but the
## note travels with every plant file so the roster reads evenly.

## The sheet id this instance reads its numbers through (see ShooterPlant.plant_id).
var plant_id: String = ""
## [P50] The sound layer, by PATH for the reason pult_plant.gd gives: a brand-new
## `class_name` does not resolve until the editor has rescanned the project, and a
## headless run cannot wait for that.
const SFX := preload("res://scripts/core/sfx.gd")
## What a stab sounds like. Deliberately NOT a new cue: 地刺 lands a hit on a body without
## a projectile in front of it, which is exactly what `impact` is for in this table, and
## inventing a 22nd sample for it would be the second cut of a different batch (§2
## 批内不混第二刀). A designer who wants the spike to sound like a spike adds the cue and
## changes this one line.
const STAB_CUE := "impact"


func setup_spike(p_id: String, p_default_skill: String, p_default_ult: String) -> void:
	## The shared opening a subclass calls from its own _init(). The AP price comes from
	## skills.csv like every other plant's: this family's 技能消耗AP cell is a number the
	## stab really spends (see `stab_the_walker`), so the row is not silent the way a
	## `threshold = 0` wall would make it.
	plant_id = p_id
	set_display_name("plant." + p_id)        # [P20] follows the language
	is_zombie = false
	## [P63] RECT, like the walls: a spike is a mat on the ground rather than a body
	## standing up off it, and the flat shape is also what lets the zombie that walks over
	## it stay readable - both of them share the cell, so the stagger the grid applies to
	## same-cell units (Unit.set_stack_index) is what keeps the two apart on screen.
	body_shape = Shape.RECT
	body_size = BalanceUI.UNIT_BODY_SIZE
	body_color = Balance.plant_def(p_id).get("color", Balance.COLOR_SPIKEWEED)
	art_path = Balance.plant_art(p_id)
	view_path = Balance.plant_view(p_id)
	max_hp = Balance.plant_max_hp(p_id)
	hp = max_hp
	## [B11] 防御 at LEVEL 1 - a garden summon re-derives it from the slot's level
	## (Battle._attach_garden_slot), exactly like the health ceiling above it.
	defence = Balance.plant_attr_defence(p_id, 1)
	# [B16] units.csv's `face` column: which way this body's picture looks (every plant: right).
	faces_left = UnitSheet.face_left(p_id)
	## [B17] the height axis off the same merged row, through Unit's one read (D103/D104).
	read_height(p_id)
	skill_code = Balance.plant_skill_code(p_id, p_default_skill)
	threshold = BalanceBattle.skill_ap_cost(skill_code)
	ult_id = p_id
	ult_code = Balance.plant_ult_code(p_id, p_default_ult)
	action_label = "SPIKE"
	action_key = "action.spike"
	## [P63] The second half of the row's sentence, read ONCE here for the same reason
	## P59 read 僵尸相邻 at spawn: the sheet is the only place the rule is written, and the
	## battle asks the instance rather than re-parsing a table on every decision.
	ignores_biting = PlantDB.is_uneatable(p_id)


# ---------------------------------------------------------------- the walkers
func walkers() -> Array:
	## The live bodies standing on THIS plant's cell. The grid keeps plants and zombies in
	## two registries, so a zombie sharing a tile with a plant is legal and always has been
	## (the same-cell stagger exists for it) - this is simply the question a spike asks
	## instead of "who can I aim at".
	var out: Array = []
	if grid == null:
		return out
	for entry in grid.get_zombies_at(col, row):
		var body := entry as Unit
		if body != null and body.is_alive():
			out.append(body)
	return out


func skill_damage() -> int:
	## [P15] The same rule as a shooter's: this instance's own skill value when it has
	## one (a garden plant, grown and potion-boosted), the sheet's base value otherwise.
	if skill_value > 0:
		return skill_value
	return Balance.plant_base_skill(plant_id)


# ---------------------------------------------------------------- the gate the AP loop never reaches
func has_target() -> bool:
	## [P63] Always false, and that is the design rather than a hole: the trigger for a
	## stab is a step, and the step happens in the zombie's own action slot. A spike that
	## answered YES here would fire in its plant phase AND under every walker afterwards -
	## the double-dip the batch's whole AP argument was about. So the plant phase prints
	## its ordinary "AP held -> no target" line and the three points sit there until the
	## zombie phase spends them.
	return false


func has_skill() -> bool:
	## True even though the ordinary loop never runs: this is what lets 能量豆 buy a stab
	## (resolve_skill_once), and a spike refused by the bean because it "has no skill"
	## would contradict the sheet's own 技能 column.
	return true


# ---------------------------------------------------------------- action
func act() -> String:
	## The energy bean's beat: erupt under whoever stands here. `resolve_skill_once()` has
	## already refused the bean when the cell is empty, so an empty list here means the
	## walker died between the two calls - say so instead of pretending a hit landed.
	var live := walkers()
	if live.is_empty():
		return "-> SPIKE but nobody stands here"
	return stab_the_walker(live[0] as Unit)


func resolve_skill_once() -> bool:
	## The bean's single beat: one erupt, and it needs a body under it to be worth the
	## bean at all (the same refund rule every other family answers with).
	if walkers().is_empty():
		return false
	act()
	return true


func stab_the_walker(walker: Unit) -> String:
	## [P63] THE ONE PLACE A SPIKE HURTS SOMEBODY, and the only exit the AP transaction
	## has: it pays the skill sheet's 技能消耗AP out of this plant's round budget, lands the
	## sheet's attack as an ordinary `take_damage` (so armour, the 处决 gate, the charge bars
	## and the kill credit all work exactly as they do for a pea), and fills its own bar
	## the way a cast fills a bar elsewhere.
	##
	## Returns "" when the plant cannot pay - a spike whose three points are gone has
	## already stabbed three bodies this round, and the caller skips an empty string, so a
	## lane of walkers simply stops being hurt rather than hurting for free.
	if walker == null or not walker.is_alive():
		return ""
	if not can_afford_action():
		return ""
	spend_action_ap()
	var before := walker.hp
	walker.take_damage(skill_damage(), self)
	if ult_charge_source() == "cast":
		charge_ultimate()
	SFX.play(STAB_CUE)
	return "-> SPIKE %d dmg -> %s(%d,%d) hp %d -> %d (AP left %d)" % [
		skill_damage(), walker.tag(), walker.col, walker.row, before, walker.hp, ap]


# ---------------------------------------------------------------- the 大招
func ult_implemented() -> bool:
	## [P30-B] A spike runs its family 大招, so every leaf of this family implements it by
	## being here. (地刺王 will get its own 大招代码 when its row is settled - a code carries
	## one number, and the two storms do not share one. See spikeweed.gd.)
	return true


func storm_lane() -> Array:
	## The bodies 尖刺风暴 erupts under: 对本行所有僵尸, the whole lane and not "the lane
	## ahead" - the same reading jalapeno's 整行 and the pea storms already use, so a body
	## that walked past the spike is still on it.
	if board == null:
		return []
	return board.get_zombies_in_row(row)


func ult_can_fire() -> bool:
	## [P63] A full bar on an empty lane is held, not spent (Unit's own rule), and this
	## family's ultimate needs prey the same way a shooter's does - it just asks a
	## different question, because it has no volley to borrow the answer from.
	return super.ult_can_fire() and not storm_lane().is_empty()


func act_ultimate() -> String:
	## [P63] 尖刺风暴: the sheet's 大招数值 down the whole row, delivered the way this
	## family delivers everything - not as a shot, but as the ground coming up. It is the
	## 一次性 `detonate()` shape (damage loop, one summary) with the family's own numbers,
	## because a spike that storms is still standing afterwards.
	var damage := BalanceBattle.plant_ult_value(ult_code)
	var live := PackedStringArray()
	var hits := 0
	for entry in storm_lane():
		var target := entry as Unit
		if target == null or not target.is_alive():
			continue          # an earlier body of this same storm may have killed it
		var before := target.hp
		target.take_damage(damage, self)
		live.append("%s(%d,%d) hp %d -> %d" % [target.tag(), target.col, target.row,
			before, target.hp])
		hits += 1
	if hits > 0:
		SFX.play(STAB_CUE)
	return "-> STORM %d dmg x %d zombie(s): %s" % [damage, hits, ", ".join(live)]
