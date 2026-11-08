class_name Fx
extends RefCounted
## [P5] Fire-and-forget visual effects.
## Nothing here blocks the turn engine: each effect animates a throwaway node
## that removes itself. Game logic never waits for these.
##
## [P33] The pea shot is NOT an effect any more: a projectile carries damage
## and an animation booking, so it lives in its own class
## (scripts/projectiles/, extends Node2D) - see Projectile.
##
## NOTE ON NAMES: inner classes must never collide with Godot native class
## names. "Popup", "Panel", "Label", "Timer", "Line" etc. are native, so we
## use HitSpark / FloatingText instead.
##
## [P76] ONE LAYER, ONE DOOR (OPTIMIZATIONS B7's first bullet). Every effect used
## to be hung off whatever the caller had to hand - all eighteen call sites passed
## the lawn - which meant two things. The board teardown walked `grid.get_children()`
## and freed only `child is Unit`, so an effect that was mid-animation when the
## battle ended kept animating on a node nobody owned any more; and an effect that
## spawned BEFORE the next unit was added drew under that unit, because children
## draw in tree order. Both are invisible in a log line and visible on screen, so
## the fix is structural: this module owns a single `FxLayer` node that the board
## installs under itself, effects only ever enter through `_put()` below, and the
## teardown calls `clear()`.
##
## The layer is a CHILD of the lawn with an identity transform, which is what lets
## every position stay in lawn coordinates - the eighteen callers pass unit
## positions, and those are lawn-local because units are lawn children too. Its
## `z_index` (BalanceUI.FX_Z_INDEX, the one number here) is what keeps it ABOVE
## them: tree order used to do that for free, because an effect was always added
## after the units on screen, and a permanent layer is added before them instead.
##
## WHAT THIS BATCH DID NOT DO: B7's title also names "无池". The audited shape
## (`new() + create_tween()` per shot) no longer exists - a spark is a Node2D that
## animates in `_process` and frees itself - and the audit's own remedy line asks
## only for the layer and the unified cleanup. A pool would be a second owner for
## the same nodes, so it stays unbuilt until something measures a reason.

static var _layer: Node2D = null


static func attach(board: Node) -> void:
	## Called once by the bootstrap, right after the lawn enters the tree. `board`
	## stays the only parent this module ever uses, so every position a caller passes
	## means the same thing it meant when the effect was hung on the lawn directly.
	_layer = Node2D.new()
	_layer.name = "FxLayer"
	_layer.z_index = BalanceUI.FX_Z_INDEX
	board.add_child(_layer)


static func layer() -> Node2D:
	## Read-only for the probe and for anyone who must not add to it directly.
	return _layer


static func clear() -> int:
	## The teardown door: however many effects were still playing are now gone.
	## `queue_free` because these nodes are inside the tree mid-frame, exactly like
	## the units the same function already frees; the count skips anything already
	## queued so a second call in the same frame answers 0.
	if not is_instance_valid(_layer):
		return 0
	var n := 0
	for child in _layer.get_children():
		if not child.is_queued_for_deletion():
			n += 1
			child.queue_free()
	return n


static func _put(node: Node2D) -> void:
	## The only entrance an effect has into the tree. No layer means "no board is on
	## screen" - normal during boot and after a battle ends - and then the node is
	## dropped here rather than kept: a `Node` is not reference-counted, so an orphan
	## that is never added leaks past the exit counter for good. The same is true when
	## the layer died with the board it belonged to.
	if not is_instance_valid(_layer):
		node.free()
		return
	_layer.add_child(node)


class HitSpark extends Node2D:
	var _color := Color.WHITE
	var _dur := 0.22
	var _t := 0.0

	func setup(at_pos: Vector2, color: Color) -> void:
		position = at_pos
		_color = color

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(1.0 - _t / _dur, 0.0, 1.0)
		draw_circle(Vector2.ZERO, BalanceUI.SPARK_RADIUS * (1.0 + _t * 3.5), Color(_color, k * 0.75))


