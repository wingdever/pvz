class_name War
extends Node2D
## [W3] THE WAR ARENA - one real-time match: its clock, its fixed world, its camera.
##
## The root script of scenes/war.tscn, and the tree below IS the ownership diagram, the way
## brawl.tscn promises its own:
##
##   War          (this, Node2D)      one match's lifetime
##   ├─ WarField  (BrawlField)        the ground: a FIXED-world map-sized board
##   │  └─ WarCamera (Camera2D)       the spectator's eyes: WASD / ctrl-drag / ctrl-wheel / +-
##   └─ WarHudLayer (CanvasLayer)     above the camera's frame, by design
##      └─ WarHud  (Control)          the commander's only instrument panel [W5]
##
## THIS FILE IS brawl.gd's SKELETON, deliberately cloned rather than shared: the tick order,
## the six timed-object lists, the factory doors Spawn calls, and the spectator keys all
## belong to the brawl engine's contract and stay Brawl's. What differs is the world the
## skeleton stands in and the rules that end it, and both differences are this file's job:
##
##   * the field is a WarField (fixed 96 px cell, map-sized grid), so the engine's gates
##     answer for THIS board; bodies hang in the camera's frame instead of a window's;
##   * art scale is WORLD_CELL / Balance.CELL_SIZE - a constant 1.0 - and never
##     BrawlLayout.piece_scale(), the one brawl.gd line the war must not inherit;
##   * RAGE is out: a brawl's clock-forced attrition exists to end a symmetric deadlock, and
##     a war's round list breaks the deadlock on its own. The actors still take a rage
##     number, so they take a 0.
##   * the OUTCOME is the war's own [W8]: a BOUT is won when its rolled enemy half falls;
##     the last round falling is the WAR winning, a middle round falling hands the field
##     back to the deployment table (`settled` with winner "round"), and the player's half
##     emptying is losing - draw only on the mutual kill at the last round. It is NOT
##     brawl's "both empty = draw" - an arena that has fielded nobody yet has two empty
##     halves and is not over.
##   * the enemy is a ROLDED ROUND, not a timeline [W8]: W5's scheduler walked absolute
##     delays and died of rounds. WarWaveGen draws the whole session's round list once from
##     setup.roll_seed and the map's weighted piece pool, setup.rounds[setup.round_no] says
##     which bout this arena fights, the deployment page scouts it before the march, and
##     _begin() fields exactly it - so an R-replay lands the same army on the same squares.
##   * the readouts are a HUD on a CanvasLayer (war_hud.gd), pushed fresh every frame -
##     the root may not draw them itself because the camera transforms this node's canvas.
##
## WHAT IT MAY TOUCH: the static modules, the domain objects and the factory - and NOT Game,
## saves or the front end (BRAWL.md §12, the boundary the same two signals `settled` / `left`
## hold up). F6 on this scene runs the fixture: an EMPTY field the waves arrive at and walk
## across forever - [W5] refuses to call "zero left" a loss when nobody ever fielded a side
## (the deployment page never lets an empty army march; this is the harness talking), so the
## arena stays live as the camera's and the HUD's quickest harness.

const Spawn := preload("res://scripts/core/spawn.gd")
const Shot := preload("res://scripts/core/brawl/brawl_shot.gd")
const Beam := preload("res://scripts/core/brawl/brawl_beam.gd")
const Gulp := preload("res://scripts/core/brawl/brawl_gulp.gd")
const Shadow := preload("res://scripts/core/brawl/brawl_shadow.gd")
const Tornado := preload("res://scripts/core/brawl/brawl_tornado.gd")
## [W3] WarSetup BY PATH for the batch's own reason: a brand-new class_name is invisible to a
## headless run until the project has been rescanned (§1.4), and this file must not depend
## on that rescan to parse.
const Setup := preload("res://scripts/core/war/war_setup.gd")

signal settled(result: Dictionary)
signal left(reason: String)

