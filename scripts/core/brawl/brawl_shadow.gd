extends Node2D
## [B17] THE SHADOWS - one ground-pinned ellipse per living body (docs/prompt/HEIGHT.md §2.2
## and §8, D102 / D97): the visual half of the height axis, and the thing that makes it
## readable at all. The arena's y axis is already spent on field depth, so height is drawn
## upward the same way - and WITHOUT a shadow on the ground, "it flew up" and "it walked a
## row further down" are the same picture. That is the spec's argument for calling this an
## axis PREREQUISITE and not a decoration.
##
## ONE NODE FOR ALL OF THEM, because a shadow is a fact about the GROUND: pos says where the
## body stands, and every ellipse lives there - not on the lifted sprite. Drawing them from
## the pool (the same Array the arena hands to a shot, kept by REFERENCE so a restart refills
## it without a word to this node) means one drawer, one pass, and no body that forgot its
## own. The menu prop (scripts/ui/menu/menu_prop.gd) draws its one shadow under its one
## object; that precedent is the SHAPE copied here, the ownership is the arena's.
##
## GROUND BODIES CAST ONE TOO (D102, the user's ruling): z = 0 is the full-size ellipse, not
## an absence. A shadow that only appeared in the air would have no baseline to shrink from.
##
## THE SHRINK: both sides and the alpha ride ONE curve, 1 / (1 + z * FALLOFF) - three readings
## of the same number, so "further off the floor" is one arithmetic and no new constant. The
## shadow itself never lifts (D99's logic-shadow position: actor.pos through world_of, exactly
## what the pieces' own ground ink is).
##
## [B17-fix] THE ANCHOR IS THE SOLE, NOT THE ORIGIN. Unit._draw_art() stretches the texture
## into an art_box() square drawn CENTERED on the node origin, so world_of(pos) - the ground
## mark - sits at the MIDDLE of the sprite, and an ellipse drawn at the bare mark lands on the
## body's waist (the user's report). [B36] answers where the sole really is by MEASURING it
## (D111): `unit.art_ink()` is the box the body actually paints, its bottom edge is the feet and
## its width is the ellipse's. The earlier fix guessed the CANVAS bottom (`art_box() * 0.5`),
## which is an eighth of a box too low on every sprite that keeps the authored 16 px of margin
## under its sole (VIEW_ART_FEET_LINE = 112 of 128) - militia said so. A box, so it follows
## piece_scale and stays per-body; and deliberately NOT the idle BREATHING stretch
## (_draw_art's sin term): a shadow that pulsed with every breath would read as ground ink
## wobbling, and the feet on the floor do not leave the floor while the chest does.
##
## THE ELLIPSE'S SIZE COMES FROM THE BODY, NOT FROM THE CELL (user, 2026-10-09: "x 宽度是 ink
## 宽度" then "影子的 y 轴宽度应当是 x 轴宽度的 1/2"). Width = the ink width, depth = half of it -
## the collision footprint's own arithmetic (D99: `body_depth = body_width / 2`) - so the cell
## ratio and the flatten ratio this file used to read are BOTH gone (BalanceUI's [B17] block says
## the same, and keeps one new constant: the share). A wide plant casts a wide shadow and a thin
## human a thin one: the picture now says something about the body it belongs to.
## THE THIRD HALF OF THAT SENTENCE IS NOT THIS FILE'S BUSINESS: "z 厚度是 ink 高度" is a SIM number
## (`HeightBody.z_thickness`), and it landed there in the same batch - D112, `UnitArt.ink_span_y()`
## read by `Unit.read_height()`. An ellipse is a picture; how tall a body reaches is a hit window.
##
## ALMANAC STAYS WITHOUT ONE (dev doc §27): a preview card is not a body standing on a field.
## THE FORMATION PAGE JOINED IN (user, 2026-10-06: "增加在编排战阵阶段就显示视觉影子") - the
## board it draws IS the arena's ground (same BrawlField geometry, same cells), so the pieces
## standing on it owe the same ink they will wear in the bout. Trays do not: the bench, the
## offers band, the bag and the drag ghost stay without, for the D92 reason - they are cards
## held above the field, not bodies on it. That page calls draw_ink_shadow() itself; the z it
## passes is 0 (nothing on this page flies).
##
## NO class_name, PRELOADED BY PATH (the brawl_shot.gd reason: a brand-new global class is
## invisible to `godot --headless` until the editor rescans). It is added to the field BEFORE
## the pieces and carries no z_index: tree order is the whole of its layering, which keeps it
## under grounded bodies (z 0), eaten ones (GULP_PREY_Z) and air ones (BRAWL_AIR_Z) alike.

var _field: BrawlField = null
var _actors: Array = []


func setup(p_field: BrawlField, p_actors: Array) -> void:
	## The coordinate system and the pool, handed over once by the arena (Brawl._begin). The
	## Array arrives by reference - which is why a restart (actors.clear() then a refill) needs
	## nothing done here: this node reads the same array _spawn_piece writes.
	_field = p_field
	_actors = p_actors


static func draw_ink_shadow(p_canvas: CanvasItem, p_mark: Vector2, p_ink: Rect2,
		p_z_cells := 0.0) -> void:
	## THE ONE SHADOW DRAWER, and the one call both pages make (the BrawlHUD.draw_top_bar
	## precedent: two pages, one picture; BrawlShadow's own ground rule, in the same line).
	## p_ink is the box the body ACTUALLY paints - Unit.art_ink() in the arena, UnitArt.ink_rect()
	## for a preview icon - stated in pixels measured FROM p_mark, which is why the arena's mark is
	## a body origin and a page's is the top of its icon box. It answers the two things the
	## ellipse takes from the art (D111): where its centre is (the ink BOTTOM, the measured sole)
	## and how wide (the ink width).
	## THE DEPTH IS NOT MEASURED, it is HALF THE WIDTH (user, 2026-10-09: "影子的 y 轴宽度应当是
	## x 轴宽度的 1/2") - the same footprint arithmetic the height axis already authors collisions
	## with (`body_depth = body_width / 2`, D99 / spec §2.1.1), so a shadow cannot claim a ground
	## shape its own body would not be hit by. Ink HEIGHT is therefore not read here at all.
	## x stays ON the mark: the ground anchor is where the body stands, and a lopsided picture is
	## the picture's business, not the floor's.
	## The MENU_PROP idiom survives: a unit circle flattened by the draw transform, not an arc.
	## The z curve is unchanged - it rides the width and the alpha, and the depth follows the
	## width, so a rising body keeps its shape while it shrinks (and D102's baseline: z = 0 is the
	## full-size ellipse, not an absence).
	var curve := 1.0 / (1.0 + p_z_cells * BalanceUI.BRAWL_SHADOW_FALLOFF)
	var width := maxf(p_ink.size.x, 1.0) * curve
	var color := BalanceUI.COLOR_BRAWL_SHADOW
	color.a *= curve
	p_canvas.draw_set_transform(Vector2(p_mark.x, p_mark.y + p_ink.end.y), 0.0,
		Vector2(1.0, BalanceUI.BRAWL_SHADOW_DEPTH_SHARE))
	p_canvas.draw_circle(Vector2.ZERO, width * 0.5, color)
	p_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if _field == null:
		return
	for entry in _actors:
		var actor := entry as BrawlActor
		if actor == null or not actor.is_alive():
			continue
		draw_ink_shadow(self, _field.world_of(actor.pos), actor.unit.art_ink(),
			actor.height.z_height)
