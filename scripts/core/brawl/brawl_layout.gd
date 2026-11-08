class_name BrawlLayout
extends RefCounted
## [S2] WHERE A BRAWL PUTS ITS PARTS - one owner for the board and the chrome around it.
##
## Why this module exists (docs/prompt/BRAWL.md §10.2, D65): the arena used to stand on the TURN
## ENGINE's lawn (Layout.lawn_rect) and therefore on the turn engine's chrome - a brain zone to
## the left of column 0 and the card rail's pad to the right of column 8, neither of which a brawl
## has. The formation page then hung its two side columns INSIDE that borrowed chrome (the old
## _column_rect in brawl_formation.gd), which is the real reason the board could not grow: the
## space it wanted had already been spent on somebody else's furniture.
##
## ONE CELL, ONE BOARD. `cell` is the only size in this file - board = cell x (9, 5), the bench's
## pitch IS cell (D39's alignment survives) and the drawn slot is a fraction of it (D69). A second
## way of working out "how big is a cell" is the mistake this module exists to prevent: the arena,
## the formation page, a shot's speed (BrawlField.cell) and a piece's picture all ask HERE.
##
## The budget (BRAWL.md §10.2): the board is 1.8 : 1 and a 16 : 9 window is 1.78 : 1, so both axes
## run out at the same moment and the only lever left is how much chrome sits above and below the
## board. That is why the chrome is priced in SHARES of cell wherever it can be: a bench row
## measured in cells keeps its proportions at every window size, and the arithmetic that picked
## 0.72 / 0.90 / 46 is written down next to it in BalanceUI.
## [B26] The WIDTH stayed unpriced on purpose: the shelf the user asked for lies ON the board (over
## the enemy half), not beside it, so nothing here pays for it in cell size. That is what the note in
## BalanceUI's budget block is about - a column of 200 px would have made the width the wall in a 4:3
## window and shrunk every piece on the field.
##
## Pure: logical size in, every rectangle out - no node access, no drawing, no Balance call that
## is not a board fact (COLS / ROWS / MIN_CELL_SIZE). Layout knows where the TURN ENGINE's lawn
## is; this knows where a brawl's board is, and the two never write to each other.
##
## NOTE: unlike Layout.Geometry, this one has no unset_fields() sentinel gate - a new self-check
## is exactly what AGENTS §2 forbids (BRAWL.md §10.2 "不写自检"), so compute_for() writes every
## field in plain sight and _apply() copies every one of them out.

## What compute_for() returns. Every field is written by compute_for() or the geometry is wrong,
## which is why the fields are listed here in the same order _apply() copies them.
class Geometry:
	var size := Vector2(NAN, NAN)         # logical viewport size
	var cell := NAN                       # the ONE size: board = cell x (COLS, ROWS)
	var board := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var top_bar := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var bag := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var bench := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var bench_slot := Vector2(NAN, NAN)   # one slot's BOX (smaller than its pitch, see D69)
	var band := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var dismiss := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))  # [B15] 遣散, the band's LEFT end
	var offers := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var engage := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))


# ---------------------------------------------------------------- live geometry
static var size := Vector2.ZERO
static var cell := 0.0
static var board := Rect2()
static var top_bar := Rect2()
static var bag := Rect2()
static var bench := Rect2()
static var bench_slot := Vector2.ZERO
static var band := Rect2()
static var dismiss := Rect2()
static var offers := Rect2()
static var engage := Rect2()

static var _booted := false


# ---------------------------------------------------------------- public API
static func refresh(p_size: Vector2) -> bool:
	## Re-derives every rectangle from the LOGICAL size (Layout.size), and returns true when the
	## geometry actually moved. Two callers, both idempotent: BrawlField._on_viewport_resized()
	## (the arena, and a scene opened on its own with F6) and BrawlFormation.on_layout_changed()
	## (the page, which has no arena node under it while it is up).
	if p_size.x < 1.0 or p_size.y < 1.0:
		return false
	if _booted and p_size.is_equal_approx(size):
		return false
	_booted = true
	_apply(compute_for(p_size))
	return true