## UNtyped on purpose, both: WarField's map doors and WarCamera's framing doors are this
## batch's own new classes, and a typed handle would ask the parser to know them before the
## first rescan has registered them. Every call below is one the class documents anyway.
@onready var field = $WarField
@onready var camera = $WarField/WarCamera
## [W5] UNtyped like the two handles above, same reason: WarHud is this batch's own new
## class. Every call below is one the class documents (begin_match / tick / show_result).
@onready var hud = $WarHudLayer/WarHud

var clock: BrawlClock = null
var actors: Array[BrawlActor] = []
var pieces: Array[Unit] = []
var shots: Array = []
var beams: Array = []
var gulps: Array = []
var tornadoes: Array = []
var _tornado_logged := false
var _shadows: Node2D = null
var outcome := ""
## [W3] The curtain machinery arrives complete from the brawl (decide → hold → report);
## the rule that starts it is W5's. `_reported` is what keeps restart / ESC / timer from
## ever producing two `settled` for one match.
var _curtain := 0.0
var _reported := false

## What this match fights: one map row, the player's placed side, and [W8] the session's
## rolled round list with the cursor telling THIS arena which bout it fields. Handed over
## once by begin(); the R key replays the same setup - same round, same army, same squares.
var setup = null

var _next_uid := 1
var _kills: Array[int] = [0, 0]
## [P111] The tug-of-war bar's denominator, per side: each army's total HP the moment THIS bout
## opened. War fields a bout's whole army at `_begin` and each round is a fresh arena, so within a
## bout `side_hp` only ever falls - the same promise the brawl's bar makes. Re-captured every
## `_begin`, zeroed every `restart`.
var _side_peak: Array[int] = [0, 0]

## [W8] THE BOUT'S COORDINATES. The scheduler, the plan cursor and the arena's own dice all
## retired with the timed model: the roll happened once at SESSION birth (WarWaveGen, off
## setup.roll_seed) and the deployment page scouted it before the march, so the arena only
## reads setup.current_round() and fields it. These two numbers are what every reader - the
## HUD band, the receipt, the win-or-next-round decision - calls the round, 1-based because
## it is a label a person reads, not an index.
var _round_no := 0
var _round_total := 0


func _ready() -> void:
	## The effect layer hangs on the FIELD, for the brawl's own reason (brawl.gd's comment):
	## callers pass body positions, and bodies are the field's children - which here means
	## they are also inside the camera's frame, the way every picture should be.
	Fx.attach(field)
	## [W11] The lattice is the SETTINGS page's call now (SettingsStore.war_grid, default on);
	## the page and this arena read the same saved switch, the generator is shared, so the two
	## grids can never disagree about existing.
	field.show_grid = SettingsStore.war_grid
	## [W9] The battlefield is FORCED VISIBLE here, and that is not decoration: the field is
	## the parent of the ground, the lattice, every unit and every effect (five add_child
	## doors below), and an editor pass once left `visible = false` on this very node in
	## scenes/war.tscn - which emptied the screen while the bout kept fighting. The scene may
	## be toggled by anyone; the code owns the rule.
	field.visible = true
	print("[War] arena: %d Hz | field %dx%d cells at %.0f px (fixed world)"
		% [BalanceBrawl.TICK_HZ, int(field.board_cols()), int(field.board_rows()),
			float(field.cell_px())])
	## Deferred like the brawl's fixture: WarMain adds this node and calls begin() on the
	## next line, so a standalone scene gets its board one frame later and a wired match
	## never builds one twice.
	_deferred_setup.call_deferred()


func _deferred_setup() -> void:
	## The F6 path: nobody handed this arena a setup within the frame it entered the tree, so
	## it stands one up itself (WarSetup.fixture reads the map sheet).
	if setup == null:
		begin(Setup.fixture())


