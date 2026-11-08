class_name Brawl
extends Node2D
## [B1] THE ARENA SESSION - one real-time bout: its clock, its two sides, its outcome.
##
## This is the root script of scenes/brawl.tscn, and the scene tree below IS the ownership
## diagram (the same promise battle.tscn makes):
##
##   Brawl        (this, Node2D)   one bout's lifetime
##   └─ BrawlField (Node2D)        the ground: pieces hang here, the halves are painted here
##
## THE CONTRACT - two node names, read by the log and by a future probe: Brawl / BrawlField.
## [S4] THE HEADER IS DRAWN, NOT A NODE: BrawlHUD.draw_top_bar paints the same band the formation
## page wears, on the same rectangle (BrawlLayout.top_bar), with the spectator readouts in it
## (BRAWL.md §10.1 / D70). [B2]'s BrawlLayer can still arrive with B4 - the kill feed and the
## pause / speed BUTTONS are what a node layer is actually for.
##
## [S4] and the LATTICE: the field draws it too now (BrawlField.show_grid, D68), dimmer, because
## a spectator and a player have to recognise the same board.
##
## WHAT IT MAY TOUCH: the static modules (Balance / BalanceBrawl / BalanceUI / Layout), the
## domain objects (Unit / Zombie / the plant scripts) and the factory (Spawn). What it may
## NOT do is cross the line BRAWL.md §12 draws: no Game, no saves, no RunState, no front
## end. The other half of that boundary (BrawlMain and the settled / left signals) belongs
## to B2 - B1 is deliberately standalone, so F6 on this scene runs a bout with no wiring.
##
## [B2b] THE BOUT IS CONFIGURED, NOT FIXTURED. What stands on each side arrives in a
## BrawlSetup (the left half from the session's stand-in line-up, the right half from
## data/brawl/formations.csv), so the arena knows nothing about rounds, purses or opponents -
## it fights the two sides it was handed and reports who won. There is still no formation page
## and no reward in here (B3 / B5): the arena's whole vocabulary is pieces, a clock, a rage and
## a winner.

const Spawn := preload("res://scripts/core/spawn.gd")
## [B7+] The brawl's own flight (BrawlShot). PRELOADED BY PATH and not by class_name, for the
## reason ProjectileDB spells out: a brand-new global class is invisible to a headless run
## until the editor has rescanned the project, and this file must not depend on that.
const Shot := preload("res://scripts/core/brawl/brawl_shot.gd")
## [P110g] The channelled beam (BrawlBeam). Preloaded by path for exactly the reason above.
const Beam := preload("res://scripts/core/brawl/brawl_beam.gd")
## [B10] One digestion (BrawlGulp) - a body held inside another body. Preloaded by path for the
## same reason, and the third thing in this file that outlives the tick which started it.
const Gulp := preload("res://scripts/core/brawl/brawl_gulp.gd")
## [B17] The shadows (BrawlShadow) - preloaded by path for the fourth time the same reason.
const Shadow := preload("res://scripts/core/brawl/brawl_shadow.gd")
## [B39] A travelling whirlwind (BrawlTornado) - the fifth timed object and the fifth time the same
## reason: a brand-new global class is invisible to a headless run until the editor has rescanned.
const Tornado := preload("res://scripts/core/brawl/brawl_tornado.gd")

## [B2] THE BOUNDARY, as two signals - the same two shapes a battle reports through, so the
## object above treats both modes the same way (BRAWL.md §12). The arena never knows what
## "menu" or a reward MEANS; it only says that the bout is decided and that the spectator
## wants out.
signal settled(result: Dictionary)
signal left(reason: String)

@onready var field: BrawlField = $BrawlField

