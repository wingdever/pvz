class_name BrawlActor
extends RefCounted
## [B1] ONE PIECE, DRIVEN - the half of a brawl unit the turn engine never had.
##
## THE SPLIT (BRAWL.md §12 / D10). The UNIT keeps everything about what a piece IS and what
## it can DO: hit points, armour, the 1/3 execution, statuses, the ultimate, its art, its
## sheet row. This class keeps the five things the real-time world adds, and nothing else:
##   where it stands  - a FLOAT cell position, which is the truth (Unit.position is its ink)
##   which way it faces
##   when it strikes next
##   [B9] how much of a SHOVE it still owes - the one way a body in this mode moves without
##        walking (shove_from below; the rule in prose is BRAWL.md §8.10)
##   [B10] WHO IS DIGESTING IT - a body inside another body rides it and does nothing else
##        (held_by below; the rule in prose is BRAWL.md §8.11)
##   [B14] WHEN A BLOW IS ITS ULTIMATE - the energy itself is the BODY's (Unit.ult_charge, the bar
##        Unit already draws) and the row owns how long the ultimate holds (大招持续); what lives
##        here is the rule that a full bar turns the next blow into that row's own beam, held
##        (BalanceBrawl.ENERGY_* / ULT_TICK_SHARE; the rule in prose is BRAWL.md §8.13)
##   [B38] HOW A LEAP IS SPENT - the second thing a full bar can buy (a row that states 大招范围
##        jumps instead of beams), and the SECOND way this body moves without walking, after the
##        shove (_leap_left below; the rule in prose is BRAWL.md §8.10)
##   [W12a] HOW LONG IT IS DAZED - the stun (眩晕), the THIRD whole-tick takeover after the belly
##        and the shove, with nothing to spend it on (_stun_left below) - and WHAT ITS CLOCK
##        BANKS: since [W12] every energy bar in this mode also grows on its own, at
##        BalanceBrawl.ENERGY_PER_SECOND (_energy_accum below)
##   [W12c] WHAT A FULL BAR BUYS THIRD - the shove-ring (盾墙冲击): the row's 大招击退 spent across
##        its 大招范围 at this body's own feet, pushing and nothing else (_open_shockwave below) -
##        and WHAT A WOUND BUYS: 受击积攒 banks on the VICTIM's own bar, inside land_hit
##
## THE BAN (BRAWL.md §12): a driven unit is NEVER asked to act(). The turn engine's act()
## bodies read the board they were written for (board.damage_brain, board.get_zombies_in_row)
## and there is no such board here. Capabilities are called directly instead - and the
## numbers they deal come from the same doors the turn engine uses (Zombie.bite_value,
## Spawn.shooter_damage), so "how hard does this thing hit" still has exactly one owner.

const Intent := preload("res://scripts/core/brawl/brawl_intent.gd")
const Spawn := preload("res://scripts/core/spawn.gd")
const HeightBody := preload("res://scripts/core/height_body.gd")
## [B22] Preloaded for ONE question - whether this piece's shot flies a SWEPT lane (直线/追踪)
## or an arc that goes over the scrum (抛射). Safe on the cycle: the table preloads only
## UnitCsv and StatusDB, and reads no brawl file (the same door brawl_shot.gd walks through).
const ProjectileDB := preload("res://scripts/core/db/projectile_db.gd")

var unit: Unit = null
var side: int = BalanceBrawl.SIDE_LEFT
## CELL units, float: the one truth about where this piece stands. Unit.col / row are its
## PROJECTION, written by _sync_position() and never registered anywhere - the brawl has no
## grid (R2), and nothing in this mode asks which cell a piece is on except the two hit
## rules that still read columns (see _sync_position).
var pos := Vector2.ZERO
## [B17] THE THIRD COORDINATE (D103). Unit carries the AUTHORED ink version of this struct
## (its sheet row, read once by Unit.read_height); the actor owns the SOLVED version - copied
## from the ink in setup, then integrated and gated here, exactly like `pos` is the solved
## truth against Unit.position's ink projection. Every hit path in this mode asks TWO doors:
## the XY geometry it always used, and height.z_hits (docs/prompt/HEIGHT.md §3).
var height: HeightBody = HeightBody.new()
var facing := Vector2.RIGHT
var target: BrawlActor = null
## [B10] WHO IS DIGESTING ME, or null. Written by the arena's gulp (BrawlGulp.launch / release)
## and by nothing else. It lives HERE rather than being asked of the arena because a body inside
## another body has to FOLLOW it every tick, and that needs a reference rather than a yes/no -
## the same reason `target` is a field. Every loop that must skip such a body asks
## is_swallowed() below, never this field.
var held_by: BrawlActor = null
var attack_timer := 0.0
## [B7] WHAT THIS PIECE WEARS, as the session summed it (BalanceBrawl.KEY_* -> total).
## B5 handed every piece on the player's side the SAME dictionary (the player's augments);
## B7 hands each piece ITS OWN (BrawlSession.mods_for(i)), so two pieces of one side may walk
## into the same bout with different numbers - which is the whole point of D43.
## The readers below are the only places an attachment touches the fight: maximum health once
## at setup, and the rest per strike / per step.
var mods: Dictionary = {}
## [B7+] THE ARENA, UNTYPED ON PURPOSE: `Brawl` has a class_name, but a `var arena: Brawl`
## here would close the cycle Brawl -> BrawlActor -> Brawl (the same reason BrawlMain types
## game.brawl as Node). The arena is where a SHOT is registered, so this is the one call this
## file makes back back into it.
var arena = null

var _field: BrawlField = null
var _drain_accum := 0.0
## [W12a] THE STUN (眩晕): the THIRD way a body in this mode does nothing - after the belly
## (owned by somebody else) and the leap/shove (owned by a movement), this one is owned by a
## daze. A float countdown exactly like theirs (no enum is introduced; the tick branch below is
## the whole state machine), and today one thing schedules it: the devourer whose meal failed.
var _stun_left := 0.0
## [W12a] THE PASSIVE FILL's accumulator (BalanceBrawl.ENERGY_PER_SECOND): seconds pay in
## fractions, whole points bank out, the same drain() shape - so a long frame never pushes the
## cadence back and the bar only ever moves in the integers Unit.charge_ultimate speaks.
var _energy_accum := 0.0
## [P114] THE SELF-HEAL's accumulator, the same drain() shape as the energy bar right above it:
## BalanceBrawl says nothing here - the RATE is this body's own authored cell (unit.regen_per_second,
## read from units.csv `regen`), seconds pay in fractions, whole HP bank out through Unit.heal() and
## the leftover stays on the field, so a long frame never pushes the cadence back. Only a body whose
## row states a nonzero rate ever fills it; everybody else's stays 0.0 and the block no-ops.
var _heal_accum := 0.0
## [P114] THE ROLL's accumulated angle (radians), fed only while this body actually WALKS (see the
## two walk branches). BalanceBrawl.ROLL_RADIANS_PER_CELL converts cells-of-ground into rotation, so
## the wheel turns at a speed tied to the stride, never to the frame. unit.set_roll() is handed the
## running total; the belly/leap/shove/stun branches return before any walk, so a body in those
## states simply stops adding and holds its last angle - which is the "stops rolling when it stops
## walking" behaviour, for free.
var _roll_rad := 0.0
## [B7+] The rage the last tick ran under. A blow used to land on the very tick it was swung,
## so the level could be read off the argument; a SHOT lands later, and `the rage when the shot
## left` is the honest reading - a ball fired before the rage began must not grow angrier in
## mid-air.
var _rage := 0
## [B9] THE SHOVE (击退): which way a blow is throwing this body right now, and how many cells of
## it are left to travel. At rest (dir ZERO / left 0) the body is walking under its own power,
## which is what every body that has not just been hit by a 击退 row is doing. A BUDGET and not a
## timer, because the rule itself is a DISTANCE ("one cell"), and how long that cell takes is
## BalanceBrawl.SHOVE_CELLS_PER_SECOND - the same split the sheet/table pair 射弹 / MELEE_FX_SIZE
## already uses (the row owns the rule, BalanceBrawl owns the pace).
var _shove_dir := Vector2.ZERO
var _shove_left := 0.0
## [B38] THE LEAP (蓄力跳跃): the SECOND way a body in this mode moves without walking, and the
## shape is deliberately the shove's - a countdown the driver walks out, a tick that belongs wholly
## to the movement, and nothing else the body gets to do while it has it (no step, no turn, no
## strike). What differs is that a leap chooses its own ending: the shove's direction comes from
## whoever struck, this one's comes from WHERE THIS BODY AIMED, and it owes the ground an answer
## when it arrives (BrawlActor._finish_leap). Air time is SECONDS because the pace
## (BalanceBrawl.LEAP_CELLS_PER_SECOND) turns the row's distance into time; the wind-up rides on the
## same countdown, so ONE number is the whole state machine and a leap that is interrupted has
## nothing left to unwind.
##
## At rest (_left 0.0) the body is under its own power, which is what every body whose row does not
## state a 大招范围 is doing.
var _leap_left := 0.0
var _leap_air := 0.0
var _leap_from := Vector2.ZERO
var _leap_to := Vector2.ZERO
var _leap_radius := 0.0
var _leap_knock := 0
## [W12b] THE DEVOUR POUNCE (扑吞): the SAME machine as the slam leap, put to the ordinary
## blow's service by the row that states 吞噬. _leap_gulp is 0.0 for every body that does not
## devour and the HOLD SECONDS for the one that does (the sheet's cell, carried through the air
## and handed to the arena at the landing - one number for "is this a pounce" and "how long the
## meal runs", the way _leap_left is one number for the whole slam state). _leap_mark is the
## prey LOCKED AT TAKE-OFF, deliberately not `target`: the driver re-picks its mark every tick
## and a devourer whose meal got eaten by another slime mid-flight must arrive with nothing,
## not swallow the new neighbour on the old promise.
var _leap_gulp := 0.0
var _leap_mark: BrawlActor = null


func is_leaping() -> bool:
	## [B38] AM I MID-JUMP? The one question the arena's other readers would ask if a leap were an
	## arena-owned object (as a channel and a digestion are - is_channelling / is_digesting). It is
	## not: a leap moves ONE body and nothing else, so the body that owns its own position owns the
	## answer, and no list has to be kept in step with it.
	return _leap_left > 0.0


func setup(p_unit: Unit, p_side: int, p_pos: Vector2, p_field: BrawlField,
		p_mods: Dictionary = {}) -> void:
	unit = p_unit
	side = p_side
	pos = p_pos
	mods = p_mods
	## [B5] Maximum health is the one effect that has to land HERE: it changes what the body IS,
	## and every later reader (the hp bar, the rage's percentage bleed, side_hp()) reads max_hp.
	## The full-health reset is deliberate - a bout begins with whole pieces.
	## [B7] MULTIPLY FIRST, THEN ADD (the order TFT uses): a Titan's Blood and an iron sword on
	## the same body pay +50% of the base and +8 flat, in that order, so the flat bonus never
	## rides on a percentage somebody else's row happens to give.
	var hp_mult := self_mult(BalanceBrawl.KEY_HP)
	var hp_bonus := flat(BalanceBrawl.KEY_HP_FLAT)
	var maxed := maxi(1, int(round(float(unit.max_hp) * hp_mult)) + hp_bonus)
	unit.max_hp = maxed
	unit.hp = unit.max_hp
	## [B2] THE DEPLOYED FACE (the user's rule): a piece keeps its OWN natural facing and is
	## TURNED only when it stands in the camp its model was not built for. A plant is drawn
	## looking right and belongs on the left; a zombie is drawn looking left and belongs on
	## the right - so a plant dropped in the right half is a mirrored body, not merely a
	## re-aimed one. Both arms end up looking at the enemy either way; what this says is WHY.
	facing = natural_facing() * (-1.0 if is_turned() else 1.0)
	## [B16] ...AND THE PICTURE IS TURNED TOO, which is the half [B2] could only promise:
	## `mirrored` flips the body's art so that a piece drawn facing the wrong way for its camp
	## (雷角兽 on the player's half, an eye monster on the enemy's) looks at the enemy like
	## everybody else. The body owns the drawing (Unit._draw_body / _apply_mirror); all this
	## line does is tell it which camp it woke up in.
	unit.mirrored = is_turned()
	_field = p_field
	## [B17] THE HEIGHT INK COPIED INTO THE SOLVER (dev doc §4-11): what the sheet authored -
	## start height, the tall-ness of the hit interval, the footprint - comes off the body's
	## own struct; what it does from here is the actor's. z_velocity is deliberately NOT copied
	## (a bout starts at rest on the axis), and z_gravity is not a sheet column at all - the
	## falling pace is the brawl's rule, so BalanceBrawl answers it here.
	height.z_height = unit.height.z_height
	height.z_thickness = unit.height.z_thickness
	height.body_width = unit.height.body_width
	height.body_depth = unit.height.body_depth
	height.body_xoff = unit.height.body_xoff
	height.body_yoff = unit.height.body_yoff
	height.z_gravity = BalanceBrawl.Z_GRAVITY_CELLS
	## A piece does not strike on the frame it appears: it must close the distance first,
	## which is what makes the approach readable.
	attack_timer = strike_interval(0)
	_sync_position()


