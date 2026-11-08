extends Node2D
## [B7+] A SHOT IN FLIGHT - a pea, an arrow, a musket ball or a lobbed melon, on its way to a body.
##
## WHY A FLIGHT OF ITS OWN (BRAWL.md §12): the turn engine's Projectile is a LANE creature - it
## sweeps a ROW, only ever sees zombies, books itself against the board's animation counter and
## resolves THROUGH the board. None of those four facts exist in the arena: there is no grid,
## both sides are shootable, nothing is staged, and a brawl target WALKS while the shot is in the
## air. So the flight is the brawl's own - and the two things that must NOT be duplicated are not:
## the DAMAGE goes through the shooter's own door (BrawlActor.land_hit, the same one a melee swing
## walks through) and the PICTURE goes through the shared painter (Projectile.draw_shot, the same
## one the turn engine's pea and melon are drawn by).
##
## THE THREE TRAJECTORIES OF data/projectiles.csv, all three flown here:
##   直线 - the line it was fired along. It does NOT follow a walking target, so it WHIFFS one
##          that stepped aside: the user's rule (O44) is that a miss is a miss, and BRAWL.md §8.7
##          files this nerf under "part of the game", not under "bug";
##   追踪 - re-aims at its mark every step while the mark lives, and keeps its last heading once
##          it does not (the shot is not recalled because somebody else got there first);
##   抛射 - climbs to an apex and comes down: it flies OVER whatever stands in between (the
##          trajectory is defined to arrive at a point, never swept mid-flight) and only looks
##          for a body where it slams down - height.z_height goes to 0 one step before that
##          look, so a body floating above the landing spot is now whiffed too. [B19] A row
##          with a stated 溅射半径 detonates at that arrival: the blast belongs to the GROUND
##          it hits, so it pays even when it came down on nobody - which is the one thing that
##          separates a lobber's shell from a melon, and every row without the cell keeps the
##          old landing exactly as it was. [B18] it is also
##          the one trajectory that is DRAWN pitched: the picture follows the VISUAL velocity
##          (the ground heading plus the climb -4 the fall), so an arrow leaves the bow at a
##          launch angle, goes level at its apex and dives onto the ground - while its ARRIVAL
##          stays exactly the one the flat track computes.
## A straight or homing shot is SWEPT against every body in its road each step, and stops on the
## first one - unless 穿透 lets it through (and 穿透伤害 decides whether that body pays anyway).
## [B21] WHICH BODIES ARE IN THE ROAD is one switch: SettingsStore.friendly_fire, captured at the
## muzzle. ON (the default) an ally eats a hit, a landing and a blast exactly like an enemy does;
## OFF the old rule stands - same-side bodies are ghosts to every shot, blasts included. Both
## ways the shooter's own body is excepted, and AIMING (BrawlActor, not this file) still only
## looks for enemies: the switch decides what a shot can HURT, never what a shooter chases.
## [B31] A HEALING FLIGHT IS THE ONE ROW THAT CHANGES BOTH HALVES OF THAT SENTENCE, and it is why
## aiming grew its own answer (BrawlActor._hunts_allies): a mend aims at its OWN side on purpose,
## and the bodies it may meet are its own side only - an enemy standing in its road is scenery it
## flies past, neither a victim nor a patient. The switch itself means nothing to such a flight,
## which is what _side_admits() below is the single owner of.
##
## [B17] EVERY MEETING PAYS THROUGH TWO DOORS: the XY overlap this file has always swept, AND
## the Z-interval overlap of height_body.gd (D93). Z here is AUTHORITATIVE, not a paint job
## (D96): a cruising pea holds 0.45..0.70 the whole flight, so a floating body that stands in
## the XY path but shares no height with it is WHIFFED exactly like one that stepped aside.
##
## A SHOT THAT TOUCHES NOBODY IS GONE: no damage, no cue, no burst (O44). If it is over the edge
## of the arena it is simply gone, unless the row's 反弹 still has a turn left in it.
##
## WHAT IT READS FROM THE SHARED TABLE: data/projectiles.csv through ProjectileDB. 速度 is a pace
## in the TURN ENGINE's pixels (converted below), 外观 is the picture, 音效 / 落点音效 are the two
## cues and 穿透 / 反弹 / 穿透伤害 / 溅射 ride along as they always did. [B19] 溅射半径 is the
## one new rider: stated in CELLS, it widens the splash and lets an arc detonate on empty ground. [B17] adds the six
## height columns; a blank there falls back HERE, to the brawl's own flying numbers (cruise
## height / thickness / lob apex) or to the row's own picture (body size = texture px over the
## art design cell, D100) - never to a walking unit's shape.
##
## NO class_name, BY PATH (the ProjectileDB doctrine): a brand-new global class is invisible to
## `godot --headless` until the editor rescans the project, and the arena preloads this file.

