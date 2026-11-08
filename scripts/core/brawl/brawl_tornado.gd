extends Node2D
## [B39] A TRAVELLING WHIRLWIND - 鸟怪's 旋风: the blow does not land on the body it was aimed at at
## all. The bird SUMMONS a funnel IN FRONT OF ITSELF ([B41], 用户: "准确地说，鸟怪应该是在身前召唤出
## 旋风，而不是发射旋风" - the storm takes the direction the body is FACING and not a line drawn to a
## victim, because it is weather and not a projectile) and that funnel then WALKS a distance across the
## arena, paying a fraction of the same blow to every body it passes through, once per period.
##
## WHY IT IS AN OBJECT OF ITS OWN AND WHY THE ARENA OWNS IT. The same argument BrawlShot and
## BrawlBeam each make for themselves: this outlives the tick that started it, it has to be ticked
## and drawn with the bout, and a replay must not inherit one - so the arena keeps the list
## (Brawl.tornadoes), ticks it and clears it with the bout. What it is NOT, is a kind of shot:
## data/projectiles.csv 轨迹 is read by the TURN engine's Projectile too, and inventing a 旋风 row
## there would be a table column that lies for one of the two engines. The whirlwind is a brawl
## rule, so it is a brawl object.
##
## WHY IT LOOKS LIKE A BEAM AND MOVES LIKE A SHOT. "一定频率的接触伤害" is the beam's and the gulp's
## shape (a cadence, priced as a SHARE of one blow, every tick going through the same door), and
## "行走一段距离" is the shot's (a thing that carries its number away from the body that made it).
## Neither class does both, so this one does: the shot's walk, the beam's pulse.
##
## ONE OWNER OF THE DAMAGE, like every other blow in this mode: each tick calls the SUMMONER's own
## land_hit(), so the rage, the attachments, the victim's own books (厚皮) and the attacker's 击退
## all keep the single home they already had (BRAWL.md §12). A whirlwind is a cadence and never a
## second damage table. The CADENCE and the SHARE are global rules (BalanceBrawl.TORNADO_*); the
## DISTANCE it walks is the row's own 旋风 cell; the picture's fractions are BalanceUI's; and [B40]
## how BIG it is is one word - BalanceBrawl.TORNADO_SIZE_TIER, read off the same ladder a
## projectiles.csv 体型 cell writes, and spent on the column and its movement instead of the ring.
##
## THE NUMBER IS FROZEN AT THE MOMENT OF SUMMONING, like a shot's and unlike a channel's. The
## distinction is real: a beam is the eye ATTACKING AGAIN every tick, so it re-reads what the shooter's
## blow is worth now; a whirlwind is ONE blow that left the bird and is still travelling. Whatever the
## rage became two seconds later, this one was struck when the funnel was called.
##
## THE SUMMONER DYING DOES NOT END IT - and that is the same split as the sentence above. A shot
## keeps flying when its shooter falls (BrawlShot), because the blow was already struck; a beam is
## cut (BrawlBeam), because it is a relationship between two live bodies. This is the summoned kind.
##
## TWO PAINTERS, ONE RULE ([B41]). BalanceUI.TORNADO_PAINTER picks which one draws this node, and the
## default is the TWO-FRAME SEQUENCE (assets/svg/fx/tornado_0.svg / tornado_1.svg, flipped every
## TORNADO_FRAME_SECONDS) - because [B40] made the code-drawn column as big as its own rulers allowed
## and the user still could not see it ("受够了，还是完全看不到旋风"). A stroke can only ever be so loud;
## a picture cannot. The vector painter stays as the selectable alternate AND as the fallback when the
## two frames are not imported, so a whirlwind may be badly drawn but never invisible. Neither painter
## moves a RULER: both pin the widest footprint on the grass to exactly TORNADO_REACH_CELLS (the frames
## painter does it through the file's own measured ink box, UnitArt.ink_fractions), and both draw no
## higher than this node's own z_thickness. [B41] adds the WHITE WIND TRACE under whichever painter is
## active - the combed corridor the funnel has already walked, the one fact neither of them could say:
## WHICH GROUND this thing swept, and so what is about to be swept.
##
## WHAT IS NOT IN HERE: whether a whirlwind holds its summoner. It does not - like a shot, it is
## one attack already paid for, and attack间隔 is the only thing that limits how many the bird can
## have walking. No sound cue either: a bird summons one of these every strike, and the audio
## table has no whirlwind entry to spend on it (docs/NUMBERS.md).