class SlamRing extends Node2D:
	## [B38] A BODY THAT FELL OUT OF THE AIR, AS ONE PICTURE ON THE GROUND. The leap's damage is a
	## circle (the row's 大招范围) and until now nothing on screen said so: the popups and the shoves
	## named the bodies the slam claimed, but the ground kept no record of what it had just been made
	## to give up. So this draws the circle - lit first, then run out to its edge by a ring - and the
	## last radius is EXACTLY the reach the caller was hit inside, the way BrawlShot._draw_blast made
	## the same promise for a 溅射半径 (BalanceUI.SLAM_*, all of it as fractions of one number).
	##
	## Shape follows the arena's ground: one draw_set_transform squash for the whole picture, at
	## BRAWL_SHADOW_DEPTH_SHARE - the same ratio every body's shadow is flattened by, so a ring that
	## would be a billboard in front of the bodies lies flat with them instead. HitSpark's shape on
	## purpose: a Node2D that animates in _process and frees itself, and the only entrance is _put.
	var _reach := 40.0
	var _dur := BalanceUI.SLAM_TIME
	var _t := 0.0

	func setup(at_pos: Vector2, reach_px: float) -> void:
		position = at_pos
		_reach = maxf(1.0, reach_px)
		## [P38]'s rule, still the rule: a divisor that comes from a tuning constant is floored here,
		## so a SLAM_TIME of 0 fades on one tick instead of painting NaN.
		_dur = maxf(BalanceUI.MIN_FX_TIME, BalanceUI.SLAM_TIME)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / _dur, 0.0, 1.0)
		## The front races out and then settles (sqrt, the shockwave idiom _draw_blast established -
		## a linear ring reads as a metronome, and this one is measuring a fall).
		var run := sqrt(k)
		draw_set_transform(Vector2.ZERO, 0.0,
			Vector2(1.0, BalanceUI.BRAWL_SHADOW_DEPTH_SHARE))
		## The claim, at full size and dying early: "everything inside THIS was struck".
		var core := 1.0 - k / BalanceUI.SLAM_CORE_SHARE
		if core > 0.0:
			var lit := BalanceUI.COLOR_SLAM_CORE
			lit.a *= core
			draw_circle(Vector2.ZERO, _reach, lit)
		## The ring, which arrives at the reach as the lit ground dies, so the size is carried over
		## instead of blinking.
		var edge := BalanceUI.COLOR_SLAM_WAVE
		edge.a *= 1.0 - k
		draw_arc(Vector2.ZERO, _reach * lerpf(BalanceUI.SLAM_WAVE_R_MIN, 1.0, run),
			0.0, TAU, 48, edge,
			lerpf(BalanceUI.SLAM_WAVE_W_MAX, BalanceUI.SLAM_WAVE_W_MIN, k))
		## ...and the earth flung past the edge, which is what makes the circle a landing and not a
		## decal: it is thrown OUT of the epicentre, and it dies thinner than it left.
		var dust := BalanceUI.COLOR_SLAM_DUST
		dust.a *= 1.0 - k
		for i in BalanceUI.SLAM_DUST:
			var ang := TAU * float(i) / float(BalanceUI.SLAM_DUST)
			var off := Vector2(cos(ang), sin(ang)) * _reach \
				* lerpf(BalanceUI.SLAM_WAVE_R_MIN, 1.0 + BalanceUI.SLAM_DUST_SCATTER, run)
			draw_circle(off, _reach * BalanceUI.SLAM_DUST_R * lerpf(1.0, 0.4, k), dust)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class FloatingText extends Node2D:
	var _text := ""
	var _color := Color.WHITE
	var _dur := 0.9
	var _rise := 40.0
	var _font_size := 15
	var _width := 90.0
	var _t := 0.0

	func setup(at_pos: Vector2, text: String, color: Color, font_size: int,
			rise: float, width: float, dur: float) -> void:
		position = at_pos
		_text = text
		_color = color
		_font_size = font_size
		_rise = rise
		_width = width
		## [P38] OPTIMIZATIONS B7: `dur` is the divisor in _process (the rise) and in
		## _draw (the fade), and it comes from a BalanceUI tuning constant - setting one
		## of those to 0 to "turn the popups off" would divide by zero and paint NaN
		## instead. A one-tick popup is the least this can mean.
		_dur = maxf(dur, BalanceUI.MIN_FX_TIME)

	func _process(delta: float) -> void:
		_t += delta
		if _rise != 0.0:
			position.y -= _rise * delta / _dur
		if _t >= _dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(1.0 - _t / _dur, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-_width * 0.5, 0.0), _text,
			HORIZONTAL_ALIGNMENT_CENTER, _width, _font_size, Color(_color, k))


