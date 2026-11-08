class_name DeckView
extends RunScreen
## [P32-UI] SEED PICKING, drawn like the original: the TOP band is a row of
## BATTLE_DECK_SLOTS seed SLOTS (click one to put its card back), and under it the
## cards the player owns. No text rows any more - every cell is a tile with the plant's
## picture,
##
## [P98] and that lower half is TWO REGIONS: 花园卷轴 left, 灵界卷轴 right, each showing ONE
## PAGE of DECK_REGION_COLS x DECK_REGION_ROWS tiles with a shared page bar under them.
## Placed from _metrics(), audited by self_check() at the smallest logical page size.
## its name and its sun cost, in the roadmap's visual vocabulary (RoadmapView's
## architecture: the pooled run-screen buttons stay as transparent click/focus
## areas over the canvas-drawn tiles, so mouse, keyboard focus and the refusal
## messages all keep running through the base untouched).
##
## The page still owns no rule: the flow answers every click (deck_slots / deck_rows
## to read, deck_put / deck_take to write, confirm_deck to leave) and holds the
## uncommitted pick list [P109] in FrontEndFlow._deck_pick, so walking away mid-pick
## loses nothing - and the scene's own death on leave cannot take the pick with it.
##
## State reads on a tile: filled slot = art + name + cost; empty slot = a dim
## recess, unclickable; pool card already on deck = dimmed art + gold frame (the
## same frame language says "this one is up there"); no-scroll card = greyed,
## and the click STILL answers in words - the squad page's teaching rule.
var profile: Profile
## [P109] `var battle: Battle` was a dead port shadow: on this page Game's battle handle
## is null (the board is not up yet), and the two calls that reached for it wanted the
## FLOW's pending path and the BATTLE MAIN's start_level. Both now go through `game.`.

var _tiles: Array = []                  # draw cache, rebuilt by _layout_rows
var _heads: Array = []                  # band headings: {baseline, text}
var _tex: Dictionary = {}               # art path -> Texture2D (null = keep drawing)
var _tile_bg: StyleBoxFlat = null       # one bg StyleBox for every tile
var _tile_edge: StyleBoxFlat = null     # border-only twin, recoloured per state
var _lit_slot := -1                     # the hovered/focused tile button, -1 = none
## [P98] The two paged regions: REGION_GARDEN / REGION_SPIRIT index _pool, and _page is the
## page BOTH of them show (the bar under them turns the two together).
const REGION_GARDEN := 0
const REGION_SPIRIT := 1
var _pool: Array = [[], []]             # the whole roster, split: garden / spirit
var _page := 0
@onready var _page_prev: Button = $PagePrev
@onready var _page_next: Button = $PageNext
@onready var _page_label: Label = $PageLabel

## [P109] The page used to keep its own `_deck_pick` / `_battle_deck` — a second copy of
## the scratch Game (now FrontEndFlow) owns. The page reads and writes THE one list.


