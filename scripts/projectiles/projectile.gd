class_name Projectile
extends Node2D
## [P33] THE PROJECTILE AS ITS OWN ACTOR: once fired it flies along its lane,
## collides with the first body on its path, carries the damage to the impact,
## and removes itself. The plant only tunes the parameters and calls fire().
##
## WHY A NODE, not the old Fx.PeaShot tween + PeaHit RefCounted pair:
## - Lifetime accounting. The pending animation is booked in _ready and
##   released in _exit_tree, so EVERY exit path (hit, flew past the lawn,
##   the whole tree freed by a restart) settles exactly once. The old split -
##   booked by the shooter, released inside a callback package that had to be
##   manually strong-referenced against the GC (the 6db1a6b incident) - had
##   two places that could leak a round.
## - Re-validation. _source and _target are plain references re-checked with
##   is_instance_valid at impact: the shovel can free the shooter mid-flight,
##   exactly like PeaHit already allowed - but no Callable can dangle.
## - Late peas cannot mis-account: each shot remembers the resolution
##   GENERATION it was booked under and skips the release when a new round
##   has since started (the 3 s timeout reset the counter, yet the airborne
##   pea's complete_animation() used to eat the NEXT round's booking).
##
## COLLISION replaces the guaranteed-hit snapshot model: during the plant
## phase zombies never move (their actions resolve after every animation has
## landed), so the only mid-flight change on the board is a death. Each step
## sweeps the segment the pea crossed (no tunnelling at PEA_SPEED) and
## strikes the first live body on it:
## - body == target                  -> it lands: the shot was meant for it;
## - body != target, pierce left     -> pass untouched: a storm pea aims at a
##   farther zombie and must not steal the nearer one's own hit;
## - otherwise                       -> it lands: the target is gone or the
##   pierce is spent, so the shot drops onto the first body still standing.
## [P49] That whole question is ONE function now (_stops_for), because a LOBBED shot
## answers it differently: a melon is thrown in an arc, so a body standing between it
## and the zombie it was aimed at does not stop it - which is what the sheet spells
## out as 可越过障碍物 for the cabbage, and simply means by 抛掷 for the melon.
## PultProjectile replaces the rule without touching the flight, the accounting or
## the hit.

var damage := 0
var speed := BalanceUI.PEA_SPEED      # px/s, the constant-speed flight of P11
var dir := 1                          # +1 flies right, -1 flies left
var pierce := 0                       # live bodies this shot may pass through
var row := 0                          # the lane this shot sweeps for victims
var tint := BalanceUI.COLOR_PEA       # the subclass draws with it
## [P34] What the hit carries besides damage: status effects to hand the victim
## ("freeze" -> rounds) and whether the damage ignores armour. A snow pea sets the
## first, a fume-shroom breath the second; both ride the same shot.
var effects: Dictionary = {}
var pierce_armor := false
## [P77] WHICH FLIGHT this shot belongs to, and it exists for the screen door's benefit,
## not the shot's: the sheet's row says the door 只挡正面**直线射弹**, so only a pea-level
## straight line may be soaked by the door and may have its riders refused by it. This
## class IS the straight flight, so the default is true and only PultProjectile answers
## false - its arc goes over the door, which is the same fact its `_stops_for()` already
## states about the bodies in between. A hit that is not a shot at all (a blast, a spike,
## the shovel) never sets the key either, so it lands on hp: the door is asked about
## shots, and it is a door to straight ones.
var straight_shot := true
## [P49] 0 = an ordinary hit. Above 0 the impact also clips whatever stands in the
## four cells around where it landed, for this FRACTION of its own damage - the melon
## the sheet describes as 对其上下左右各造成一半伤害. Damage only: a rider (the icy
## melon's freeze) belongs to the body the shot was aimed at, which is exactly how the
## same sentence reads (伤害=attack，并冻结1回合 / 各造成一半伤害).
var splash := 0.0
## [P91] WHICH ROW of `data/projectiles.csv` this shot is. The table owns the shape of the
## flight (轨迹), how many bodies it passes (穿透), how many times the lawn edge turns it
## around (反弹), the armour/splash/status it carries and the two cues; the plant only
## names the row. Everything below is the RESOLVED value, filled in _configure().
var shot_id := ""
var trajectory := ""
var look := ""
## [D79] This shot's picture, resolved ONCE at launch (ProjectileDB.art_of) and carried: the row
## cannot change under a shot in flight, and asking the sheet again every frame would be a lookup
## per draw for an answer that is already known.
var art := ""
## [B32] The row's 尺寸 (px), resolved with the picture above: -1 = "the picture answers for itself".
var size := -1.0
## [B40] The row's 体型 magnitude as a MULTIPLIER, resolved with the picture above: 1.0 = 标准 / no
## word. Like 尺寸 it is frozen at launch and it scales the DRAW only.
var size_tier := 1.0
var bounce := 0                       # lawn-edge turns left in this shot's budget
## [P91] 穿透伤害: whether a body the shot passes THROUGH also takes the damage. Off by
## default (see _strike): the storms need "passed, untouched" and a table row opts in.
var pierce_damage := false
## [B30] 治疗: WHICH SIDE this flight hunts, and what its number does when it arrives. A
## healing shot sweeps the lawn for live ALLIES instead of for zombies, and PUTS its number
## back onto the body it was aimed at rather than taking it off. `damage` stays the payload
## either way - the shooter's own skill value owns the amount (the shot table's WHAT IS NOT
## HERE), and this flag only answers "wound or mend". It also refuses to be stopped by anyone
## who is not its target, which is the sheet's sentence for the 暖阳 (穿过非目标单位) and the same
## reading a 抛射 lob already keeps about the bodies standing in between.
var heals := false
## [P49] the two ends of a 抛射 arc, captured at launch because the body it was aimed at
## may be gone before it lands (see the [P91] arc note in _process).
var _start_x := 0.0
var _start_y := 0.0
var _aim_x := 0.0
## [P91] the direction a 追踪 shot is currently flying in, in world units.
var _heading := Vector2.RIGHT
## [B30] the top and bottom of the lawn for a 追踪 shot (±INF for every other flight, so the
## test in _process is a no-op there) - see the capture in _configure().
var _top_y := INF
var _bottom_y := -INF

