class_name BrawlField
extends Node2D
## [B1] THE ARENA - the ground a brawl stands on, and the line between the two halves.
##
## R2 (docs/prompt/BRAWL.md §12): the brawl does NOT register with Grid. Grid is the turn
## engine's board - integer cells, lanes, placeability, hover - and every one of those is a
## fact about the TURN ENGINE. A brawl piece has a FLOAT cell position and no lane at all,
## so this node is the brawl's own coordinate system rather than a second tenant of Grid's.
##
## [S2] WHERE THE ARENA IS is BrawlLayout's answer now, not Layout's (D65). It used to be
## Layout.lawn_rect(), which meant the brawl inherited the TURN ENGINE's chrome - a brain zone
## left of column 0, the card rail's pad right of column 8 - and could never grow into it. The
## two pages still share ONE owner, just not the turn engine's. Layout keeps the LOGICAL SIZE
## (the expanded canvas every page is laid out in), which is why both are refreshed together.
## The lifecycle is normally driven by Game; a brawl scene opened on its own (F6) has no Game,
## so this node drives it - see _on_viewport_resized().

## The border of the arena. A LOCAL constant on purpose: the shared palette is BalanceUI's
## job, while the width of a line this node draws is this node's (the same shape Grid's own
## GRID_LINE_WIDTH has).
const EDGE_WIDTH := 2.0


## [D68] The ARENA's own switch for the lattice. The formation page draws it through the
## static call; this node is the one instance that stands on a battlefield, and a spectator gets
## the same lattice at BRAWL_GRID_ARENA_ALPHA.
var show_grid := false


func _ready() -> void:
	_on_viewport_resized()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	## [S2] TWO OWNERS, TWO CALLS: Layout says how big the logical canvas is, BrawlLayout says
	## where a brawl puts its board inside it. The second reads the first's answer, so the order
	## here is the contract - and it is the same pair the formation page runs on layout change.
	var win := get_window()
	Layout.refresh(get_viewport().get_visible_rect().size,
		win.size if win != null else Vector2i.ZERO)
	BrawlLayout.refresh(Layout.size)
	queue_redraw()


# ---------------------------------------------------------------- the geometry
## The four functions below are STATIC on purpose: the formation page (scripts/ui/brawl) draws
## and hit-tests the very same rectangles the arena draws, and two copies of "which ground is
## whose" is exactly the kind of fact this project keeps in one place. Only the conversions that
## belong to a live arena (world_of / clamp_to_arena) stay on the instance.

static func arena_rect() -> Rect2:
	## The ground a brawl stands on: BrawlLayout's board rectangle, so the arena and the formation
	## page follow the window through ONE owner (D65/D66) - and no longer through the turn
	## engine's lawn, whose chrome a brawl has no use for.
	return BrawlLayout.board_rect()


static func cell() -> float:
	## [S1] THE ONE RULER. How many pixels a board cell is - what every part of a brawl that
	## speaks in cells has to ask: the geometry functions below, both drawers, a shot's speed
	## (BrawlShot.speed_cells) and a piece's picture (BrawlLayout.piece_scale). Before this door
	## there were FOUR answers - Layout.cell here, Balance.CELL_SIZE (a fixed 96) for the shots
	## and for the formation page's drag ghosts, BalanceUI.UNIT_ART_SIZE for the art - and they
	## agreed only while the cell happened to BE 96.
	return BrawlLayout.cell_size()


## [W1] THE INSTANCE GATES. The three statics above answer for THE brawl's board (the window-
## scaled cell, the global 9x5). A field that is not that board - the war's fixed 96px cell on
## a data-driven 30x10 (scripts/core/war/war_field.gd) - overrides these INSTANCE methods, and
## every simulation/draw call site that lives on a live board asks the instance instead. The
## defaults return exactly what the statics answer today, so a plain BrawlField - the only kind
## a bout ever builds - keeps every reading bit-identical. Statics cannot be overridden; that
## is why the gates are instance methods and not new statics.

func cell_px() -> float:
	## The live board's answer to "how many pixels is one cell".
	return cell()


func board_cols() -> int:
	## The live board's width in cells - what "off the right edge" means for shots and funnels.
	return Balance.COLS


func board_rows() -> int:
	## The live board's height in cells.
	return Balance.ROWS


func ranged_reach_mult() -> float:
	## [W7b] THE GROUND'S SAY OVER A STRIKE'S REACH, asked by BrawlActor.attack_reach. A bout
	## multiplies nothing; a mode whose ground fights differently (the war's doubled 射程)
	## overrides THIS door and nothing in the actor. Same instance-gate shape as the three
	## above ([W1]: defaults answer the today-value, so a plain BrawlField is bit-identical).
	return 1.0


