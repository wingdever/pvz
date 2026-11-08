class_name BrawlClock
extends RefCounted
## [B1] THE CLOCK OF A BRAWL - a fixed-step accumulator, and nothing else.
##
## Why a fixed step at all: a real-time mode is the one kind of system that is normally
## impossible to verify (docs/prompt/BRAWL.md §14). With a fixed step the whole bout is a
## function of (preset, step count), so "run it twice" and "run it at 4x" become the same
## question, and a headless run can drive it with no window at all. This class never
## touches get_tree(), the OS or the scene: it only answers "how many steps does this frame
## buy".
##
## SPEED multiplies the SIMULATED time, so the spectator's 4x changes the picture and not
## the outcome. PAUSE buys zero steps - which is what makes a paused bout resumable instead
## of merely frozen.

var elapsed := 0.0        # SIMULATED seconds: what the rage and the summary read
var paused := false
var speed := 1.0          # one of BalanceBrawl.SPEED_CHOICES
var steps := 0            # total logic steps run so far

var _step := 1.0 / float(BalanceBrawl.TICK_HZ)
var _accum := 0.0


func step_size() -> float:
	return _step


func advance(p_delta: float) -> int:
	## How many logic steps this frame is worth. A frame longer than the whole ladder drops
	## the debt instead of paying it: catching up is what turns one hitch into a spiral.
	if paused or p_delta <= 0.0:
		return 0
	_accum += p_delta * maxf(0.01, speed)
	var count := 0
	while _accum >= _step and count < BalanceBrawl.MAX_STEPS_PER_FRAME:
		_accum -= _step
		count += 1
	if count >= BalanceBrawl.MAX_STEPS_PER_FRAME:
		_accum = 0.0
	elapsed += float(count) * _step
	steps += count
	return count


func cycle_speed() -> float:
	## F walks the ladder. Labelling the step is the caller's business (the log's).
	var at := BalanceBrawl.SPEED_CHOICES.find(speed)
	speed = BalanceBrawl.SPEED_CHOICES[(at + 1) % BalanceBrawl.SPEED_CHOICES.size()]
	return speed


func toggle_pause() -> bool:
	paused = not paused
	return paused