const Projectile := preload("res://scripts/projectiles/projectile.gd")
const ProjectileDB := preload("res://scripts/core/db/projectile_db.gd")
const SFX := preload("res://scripts/core/sfx.gd")
const HeightBody := preload("res://scripts/core/height_body.gd")

var shot_id := ""
## [D79] The row's picture, resolved once at launch - see Projectile.art.
var art := ""
var look := ""
## [B32] The row's 尺寸 (px), resolved with the picture: -1 = "the asset's own size decides".
var size := -1.0
## [B40] The row's 体型 magnitude as a multiplier, resolved with the picture: 1.0 = 标准 / no word.
## Draw only, like 尺寸 - the brawl's collision reads body_width in cells.
var size_tier := 1.0
## The shooter's own colour, used by the two looks that HAVE a tint (a pea is a ball of the
## plant's colour). The arrow and the ball own their palettes in BalanceUI and ignore it.
## [B31] A body that states the colour of its OWN shot (ShooterPlant.brawl_shot_tint) answers
## instead - the 暖阳 is gold in both modes, and the mend's tells below read this one field.
var tint := BalanceUI.COLOR_PEA
var speed := BalanceBrawl.SHOT_CELLS_PER_SECOND
var traj := ""
## The direction of flight. For 直线 it is set once at the muzzle and never touched again.
var heading := Vector2.RIGHT
## 穿透: live bodies this shot may still pass THROUGH. 反弹: how many times the edge of the arena
## turns it around instead of swallowing it. 穿透伤害: whether a body it passes through pays too.
var pierce := 0
var bounce := 0
var pierce_damage := false
## [B31] 治疗: this flight MENDS what it lands on instead of wounding it, and so hunts its
## SHOOTER'S OWN SIDE. The one cell the sheet writes for it (the same 治疗 column the turn
## engine's Projectile reads for the same row, B30's warm_sun) and the three questions it changes
## here: WHICH bodies the flight may meet at all (_side_admits), WHETHER it ends on a body it
## brushed (_stops_for) and WHAT the arrival does to it (_impact -> BrawlActor.land_mend).
## Captured at the muzzle like every other row fact, so a flight cannot change its mind mid-air.
var heals := false
var splash := 0.0
## [B19] The row's 溅射半径 in cells, -1.0 = the sheet says nothing. A stated number both
## WIDENS the splash (a blast is not a graze) and turns an arc's empty landing into a detonation.
var splash_reach := -1.0
## [B21] THE FRIENDLY FIRE POLICY, CAPTURED AT THE MUZZLE (SettingsStore.friendly_fire). ON,
## every body gate below admits same-side bodies: an ally in the road eats the shot like any
## other body, and a blast clips allies at the same share as enemies. The shot keeps ONE answer
## for its whole flight - flipping the setting mid-bout is a policy change, not a reweld.
## Two things the switch never moves: the shooter's own body is not a victim of its own shot
## (a gun does not hit the platform that fired it), and AIMING still only looks for enemies -
## this decides what a shot can HURT, not what a shooter targets.
var friendly_fire := true

var _field: BrawlField = null


## [W1] The live board's gates, with the brawl's own answer as fallback. `launch()` runs AFTER
## `add_child` (Brawl.spawn_shot), so `_draw` can legally meet a null `_field`; and a gate that
## falls back to the statics returns what a plain BrawlField would answer anyway - readings for
## a bout are bit-identical, while a war shot just asks its own field.
func _px_field() -> BrawlField:
	return _field if _field != null and is_instance_valid(_field) else null


func _shot_cell_px() -> float:
	var f := _px_field()
	return f.cell_px() if f != null else BrawlField.cell()


func _shot_board_cols() -> int:
	var f := _px_field()
	return f.board_cols() if f != null else Balance.COLS


func _shot_board_rows() -> int:
	var f := _px_field()
	return f.board_rows() if f != null else Balance.ROWS
var _shooter: BrawlActor = null
var _target: BrawlActor = null
## Every actor in this bout, handed over by the arena: a shot has to find the bodies it flies
## through, and the arena is the only thing that knows them all.
var _actors: Array = []
var _side := BalanceBrawl.SIDE_LEFT
## The blow, worked out by the shooter the moment the trigger was pulled (BrawlActor.blow_value):
## a shot CARRIES the damage, it does not own it. The victim's own books (厚皮's taken_mult) are
## applied on arrival by land_hit, because they can still change while the shot is in the air.
var _amount := 0.0
var _cell := Vector2.ZERO          # where the shot IS, in float cells (the arena's own unit)
var _aim := Vector2.ZERO           # the point it is flying at: the target's live position for a
								   # homing shot, the launch-time one for a straight or lobbed one
