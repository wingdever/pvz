extends RefCounted
## [B17] THE HEIGHT BODY - the one shared shape of "where a body is on the Z axis, and how
## wide it stands on the ground" (docs/prompt/HEIGHT.md §2.1, D103).
##
## This is the SIM's data, not a physics node: the brawl has no engine bodies, the XY overlap
## is answered by each path's own geometry (the swept point-to-segment, the arrival radius,
## the melee reach), and this struct adds the SECOND gate those paths consult - the Z interval
## [z_height, z_height + z_thickness]. Ground and air are not enumerated states; they fall out
## of intervals (spec §3): a body hugging the ground cannot reach high, a dive is just
## z_velocity pushing the interval down.
##
## NO class_name on purpose (AGENTS.md §1.4: a new global class needs the editor to register
## it). Callers preload it by path - the precedent is this batch's own files: BrawlActor and
## BrawlShot each carry one `height` composed in, and Unit carries the authored "ink" version
## the actor copies from at setup.
##
## UNITS: every field here is CELLS (spec §6, D100 revised). The 128 that appears near these
## fields in comments is the ART DESIGN BASELINE (texture px / 128 = cells), a fixed ruler for
## defaults - never the live BrawlField.cell(), which stays dynamic and only converts cells to
## pixels at the draw call.

var z_height := 0.0        ## the feet's height above the ground, up is positive (cells)
var z_velocity := 0.0      ## cells/second along the axis; integrate() owns its decay
var z_gravity := 0.0       ## cells/second^2 pulling z_velocity down (0 = the body floats by design)
var z_thickness := 1.0     ## how tall the body reaches from its feet (cells) - the hit interval's other end
var body_width := 1.0      ## XY footprint width (cells); defaults come from the texture (px / 128)
var body_depth := 0.5      ## XY footprint depth (cells); default = body_width / 2 (spec §2.1.1)
var body_xoff := 0.0       ## footprint offset from the art's bottom-centre, art-local coords, NOT mirrored (D101)
var body_yoff := 0.0       ## ...and along Godot's y-down second axis (D101)


static func z_overlap(p_az: float, p_ath: float, p_bz: float, p_bth: float) -> bool:
	## THE second gate, one line, strict on both sides (spec §3 / D94): the intervals touch when
	## each side's feet sit under the other's head. Strict `<` means two bodies stacked exactly
	## head-to-foot do NOT hit - the gap is the whiff, and O44 says a whiff costs no damage,
	## no sound, no burst, no log.
	return p_az < p_bz + p_bth and p_bz < p_az + p_ath


func z_hits(p_other) -> bool:
	## The instance door: does THIS body's interval meet the other HeightBody's? Takes the
	## other body untyped on purpose - the pool loops that ask are the untyped-by-discipline
	## ones (brawl_intent.gd), and duck-typed field reads keep this file preload-only.
	return z_overlap(z_height, z_thickness, p_other.z_height, p_other.z_thickness)


func integrate(p_dt: float) -> void:
	## [B17] The axis's one motion rule, written so the GROUND is the floor and the landing is
	## free: gravity eats z_velocity, the height walks, touching 0 clamps the velocity off so a
	## landed body never jitters a negative interval under the grass. Today every authored z is
	## 0 with z_gravity only set for divers that do not exist yet (Phase 2) - so this runs as
	## arithmetic on zeros and the bout stays frame-identical (the spec's regression promise).
	z_velocity -= z_gravity * p_dt
	z_height = maxf(0.0, z_height + z_velocity * p_dt)
	if z_height == 0.0:
		z_velocity = 0.0