const HeightBody := preload("res://scripts/core/height_body.gd")

var _field: BrawlField = null


## [W1] The live board's gates, with the brawl's own answer as fallback - same reason as
## BrawlShot's trio: `summon()` runs after `add_child`, so a draw can meet a null `_field`,
## and a plain BrawlField answers what the statics answer today (bit-identical for the bout).
func _tx_field() -> BrawlField:
	return _field if _field != null and is_instance_valid(_field) else null


func _tx_cell_px() -> float:
	var f := _tx_field()
	return f.cell_px() if f != null else BrawlField.cell()


func _tx_board_cols() -> int:
	var f := _tx_field()
	return f.board_cols() if f != null else Balance.COLS


func _tx_board_rows() -> int:
	var f := _tx_field()
	return f.board_rows() if f != null else Balance.ROWS
var _summoner: BrawlActor = null
var _actors: Array = []
var _side := BalanceBrawl.SIDE_LEFT
## WHAT ONE PULSE OF THIS THING IS WORTH, taken from the summoner's blow as it was worked out on the
## strike frame. Kept as
## the number and not the share, for the reason BrawlBeam keeps its share: a body cannot change
## what a whirlwind already in motion is worth by putting a ring on half way through.
var _pulse := 0.0
## CELLS OF WALK LEFT - the row's 旋风 cell, spent at BalanceBrawl.TORNADO_CELLS_PER_SECOND. It is
## a DISTANCE and not a duration because "how far" is the piece's fact and "how fast" is the mode's.
var _left := 0.0
## Seconds until the next pulse, counted with += so a frame that ran long does not push the whole
## cadence back - BrawlBeam's and BrawlGulp's rule, for the same reason.
var _tick_at := 0.0
var _cell := Vector2.ZERO
var _heading := Vector2.RIGHT
## [B40] The same heading as it looks ON SCREEN, asked of the field when the funnel is called. The lean
## is drawn in the node's own frame, and the arena's cell->pixel map is not assumed to be axis-aligned
## (it is today, but the day it tilts the funnel must still trail the way it walks): one subtraction at
## summoning, and the drawing never guesses.
var _screen := Vector2.RIGHT
## Seconds since the funnel was called: the spin's clock, [B41]'s frame-flip clock and the ramp-in's
## meter - three readings, one number.
var _age := 0.0
## >= 0 while the whirlwind is only a picture fading out. Kept apart from _left so that "how far
## it walked" and "how long it takes to go away" stay two facts (BrawlBeam's _tail again).
var _tail := -1.0
## [B21] Captured when the funnel is called, so one walk never changes policy mid-air.
var friendly_fire := true
var _done := false
## [B40] 1.0 while a pulse it just landed is still glowing, and it is set by the SWEEP and not by a
## clock: the bright frame is the frame a body actually paid (BalanceUI's PULSE argument). Spent on
## the bands' weight and brightness, never on the radius.
var _flash := 0.0
## [B40] THIS whirlwind's magnitude as a multiplier, resolved once when it is called from the word
## BalanceBrawl.TORNADO_SIZE_TIER (大 = 1.5× on Balance's ladder). Resolved and not re-read, for the
## same reason _pulse is: the picture a body watched coming at it must not change size mid-flight.
## It buys height, band count, stroke weight and how far the top moves - and never the floor ring.
var _tier := 1.0
## [B41] THE CELL THE FUNNEL WAS CALLED AT, kept for the white trace: the corridor is measured from
## here to the foot, which is a fact about where the bird STOOD and not about how far it has walked
## (_left counts the walk down as it goes, and the trace needs the end it started from).
var _born := Vector2.ZERO
## [B41] WHICH PAINTER draws this node, resolved once from BalanceUI.TORNADO_PAINTER - and DEMOTED to
## the vector painter at once if the two frames are not on disk. The bug this batch exists to kill is
## an invisible whirlwind, so a missing import may not quietly become a second one.
var _painter := BalanceUI.TORNADO_PAINTER_FRAMES
## [B41] THE TWO FRAMES, each with the ink box measured beside it (UnitArt.ink_fractions). The ink and
## not the canvas is what gets pinned to the ring: a file's own margins are the artist's business, the
## damage radius is the arena's, and pinning the canvas would let an empty border lie about reach.
var _frames: Array = []
var _frame_inks: Array = []
## The column of air the whirlwind actually occupies, and the ONLY reason it is here: the pulse
## asks z_hits like every other blow, so a body that clears the column walks the bout untouched
## (docs/prompt/HEIGHT.md §3). It does not fly, so nothing integrates it.
## [B40] Its thickness is the rule's number TIMES this node's magnitude - 大 buys more AIR, which is
## the one thing a whirlwind may honestly buy big: a taller storm is a storm a jumper cannot clear,
## and the picture above draws exactly what this number says.
var height: HeightBody = HeightBody.new()


