class_name WarFormation
extends Control
## [W4] THE DEPLOYMENT TABLE - one screen, one decision: who stands on the left, and where.
##
## BrawlFormation's cousin with the round machinery taken OUT (plan section E): no session, no
## offers, no bench, no shop, no coins. The player picks from the mode's whole list
## (RosterDB.drawable_ids() - the `timed` column, [B31]) and places pieces into the map's
## deployment zone, once, before the match. 出征 commits and the arena runs by itself.
##
## THE PAGE AND THE ARENA SHARE ONE GEOMETRY (plan section C): the board is a FIXED WORLD
## (WarField: 96 px cells, origin (0,0)) seen through a camera transform, and this page runs
## the SAME two classes as QUIET instances - [W8]: the field invisible (an `enabled = false`
## on a Node2D switches off nothing), the camera disabled (Camera2D does have that door) -
## so a WarField hands over the cell doors and a WarCamera the fit and the world<->page
## conversions. [W9] amended even that: the page no longer borrows the field's strip drawer
## either - at fit zoom the two 0.55-alpha half-bands covered the whole view and read as a
## veil, and the page speaks "where" through its lattice, hover tints and sentences alone.
## So the cell a click lands on is the cell that was drawn, computed by the arena's own
## mathematics rather than a second copy that could drift (D66's rule, kept across two
## boards). Fitting the whole field at fit zoom is what makes the page read as "the
## battlefield from above", and W7's zoom-on-the-page is a set_position change only.
##
## ONE GESTURE IDIOM (plan section E, the user's simplified 编阵): the two-step click -
## a shelf tile arms a piece, a board cell places it; a click on a placed piece lifts it
## off the field, a click on a shelf tile that is already fielded arms that body instead.
## [W7] AMENDED, by the user's five-point order after the first play: a GRAB arrived -
## Ctrl+left or right-drag pans the view (it never places), the wheel zooms about the
## cursor and a middle click resets to the fit - while the PLAIN click keeps the two-step
## idiom exactly as written above, the click↔cell identity guaranteed by the same
## page_to_world/world_to_page pair it always used (plan section C, one math, two grounds).
## [W7b] AMENDED AGAIN, by the same user after the first LOOK: the grab is Ctrl+left ALONE
## (right-drag was a nice idea that had taken the right button's one job), a motion without
## ctrl counts as letting go of the map mid-drag, and the right PRESS now only frees the
## hand. The arena's camera follows the same ctrl rule, so the grip means one thing on both
## grounds.
##
## THE THREE REFUSALS are words, never silence (every drop question on the brawl's page is
## answered by a sentence) - [W7] admits the sentence was written to the model and never
## PAINTED: the hint strip now has its own drawer. The cap is WAR_DEPLOY_LIMIT and the zone
## is the map's own deploy_cols - both printed in the lines that enforce them, so the page
## never states a number it does not check.

const BrawlShadow := preload("res://scripts/core/brawl/brawl_shadow.gd")

## [W7] The range preview's ink - a LOCAL pair, the arena field's own idiom: this is
## one picture this node paints and no other file is supposed to know its alpha.
const RANGE_FILL := Color(0.42, 0.86, 0.45, 0.10)
const RANGE_EDGE := Color(0.42, 0.86, 0.45, 0.60)

## [W8] The scouted enemy's wash - a LOCAL constant, the RANGE_FILL idiom
## again: one picture, one owner, no other file is supposed to know this alpha. Red because
## the arena's enemy band already is (COLOR_BRAWL_RIGHT's story told in ink).
const ENEMY_TINT := Color(1.0, 0.32, 0.28, 0.30)

## [W10] The two zone seams' ink - a LOCAL constant on the same idiom. Gold is the hue the
## arena's retired deploy tint used to carry; here the page owns it alone, and the mirrored
## pair says "same shape, other side" in one colour. The arena itself shows the SAME two
## zones as its blue/red bands (war_field's draw_board, [W10] symmetry).
const DEPLOY_EDGE_LINE := Color(1.0, 0.85, 0.35, 0.90)

## UNtyped on purpose (the batch's class-registration window, same alias as war.gd uses):
## these two are this scene's own children and the first rescan may not know the classes yet.
@onready var _field = $Field
@onready var _camera = $Camera

var game = null                      # GameManager autoload；故意不标名称

var _pieces: Array = []              # the committed rows: [{piece, col, row}] - the W5 setup
## [W8] THE SCOUT'S PAGE, three lines of state: the round this table stands on, and the
## enemy line-up WarWaveGen rolled for it (units AND cells, exactly what the arena will
## field when 出征 commits). WarMain hands all three through the doors below after opening
## the page; NOTHING here re-rolls, and open_view keeps them across a language rebuild
## like it keeps the army - they are the session's, on loan to the page.
var _round_no := 0                   # 1-based label; 0 = no session was rolled (bare open)
var _round_total := 0
var _preview: Array = []             # [{piece, col, row}] of the NEXT bout's enemy
var _shelf: Array[String] = []       # RosterDB.drawable_ids() - the mode's whole list
var _selected := -1                  # the shelf index in hand (-1 = empty hand)
var _start: Button = null
var _clear: Button = null            # [W7] the page's one do-over
var _touched := false                # [W7] has the player moved their own eyes yet?
var _drag_btn := -1                  # [W7] which button holds the grab (-1 = nobody)
var _drag_active := false            # ...and has it crossed WAR_PAGE_DRAG_SLOP_PX yet?
var _drag_last := Vector2.ZERO       # the previous motion reading, for the delta
var _drag_start := Vector2.ZERO      # the press point, for the slop's cumulative test
var _title := ""
var _status := ""
var _hint := ""
var _mouse := Vector2.ZERO           # for the hover panel
var _hover: Vector2i = Vector2i(-1, -1)   # the board cell under the pointer
var _hover_shelf := -1               # the shelf tile under the pointer (-1 = none)

## _place()'s answers, and the hint line picks the sentence per code: one place decides
## WHICH refusal a click means, the caller only says what it costs to read the outcome.
const PLACE_OK := 0
const PLACE_FIELDED := 1
const PLACE_FULL := 2
const PLACE_ZONE := 3


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	## The PAGE takes the clicks (it hit-tests the board and the shelf itself), so everything
	## that is not a button must let them through - the brawl page's note applies verbatim.
	mouse_filter = Control.MOUSE_FILTER_STOP
	if $ButtonLayer != null:
		$ButtonLayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	## [W9] The code-level twin of the scene's `visible = false` on the page's Field child:
	## that instance owes this page its cell doors and NOTHING else - its raw world-picture
	## (2880 x 960 at the origin, children paint after the parent) is the very veil this
	## batch was called to remove. Written here too, so a stale scene buffer re-saved by the
	## editor can never bring the strips back over the page.
	_field.visible = false