func natural_facing() -> Vector2:
	## Which way this unit is MODELLED, before any deployment: a plant looks right (the way
	## the zombies come from), a zombie looks left (the way it walks). A fact about the unit,
	## never about the camp - which is exactly what lets the formation page put a plant on the
	## right and get a body that had to turn around.
	##
	## [B14/B16] ASKED OF THE BODY, never guessed from is_zombie: a monster may be drawn either
	## way (雷角兽 looks left like a zombie, 激光眼 looks right like a plant), and since [B16]
	## the answer is a units.csv column like every other unit fact (Unit.faces_left, filled from
	## UnitSheet.face_left at spawn).
	return Vector2.LEFT if unit.drawn_left() else Vector2.RIGHT


func is_turned() -> bool:
	## True when this piece stands in the far camp and therefore faces the OTHER way than it
	## was drawn. The fixture picks its sides so that nothing is turned; the formation page
	## (B2) is where a turned piece becomes normal.
	##
	## [B14] Same door as natural_facing above, and the two must agree: it has to be the DRAWN
	## orientation that answers, never is_zombie. Neither of them decides which way the body
	## FIGHTS - a piece turns to its target every tick, so `facing` always ends up pointing at
	## the enemy whichever way the art looks. [B16] What reads this now is setup(), which hands
	## it to the body as `Unit.mirrored`: the picture is flipped, so the two agree.
	return turned_in(unit.drawn_left(), side)


static func turned_in(p_drawn_left: bool, p_side: int) -> bool:
	## [B16b] THE SAME RULE WITH NO BODY IN SIGHT: would a piece drawn this way, standing in
	## THIS camp, be turned? is_turned() above is this line with the body's own answer filled
	## in (`unit.drawn_left()`), and a PAGE that previews a line-up asks this one directly -
	## it has an id and a half, not a body (BrawlFormation draws the player's bench, the
	## player's half and the enemy preview, and all three must agree with the arena).
	##
	## ONE OWNER, TWO CALLERS: the two ways of asking are here, side by side, so the preview
	## cannot grow a second opinion about which way a piece looks (the alternative - the page
	## re-deriving it from `side == RIGHT != faces_left` - is exactly the drift this avoids).
	return (p_side == BalanceBrawl.SIDE_RIGHT) != p_drawn_left


func is_alive() -> bool:
	## is_instance_valid matters: play_death() queue_frees the body a moment after it falls,
	## and the actor OUTLIVES it (the session keeps the actors for the count and the log).
	return unit != null and is_instance_valid(unit) and unit.is_alive()


func tick(p_dt: float, p_pool: Array, p_rage: int) -> void:
	if not is_alive():
		return
	_rage = p_rage
	## [B31] WHICH SEARCH THIS BODY RUNS, asked of the ROW before anything else: a piece whose
	## shot's 治疗 cell says YES wants a PATIENT, not prey. One read per tick, reused twice below
	## (the aim, and the gunner's step it must NOT take), and it is the only reason a mend ever
	## crosses this function - every other line is the same for both kinds of blow.
	var mend := _hunts_allies()
	## [B10] A target that has been swallowed by somebody else is not on the board any more: it
	## cannot be reached, so it must not be walked at either. Re-picking here is what makes a
	## devourer's meal also take the OTHER side's attention off it (the pool skips it: Intent).
	## [B31] ...and a HEALER re-picks on one further condition: a patient that is now WHOLE is no
	## longer a patient. Without that clause a 暖阳葵 would stand next to the ally it just mended
	## and fire into it for 0 points until somebody else got hurt, because the enemy search above
	## only ever drops a target that DIES - and dying is not the only way a mark stops mattering.
	if target == null or not target.is_alive() or target.is_swallowed() \
			or (mend and target.unit != null and target.unit.hp >= target.unit.max_hp):
		target = Intent.lowest_hp_ally(self, p_pool) if mend \
			else Intent.nearest_enemy(self, p_pool)
	attack_timer = maxf(0.0, attack_timer - p_dt)
	## [W12a] THE DAZE DECAYS UNDER EVERY BRANCH, exactly like the strike timer above it: a
	## shove can carry a stunned body across the arena and a belly can hold one, and in neither
	## case may the daze freeze - it runs out on wall-clock seconds or it never does.
	_stun_left = maxf(0.0, _stun_left - p_dt)
	## [W12a] THE PASSIVE FILL: every body NOT inside somebody else's belly banks
	## BalanceBrawl.ENERGY_PER_SECOND - walking, striking, leaping, shoved and stunned alike;
	## a prey being digested is the one exemption, because the belly branch's rule is "rides
	## its holder and does nothing else" and a swallowed body visibly refilling its bar reads
	## wrong. Who HAS a bar is the shared answer _has_gauge() below (thundercorn, snorlax, and
	## since [W12c] the shieldman), so a row that states no ultimate never silently fills one.
	if held_by == null:
		_energy_accum += BalanceBrawl.ENERGY_PER_SECOND * p_dt
		var banked := int(_energy_accum)
		if banked > 0:
			_energy_accum -= float(banked)
			charge_passive_energy(banked)
	## [P114] THE SELF-HEAL: same "not in a belly" door as the passive fill above it - a prey being
	## digested does not visibly knit itself back together either. The RATE is this body's own cell
	## (unit.regen_per_second), so a row that states none never enters this block at all, and the
	## points land through Unit.heal() (its one owner: caps at max_hp, no-ops on a dead body), never
	## through the round-based defence formula. The user's ruling: while alive it always regens - no
	## out-of-combat pause.
	if unit.regen_per_second > 0 and held_by == null:
		_heal_accum += float(unit.regen_per_second) * p_dt
		var healed := int(_heal_accum)
		if healed > 0:
			_heal_accum -= float(healed)
			unit.heal(healed)
	if held_by != null:
		## [B10] INSIDE A BELLY: no walking, no turning towards anybody, no striking. The only thing
		## this body does is ride where its holder goes - and the holder is a body that is still
		## moving, so "a lump travelling inside a slime" comes from HERE, not from the gulp.
		## The strike timer above keeps running: six seconds in a belly is six seconds of the bout,
		## and a piece that comes back out is not handed a fresh cooldown for it.
		pos = held_by.pos
		_sync_position()
		return
	if is_leaping():
		## [B38] BEING IN MID-LEAP TAKES THE WHOLE TICK, for the two reasons the shove above gives:
		## a body that is over the scrum is not also walking at it, and the jump IS its action. The
		## strike timer keeps running (a leap costs no cooldown it had not already paid), and this
		## branch sits BEFORE the shove's on purpose - a body struck while airborne does not stop
		## mid-jump; the slide is armed, and it is spent after the landing, because the leap decided
		## where this body belongs and one blow cannot unsay that. It also sits before
		## height.integrate() for the same reason the belly and the shove do: during a flight the
		## leap writes the axis itself, and a second writer would fight it every tick.
		_advance_leap(p_dt, p_pool)
		_sync_position()
		return
	if _shove_left > 0.0:
		## [B9] BEING SHOVED TAKES THE WHOLE TICK. A body that is flying backwards is not also
		## walking and not also swinging: it gets no step, no turn towards its target and no
		## strike. The strike timer above keeps running while it slides, so a shove costs the
		## victim the ground and the beat - never a cooldown it had already paid for.
		_advance_shove(p_dt)
		_sync_position()
		return
	if _stun_left > 0.0:
		## [W12a] BEING DAZED TAKES THE WHOLE TICK: no step, no turn, no strike, no leap, no
		## ultimate - the branch returns and the body keeps only what it always keeps (its
		## target, its belly, its ticking timers). The branch sits BELOW the shove's on purpose:
		## a shove is a distance somebody ELSE paid, and a dazed body caught in the shieldman's
		## shockwave must still physically slide, or the ult's budget would strand; a daze is
		## this body's own lost time, so it yields to every imposed movement and to the belly.
		_keep_stun_sway()
		_sync_position()
		return
	## [B17] The axis moves even when nothing else does (dev doc §4-12): gravity, the clamp at
	## the ground, the velocity a landing clears - all of it is height_body.integrate. Today
	## every authored z is 0 with no velocity, so this runs as arithmetic on zeros and the bout
	## stays frame-identical; Phase 2's dives and hops ride on this one line. A body in a belly
	## or mid-shove is NOT integrated - the first rides its holder, the second owes the whole
	## tick to the slide.
	height.integrate(p_dt)
	if target == null:
		## [W-fix] AN IDLE HEALER WALKS AT ITS ARMY, IN BOTH MODES: no patient means NOBODY IS
		## HURT, not that there is nothing to do - the user's ruling after the first war bout,
		## widened to a GLOBAL rule on the follow-up ("乱斗同样适用"), which retires [B31]'s
		## hold-in-place everywhere. The body walks at its nearest FIGHTING ally
		## (Intent.nearest_fighter_ally) until that ally sits inside attack_reach(), the very
		## door the strike below checks, so "kept in range" here and "a mend would already land"
		## are one number off one table row. The step is the walk's own idiom - heading blended
		## with separation, clamped to the arena. A huddle of healers has no fighter in it and
		## the whole side simply holds, which is what [B31] left standing.
		if mend:
			var anchor = Intent.nearest_fighter_ally(self, p_pool)
			if anchor != null:
				var to_anchor: Vector2 = anchor.pos - pos
				var gap := to_anchor.length()
				if gap > attack_reach():
					var heading := to_anchor.normalized() if gap > 0.001 else facing
					var step := (heading + Intent.separation(self, p_pool)).normalized()
					facing = step
					pos = _field.clamp_to_arena(pos + step * move_speed() * p_dt)
					_advance_roll(step, p_dt)
		_sync_position()
		return
	var to_target: Vector2 = target.pos - pos
	var distance := to_target.length()
	if distance > attack_reach():
		## [B38] A LEAP DOES NOT WAIT TO BE WITHIN SWINGING RANGE - that is what makes it a jump
		## rather than a bigger swing. A full bar and a mark inside BalanceBrawl.LEAP_MAX_CELLS is
		## the whole condition, so 卡比兽 crosses the ground the ordinary blow cannot reach and lands
		## INSIDE the line it was walking at. The strike path calls the same function (one body, one
		## ultimate: _begin_strike -> _open_ultimate -> _open_leap), and calling it from here costs
		## nothing when the row states no radius - ult_radius() is the sheet's blank and the answer
		## is false on the first line.
		## [W12c] ...and one guard more, for the row that states BOTH 大招范围 and 大招击退: the
		## 盾卫's ring radius is the size of its WALL, not of a jump - a pusher out of reach walks
		## up like everything else and spends the bar on a strike, never mid-approach through the
		## air. The dispatch inside _open_ultimate asks push FIRST; this walk-up gate had no push
		## branch to keep the order honest, so it defers to the same cell the ring lives on.
		if ult_ready() and ult_radius() > 0.0 and ult_knockback_cells() <= 0 and _open_leap():
			## [P112] An ultimate that just FIRED shouts, and this walk-up gate is the LEAP's SECOND
			## door: a leaper that is still OUT of swinging range opens its jump from the approach
			## HERE, not through _begin_strike -> _open_ultimate. Without it the 卡比兽's leap would
			## land in silence every time it closes the gap by jumping mid-walk instead of from a
			## swing - and the rule is 大招必喊, whichever door spends the bar. ult_ready() already
			## vouches the body is alive (see its guard), so the shout is as safe as the strike path's.
			unit.shout(unit.ult_shout_text(), true)
			_sync_position()
			return
		var heading := to_target.normalized() if distance > 0.001 else facing
		var step := (heading + Intent.separation(self, p_pool)).normalized()
		facing = step
		pos = _field.clamp_to_arena(pos + step * move_speed() * p_dt)
		_advance_roll(step, p_dt)
	else:
		if distance > 0.001:
			facing = to_target / distance
		## [B22] THE GUNNER'S STEP - never shoot through one of your own. In range and about
		## to loose a swept shot? First ask whether the lane to the target crosses a friendly
		## body (Intent.shot_lane_blocker, measured with the exact radii and height door the
		## flight itself pays). If it does, spend this tick SIDEWAYS instead of firing: the
		## perpendicular is the fastest gradient off the line, so sidesteping is the honest
		## approximation of "walk to the nearest position from which the shot hits the enemy
		## and nobody else" - a full search over the arena would need a state this RefCounted
		## body deliberately does not carry. facing stays ON the target (set above), so the
		## muzzle keeps tracking the mark while the feet slide; attack_timer sits at 0 and the
		## first clear tick fires. Two accepted edges: a shooter CORNERED against the arena
		## clamp holds fire indefinitely (a whiffing gun is worse than a silent one), and the
		## check is made at the moment of firing - an ally who strolls into the flight after
		## the trigger is still a victim, exactly as [B21] decided.
		## [B31] A HEALER TAKES NONE OF THIS STEP. Not because its lane cannot be blocked - a
		## 暖阳葵 standing in a scrum always has an ally in front of it - but because a friendly in
		## the road of a MEND is not a problem: the row says the flight passes through everybody
		## who is not its patient (BrawlShot._stops_for), so sidestepping would move the body for
		## nothing and delay help nobody asked the shot to dodge. `mend` is tested FIRST because
		## it is already in hand, while _fires_swept_shot() has to ask the row again.
		var blocker = null
		if SettingsStore.friendly_fire and not mend and _fires_swept_shot():
			blocker = Intent.shot_lane_blocker(self, p_pool)
		if blocker != null:
			var perp := Vector2(-facing.y, facing.x)
			## Step to the side the blocker is NOT on. Dead centre on the line (away == 0)
			## still counts as blocked, and the tie is broken by CAMP rather than by whichever
			## actor happened to be ticked first - the determinism rule of the intent library,
			## kept here because the same bout must replay the same way.
			var away: float = (blocker.pos - pos).dot(perp)
			var strafe := -signf(away) if absf(away) > 0.001 \
				else (1.0 if side == BalanceBrawl.SIDE_LEFT else -1.0)
			var step := (perp * strafe + Intent.separation(self, p_pool)).normalized()
			pos = _field.clamp_to_arena(pos + step * move_speed() * p_dt)
			_advance_roll(step, p_dt)
		elif attack_timer <= 0.0 and can_strike():
			_begin_strike(p_pool)
	_sync_position()