func summon(p_summoner: BrawlActor, p_cells: float, p_amount: float,
		p_field: BrawlField, p_actors: Array) -> void:
	## Everything a whirlwind needs, handed over once by the arena (Brawl.spawn_tornado). p_cells is
	## the row's own 旋风 cell and p_amount the summoner's blow as it was worked out on the strike
	## frame; both are read once, here, and this node never asks another body for a number again.
	_summoner = p_summoner
	_field = p_field
	_actors = p_actors
	_side = p_summoner.side
	_pulse = p_amount * BalanceBrawl.TORNADO_TICK_SHARE
	_left = maxf(0.0, p_cells)
	## [B41] THE HEADING IS THE BODY'S OWN FRONT and not a line drawn to a victim: the bird summons the
	## storm IN FRONT OF ITSELF and the weather then does what weather does - it walks that way and pays
	## whoever happens to be standing there. That is the whole difference from an arrow, and it is why
	## the arena no longer hands this node a target at all: nothing about the walk is chosen by the body
	## the strike happened to pick. `facing` is the arena's own unit vector (BrawlActor writes it from
	## normalized headings only), and the birth cell is one body-radius out along it, so the funnel does
	## not start inside the bird that called it. _born is that same cell: where the grass first got
	## combed, which is what the white trace measures back to.
	_heading = p_summoner.facing
	_cell = p_summoner.pos + _heading * BalanceBrawl.BODY_RADIUS_CELLS
	_born = _cell
	## The cadence's first pulse comes one FULL period after summoning (BrawlGulp's and BrawlBeam's
	## rule): the frame a whirlwind appears on is the frame the attack was struck, and a hit here
	## would be a free blow nobody paid for. Counting from the period also makes the payout exactly
	## countable - see BalanceBrawl's TORNADO_* block for the arithmetic.
	_tick_at = maxf(0.01, BalanceBrawl.TORNADO_TICK_SECONDS)
	## [B40] The magnitude, frozen with the pulse: the word is the rule table's, the ratio is the
	## ladder's (Balance.SIZE_TIERS), and a blank/unknown word answers 1.0 = 标准.
	_tier = maxf(0.01, Balance.size_scale(BalanceBrawl.TORNADO_SIZE_TIER))
	height.z_thickness = BalanceBrawl.TORNADO_HEIGHT_CELLS * _tier
	## [B41] The painter is chosen HERE and not in _draw: a funnel that changed how it is drawn
	## mid-flight would be a different object on screen, and a missing picture must degrade to the
	## code-drawn column instead of to nothing at all.
	_painter = BalanceUI.TORNADO_PAINTER
	_load_frames()
	if _frames.is_empty():
		_painter = BalanceUI.TORNADO_PAINTER_VECTOR
	friendly_fire = SettingsStore.friendly_fire
	position = p_field.world_of(_cell)
	## The screen direction this thing walks in, for the lean and the trace: the SAME subtraction the
	## node's own position comes from, over a short step of the heading, so the top of the column trails
	## the foot along the walk however the arena maps cells to pixels.
	var ahead := p_field.world_of(_cell + _heading * 0.25) - position
	_screen = ahead.normalized() if ahead.length() > 0.001 else Vector2.RIGHT
	queue_redraw()