# ---------------------------------------------------------------- public API
func open_view() -> void:
	## The front-end's page door. [W4] A REBUILD (apply_language opens this page again through
	## the flow's language list) keeps the placed pieces - losing an army to a language switch
	## would be a worse promise than a stale translated button.
	if _field == null or _camera == null:
		push_error("[War] the formation scene is missing its Field/Camera children")
		return
	_selected = -1
	_hover = Vector2i(-1, -1)
	_hover_shelf = -1
	## [W7] An opening always starts at "all of it on screen": the view the player left last
	## visit (or the page had before a language switch reopened it) is not owed to them -
	## the army IS (kept above by design), the framing re-fits. The drag state resets so a
	## reopen can never inherit a half-finished grab.
	_touched = false
	_drag_btn = -1
	_drag_active = false
	_hint = ""
	_shelf = RosterDB.drawable_ids()
	_field.set_map(BalanceWar.WAR_DEFAULT_MAP)
	## [W11] The grid switch is a SAVED setting (SettingsStore.war_grid, [ui] section, default
	## on) - this page and the battlefield read the one variable through the same field door
	## (`show_grid` is inherited from BrawlField and means exactly "draw the lattice here").
	## An opening re-reads it, so flipping the setting and coming back takes effect everywhere
	## without either screen holding a copy.
	_field.show_grid = SettingsStore.war_grid
	_build()
	visible = true
	on_layout_changed()
	## [W7] The title/status/hint through the ONE door they all have - and this call was the
	## missing reader: an opening used to paint an empty header until the first click
	## happened to run a refresh.
	_refresh_texts()
	_focus_first()


func hide_view() -> void:
	visible = false


func on_layout_changed() -> void:
	## A resize re-fits the world and moves the button; the board's own pixels never move
	## (they are world space), only the window looking at them changes - the same zero-jump
	## property W3 gave the arena.
	position = Vector2.ZERO
	size = Layout.size
	_layout()
	queue_redraw()


func rows() -> Array:
	## What 出征 commits: the rows in the shape WarSetup.from_placement re-checks.
	return _pieces.duplicate()


func map_id() -> String:
	return _field.map_id if _field != null else ""


# ---------------------------------------------------------------- the round brief [W8]
func show_round(p_no: int, p_total: int) -> void:
	## Which bout of how many this table stands on. The numbers arrive as labels (1-based);
	## the page prints them into the status line and draws nothing else from them - the
	## round is WarMain's cursor's business, this is the sentence it earns.
	_round_no = p_no
	_round_total = p_total
	_refresh_texts()


func show_enemy(p_rows: Array) -> void:
	## The SCOUTED LINE-UP: the next bout's rolled rows, {piece, col, row} - the same rows
	## the arena will field when 出征 commits, so a preview and a battlefield cannot drift
	## (the roller decided the cells; the page only draws and the march only obeys).
	_preview = p_rows.duplicate(true) if p_rows != null else []
	_refresh_texts()


func prefill(p_rows: Array) -> void:
	## The army from the last bout, standing again on the next table (the user's 重新编阵:
	## re-arrange, not re-place-from-zero - every row is still liftable, movable, addable
	## before the next 出征, the rows are just no longer missing). Deep-copied: the session
	## keeps its own copy, the page edits its own.
	_pieces = p_rows.duplicate(true) if p_rows != null else []
	_refresh_texts()


func has_board() -> bool:
	return _field != null and _field.has_board()


# ---------------------------------------------------------------- page building
func _build() -> void:
	_clear_entries()
	if not has_board():
		_title = Loc.t("war.formation.title").replace("%s", "")
		_hint = Loc.t("war.no_maps")
		_status = ""
		return
	_start = _add_button(Loc.t("war.formation.start"), _on_start)
	## [W7] The one do-over, made and owned exactly like 出征: same layer, same removal
	## rule, same disabled-until-there-is-something-to-do courtesy.
	_clear = _add_button(Loc.t("war.formation.clear"), _on_clear)


func _clear_entries() -> void:
	## _build() runs on every page rebuild (a language switch included), so the buttons it
	## made last time have to leave first - the brawl page's one-button-one-owner rule,
	## now kept for two buttons through the same three lines.
	for btn in [_start, _clear]:
		var old := btn as Button
		if old != null and is_instance_valid(old):
			var host := old.get_parent()
			if host != null:
				host.remove_child(old)
			old.queue_free()
	_start = null
	_clear = null


func _add_button(p_text: String, p_pressed: Callable) -> Button:
	var btn := UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)
	btn.text = p_text
	btn.add_theme_font_size_override("font_size", BalanceUI.FONT_SIZE_MENU_BUTTON)
	btn.pressed.connect(p_pressed)
	$ButtonLayer.add_child(btn)
	return btn


func _focus_first() -> void:
	if _start != null and is_instance_valid(_start) and not _start.disabled:
		_start.grab_focus()


# ---------------------------------------------------------------- the rectangles
func _view_rect() -> Rect2:
	## THE WINDOW THE WORLD LOOKS THROUGH: full width, under the header band and above the
	## shelf + hint strips. The page reserves its own strips here (the camera's HUD reserve
	## belongs to the arena) so `page_fit_zoom` sees the real visible box.
	var top := BalanceWar.CAMERA_HUD_RESERVED_PX
	var bottom := _shelf_h() + _hint_h()
	var h := maxf(1.0, size.y - top - bottom)
	return Rect2(Vector2(0.0, top), Vector2(size.x, h))


func _header_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, BalanceWar.CAMERA_HUD_RESERVED_PX))


func _shelf_rect() -> Rect2:
	return Rect2(Vector2(0.0, size.y - _shelf_h() - _hint_h()),
		Vector2(size.x, _shelf_h()))


func _hint_rect() -> Rect2:
	return Rect2(Vector2(0.0, size.y - _hint_h()), Vector2(size.x, _hint_h()))


func _shelf_h() -> float:
	## [W6] both numbers are the mode's, so they live in BalanceWar next to every other war
	## strip. [W7] the band became a GRID: rows of square tiles (icon + name inside each),
	## gaps between them, and the same 2 px padding the rects always carried top and bottom.
	## It reads _tile_size(), and _tile_size() reads only the window's WIDTH - the two used
	## to lean on each other through _shelf_rect and must not start again.
	var rows := float(_shelf_rows())
	return rows * _tile_size() + (rows - 1.0) * BalanceUI.BRAWL_MARGIN + 4.0