var clock: BrawlClock = null
var actors: Array[BrawlActor] = []
var pieces: Array[Unit] = []
## [B7+] THE SHOTS IN THE AIR. The arena owns them and not the actor that fired one: a shot
## outlives the tick that launched it, it has to be ticked and drawn with the bout, and it has
## to go down with it (restart and the final whistle both clear this list).
var shots: Array = []
## [P110g] THE BEAMS BURNING RIGHT NOW. Owned by the arena for the same reason the shots are: a
## channel outlives the tick that opened it, it is ticked and drawn with the bout, and it goes
## down with it (restart and the final whistle both clear this list).
var beams: Array = []
## [B10] THE DIGESTIONS RUNNING RIGHT NOW, owned by the arena for the third time and the same
## reason: a swallow outlives the tick that made it, it ends when either body falls, and a replay
## must not inherit one. Unlike the shots and the beams these are RefCounted and not nodes -
## nothing about a digestion is drawn by the gulp; the prey is a body of its own and is drawn
## where its own driver puts it (BrawlActor.be_swallowed).
var gulps: Array = []
## [B39] THE WHIRLWINDS WALKING RIGHT NOW, owned by the arena for the fourth time and the same
## reason: a tornado outlives the tick that summoned it, it is ticked and drawn with the bout, and a
## replay must not inherit one. Unlike the gulp these ARE nodes - the funnel is a picture the player
## has to watch and step out of, and it judges its own height every pulse.
var tornadoes: Array = []
## [B40] Has THIS bout said its first whirlwind out loud yet - see the one line `spawn_tornado` prints.
var _tornado_logged := false
## [B17] THE SHADOW FIELD (BrawlShadow) - one node under every living body's ground mark.
## Made once in _begin and NEVER rebuilt by a restart: it is the field's child like the FX
## layer is, and the actors Array it reads is refilled in place (its dev doc §26 hook).
var _shadows: Node2D = null
var outcome := ""
var rage_level := 0
## [B23] THE CURTAIN. Two readings, kept apart on purpose: `outcome != ""` means "this bout is
## decided" (every rule asks that), and these two mean "and the decision has not yet reached the
## page above". `_curtain` counts the real seconds left of the fall; `_reported` is what keeps a
## restart, an ESC and the timer from ever producing two `settled` for one bout.
var _curtain := 0.0
var _reported := false

## [B2b] What this bout fights: two sides of {piece, col, row} plus the round label. Handed
## over once by begin(); the R key replays the same setup.
var setup: BrawlSetup = null

var _next_uid := 1
var _kills: Array[int] = [0, 0]
## [P111] The tug-of-war bar's denominator, per side: each army's total HP the moment the bout
## opened. The roster is fixed for a bout (both `_fill_side`s land it in `_begin`, and a summon
## makes a shot/tornado, never an actor), so `side_hp` can only ever fall from here - a shrinking
## bar is real damage, never a re-based line. Re-captured every `_begin`, zeroed every `restart`.
var _side_peak: Array[int] = [0, 0]


func _ready() -> void:
	## [P110d] THE ARENA OWNS AN EFFECT LAYER TOO. scripts/fx/fx.gd keeps ONE static layer and
	## every picture enters through its one door (_put); until now only the turn engine attached
	## it (battle.gd), so in a brawl that door had nothing to add to and DROPPED every effect on
	## the floor - silently, which is the worst way to lose one.
	##
	## `field` is the parent for exactly the reason `grid` is the parent in a battle: the
	## callers pass the positions of the pieces, and the pieces are field's own children
	## (_attach_piece), so their local coordinates mean for the layer what they mean for a body.
	## Its z_index (BalanceUI.FX_Z_INDEX) is what keeps a picture above the pieces - tree order
	## cannot, because this layer is added BEFORE them.
	Fx.attach(field)
	## [S4/D68] The arena shows the lattice at BRAWL_GRID_ARENA_ALPHA (BrawlField draws it for
	## the formation page already). Set here rather than in the scene file so the two pages'
	## boards are decided by code in one place.
	field.show_grid = true
	print("[Brawl] arena: %d Hz, one round = %.2fs (%.2f AP/s), bout %.0fs, rage at %.0fs"
		% [BalanceBrawl.TICK_HZ, BalanceBrawl.ROUND_SECONDS, BalanceBrawl.ap_rate(),
			BalanceBrawl.BOUT_SECONDS, BalanceBrawl.RAGE_START])
	## [B2b] A scene opened on its own (F6) runs the fixture bout; BrawlMain calls begin() with
	## the round's real setup instead. The arena cannot tell which of the two happened.
	##
	## [B5] DEFERRED, and that is the fix for a real waste: BrawlMain adds this node to the tree
	## and calls begin() on the very next line, so an immediate fixture used to spawn a whole
	## side (art, view scenes, one "bout started" line) for the setup that was about to replace
	## it. One frame later either answer is known, and a standalone scene still gets its bout.
	_deferred_fixture.call_deferred()


func _deferred_fixture() -> void:
	## The F6 path: nobody handed this arena a setup within the frame it entered the tree, so it
	## stands one up itself (BrawlSetup.fixture reads the sheets, so a standalone scene fights a
	## real formation rather than nothing).
	if setup == null:
		begin(BrawlSetup.fixture())


func _process(p_delta: float) -> void:
	## [S4] The header is redrawn with the bout: it carries the clock and the two sides' counts,
	## and this node is already ticking - one more redraw of four lines of text is free.
	queue_redraw()
	## [B17] And the shadows ride the same frame (dev doc §26): bodies move in the SIM steps,
	## one redraw per drawn frame is enough for every ellipse to keep its owner's ground mark.
	if _shadows != null:
		_shadows.queue_redraw()
	if clock == null:
		return
	if outcome != "":
		## [B23] A decided bout buys no logic steps - but it is not finished performing.
		_tick_curtain(p_delta)
		return
	var steps := clock.advance(p_delta)
	for i in steps:
		_step(clock.step_size())


