class_name Layout
extends RefCounted
## [P9] Runtime geometry: the one place that knows where things are drawn.
##
## Static-only, exactly like Balance / Difficulty / Fx - deliberately NOT an
## autoload, so nothing has to be registered in project.godot and every script can
## reach it with a plain `Layout.<name>`.
##
## Why it exists: project.godot uses stretch mode "canvas_items" with aspect
## "expand" (see docs/PLAN.md 3.4). The engine scales the whole 2D world with the
## window and EXPANDS the logical coordinate space along whichever axis the window
## is proportionally bigger, so the logical space is never smaller than
## Balance.WINDOW_SIZE (1280x720). Every fixed-size HUD value therefore stays valid
## as an absolute pixel value at any resolution; what has to adapt is the LAWN.
##
##   window ratio -> logical space
##     4:3   1280 x  960      16:9   1280 x 720 (design)      21:9   1680 x 720
##
## Lifecycle, driven by the Game autoload (there is no signal here on purpose):
##   Game._bootstrap()        Layout.refresh(viewport_size, window_size) + self_check()
##   Viewport.size_changed -> Game._on_viewport_resized()
##                            Layout.refresh(...)  -> true when the geometry moved
##                            then grid/hud/menu.on_layout_changed()
##
## Consumers read the static vars and helpers below. Nothing in here draws:
##   grid.gd / hud.gd / menu.gd read the vars; game_manager.gd drives refresh().
##
## Consumers read the static vars and helpers below. Nothing in here draws.

## Tolerance for the self-check, in logical pixels: derived coordinates are
## floored, so an exact comparison would produce false failures.
const EPSILON := 0.5

## Sampled window ratios for the startup self-check (target range 4:3 .. 21:9).
const RATIO_SAMPLES := [
	{"label": "5:4  ", "ratio": 5.0 / 4.0},
	{"label": "4:3  ", "ratio": 4.0 / 3.0},
	{"label": "16:10", "ratio": 16.0 / 10.0},
	{"label": "16:9 ", "ratio": 16.0 / 9.0},
	{"label": "2:1  ", "ratio": 2.0},
	{"label": "21:9 ", "ratio": 21.0 / 9.0},
]

# ---------------------------------------------------------------- derived shape
## [P82] D5: what compute_for() returns. It used to be an untyped Dictionary read
## with string keys by _apply() and _audit(), which had two failure modes worth
## removing at once: a misspelt key crashed at runtime, and - the worse one - a key
## that no reader ever asked for was completely invisible, so the geometry could
## carry a value nobody used (or lose one nobody copied out).
##
## Every field starts on a SENTINEL: NAN for the floats and for the Vector2/Rect2
## fields, UNSET_INT for the ints. compute_for() has to write each one to derive the
## geometry, so "was this field ever computed?" is answered by unset_fields() -
## which enumerates the declared fields through get_property_list() precisely so it
## cannot drift into a hand-kept list of names (the second-owner mistake P81 removed
## from Difficulty, docs/OPTIMIZATION_PLAN.md 5.38).
class Geometry:
	## card_rows is a card count and can never be negative, so -1 is unreachable.
	const UNSET_INT := -1

	var size := Vector2(NAN, NAN)             # logical viewport size
	var top_h := NAN                          # height of the top bar
	var bottom_y := NAN                       # y where the bottom bar starts
	var play := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))    # between the two bars
	var cell := NAN                           # lawn cell edge (square, whole pixels)
	var lawn_origin := Vector2(NAN, NAN)      # top-left corner of cell (0, 0)
	var lawn_size := Vector2(NAN, NAN)        # the whole board
	var cards_x := NAN                        # left edge of both card rows
	var card_size := Vector2(NAN, NAN)
	var card_gap := NAN
	var card_y := NAN                         # plant card row
	var tool_y := NAN                         # tool card row
	var label_x := NAN                        # the row-label column
	var label_w := NAN
	var end_turn := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var top_buttons := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var brain_zone := Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))
	var overlay_pos := Vector2(NAN, NAN)      # top-left corner of the result panel
	var hud_gap := NAN                        # gap between two top-bar readouts
	var card_rows: int = UNSET_INT

	func unset_fields() -> PackedStringArray:
		## The fields still wearing their sentinel, i.e. the ones compute_for()
		## never wrote. A field whose type has no sentinel shape is reported too:
		## an unlisted type must not get to skip this gate silently.
		var out: PackedStringArray = []
		for prop in get_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var field := str(prop["name"])
			var value: Variant = get(field)
			match typeof(value):
				TYPE_FLOAT:
					if is_nan(float(value)):
						out.append(field)
				TYPE_INT:
					if int(value) == UNSET_INT:
						out.append(field)
				TYPE_VECTOR2:
					var point: Vector2 = value
					if is_nan(point.x) or is_nan(point.y):
						out.append(field)
				TYPE_RECT2:
					var box: Rect2 = value
					if is_nan(box.position.x) or is_nan(box.position.y) \
							or is_nan(box.size.x) or is_nan(box.size.y):
						out.append(field)
				_:
					out.append(field + " [type " + type_string(typeof(value))
						+ " has no sentinel shape here]")
		return out