func _shelf_rows() -> int:
	## [W7] One row per WAR_PAGE_SHELF_PER_ROW units, rounded up: seventeen read as 9 + 8 at
	## the design window, and a growing roster grows rows, not scrunched tiles.
	return maxi(1, ceili(float(_shelf.size()) / float(BalanceWar.WAR_PAGE_SHELF_PER_ROW)))


func _shelf_per_row() -> int:
	## The row count split back out - 17 over 2 rows is 9, not 8.5 bodies. The last row
	## simply runs short; tiles keep one pitch.
	return maxi(1, ceili(float(_shelf.size()) / float(_shelf_rows())))


func _hint_h() -> float:
	## One line only: the title and the cap are the header's, this is the page's single
	## sentence of feedback (the brawl page's drawn hint, same job).
	return BalanceWar.WAR_PAGE_HINT_LINE_PX


func _tile_size() -> float:
	## [W7] The budget is per ROW, and it reads the window's WIDTH only - never _shelf_rect,
	## whose height this function feeds (the old loop would have become recursion).
	var n := maxi(1, _shelf_per_row())
	var gap := BalanceUI.BRAWL_MARGIN
	var avail := maxf(0.0, size.x - BalanceUI.BRAWL_MARGIN * 2.0
		- gap * float(n - 1))
	var tile := floorf(avail / float(n))
	return clampf(tile, BalanceWar.WAR_PAGE_TILE_MIN_PX,
		BalanceWar.WORLD_CELL * BalanceWar.WAR_PAGE_TILE_MAX_SHARE)


func _tile_rect(p_k: int) -> Rect2:
	var box := _shelf_rect()
	var tile := _tile_size()
	var gap := BalanceUI.BRAWL_MARGIN
	var per := maxi(1, _shelf_per_row())
	var col := p_k % per
	var row := floori(float(p_k) / float(per))
	return Rect2(Vector2(box.position.x + BalanceUI.BRAWL_MARGIN
		+ float(col) * (tile + gap), box.position.y + 2.0
		+ float(row) * (tile + gap)), Vector2(tile, tile))


func _tile_at(p_at: Vector2) -> int:
	for k in _shelf.size():
		var rect := _tile_rect(k)
		if rect.has_point(p_at):
			return k
	return -1


func _preview_reach(p_piece: String) -> float:
	## [W7] THE STRIKE'S OWN MEASURE, asked by id instead of by body. BrawlActor.attack_reach
	## reads the number off the live unit - a human states its 射程 (HumanPiece.effective_reach),
	## a zombie fights what it can touch (MELEE_REACH_CELLS), a plant shoots the length of the
	## arena (RANGED_REACH_CELLS) - and this is that EXACT three-way reading with no Unit under
	## it, in the same dispatch order _info_for keeps for the numbers panel. A preview that
	## guessed would be worse than none, so it does not: it asks the same tables the blow will.
	## [W7b] ...and the SAME GROUND BEND now rides on it: the war doubles a shooter's reach, so
	## the ring asks this page's field (a WarField, whose door answers 2.0) for the same
	## multiplier the actor's strike will pay. Ranged here means what it means in the arena -
	## THE ROW FIRES A PROJECTILE (HumanPiece.effective_shot, the id-side twin of
	## BrawlActor.is_ranged's shot_id) - not "the reach reads long": the 刀剑客 swings at
	## 1.1 cells and the ring must not pretend otherwise.
	var base := 0.0
	var ranged := false
	if PieceDB.has(p_piece):
		base = HumanPiece.effective_reach(p_piece)
		ranged = HumanPiece.effective_shot(p_piece) != ""
	elif ZombieDB.has(p_piece):
		base = BalanceBrawl.MELEE_REACH_CELLS
	else:
		base = BalanceBrawl.RANGED_REACH_CELLS
		ranged = true
	if ranged:
		var mult: float = _field.ranged_reach_mult()
		base *= mult
	return base


func _shelf_count(p_piece: String) -> int:
	## How many of one unit are already on the field - the small badge that answers "is this
	## the tile I just used" without counting by eye.
	var n := 0
	for entry in _pieces:
		if str((entry as Dictionary).get("piece", "")) == p_piece:
			n += 1
	return n


func _piece_at(p_cell: Vector2i) -> int:
	## The placed row on that cell, or -1. One piece per cell is THE page rule (the arena
	## would happily overlap two bodies); this is its only reader list.
	for i in _pieces.size():
		var row := _pieces[i] as Dictionary
		if int(row.get("col", -1)) == p_cell.x and int(row.get("row", -1)) == p_cell.y:
			return i
	return -1


func _preview_piece(p_cell: Vector2i) -> String:
	## [W8] The scouted enemy on that cell, or "" - the same one-per-cell scan run over the
	## preview list, so hovering a red piece answers with the numbers it will actually
	## field. The scouting report is a roster, not a shade: unnamed it says nothing.
	for entry in _preview:
		var row := entry as Dictionary
		if int(row.get("col", -1)) == p_cell.x and int(row.get("row", -1)) == p_cell.y:
			return str(row.get("piece", ""))
	return ""


