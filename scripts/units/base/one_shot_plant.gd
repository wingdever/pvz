class_name OneShotPlant
extends Unit
## [P39] THE PLANTS THAT SPEND THEMSELVES - 一次性: 窝瓜 stomps, 火爆辣椒 burns a lane
## out, 樱桃炸弹 takes the 3x3 around itself and 土豆地雷 waits three rounds to do it to
## one zombie, and none of them is still standing afterwards. The sheet marks them with
## the words 一次性 in units.csv 特殊机制 (PlantDB.is_one_shot) and leaves their 生命 cell
## empty, which is the engine's own sign for "no health of its own"
## (Balance.plant_attr_hp floors such a plant at 1 so nothing divides by it).
##
## WHAT A SUBCLASS HAS TO SAY is which bodies the blast covers (`blast_targets()`),
## and - only when the blast is not just a number - what it leaves on them
## (`blast_effects()`, [P43]). Everything else is shared, and it is shared here for the
## same reason WallPlant exists - the plants of this family differ in reach and in kind,
## not in structure:
##   * the blast is a damage roll like any other, so the bodies it kills are credited
##     to this plant (exp, coin drops) through Unit.take_damage, not through a private
##     death path;
##   * after it lands, the plant is gone - hp 0 plus `died`, i.e. exactly the road a
##     zombie's death takes, so the grid unregisters it, the ledger writes it and the
##     fade-out plays without this file knowing any of that;
##   * the ONE consequence worth naming out loud: a garden plant that blasts marks its
##     slot DOWNED like a plant that was eaten, because the engine has one death road
##     and 一次性 means "spent", not "survived but idle". The garden's 肥料 is what
##     raises it again, which is the same consumable economy the sheet's 一次性 word
##     already implies.
##
## WHAT THE SHEET OWNS (AGENTS.md §2): 费用 / 卡片冷却 through plants.csv, the AP price
## through skills.csv, and the 9999 in 最近1只僵尸9999伤害 through the attack column (which
## these rows used to leave empty - an empty attack means "no skill number", and these
## plants DO have one, the prose just spelled it out instead of the column).

## The sheet id this instance reads its numbers through (see ShooterPlant.plant_id).
var plant_id: String = ""
## [P50] The sound layer, by PATH for the reason pult_plant.gd gives: a brand-new
## `class_name` does not resolve until the editor has rescanned the project, and a
## headless run cannot wait for that.
const SFX := preload("res://scripts/core/sfx.gd")
## What the blast sounds like, as a cue id of BalanceAudio.SFX_DEFS. Every 一次性 plant in this
## family detonates something, but the samples are far apart - a cherry is a crater, a
## mine is a pop and a squash is a squelch - so each subclass names its own cue here.
## "" means "this blast makes no noise of its own": 寒冰菇 deals no damage at all and the
## freeze rider it leaves already has its sound (Zombie.apply_hit_effects), so a second
## one here would be the same event twice.
var blast_cue := "blast"


func setup_one_shot(p_id: String, p_default_skill: String, p_arm_rounds: int = 0) -> void:
	## The shared opening a subclass calls from its own _init(). No ultimate argument:
	## none of these plants has a 大招 cell (窝瓜 / 火爆辣椒 both say —), and a plant
	## whose sheet has no ultimate is the engine's ordinary "no bar" state, so there is
	## nothing to hand in here.
	##
	## [P39] `p_arm_rounds` is the other half of what a 一次性 plant's own sentence says:
	## 窝瓜 / 火爆辣椒 answer the moment anything walks into reach, 土豆地雷 需3回合武装 and
	## 樱桃炸弹 种下后下回合爆炸 both name a wait. It is a plain stand-down, which the
	## engine already ticks at TURN_START (see GameManager) - so arming costs ROUNDS, not
	## a new mechanic, and a mine planted in round N is ready in N+3 exactly the way a
	## chomper that swallowed in N bites again in N+3.
	plant_id = p_id
	set_display_name("plant." + p_id)        # [P20] follows the language
	is_zombie = false
	body_shape = Shape.CIRCLE
	body_size = BalanceUI.UNIT_BODY_SIZE
	body_color = Balance.plant_def(p_id).get("color", Balance.COLOR_SQUASH)
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
	## [P30-A] the blast costs the skill sheet's 技能消耗AP like any other skill.
	skill_code = Balance.plant_skill_code(p_id, p_default_skill)
	threshold = BalanceBattle.skill_ap_cost(skill_code)
	ult_id = p_id
	ult_code = Balance.plant_ult_code(p_id, "")
	action_label = "BLAST"
	action_key = "action.blast"
	# [P15] the base blast value; a garden plant overwrites it with its own
	skill_value = Balance.plant_base_skill(p_id)
	if p_arm_rounds > 0:
		stand_down_rounds = p_arm_rounds
		stand_down_note = "arming"