# ---------------------------------------------------------------- live geometry
static var size := Vector2(Balance.WINDOW_SIZE)     # logical viewport size
static var window_size := Vector2i.ZERO              # real window size (logging only)
static var top_h := Balance.HUD_TOP_HEIGHT           # height of the top bar
static var bottom_y := Balance.HUD_BOTTOM_Y          # y where the bottom bar starts
static var cell := float(Balance.CELL_SIZE)          # lawn cell edge (square, whole pixels)
static var lawn_origin := Balance.LAWN_ORIGIN        # top-left corner of cell (0, 0)
static var cards_x := 0.0                            # left edge of both card rows
static var card_size := BalanceUI.CARD_SIZE
static var card_gap := BalanceUI.CARD_GAP
static var card_y := 0.0                             # plant card row
static var tool_y := 0.0                             # tool card row
static var label_x := 0.0                            # "SCROLLS" / "TOOLS" column
static var label_w := BalanceUI.ROW_LABEL_WIDTH
static var end_turn := Rect2()                       # END TURN, always spans both card rows
static var top_buttons := Rect2()                    # [P13] SETTINGS + RETREAT, top right
static var brain_zone := Rect2()
static var overlay_pos := Vector2.ZERO               # top-left corner of the result panel
static var hud_gap := BalanceUI.HUD_LINE_GAP           # gap between two top-bar readouts

static var _booted := false


# ---------------------------------------------------------------- public API
static func refresh(p_viewport: Vector2, p_window: Vector2i = Vector2i.ZERO) -> bool:
	## Re-derives every rectangle from the real viewport size. Returns true when
	## the geometry actually moved, so the caller knows to re-place its controls.
	if p_window != Vector2i.ZERO:
		window_size = p_window
	if p_viewport.x < 1.0 or p_viewport.y < 1.0:
		return false
	if _booted and p_viewport.is_equal_approx(size):
		return false
	var first := not _booted
	_booted = true
	_apply(compute_for(p_viewport))
	# the very first pass is reported by self_check() instead
	if Balance.LAYOUT_LOG_RESIZE and not first:
		print("[Layout] " + geometry_line())
	return true


static func lawn_rect() -> Rect2:
	return Rect2(lawn_origin, Vector2(cell * float(Balance.COLS), cell * float(Balance.ROWS)))


static func banner_pos() -> Vector2:
	## Centre of the round banner, just under the top bar.
	return Vector2(size.x * 0.5, BalanceUI.BANNER_Y)


static func result_button_pos(p_index: int, p_count: int, p_size: Vector2) -> Vector2:
	## Result-panel buttons (RESTART, MAIN MENU) sit side by side, centred.
	var count := maxi(p_count, 1)
	var gap := BalanceUI.RESULT_BUTTON_GAP
	var total := p_size.x * float(count) + gap * float(count - 1)
	var x := overlay_pos.x + (BalanceUI.OVERLAY_PANEL_SIZE.x - total) * 0.5
	var row_y := overlay_pos.y + BalanceUI.OVERLAY_PANEL_SIZE.y - p_size.y
	row_y -= BalanceUI.OVERLAY_RESTART_BOTTOM_MARGIN
	return Vector2(x + float(p_index) * (p_size.x + gap), row_y)