# ---------------------------------------------------------------- the camera math
func _layout() -> void:
	## [W7] THE FIT-LOCK IS OPEN, in exactly the shape the plan promised ("a later free-pan
	## or zoom-on-the-page is a set_position here and nothing else"): UNTOUCHED, the page
	## still shows the whole battlefield centred - the framing W4 opened with and the one a
	## middle click returns to; once the player has grabbed or wheeled, a resize keeps THEIR
	## view, re-laddered and re-clamped against the new box instead of re-fitted under their
	## fingers. All of it is the shared camera's math (WarCamera's page doors [W7]).
	if not has_board():
		return
	_camera.field = _field
	var view := _view_rect()
	if not _touched:
		var z: float = _camera.page_fit_zoom(view)
		_camera.zoom = Vector2(z, z)
		_camera.position = _field.board_rect().get_center()
	else:
		## [W7] EXPLICIT types, both here and in the ring below: _camera is a ducked onready
		## (the class-registration window), so a `:=` on anything that touches it has no
		## static type to infer from - the page's W4 line above already spelled its `z`.
		var lim: Vector2 = _camera.page_zoom_limits(view)
		var kept: float = clampf(_camera.zoom.x, lim.x, lim.y)
		_camera.zoom = Vector2(kept, kept)
		_camera.page_clamp_position(view)
	## [W7] The two buttons share the hint strip's right end: 出征 at the wall (the W4 spot,
	## unchanged), 清空 one margin to its left. Widths are both BalanceWar's.
	var box := _hint_rect()
	var y := box.position.y + 1.0
	var h := box.size.y - 2.0
	if _start != null and is_instance_valid(_start):
		var w := BalanceWar.WAR_PAGE_BUTTON_W_PX
		var x := box.position.x + box.size.x - w - BalanceUI.BRAWL_MARGIN
		_start.position = Vector2(x, y)
		_start.custom_minimum_size = Vector2(w, h)
		_start.size = Vector2(w, h)
	if _clear != null and is_instance_valid(_clear):
		var w := BalanceWar.WAR_PAGE_CLEAR_W_PX
		var x := box.position.x + box.size.x - BalanceWar.WAR_PAGE_BUTTON_W_PX \
			- BalanceUI.BRAWL_MARGIN * 2.0 - w
		_clear.position = Vector2(x, y)
		_clear.custom_minimum_size = Vector2(w, h)
		_clear.size = Vector2(w, h)


func _world_to_page(p_world: Vector2) -> Vector2:
	return _camera.world_to_page(p_world, _view_rect())


func _page_to_world(p_page: Vector2) -> Vector2:
	return _camera.page_to_world(p_page, _view_rect())


func _cell_page_rect(p_cell: Vector2i) -> Rect2:
	## The WORLD rect through the PAGE transform - the pair (draw, hit-test) that cannot
	## drift because both go through _field.war_cell_rect and this one mapping.
	var w: Rect2 = _field.war_cell_rect(p_cell)
	return Rect2(_world_to_page(w.position), w.size * _camera.zoom.x)


# ---------------------------------------------------------------- the picture
func _draw() -> void:
	## The backdrop is the page's own first rectangle (no Background child - the brawl page's
	## note applies: a Control child would paint over everything drawn after it).
	draw_rect(Rect2(Vector2.ZERO, size), BalanceUI.COLOR_MENU_BG, true)
	## [W9] THE GROUND WASHES ARE GONE FROM THIS PAGE (the user's ruling, collecting the
	## standing offer from [W8]): the arena's two half-bands are 0.55-alpha colours and the
	## page shows the WHOLE board at fit zoom, so over the dark backdrop they read as one
	## colour VEIL, not as ground - and every question they used to answer, the page already
	## answers better (the lattice says cells, the hover tints say placeable, the sentences
	## say the zone, the red cells say scouted). The ARENA keeps drawing them through its own
	## field: under live bodies the halves and the seam say which way the front runs.
	_draw_header()
	if not has_board():
		return
	_draw_cells()
	## [W10] The two thick zone seams sit on the lattice and under the scouted bodies: they
	## frame where armies may stand, they are not themselves an army's picture.
	_draw_zones()
	## [W8] The scouted line-up sits ON the cells it owns and under everything the page
	## speaks with (shelf, hint strip, info panel) - the page's standing layering law:
	## world pictures below, window sentences above.
	_draw_enemy()
	_draw_shelf()
	## [W7] The sentence strip, painted at last - see _draw_hint.
	_draw_hint()
	_draw_info()


func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var box := _header_rect()
	var line := float(BalanceUI.FONT_SIZE_MENU_TITLE) + 10.0
	_draw_text(font, _title, box.position.x + box.size.x * 0.5,
		box.position.y + line * 0.85, BalanceUI.FONT_SIZE_MENU_TITLE,
		BalanceUI.COLOR_MENU_TITLE, box.size.x - 8.0)
	_draw_text(font, _status, box.position.x + box.size.x * 0.5,
		box.position.y + line + float(BalanceUI.FONT_SIZE_MENU_SUB) + 4.0,
		BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB, box.size.x - 8.0)


func _draw_cells() -> void:
	## Only the cells the view shows are touched: at fit zoom that is the whole board, and
	## the loop is cols x rows of cheap rectangles - the same shape WarField._draw uses.
	var view := _view_rect()
	var shown: Rect2 = _camera.visible_world_rect(view)
	var edge := BalanceWar.WORLD_CELL
	var c0 := clampi(int(floor(shown.position.x / edge)), 0, _field.cols - 1)
	var c1 := clampi(int(floor((shown.position.x + shown.size.x) / edge)), 0, _field.cols - 1)
	var r0 := clampi(int(floor(shown.position.y / edge)), 0, _field.rows - 1)
	var r1 := clampi(int(floor((shown.position.y + shown.size.y) / edge)), 0, _field.rows - 1)
	## The page draws the lattice itself (the field node's own _draw is off here): brighter
	## than the arena's, because on this page a cell is a CLICK TARGET, not scenery.
	for col in range(c0, c1 + 1):
		for row in range(r0, r1 + 1):
			var cell := Vector2i(col, row)
			var rect := _cell_page_rect(cell).grow(-BalanceUI.BRAWL_CELL_INSET * _camera.zoom.x)
			if rect.size.x <= 1.0:
				continue
			_draw_cell(cell, rect)
	_redraw_grid()


func _redraw_grid() -> void:
	## [W11] THE ONE GENERATOR, THIS PAGE'S GROUND (the user's question answered in code:
	## both phases now walk WarField.for_each_grid_segment - one list of boundaries, two
	## mappings). The page's half of the fix is SNAPPING: at fit zoom every mapped boundary
	## lands on a fraction (96 world px x ~0.43 = 41.3 window px), and a 1-px line at 41.3
	## reads thinner than its neighbour at 41.8 - which is how "有些地方没画网格线" looks from
	## a chair. Every endpoint goes _world_to_page and then round(): whole pixels, whole
	## lines, ALL of them - the four outer boundaries included, because the generator walks
	## 0..cols / 0..rows and no loop's leftover can hide here any more. [W10]'s c0..c1 view
	## clamp was a patch on a private loop; this is the loop being retired.
	if _field == null or not _field.show_grid:
		return
	_field.for_each_grid_segment(Callable(self, "_grid_line").bind(
		BalanceUI.COLOR_GRID_LINE, BalanceUI.BRAWL_GRID_WIDTH))