func _tick_curtain(p_delta: float) -> void:
	## [B23] THE HOLD AFTER THE WHISTLE. The bodies that lost the bout are falling on their own
	## tweens while the sim stays frozen (no step means no movement, no damage, no second
	## outcome), and only when that has had its seconds does the result go upward. Until this
	## wait existed, `_finish` emitted and BrawlMain freed the arena in the same frame, so the
	## death of the last piece was never seen at all.
	if _reported:
		return
	_curtain -= maxf(0.0, p_delta)
	if _curtain > 0.0:
		return
	_report()


# ---------------------------------------------------------------- the header [S4]
func _draw() -> void:
	## THE SPECTATOR HEADER (BRAWL.md §10.1), through the SAME drawer the formation page calls
	## (BrawlHUD.draw_top_bar) on the SAME rectangle (BrawlLayout.top_bar). That shared call is
	## the whole point of D66: the two pages differ in what the four slots SAY, never in where
	## they are or how big they are. This is B4's 观众 HUD down to its readouts - the kill feed,
	## the pause / speed buttons and the result overlay on the field are still to come.
	if clock == null:
		return
	var score := Loc.tf("brawl.hud.score", [alive_count(BalanceBrawl.SIDE_LEFT),
		alive_count(BalanceBrawl.SIDE_RIGHT)])
	var clock_line := Loc.tf("brawl.hud.clock", [_clock_text(), _speed_text(), rage_level])
	BrawlHUD.draw_top_bar(self, score, clock_line, Loc.t("brawl.hud.hint"), _round_text())
	## [P111] The two sides' total HP, laid in the empty middle of the line the band just painted.
	## The SAME two strings that drew line 1 are handed in so the strips stop short of them.
	BrawlHUD.draw_side_hp_bars(self, score, clock_line,
		side_hp(BalanceBrawl.SIDE_LEFT), _side_peak[BalanceBrawl.SIDE_LEFT],
		side_hp(BalanceBrawl.SIDE_RIGHT), _side_peak[BalanceBrawl.SIDE_RIGHT])


func _clock_text() -> String:
	## mm:ss since the bout started: a readout, not a rule, so it lives here rather than in
	## BrawlClock (which counts simulated seconds and answers in floats).
	var total := int(clock.elapsed)
	return "%d:%02d" % [total / 60, total % 60]


func _speed_text() -> String:
	return "%.1f" % clock.speed


func _round_text() -> String:
	## "第 n 轮 - 对 突袭阵", the arena's half of the header's second line: the same fact the
	## formation page's own line carries, so a spectator always knows WHICH round they are watching.
	## [B29] The name comes IN on the setup rather than being looked up here: since a round can be
	## dealt an opponent no sheet lists, the arena has nothing to look it up in - and a bout should not
	## be reading data tables to draw its own header anyway.
	if setup == null:
		return ""
	var who := setup.opponent_name
	if who == "":
		who = setup.opponent
	return Loc.tf("brawl.hud.round", [setup.round_no, who])


# ---------------------------------------------------------------- a bout's life
func begin(p_setup: BrawlSetup) -> void:
	## One bout's input, handed over once: BrawlMain.start_bout() passes the round's setup, and
	## _ready() passes the fixture. This is the arena's ONLY way to learn what to field.
	setup = p_setup if p_setup != null else BrawlSetup.new()
	restart()


func restart() -> void:
	## [B40] One bout, one chance to say it: the whirlwind's breadcrumb is re-armed here rather than
	## in _clear_tornadoes(), because this is the door that says "a bout is starting again" and the
	## finish whistle should not silence the next one's first line.
	_tornado_logged = false
	for unit in pieces:
		if is_instance_valid(unit):
			unit.queue_free()
	## [B7+] ...and the shots, through the same door the final whistle uses: a replay must not
	## inherit arrows from the bout before it.
	_clear_shots()
	## [P110g] Nor a beam: a channel is longer-lived than a shot, so a replay that inherited one
	## would burn the new bout's pieces with the old bout's eye.
	_clear_beams()
	## [B10] And no digestion, for the same reason - and here the stakes are higher than a stray
	## picture: a gulp still on the list would keep the NEW bout's piece held inside an actor that
	## belongs to the old one.
	_clear_gulps()
	## [B39] Nor a whirlwind: a replay that inherited one would pay the new bout's bodies with the
	## old bout's attack - and the funnel is a NODE, so it would also still be drawing.
	_clear_tornadoes()
	## [P110d] And the PICTURES, for the same reason: a replay must not inherit a claw mark
	## from the bout before it. The layer itself stays - it is the FIELD's child and a restart
	## does not rebuild the field - so this call is what keeps it honest. The bout ENDING needs
	## no door of its own: the arena is queue_freed and the layer goes down with it.
	Fx.clear()
	pieces.clear()
	actors.clear()
	_next_uid = 1
	_kills = [0, 0]
	_side_peak = [0, 0]
	outcome = ""
	rage_level = 0
	## [B23] A replay inherits no curtain and no already-reported verdict - otherwise the second
	## bout would emit its result on the first frame it decided.
	_curtain = 0.0
	_reported = false
	clock = BrawlClock.new()
	_begin()