static func top_button_pos(p_index: int, p_count: int, p_size: Vector2) -> Vector2:
	## [P13] The in-battle corner buttons, laid out from the RIGHT edge of the box
	## reserved in the top bar, so index 0 is the leftmost of them.
	var count := maxi(p_count, 1)
	var gap := BalanceUI.TOP_BUTTON_GAP
	var total := p_size.x * float(count) + gap * float(count - 1)
	var x := top_buttons.position.x + top_buttons.size.x - total
	return Vector2(x + float(p_index) * (p_size.x + gap), top_buttons.position.y)


static func top_bar_text_right() -> float:
	## Where the right aligned readouts in the top bar must stop: short of the
	## corner buttons, otherwise "next wave" would be drawn under them.
	return top_buttons.position.x - BalanceUI.HUD_LINE_GAP


static func geometry_line() -> String:
	## "viewport" is the LOGICAL space the game draws in, "window" is the real
	## window size: the two differ whenever the engine scales the canvas, which is
	## the quickest way to confirm from a log that the stretch mode is active.
	## [P20] The labels are translated (it is shown in the SETTINGS hint too), the
	## numbers - the only part that matters - are not.
	var lawn := lawn_rect().size
	var line := Loc.tf("ui.geometry.viewport", [int(size.x), int(size.y)])
	if window_size != Vector2i.ZERO:
		line += Loc.tf("ui.geometry.window", [window_size.x, window_size.y])
	line += Loc.tf("ui.geometry.cell", [int(cell)])
	line += Loc.tf("ui.geometry.lawn", [int(lawn.x), int(lawn.y)])
	line += Loc.tf("ui.geometry.origin", [int(lawn_origin.x), int(lawn_origin.y)])
	return line


# ---------------------------------------------------------------- the maths
static func logical_size_for(p_ratio: float) -> Vector2:
	## Mirrors what Window does for content_scale_aspect = EXPAND: the design box
	## keeps its shorter axis and the other one grows to match the window ratio.
	var base := Vector2(Balance.WINDOW_SIZE)
	var base_ratio := base.x / base.y
	if p_ratio >= base_ratio:
		return Vector2(floorf(base.y * p_ratio), base.y)
	return Vector2(base.x, floorf(base.x / p_ratio))