func _grid_line(p_a: Vector2, p_b: Vector2, p_color: Color, p_width: float) -> void:
	## The page's reading of the shared generator: endpoints through the camera mapping and
	## snapped - this canvas is the WINDOW, the arena field's canvas is the world.
	draw_line(_world_to_page(p_a).round(), _world_to_page(p_b).round(), p_color, p_width)


func _draw_zones() -> void:
	## [W10] THE TWO THICK SEAMS (the user's ruling: 我方战阵区域和敌方战阵区域应当大小形状
	## 一致, 各用一条粗线分隔): one line closing OUR band on its right, its MIRROR closing the
	## enemy band on its left. The geometry is the roller's read back - band = the map's own
	## deploy_cols clamped the same way war_wave_gen rolls with - so a seam here can never
	## disagree with where bodies may actually stand on either wing.
	var edge := BalanceWar.WORLD_CELL
	var band := clampi(_field.deploy_cols, 1, _field.cols)
	var foot := float(_field.rows) * edge
	for x in [float(band) * edge, float(_field.cols - band) * edge]:
		draw_line(_world_to_page(Vector2(x, 0.0)),
			_world_to_page(Vector2(x, foot)),
			DEPLOY_EDGE_LINE, BalanceWar.WAR_PAGE_ZONE_LINE_PX)


func _draw_enemy() -> void:
	## [W8] THE SCOUTED LINE-UP: every body the roller put in this round, on the very cell
	## the arena will field it at - wash, art turned against the player, and a name line.
	## All through the SAME _cell_page_rect mapping the placement clicks hit-test with (the
	## page's one-math promise), so what a spectator reads here and what marches there are
	## one picture seen twice, never two pictures that could drift.
	if _preview.is_empty():
		return
	var font := ThemeDB.fallback_font
	for entry in _preview:
		var row := entry as Dictionary
		var cell := Vector2i(int(row.get("col", -1)), int(row.get("row", -1)))
		if cell.x < 0 or cell.y < 0:
			continue
		var rect := _cell_page_rect(cell).grow(-BalanceUI.BRAWL_CELL_INSET * _camera.zoom.x)
		if rect.size.x <= 1.0:
			continue
		draw_rect(rect, ENEMY_TINT, true)
		var piece := str(row.get("piece", ""))
		_draw_piece(piece, rect, false, BalanceBrawl.SIDE_RIGHT)
		if font != null:
			_draw_text(font, Balance.unit_name(piece),
				rect.position.x + rect.size.x * 0.5,
				rect.position.y + rect.size.y - 3.0,
				BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE, BalanceUI.COLOR_MENU_TITLE,
				rect.size.x)


func _draw_cell(p_cell: Vector2i, p_rect: Rect2) -> void:
	var index := _piece_at(p_cell)
	var hovered: bool = p_cell == _hover
	var in_zone: bool = p_cell.x < _field.deploy_cols and p_cell.y < _field.rows
	if hovered and _selected >= 0 and index < 0:
		## The same two answers the brawl's page tints with: green "you may put it here",
		## red "this cell cannot take it" (the zone line is the war's, not the half's).
		draw_rect(p_rect, BalanceUI.COLOR_PLACEABLE if in_zone \
			else BalanceUI.COLOR_BRAWL_DROP_BAD, true)
		if in_zone:
			## [W7] THE RING OF OFFICE: what a blow struck from this very cell would reach,
			## drawn while the cell is still only a promise. The radius is the number the
			## strike itself will pay at the arena (_preview_reach mirrors the three-way
			## reading of BrawlActor.attack_reach, by id instead of by body) scaled by the
			## LIVE zoom - so the ring cannot lie about the cell it previews, at the fit or
			## at three times it.
			var centre := p_rect.get_center()
			var radius: float = _preview_reach(_shelf[_selected]) * BalanceWar.WORLD_CELL \
				* _camera.zoom.x
			draw_circle(centre, radius, RANGE_FILL)
			draw_arc(centre, radius, 0.0, TAU, BalanceWar.WAR_PAGE_RANGE_RING_SEGMENTS,
				RANGE_EDGE, BalanceWar.WAR_PAGE_RANGE_RING_PX, true)
	elif hovered:
		draw_rect(p_rect, BalanceUI.COLOR_ITEM_TILE_HOVER, true)
	if index < 0:
		return
	var row := _pieces[index] as Dictionary
	_draw_piece(str(row.get("piece", "")), p_rect, p_cell == _hover)
	if p_cell == _hover:
		draw_rect(p_rect, BalanceUI.COLOR_ITEM_TILE_SELECTED, false, BrawlField.EDGE_WIDTH)


func _draw_piece(p_piece: String, p_rect: Rect2, p_lifted: bool,
		p_side: int = BalanceBrawl.SIDE_LEFT) -> void:
	## Icon square inside the cell, and the BRAWL's ink shadow beneath it - the same static
	## drawer the arena and the brawl page share (B17's rule), so a preview body wears
	## exactly the ellipse it will cast on the field. Mirrored through the same rule door.
	## [W8] `p_side` joined that mirroring: the player's rows face right as they will in the
	## arena, the scouted enemies face left - one drawer, two armies, still turned the way
	## BrawlActor turns them.
	if p_piece == "" or p_rect.size.x <= 1.0:
		return
	var art := Balance.unit_art(p_piece)
	var texture := UnitArt.load_texture(art)
	if texture == null:
		return
	var size := maxf(8.0, p_rect.size.y)
	var icon := p_rect.position + Vector2((p_rect.size.x - size) * 0.5, 0.0)
	var alpha := BalanceUI.BRAWL_DRAG_ALPHA if p_lifted else 1.0
	BrawlShadow.draw_ink_shadow(self, icon + Vector2(size * 0.5, 0.0),
		UnitArt.ink_rect(art, Vector2.ZERO, size))
	UiStyle.draw_icon(self, art, icon, size, alpha,
		BrawlActor.turned_in(UnitSheet.face_left(p_piece), p_side))


