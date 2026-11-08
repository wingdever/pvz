extends Node2D
## [P110g] A CHANNELLED BEAM - the eye tower's 连续冲击光束: one ranged attack that does not fire
## once but BURNS for as long as its row's 持续 cell says, dealing damage in ticks (1 s of gap
## between two channels comes from attack间隔 being the whole CYCLE - see the sheet).
##
## WHY IT IS A NODE AND NOT A PICTURE. The one-shot beams (Fx.spawn_beam) are fire-and-forget:
## born at a spot, faded, freed by the layer - and this project's rule is that such a picture may
## not hold a Unit, because a picture must be able to outlive the body it was drawn on. A
## three-second channel is the opposite kind of thing: it is a RELATIONSHIP between two living
## bodies, it has to follow both of them, and it has to stop the moment either of them falls. That
## is the same argument BrawlShot makes for itself, and it lands in the same place: the ARENA owns
## it (Brawl.beams), ticks it, draws it with the bout and frees it with it.
##
## ONE OWNER OF THE DAMAGE: every tick goes through the shooter's own land_hit(), the same door a
## melee swing, a shot's arrival and a hitscan beam already use (BRAWL.md §12) - a channel is a
## CADENCE, never a second damage table. The numbers that decide what a tick is WORTH are game
## rules and live in BalanceBrawl (BEAM_TICK_SECONDS and the share handed in at launch); what it
## looks like is BalanceUI's, and the drawing itself is Fx.draw_beam - the same painter the flash
## uses.
##
## [B14] TWO THINGS OPEN ONE NOW: a row whose 持续 cell holds a number (the eye tower's cadence,
## BalanceBrawl.BEAM_TICK_SHARE per tick) and a piece whose 大招持续 cell does (an ULTIMATE - the
## same beam, held, at ULT_TICK_SHARE per tick). Nothing in this file knows which one it is: the
## share arrives as an argument, exactly as the kind does.
##
## NO class_name, PRELOADED BY PATH, for the reason brawl_shot.gd spells out: a brand-new global
## class is invisible to a headless run until the editor has rescanned the project.

const Intent := preload("res://scripts/core/brawl/brawl_intent.gd")

var _shooter: BrawlActor = null
var _target: BrawlActor = null
var _kind := ""
var _pool: Array = []
## [B14] WHAT ONE TICK OF THIS CHANNEL IS WORTH, as a share of the shooter's blow. Handed in by
## the arena because the two things that open a channel pay differently - a 持续 row's cadence
## (BEAM_TICK_SHARE) and an ultimate's burst (ULT_TICK_SHARE) - and kept here as a number rather
## than asked of the shooter every tick, so a piece cannot change what its burning beam is worth
## half way through by putting a ring on.
var _share := BalanceBrawl.BEAM_TICK_SHARE
var _left := 0.0
var _tick_at := 0.0
var _elapsed := 0.0
## >= 0 while the beam is POWERING DOWN: the channel is over, the picture is still fading. Kept
## apart from _left so that "how long it burns" and "how long it takes to go out" stay two facts.
var _tail := -1.0
## True once this node has finished AND freed itself. BrawlShot's convention, and the arena
## depends on it: finished() only tells the arena to drop its REFERENCE, and a node that stayed in
## the field would sit there for the rest of the bout drawing nothing.
var _done := false


func launch(p_shooter: BrawlActor, p_target: BrawlActor, p_kind: String, p_seconds: float,
		p_pool: Array, p_share: float = BalanceBrawl.BEAM_TICK_SHARE) -> void:
	_shooter = p_shooter
	_target = p_target
	_kind = p_kind
	_pool = p_pool
	_share = maxf(0.0, p_share)
	_left = maxf(0.0, p_seconds)
	## THE OPENING BLOW IS NOT THIS NODE'S. The actor landed it on the frame that opened the beam
	## (BrawlActor._open_ultimate / _strike_once -> land_hit), so this node's first tick comes one
	## full period LATER - ticking immediately would deal the opening damage twice, sixteen
	## milliseconds apart, and a 3 second channel would pay out a free extra hit. The payout is
	## EXACTLY countable instead: the opening blow, then one every BEAM_TICK_SECONDS that fits
	## inside the channel - six hits over three seconds, and what those add up to is the SHARE's
	## business (three blows at BEAM_TICK_SHARE, i.e. the eye tower's cadence; six at
	## ULT_TICK_SHARE, i.e. an ultimate).
	_tick_at = maxf(0.01, BalanceBrawl.BEAM_TICK_SECONDS)


