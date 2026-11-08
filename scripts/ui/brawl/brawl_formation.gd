class_name BrawlFormation
extends Control
## [B2c] THE FORMATION PAGE - the whole battlefield, and both decisions a round opens with.
##
## D3's first two steps AND its fourth on one page: arrange your own half, flip through the
## round's offers WHILE the enemy half changes under them, then send them in. Putting a piece
## down and choosing who to fight are one decision made while looking at the same board - which
## is why the offers moved here from the result page (the user's call, 2026-10-04).
##
## The board is painted with BrawlField's own drawers and geometry (draw_ground / draw_grid /
## half_rect / cell_rect / cell_at), and the enemy half is drawn from FormationDB's rows - the
## same rows the arena fields. So this page cannot disagree with the fight about where a cell is
## or who stands on the right.
##
## [S2/S3] THE PAGE IS THE FIELD. Every rectangle below comes from BrawlLayout - the same owner
## the arena reads - and the header is painted by BrawlHUD, the same drawer the arena calls. That
## is the user's requirement (D66) made structural rather than eyeballed: the two screens cannot
## drift apart, because there is only one place that says where a cell is (see BRAWL.md §10.2).
## What the page adds around the board is its own three parts, all of them in BrawlLayout:
## the bag column on the left, the bench row under the board and the BAND under that (offers +
## 出战). [B26] added no fourth part: the SHOP lies ON the board, over the enemy half - and [B27]
## made that covering something the player turns on, so the half is the opponent's preview by default.
## Nothing here is measured against the chrome the TURN ENGINE reserves any more.
##
## [B5+] THE BENCH (候战区) IS NINE FIXED SLOTS in one row under the board, and the page DRAWS it
## rather than building buttons. Three consequences the user asked for, and they are really one
## rule:
##   a piece that is dragged onto the board LEAVES the bench (its slot becomes an empty frame),
##   a piece dragged back takes a slot (the slot under the pointer, or the lowest free one),
##   and HOVERING any piece - a slot, a piece on your half, or a visible enemy - opens a panel
##   with its numbers, all of them read from the sheet that owns them.
## The grid is drawn whether or not it is full, because the grid IS the capacity
## (BalanceBrawl.BENCH_SLOTS): a session whose bench is full cannot take another piece, which the
## shop and the reward roll both ask about before they offer one.
##
## ONE BUTTON, TWO IDIOMS. A press that lifts off without moving is still the old two-step click
## (pick a piece up, click a cell to put it down - PROMPT.md §8, the garden and the battle's tools
## use it too); a press that TRAVELS past BalanceUI.BRAWL_DRAG_THRESHOLD becomes a drag, and the
## release drops the piece wherever the pointer is. NOTHING MOVES UNTIL THE RELEASE, and that is
## on purpose: it means an abandoned drag costs nothing (no slot is held, no cell is emptied),
## which is what lets the bench be a hard limit instead of a suggestion.
##
## [B7] THE BAG AND THE THREE SLOTS (BRAWL.md §8.6.3 / §8.6.4). A piece wears up to three
## 挂件 (augments and equipment alike), drawn as three squares along the bottom of its tile, and
## everything nobody wears waits in the BAG - [S2] which now OWNS the whole left column (D67,
## the user's call: "背包改为左侧一列"), the two text lines that used to share it having moved up
## into the header. Two gestures live on the same button: a press picks up a PIECE (B5+,
## unchanged) or an ATTACHMENT - from a bag tile, or off one of those three squares. Acquiring is
## not equipping (D44), so a reward or a purchase lands in the bag and THIS page is where it is
## put on.
##
## [B5 → B26 → B27] THE BAND UNDER THE BOARD IS THE ROUND'S CHOICE: three opponents, and the round
## is committed to exactly one (D35). Picking one redraws the enemy half, which is the whole point of
## choosing here. [S2] The band is the shape the genre uses and it is why the right-hand column was
## deleted once (D67): the offers read left to right under the board they are about, and 出战 sits
## in the board's bottom-right corner. [B26] took the SHOP out of this list as a rolled offer, and
## [B27] put it back as a standing cell: the strip reads 遣散 | 商店 | three 敌阵 | 出战, and the
## shop cell TOGGLES the shelf instead of being a round's event (BrawlMain.start_bout() is still the
## band's only door that commits anything).
## [B28] A card is TWO LINES and three facts - the opponent's name, how many bodies this round rolled
## and what they add up to in 战力 (the user's call, 2026-10-08: "为操作栏的敌阵选项增加显示敌方战阵
## 所有单位的战力之和"). The number is FormationDB.power_total_of() over the SAME rolled rows the
## arena will field, each term Balance.unit_power() - the very figure the almanac prints per unit, so
## the card can be checked by hand. The band did not grow for it (BRAWL_POOL_TILE_H is paid for by
## the board, cell for cell), which is why the strip's type is 14 rather than 18.
## [B29] SINCE THIS ROUND a card may name an opponent NOBODY WROTE: one of the three is assembled by
## BrawlFormationGen up to the round's power floor, and the written two are raised to that floor too
## (reinforcements on the cells their sheet left free). The page did not change shape for it - the
## rows are the same {piece, col, row} the formation sheet writes, so the preview, the hover panel and
## the fight all read a random formation through the doors a written one already used. What the card
## does NOT say is which kind it is: a name from the language layer's list rather than from
## formations.csv is the only tell, and the 只数 / 战力 pair is what a player actually compares.
##
## [B26 / B27] THE SHELF LIVES HERE (the user's calls, 2026-10-08: "现在右侧有一个购买棋子的区域，
## 商店不用另外开页面了", then "商店选项直接覆盖战场上右侧的敌阵区，而不是开出来一个新的区域专门放
## 商店选项", then "敌阵选项里点击商店才会把货架UI覆盖敌阵，点击某敌阵时会显示对应敌阵"). It is NOT a
## new region: the rows lie on the board's ENEMY half - the four columns a foe would stand in - and
## they cover that half only while the band's 商店 cell is on. Choosing an opponent instead closes it,
## so the two things the right half can show (the foe you are about to fight, the stock you are about
## to spend coin on) are ONE rectangle with a switch on it rather than two regions competing for the
## page. What moved is the DRAWING only: the shelf is still the SESSION's (BrawlSession.shop_stock,
## rolled with the round, priced by the sheets, sold by buy()), refreshed IN PLACE. Two consequences
## worth naming out loud: the shop is no longer an EVENT a round can be SPENT on (D22's "逛商店 =
## 这一轮不打架" went with the page), so a purchase costs coin and never the round; and a purchase no
## longer leaves the board, which is what a bench that is full has always needed to be visible next to
## (the row says so, the bench shows it).
## [B27] WHICH MEANS THE ENEMY PREVIEW IS BACK: the half under a closed shelf is the chosen
## formation's own rows, drawn from the same FormationDB rows the arena fields, so hovering a foe on
## this page reaches its numbers again. `_shop_open` is the page's state and nothing else - the stock
## does not care which of the two is on screen.
##
## [B15] THE BAND HAS THREE PARTS NOW, and the third is 遣散 (the user's call, D90: D71 had
## refused any button in the band, and this is the one they asked for). It stands at the band's
## LEFT end - as far from 出战 as the band allows, because one throws a piece away and the other
## commits a round - and it acts on the piece IN HAND: picking a piece up is what arms it, so
## the selected border is the button's target and an empty hand leaves it dead.
##
## [B17+] THE BOARD CASTS SHADOWS (user, 2026-10-06: "增加在编排战阵阶段就显示视觉影子").
## This page's ground IS the arena's ground (same BrawlField geometry, D66), so every body
## standing on a cell is drawn with the same ellipse it will wear in the bout - through the
## arena's ONE drawer (BrawlShadow's static path, the BrawlHUD precedent: the two screens
## cannot drift about what a shadow looks like). Trays stay without one: bench, offers band,
## bag and drag ghost are cards held above the field, not bodies on it (D92's line, and the
## almanac's). A piece on this page never flies, so the z handed to the drawer is always 0.

const BrawlShadow := preload("res://scripts/core/brawl/brawl_shadow.gd")

var game = null                      # GameManager autoload；故意不标名称

## [S4] THE FOUR LINES OF THE HEADER, in the order BrawlHUD.draw_top_bar reads them: title and
## cap line share the first row, the key hint and the opponent the second. They are DRAWN, not
## Labels - the arena paints its own four through the same call - so this page keeps no header
## nodes at all (the scene's Title / Subtitle / Versus / Hint are gone with the old layout).
var _title := ""
var _status := ""
var _hint := ""
var _versus := ""
var _offer_buttons: Array = []       # [{btn, index}]
var _confirm: Button = null
## [B15] 遣散, the band's LEFT end: the one button D71 refused and the user asked for. It acts
## on the piece IN HAND and is dead while the hand is empty (see _sync_dismiss), so a stray
## click cannot throw a piece away - picking one up first is the whole safety.
var _dismiss: Button = null
## [B26] THE SHELF, over the board's enemy half: one Button per row of the session's stock,
## same {btn, index} shape as the offers so the two groups are freed and refreshed the same way.
var _shop_buttons: Array = []          # [{btn, index}]
## [B27] THE SHELF'S DOOR, and the page's own one-bit state. The band's 商店 cell toggles it; an
## offer click closes it. WHY IT IS NOT IN THE SESSION: which of the two the right half is showing is
## a VIEW - the stock, its prices and whether a row can be bought are rules, and none of them changed
## when the player looked away from them. It starts CLOSED with every round (see open_view()), because
## the first thing a round has to answer is "who am I fighting".
var _shop_open := false
var _shop_toggle: Button = null

## [B5+] THE HAND. One index does three jobs on purpose - the piece that is SELECTED (the two-step
## click), the piece being DRAGGED (that same piece with the button still down), and the piece
## whose slot or cell wears the selected border. _dragging only says whether the pointer has
## travelled far enough to have turned the press into a drag.
var _selected := -1
var _drag_index := -1
var _drag_pos := Vector2.ZERO        # the pointer, in page coordinates: the ghost follows it
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _mouse := Vector2.ZERO           # where the pointer is, for the hover panel
var _hover := Vector2i(-1, -1)       # the board cell under the pointer
var _hover_bench := -1               # the bench SLOT under the pointer (-1 = none)