var _start := Vector2.ZERO         # the muzzle, for the lob's lift
var _passed: Array = []            # bodies this shot already went through
var _age := 0.0
## [B17] The shot's own place on the height axis, and the thing every meeting is now gated
## against (D96). A direct shot holds one cruise height for the whole flight; a lobbed one
## walks its arc (climb, apex, slam). The node's `position` stays the GROUND track.
var height: HeightBody = HeightBody.new()
var _z_apex := 0.0                   # the lob's apex, in cells (the row's z_height or the fall-back)
## [B18] CELLS PER SECOND of climb (+) or fall (-) along the arc - DERIVED, never simulated:
## the parabola's shape is one number (`_z_apex` over the ground span), so its slope is exact
## arithmetic and not a second physics answer the sim could drift from. It exists for the PICTURE
## only (the drawn pitch below) - no gate anywhere reads it.
var _z_vel := 0.0
var _flash := -1.0                   # >= 0 while the impact burst is drawn; then the node goes
var _done := false


static func speed_cells(p_id: String) -> float:
	## HOW FAST THIS SHOT CROSSES THE ARENA, in CELLS per second - the only unit the brawl has
	## (BrawlActor.pos is a float cell; move_speed and attack_reach are cells too). The sheet
	## speaks the turn engine's language: px/s, and a blank cell means "the default for this 轨迹",
	## which here would be BalanceUI.PEA_SPEED - a pea's speed, not an arrow's. So a row that
	## states a number is converted with Balance.CELL_SIZE, and a row that says nothing gets the
	## brawl's own pace. This is the one place the two coordinate systems meet.
	##
	## [S2/D73] THE DIVISOR IS THE SHEET'S OWN CELL (96), NOT THE BRAWL'S LIVE ONE - on purpose,
	## and it was nearly changed by mistake. Everything the simulation does is measured in CELLS
	## (speed, reach, body radius), so "620 px/s" has to become a fixed number of cells per second
	## or the PACING would change with the window: a player at 4:3 would watch the same arrow fly
	## slower across the same board than a player at 16:9. The brawl's cell is a PRESENTATION
	## number now (BrawlField.cell): where a cell is drawn, how big a piece is, how fast a shot
	## LOOKS. Only the second half of that pair may follow the window.
	var stated := ProjectileDB.speed_of(p_id)
	if stated <= 0.0:
		return BalanceBrawl.SHOT_CELLS_PER_SECOND
	return stated / float(Balance.CELL_SIZE)


