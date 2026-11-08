class_name ShooterPlant
extends Unit
## [P87] every volley goes through the projectile factory (by PATH - see spawn.gd).
const Spawn := preload("res://scripts/core/spawn.gd")
## [P34] THE PLANT THAT SHOOTS - the behaviour half every pea-family member, snow
## pea, split pea and the two shrooms share: pick prey down one or more lanes, pay
## one AP-priced action for a volley, hand each shot to a projectile, feed the
## ultimate bar once per action.
##
## WHY A BASE CLASS AT ALL (and why these nine plants did not each copy the
## peashooter): the peashooter, the repeater and the gatling differ in ONE number -
## how many peas leave per action - and the threepeater differs in one more, which
## lanes. Without a shared body, every tuning change and every new hit rider (the
## snow pea's freeze, the fume-shroom's armour-pierce) had to be written N times,
## and the copies would drift apart silently. So a subclass declares WHAT it is
## (a few parameters and its own 大招), never HOW a shot works.
##
## THE SPLIT THAT KEEPS THE SHEETS IN CHARGE (AGENTS.md §2):
##   subclass var  = identity (shot_count, row_offsets, range_cells, hit_effects...)
##                   - "who is this plant", which is not a tuning knob;
##   data/units/*  = every number a designer may move (hp, attack, cost, cooldown,
##                   skill AP, ult value and charge), read through Balance.
## A behaviour parameter therefore never takes a damage value: the volley's damage is
## skill_damage(), i.e. the plant's own skill value, exactly like the peashooter's.
##
## A GDScript trap this class deliberately walks around: a `const` in a base class is
## resolved against the base, so a subclass that redeclares `const SKILL` would NOT
## change what the base reads. That is why the default codes arrive through
## setup_shooter()'s arguments instead of a virtual const, and why each subclass still
## keeps its own `const SKILL` / `const ULTIMATE` as the readable declaration.

## Projectiles this plant's action launches at ONE target (the repeater's 2, the
## gatling's 4). Rear-facing shots are counted separately by back_shots.
var shot_count: int = 1
## Shots that fly the OTHER way per lane, aimed at the nearest body behind the plant
## (the split pea's 1). 0 = a plain forward shooter.
var back_shots: int = 0
## Which lanes the volley covers, as offsets from this plant's own row: [0] for
## everything but the threepeater's [-1, 0, 1]. One shot per listed lane, so a plant
## on the top lawn row simply fires fewer shots instead of aiming off the board.
var row_offsets: Array[int] = [0]
## How far a shot reaches in columns; 0 = the whole lane (every pea plant), 3 = the
## short breath of the mushroom family.
var range_cells: int = 0
## False (default): one action hits the NEAREST body of each lane. True: it hits
## every body inside range_cells - the difference between a puff-shroom and a
## fume-shroom, and the shape the later shroom batch keeps using.
var targets_all_in_range: bool = false
## Status riders each shot leaves on what it hits ("freeze" -> rounds). Empty for
## every plant that only deals damage.
var hit_effects: Dictionary = {}
## True when the shot walks over armour instead of through it (the fume-shroom's
## 无视护甲 breath). Carried to Projectile, which passes it to take_damage.
var pierce_armor: bool = false
## The pea's colour: a snow pea fires the same round with a cold tint.
var shot_tint: Color = BalanceUI.COLOR_PEA
## [P49/P91] Which SHOT this plant's action launches, named by its row in
## `data/projectiles.csv` ("pea" / "snow_pea_shot" / "melon" / ...). A subclass says which
## shot it throws, never how a shot works: the volley, the charge and the summary stay
## here, and the flight, the picture, the pierce/bounce budget, the rider and the cues are
## the row's. A shot the table cannot express is the one case that gets a class.
var shot_id: String = "pea"
## The sheet id this instance reads its numbers through (plant_max_hp,
## plant_base_skill, ...). Same role as Zombie.zombie_type.
var plant_id: String = ""