func action_text() -> String:
	## [P39] The word under the bar while the fuse burns down - the same presentation
	## trick as a chewing chomper or a frozen zombie. A mine that shows BLAST while it
	## cannot act reads as a plant that broke; ARMING says the wait is the price.
	return Loc.t("action.arming", "ARMING") if stand_down_rounds > 0 else super.action_text()


# ---------------------------------------------------------------- targeting
func skill_damage() -> int:
	## [P15] The same rule as a shooter's: this instance's own skill value when it has
	## one (a garden plant, grown and potion-boosted), the sheet's base value otherwise.
	if skill_value > 0:
		return skill_value
	return Balance.plant_base_skill(plant_id)


func blast_targets() -> Array:
	## Which bodies the blast covers - the ONE thing a subclass decides. Alive or not is
	## filtered by detonate(), so a subclass may report a body a previous action killed.
	return []


func blast_effects() -> Dictionary:
	## [P43] The second question the family turned out to have, added with its first
	## non-damage member: WHAT the blast leaves on the bodies it touches. A rider
	## Dictionary is the engine's own shape for this (a shooter hands the same thing to
	## Projectile, which hands it to Unit.apply_hit_effects on impact), so the immunity
	## and the "refresh, never stack" rules stay in Zombie and this family only names
	## rounds. `{}` - what every 一次性 plant until 寒冰菇 answers - means the blast is a
	## number and nothing else, and detonate() then behaves byte for byte as before.
	##
	## This is a hook rather than a subclass `act()` override for the reason the header
	## gives: detonate() is the single place that decides whether the card was spent, and
	## a plant that reimplements the action reimplements that decision too.
	return {}


func has_target() -> bool:
	## [P39] The AP loop asks this before every point it spends (see the while in
	## _do_plant_action), so a blast that has already been spent by an energy bean finds
	## nothing left to hit and stops there.
	return not blast_targets().is_empty()


func has_skill() -> bool:
	return true


# ---------------------------------------------------------------- action
func act() -> String:
	return detonate(skill_damage())


func resolve_skill_once() -> bool:
	## The energy bean's single beat: one blast, and the plant is gone with it, so the
	## bean's remaining hits have no target and the bean refunds nothing it did not buy.
	if not has_target():
		return false
	act()
	return true


func detonate(damage: int) -> String:
	## The whole contract of this family: hit everything the subclass pointed at, then
	## stop existing. `last_attacker` is set by take_damage, so the kill credit, the
	## drops and the exp all land on this plant exactly as they do for a pea.
	var live := PackedStringArray()
	var hits := 0
	var riders := blast_effects()
	for entry in blast_targets():
		var target := entry as Unit
		if target == null or not target.is_alive():
			continue          # an earlier body of this same blast may have killed it
		var before := target.hp
		## [P43] A attack cell the sheet left empty is the number 0, and 0 is not a hit:
		## taking it would still wave the zombie through its armour soak, its 处决 gate
		## and its charge bar, i.e. a frost could execute a half-dead body it was never
		## asked to touch. So damage lands only when there is damage.
		## [P77] And it lands bare on purpose: no hit options means "this is not a shot",
		## which is the answer a screen door reads as "not my business" (Zombie.take_damage).
		## A cherry bomb was never stopped by a door, and now the code says so.
		if damage > 0:
			target.take_damage(damage, self)
		if not riders.is_empty() and target.is_alive():
			## Riders go on bodies still standing - the same damage-then-effects order a
			## projectile uses, and freezing a corpse would paint a fading unit cold.
			target.apply_hit_effects(riders)
		live.append("%s(%d,%d) hp %d -> %d" % [target.tag(), target.col, target.row,
			before, target.hp])
		hits += 1
	## [P43] The log keeps its old shape for a blast that only hurts (`BLAST 9999`), names
	## what it left behind when it also binds (`BLAST 40 + freeze x1`), and for the
	## family's first pure-control blast says `BLAST + freeze x3` rather than advertising
	## a 0 it never dealt.
	var deed := ("BLAST %d" % damage) if damage > 0 else "BLAST"
	if not riders.is_empty():
		var parts := PackedStringArray()
		for key in riders:
			parts.append("%s x%d" % [str(key), int(riders[key])])
		deed = "%s + %s" % [deed, ", ".join(parts)]
	var summary := "-> %s x %d zombie(s): %s" % [deed, hits, ", ".join(live)]
	if hits > 0:
		## [P50] The noise rides the same guard as the plant's own life: a blast that
		## found nothing alive did not happen, and a card that is still on the lawn has
		## no explosion in its future either.
		SFX.play(blast_cue)
		## The plant only spends itself when the blast actually landed: a plant that
		## found nothing alive to hit is a plant that never acted, and burning a card
		## on thin air is not what 一次性 says.
		spend_self()
	return summary


func spend_self() -> void:
	## Die the engine's own death: `_on_unit_died` unregisters the cell, counts it,
	## writes the garden ledger and plays the fade. Nothing here frees or erases
	## anything, because nothing here is allowed to.
	hp = 0
	died.emit(self)