## The cells a splashing shot reaches, as offsets from where it landed: 上下左右. The
## centre is deliberately absent - the body standing there already took the whole hit.
const SPLASH_CELLS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

## [P50] The two sounds a shot owns: the throw and the landing. They are DATA on the
## shot (set from the fire options), because the plant already knows which of the two it
## is - a pea goes "puff / flop", a melon goes "lob / crash". A subclass never picks a
## sample, it names a cue of BalanceAudio.SFX_DEFS, and an unknown cue is a boot failure.
## By PATH for the reason pult_plant.gd gives: a brand-new `class_name` does not resolve
## until the editor has rescanned the project, and a headless run cannot wait for that.
const SFX := preload("res://scripts/core/sfx.gd")
## [P91] the shot table: what THIS projectile is (trajectory, pierce, bounce, riders, cues).
const ProjectileDB := preload("res://scripts/core/db/projectile_db.gd")

var launch_cue := "shoot"
var hit_cue := "impact"

var _board = null                      # the battle, untyped here like Unit.board
var _source: Unit = null
var _target: Unit = null
var _passed: Array = []               # bodies this shot already pierced
var _accounted := false               # the one-booking flag
var _gen := -1                        # resolution generation of that booking
var _end_x := 0.0                     # past this the shot is over the lawn
var _gone := false                    # impact decided: stop flying, await free


static func fire(cls: GDScript, shooter: Unit, target: Unit, p_damage: int,
		opts := {}) -> void:
	## The one-line launch entry: pass the projectile class and the numbers.
	## opts: from_offset (muzzle), dir (+-1, auto by target side otherwise),
	## pierce, speed, tint, effects (status dict), pierce_armor (bool), splash
	## (fraction of the damage the four neighbouring cells also take), sfx / sfx_hit
	## (cue ids of BalanceAudio.SFX_DEFS for the throw and the landing). Without a
	## world or under the synchronous resolver (fast_forward, the self-checks) the
	## hit resolves here and now - no node, exactly like P30's sync path.
	var shot: Projectile = cls.new()
	shot._configure(shooter, target, shooter.position
		+ opts.get("from_offset", Vector2.ZERO), p_damage, opts)
	## [P50] The throw sounds HERE and not in _ready(): the synchronous path below never
	## enters the tree, so a cue booked with the flight would go missing from every
	## fast-forwarded round - the same split P34 had to solve for its status riders.
	SFX.play(shot.launch_cue)
	if shooter.board == null or shooter.grid == null \
			or not bool(shooter.board.resolution_staged):
		shot._resolve_now()
		shot.free()
		return
	shooter.grid.add_child(shot)


func _configure(shooter: Unit, target: Unit, from: Vector2, p_damage: int,
		opts: Dictionary) -> void:
	damage = p_damage
	_source = shooter
	_target = target
	_board = shooter.board
	## [P91] THE TABLE FIRST, THE CALLER SECOND: the row says what this shot is, and an
	## option the caller names wins over it (that is how 寒冰射手's 大招 freezes for three
	## rounds while the row says one). Every default below therefore reads as
	## "opts.get(key, the row's value)".
	shot_id = str(opts.get("shot", ProjectileDB.ID_PEA))
	## The trajectory is overridable like every other key: a caller that wants a 追踪 flight
	## out of an ordinary row can ask for it (the shots probe is the only caller today).
	trajectory = str(opts.get("trajectory", ProjectileDB.trajectory(shot_id)))
	look = ProjectileDB.look_of(shot_id)
	art = ProjectileDB.art_of(shot_id)
	size = float(opts.get("size", ProjectileDB.size_of(shot_id)))
	size_tier = float(opts.get("size_tier", ProjectileDB.size_scale_of(shot_id)))
	bounce = int(opts.get("bounce", int(ProjectileDB.row(shot_id).get("bounce", 0))))
	## [P34] The lane this shot flies down: the shooter's own row by default, but a
	## plant that fires up and down the lawn (the threepeater) names the row per shot
	## so one action can launch three lanes at once.
	row = int(opts.get("row", shooter.row))
	## [P91] Speed: the caller, else the row, else the default for this TRAJECTORY (a lobbed
	## shot has to be followed by the eye, which is why it is slower than a pea).
	var row_speed := ProjectileDB.speed_of(shot_id)
	speed = float(opts.get("speed", row_speed if row_speed > 0.0
		else (BalanceUI.PULT_SPEED if ProjectileDB.is_arc(shot_id) else BalanceUI.PEA_SPEED)))
	pierce = int(opts.get("pierce", int(ProjectileDB.row(shot_id).get("pierce", 0))))
	tint = opts.get("tint", tint)
	## The rider: an empty dict the caller passes on purpose (a 大招 whose own effects are
	## computed per lane) must be able to win, so only an ABSENT key falls back to the row.
	effects = opts.get("effects", ProjectileDB.effects_of(shot_id))
	pierce_armor = bool(opts.get("pierce_armor", bool(ProjectileDB.row(shot_id).get("armor", false))))
	pierce_damage = bool(opts.get("pierce_damage", ProjectileDB.pierce_damage(shot_id)))
	## [B30] Which side this flight hunts (see the `heals` note above): the row says it, and a
	## caller may say it again - the same shape every other key of this block has.
	heals = bool(opts.get("heals", ProjectileDB.heals(shot_id)))
	## [P77] DERIVED, never written twice: the 铁门 stops 正面直线射弹, and that is exactly
	## "this shot flies in a straight line". The flag and the armour story travel together.
	straight_shot = bool(opts.get("straight_shot", ProjectileDB.is_straight(shot_id)))
	## [P49] The melon's reach around its own landing point, as a fraction of the shot.
	splash = float(opts.get("splash", float(ProjectileDB.row(shot_id).get("splash", 0.0))))
	## [P50] The cue pair: the caller's, else the row's.
	launch_cue = str(opts.get("sfx", ProjectileDB.row(shot_id).get("cue", launch_cue)))
	hit_cue = str(opts.get("sfx_hit", ProjectileDB.row(shot_id).get("cue_hit", hit_cue)))
	position = from
	dir = int(opts.get("dir", 1 if target.position.x >= from.x else -1))
	## [P91] A 抛射 shot keeps the two ends of its arc: the muzzle it left and the body it
	## was aimed at (the arc's own y is drawn from them, see _arc_y()).
	_start_x = from.x
	_start_y = from.y
	_aim_x = target.position.x
	## [P91] A 追踪 shot starts out pointing at its target and re-aims every step.
	_heading = Vector2(float(dir), 0.0)
	## The flight ends at the far lawn edge plus one body, whatever it misses:
	## the grid geometry follows Layout, so this stays true on any window.
	var margin := BalanceUI.UNIT_BODY_SIZE
	if shooter.grid != null:
		var far_x := float(shooter.grid.cell_to_world(Balance.COLS, row).x) \
			if dir > 0 else float(shooter.grid.cell_to_world(0, row).x)
		_end_x = far_x + float(dir) * margin
		## [B30] A 追踪 shot moves in TWO dimensions, so the lawn has four edges it can leave
		## and not two: the x gate above was written when every flight in this class ran down
		## a lane. Captured for that flight only (a 直线/抛射 shot keeps ±INF and the y test
		## below can never fire for it).
		if trajectory == ProjectileDB.TRAJ_HOMING:
			_top_y = float(shooter.grid.cell_to_world(0, 0).y) - margin
			_bottom_y = float(shooter.grid.cell_to_world(0, Balance.ROWS - 1).y) + margin
	else:
		_end_x = from.x + float(dir) * 4000.0


