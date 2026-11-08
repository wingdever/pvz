class_name WarCamera
extends Camera2D
## [W3] THE WAR'S EYES - the project's first camera that runs during play.
##
## The rule the whole design stands on: the battlefield is a FIXED WORLD (WarField: cell
## 96 px, a map-sized grid, origin (0,0)) and "how much of it you see" is this node's zoom
## and nothing else. During a match the player commands only their eyes - the fight runs
## itself - so panning and zooming are not convenience features, they ARE the interaction.
##
## THE CONTROLS, as the user specced them (the same shape reads on the spectator hint):
##   pan    WASD held, or Ctrl + left-drag
##   zoom   Ctrl + wheel, or the +/- keys
## [W7b] The ctrl in that grab IS part of the grip: the user ruled that a pan works only
## while ctrl+left are BOTH held - dropping either counts as letting go (the drag-motion
## branch below checks the modifier, and the formation page's grab does the same).
## Nothing else is swallowed: SPACE / F / R / ESC belong to the arena's own _input, and an
## unmodified click belongs to the deployment page (W4), which shares this camera.
##
## WHY THE HOOKS SIT HERE AND NOT ON THE ARENA: a Camera2D transforms every CanvasItem in
## its viewport except the ones on a CanvasLayer, and the HUD (W5) lives on a layer for
## exactly that reason. The arena node stays a plain clock-and-rules object; this node owns
## the pixels the spectator moves through.
##
## THE SCREEN-CENTER ANCHOR is Godot's Camera2D default (anchor_mode CENTER_OF_SCREEN):
## `position` is the WORLD point drawn at the screen's middle. That is what makes the two
## zoom knobs (wheel, keys) cheap: multiplying `zoom` about a fixed `position` keeps the
## centre of the screen looking at the same patch of grass.

## The field this camera looks at, DUCKED on purpose: it is asked only for the three gate
## methods BrawlField documents (cell_px / board_cols / board_rows), so the camera follows
## the board through the same doors the engine does - and war.gd needs no WarCamera class
## in scope to hand one over (AGENTS §1.4's registration window, same alias-free reason).
var field = null

var _fit := 1.0                  # the last computed fit zoom, refreshed each frame
var _dragging := false
var _drag_last := Vector2.ZERO
var _redraw_zoom := 0.0           # the zoom the field's current picture was drawn at [W11]


func set_world(p_field) -> void:
	## Point the camera at the field it frames, and start at "all of it on screen".
	field = p_field
	_dragging = false
	fit()


# ---------------------------------------------------------------- the fit
func _view_px() -> Vector2:
	## LOGICAL viewport pixels - the canvas_items/expand contract every page in this project
	## reads through the same door (never a 1280x720 literal).
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2.ZERO


func _board_px() -> Vector2:
	if field == null:
		return Vector2.ZERO
	return Vector2(float(field.board_cols()), float(field.board_rows())) * field.cell_px()


func _fit_zoom() -> float:
	## The zoom that puts the WHOLE battlefield on screen, minus the strip the self-drawn
	## HUD will eat at the top. Computed, never stored as law: the window moves, the world
	## does not, and this number is the camera's floor by relation to it.
	var view := _view_px()
	var board := _board_px()
	if board.x <= 0.0 or board.y <= 0.0 or view.x <= 0.0 or view.y <= 0.0:
		return 1.0
	var avail_y := maxf(view.y - BalanceWar.CAMERA_HUD_RESERVED_PX, 1.0)
	return minf(view.x / board.x, avail_y / board.y) * BalanceWar.CAMERA_FIT_PAD


func _min_zoom() -> float:
	return _fit_zoom() * BalanceWar.CAMERA_MIN_ZOOM_SHARE


func fit() -> void:
	## "Show me the whole field": the opening framing, and what a map change re-anchors to.
	var z := _fit_zoom()
	zoom = Vector2(z, z)
	_clamp_position()