## [B7] THE SECOND HAND. A press picks up a PIECE or an ATTACHMENT, never both: _gear_bag is the
## bag position in hand, _gear_piece/_gear_slot the worn row in hand, and all three are -1 while a
## piece is. _dragging covers every one of them (see _begin_drag / _on_press).
var _gear_bag := -1
var _gear_piece := -1
var _gear_slot := -1
## [B7] WHICH BAG TILES ARE ON SCREEN: the box at the foot of the left column holds what it holds,
## and a bag longer than that slides (the last tile becomes a "+N" mark). The bag itself has no
## capacity (O38) - this is a DRAWING window, not a rule.
var _bag_first := 0

## NOTE: this page has NO Background child, and that is deliberate. A Control's children are
## painted AFTER its own _draw(), so an opaque ColorRect child covers the board this page draws -
## which is exactly what a black battlefield with floating buttons is. The backdrop is therefore
## painted in _draw() itself, as its first rectangle.
@onready var _button_layer: Control = $ButtonLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	## The PAGE takes the clicks (it hit-tests the board and the bench itself), so everything that
	## is not a button must let them through: a ColorRect or a plain Control child defaults to
	## STOP and would swallow every click that missed a button.
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _button_layer != null:
		_button_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


# ---------------------------------------------------------------- public API
func open_view() -> void:
	_selected = -1
	_hover = Vector2i(-1, -1)
	_hover_bench = -1
	## [B27] A round opens on the OPPONENT, not on the shelf: the cover goes back down every time this
	## page comes up (see _shop_open for why the bit lives here rather than in the session).
	_shop_open = false
	## [B7] The bag window starts at the head every time the page comes back: a session that left
	## it scrolled to the tail would look like it had lost the first few attachments.
	_bag_first = 0
	_cancel_drag()
	_build()
	visible = true
	on_layout_changed()
	_focus_first()


func hide_view() -> void:
	_cancel_drag()
	visible = false


func on_layout_changed() -> void:
	## [S2] The page has no arena node under it, so IT is what refreshes the brawl's geometry:
	## Layout owns the logical size (refreshed by the front end before this call) and BrawlLayout
	## turns it into rectangles. _layout() runs it too, because open_view() reaches the page
	## without going through the front end's resize list.
	position = Vector2.ZERO
	size = Layout.size
	_layout()
	queue_redraw()


# ---------------------------------------------------------------- the session
func _session() -> BrawlSession:
	if game == null or game.brawl_main == null:
		return null
	return game.brawl_main.session


# ---------------------------------------------------------------- page building
func _build() -> void:
	_clear_entries()
	var session := _session()
	if session == null:
		_title = Loc.t("brawl.title")
		_status = ""
		_versus = ""
		_hint = Loc.t("brawl.no_session")
		return
	_title = Loc.tf("brawl.form.title", [session.round_no])
	_hint = Loc.t("brawl.form.hint")
	for i in session.offers.size():
		_add_button_into(_offer_buttons, _offer_label(session, i), _on_offer_pressed.bind(i), i,
			BalanceUI.BRAWL_OFFER_FONT_SIZE)
	_confirm = _add_button(Loc.t("brawl.form.engaged"), _on_confirm)
	## [B15] The band's third part. It is built with the others and laid out by BrawlLayout, so
	## the page never measures the band itself.
	_dismiss = _add_button(Loc.t("brawl.form.dismiss"), _on_dismiss)
	## [B27] The band's SHOP cell: the shelf's only door (the user, 2026-10-08: "敌阵选项里点击商店
	## 才会把货架UI覆盖敌阵"). It is built like 遣散 - one button, not a rolled list - because it is
	## not an opponent: the round's choice is the three cards to its right, and this says what the
	## right half of the board should be showing.
	_shop_toggle = _add_button(Loc.t("brawl.shop.caption"), _on_shop_toggle)
	_shop_toggle.add_theme_font_size_override("font_size", BalanceUI.BRAWL_OFFER_FONT_SIZE)
	## [B26] THE SHELF: one row per stock entry, laid over the board's enemy half. A row WRAPS rather
	## than ellipsises, because "what does this cost me" and "what does this do" are the two halves
	## of a purchase decision and neither is decoration. [B27] These are built once WITH the page and
	## only shown or hidden afterwards (_refresh_shop): a toggle that rebuilt the rows would rebuild
	## the one a player was about to click.
	for i in session.shop_stock.size():
		var btn := _add_button_into(_shop_buttons, _shop_row_text(session, i),
			_on_shop_pressed.bind(i), i, BalanceUI.BRAWL_SHOP_FONT_SIZE)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_texts()


func _offer_label(p_session: BrawlSession, p_index: int) -> String:
	## [B26] One OPPONENT as the band under the board shows it: its name, its size and (D34) what it
	## is worth. The shop used to be a third thing this list could hold (D22) and had its own
	## wording here; [B26/B27] put a 商店 cell in the same STRIP but not among the round's OFFERS - it
	## is the page's own button, built outside this list - so a card here is always a fight. The
	## "picked" mark goes in front of whichever it is, which is why this is one function and not two
	## label sites.
	var rows := p_session.offer_rows(p_index)
	## [B8+] The COUNT is the round's roll, not the sheet's list: a formation whose archer
	## did not show up this round must not be advertised as if it had (see chosen_rows).
	## [B28] And neither is the POWER behind it: FormationDB.power_total_of() sums the SAME rolled
	## rows the arena will field, each term read from the unit sheet the almanac prints (B24) - so the
	## card, the preview, the fight and the 图鉴 cannot disagree about how strong this is.
	## [B29] The NAME asks the SESSION, not the sheet: one of these cards may be an opponent nobody
	## wrote, and offer_title() is the door that knows which.
	var text := Loc.tf("brawl.offer", [p_session.offer_title(p_index),
		FormationDB.count_of(rows), FormationDB.power_total_of(rows)])
	if p_index == p_session.chosen:
		text = Loc.t("brawl.form.chosen_mark") + "  " + text
	return text


func _clear_entries() -> void:
	_free_group(_offer_buttons)
	## [B26] The shelf goes with them: _build() is what runs a page refresh, and a second set of
	## rows appended to the same group is how one row ends up bought twice.
	_free_group(_shop_buttons)
	if _confirm != null and is_instance_valid(_confirm):
		var host := _confirm.get_parent()
		if host != null:
			host.remove_child(_confirm)
		_confirm.queue_free()
	_confirm = null
	## [B15] ...and the dismiss button with it: _build() is what runs a page refresh, and two
	## buttons where one is expected is how a page ends up with two 出战s.
	if _dismiss != null and is_instance_valid(_dismiss):
		var host := _dismiss.get_parent()
		if host != null:
			host.remove_child(_dismiss)
		_dismiss.queue_free()
	_dismiss = null
	## [B27] ...and the shelf's door with them, same reason: _build() runs a page refresh and two
	## 商店 cells is one more way of asking which one the click landed on.
	if _shop_toggle != null and is_instance_valid(_shop_toggle):
		var host := _shop_toggle.get_parent()
		if host != null:
			host.remove_child(_shop_toggle)
		_shop_toggle.queue_free()
	_shop_toggle = null


func _free_group(p_group: Array) -> void:
	## One {btn, index} list taken down: out of the tree AT ONCE (no ghost clicks), freed at the
	## frame's end. The offers and the shelf are the page's two groups and they leave the same way.
	for entry in p_group:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn != null and is_instance_valid(btn):
			var parent := btn.get_parent()
			if parent != null:
				parent.remove_child(btn)
			btn.queue_free()
	p_group.clear()


func _add_button(p_text: String, p_pressed: Callable) -> Button:
	var btn := UiStyle.make_button(null, "", Callable(), -1, Control.FOCUS_ALL, {}, false)
	btn.text = p_text
	btn.add_theme_font_size_override("font_size", BalanceUI.FONT_SIZE_MENU_BUTTON)
	btn.pressed.connect(p_pressed)
	_button_layer.add_child(btn)
	return btn


func _add_button_into(p_group: Array, p_text: String, p_pressed: Callable, p_index: int,
		p_font_size: int) -> Button:
	var btn := _add_button(p_text, p_pressed)
	## [S2] Neither group takes the menu button's 22: a band card is ~224 px wide at the design window
	## (181 since [B27]'s shop cell takes its share of the strip), and [B26] a shelf row is as wide as
	## the enemy half it covers - both size their own text (the two font sizes are the caller's
	## argument, so this function has no opinion about which list it joins).
	btn.add_theme_font_size_override("font_size", p_font_size)
	p_group.append({"btn": btn, "index": p_index})
	return btn


# ---------------------------------------------------------------- layout
func _layout() -> void:
	## [S3] EVERY RECTANGLE ON THIS PAGE COMES FROM BrawlLayout (D65-D69). The page used to solve
	## its own chrome against the turn engine's (the old _column_rect, which hung both side
	## columns in the battle layout's brain zone and card pad) - that is what kept the board
	## small. Now the BOARD is solved first and the parts are hung on it.
	BrawlLayout.refresh(Layout.size)
	_layout_columns()
	_layout_shop()


func _layout_columns() -> void:
	## What is a NODE gets placed: the band's four parts and [B26] the shelf's rows (the bench and
	## the bag are DRAWN - see _draw_bench / _draw_bag - so there is nothing to place for them). The
	## band lives under the board (D67): 出战 keeps its right end, 遣散 its left, and the offers strip
	## between them is shared by [B27] the shelf's door and the round's opponents.
	var box := BrawlLayout.offers_rect()
	var count := maxi(1, _offer_buttons.size())
	var gap := BalanceUI.BRAWL_POOL_GAP
	## [B27] The door takes a FIXED cell at the strip's left end (next to 遣散, deliberately far from
	## 出战), and it never takes more than a quarter of what the strip has: a window too cramped for
	## 120 px gives the width back to the opponents rather than leaving them no card at all.
	var door_w := minf(BalanceUI.BRAWL_BAND_SHOP_W, floorf(box.size.x * 0.25))
	var rest := maxf(0.0, box.size.x - (door_w + gap if door_w > 1.0 else 0.0))
	var card_w := floorf(maxf(0.0, rest - gap * float(count - 1)) / float(count))
	var x := box.position.x
	if _shop_toggle != null and door_w > 1.0:
		_shop_toggle.position = Vector2(x, box.position.y)
		_shop_toggle.custom_minimum_size = Vector2(door_w, box.size.y)
		_shop_toggle.size = Vector2(door_w, box.size.y)
		x += door_w + gap
	for entry in _offer_buttons:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn == null:
			continue
		btn.position = Vector2(x, box.position.y)
		btn.custom_minimum_size = Vector2(card_w, box.size.y)
		btn.size = Vector2(card_w, box.size.y)
		x += card_w + gap
	if _confirm != null:
		## 出战 ends the band, in the board's own bottom-right corner: the last thing on the page
		## is the thing that starts the round.
		var at := BrawlLayout.engage_rect()
		_confirm.position = at.position
		_confirm.custom_minimum_size = at.size
		_confirm.size = at.size
	if _dismiss != null:
		## [B15] ...and 遣散 opens it, at the far end from 出战: the band's left end is where a
		## piece is thrown away, its right corner is where the round is committed.
		var off := BrawlLayout.dismiss_rect()
		_dismiss.position = off.position
		_dismiss.custom_minimum_size = off.size
		_dismiss.size = off.size