func _ready() -> void:
	## The ONLY booking point - add_child already happened, the node owns its
	## lifecycle from here.
	_gen = _board.animation_generation()
	_board.add_pending_animation()
	_accounted = true


func _exit_tree() -> void:
	## The ONLY release point, reached by every way out of the tree.
	if _accounted:
		_accounted = false
		if is_instance_valid(_board) and _gen == _board.animation_generation():
			_board.complete_animation()


func _process(delta: float) -> void:
	## [P91] ONE body, THREE flight shapes, all read from the shot's row:
	##   直线 - the muzzle line it was fired along (the original pea);
	##   追踪 - re-aims at its target every step, so a body that walks is followed;
	##   抛射 - advances in x like a pea and owns its own y (a parabola through the muzzle
	##          and the body it was aimed at), which is presentation only: the swept
	##          collision still reads the x, so a lobbed shot cannot hit earlier or later
	##          than a straight one, however high it is thrown.
	if _gone:
		return              # impact decided, the node leaves with this frame
	var prev_x := position.x
	if trajectory == ProjectileDB.TRAJ_HOMING:
		var aim := _homing_heading()
		position.x += aim.x * speed * delta
		position.y += aim.y * speed * delta
	elif trajectory == ProjectileDB.TRAJ_ARC:
		position.x += speed * delta * float(dir)
		position.y = _arc_y()
	else:
		position.x += speed * delta * float(dir)
	var victim := _swept_body(prev_x)
	if victim != null and _strike(victim):
		return
	if position.y < _top_y or position.y > _bottom_y:
		## [B30] A 追踪 shot that has drifted off the TOP or the BOTTOM of the lawn is over,
		## exactly like one that passed the far edge: it will never meet a body again, and a
		## node that keeps flying keeps the round's animation booking open. The two bounds
		## stay ±INF for every other flight, so nothing else can ever reach this line.
		print("[SHOT] %s left the lawn across a row, nothing left on its path" % shot_id)
		_gone = true
		queue_free()
		return
	if float(dir) * (position.x - _end_x) >= 0.0:
		## [P91] 反弹: the lawn edge turns the shot around instead of ending it. The bodies
		## it already touched stay in `_passed`, so a bounce can never re-hit its way to
		## infinite damage on one zombie - it comes back for the ones it has NOT met.
		if bounce > 0:
			bounce -= 1
			dir = -dir
			_end_x = _far_x_for_dir()
			print("[SHOT] %s bounced off the lawn edge, %d bounce(s) left" % [shot_id, bounce])
			return
		print("[SHOT] %s flew past the lawn, nothing left on its path" % shot_id)
		_gone = true
		queue_free()


func _homing_heading() -> Vector2:
	## A 追踪 shot's direction THIS step: straight at its target while that target is
	## still standing, and the last heading it had once the target is gone (a homing shot
	## does not stop dead in the air because somebody else killed its prey - it keeps
	## going the way it was pointed and the ordinary collision rules take over).
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		var to := _target.position - position
		if to.length() > 0.01:
			_heading = to.normalized()
	return _heading


