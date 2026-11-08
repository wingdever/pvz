class_name ItemGrid
extends Control
## [P22] A wrapping grid of ItemTile cells.
##
## The host gives it a box (position + size) and a list of rows; this class pools
## the cells, lays them out and reports which one was clicked. A row is a plain
## dictionary, the same shape in all three screens:
##
##   {id, title, art, badge, note, dimmed, badge_color}
##
## The cells SHRINK (down to BalanceUI.ITEM_TILE_MIN_SCALE) when the rows would not fit
## the box, so a full warehouse (12 kinds) and a two-item backpack both fill their
## space deliberately instead of one of them needing a scrollbar. The maths lives in
## fit_for(), a pure function, which is what lets self_check() audit it at start-up
## without opening a screen (same idea as Layout.compute_for).
##
## [P27] A HOST may override three things, which is what lets the almanac show eight
## smaller cells per row while the warehouse / shop / backpack keep the shared ones:
##
##   tile_size   the cell box (default BalanceUI.ITEM_TILE_SIZE)
##   max_cols    the widest row this grid may build (default ITEM_GRID_MAX_COLS)
##   top_align   fill the box from its top edge instead of centring the block in it
##
## All three keep their default, so not one of the existing screens changes.
##
## [P42] A host may also ask for PAGES (`paged = true`). The item kinds grew past what any
## of the boxes holds at a readable size - the warehouse box fits 12 cells, the bag fewer -
## and the shrink floor stops the old trick of squeezing more in. A paged grid therefore
## keeps the WHOLE row list, shows one page of it, and spends the bottom strip of its own
## box on PREV / "2 / 5" / NEXT. The page a selection lives on is what show_items() opens
## (selling an item keeps it on screen), and turn_page() moves the selection to the page it
## lands on and reports it through the same picked() signal a click uses, so no host has to
## track a second notion of "what is selected". The almanac pages in its own file because
## it also owns its tabs; every item host gets it from here instead of writing it twice.

signal picked(id: String)

var selected_id: String = ""

var tile_size: Vector2 = BalanceUI.ITEM_TILE_SIZE
var max_cols: int = BalanceUI.ITEM_GRID_MAX_COLS
var top_align: bool = false
var paged: bool = false                # [P42] see the note above

var _tiles: Array = []                 # ItemTile pool, reused across refreshes
var _rows: Array = []                  # the page on screen (the whole list when unpaged)
var _all_rows: Array = []              # [P42] everything show_items() was handed
var _page := 0
var _prev_btn: Button = null           # [P42] the page bar, built by _ready() when paged
var _next_btn: Button = null
var _page_label: Label = null


func _init() -> void:
	## The cells handle their own clicks, so the grid itself stays transparent: a
	## click on the empty area around them must not be swallowed.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


# ---------------------------------------------------------------- public API
func show_items(p_rows: Array, p_selected: String = "") -> void:
	## Rebuilds the cells from scratch. Called on open, after every action and after
	## a live language switch, so a screen can never show a stale list or language.
	##
	## [P42] A paged grid keeps the WHOLE list and paints one page of it, opening on the
	## page that holds p_selected: selling the last of a stack must not hide the row the
	## panel is describing. The slice itself happens in relayout(), because the page size
	## is a property of the BOX (see _apply_page) and the host may not have sized us yet.
	_all_rows = p_rows
	_rows = p_rows
	selected_id = p_selected
	if paged:
		_page = maxi(_page_of(p_selected, maxi(capacity(), 1)), 0)
	relayout()


func select(p_id: String) -> void:
	## Cheap selection change: no art is re-loaded, only the frames are repainted.
	##
	## [P42] One exception: a paged grid whose target is on ANOTHER page cannot repaint a
	## cell that is not there, so it turns the page instead. A host that asks for an entry
	## should never end up with a selection the player cannot see. The lookup only runs
	## for a paged grid - an unpaged host (the almanac) keeps the O(1) repaint it had.
	if paged:
		var want := _page_of(p_id, maxi(capacity(), 1))
		if want >= 0 and want != _page:
			selected_id = p_id
			_page = want
			relayout()
			return
	selected_id = p_id
	_refresh_selection()