func setup_shooter(p_id: String, p_default_skill: String, p_default_ult: String) -> void:
	## The shared opening a subclass calls from its own _init(), AFTER it has filled
	## the behaviour parameters above. Everything here is either boilerplate every
	## plant repeats or a number the sheet owns.
	plant_id = p_id
	set_display_name("plant." + p_id)        # [P20] follows the language
	is_zombie = false
	body_shape = Shape.CIRCLE
	body_size = BalanceUI.UNIT_BODY_SIZE
	body_color = Balance.plant_def(p_id).get("color", Balance.COLOR_PEASHOOTER)
	## [P26] art, view scene and health come from the plant's own sheet row (through
	## Balance), so a level starting plant is a plain "fresh level 1" instance and an
	## edit to the sheet moves this without a code change.
	art_path = Balance.plant_art(p_id)
	view_path = Balance.plant_view(p_id)
	max_hp = Balance.plant_max_hp(p_id)
	hp = max_hp
	## [B11] 防御 at LEVEL 1 - a garden summon re-derives it from the slot's level
	## (Battle._attach_garden_slot), exactly like the health ceiling above it.
	# [B16] units.csv's `face` column: which way this body's picture looks (every plant: right).
	faces_left = UnitSheet.face_left(p_id)
	## [B17] the height axis off the same merged row, through Unit's one read (D103/D104).
	read_height(p_id)
	## [P30-A] one volley spends the skill sheet's 技能消耗AP; which code is loaded
	## comes from units.csv 技能代码, with the subclass's const as the fall-back.
	skill_code = Balance.plant_skill_code(p_id, p_default_skill)
	threshold = BalanceBattle.skill_ap_cost(skill_code)
	## [P30-B] the loaded ultimate plus the plant id the bar reads its name from.
	ult_id = p_id
	ult_code = Balance.plant_ult_code(p_id, p_default_ult)
	action_label = "FIRE"
	action_key = "action.fire"
	# [P15] the base skill value; a garden plant overwrites it with its own
	skill_value = Balance.plant_base_skill(p_id)


# ---------------------------------------------------------------- targeting
func launch_shot(target: Unit, damage: int, opts: Dictionary, shot: String = "") -> void:
	## [P87] THE ONE LAUNCH POINT of this family: every volley, every storm and every pult
	## throws through here, so "what does a bare shot default to" is answered in one place
	## (the factory: the class and the damage). A SUBCLASS must not call the factory itself -
	## a GDScript `const` is inherited and repeating it in the child is a parse error, the
	## same rule the SKILL const above obeys.
	Spawn.create_projectile(self, target, damage, opts, shot if shot != "" else shot_id)


func skill_damage() -> int:
	## [P15] The damage one shot resolves: this instance's own skill value when it
	## has one (a garden plant), the sheet's base value otherwise.
	if skill_value > 0:
		return skill_value
	return Balance.plant_base_skill(plant_id)


func reach() -> int:
	## The column window a lane search uses: the plant's short breath, or the whole
	## lawn in front of it. Kept as one expression so the volley and its log cannot
	## disagree about where the plant's fire ends.
	return range_cells if range_cells > 0 else Balance.COLS


func target_rows() -> Array:
	## The lanes this plant shoots down: its own row plus row_offsets, still inside
	## the lawn. [P34] A threepeater planted on the top row has no row above it, so
	## its volley is simply two shots instead of three.
	var out: Array = []
	for off in row_offsets:
		var r: int = row + int(off)
		if r >= 0 and r < Balance.ROWS:
			out.append(r)
	return out


func row_target(p_row: int) -> Unit:
	## The body a shot down lane p_row is aimed at: the nearest one ahead of this
	## plant and inside its reach. Null means the lane is empty.
	if board == null:
		return null
	var victims: Array = board.get_zombies_ahead([p_row], col, reach())
	return null if victims.is_empty() else victims[0]