func _layout_shop() -> void:
	## [B26] THE SHELF'S ROWS, placed inside the board's ENEMY HALF - the rectangle is the arena's
	## own (BrawlField.half_rect, so the shelf is exactly the four columns the enemy would stand in
	## and no region of its own was cut out of the page). The frame, the caption and the hint line are
	## DRAWN (see _draw_shop), only what a click can land on is a node. The rows fill the half
	## downwards from under its caption, each as tall as that half can pay for and no taller than
	## BRAWL_SHOP_ROW_MAX_H, so five rows on a big window read as comfortable rather than huge and a
	## cramped window still gets five legible lines.
	var box := BrawlField.half_rect(BalanceBrawl.SIDE_RIGHT)
	var count := _shop_buttons.size()
	if count <= 0:
		return
	var gap := BalanceUI.BRAWL_SHOP_ROW_GAP
	var pad := BalanceUI.BRAWL_MARGIN * 0.5
	var line := BalanceUI.BRAWL_COLUMN_TITLE_H
	var top := box.position.y + line + gap
	## The half's bottom belongs to the hint line, which reserves the same height the caption does.
	var avail := maxf(0.0, box.position.y + box.size.y - top - line - gap)
	var row_h := clampf((avail - gap * float(count - 1)) / float(count),
		BalanceUI.BRAWL_SHOP_ROW_MIN_H, BalanceUI.BRAWL_SHOP_ROW_MAX_H)
	var width := maxf(0.0, box.size.x - pad * 2.0)
	for i in count:
		var entry: Dictionary = _shop_buttons[i]
		var btn := entry["btn"] as Button
		if btn == null:
			continue
		btn.position = Vector2(box.position.x + pad, top + float(i) * (row_h + gap))
		btn.custom_minimum_size = Vector2(width, row_h)
		btn.size = Vector2(width, row_h)


func _focus_first() -> void:
	if _confirm != null and is_instance_valid(_confirm) and not _confirm.disabled:
		_confirm.grab_focus()
		return
	for entry in _offer_buttons:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		if btn != null and is_instance_valid(btn) and btn.visible and not btn.disabled:
			btn.grab_focus()
			return


# ---------------------------------------------------------------- the bench it draws
func _bench_row_rect() -> Rect2:
	## [S2] The row's rectangle is BrawlLayout's: nine slots at a PITCH of one cell, starting at
	## the board's own left edge, so slot k still sits under column k and the row still reads as a
	## continuation of the board (D39, kept).
	return BrawlLayout.bench_rect()


func _bench_slot_rect(p_slot: int) -> Rect2:
	## [S2/D69] One slot's BOX: BRAWL_BENCH_SLOT_SHARE of a cell wide, as tall as the row, and
	## centred inside its own cell-wide pitch - so the row can shrink without the columns moving.
	## BrawlLayout owns both the pitch and the box, and it answers Rect2() for a slot that is not
	## on the row.
	return BrawlLayout.bench_slot_rect(p_slot)


func _bench_slot_at(p_at: Vector2) -> int:
	## Which SLOT the pointer is over, or -1. Empty slots answer too (a drop needs to know where it
	## lands, and "onto slot 6" is a different gesture from "onto the bench at large").
	for slot in BalanceBrawl.BENCH_SLOTS:
		var rect := _bench_slot_rect(slot)
		if rect.size.x > 0.0 and rect.has_point(p_at):
			return slot
	return -1


func _in_bench_strip(p_at: Vector2) -> bool:
	## The whole strip around the row takes a drop, not just the nine slots: a piece dropped on the
	## caption or on the seam between two slots simply goes to the lowest free slot.
	return _bench_row_rect().grow(BalanceUI.BRAWL_MARGIN).has_point(p_at)


func _draw_bench() -> void:
	var session := _session()
	if session == null:
		return
	var row := _bench_row_rect()
	if _dragging:
		## A drop on the bench is legal while slots are free, and the border says so.
		draw_rect(row.grow(BrawlField.EDGE_WIDTH), BalanceUI.COLOR_ITEM_TILE_SELECTED, false,
			BrawlField.EDGE_WIDTH)
	for slot in BalanceBrawl.BENCH_SLOTS:
		_draw_bench_slot(session, slot, _bench_slot_rect(slot))
	## [S2] The caption that used to sit under this row ("候战区 n/9") is GONE: the band is there
	## now, so the count moved into the header's cap line (see _refresh_texts), where the player's
	## other numbers already are. One line, one place - and the row gets its 18 px back.


func _draw_bench_slot(p_session: BrawlSession, p_slot: int, p_rect: Rect2) -> void:
	if p_rect.size.x <= 1.0:
		return
	var index := p_session.bench_piece_at_slot(p_slot)
	## An EMPTY frame is drawn, and drawn dimmer: the nine slots are the capacity, so a free one
	## has to be visible, and it must not read as "a piece is here".
	var fill := BalanceUI.COLOR_ITEM_TILE_BG if index >= 0 else BalanceUI.COLOR_BRAWL_BENCH_EMPTY
	if p_slot == _hover_bench and index >= 0:
		fill = BalanceUI.COLOR_ITEM_TILE_HOVER
	draw_rect(p_rect, fill, true)
	var border := BalanceUI.COLOR_ITEM_TILE_BORDER
	if index >= 0 and (index == _selected or index == _drag_index):
		border = BalanceUI.COLOR_ITEM_TILE_SELECTED
	draw_rect(p_rect, border, false, BrawlField.EDGE_WIDTH)
	if index < 0:
		return
	var piece := _piece_of(p_session, index)
	## A slot is a whole board cell, so the name strip is always there - the guard is for a window
	## so small that Layout handed out a cramped cell, where an icon beats an unreadable caption.
	## [B7] The strip now shares the foot with the three attachment squares, so the icon gives up
	## the slot row's height and the name moves up to sit above them.
	var slot_h := _slot_row_rect(p_rect).size.y
	var name_h := 0.0
	if p_rect.size.y >= BalanceUI.BRAWL_BENCH_NAME_H * 2.0:
		name_h = BalanceUI.BRAWL_BENCH_NAME_H
	var inset := 4.0
	var icon := minf(p_rect.size.y - name_h - slot_h - inset * 2.0, p_rect.size.x - inset * 2.0)
	var alpha := 1.0
	if index == _drag_index and _dragging:
		alpha = BalanceUI.BRAWL_DRAG_ALPHA
	## [B16b] ...and mirrored like the board above it: the bench holds the PLAYER's pieces, so a
	## piece drawn facing left is previewed the way it will stand once it is fielded.
	UiStyle.draw_icon(self, Balance.unit_art(piece),
		p_rect.position + Vector2((p_rect.size.x - icon) * 0.5, inset), icon, alpha,
		_mirrored(piece, BalanceBrawl.SIDE_LEFT))
	_draw_slots(p_session, index, p_rect)
	var font := ThemeDB.fallback_font
	if font == null or name_h <= 0.0:
		return
	_draw_text(font, Balance.unit_name(piece), p_rect.position.x + p_rect.size.x * 0.5,
		p_rect.position.y + p_rect.size.y - slot_h - 4.0, BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE,
		BalanceUI.COLOR_MENU_SUB, p_rect.size.x)


func _draw_text(p_font: Font, p_text: String, p_center_x: float, p_baseline: float,
		p_size: int, p_color: Color, p_max_width: float) -> void:
	## One centred line, clipped to the box it belongs to. Drawn text is measured here rather than
	## laid out by a Label because every one of these lines lives inside a rectangle this page
	## computed (a slot, the bench caption).
	if p_font == null or p_text == "":
		return
	var width := p_font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_size).x
	draw_string(p_font, Vector2(p_center_x - width * 0.5, p_baseline), p_text,
		HORIZONTAL_ALIGNMENT_LEFT, p_max_width, p_size, p_color)


# ---------------------------------------------------------------- the bag and the slots [B7]
func _bag_box() -> Rect2:
	## [S2] THE BAG'S BOX is BrawlLayout's left column (D67): the whole height of the stack of
	## rows beside the board, so the bag is exactly as tall as the field it serves. The bag is
	## DRAWN, not built out of nodes - the same choice the bench made.
	return BrawlLayout.bag_rect()


func _bag_tile_size() -> float:
	## One tile: the box split into BRAWL_BAG_COLS columns. Square.
	var box := _bag_box()
	var cols := BalanceUI.BRAWL_BAG_COLS
	var gap := BalanceUI.BRAWL_BAG_TILE_GAP
	return floorf(maxf(0.0, box.size.x - gap * float(cols - 1)) / float(cols))


func _bag_fit() -> int:
	## HOW MANY TILES THE BOX HOLDS: the header (title + icon) comes off the top, then whole rows
	## of square tiles. At least one row, however cramped the window - a bag nobody can see would
	## be worse than a small one.
	var box := _bag_box()
	var tile := _bag_tile_size()
	if tile <= 1.0:
		return 0
	var head := BalanceUI.BRAWL_COLUMN_TITLE_H + BalanceUI.BRAWL_BAG_ICON_H + BalanceUI.BRAWL_BAG_TILE_GAP
	var rows := int(floor((box.size.y - head + BalanceUI.BRAWL_BAG_TILE_GAP)
		/ (tile + BalanceUI.BRAWL_BAG_TILE_GAP)))
	return clampi(rows, 1, BalanceUI.BRAWL_BAG_ROWS_MAX) * BalanceUI.BRAWL_BAG_COLS


func _bag_tile_rect(p_k: int) -> Rect2:
	## Where tile POSITION k sits (0 = top-left of the grid). Which bag entry that position shows
	## is the window's job - see _bag_window().
	var box := _bag_box()
	var tile := _bag_tile_size()
	var gap := BalanceUI.BRAWL_BAG_TILE_GAP
	var top := box.position.y + BalanceUI.BRAWL_COLUMN_TITLE_H + BalanceUI.BRAWL_BAG_ICON_H + gap
	var col := p_k % BalanceUI.BRAWL_BAG_COLS
	var row := floori(float(p_k) / float(BalanceUI.BRAWL_BAG_COLS))
	return Rect2(Vector2(box.position.x + float(col) * (tile + gap), top + float(row) * (tile + gap)),
		Vector2(tile, tile))