func launch(p_shooter: BrawlActor, p_target: BrawlActor, p_id: String, p_amount: float,
		p_field: BrawlField, p_actors: Array) -> void:
	## Everything a shot needs, handed over once by the arena (Brawl.spawn_shot). The launch cue
	## sounds HERE and not on the first tick: a shot is fired when the trigger is pulled, and one
	## frame of silence at the muzzle is exactly the feedback that goes missing.
	_shooter = p_shooter
	_target = p_target
	_field = p_field
	_actors = p_actors
	_side = p_shooter.side
	shot_id = p_id
	_amount = p_amount
	var row := ProjectileDB.row(shot_id)
	look = ProjectileDB.look_of(shot_id)
	art = ProjectileDB.art_of(shot_id)
	size = ProjectileDB.size_of(shot_id)
	size_tier = ProjectileDB.size_scale_of(shot_id)
	traj = ProjectileDB.trajectory(shot_id)
	speed = maxf(1.0, speed_cells(shot_id))
	pierce = int(row.get("pierce", 0))
	bounce = int(row.get("bounce", 0))
	pierce_damage = ProjectileDB.pierce_damage(shot_id)
	heals = ProjectileDB.heals(shot_id)
	splash = float(row.get("splash", 0.0))
	splash_reach = float(row.get("splash_reach", -1.0))
	friendly_fire = SettingsStore.friendly_fire
	## [B17] THE SIX HEIGHT COLUMNS (D96). ProjectileDB answers -1.0 for a cell the row leaves
	## blank, so a number of -1 means "this row says nothing" and the fall-back below owns the
	## answer. A flying thing is NOT a walking body: an empty band falls back to the brawl's
	## cruise numbers, never to a unit's. A lob starts on the ground and climbs from the muzzle;
	## a direct shot holds its cruise height for the whole flight.
	var z_stated := float(row.get("z_height", -1.0))
	var th_stated := float(row.get("z_thickness", -1.0))
	height.z_gravity = BalanceBrawl.Z_GRAVITY_CELLS
	height.z_thickness = th_stated if th_stated >= 0.0 else BalanceBrawl.SHOT_Z_THICKNESS_CELLS
	if traj == ProjectileDB.TRAJ_ARC:
		## A STATED z_height is a fixed apex and stays authoritative; a blank one defers to the
		## muzzle-to-mark distance below ([B18]: the apex is then SHARE of the ground span, which
		## is what makes the launch angle constant across ranges).
		_z_apex = z_stated if z_stated >= 0.0 else -1.0
		height.z_height = 0.0
	else:
		height.z_height = z_stated if z_stated >= 0.0 else BalanceBrawl.SHOT_Z_CELLS
	## The footprint is stored but NOT yet wired into any XY gate this phase (dev doc §6-22:
	## the sweep keeps the round radii it has always used, so old rows resolve frame-identically).
	## A blank borrows the row's own PICTURE - the texture over the art design cell (D100's fixed
	## ruler), half as deep as wide, and a shot with no art has no depth to claim.
	var tex: Texture2D = null
	if art != "":
		tex = UnitArt.load_texture(art)
	var art_w := (tex.get_size().x / Balance.ART_DESIGN_CELL_PX) if tex != null else 0.0
	var w_stated := float(row.get("body_width", -1.0))
	var d_stated := float(row.get("body_depth", -1.0))
	var xo_stated := float(row.get("body_xoff", -1.0))
	var yo_stated := float(row.get("body_yoff", -1.0))
	height.body_width = w_stated if w_stated >= 0.0 \
		else (art_w if art_w > 0.0 else BalanceBrawl.SHOT_HIT_RADIUS_CELLS * 2.0)
	height.body_depth = d_stated if d_stated >= 0.0 else (art_w * 0.5 if art_w > 0.0 else 0.0)
	height.body_xoff = xo_stated if xo_stated >= 0.0 else 0.0
	height.body_yoff = yo_stated if yo_stated >= 0.0 else 0.0
	if _shooter.unit != null and is_instance_valid(_shooter.unit):
		tint = _shooter.unit.body_color
		## [B31] ...but a body that STATES the colour of its own shot wins, and it is asked the same
		## way `brawl_shot_id` is (a door on the body, not a guess here): the sun picture is tinted
		## by look_takes_tint(), so without this a 暖阳葵 would fire a GREEN sun - and the mend's
		## "+N" popup and spark below read THIS field, so one answer colours all three tells.
		if _shooter.unit.has_method("brawl_shot_tint"):
			tint = _shooter.unit.call("brawl_shot_tint")
	var from := p_shooter.pos
	var to := p_target.pos
	heading = (to - from).normalized() if (to - from).length() > 0.001 else p_shooter.facing
	## The muzzle: the shooter's centre pushed out to its own edge, so the picture does not start
	## inside the body that fired it (the complaint P11 fixed for the peashooter, and it is just
	## as true of an arrow).
	_start = from + heading * BalanceBrawl.BODY_RADIUS_CELLS
	_cell = _start
	_aim = to
	if traj == ProjectileDB.TRAJ_ARC:
		## [B18] THE LAUNCH ANGLE, one arithmetic. The parabola is z = 4·apex·t(1-t) over a
		## ground line, so its slope at the muzzle (t = 0) is 4·apex per span - with a blank
		## apex column that is a constant `4 · LOB_APEX_SHARE` no matter how far the shot flies,
		## and every arrow leaves the bow at the SAME angle while short shots simply arc lower.
		## A row that states its own z_height keeps its fixed apex (the high melon lob stays
		## writable data). Nothing here moves the sim: the ground track and the arrival moment
		## are the ones _tick_arc has always computed.
		var span := maxf(0.001, _start.distance_to(_aim))
		if _z_apex < 0.0:
			_z_apex = span * BalanceBrawl.LOB_APEX_SHARE
		_z_vel = _z_apex * 4.0 * speed / span
	position = _field.world_of(_cell)
	SFX.play(str(row.get("cue", "shoot")))
	queue_redraw()


func finished() -> bool:
	## True once the flight is over AND its burst has burnt out - the arena drops the node from
	## its list on this answer, which is the only place the list is pruned.
	return _done


func tick(p_dt: float) -> void:
	if _done:
		return
	if _flash >= 0.0:
		## The burst: the shot has landed and is only a picture now.
		_flash -= p_dt
		if _flash < 0.0:
			_done = true
			queue_free()
		else:
			queue_redraw()
		return
	_age += p_dt
	## [W1] The cap scales with the live board's width (a 30-cell field gives a slow shot three
	## times the road to arrive; the brawl's 9/9 == 1.0 keeps today's number bit-identical).
	if _age > BalanceBrawl.SHOT_MAX_SECONDS * float(_shot_board_cols()) / float(Balance.COLS):
		## The safety net, for the two ways a flight can fail to arrive: a target that left the
		## arena, and a sheet row whose speed came out at zero. Said out loud, because a shot that
		## disappears is otherwise indistinguishable from a shot that never happened.
		print("[Shot] %s flew %.1fs and never arrived - dropped" % [shot_id, _age])
		_vanish()
		return
	if traj == ProjectileDB.TRAJ_ARC:
		_tick_arc(p_dt)
		return
	_tick_direct(p_dt)