func find_target() -> Unit:
	## The prey this plant's next shot goes to, in its OWN lane. The name is the one
	## docs/ADD_UNIT.md teaches and the target-priority self-check calls; with the
	## default row_offsets of [0] it is exactly what the volley below aims at, and a
	## multi-lane plant simply has more lanes than this one answer.
	return row_target(row)


func row_back_target(p_row: int) -> Unit:
	## The nearest body BEHIND the plant in this lane, which is what a split pea's
	## rear shot aims at. GameManager's lane query picks the leftmost zombie of the
	## whole lane when it allows prey behind, so "closest behind" is asked here.
	if board == null:
		return null
	var best: Unit = null
	for u in board.units:
		if not u.is_zombie or not u.is_alive() or u.row != p_row:
			continue
		if u.col >= col:
			continue
		if best == null or u.col > best.col:
			best = u
	return best


func volley() -> Array:
	## The shots this plant's action would deliver, as {target, row, dir} entries.
	## One list answers both "is there anything to shoot at" (has_target) and "what
	## does the action do" (act), which is why the two can never drift apart.
	var out: Array = []
	if board == null:
		return out
	for r in target_rows():
		var first := row_target(r)
		if first != null:
			var victims: Array = [first]
			if targets_all_in_range:
				victims = board.get_zombies_ahead([r], col, reach())
			for item in victims:
				for i in shot_count:
					out.append({"target": item, "row": r, "dir": 1})
		if back_shots > 0:
			var behind := row_back_target(r)
			if behind != null:
				for i in back_shots:
					out.append({"target": behind, "row": r, "dir": -1})
	return out


func has_target() -> bool:
	## No prey in any lane -> hold the AP instead of wasting a shot on nothing.
	return not volley().is_empty()


# ---------------------------------------------------------------- action
func has_skill() -> bool:
	return true


func resolve_skill_once() -> bool:
	## [P15] One instant volley, for the energy bean. Refuses (and so keeps the bean)
	## when there is nothing in front of or behind it.
	if not has_target():
		return false
	act()
	return true


func shot_options(p_row: int, p_dir: int) -> Dictionary:
	## What THIS plant tunes on each shot: the lane, the way it flies, the colour, and only
	## the riders it deliberately overrides. [P91] The muzzle is the pea's own and mirrors
	## with the direction, so a rear shot leaves the back of the head instead of the front.
	## An ABSENT key means "the shot's row decides" - which is why the two rider keys are
	## added only when this instance really carries one (its row is where a freeze, an
	## armour-piercing breath or a splash normally comes from).
	var muzzle := BalanceUI.PEA_MUZZLE_OFFSET
	if p_dir < 0:
		muzzle = Vector2(-muzzle.x, muzzle.y)
	var opts := {
		"from_offset": muzzle,
		"row": p_row,
		"dir": p_dir,
		"tint": shot_tint,
	}
	if not hit_effects.is_empty():
		opts["effects"] = hit_effects
	if pierce_armor:
		opts["pierce_armor"] = true
	return opts


func brawl_shot_id() -> String:
	## [B8+] THE BRAWL'S DOOR: "what does this body fire", asked by BrawlActor before every blow.
	## A plant that SHOOTS answers with the row of data/projectiles.csv it already fires in the
	## turn engine - so "does this thing shoot, and what with" is answered by ONE fact in both
	## modes (BRAWL.md §8.7), and a wall-nut, a sunflower or a cherry bomb (none of which is a
	## ShooterPlant) simply has no such method and swings at what it can touch.
	## NOTE the flight is the ROW's, not this class's: a pea is 直线 in the brawl too, which
	## means it can WHIFF a walking target. The user called that part of the game (O44).
	return shot_id


func brawl_shot_tint() -> Color:
	## [B31] THE FIFTH DOOR, and the colour half of the same question: "what does this shot LOOK
	## like". The brawl reads the shooter's `body_color` for every flight, which is right for a
	## piece whose pea IS its colour, and wrong for a 暖阳 - the sun picture takes the tint
	## (`Projectile.look_takes_tint`), so a green plant would paint a green sun. The turn engine
	## paints the same row with `shot_tint`, so the brawl asks for that same field instead of
	## guessing: one colour, both modes, still owned by the body.
	return shot_tint