static func spawn_spark(at_pos: Vector2, color: Color) -> void:
	var spark := HitSpark.new()
	spark.setup(at_pos, color)
	_put(spark)


static func spawn_slam(at_pos: Vector2, reach_px: float) -> void:
	## [B38] THE LEAP'S LANDING. `at_pos` is the GROUND point in field pixels (not the body's lifted
	## position - the ring lies flat under where the feet came down) and `reach_px` is the row's
	## 大招范围 already converted with the live cell, because BrawlField.cell() is the arena's ruler and
	## this module stays pixel-native like every other door here.
	var ring := SlamRing.new()
	ring.setup(at_pos, reach_px)
	_put(ring)


static func spawn_popup(at_pos: Vector2, text: String, color: Color) -> void:
	var p := FloatingText.new()
	p.setup(at_pos, text, color, BalanceUI.FONT_SIZE_POPUP, BalanceUI.POPUP_RISE,
		BalanceUI.POPUP_WIDTH, BalanceUI.POPUP_TIME)
	_put(p)


static func spawn_banner(at_pos: Vector2, text: String, color: Color) -> void:
	var p := FloatingText.new()
	p.setup(at_pos, text, color, BalanceUI.FONT_SIZE_BANNER, 0.0,
		BalanceUI.BANNER_WIDTH, BalanceUI.BANNER_TIME)
	_put(p)


class MeleeMark extends Node2D:
	## [P110b/P110e] ONE MELEE BLOW'S PICTURE, landing once, on the body it just opened up -
	## a zombie's claw, a militiaman's slash, a captain's divine arc. The node does not know
	## which: the drawing arrives as a texture, and EVERY picture of this family is one file
	## under assets/svg/fx/ drawn into the same box (see Fx.spawn_melee_fx).
	var _tex: Texture2D = null
	var _mirror := false
	var _t := 0.0

	func setup(at_pos: Vector2, tex: Texture2D, mirror: bool) -> void:
		position = at_pos
		_tex = tex
		_mirror = mirror

	func _process(delta: float) -> void:
		_t += delta
		if _t >= BalanceUI.MELEE_FX_TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _tex == null:
			return
		var k := clampf(_t / BalanceUI.MELEE_FX_TIME, 0.0, 1.0)
		## BORN at full strength, HELD there for the first MELEE_FX_HOLD of its life, and faded over
		## what is left: a mark that faded IN would read as a stain appearing on the plant
		## rather than as a blow landing on it.
		var alpha := clampf((1.0 - k) / (1.0 - BalanceUI.MELEE_FX_HOLD), 0.0, 1.0)
		## sqrt settles the pop early - the slash reaches its size almost at once and then only
		## fades. ease() would buy the same curve for one more knob to keep in BalanceUI.
		var box := BalanceUI.MELEE_FX_SIZE * lerpf(BalanceUI.MELEE_FX_POP, 1.0, sqrt(k))
		## [P110c] MELEE_FX_SIZE IS THE BOX THE DRAWING IS FITTED INTO, NOT A SCALE FACTOR, and the
		## fit is worked out from the TEXTURE's own size rather than from a number assumed here.
		## [P110b] handed the box straight to draw_set_transform: a scale of 70 against a 128 px
		## sheet painted 128 * 70 = 8960 px, i.e. a claw bigger than the whole board. That is
		## what "the effect should be one body wide" has to be spelled as in code.
		var tex_size := _tex.get_size()
		var fit := box / maxf(maxf(tex_size.x, tex_size.y), 1.0)
		## The mirror is a NEGATIVE X SCALE in the draw transform, not a second flipped asset:
		## one file serves both facings, so a turned piece and a zombie walking left can never
		## drift apart in two copies of the same drawing.
		var across := -fit if _mirror else fit
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(across, fit))
		draw_texture_rect(_tex, Rect2(-tex_size * 0.5, tex_size), false,
			Color(1.0, 1.0, 1.0, alpha))