func relayout() -> void:
	## Places the cells inside the box the host gave us (size is owned by the host).
	##
	## [P42] A paged grid re-slices and repaints its cells here rather than in
	## show_items(): the host resizes this box without re-reading the list, and the page
	## size is derived from the box, so "how many cells is this page" can change with a
	## window drag. Syncing every time is affordable - the art is cached by UnitArt and
	## the almanac has done exactly this since P28.
	if paged:
		_ensure_page_bar()
		_apply_page()
	_sync_tiles()
	var m := fit_for(cell_area(), _rows.size(), tile_size, max_cols)
	var cols := int(m["cols"])
	var tile_box: Vector2 = m["tile"]
	var gap: float = BalanceUI.ITEM_TILE_GAP
	var x0: float = m["x0"]
	## [P27] With top_align the first row touches the top edge of the box: the almanac
	## wants its cells right under the tabs whatever the tab holds. Without it the block
	## stays centred, which is what the warehouse / shop / backpack have always done.
	var y0: float = 0.0 if top_align else float(m["y0"])
	for i in _rows.size():
		if i >= _tiles.size():
			break
		var tile := _tiles[i] as ItemTile
		if tile == null:
			continue
		var column := i % maxi(cols, 1)
		## [P109] floori on a float division: the row INDEX wants the truncation, but a bare
		## `int / int` is what the editor's INTEGER_DIVISION warning points at - it cannot
		## tell an intended truncation from a lost fraction. Same spelling as garden_plot._mmss.
		var row := floori(float(i) / float(maxi(cols, 1)))
		tile.position = Vector2(x0 + float(column) * (tile_box.x + gap),
			y0 + float(row) * (tile_box.y + gap))
		tile.custom_minimum_size = tile_box
		tile.size = tile_box
	if paged:
		_place_page_bar()


# ---------------------------------------------------------------- [P42] paging
func cell_area() -> Vector2:
	## [P42] The box the CELLS may use: the host's box minus the page bar strip. Unpaged
	## that is the whole box, so not one existing screen changes its geometry.
	if not paged:
		return size
	return page_cell_area(size)


static func page_cell_area(p_box: Vector2) -> Vector2:
	## [P42] PURE twin of the branch above, so self_check() can audit the strip it is
	## about to promise the bar without putting a grid on screen (the same reason fit_for()
	## and capacity_for() are static).
	##
	## The floor keeps one shrunk row alive in a box too short for the bar's promise -
	## better a tight page than a grid with no room to draw at all.
	return Vector2(p_box.x, maxf(p_box.y
			- BalanceUI.ITEM_PAGE_BAR_H - BalanceUI.ITEM_PAGE_GAP,
		BalanceUI.ITEM_TILE_SIZE.y * BalanceUI.ITEM_TILE_MIN_SCALE))


func capacity() -> int:
	## [P42] How many cells THIS box holds at the full cell size, i.e. the page size.
	## The same pure function a hand-paged host already asks (capacity_for), so the grid
	## and the almanac can never disagree about what a page is.
	return capacity_for(cell_area(), tile_size, max_cols)


func page_count() -> int:
	## [P42] Always at least 1: a list that fits one page is a one-page grid, and the bar
	## then reads "1 / 1" with both buttons disabled - which is how the player learns the
	## bag is not hiding anything.
	return pages_for(_all_rows.size(), capacity())


static func pages_for(p_count: int, p_capacity: int) -> int:
	## [P42] PURE twin of page_count(): how many pages `p_count` rows need at `p_capacity`
	## rows per page. `capacity` is never trusted to be positive - a zero-size box would
	## otherwise divide the whole audit into infinity.
	return maxi(1, int(ceil(float(maxi(p_count, 0)) / float(maxi(p_capacity, 1)))))