func _advance_roll(p_step: Vector2, p_dt: float) -> void:
	## [P114] THE ROLL, one call under every walk branch: a body whose sheet row says it ROLLS turns
	## in proportion to the ground it just covered this tick - cells moved (move_speed()*p_dt) times
	## BalanceBrawl.ROLL_RADIANS_PER_CELL, signed by the step's HORIZONTAL component so a body rolling
	## right spins one way and one rolling left spins the other (a purely vertical step has no x-sign
	## and so adds no turn - the honest read of "a wheel on the ground"). The step, not `facing`, is
	## what decides the sign: a gunner sidestepping keeps facing its mark while its feet slide
	## sideways, and it is the feet that would turn the wheel.
	## The guard is the whole cost for a non-roller: unit.rolls is false for every other piece, so
	## this returns on the first line and their walk stays byte-for-byte the old walk. It is called
	## ONLY from the walk branches, which all sit BELOW the belly/leap/shove/stun returns - so a body
	## in one of those imposed states never reaches here and holds its last angle instead of spinning.
	if not unit.rolls:
		return
	_roll_rad += BalanceBrawl.ROLL_RADIANS_PER_CELL * (move_speed() * p_dt) \
		* signf(p_step.x)
	unit.set_roll(_roll_rad)


func drain(p_fraction: float) -> void:
	## The rage's bleed, handed in as a FRACTION OF MAXIMUM HEALTH so every piece loses the
	## same share of itself. Whole points only - take_damage() speaks integers, and a piece
	## on its last hit point must fall on the tick it was meant to, not the one after.
	if not is_alive():
		return
	_drain_accum += p_fraction * float(unit.max_hp)
	var whole := int(_drain_accum)
	if whole <= 0:
		return
	_drain_accum -= float(whole)
	unit.take_damage(whole)


# ---------------------------------------------------------------- what this piece is worth
func strike_interval(p_rage: int) -> float:
	## Seconds between two attacks. Two ways to know it, and the piece itself picks which:
	##   [B5] a HUMAN PIECE states its own attack间隔 in seconds (PieceDB) - it is the row's
	##        rhythm and no turn-engine number means anything to it;
	##   a plant converts the turn engine's AP price for one attack at the brawl's AP rate
	##        (a peashooter, 技能消耗AP = 1, fires every 0.83 s at rest - exactly the three
	##        shots a round its sheet already pays for); a zombie uses DEFAULT_ATTACK_AP.
	## The rage and the player's haste then divide the interval: both are SPEED multipliers.
	var base := 0.0
	if unit.has_method("brawl_strike_seconds"):
		base = maxf(0.05, float(unit.call("brawl_strike_seconds")))
	else:
		var ap := BalanceBrawl.DEFAULT_ATTACK_AP
		if not unit.is_zombie:
			ap = maxf(0.1, float(unit.threshold))
		base = ap / BalanceBrawl.ap_rate()
	return base / ((1.0 + float(p_rage) * BalanceBrawl.RAGE_ATTACK_SPEED_PER_LEVEL)
		* self_mult(BalanceBrawl.KEY_HASTE))


func damage_per_attack() -> int:
	## The two doors the turn engine already uses, so a piece's damage keeps one owner: a
	## zombie's bite is BITE_DAMAGE_RATIO of its 啃食 (the number it does three times a round
	## over there), a plant's is its own skill value.
	## [B7] ...plus the flat attack a worn row may add (an iron sword's +8). It is added AFTER the
	## piece's own number and BEFORE every multiplier in blow_value(), so a flat bonus is worth
	## same on a cheap piece as on an expensive one - which is what makes it equipment and not a
	## second kind of augment.
	var bonus := flat(BalanceBrawl.KEY_ATTACK_FLAT)
	if unit.is_zombie:
		var zombie := unit as Zombie
		return (zombie.bite_value() if zombie != null else 0) + bonus
	return Spawn.shooter_damage(unit) + bonus


func can_strike() -> bool:
	## WHETHER THIS PIECE ATTACKS AT ALL, which is not the same question as "is it in range".
	## A plant whose 技能消耗AP is 0 NEVER acts - the wall-nut rule the turn engine's
	## Unit.can_act() enforces - so in the arena it never strikes either: it walks in and tanks,
	## and its attack column (a real 0 in the sheet) is not a damage number. Without this gate the
	## fall-back below would hand a wall-nut a 1-damage hit twelve times a second, which is more
	## DPS than the peashooter it is supposed to be shielding.
	if arena != null and arena.is_channelling(self):
		## [P110g] A piece that is CHANNELLING is busy by definition. The ARENA knows - it owns the
		## beams - so the question is asked there rather than mirrored into a flag on this body,
		## which keeps "how long a channel runs" a fact with exactly one owner. Without this, 狂暴
		## (which shortens attack间隔) could bring the timer up mid-channel and open a second beam.
		return false
	if arena != null and arena.is_digesting(self):
		## [B10] ...and a devourer whose mouth is full is busy for exactly the reason the eye above
		## is: it holds ONE body at a time. Asked of the ARENA, which owns the gulps, rather than
		## mirrored into a flag on this body - the same division is_channelling makes.
		return false
	if unit.is_zombie:
		return true
	return unit.threshold > 0


func move_speed() -> float:
	## [B5] A human piece walks at its own 移速; everything else at the arena's pace. The
	## augment's speed works on both, because it multiplies whatever the answer was.
	## [W7b] ...and the GROUND gets a word too: a board may double the feet of the bodies
	## that fight what they can touch (the war's melee ruling). A shooter asks the same door
	## and hears 1.0 - the speed bend is a MELEE-only one, and the brawl never hears it at
	## all (BrawlField's default on both doors keeps [B5]'s arithmetic to the bit).
	var base := BalanceBrawl.MOVE_CELLS_PER_SECOND
	if unit.has_method("brawl_move_speed"):
		base = maxf(0.05, float(unit.call("brawl_move_speed")))
	var mult := self_mult(BalanceBrawl.KEY_SPEED)
	if not is_ranged():
		mult *= _field.melee_speed_mult()
	return base * mult


func is_ranged() -> bool:
	## [W7b] WHO I AM, decided by WHAT I FIRE - shot_id() is the very door the strike walks,
	## so "ranged" here and "launches a projectile" in the attack branch cannot disagree.
	## Reach LENGTH is deliberately NOT the classifier: the 刀剑客 states 1.1 cells and
	## swings (melee), and a reach-threshold split would hand it the shooter's bend.
	return shot_id() != ""


func attack_reach() -> float:
	## [B5] How far this piece strikes, in cells: a human states it (0.75 melee / 3.0 ranged
	## are just what a sheet that says nothing gets), a zombie fights what it can touch and a
	## plant shoots down the arena.
	## [W7b] A shooter's answer then goes through the ground's door, so the war's doubling
	## lands on EVERY reader of this one number at once - the strike, the pursuit stop, the
	## idle healer's stand-off, the page's preview ring - without a second copy anywhere.
	var base: float
	if unit.has_method("brawl_attack_reach"):
		base = maxf(0.1, float(unit.call("brawl_attack_reach")))
	elif unit.is_zombie:
		base = BalanceBrawl.MELEE_REACH_CELLS
	else:
		base = BalanceBrawl.RANGED_REACH_CELLS
	if is_ranged():
		base *= _field.ranged_reach_mult()
	return base


func hp_total() -> int:
	return unit.hp if is_alive() else 0


# ---------------------------------------------------------------- what a piece wears [B5/B7]
func self_mult(p_key: String) -> float:
	## One MULTIPLIER key as a multiplier. The sheet writes a DELTA (+0.15 = "15% more"), so the
	## multiplier is 1 + delta and a piece wearing nothing answers exactly 1.0 - which is what
	## makes "nothing attached" and "attachments that happen to add up to zero" the same fight.
	return 1.0 + float(mods.get(p_key, 0.0))


func flat(p_key: String) -> int:
	## [B7] One FLAT key as a whole number ("+120 hit points"). Whole points only: every health
	## number in this project is an int, and a half hit point would be a number nobody can see.
	## The sheet's two flat keys are hp_flat and attack_flat (BalanceBrawl.EFFECT_KEYS), and a
	## key spelled here that nothing writes simply answers 0.
	return int(round(float(mods.get(p_key, 0.0))))


