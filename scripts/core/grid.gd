extends Node2D
## [P8] 9x5 lawn grid.
## [P34] The MVP played the whole battle on one row (Balance.MVP_ROW); the lawn is
## now live on every row a level ENABLES (see set_enabled_rows) - that is what lets
## a threepeater shoot three lanes and a pumpkin guard a plant in another.
## Occupancy is a LIST per cell: several zombies may legally share one tile
## (original PvZ behaviour), so a single node per cell is not enough.
## Same-cell units get a staggered visual slot automatically.
## Text readouts live in the HUD; this node only draws the lawn and highlights.

signal cell_clicked(cell: Vector2i)

const GRID_LINE_WIDTH := 2
const LABEL_FONT_SIZE := 14
const FIT_EPSILON := 0.5         # self-check tolerance, in logical pixels

var _plants: Dictionary = {}     # Vector2i(col, row) -> Array[Node]
var _zombies: Dictionary = {}    # Vector2i(col, row) -> Array[Node]
var _hover_cell := Vector2i(-1, -1)
## [P34] The rows this battle plays on. Set by GameManager from the level file
## (LevelData.rows); every other row stays drawn but dead, exactly as the MVP row
## rule worked - only now it is a LEVEL choice instead of a hard-coded row.
var _enabled_rows: Array[int] = Balance.all_rows()

## Set by GameManager: while true, free cells glow green and blocked ones red.
var selection_active: bool = false
## Set by GameManager: "", "shovel", "glove" or "hammer".
var tool_mode: String = ""
var glove_source := Vector2i(-1, -1)
var glove_has_source: bool = false


class LawnBackdrop extends Node2D:
	## [P38] OPTIMIZATIONS B3: the checkerboard, the column/row numbers and the brain
	## marker only move when the WINDOW moves - yet they were repainted by Grid._draw()
	## every time the cursor crossed a cell. As a child node of the grid they are handed
	## to somebody who repaints on its own schedule; the tints and the hover stay in
	## Grid itself. The picture does not change depth: a parent node is painted before
	## its children, so this still sits under every plant, zombie and effect.
	## Layout and the language are the only inputs, so those are the signature.
	var _sig := ""

	func _signature() -> String:
		return "%d cell %d origin %s brain %s lang %s" % [
			int(Layout.size.x), int(Layout.cell), str(Layout.lawn_origin),
			str(Layout.brain_zone), Loc.language]

	func sync() -> void:
		## Called from Grid._draw(): cheap enough to run on every repaint of the tints,
		## and the only way this node learns the window or the language moved.
		var next := _signature()
		if next == _sig:
			return
		_sig = next
		queue_redraw()

	func _draw() -> void:
		## Backdrop for the whole window: with a wide window the lawn is centred and the
		## space around it must not look like a rendering hole.
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, Layout.size), BalanceUI.COLOR_BG)
		var cell_size := Layout.cell
		for row in Balance.ROWS:
			for col in Balance.COLS:
				var base := BalanceUI.COLOR_LAWN_A if (col + row) % 2 == 0 else BalanceUI.COLOR_LAWN_B
				## [P34] The MVP row used to sit brighter and every other row darker. The
				## whole lawn is in play now, so no row is second class - the checkerboard
				## alone tells the cells apart. A row this battle does not use stays plain
				## and simply refuses the placement (the hover tint says so when a card is
				## selected, see Grid._draw_placeable_tint).
				var rect := Rect2(Layout.lawn_origin + Vector2(col, row) * cell_size,
					Vector2(cell_size, cell_size))
				draw_rect(rect, base)
				draw_rect(rect, BalanceUI.COLOR_GRID_LINE, false, GRID_LINE_WIDTH)

		for col in Balance.COLS:
			var x := Layout.lawn_origin.x + col * cell_size
			draw_string(font, Vector2(x, Layout.lawn_origin.y - 8.0), str(col),
				HORIZONTAL_ALIGNMENT_CENTER, cell_size, LABEL_FONT_SIZE, BalanceUI.COLOR_TEXT_DIM)

		for row in Balance.ROWS:
			var y := Layout.lawn_origin.y + row * cell_size + cell_size * 0.5 + BalanceUI.TEXT_BASELINE_NUDGE
			draw_string(font, Vector2(Layout.lawn_origin.x - 30.0, y), str(row),
				HORIZONTAL_ALIGNMENT_CENTER, 24.0, LABEL_FONT_SIZE, BalanceUI.COLOR_TEXT_DIM)

		var zone: Rect2 = Layout.brain_zone
		draw_rect(zone, Color(BalanceUI.COLOR_BRAIN, 0.22))
		draw_rect(zone, BalanceUI.COLOR_BRAIN, false, GRID_LINE_WIDTH)
		var zy := zone.position.y + zone.size.y * 0.5 + BalanceUI.TEXT_BASELINE_NUDGE
		draw_string(font, Vector2(zone.position.x, zy), Loc.t("unit.brain"),
			HORIZONTAL_ALIGNMENT_CENTER, zone.size.x, LABEL_FONT_SIZE, BalanceUI.COLOR_BRAIN)