class BeamLance extends Node2D:
	## [P110f] ONE RANGED ATTACK'S BEAM: a line between two bodies, at the moment the blow lands.
	## Unlike the melee marks this family has TWO endpoints, and both are read off the board once,
	## at spawn - see spawn_beam for why that is the honest choice here rather than a shortcut.
	var _kind := ""
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO
	var _t := 0.0

	func setup(p_kind: String, p_from: Vector2, p_to: Vector2) -> void:
		_kind = p_kind
		_from = p_from
		_to = p_to

	func _spec() -> Dictionary:
		return BalanceUI.BEAMS.get(_kind, BalanceUI.BEAMS[BalanceUI.BEAM_LASER])

	func _life() -> float:
		return maxf(0.01, float(_spec().get("time", 0.2)))

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _life():
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		## [P110g] The picture itself is the SHARED painter below, not this class's own code: the
		## arena's 3-second channel (scripts/core/brawl/brawl_beam.gd) draws the very same beam,
		## and two copies of "what a beam looks like" would drift apart the first time one of them
		## was tuned. What this class owns is only its CLOCK: a flash runs its phase 0 -> 1 as it
		## fades out, where a channel loops its phase and holds its fade until the end.
		var k := clampf(_t / _life(), 0.0, 1.0)
		Fx.draw_beam(self, _kind, _from, _to, k, 1.0 - k)


## WHERE EVERY MELEE PICTURE LIVES. A unit's sheet cell names a SHORT id ("claw", "slash",
## "slash_heavy", "slash_divine") and this root plus ".svg" is the only place the folder is
## spelled - the same rule data/projectiles.csv's 贴图 column follows one door down
## (ProjectileDB.art_path), so a board and a page can never disagree about where a picture is.
const MELEE_FX_ROOT := "res://assets/svg/fx/"


static func melee_fx_path(p_cell: String) -> String:
	## "slash" -> "res://assets/svg/fx/slash.svg". A cell that spells res:// or carries its own
	## extension is used as it is - ProjectileDB.art_path's rule, kept identical on purpose.
	var text := UnitCsvManager.clean(p_cell)
	if UnitCsvManager.is_blank(text):
		return ""
	if text.begins_with("res://"):
		return text
	if not (text.ends_with(".svg") or text.ends_with(".png")):
		text += ".svg"
	return MELEE_FX_ROOT + text


static func spawn_melee_fx(p_id: String, at_pos: Vector2, facing: Vector2 = Vector2.LEFT) -> bool:
	## [P110b/P110e] THE PICTURE A MELEE BLOW LEAVES, named by the attacker's own sheet row
	## (humans.csv / zombies.csv 近战特效) and asked of the body through Unit.melee_fx_id().
	## A zombie's "claw", a militia's "slash": one door, one family of drawings, and the caller
	## never spells a path.
	##
	## NOT a named unit effect (scripts/core/unit_fx.gd): those are POSES a body holds, they have
	## to survive that body's death and they must step aside when the body animates the event
	## itself. This is the other kind - a picture born at a spot on the board and gone in a third
	## of a second - which is what this module and its one layer are for.
	##
	## `facing` is the ATTACKER's and decides only the mirror: a mark that trails the swipe
	## reads wrong the other way round. LEFT is the default because that is the way a zombie is
	## drawn walking.
	##
	## Returns whether a picture was put on the board. "" (a body that names none), a name nobody
	## drew and a missing import are all the same answer - FALSE, quietly - because the blow still
	## landed: UnitArt.warn_once says so once per path, exactly like a unit with no sprite.
	var path := melee_fx_path(p_id)
	if path == "":
		return false
	var tex := UnitArt.load_texture(path)
	if tex == null:
		UnitArt.warn_once(path)
		return false
	var mark := MeleeMark.new()
	mark.setup(at_pos, tex, facing.x > 0.0)
	_put(mark)
	return true


