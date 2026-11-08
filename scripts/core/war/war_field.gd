class_name WarField
extends BrawlField
## [W3] THE WAR'S GROUND - the same node the brawl engine already talks to, on a DIFFERENT board.
##
## This is what the parameterisation was for: the brawl's simulation and its flying things ask a
## LIVE FIELD (not the class) for the three facts of a board - cell_px() / board_cols() /
## board_rows() ([W1] gates) - and for the two conversions world_of() / clamp_to_arena(). A war
## field answers them from a FIXED WORLD instead of from the window:
##
##   * the cell is BalanceWar.WORLD_CELL pixels, always, so a resize changes zero pixels of
##     battlefield (the brawl re-derives its cell from the window on every resize);
##   * the grid is rows x cols cells of the CURRENT MAP (data/war/maps.csv, read by WarDB),
##     not the global 9x5;
##   * the board's origin is world (0, 0) and stays there - "where the battlefield is" is
##     answered once, and the camera (scripts/core/war/war_camera.gd) is what moves.
##
## What this class deliberately does NOT touch: BrawlLayout (the brawl's window maths), the
## static drawers/rect helpers of BrawlField (they answer for the 9x5 board - plan risk #3:
## a war that drew through them would paint the wrong board), and Layout's logical size (the
## war's geometry does not depend on the window, so _on_viewport_resized() only redraws the
## lines, which is all the inherited signal connection can ask for).

## The border of the battlefield: the inherited BrawlField.EDGE_WIDTH - the same two pixels
## the brawl's frame is drawn with.

## [W10] DEPLOY_TINT is RETIRED with the half-board washes: the washes themselves are now the
## zones (draw_board), so a tint over a tint had nothing left to say. The formation page keeps
## its own gold seam ink (war_formation's DEPLOY_EDGE_LINE); this node draws the same two
## bands in the two SIDE colours the engine already speaks.

var map_id := ""
var cols := 0
var rows := 0
var deploy_cols := 0


func _ready() -> void:
	## [W4] NO GUARD AGAINST THE PAGE'S INSTANCE, and that is a decision, not an oversight.
	## The formation page runs a second field; a node kept out of the PICTURE still gets
	## _ready, so this body runs there too. It is harmless BY CONSTRUCTION:
	## set_map(WAR_DEFAULT_MAP) is exactly what the page's open_view asks for anyway (the
	## re-read just resets the box to the same answer), the resize echo lands on the override
	## below (redraw nothing), and [W8] the page's instance is `visible = false`, which stops
	## its _draw from ever running - the scene used to say `enabled = false` here, a property
	## a Node2D does not have, so nothing was switched off and the child painted its raw
	## world strips over the whole page every frame (children draw after parents). What DOES
	## have to stay guarded is any call through the base class during this window:
	## `is_enabled()` parses in war_camera.gd (native base) but failed here with "not found
	## in base self" while BrawlField was still unregistered - so nothing in this function
	## may ask the base.
	## The map arrives from the arena's begin() in a wired match; a field on its own (F6 on
	## scenes/war.tscn, or the frame before begin runs) still has to stand on SOMETHING, so
	## the default map is resolved here first and super._ready() then wires the resize echo.
	set_map(BalanceWar.WAR_DEFAULT_MAP)
	super._ready()


func _on_viewport_resized() -> void:
	## [W3] THE OVERRIDE THAT SAYS NO: the brawl's version refreshes Layout and BrawlLayout
	## because its board follows the window. The war's board does not - it is a fixed world
	## seen through a camera - so a resize buys a redraw of nothing moving. (WarCamera watches
	## the same viewport signal for its own fit; this node owes the scene-tree connection only
	## the redraw.)
	queue_redraw()


# ---------------------------------------------------------------- the map
func set_map(p_id: String) -> void:
	## Point this field at one row of data/war/maps.csv. An id the sheet does not list falls
	## back to the default map, and if even THAT is gone the board collapses to 0x0 - which
	## every reader below treats as "nothing to draw", the same way an empty half_rect is not
	## a rectangle anywhere else. A guessed board would be a second, wrong answer.
	var id := p_id
	if not WarDB.has_map(id):
		id = BalanceWar.WAR_DEFAULT_MAP
	if not WarDB.has_map(id):
		var ids := WarDB.map_ids()
		id = ids[0] if not ids.is_empty() else ""
	map_id = id
	cols = WarDB.cols_of(id) if id != "" else 0
	rows = WarDB.rows_of(id) if id != "" else 0
	deploy_cols = maxi(WarDB.deploy_cols_of(id), 0) if id != "" else 0
	queue_redraw()