func _process(p_delta: float) -> void:
	## [W5] The root still draws NOTHING (its canvas is the camera's frame); it PUSHES the
	## readouts to the HUD every frame instead. The numbers are formatted here because this
	## node owns every fact the band shows - round label, alive counts, the clock - and the
	## HUD's whole contract is "draw what you were told last frame". A language switch needs
	## no wiring: the strings are rebuilt from Loc on every push.
	if _shadows != null:
		_shadows.queue_redraw()
	if clock == null:
		return
	if outcome != "":
		_tick_curtain(p_delta)
	else:
		var steps := clock.advance(p_delta)
		for i in steps:
			_step(clock.step_size())
	_push_hud()


func _push_hud() -> void:
	if hud == null or not hud.has_method("tick"):
		return
	## [W8] The NEXT slot stays empty by decision: its old content was a scheduler countdown
	## ("下一波 x 秒"), and a round has no second hand - the enemy of THIS bout is already on
	## the ground and counted in the score, and the enemy of the NEXT one is the deployment
	## page's scout line, not the arena's business. The band's drawer paints nothing on an
	## empty string, so the slot costs one argument and no lie.
	hud.tick(
		Loc.tf("war.hud.round", [_round_no, _round_total]),
		"",
		Loc.tf("war.hud.score", [alive_count(BalanceBrawl.SIDE_LEFT),
			alive_count(BalanceBrawl.SIDE_RIGHT)]),
		Loc.tf("war.hud.clock", [_clock_text(), _speed_text()]),
		Loc.t("war.hud.hint"))
	## [P111] The side totals the tug-of-war bar is drawn from, pushed every frame like the band
	## strings. The line-1 texts the HUD already holds (round / clock) are what it measures against.
	if hud != null and hud.has_method("set_side_hp"):
		hud.set_side_hp(side_hp(BalanceBrawl.SIDE_LEFT), _side_peak[BalanceBrawl.SIDE_LEFT],
			side_hp(BalanceBrawl.SIDE_RIGHT), _side_peak[BalanceBrawl.SIDE_RIGHT])


func _clock_text() -> String:
	## mm:ss of SIMULATED time - the brawl arena's same shape (brawl.gd), because it is the
	## same clock answering and a spectator should read the same instrument in both modes.
	var total := int(clock.elapsed)
	return "%d:%02d" % [total / 60, total % 60]


func _speed_text() -> String:
	return "%.1f" % clock.speed


func _tick_curtain(p_delta: float) -> void:
	## The hold after the whistle, B23's rule kept whole: the losing bodies fall on their own
	## tweens while the sim stays frozen, and only then does the report go upward.
	if _reported:
		return
	_curtain -= maxf(0.0, p_delta)
	if _curtain > 0.0:
		return
	_report()


# ---------------------------------------------------------------- a match's life
func begin(p_setup) -> void:
	## One match's input, handed over once. The FIELD learns the map first - the camera's fit
	## reads the board through the field's gates, so framing a board that has not been sized
	## yet would frame nothing.
	setup = p_setup if p_setup != null else Setup.new()
	field.set_map(setup.map_id)
	camera.set_world(field)
	restart()


func restart() -> void:
	_tornado_logged = false
	for unit in pieces:
		if is_instance_valid(unit):
			unit.queue_free()
	_clear_shots()
	_clear_beams()
	_clear_gulps()
	_clear_tornadoes()
	Fx.clear()
	pieces.clear()
	actors.clear()
	_next_uid = 1
	_kills = [0, 0]
	_side_peak = [0, 0]
	outcome = ""
	_curtain = 0.0
	_reported = false
	## [W8] No dice to reseed any more: the round's army was rolled at SESSION birth, lives
	## on the setup, and _begin() fields that same list - so R replays the identical bout
	## for the identical reason the old re-roll did, with fewer moving parts.
	clock = BrawlClock.new()
	_begin()