func _tick_direct(p_dt: float) -> void:
	## 直线 and 追踪 on one ground track, swept for bodies every step. They differ ONLY in where
	## the heading comes from - a straight shot keeps the line it was fired along (and whiffs a
	## target that stepped aside), a homing one re-aims while its mark lives. The cruise height
	## is never touched in here - launch() set it once and every gate below reads the same band.
	var step := heading
	## [B10] ...and a mark that gets SWALLOWED mid-flight is lost the same way a dead one is: the
	## shot keeps its last heading and flies on, which in practice means it lands on the body that
	## ate its mark (that body is standing exactly where the mark used to be).
	if traj == ProjectileDB.TRAJ_HOMING and _target != null and _target.is_alive() \
			and not _target.is_swallowed():
		var to_target := _target.pos - _cell
		var left := to_target.length()
		if left <= maxf(BalanceBrawl.SHOT_HIT_RADIUS_CELLS, speed * p_dt) \
				and height.z_hits(_target.height):
			_impact(_target)
			return
		if left > 0.001:
			step = to_target / left
	heading = step
	var next := _cell + step * speed * p_dt
	var victim := _swept_body(_cell, next)
	_cell = next
	position = _field.world_of(_cell)
	if victim != null and _stops_for(victim):
		_impact(victim)
		return
	if _outside_arena():
		if bounce > 0:
			_rebound()
		else:
			_vanish()
		return
	queue_redraw()


func _tick_arc(p_dt: float) -> void:
	## 抛射: it flies OVER whatever stands in between - that is what the trajectory MEANS in
	## data/projectiles.csv, and it is kept the old way: no mid-flight sweep, arrival at a
	## point. The GROUND track still decides WHEN it arrives, exactly as the turn engine's arc
	## does, so a lobbed shot can never hit earlier or later than a straight one however high it
	## is thrown. [B17] adds the height of the ARRIVAL: the shot slams Z to 0 one step before it
	## looks, so it lands ON whoever stands there - and whiffs a body floating above the spot.
	var to := _aim - _cell
	var left := to.length()
	if left <= maxf(BalanceBrawl.SHOT_HIT_RADIUS_CELLS, speed * p_dt):
		_cell = _aim
		height.z_height = 0.0
		position = _field.world_of(_cell)
		var victim := _nearest_body(_cell)
		if victim == null:
			## It came down on empty grass - or over a head too high off the ground to share
			## the landing band. A miss is a miss (O44) and the shot is simply gone… UNLESS the
			## row carries a blast of its own [B19]: a shell with a 溅射半径 detonates wherever
			## it arrives, body or no body, because the explosion is what it IS.
			if splash > 0.0 and splash_reach > 0.0:
				_detonate()
			else:
				_vanish()
			return
		_impact(victim)
		return
	var step := to / left
	heading = step
	_cell += step * speed * p_dt
	position = _field.world_of(_cell)
	var span := maxf(0.001, _start.distance_to(_aim))
	var t := clampf(_start.distance_to(_cell) / span, 0.0, 1.0)
	height.z_height = _z_apex * 4.0 * t * (1.0 - t)
	## [B18] the slope of that same parabola (dz/dt of 4·apex·t(1-t), t advancing at speed/span
	## per second) - positive through the climb, zero at the apex, negative the whole fall.
	_z_vel = _z_apex * (4.0 - 8.0 * t) * speed / span
	queue_redraw()


# ---------------------------------------------------------------- what it meets
func _side_admits(p_other: BrawlActor) -> bool:
	## [B31] WHICH SIDE a body has to be on for THIS flight to meet it at all - the one answer the
	## sweep, the lob's landing and the blast all read, so a healing row cannot be honoured by one
	## of them and forgotten by the other two (the shape every other "one fact, one door" rule in
	## this mode takes).
	##   a MEND sees its OWN side and nothing else - an enemy in the road is not a patient and not
	##     a victim, it is scenery the flight is written to fly past;
	##   every other flight sees the OTHER side, plus same-side bodies only while the [B21]
	##     friendly-fire switch is on (captured at the muzzle, so one flight never changes policy
	##     mid-air).
	## Note the switch is NOT asked on the mend branch, and that is not an oversight: the switch
	## decides whether an ally may EAT THIS SHOT, and a flight that cannot hurt anybody has no
	## reading of that question which means anything. Its own side is what it hunts, always.
	if heals:
		return p_other.side == _side
	return p_other.side != _side or friendly_fire