func _bag_window() -> Dictionary:
	## WHAT IS ON SCREEN: {first, back, items, more}.
	##   the bag entries first .. first + items - 1 get a tile each,
	##   back = 1 when the window has slid forward (position 0 then wears a "‹" mark),
	##   more > 0 when entries are left over (the tile after the last one wears "+N").
	## The window is CLAMPED here rather than at every writer, so a bag that shrank (something was
	## equipped, or removed) can never leave the view hanging past its end.
	var session := _session()
	var count := session.bag.size() if session != null else 0
	var fit := _bag_fit()
	if fit <= 0 or count <= 0:
		return {"first": 0, "back": 0, "items": 0, "more": 0}
	var first := clampi(_bag_first, 0, maxi(0, count - fit))
	var items := mini(count - first, fit)
	var more := count - first - items
	if more > 0:
		items -= 1
	var back := 1 if first > 0 else 0
	items -= back
	return {"first": first, "back": back, "items": maxi(0, items), "more": maxi(0, more)}


func _bag_tile_at(p_at: Vector2) -> int:
	## WHICH TILE POSITION the pointer is over, or -1 (including "outside the bag box entirely").
	## A position means different things depending on the window, so _on_bag_press is the only
	## reader that has to care.
	var fit := _bag_fit()
	for k in fit:
		var rect := _bag_tile_rect(k)
		if rect.size.x > 1.0 and rect.has_point(p_at):
			return k
	return -1


func _draw_bag() -> void:
	## [B7] THE BAG: a header (the same backpack picture the turn-mode menu hangs on its prop, plus
	## the count) and a grid of the attachments nobody wears yet.
	var session := _session()
	var box := _bag_box()
	if session == null or box.size.y < 8.0:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_rect(box, BalanceUI.COLOR_BRAWL_INFO_BG, true)
	draw_rect(box, BalanceUI.COLOR_BRAWL_INFO_BORDER, false, BrawlField.EDGE_WIDTH)
	var head := BalanceUI.BRAWL_COLUMN_TITLE_H + BalanceUI.BRAWL_BAG_ICON_H
	if box.size.y < head:
		return
	var pad := BalanceUI.BRAWL_MARGIN * 0.5
	UiStyle.draw_icon(self, BalanceUI.ART_ICON_BACKPACK,
		Vector2(box.position.x + pad, box.position.y + BalanceUI.BRAWL_COLUMN_TITLE_H),
		BalanceUI.BRAWL_BAG_ICON_H)
	## The count sits at the TOP, and the header is also where a press sends the window home:
	## there is no page button, and the icon is the obvious "take me back to the start".
	_draw_text(font, Loc.tf("brawl.info.bag", [session.bag.size()]),
		box.position.x + box.size.x * 0.5, box.position.y + BalanceUI.BRAWL_COLUMN_TITLE_H - 5.0,
		BalanceUI.BRAWL_COLUMN_TITLE_FONT_SIZE, BalanceUI.COLOR_MENU_TITLE, box.size.x)
	if session.bag.is_empty():
		_draw_text(font, Loc.t("brawl.bag.empty"), box.position.x + box.size.x * 0.5,
			box.position.y + head + BalanceUI.BRAWL_COLUMN_TITLE_H, BalanceUI.BRAWL_COLUMN_TITLE_FONT_SIZE,
			BalanceUI.COLOR_MENU_SUB, box.size.x)
		return
	var window := _bag_window()
	var first := int(window.get("first", 0))
	var back := int(window.get("back", 0))
	var items := int(window.get("items", 0))
	var more := int(window.get("more", 0))
	var pos := 0
	if back > 0:
		_draw_bag_mark(0, "‹", font)
		pos = 1
	for k in items:
		_draw_bag_tile(session, pos + k, first + k, font)
	if more > 0:
		_draw_bag_mark(pos + items, Loc.tf("brawl.bag.more", [more]), font)


func _draw_bag_tile(p_session: BrawlSession, p_pos: int, p_index: int, p_font: Font) -> void:
	## One attachment in the bag. The picture when the row has one (equipment does, augments do
	## not), the name otherwise - a tile is small, and a blank square would say nothing at all.
	var rect := _bag_tile_rect(p_pos)
	if rect.size.x <= 1.0:
		return
	var id := str(p_session.bag_gear(p_index).get("id", ""))
	var carried: bool = p_index == _gear_bag and _dragging
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_HOVER if carried else BalanceUI.COLOR_ITEM_TILE_BG, true)
	var art := GearDB.art(id)
	if art != "":
		var inset := 3.0
		UiStyle.draw_icon(self, art, rect.position + Vector2(inset, inset),
			maxf(4.0, rect.size.x - inset * 2.0), BalanceUI.BRAWL_DRAG_ALPHA if carried else 1.0)
	else:
		_draw_text(p_font, GearDB.display_name(id), rect.position.x + rect.size.x * 0.5,
			rect.position.y + rect.size.y * 0.5 + float(BalanceUI.BRAWL_COLUMN_TITLE_FONT_SIZE) * 0.35,
			BalanceUI.BRAWL_COLUMN_TITLE_FONT_SIZE, BalanceUI.COLOR_MENU_SUB, rect.size.x - 2.0)
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_SELECTED if carried else BalanceUI.COLOR_ITEM_TILE_BORDER,
		false, BrawlField.EDGE_WIDTH)


func _draw_bag_mark(p_pos: int, p_text: String, p_font: Font) -> void:
	## The two marks a slid window wears: "‹" at the front and "+N" at the back. They are tile
	## POSITIONS, so they are pressed exactly as a tile is (see _on_bag_press).
	var rect := _bag_tile_rect(p_pos)
	if rect.size.x <= 1.0:
		return
	draw_rect(rect, BalanceUI.COLOR_BRAWL_BENCH_EMPTY, true)
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_BORDER, false, BrawlField.EDGE_WIDTH)
	_draw_text(p_font, p_text, rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.5 + float(BalanceUI.BRAWL_BAG_MORE_FONT_SIZE) * 0.35,
		BalanceUI.BRAWL_BAG_MORE_FONT_SIZE, BalanceUI.COLOR_BRAWL_BAG_MORE, rect.size.x - 2.0)


func _draw_shop() -> void:
	## [B26] THE SHELF'S FRAME: the panel the rows sit on, its caption and its one hint line - all of
	## it inside the board's enemy half. The rows are Buttons, and a page's children paint over its
	## own drawing - which is exactly what they have to do here; what is drawn is only what no row
	## covers.
	##
	## [B27] AND IT IS DRAWN ONLY WHILE THE SHELF IS UP (the user, 2026-10-08: "敌阵选项里点击商店
	## 才会把货架UI覆盖敌阵，点击某敌阵时会显示对应敌阵"). This is the ONE thing the toggle changes
	## about the page's drawing: with the cover down, the four right columns are the ENEMY PREVIEW
	## again - _draw()'s first loop already paints the chosen formation's own rows there, and it was
	## this panel sitting on top of that, permanently, which is what hid them.
	if not _shop_open:
		return
	var session := _session()
	var box := BrawlField.half_rect(BalanceBrawl.SIDE_RIGHT)
	if session == null or box.size.y < 8.0:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_rect(box, BalanceUI.COLOR_BRAWL_INFO_BG, true)
	draw_rect(box, BalanceUI.COLOR_BRAWL_INFO_BORDER, false, BrawlField.EDGE_WIDTH)
	## The caption heads the panel the way the bag heads its own column, so the two ends of the board
	## carry a title at the same height and in the same type.
	_draw_text(font, Loc.t("brawl.shop.caption"), box.position.x + box.size.x * 0.5,
		box.position.y + BalanceUI.BRAWL_COLUMN_TITLE_H - 5.0,
		BalanceUI.BRAWL_COLUMN_TITLE_FONT_SIZE, BalanceUI.COLOR_MENU_TITLE, box.size.x)
	_draw_text(font, Loc.t("brawl.shop.hint"), box.position.x + box.size.x * 0.5,
		box.position.y + box.size.y - 8.0, BalanceUI.BRAWL_TOP_HINT_FONT_SIZE,
		BalanceUI.COLOR_MENU_SUB, box.size.x - 4.0)


func _slot_row_rect(p_rect: Rect2) -> Rect2:
	## The strip along the bottom of a tile where a piece's three squares live. Its height is a
	## FRACTION of the tile (so a shrunk board shrinks it with the board), capped so a big cell
	## does not turn three small squares into three billboards.
	var h := minf(p_rect.size.y * BalanceUI.BRAWL_SLOT_ROW_RATIO, BalanceUI.BRAWL_SLOT_MAX_H)
	if h <= 0.0:
		return Rect2()
	return Rect2(Vector2(p_rect.position.x, p_rect.position.y + p_rect.size.y - h),
		Vector2(p_rect.size.x, h))


func _slot_rect(p_rect: Rect2, p_k: int) -> Rect2:
	## Square k of the three, centred in the strip. SQUARES rather than thirds of the width, so
	## they read as three separate things - which is what "three slots" means.
	var row := _slot_row_rect(p_rect)
	if row.size.y <= 0.0:
		return Rect2()
	var slots := float(BalanceBrawl.ATTACH_SLOTS)
	var side := minf(row.size.y,
		maxf(0.0, row.size.x - BalanceUI.BRAWL_SLOT_GAP * (slots - 1.0)) / slots)
	var total := side * slots + BalanceUI.BRAWL_SLOT_GAP * (slots - 1.0)
	var x := row.position.x + (row.size.x - total) * 0.5
	return Rect2(Vector2(x + float(p_k) * (side + BalanceUI.BRAWL_SLOT_GAP), row.position.y),
		Vector2(side, side))


func _draw_slots(p_session: BrawlSession, p_index: int, p_rect: Rect2) -> void:
	## [B7] THE THREE SQUARES a piece wears its attachments in. An EMPTY square is drawn too:
	## three is the CAPACITY (BalanceBrawl.ATTACH_SLOTS), and a piece that showed only what it
	## happens to wear would look like it could wear nothing else.
	if p_index < 0:
		return
	var worn := p_session.attach_slots(p_index)
	for k in BalanceBrawl.ATTACH_SLOTS:
		var square := _slot_rect(p_rect, k)
		if square.size.x <= 1.0:
			continue
		var filled: bool = k < worn.size()
		draw_rect(square, BalanceUI.COLOR_BRAWL_SLOT_FILLED if filled
			else BalanceUI.COLOR_BRAWL_SLOT_EMPTY, true)
		if filled:
			var art := GearDB.art(str((worn[k] as Dictionary).get("id", "")))
			if art != "":
				var size := maxf(4.0, square.size.y - 2.0)
				UiStyle.draw_icon(self, art,
					square.position + Vector2((square.size.x - size) * 0.5, 1.0), size)
		draw_rect(square, BalanceUI.COLOR_BRAWL_SLOT_BORDER, false, BalanceUI.BRAWL_GRID_WIDTH)