func _draw_shelf() -> void:
	var font := ThemeDB.fallback_font
	var tile := _tile_size()
	for k in _shelf.size():
		var rect := _tile_rect(k)
		var piece := _shelf[k]
		var selected := k == _selected
		var fill := BalanceUI.COLOR_ITEM_TILE_HOVER if (k == _hover_shelf or selected) \
			else BalanceUI.COLOR_ITEM_TILE_BG
		draw_rect(rect, fill, true)
		var art := Balance.unit_art(piece)
		if UnitArt.load_texture(art) != null:
			var inset := 3.0
			UiStyle.draw_icon(self, art, rect.position + Vector2(inset, inset),
				maxf(4.0, tile - inset * 2.0
					- BalanceWar.WAR_PAGE_SHELF_NAME_LINE_PX),
				BalanceUI.BRAWL_DRAG_ALPHA if selected else 1.0,
				BrawlActor.turned_in(UnitSheet.face_left(piece), BalanceBrawl.SIDE_LEFT))
		if font != null:
			## The name under the icon - a one-word row of BENCH_NAME type, clipped like the
			## brawl's bench names (a long English name ellipsises inside the tile).
			_draw_text(font, Balance.unit_name(piece), rect.position.x + rect.size.x * 0.5,
				rect.position.y + rect.size.y - 5.0, BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE,
				BalanceUI.COLOR_MENU_SUB, rect.size.x - 2.0)
		var count := _shelf_count(piece)
		if count > 0:
			draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(16.0, 16.0)),
				BalanceUI.COLOR_ITEM_TILE_BADGE_BG, true)
			_draw_text(font, str(count), rect.position.x + 10.0, rect.position.y + 14.0,
				BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE, BalanceUI.COLOR_MENU_MARK, 14.0)
		draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_SELECTED if selected \
			else BalanceUI.COLOR_ITEM_TILE_BORDER, false, BrawlField.EDGE_WIDTH)
		if count > 0:
			## A faint dim on a tile whose body is already standing somewhere - not a
			## refusal (placing a second one is legal), just the answer to "did I use this".
			draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_DIM, true)


func _draw_hint() -> void:
	## [W7] THE SENTENCE STRIP, PAINTED AT LAST. Every refusal this page answers with was
	## being WRITTEN to _hint and read back by no drawer at all - the strip's rectangle was
	## computed for the button and nothing else visited it. Three readers share it now, left
	## to right: the controls sentence (a permanent door, never silenced by a refusal), the
	## hint centred in the space that leaves, and the two buttons at the wall (real Controls,
	## painted by their own layer above this one).
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var box := _hint_rect()
	var size_main := BalanceUI.FONT_SIZE_MENU_SUB
	var baseline := box.position.y + box.size.y * 0.5 + float(size_main) * 0.35
	var buttons_w := BalanceWar.WAR_PAGE_BUTTON_W_PX + BalanceWar.WAR_PAGE_CLEAR_W_PX \
		+ BalanceUI.BRAWL_MARGIN * 3.0
	var view := Loc.t("war.formation.view")
	var view_w := font.get_string_size(view, HORIZONTAL_ALIGNMENT_LEFT, -1,
		BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE).x
	var left := box.position.x + BalanceUI.BRAWL_MARGIN
	draw_string(font, Vector2(left, baseline), view, HORIZONTAL_ALIGNMENT_LEFT,
		maxf(1.0, box.size.x - buttons_w - BalanceUI.BRAWL_MARGIN * 2.0),
		BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE, BalanceUI.COLOR_MENU_SUB)
	var from := left + view_w + BalanceUI.BRAWL_MARGIN
	var to := box.position.x + box.size.x - buttons_w
	if _hint != "" and to > from:
		_draw_text(font, _hint, from + (to - from) * 0.5, baseline, size_main,
			BalanceUI.COLOR_MENU_TITLE, to - from)


func _draw_text(p_font: Font, p_text: String, p_center_x: float, p_baseline: float,
		p_size: int, p_color: Color, p_max_width: float) -> void:
	## One centred clipped line - the brawl page's helper shape (drawn text measured here,
	## because every line lives inside a rectangle this page computed).
	if p_font == null or p_text == "":
		return
	var width := p_font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_size).x
	draw_string(p_font, Vector2(p_center_x - width * 0.5, p_baseline), p_text,
		HORIZONTAL_ALIGNMENT_LEFT, p_max_width, p_size, p_color)


# ---------------------------------------------------------------- the hover panel
func _hover_piece() -> String:
	## Which unit the pointer is over: a placed piece first (it is the thing under the cursor
	## on the board), else a shelf tile, else "".
	if _hover_shelf >= 0 and _hover_shelf < _shelf.size():
		return _shelf[_hover_shelf]
	var index := _piece_at(_hover)
	if index >= 0:
		return str((_pieces[index] as Dictionary).get("piece", ""))
	## [W8] The scouted enemy is the third answer: the info panel is this page's scouting
	## instrument, and the red formation it shows would be worthless unreadable.
	return _preview_piece(_hover)


func _info_for(p_piece: String) -> Dictionary:
	## Every NUMBER from the sheet that owns it - the brawl page's three-way dispatch kept
	## line for line (a timed pool can hold a plant, a zombie and a human piece alike).
	if p_piece == "":
		return {}
	var lines: Array = []
	if PieceDB.has(p_piece):
		lines.append(Loc.tf("brawl.info.stats_piece", [PieceDB.cost(p_piece),
			PieceDB.hp(p_piece), PieceDB.attack(p_piece)]))
		## [W7b] The two BENT numbers are printed as THIS GROUND PAYS them, not as the sheet
		## writes them: a shooter's 射程 through _preview_reach (the ring's own door, doubling
		## included) and a swinging body's 移速 through the melee door - so the panel, the
		## ring and the fight state one number, and the brawl's 1.0s keep this identical
		## where nothing is bent.
		var reach := _preview_reach(p_piece)
		var speed := HumanPiece.effective_move_speed(p_piece)
		if HumanPiece.effective_shot(p_piece) == "":
			var bend: float = _field.melee_speed_mult()
			speed *= bend
		lines.append(Loc.tf("brawl.info.stats_move", [reach, speed,
			HumanPiece.effective_strike_seconds(p_piece)]))
		var rarity := PieceDB.rarity(p_piece)
		if rarity != "":
			lines.append(Loc.tf("brawl.info.rarity", [Balance.rarity_label(rarity)]))
		_append_prose(lines, PieceDB.text(p_piece, "skill"), PieceDB.text(p_piece, "special"))
	elif ZombieDB.has(p_piece):
		## [W7b] A zombie has no brawl_shot_id door to answer through - the family IS melee -
		## so its 移速 pays the melee bend directly (the same reading BrawlActor.is_ranged
		## resolves to "" for every zombie body).
		var zspeed: float = ZombieDB.move(p_piece)
		var zbend: float = _field.melee_speed_mult()
		lines.append(Loc.tf("brawl.info.stats_zombie", [ZombieDB.hp(p_piece),
			ZombieDB.armor(p_piece), zspeed * zbend, ZombieDB.bite(p_piece)]))
		_append_prose(lines, "", ZombieDB.text(p_piece, "special"))
	elif Balance.has_plant(p_piece):
		lines.append(Loc.tf("brawl.info.stats_plant", [Balance.plant_max_hp(p_piece),
			PlantDB.attack(p_piece), Balance.plant_cost(p_piece)]))
		_append_prose(lines, PlantDB.text(p_piece, "skill"),
			PlantDB.text(p_piece, "special"))
	else:
		return {}
	return {"title": Balance.unit_name(p_piece), "lines": lines}