func taken_mult() -> float:
	## What MY rows do to the damage I TAKE (1.0 = untouched), asked by whoever strikes
	## me. Floored so a stack of 厚皮 can never turn a body into an immortal one: a real-time
	## bout has to end (BRAWL.md §3.2), and a zero here would be the one way a piece could
	## outlive both the rage and its enemy.
	return maxf(BalanceBrawl.TAKEN_FLOOR,
		1.0 + float(mods.get(BalanceBrawl.KEY_TAKEN, 0.0)))


# ---------------------------------------------------------------- the strike
func _begin_strike(p_pool: Array) -> void:
	## WHAT HAPPENS WHEN THE TIMER COMES UP. [B14] There are two answers now, and the first one
	## is asked before the shapes below: IS THIS BLOW THE ULTIMATE? A body whose energy bar is
	## full (and whose row says how long its ultimate holds) spends the whole bar here, and what
	## that buys is the SAME 远程特效 beam HELD for those seconds - not a fifth shape and not a
	## second damage table: the opening blow lands through land_hit like every other, and the
	## ticks that follow are the arena's channel (BrawlBeam), at BalanceBrawl.ULT_TICK_SHARE.
	##
	## Everything else is the ordinary blow, and it BANKS ENERGY on the way out (charge_energy
	## below): one attack, one deposit - a four-barrel volley does not bank four times (the rule
	## the turn engine's charge already lives by, shooter_plant.gd). A piece with no ultimate
	## banks nothing, because Unit.charge_ultimate refuses a body that has none.
	##
	## [W12c] The POOL comes along for the ride: the ultimate is asked first, and one of its three
	## kinds (the shove-ring) enumerates the bodies around this one - the same pool the tick is
	## already holding, handed down rather than re-looked-up, which is how the leap and the beam
	## have always avoided owning a second view of the arena.
	attack_timer = strike_interval(_rage)
	if target == null or target.unit == null:
		return
	## [P110] A named effect now, and in a brawl it is a LEAN and nothing more: the knock-back
	## channel refuses a body with no grid, so the old `unit.shake(facing, ANIM_LUNGE_DIST)`
	## line was silently doing nothing here. The lean itself needs no grid - a rotation is not
	## ink - and it follows `facing`, so a TURNED piece leans the way it is looking.
	unit.play_fx("attack")
	if ult_ready() and _open_ultimate(p_pool):
		## [P112] A FIRED ULTIMATE SHOUTS - the one guaranteed cry of the mode, whatever shape the
		## full bar took (a held beam, a leap, a shove-ring). Only reached when _open_ultimate said
		## yes, so a refused opening (empty wall, no shared height) stays silent rather than crying
		## a big move it did not make. The name is the row's new 大招 cell; an unfilled cell shouts
		## nothing (Unit.shout refuses an empty text).
		unit.shout(unit.ult_shout_text(), true)
		return
	_strike_once()
	charge_energy()


func _strike_once() -> void:
	## THE ORDINARY BLOW - and there are FIVE shapes of it, all of them asked of the BODY (never
	## of its type, never of a list here):
	##   射弹     a projectile that FLIES: the blow is handed to a BrawlShot and lands later;
	##   旋风     a WHIRLWIND that WALKS, summoned IN FRONT of this body: the blow is handed to a
	##            BrawlTornado and pays itself out in pulses along the line the row's 旋风 cell measures;
	##   远程特效 a BEAM that does not fly: the blow lands HERE and the beam is drawn here;
	##   吞噬     a POUNCE onto the prey and a SWALLOW on the landing ([W12b]): no damage at all
	##            from the contact - the enemy goes INSIDE and is digested there (BrawlGulp);
	##   剩下     a swing: the blow lands here and the melee picture is drawn here.
	## Three of the five land through the SAME door (land_hit below), so a shot is a DELAY and a
	## beam is a cadence, never a second damage table (BRAWL.md §12); the swallow and the whirlwind
	## are the two shapes whose damage is dealt by something else entirely (the gulp that holds the
	## prey, the funnel that walks over it).
	## Split out of _begin_strike when [B14] put the ultimate in front of it, and it returns at
	## every shape it picks - which is why the energy deposit is a line in the CALLER and not
	## something this function has to remember to do on each of its exits.
	var shot := shot_id()
	if shot != "" and arena == null:
		## A shot with no arena to fly in (a fixture) is a swing, exactly as it was before - the
		## fall-through below is what handles it.
		shot = ""
	if shot != "":
		arena.spawn_shot(self, target, shot, blow_value())
		return
	## [B39] THE FIFTH SHAPE, and it sits HERE rather than below the height gate for the shot's own
	## reason: the funnel carries its own column of air and answers the height question itself, every
	## pulse, against every body it passes. This blow is not landed on `target` at all - the row's
	## 旋风 cell REPLACES the contact the way 吞噬 does, so a bird that stopped in front of a body still
	## spends its strike on SUMMONING the storm. [B41] makes that said out loud rather than implied: the
	## arena is handed no target, because the funnel walks the bird's OWN front (its facing) and not a
	## line drawn to whatever it happened to be fighting.
	## A whirlwind with no arena to walk in (a fixture) falls through to the swing below, exactly
	## like a shot does.
	var cells := tornado_cells()
	if cells > 0.0 and arena != null:
		arena.spawn_tornado(self, cells, blow_value())
		## [P112] A WHIRLWIND IS A SPECIAL, NOT AN ORDINARY BLOW: the row's 旋风 cell replaces the
		## contact, so this strike spends itself summoning a storm - the bird cries its 技能 name as
		## it does (a plain shot or swing, which this shape took the place of, never shouts).
		unit.shout(unit.skill_shout_text())
		return
	## [B17] THE SECOND DOOR, FOR THE THREE INSTANT SHAPES (dev doc §4-14): gulp, beam and
	## swing all land on the body standing HERE and NOW, and if their height intervals share
	## nothing the blow met air - even where the XY reach always said it was in range. The
	## caller has already played the wind-up pose and still banks the energy, and no spark or
	## beam is drawn: the futility of swinging at the sky is itself the feedback, and O44 is
	## O44 whether the missed thing flew or did not. The shot shape above does NOT pass this
	## gate - it carries its own height and lets BrawlShot's sweep answer.
	if not height.z_hits(target.height):
		return
	## [B10] THE FOURTH SHAPE: 吞噬. A row whose 吞噬 cell holds a number does not damage what it
	## touches at all - it takes the enemy INSIDE and pays the damage out while it digests
	## (BrawlGulp). That is why this branch stands BEFORE land_hit rather than beside it: a
	## devourer has no contact damage to land. The order among the shapes is the order the arena asks
	## them in (the two MOVING ones - 射弹 and [B39] 旋风 - above the height gate, then 吞噬 /
	## 远程特效 / 近战 below it), so a row that named two of them gets the first one - the same rule
	## the shot and the beam already live by.
	##
	## A swallow with no arena to hold the prey (a fixture) falls through to the swing below,
	## exactly like a shot with no arena does.
	## A REFUSED swallow (the prey was eaten by somebody else on this very frame, or this body is
	## already digesting) falls through to the swing: a devourer that cannot eat still hits, which
	## is better than a blow that silently does nothing.
	## [W12b] THE SWALLOW NOW WEARS THE POUNCE: the user's rule is that the slime LEAPS ONTO its
	## prey to devour it, so this shape opens the leap machine pointed AT the mark and the meal
	## itself is handed to the arena at the LANDING (_finish_leap's first branch), not here. The
	## height gate above already passed - the pounce replaces the contact this frame would have
	## made - and the strike cost is already paid (attack_timer was reset in _begin_strike). A
	## pounce that cannot open (the mark died this frame, no field) falls through to the swing
	## below, the same refusal road the swallow always had.
	var gulp := gulp_seconds()
	if gulp > 0.0 and _open_pounce(target, gulp):
		## [P112] THE DEVOUR IS THE OTHER SPECIAL that replaces the blow - so the slime cries its
		## 技能 name as it leaps onto the prey. Shouted at the OPEN (the launch), matching how the
		## whirlwind shouts at its summon; a refused pounce (the mark died this frame) falls through
		## to the swing below and stays silent, exactly like a refused ultimate.
		unit.shout(unit.skill_shout_text())
		return
	## The two remaining shapes land the blow on THIS frame, and the victim's position is read
	## BEFORE it: the blow may kill it, and play_death() queue_frees the body a moment later.
	var at := target.unit.position
	var beam := ranged_fx_id()
	var burn := brawl_beam_seconds()
	land_hit(target, blow_value())
	if beam != "":
		if burn > 0.0 and arena != null:
			## A CHANNEL (连续冲击光束): the blow just landed is its FIRST tick, and the arena takes
			## over from here - it owns the node that keeps burning, follows both bodies and ends
			## when the channel is over or either body falls (brawl_beam.gd). The cadence needs no
			## number here: attack间隔 is the whole CYCLE (burn + gap), so 4.0 with a 3 second channel
			## IS the one second of 间歇.
			arena.open_beam(self, target, beam, burn)
			return
		## ...or a FLASH (瞬发光束 / 喷射火焰 / 雷角电击): one hit, one picture between the two
		## bodies, no flight and nothing to track. Hitscan: nothing crossed the board, so the line
		## is drawn from THIS body to where the target stood - and from the point the look says it
		## leaves (muzzle below: the eye's centre, or the thundercorn's horn).
		Fx.spawn_beam(beam, muzzle(beam), at)
		return
	## A swing. Two layers, in the order they read: the spark is the generic "something landed
	## here" and EVERY melee gets it; the named picture is the attacker's own (Unit.melee_fx_id ->
	## humans.csv / zombies.csv 近战特效 - a militia's slash, a knight's heavy slash, a captain's
	## divine arc, a zombie's claw) and a piece whose cell is blank keeps the spark alone.
	Fx.spawn_spark(at, BalanceUI.COLOR_HP_FILL)
	Fx.spawn_melee_fx(melee_fx_id(), at, facing)


# ---------------------------------------------------------------- the energy and the ultimate [B14]
func _has_gauge() -> bool:
	## [W12a] WHO OWNS AN ENERGY BAR, in the ONE answer every fill now shares: a row that
	## states a held beam (大招持续), [B38] a slam leap (大招范围), or [W12c] a push ult
	## (大招击退). This was the inline test inside charge_energy; the passive fill and the
	## per-hit fill joined it, because three doors reading the same two cells three ways is
	## exactly how a bar that nothing ever fires sneaks onto a body.
	return ult_seconds() > 0.0 or ult_radius() > 0.0 or ult_knockback_cells() > 0


func charge_energy() -> void:
	## ONE ORDINARY BLOW, ONE DEPOSIT. Called the moment a piece has made its attack - whatever
	## shape it took - and NOT by the ticks of a channel (those are the same attack paying out,
	## not new ones). Unit.charge_ultimate is the ONE entry point of the bar and it caps at the
	## top, so a piece whose bar is full and whose ultimate is refused banks nothing extra.
	##
	## ONLY A BODY THAT COULD SPEND IT BANKS IT: the test moved to _has_gauge() [W12a] for the
	## reason written there - 雷角兽 and 卡比兽 today and nothing else, because without this line
	## a plant or a zombie fielded in this mode could quietly fill a turn-engine ultimate bar
	## that nothing here would ever fire.
	if unit == null or not is_instance_valid(unit) or not _has_gauge():
		return
	unit.charge_ultimate(BalanceBrawl.ENERGY_PER_STRIKE)


func charge_passive_energy(p_amount: int) -> void:
	## [W12a] THE CLOCK'S DEPOSIT (+BalanceBrawl.ENERGY_PER_SECOND per second, tick()), paid
	## through the SAME bar door and the SAME gauge test as a blow's - the passive fill is a
	## different PAYER, not a different system. p_amount is whole points by construction (the
	## accumulator only hands out integers).
	if unit == null or not is_instance_valid(unit) or not _has_gauge():
		return
	unit.charge_ultimate(p_amount)


func charge_hit_energy() -> void:
	## [W12c] THE HIT'S DEPOSIT, asked of the VICTIM by land_hit: the row's own 受击积攒 paid
	## through the SAME bar door and the SAME gauge test as the blow's and the clock's - three
	## payers, one bar. A row with a blank cell has per_hit_energy() answer 0 and this returns on
	## the second line, so the cost of NOT being the shieldman is one integer read.
	if unit == null or not is_instance_valid(unit) or not _has_gauge():
		return
	var amount := per_hit_energy()
	if amount > 0:
		unit.charge_ultimate(amount)