func _load_frames() -> void:
	## [B41] THE TWO FRAMES, asked once per funnel - and asked through the doors the rest of the FX
	## picture family already uses: Fx.melee_fx_path() is the ONLY spelling of assets/svg/fx/ in this
	## project (slash, claw, and now these two) and UnitArt.load_texture() caches it, so a bird that
	## summons six storms in a bout reads the disk zero times.
	## A frame that is not imported is not a half-drawn whirlwind: BOTH frames are dropped and the node
	## paints with the vector painter instead, because the failure this batch exists to kill is an
	## invisible storm and a missing file must not become a second one. UnitArt.warn_once says which
	## path failed, once per path, in the same voice a unit with no sprite uses.
	_frames.clear()
	_frame_inks.clear()
	for id in BalanceUI.TORNADO_FRAMES:
		var path := Fx.melee_fx_path(str(id))
		var tex := UnitArt.load_texture(path)
		if tex == null:
			UnitArt.warn_once(path)
			_frames.clear()
			_frame_inks.clear()
			return
		## The ink box, measured once and kept beside the texture it belongs to: the picture is sized by
		## ITS INK, so a file's empty border cannot quietly change what the ring claims. A file that
		## will not measure is believed at its own canvas.
		var ink := UnitArt.ink_fractions(path)
		if ink.size.x <= 0.0 or ink.size.y <= 0.0:
			ink = Rect2(0.0, 0.0, 1.0, 1.0)
		_frames.append(tex)
		_frame_inks.append(ink)


func tick(p_dt: float) -> void:
	if _done:
		return
	_age += p_dt
	## The glow decays whether or not this step also walked: a pulse that landed on the last frame of
	## a life still owes its ending, and freezing it here would leave the funnel lit at full bright in
	## the middle of its own fade.
	_flash = maxf(0.0, _flash - p_dt / maxf(0.001, BalanceUI.TORNADO_PULSE_SECONDS))
	if _tail >= 0.0:
		## The walk is over; only the picture is still leaving.
		_tail -= p_dt
		if _tail <= 0.0:
			_done = true
			queue_free()
			return
		queue_redraw()
		return
	var step := minf(BalanceBrawl.TORNADO_CELLS_PER_SECOND * p_dt, _left)
	_left -= step
	_cell += _heading * step
	position = _field.world_of(_cell)
	## THE END IS CHECKED BEFORE THE PULSE, so the frame the walk runs out on does not also land a
	## hit - BrawlBeam's line, and it is what makes the number of pulses a countable fact instead
	## of a lottery. Leaving the grass is the same ending one step earlier: the funnel does not
	## slide along the wall, and unlike a shot there is no whiff to honour here - a whirlwind that
	## met nobody has already paid nobody, and the fade is the picture owing its ending.
	if _left <= 0.0 or _outside_arena():
		_dissipate()
		queue_redraw()
		return
	_tick_at -= p_dt
	if _tick_at <= 0.0:
		_tick_at += maxf(0.01, BalanceBrawl.TORNADO_TICK_SECONDS)
		_sweep()
	queue_redraw()


func finished() -> bool:
	## The arena's door, exactly like BrawlShot's and BrawlBeam's: true once this node may leave the
	## list - and by then it has already queued its own free.
	return _done