func _append_prose(p_lines: Array, p_skill: String, p_special: String) -> void:
	if p_skill.strip_edges() != "":
		p_lines.append(Loc.tf("brawl.info.skill", [p_skill]))
	if p_special.strip_edges() != "":
		p_lines.append(Loc.tf("brawl.info.special", [p_special]))


func _draw_info() -> void:
	## The panel follows the pointer, the brawl page's box and clamp kept whole.
	if _mouse == Vector2.ZERO:
		return
	var piece := _hover_piece()
	if piece == "":
		return
	var info := _info_for(piece)
	if info.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var lines: Array = info["lines"]
	var pad := BalanceUI.BRAWL_INFO_PAD
	var title_size := BalanceUI.BRAWL_INFO_TITLE_FONT_SIZE
	var line_size := BalanceUI.BRAWL_INFO_FONT_SIZE
	var width := BalanceUI.BRAWL_INFO_WIDTH
	var height := pad * 2.0 + float(title_size) * 1.4 + float(lines.size()) * BalanceUI.BRAWL_INFO_LINE_H
	var at := _mouse + Vector2(BalanceUI.BRAWL_INFO_MARGIN, BalanceUI.BRAWL_INFO_MARGIN)
	if at.x + width > Layout.size.x - BalanceUI.BRAWL_MARGIN:
		at.x = _mouse.x - BalanceUI.BRAWL_INFO_MARGIN - width
	at.x = maxf(BalanceUI.BRAWL_MARGIN, at.x)
	at.y = clampf(at.y, BalanceUI.BRAWL_MARGIN,
		maxf(BalanceUI.BRAWL_MARGIN, Layout.size.y - height - BalanceUI.BRAWL_INFO_MARGIN))
	var panel := Rect2(at, Vector2(width, height))
	draw_rect(panel, BalanceUI.COLOR_BRAWL_INFO_BG, true)
	draw_rect(panel, BalanceUI.COLOR_BRAWL_INFO_BORDER, false, BrawlField.EDGE_WIDTH)
	draw_string(font, at + Vector2(pad, pad + float(title_size)), str(info["title"]),
		HORIZONTAL_ALIGNMENT_LEFT, width - pad * 2.0, title_size, BalanceUI.COLOR_MENU_TITLE)
	var y := at.y + pad + float(title_size) * 1.4
	for line in lines:
		y += BalanceUI.BRAWL_INFO_LINE_H
		draw_string(font, Vector2(at.x + pad, y), str(line), HORIZONTAL_ALIGNMENT_LEFT,
			width - pad * 2.0, line_size, BalanceUI.COLOR_MENU_SUB)