func _swept_body(p_from: Vector2, p_to: Vector2) -> BrawlActor:
	## THE FIRST BODY THE STEP CROSSED - an enemy while friendly fire is OFF, ANY side's body
	## while it is ON ([B21]; the shooter itself excepted, then and now). Free 2D space, so this
	## is a real point-to-segment distance and not the turn engine's x-window (that window is a
	## LANE fact - a shot there only ever meets bodies in its own row, which is a rule the brawl
	## does not have). Bodies already pierced are skipped, and the nearest one along the step
	## wins when two overlap.
	## [B31] WHICH SIDE is the helper's answer and not a third opinion spelled out here: a normal
	## flight sees the enemy (plus allies while the switch is on), a MEND sees its own side only.
	var reach := BalanceBrawl.BODY_RADIUS_CELLS + BalanceBrawl.SHOT_BODY_RADIUS_CELLS
	var seg := p_to - p_from
	var best: BrawlActor = null
	var best_t := INF
	for entry in _actors:
		var other := entry as BrawlActor
		## [B10] A body inside a belly cannot be swept through: the arrow meets the body that ate it
		## (it is a normal enemy body standing there) and stops on that instead.
		if other == null or other == _shooter or not other.is_alive() \
				or other.is_swallowed() or _passed.has(other) \
				or not _side_admits(other):
			continue
		if _segment_distance(p_from, p_to, other.pos) > reach:
			continue
		## [B17] the second door: the XY path crossed it, but no shared height means the shot
		## flies past (or under) it (D93). A body is only in the way at its own height band.
		if not height.z_hits(other.height):
			continue
		var t := (other.pos - p_from).dot(seg)
		if t < best_t:
			best_t = t
			best = other
	return best


func _nearest_body(p_at: Vector2) -> BrawlActor:
	## Who is standing where a lobbed shot comes down (or under a ball that caught up with its
	## mark). The same reach the sweep uses, so "hit" means one thing in this file - and the
	## same height gate, so the landing band answers for the slam the way the cruise band does
	## for a graze. [B21] With friendly fire ON an ALLY standing there takes the landing too;
	## the name used to say "enemy" because the side gate below used to be unconditional.
	var reach := BalanceBrawl.BODY_RADIUS_CELLS + BalanceBrawl.SHOT_BODY_RADIUS_CELLS
	var best: BrawlActor = null
	var best_d := reach
	for entry in _actors:
		var other := entry as BrawlActor
		if other == null or other == _shooter or not other.is_alive() \
				or other.is_swallowed() or not _side_admits(other):
			continue
		if not height.z_hits(other.height):
			continue
		var d := other.pos.distance_to(p_at)
		if d < best_d:
			best_d = d
			best = other
	return best


static func _segment_distance(p_from: Vector2, p_to: Vector2, p_point: Vector2) -> float:
	## How far a point is from the segment a step covered. The step is a straight line between
	## two ticks, and a distance-to-ENDPOINT test would let a fast ball clip through a body it
	## passed straight through - the same tunnelling the arrival radius below guards against.
	var seg := p_to - p_from
	var len_sq := seg.length_squared()
	if len_sq < 0.000001:
		return p_from.distance_to(p_point)
	var t := clampf((p_point - p_from).dot(seg) / len_sq, 0.0, 1.0)
	return p_from.lerp(p_to, t).distance_to(p_point)


func _stops_for(p_victim: BrawlActor) -> bool:
	## DOES THE FLIGHT END ON THIS BODY? The turn engine's rule, re-asked in two dimensions:
	## the body the shot was AIMED at always lands on it; any other body is passed through while
	## 穿透 lasts; once it is spent the shot drops onto the first body still standing.
	## 穿透伤害 decides whether a body it went THROUGH pays anyway - off by default, because the
	## storms depend on "passed, untouched".
	if p_victim == _target:
		return true
	## [B31] 穿过非目标单位 - the sheet's own words for a 治疗 row, and the one line that obeys
	## them: a mend that stops on whichever ally it happened to brush is not a healed patient, so
	## ONLY the body this flight was chosen for ends it. It is the SAME clause a 抛射 shot lives by
	## in the turn engine's copy of this function, for the same reason in the mend's words (an arc
	## arrives at a POINT, and so does a help that was aimed at somebody); and like that arc, when
	## the mark is gone the ordinary rule below takes over instead of the whole flight being thrown
	## away - a 暖阳 whose patient died mid-air mends the first ally it catches up with.
	## No _passed bookkeeping, deliberately: the pierce counter RECORDS each body it spends, so a
	## shot that went through one may stop on the next; a mend spends nothing and passes through
	## everything that is not its patient, so there is no budget to track and nobody to remember.
	if heals and _target != null and _target.is_alive():
		return false
	if pierce > 0:
		pierce -= 1
		_passed.append(p_victim)
		if pierce_damage and _shooter != null:
			_shooter.land_hit(p_victim, _amount)
		return false
	return true


func _outside_arena() -> bool:
	return _cell.x < 0.0 or _cell.x > float(_shot_board_cols()) \
		or _cell.y < 0.0 or _cell.y > float(_shot_board_rows())


func _rebound() -> void:
	## 反弹: the edge of the arena turns a shot around instead of swallowing it. Every shipped
	## row leaves the count at 0 - nothing bounces today - but the column says a row may, and a
	## bounce that only worked in the turn engine would be a table column that lies.
	bounce -= 1
	var size := Vector2(float(_shot_board_cols()), float(_shot_board_rows()))
	var margin := 0.05
	if _cell.x <= margin or _cell.x >= size.x - margin:
		heading.x = -heading.x
	if _cell.y <= margin or _cell.y >= size.y - margin:
		heading.y = -heading.y
	_cell.x = clampf(_cell.x, margin, size.x - margin)
	_cell.y = clampf(_cell.y, margin, size.y - margin)
	position = _field.world_of(_cell)
	queue_redraw()