func _begin() -> void:
	## The shadows go in before the pieces for the brawl's reason (tree order at equal z lays
	## every ellipse under every body), reading THIS arena's actor list.
	if _shadows == null:
		_shadows = Shadow.new()
		_shadows.name = "WarShadows"
		field.add_child(_shadows)
		_shadows.setup(field, actors)
	## [W8] BOTH SIDES land on the ground before the first step: the player's from the
	## committed placement, the enemy from the session's rolled list (setup.current_round(),
	## scouted by the deployment page before 出征). There is no timeline left to re-read -
	## the bout's army travels INSIDE the setup, which is what lets the page promise the
	## same line-up the arena will field.
	_fill_side(setup.left, BalanceBrawl.SIDE_LEFT)
	_round_total = setup.round_total()
	_round_no = setup.round_no + 1
	_fill_side(setup.current_round(), BalanceBrawl.SIDE_RIGHT)
	## [P111] Both armies stand at full HP now and nothing more joins them this bout, so this is
	## the 100% the HUD's tug-of-war bar measures against.
	_side_peak[BalanceBrawl.SIDE_LEFT] = side_hp(BalanceBrawl.SIDE_LEFT)
	_side_peak[BalanceBrawl.SIDE_RIGHT] = side_hp(BalanceBrawl.SIDE_RIGHT)
	if hud != null and hud.has_method("begin_match"):
		hud.begin_match(_round_total)
	print("[War] bout opened: map %s | round %d/%d | player %d piece(s), enemy %d"
		% [setup.map_id if setup.map_id != "" else "?", _round_no, _round_total,
			setup.left.size(), setup.current_round().size()])


func _fill_side(p_roster: Array, p_side: int) -> void:
	## One side's rows, {piece, col, row} (+ an optional mods dict a war row never carries
	## today - the door stays open because the brawl's _spawn_piece already handles it).
	for entry in p_roster:
		var row := entry as Dictionary
		_spawn_piece(str(row.get("piece", "")), p_side,
			Vector2i(int(row.get("col", -1)), int(row.get("row", -1))),
			row.get("mods", {}) as Dictionary)


func _spawn_piece(p_id: String, p_side: int, p_cell: Vector2i, p_mods: Dictionary) -> void:
	## A cell becomes a FLOAT CENTRE here and nowhere else - the same one conversion the
	## brawl's sheets and this mode's formation page both speak through.
	var at := Vector2(float(p_cell.x) + 0.5, float(p_cell.y) + 0.5)
	var unit := Spawn.create_unit(self, p_id, p_cell)
	if unit == null:
		print("[War] the setup names '%s', which no roster implements - skipped" % p_id)
		return
	var actor := BrawlActor.new()
	actor.arena = self
	actor.setup(unit, p_side, at, field, p_mods)
	actors.append(actor)
	pieces.append(unit)


# ---------------------------------------------------------------- the shots [B7+]
func spawn_shot(p_shooter: BrawlActor, p_target: BrawlActor, p_shot_id: String,
		p_amount: float) -> void:
	## The brawl's door kept verbatim - a shot outlives the tick that fired it, so the arena
	## owns it. The ONLY war difference is who it is asked about: `field` here is the fixed
	## world, so flight speeds keep their absolute px/second meaning.
	if p_shooter == null or p_target == null:
		return
	var shot = Shot.new()
	shot.name = "shot_%d" % _next_uid
	_next_uid += 1
	field.add_child(shot)
	shot.launch(p_shooter, p_target, p_shot_id, p_amount, field, actors)
	shots.append(shot)


func _tick_shots(p_dt: float) -> void:
	var i := shots.size() - 1
	while i >= 0:
		var shot = shots[i]
		if shot == null or not is_instance_valid(shot):
			shots.remove_at(i)
		else:
			shot.tick(p_dt)
			if shot.finished():
				shots.remove_at(i)
		i -= 1


func _clear_shots() -> void:
	for shot in shots:
		if is_instance_valid(shot):
			shot.queue_free()
	shots.clear()


# ---------------------------------------------------------------- the beams [P110g]
func open_beam(p_shooter: BrawlActor, p_target: BrawlActor, p_kind: String, p_seconds: float,
		p_share: float = BalanceBrawl.BEAM_TICK_SHARE) -> void:
	if p_shooter == null or p_target == null or is_channelling(p_shooter):
		return
	var beam = Beam.new()
	beam.name = "beam_%d" % _next_uid
	_next_uid += 1
	field.add_child(beam)
	beam.launch(p_shooter, p_target, p_kind, p_seconds, actors, p_share)
	beams.append(beam)