static func compute_for(p_size: Vector2) -> Geometry:
	## Pure: logical size in, every derived rectangle out. No node access, which
	## is what lets the self-check audit arbitrary window ratios at startup.
	## Local names deliberately differ from the static vars: a local that shadows
	## one would show up as a warning in the editor's error panel.
	var w := maxf(p_size.x, 1.0)
	var h := maxf(p_size.y, 1.0)
	var bar_top := Balance.HUD_TOP_HEIGHT
	var bar_bottom := h - Balance.HUD_BOTTOM_HEIGHT
	var play_h := maxf(bar_bottom - bar_top, 1.0)

	# --- lawn: square cells as large as the free area allows -------------------
	var avail_h := maxf(play_h - 2.0 * Balance.BOARD_PAD, 1.0)
	var avail_w := maxf(w - Balance.BOARD_LEFT_CHROME - Balance.BOARD_RIGHT_PAD, 1.0)
	var edge := floorf(maxf(minf(avail_h / float(Balance.ROWS), avail_w / float(Balance.COLS)),
		Balance.MIN_CELL_SIZE))
	var board := Vector2(edge * float(Balance.COLS), edge * float(Balance.ROWS))
	# centre the whole group (left chrome + lawn + right pad) so wide windows stay balanced
	var group_x := floorf((w - (Balance.BOARD_LEFT_CHROME + board.x + Balance.BOARD_RIGHT_PAD)) * 0.5)
	var lawn_pos := Vector2(group_x + Balance.BOARD_LEFT_CHROME,
		floorf(bar_top + (play_h - board.y) * 0.5))

	# --- bottom bar: two card rows + END TURN spanning both --------------------
	## [P37] The rail is as wide as the DECK, not as the ROSTER. It used to read
	## plant_cards().size(), which was still correct while the roster held three cards;
	## Game.battle_cards() (P34) now hands the HUD at most BATTLE_DECK_SLOTS of them,
	## so measuring the roster reserved room for 13 cards, drove the shrink branch in
	## every window (cards pinned at MIN_CARD_WIDTH) and made [Layout] self-check
	## report "cards collide with END TURN" at every aspect ratio while nothing on
	## screen actually collided.
	var rows: int = maxi(BalanceBattle.BATTLE_DECK_SLOTS, BalanceBattle.TOOL_CARDS.size())
	var card_box := BalanceUI.CARD_SIZE
	var end_size := Vector2(BalanceUI.END_TURN_SIZE.x, card_box.y * 2.0 + BalanceUI.CARD_ROW_GAP)
	var end_pos := Vector2(w - BalanceUI.END_TURN_MARGIN - end_size.x,
		bar_bottom + BalanceUI.CARD_ROW_TOP_OFFSET)
	var cards_left := lawn_pos.x        # the cards line up with the lawn, like the design
	var gaps := float(rows - 1) * BalanceUI.CARD_GAP
	var cards_span := float(rows) * card_box.x + gaps
	if cards_left + cards_span + BalanceUI.CARD_END_TURN_GAP > end_pos.x:
		# narrow window: shrink the cards instead of letting them reach END TURN
		var room := end_pos.x - BalanceUI.CARD_END_TURN_GAP - cards_left - gaps
		card_box.x = maxf(BalanceUI.MIN_CARD_WIDTH, floorf(room / float(rows)))
	var cards_top := bar_bottom + BalanceUI.CARD_ROW_TOP_OFFSET
	var label_box_w := BalanceUI.ROW_LABEL_WIDTH
	var label_left := maxf(BalanceUI.HUD_SIDE_MARGIN, cards_left - BalanceUI.ROW_LABEL_GAP - label_box_w)

	# --- brain zone marker, left of column 0 on the MVP row -------------------
	var brain_x := lawn_pos.x - Balance.BRAIN_ZONE_GAP - Balance.BRAIN_ZONE_WIDTH
	var brain_y := lawn_pos.y + float(Balance.MVP_ROW) * edge
	var brain_box := Rect2(Vector2(brain_x, brain_y), Vector2(Balance.BRAIN_ZONE_WIDTH, edge))

	# --- in-battle corner buttons, top right (P13) ----------------------------
	var top_size := BalanceUI.TOP_BUTTON_SIZE
	var top_count := BalanceUI.TOP_BUTTON_COUNT
	var top_span := top_size.x * float(top_count) + BalanceUI.TOP_BUTTON_GAP * float(top_count - 1)
	var top_at := Vector2(w - BalanceUI.TOP_BUTTON_MARGIN - top_span,
		floorf((bar_top - top_size.y) * 0.5))
	var top_box := Rect2(top_at, Vector2(top_span, top_size.y))

	# --- result panel, centred; its fixed size always fits the logical space ---
	var overlay_at := Vector2(floorf((w - BalanceUI.OVERLAY_PANEL_SIZE.x) * 0.5),
		floorf((h - BalanceUI.OVERLAY_PANEL_SIZE.y) * 0.5))

	var g := Geometry.new()
	g.size = Vector2(w, h)
	g.top_h = bar_top
	g.bottom_y = bar_bottom
	g.play = Rect2(0.0, bar_top, w, play_h)
	g.cell = edge
	g.lawn_origin = lawn_pos
	g.lawn_size = board
	g.cards_x = cards_left
	g.card_size = card_box
	g.card_gap = BalanceUI.CARD_GAP
	g.card_y = cards_top
	g.tool_y = cards_top + card_box.y + BalanceUI.CARD_ROW_GAP
	g.label_x = label_left
	g.label_w = label_box_w
	g.end_turn = Rect2(end_pos, end_size)
	g.top_buttons = top_box
	g.brain_zone = brain_box
	g.overlay_pos = overlay_at
	g.hud_gap = clampf(w * BalanceUI.HUD_GAP_RATIO, BalanceUI.HUD_LINE_GAP, BalanceUI.HUD_GAP_MAX)
	g.card_rows = rows
	return g