func page() -> int:
	return _page


func turn_page(p_delta: int) -> void:
	## [P42] One page left or right, shared by the two buttons and the host's mouse wheel.
	## Nothing happens at either end (the buttons are disabled there anyway).
	##
	## The selection follows the page rather than the page following the selection: an
	## off-screen entry must never be the one the detail panel describes. The host learns
	## of it through the SAME picked() signal a click uses, so no screen has to keep a
	## second notion of "what is selected" in step with this grid.
	var cap := maxi(capacity(), 1)
	var want := clampi(_page + p_delta, 0, page_count() - 1)
	if want == _page:
		return
	var before := selected_id
	_page = want
	var start := want * cap
	if start < _all_rows.size():
		if _page_of(selected_id, cap) != want:
			selected_id = str((_all_rows[start] as Dictionary).get("id", ""))
	relayout()
	if selected_id != before and selected_id != "":
		picked.emit(selected_id)


func _apply_page() -> void:
	## [P42] Cuts _all_rows down to the page that is actually on screen, and keeps that
	## page honest about the selection. Two rules in one place, because both are about
	## "does the box still agree with the page index we hold":
	##   - a RESIZE may change how many cells a page holds, so the selected id is followed
	##     to whatever page now holds it (otherwise the panel would describe off-screen
	##     rows, and the old centred block used to simply overflow);
	##   - a page TURN has already re-targeted the selection (turn_page), so following it
	##     here is a no-op and can never pull the turn back.
	## An id that left the list entirely (sold out) keeps the page and hands the selection
	## to that page's first cell.
	var cap := maxi(capacity(), 1)
	var hold := _page_of(selected_id, cap)
	if hold >= 0:
		_page = hold
	_page = clampi(_page, 0, page_count() - 1)
	var start := _page * cap
	_rows = _all_rows.slice(start, mini(start + cap, _all_rows.size()))
	var on_page := false
	for row in _rows:
		if str((row as Dictionary).get("id", "")) == selected_id:
			on_page = true
			break
	if not _rows.is_empty() and not on_page:
		selected_id = str((_rows[0] as Dictionary).get("id", ""))


func _page_of(p_id: String, p_capacity: int) -> int:
	## [P42] Which page holds this id, or -1 for "nothing selected / it is not in the
	## list". A lookup, never a guess: a stale id must not silently pick a page.
	if p_id == "":
		return -1
	var cap := maxi(p_capacity, 1)
	for i in _all_rows.size():
		if str((_all_rows[i] as Dictionary).get("id", "")) == p_id:
			## [P109] The page index is a truncation on purpose; floori spells it out
			## instead of tripping INTEGER_DIVISION (see _layout_rows).
			return floori(float(i) / float(cap))
	return -1


func _ensure_page_bar() -> void:
	## [P42] Built on the first paged re-layout rather than in _ready(): that way the host
	## may set `paged` at any point before it starts showing items, and a grid that never
	## pages (the almanac, which pages in its own file) never creates three nodes it will
	## not use.
	if _prev_btn != null or not paged:
		return
	_prev_btn = _make_page_button(_on_page_pressed.bind(-1))
	_next_btn = _make_page_button(_on_page_pressed.bind(1))
	_page_label = UiStyle.make_label("", BalanceUI.COLOR_TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER, BalanceUI.FONT_SIZE_MENU_SUB)
	add_child(_page_label)


func _make_page_button(p_pressed: Callable) -> Button:
	## The same skin every other button on these screens wears, so PREV looks like the
	## buttons above it and not like a third kind of control. FOCUS_ALL for the same
	## reason: the wheel and the two captions are the mouse way, the tab key is the
	## keyboard way, and paging must not need a pointer (the CELLS stay unfocusable -
	## see item_tile.gd - but turning a page is a control, not a selection).
	## [P73] The twelve lines that used to sit here are UiStyle.make_button()'s now, shared
	## with the five other screens that hand-rolled the same skin.
	return UiStyle.make_button(self, "", p_pressed)