static func beam_phase_speed(p_kind: String) -> float:
	## [P110h] How fast THIS look's clock wraps when it is CHANNELLED. The channel node asks it
	## (brawl_beam.gd) instead of holding a speed of its own, because the speed belongs to the
	## picture: fire flickers, bands travel, and one number could not serve both.
	var spec: Dictionary = BalanceUI.BEAMS.get(p_kind, BalanceUI.BEAMS[BalanceUI.BEAM_LASER])
	return maxf(0.0, float(spec.get("phase_speed", 0.0)))


static func beam_muzzle(p_kind: String, p_box: float) -> Vector2:
	## [B14] WHERE A LOOK LEAVES THE BODY THAT FIRES IT, in pixels of the board, for a body whose
	## picture is p_box pixels across (Unit.art_box). A beam of pure light starts at the caster's
	## centre - which is what every look but the bolt says, by spelling Vector2.ZERO - and the
	## thundercorn's lightning starts at the HORN, so its row in BalanceUI.BEAMS carries that spot
	## as a fraction of the drawn box. The fraction (and not a pixel offset) is what keeps the
	## horn's tip on the horn when the brawl scales a piece up for a big window.
	##
	## Asked by BOTH callers of a beam - the one-shot flash (BrawlActor) and the channel that
	## follows two bodies for seconds (BrawlBeam) - so "where does this attack come out of" has
	## one answer instead of two.
	var spec: Dictionary = BalanceUI.BEAMS.get(p_kind, BalanceUI.BEAMS[BalanceUI.BEAM_LASER])
	var frac: Vector2 = spec.get("muzzle", Vector2.ZERO)
	return Vector2(frac.x * p_box, frac.y * p_box)


