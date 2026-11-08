class_name RoadmapView
extends RunScreen
## [P31-UI] CAMPAIGN ROUTE, drawn as an ICON GRAPH: one column per layer
## (left -> right), one tile per node carrying its type's picture, and an edge for
## every `next` link - so the branching finally reads the way it is played. It
## still owns no rule: Game decides which nodes are open (run_open_choices) and
## what entering one does (enter_run_node); this page only prints run_map_rows()
## and paints the state the rows carry (current / open / done / locked).
##
## HOW IT IS BUILT. The base RunScreen hands every page a pool of row buttons;
## the roadmap overrides the ONE hook the base grew for it - _layout_rows() - to
## place those buttons as tiles instead of text lines and to cache the graph
## (centres, sides, edges) in _nodes for _draw(). The pooled buttons are kept
## transparent OVER their tile, so pressing a node is still a real button press:
## mouse, keyboard focus and "only open nodes answer" all stay where they were.
## refresh() re-centres the cache deliberately: the base relabels its buttons
## from the rows, and here the VISIBLE text lives on the canvas, so every refresh
## must re-run the layout or a live language switch would leave stale titles (and
## the emptied buttons would grow their old labels back).
##
## The three body lines are the run's wallet: money carried, live mods, pouch
## loot. BACK here means "put the run away", not "quit it" - the save stays, and
## the menu offers CONTINUE (Game.show_main_menu keeps run.json; ESC shares this
## exact path).

var _nodes: Array = []                  # graph draw cache, rebuilt by _layout_rows
var _tex: Dictionary = {}               # art path -> Texture2D (null = keep drawing)
var _tile_bg: StyleBoxFlat = null       # reused for every tile: only the rect changes
var _tile_edge: StyleBoxFlat = null     # border-only twin, recoloured per state
var _lit_slot := -1                     # the hovered/focused node button, -1 = none


