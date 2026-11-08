class_name UnitFx
extends RefCounted
## [P110] NAMED UNIT EFFECTS - what a body DOES when something happens to it.
##
## THE SPLIT (the prose owner of these rules is docs/prompt/FX.md, the call-site list is docs/dev/FX.md):
##   this file  WHICH effects exist, what each one is made of, who wins when two collide.
##   Unit       the CHANNELS an effect writes (red flash / pose lean - rocked about the feet
##              by the [B33] stun sway / knock-back / idle sway and [B33] idle stretch /
##              [B34] hit jelly - the same scale channel, ringed).
##   BalanceUI  every number either of them reads - no angle or duration is spelled here.
## Nothing in this file draws: an effect is a pose a body is asked to hold, and the body
## already knows how to draw itself (sprite, view scene or flat shape).
##
## WHY THE PARAMETER IS UNTYPED. play() acts on a unit, and spelling that type would make
## this file and unit.gd name each other. Unit.board has the same shape for the same reason
## (see its header comment): the caller knows the type, this file only calls doors on it.
##
## WHY THIS IS NOT scripts/fx/fx.gd. Fx owns the BOARD's throwaway pictures (sparks, rings,
## popups) on one shared layer, and its header says so. A flinch is not a picture on the
## lawn: it is a temporary POSE of one body, it must survive that body's death, and it must
## step aside when that body animates the same event itself. Different lifetime, different
## owner - which is why the named effects are here and the twelve Fx call sites are not.
##
## THE NAMES AND WHERE THEY ARE TRIGGERED TODAY (the call sites are the trigger owner; this
## table is the behaviour owner):
##   "hit"       a body is damaged by a CHOMP        Zombie.act BITE -> the victim
##   "hit_shot"  a body is damaged by a PROJECTILE   Projectile._strike / _resolve_now
##   "attack"    a body strikes                      Zombie.act BITE / EAT_BRAIN, BrawlActor._begin_strike
##   "stun"      a body is dazed [B33]               BrawlActor.apply_stun, re-armed each tick
##               [W12]                             by _keep_stun_sway (the real-time stun: a
##                                                 devourer whose meal failed, BRAWL.md §8.14)
##   "idle"      the baseline: [B33] the stretch by default, the old breath on request
##                                                   always on - Unit._tick_idle
##   "death"     a body falls                        Unit.play_death  ->  death_spec() below
##
## WHAT IS DELIBERATELY *NOT* A NAMED EFFECT: the giant zombie's hammer. Its wind-up drops
## the whole body DOWN and its victim is thrown UP, and neither is "forward" or "backward"
## - that is a move's own choreography, and it keeps calling Unit.shake() directly. The
## rule of thumb: a named effect is what EVERY body does; a move's flourish stays with the
## move. Adding one is a row here plus a line in docs/prompt/FX.md, not a new door.
##
## [B25] THE DEATH HAS TWO PRESENTATIONS, and they are NOT two ids in the priority table:
## there is still exactly one death (a corpse competes with nothing). `death_spec()` below is
## the table of the ways a body may spend its last second, and `Unit.play_death()` reads it.
##
## [B33] THE IDLE HAS TWO PRESENTATIONS too, for the same reason and in the same shape: the
## baseline stays ONE row in the priority table, `idle_spec()` is the table of ways to stand
## doing nothing, and the default is the NEW one (long-and-thin against short-and-wide).

const ID_HIT := "hit"
const ID_HIT_SHOT := "hit_shot"
const ID_ATTACK := "attack"
const ID_STUN := "stun"
const ID_IDLE := "idle"
const ID_DEATH := "death"