func _begin() -> void:
	## [B7] WHAT A PIECE WEARS RIDES WITH THE PIECE. Every row of a side may carry its own "mods"
	## (BrawlSession.mods_for put it there); B5's one-dictionary-per-side is gone with the
	## team-wide augments (D43). The enemy half carries none today - an enemy formation has no
	## rewards, and the door stays open for the day one does (a data decision, not a code shape).
	##
	## [B17] THE SHADOWS GO IN BEFORE THE PIECES (dev doc §26): the field is drawn in tree
	## order at equal z, so being an elder sibling is what lays every ellipse under every body.
	## Made once - a restart keeps the field and this child, and refills the very actors array
	## the node reads - and redrawn from _process with the bout, not with its own loop.
	if _shadows == null:
		_shadows = Shadow.new()
		_shadows.name = "BrawlShadows"
		field.add_child(_shadows)
		_shadows.setup(field, actors)
	_fill_side(setup.left, BalanceBrawl.SIDE_LEFT)
	_fill_side(setup.right, BalanceBrawl.SIDE_RIGHT)
	## [B5+] What the player's side wears is part of the readout, not a silent multiplier: this
	## line is what the manual pass compares two bouts with (AGENTS §2 - there are no test
	## scripts). A bout where nobody wears anything prints nothing extra.
	print("[Brawl] bout started: round %d vs %s | %d v %d pieces%s"
		% [setup.round_no, setup.opponent if setup.opponent != "" else "?",
			setup.left.size(), setup.right.size(), _mods_text()])
	## [P111] Both armies now stand at full HP and nothing more will join them this bout, so
	## whatever they total RIGHT HERE is the 100% the spectator's bar is measured against.
	_side_peak[BalanceBrawl.SIDE_LEFT] = side_hp(BalanceBrawl.SIDE_LEFT)
	_side_peak[BalanceBrawl.SIDE_RIGHT] = side_hp(BalanceBrawl.SIDE_RIGHT)


func _mods_text() -> String:
	## "| worn: attack_flat +16, hp_mult +30%" - EVERYTHING the player's side wears, summed over
	## its pieces, keys sorted so two runs print the same line. A flat key prints its amount and a
	## multiplier key its hundredths, which is exactly how data/brawl/gear.csv spells them.
	if setup == null:
		return ""
	var totals: Dictionary = {}
	for entry in setup.left:
		var mods: Dictionary = (entry as Dictionary).get("mods", {})
		for key in mods.keys():
			totals[key] = float(totals.get(key, 0.0)) + float(mods[key])
	if totals.is_empty():
		return ""
	var keys: Array = totals.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key in keys:
		if BalanceBrawl.effect_is_flat(str(key)):
			parts.append("%s %+.0f" % [str(key), float(totals[key])])
		else:
			parts.append("%s %+.0f%%" % [str(key), float(totals[key]) * 100.0])
	return " | worn: " + ", ".join(parts)


func _fill_side(p_roster: Array, p_side: int) -> void:
	## One side's rows, each with whatever it wears. A row that names no mods is a plain piece -
	## which is what every enemy row is today, and what a freshly bought piece is.
	for entry in p_roster:
		var row := entry as Dictionary
		_spawn_piece(str(row.get("piece", "")), p_side,
			Vector2i(int(row.get("col", -1)), int(row.get("row", -1))),
			row.get("mods", {}) as Dictionary)


func _spawn_piece(p_id: String, p_side: int, p_cell: Vector2i, p_mods: Dictionary) -> void:
	## A cell becomes a FLOAT CENTRE here and nowhere else: the sheets speak in cells (0-8 /
	## 0-4) and the arena works in cell units with the half-cell offset already in them.
	var at := Vector2(float(p_cell.x) + 0.5, float(p_cell.y) + 0.5)
	## The FACTORY is the same door the turn engine walks through (Spawn.create_unit) -
	## which is why this class implements spawn_zombie() / spawn_unit() below.
	var unit := Spawn.create_unit(self, p_id, p_cell)
	if unit == null:
		print("[Brawl] the setup names '%s', which no roster implements - skipped" % p_id)
		return
	var actor := BrawlActor.new()
	## [B7+] The one handle back to the arena: a ranged piece asks it for a shot. Set before
	## setup() so the very first strike of the very first tick already has somewhere to fire.
	actor.arena = self
	actor.setup(unit, p_side, at, field, p_mods)
	actors.append(actor)
	pieces.append(unit)