func _place_page_bar() -> void:
	## [P42] The strip sits at the BOTTOM EDGE of the host's box, and the three pieces are
	## centred as one row: PREV / "2 / 5" / NEXT never overlap each other and never leave
	## the box, whatever the window does. A box narrower than the bar's design width sheds
	## the pieces proportionally, but keeps all three - the count is how the player knows
	## there IS a next page, so it is the last thing to go.
	var bar_h: float = BalanceUI.ITEM_PAGE_BAR_H
	var gap: float = BalanceUI.ITEM_PAGE_GAP
	var btn_w: float = BalanceUI.ITEM_PAGE_BTN_W
	var label_w: float = BalanceUI.ITEM_PAGE_LABEL_W
	var total := btn_w * 2.0 + label_w + gap * 2.0
	if total > size.x and total > 0.0:
		var k := maxf(size.x / total, 0.0)
		btn_w = maxf(btn_w * k, 24.0)
		label_w = maxf(label_w * k, 40.0)
		total = btn_w * 2.0 + label_w + gap * 2.0
	var top := maxf(size.y - bar_h, 0.0)
	var x0 := maxf((size.x - total) * 0.5, 0.0)
	_prev_btn.position = Vector2(x0, top)
	_prev_btn.size = Vector2(btn_w, bar_h)
	_page_label.position = Vector2(x0 + btn_w + gap, top)
	_page_label.size = Vector2(label_w, bar_h)
	_next_btn.position = Vector2(x0 + btn_w + gap + label_w + gap, top)
	_next_btn.size = Vector2(btn_w, bar_h)
	_update_page_bar()


func _update_page_bar() -> void:
	## Re-read on every placement, which is also what makes a live language switch change
	## the two captions: every host re-shows its rows when the language flips.
	_prev_btn.text = Loc.t("grid.page.prev")
	_next_btn.text = Loc.t("grid.page.next")
	_page_label.text = Loc.tf("grid.page", [_page + 1, page_count()])
	_prev_btn.disabled = _page <= 0
	_next_btn.disabled = _page >= page_count() - 1


func _on_page_pressed(p_delta: int) -> void:
	turn_page(p_delta)


# ---------------------------------------------------------------- the maths
static func design_area() -> Vector2:
	## The box the item screens reserve for the grid at the design window size.
	return Vector2(float(BalanceUI.ITEM_GRID_COLS) * BalanceUI.ITEM_TILE_SIZE.x
			+ float(BalanceUI.ITEM_GRID_COLS - 1) * BalanceUI.ITEM_TILE_GAP,
		float(BalanceUI.ITEM_GRID_ROWS) * BalanceUI.ITEM_TILE_SIZE.y
			+ float(BalanceUI.ITEM_GRID_ROWS - 1) * BalanceUI.ITEM_TILE_GAP)