func _cell_inner_rect(p_cell: Vector2i) -> Rect2:
	## The rectangle a piece is DRAWN in: the drawing and the hit-testing of the three squares have
	## to agree on it, so it lives in one place.
	return BrawlField.cell_rect(p_cell).grow(-BalanceUI.BRAWL_CELL_INSET)


func _attach_hit(p_at: Vector2) -> Dictionary:
	## WHICH PIECE THE POINTER IS OVER, and which of its squares if it is over one at all:
	## {piece, slot} with slot -1 for "on the piece, not on a square", {} for "no piece there".
	## TWO READERS, TWO MEANINGS: _on_press only PICK A ROW UP off an OCCUPIED square, while a drop
	## only needs the piece - an empty square is a perfectly good place to put one.
	var session := _session()
	if session == null:
		return {}
	var index := -1
	var rect := Rect2()
	var slot := _bench_slot_at(p_at)
	if slot >= 0:
		index = session.bench_piece_at_slot(slot)
		rect = _bench_slot_rect(slot)
	else:
		var cell := BrawlField.cell_at(p_at)
		if not session.is_home_cell(cell.x, cell.y):
			return {}
		index = session.index_at_cell(cell.x, cell.y)
		rect = _cell_inner_rect(cell)
	if index < 0:
		return {}
	var hit_slot := -1
	for k in BalanceBrawl.ATTACH_SLOTS:
		if _slot_rect(rect, k).has_point(p_at):
			hit_slot = k
			break
	return {"piece": index, "slot": hit_slot}


func _in_bag_box(p_at: Vector2) -> bool:
	## Is the pointer over the bag at all (header included)? A drop there means "take it off".
	return _bag_box().has_point(p_at)


func _hover_index() -> int:
	## WHICH OWNED PIECE the pointer is over, as an index into the pool, or -1 (an enemy, an empty
	## cell, nothing). _hover_piece() answers the ID; the panel needs the INDEX, because that is
	## where the attachments live.
	var session := _session()
	if session == null:
		return -1
	if _hover_bench >= 0:
		return session.bench_piece_at_slot(_hover_bench)
	if session.is_home_cell(_hover.x, _hover.y):
		return session.index_at_cell(_hover.x, _hover.y)
	return -1


func _worn_text(p_session: BrawlSession, p_index: int) -> String:
	## What ONE piece wears, as names. "" when it wears nothing, so the panel can leave the line
	## out instead of printing an empty promise. The JOINER follows the language: a Chinese list
	## uses "、", an English one a comma.
	if p_session == null or p_index < 0:
		return ""
	var names := PackedStringArray()
	for gear in p_session.attach_slots(p_index):
		names.append(GearDB.display_name(str((gear as Dictionary).get("id", ""))))
	return "、".join(names) if Loc.prefer_zh() else ", ".join(names)


func _gear_in_hand() -> bool:
	return _gear_bag >= 0 or _gear_piece >= 0


func _gear_id(p_session: BrawlSession) -> String:
	## WHAT IS IN THE SECOND HAND, as a row id, or "". One door, so the hint, the ghost and the
	## drop all name the same thing.
	if p_session == null:
		return ""
	if _gear_bag >= 0:
		return str(p_session.bag_gear(_gear_bag).get("id", ""))
	if _gear_piece >= 0 and _gear_slot >= 0:
		var worn := p_session.attach_slots(_gear_piece)
		if _gear_slot < worn.size():
			return str((worn[_gear_slot] as Dictionary).get("id", ""))
	return ""


# ---------------------------------------------------------------- the board it draws
func _draw() -> void:
	## The backdrop is the FIRST rectangle of this page's own drawing, not a child node: a child
	## Control paints over its parent's _draw(), which is what buried this board once already.
	draw_rect(Rect2(Vector2.ZERO, size), BalanceUI.COLOR_MENU_BG, true)
	## [S4] THE HEADER, through the SAME drawer the arena calls (BrawlHUD.draw_top_bar) on the
	## same rectangle (BrawlLayout.top_bar). The two pages differ in what the four slots SAY,
	## never in where they are or how big they are - that is D66, drawn rather than promised.
	BrawlHUD.draw_top_bar(self, _title, _status, _hint, _versus)
	## Ground, then the lattice (this page is where a cell is a clickable thing), then the ENEMY
	## half, then ours: our own pieces are the ones being edited, so they end up on top.
	BrawlField.draw_ground(self)
	BrawlField.draw_grid(self)
	var session := _session()
	if session == null:
		return
	## [B5] The enemy half previews the opponent the round is committed to, through the SAME rows the
	## arena fields (FormationDB's own roll - so the preview, the header line and the fight cannot
	## disagree). [B27] It is visible whenever the shelf is down; the shelf covers these same four
	## columns only while the band's 商店 cell is on.
	for entry in session.chosen_rows():
		var row := entry as Dictionary
		_draw_enemy_piece(str(row.get("piece", "")),
			Vector2i(int(row.get("col", -1)), int(row.get("row", -1))))
	for row in Balance.ROWS:
		for col in BalanceBrawl.HALF_COLS:
			_draw_cell(session, Vector2i(col, row))
	_draw_bad_drop()
	_draw_bench()
	## [B7] The bag is drawn AFTER the bench and BEFORE the ghost, so a gear in hand floats over
	## every tile it could be dropped on - which is the whole point of dragging it.
	_draw_bag()
	## [B26] The shelf's FRAME (its rows are nodes, and a node paints over this page's own drawing,
	## so the panel has to be drawn here or the buttons would float on the backdrop).
	_draw_shop()
	_draw_ghost()
	_draw_info()


func _draw_bad_drop() -> void:
	## [B5+] While a piece is in hand, the cells that CANNOT take it say so: the no man's land and
	## the enemy half. The half a piece may land on is the thing the board is about, so the answer
	## has to be visible before the button comes up.
	## [B7] An ATTACHMENT in hand answers with the same red, and its one "no" is a piece that
	## already wears three (O37): the tint follows the pointer, so the refusal is visible before
	## the button comes up rather than after.
	var session := _session()
	if _dragging and _gear_in_hand():
		var hit := _attach_hit(_drag_pos)
		if session != null and not hit.is_empty():
			var over := int(hit.get("piece", -1))
			if session.free_slot_in(over) < 0:
				draw_rect(_slot_row_rect(_piece_rect(session, over)),
					BalanceUI.COLOR_BRAWL_DROP_BAD, true)
		return
	if _selected < 0 or _hover.x < 0 or _hover.y < 0:
		return
	if _hover.x >= Balance.COLS or _hover.y >= Balance.ROWS:
		return
	if session == null or session.is_home_cell(_hover.x, _hover.y):
		return
	draw_rect(BrawlField.cell_rect(_hover).grow(-BalanceUI.BRAWL_CELL_INSET),
		BalanceUI.COLOR_BRAWL_DROP_BAD, true)


func _draw_piece(p_piece: String, p_cell: Vector2i,
		p_side: int = BalanceBrawl.SIDE_LEFT) -> void:
	## A piece's icon, square and as tall as what is left of its cell, centred in it.
	## UiStyle.draw_icon is the one door that turns a sheet path into pixels, and it draws nothing
	## when the art is missing - so a piece without art still leaves a usable cell behind.
	## [B7] WHAT IS LEFT excludes the slot row ([B7] the three squares at the foot): the icon and
	## the squares are two different readouts of the same tile, and stacking them would hide the
	## one the player just changed.
	## [B16b] p_side is the CAMP this piece is being previewed in, and it is what decides the
	## mirror: the enemy half passes SIDE_RIGHT (so a zombie still looks left there and an
	## archer looks back at us), our own half keeps the default. See _mirrored().
	if p_cell.x < 0 or p_cell.y < 0:
		return
	var rect := _cell_inner_rect(p_cell)
	var size := maxf(8.0, rect.size.y - _slot_row_rect(rect).size.y)
	var icon := rect.position + Vector2((rect.size.x - size) * 0.5, 0.0)
	var art := Balance.unit_art(p_piece)
	## [B17+] The shadow goes down FIRST - the arena layers the same way (the shadow node is
	## added before the pieces), so the icon stands ON its ellipse, upper half hidden behind
	## the sprite's feet exactly as in the bout. [B36] Where the sole is and how big the ellipse
	## is now come from the SAME measurement the arena reads (UnitArt.ink_rect over the piece's
	## own art), so a preview wears exactly the ink it will cast in the bout; the mark here is the
	## icon box's top middle, which is the space that ink box is stated in. z is 0 - nothing on
	## this page flies. A piece whose file nobody has drawn yet gets NO ellipse: draw_icon()
	## paints nothing for it, and a shadow with no body over it would be the only ink in the cell.
	if UnitArt.load_texture(art) != null:
		BrawlShadow.draw_ink_shadow(self, icon + Vector2(size * 0.5, 0.0),
			UnitArt.ink_rect(art, Vector2.ZERO, size))
	UiStyle.draw_icon(self, art, icon, size, 1.0, _mirrored(p_piece, p_side))


func _draw_enemy_piece(p_piece: String, p_cell: Vector2i) -> void:
	## [B2c] THE VISIBILITY SWITCH (SettingsStore.show_enemy_pieces). OFF means the cell says only
	## that SOMETHING stands there: the formation's size, strength and reward stay on the page
	## either way (D34), so what this hides is the identity, not the threat. ON draws the piece.
	if p_cell.x < 0 or p_cell.y < 0:
		return
	if SettingsStore.show_enemy_pieces:
		## [B16b] The preview is the ENEMY's camp, so a piece drawn looking right is turned here -
		## the same rule the arena applies to the bodies it actually fields.
		_draw_piece(p_piece, p_cell, BalanceBrawl.SIDE_RIGHT)
		return
	var rect := BrawlField.cell_rect(p_cell).grow(-BalanceUI.BRAWL_CELL_INSET)
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_BG, true)
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_BORDER, false, BrawlField.EDGE_WIDTH)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var size := BalanceUI.BRAWL_MARK_FONT_SIZE
	var mark := "?"
	var width := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, rect.position + Vector2((rect.size.x - width) * 0.5,
		(rect.size.y + float(size) * 0.7) * 0.5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		BalanceUI.COLOR_TEXT_DIM)