func _far_x_for_dir() -> float:
	## The x a shot flying in `dir` has to reach before it is over the lawn - the same
	## expression _configure uses at launch, asked again after a bounce reverses `dir`.
	var margin := BalanceUI.UNIT_BODY_SIZE
	if _source != null and is_instance_valid(_source) and _source.grid != null:
		var far_x := float(_source.grid.cell_to_world(Balance.COLS, row).x) if dir > 0 \
			else float(_source.grid.cell_to_world(0, row).x)
		return far_x + float(dir) * margin
	return _end_x


func _arc_y() -> float:
	## [P49/P91] A parabola through the two endpoints, peaking at PULT_ARC_HEIGHT above the
	## launch line at half flight: 4t(1-t) is exactly that shape. One expression covers both
	## directions; a zero span (a zombie on the muzzle) returns the flat line instead of
	## dividing by itself.
	var span := _aim_x - _start_x
	if absf(span) < 1.0:
		return _start_y
	var t := clampf((position.x - _start_x) / span, 0.0, 1.0)
	return _start_y - BalanceUI.PULT_ARC_HEIGHT * 4.0 * t * (1.0 - t)


func _swept_body(prev_x: float) -> Unit:
	## The live lane body this step crossed: its centre inside the swept
	## segment widened by one combined body radius. The nearest end wins when
	## the step covers two bodies (they can share a cell).
	var reach := BalanceUI.UNIT_BODY_SIZE * 0.5 + BalanceUI.PEA_RADIUS
	var near := minf(prev_x, position.x)
	var far := maxf(prev_x, position.x)
	var best: Unit = null
	var best_d := INF
	var homing: bool = trajectory == ProjectileDB.TRAJ_HOMING
	for u in _board.units:
		## [B30] WHICH SIDE a body has to be on to be in this flight at all: a healing shot
		## hunts the plants and a zombie standing in the lane is scenery it flies past, while
		## every other shot hunts the zombies. One gate here, so the swept segment, the lane
		## rule below and the |dy| rule all read the same answer.
		if u.is_zombie == heals or not u.is_alive():
			continue
		## [P91] A body in ANOTHER lane is invisible to a straight or lobbed shot (the lane is
		## what those flights are aimed down), but a 追踪 shot follows its prey wherever the
		## prey went - the |dy| gate below is what keeps it honest about where it flies.
		if not homing and u.row != row:
			continue
		if u in _passed:
			continue
		if u.position.x + reach < near or u.position.x - reach > far:
			continue
		## [P91] A 追踪 shot moves in two dimensions, so passing the x window is no longer
		## enough: it has to fly NEAR the body, or it would clip bodies it curved away from.
		## A straight or lobbed shot keeps the original x-only rule (a melon lands on the
		## body it was aimed at however high it is thrown - see the [P49] note in _process).
		if trajectory == ProjectileDB.TRAJ_HOMING and absf(u.position.y - position.y) > reach:
			continue
		var d := absf(u.position.x - position.x)
		if d < best_d:
			best_d = d
			best = u
	return best


func _hit_opts() -> Dictionary:
	## [P77] The one package that says HOW this shot's hit lands, shared by the damage and
	## the rider calls of both impact paths (and by the splash). A shot must not be able to
	## tell the armour one story and the status layer another: `pierce_armor` and
	## `straight_shot` travel together or not at all.
	return {"pierce_armor": pierce_armor, "straight_shot": straight_shot}


func _strike(victim: Unit) -> bool:
	## true = this impact was the shot's last (it is on its way out);
	## false = the pea passed through, the flight continues. [P49] The decision moved
	## out into _stops_for() so a lobbed shot can answer it another way.
	if not _stops_for(victim):
		## [P91] 穿透伤害: the classic pierce - a body the shot goes THROUGH still pays for it.
		## Off by default, because the storms depend on the opposite reading: a pea aimed at a
		## farther zombie must not steal the nearer one's own hit (P33), and that is what a
		## bare `pierce` counts. A row that wants the classic behaviour says so.
		if pierce_damage:
			_pay_pierced(victim)
		return false
	## One impact per pea: the flight is over here, the node leaves the tree at
	## the end of the frame - and the booking leaves with it (_exit_tree).
	_gone = true
	queue_free()
	if _board.is_finished():
		print("[PEA] the battle is over, the shot dies with no damage")
		return true
	if heals:
		## [B30] The mend is its own landing - see _mend() for what it leaves out.
		return _mend(victim)
	var before := victim.hp
	var src: Unit = _source if is_instance_valid(_source) else null
	victim.take_damage(damage, src, _hit_opts())
	## [P34] The rider comes with the hit. Both impact paths call apply_hit_effects,
	## because the synchronous path below is what the self-checks and fast_forward
	## settle on: an effect only wired into the staged flight would make the two
	## resolutions disagree. [P77] And the rider is handed the SAME opts as the damage,
	## because a door that let this shot through does not stop its freeze either.
	victim.apply_hit_effects(effects, _hit_opts())
	print("[PEA] landed: %d damage, hp %d -> %d" % [damage, before, victim.hp])
	## [P50] The landing, on this path only after the board-over guard above: a shot that
	## died because the battle ended did not hit anything, and should not say otherwise.
	SFX.play(hit_cue)
	## [P76] No liveness check here any more: the effect goes to the one layer, and the
	## door that puts it there is the one that knows whether that layer is still alive.
	Fx.spawn_spark(victim.position, tint)
	## [P110] A named effect. This was `shake(Vector2.RIGHT, ANIM_SHAKE_DIST * 0.6)`: the
	## direction was decided at the call site and the 0.6 was a number with no owner. Both
	## live in the "hit_shot" row of UnitFx / BalanceUI now, and the direction comes from the
	## victim's own facing - which for a zombie is still RIGHT, the way it is walking.
	victim.play_fx("hit_shot")
	## [P49] The melon's neighbours, on the SAME impact - see _clip_splash().
	_clip_splash(victim)
	return true