## [P38] B3: the static half of the lawn picture, as the first child (see above).
var _backdrop: LawnBackdrop = null


func _ready() -> void:
	## [P38] B3: first child, so the lawn stays behind every unit that comes later.
	_backdrop = LawnBackdrop.new()
	add_child(_backdrop)
	_run_self_check()


func _process(_delta: float) -> void:
	var cell_pos := world_to_cell(get_local_mouse_position())
	if cell_pos != _hover_cell:
		_hover_cell = cell_pos
		queue_redraw()


func get_hover_cell() -> Vector2i:
	return _hover_cell


func on_layout_changed() -> void:
	## Called by Game after the window changed the lawn geometry: every unit sits
	## on a cell centre that just moved.
	_refresh_unit_layout(_plants)
	_refresh_unit_layout(_zombies)
	_hover_cell = world_to_cell(get_local_mouse_position())
	queue_redraw()


static func _refresh_unit_layout(p_table: Dictionary) -> void:
	## [P75] OPTIMIZATIONS B3's last bullet. This walked `for table in [_plants, _zombies]`,
	## which allocates an array per call plus a key array per table, and then asked every
	## node has_method("refresh_layout"). The two tables are now taken one at a time, their
	## keys iterated in place, and a node is recognised by the class that OWNS the method:
	## the self-check's bare Node2D stubs cast to null, which skips them exactly as the
	## duck-typed probe did - but without paying a method lookup per unit.
	for key in p_table:
		for node in (p_table[key] as Array):
			if node == null or not is_instance_valid(node):
				continue
			var unit := node as Unit
			if unit != null:
				unit.refresh_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	cell_clicked.emit(world_to_cell(get_local_mouse_position()))
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- geometry API
# All of it comes from Layout, so it follows the window around.
func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < Balance.COLS and row >= 0 and row < Balance.ROWS


func is_enabled(col: int, row: int) -> bool:
	## [P34] In bounds AND on a row this battle enabled.
	return in_bounds(col, row) and is_row_enabled(row)


func is_row_enabled(row: int) -> bool:
	## [P34] The single row test every caller now goes through, so a level that
	## narrows the lawn cannot be bypassed by a call site reading MVP_ROW again.
	return _enabled_rows.has(row)


func set_enabled_rows(p_rows: Array) -> void:
	## [P34] Called when a level starts with its `rows` key. A raw JSON array is not
	## trusted: out-of-range and duplicate entries drop, and a level that named
	## nothing usable gets the whole lawn (same as a level with no `rows` at all).
	var rows: Array[int] = []
	for r in p_rows:
		var ri := int(r)
		if ri >= 0 and ri < Balance.ROWS and not rows.has(ri):
			rows.append(ri)
	_enabled_rows = rows if not rows.is_empty() else Balance.all_rows()
	queue_redraw()


func enabled_rows() -> Array[int]:
	return _enabled_rows.duplicate()


func enabled_rows_text() -> String:
	## What the "this row is not in the battle" refusal adds: the rows that ARE.
	var sorted := _enabled_rows.duplicate()
	sorted.sort()
	var parts := PackedStringArray()
	for r in sorted:
		parts.append(str(int(r)))
	return ", ".join(parts)


func first_enabled_row() -> int:
	## The row a probe (or a default placement) uses when it needs one live cell.
	return _enabled_rows[0] if not _enabled_rows.is_empty() else Balance.MVP_ROW


func refused_row() -> int:
	## [P34] The mirror of first_enabled_row(): a row the battle must say NO to -
	## the bottom-most lane this level left out when it narrowed the lawn, or, once
	## every lane is live, a row outside the lawn at all (the gates refuse that one
	## through in_bounds instead, which is still a refusal).
	##
	## This exists because the self-checks used to write `MVP_ROW + 1` and call it
	## "the inactive row". That stopped being true the moment a level opened all
	## five lanes: the assertion would then be checking a refusal that cannot
	## happen, and it would PASS IN SILENCE. Asking the grid keeps the probe's
	## premise tied to the lawn the battle actually enabled.
	for r in range(Balance.ROWS - 1, -1, -1):
		if not _enabled_rows.has(r):
			return r
	return Balance.ROWS