static func _apply(g: Geometry) -> void:
	## [P82] play / lawn_size / card_rows are deliberately NOT copied out: they are
	## audit-and-print only, which is exactly the fact the old Dictionary could not
	## state. A new field must be written by compute_for() or unset_fields() reports
	## it, so "nobody copies this out" can no longer be silent either.
	size = g.size
	top_h = g.top_h
	bottom_y = g.bottom_y
	cell = g.cell
	lawn_origin = g.lawn_origin
	cards_x = g.cards_x
	card_size = g.card_size
	card_gap = g.card_gap
	card_y = g.card_y
	tool_y = g.tool_y
	label_x = g.label_x
	label_w = g.label_w
	end_turn = g.end_turn
	top_buttons = g.top_buttons
	brain_zone = g.brain_zone
	overlay_pos = g.overlay_pos
	hud_gap = g.hud_gap


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game. Log lines are built with concatenation or
	## with one "%" expression per physical line on purpose (docs/HANDOFF.md 7.1).
	print("[Layout] --- responsive geometry (canvas_items + expand) ---")
	print("[Layout] design canvas %dx%d" % [Balance.WINDOW_SIZE.x, Balance.WINDOW_SIZE.y])
	print("[Layout] min window    %dx%d" % [Balance.MIN_WINDOW_SIZE.x, Balance.MIN_WINDOW_SIZE.y])
	var ok := true
	for entry in RATIO_SAMPLES:
		var live := logical_size_for(float(entry["ratio"]))
		var m := compute_for(live)
		var fails := _audit(m)
		var good: bool = fails.is_empty()
		ok = ok and good
		var play := m.play
		var lawn_box := m.lawn_size
		var lawn_at := m.lawn_origin
		var line := "[Layout] " + str(entry["label"])
		line += "  logical %4dx%4d" % [int(live.x), int(live.y)]
		line += "  play %4dx%4d" % [int(live.x), int(play.size.y)]
		line += "  cell %3d" % int(m.cell)
		line += "  lawn %3dx%3d" % [int(lawn_box.x), int(lawn_box.y)]
		line += " @ (%4d,%4d)" % [int(lawn_at.x), int(lawn_at.y)]
		line += "  | " + ("OK" if good else "FAIL")
		print(line)
		for f in fails:
			print("[Layout]        -> " + f)

	# design regression: 16:9 must still reproduce the hand-tuned board
	var design := compute_for(Vector2(Balance.WINDOW_SIZE))
	var design_lawn := design.lawn_size
	var design_at := design.lawn_origin
	var want_lawn := Vector2(float(Balance.CELL_SIZE) * float(Balance.COLS),
		float(Balance.CELL_SIZE) * float(Balance.ROWS))
	var design_cell_ok: bool = int(design.cell) == Balance.CELL_SIZE
	var design_lawn_ok: bool = design_lawn.is_equal_approx(want_lawn)
	var design_cards_ok: bool = is_equal_approx(design.cards_x, design_at.x)
	var design_ok: bool = design_cell_ok and design_lawn_ok and design_cards_ok
	ok = ok and design_ok
	print("[Layout] 16:9 design board (cell " + str(Balance.CELL_SIZE) + ", cards aligned to the lawn) = "
		+ str(design_ok) + " | " + ("OK" if design_ok else "FAIL"))

	# informational: the window that is actually open may sit outside the samples
	var live_fails := _audit(compute_for(size))
	print("[Layout] current window " + geometry_line() + " | "
		+ ("OK" if live_fails.is_empty() else "see below"))
	for f in live_fails:
		print("[Layout]        -> " + f)
	print("[Layout] self-check %s" % ("PASSED" if ok else "FAILED"))