## 死亡 > 受击 > 被射 > 眩晕 > attack > 空闲 - the ladder is the user's call, [P110];
## [B33] slotted stun into it as the first guess (see PRIORITY_STUN for the reasoning).
const PRIORITY_DEATH := 100
const PRIORITY_HIT := 30
## A chomp outranks a pellet on purpose: a body being chewed must not have its flinch cut
## short by a pea landing in the same frame. The two are otherwise the same effect.
const PRIORITY_HIT_SHOT := 25
## [B33] Stun sits BELOW every flinch and ABOVE the lunge: a chomp or a pellet still snaps a
## dazed body awake (a stun is a STATE an attack wears off), while `attack` must not start a
## lunge on one - a dizzy body does not strike. Reshape freely; it is one number.
const PRIORITY_STUN := 22
const PRIORITY_ATTACK := 20
const PRIORITY_IDLE := 0


static func priority(p_id: String) -> int:
	## What this id is worth against whatever a body is already playing. -1 covers both
	## "nothing is playing" ("") and any typo, and it is below every real effect: an empty
	## body always loses to an effect that is still running.
	match p_id:
		ID_DEATH: return PRIORITY_DEATH
		ID_HIT: return PRIORITY_HIT
		ID_HIT_SHOT: return PRIORITY_HIT_SHOT
		ID_ATTACK: return PRIORITY_ATTACK
		ID_STUN: return PRIORITY_STUN
		ID_IDLE: return PRIORITY_IDLE
	return -1


static func spec(p_id: String) -> Dictionary:
	## THE TABLE. Empty means "no such effect" and play() says so out loud.
	##
	## A POSITIVE lean tips the body FORWARD and a positive push moves it forward; both are
	## resolved against the unit's own facing (Unit.facing_dir), which is what lets ONE row
	## describe a plant looking right and a zombie looking left. `time` is how long the pose
	## takes to come back to rest: every effect SNAPS into its pose and eases out of it, the
	## shape shake() always had - a flinch that eases IN reads as a shove, not as a hit.
	## [B33] `sway` is the third thing a row can ask for: an amplitude of lean ROCKED about the
	## FEET (Unit.sway_pose owns the hinge and hands it back when the body settles), facing
	## deciding only which way the first pass goes.
	## [B34] `jelly` is the fourth: an amplitude of SCALE rung through (Unit.jelly_pose owns the
	## damped cosine), the value a row carries is the first squash itself - positive squashes
	## short-and-wide, which is what being struck looks like. It multiplies into the same
	## channel as the idle stretch, so a body that is breathing shape and ringing at once is
	## one picture, not two writers.
	match p_id:
		ID_HIT:
			return {
				"priority": PRIORITY_HIT,
				"lean": -BalanceUI.FX_HIT_LEAN,
				"push": -BalanceUI.ANIM_SHAKE_DIST,
				"jelly": BalanceUI.FX_JELLY_AMP,
				"time": BalanceUI.ANIM_SHAKE_TIME,
			}
		ID_HIT_SHOT:
			## [P5] The 0.6 that used to sit in the call site as `ANIM_SHAKE_DIST * 0.6` is
			## now a named number in BalanceUI: a pea is not a chomp, and a body under fire
			## from three peashooters would twitch instead of flinching at full strength.
			## [B34] The jelly is scaled by the SAME 0.6 - a pellet rings the body less, not
			## differently; a row never carries a second amplitude number of its own.
			return {
				"priority": PRIORITY_HIT_SHOT,
				"lean": -BalanceUI.FX_HIT_LEAN * BalanceUI.FX_PELLET_SCALE,
				"push": -BalanceUI.ANIM_SHAKE_DIST * BalanceUI.FX_PELLET_SCALE,
				"jelly": BalanceUI.FX_JELLY_AMP * BalanceUI.FX_PELLET_SCALE,
				"time": BalanceUI.ANIM_SHAKE_TIME,
			}
		ID_ATTACK:
			## The lunge a zombie bite always had (ANIM_LUNGE_DIST), plus the lean it never
			## had: the body now tips into the blow instead of only sliding towards it.
			return {
				"priority": PRIORITY_ATTACK,
				"lean": BalanceUI.FX_ATTACK_LEAN,
				"push": BalanceUI.ANIM_LUNGE_DIST,
				"time": BalanceUI.ANIM_SHAKE_TIME,
			}
		ID_STUN:
			## [B33] The one row that uses the SWAY channel and no push: a dizzy body wobbles
			## where it stands. The clock is the whole rock (stun_time() below) so the priority
			## is held exactly as long as the body is visibly swaying.
			return {
				"priority": PRIORITY_STUN,
				"sway": BalanceUI.FX_STUN_LEAN,
				"time": stun_time(),
			}
		ID_IDLE:
			## No pose and no clock: the baseline is a STATE (the [B33] stretch, or the old
			## breath on request - idle_spec() below), and taking this effect means "go back to
			## it" (Unit.fx_settle), not "hold this for n seconds".
			return {"priority": PRIORITY_IDLE, "time": 0.0}
		ID_DEATH:
			## Never routed through the body's own animation - see play(). The clock is the
			## WHOLE presentation (fall + settle + fade), so a body that got here through
			## play_fx("death") holds the top priority for exactly as long as it takes.
			return {"priority": PRIORITY_DEATH, "time": death_time()}
	return {}