# ---------------------------------------------------------------- the two endings
func _impact(p_victim: BrawlActor) -> void:
	## THE ARRIVAL. The blow is the SHOOTER's door, never this node's, and it is handed over
	## exactly as it was computed at the muzzle - so the rage and the attachments keep one owner.
	## [B31] A healing flight takes the SAME arrival to a DIFFERENT door (land_mend), because a
	## mend is not a blow and the two only agree about the number travelling and the body it
	## arrived on.
	_cell = p_victim.pos
	position = _field.world_of(_cell)
	if _shooter != null:
		if heals:
			## [B31] THE ARRIVAL WITH THE OTHER SIGN. The row's 落点音效 still plays - the flight
			## did arrive, and silence would read as another whiff - and the burst below is kept
			## for the same reason: "something got here" is a visible event whoever it lands on,
			## and the two rings are not a claim about damage. What is NOT asked is 溅射: a blast is
			## a WOUND spreading, while a 暖阳 is aimed at ONE patient - picking the most wounded
			## body is the whole point, and spraying the help back over the scrum would undo it.
			_shooter.land_mend(p_victim, _amount, tint)
			SFX.play(str(ProjectileDB.row(shot_id).get("cue_hit", "impact")))
		else:
			_shooter.land_hit(p_victim, _amount)
			SFX.play(str(ProjectileDB.row(shot_id).get("cue_hit", "impact")))
			_clip_splash(p_victim.pos, p_victim)
	_burst()


func _detonate() -> void:
	## [B19] THE ARRIVAL OF A BLAST WITH NOBODY UNDER IT. The whiff rule says a shot that
	## touches nobody pays nothing (O44) - a shell with a 溅射半径 did touch the ground, so the
	## neighbours still pay and the player still sees and hears the burst. There is only no
	## DIRECT victim: no full-price blow, and no kill attributed to the impact itself.
	if _shooter != null:
		SFX.play(str(ProjectileDB.row(shot_id).get("cue_hit", "impact")))
		_clip_splash(_cell, null)
	_burst()


func _clip_splash(p_at: Vector2, p_direct: BrawlActor) -> void:
	## 溅射: the neighbours pay a fraction of the same blow. The table's own column, applied here
	## because a brawl blow has no other place to be spread - damage only, and only when the row
	## asks for it. [B19] The lobber's shell is the first row the brawl fires that does ask, and
	## it also states 溅射半径 - the blast's own reach in cells. A row without that cell keeps
	## the graze width the melon has always had. [B21] With friendly fire ON the ring does not
	## stop at the side line: allies inside it pay the same share enemies do (the shooter's own
	## body excepted - it is the platform, not a victim of its own gun).
	if splash <= 0.0 or _shooter == null:
		return
	var reach := splash_reach if splash_reach > 0.0 \
		else BalanceBrawl.BODY_RADIUS_CELLS * 2.0
	for entry in _actors:
		var other := entry as BrawlActor
		if other == null or other == p_direct or other == _shooter \
				or not other.is_alive() or other.is_swallowed() \
				or not _side_admits(other):
			continue
		if other.pos.distance_to(p_at) > reach:
			continue
		## [B17] splash pays through the same second door as the hit itself did - the shot's
		## height at the moment of impact (a ground slam splashes the ground row it joined).
		if not height.z_hits(other.height):
			continue
		_shooter.land_hit(other, _amount * splash)


func _vanish() -> void:
	## THE WHIFF (O44, the user's rule): a shot that reaches the end of its flight without
	## touching anybody is GONE - no damage, no impact cue, no burst. It is the outcome a
	## straight shot produces often, and the user asked for it by name: 打空就是打空.
	## No log line either: a peashooter that misses three times a second would bury the log.
	_done = true
	queue_free()


func _burst() -> void:
	## [B20] A HIT FLASHES, A BLAST BURNS. Only a row that states 溅射半径 gets the long burst -
	## every other shot keeps SHOT_FLASH_SECONDS and the two rings it has always drawn.
	_flash = BalanceBrawl.BLAST_FLASH_SECONDS if splash_reach > 0.0 \
		else BalanceBrawl.SHOT_FLASH_SECONDS
	queue_redraw()