func _collect_and_wire() -> void:
	## [P107] the shared skeleton first (the page's scene declares it), then this page's own
	## decoration: bare click areas, because the tile is drawn on the canvas underneath.
	super._collect_and_wire()
	## The pooled buttons arrive styled like every other run page's row buttons.
	## Here the VISIBLE tile is drawn on the canvas underneath, so any panel -
	## above all the hover/pressed/focus boxes, which are OPAQUE and would bury
	## the node art - has to go; the button stays as a bare click area and the
	## hover answer moves onto the canvas with it (_lit_slot).
	var empty := StyleBoxEmpty.new()
	for i in _row_btns.size():
		var btn := _row_btns[i] as Button
		for sb in ["normal", "hover", "pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(sb, empty)
		btn.mouse_entered.connect(_on_node_lit.bind(i, true))
		btn.mouse_exited.connect(_on_node_lit.bind(i, false))
		btn.focus_entered.connect(_on_node_lit.bind(i, true))
		btn.focus_exited.connect(_on_node_lit.bind(i, false))


func _on_node_lit(p_slot: int, p_on: bool) -> void:
	var want := p_slot if p_on else -1
	if want != _lit_slot:
		_lit_slot = want
		queue_redraw()


func _screen_title() -> String:
	return Loc.t("run.map.title")


func _screen_subtitle() -> String:
	var subtitle_name := ""
	if game != null and game.chapter != null:
		subtitle_name = game.chapter.display_name()
	return Loc.tf("run.map.subtitle", [subtitle_name if subtitle_name != "" else "-"])


func _screen_hint() -> String:
	return Loc.t("run.map.hint")


func _body_lines() -> Array[String]:
	var out: Array[String] = []
	if game == null or game.run == null:
		return out
	out.append(Loc.tf("run.map.wallet", [int(game.money_amount())]))
	out.append(Loc.tf("run.map.mods", [game.run.mods_text()]))
	out.append(Loc.tf("run.map.pouch", [game.run.pouch_text()]))
	return out


func refresh() -> void:
	## The rows the base just re-read are the graph's ONLY data: rebuild the node
	## cache and the button overlay from them (see the class comment for the why).
	super.refresh()
	on_layout_changed()


# ---------------------------------------------------------------- rows -> nodes
func _read_rows() -> Array:
	## Group the flat node list by layer, exactly as the text version did; a GROUP
	## is now a graph COLUMN instead of a line of buttons.
	var rows: Array = game.run_flow.run_map_rows() if game != null else []
	var layers: Array = []
	for entry in rows:
		var row: Dictionary = entry
		var layer := int(row.get("layer", 0))
		while layers.size() <= layer:
			layers.append([])
		(layers[layer] as Array).append(_row_dict(row))
	return layers


func _row_dict(p_row: Dictionary) -> Dictionary:
	## Keeps the base contract (text / enabled / color - the text now only feeds
	## the tile's TOOLTIP, so hovering a node still says "X · 已完成" in words)
	## and adds the fields the graph draws with (type / state / next / fee).
	var title := str(p_row.get("title", "?"))
	var done := bool(p_row.get("done", false))
	var open := bool(p_row.get("open", false))
	var current := bool(p_row.get("current", false))
	var fee := int(p_row.get("fee", 0))
	var state := "locked"
	if current:
		state = "current"
	elif open:
		state = "open"
	elif done:
		state = "done"
	var parts := PackedStringArray([title])
	if current:
		parts.append(">")
	elif done:
		parts.append(Loc.t("run.map.state.done"))
	elif open:
		parts.append(Loc.t("run.map.state.open"))
	else:
		parts.append(Loc.t("run.map.state.locked"))
	var text := " · ".join(parts)
	if fee > 0:
		text += "  (%s)" % Loc.tf("run.map.fee", [fee])
	var color: Color = BalanceUI.COLOR_RUN_LOCKED
	if current:
		color = BalanceUI.COLOR_RUN_PICKED
	elif open:
		color = BalanceUI.COLOR_RUN_OPEN
	elif done:
		color = BalanceUI.COLOR_RUN_DONE
	return {
		"text": text,
		"enabled": open,
		"color": color,
		"id": str(p_row.get("id", "")),
		"type": str(p_row.get("type", "")),
		"title": title,
		"state": state,
		"fee": fee,
		"next": (p_row.get("next", []) as Array).duplicate(),
	}


func _on_row_pressed(p_group: int, p_index: int) -> void:
	if game == null:
		return
	var row: Dictionary = (_groups[p_group] as Array)[p_index] as Dictionary
	## Entering a node LEAVES this page (battle / shop / node page). If Game ever
	## refuses (not an open choice - it cannot be pressed while disabled, but a
	## stale frame could), stay put loudly instead of pretending.
	if not bool(game.run_flow.enter_run_node(str(row.get("id", "")))):
		_status = Loc.t("run.map.state.locked")
		refresh()


# ---------------------------------------------------------------- graph geometry
func _layout_rows(p_top: float) -> float:
	## Places the pooled buttons as tiles and records the graph, then returns the
	## y just below the band so the base stacks status / footers / BACK under it
	## like on every other run page.
	_build_nodes(p_top)
	_place_node_buttons()
	var bottom := p_top
	for node in _nodes:
		bottom = maxf(bottom, float((node as Dictionary)["bottom"]))
	return bottom


func _build_nodes(p_top: float) -> void:
	## Columns = layers spread across the width; inside a column the tiles stack
	## centred on the band. Everything derives from Layout.size, so the graph
	## reflows on any window instead of assuming the design 1280 x 720.
	_nodes.clear()
	var layers := _groups.size()
	if layers == 0:
		return
	var left := BalanceUI.RUN_GRAPH_PAD_X
	var right := maxf(left + 1.0, Layout.size.x - BalanceUI.RUN_GRAPH_PAD_X)
	var band_h := maxf(BalanceUI.RUN_GRAPH_MIN_H,
		Layout.size.y - p_top - BalanceUI.RUN_GRAPH_BOTTOM_RESERVE)
	var band_mid := p_top + band_h * 0.5
	var col_w := (right - left) / float(layers)
	## One tile size for the WHOLE graph (the edges assume it): shrink it so the
	## busiest column fits, in both directions, but never below the readable floor.
	var busiest := 1
	for group in _groups:
		busiest = maxi(busiest, (group as Array).size())
	var fit_w := col_w * BalanceUI.RUN_NODE_COL_SHARE
	var fit_h := band_h / float(busiest) * BalanceUI.RUN_NODE_ROW_SHARE
	var s := clampf(minf(fit_w, fit_h), BalanceUI.RUN_NODE_MIN, BalanceUI.RUN_NODE_MAX)
	var pitch_y := minf(BalanceUI.RUN_NODE_PITCH_Y, s + BalanceUI.RUN_GRAPH_LABEL_H * 2.0)
	if busiest > 1:
		## …and never let the stack outgrow the band itself (short windows compress
		## the pitch before the status line gets pushed off-screen).
		pitch_y = minf(pitch_y,
			(band_h - s - BalanceUI.RUN_GRAPH_LABEL_H * 2.0) / float(busiest - 1))
	pitch_y = maxf(pitch_y, s * 0.5)   # tiles may touch, but never swallow each other
	var label_w := minf(col_w - 8.0, s * 2.2)
	var k := 0
	for li in layers:
		var cells: Array = _groups[li]
		var n := maxi(1, cells.size())
		var cx := left + (float(li) + 0.5) * col_w
		for j in cells.size():
			var row: Dictionary = cells[j]
			var cy := band_mid + (float(j) - float(n - 1) * 0.5) * pitch_y
			_nodes.append({
				"id": str(row.get("id", "")),
				"type": str(row.get("type", "")),
				"title": str(row.get("title", "")),
				"state": str(row.get("state", "")),
				"fee": int(row.get("fee", 0)),
				"next": (row.get("next", []) as Array),
				"center": Vector2(cx, cy),
				"side": s,
				"label_w": label_w,
				"slot": k,           # the pooled button covering this tile (_lit_slot)
				# the fee line hangs under the title on retry nodes: count both
				"bottom": cy + s * 0.5 + BalanceUI.RUN_GRAPH_LABEL_H \
					+ (float(BalanceUI.FONT_SIZE_RUN_NODE_FEE) + 2.0 if int(row.get("fee", 0)) > 0 else 0.0),
			})
			k += 1


func _place_node_buttons() -> void:
	## Overlay one pooled button on each node, in the SAME order _nodes uses
	## (group-major, which is what _slot_map walks too) so presses still route
	## through the base untouched. The button carries no text and no panel here:
	## the tile is drawn on the canvas, the button only catches press and focus.
	var k := 0
	for group in _groups:
		var cells: Array = group
		for j in cells.size():
			if k >= _row_btns.size() or k >= _nodes.size():
				break   # the pool is the cap; nodes past it are drawn, just unclickable
			var node: Dictionary = _nodes[k]
			var btn := _row_btns[k] as Button
			var side := float(node["side"])
			_place(btn, (node["center"] as Vector2) - Vector2.ONE * side * 0.5,
				Vector2.ONE * side)
			btn.flat = true
			btn.text = ""
			btn.tooltip_text = str((cells[j] as Dictionary).get("text", ""))
			k += 1


func _node_by_id(p_id: String) -> Dictionary:
	for node in _nodes:
		if str((node as Dictionary)["id"]) == p_id:
			return node
	return {}


func _node_edge(p_from: Vector2, p_to: Vector2, p_side: float) -> Vector2:
	## A point on the tile's border in the direction of the other end, so edges
	## start and stop AT the tiles instead of crossing under them.
	var dir: Vector2 = p_to - p_from
	if dir == Vector2.ZERO:
		return p_from
	return p_from + dir.normalized() * (p_side * 0.5 + BalanceUI.RUN_LINE_W)


func _icon_texture(p_type: String) -> Texture2D:
	var path := str(BalanceUI.RUN_NODE_ART.get(p_type, ""))
	if path == "":
		return null
	if not _tex.has(path):
		_tex[path] = UnitArt.load_texture(path)
	return _tex[path] as Texture2D


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	super._draw()          # background + title / subtitle / hint, then the graph
	if _nodes.is_empty():
		return
	var side := float((_nodes[0] as Dictionary)["side"])
	# edges first, so the tiles always sit on top of them
	for node_v in _nodes:
		var node: Dictionary = node_v
		var state := str(node["state"])
		var center: Vector2 = node["center"]
		for nxt_v in (node["next"] as Array):
			var target := _node_by_id(str(nxt_v))
			if target.is_empty():
				continue
			var to: Vector2 = target["center"]
			var to_state := str(target["state"])
			var col: Color = BalanceUI.COLOR_RUN_LINE
			if state == "done" and (to_state == "open" or to_state == "current"):
				col = BalanceUI.COLOR_RUN_LINE_LIVE   # the road ahead, lit
			elif state == "done" and to_state == "done":
				col = BalanceUI.COLOR_RUN_LINE_DONE   # a road already walked
			draw_line(_node_edge(center, to, side), _node_edge(to, center, side),
				col, BalanceUI.RUN_LINE_W, true)
	for node_v in _nodes:
		_draw_node(node_v as Dictionary, side)


func _draw_node(p_node: Dictionary, p_side: float) -> void:
	var center: Vector2 = p_node["center"]
	var state := str(p_node["state"])
	var half := p_side * 0.5
	var box := Rect2(center - Vector2.ONE * half, Vector2.ONE * p_side)
	var ring: Color = BalanceUI.COLOR_RUN_LOCKED
	match state:
		"current":
			ring = BalanceUI.COLOR_RUN_PICKED
		"open":
			ring = BalanceUI.COLOR_RUN_OPEN
		"done":
			ring = BalanceUI.COLOR_RUN_DONE
	_ensure_tile()
	_tile_bg.draw(self, box)
	_tile_edge.set_border_width_all(int(BalanceUI.RUN_TILE_BORDER_W))
	match state:
		"current":
			_tile_edge.set_border_width_all(int(BalanceUI.RUN_TILE_CURRENT_W))
		"open":
			_tile_edge.set_border_width_all(int(BalanceUI.RUN_TILE_LIVE_W))
	_tile_edge.border_color = ring
	_tile_edge.draw(self, box)
	if int(p_node["slot"]) == _lit_slot:
		## The buttons are panels with no visuals here, so the mouse / keyboard
		## answer is drawn too: one pale line just outside the tile's own edge.
		draw_rect(box.grow(2.5), Color(1.0, 1.0, 1.0, 0.30), false, 2.0)
	## the node picture, dimmed for a locked tile so "not yet" reads without colour;
	## a missing / not-yet-imported SVG leaves the ring and the title, never a hole
	var tex := _icon_texture(str(p_node["type"]))
	if tex != null:
		var icon_side := p_side * BalanceUI.RUN_NODE_ICON_SHARE
		var tint := Color(1.0, 1.0, 1.0, 1.0)
		if state == "locked":
			tint = BalanceUI.COLOR_RUN_ICON_DIM
		elif state == "done":
			tint = BalanceUI.COLOR_RUN_ICON_DONE
		draw_texture_rect(tex,
			Rect2(center - Vector2.ONE * icon_side * 0.5, Vector2.ONE * icon_side), false, tint)
	# the title under the tile (+ the retry fee line where one is due)
	var label_w := float(p_node["label_w"])
	var font := ThemeDB.fallback_font
	var label := UiStyle.fit_text(font, str(p_node["title"]),
		BalanceUI.FONT_SIZE_RUN_NODE_LABEL, label_w)
	var ly := center.y + half + float(BalanceUI.FONT_SIZE_RUN_NODE_LABEL) + 5.0
	draw_string(font, Vector2(center.x - label_w * 0.5, ly), label,
		HORIZONTAL_ALIGNMENT_CENTER, label_w, BalanceUI.FONT_SIZE_RUN_NODE_LABEL, ring)
	var fee := int(p_node["fee"])
	if fee > 0:
		var fee_text := Loc.tf("run.map.fee", [fee])
		draw_string(font, Vector2(center.x - label_w * 0.5,
			ly + float(BalanceUI.FONT_SIZE_RUN_NODE_FEE) + 2.0),
			UiStyle.fit_text(font, fee_text, BalanceUI.FONT_SIZE_RUN_NODE_FEE, label_w),
			HORIZONTAL_ALIGNMENT_CENTER, label_w, BalanceUI.FONT_SIZE_RUN_NODE_FEE,
			BalanceUI.COLOR_MONEY)


func _ensure_tile() -> void:
	## The two StyleBoxes are built once and re-used for every tile on every frame:
	## only the rect and the border fields change between draws.
	if _tile_bg != null:
		return
	_tile_bg = StyleBoxFlat.new()
	_tile_bg.bg_color = BalanceUI.COLOR_RUN_NODE_BG
	_tile_bg.set_corner_radius_all(int(BalanceUI.RUN_NODE_CORNER))
	_tile_edge = StyleBoxFlat.new()
	_tile_edge.draw_center = false
	_tile_edge.set_corner_radius_all(int(BalanceUI.RUN_NODE_CORNER))