static func compute_for(p_size: Vector2) -> Geometry:
	## Pure: a logical size in, the whole page's rectangles out.
	var w := maxf(p_size.x, 1.0)
	var h := maxf(p_size.y, 1.0)
	var margin := BalanceUI.BRAWL_MARGIN
	var top_h := BalanceUI.BRAWL_TOP_BAR_H
	var top_gap := BalanceUI.BRAWL_TOP_GAP
	var row_gap := BalanceUI.BRAWL_ROW_GAP
	var band_h := BalanceUI.BRAWL_POOL_TILE_H   # one offer card IS the band's height
	var bench_share := BalanceUI.BRAWL_BENCH_BAR_SHARE
	# --- the cell: what the height can pay for, capped by what the width can ---------------
	## Height: the top band, the board, the bench row and the band, plus the gaps and two
	## margins. The bench row is a SHARE of the cell, so the row and the board scale together.
	var avail_h := maxf(h - margin * 2.0 - top_h - top_gap - row_gap * 2.0 - band_h, 1.0)
	## Width: the bag column and the board side by side. The column the OFFERS used to live in is
	## still gone (D67) - they lie in the band under the board - and [B26] no column came back: the
	## shelf lies ON the board, over the enemy half (BrawlField.half_rect), so the cell is still
	## priced by the bag alone and a window that was height-bound stays height-bound.
	var avail_w := maxf(w - margin * 2.0 - BalanceUI.BRAWL_BAG_W - BalanceUI.BRAWL_BAG_GAP, 1.0)
	var edge := floorf(maxf(minf(avail_h / (float(Balance.ROWS) + bench_share),
		avail_w / float(Balance.COLS)), Balance.MIN_CELL_SIZE))
	var board_w := edge * float(Balance.COLS)
	var board_h := edge * float(Balance.ROWS)
	var bench_h := floorf(edge * bench_share)
	# --- where the stack sits: centred, so a tall window keeps the board in the middle ------
	var chrome_h := top_h + top_gap + board_h + row_gap + bench_h + row_gap + band_h
	var group_w := BalanceUI.BRAWL_BAG_W + BalanceUI.BRAWL_BAG_GAP + board_w
	var group_x := floorf((w - group_w) * 0.5)
	var top_y := floorf((h - chrome_h) * 0.5)
	var board_x := group_x + BalanceUI.BRAWL_BAG_W + BalanceUI.BRAWL_BAG_GAP
	var board_y := top_y + top_h + top_gap
	var bench_y := board_y + board_h + row_gap
	var band_y := bench_y + bench_h + row_gap

	var g := Geometry.new()
	g.size = Vector2(w, h)
	g.cell = edge
	g.board = Rect2(Vector2(board_x, board_y), Vector2(board_w, board_h))
	## The header is as wide as the whole group, so the title's left edge lines up with the bag
	## column and the status line's right edge with the BOARD's - on BOTH pages, which is what makes
	## the two screens read as one place (the arena leaves the side column empty).
	g.top_bar = Rect2(Vector2(group_x, top_y), Vector2(group_w, top_h))
	## The bag keeps the whole height of the stack: the board, the bench row and the band are all
	## beside it, so the column is exactly as tall as the page's field is.
	g.bag = Rect2(Vector2(group_x, board_y), Vector2(BalanceUI.BRAWL_BAG_W,
		board_h + row_gap + bench_h + row_gap + band_h))
	## [B26] THERE IS NO SHOP RECTANGLE HERE, and that is the change: the shelf lies over the
	## board's ENEMY half, which BrawlField.half_rect(SIDE_RIGHT) already owns (D11's 4|1|4). A second
	## rectangle holding the same four columns is how the page and the arena would stop agreeing about
	## where the enemy stands - so the page asks the arena's door, and this module keeps one board.
	g.bench = Rect2(Vector2(board_x, bench_y), Vector2(board_w, bench_h))
	g.bench_slot = Vector2(floorf(edge * BalanceUI.BRAWL_BENCH_SLOT_SHARE), bench_h)
	g.band = Rect2(Vector2(board_x, band_y), Vector2(board_w, band_h))
	## [B15] 遣散 sits at the band's LEFT end while 出战 keeps its right corner: the two ends of
	## the band are the two decisions, and the destructive one is deliberately as far as
	## possible from the one that commits the round. The offers give up the width (they are
	## three cards sharing what is left - see BrawlFormation._layout_columns).
	var dismiss_w := minf(BalanceUI.BRAWL_BAND_DISMISS_W, band_w_max(board_w))
	g.dismiss = Rect2(Vector2(board_x, band_y), Vector2(dismiss_w, band_h))
	## The band is the OFFER bar (D67): the three offers between the two action buttons, 出战
	## pinned to the right end so it lands in the board's bottom-right corner. [B26] It is NOT the
	## shop bar any more - the shelf lies on the board - so the band is the
	## round's choice of opponent and nothing else. The other three of D71's four action buttons
	## are deliberately NOT here - a view, an unequip and a move are gestures this page already
	## has; [B15] 遣散 is the one the user asked FOR a button.
	## [B27] ONE OF THE CELLS INSIDE this strip is the shelf's door (商店), and it has NO rectangle
	## here: it is a fixed-width cell BrawlFormation._layout_columns() carves off the strip it is
	## already given, exactly as that function divides the offers. A fifth Rect2 would be a second
	## owner of where the band's parts begin - the thing this module was written to prevent.
	var engage_w := minf(BalanceUI.BRAWL_BAND_ENGAGE_W, band_w_max(board_w))
	g.engage = Rect2(Vector2(board_x + board_w - engage_w, band_y), Vector2(engage_w, band_h))
	## The offers start where 遣散 ENDS rather than at the board's edge, and that is arithmetic
	## done once, FROM the rectangle above: a second copy of "where the band parts begin" is how
	## a card ends up drawn under a button.
	var offers_x := g.dismiss.position.x + g.dismiss.size.x + row_gap
	g.offers = Rect2(Vector2(offers_x, band_y),
		Vector2(maxf(0.0, g.engage.position.x - row_gap - offers_x), band_h))
	return g