func _draw_cell(p_session: BrawlSession, p_cell: Vector2i) -> void:
	var rect := _cell_inner_rect(p_cell)
	var index := p_session.index_at_cell(p_cell.x, p_cell.y)
	var hovered: bool = p_cell == _hover
	var fill := BalanceUI.COLOR_ITEM_TILE_BG
	if hovered and _selected >= 0:
		## The battle's own "you may put it here" tint, reused rather than reinvented. It answers
		## the DROP question for the cell under the pointer, whether the piece is being dragged or
		## was picked up with a click: a cell holding another piece is a legal target too, because
		## the drop SWAPS the two (see BrawlSession.place).
		fill = BalanceUI.COLOR_PLACEABLE
	elif hovered:
		fill = BalanceUI.COLOR_ITEM_TILE_HOVER
	draw_rect(rect, fill, true)
	var border := BalanceUI.COLOR_ITEM_TILE_BORDER
	if index >= 0 and (index == _selected or index == _drag_index):
		border = BalanceUI.COLOR_ITEM_TILE_SELECTED
	draw_rect(rect, border, false, BrawlField.EDGE_WIDTH)
	if index < 0:
		return
	var entry := p_session.pool[index] as Dictionary
	_draw_piece(str(entry.get("piece", "")), p_cell)
	## [B7] ...and the three squares it wears along the tile's foot.
	_draw_slots(p_session, index, rect)


func _mirrored(p_piece: String, p_side: int) -> bool:
	## [B16b] SHOULD THIS PIECE BE DRAWN FLIPPED, standing in that camp? The page asks the RULE
	## OWNER (BrawlActor.turned_in) with the ROW's own answer (UnitSheet.face_left - the very
	## reader a body uses at spawn), so the preview and the arena cannot disagree about which
	## way anything looks. Deriving it here instead (`side == RIGHT != faces_left`) would be the
	## second copy of a rule that already has exactly one home.
	##
	## It is asked per drawn piece and not cached: it is two dictionary lookups, and the page
	## already asks Balance.unit_art()/unit_name() the same way on the same frames.
	return BrawlActor.turned_in(UnitSheet.face_left(p_piece), p_side)


func _draw_ghost() -> void:
	## What is in hand, under the pointer. A PIECE is drawn at the CELL's size and not the slot's,
	## so what follows the cursor is the same body that is about to stand on the board; [B7] an
	## ATTACHMENT is drawn as its own icon at a tile's size, because that is the size it will
	## occupy once it is worn.
	if not _dragging:
		return
	var session := _session()
	if session == null:
		return
	if _gear_in_hand():
		_draw_gear_ghost(session)
		return
	if _drag_index < 0:
		return
	var piece := _piece_of(session, _drag_index)
	if piece == "":
		return
	var size := BrawlField.cell() * 0.8
	var rect := Rect2(_drag_pos - Vector2(size * 0.5, size * 0.5), Vector2(size, size))
	## [B16b] The ghost is the body about to land, so it wears the same mirror its destination
	## will give it: a piece in hand can only be dropped on the player's half or the bench.
	UiStyle.draw_icon(self, Balance.unit_art(piece), rect.position, size, BalanceUI.BRAWL_DRAG_ALPHA,
		_mirrored(piece, BalanceBrawl.SIDE_LEFT))
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_SELECTED, false, BrawlField.EDGE_WIDTH)


func _draw_gear_ghost(p_session: BrawlSession) -> void:
	## [B7] The attachment in hand: its own icon (or its name when the row has none - the seven
	## augments have no picture), in a frame the size of one of the three squares it is about to
	## land in. Drawn a little larger than a square so it stays readable under the cursor.
	var id := _gear_id(p_session)
	if id == "":
		return
	var size := BrawlField.cell() * 0.34
	var rect := Rect2(_drag_pos - Vector2(size * 0.5, size * 0.5), Vector2(size, size))
	draw_rect(rect, BalanceUI.COLOR_BRAWL_INFO_BG, true)
	var art := GearDB.art(id)
	if art != "":
		UiStyle.draw_icon(self, art, rect.position + Vector2(2.0, 2.0), size - 4.0,
			BalanceUI.BRAWL_DRAG_ALPHA)
	else:
		var font := ThemeDB.fallback_font
		if font != null:
			_draw_text(font, GearDB.display_name(id), rect.position.x + size * 0.5,
				rect.position.y + size * 0.5 + 5.0, BalanceUI.BRAWL_BENCH_NAME_FONT_SIZE,
				BalanceUI.COLOR_MENU_TITLE, size)
	draw_rect(rect, BalanceUI.COLOR_ITEM_TILE_SELECTED, false, BrawlField.EDGE_WIDTH)


# ---------------------------------------------------------------- the hover panel [B5+]
func _hover_piece() -> String:
	## WHICH piece the pointer is over, or "". Three places can answer, in this order: a bench
	## slot, a piece on your own half, and an enemy piece - the last one only while the identity
	## setting allows it (D37: with the switch off the page must not tell you who is over there,
	## or the setting would be decoration).
	var session := _session()
	if session == null:
		return ""
	if _hover_bench >= 0:
		return _piece_of(session, session.bench_piece_at_slot(_hover_bench))
	if session.is_home_cell(_hover.x, _hover.y):
		return _piece_of(session, session.index_at_cell(_hover.x, _hover.y))
	if not SettingsStore.show_enemy_pieces:
		return ""
	if _hover.x < BalanceBrawl.HALF_COLS + BalanceBrawl.GAP_COLS or _hover.y < 0 \
			or _hover.y >= Balance.ROWS:
		return ""
	for entry in session.chosen_rows():
		var row := entry as Dictionary
		if int(row.get("col", -1)) == _hover.x and int(row.get("row", -1)) == _hover.y:
			return str(row.get("piece", ""))
	return ""


func _info_for(p_piece: String) -> Dictionary:
	## Everything the panel says about one piece, in the player's language, with every NUMBER read
	## from the sheet that owns it. This is the one place on the page where a PLANT, a ZOMBIE and
	## a HUMAN PIECE are described by the same code, so it dispatches by roster exactly as
	## Balance.unit_name() / unit_art() do (and in the same order).
	if p_piece == "":
		return {}
	var lines: Array = []
	if PieceDB.has(p_piece):
		lines.append(Loc.tf("brawl.info.stats_piece", [PieceDB.cost(p_piece), PieceDB.hp(p_piece),
			PieceDB.attack(p_piece)]))
		## The three real-time numbers through HumanPiece's own doors: the panel must not promise
		## a reach or a rhythm the piece would not actually have (a blank cell falls back to
		## BalanceBrawl, and that choice has one owner - the body).
		lines.append(Loc.tf("brawl.info.stats_move", [HumanPiece.effective_reach(p_piece),
			HumanPiece.effective_move_speed(p_piece), HumanPiece.effective_strike_seconds(p_piece)]))
		var rarity := PieceDB.rarity(p_piece)
		if rarity != "":
			lines.append(Loc.tf("brawl.info.rarity", [Balance.rarity_label(rarity)]))
		_append_prose(lines, PieceDB.text(p_piece, "skill"), PieceDB.text(p_piece, "special"))
	elif ZombieDB.has(p_piece):
		lines.append(Loc.tf("brawl.info.stats_zombie", [ZombieDB.hp(p_piece),
			ZombieDB.armor(p_piece), ZombieDB.move(p_piece), ZombieDB.bite(p_piece)]))
		_append_prose(lines, "", ZombieDB.text(p_piece, "special"))
	elif Balance.has_plant(p_piece):
		lines.append(Loc.tf("brawl.info.stats_plant", [Balance.plant_max_hp(p_piece),
			PlantDB.attack(p_piece), Balance.plant_cost(p_piece)]))
		_append_prose(lines, PlantDB.text(p_piece, "skill"), PlantDB.text(p_piece, "special"))
	else:
		return {}
	return {"title": Balance.unit_name(p_piece), "lines": lines}


func _append_prose(p_lines: Array, p_skill: String, p_special: String) -> void:
	## The sheet's own sentences, when it has them. A row that says nothing adds no line: an empty
	## "技能：" would read as a promise rather than as a description.
	if p_skill.strip_edges() != "":
		p_lines.append(Loc.tf("brawl.info.skill", [p_skill]))
	if p_special.strip_edges() != "":
		p_lines.append(Loc.tf("brawl.info.special", [p_special]))


func _draw_info() -> void:
	## The panel follows the pointer. While a piece is IN HAND it stays away: the ghost is under
	## the cursor, and a panel on top of it would hide the thing being placed.
	if _dragging:
		return
	var piece := _hover_piece()
	if piece == "":
		return
	var info := _info_for(piece)
	if info.is_empty():
		return
	## [B7] What THIS piece wears, appended here rather than inside _info_for: that function knows
	## a piece by its ID (it also answers for enemies), while the attachments hang off the roster
	## ENTRY - so the page asks the session for the index and the door is _worn_text().
	var worn := _worn_text(_session(), _hover_index())
	if worn != "":
		(info["lines"] as Array).append(Loc.tf("brawl.info.gear", [worn]))
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
	if p_event is InputEventMouseMotion:
		var motion := p_event as InputEventMouseMotion
		_update_hover(motion.position)
		if _pressing:
			_drag_pos = motion.position
			if not _dragging and _press_pos.distance_to(motion.position) > BalanceUI.BRAWL_DRAG_THRESHOLD:
				_dragging = true
			queue_redraw()
		return
	if not (p_event is InputEventMouseButton):
		return
	var click := p_event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var session := _session()
	if session == null:
		return
	if click.pressed:
		_on_press(session, click.position)
	else:
		_on_release(session, click.position)


func _update_hover(p_at: Vector2) -> void:
	_mouse = p_at
	var session := _session()
	if session == null:
		return
	var slot := _bench_slot_at(p_at)
	var cell := BrawlField.cell_at(p_at)
	if slot == _hover_bench and cell == _hover:
		return
	_hover_bench = slot
	_hover = cell
	## The pointer says what is under it: a hand over a piece [B7] or over a bag tile that holds
	## something, an arrow anywhere else.
	var grabby: bool = _hover_piece() != ""
	if not grabby:
		var window := _bag_window()
		var tile := _bag_tile_at(p_at)
		grabby = tile >= 0 and tile < int(window.get("back", 0)) + int(window.get("items", 0))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if grabby else Control.CURSOR_ARROW
	queue_redraw()