func painter() -> String:
	## [B41] WHICH PAINTER this node actually settled on, for the arena's one line per bout. The switch
	## word is BalanceUI's and could be read there; what only THIS node knows is whether the two frames
	## were on disk - and "vector" in that column is the log saying the artist's funnel did not import.
	return _painter


func _sweep() -> void:
	## EVERY BODY INSIDE THE FUNNEL, RIGHT NOW. The judgement is a plain radius and not the shot's
	## swept point-to-segment, because this is not a thing that STOPS at the first body it meets:
	## it is a region that walks, and what it owes each body is the pulse. At [B41]'s 1.4 cells a second
	## and a 30 Hz step the funnel moves 0.047 cells per step, so nothing can be missed between two
	## pulses that is not missed by the same honest reading of "was it in it when it spun".
	## Bodies inside a belly are not on the board to be touched (BrawlGulp's rule, asked of the body
	## itself), the summoner is carried along by its own storm and is not its victim, and a dead
	## body is not a body. [B21] Friendly fire decides whether same-side bodies pay, exactly as it
	## decides it for a flight.
	var reach := BalanceBrawl.TORNADO_REACH_CELLS + BalanceBrawl.BODY_RADIUS_CELLS
	var struck := 0
	for entry in _actors:
		var other := entry as BrawlActor
		if other == null or other == _summoner or not other.is_alive() \
				or other.is_swallowed():
			continue
		if other.side == _side and not friendly_fire:
			continue
		if other.pos.distance_to(_cell) > reach:
			continue
		## [B17] the second door, every pulse: the funnel occupies 0..(TORNADO_HEIGHT_CELLS × magnitude)
		## of air, and a body whose interval meets none of it is above the storm rather than in it.
		## Say what the reading is TODAY so nobody hunts for a dodge that cannot happen: nothing on
		## the board clears the column's ≈3.3 cells (2.2 × the 大 tier [B40] put on it; the tallest thing
		## is a leap, and LEAP_APEX_SHARE × the hop's own distance puts the snorlax at ≈1.6 cells at
		## best), so this door answers yes to every body.
		## It exists for the flying units docs/dev/HEIGHT.md §9 (Phase 2) promises, not for anything now.
		if not height.z_hits(other.height):
			continue
		## THROUGH THE SUMMONER's door, so the victim's books and the attacker's 击退 are applied by
		## the same code that applies them for a swing, an arrow and a beam tick. A summoner whose
		## body is already gone still pays: land_hit() takes a null source quite happily and the
		## blow was struck while it was alive.
		_summoner.land_hit(other, _pulse)
		struck += 1
	## [B40] THE PICTURE PAYS FOR THE EVENT AND NOT FOR THE CLOCK: the funnel brightens only on a
	## pulse that actually struck a body, so a whirlwind walking over empty grass spins quietly and
	## one that just caught the line lights up. One frame of glow per landed pulse, whatever the
	## count - the count is the damage's business, the glow is the eye's.
	if struck > 0:
		_flash = 1.0


func _outside_arena() -> bool:
	return _cell.x < 0.0 or _cell.x > float(_tx_board_cols()) \
		or _cell.y < 0.0 or _cell.y > float(_tx_board_rows())


func _dissipate() -> void:
	## The walk is done; the air takes a moment to stop moving.
	_left = 0.0
	if _tail < 0.0:
		_tail = BalanceUI.TORNADO_TAIL_SECONDS


func _ready() -> void:
	## Above every body and under the FX layer (BalanceUI's BRAWL_TORNADO_Z): the whirlwind is a
	## thing currently happening on the board, and the picture has to be legible over a scrum.
	z_index = BalanceUI.BRAWL_TORNADO_Z