static func draw_beam(p_ci: CanvasItem, p_kind: String, p_from: Vector2, p_to: Vector2,
		p_phase: float = 0.0, p_fade: float = 1.0) -> void:
	## [P110g] THE CLOSED LIST OF BEAM LOOKS, and the ONE painter BOTH of them use: the
	## fire-and-forget flash spawn_beam puts on the layer, and the arena-owned channel
	## (scripts/core/brawl/brawl_beam.gd) that follows two moving bodies for seconds. STATIC and
	## taking the CanvasItem, exactly like Projectile.draw_shot - so "what a beam looks like" has
	## one owner even though two very different things draw one.
	##
	## p_phase is the picture's own clock in 0..1 (the travelling bands, the flame's wobble) and
	## p_fade is how present the whole thing is (0..1). They are separate on purpose: a flash runs
	## its phase 0 -> 1 as it fades out, while a channel loops its phase and keeps its fade at 1
	## until the very end.
	if p_ci == null:
		return
	var spec: Dictionary = BalanceUI.BEAMS.get(p_kind, BalanceUI.BEAMS[BalanceUI.BEAM_LASER])
	var color: Color = spec.get("color", Color.WHITE)
	var width := float(spec.get("width", 4.0))
	var fade := clampf(p_fade, 0.0, 1.0)
	if fade <= 0.0:
		return
	var phase := clampf(p_phase, 0.0, 1.0)
	var dir := (p_to - p_from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if p_kind == BalanceUI.BEAM_FLAME:
		_beam_flame(p_ci, p_from, p_to, phase, fade, color, width, dir)
	elif p_kind == BalanceUI.BEAM_THUNDER:
		_beam_thunder(p_ci, p_from, p_to, phase, fade, color, width, dir)
	else:
		_beam_lance(p_ci, p_from, p_to, phase, fade, color, width,
			p_kind == BalanceUI.BEAM_IMPULSE)
	_beam_impact(p_ci, p_to, phase, fade, color, width)


static func _beam_lance(p_ci: CanvasItem, p_from: Vector2, p_to: Vector2, p_phase: float,
		p_fade: float, p_color: Color, p_width: float, p_pulse: bool) -> void:
	## Three passes, widest and faintest first: halo, body, white-hot core. The same layering the
	## claw sheet draws with its own strokes - a beam that is one flat line of one colour reads as
	## a UI rectangle rather than as light.
	p_ci.draw_line(p_from, p_to, Color(p_color, p_fade * 0.22), p_width * 3.0)
	p_ci.draw_line(p_from, p_to, Color(p_color, p_fade * 0.85), p_width)
	p_ci.draw_line(p_from, p_to, Color(1.0, 1.0, 1.0, p_fade), p_width * 0.38)
	if not p_pulse:
		return
	## 连续: bands of light running outward along the lance, so a HELD beam is not a still
	## picture. Four of them, evenly spaced, all moving the same way - deterministic (no rng in a
	## picture: the same attack plays the same way twice).
	var along := p_to - p_from
	for i in 4:
		var at := fposmod(float(i) / 4.0 + p_phase, 1.0)
		p_ci.draw_circle(p_from + along * at, p_width * 0.85, Color(1.0, 1.0, 1.0, p_fade * 0.5))


static func _beam_flame(p_ci: CanvasItem, p_from: Vector2, p_to: Vector2, p_phase: float,
		p_fade: float, p_color: Color, p_width: float, p_dir: Vector2) -> void:
	## A CONE, not a line, and it stops short of the target's centre: that is what tells 喷射火焰
	## apart from the two beams at a glance.
	var span := (p_to - p_from).length() * BalanceUI.BEAM_FLAME_REACH
	var half := deg_to_rad(BalanceUI.BEAM_FLAME_SPREAD)
	var tongues := maxi(1, BalanceUI.BEAM_FLAME_TONGUES)
	for i in tongues:
		var wobble := 1.0 - 0.24 * absf(sin(p_phase * 6.283 + float(i) * 1.7))
		var reach := span * wobble * (1.0 - 0.38 * float(i) / float(tongues))
		var off := lerpf(-half, half, float(i) / float(maxi(1, tongues - 1)))
		var wide := p_width * (1.0 + 0.5 * absf(sin(p_phase * 5.0 + float(i))))
		var tip := p_from + p_dir.rotated(off) * reach
		var side := p_dir.rotated(off + PI * 0.5) * wide
		p_ci.draw_colored_polygon(PackedVector2Array([p_from + side, p_from - side, tip]),
			Color(p_color, p_fade * 0.40))
	## The hot root, right at the muzzle: without it the cone looks detached from the eye.
	p_ci.draw_circle(p_from + p_dir * p_width * 0.6, p_width * 0.85,
		Color(1.0, 0.92, 0.55, p_fade * 0.9))


static func _beam_thunder(p_ci: CanvasItem, p_from: Vector2, p_to: Vector2, p_phase: float,
		p_fade: float, p_color: Color, p_width: float, p_dir: Vector2) -> void:
	## [B14] A BOLT, not a beam: the path is FOLDED, so it is a polyline rather than one draw_line.
	## Both ENDS stay exactly on the two bodies - the fold fades out with sin(t * PI), i.e. it is
	## zero at each end - because a bolt that started beside the horn or stopped short of the
	## victim would read as a stray line, which is the one thing this picture must not be.
	##
	## The fold is a function of the PHASE and of the span's index, never of the clock: a flash
	## runs its phase 0 -> 1 over its own 0.16 s and a channel loops it fourteen times a second, so
	## the same strike draws the same picture on any machine - no rng in a picture, the rule
	## _beam_lance's travelling bands already live by.
	var span := p_to - p_from
	var side := p_dir.rotated(PI * 0.5)
	var segs := maxi(2, BalanceUI.THUNDER_SEGMENTS)
	var points := PackedVector2Array()
	for i in segs + 1:
		var t := float(i) / float(segs)
		var amp := sin(t * PI)
		var jag := sin(float(i) * BalanceUI.THUNDER_FOLD + p_phase * BalanceUI.THUNDER_SHUFFLE)
		points.append(p_from + span * t + side * jag * amp * BalanceUI.THUNDER_JITTER)
	## The same three passes every other beam is drawn with - widest and faintest first, then the
	## colour, then the white-hot core - so a bolt and a lance still belong to one family of light.
	p_ci.draw_polyline(points, Color(p_color, p_fade * 0.22), p_width * 3.0)
	p_ci.draw_polyline(points, Color(p_color, p_fade * 0.85), p_width)
	p_ci.draw_polyline(points, Color(1.0, 1.0, 1.0, p_fade), p_width * 0.38)
	## The branches. WHICH vertex a fork grows from is decided by its own index and not by the
	## phase - a fork that jumped to another spot every frame would read as noise rather than as
	## lightning - while its LENGTH breathes with the phase, which is what keeps a channelled bolt
	## alive instead of merely vibrating.
	var forks := maxi(0, BalanceUI.THUNDER_FORKS)
	var reach := span.length() * BalanceUI.THUNDER_FORK_REACH
	for k in forks:
		var at := clampi(1 + int((float(k) + 1.0) * float(segs) / float(forks + 1)), 1, segs)
		var root := points[at]
		var lean := 1.0 if (k % 2) == 0 else -1.0
		var grow := 0.6 + 0.4 * absf(sin(p_phase * BalanceUI.THUNDER_SHUFFLE * 0.5 + float(k) * 1.7))
		var tip := root + (side * lean + p_dir * 0.35).normalized() * reach * grow
		var elbow := (root + tip) * 0.5 + side * lean * reach * 0.18
		p_ci.draw_polyline(PackedVector2Array([root, elbow, tip]),
			Color(p_color, p_fade * 0.45), p_width * 0.5)


static func _beam_impact(p_ci: CanvasItem, p_to: Vector2, p_phase: float, p_fade: float,
		p_color: Color, p_width: float) -> void:
	## What the beam does where it lands: a bloom that opens with the phase, so the hit reads as
	## energy arriving rather than as a line that happens to touch a dot.
	var bloom := p_width * BalanceUI.BEAM_IMPACT_FLASH * (0.55 + 1.45 * p_phase)
	p_ci.draw_circle(p_to, bloom, Color(p_color, p_fade * 0.30))
	p_ci.draw_circle(p_to, bloom * 0.45, Color(1.0, 1.0, 1.0, p_fade * 0.65))


static func spawn_beam(p_id: String, from_pos: Vector2, to_pos: Vector2) -> bool:
	## [P110f] THE PICTURE A RANGED ATTACK THAT DOES NOT FLY DRAWS: a beam between the two bodies,
	## named by the attacker's own sheet row (data/units/monsters.csv 远程特效) and asked of the
	## body through Unit.ranged_fx_id() - the twin of spawn_melee_fx above, for the third attack
	## shape.
	##
	## BOTH ENDPOINTS ARE READ ONCE, HERE, and the picture does not follow the bodies afterwards.
	## That is deliberate and it has a precedent: D61 says a 直线 shot goes where it was AIMED and
	## a target that walks out of the way dodges it. A beam that chased its target would be a
	## second, cleverer rule about the same thing - and this module holds no reference to a Unit
	## for the same reason the melee marks do not (a picture must be able to outlive the body it
	## was drawn on, and a held beam's caster can die mid-flash).
	##
	## An id nobody implemented is NOT silent, unlike a missing drawing: the attack really is a
	## beam, so the plainest beam is drawn and the log says which name was wrong.
	var kind := UnitCsvManager.clean(p_id)
	if UnitCsvManager.is_blank(kind):
		return false
	if not BalanceUI.BEAMS.has(kind):
		push_warning("[Fx] no such beam: " + kind + " -> drawing the laser look instead")
		kind = BalanceUI.BEAM_LASER
	var beam := BeamLance.new()
	beam.setup(kind, from_pos, to_pos)
	_put(beam)
	return true


static func self_check() -> void:
	## [P76] OPTIMIZATIONS B7: the layer and the one door, checked on a board of our
	## own. Runs from the bootstrap BEFORE the lawn exists, so it builds a throwaway
	## host and hands the layer back at the end - the bootstrap's own `attach()` must
	## stay the only one that sticks. No frame is awaited: nothing here animates, and
	## `queue_free()` is checked with `is_queued_for_deletion()`, which is the honest
	## same-frame answer ("the count is not a lie" rather than "the node is gone").
	var ok := true

	# 1. with no board, a spawn has to DROP the node: a `Node` is not ref-counted, so
	#    an orphan that is never added would leak for the rest of the process.
	var dropped := HitSpark.new()
	_put(dropped)
	var drop_ok: bool = _layer == null and not is_instance_valid(dropped)
	ok = ok and drop_ok
	print("[Fx] with no board a spark is freed at the door, not orphaned = %s | %s"
		% [str(drop_ok), "OK" if drop_ok else "FAIL"])

	# 2. attach() gives the board exactly one child, and that child is the layer:
	#    unnamed (name), moved (position) or parented elsewhere would each put the
	#    lawn-local coordinates the eighteen callers pass somewhere they do not mean.
	var host := Node2D.new()
	attach(host)
	var attach_ok: bool = is_instance_valid(_layer) and host.get_child_count() == 1 \
		and String(_layer.name) == "FxLayer" and _layer.position == Vector2.ZERO \
		and _layer.z_index > 0 and layer() == _layer
	ok = ok and attach_ok
	print("[Fx] attach() hangs one identity-transform layer above the units (z=%d, board children=%d) = %s | %s"
		% [_layer.z_index, host.get_child_count(), str(attach_ok),
			"OK" if attach_ok else "FAIL"])

	# 3. all three doors land inside the layer and nowhere else, still the two node
	#    kinds, still at the position the caller passed.
	var at := Vector2(120.0, -34.0)
	spawn_spark(at, Color.WHITE)
	spawn_popup(at, "check", Color.WHITE)
	spawn_banner(at, "check", Color.WHITE)
	var kids: Array = _layer.get_children()
	var route_ok: bool = kids.size() == 3 and host.get_child_count() == 1
	for child in kids:
		route_ok = route_ok and child.get_parent() == _layer and child.position == at
	route_ok = route_ok and kids.size() == 3 \
		and kids[0] is HitSpark and kids[1] is FloatingText and kids[2] is FloatingText
	ok = ok and route_ok
	print("[Fx] spark, popup and banner all enter through the one door (%d in the layer, %d on the board) = %s | %s"
		% [kids.size(), host.get_child_count(), str(route_ok), "OK" if route_ok else "FAIL"])

	# 4. the teardown door reports what it freed, once. `clear()` returning 3 is the
	#    whole point of B7's first bullet: those effects used to survive the board's
	#    `child is Unit` filter and keep animating on a node nobody owned.
	var freed := clear()
	var again := clear()
	var clear_ok: bool = freed == 3 and again == 0
	for child in kids:
		clear_ok = clear_ok and child.is_queued_for_deletion()
	ok = ok and clear_ok
	print("[Fx] clear() takes the %d still-playing effect(s) and a second call takes 0 = %s | %s"
		% [freed, str(clear_ok), "OK" if clear_ok else "FAIL"])

	# 5. the layer dies with its board: `host.free()` above is what a freed lawn looks
	#    like, and the door still answers 0 instead of touching a freed object. That is
	#    the failure the old `parent.add_child()` shape could not have - the parent it
	#    was handed was always somebody's live node.
	host.free()
	var gone := clear()
	_layer = null
	var after := FloatingText.new()
	_put(after)
	var gone_ok: bool = gone == 0 and _layer == null and not is_instance_valid(after)
	ok = ok and gone_ok
	print("[Fx] a layer freed with its board is never touched: clear()=%d and a late spawn is dropped = %s | %s"
		% [gone, str(gone_ok), "OK" if gone_ok else "FAIL"])
	print("[Fx] self-check %s" % ("PASSED" if ok else "FAILED"))