# ---------------------------------------------------------------- the frame
func _process(p_delta: float) -> void:
	if field == null or not is_enabled():
		return
	## [W3] The floor is recomputed EVERY frame, which is also the whole resize policy:
	## growing a window raises the fit and drags a fitted view with it, shrinking one lets a
	## zoomed-out view snap to the new floor, and a board never changes its own pixels.
	var floor_z := _min_zoom()
	if zoom.x < floor_z:
		zoom = Vector2(floor_z, floor_z)
	_pan_keys(p_delta)
	_clamp_position()
	## [W11] THE GROUND BUYS ITS STROKES IN SCREEN PIXELS (WarField._screen_stroke reads this
	## camera's zoom when it draws the lattice, seam and frame), which makes the field's
	## PICTURE a function of the zoom - and moving a camera never redraws what it looks at.
	## One epsilon-tracked number: when the zoom left the value the standing picture was drawn
	## for, ask the field for a fresh one. Wheel and +/- land here through _set_zoom, a window
	## resize through the floor clamp above; the first tick after fit() redrawing the ground
	## once is free.
	if absf(zoom.x - _redraw_zoom) > 0.001:
		_redraw_zoom = zoom.x
		field.queue_redraw()


func _pan_keys(p_delta: float) -> void:
	## WASD, POLLED rather than event-driven: a held key must keep gliding with no auto-repeat
	## stutter, and the project's idiom for raw keys is the _input family - of which polling is
	## the no-events-at-all member. The speed DIVIDES BY ZOOM, so the screen glides at the
	## same on-screen rate at every zoom while the world itself always passes at
	## CAMERA_PAN_PX_PER_SECOND absolute pixels a second (BalanceWar's comment for the number).
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	position += dir.normalized() * BalanceWar.CAMERA_PAN_PX_PER_SECOND * p_delta / zoom.x


func _clamp_position() -> void:
	## THE EDGE CLAMP: keep the board inside the frame. An axis whose WHOLE world fits the
	## view centres that axis (panning further would only slide wall past); otherwise the
	## screen-centre anchor may travel no further than the view's own half reaches inside.
	var board := _board_px()
	if board.x <= 0.0 or board.y <= 0.0:
		return
	var half := _view_px() / zoom * 0.5
	var x := board.x * 0.5 if half.x * 2.0 >= board.x \
		else clampf(position.x, half.x, board.x - half.x)
	var y := board.y * 0.5 if half.y * 2.0 >= board.y \
		else clampf(position.y, half.y, board.y - half.y)
	position = Vector2(x, y)


# ---------------------------------------------------------------- the page's doors [W4]
## THE FORMATION PAGE SHARES THIS MATHEMATICS (plan section C: "布阵页共用同一台相机").
## The page runs a disabled camera instance of this same class and does its own drawing, so
## what it borrows is the three conversions and the fit - the exact numbers a live camera
## would be looking through. Page space is a rectangle in LOGICAL viewport pixels (the page
## fills the window), which is why every conversion below carries `page_rect.position`: the
## arena's own screen space is the whole viewport, the page's is the strip it chose.

func page_fit_zoom(p_view_rect: Rect2) -> float:
	## The zoom that fits the WHOLE board inside p_view_rect (the page subtracts its own
	## header/shelf strips from the rect BEFORE asking - CAMERA_HUD_RESERVED_PX belongs to
	## the arena's HUD and is not subtracted twice here).
	var board := _board_px()
	if board.x <= 0.0 or board.y <= 0.0 or p_view_rect.size.x <= 0.0 \
			or p_view_rect.size.y <= 0.0:
		return 1.0
	return minf(p_view_rect.size.x / board.x, p_view_rect.size.y / board.y) \
		* BalanceWar.CAMERA_FIT_PAD


func world_to_page(p_world: Vector2, p_view_rect: Rect2) -> Vector2:
	## The screen-centre anchor is what makes this one line: `position` is the world point
	## drawn at the VIEW's middle, and zoom scales about it.
	return (p_world - position) * zoom + p_view_rect.get_center()


func page_to_world(p_page: Vector2, p_view_rect: Rect2) -> Vector2:
	## The exact inverse of the line above - the page hit-tests with this, so a click lands
	## on the cell it was drawn on and the two can never drift.
	return (p_page - p_view_rect.get_center()) / zoom + position


func visible_world_rect(p_view_rect: Rect2) -> Rect2:
	## How much of the world p_view_rect shows right now - the page's draw loop bounds.
	var half := p_view_rect.size / zoom * 0.5
	return Rect2(position - half, half * 2.0)


## [W7] THE PAGE MOVES ITS EYES. The plan deferred "free pan on the deployment page" until a
## bigger board made it a need; the fit-lock was opened here and nowhere else, because the
## page and the arena share this node's math and a second camera copy would drift. These
## doors are pure arithmetic on `zoom`/`position` - they never touch is_enabled(), and the
## page's disabled instance runs them just the same as the arena's live one.