func melee_speed_mult() -> float:
	## [W7b] THE GROUND'S SAY OVER A MELEE BODY'S FEET - the door BrawlActor.move_speed asks
	## for units that fight what they can touch. 1.0 here = the brawl keeps its pace.
	return 1.0


static func half_rect(p_side: int) -> Rect2:
	## One side's half (D11: 4 columns | 1 column | 4 columns). The GAP is not returned by
	## anybody - it is what is left between the two.
	var r := arena_rect()
	var half := r.size.x * float(BalanceBrawl.HALF_COLS) / float(Balance.COLS)
	var x := r.position.x
	if p_side == BalanceBrawl.SIDE_RIGHT:
		x += r.size.x - half
	return Rect2(Vector2(x, r.position.y), Vector2(half, r.size.y))


static func cell_rect(p_cell: Vector2i) -> Rect2:
	## One board cell, in pixels - what the formation page paints a slot with.
	var edge := cell()
	return Rect2(arena_rect().position + Vector2(float(p_cell.x), float(p_cell.y)) * edge,
		Vector2(edge, edge))


static func cell_at(p_point: Vector2) -> Vector2i:
	## Pixels -> cell, floored: the formation page turns a click into a slot with this, and the
	## result may be OFF the board (the caller checks the half it asked for).
	var edge := maxf(1.0, cell())
	var local := p_point - arena_rect().position
	return Vector2i(int(floor(local.x / edge)), int(floor(local.y / edge)))


func world_of(p_cell: Vector2) -> Vector2:
	## FLOAT cell units -> pixels. The turn engine's conversion pair lives in Grid (integer
	## cells); this is the brawl's pair, and the two never mix (R2).
	return arena_rect().position + p_cell * cell()


func clamp_to_arena(p_cell: Vector2) -> Vector2:
	## Keeps a piece ON the grass: a body's CENTRE may come within one radius of the edge and
	## no further. Without it the separation force can shove a scrum off the board, and "off
	## the board" is a state nothing else in the brawl has an opinion about.
	var margin := BalanceBrawl.BODY_RADIUS_CELLS
	return Vector2(
		clampf(p_cell.x, margin, float(Balance.COLS) - margin),
		clampf(p_cell.y, margin, float(Balance.ROWS) - margin))


# ---------------------------------------------------------------- the picture
## Both drawers are STATIC and take the CanvasItem to paint on, because TWO places paint this
## board: the arena itself, and the formation page (which previews the enemy half on the very
## same rectangle). A second copy of "what the ground looks like" is how two screens start
## disagreeing about where a cell is.

static func draw_ground(p_ci: CanvasItem) -> void:
	## The two halves and the no man's land between them (D11: 4 columns | 1 column | 4 columns).
	if p_ci == null:
		return
	var r := arena_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var left := half_rect(BalanceBrawl.SIDE_LEFT)
	var right := half_rect(BalanceBrawl.SIDE_RIGHT)
	p_ci.draw_rect(left, BalanceUI.COLOR_BRAWL_LEFT, true)
	p_ci.draw_rect(right, BalanceUI.COLOR_BRAWL_RIGHT, true)
	## The no man's land is whatever the two halves leave between them - never a third rectangle
	## computed from GAP_COLS, which would be a second answer to the same question.
	p_ci.draw_rect(Rect2(Vector2(left.position.x + left.size.x, r.position.y),
		Vector2(right.position.x - left.position.x - left.size.x, r.size.y)),
		BalanceUI.COLOR_BRAWL_GAP, true)
	p_ci.draw_rect(r, BalanceUI.COLOR_GRID_LINE, false, EDGE_WIDTH)


static func draw_grid(p_ci: CanvasItem, p_alpha: float = 1.0) -> void:
	## The 9x5 lattice. BOTH pages draw it now (D68): the arena used to leave it out ("bodies are
	## what a spectator watches"), and the two screens read as two different places because of it -
	## which is the one thing this redesign is about. The arena's lines are DIMMER
	## (BRAWL_GRID_ARENA_ALPHA) so the fight stays the subject rather than the chessboard.
	if p_ci == null:
		return
	var r := arena_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var line := BalanceUI.COLOR_GRID_LINE
	line.a *= p_alpha
	var edge := cell()
	for col in range(1, Balance.COLS):
		var x := r.position.x + float(col) * edge
		p_ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y),
			line, BalanceUI.BRAWL_GRID_WIDTH)
	for row in range(1, Balance.ROWS):
		var y := r.position.y + float(row) * edge
		p_ci.draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y),
			line, BalanceUI.BRAWL_GRID_WIDTH)


func _draw() -> void:
	draw_ground(self)
	if show_grid:
		draw_grid(self, BalanceUI.BRAWL_GRID_ARENA_ALPHA)