static func fit_for(p_area: Vector2, p_count: int, p_tile_size: Vector2 = Vector2.ZERO,
		p_max_cols: int = 0) -> Dictionary:
	## Pure: "this box and this many cells" in, the whole grid geometry out.
	## The shrink loop is bounded by ITEM_GRID_FIT_PASSES and the scale only ever
	## decreases, so it always terminates. `rows` is 0 for an empty grid.
	##
	## [P27] p_tile_size / p_max_cols let a host build a grid of OTHER cells than the
	## shared item ones (the almanac's eight per row). Zero means "the default": a
	## default argument cannot read another class's const, so zero IS the sentinel,
	## and every caller that passes nothing gets exactly the old behaviour.
	var cell: Vector2 = p_tile_size if p_tile_size.x > 0.0 else BalanceUI.ITEM_TILE_SIZE
	var col_cap: int = p_max_cols if p_max_cols > 0 else BalanceUI.ITEM_GRID_MAX_COLS
	var gap: float = BalanceUI.ITEM_TILE_GAP
	var count := maxi(p_count, 0)
	var grid_scale := 1.0
	var cols := 1
	var rows := 0
	var attempts := 0
	while attempts < BalanceUI.ITEM_GRID_FIT_PASSES and count > 0:
		attempts += 1
		var tw := cell.x * grid_scale
		var th := cell.y * grid_scale
		cols = clampi(int(floor((p_area.x + gap) / maxf(tw + gap, 1.0))), 1, col_cap)
		cols = maxi(1, mini(cols, count))
		rows = int(ceil(float(count) / float(cols)))
		var needed := float(rows) * th + float(rows - 1) * gap
		if needed <= p_area.y + 0.5 or grid_scale <= BalanceUI.ITEM_TILE_MIN_SCALE:
			break
		grid_scale = clampf(grid_scale * (p_area.y / needed), BalanceUI.ITEM_TILE_MIN_SCALE, 1.0)
	var tile_box := Vector2(floorf(cell.x * grid_scale), floorf(cell.y * grid_scale))
	var block := Vector2(0.0, 0.0)
	if count > 0:
		block = Vector2(float(cols) * tile_box.x + float(cols - 1) * gap,
			float(rows) * tile_box.y + float(maxi(rows - 1, 0)) * gap)
	return {
		"cols": cols,
		"rows": rows,
		"tile": tile_box,
		"block": block,
		"scale": grid_scale,
		"x0": floorf(maxf((p_area.x - block.x) * 0.5, 0.0)),
		"y0": floorf(maxf((p_area.y - block.y) * 0.5, 0.0)),
	}


static func capacity_for(p_area: Vector2, p_tile_size: Vector2 = Vector2.ZERO,
		p_max_cols: int = 0) -> int:
	## [P28] How many cells of the FULL size one screen of this box holds - the first pass
	## of fit_for() WITHOUT the shrink loop. A host that TURNS A PAGE (the almanac) has to
	## know that before it knows how many pages there are, and it must not be a second copy
	## of the arithmetic: self_check() asserts the two agree at exactly this count.
	##
	## Same sentinels as fit_for(): a zero tile size / column cap means "the shared
	## default", because a default argument cannot read another class's const.
	var cell: Vector2 = p_tile_size if p_tile_size.x > 0.0 else BalanceUI.ITEM_TILE_SIZE
	var col_cap: int = p_max_cols if p_max_cols > 0 else BalanceUI.ITEM_GRID_MAX_COLS
	var gap: float = BalanceUI.ITEM_TILE_GAP
	var cols := clampi(int(floor((p_area.x + gap) / maxf(cell.x + gap, 1.0))), 1, col_cap)
	var rows := maxi(1, int(floor((p_area.y + gap) / maxf(cell.y + gap, 1.0))))
	return cols * rows


# ---------------------------------------------------------------- internals
func _sync_tiles() -> void:
	while _tiles.size() < _rows.size():
		var tile := ItemTile.new()
		tile.name = "Tile%d" % _tiles.size()
		tile.picked.connect(_on_tile_picked)
		add_child(tile)
		_tiles.append(tile)
	for i in _tiles.size():
		var tile := _tiles[i] as ItemTile
		if tile == null:
			continue
		if i >= _rows.size():
			tile.visible = false
			continue
		var row: Dictionary = _rows[i]
		var id := str(row.get("id", ""))
		var color: Color = row.get("badge_color", Color.WHITE)
		tile.setup(id, str(row.get("title", id)), str(row.get("art", "")),
			str(row.get("badge", "")), str(row.get("note", "")),
			bool(row.get("dimmed", false)), color)
		tile.selected = id != "" and id == selected_id
		tile.queue_redraw()