# ---------------------------------------------------------------- death presentations [B25]
## THE DEFAULT (the user's call, 2026-10-08): 倒地并淡出. A name that is not one of the two
## rows below is a typo, and `death_spec()` answers the default for it - out loud.
const DEATH_TOPPLE := "topple"   # fall BACKWARD about the feet, lie flat, then fade
const DEATH_FADE := "fade"       # fade + shrink where it stands: nothing says "it fell"

static func death_spec(p_id: String) -> Dictionary:
	## THE DEATH TABLE, read by Unit.play_death(). "" means "whatever bodies do by default".
	##
	## `fall` is the angle the body ENDS at, forward-positive like every lean in this file:
	## NEGATIVE = it tips BACKWARD, away from what it was facing - the same way a `hit` flinch
	## goes, because a body falls away from the thing that killed it. The keys are only what
	## play_death() asks for, so a presentation that has no fall simply does not carry one.
	##
	## THE TIMES ARE SEQUENTIAL and their sum is what a viewer waits for: the arena's curtain
	## (BalanceBrawl.BOUT_CURTAIN_SECONDS, [B23]) has to outlast it, so lengthening a fall is
	## not a private decision about one number.
	match p_id:
		DEATH_TOPPLE:
			return {
				"fall": -BalanceUI.DEATH_TOPPLE_ANGLE,
				"fall_time": BalanceUI.DEATH_TOPPLE_TIME,
				"overshoot": BalanceUI.DEATH_TOPPLE_OVERSHOOT,
				"settle_time": BalanceUI.DEATH_TOPPLE_SETTLE_TIME,
				"fade_time": BalanceUI.ANIM_DEATH_TIME,
			}
		DEATH_FADE:
			return {
				"fade_time": BalanceUI.ANIM_DEATH_TIME,
				"shrink": BalanceUI.DEATH_FADE_SHRINK,
			}
	if p_id != "":
		push_warning("[Fx] no such death effect: " + p_id)
	return death_spec(DEATH_TOPPLE)


static func death_time(p_id: String = "") -> float:
	## How long a death presentation occupies the body, every step of it together. The one
	## place that sum is spelled, so the priority clock above and any caller that has to wait
	## for a fall both read the same arithmetic.
	var fx := death_spec(p_id)
	return float(fx.get("fall_time", 0.0)) + float(fx.get("settle_time", 0.0)) \
		+ float(fx["fade_time"])


static func stun_time() -> float:
	## [B33] The whole rock, spelled once: the swinging passes PLUS the pass that settles the
	## body upright, each FX_STUN_SWING_TIME seconds. Unit.sway_pose() divides the SAME clock
	## over the same number of legs, so the priority timer and the tween agree by construction.
	return float(BalanceUI.FX_STUN_SWINGS + 1) * BalanceUI.FX_STUN_SWING_TIME