func cell_to_world(col: int, row: int) -> Vector2:
	## Top-left corner of the cell, in this node's local space.
	return Layout.lawn_origin + Vector2(float(col), float(row)) * Layout.cell


func cell_center(col: int, row: int) -> Vector2:
	return cell_to_world(col, row) + Vector2(Layout.cell, Layout.cell) * 0.5


func world_to_cell(pos: Vector2) -> Vector2i:
	## Returns Vector2i(-1, -1) when the position is outside the lawn.
	var edge := maxf(Layout.cell, 1.0)
	var local := pos - Layout.lawn_origin
	var col := int(floor(local.x / edge))
	var row := int(floor(local.y / edge))
	if not in_bounds(col, row):
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func brain_zone_rect() -> Rect2:
	## Marker for the house / brain area left of the lawn. Not a lawn cell.
	return Layout.brain_zone


# ---------------------------------------------------------------- occupancy internals
func _list_add(table: Dictionary, col: int, row: int, node: Node) -> void:
	var key := Vector2i(col, row)
	var list: Array = table.get(key, [])
	if not list.has(node):
		list.append(node)
	table[key] = list
	_restack(table, col, row)
	queue_redraw()


func _list_erase(table: Dictionary, col: int, row: int, node: Node) -> void:
	var key := Vector2i(col, row)
	if not table.has(key):
		return
	var list: Array = table[key]
	list.erase(node)
	if list.is_empty():
		table.erase(key)
	else:
		table[key] = list
	_restack(table, col, row)
	queue_redraw()


func _list_count(table: Dictionary) -> int:
	var total := 0
	for key in table.keys():
		total += (table[key] as Array).size()
	return total


func _restack(table: Dictionary, col: int, row: int) -> void:
	## Keeps same-cell units visually staggered: list order == slot index.
	## Nodes without set_stack_index() (self-check stubs) are skipped.
	var list: Array = table.get(Vector2i(col, row), [])
	for i in list.size():
		var node = list[i]
		if node != null and is_instance_valid(node) and node.has_method("set_stack_index"):
			node.set_stack_index(i)


# ---------------------------------------------------------------- occupancy API
func register_plant(col: int, row: int, node: Node) -> void:
	_list_add(_plants, col, row, node)


func unregister_plant(col: int, row: int, node: Node) -> void:
	_list_erase(_plants, col, row, node)


func register_zombie(col: int, row: int, node: Node) -> void:
	_list_add(_zombies, col, row, node)


func unregister_zombie(col: int, row: int, node: Node) -> void:
	_list_erase(_zombies, col, row, node)


func get_plants_at(col: int, row: int) -> Array:
	return (_plants.get(Vector2i(col, row), []) as Array).duplicate()


func get_zombies_at(col: int, row: int) -> Array:
	return (_zombies.get(Vector2i(col, row), []) as Array).duplicate()


func get_zombies_around(p_col: int, p_row: int, radius: int) -> Array:
	## [P58] THE BOX AROUND A CELL - the one answer every "周围 N 格" blast asks.
	## 樱桃炸弹's 3x3 and 忧郁菇's 周围8格 are the same question with the same reach,
	## and until now the first of them owned the loop privately (CherryBomb
	## .blast_targets) while the second had nowhere to ask it. The centre counts as
	## inside its own box: planting needs a free cell, but a body can still arrive
	## there afterwards - VAULT lands one cell behind the wall it cleared, which is
	## another plant's cell - and a zombie standing on top of a mushroom is exactly
	## what a ring blast is for. So the radius is the only number a caller has to say.
	## Collected row by row so a log reads top lane to bottom lane, and a cell outside
	## the lawn simply misses in the registry - an edge blast burns the strip that
	## exists, which is the shape the cherry already had.
	var out: Array = []
	for d_row in range(-radius, radius + 1):
		for d_col in range(-radius, radius + 1):
			out.append_array(get_zombies_at(p_col + d_col, p_row + d_row))
	return out


func get_plant_at(col: int, row: int) -> Node:
	var list: Array = _plants.get(Vector2i(col, row), [])
	return list[0] if not list.is_empty() else null