func _refresh_selection() -> void:
	for i in _tiles.size():
		var tile := _tiles[i] as ItemTile
		if tile == null or not tile.visible:
			continue
		var want: bool = tile.id != "" and tile.id == selected_id
		if tile.selected != want:
			tile.selected = want
			tile.queue_redraw()


func _on_tile_picked(p_id: String) -> void:
	select(p_id)
	picked.emit(p_id)


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## The tile maths without opening a screen, in two halves.
	##
	## (1) The UNPAGED contract every host still relies on: for any count the game can
	## show, the block fits its box, holds every cell, and the cells never overlap.
	## (2) The [P42] PAGED contract, which replaced "the box must hold all the kinds" once
	## the item list outgrew the shrink floor: one page is laid out at the FULL cell size
	## (no squeeze), pages x capacity covers every kind, and the bar the grid spends its
	## bottom strip on really fits in that box. Printed once at start-up by Game, next to
	## the other self-checks, so "the grid looks wrong" is answerable from a log line.
	## [P52] The prefix is [ItemUI], not [Items]: `ItemDB.self_check()` prints the DATA
	## sheet under [Items], and both blocks used to end with the same
	## "[Items] self-check PASSED" line - so a FAILED one named no module, and telling
	## "an item row disagrees with the battle" from "a grid does not fit its box" meant
	## scrolling back to whichever banner opened the block. Geometry here, item rows there;
	## the banner now says which without a second look.
	print("[ItemUI] --- item tiles + grids (P22) ---")
	var area := design_area()
	print("[ItemUI] cell %dx%d, gap %d, grid %dx%d, panel %d wide, fit passes %d"
		% [int(BalanceUI.ITEM_TILE_SIZE.x), int(BalanceUI.ITEM_TILE_SIZE.y),
		   int(BalanceUI.ITEM_TILE_GAP), int(area.x), int(area.y),
		   int(BalanceUI.ITEM_PANEL_W), BalanceUI.ITEM_GRID_FIT_PASSES])

	# the two boxes the game really uses: the warehouse / shop screen, and the
	# in-battle backpack panel. Both are paged, so both are audited both ways.
	var pack_area := Vector2(BalanceUI.OVERLAY_PANEL_SIZE.x - BalanceUI.PACK_PANEL_INSET * 2.0,
		BalanceUI.PACK_PANEL_GRID_H)
	var boxes: Array = [
		{"label": "warehouse/shop", "area": area},
		{"label": "backpack    ", "area": pack_area},
	]
	var ok := true
	var kinds: int = Balance.ITEM_ORDER.size()
	for entry in boxes:
		var box: Dictionary = entry
		var box_area: Vector2 = box["area"]
		var box_ok := true
		var smallest := 999.0
		var most_cols := 0
		## Up to ONE PAGE the old rule applies untouched: the block fits its box, holds every
		## cell and never shrinks below the floor the constants promise. Past a page a shrink
		## is no longer a failure - that is what the next page is for - so the counts beyond it
		## are audited by _page_contract() below instead of pretending to be laid out whole.
		var one_page := maxi(capacity_for(page_cell_area(box_area)), 1)
		for count in range(1, mini(kinds, one_page) + 1):
			var m := fit_for(box_area, count)
			var tile_box: Vector2 = m["tile"]
			var block: Vector2 = m["block"]
			var cols := int(m["cols"])
			var rows := int(m["rows"])
			smallest = minf(smallest, tile_box.x)
			most_cols = maxi(most_cols, cols)
			var fits: bool = block.x <= box_area.x + 0.5 and block.y <= box_area.y + 0.5
			var holds: bool = cols * rows >= count and rows >= 1 and cols >= 1
			var floor_ok: bool = float(m["scale"]) >= BalanceUI.ITEM_TILE_MIN_SCALE - 0.001
			var good: bool = fits and holds and floor_ok
			box_ok = box_ok and good
			if not good:
				print("[ItemUI] %s count %2d -> %dx%d cells of %dx%d | FAIL"
					% [box["label"], count, cols, rows, int(tile_box.x), int(tile_box.y)])
		ok = ok and box_ok
		print(("[ItemUI] %s box %dx%d holds one page of %d cell(s) at full size, "
			+ "up to %d column(s), smallest cell %d px (kinds now %d) | %s")
			% [box["label"], int(box_area.x), int(box_area.y), one_page, most_cols,
			   int(smallest), kinds, "OK" if box_ok else "FAIL"])
		ok = ok and _page_contract(box)

	# an empty grid must not draw anything at all
	var empty := fit_for(area, 0)
	var empty_ok: bool = int(empty["rows"]) == 0 and (empty["block"] as Vector2) == Vector2.ZERO
	ok = ok and empty_ok
	print("[ItemUI] empty container -> no cells = %s | %s"
		% [empty_ok, "OK" if empty_ok else "FAIL"])

	# [P28] capacity_for() is what a PAGED host asks ("how many cells fit at the REAL
	# size"), so it has to be the exact boundary of fit_for(): that many cells are laid
	# out at scale 1, one more starts the shrink (i.e. needs a second page).
	var cap := capacity_for(area)
	var at_cap := fit_for(area, cap)
	var over_cap := fit_for(area, cap + 1)
	var cap_ok: bool = int(at_cap["cols"]) * int(at_cap["rows"]) == cap \
		and is_equal_approx(float(at_cap["scale"]), 1.0) \
		and int(over_cap["cols"]) * int(over_cap["rows"]) >= cap + 1 \
		and float(over_cap["scale"]) < 1.0
	ok = ok and cap_ok
	print("[ItemUI] full-size capacity of the %dx%d warehouse box = %d cell(s); %d would shrink | %s"
		% [int(area.x), int(area.y), cap, cap + 1, "OK" if cap_ok else "FAIL"])
	print("[ItemUI] self-check %s" % ("PASSED" if ok else "FAILED"))