# ---------------------------------------------------------------- idle presentations [B33]
## THE DEFAULT (the user's call, 2026-10-08): the SECOND idle - the body's picture swings
## between LONG-AND-THIN and SHORT-AND-WIDE about its feet. The old breathing (bob + sway +
## a 3% squash) stays on the table under its own name for a caller that asks for it, through
## Unit.set_idle_fx() - and, exactly like a death presentation, this is the CALLER's pick,
## NOT a per-unit column (docs/prompt/FX.md §9 keeps one table for every body).
const IDLE_BREATH := "breath"     # the pre-B33 baseline: bob + sway + a 3% squash
const IDLE_STRETCH := "stretch"   # [B33] the new default: elongate <-> flatten, rocking
const IDLE_DEFAULT := IDLE_STRETCH

static func has_idle(p_id: String) -> bool:
	## The closed set, so set_idle_fx() can reject a typo ONCE instead of letting idle_spec()
	## warn every frame the baseline ticks.
	return p_id == IDLE_BREATH or p_id == IDLE_STRETCH

static func idle_spec(p_id: String) -> Dictionary:
	## THE IDLE TABLE, read by Unit._tick_idle(). "" means "whatever bodies do by default".
	## `kind` is what the tick branches on; the stretch carries its own numbers, the breath
	## simply keeps reading the IDLE_* constants it always had.
	match p_id:
		IDLE_BREATH:
			return {"kind": IDLE_BREATH}
		IDLE_STRETCH:
			return {
				"kind": IDLE_STRETCH,
				"amp": BalanceUI.IDLE_STRETCH_AMP,
				"speed": BalanceUI.IDLE_STRETCH_SPEED,
			}
	if p_id != "":
		push_warning("[Fx] no such idle effect: " + p_id)
	return idle_spec(IDLE_DEFAULT)


static func play(p_unit, p_id: String) -> bool:
	## THE DOOR (Unit.play_fx). Answers whether this effect was taken: a body already
	## playing something better keeps doing it and this call is a no-op.
	if p_unit == null or not is_instance_valid(p_unit):
		return false
	var fx := spec(p_id)
	if fx.is_empty():
		push_warning("[Fx] no such unit effect: " + p_id)
		return false
	if p_unit.is_dying() and p_id != ID_DEATH:
		## The dead do not flinch. play_death() already makes Unit.shake a no-op; this says
		## the same thing for the whole table, so a caller cannot get a lean out of a corpse.
		return false
	if p_unit.fx_priority() > int(fx["priority"]):
		return false
	if p_id == ID_IDLE:
		return p_unit.fx_settle()
	if p_id == ID_DEATH:
		p_unit.fx_begin(p_id, float(fx["time"]))
		p_unit.play_death()
		return true
	if p_unit.fx_body_plays(p_id):
		## THE FALLBACK RULE (the premise this whole file exists for): a body that HAS a
		## real animation for this event plays it, and the generic pose stands aside. The
		## question is asked of the body, never of a list kept here - see Unit.fx_body_plays.
		## Today no registered view scene carries any of these clips, so this is the branch
		## nothing takes yet, which is exactly what a fallback is for.
		p_unit.fx_begin(p_id, float(fx["time"]))
		return true
	p_unit.fx_begin(p_id, float(fx["time"]))
	if fx.has("lean"):
		p_unit.lean_pose(float(fx["lean"]), float(fx["time"]))
	if fx.has("push"):
		p_unit.push_pose(float(fx["push"]), float(fx["time"]))
	if fx.has("sway"):
		## [B33] The stun's channel: the body owns the hinge (feet) and puts it back itself.
		p_unit.sway_pose(float(fx["sway"]), float(fx["time"]))
	if fx.has("jelly"):
		## [B34] The hit's channel: the value the row carries IS the amplitude of the first
		## squash (a pellet's row scales it by FX_PELLET_SCALE itself), the ring's shape is
		## Unit's own constants. Positive = squash first, which is what being struck means.
		p_unit.jelly_pose(float(fx["jelly"]), float(fx["time"]))
	return true