func ult_ready() -> bool:
	## [B14] IS THE BAR FULL? Asked of the BODY, which owns both halves of the answer: whether
	## this piece has an ultimate at all (its row's 大招持续 cell) and how full the bar is
	## (ult_charge against BalanceBrawl.ENERGY_MAX). The actor keeps no copy - the same division
	## is_channelling / is_digesting make.
	return unit != null and is_instance_valid(unit) and unit.ult_ready()


func ult_seconds() -> float:
	## HOW LONG THIS PIECE'S ULTIMATE HOLDS, in seconds; 0.0 = it has none. Asked of the BODY
	## like shot_id / ranged_fx_id / gulp_seconds above, so "give this row an ultimate" stays one
	## sheet cell. The base Unit has no such method, which is the whole answer for the families
	## that never have one.
	if unit == null or not is_instance_valid(unit) or not unit.has_method("brawl_ult_seconds"):
		return 0.0
	return maxf(0.0, float(unit.call("brawl_ult_seconds")))


func ult_radius() -> float:
	## [B38] HOW BIG THE ULTIMATE'S LANDING IS, in cells; 0.0 = this piece's ultimate is not a leap.
	## The THIRD question about the same cell pair, asked of the BODY like the one above - and it is
	## deliberately a radius and not a boolean, because "how much of the ground does the slam claim"
	## is part of what the piece IS (data/units/pokemon.csv 的 大招范围) just as 击退 is. A row that
	## leaves it blank is 雷角兽 and every other family: the two lines below are the whole answer.
	if unit == null or not is_instance_valid(unit) or not unit.has_method("brawl_ult_radius"):
		return 0.0
	return maxf(0.0, float(unit.call("brawl_ult_radius")))


func ult_knock_cells() -> int:
	## [B38] HOW FAR THE LANDING THROWS WHAT IT LANDS ON, in cells; 0 = the slam only damages.
	## The same split as the ordinary 击退, twice over: the DISTANCE is the sheet's and the PACE is
	## BalanceBrawl's, and it is asked of the BODY so that "this jump knocks bodies flying" stays one
	## CSV cell. Note whose rule this is - the ATTACKER's, on the row's ultimate rather than on its
	## swing - which is why 卡比兽 leaves 击退 blank and still throws a crowd with its jump.
	if unit == null or not is_instance_valid(unit) \
			or not unit.has_method("brawl_ult_knock_cells"):
		return 0
	return maxi(0, int(unit.call("brawl_ult_knock_cells")))


func ult_knockback_cells() -> int:
	## [W12c] HOW MANY CELLS THE FULL BAR PUSHES, when what it buys is a ring opened at this body's
	## own feet rather than a beam held or a leap taken; 0 = this row's ultimate is not a shove.
	## The FOURTH question about the same family of cells, asked of the BODY like the three above -
	## and the same walk into `has_method` is the whole answer for every family that never shoves:
	## plants, zombies, and every human row that leaves 大招击退 blank.
	if unit == null or not is_instance_valid(unit) \
			or not unit.has_method("brawl_ult_knockback_cells"):
		return 0
	return maxi(0, int(unit.call("brawl_ult_knockback_cells")))


func per_hit_energy() -> int:
	## [W12c] HOW MUCH ENERGY THIS PIECE BANKS ON EVERY BLOW IT TAKES; 0 = being hit funds nothing.
	## The one energy question in this file answered from the VICTIM's row rather than the
	## striker's, because the sentence is the wall's own: "I earn my ultimate by being hit"
	## (data/units/humans.csv 受击积攒, the 盾卫's column). land_hit asks it after the damage has
	## settled - a body the blow killed banks nothing, which is the same alive-gate ordering the
	## shove has always kept.
	if unit == null or not is_instance_valid(unit) or not unit.has_method("brawl_energy_per_hit"):
		return 0
	return maxi(0, int(unit.call("brawl_energy_per_hit")))


func _open_ultimate(p_pool: Array) -> bool:
	## [B14] THE ULTIMATE ITSELF, and the whole of it is two lines: the opening blow lands through
	## land_hit - the ONE door every blow in this mode goes through, so the rage, the attachments
	## and the victim's own books keep their single owner - and the rest is the arena's channel,
	## which is the very node a 持续 row opens (brawl_beam.gd). What differs is only what a tick
	## is WORTH (BalanceBrawl.ULT_TICK_SHARE) and how long it burns (the row's 大招持续).
	##
	## So an ultimate is not a fifth attack shape: it is the row's own beam, held. A row that
	## fills 大招持续 without naming a 远程特效 has nothing to draw, and this answers FALSE - the
	## piece then keeps attacking normally with a full bar, which is a visible symptom of a
	## half-filled row rather than a blow that silently does nothing.
	##
	## The bar is spent on the spot, and it is safe to do so: this runs only on a tick where
	## can_strike() said yes, and can_strike() refuses a body that is already channelling - which
	## is exactly the case the arena's own refusal (open_beam's second door) is there for.
	##
	## [B38] THE ROW SAYS WHICH ULTIMATE THIS IS, and the leap was asked FIRST: a row that states a
	## 大招范围 jumps (see _open_leap below) and never reaches the lines above, because a body that
	## lands inside a crowd has no beam to hold. A row that states only 大招持续 is 雷角兽 and reads
	## exactly as it did before this batch.
	##
	## [W12c] THE ORDER MOVED: the shove-ring is asked FIRST now, because the 盾卫's row fills BOTH
	## distance cells - 大招范围 is how wide its wall is and 大招击退 is what the wall spends - and a
	## pusher read as a leaper would charge the enemy line on its back and headbutt people instead of
	## shoving them off. A row that states 大招击退 is a shove, whatever else it states; a row that
	## states only 大招范围 is 卡比兽 and still jumps; a row that states neither and holds a 大招持续
	## is still the beam the whole block above describes.
	if ult_knockback_cells() > 0:
		return _open_shockwave(p_pool)
	if ult_radius() > 0.0:
		return _open_leap()
	var beam := ranged_fx_id()
	var seconds := ult_seconds()
	if beam == "" or seconds <= 0.0 or arena == null:
		return false
	## [B17] The ultimate is the row's own beam held, so it pays the same second door an
	## ordinary beam does (dev doc §4-14): no shared height, no opening - and no spending of
	## the bar either, which is the kind answer. The piece keeps its charge and swings at the
	## air until something stands where its beam can reach.
	if not height.z_hits(target.height):
		return false
	land_hit(target, blow_value())
	arena.open_beam(self, target, beam, seconds, BalanceBrawl.ULT_TICK_SHARE)
	unit.consume_ult_charge()
	return true


func _open_shockwave(p_pool: Array) -> bool:
	## [W12c] THE SHOVE-RING - the 盾卫's 盾墙冲击, and the THIRD thing a full bar can buy in this
	## mode (a beam held, a leap taken, a wall pushed). The whole of it is one EXISTING budget spent
	## in a new shape: every enemy standing within the row's 大招范围 at this body's own feet
	## receives the row's 大招击退 through shove_from - the same armed slide a bash or a slam arms,
	## from the epicentre rather than from a fist - and NOTHING lands through land_hit, because what
	## this ultimate sells is displacement and not damage: no blow value, no popup, no second
	## damage table. The 1/3 execution cannot fire here by construction, which IS the zero.
	##
	## THE RING IS COUNTED BEFORE THE BAR IS SPENT: an empty wall is a refused ultimate - the charge
	## stays on the body and the piece swings normally instead, the same kind refusal the beam makes
	## at its height door and the leap makes at its max distance. A ring only opens when there is
	## somebody to push out of it, so the shieldman facing an empty field keeps its 100.
	##
	## The victim gate is the slam's, line for line (the XY circle AND the B17 height door, alive,
	## not-swallowed, enemy side), walked in POOL order for the file's determinism rule - the day a
	## bout fields two shieldmen, the same crowd must be thrown in the same sequence every run.
	## Nothing here can kill or wound a victim between the count and the shove (no damage is dealt),
	## which is why one pass collects and the other spends.
	var cells := ult_knockback_cells()
	var radius := ult_radius()
	if cells <= 0 or radius <= 0.0 or _field == null or unit == null \
			or not is_instance_valid(unit):
		## A row that states a push without a radius is half-filled: the bar shows, nothing ever
		## fires, and the symptom is visible - the convention every other refusal keeps.
		return false
	var victims: Array[BrawlActor] = []
	for other in p_pool:
		var victim: BrawlActor = other
		if victim == null or victim == self or not victim.is_alive() \
				or victim.is_swallowed() or victim.side == side:
			continue
		if not height.z_hits(victim.height) or pos.distance_to(victim.pos) > radius:
			continue
		victims.append(victim)
	if victims.is_empty():
		return false
	unit.consume_ult_charge()
	var thrown := 0
	for victim in victims:
		if victim.shove_from(self, cells):
			thrown += 1
	Fx.spawn_slam(_field.world_of(pos), _field.cell_px() * radius)
	unit.jelly_pose(BalanceUI.SLAM_JELLY_AMP, BalanceUI.SLAM_JELLY_TIME)
	if arena != null:
		print("[Brawl] %.1fs  %s opens a shield wall: r%.1f at (%.2f, %.2f) -> %d body(ies) thrown"
			% [float(arena.clock.elapsed), unit.name, radius, pos.x, pos.y, thrown])
	return true


func melee_fx_id() -> String:
	## [P110e] WHICH MELEE PICTURE THIS PIECE LEAVES WHERE IT HITS - asked of the BODY, exactly
	## like shot_id() below, and that IS the design: the arena does not decide what a blow looks
	## like from the attacker's type (which is what `if unit.is_zombie` used to be), it asks the
	## body, and the body reads its own sheet row. A new piece with a new slash is a CSV cell.
	## "" = nothing of its own, and the spark is the whole effect.
	if unit == null or not is_instance_valid(unit):
		return ""
	return unit.melee_fx_id()


func ranged_fx_id() -> String:
	## [P110f] WHICH BEAM THIS PIECE ATTACKS WITH, asked of the BODY like the two above: "" means
	## it does not attack that way, anything else means its blow lands INSTANTLY - nothing crosses
	## the board - and that beam is drawn between the two bodies. The three monsters answer; every
	## human and zombie answers "".
	if unit == null or not is_instance_valid(unit):
		return ""
	return unit.ranged_fx_id()


func brawl_beam_seconds() -> float:
	## [P110g] HOW LONG THIS PIECE'S BEAM BURNS, in seconds - 0.0 for the shapes that land once (a
	## swing, a flash) and for every body that does not attack with a beam at all. Asked of the
	## BODY, like the three questions above: the sheet's 持续 cell is the only thing that decides
	## that the eye tower keeps burning where the laser eye does not.
	if unit != null and is_instance_valid(unit) and unit.has_method("brawl_beam_seconds"):
		return maxf(0.0, float(unit.call("brawl_beam_seconds")))
	return 0.0


func _fires_swept_shot() -> bool:
	## [B22] DOES THIS PIECE'S BLOW CROSS THE BOARD IN A STRAIGHT-THINKABLE LANE? Asked of the
	## ROW (射弹 id + its 轨迹 column), never of the unit type: only a swept flight (直线 or 追踪)
	## can be blocked by a body standing between the two, so only its shooter has a lane to
	## clear. 抛射 arcs go OVER the scrum and land where they land - sidestepping cannot un-
	## block a shell whose splash is the point - and a piece whose answer is "" strikes with a
	## swing or a beam that never travels through an ally at all. Those all answer false and
	## fight exactly like they did before this batch.
	var shot := shot_id()
	if shot == "":
		return false
	return ProjectileDB.trajectory(shot) != ProjectileDB.TRAJ_ARC