static func _audit(g: Geometry) -> PackedStringArray:
	## Invariants that must hold at every window size the engine can produce.
	## EPSILON absorbs the flooring of the derived coordinates.
	var fails: PackedStringArray = []
	## [P82] Asked before any geometry question, because a field nobody derived is
	## the one mistake that used to be invisible: every other check reads a *pair*
	## of numbers, so a stale or missing value could sit inside the tolerance and
	## look fine. This one cannot - it is a statement about completeness, not size.
	for field in g.unset_fields():
		fails.append("field \"" + str(field) + "\" was never derived")
	var box := g.size
	var bar_top := g.top_h
	var bar_bottom := g.bottom_y
	var edge := g.cell
	var lawn_at := g.lawn_origin
	var lawn_box := g.lawn_size
	var card_box := g.card_size
	var cards_left := g.cards_x
	var cards_top := g.card_y
	var tools_top := g.tool_y
	var label_left := g.label_x
	var label_box_w := g.label_w
	var end_box := g.end_turn
	var top_box := g.top_buttons
	var brain_box := g.brain_zone
	var overlay_at := g.overlay_pos
	var rows := g.card_rows

	if edge < Balance.MIN_CELL_SIZE - EPSILON:
		fails.append("cell %d is below the minimum" % int(edge))
	if lawn_at.y < bar_top - EPSILON or lawn_at.y + lawn_box.y > bar_bottom + EPSILON:
		fails.append("lawn leaves the play area vertically")
	if lawn_at.x - Balance.BOARD_LEFT_CHROME < -EPSILON:
		fails.append("left chrome (brain zone) pushed off screen")
	if lawn_at.x + lawn_box.x + Balance.BOARD_RIGHT_PAD > box.x + EPSILON:
		fails.append("lawn reaches the right edge")
	if brain_box.position.x + brain_box.size.x > lawn_at.x + EPSILON:
		fails.append("brain zone overlaps column 0")
	if brain_box.position.x < -EPSILON:
		fails.append("brain zone off screen")
	if label_left < BalanceUI.HUD_SIDE_MARGIN - EPSILON:
		fails.append("card row label pushed off screen")
	if label_left + label_box_w + BalanceUI.ROW_LABEL_GAP > cards_left + EPSILON:
		fails.append("card row label overlaps the cards")
	var cards_end := cards_left + float(rows) * card_box.x + float(rows - 1) * BalanceUI.CARD_GAP
	if cards_end > end_box.position.x - BalanceUI.CARD_END_TURN_GAP + EPSILON:
		fails.append("cards collide with END TURN")
	if not is_equal_approx(end_box.size.y, card_box.y * 2.0 + BalanceUI.CARD_ROW_GAP):
		fails.append("END TURN does not span both card rows")
	if cards_top < bar_bottom - EPSILON:
		fails.append("card rows overlap the lawn area")
	if tools_top + card_box.y > box.y - EPSILON:
		fails.append("tool row leaves the bottom bar")
	var panel_end := overlay_at + BalanceUI.OVERLAY_PANEL_SIZE
	var panel_out := overlay_at.x < -EPSILON or overlay_at.y < -EPSILON
	panel_out = panel_out or panel_end.x > box.x + EPSILON or panel_end.y > box.y + EPSILON
	if panel_out:
		fails.append("result panel does not fit")
	# [P13] the corner buttons must stay inside the top bar and on screen
	if top_box.position.x < BalanceUI.HUD_SIDE_MARGIN - EPSILON:
		fails.append("top corner buttons leave the screen")
	if top_box.position.y < -EPSILON or top_box.position.y + top_box.size.y > bar_top + EPSILON:
		fails.append("top corner buttons leave the top bar")
	if top_box.position.x + top_box.size.x > box.x - EPSILON:
		fails.append("top corner buttons are pushed off the right edge")
	return fails