# ---------------------------------------------------------------- input
func _gui_input(p_event: InputEvent) -> void:
	## [W7] THE GESTURE TABLE, [W7b] AMENDED by the user's pan ruling - the grab is Ctrl+left
	## and NOTHING else, and letting go of ctrl mid-drag is letting go of the map:
	##   plain left press    = the two-step click (pick / place / lift) - UNTOUCHED, the W4
	##                         promise the plan's acceptance list tests line for line;
	##   wheel               = zoom about the cursor, but only while the cursor looks at the
	##                         board (the shelf and hint strips are window furniture);
	##   middle click        = reset the framing to the fit;
	##   Ctrl+left press     = arm the grab; motion past WAR_PAGE_DRAG_SLOP_PX pans; a motion
	##                         WITHOUT ctrl, or the button's release, ends it (a ctrl tap
	##                         does nothing - the arena swallows ctrl-clicks the same way);
	##   right press         = FREE THE HAND (the A half of the order: a placement keeps its
	##                         piece armed, so the right button is its door) - and nothing
	##                         else; right-DOWN is no longer a grab at all.
	if p_event is InputEventMouseMotion:
		var mm := p_event as InputEventMouseMotion
		if _drag_btn >= 0:
			## [W7b] A motion that arrives without the modifier IS the moment the player
			## let go of ctrl - the map stops following and the cursor takes its hover back
			## on the very same event.
			if not mm.ctrl_pressed:
				_end_drag()
				_update_hover(mm.position)
				return
			_advance_drag(mm.position)
			return
		_update_hover(mm.position)
		return
	if not (p_event is InputEventMouseButton):
		return
	var click := p_event as InputEventMouseButton
	if not click.pressed:
		## [W7b] A release now has exactly one job: let go of the map. (The right button's
		## second intent moved to its PRESS - freeing the hand is not a drag's business.)
		if click.button_index != _drag_btn:
			return
		_end_drag()
		queue_redraw()
		return
	match click.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_wheel_zoom(click.position, BalanceWar.CAMERA_ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			_wheel_zoom(click.position, 1.0 / BalanceWar.CAMERA_ZOOM_STEP)
		MOUSE_BUTTON_MIDDLE:
			_touched = false
			_layout()
			queue_redraw()
		MOUSE_BUTTON_LEFT:
			if click.ctrl_pressed:
				_arm_drag(MOUSE_BUTTON_LEFT, click.position)
			else:
				_update_hover(click.position)
				_on_click(click.position)
		MOUSE_BUTTON_RIGHT:
			## [W7b] Right = THE HAND'S DOOR, not the map's: one press frees whatever the
			## hand holds - no slop, no release, no second guess about what the drag meant.
			if _selected >= 0:
				_selected = -1
				_refresh_texts()
		_:
			pass


func _arm_drag(p_btn: int, p_at: Vector2) -> void:
	## The grab is armed, not yet real: slop first (a placement jitter must never slide the
	## world), pan after. The hover goes dark on purpose - mid-grab the cursor means "the
	## map's corner", and the green cell and the info panel should stop pretending otherwise.
	_drag_btn = p_btn
	_drag_active = false
	_drag_last = p_at
	_drag_start = p_at
	_hover = Vector2i(-1, -1)
	_hover_shelf = -1
	queue_redraw()


func _end_drag() -> void:
	_drag_btn = -1
	_drag_active = false


func _advance_drag(p_at: Vector2) -> void:
	var delta: Vector2 = p_at - _drag_last
	_drag_last = p_at
	if not _drag_active:
		if (p_at - _drag_start).length() <= BalanceWar.WAR_PAGE_DRAG_SLOP_PX:
			return
		_drag_active = true
	_touched = true
	_camera.page_pan_by(delta, _view_rect())
	queue_redraw()


func _wheel_zoom(p_at: Vector2, p_factor: float) -> void:
	if not has_board() or not _view_rect().has_point(p_at):
		return
	_touched = true
	_camera.page_zoom_about(_camera.zoom.x * p_factor, p_at, _view_rect())
	_update_hover(p_at)


func _update_hover(p_at: Vector2) -> void:
	_mouse = p_at
	_hover_shelf = _tile_at(p_at)
	_hover = Vector2i(-1, -1)
	if _hover_shelf < 0 and has_board():
		var cell: Vector2i = _field.war_cell_at(_page_to_world(p_at))
		if cell.x >= 0 and cell.x < _field.cols and cell.y >= 0 and cell.y < _field.rows:
			_hover = cell
	var grabby: bool = _hover_shelf >= 0 or _hover != Vector2i(-1, -1)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if grabby else Control.CURSOR_ARROW
	queue_redraw()


func _on_click(p_at: Vector2) -> void:
	if not has_board():
		return
	if _hover_shelf >= 0:
		_pick_from_shelf(_hover_shelf)
		return
	if _hover == Vector2i(-1, -1):
		return
	var index := _piece_at(_hover)
	if index >= 0:
		_remove_at(index)
		return
	_put_down(_hover)


func _pick_from_shelf(p_index: int) -> void:
	## Same tile twice = the empty hand (the click that picked up a piece can put it back).
	## A tile whose body is already on the field arms it too - placing a second one is a
	## legal order, and the count badge says how many already stand.
	if p_index < 0 or p_index >= _shelf.size():
		return
	_selected = -1 if p_index == _selected else p_index
	_refresh_texts()


func _remove_at(p_index: int) -> void:
	## Lift the placed row off the field (it returns to the shelf's pool - the unit list is
	## the mode's whole list, never a consumable here).
	## [W7] The hand is NOT touched: with the armed hand now a real state (placements keep
	## their piece), lifting somebody else's body off a cell has no business emptying it -
	## the old clear rode harmlessly on a hand that was always empty at that point anyway.
	_pieces.remove_at(p_index)
	_refresh_forced()


func _put_down(p_cell: Vector2i) -> void:
	if _selected < 0:
		_hint = Loc.t("war.formation.pick")
		_refresh_forced()
		return
	var code := _place(_shelf[_selected], p_cell)
	match code:
		PLACE_OK:
			_hint = ""
			## [W7] THE HAND STAYS ARMED (the order's A half): placing one did not use the
			## piece up - the shelf is the mode's whole list, never a consumable, so the
			## second copy costs a second click on the FIELD, not a second trip to the
			## shelf. The hand empties by choice only: the right button's press, a
			## re-click of the armed tile, or 清空.
		PLACE_FIELDED:
			_hint = Loc.t("war.formation.pick")
		PLACE_FULL:
			_hint = Loc.tf("war.formation.limit", [BalanceWar.WAR_DEPLOY_LIMIT])
		PLACE_ZONE:
			_hint = Loc.tf("war.formation.zone", [_field.deploy_cols])
	_refresh_forced()


func _place(p_piece: String, p_cell: Vector2i) -> int:
	## THE PAGE'S RULES, in one door (from_placement will re-check them at the commit - the
	## arena does not trust a page). One piece per cell, only inside the zone, capped at
	## WAR_DEPLOY_LIMIT; the codes tell the caller WHICH sentence the refusal costs.
	if _piece_at(p_cell) >= 0:
		return PLACE_FIELDED
	if _pieces.size() >= BalanceWar.WAR_DEPLOY_LIMIT:
		return PLACE_FULL
	if p_cell.x < 0 or p_cell.x >= _field.deploy_cols or p_cell.y < 0 \
			or p_cell.y >= _field.rows:
		return PLACE_ZONE
	_pieces.append({"piece": p_piece, "col": p_cell.x, "row": p_cell.y})
	return PLACE_OK


func _refresh_forced() -> void:
	if _hint == "":
		_hint = Loc.t("war.formation.pick")
	_refresh_texts()


# ---------------------------------------------------------------- the texts
func _refresh_texts() -> void:
	## Rebuilt on every state change - selection, placement, removal - through this ONE
	## door, the brawl page's rule (a button whose state is updated at the call sites
	## drifts the first time a new one is added).
	if has_board():
		_title = Loc.tf("war.formation.title", [WarDB.display_name(_field.map_id)])
		_status = Loc.tf("war.formation.cap",
			[_pieces.size(), BalanceWar.WAR_DEPLOY_LIMIT])
		## [W8] The round register rides on the same line - three numbers the scouting page
		## exists to answer. Only when a session rolled them: a bare open (no fixture)
		## keeps the old cap-only sentence rather than printing "0 / 0".
		if _round_total > 0:
			_status += "   ·   " + Loc.tf("war.formation.round",
				[_round_no, _round_total, _preview.size()])
		if _hint == "":
			_hint = Loc.t("war.formation.pick")
	else:
		_hint = Loc.t("war.no_maps")
	if _start != null and is_instance_valid(_start):
		## [W5's rule preview] an empty field LOSES (left empty = defeat), so the button is
		## the army's one gate: no pieces, no march - and the reason is in the cap line.
		_start.disabled = _pieces.is_empty()
	if _clear != null and is_instance_valid(_clear):
		## [W7] The do-over has nothing to do on an empty field - grey, not hidden, so the
		## strip never changes shape between states.
		_clear.disabled = _pieces.is_empty()
	queue_redraw()


# ---------------------------------------------------------------- the commit
func _on_clear() -> void:
	## [W7] The page's one do-over: everything back to the shelf, hand emptied too (an armed
	## hand pointing at a field you just erased is not a state worth keeping). No
	## confirmation - a mistake here costs re-picks, not an army; 出征 remains the only
	## commitment on the page, and the disabled rule above already guards the empty case.
	var n := _pieces.size()
	if n <= 0:
		return
	_pieces.clear()
	_selected = -1
	_hint = Loc.tf("war.formation.cleared", [n])
	_refresh_forced()


func _on_start() -> void:
	if game != null and not _pieces.is_empty():
		game.war_main.start_match()