# ---------------------------------------------------------------- the picture
func _draw() -> void:
	if _flash >= 0.0:
		_draw_burst()
		return
	## The trail first, so the ball reads as a MOVING thing at 30 Hz, and the body after it.
	## Both ride the shot's own Z - the node's position is the GROUND track and this lift is
	## pure presentation, drawn with the arena's live cell (D100: the picture follows the
	## window, the judgement above it never does).
	var at := Vector2(0.0, -height.z_height * _shot_cell_px())
	## [B18] A LOB IS DRAWN ALONG ITS VISUAL VELOCITY: the ground heading at its own pace,
	## plus the vertical climb -4 the fall folded into screen y (negative = up). That is the
	## launch angle, the level apex and the dive, all from the one derived number _tick_arc
	## keeps honest - and the trail rides it too, so the arrow never slides sideways through
	## its own arc. draw_shot rotates the picture by this vector's angle for every look that
	## POINTS somewhere (the arrow among them), so no second rotation door exists. A direct
	## shot never moves the vertical term and draws exactly as it always did.
	var pict := heading
	if traj == ProjectileDB.TRAJ_ARC:
		var vel := heading * speed + Vector2(0.0, -_z_vel)
		if vel.length() > 0.001:
			pict = vel.normalized()
	draw_line(at - pict * BalanceUI.SHOT_TRAIL_LEN, at, BalanceUI.COLOR_SHOT_TRAIL,
		BalanceUI.SHOT_TRAIL_WIDTH)
	Projectile.draw_shot(self, look, tint, pict, 0.0, at, 1.0, art, size, size_tier)


func _draw_burst() -> void:
	## Two rings, expanding and fading over SHOT_FLASH_SECONDS. Drawn in this node's own frame
	## (position is already the impact point), so the burst costs one node and no second class.
	if splash_reach > 0.0:
		_draw_blast()
		return
	var t := 1.0 - clampf(_flash / BalanceBrawl.SHOT_FLASH_SECONDS, 0.0, 1.0)
	var radius := lerpf(BalanceUI.SHOT_FLASH_R_MIN, BalanceUI.SHOT_FLASH_R_MAX, t)
	var color := BalanceUI.COLOR_SHOT_FLASH
	color.a *= 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, BalanceUI.SHOT_FLASH_WIDTH)
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 18, color, BalanceUI.SHOT_FLASH_WIDTH * 0.6)


func _draw_blast() -> void:
	## [B20] AN EXPLOSION HAS THREE LAYERS, and the middle one is the message: the shockwave
	## expands from a stub to EXACTLY the 溅射半径 - the circle the eye watches die is the same
	## circle the damage was paid inside (_clip_splash measures the identical cell distance, and
	## BrawlField.world_of scales both axes by one cell, so the two circles agree at any window).
	## Fire core, wave, smoke - painted in that order only for the overlap, never for the rules.
	## Nothing here judges anything: like the old burst, this is a picture the flight already
	## settled, burning for BLAST_FLASH_SECONDS and then freeing the node.
	var t := 1.0 - clampf(_flash / BalanceBrawl.BLAST_FLASH_SECONDS, 0.0, 1.0)
	var reach_px := splash_reach * _shot_cell_px()
	## The smoke first, so the bright parts stay on top of it while the core lives.
	for i in BalanceUI.BLAST_PUFFS:
		var ang := TAU * float(i) / float(BalanceUI.BLAST_PUFFS) + heading.angle()
		var off := Vector2(cos(ang), sin(ang)) * reach_px * lerpf(0.30, 1.0, t)
		var smoke := BalanceUI.COLOR_BLAST_SMOKE
		smoke.a *= 1.0 - t
		draw_circle(off, reach_px * BalanceUI.BLAST_PUFF_R * lerpf(0.6, BalanceUI.BLAST_PUFF_GROW, t),
			smoke)
	## The shockwave: sqrt on the expansion so it races out then decelerates, like a real front.
	var wave := lerpf(BalanceUI.BLAST_WAVE_R_MIN, 1.0, sqrt(t))
	var wave_color := BalanceUI.COLOR_BLAST_WAVE
	wave_color.a *= 1.0 - t
	draw_arc(Vector2.ZERO, reach_px * wave, 0.0, TAU, 40, wave_color,
		lerpf(BalanceUI.BLAST_WAVE_W_MAX, BalanceUI.BLAST_WAVE_W_MIN, t))
	## The fireball: pops to full size at the instant of arrival, shrinks and fades out over
	## the first CORE_SHARE of the burst; the white heart is the same curve one shade tighter.
	var k := t / BalanceUI.BLAST_CORE_SHARE
	if k < 1.0:
		var core := reach_px * BalanceUI.BLAST_CORE_R * lerpf(1.0, 0.35, k)
		var flame := BalanceUI.COLOR_BLAST_CORE
		flame.a *= 1.0 - k
		draw_circle(Vector2.ZERO, core, flame)
		var heart := BalanceUI.COLOR_BLAST_CORE_HOT
		heart.a *= clampf(1.0 - k * 1.4, 0.0, 1.0)
		draw_circle(Vector2.ZERO, core * BalanceUI.BLAST_CORE_HOT_R, heart)
