extends RefCounted
## [B10] A DEVOUR IN PROGRESS - 绿史莱姆's 吞噬: one enemy is held INSIDE another body, drawn in
## there, losing health every half second until it dies or the window runs out. [W12b] made the
## window the verdict the user asked for: prey dead inside the hold = digested, prey alive when
## the hold ends = spat out WHOLE and the devourer itself stands dazed (STUN_FAILED_DEVOUR_*),
## and the hold now starts where the slime has LEAPED ONTO its prey (BrawlActor._open_pounce).
##
## WHY IT IS AN OBJECT OF ITS OWN, AND WHY THE ARENA OWNS IT. The same argument BrawlBeam makes
## for the channelled beam: a swallow is a RELATIONSHIP between two living bodies that outlives
## the tick which started it. It has to follow the belly while the devourer walks, it has to end
## the moment either body falls, and a replay must not inherit one - so the arena keeps the list
## (Brawl.gulps), ticks it and clears it with the bout. What differs from the beam is what it
## DRAWS: nothing at all. The prey is a body of its own and is still drawn by its own Unit; this
## class only puts it in the pose of being eaten (BrawlActor.be_swallowed) and keeps it there.
## That is why it needs no node and no _draw - a RefCounted held by the arena, the shape
## BrawlActor itself has.
##
## ONE OWNER OF THE DAMAGE, like every other blow in this mode: each tick goes through the
## devourer's own land_hit(), so the rage, the attachments, the prey's own books (厚皮) and the
## shieldman's 击退 all keep the single home they already had (BRAWL.md §12). The CADENCE and the
## SHARE are global rules (BalanceBrawl.GULP_*); HOW LONG a row digests is the sheet's
## (data/units/<faction>.csv 吞噬 = seconds); the pose's numbers are BalanceUI's.
##
## WHAT IS NOT IN HERE: the prey's "cannot act". That is one line in BrawlActor.tick (a held body
## rides its holder and does nothing else), because "a body that is inside another body" is a fact
## about that body - and every reader that must skip it (targeting, separation, shots, beams) asks
## the body itself (is_swallowed), never this list.

var _slime: BrawlActor = null
var _prey: BrawlActor = null
## Seconds of digestion left. The sheet's 吞噬 cell, and the ONLY thing that ends a meal with the
## prey still breathing (see _finish).
var _left := 0.0
## Seconds until the next blow lands inside. Counted with += so a frame that ran long does not
## push the whole cadence back - BrawlBeam's rule, for the same reason.
var _tick_at := 0.0
var _done := false


func launch(p_slime: BrawlActor, p_prey: BrawlActor, p_seconds: float) -> void:
	_slime = p_slime
	_prey = p_prey
	_left = maxf(0.0, p_seconds)
	## THE FIRST BLOW COMES ONE FULL PERIOD LATER. A swallow deals no damage on contact - that is
	## what makes it a swallow and not a bite - so a tick on this frame would be a free blow nobody
	## asked for. Counting from GULP_TICK_SECONDS makes the payout exactly "one blow every half
	## second for as long as the row says", which is the number the sheet and BalanceBrawl hold
	## between them.
	_tick_at = maxf(0.01, BalanceBrawl.GULP_TICK_SECONDS)
	## The pose and the hold are the PREY's own business (it owns its ink and its look); this is
	## the one call that puts it inside.
	_prey.be_swallowed(_slime)
	## [W12b] THE DEVOURER PAYS FOR THE MEAL WITH ITS OWN FEET: the user's rule says a slime
	## holding prey cannot move under its own power, and the mode's one answer to "no step, no
	## turn, no strike" is the stun takeover (BrawlActor.apply_stun) - not a second "am I busy"
	## flag. The daze is exactly the window, so the two countdowns end together unless the meal
	## finishes first (tick breaks it) or fails (tick re-applies the indigestion daze). The
	## PREY needs no stun of its own: the belly it is already riding is the strictly stronger
	## takeover, and that IS its "眩晕" in play.
	_slime.apply_stun(_left)


func tick(p_dt: float) -> void:
	if _done:
		return
	## EITHER BODY FALLING ENDS THE DIGESTION, and both endings are the same one here: release.
	## The prey dying is the meal being finished; the DEVOURER dying is the meal being freed - and
	## that is deliberate, because "kill the slime and your friend comes back out" is the counter
	## this whole effect is balanced around (BRAWL.md §8.11).
	if not _alive(_prey):
		## DIGESTED INSIDE THE WINDOW - the success the user's rule calls 消化. The hold ends with
		## the meal: the devourer's feet come back on the frame the prey falls. [W12b]
		_finish()
		if _slime != null and _slime.is_alive():
			_slime.break_stun()
		return
	if not _alive(_slime):
		## The devourer died: the prey is freed and there is nobody left to stun.
		_finish()
		return
	## [W12b] THE BITE NOW COMES BEFORE THE WINDOW CHECK, so a hold of exactly 2.0 s pays its
	## FOURTH bite at t=2.0 and then reads its own result: "吞噬 2s" is four half-second bites,
	## and success-or-failure is decided AFTER the last blow, not a tick before it. (The old
	## order was the 6-second digestion's, where the missing last bite was a rounding nobody
	## could see; at four bites it would be a quarter of the meal.)
	_tick_at -= p_dt
	if _tick_at <= 0.0:
		_tick_at += maxf(0.01, BalanceBrawl.GULP_TICK_SECONDS)
		_slime.land_hit(_prey, _slime.blow_value() * BalanceBrawl.GULP_TICK_SHARE)
	_left -= p_dt
	if _left <= 0.0:
		if not _alive(_prey):
			## THE LAST BITE KILLED - success on the buzzer, not a failure.
			_finish()
			if _slime != null and _slime.is_alive():
				_slime.break_stun()
			return
		## SPAT OUT ALIVE, and since [W12b] the indigestion turns on its maker: the user's rule
		## is 消化不掉则释放目标、自身眩晕1s. The prey carries NO residual stun (it returns to its
		## driver whole - the tank's counter-play stands), and the devourer's fresh daze is
		## broken before it is applied, so the punish is exactly STUN_FAILED_DEVOUR_SECONDS and
		## not that plus the residue of the hold. The outcome branches live HERE and only here:
		## release() is also the bout-teardown door (_clear_gulps), and nobody is punished when
		## the clock simply stops.
		_finish()
		if _slime != null and _slime.is_alive():
			_slime.break_stun()
			_slime.apply_stun(BalanceBrawl.STUN_FAILED_DEVOUR_SECONDS)
		return


func is_slime(p_actor: BrawlActor) -> bool:
	## WHO IS DIGESTING. The arena asks it (is_digesting) so one devourer cannot hold two bodies
	## at once, and it is the reason BrawlActor keeps no "am I busy" flag of its own - the same
	## division Brawl.is_channelling() makes for the eye tower.
	return _slime == p_actor


func finished() -> bool:
	## The arena's door, exactly like BrawlShot's and BrawlBeam's: true on the frame this gulp may
	## be dropped from the list.
	return _done


func release() -> void:
	## LET GO, whatever the reason: the prey is handed back to its own driver. Idempotent, because
	## both endings call it and the arena's clear calls it once more on the way out.
	_done = true
	if _prey != null:
		_prey.release_held()


func _finish() -> void:
	release()


func _alive(p_actor: BrawlActor) -> bool:
	## BrawlActor.is_alive() already covers "the body was freed" (play_death queue_frees it a
	## moment after it falls, and the actor outlives it), so this is one question in one place.
	return p_actor != null and p_actor.is_alive()