func _fade() -> float:
	## [B40] ONE meter, two jobs: it is the alpha AND how far the column has stood up. A funnel that
	## appears at full height on the frame it is called up is a glitch, and one that reaches its
	## distance and is simply gone never shows the player that it ended - so it grows out of the
	## grass and sinks back into it. Note which side is conservative: the RULE this node sweeps on
	## is height.z_thickness at its FULL frozen value, and the picture only ever draws shorter than
	## that, never taller (a column drawn above the air the pulse judges would be a promise the
	## damage does not keep).
	if _tail >= 0.0:
		return clampf(_tail / maxf(0.001, BalanceUI.TORNADO_TAIL_SECONDS), 0.0, 1.0)
	## ...and a ramp at the START: a funnel at full strength on the frame the bird calls it up is a
	## glitch (BrawlBeam's spinning-up argument, word for word).
	return clampf(_age / maxf(0.001, BalanceUI.TORNADO_RAMP_SECONDS), 0.0, 1.0)


func _draw() -> void:
	## [B41] ONE GUARD, ONE TRACE, TWO PAINTERS. Each painter reads its own rulers out of the same two
	## owners (_fade for the meter, BalanceBrawl.TORNADO_REACH_CELLS and this node's own z_thickness for
	## the two measurements), which is why none of them takes a parameter: three drawings cannot drift
	## apart by each carrying a copy of the same line.
	if _fade() <= 0.0:
		return
	_draw_trace()
	if _painter == BalanceUI.TORNADO_PAINTER_FRAMES:
		_draw_frames()
	else:
		_draw_vector()


func _draw_trace() -> void:
	## [B41] THE WHITE WIND TRACE: the corridor of grass this funnel has already combed, drawn under
	## whichever picture is up (用户: "通过白色风痕表现旋风"). It exists because a body two cells away
	## cannot tell, from a funnel 0.8 cells wide, WHICH WAY the weather is going - the trace says it at
	## a glance, and it says it in the arena's own ruler: the corridor is exactly as wide as the ring
	## that pays, so "stood here = get blown" stays one sentence and not two.
	## The tail remembers only the last BalanceUI.TORNADO_TRACE_CELLS of walk, so the mark is a comet
	## trail and not a painted road: grass swept three seconds ago is not still being claimed. Each slab
	## loses its alpha QUADRATICALLY towards the far end, because a tail that stops is an error and a
	## tail that fades is a distance.
	var px := _tx_cell_px()
	var radius := BalanceBrawl.TORNADO_REACH_CELLS * px
	var fade := _fade()
	var back := _field.world_of(_born) - position
	var walked := back.length()
	if walked <= 1.0:
		return
	var dir := back / walked
	var perp := Vector2(-dir.y, dir.x)
	var limit := minf(walked, BalanceUI.TORNADO_TRACE_CELLS * px)
	var steps := maxi(1, BalanceUI.TORNADO_TRACE_SEGMENTS)
	for i in steps:
		var from := limit * float(i) / float(steps)
		var to := limit * float(i + 1) / float(steps)
		var near := 1.0 - float(i) / float(steps)
		var trace := BalanceUI.COLOR_TORNADO_TRACE
		trace.a = trace.a * near * near * fade
		draw_colored_polygon(PackedVector2Array([
			(dir * from) + perp * radius, (dir * to) + perp * radius,
			(dir * to) - perp * radius, (dir * from) - perp * radius]), trace)