# ---------------------------------------------------------------- build / lit
func _collect_and_wire() -> void:
	## [P107] the shared skeleton first (the page's scene declares it), then the two things this
	## page adds: bare click areas for the tiles, and the shared page bar.
	super._collect_and_wire()
	## The pooled buttons arrive styled as text rows. Here the VISIBLE tile is
	## drawn on the canvas underneath, so every panel - above all the opaque
	## hover/pressed/focus boxes - has to go; the button stays a bare click area
	## and the hover answer moves onto the canvas with it (_lit_slot).
	var empty := StyleBoxEmpty.new()
	for i in _row_btns.size():
		var btn := _row_btns[i] as Button
		for sb in ["normal", "hover", "pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(sb, empty)
		btn.mouse_entered.connect(_on_tile_lit.bind(i, true))
		btn.mouse_exited.connect(_on_tile_lit.bind(i, false))
		btn.focus_entered.connect(_on_tile_lit.bind(i, true))
		btn.focus_exited.connect(_on_tile_lit.bind(i, false))
	## [P98] The shared page bar (grid.page* labels); hidden while the roster fits one page. The
	## three nodes come from the scene; this names and styles them.
	UiStyle.style_button(_page_prev, Loc.t("grid.page.prev"), _on_page_pressed.bind(-1),
		BalanceUI.FONT_SIZE_BUTTON)
	UiStyle.style_button(_page_next, Loc.t("grid.page.next"), _on_page_pressed.bind(1),
		BalanceUI.FONT_SIZE_BUTTON)
	UiStyle.style_label(_page_label, "", BalanceUI.COLOR_MENU_SUB, HORIZONTAL_ALIGNMENT_CENTER,
		BalanceUI.FONT_SIZE_BUTTON)


func _on_tile_lit(p_slot: int, p_on: bool) -> void:
	var want := p_slot if p_on else -1
	if want != _lit_slot:
		_lit_slot = want
		queue_redraw()


# ---------------------------------------------------------------- header texts
func _screen_title() -> String:
	return Loc.t("deck.title")


func deck_pick_count() -> int:
	return game.front._deck_pick.size()
	

func _screen_subtitle() -> String:
	var picked: int = deck_pick_count() if game != null else 0
	return Loc.tf("deck.subtitle", [picked, BalanceBattle.BATTLE_DECK_SLOTS])


func _screen_hint() -> String:
	return Loc.tf("deck.hint", [BalanceBattle.BATTLE_DECK_SLOTS])


func refresh() -> void:
	## The tiles live on the canvas, not on the buttons the base just relabelled:
	## every refresh must re-run the layout, or a live language switch would leave
	## stale headings and the emptied buttons would grow their old labels back.
	super.refresh()
	on_layout_changed()


# ---------------------------------------------------------------- rows -> tiles
func deck_rows() -> Array:
	## [P32-UI] The POOL data: one entry per plant card of the roster, in
	## plant_cards() order (deck_put indexes this list). A card without its scroll
	## is shown but only answers with the refusal - the way a DOWNED plant does
	## on the squad page. "art" rides along so the tile needs no Balance access.
	var out: Array = []
	var index := 0
	for entry in Balance.plant_cards():
		var key := str(entry)
		var pickable: bool = profile.has_scroll_for(key)
		var scroll_text := Loc.t("deck.scroll_none")
		if pickable:
			var item: String = Balance.scroll_item_for(key)
			scroll_text = Loc.tf("deck.scroll_state",
				[profile.durability_of(item), Balance.item_max_durability(item)])
		out.append({
			"index": index,
			"id": key,
			"title": Balance.plant_name(key),
			"cost": Balance.plant_cost(key),
			"picked": game.front._deck_pick.has(key),
			"pickable": pickable,
			"art": Balance.plant_art(key),
			"spirit": Balance.spirit_base(key) != "",
			"scroll_text": scroll_text,
		})
		index += 1
	return out


func deck_slots() -> Array:
	## [P32-UI] The SEED SLOT band: exactly BATTLE_DECK_SLOTS entries, slot order
	## = pick order. A filled slot carries the card's display fields (looked up in
	## the same plant_cards() order the pool rows use); an empty one says so plainly.
	## deck_take indexes this list by position. "spirit" drives the tile's blue
	## tint + badge (a spirit card is summoned by a SPIRIT scroll).
	var out: Array = []
	for j in BalanceBattle.BATTLE_DECK_SLOTS:
		var id := deck_card_at(j)
		if id == "":
			out.append({"slot": j, "filled": false, "id": "", "title": "",
				"cost": 0, "art": "", "text": "", "enabled": false, "spirit": false})
			continue
		out.append({
			"slot": j,
			"filled": true,
			"id": id,
			"title": Balance.plant_name(id),
			"cost": Balance.plant_cost(id),
			"art": Balance.plant_art(id),
			"spirit": Balance.spirit_base(id) != "",
			"text": "%s  %s" % [Balance.plant_name(id), Loc.tf("hud.card.cost",
				[Balance.plant_cost(id)])],
			"enabled": true,
		})
	return out


func _read_rows() -> Array:
	## [P98] Group 0 = the seed slots; groups 1 / 2 = ONE PAGE of the garden and of the spirit
	## scrolls. Group-major order is what the base's _slot_map walks AND what _layout_rows
	## overlays, so the two stay in step.
	_pool = [[], []]
	var out: Array = []
	if game == null:
		return out
	_pool = _split_rows(deck_rows())
	out.append(deck_slots().map(func(p): return _slot_dict(p as Dictionary)))
	_page = clampi(_page, 0, _pages() - 1)
	var start := _page * _page_size()
	for region in 2:
		var section: Array = _pool[region]
		var cells: Array = []
		for entry in section.slice(mini(start, section.size()), start + _page_size()):
			cells.append(_pool_dict(entry as Dictionary))
		out.append(cells)
	return out


func _slot_dict(p_row: Dictionary) -> Dictionary:
	return {
		"kind": "slot",
		"slot": int(p_row.get("slot", -1)),
		"text": str(p_row.get("text", "")),
		"enabled": bool(p_row.get("enabled", false)),
		"color": BalanceUI.COLOR_TEXT,
		"title": str(p_row.get("title", "")),
		"cost": int(p_row.get("cost", 0)),
		"art": str(p_row.get("art", "")),
		"spirit": bool(p_row.get("spirit", false)),
		"filled": bool(p_row.get("filled", false)),
		"pickable": true,
		"picked": false,
	}


func _pool_dict(p_row: Dictionary) -> Dictionary:
	var picked := bool(p_row.get("picked", false))
	var pickable := bool(p_row.get("pickable", true))
	var text := "%s  %s  %s" % [str(p_row.get("title", "")),
		Loc.tf("hud.card.cost", [int(p_row.get("cost", 0))]),
		str(p_row.get("scroll_text", ""))]
	var color: Color = BalanceUI.COLOR_TEXT
	if not pickable:
		color = BalanceUI.COLOR_RUN_LOCKED
	elif picked:
		color = BalanceUI.COLOR_RUN_PICKED
	return {
		"kind": "pool",
		"index": int(p_row.get("index", -1)),
		"text": text,
		"enabled": true,          # a refusal still has to be ABLE to speak (squad rule)
		"color": color,
		"title": str(p_row.get("title", "")),
		"cost": int(p_row.get("cost", 0)),
		"art": str(p_row.get("art", "")),
		"spirit": bool(p_row.get("spirit", false)),
		"filled": true,
		"pickable": pickable,
		"picked": picked,
	}


# ---------------------------------------------------------------- geometry
func _layout_rows(p_top: float) -> float:
	## [P98] Seed slots, the two REGIONS side by side, the shared page bar - all from _metrics().
	_tiles.clear()
	_heads.clear()
	if _groups.is_empty():
		return p_top
	var m := _metrics(Layout.size)
	var side: float = m["side"]
	var label_h: float = BalanceUI.DECK_SLOT_LABEL_H
	var gap: float = BalanceUI.DECK_TILE_GAP
	var head_h: float = BalanceUI.DECK_HEAD_H
	var slot_side: float = BalanceUI.DECK_SLOT_TILE
	# --- seed slot band -------------------------------------------------------
	var cells: Array = _groups[0]
	_heads.append({"baseline": p_top + head_h - 6.0, "text": Loc.t("deck.head.slots")})
	var x0 := _line_start(float(cells.size()), slot_side, gap)
	for j in cells.size():
		_place_tile(cells[j] as Dictionary, Vector2(x0 + float(j) * (slot_side + gap),
			p_top + head_h), slot_side, label_h, _tiles.size())
	# --- the two paged regions ------------------------------------------------
	var titles := ["deck.head.garden", "deck.head.spirit"]
	var at_list: Array = m["at"]
	var k := _tiles.size()
	for region in 2:
		var at: Vector2 = at_list[region]
		_heads.append({"baseline": at.y + head_h - 6.0, "text": Loc.t(str(titles[region])),
			"x": at.x, "w": float(m["region_w"])})
		var row_cells: Array = _groups[region + 1] if region + 1 < _groups.size() else []
		for j in row_cells.size():
			var col := j % BalanceUI.DECK_REGION_COLS
			## [P109] floori on a float division: the row index wants the truncation, but a
			## bare `int / int` trips the editor's INTEGER_DIVISION warning - it cannot tell
			## an intended truncation from a lost fraction (same spelling as ItemGrid).
			var line := floori(float(j) / float(BalanceUI.DECK_REGION_COLS))
			k = _place_tile(row_cells[j] as Dictionary,
				Vector2(at.x + float(col) * (side + gap),
					at.y + head_h + float(line) * (side + label_h + gap)),
				side, label_h, k)
	_place_page_bar(m)
	return float(m["bottom"])


func _line_start(p_n: float, p_side: float, p_gap: float) -> float:
	## Centred line of p_n tiles inside the window.
	return floorf((Layout.size.x - (p_n * p_side + maxf(p_n - 1.0, 0.0) * p_gap)) * 0.5)


# ---------------------------------------------------------------- pages (P98)
static func _page_size() -> int:
	## How many cards ONE region shows at a time.
	return BalanceUI.DECK_REGION_COLS * BalanceUI.DECK_REGION_ROWS


static func _split_rows(p_rows: Array) -> Array:
	## [P98] deck_rows() in, [garden, spirit] out. self_check() walks the ROSTER through this
	## same function, so a card in the wrong region is a claim, not something to notice.
	var out: Array = [[], []]
	for entry in p_rows:
		var row: Dictionary = entry
		out[REGION_SPIRIT if bool(row.get("spirit", false)) else REGION_GARDEN].append(row)
	return out


static func _pages_needed(p_cards: int) -> int:
	return maxi(1, int(ceil(float(maxi(p_cards, 0)) / float(_page_size()))))


func _pages() -> int:
	## Both regions turn together, so the page count is the BUSIER side: the other one just
	## shows fewer cards on the last page.
	return _pages_needed(maxi((_pool[REGION_GARDEN] as Array).size(), (_pool[REGION_SPIRIT] as Array).size()))


func _on_page_pressed(p_delta: int) -> void:
	_page = wrapi(_page + p_delta, 0, _pages())
	refresh()


func _apply_static_texts() -> void:
	## The bar's own labels are chrome, so they follow a live language switch like every
	## other label here (the page NUMBER is written by _place_page_bar, which runs after the
	## rows are rebuilt - see RunScreen.refresh()'s order).
	super._apply_static_texts()
	if _page_prev != null:
		_page_prev.text = Loc.t("grid.page.prev")
		_page_prev.tooltip_text = Loc.t("grid.page.prev")
	if _page_next != null:
		_page_next.text = Loc.t("grid.page.next")
		_page_next.tooltip_text = Loc.t("grid.page.next")


func _place_page_bar(p_m: Dictionary) -> void:
	## Both regions always show the same page number, so one pair turns them together.
	var pages := _pages()
	var many := pages > 1
	var at: Vector2 = p_m["page_bar_at"]
	var h: float = BalanceUI.DECK_PAGE_BAR_H
	var bar_w: float = BalanceUI.DECK_PAGE_BTN_W * 2.0 + BalanceUI.DECK_PAGE_LABEL_W \
		+ BalanceUI.DECK_PAGE_GAP * 2.0
	if _page_prev != null:
		_page_prev.visible = many
		_page_prev.disabled = not many
		_place(_page_prev, at, Vector2(BalanceUI.DECK_PAGE_BTN_W, h))
	if _page_next != null:
		_page_next.visible = many
		_page_next.disabled = not many
		_place(_page_next, Vector2(at.x + bar_w - BalanceUI.DECK_PAGE_BTN_W, at.y),
			Vector2(BalanceUI.DECK_PAGE_BTN_W, h))
	if _page_label != null:
		_page_label.visible = many
		_page_label.text = Loc.tf("grid.page", [_page + 1, pages])
		_place(_page_label,
			Vector2(at.x + BalanceUI.DECK_PAGE_BTN_W + BalanceUI.DECK_PAGE_GAP, at.y),
			Vector2(BalanceUI.DECK_PAGE_LABEL_W, h))


static func _metrics(p_page: Vector2) -> Dictionary:
	## [P98] Window in, every rect out; self_check() audits the same numbers at
	## Balance.WINDOW_SIZE (regions that do not fit between the slots and the footer, or a
	## tile squeezed below DECK_TILE_MIN, would otherwise only show up on a screen).
	var gap: float = BalanceUI.DECK_TILE_GAP
	var head_h: float = BalanceUI.DECK_HEAD_H
	var label_h: float = BalanceUI.DECK_SLOT_LABEL_H
	var body: float = BalanceUI.RUN_TOP + head_h + BalanceUI.DECK_SLOT_TILE + label_h \
		+ BalanceUI.DECK_BAND_GAP
	## What the footer band takes below the regions (RunScreen._layout stacks it from the y
	## _layout_rows returns): the answer line, this page's footer button and BACK.
	var footer: float = BalanceUI.RUN_STATUS_H + BalanceUI.RUN_FOOTER_GAP \
		+ 2.0 * (BalanceUI.RUN_ROW_H + BalanceUI.RUN_ROW_GAP)
	var room := maxf(p_page.y - footer - body, 1.0)
	var bar_h: float = BalanceUI.DECK_PAGE_BAR_H
	var region_w: float = (p_page.x - BalanceUI.HUD_SIDE_MARGIN * 2.0 \
		- BalanceUI.DECK_REGION_GAP) * 0.5
	var rows := BalanceUI.DECK_REGION_ROWS
	var by_w: float = (region_w - float(BalanceUI.DECK_REGION_COLS - 1) * gap) \
		/ float(BalanceUI.DECK_REGION_COLS)
	var by_h: float = (room - head_h - bar_h - BalanceUI.DECK_PAGE_GAP \
		- float(rows - 1) * gap) / float(rows) - label_h
	var side := floorf(clampf(minf(by_w, by_h), BalanceUI.DECK_TILE_MIN, BalanceUI.DECK_TILE_SIDE))
	var region_h: float = head_h + float(rows) * (side + label_h) \
		+ float(rows - 1) * gap + BalanceUI.DECK_PAGE_GAP + bar_h
	var at := Vector2(BalanceUI.HUD_SIDE_MARGIN, body)
	var bar_w: float = BalanceUI.DECK_PAGE_BTN_W * 2.0 + BalanceUI.DECK_PAGE_LABEL_W \
		+ BalanceUI.DECK_PAGE_GAP * 2.0
	return {
		"side": side, "room": room, "region_w": region_w,
		"region_h": region_h,
		"at": [at, Vector2(at.x + region_w + BalanceUI.DECK_REGION_GAP, at.y)],
		"page_bar_at": Vector2(floorf((p_page.x - bar_w) * 0.5), at.y + region_h - bar_h),
		"bottom": at.y + region_h,
	}


static func self_check() -> void:
	## [P98] Without the screen: the two regions must fit the room the page leaves them, and
	## the page arithmetic closes over the REAL roster (Balance.plant_cards()).
	var m := _metrics(Vector2(Balance.WINDOW_SIZE))
	var side: float = m["side"]
	var per := _page_size()
	var roster: Array = []
	for entry in Balance.plant_cards():
		roster.append({"spirit": Balance.spirit_base(str(entry)) != ""})
	var split := _split_rows(roster)
	var garden: int = (split[REGION_GARDEN] as Array).size()
	var spirit: int = (split[REGION_SPIRIT] as Array).size()
	var pages := _pages_needed(maxi(garden, spirit))
	var fits: bool = side >= BalanceUI.DECK_TILE_MIN \
		and float(m["region_h"]) <= float(m["room"]) + 0.5
	var math_ok: bool = per == BalanceUI.DECK_REGION_COLS * BalanceUI.DECK_REGION_ROWS \
		and garden + spirit == Balance.plant_cards().size() and spirit > 0 and garden > 0
	var at: Vector2 = (m["at"] as Array)[0]
	print("[Deck] %d garden + %d spirit card(s), %d a page -> %d page(s); region %dx%d at (%d,%d), tile %d in %d..%d, room %d = %s | %s"
		% [garden, spirit, per, pages, int(m["region_w"]), int(m["region_h"]),
		   int(at.x), int(at.y), int(side), int(BalanceUI.DECK_TILE_MIN),
		   int(BalanceUI.DECK_TILE_SIDE), int(m["room"]), str(fits and math_ok),
		   "OK" if (fits and math_ok) else "FAIL"])
	print("[Deck] self-check %s" % ("PASSED" if (fits and math_ok) else "FAILED"))


func _place_tile(p_row: Dictionary, p_at: Vector2, p_side: float, p_label_h: float,
	p_k: int) -> int:
	## Records the tile for _draw and overlays pooled button p_k on it (same
	## group-major order as _slot_map, so presses route through the base).
	_tiles.append({
		"at": p_at,
		"side": p_side,
		"label_h": p_label_h,
		"slot": p_k,
		"kind": str(p_row.get("kind", "")),
		"title": str(p_row.get("title", "")),
		"cost": int(p_row.get("cost", 0)),
		"art": str(p_row.get("art", "")),
		"filled": bool(p_row.get("filled", false)),
		"picked": bool(p_row.get("picked", false)),
		"pickable": bool(p_row.get("pickable", true)),
		"spirit": bool(p_row.get("spirit", false)),
	})
	if p_k < _row_btns.size():
		var btn := _row_btns[p_k] as Button
		_place(btn, p_at, Vector2.ONE * p_side)
		btn.flat = true
		btn.text = ""
		btn.tooltip_text = str(p_row.get("text", ""))
	return p_k + 1


func _icon_texture(p_path: String) -> Texture2D:
	if p_path == "":
		return null
	if not _tex.has(p_path):
		_tex[p_path] = UnitArt.load_texture(p_path)
	return _tex[p_path] as Texture2D


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	super._draw()          # background + title / subtitle / hint
	if _tiles.is_empty():
		return
	var font := ThemeDB.fallback_font
	## [P98] A heading is centred inside ITS OWN box: the slot band's spans the page, and each
	## region's spans that region (otherwise both pool headings would sit on top of each other
	## in the middle of the window).
	for head in _heads:
		var h := head as Dictionary
		var hx := float(h.get("x", 0.0))
		var hw := float(h.get("w", Layout.size.x))
		draw_string(font, Vector2(hx, float(h["baseline"])), str(h["text"]),
			HORIZONTAL_ALIGNMENT_CENTER, hw, BalanceUI.FONT_SIZE_MENU_SUB, BalanceUI.COLOR_MENU_SUB)
	for tile in _tiles:
		_draw_tile(tile as Dictionary, font)


func _draw_tile(p_tile: Dictionary, p_font: Font) -> void:
	var side := float(p_tile["side"])
	var box := Rect2(p_tile["at"] as Vector2, Vector2.ONE * side)
	var kind := str(p_tile["kind"])
	var filled := bool(p_tile["filled"])
	var picked := bool(p_tile["picked"])
	var pickable := bool(p_tile["pickable"])
	_ensure_tile()
	_tile_bg.draw(get_canvas_item(), box)
	## One frame per state: the pool card ON deck wears the gold frame (it points
	## at its slot), a locked card greys out, the rest take the plain edge.
	var edge: Color = BalanceUI.COLOR_ITEM_TILE_BORDER
	var edge_w: float = BalanceUI.RUN_TILE_BORDER_W
	if not pickable:
		edge = BalanceUI.COLOR_RUN_LOCKED
	elif kind == "pool" and picked:
		edge = BalanceUI.COLOR_ITEM_TILE_SELECTED
		edge_w = BalanceUI.ITEM_TILE_SELECTED_W
	elif kind == "slot" and filled:
		edge = BalanceUI.COLOR_ITEM_TILE_SELECTED
		edge_w = BalanceUI.ITEM_TILE_SELECTED_W
	elif kind == "slot":
		edge = BalanceUI.COLOR_RUN_LOCKED
	_tile_edge.set_border_width_all(int(edge_w))
	_tile_edge.border_color = edge
	_tile_edge.draw(get_canvas_item(), box)
	if int(p_tile["slot"]) == _lit_slot:
		## The buttons have no panels here, so the mouse / keyboard answer is
		## drawn too: one pale line just outside the tile's own edge.
		draw_rect(box.grow(2.5), Color(1.0, 1.0, 1.0, 0.30), false, 2.0)
	if kind == "slot" and not filled:
		return          # the recess keeps its name + cost lines empty on purpose
	## the plant's picture; a locked card fades behind the grey, an enlisted one
	## dims a little so the pool reads "over there" against its bright slot twin;
	## a SPIRIT card wears the board's blue tint (the same COLOR_SPIRIT_TINT the
	## HUD and the lawn use - "发蓝 = 灵界" is already the player's lesson);
	## a missing SVG leaves the frame and the labels, never a hole
	var spirit := bool(p_tile.get("spirit", false))
	var tex := _icon_texture(str(p_tile["art"]))
	if tex != null:
		var icon := side * BalanceUI.RUN_NODE_ICON_SHARE
		var tint: Color = BalanceUI.COLOR_SPIRIT_TINT if spirit else Color(1.0, 1.0, 1.0, 1.0)
		if not pickable:
			## locked stays locked; only a SPIRIT one keeps its blue under the dim
			if not spirit:
				tint = BalanceUI.COLOR_RUN_ICON_DIM
			else:
				tint.a = BalanceUI.COLOR_RUN_ICON_DIM.a
		elif picked:
			tint.a = BalanceUI.ITEM_TILE_DIM_ALPHA
		draw_texture_rect(tex, Rect2((p_tile["at"] as Vector2)
			+ Vector2.ONE * (side - icon) * 0.5, Vector2.ONE * icon), false, tint)
	# [P32-UI] the scroll-kind corner chip: WHICH scroll summons this card -
	# green 园 for a garden scroll, blue 灵 for a spirit scroll. The colour pair
	# repeats the icon tint's message in a form that survives the small scale.
	var badge_side: float = BalanceUI.DECK_BADGE_SIDE
	var chip := Rect2(box.position + Vector2(side - BalanceUI.DECK_BADGE_INSET - badge_side,
		BalanceUI.DECK_BADGE_INSET), Vector2.ONE * badge_side)
	draw_rect(chip, BalanceUI.COLOR_SPIRIT_TINT if spirit
		else BalanceUI.COLOR_DECK_BADGE_GARDEN)
	draw_string(p_font, Vector2(chip.position.x, chip.position.y + badge_side * 0.8),
		Loc.t("deck.badge.spirit" if spirit else "deck.badge.garden"),
		HORIZONTAL_ALIGNMENT_CENTER, badge_side, BalanceUI.FONT_SIZE_DECK_BADGE,
		BalanceUI.COLOR_DECK_BADGE_TEXT)
	var center_x := (p_tile["at"] as Vector2).x + side * 0.5
	var label_w := side * 1.6
	var name_col: Color = BalanceUI.COLOR_TEXT
	if not pickable:
		name_col = BalanceUI.COLOR_RUN_LOCKED
	elif picked:
		name_col = BalanceUI.COLOR_RUN_PICKED
	var ny := (p_tile["at"] as Vector2).y + side + float(BalanceUI.FONT_SIZE_RUN_NODE_LABEL) + 4.0
	draw_string(p_font, Vector2(center_x - label_w * 0.5, ny), UiStyle.fit_text(
		p_font, str(p_tile["title"]), BalanceUI.FONT_SIZE_RUN_NODE_LABEL, label_w),
		HORIZONTAL_ALIGNMENT_CENTER, label_w, BalanceUI.FONT_SIZE_RUN_NODE_LABEL, name_col)
	draw_string(p_font, Vector2(center_x - label_w * 0.5, ny + float(BalanceUI.FONT_SIZE_RUN_NODE_FEE) + 2.0),
		Loc.tf("hud.card.cost", [int(p_tile["cost"])]), HORIZONTAL_ALIGNMENT_CENTER,
		label_w, BalanceUI.FONT_SIZE_RUN_NODE_FEE, BalanceUI.COLOR_MONEY)


func _ensure_tile() -> void:
	## The two StyleBoxes are built once and re-used for every tile on every
	## frame: only the rect and the border fields change between draws.
	if _tile_bg != null:
		return
	_tile_bg = StyleBoxFlat.new()
	_tile_bg.bg_color = BalanceUI.COLOR_RUN_NODE_BG
	_tile_bg.set_corner_radius_all(int(BalanceUI.RUN_NODE_CORNER))
	_tile_edge = StyleBoxFlat.new()
	_tile_edge.draw_center = false
	_tile_edge.set_corner_radius_all(int(BalanceUI.RUN_NODE_CORNER))


# ---------------------------------------------------------------- presses
func _on_row_pressed(p_group: int, p_index: int) -> void:
	if game == null or p_group >= _groups.size():
		return
	var row: Dictionary = (_groups[p_group] as Array)[p_index] as Dictionary
	if str(row.get("kind", "")) == "slot":
		_report(deck_take(int(row.get("slot", -1))))
	else:
		_report(deck_put(int(row.get("index", -1))))


func _footer_specs() -> Array:
	var picked: int = deck_pick_count() if game != null else 0
	return [{"text": Loc.t("deck.confirm"), "enabled": picked > 0}]


func _on_footer_pressed(p_index: int) -> void:
	if game == null or p_index != 0:
		return
	_report(confirm_deck())


func deck_put(p_index: int) -> Dictionary:
	## [P32-UI] Click a card in the POOL: it loads the next empty seed slot.
	## A card already in the deck is a silent no-op (the only way OUT is clicking
	## its slot); the cap and the missing scroll answer in words.
	if p_index < 0 or p_index >= Balance.plant_cards().size():
		return {"ok": false, "message": ""}
	var key := str(Balance.plant_cards()[p_index])
	if not profile.has_scroll_for(key):
		return {"ok": false, "message": Loc.tf("deck.msg.no_scroll", [Balance.plant_name(key)])}
	if game.front._deck_pick.has(key):
		return {"ok": true, "message": ""}
	if game.front._deck_pick.size() >= BalanceBattle.BATTLE_DECK_SLOTS:
		return {"ok": false, "message": Loc.tf("deck.msg.deck_full", [BalanceBattle.BATTLE_DECK_SLOTS])}
	game.front._deck_pick.append(key)
	return {"ok": true, "message": ""}


func deck_take(p_slot: int) -> Dictionary:
	## [P32-UI] Click a FILLED seed slot: the card goes back to the pool. An empty
	## or out-of-range slot is a silent no-op (the page renders empty slots
	## disabled, so this only catches a stale frame).
	if p_slot < 0 or p_slot >= game.front._deck_pick.size():
		return {"ok": true, "message": ""}
	game.front._deck_pick.remove_at(p_slot)
	return {"ok": true, "message": ""}


func deck_card_at(p_slot: int) -> String:
	## [P32-UI] The card standing in seed slot p_slot, "" for an empty slot.
	var pick: Array[String] = game.front._deck_pick
	return str(pick[p_slot]) if p_slot >= 0 and p_slot < pick.size() else ""


func confirm_deck() -> Dictionary:
	if game.front._deck_pick.is_empty():
		return {"ok": false, "message": Loc.t("deck.msg.deck_empty")}
	if game.front._pending_level_path == "":
		return {"ok": false, "message": ""}
	game.front._battle_deck = game.front._deck_pick.duplicate()
	game.battle_main.start_level(game.front._pending_level_path)
	return {"ok": true, "message": ""}