static func board_rect() -> Rect2:
	## The ground a brawl stands on. BrawlField.arena_rect() returns THIS and nothing else, so
	## the arena and the formation page cannot disagree about where a cell is (D66).
	return board


static func cell_size() -> float:
	return cell


static func top_bar_rect() -> Rect2:
	return top_bar


static func bag_rect() -> Rect2:
	## The bag column, left of the board (O38 / D67: one column, tiles as wide as it is).
	return bag


static func bench_rect() -> Rect2:
	## The whole bench row: COLS slots at a pitch of one cell, starting at the board's own left
	## edge - the row still reads as a continuation of the board (D39).
	return bench


static func bench_slot_rect(p_slot: int) -> Rect2:
	## One slot's box. The PITCH is a whole cell (slot k sits under column k) while the box is
	## BRAWL_BENCH_SLOT_SHARE of it, so the slot stays centred under its own column (D69).
	if p_slot < 0 or p_slot >= BalanceBrawl.BENCH_SLOTS:
		return Rect2()
	return Rect2(Vector2(bench.position.x + float(p_slot) * cell + (cell - bench_slot.x) * 0.5,
		bench.position.y), bench_slot)


static func band_rect() -> Rect2:
	## The button band under the bench row: 遣散, the offers and 出战 (D67 / [B15]).
	return band


static func dismiss_rect() -> Rect2:
	## [B15] 遣散, at the band's own LEFT end (D90). One owner for the rectangle: the page places
	## its button with this, and the arena (which draws no band at all) never asks.
	return dismiss


static func offers_rect() -> Rect2:
	return offers


static func engage_rect() -> Rect2:
	## 出战 (or 逛商店), pinned to the band's right end - the same corner the board ends on.
	return engage


static func piece_scale() -> float:
	## [D72] HOW MUCH BIGGER A PIECE IS DRAWN THAN THE DESIGN BOX: the brawl's cell against the
	## design cell (Balance.CELL_SIZE, the one the art was measured for), clamped so a cramped or
	## an absurd window cannot turn a unit into a dot or a billboard. Unit.art_scale carries it.
	return clampf(cell / float(Balance.CELL_SIZE), BalanceUI.BRAWL_PIECE_SHARE_MIN,
		BalanceUI.BRAWL_PIECE_SHARE_MAX)


static func band_w_max(p_w: float) -> float:
	## ONE action button never eats more than a third of the band, and since [B15] there are two
	## of them (遣散 and 出战, one at each end): below that the three offers between them would be
	## unreadable in a window nobody should be running the game in anyway.
	return maxf(0.0, p_w / 3.0)


static func _apply(g: Geometry) -> void:
	size = g.size
	cell = g.cell
	board = g.board
	top_bar = g.top_bar
	bag = g.bag
	bench = g.bench
	bench_slot = g.bench_slot
	band = g.band
	dismiss = g.dismiss
	offers = g.offers
	engage = g.engage