func has_board() -> bool:
	return cols > 0 and rows > 0


# ---------------------------------------------------------------- the gates [W1]
func cell_px() -> float:
	## THE FIXED CELL. The one number every part of the war speaks in pixels through.
	return BalanceWar.WORLD_CELL


func board_cols() -> int:
	return cols


func board_rows() -> int:
	return rows


func ranged_reach_mult() -> float:
	## [W7b] THE WAR GROUND DOUBLES A SHOOTER'S REACH (the user's ruling). The multiplier is
	## asked through BrawlField's door, so every reader of attack_reach - the strike, the
	## pursuit stop, the idle healer's stand-off, the page's preview ring - pays one number.
	return BalanceWar.WAR_RANGED_REACH_MULT


func melee_speed_mult() -> float:
	## [W7b] ...and DOUBLES a melee body's feet, wave zombies and pushing lines included.
	return BalanceWar.WAR_MELEE_SPEED_MULT


func world_of(p_cell: Vector2) -> Vector2:
	## FLOAT cell units -> pixels. The brawl's version adds arena_rect()'s window position;
	## the war's board IS the world origin, so the conversion is a pure scale.
	return p_cell * BalanceWar.WORLD_CELL


func clamp_to_arena(p_cell: Vector2) -> Vector2:
	## Keeps a body on THIS map's grass - the brawl's rule with the map's numbers in it.
	var margin := BalanceBrawl.BODY_RADIUS_CELLS
	return Vector2(
		clampf(p_cell.x, margin, float(cols) - margin),
		clampf(p_cell.y, margin, float(rows) - margin))


# ---------------------------------------------------------------- the rectangles
## Instance helpers, sized for THIS map. The war's formation page (W4) hit-tests through the
## same doors the arena draws with - the one-board rule BrawlField's statics exist for, kept
## with two boards by putting each pair on the field that owns it.

func board_rect() -> Rect2:
	if not has_board():
		return Rect2()
	return Rect2(Vector2.ZERO, Vector2(float(cols), float(rows)) * BalanceWar.WORLD_CELL)


func deploy_rect() -> Rect2:
	## The player's deployment band - THE zone math of the war, clamped exactly the way
	## war_wave_gen rolls its mirrored band and the page's seams draw them ([W10]: one shape,
	## three readers, no second formula). Empty only when there is no board at all.
	if not has_board():
		return Rect2()
	var edge := BalanceWar.WORLD_CELL
	var band := clampi(deploy_cols, 1, cols)
	return Rect2(Vector2.ZERO, Vector2(float(band) * edge, float(rows) * edge))


## THE WAR'S OWN NAMES for the two cell conversions: BrawlField answers the same questions
## with cell_rect() / cell_at() as STATICS of the 9x5 board, and GDScript will not let an
## instance method take a parent's static name. The `war_` prefix says both halves of that -
## whose board, and which kind of call.
func war_cell_rect(p_cell: Vector2i) -> Rect2:
	var edge := BalanceWar.WORLD_CELL
	return Rect2(Vector2(float(p_cell.x), float(p_cell.y)) * edge, Vector2(edge, edge))


func war_cell_at(p_point: Vector2) -> Vector2i:
	## Pixels (world space) -> cell, floored. May be OFF the board; the caller checks. The
	## brawl's version subtracts arena_rect()'s window position first; this board starts at
	## the world origin, so the point already IS the local coordinate.
	var edge := maxf(BalanceWar.WORLD_CELL, 1.0)
	return Vector2i(int(floor(p_point.x / edge)), int(floor(p_point.y / edge)))