func fire_shot(target: Unit, damage: int, p_row: int, p_dir: int) -> void:
	## [P33] Tune and call: the projectile owns the rest - flight, the lane
	## collision, the damage and its own animation booking. Under the synchronous
	## resolver (fast_forward, the self-checks) fire() settles here and now.
	## [P49] `shot_class` is where a melon arrives (see PultPlant): every shooter of
	## the first two batches fires the same round pea with its own tint, so until now
	## the class and the tint were the same decision.
	launch_shot(target, damage, shot_options(p_row, p_dir))


func act() -> String:
	var shots := volley()
	if shots.is_empty():
		return "-> FIRE but no target (should not happen)"
	var damage := skill_damage()
	var staged: bool = board != null and board.resolution_staged and grid != null
	var summary := PackedStringArray()
	for shot in shots:
		var target: Unit = shot["target"]
		if not target.is_alive():
			continue          # the synchronous path can kill it mid-volley
		var before := target.hp
		fire_shot(target, damage, int(shot["row"]), int(shot["dir"]))
		summary.append("%s(%d,%d) hp %d" % [target.tag(), target.col, target.row, before])
	## [P30-B] ONE action, one point of charge - a four-barrel volley does not fill
	## the bar four times faster than a single shot (the sheet may re-point 大招充能
	## to "hit", and then the cast stops feeding the bar).
	if ult_charge_source() == "cast":
		charge_ultimate()
	var suffix := " (damage on impact)" if staged else ""
	return "-> FIRE %d dmg x %d shot(s) -> %s%s" % [damage, summary.size(),
		"; ".join(summary), suffix]


func ult_implemented() -> bool:
	## [P30-B] A shooter runs its family 大招; each subclass overrides act_ultimate()
	## and keeps this true. A plant that loads an ultimate code its script never
	## implemented would draw a bar that fills and never pays out, which is what the
	## Unit.has_ultimate() wiring check exists to prevent.
	return true


func ult_can_fire() -> bool:
	## [P30-B] The default ultimate is a volley down the lane(s) this plant covers, so
	## it needs prey in at least one of them: a full bar on an empty lawn is HELD, not
	## wasted - the charge does not expire with the round. [P34] Asking the same
	## `storm_lane()` the ultimate itself fires into is what keeps a short-breathed
	## shroom from spending its bar on a zombie standing outside that breath, and a
	## threepeater from waiting for prey in its own row while the neighbours are full.
	## A subclass whose 大招 pays out without a target (none today) overrides this and
	## calls back into it via super.
	if not super.ult_can_fire() or board == null:
		return false
	for r in storm_rows():
		if not storm_lane(int(r)).is_empty():
			return true
	return false


func storm_rows() -> Array:
	## [P34] The lanes this plant's 大招 sweeps. Its own row for everything in the pea
	## family that shoots straight; the multi-lane plants replace this with the rows
	## their volley already covers (see Threepeater.storm_rows).
	return [row]


func storm_lane(p_row: int) -> Array:
	## [P34] The bodies one swept lane hits: as far as this plant's breath reaches when
	## it has a short one (the shrooms' 3 cells), the whole lane otherwise - and the
	## whole lane means 对同行所有僵尸, including bodies that already walked past it.
	if board == null:
		return []
	return board.get_zombies_ahead([p_row], col, range_cells) if range_cells > 0 \
		else board.get_zombies_in_row(p_row)


func fire_row_storm(p_effects: Dictionary = {}) -> String:
	## [P34] The pea family's shared 大招 body: one shot per zombie in this plant's own
	## lane, each for the sheet's 大招数值. `p_effects` replaces the plant's own hit
	## riders for this cast only - the snow pea's 冰封 freezes three rounds instead of
	## the one its ordinary shot leaves behind.
	return fire_lane_storm([row], BalanceBattle.plant_ult_value(ult_code), p_effects)