func shot_id() -> String:
	## WHICH PROJECTILE THIS PIECE FIRES, or the empty string - asked of the BODY (HumanPiece's
	## fourth door, ShooterPlant's [B8+] answer for a plant) and not decided here, so `make this
	## piece ranged` stays a sheet edit. A zombie is the family that still answers the empty string
	## today: its shot id belongs to the turn engine's lane rules, so it fights what it can touch.
	if unit != null and is_instance_valid(unit) and unit.has_method("brawl_shot_id"):
		return str(unit.call("brawl_shot_id"))
	return ""


func tornado_cells() -> float:
	## HOW FAR THE WHIRLWIND I SUMMON WALKS, in cells; 0.0 = I do not summon one ([B41]: the funnel is
	## called up IN FRONT of this body, along its facing, and no target is handed to it). The FIFTH attack
	## shape's only number, asked of the BODY like shot_id() above so "make this piece a storm-bird"
	## stays one cell of data/units/<faction>.csv (旋风) and no branch in the arena.
	##
	## A DISTANCE and not a flag, for the reason 击退 and 大招范围 are distances: "a gust that goes two
	## cells" and "a front that goes six" are two rows of one rule, while the pace, the funnel's
	## radius, the pulse and what a pulse is worth are the mode's (BalanceBrawl.TORNADO_*). There is
	## no fall-back to choose either - a blank cell IS the answer ("this row does not storm"), which
	## is why there is no static effective_* twin on the body.
	if unit == null or not is_instance_valid(unit) or not unit.has_method("brawl_tornado_cells"):
		return 0.0
	return maxf(0.0, float(unit.call("brawl_tornado_cells")))


func _hunts_allies() -> bool:
	## [B31] DOES MY ROW FIRE A SHOT THAT MENDS RATHER THAN WOUND? Asked of the ROW - the 治疗
	## cell of data/projectiles.csv, which the turn engine's warm_sun row is the only line that
	## fills today - and never of the unit type: the sheet decides what a blow IS, this file only
	## asks what it said, the same reading _fires_swept_shot() just above gives for 轨迹.
	##
	## THREE READERS, ONE ANSWER, all of them inside this file: tick() aims this body at its own
	## side instead of at an enemy (Intent.lowest_hp_ally), tick() refuses the gunner's sideways
	## step because a friendly in the lane of a mend is nothing to dodge, and BrawlShot re-asks
	## the SAME cell for its own half of the flight (which side it may meet, and whether the
	## flight ends on the body it brushed). A fourth would be a drift waiting to happen, so the
	## question is asked of ProjectileDB and nowhere else - the same table both modes read.
	var shot := shot_id()
	return shot != "" and ProjectileDB.heals(shot)


func is_healer() -> bool:
	## [W-fix] THE PUBLIC FACE of _hunts_allies(), and it exists for exactly one outside reader:
	## Intent.nearest_fighter_ally must tell a fighter from a fellow mender while it walks the
	## pool, and brawl_intent.gd may not name this class (its header's cycle ban) - but it can
	## ask a duck. ONE answer, two spellings: the row stays the only owner of what a mend is.
	return _hunts_allies()


func muzzle(p_kind: String) -> Vector2:
	## [B14] WHERE ONE OF THIS BODY'S BEAMS LEAVES IT, in board pixels: the body's centre, or the
	## point the LOOK names as a fraction of its picture (Fx.beam_muzzle -> BalanceUI.BEAMS.muzzle;
	## the thundercorn's bolt comes out of the horn on its upper left).
	##
	## Public because TWO things draw the same beam - the one-shot flash in _strike_once and the
	## channel node that follows two bodies for seconds (brawl_beam.gd) - and "where does this
	## attack come out of" must not have two answers. It is read at DRAWING time and not baked into
	## a position at launch, so a body that walks mid-channel carries its horn along with it.
	##
	## [B16] A MIRRORED BODY FIRES FROM THE OTHER SIDE, because the horn moved with the picture:
	## the muzzle offset is authored against the ART (the thundercorn's horn is at its upper
	## LEFT), so a body the board has flipped must have that x negated - otherwise the bolt
	## leaves the back of its head. One sign, one place, both beam shapes.
	if unit == null or not is_instance_valid(unit):
		return Vector2.ZERO
	var offset := Fx.beam_muzzle(p_kind, unit.art_box())
	if unit.mirrored:
		offset.x = -offset.x
	return unit.position + offset


func blow_value() -> float:
	## WHAT ONE BLOW OF MINE IS WORTH, before the victim has any say - the number a shot CARRIES
	## from the muzzle to the impact. The rage's two offensive halves are in here, and so is my
	## own attack attachment; the victim's books are deliberately NOT (see land_hit).
	## The rage's defensive half is in here too, and it is still applied as extra damage TAKEN by
	## the target rather than by rewriting Zombie.armor: the armour LAYER has its own downgrade
	## and 处决 rules (P26) and a brawl blow has no business editing them.
	## NOT rounded: the victim's multiplier is applied to this float and the sum is rounded once,
	## exactly where it always was.
	var amount := float(damage_per_attack())
	amount *= 1.0 + float(_rage) * BalanceBrawl.RAGE_ATTACK_PER_LEVEL
	amount *= 1.0 + float(_rage) * BalanceBrawl.RAGE_DEFENSE_PER_LEVEL
	amount *= self_mult(BalanceBrawl.KEY_ATTACK)
	return amount


func land_hit(p_target: BrawlActor, p_amount: float) -> void:
	## THE ONE PLACE A BRAWL BLOW BECOMES DAMAGE - and since [B9] the one place it becomes a
	## DISPLACEMENT too. A melee swing and a landed arrow both come through here, which is what
	## keeps the rage, the attachments and the shove from growing a second owner the day a third
	## kind of blow shows up.
	##
	## The victim's own books are applied LAST and HERE, and that order is the point: 厚皮's
	## floor can change while a shot is in the air, and only the victim knows them - the
	## multiplier is a DOOR (taken_mult) rather than a read of somebody else's dictionary.
	if p_target == null or p_target.unit == null or not p_target.is_alive():
		return
	## A shooter that died in mid-air stops being a damage SOURCE but not a sender: the blow was
	## already struck, and take_damage() takes a null source quite happily.
	var src: Unit = unit if (unit != null and is_instance_valid(unit)) else null
	## [B12] THE DAMAGE NUMBER IS READ AROUND THE CALL, not inside it: take_damage() has four
	## ways to change the answer (the ultimate's immunity, 防御 in the damage formula, a zombie's
	## armour layer, the 1/3 execution) and only the body that was hit knows which one happened.
	## What the popup says is therefore what the hp bar ACTUALLY lost - the one number a spectator
	## has, since the arena puts no other readout on the board.
	var before := p_target.unit.hp
	p_target.unit.take_damage(maxi(1, int(round(p_amount * p_target.taken_mult()))), src)
	var dealt := before - p_target.unit.hp
	if dealt > 0 and is_instance_valid(p_target.unit):
		## The body may have just died (play_death fades it over the next frames), so its position
		## is read here, before that fade moves it nowhere: a popup belongs where the blow landed.
		Fx.spawn_popup(p_target.unit.position + Vector2(0.0, BalanceUI.DAMAGE_POPUP_DY),
			"-%d" % dealt, BalanceUI.COLOR_DAMAGE)
	## [B9] ...AND THE SHOVE RIDES ON THE SAME BLOW, if my row says my blows shove. It is asked
	## AFTER the damage for one reason: a body this blow KILLED must not be pushed anywhere.
	## take_damage() has already emitted its death signal by the time it returns (Brawl's
	## _on_piece_died -> play_death), so the is_alive() gate inside shove_from is the whole
	## check - and it is the same gate every other reader of a victim uses.
	## The rule asked here is the ATTACKER's ("do my blows shove"), put to the body like every
	## other attack question: a piece whose 击退 cell is blank never calls this at all.
	var shove := knockback_cells()
	if shove > 0:
		p_target.shove_from(self, shove)
	## [W12c] ...AND THE VICTIM MAY BANK FROM IT. The one energy deposit in the mode asked of the
	## body being HIT rather than the one doing the hitting - the 盾卫's row says how much a wound
	## is worth to ITS bar, and asking the attacker instead would make every enemy on the board
	## fund the shieldman's ultimate, which is a different (and much louder) game. It sits after
	## the damage for the shove's own reason, reused: a body this blow killed banks nothing.
	if p_target.is_alive():
		p_target.charge_hit_energy()


func land_mend(p_target: BrawlActor, p_amount: float, p_tint: Color) -> void:
	## [B31] THE ONE DOOR A MEND LANDS THROUGH, and the brawl's twin of Projectile._mend(): the
	## SAME number a blow carries, moving BACK on instead of off. It is a second door rather than
	## a flag on land_hit because everything else that function does is a question a mend must not
	## answer, each for its own reason:
	##   taken_mult - 厚皮 is a body's answer to being HIT, and a mend is not a hit. Applying it
	##       would make an ally who wears a shield harder to help, which is the opposite of what
	##       the row means;
	##   the shove - knockback_cells() is a rule about throwing a VICTIM away. A healer that
	##       punched its patient backwards would be the joke of the mode, and the gate below is
	##       the whole reason it cannot happen rather than a branch that remembers not to;
	##   the flinch - shove_from plays "hit" for a body that was just struck; nothing here plays
	##       anything for a body that was just helped;
	##   the death bookkeeping - a mend cannot kill anything, so the before/after read a blow
	##       needs (B12: four ways take_damage changes the answer) collapses into the one number
	##       Unit.heal() already returns.
	##
	## WHAT IT KEEPS is the two tells a spectator has: the "+N" over the body, and the spark where
	## it landed, both in the FLIGHT's colour (the tint is handed in by BrawlShot rather than
	## guessed here, exactly as a wound's popup is the victim's own position rather than the
	## shooter's opinion of it). A mend that lands 0 points says NOTHING - an ally the flight
	## found already whole is not a miracle, and "+0" would be a lie about a number.
	if p_target == null or p_target.unit == null or not p_target.is_alive():
		return
	var gained := p_target.unit.heal(maxi(1, int(round(p_amount))))
	if gained <= 0:
		return
	Fx.spawn_spark(p_target.unit.position, p_tint)
	Fx.spawn_popup(p_target.unit.position + Vector2(0.0, BalanceUI.DAMAGE_POPUP_DY),
		"+%d" % gained, p_tint)


# ---------------------------------------------------------------- the shove [B9]
func knockback_cells() -> int:
	## HOW FAR MY BLOW THROWS THE BODY IT LANDS ON, in cells; 0 = my blows only damage. Asked of
	## the BODY exactly like shot_id() / melee_fx_id() above, so "make this piece a pusher" stays a
	## sheet cell (data/units/humans.csv 的 击退) and never a branch in the arena. Two of the three
	## families answer 0 by NOT HAVING THE DOOR: a plant and a zombie in the brawl walk into the
	## has_method below and stop there, which is the whole answer for them.
	if unit == null or not is_instance_valid(unit) or not unit.has_method("brawl_knockback_cells"):
		return 0
	return maxi(0, int(unit.call("brawl_knockback_cells")))