func _mend(victim: Unit) -> bool:
	## [B30] A healing shot's landing, and the ONLY thing that changes is the direction the
	## number moves: it goes BACK on instead of off. Everything else a hit does is deliberately
	## absent - no armour question (an ally has no door to hide behind), no status rider (the
	## row carries none, and a mend is not a blow that could leave one), no splash (a 暖阳 is
	## aimed at ONE patient: the whole point of picking the most wounded body is that it does
	## not spread), and no flinch (`play_fx("hit_shot")` would shake a body that was just
	## helped).
	var gained := victim.heal(damage)
	print("[SHOT] %s mended %s for %d, hp %d -> %d"
		% [shot_id, victim.tag(), gained, victim.hp - gained, victim.hp])
	SFX.play(hit_cue)
	_mend_tells(victim, gained)
	return true


func _mend_tells(victim: Unit, gained: int) -> void:
	## [B30] The two tells a mend leaves: a spark in this shot's own colour, and the "+N" over
	## the body that got it (the same tell the wall-nut's 铁壁 gives its player). A number only
	## appears when points really landed - an ally the shot found already whole is not a
	## miracle. BOTH impact paths call this, exactly like they both call apply_hit_effects: a
	## fast-forwarded round must show what a played one shows.
	Fx.spawn_spark(victim.position, tint)
	if gained > 0:
		Fx.spawn_popup(victim.position
			+ Vector2(0.0, -BalanceUI.UNIT_BODY_SIZE * 0.6), "+%d" % gained, tint)


func _stops_for(victim: Unit) -> bool:
	## [P91] A 抛射 shot flies OVER everything except the body it was aimed at (the fact the
	## sheet spells out as 可越过障碍物 for the cabbage and implies with 抛掷 for the melon).
	## If that body is gone - another shot killed it mid-flight - fall back to the rule
	## below and land on the nearest one still standing, rather than throwing a whole melon
	## away on an empty lane.
	## [B30] A 治疗 shot keeps the SAME clause, for the SAME reason in its own words: a 暖阳
	## spent on whichever body it happened to brush is not a healed patient, so the sheet says
	## 穿过非目标单位 and the flight obeys it the way a lob obeys 越过障碍物 - only the body it was
	## chosen for ends the flight, and if that body is gone the ordinary rule below takes over
	## and the shot mends the first ally still standing.
	if (trajectory == ProjectileDB.TRAJ_ARC or heals) and is_instance_valid(_target) \
			and victim != _target and not _passed.has(victim):
		return false
	## [P49] The one question a touched body asks of the flight: does it end here?
	## P33's rule, spelled out: the body this shot was aimed at always lands on it;
	## any other body is passed through while the storm's `pierce` lasts (a storm pea
	## aims at a farther zombie and must not steal the nearer one's own hit); once it
	## is spent, the shot drops onto the first body still standing.
	if victim == _target:
		return true
	if pierce > 0:
		pierce -= 1
		_passed.append(victim)
		return false
	return true


func _pay_pierced(victim: Unit) -> void:
	## [P91] The damage a body takes for standing IN the flight rather than at its end:
	## damage only - the rider belongs to the body the shot was aimed at, and a splash is a
	## claim about the landing point. Both impact paths share it, like every other rule here.
	if not is_instance_valid(_board) or _board.is_finished():
		return
	var before := victim.hp
	var src: Unit = _source if is_instance_valid(_source) else null
	victim.take_damage(damage, src, _hit_opts())
	print("[SHOT] %s pierced %s: %d damage, hp %d -> %d"
		% [shot_id, victim.tag(), damage, before, victim.hp])


func _clip_splash(victim: Unit) -> void:
	## [P49] 对其上下左右各造成一半伤害: every body standing in one of the four cells
	## around the impact point takes `splash` of this shot's damage. Damage only - the
	## rider belongs to the body the melon was aimed at. Both impact paths call this,
	## for the same reason they both call apply_hit_effects: a splash that only worked
	## while airborne would make a fast-forwarded round deal less damage than a live one.
	if splash <= 0.0 or not is_instance_valid(_board):
		return
	var grid = _board.grid
	if grid == null:
		return
	var amount := maxi(1, int(round(float(damage) * splash)))
	var src: Unit = _source if is_instance_valid(_source) else null
	var bodies := 0
	for off in SPLASH_CELLS:
		for cell in grid.get_zombies_at(victim.col + off.x, victim.row + off.y):
			var neighbour := cell as Unit
			if neighbour == null or not neighbour.is_alive():
				continue
			var was := neighbour.hp
			neighbour.take_damage(amount, src, _hit_opts())
			bodies += 1
			print("[SPLASH] %d damage to %s, hp %d -> %d"
				% [amount, neighbour.tag(), was, neighbour.hp])
	if bodies > 0:
		print("[SPLASH] %d body(s) clipped around (%d,%d) at %d each"
			% [bodies, victim.col, victim.row, amount])