func _draw_frames() -> void:
	## [B41] THE DEFAULT PICTURE: the artist's funnel, flipped between assets/svg/fx/tornado_0.svg and
	## tornado_1.svg every BalanceUI.TORNADO_FRAME_SECONDS. The clock is _age and not a step counter,
	## for the same reason the spin's is - one number, and a replay reads the same frame on the same
	## step of the same bout.
	## SIZING IS THE RING, MEASURED. The canvas is widened until the file's own INK is exactly the
	## ring's DIAMETER (2 × TORNADO_REACH_CELLS), so a picture's empty border can neither flatter nor
	## shrink what the sweep judged - the same claim the vector painter makes with its floor band, kept
	## with a ruler instead of with a stroke. The ink's BOTTOM edge is pinned to local y = 0, which is
	## the grass point this node's position and its pulse are both measured around.
	## The height is then the file's own proportion, CLIPPED to this node's z_thickness: a funnel may
	## paint less air than it occupies and never more (the [B40] promise), and _fade is applied to the
	## height and not the width, which is exactly how the vector painter stands its column up out of the
	## grass - so the sprite grows tall instead of fading in like a decal.
	var px := _tx_cell_px()
	var radius := BalanceBrawl.TORNADO_REACH_CELLS * px
	var fade := _fade()
	var index := int(_age / maxf(0.001, BalanceUI.TORNADO_FRAME_SECONDS)) % _frames.size()
	var tex := _frames[index] as Texture2D
	var ink := _frame_inks[index] as Rect2
	var canvas := tex.get_size()
	var box_w := 2.0 * radius / ink.size.x
	var want_h := box_w * (canvas.y / maxf(0.001, canvas.x)) * ink.size.y
	var ink_h := minf(want_h, height.z_thickness * px * fade)
	var box_h := ink_h / ink.size.y
	var rect := Rect2(-(ink.position.x + ink.size.x * 0.5) * box_w,
		-(ink.position.y + ink.size.y) * box_h, box_w, box_h)
	draw_texture_rect(tex, rect, false, Color(1.0, 1.0, 1.0, fade))
	## The ring on top of it, because the ring is the sentence and the art is the illustration:
	## flattened onto the same ground plane the slam ring uses, and on the frame a pulse lands it
	## thickens and whitens ([B40]'s glow - told here by the ruler, since modulate cannot brighten a
	## texture past itself).
	var glow := _flash * BalanceUI.TORNADO_PULSE_AMP
	var ring := BalanceUI.COLOR_TORNADO_RING
	ring.a = minf(1.0, ring.a * fade * (1.0 + glow))
	draw_set_transform(Vector2.ZERO, 0.0,
		Vector2(1.0, BalanceUI.BRAWL_SHADOW_DEPTH_SHARE))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, ring,
		radius * BalanceUI.TORNADO_RING_SHARE * (1.0 + glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vector() -> void:
	## [B39]/[B40] THE CODE-DRAWN COLUMN, now the selectable ALTERNATE (BalanceUI.TORNADO_PAINTER) and
	## the standing fallback when the two frames are not imported. Its own argument, unchanged:
	## The lowest band is drawn at EXACTLY TORNADO_REACH_CELLS, flattened onto the ground plane:
	## the circle a spectator watches eat bodies is the circle the damage was paid inside (B20's
	## argument, and the slam ring's). Everything else here is a fraction or a count of that one
	## radius and of this node's own z_thickness, so the height the picture shows is the height the
	## sweep judged - two facts, one owner each, and no second ruler.
	## [B40] The magnitude is spent on the SECOND of those two rulers and on how much MOVEMENT and
	## MASS the column carries: more bands, heavier strokes, a wider sway, puffs that climb the funnel
	## and a glow on the frame a pulse lands. Never on the first ruler - which is why this thing can
	## be twice the size it was and still tell the exact truth about what it reaches.
	var fade := _fade()
	var px := _tx_cell_px()
	var radius := BalanceBrawl.TORNADO_REACH_CELLS * px
	var column := height.z_thickness * px * fade
	## A bigger whirlwind is also a DENSER one: one band per step of the ladder, so the 大 funnel
	## stacks six arcs where a 标准 one stacks four.
	var bands := maxi(2, int(round(float(BalanceUI.TORNADO_BANDS) * _tier)))
	var spin := TAU * _age * BalanceUI.TORNADO_SPIN_HZ
	var glow := _flash * BalanceUI.TORNADO_PULSE_AMP
	var line := radius * BalanceUI.TORNADO_LINE_SHARE * _tier * (1.0 + glow)
	## The sway is a precession of the TOP about a FOOT that never moves: the funnel's centre on the
	## grass is where the sweep judged bodies, and it is pinned there by construction. The lean is the
	## same top trailing behind the walk. Both are proportional to the height fraction k, so the floor
	## band sits exactly where this node's position says it does.
	var perp := Vector2(-_screen.y, _screen.x)
	var sway := perp * sin(TAU * _age * BalanceUI.TORNADO_WOBBLE_HZ) \
		* BalanceUI.TORNADO_WOBBLE * radius
	## [B40] The negative sign sits on the NUMBER and not on the vector, so this line has exactly the
	## operator shape of the two above it (a Vector2 times two floats) and the funnel's top still
	## trails behind its foot. Same value, one operator less: `_draw` is a single statement list, so an
	## expression it cannot evaluate loses the WHOLE picture - the floor ring, the column and the
	## debris with it - which is why the lean gets the boring form.
	var lean := _screen * (-BalanceUI.TORNADO_LEAN * column)
	## The mass first, so the bright bands stay on top of it.
	var core := BalanceUI.COLOR_TORNADO_CORE
	core = core.lightened(glow)
	core.a *= fade
	draw_set_transform(Vector2.ZERO, 0.0,
		Vector2(1.0, BalanceUI.BRAWL_SHADOW_DEPTH_SHARE))
	draw_circle(Vector2.ZERO, radius, core)
	for i in bands:
		var k := float(i) / float(maxi(1, bands - 1))
		var at := (sway * k) + (lean * k) + Vector2(0.0, -column * k)
		var band_color := BalanceUI.COLOR_TORNADO_BAND
		band_color = band_color.lightened(glow)
		band_color.a = minf(1.0, band_color.a * fade * (1.0 + glow))
		var band_r := radius * lerpf(1.0, BalanceUI.TORNADO_TAPER, k)
		## Each higher band is narrower, turned a little further AND turned a little FASTER - which is
		## what makes a stack of arcs read as one body rotating instead of as rings sliding up.
		var from := spin * (1.0 + BalanceUI.TORNADO_SPIN_SHEAR * k) \
			+ TAU * BalanceUI.TORNADO_LAG * float(i)
		var to := from + TAU * BalanceUI.TORNADO_ARC_SHARE
		draw_set_transform(at, 0.0, Vector2(1.0, BalanceUI.BRAWL_SHADOW_DEPTH_SHARE))
		## The dull wide stroke under the bright one is the funnel's WALL: the same arc, twice, costs
		## one more draw per band and is what makes the column read as a body of air rather than as a
		## wireframe of rings.
		var wall := BalanceUI.COLOR_TORNADO_BAND
		wall.a = band_color.a * 0.35
		draw_arc(Vector2.ZERO, band_r, from, to, 26, wall, line * 2.4)
		draw_arc(Vector2.ZERO, band_r, from, to, 26, band_color, line)
	## The debris ride the funnel in the TRUE circle and are flattened by hand, so they need no
	## transform of their own - and they carry the same phase as the bands, which is the motion the eye
	## follows when the whirlwind is over nobody. [B40] They also CLIMB: one puff per rung of the
	## ladder's phase, each rising the column and pulling inward as it goes, which is the one motion a
	## real whirlwind has that this picture was not making.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var count := maxi(1, int(round(float(BalanceUI.TORNADO_DEBRIS) * _tier)))
	for j in count:
		var k := fmod(_age * BalanceUI.TORNADO_DEBRIS_RISE_HZ + float(j) / float(count), 1.0)
		var band_r := radius * lerpf(1.0, BalanceUI.TORNADO_TAPER, k) \
			* (1.0 - BalanceUI.TORNADO_DEBRIS_SPIRAL * k)
		var ang := spin * (1.0 + BalanceUI.TORNADO_SPIN_SHEAR * k) \
			+ TAU * float(j) / float(count)
		var at := Vector2(cos(ang), sin(ang) * BalanceUI.BRAWL_SHADOW_DEPTH_SHARE) * band_r \
			+ (sway * k) + (lean * k) + Vector2(0.0, -column * k)
		var debris := BalanceUI.COLOR_TORNADO_DEBRIS
		debris.a *= fade * (1.0 - 0.45 * k)
		draw_circle(at, radius * BalanceUI.TORNADO_DEBRIS_R * _tier, debris)