func shove_from(p_source: BrawlActor, p_cells: int) -> bool:
	## [B9] 击退 - THE FIRST WAY A BODY IN THIS MODE MOVES WITHOUT WALKING.
	##
	## WHY IT IS NOT A STATUS, AND NOT THE TURN ENGINE'S PUSH. The turn engine's 击退
	## (Zombie.push_back, P59) and this one agree on the two things that matter - a shove is
	## settled at once and leaves no counter behind - but they cannot share an implementation:
	## over there "back" is a HIGHER COLUMN, because a lane is a direction and a zombie walks one
	## way, while here there are no lanes and no left (BRAWL.md §12: the intent splits for exactly
	## this reason). So "the way it came" is re-asked in two dimensions as AWAY FROM THE BODY THAT
	## STRUCK ME - the one reading that stays true when a piece is hit from the side, and true
	## again when one shieldman bashes another.
	##
	## THE DISTANCE IS THE SHEET'S, SPENT AS A BUDGET. This call only ARMS the slide; the victim's
	## own driver walks it out over the next few ticks (_advance_shove). A real-time bout has to
	## have the victim somewhere in between, and a one-cell instant teleport would be the one
	## movement in this mode that skips the in-between.
	##
	## A SECOND SHOVE ADDS. Two shieldmen bashing one body send it two cells and the DIRECTION is
	## the latest blow's: budgets are distances and distances add, while "which way" can only have
	## one answer at a time.
	if p_cells <= 0 or p_source == null or not is_alive():
		## A dead body is not shoved: the blow that killed it has already reported itself, and a
		## corpse sliding backwards is a picture of a bug (see the ordering note in land_hit).
		return false
	var away: Vector2 = pos - p_source.pos
	if away.length() < 0.001:
		## Exactly on top of each other (D31 lets bodies overlap): the striker's own facing is
		## the only honest answer left, and it does not depend on which one ticked first.
		away = p_source.facing
	_shove_dir = away.normalized()
	_shove_left += float(p_cells)
	## THE VICTIM'S ANSWER TO BEING HIT, and the only flinch in this mode: a brawl blow otherwise
	## leaves the red flash take_damage() writes and nothing else, and a body that slides a whole
	## cell while looking untouched reads as a teleport. "hit" is the shared pose (backward lean +
	## backward push, scripts/core/unit_fx.gd) - of which the LEAN is what a brawl body can play,
	## because the push channel is Unit.shake() and that refuses a body with no grid (R1). One
	## door, one owner: docs/dev/FX.md §2 carries this call site.
	if unit != null and is_instance_valid(unit):
		unit.play_fx("hit")
	return true


func _advance_shove(p_dt: float) -> void:
	## One step of the slide, taken INSTEAD of a walk (see tick). The pace is BalanceBrawl's
	## (SHOVE_CELLS_PER_SECOND) so that the RULE stays a distance: one cell at six is a fifth of a
	## second, and it reads the same whatever the window size.
	##
	## The budget is spent whether or not the arena let the body MOVE: a piece already against the
	## wall is pinned there and the shove is simply over, rather than pressing into the edge for
	## the rest of the bout. Landing on a spot another body already holds is fine - D14 has no
	## blocking, and the separation force sorts the overlap out on the next tick the body walks.
	var step := minf(_shove_left, BalanceBrawl.SHOVE_CELLS_PER_SECOND * p_dt)
	pos = _field.clamp_to_arena(pos + _shove_dir * step)
	_shove_left = maxf(0.0, _shove_left - step)


# ---------------------------------------------------------------- the stun (眩晕) [W12a]
func is_stunned() -> bool:
	## AM I DAZED? The one question the rest of the mode would ask a dazed body, answered the
	## way is_leaping answers a jumping one - from the countdown, never a second flag.
	return _stun_left > 0.0


func apply_stun(p_seconds: float) -> void:
	## [W12a] ENTER (or EXTEND) A DAZE. Today one thing calls this - the devourer whose meal
	## failed (BrawlGulp) - and the rule is written for any future daze, so three doors decide:
	##   DEAD OR HELD, REFUSED - a corpse gets nothing, and a body already inside a belly is
	##       wholly owned by that branch; a second takeover would be a second opinion on the
	##       same tick (the prey's "stunned while devoured" is the belly's job already).
	##   A DAZED BODY IS NOT MID-JUMP - an unspent leap is dropped, the same rule [B38] wrote
	##       for being eaten (_drop_leap is now the one owner of both).
	##   DAZES ADD - they are durations and durations add, for shove_from's stated reason.
	## The picture is the sway the priority ladder has carried since [B33] with no call site:
	## UnitFx.ID_STUN rocks the body about its feet, and a flinch OUTRANKS it - being hit snaps
	## the lean over the rock, which is the documented meaning of "a stun is a state an attack
	## wears off, not a shield".
	if p_seconds <= 0.0 or not is_alive() or held_by != null:
		return
	if _leap_left > 0.0:
		_drop_leap()
	_stun_left += p_seconds
	if unit != null and is_instance_valid(unit):
		unit.play_fx(UnitFx.ID_STUN)


func break_stun() -> void:
	## [W12a] CANCEL THE REMAINDER - the meal is over early because the prey DIED, and the
	## devourer that already paid for the hold with its own immobility gets its feet back on the
	## frame it finishes. No picture to undo: the sway has no state to reset beyond the timer
	## (an outranking flinch has already re-drawn the body).
	_stun_left = 0.0


func _keep_stun_sway() -> void:
	## [W12a] THE ROCK RE-ARMS ITSELF. One pass of UnitFx's stun sways for FX_STUN_* seconds
	## (0.88 s today) and the dazes this mode schedules are LONGER (1 s, 2 s), so the stun
	## branch asks, every tick, whether anything at stun priority is still playing - and when
	## the body has fallen back to its idle (priority 0) puts the rock on again. A flinch
	## (hit 30 / hit_shot 25) outranks and is deliberately left to finish first: the snap IS
	## the feedback of being struck while dazed.
	if unit != null and is_instance_valid(unit) \
			and unit.fx_priority() < UnitFx.PRIORITY_STUN:
		unit.play_fx(UnitFx.ID_STUN)


func _drop_leap() -> void:
	## [W12a] UNSAY AN UNSPENT LEAP - the one owner of the rule [B38] wrote inside
	## be_swallowed ("a body inside somebody is not mid-jump") and [W12a] extends to a dazed
	## body: the belly pose or the standing sway owns the picture from here, and a slam
	## delivered from a belly or a daze is not a thing this mode should ever draw. The pose
	## goes back to rest on the spot (a body dropped out of a stretch may not stay stretched);
	## the charge STAYS spent - the wind-up paid it, and dropping is the price of being hit at
	## the worst moment, not a refund.
	_leap_left = 0.0
	_leap_air = 0.0
	_leap_radius = 0.0
	_leap_knock = 0
	_leap_gulp = 0.0
	_leap_mark = null
	height.z_height = 0.0
	height.z_velocity = 0.0
	_set_leap_pose(Vector2.ONE)


# ---------------------------------------------------------------- the leap [B38]
func _open_leap() -> bool:
	## [B38] 蓄力跳跃 - THE SECOND WAY A BODY IN THIS MODE MOVES WITHOUT WALKING, and the only one
	## it chooses. A shove has a direction imposed on it; this one AIMED somewhere, so the whole of
	## the arithmetic below is about WHERE and THE SHEET'S OWN NUMBERS decide it: the row's 大招范围
	## is both the switch (a blank = no leap, and this answers false on its first line) and how much
	## ground the slam claims, its 大招震飞 is what the landing throws.
	##
	## THE LANDING IS THE TARGET, MINUS A BODY LENGTH. Landing ON a mark would put the two bodies
	## exactly on top of each other and read as a teleport; landing just short of it is where a slam
	## is aimed, and the same offset makes an already-adjacent mark a tiny HOP ON THE SPOT instead of
	## a jump backwards over it (offset = half the span, capped at the melee reach). Both ends are
	## clamped to the arena, so a mark against the wall is jumped to the wall and not through it.
	##
	## ONE COUNTDOWN HOLDS THE WHOLE SHAPE: wind-up first, then air, so the state machine is the
	## single `_leap_left` the tick branches already read (see is_leaping). The wind-up is a fixed
	## time, because a charge that scales with distance would make a hop look like a leap; the air is
	## DISTANCE DIVIDED BY A PACE (BalanceBrawl.LEAP_CELLS_PER_SECOND), because a jump that takes the
	## same time however far it goes is a teleport with a pose on it.
	##
	## The bar is spent HERE and on the spot, for the same reason the beam's is: the callers only get
	## this far after can_strike()/the tick's own gates said this body is free, and a refusal above
	## leaves the charge unspent - the kind answer a half-filled row deserves.
	if _field == null or unit == null or not is_instance_valid(unit):
		return false
	var radius := ult_radius()
	if radius <= 0.0 or target == null or not target.is_alive():
		return false
	var away: Vector2 = target.pos - pos
	var span := away.length()
	if span > BalanceBrawl.LEAP_MAX_CELLS:
		return false
	var dir := away / span if span > 0.001 else facing
	var landing := dir * maxf(0.0, span - minf(BalanceBrawl.MELEE_REACH_CELLS, span * 0.5))
	_leap_from = pos
	_leap_to = _field.clamp_to_arena(pos + landing)
	var ground := maxf(0.001, _leap_to.distance_to(_leap_from))
	_leap_air = maxf(0.1, ground / BalanceBrawl.LEAP_CELLS_PER_SECOND)
	_leap_radius = radius
	_leap_knock = ult_knock_cells()
	_leap_left = BalanceBrawl.LEAP_WINDUP_SECONDS + _leap_air
	unit.consume_ult_charge()
	unit.play_fx("attack")
	## The squat is NOT switched on here: _advance_leap walks it in over the wind-up, so the press is
	## animation and not a pose that was simply already bent.
	_set_leap_pose(Vector2.ONE)
	return true


func _open_pounce(p_mark: BrawlActor, p_hold: float) -> bool:
	## [W12b] THE LEAP OF THE DEVOURER - the slam machine put to an ORDINARY blow's service,
	## with exactly three differences from _open_leap, and everything else (the wind-up press,
	## the arc, the whole-tick takeover) is the one machine, not a second one:
	##   THE MARK IS LANDED ON, NOT SHORT OF IT. [B38] stops a slam a body-length short because
	##       two bodies exactly on one spot read as a teleport; a devourer's landing IS the
	##       swallow, so the pounce aims AT the prey and the overlap is the point (the prey then
	##       rides the belly pose, not the board).
	##   NOTHING IS SPENT. This is the row's own attack shape, not a purchased ultimate: no bar
	##       to consume, and the callers have already paid the swing's cooldown.
	##   IT CARRIES THE HOLD. _leap_gulp is the sheet's seconds and _leap_mark the locked prey;
	##       the landing of the same countdown hands both to the arena (see _finish_leap).
	if _field == null or p_mark == null or p_hold <= 0.0 or not is_alive():
		return false
	if not p_mark.is_alive():
		return false
	_leap_from = pos
	_leap_to = _field.clamp_to_arena(p_mark.pos)
	var ground := maxf(0.001, _leap_to.distance_to(_leap_from))
	_leap_air = maxf(0.1, ground / BalanceBrawl.LEAP_CELLS_PER_SECOND)
	_leap_radius = 0.0
	_leap_knock = 0
	_leap_gulp = p_hold
	_leap_mark = p_mark
	_leap_left = BalanceBrawl.LEAP_WINDUP_SECONDS + _leap_air
	if unit != null and is_instance_valid(unit):
		unit.play_fx("attack")
	_set_leap_pose(Vector2.ONE)
	return true


func _advance_leap(p_dt: float, p_pool: Array) -> void:
	## One step of the jump, taken INSTEAD of everything else (see tick). The countdown falls through
	## the wind-up on its own, so the only branch here is "am I still squatting" - and while I am, the
	## body deliberately does NOT move: a charge reads as a charge because something happens before it
	## flies. What happens is the PRESS: rest → CROUCH, walked with a sqrt so the body drops into the
	## squat at once and then keeps loading more slowly. A linear ramp would spend the whole wind-up
	## halfway bent and finish with a snap nobody reads; eased this way, the pose is unmistakably
	## "pressed down" for the last third of the time, which is the part the eye is watching for.
	##
	## In the air the two writers of this body's place are the line below and _sync_position, which is
	## exactly the pair the shove uses; what the shove has no need of is the third coordinate, and the
	## arc gets one. The parabola is written rather than integrated (4·h·s·(1-s) over a fixed flight
	## time) because a hop has to LAND on the tick the countdown runs out: a gravity sum would leave a
	## body still falling when its jump was already over. That is also why z_velocity is zeroed here -
	## height.integrate() is skipped for the whole flight, and it must find nothing half-written when
	## the leap hands the axis back at the ground.
	_leap_left = maxf(0.0, _leap_left - p_dt)
	if _leap_left > _leap_air:
		var left := (_leap_left - _leap_air) / BalanceBrawl.LEAP_WINDUP_SECONDS
		var press := sqrt(1.0 - clampf(left, 0.0, 1.0))
		_set_leap_pose(Vector2.ONE.lerp(BalanceUI.BRAWL_LEAP_CROUCH, press))
		return
	if _leap_left <= 0.0:
		_finish_leap(p_pool)
		return
	var share := 1.0 - _leap_left / _leap_air
	_set_leap_pose(BalanceUI.BRAWL_LEAP_STRETCH)
	pos = _field.clamp_to_arena(_leap_from.lerp(_leap_to, share))
	var apex := BalanceBrawl.LEAP_APEX_SHARE * _leap_from.distance_to(_leap_to)
	height.z_height = 4.0 * apex * share * (1.0 - share)
	height.z_velocity = 0.0