func page_zoom_limits(p_view_rect: Rect2) -> Vector2:
	## The page's own ladder, measured against the page's own box: floor = a share of the
	## page FIT (not the viewport's), top = the inspection zoom. Returned as (min, max).
	var floor_z := page_fit_zoom(p_view_rect) * BalanceWar.WAR_PAGE_ZOOM_MIN_SHARE
	return Vector2(floor_z, maxf(BalanceWar.CAMERA_MAX_ZOOM, BalanceWar.WAR_PAGE_ZOOM_MAX))


func page_clamp_position(p_view_rect: Rect2) -> void:
	## The arena's edge clamp with the page's box in it: the half-reach is measured against
	## p_view_rect, not the whole viewport - the page's view does not extend over its own
	## shelf strips, and sliding the board there would hide the very cells being placed.
	var board := _board_px()
	if board.x <= 0.0 or board.y <= 0.0:
		return
	var half := p_view_rect.size / zoom * 0.5
	var x := board.x * 0.5 if half.x * 2.0 >= board.x \
		else clampf(position.x, half.x, board.x - half.x)
	var y := board.y * 0.5 if half.y * 2.0 >= board.y \
		else clampf(position.y, half.y, board.y - half.y)
	position = Vector2(x, y)


func page_pan_by(p_delta_page: Vector2, p_view_rect: Rect2) -> void:
	## The grab: screen pixels of motion divided by the zoom - the grass under the cursor is
	## what is being dragged, the arena's rule kept for the page.
	position -= p_delta_page / zoom.x
	page_clamp_position(p_view_rect)


func page_zoom_about(p_zoom: float, p_anchor_page: Vector2, p_view_rect: Rect2) -> void:
	## The wheel, gripped on the cursor. The arena zooms about the SCREEN CENTRE (Camera2D's
	## anchor and the reason its `position` is one number); a placement page wants the cell
	## under the pointer to STAY under the pointer, so the world point gripped before the
	## change is solved back onto the anchor after it - one line of the inverse of
	## world_to_page, and the ladder's clamp keeps "past the whole board" out of reach.
	var lim := page_zoom_limits(p_view_rect)
	var z := clampf(p_zoom, lim.x, lim.y)
	var grip := page_to_world(p_anchor_page, p_view_rect)
	zoom = Vector2(z, z)
	position = grip - (p_anchor_page - p_view_rect.get_center()) / z
	page_clamp_position(p_view_rect)


func _set_zoom(z: float) -> void:
	var clamped := clampf(z, _min_zoom(), BalanceWar.CAMERA_MAX_ZOOM)
	zoom = Vector2(clamped, clamped)
	_clamp_position()


# ---------------------------------------------------------------- the gestures
func _unhandled_input(event: InputEvent) -> void:
	## UNHANDLED on purpose: a front-end page sitting above the world still gets its buttons,
	## and only gestures nobody else wanted reach the camera. Keys the arena claims (SPACE /
	## F / R / ESC) are marked handled in its own _input, so they never arrive here.
	if field == null or not is_enabled():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.ctrl_pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_set_zoom(zoom.x * BalanceWar.CAMERA_ZOOM_STEP)
					get_viewport().set_input_as_handled()
					return
				MOUSE_BUTTON_WHEEL_DOWN:
					_set_zoom(zoom.x / BalanceWar.CAMERA_ZOOM_STEP)
					get_viewport().set_input_as_handled()
					return
				MOUSE_BUTTON_LEFT:
					## Ctrl + left-drag: the grab. Press starts it, release ends it, and both
					## mark the click handled so the world below never sees a ctrl+click that
					## was really "I grabbed the map".
					if mb.pressed:
						_dragging = true
						_drag_last = mb.position
						get_viewport().set_input_as_handled()
					return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion and _dragging:
		## [W7b] THE GRIP IS THE MODIFIER: letting go of ctrl mid-drag lets go of the map
		## (the user's ruling, stated the same words on this camera and the page's grab).
		## The camera just stands down - nothing is marked handled, because a motion that
		## is no longer a drag is no longer the camera's to swallow.
		var mm := event as InputEventMouseMotion
		if not mm.ctrl_pressed:
			_dragging = false
			return
		## Screen pixels of motion, divided by the zoom: the grass under the cursor is what
		## is being dragged, so the grab keeps its grip at every zoom.
		position -= (mm.position - _drag_last) / zoom.x
		_drag_last = mm.position
		_clamp_position()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_set_zoom(zoom.x * BalanceWar.CAMERA_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_set_zoom(zoom.x / BalanceWar.CAMERA_ZOOM_STEP)
				get_viewport().set_input_as_handled()