func _on_press(p_session: BrawlSession, p_at: Vector2) -> void:
	_press_pos = p_at
	_drag_pos = p_at
	_pressing = true
	_dragging = false
	_update_hover(p_at)
	## [B7] THE BAG FIRST OF ALL: it is a box of its own at the foot of the left column, and a
	## press there is never a press on the board behind it.
	var tile := _bag_tile_at(p_at)
	if tile >= 0:
		_on_bag_press(p_session, tile)
		return
	## [B7] AN ATTACHMENT ALREADY IN HAND + a press anywhere else = the second half of the
	## two-step idiom: the same "pick it up, click where it goes" a piece gets, so a player who
	## clicks instead of dragging is not left wondering why nothing happened. A press on a bag
	## tile above has already returned, so this can never mean "put it down where it came from"
	## by accident.
	if _gear_in_hand():
		_drop_gear(p_session, p_at)
		return
	## [B7] ...then the three squares under a piece: a press on an OCCUPIED one picks THAT up
	## instead of the piece. An empty square is not a press at all - it falls through to the piece
	## below it, which is what makes "click the piece, click a cell" keep working.
	var hit := _attach_hit(p_at)
	var hit_piece := int(hit.get("piece", -1))
	var hit_slot := int(hit.get("slot", -1))
	if hit_piece >= 0 and hit_slot >= 0 and hit_slot < p_session.attach_slots(hit_piece).size():
		_gear_bag = -1
		_gear_piece = hit_piece
		_gear_slot = hit_slot
		## ONE HAND AT A TIME: a piece that was picked up with a click is let go, or the next
		## click would have to guess which of the two the player meant.
		_selected = -1
		_drag_index = -1
		_hint = Loc.tf("brawl.form.selected_gear", [_gear_name(p_session)])
		_refresh_texts()
		return
	## A SLOT first, then a cell: the bench is a strip of the same page, and a press there must
	## never be read as a press on the board behind it. An EMPTY slot is not a press at all.
	var slot := _bench_slot_at(p_at)
	if slot >= 0:
		var waiting := p_session.bench_piece_at_slot(slot)
		if waiting >= 0:
			_begin_drag(p_session, waiting)
		return
	var cell := BrawlField.cell_at(p_at)
	if not p_session.is_home_cell(cell.x, cell.y):
		## Outside the half: the old idiom's "put it down" gesture, and the refusal the drag
		## would have given (the same words, so the two idioms answer alike).
		if _selected >= 0:
			_hint = Loc.t("brawl.form.drop_bad")
			queue_redraw()
		return
	var occupant := p_session.index_at_cell(cell.x, cell.y)
	if occupant >= 0:
		_begin_drag(p_session, occupant)
		return
	_place_selected(p_session, cell)


func _on_bag_press(p_session: BrawlSession, p_tile: int) -> void:
	## [B7] A PRESS IN THE BAG. Three things a tile position can mean, in this order: the window's
	## "back" mark, its "+N" mark, or an attachment to pick up. The HEADER (above the tiles) sends
	## the window home, so a bag whose tail is out of sight is two clicks from its head.
	var window := _bag_window()
	if p_tile < 0:
		return
	if not _bag_tile_rect(p_tile).has_point(_press_pos):
		return
	if p_tile < int(window.get("back", 0)):
		_bag_first = maxi(0, int(window.get("first", 0)) - maxi(1, _bag_fit() - 2))
		queue_redraw()
		return
	var items := int(window.get("items", 0))
	if p_tile >= int(window.get("back", 0)) + items:
		_bag_first = int(window.get("first", 0)) + maxi(1, items)
		queue_redraw()
		return
	var index := int(window.get("first", 0)) + p_tile - int(window.get("back", 0))
	if index < 0 or index >= p_session.bag.size():
		return
	_gear_bag = index
	_gear_piece = -1
	_gear_slot = -1
	## ONE HAND AT A TIME - see the note on the squares above.
	_selected = -1
	_drag_index = -1
	_hint = Loc.tf("brawl.form.selected_gear", [_gear_name(p_session)])
	_refresh_texts()


func _gear_name(p_session: BrawlSession) -> String:
	## What the hand is holding, named for the hint line. GearDB owns the name (the sheet carries
	## name_zh), so nothing here spells a row.
	return GearDB.display_name(_gear_id(p_session))


func _begin_drag(p_session: BrawlSession, p_index: int) -> void:
	## THE HAND, and the only thing a press does: NOTHING MOVES YET. That is what makes an
	## abandoned drag free - the piece is still on its cell or in its slot until the button comes
	## up - and it is also what lets the bench be a hard limit of nine slots, since grabbing a
	## piece off the board needs no slot at all.
	## [B7] ONE HAND AT A TIME: an attachment that was picked up goes back to where it was (it was
	## never taken anywhere - see _cancel_drag), so the two gestures cannot both be half-done.
	_gear_bag = -1
	_gear_piece = -1
	_gear_slot = -1
	_drag_index = p_index
	_selected = p_index
	## [B15] The PIECE's own line (brawl.form.selected_piece, and the twin of the gear hand's
	## selected_gear): a piece can be dismissed as well as placed, and the sentence a player reads
	## while holding one is the only place that button is announced.
	_hint = Loc.tf("brawl.form.selected_piece", [Balance.unit_name(_piece_of(p_session, p_index))])
	_refresh_texts()


func _on_release(p_session: BrawlSession, p_at: Vector2) -> void:
	_pressing = false
	if not _dragging:
		## A CLICK, not a drag: the press put a piece in hand (or placed one), so lifting off
		## changes nothing. The next click - on a cell - is what puts it down (the two-step idiom).
		queue_redraw()
		return
	_dragging = false
	_drop(p_session, p_at)


func _drop(p_session: BrawlSession, p_at: Vector2) -> void:
	## [B7] AN ATTACHMENT IN HAND goes to its own door: onto a piece (worn), onto the bag (taken
	## off), or nowhere (refused with a sentence).
	if _gear_in_hand():
		_drop_gear(p_session, p_at)
		return
	## WHERE THE PIECE ENDS UP, through one of the session's two doors: onto the board (place) or
	## into the bench (send_to_bench). Both settle whoever stands there themselves - a drop is
	## never a two-step the page then has to undo.
	var index := _drag_index
	_cancel_drag()
	if index < 0:
		return
	var piece := Balance.unit_name(_piece_of(p_session, index))
	var slot := _bench_slot_at(p_at)
	if slot >= 0 or _in_bench_strip(p_at):
		## The bench: a NAMED slot trades places with whoever waits there, the column at large
		## means "the lowest free slot".
		if p_session.send_to_bench(index, slot):
			_hint = Loc.tf("brawl.form.benched", [piece])
		else:
			_hint = Loc.t("brawl.form.bench_full")
		_selected = -1
		_refresh_texts()
		return
	var cell := BrawlField.cell_at(p_at)
	if not p_session.is_home_cell(cell.x, cell.y):
		_hint = Loc.t("brawl.form.drop_bad")
		_selected = -1
		_refresh_texts()
		return
	if p_session.place(index, cell.x, cell.y):
		_hint = Loc.t("brawl.form.hint")
	else:
		## The only way place() refuses a cell of your own half: the cap is full and the piece is
		## coming out of the bench onto an empty cell.
		_hint = Loc.tf("brawl.form.full", [p_session.deploy_cap])
	_selected = -1
	_refresh_texts()


func _drop_gear(p_session: BrawlSession, p_at: Vector2) -> void:
	## [B7] WHERE AN ATTACHMENT ENDS UP. Three answers:
	##   on the bag (header included) -> UNEQUIPPED, back in the bag (O36: nothing is locked on);
	##   on a piece                  -> worn, or MOVED off the piece it came from;
	##   anywhere else               -> refused, with the sentence that says what a legal drop is.
	## The hand is captured FIRST because _cancel_drag() forgets it - and the session is only
	## touched after that, so a refused drop has changed nothing at all.
	var name := _gear_name(p_session)
	var from_bag := _gear_bag
	var from_piece := _gear_piece
	var from_slot := _gear_slot
	_cancel_drag()
	_selected = -1
	if _in_bag_box(p_at):
		if from_piece >= 0 and p_session.unequip(from_piece, from_slot):
			_hint = Loc.tf("brawl.attach.removed", [name])
		else:
			_hint = Loc.t("brawl.form.hint")
		_refresh_texts()
		return
	var hit := _attach_hit(p_at)
	if hit.is_empty():
		_hint = Loc.t("brawl.attach.bad")
		_refresh_texts()
		return
	var target := int(hit.get("piece", -1))
	var target_slot := int(hit.get("slot", -1))
	var landed := false
	if from_bag >= 0:
		landed = p_session.equip(target, from_bag)
	else:
		landed = p_session.move_attach(from_piece, from_slot, target, target_slot)
	if landed:
		var verb := "brawl.attach.equipped" if from_bag >= 0 else "brawl.attach.moved"
		_hint = Loc.tf(verb, [name, Balance.unit_name(_piece_of(p_session, target))])
	else:
		## Only one way a drop onto a piece can be refused: it already wears three (O37).
		_hint = Loc.tf("brawl.attach.full", [Balance.unit_name(_piece_of(p_session, target))])
	_refresh_texts()


func _place_selected(p_session: BrawlSession, p_cell: Vector2i) -> void:
	## The second half of the two-step idiom, unchanged from B2c: a click on a free cell of your
	## half puts down whatever is in hand.
	if _selected < 0:
		_hint = Loc.t("brawl.form.pick_first")
		queue_redraw()
		return
	if not p_session.field_at(_selected, p_cell.x, p_cell.y):
		_hint = Loc.tf("brawl.form.full", [p_session.deploy_cap])
		queue_redraw()
		return
	_selected = -1
	_hint = Loc.t("brawl.form.hint")
	_refresh_texts()


func _cancel_drag() -> void:
	## Forget BOTH hands. NOTHING IS PUT BACK, because nothing was ever taken: the session is only
	## touched at the release (see _begin_drag). [B7] the same promise covers an attachment - a
	## drag that is abandoned leaves it exactly where it was.
	_drag_index = -1
	_gear_bag = -1
	_gear_piece = -1
	_gear_slot = -1
	_pressing = false
	_dragging = false