func _resolve_now() -> void:
	## P30's synchronous path, unchanged: the self-checks and fast_forward
	## settle the hit the instant the plant acts - damage, spark and shake in
	## one call, no animation booked. [P34] damage, armour-piercing and status
	## riders all match _strike() here, one for one. [P49] so does the splash.
	if heals:
		## [B30] ...and so does the 暖阳's mend: the two paths are one event seen from either
		## side of the resolver, so a fast-forwarded round must give the patient the same
		## points a played one does. The tells stay behind the guard the hit below uses,
		## because this path also runs with no world at all (the start-up checks).
		var gained := _target.heal(damage)
		print("[SHOT] %s mended %s for %d (sync), hp %d -> %d"
			% [shot_id, _target.tag(), gained, _target.hp - gained, _target.hp])
		SFX.play(hit_cue)
		if is_instance_valid(_source) and _source.grid != null:
			_mend_tells(_target, gained)
		return
	var before := _target.hp
	_target.take_damage(damage, _source, _hit_opts())
	_target.apply_hit_effects(effects, _hit_opts())
	print("[PEA] hit (sync): %d damage, hp %d -> %d" % [damage, before, _target.hp])
	## [P50] And so does the landing sound - the two paths are the same event seen from
	## two sides of the resolver, so a fast-forwarded round must not be the quiet one.
	SFX.play(hit_cue)
	if is_instance_valid(_source) and _source.grid != null:
		Fx.spawn_spark(_target.position, tint)
		_target.play_fx("hit_shot")     # [P110] the same named effect as the staged path
	_clip_splash(_target)


func _draw() -> void:
	## [P91] The picture comes from the shared painter below, which [B7+] the brawl's own flight
	## (scripts/core/brawl/brawl_shot.gd) draws through as well - "what an arrow looks like" has
	## one owner even though two very different flights fire one.
	draw_shot(self, look, tint, Vector2(float(dir), 0.0), splash, Vector2.ZERO, 1.0, art, size,
		size_tier)


static func draw_shot(p_ci: CanvasItem, p_look: String, p_tint: Color,
		p_heading: Vector2 = Vector2.RIGHT, p_splash := 0.0, p_at := Vector2.ZERO,
		p_scale := 1.0, p_art := "", p_size := 0.0, p_tier := 1.0) -> void:
	## [P91] THE CLOSED LIST OF LOOKS - a new PICTURE means one branch here, and a new SHOT that
	## reuses one of them is a table row and nothing else. [B7+] It is STATIC and takes the
	## CanvasItem because TWO flights paint through it: this class (the turn engine's lane shot)
	## and the brawl's free-flight one.
	##
	## p_tint is the shooter's own colour for the two looks that HAVE one (so 冰西瓜 needs no
	## class - it is the melon picture with COLOR_FREEZE on it); the arrow and the ball own their
	## palettes in BalanceUI instead, because a wooden shaft is not a plant's colour.
	## p_heading is the direction of flight, and only the looks that POINT somewhere read it.
	## [B8+] p_at shifts the whole picture, and the turn engine always passes the origin: the
	## BRAWL's lobbed shots need it, because their arc is a LIFT and the node's own position is
	## the ground track a body is hit on (see scripts/core/brawl/brawl_shot.gd).
	## [D78] p_scale is the ALMANAC's zoom, and 1.0 is what both engines pass: the page's picture box
	## is 104 px while a board cell is 96 - the page asks for the same picture, bigger, instead of a
	## second illustration of it (see draw_extent, and [B32] shot_box for what "the same size" is).
	##
	## [D79] p_art is the row's 贴图, resolved by ProjectileDB.art_of() - ONE question ("does this
	## shot have a picture?") asked by both engines and by the 图鉴, so the three of them can never
	## disagree. A picture that loads is drawn INSTEAD of the primitive; anything else (no cell, or
	## a file the import has not produced) falls through to the drawing below, which is why the
	## table may name art nobody has drawn yet.
	##
	## [B32] p_size is the row's 尺寸 (ProjectileDB.size_of), 0 / negative meaning "the row states
	## nothing" - and THEN THE PICTURE IS THE RULER: an SVG is drawn at its own canvas size, a
	## code-drawn look at its own box (see shot_box(), the ONE door for "how big"). A stated size is
	## a square the picture is fitted into, so the exception (a 200 px item icon reused as a shot)
	## lives in the sheet instead of in the shared painter.
	## [B40] p_tier is the row's 体型 magnitude (ProjectileDB.size_scale_of), 1.0 = 标准 / no word, and
	## it is carried to shot_box() and no further: one multiply, at the one door, after the base won.
	if p_ci == null:
		return
	var share := shot_box(p_look, p_size, Vector2.ZERO, p_tier).x / maxf(draw_extent(p_look).x, 1.0)
	if p_art != "":
		var texture := UnitArt.load_texture(p_art)
		if texture != null:
			_draw_textured_shot(p_ci, texture, p_look, p_tint, p_heading, p_at, p_scale, p_size, p_tier)
			## [P51] The rind is NOT part of the picture: it is the splash's own tell, and the
			## sheet decides it (卷心菜 and 西瓜 share a picture and differ by the word 溅射), so
			## it stays code and is drawn over whatever the body turned out to be.
			if p_look == ProjectileDB.LOOK_MELON and p_splash > 0.0:
				_draw_melon_rind(p_ci, p_tint, p_at, p_scale * share)
			return
	## [B32] A stated 尺寸 scales the code box from its own size; when the row states none the share
	## is 1.0 and every radius below is exactly what it always was.
	p_scale *= share
	if p_look == ProjectileDB.LOOK_MELON:
		p_ci.draw_circle(p_at, BalanceUI.MELON_RADIUS * p_scale, p_tint)
		p_ci.draw_circle(p_at, BalanceUI.MELON_RADIUS * 0.62 * p_scale, p_tint.lightened(0.30))
		## [P51] The rind belongs to the SPLASH, not to the arc: 卷心菜 is thrown the same way
		## and lands the same way, and the sheet distinguishes the two only by the word 溅射.
		if p_splash > 0.0:
			_draw_melon_rind(p_ci, p_tint, p_at, p_scale)
		return
	if p_look == ProjectileDB.LOOK_ARROW:
		_draw_arrow(p_ci, p_heading, p_at, p_scale)
		return
	if p_look == ProjectileDB.LOOK_MUSKET:
		_draw_musket_ball(p_ci, p_heading, p_at, p_scale)
		return
	if p_look == ProjectileDB.LOOK_BOMB:
		## [B19] The lobber's shell. No heading and no smoke: a bomb is a sphere, and the STORY
		## of it is the arc the flight already paints - the picture only has to read HEAVY.
		_draw_bomb(p_ci, p_at, p_scale)
		return
	p_ci.draw_circle(p_at, BalanceUI.PEA_RADIUS * p_scale, p_tint)
	p_ci.draw_circle(p_at, BalanceUI.PEA_RADIUS * 0.45 * p_scale, p_tint.lightened(0.45))