static func _page_contract(p_box: Dictionary) -> bool:
	## [P42] The four things a paged grid has to keep true in one specific box. Each is
	## computed from the SAME pure functions the nodes call at run time, which is the whole
	## point of the paging maths being static.
	var label: String = str(p_box["label"])
	var box_area: Vector2 = p_box["area"]
	var kinds: int = Balance.ITEM_ORDER.size()
	var cells := page_cell_area(box_area)
	var cap := capacity_for(cells)
	var pages := pages_for(kinds, cap)

	# 1. one page really holds the whole list once you add the pages back
	var covers: bool = pages * maxi(cap, 1) >= kinds and cap >= 1
	# 2. a page is never squeezed: capacity is BY DEFINITION the count that fits at scale 1
	var grid_page := fit_for(cells, cap)
	var full_size: bool = float(grid_page["scale"]) >= 1.0 - 0.001
	# 3. the strip the bar was promised is really inside the box (i.e. the cell area did not
	#    fall through its own floor to make room for it)
	var strip := box_area.y - cells.y
	var bar_fits: bool = is_equal_approx(strip, BalanceUI.ITEM_PAGE_BAR_H + BalanceUI.ITEM_PAGE_GAP)
	# 4. the bar's design width is not wider than the box it is centred in
	var bar_w := BalanceUI.ITEM_PAGE_BTN_W * 2.0 + BalanceUI.ITEM_PAGE_LABEL_W \
		+ BalanceUI.ITEM_PAGE_GAP * 2.0
	var bar_wide: bool = bar_w <= box_area.x + 0.5
	var good: bool = covers and full_size and bar_fits and bar_wide
	print(("[ItemUI] %s paged: %d cell(s)/page x %d page(s) for %d kinds, cell area %dx%d, "
		+ "bar strip %d px, bar %d px wide | %s")
		% [label, cap, pages, kinds, int(cells.x), int(cells.y), int(strip), int(bar_w),
		   "OK" if good else "FAIL"])
	return good