# ---------------------------------------------------------------- the shots [B7+]
func spawn_shot(p_shooter: BrawlActor, p_target: BrawlActor, p_shot_id: String,
		p_amount: float) -> void:
	## ONE SHOT LEAVES THE MUZZLE. The actor asked for it (its own row names the shot) and hands
	## over the blow it just worked out; the arena owns it from here, because a shot outlives the
	## tick that fired it and has to be ticked, drawn and freed with the bout.
	## A shot is a CHILD OF THE FIELD, like every piece: the field is the brawl's coordinate
	## system (world_of), so a shot and the body it is aimed at live in the same space.
	if p_shooter == null or p_target == null:
		return
	var shot = Shot.new()
	shot.name = "shot_%d" % _next_uid
	_next_uid += 1
	field.add_child(shot)
	shot.launch(p_shooter, p_target, p_shot_id, p_amount, field, actors)
	shots.append(shot)


func _tick_shots(p_dt: float) -> void:
	## Every shot in the air, and the ONE place the list is pruned: a shot that has landed and
	## burnt out its burst frees itself and is dropped here. Walked backwards, because removing
	## from an Array while walking it forwards is how an index gets skipped.
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
	## The bout is over (or starting again): no shot survives either. queue_free and not free,
	## because a shot may be mid-frame when this runs.
	for shot in shots:
		if is_instance_valid(shot):
			shot.queue_free()
	shots.clear()


# ---------------------------------------------------------------- the beams [P110g]
func open_beam(p_shooter: BrawlActor, p_target: BrawlActor, p_kind: String, p_seconds: float,
		p_share: float = BalanceBrawl.BEAM_TICK_SHARE) -> void:
	## ONE BEAM OPENS. The actor asked for it (its row named a beam AND a 持续), the blow of the
	## opening frame is already settled by then, and the arena owns the rest: the node burns,
	## follows both bodies, and ends when the channel is over or either body falls.
	##
	## [B14] p_share is WHAT ONE TICK IS WORTH, and it is an argument because the two things that
	## open a channel pay differently: a 持续 row's channel is a CADENCE (BEAM_TICK_SHARE, the
	## default - it is how that piece attacks, three blows over three seconds), while an ULTIMATE
	## is a BURST (BalanceBrawl.ULT_TICK_SHARE, a whole blow per tick). Both numbers are game
	## rules out of BalanceBrawl, so the arena still decides nothing by itself - it is handed one.
	##
	## A shooter that is ALREADY burning something is refused rather than stacked. Under 狂暴 the
	## strike timer can come up before a 3-second channel is over, and two beams from one eye would
	## deal double damage on a cadence the sheet never priced - the actor also asks (can_strike)
	## and this is the door that makes the answer true even if it forgets.
	if p_shooter == null or p_target == null or is_channelling(p_shooter):
		return
	var beam = Beam.new()
	beam.name = "beam_%d" % _next_uid
	_next_uid += 1
	field.add_child(beam)
	beam.launch(p_shooter, p_target, p_kind, p_seconds, actors, p_share)
	beams.append(beam)


func is_channelling(p_actor: BrawlActor) -> bool:
	## Is this piece busy burning something? The actor asks before it strikes (can_strike) and
	## open_beam asks before it opens a second one. The list is the ONE answer to that question -
	## the actor keeps no flag of its own, so "how long a channel runs" stays a fact with one owner.
	for beam in beams:
		if beam != null and is_instance_valid(beam) and beam.is_shooter(p_actor):
			return true
	return false


func _tick_beams(p_dt: float) -> void:
	## Every beam burning, and the ONE place the list is pruned - walked backwards for the reason
	## _tick_shots is: removing from an Array while walking it forwards is how an index gets skipped.
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
	## The bout is over (or starting again): no channel survives either.
	for beam in beams:
		if is_instance_valid(beam):
			beam.queue_free()
	beams.clear()


# ---------------------------------------------------------------- the gulps [B10]
func swallow(p_slime: BrawlActor, p_prey: BrawlActor, p_seconds: float) -> bool:
	## ONE BODY GOES INSIDE ANOTHER. The devourer's actor asked for it - its own row's 吞噬 cell
	## said how long for - and hands over the enemy it just reached; the arena owns the rest.
	##
	## THE REFUSALS ARE HERE rather than in the actor, because two of them are facts about the
	## BOARD and not about either body: a devourer already digesting something has no room
	## (BrawlActor.can_strike asks is_digesting for exactly this, and this is the door that makes
	## that answer true even if it ever forgets to ask), and a body somebody else already swallowed
	## is not standing there to be swallowed again. Both are one-liners over the list below.
	if p_slime == null or p_prey == null or p_seconds <= 0.0:
		return false
	if not p_slime.is_alive() or not p_prey.is_alive():
		return false
	if p_prey.is_swallowed() or is_digesting(p_slime):
		return false
	var gulp = Gulp.new()
	gulp.launch(p_slime, p_prey, p_seconds)
	gulps.append(gulp)
	## Said out loud, unlike the per-blow effects: a swallow happens a handful of times a bout and
	## it is the one event a reader of the log cannot reconstruct from the summary line.
	print("[Brawl] %.1fs  %s swallows %s for %.1fs"
		% [clock.elapsed, BalanceBrawl.SIDE_NAMES[p_slime.side], _unit_name(p_prey), p_seconds])
	return true