func _finish_leap(p_pool: Array) -> void:
	## ...AND DOWN. The slam is not a fifth attack shape any more than an ultimate's beam is: every
	## body in the circle is struck THROUGH land_hit, so rage, attachments, armour, the 1/3 execution
	## and the popup keep the one owner they have had since [B12], and the 震飞 is the same shove a
	## bash arms - only from the epicentre rather than from a fist.
	##
	## The gate is the XY circle AND the height door (B17), asked per victim exactly as a swing asks
	## it: a body under the landing that shares no height with the slam is not hit by it. A body in
	## mid-air over the scrum, though, IS - which is the reading the mode already made for an arc.
	##
	## The order is the one land_hit was written for: damage, then (inside shove_from) the alive check,
	## so a body the slam killed is not also thrown across the arena.
	##
	## [B38] FEET FIRST. The axis is put back on the ground BEFORE the circle is measured, because the
	## slam IS the landing and not the last frame of the flight: left alone, whether a 1.5-cell-high hop
	## still reaches the bodies under it would depend on which tick the countdown happened to run out
	## on (the z written by the previous step, since this branch returns before writing another). That
	## is a height fact about a picture, and the picture is what this batch is changing - so the ring's
	## victims are judged from the ground, exactly like a swing's, and the arc is free to be as tall as
	## it needs to be SEEN.
	## [W12b] FIRST BRANCH: THE DEVOURER'S LANDING. The pounce carries no circle and throws nobody -
	## its payload is the meal itself. If the prey locked at take-off is still there (alive, not
	## swallowed by somebody else while this body was in the air, and within
	## GULP_LAND_TOLERANCE_CELLS of the mark - it may have walked during the flight), it goes to the
	## arena's swallow(), which answers its own refusals. A refused swallow falls through to the
	## ordinary blow: "a devourer that cannot eat still hits", the rule this branch already had when
	## the gulp landed on contact. No slam ring: the belly pose IS the picture of arriving here.
	if _leap_gulp > 0.0:
		var hold := _leap_gulp
		var mark := _leap_mark
		_leap_gulp = 0.0
		_leap_mark = null
		_leap_left = 0.0
		_leap_air = 0.0
		height.z_height = 0.0
		height.z_velocity = 0.0
		pos = _leap_to
		_set_leap_pose(Vector2.ONE)
		if unit != null and is_instance_valid(unit):
			unit.jelly_pose(BalanceUI.SLAM_JELLY_AMP, BalanceUI.SLAM_JELLY_TIME)
		if mark != null and mark.is_alive() and not mark.is_swallowed() \
				and pos.distance_to(mark.pos) <= BalanceBrawl.GULP_LAND_TOLERANCE_CELLS \
				and arena != null and arena.swallow(self, mark, hold):
			Fx.spawn_spark(mark.unit.position, BalanceUI.COLOR_HP_FILL)
		elif mark != null and mark.is_alive():
			land_hit(mark, blow_value())
			Fx.spawn_spark(mark.unit.position, BalanceUI.COLOR_HP_FILL)
			Fx.spawn_melee_fx(melee_fx_id(), mark.unit.position, facing)
		return
	var amount := blow_value()
	var radius := _leap_radius
	var struck := 0
	var thrown := 0
	height.z_height = 0.0
	height.z_velocity = 0.0
	for other in p_pool:
		var victim: BrawlActor = other
		if victim == null or victim == self or not victim.is_alive() \
				or victim.is_swallowed() or victim.side == side:
			continue
		if not height.z_hits(victim.height) \
				or pos.distance_to(victim.pos) > radius:
			continue
		land_hit(victim, amount)
		struck += 1
		if _leap_knock > 0 and victim.shove_from(self, _leap_knock):
			thrown += 1
	_leap_left = 0.0
	_leap_air = 0.0
	_leap_radius = 0.0
	_leap_knock = 0
	pos = _leap_to
	_set_leap_pose(Vector2.ONE)
	## [B38] THE PICTURE OF ARRIVING, and it is drawn whether or not the circle found anybody: a body
	## that fell out of the air always marks the ground it came down on, and an empty slam that shows
	## nothing would leave the player to wonder where the jump actually landed. Two channels, both
	## already owned by somebody else -
	##   the ring: Fx, the one door for a one-shot effect, at the GROUND point (`world_of`, not
	##     unit.position, which _sync_position lifts by the body's z), and as wide as the sheet said;
	##   the rebound: the body's own jelly, which scales the PICTURE about the feet and so composes
	##     with the rest pose written above instead of fighting it ([B34]'s channel, [B33]'s split).
	if _field != null and is_instance_valid(_field):
		Fx.spawn_slam(_field.world_of(pos), _field.cell_px() * radius)
	if unit != null and is_instance_valid(unit):
		unit.jelly_pose(BalanceUI.SLAM_JELLY_AMP, BalanceUI.SLAM_JELLY_TIME)
	if struck > 0 and arena != null:
		## The bout's one log of a slam, in the arena's voice (the file's convention: a blow says
		## nothing, the arena reports what its state did). The count is what a play-by-play reader
		## wants - "how many bodies did that jump claim" is the number the row is being paid for.
		print("[Brawl] %.1fs  %s lands a leap: r%.1f at (%.2f, %.2f) -> %d body(ies) struck, %d thrown"
			% [float(arena.clock.elapsed), unit.name, radius, pos.x, pos.y, struck, thrown])


func _set_leap_pose(p_pose: Vector2) -> void:
	## THE POSE OF A JUMP, squatted / stretched / at rest - and the ONE door a leap writes it through,
	## so no branch can leave a body bent. It is a SCALE and not a Tween because a brawl body's frame
	## budget is the sheet's (no new tscn per family), and it is one place because the belly
	## (GULP_PREY_SCALE) and a falling corpse (play_death's fade) both own the same field - which is
	## also why a body that is dying gets nothing here.
	if unit == null or not is_instance_valid(unit) or unit.is_dying():
		return
	unit.scale = p_pose


# ---------------------------------------------------------------- the belly [B10]
func gulp_seconds() -> float:
	## HOW LONG I HOLD WHAT I SWALLOW, in seconds; 0.0 = my blows are ordinary blows. Asked of the
	## BODY like shot_id() and ranged_fx_id() above, so "make this piece a devourer" stays a sheet
	## cell (data/units/<faction>.csv 的 吞噬). The base Unit has no such method, which is the
	## whole answer for the two families that never devour.
	if unit == null or not is_instance_valid(unit) or not unit.has_method("brawl_gulp_seconds"):
		return 0.0
	return maxf(0.0, float(unit.call("brawl_gulp_seconds")))


func is_swallowed() -> bool:
	## AM I INSIDE SOMEBODY? The one question every "who can be hit / who can be aimed at" loop
	## asks before it counts this body (BrawlIntent's two searches, BrawlShot's sweep and its
	## landing, BrawlBeam's re-aim). A body inside another body is not standing on the board, and
	## letting it be hit through its holder would make the whole effect pointless.
	return held_by != null


func be_swallowed(p_slime: BrawlActor) -> void:
	## [B10] THE MOMENT OF BEING EATEN. Called by BrawlGulp.launch() and by nothing else, on the
	## frame the devourer's blow would have landed. Three things happen and all three are this
	## body's own business, because this body owns its ink and its look:
	##   the HOLD   held_by - what makes tick() ride the belly and what every query reads;
	##   the POSE   smaller, tinted, drawn over the body that ate it (BalanceUI.GULP_*);
	##   the FLINCH "hit", the same answer any blow gets (see shove_from above).
	## [B38] A BODY INSIDE SOMEBODY IS NOT MID-JUMP. An unspent leap is dropped here rather than
	## finished: the belly branch of tick() now owns the whole body, the belly pose owns its scale, and
	## a slam delivered from inside a slime is not a thing this mode should ever draw. The charge is
	## already spent (the wind-up paid it) - the price of being eaten at the worst moment.
	## [W12a] the drop itself moved to _drop_leap(), the one owner it now shares with apply_stun.
	if _leap_left > 0.0:
		_drop_leap()
	held_by = p_slime
	_apply_belly_pose(true)
	if unit != null and is_instance_valid(unit):
		unit.play_fx("hit")


func release_held() -> void:
	## ...AND OUT AGAIN, whatever the reason: the meal was finished, the devourer died, the
	## digestion ran out, or the bout ended. The HOLD is always dropped - a body left holding a
	## reference to a corpse would follow it for the rest of the bout - while the POSE is only
	## undone for a body that is still standing (see _apply_belly_pose).
	held_by = null
	_apply_belly_pose(false)


func _apply_belly_pose(p_inside: bool) -> void:
	## THE POSE OF BEING EATEN, and the only place it is written. Nothing is put back for a body
	## that is already falling: play_death() owns its fade and its scale from that moment on, and
	## restoring a corpse to full size in the middle of that fade is exactly the kind of bug that
	## shows up months later as "the eaten one grew again just before it vanished".
	if unit == null or not is_instance_valid(unit) or unit.is_dying():
		return
	var size := BalanceUI.GULP_PREY_SCALE if p_inside else 1.0
	unit.scale = Vector2(size, size)
	unit.modulate = BalanceUI.COLOR_GULP_PREY if p_inside else Color.WHITE
	unit.z_index = BalanceUI.GULP_PREY_Z if p_inside else 0


func _sync_position() -> void:
	## The ONLY writer of a brawl unit's ink. Legal because the body was placed with a null
	## grid: Unit._apply_position() returns early for such a unit, and _tick_idle() can
	## therefore never fight this line (agreed as R1, BRAWL.md §12).
	if _field == null or unit == null or not is_instance_valid(unit):
		return
	## col / row are DERIVED here, never registered: BRAWL.md §4 says the float position is
	## the truth and a cell is only its projection. They are written because a few of the
	## rules that run on a hit read cells - Zombie._struck_from_behind() compares columns to
	## decide whether a shot met the screen door from the front or the back (P45). A driver
	## that left them at 0 would silently make "hit from behind" false for every hit.
	unit.col = int(floor(pos.x))
	unit.row = int(floor(pos.y))
	## [B17] THE PICTURE IS LIFTED off the ground track by the body's own Z (dev doc §4-15),
	## converted with the arena's LIVE cell - presentation follows the window, and the cells
	## above it are what judged (D100's two rulers, kept apart on the drawing line itself).
	## pos / height stay untouched: this is ink, the same projection col and row are.
	unit.position = _field.world_of(pos) + Vector2(0.0, -height.z_height * _field.cell_px())
	if held_by == null:
		## ...and air sits ABOVE the field's bodies. Skipped inside a belly on purpose: the
		## pose of being eaten owns its own z_index (the lump drawn over its holder), and a
		## second writer would fight it every tick (_apply_belly_pose, BRAWL.md §8.11).
		unit.z_index = BalanceUI.BRAWL_AIR_Z if height.z_height > 0.0 else 0
	## [P110] The body's facing rides along: the pose effects resolve "lean forward" against
	## it, and this is the only place that knows. A piece can be deployed TURNED (is_turned)
	## or be walking on a diagonal, and neither is derivable from is_zombie.
	unit.facing = facing