func is_channelling(p_actor: BrawlActor) -> bool:
	for beam in beams:
		if beam != null and is_instance_valid(beam) and beam.is_shooter(p_actor):
			return true
	return false


func _tick_beams(p_dt: float) -> void:
	var i := beams.size() - 1
	while i >= 0:
		var beam = beams[i]
		if beam == null or not is_instance_valid(beam):
			beams.remove_at(i)
		else:
			beam.tick(p_dt)
			if beam.finished():
				beams.remove_at(i)
		i -= 1


func _clear_beams() -> void:
	for beam in beams:
		if is_instance_valid(beam):
			beam.queue_free()
	beams.clear()


# ---------------------------------------------------------------- the gulps [B10]
func swallow(p_slime: BrawlActor, p_prey: BrawlActor, p_seconds: float) -> bool:
	if p_slime == null or p_prey == null or p_seconds <= 0.0:
		return false
	if not p_slime.is_alive() or not p_prey.is_alive():
		return false
	if p_prey.is_swallowed() or is_digesting(p_slime):
		return false
	var gulp = Gulp.new()
	gulp.launch(p_slime, p_prey, p_seconds)
	gulps.append(gulp)
	print("[War] %.1fs  %s swallows %s for %.1fs"
		% [clock.elapsed, BalanceBrawl.SIDE_NAMES[p_slime.side], _unit_name(p_prey), p_seconds])
	return true


func _unit_name(p_actor: BrawlActor) -> String:
	if p_actor.unit == null or not is_instance_valid(p_actor.unit):
		return "?"
	return p_actor.unit.display_name


func is_digesting(p_actor: BrawlActor) -> bool:
	for gulp in gulps:
		if gulp != null and gulp.is_slime(p_actor):
			return true
	return false


func _tick_gulps(p_dt: float) -> void:
	var i := gulps.size() - 1
	while i >= 0:
		var gulp = gulps[i]
		if gulp == null:
			gulps.remove_at(i)
		else:
			gulp.tick(p_dt)
			if gulp.finished():
				gulps.remove_at(i)
		i -= 1


func _clear_gulps() -> void:
	for gulp in gulps:
		if gulp != null:
			gulp.release()
	gulps.clear()


# ---------------------------------------------------------------- the whirlwinds [B39]
func spawn_tornado(p_summoner: BrawlActor, p_cells: float, p_amount: float) -> void:
	if p_summoner == null:
		return
	var tornado = Tornado.new()
	tornado.name = "tornado_%d" % _next_uid
	_next_uid += 1
	field.add_child(tornado)
	tornado.summon(p_summoner, p_cells, p_amount, field, actors)
	tornadoes.append(tornado)
	if not _tornado_logged:
		_tornado_logged = true
		var who := "a piece"
		if p_summoner.unit != null and is_instance_valid(p_summoner.unit):
			who = str(p_summoner.unit.name)
		print("[War] %s summoned a whirlwind: %.1f cells, %d on the board"
			% [who, p_cells, tornadoes.size()])


func _tick_tornadoes(p_dt: float) -> void:
	var i := tornadoes.size() - 1
	while i >= 0:
		var tornado = tornadoes[i]
		if tornado == null or not is_instance_valid(tornado):
			tornadoes.remove_at(i)
		else:
			tornado.tick(p_dt)
			if tornado.finished():
				tornadoes.remove_at(i)
		i -= 1


func _clear_tornadoes() -> void:
	for tornado in tornadoes:
		if is_instance_valid(tornado):
			tornado.queue_free()
	tornadoes.clear()