func _piece_rect(p_session: BrawlSession, p_index: int) -> Rect2:
	## The rectangle one roster entry is drawn in, wherever it is - a bench slot or a board cell.
	## The tint above needs it for a piece the POINTER is over (not the hovered one), so it asks
	## the session where that entry is rather than reading _hover.
	if p_session == null or p_index < 0 or p_index >= p_session.pool.size():
		return Rect2()
	var row := p_session.pool[p_index] as Dictionary
	var slot := int(row.get("slot", -1))
	if slot >= 0:
		return _bench_slot_rect(slot)
	return _cell_inner_rect(Vector2i(int(row.get("col", -1)), int(row.get("row", -1))))


func _piece_of(p_session: BrawlSession, p_index: int) -> String:
	if p_session == null or p_index < 0 or p_index >= p_session.pool.size():
		return ""
	return str((p_session.pool[p_index] as Dictionary).get("piece", ""))


func _refresh_texts() -> void:
	## Refresh every line the session can have changed, WITHOUT touching the hand: a player who
	## just put a piece down must not lose what they picked up.
	var session := _session()
	if session == null:
		return
	## [S2] The cap line carries the bench count too: the caption that used to sit under the bench
	## row is gone with the band (see _draw_bench), and these are the numbers a player checks
	## before committing a round.
	_status = (Loc.tf("brawl.form.cap",
		[session.fielded_count(), session.deploy_cap, session.coins])
		+ "   -   " + Loc.tf("brawl.info.bench",
			[session.reserve_count(), BalanceBrawl.BENCH_SLOTS]))
	var offer := session.chosen_offer()
	if offer.is_empty():
		_versus = Loc.t("brawl.no_offers")
	else:
		## [B8+] Count and strength come from the ROUND'S ROLL, so the card, the preview and the
		## fight agree - the sheet's authored list is what MAY stand there, not what does.
		## [B29] Name and price come from the OFFER for the same reason the rows do: this round's
		## opponent may be one no formation sheet lists, and its 金币 is the round's floor, not the
		## column a four-row file happens to carry.
		var rows := session.chosen_rows()
		_versus = Loc.tf("brawl.form.opponent", [session.chosen_title(),
			FormationDB.count_of(rows), FormationDB.hp_total_of(rows), session.chosen_coins()])
	if _confirm != null:
		## [B26] ONE label and ONE rule: the round is committed to an opponent, and an opponent needs
		## pieces on the board. Both used to have a second arm for a SHOP round (the button said
		## 逛商店 and no piece was required) - the shelf lies on the board now, so spending
		## coin is never what a round is.
		_confirm.disabled = offer.is_empty() or session.fielded_count() <= 0
		_confirm.text = Loc.t("brawl.form.engaged")
	for entry in _offer_buttons:
		var row: Dictionary = entry
		var btn := row["btn"] as Button
		var index := int(row.get("index", -1))
		if btn == null or index < 0 or index >= session.offers.size():
			continue
		btn.text = _offer_label(session, index)
	_refresh_shop()
	_sync_dismiss()
	queue_redraw()


func _sync_dismiss() -> void:
	## [B15] 遣散 IS ARMED BY THE HAND, NOT BY THE POINTER. A piece has to be picked up first
	## (the same first half the two-step idiom uses for moving one), which is the whole safety
	## of an action that cannot be undone: with an empty hand the button is dead, and the piece
	## it will take is the one wearing the selected border.
	##
	## Called from _refresh_texts(), i.e. every time the selection moves - one line, one place,
	## because a button whose state is updated at the call sites drifts the first time a new
	## one is added.
	if _dismiss == null or not is_instance_valid(_dismiss):
		return
	_dismiss.disabled = _selected < 0


# ---------------------------------------------------------------- the shelf [B26]
func _shop_label(p_row: Dictionary) -> String:
	## The NAME half of a shelf row. A piece and an attachment are named by the sheet that owns
	## them (and an attachment shows its effect, value and all); the cap rung is the one row the
	## brawl authors itself, so its wording is a loc entry. This came here with the shelf - the page
	## never owns a price, a name or a rule, it only says which sheet to ask.
	## [B7] An augment row and an equipment row are ONE branch with two words in front of the name:
	## on a shelf of five rows, "which of these two do I drag onto a piece" has to be readable at a
	## glance, and the two kinds are otherwise spelled the same way.
	var kind := str(p_row.get("kind", ""))
	if kind == BalanceBrawl.REWARD_KIND_CAP:
		return Loc.tf("brawl.shop.cap", [BalanceBrawl.DEPLOY_CAP_STEP])
	if kind == BalanceBrawl.REWARD_KIND_AUGMENT or kind == BalanceBrawl.REWARD_KIND_EQUIPMENT:
		var gear := str(p_row.get("id", ""))
		var is_augment: bool = kind == BalanceBrawl.REWARD_KIND_AUGMENT
		return Loc.tf("brawl.shop.augment" if is_augment else "brawl.shop.equipment",
			[GearDB.display_name(gear), GearDB.effect_text(gear)])
	return Balance.unit_name(str(p_row.get("id", "")))


func _shop_row_text(p_session: BrawlSession, p_index: int) -> String:
	## What one row says: the item and its price, or the item and the fact it is gone. Built once
	## and reused by _build() and _refresh_shop(), so a row cannot read differently before and after
	## somebody else's purchase.
	var row := p_session.stock_row(p_index)
	var label := _shop_label(row)
	if bool(row.get("sold", false)):
		return Loc.tf("brawl.shop.sold", [label])
	return Loc.tf("brawl.shop.row", [label, int(row.get("price", 0))])


func _refresh_shop() -> void:
	## [B26] Every shelf line and every grey row, WITHOUT rebuilding the buttons - so a purchase
	## cannot move the row a player was about to click (the reason the standalone page did it this
	## way too). A row that cannot be bought is DISABLED rather than hidden: "too dear", "already
	## sold" and "no room in the bench" all have to be visible, or the shelf looks like it lost an
	## item. [B5+] The last of the three also SAYS SO - the three want different answers from the
	## player, so they must not look alike.
	## [B27] The whole group, on the other hand, IS hidden when the shelf is down: a row that is merely
	## DISABLED would still lie over the enemy preview and swallow the clicks meant for it.
	var session := _session()
	if session == null:
		return
	## [B27] THE DOOR WEARS THE SAME MARK the opponents wear. The two answer different questions and can
	## both be lit at once: an offer card's 已选 is the round's COMMITMENT, this cell's is what the
	## right half is SHOWING. So closing the shelf never clears the chosen opponent, and opening it
	## never commits anything.
	if _shop_toggle != null and is_instance_valid(_shop_toggle):
		_shop_toggle.text = ((Loc.t("brawl.form.chosen_mark") + "  " + Loc.t("brawl.shop.caption"))
			if _shop_open else Loc.t("brawl.shop.caption"))
	for entry in _shop_buttons:
		var handle: Dictionary = entry
		var btn := handle["btn"] as Button
		var index := int(handle.get("index", -1))
		if btn == null or not is_instance_valid(btn):
			continue
		btn.visible = _shop_open
		var stock := session.stock_row(index)
		btn.text = _shop_row_text(session, index)
		btn.disabled = not session.can_buy(index)
		if btn.disabled and not bool(stock.get("sold", false)) \
				and str(stock.get("kind", "")) == BalanceBrawl.REWARD_KIND_PIECE \
				and not session.can_hold_more():
			btn.text += "  " + Loc.t("brawl.shop.bench_full")


# ---------------------------------------------------------------- callbacks
func _on_offer_pressed(p_index: int) -> void:
	## Switching the opponent REDRAWS THE ENEMY HALF, which is the whole point of choosing here:
	## the board you are arranging against changes under your hands.
	## [B27] And it pulls the shelf's cover DOWN to do it (the user, 2026-10-08: "点击某敌阵时会显示
	## 对应敌阵") - an opponent picked behind an opaque panel would be a choice made blind.
	var session := _session()
	if session == null or not session.pick(p_index):
		return
	_shop_open = false
	_refresh_texts()


func _on_shop_toggle() -> void:
	## [B27] THE SHELF'S ONE DOOR, and the whole of it: the bit flips, the page redraws. Nothing here
	## touches the session - the stock is rolled with the round and stays rolled whether or not the
	## player is looking at it, so there is no "opening the shop" left to do (D22's shop EVENT went
	## with the page in [B26], and a toggle is not an event: no round is spent, no round is entered).
	_shop_open = not _shop_open
	_refresh_texts()


func _on_shop_pressed(p_index: int) -> void:
	## [B26] Buy through the session's one door (which prices, pays, marks the row sold and hands
	## the goods to the SAME door a reward goes through), then refresh IN PLACE - the shelf, the
	## bench and the header all read the session's numbers, and the goods are already among them.
	## A "" answer (a double click reaching a button that was still live for one frame) needs no
	## special handling: refreshing what did not change is free.
	##
	## ⚠ A purchase is NOT a round's event any more (D22's shop event is retired): it costs coin and
	## nothing else, and the round is still the opponent's.
	var session := _session()
	if session == null:
		return
	session.buy(p_index)
	_refresh_texts()


func _on_dismiss() -> void:
	## [B15] 遣散 THE PIECE IN HAND, through the session's one door. Everything this function
	## needs is read BEFORE the call, because the call is what invalidates the index (the pool
	## closes the gap the entry left, so every later index means somebody else afterwards).
	##
	## A REFUSAL IS THE SESSION'S, and it has exactly one cause today: the piece in hand is the
	## last one, and a roster with nothing in it could never field anything again. The sentence
	## says so instead of the button simply doing nothing.
	var session := _session()
	if session == null or _selected < 0:
		return
	var piece := Balance.unit_name(_piece_of(session, _selected))
	var worn := session.attach_slots(_selected).size()
	if not session.dismiss(_selected):
		_hint = Loc.t("brawl.form.dismiss_last")
		_refresh_texts()
		return
	## BOTH HANDS LET GO: the piece is gone, so nothing may still be pointing at it (see the
	## note above about indices).
	_cancel_drag()
	_selected = -1
	_hint = (Loc.tf("brawl.form.dismissed_gear", [piece, worn]) if worn > 0
		else Loc.tf("brawl.form.dismissed", [piece]))
	_refresh_texts()


func _on_confirm() -> void:
	## [B26] ONE button, ONE destination: 出战 starts the bout the round is committed to. The fork
	## that used to sit behind this door (BrawlMain.confirm(), which sent a SHOP round to a page of
	## its own) went with the page, so the receiver moves back to start_bout() - and this line is
	## the caller PITFALLS §2.1 #69 says to change together with the door.
	_cancel_drag()
	if game != null:
		game.brawl_main.start_bout()