func get_zombie_at(col: int, row: int) -> Node:
	var list: Array = _zombies.get(Vector2i(col, row), [])
	return list[0] if not list.is_empty() else null


func has_zombies_at(col: int, row: int) -> bool:
	## [P38] OPTIMIZATIONS B3: the drawing path only ever asks "is anything standing
	## here", and get_zombies_at() answers it by DUPLICATING the list first - which the
	## 45-cell tool tint loop therefore did 45 times per lawn redraw. This reads the
	## registry key instead, so it allocates nothing: _list_erase() drops the key the
	## moment the last node leaves, which makes "the key is there" and "the list is not
	## empty" the same question.
	return _zombies.has(Vector2i(col, row))


func is_occupied(col: int, row: int) -> bool:
	var key := Vector2i(col, row)
	return _plants.has(key) or _zombies.has(key)


func is_free(col: int, row: int) -> bool:
	if not in_bounds(col, row):
		return false
	return not is_occupied(col, row)


func is_placeable(col: int, row: int) -> bool:
	return is_enabled(col, row) and is_free(col, row)


func plant_count() -> int:
	return _list_count(_plants)


func zombie_count() -> int:
	return _list_count(_zombies)


func all_units() -> Array:
	## Every unit currently on the lawn (plants and zombies). [P20] The language
	## switch uses it to rename what is ALREADY on the board, so switching language
	## mid-battle does not mean restarting the battle.
	## [P75] Same shape as _refresh_unit_layout(): the returned array is the point of this
	## call, but the array OF TABLES it used to walk on every call was not.
	var out: Array = []
	_append_units(_plants, out)
	_append_units(_zombies, out)
	return out


static func _append_units(p_table: Dictionary, p_out: Array) -> void:
	for key in p_table:
		for node in (p_table[key] as Array):
			p_out.append(node)


func clear_occupancy() -> void:
	_plants.clear()
	_zombies.clear()
	queue_redraw()


# ---------------------------------------------------------------- tool targeting
func is_tool_target(col: int, row: int) -> bool:
	## True when the currently selected tool could act on this cell.
	if not in_bounds(col, row):
		return false
	match tool_mode:
		"shovel":
			return get_plant_at(col, row) != null
		"hammer":
			return has_zombies_at(col, row)
		"glove":
			if glove_has_source:
				return is_enabled(col, row) and is_free(col, row)
			return get_plant_at(col, row) != null
	return false


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	## [P38] B3: only the parts that DO move are painted here. The backdrop child is told
	## to look at the geometry and the language (a string compare when nothing moved) and
	## keeps its own picture otherwise, so crossing the lawn with the mouse no longer
	## repaints 45 cells and 14 labels.
	_backdrop.sync()
	_draw_placeable_tint()
	_draw_tool_tint()
	_draw_hover(ThemeDB.fallback_font)


func _draw_placeable_tint() -> void:
	if not selection_active:
		return
	var cell_size := Layout.cell
	for row in Balance.ROWS:
		for col in Balance.COLS:
			if not is_enabled(col, row):
				continue
			var rect := Rect2(cell_to_world(col, row), Vector2(cell_size, cell_size))
			if is_free(col, row):
				draw_rect(rect, BalanceUI.COLOR_PLACEABLE)
			else:
				draw_rect(rect, BalanceUI.COLOR_BLOCKED)


func _draw_tool_tint() -> void:
	if tool_mode == "":
		return
	var cell_size := Layout.cell
	for row in Balance.ROWS:
		for col in Balance.COLS:
			if is_tool_target(col, row):
				draw_rect(Rect2(cell_to_world(col, row), Vector2(cell_size, cell_size)),
					BalanceUI.COLOR_TOOL_TARGET)
	if glove_has_source and in_bounds(glove_source.x, glove_source.y):
		var r := Rect2(cell_to_world(glove_source.x, glove_source.y), Vector2(cell_size, cell_size))
		draw_rect(r, BalanceUI.COLOR_TOOL_SOURCE)
		draw_rect(r, BalanceUI.COLOR_TOOL_TARGET_LINE, false, 3.0)