# ---------------------------------------------------------------- the tick
func _step(p_dt: float) -> void:
	## The brawl's order, kept: bodies move, then the things that read positions react to
	## where this step LEFT them. No rage and no drain (the header's comment says why) -
	## the actor still asks for a rage number, and the number it gets is 0.
	## [W8] Both armies landed in _begin() before the first step ever ran - the scheduler
	## that used to APPEND bodies mid-fight is gone, so this loop now iterates a list that
	## only shrinks (by dying) while it walks.
	for actor in actors:
		actor.tick(p_dt, actors, 0)
	_tick_shots(p_dt)
	_tick_beams(p_dt)
	_tick_gulps(p_dt)
	_tick_tornadoes(p_dt)
	_check_outcome()


func _check_outcome() -> void:
	## [W8] THE RULE, round-shaped - and it is still NOT brawl's "both empty = draw". Two
	## facts answer it every step: whose half is standing, and which round this bout is.
	## A bout's whole army landed at _begin(), so "the enemy half is empty" alone decides
	## whether the ROUND fell; what that means depends on which round the band prints:
	##   last round fell   -> WIN (every enemy the session rolled is six feet down);
	##   middle round fell -> "round": the curtain holds, then WarMain takes the field
	##     apart and reopens the deployment table for the next scouted line-up;
	##   player half empty -> LOSE, whatever the enemy half is doing - except the mutual
	##     kill AT the last round, which is the only DRAW left.
	## The F6 harness keeps its exemption: the deployment page will not march an empty army,
	## so `left.is_empty()` is the harness talking, and a harness does not get a verdict -
	## the rolled round's bodies walk a field nobody commands and the camera keeps working.
	if outcome != "":
		return
	var left_alive := alive_count(BalanceBrawl.SIDE_LEFT)
	var right_alive := alive_count(BalanceBrawl.SIDE_RIGHT)
	if left_alive <= 0:
		if setup != null and setup.left.is_empty():
			return
		_finish("draw" if _round_no >= _round_total and right_alive <= 0 else "lose")
	elif right_alive <= 0 and _round_total > 0:
		_finish("round" if _round_no < _round_total else "win")


func _finish(p_winner: String) -> void:
	outcome = p_winner
	_clear_shots()
	_clear_beams()
	_clear_gulps()
	_clear_tornadoes()
	print("[War] " + summary())
	_curtain = BalanceWar.WAR_CURTAIN_SECONDS


func _report() -> void:
	if _reported:
		return
	_reported = true
	## [W5] The receipt goes to the HUD the instant it goes upward: the arena stays up (the
	## routing W3 decided and war_main recorded - no result page in v1), so the picture and
	## the verdict must land together. [W8] the line counts ROUNDS now - on a win that is
	## the whole list by construction, on a loss it is how far the field got; a middle round
	## clearing shows the same machinery the exact same 2.0 s, then war_main routes the
	## field back to the deployment table and this receipt was never a match's end.
	if hud != null and hud.has_method("show_result"):
		hud.show_result(_receipt_word(),
			Loc.tf("war.result.line", [_round_no, _clock_text()]),
			Loc.t("war.result.hint"))
	settled.emit({
		"winner": outcome,
		"summary": summary(),
		"seconds": clock.elapsed,
		"steps": clock.steps,
		"rounds": _round_no,
		"left_hp": side_hp(BalanceBrawl.SIDE_LEFT),
		"right_hp": side_hp(BalanceBrawl.SIDE_RIGHT),
	})


func _receipt_word() -> String:
	match outcome:
		"win":
			return Loc.t("war.result.win")
		"lose":
			return Loc.t("war.result.lose")
		"round":
			## [W8] The mid-war flash: this bout fell, the next one is being scouted behind
			## the curtain. Not a verdict on the war - war_main's route for this word tears
			## the arena down rather than leaving it up.
			return Loc.t("war.result.round")
	return Loc.t("war.result.draw")


func summary() -> String:
	return "MATCH OVER at %.1fs (sim, %d steps): winner %s | LEFT %d alive / %d hp, RIGHT %d alive / %d hp | kills %d-%d" % [
		clock.elapsed, clock.steps, outcome,
		alive_count(BalanceBrawl.SIDE_LEFT), side_hp(BalanceBrawl.SIDE_LEFT),
		alive_count(BalanceBrawl.SIDE_RIGHT), side_hp(BalanceBrawl.SIDE_RIGHT),
		_kills[BalanceBrawl.SIDE_LEFT], _kills[BalanceBrawl.SIDE_RIGHT]
	]