func _unit_name(p_actor: BrawlActor) -> String:
	if p_actor.unit == null or not is_instance_valid(p_actor.unit):
		return "?"
	return p_actor.unit.display_name


func is_digesting(p_actor: BrawlActor) -> bool:
	## Is this body busy digesting something? BrawlActor.can_strike asks before every blow, and
	## swallow() asks before it starts a second. The list is the ONE answer to that question - the
	## actor keeps no flag of its own, which is the same division is_channelling() above makes.
	for gulp in gulps:
		if gulp != null and gulp.is_slime(p_actor):
			return true
	return false


func _tick_gulps(p_dt: float) -> void:
	## Every digestion running, and the ONE place the list is pruned - walked backwards for the
	## reason _tick_shots is: removing from an Array while walking it forwards is how an index gets
	## skipped. finished() means the prey has already been handed back (BrawlGulp.release).
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
	## The bout is over (or starting again): nobody stays inside anybody. release() and not a
	## silent drop - the prey belongs to its own driver, and letting the list go without handing it
	## back would leave a body riding a holder that is no longer on the field.
	for gulp in gulps:
		if gulp != null:
			gulp.release()
	gulps.clear()


# ---------------------------------------------------------------- the whirlwinds [B39]
func spawn_tornado(p_summoner: BrawlActor, p_cells: float, p_amount: float) -> void:
	## ONE WHIRLWIND IS SUMMONED ([B41]: the bird calls the storm up IN FRONT OF ITSELF - it does not
	## fire it at a body, so no target is handed over here and the funnel's direction is the summoner's
	## own facing). The actor asked for it (its row's 旋风 cell says how far) and hands over the blow it
	## just worked out; the arena owns it from here, for the same reason it owns a shot: the thing
	## outlives the frame that made it, it walks across other bodies, and it has to go down with the bout.
	##
	## THERE IS NO BUSY-GATE HERE, and that is a decision rather than an omission. A whirlwind is a
	## summoned attack and not a channel: the bird is not holding anything, it has simply spent one
	## strike, and attack间隔 is the only thing that limits how many funnels it can have walking. The
	## beam and the gulp DO have one (is_channelling / is_digesting) because those two leave the
	## piece attached to a body - three funnels on the board at once is a flock, and a flock is what
	## the row priced.
	if p_summoner == null:
		return
	var tornado = Tornado.new()
	tornado.name = "tornado_%d" % _next_uid
	_next_uid += 1
	field.add_child(tornado)
	tornado.summon(p_summoner, p_cells, p_amount, field, actors)
	tornadoes.append(tornado)
	## [B40] THE ONE THING THIS OUT SAYS ABOUT ITSELF, printed the FIRST time a bout summons a
	## whirlwind and never again. The reason is a report, not a feature: "I cannot see the storm" is
	## TWO questions - was one ever summoned, and if so why is nothing painted - and only the log can
	## split them without a probe script (AGENTS.md §2). [B41] adds the answer to the SECOND of those:
	## which painter the node settled on, because "frames" means the artist's funnel is on screen and
	## "vector" means assets/svg/fx/tornado_0.svg did not import. One line per bout because the bird
	## summons one every attack间隔, and a print per strike would bury every other line here.
	## Remove it once the answer is known; nothing reads it.
	if not _tornado_logged:
		_tornado_logged = true
		var who := "a piece"
		if p_summoner.unit != null and is_instance_valid(p_summoner.unit):
			who = str(p_summoner.unit.name)
		var tier := Balance.size_scale(BalanceBrawl.TORNADO_SIZE_TIER)
		print("[Brawl] %s summoned a whirlwind: %.1f cells at %.1f cells/s, one pulse %.1f (%d%% of the blow), magnitude x%.2f = %.1f cells of air, reach %.2f cells, painter=%s, %d on the board"
			% [who, p_cells, BalanceBrawl.TORNADO_CELLS_PER_SECOND,
				p_amount * BalanceBrawl.TORNADO_TICK_SHARE,
				int(BalanceBrawl.TORNADO_TICK_SHARE * 100.0), tier,
				BalanceBrawl.TORNADO_HEIGHT_CELLS * tier,
				BalanceBrawl.TORNADO_REACH_CELLS, tornado.painter(), tornadoes.size()])