static func look_takes_tint(p_look: String) -> bool:
	## [D79] DOES THE SHOOTER'S COLOUR APPLY TO THIS LOOK? It does for the two that ARE a colour
	## (the pea and the melon: 冰西瓜 is the melon wearing COLOR_FREEZE) and it does not for the
	## three that own their palettes (a wooden shaft is not a plant's colour, and neither is
	## [B19] a cast-iron bomb). The question is asked about the LOOK and not about the file, so
	## a picture that replaces a pea is tinted exactly like a pea - which is what lets the sheet
	## swap art in without touching a call site.
	return p_look != ProjectileDB.LOOK_ARROW and p_look != ProjectileDB.LOOK_MUSKET \
		and p_look != ProjectileDB.LOOK_BOMB


static func _draw_textured_shot(p_ci: CanvasItem, p_texture: Texture2D, p_look: String,
		p_tint: Color, p_heading: Vector2, p_at: Vector2, p_scale: float,
		p_size := 0.0, p_tier := 1.0) -> void:
	## [D79] A PICTURE FITTED INTO A BOX, rotated to its heading, aspect ratio kept.
	## [B32] WHAT THAT BOX IS changed hands: 外观 used to own it (so a 32 px pea.svg was drawn at the
	## pea's 14 px, and a shot that wanted a bigger picture needed a new LOOK), and the user's rule
	## now is "no sheet value ⇒ the asset's own size" - see shot_box(), the one door both this
	## painter and the 图鉴's zoom answer through. Neither version touches the hit box: this is the
	## draw, and a swap can still never change the board's geometry.
	##
	## It is rotated to the heading ALWAYS, not only for the arrow: a round pea does not care, and
	## a picture that does (a shaft, a puff of smoke) gets the direction for free - one rule
	## instead of a per-look list.
	var canvas := Vector2(float(p_texture.get_width()), float(p_texture.get_height()))
	var box := shot_box(p_look, p_size, canvas, p_tier) * p_scale
	if canvas.x <= 0.0 or canvas.y <= 0.0 or box.x <= 0.0 or box.y <= 0.0:
		return
	var drawn := canvas * minf(box.x / canvas.x, box.y / canvas.y)
	var colour := Color(1.0, 1.0, 1.0, p_tint.a) if not look_takes_tint(p_look) else p_tint
	var angle := p_heading.angle() if p_heading.length() > 0.01 else 0.0
	p_ci.draw_set_transform(p_at, angle, Vector2.ONE)
	p_ci.draw_texture_rect(p_texture, Rect2(-drawn * 0.5, drawn), false, colour)
	p_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_melon_rind(p_ci: CanvasItem, p_tint: Color, p_at: Vector2,
		p_scale: float) -> void:
	## The two arcs that say "this one splashes" (P51). Code, not art: see draw_shot.
	p_ci.draw_arc(p_at, BalanceUI.MELON_RADIUS * 0.62 * p_scale, -0.9, 0.9, 6, p_tint,
		1.5 * p_scale)
	p_ci.draw_arc(p_at, BalanceUI.MELON_RADIUS * 0.62 * p_scale, PI - 0.9, PI + 0.9, 6,
		p_tint, 1.5 * p_scale)


static func draw_extent(p_look: String) -> Vector2:
	## [D78] HOW BIG A CODE-DRAWN LOOK IS, in its own pixels - the owner of the radii below, so a page
	## that wants to show a shot LARGER than the board does (the almanac's picture box) can scale
	## it to fit without knowing a single radius. Keeping the list here rather than in the page is
	## the same rule the look list follows: a new picture is one branch in THIS file.
	## [B32] A ROW WITH A PICTURE does not stop here: shot_box() below asks this question first and
	## falls back to the asset's own canvas, which is what lets 外观 stay a CLOSED list of primitives.
	if p_look == ProjectileDB.LOOK_MELON:
		return Vector2(BalanceUI.MELON_RADIUS, BalanceUI.MELON_RADIUS) * 2.0
	if p_look == ProjectileDB.LOOK_ARROW:
		return Vector2(BalanceUI.ARROW_LEN + BalanceUI.ARROW_HEAD_LEN, BalanceUI.ARROW_FLETCH * 2.0)
	if p_look == ProjectileDB.LOOK_MUSKET:
		## The ball, plus the puff the ball drags BEHIND it (that is what makes it wider than tall).
		return Vector2(BalanceUI.MUSKET_SMOKE_OFFSET + BalanceUI.MUSKET_SMOKE_RADIUS
			+ BalanceUI.MUSKET_RADIUS, BalanceUI.MUSKET_SMOKE_RADIUS * 2.0)
	if p_look == ProjectileDB.LOOK_BOMB:
		## [B19] A sphere and nothing else - the box is its diameter.
		return Vector2(BalanceUI.BOMB_RADIUS, BalanceUI.BOMB_RADIUS) * 2.0
	return Vector2(BalanceUI.PEA_RADIUS, BalanceUI.PEA_RADIUS) * 2.0