func alive_count(p_side: int) -> int:
	var n := 0
	for actor in actors:
		if actor.side == p_side and actor.is_alive():
			n += 1
	return n


func side_hp(p_side: int) -> int:
	var total := 0
	for actor in actors:
		if actor.side == p_side:
			total += actor.hp_total()
	return total


# ---------------------------------------------------------------- the factory's doors
func spawn_zombie(p_type: String, _p_col: int, _p_row: int) -> Zombie:
	## The three doors Spawn.create_unit() calls back into, verbatim from the arena's contract
	## (brawl.gd documents the ordering rules): the body exists first, THIS arena then says
	## how big it is drawn and where it hangs.
	var zombie := Zombie.new() as Zombie
	zombie.name = "%s_%d" % [p_type, _next_uid]
	_next_uid += 1
	zombie.apply_type(p_type, ZombieDB.hp(p_type), ZombieDB.armor(p_type))
	_attach_piece(zombie)
	return zombie


func spawn_unit(p_script: GDScript, _p_col: int, _p_row: int) -> Unit:
	var unit := p_script.new() as Unit
	unit.name = "piece_%d" % _next_uid
	_next_uid += 1
	_attach_piece(unit)
	return unit


func spawn_human(p_id: String, _p_col: int, _p_row: int) -> Unit:
	## apply_piece BEFORE attach - the brawl's ordering rule, and it has the same consequence
	## here: a body told what it is after attaching wears no art, ever.
	var piece := HumanPiece.new()
	piece.name = "%s_%d" % [p_id, _next_uid]
	_next_uid += 1
	piece.apply_piece(p_id)
	_attach_piece(piece)
	return piece


func _attach_piece(p_unit: Unit) -> void:
	## THE ONE LINE THAT CHANGED: brawl.gd scales a body by BrawlLayout.piece_scale(), the
	## window's cell against the 60 px art box. The war's cell is FIXED, so a body is drawn
	## at WORLD_CELL over the turn engine's baseline - today's answer is 1.0 for every map
	## and every window, which is the whole point of the fixed world (BalanceWar's header).
	p_unit.board = self
	field.add_child(p_unit)
	p_unit.art_scale = BalanceWar.WORLD_CELL / float(Balance.CELL_SIZE)
	p_unit.place(null, 0, 0)
	p_unit.died.connect(_on_piece_died)


func _on_piece_died(p_unit: Unit) -> void:
	var actor := actor_of(p_unit)
	if actor != null:
		_kills[1 - actor.side] += 1
		print("[War] %.1fs  %s piece down at (%.2f, %.2f)  ->  %d v %d alive"
			% [clock.elapsed, BalanceBrawl.SIDE_NAMES[actor.side], actor.pos.x, actor.pos.y,
				alive_count(BalanceBrawl.SIDE_LEFT), alive_count(BalanceBrawl.SIDE_RIGHT)])
	p_unit.play_death()


func actor_of(p_unit: Unit) -> BrawlActor:
	for actor in actors:
		if actor.unit == p_unit:
			return actor
	return null


# ---------------------------------------------------------------- the spectator's keys
func _input(p_event: InputEvent) -> void:
	## The same four keys the brawl's spectator has: SPACE pause, F speed, R replay, ESC out.
	## The camera's gestures are NOT here - it listens unhandled, and a key this node acted
	## on is marked handled so it never reaches Game's front-end list either.
	if not (p_event is InputEventKey):
		return
	var key := p_event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			print("[War] %s" % ("paused" if clock.toggle_pause() else "running"))
		KEY_F:
			print("[War] speed x%.0f" % clock.cycle_speed())
		KEY_R:
			print("[War] restart")
			restart()
		KEY_ESCAPE:
			left.emit("menu")
		_:
			return
	get_viewport().set_input_as_handled()