func tick(p_dt: float) -> void:
	if _done:
		return
	if _tail >= 0.0:
		_tail -= p_dt
		if _tail <= 0.0:
			_done = true
			queue_free()
			return
		queue_redraw()
		return
	## Either body falling ends the channel: a beam is a live eye burning a live body, and a
	## corpse neither aims nor burns. The shooter dying mid-channel is the common case (a tower is
	## exactly what the other side shoots at), and it must not leave a beam hanging over a body
	## that is already gone.
	if not _alive(_shooter):
		_cut()
		return
	if not _alive(_target) or _target.is_swallowed():
		## [B10] A SWALLOWED target counts as gone for the same reason a dead one does, and one more:
		## a beam is a line between two bodies, and there is no line into a belly - the devourer is
		## the body standing in the way, and the eye swings onto it below.
		## A dead TARGET, though, must not waste the rest of the channel: the beam swings to the
		## nearest enemy still standing and keeps burning. Without this, a 3-second channel that
		## killed its target in half a second would leave the tower idle for the whole cycle - the
		## one thing a channelled attack is not allowed to be.
		var next: BrawlActor = Intent.nearest_enemy(_shooter, _pool)
		if next == null:
			_cut()
			return
		_target = next
	_elapsed += p_dt
	_left -= p_dt
	if _left <= 0.0:
		## THE END IS CHECKED BEFORE THE TICK, so the frame the channel runs out on does not also
		## land a hit. That is what makes the payout EXACTLY countable: the opening blow (the
		## actor's) plus every BEAM_TICK_SECONDS that fits inside 持续 - 1 + 5 over a 3 second
		## channel, six hits, three blows' worth. Ticking first made the last frame a lottery.
		_finish()
		queue_redraw()
		return
	_tick_at -= p_dt
	if _tick_at <= 0.0:
		## += and not =, so a frame that ran long does not push the whole cadence back.
		_tick_at += maxf(0.01, BalanceBrawl.BEAM_TICK_SECONDS)
		## [B17] The channel burns WITHOUT re-asking the height gate each tick (dev doc §23):
		## the opening blow already passed it in the actor (_strike_once / _open_ultimate), and
		## through Phase 1 nothing here can change a body's z mid-burn - so one answer at the
		## door is the honest reuse, not a missing check. THE BATCH THAT GROWS AIR BEHAVIOUR
		## (dives, floats that move) must add a per-tick `_shooter.height.z_hits(_target.height)`
		## here and cut or swing on its answer (docs/dev/HEIGHT.md §9-6).
		_shooter.land_hit(_target, _shooter.blow_value() * _share)
		## A tick that KILLS is already handled: this node learns about it on the next one, at the
		## top of this function, and re-aims there.
	queue_redraw()


func is_shooter(p_actor: BrawlActor) -> bool:
	## WHO OPENED THIS BEAM. The arena asks it (is_channelling) so one eye cannot burn two bodies
	## at once, and it is the reason the arena keeps no per-actor flag of its own.
	return _shooter == p_actor


func finished() -> bool:
	## The arena's door, exactly like BrawlShot's: true on the frame this node may be dropped from
	## the list - and by then the node has already queued its own free (see _done).
	return _done


func _finish() -> void:
	## A channel that RAN OUT powers down over BalanceUI.BEAM_CHANNEL_TAIL rather than snapping off, so
	## the eye reads as a machine spinning down - and the gap the sheet asked for starts from here,
	## visually.
	_left = 0.0
	if _tail < 0.0:
		_tail = BalanceUI.BEAM_CHANNEL_TAIL


func _cut() -> void:
	## A beam whose EYE or whose TARGET is gone does not power down - it is simply not there any
	## more: a fade would be drawn over a body that is already fading itself, from a position that
	## belongs to a corpse.
	_left = 0.0
	_tail = 0.0
	_done = true
	queue_free()


func _fade() -> float:
	if _tail >= 0.0:
		return clampf(_tail / maxf(0.001, BalanceUI.BEAM_CHANNEL_TAIL), 0.0, 1.0)
	## A short ramp at the START as well: a beam that appears at full strength on the frame it is
	## switched on reads as a glitch, where a tenth of a second of coming up reads as a machine
	## spinning up. A one-shot FLASH does not want this - it is the whole point of a flash - which
	## is why the ramp lives here and not in the painter.
	return clampf(_elapsed / maxf(0.001, BalanceUI.BEAM_CHANNEL_RAMP), 0.0, 1.0)


func _alive(p_actor: BrawlActor) -> bool:
	## BrawlActor.is_alive() already covers "unit freed" (play_death queue_frees the body a moment
	## after it falls, and the actor outlives it), so this is one question in one place.
	return p_actor != null and p_actor.is_alive()


func _draw() -> void:
	if not _alive(_shooter) or not _alive(_target):
		return
	## The phase LOOPS here (unlike a flash's 0 -> 1): the bands and the flicker have to keep
	## running for three whole seconds. HOW fast it wraps is the look's own number (Fx.beam_phase_speed
	## -> BalanceUI.BEAMS) and not this node's: fire flickers several times a second where a lance's
	## bands travel slowly, and one shared speed made a channelled flame look like slow motion.
	var phase := fposmod(_elapsed * Fx.beam_phase_speed(_kind), 1.0)
	## [B14] The line starts where the LOOK says its attack leaves the body (BrawlActor.muzzle:
	## the eye's centre, or the thundercorn's horn) and is re-read here every frame - unlike a
	## flash, a channel is a relationship between two moving bodies, so a shooter that walks
	## mid-burn carries its horn along with it.
	Fx.draw_beam(self, _kind, _shooter.muzzle(_kind), _target.unit.position, phase, _fade())