func _tick_tornadoes(p_dt: float) -> void:
	## Every funnel on the board, and the ONE place the list is pruned - walked backwards for the
	## reason _tick_shots is. finished() means the node has already queued its own free.
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
	## The bout is over (or starting again): no funnel survives either. queue_free and not free,
	## because a whirlwind may be mid-pulse when this runs.
	for tornado in tornadoes:
		if is_instance_valid(tornado):
			tornado.queue_free()
	tornadoes.clear()


func _step(p_dt: float) -> void:
	_update_rage()
	_drain(p_dt)
	for actor in actors:
		actor.tick(p_dt, actors, rage_level)
	## [B7+] The shots fly AFTER the bodies have moved, so a shot re-aims at where its target
	## IS this step rather than at where it was when the trigger was pulled.
	_tick_shots(p_dt)
	## [P110g] And the channels burn after that, in the same place and for the same reason: what a
	## beam draws and what it hits are where the two bodies ARE this step.
	_tick_beams(p_dt)
	## [B10] And the digestions last, after every body has moved: what a gulp deals out is damage
	## to a body that is riding another one, so the belly has to be where this step put it.
	_tick_gulps(p_dt)
	## [B39] And the whirlwinds walk last, after every body has moved: a funnel judges who is inside
	## it on the positions THIS step left them at, exactly like the gulp above and for the same
	## reason - the alternative is a pulse that hits where a body was.
	_tick_tornadoes(p_dt)
	_check_outcome()


func _update_rage() -> void:
	var want := 0
	if clock.elapsed >= BalanceBrawl.RAGE_START:
		want = 1 + int(floor((clock.elapsed - BalanceBrawl.RAGE_START)
			/ BalanceBrawl.RAGE_STEP_SECONDS))
		want = mini(want, BalanceBrawl.RAGE_MAX_LEVEL)
	if want == rage_level:
		return
	rage_level = want
	if rage_level <= 0:
		return
	print("[Brawl] %.1fs  RAGE %d: both sides bleed %.1f%% max hp a second, strike %.0f%% faster, hit %.0f%% harder, take %.0f%% more"
		% [clock.elapsed, rage_level,
			BalanceBrawl.RAGE_DRAIN_PER_LEVEL * float(rage_level) * 100.0,
			BalanceBrawl.RAGE_ATTACK_SPEED_PER_LEVEL * float(rage_level) * 100.0,
			BalanceBrawl.RAGE_ATTACK_PER_LEVEL * float(rage_level) * 100.0,
			BalanceBrawl.RAGE_DEFENSE_PER_LEVEL * float(rage_level) * 100.0])


func _drain(p_dt: float) -> void:
	if rage_level <= 0:
		return
	var fraction := BalanceBrawl.RAGE_DRAIN_PER_LEVEL * float(rage_level) * p_dt
	for actor in actors:
		actor.drain(fraction)


func _check_outcome() -> void:
	if outcome != "":
		return
	var left := alive_count(BalanceBrawl.SIDE_LEFT)
	var right := alive_count(BalanceBrawl.SIDE_RIGHT)
	if left > 0 and right > 0:
		return
	if left <= 0 and right <= 0:
		_finish("draw")
	elif right <= 0:
		_finish(BalanceBrawl.SIDE_NAMES[BalanceBrawl.SIDE_LEFT])
	else:
		_finish(BalanceBrawl.SIDE_NAMES[BalanceBrawl.SIDE_RIGHT])


func _finish(p_winner: String) -> void:
	outcome = p_winner
	## [B7+] A decided bout has no shots in the air: the clock stops on the next frame, so
	## anything still flying would simply hang there for the rest of the page's life.
	_clear_shots()
	## [P110g] ...and no beams burning, for the same reason - a channel would keep ticking damage
	## onto pieces that are standing in a bout that is already decided.
	_clear_beams()
	## [B10] ...and nothing stays eaten: a decided bout has no digestions either, or a piece would
	## come out of a belly into a summary that has already been written.
	_clear_gulps()
	## [B39] ...and no whirlwind is still walking. It is cleared last of the four because it is the
	## one that pays its pulse to whoever is standing in it: the bodies this step left where they
	## stand are the bodies the funnel must not reach into on a bout that is over.
	_clear_tornadoes()
	print("[Brawl] " + summary())
	## [B23] THE WHISTLE NO LONGER ENDS THE PAGE. The result is held for BOUT_CURTAIN_SECONDS so
	## the deaths that decided it finish falling in front of the spectator (`_tick_curtain`), and
	## the report below goes upward only when that is done. Nothing here can double-fire: `_finish`
	## is reached only while `outcome` is still empty, and `_report` answers to `_reported`.
	_curtain = BalanceBrawl.BOUT_CURTAIN_SECONDS