# ---------------------------------------------------------------- the picture
func draw_board(p_ci: CanvasItem) -> void:
	## The whole battlefield, painted on whatever CanvasItem asks - since [W9] the field's own
	## _draw is the only caller (the page keeps its dark backdrop and gold seams). [W10] THE
	## BANDS ARE THE ZONES (the user's symmetry ruling reaching the combat field): the old
	## picture washed the WHOLE left half blue and the WHOLE right half red, then tinted gold
	## only the player's deploy end - one front, two wings telling two different shapes. Now
	## one neutral ground carries two MIRRORED bands: our deploy_rect columns blue at the left
	## end, theirs - the roller's band, same zone math - red at the right end, the middle left
	## bare as the no-man's-land both armies walk through. The seam and the frame stay: the
	## front's line, the board's edge, the story [W9] kept for the arena.
	if p_ci == null or not has_board():
		return
	var r := board_rect()
	p_ci.draw_rect(r, BalanceUI.COLOR_MENU_BG, true)
	var zone := deploy_rect()
	p_ci.draw_rect(zone, BalanceUI.COLOR_BRAWL_LEFT, true)
	p_ci.draw_rect(Rect2(Vector2(r.size.x - zone.size.x, 0.0), zone.size),
		BalanceUI.COLOR_BRAWL_RIGHT, true)
	## The seam - what the brawl's no man's land is, here drawn as a line so the middle of a
	## 30-column field still reads as the front. [W11] Its width (and the frame's) is bought
	## in SCREEN pixels - see _screen_stroke - or a fit-zoom camera thins both to sub-pixel
	## and the board loses its edges the same way the lattice did.
	var half_w := r.size.x * 0.5
	p_ci.draw_line(Vector2(half_w, 0.0), Vector2(half_w, r.size.y),
		BalanceUI.COLOR_BRAWL_GAP, _screen_stroke(EDGE_WIDTH))
	p_ci.draw_rect(r, BalanceUI.COLOR_GRID_LINE, false, _screen_stroke(EDGE_WIDTH))


func for_each_grid_segment(p_cb: Callable) -> void:
	## [W11] THE ONE LATTICE GENERATOR of the war (the user's question answered in code):
	## every boundary the board owns, as WORLD-space line segments handed one at a time to
	## the caller's drawer - k = 0..cols verticals spanning the board height, j = 0..rows
	## horizontals spanning its width. Both phases now walk THIS list: the arena's _draw
	## feeds the segments straight to draw_line with a zoom-compensated stroke, the formation
	## page maps each endpoint through its camera first. Two grounds, never two loops -
	## [W10]'s edge-fix was a private patch in each file, and a private loop is exactly how
	## a line goes missing in one picture and not the other.
	if not has_board():
		return
	var edge := BalanceWar.WORLD_CELL
	var w := float(cols) * edge
	var h := float(rows) * edge
	for col in range(cols + 1):
		p_cb.call(Vector2(float(col) * edge, 0.0), Vector2(float(col) * edge, h))
	for row in range(rows + 1):
		p_cb.call(Vector2(0.0, float(row) * edge), Vector2(w, float(row) * edge))


func _screen_stroke(p_world_width: float) -> float:
	## [W11] STROKES BOUGHT IN SCREEN PIXELS. This field hangs under a Camera2D whose zoom
	## SCALES every drawn width: at the fit's ~0.43 a 1-px lattice line lands UNDER a screen
	## pixel, and aliasing eats some of them whole while their neighbours survive - the user's
	## "编阵阶段和战斗阶段的网格仍然有线条没有绘制". The brawl's field never met this: its board
	## IS the window, zoom always 1.0. On this node's own ground the answer is to widen the
	## stroke to at least one screen pixel in world units; the page's ground snaps its
	## endpoints instead (war_formation's _grid_line) because its lines are drawn in window
	## space already. Only ever consults a camera that is OUR OWN child - which is exactly the
	## arena's wiring (scenes/war.tscn hangs WarCamera under WarField); the formation page's
	## camera is a sibling, so its field instance answers p_world_width untouched.
	var cam := get_node_or_null("WarCamera")
	if cam is Camera2D:
		return maxf(p_world_width, 1.0 / maxf((cam as Camera2D).zoom.x, 0.05))
	return p_world_width


func _draw() -> void:
	draw_board(self)
	if show_grid and has_board():
		var line := BalanceUI.COLOR_GRID_LINE
		line.a *= BalanceUI.BRAWL_GRID_ARENA_ALPHA
		for_each_grid_segment(Callable(self, "_lattice_line").bind(
			line, _screen_stroke(BalanceUI.BRAWL_GRID_WIDTH)))


func _lattice_line(p_a: Vector2, p_b: Vector2, p_color: Color, p_width: float) -> void:
	## The arena's reading of the shared generator: world endpoints, world stroke (already
	## zoom-compensated by the caller), nothing mapped - this node's own canvas IS the world.
	draw_line(p_a, p_b, p_color, p_width)