static func shot_box(p_look: String, p_size := 0.0, p_canvas := Vector2.ZERO,
		p_tier := 1.0) -> Vector2:
	## [B32] HOW BIG ONE SHOT'S PICTURE IS BEFORE ANY ZOOM - the answer to "how big", asked by the
	## painter AND by the 图鉴's zoom, so a page can never show a shot at a size the board does not.
	## Three steps, in this order:
	##   * the row's 尺寸 when it states one - a SQUARE the picture is fitted into (aspect kept), for a
	##     code-drawn look the same number scales its own box; this is where an exception such as a
	##     200 px item icon reused as a shot belongs, in the sheet rather than in the painter;
	##   * else the asset's OWN canvas - the user's rule for the default (2026-10-08): "没有表值就取
	##     svg 素材的大小", which is also what the shot SVGs are authored at (pea 32, melon 40,
	##     arrow 64x16), so a picture finally draws at the size it was drawn to be;
	##   * else the look's code box, because a primitive has no file to ask.
	## [B40] THEN, AND ON WHICHEVER OF THE THREE WON: the row's 体型 magnitude. It is a MULTIPLIER and
	## not a fourth base, because the two questions are different - 尺寸 asks "how many pixels",
	## 体型 asks "how big a THING is" - and a sheet may legitimately mean both at once (暖阳 is a
	## 100 px icon of a thing that is 大, so 150 px). Keeping it here instead of at each call site is
	## what stops "大" from meaning 1.5× on the lawn and 1.4× in the 图鉴. Still DRAW ONLY: a hit box
	## is the flight's reach in CELLS and none of these numbers touch it.
	var box := draw_extent(p_look)
	if p_size > 0.0:
		box = Vector2(p_size, p_size)
	elif p_canvas.x > 0.0 and p_canvas.y > 0.0:
		box = p_canvas
	return box * maxf(0.01, p_tier)


static func _draw_arrow(p_ci: CanvasItem, p_heading: Vector2, p_at := Vector2.ZERO,
		p_scale := 1.0) -> void:
	## [B7+] AN ARROW POINTS WHERE IT FLIES. The three pieces are drawn in the SHOT's own frame:
	## draw_set_transform is set for them and RESET at the end, because that transform belongs to
	## the canvas item and anything painted afterwards would inherit the rotation.
	var angle := p_heading.angle() if p_heading.length() > 0.01 else 0.0
	p_ci.draw_set_transform(p_at, angle, Vector2(p_scale, p_scale))
	## The shaft, then the head in front of it, then the two fletches at the tail.
	p_ci.draw_line(Vector2(-BalanceUI.ARROW_LEN, 0.0), Vector2(BalanceUI.ARROW_HEAD_LEN, 0.0),
		BalanceUI.COLOR_ARROW_SHAFT, BalanceUI.ARROW_WIDTH)
	p_ci.draw_colored_polygon(PackedVector2Array([
		Vector2(BalanceUI.ARROW_LEN, 0.0),
		Vector2(BalanceUI.ARROW_HEAD_LEN, -BalanceUI.ARROW_HEAD_HALF),
		Vector2(BalanceUI.ARROW_HEAD_LEN, BalanceUI.ARROW_HEAD_HALF),
	]), BalanceUI.COLOR_ARROW_HEAD)
	for side in [-1.0, 1.0]:
		p_ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-BalanceUI.ARROW_LEN, 0.0),
			Vector2(-BalanceUI.ARROW_LEN + BalanceUI.ARROW_FLETCH, 0.0),
			Vector2(-BalanceUI.ARROW_LEN + BalanceUI.ARROW_FLETCH * 0.35,
				side * BalanceUI.ARROW_FLETCH),
		]), BalanceUI.COLOR_ARROW_FLETCH)
	p_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_musket_ball(p_ci: CanvasItem, p_heading: Vector2, p_at := Vector2.ZERO,
		p_scale := 1.0) -> void:
	## [B7+] A LEAD BALL WITH ITS SMOKE BEHIND IT. No transform here: a sphere looks the same
	## from every angle, so only the puff cares which way the shot is going.
	var back := -p_heading.normalized() if p_heading.length() > 0.01 else Vector2.LEFT
	p_ci.draw_circle(p_at + back * BalanceUI.MUSKET_SMOKE_OFFSET * p_scale,
		BalanceUI.MUSKET_SMOKE_RADIUS * p_scale, BalanceUI.COLOR_MUSKET_SMOKE)
	p_ci.draw_circle(p_at, BalanceUI.MUSKET_RADIUS * p_scale, BalanceUI.COLOR_MUSKET_BALL)
	p_ci.draw_circle(p_at + back * BalanceUI.MUSKET_RADIUS * 0.35 * p_scale,
		BalanceUI.MUSKET_RADIUS * 0.42 * p_scale, BalanceUI.COLOR_MUSKET_HIGHLIGHT)


static func _draw_bomb(p_ci: CanvasItem, p_at := Vector2.ZERO, p_scale := 1.0) -> void:
	## [B19] A CAST-IRON SPHERE, darker than the musket round and a size fatter: the player has
	## to read "this lands and bursts" from the silhouette alone, because the shot spends most
	## of its life above everyone's head. The highlight sits up-and-left - the light of the
	## arena, not the direction of a flight a sphere does not care about.
	p_ci.draw_circle(p_at, BalanceUI.BOMB_RADIUS * p_scale, BalanceUI.COLOR_BOMB)
	p_ci.draw_circle(p_at + Vector2(-0.32, -0.36) * BalanceUI.BOMB_RADIUS * p_scale,
		BalanceUI.BOMB_RADIUS * 0.34 * p_scale, BalanceUI.COLOR_BOMB_HIGHLIGHT)