func fire_lane_storm(p_rows: Array, p_damage: int, p_effects: Dictionary = {}) -> String:
	## [P34] The same storm down EVERY lane listed: the threepeater's 三线齐射 hands in
	## its three, a shroom's 孢子云 keeps its short breath (both through storm_lane()).
	## [P58] Which bodies and what number are all that is decided here now; the shooting
	## itself moved to fire_storm(), which the ring storms hand their own list into.
	var victims: Array = []
	for item in p_rows:
		victims.append_array(storm_lane(int(item)))
	return fire_storm(victims, p_damage, p_effects)


func _storm_dir(target: Unit) -> int:
	## [P58] The way a shot at THIS body has to fly: the body's own side of the plant.
	## The lane queries only ever answered "ahead of me", so every storm before the ring
	## batch could hard-code +1 - and a whole-lane storm therefore handed a body that had
	## already walked past the plant a forward pea, which landed on somebody else and
	## took their hit twice while the walker took none. Projectile derives the same answer
	## from the two positions when a shot does not name a direction (see its `dir` default).
	return 1 if target.col > col else -1


func _nearer_first(a: Unit, b: Unit) -> bool:
	## [P58] The order a storm shoots in: nearest body to this plant first, whichever
	## side of it the body stands on - which is what lets fire_storm() count the bodies
	## each shot has to pass on its own side (see the P33 note there).
	return absi(a.col - col) < absi(b.col - col)


func fire_storm(victims: Array, p_damage: int, p_effects: Dictionary = {}) -> String:
	## [P58] THE STORM BODY this family's 大招 share, pulled out of fire_lane_storm() so
	## a storm that is not a lane gets the same rules instead of a second copy of them:
	## [P33] the staggering - the pea aimed at the i-th nearest body of a lane is given
	## pierce = i so it passes the nearer bodies untouched and lands on its own target
	## (the query already returns exactly the live bodies, so there are always i of them
	## closer at launch time); the re-check that a synchronous earlier hit may have killed
	## a later victim; the sheet's `p_effects` replacing this plant's own riders for this
	## cast; the summary and the "damage on impact" suffix. Under the synchronous resolver
	## fire() settles each hit on its own target here and now.
	var ordered := victims.duplicate()
	ordered.sort_custom(_nearer_first)
	var counts := {}
	var summary := PackedStringArray()
	var hits := 0
	for entry in ordered:
		var target := entry as Unit
		if target == null or not target.is_alive():
			continue          # a synchronous earlier storm shot may have killed it
		var before := target.hp
		var dir := _storm_dir(target)
		var key := Vector2i(target.row, dir)
		var opts := shot_options(target.row, dir)
		opts["pierce"] = int(counts.get(key, 0))
		## [P91] A storm spreads over LANES (or over the rows a plant covers) by itself, so
		## its shots never clip the cells beside a landing: an EXPLICIT 0 beats the row's
		## splash, which is what keeps a side lane from paying the same number twice -
		## the ordinary volley opts into the splash in PultPlant.fire_shot instead.
		opts["splash"] = 0.0
		counts[key] = int(counts.get(key, 0)) + 1
		if not p_effects.is_empty():
			opts["effects"] = p_effects
		launch_shot(target, p_damage, opts)
		summary.append("%s(%d,%d) hp %d" % [target.tag(), target.col, target.row, before])
		hits += 1
	var suffix := " (damage on impact)" \
		if board != null and board.resolution_staged and grid != null else ""
	return "-> ULT %d x %d zombie(s)%s: %s" % [p_damage, hits, suffix, ", ".join(summary)]


func act_ultimate() -> String:
	## [P30-B] The default shooter ultimate (see fire_lane_storm): the sheet's number
	## down every lane this plant's 大招 covers. A plant whose 大招 works differently -
	## extra riders, or a shot into the cell behind - replaces this whole function.
	return fire_lane_storm(storm_rows(), BalanceBattle.plant_ult_value(ult_code))