func _draw_hover(_font: Font) -> void:
	if not in_bounds(_hover_cell.x, _hover_cell.y):
		return
	var cell_size := Layout.cell
	var rect := Rect2(cell_to_world(_hover_cell.x, _hover_cell.y), Vector2(cell_size, cell_size))
	var fill := BalanceUI.COLOR_HOVER
	var line := BalanceUI.COLOR_HOVER_LINE
	if tool_mode != "":
		if is_tool_target(_hover_cell.x, _hover_cell.y):
			fill = BalanceUI.COLOR_TOOL_TARGET.lightened(0.15)
			line = BalanceUI.COLOR_TOOL_TARGET_LINE
		else:
			fill = BalanceUI.COLOR_BLOCKED
			line = Color(1.0, 0.35, 0.35, 0.95)
	elif selection_active:
		if is_placeable(_hover_cell.x, _hover_cell.y):
			fill = BalanceUI.COLOR_PLACEABLE.lightened(0.15)
			line = Color(0.45, 1.0, 0.50, 0.95)
		else:
			fill = BalanceUI.COLOR_BLOCKED
			line = Color(1.0, 0.35, 0.35, 0.95)
	draw_rect(rect, fill)
	draw_rect(rect, line, false, GRID_LINE_WIDTH)


# ---------------------------------------------------------------- self check
func _run_self_check() -> void:
	# Log lines are built with string concatenation on purpose: a "%" expression
	# split over two physical lines is this project's classic paste accident.
	var ok := true

	# geometry now comes from Layout, so the probes use the live values
	var origin := Layout.lawn_origin
	var corner := cell_to_world(0, 0)
	var corner_ok := corner.is_equal_approx(origin)
	ok = ok and corner_ok
	print("[Grid] cell_to_world(0,0) = " + str(corner) + " | expected Layout.lawn_origin "
		+ str(origin) + " | " + ("OK" if corner_ok else "FAIL"))

	var back := world_to_cell(origin)
	var back_ok := back == Vector2i(0, 0)
	ok = ok and back_ok
	print("[Grid] world_to_cell(lawn origin) = " + str(back) + " | expected (0, 0) | "
		+ ("OK" if back_ok else "FAIL"))

	var last := world_to_cell(cell_center(Balance.COLS - 1, Balance.ROWS - 1))
	var last_ok := last == Vector2i(Balance.COLS - 1, Balance.ROWS - 1)
	ok = ok and last_ok
	print("[Grid] world_to_cell(center of 8,4) = " + str(last) + " | expected (8, 4) | "
		+ ("OK" if last_ok else "FAIL"))

	var oob := world_to_cell(Vector2(0.0, 0.0))
	var oob_ok := oob == Vector2i(-1, -1)
	ok = ok and oob_ok
	print("[Grid] world_to_cell(0,0) out of lawn = " + str(oob) + " | expected (-1, -1) | "
		+ ("OK" if oob_ok else "FAIL"))

	var edge := world_to_cell(Vector2(origin.x + Layout.cell * Balance.COLS - 1.0,
		origin.y + Layout.cell * Balance.ROWS - 1.0))
	var edge_ok := edge == Vector2i(Balance.COLS - 1, Balance.ROWS - 1)
	ok = ok and edge_ok
	print("[Grid] world_to_cell(bottom-right px) = " + str(edge) + " | expected (8, 4) | "
		+ ("OK" if edge_ok else "FAIL"))

	# the lawn must always sit in the area the HUD leaves free, and the brain
	# zone must stay left of column 0 (this is what a window resize moves)
	var lawn := Layout.lawn_rect()
	var zone := brain_zone_rect()
	var fits_ok: bool = lawn.position.y >= Layout.top_h - FIT_EPSILON \
		and lawn.end.y <= Layout.bottom_y + FIT_EPSILON \
		and zone.end.x <= lawn.position.x + FIT_EPSILON \
		and zone.position.x >= -FIT_EPSILON
	ok = ok and fits_ok
	print("[Grid] lawn inside the play area, brain zone left of col 0 = " + str(fits_ok) + " | "
		+ ("OK" if fits_ok else "FAIL"))
	print("[Grid] live geometry = " + Layout.geometry_line() + ", brain zone " + str(zone))

	# multi-occupancy registry (regression guard for same-cell overlap)
	var a := Node2D.new()
	var b := Node2D.new()
	add_child(a)
	add_child(b)
	register_zombie(3, 4, a)
	register_zombie(3, 4, b)
	var two_ok := get_zombies_at(3, 4).size() == 2
	## [P38] B3: has_zombies_at() is the allocation-free answer the draw loop uses, so it
	## has to agree with the list it replaced at every step of that probe - a cell that
	## said "no" while a zombie stood on it would turn the hammer highlight off.
	var peek_two_ok := has_zombies_at(3, 4)
	## [P58] The same two bodies also answer the box question, and this is the cheapest
	## place in the project to ask it: with both standing in (3,4), a radius-1 ring round
	## (2,4) - or (3,3), one lane up - holds them, and one cell further off holds nothing.
	## The off-lawn probe is the other half of the promise: a box whose centre sits on the
	## corner of the lawn reaches into cells that do not exist, and must say "two", not
	## crash and not count a neighbour lane the grass never had.
	var box_side_ok := get_zombies_around(2, 4, 1).size() == 2
	var box_lane_ok := get_zombies_around(3, 3, 1).size() == 2
	var box_far_ok := get_zombies_around(0, 4, 1).is_empty()
	var box := Node2D.new()
	add_child(box)
	register_zombie(0, 0, box)
	var box_corner_ok := get_zombies_around(0, 0, 1).size() == 1
	unregister_zombie(0, 0, box)
	box.queue_free()
	unregister_zombie(3, 4, a)
	var one_ok := get_zombies_at(3, 4).size() == 1 and get_zombie_at(3, 4) == b
	var peek_one_ok := has_zombies_at(3, 4)
	unregister_zombie(3, 4, b)
	var zero_ok := not is_occupied(3, 4)
	var peek_zero_ok := not has_zombies_at(3, 4)
	a.queue_free()
	b.queue_free()
	var peek_ok: bool = peek_two_ok and peek_one_ok and peek_zero_ok
	var box_ok := box_side_ok and box_lane_ok and box_far_ok and box_corner_ok
	ok = ok and two_ok and one_ok and zero_ok and peek_ok and box_ok
	print("[Grid] two zombies in one cell = " + str(two_ok) + ", after one leaves = " + str(one_ok)
		+ ", empty = " + str(zero_ok) + ", has_zombies_at agrees = "
		+ str(peek_ok) + " | " + ("OK" if (two_ok and one_ok and zero_ok and peek_ok) else "FAIL"))
	## [P58] Printed on its own line because it is a different question from the one
	## above: that one asks who stands IN a cell, this one who stands NEAR it - and both
	## of them are now asked by two plants (樱桃炸弹's 3×3, 忧郁菇's 周围8格).
	print("[Grid] box around (3,4): side cell and lane above both hold 2, one cell further"
		+ " holds 0, an off-lawn corner counts only what exists = " + str(box_ok) + " | "
		+ ("OK" if box_ok else "FAIL"))

	# [P34] the multi-row gate itself: an unnamed level owns the whole lawn, a level
	# that names rows owns only those, and the probe must leave the gate as it found
	# it (this runs before any level loads, so "as it found it" is the whole lawn).
	var open_ok := is_enabled(0, 0) and is_enabled(Balance.COLS - 1, Balance.ROWS - 1)
	set_enabled_rows([2])
	var nar_ok := is_enabled(0, Balance.MVP_ROW) \
		and not is_enabled(0, Balance.MVP_ROW - 1) and not is_enabled(0, Balance.MVP_ROW + 1)
	var rows_ok := enabled_rows().size() == 1 and enabled_rows().has(Balance.MVP_ROW) \
		and first_enabled_row() == Balance.MVP_ROW
	## [P34] `refused_row()` is the promise the BATTLE self-checks lean on ("this row
	## must be a no"), so the promise is tested on both kinds of lawn: a narrowed one,
	## where it is a lane the level left out, and an open one, where it can only be a
	## row outside the lawn. A helper that handed back a live row would turn every
	## refusal probe into a green lie, which is exactly the failure this guards.
	var dead_narrow_ok := refused_row() != Balance.MVP_ROW and not is_enabled(0, refused_row())
	set_enabled_rows(Balance.all_rows())
	var dead_open_ok := not is_enabled(0, refused_row())
	set_enabled_rows([])
	var back_ok1 := is_enabled(0, 0) and is_enabled(Balance.COLS - 1, Balance.ROWS - 1)
	var gate_ok := open_ok and nar_ok and rows_ok and dead_narrow_ok and dead_open_ok and back_ok1
	ok = ok and gate_ok
	print("[Grid] rows: default whole lawn = " + str(open_ok) + ", [2] narrows = " + str(nar_ok)
		+ ", list/first = " + str(rows_ok) + ", refused_row on both lawns = "
		+ str(dead_narrow_ok and dead_open_ok) + ", empty restores = " + str(back_ok1) + " | "
		+ ("OK" if gate_ok else "FAIL"))

	print("[Grid] self-check %s" % ("PASSED" if ok else "FAILED"))