func _report() -> void:
	## [B2] One report upward, carrying the numbers rather than a verdict: what a win is WORTH
	## (a chest, a round, a coin) is the session's fact, not the arena's.
	if _reported:
		return
	_reported = true
	settled.emit({
		"winner": outcome,
		"summary": summary(),
		"seconds": clock.elapsed,
		"steps": clock.steps,
		"left_hp": side_hp(BalanceBrawl.SIDE_LEFT),
		"right_hp": side_hp(BalanceBrawl.SIDE_RIGHT),
	})


func summary() -> String:
	## One English line carrying everything a reader needs to compare two runs - which is
	## what BRAWL.md §14's determinism claim is made of: same preset, same line.
	return "BOUT OVER at %.1fs (sim, %d steps): winner %s | LEFT %d alive / %d hp, RIGHT %d alive / %d hp | kills %d-%d" % [
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


# ---------------------------------------------------------------- the factory's two doors
func spawn_zombie(p_type: String, _p_col: int, _p_row: int) -> Zombie:
	## THIS BRAWL'S HALF OF Spawn.create_unit(). The NAME IS THE SAME AS Battle's on purpose:
	## "build a body of this type" is ONE fact with two callers, not two facts (BRAWL.md §12;
	## [Arch]'s sixth rule carries both names on its allowlist). What differs is everything
	## AFTER the body exists - no grid registration (R2: the brawl has no grid), no level or
	## difficulty scaling (a formation carries its own numbers), and the position belongs to
	## the actor (R1).
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
	## [B5] THE THIRD BODY THE ARENA CAN FIELD, and the only one that belongs to the brawl
	## alone - no other mode has one. [P110f] It fields EVERY brawl faction, not only the humans:
	## the monsters (data/units/monsters.csv) are fielded through here too, which makes this name
	## narrower than what it does (the rename is a git mv the user runs, AGENTS.md §2).
	## Its door exists because THE ORDER IS THE
	## POINT: a zombie is told what it is (Zombie.apply_type) before it is attached and a
	## plant knows from its own file, while a brawl piece is one script for the whole roster and
	## therefore has to be TOLD its row. apply_piece() must run BEFORE _attach_piece(), which
	## is what calls Unit.place() -> _load_art() / _load_view(): a body told what it is
	## afterwards would wear no art and no scene and would never try again.
	var piece := HumanPiece.new()
	piece.name = "%s_%d" % [p_id, _next_uid]
	_next_uid += 1
	piece.apply_piece(p_id)
	_attach_piece(piece)
	return piece


func _attach_piece(p_unit: Unit) -> void:
	## The brawl's own version of Battle._attach_unit, deliberately NOT shared with it: that
	## one is about the GRID (register_plant / register_zombie) and this board has none. The
	## lines that ARE the same - board, parent, place, the death signal - are the handshake
	## Unit documents for itself.
	p_unit.board = self
	field.add_child(p_unit)
	## [S4/D72] HOW BIG THIS BODY IS DRAWN, set BEFORE place(): place() is what loads the view
	## and fits it to UNIT_ART_SIZE, so a scale applied afterwards would only reach the sprite
	## path. A brawl's cell is BrawlLayout's number and the turn engine's 96 px box is not it.
	p_unit.art_scale = BrawlLayout.piece_scale()
	## The null grid is the R1 contract: "this piece's position belongs to its driver".
	p_unit.place(null, 0, 0)
	p_unit.died.connect(_on_piece_died)


func _on_piece_died(p_unit: Unit) -> void:
	var actor := actor_of(p_unit)
	if actor != null:
		_kills[1 - actor.side] += 1
		print("[Brawl] %.1fs  %s piece down at (%.2f, %.2f)  ->  %d v %d alive"
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
	## SPACE pauses, F cycles the speed ladder, R starts the bout again, ESC leaves. There is
	## no HUD yet (B4), so the console is the readout - the same four keys the HUD will show as
	## buttons. ESC reports through `left`; where that lands is BrawlMain's routing.
	if not (p_event is InputEventKey):
		return
	var key := p_event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			print("[Brawl] %s" % ("paused" if clock.toggle_pause() else "running"))
		KEY_F:
			print("[Brawl] speed x%.0f" % clock.cycle_speed())
		KEY_R:
			print("[Brawl] restart")
			restart()
		KEY_ESCAPE:
			## [B2] The way out. Which page that becomes is the session's routing
			## (BrawlMain -> the menu) - the arena only reports that the spectator wants out.
			left.emit("menu")
		_:
			return
	## [P106] The same promise battle.gd makes: a key this node acted on does not also reach
	## Game's front-end handling. Unknown keys are NOT swallowed (the return above).
	get_viewport().set_input_as_handled()
