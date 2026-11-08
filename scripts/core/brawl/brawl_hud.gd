class_name BrawlHUD
extends RefCounted
## [S4] THE BAND ABOVE THE BOARD - the one strip both brawl pages wear.
##
## The two pages are the same field (D66): the same board rectangle (BrawlLayout), the same
## lattice (BrawlField.draw_grid) and the same header. Drawing the header through ONE function is
## what makes that true rather than merely similar: the formation page hands it the round's title,
## its cap line, the key hint and the opponent; the arena hands it the spectator readout (D70).
## A second copy of "how the header looks" is how two screens start disagreeing - the same rule
## BrawlField's drawers already follow.
##
## Read by scripts/ui/brawl/brawl_formation.gd and scripts/core/brawl/brawl.gd, and by nothing
## else. Nothing here owns a string: the words come from the language layer (AGENTS §3), and the
## numbers from whoever knows them.

static func draw_top_bar(p_ci: CanvasItem, p_title: String, p_status: String,
		p_hint: String, p_note: String) -> void:
	## Four slots, two lines: title and status on the first (the status is right-aligned, so it
	## ends where the board ends), the hint and the note on the second. Any of them may be empty -
	## the arena has no key hint worth a line of its own today, and a page with no session has no
	## note - and an empty slot simply draws nothing.
	if p_ci == null:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var rect := BrawlLayout.top_bar_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	## Line 1: the title's BASELINE, not its top - the one thing about text placement that is
	## easy to get wrong twice. BRAWL_TOP_BAR_H is 48 for exactly these two lines.
	var line1 := rect.position.y + BalanceUI.BRAWL_TOP_TITLE_BASELINE
	var line2 := rect.position.y + rect.size.y - BalanceUI.BRAWL_TOP_LINE_PAD
	_draw_line(p_ci, font, p_title, rect, line1, BalanceUI.BRAWL_TOP_TITLE_FONT_SIZE,
		BalanceUI.COLOR_MENU_TITLE, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_line(p_ci, font, p_status, rect, line1, BalanceUI.BRAWL_TOP_STATUS_FONT_SIZE,
		BalanceUI.COLOR_MENU_SUB, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_line(p_ci, font, p_hint, rect, line2, BalanceUI.BRAWL_TOP_HINT_FONT_SIZE,
		BalanceUI.COLOR_MENU_SUB, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_line(p_ci, font, p_note, rect, line2, BalanceUI.BRAWL_TOP_HINT_FONT_SIZE,
		BalanceUI.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)


static func _draw_line(p_ci: CanvasItem, p_font: Font, p_text: String, p_rect: Rect2,
		p_baseline: float, p_size: int, p_color: Color, p_align: int) -> void:
	## One line of the header, clipped to the band: draw_string's own width argument is the clip,
	## so a language that says the same thing in more words cannot spill over the board's edge.
	if p_text == "":
		return
	p_ci.draw_string(p_font, Vector2(p_rect.position.x, p_baseline), p_text, p_align,
		p_rect.size.x, p_size, p_color)


static func draw_side_hp_bars(p_ci: CanvasItem, p_left_text: String, p_right_text: String,
		p_left_cur: int, p_left_peak: int, p_right_cur: int, p_right_peak: int) -> void:
	## [P111] THE SIDE-HP TUG-OF-WAR, drawn by a fighting arena right AFTER draw_top_bar (and by
	## the formation page never - there is no bout to read yet). It lives in the empty middle of
	## line 1, between the end texts, which is why it MEASURES them rather than trusting a fixed
	## gutter: the arena hands in the very strings draw_top_bar just painted (brawl's score, war's
	## round / clock) so a longer language, a bigger alive count or a wide clock cannot make the
	## strips collide with the text. Ally (SIDE_LEFT, green) hugs the left and shrinks leftward;
	## enemy (SIDE_RIGHT, red) mirrors it, hugging the right. The denominator is the side's HP when
	## the bout opened - the roster is fixed for a bout, so `cur / peak` only ever falls and the bar
	## reads "how much of this army is still standing", never grows. A side that opened empty
	## (peak 0) draws nothing for that half; both empty drops the pair.
	if p_ci == null:
		return
	if p_left_peak <= 0 and p_right_peak <= 0:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var rect := BrawlLayout.top_bar_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	## The two ends line 1 already spends, so the pair is laid in what is genuinely left.
	var left_pad := _text_width(font, p_left_text, BalanceUI.BRAWL_TOP_TITLE_FONT_SIZE)
	var right_pad := _text_width(font, p_right_text, BalanceUI.BRAWL_TOP_STATUS_FONT_SIZE)
	var pad := BalanceUI.BRAWL_SIDE_BAR_TEXT_PAD
	var lx := rect.position.x + left_pad + pad
	var rx := rect.position.x + rect.size.x - right_pad - pad
	var avail := rx - lx
	if avail <= 0.0:
		return
	var small := BalanceUI.BRAWL_TOP_HINT_FONT_SIZE
	var ln := "%d/%d" % [p_left_cur, p_left_peak]
	var rn := "%d/%d" % [p_right_cur, p_right_peak]
	var ln_w := _text_width(font, ln, small)
	var rn_w := _text_width(font, rn, small)
	var gap := BalanceUI.BRAWL_SIDE_BAR_GAP
	var mid := BalanceUI.BRAWL_SIDE_BAR_TEXT_TO_TEXT_GAP
	var bar_w := BalanceUI.BRAWL_SIDE_BAR_W
	if bar_w * 2.0 + gap * 2.0 + ln_w + rn_w + mid > avail:
		bar_w = floor((avail - gap * 2.0 - ln_w - rn_w - mid) * 0.5)
	if bar_w < BalanceUI.BRAWL_SIDE_BAR_MIN_W:
		return
	var y := rect.position.y + BalanceUI.BRAWL_SIDE_BAR_LINE_Y
	var h := BalanceUI.BRAWL_SIDE_BAR_H
	# ally: track, then a fill hugging the LEFT edge, its number to the bar's right
	p_ci.draw_rect(Rect2(lx, y, bar_w, h), BalanceUI.COLOR_BAR_BG)
	if p_left_peak > 0:
		var lr := clampf(float(p_left_cur) / float(p_left_peak), 0.0, 1.0)
		p_ci.draw_rect(Rect2(lx, y, bar_w * lr, h), BalanceUI.COLOR_SIDE_BAR_ALLY)
	p_ci.draw_string(font, Vector2(lx + bar_w + gap, y + h), ln,
		HORIZONTAL_ALIGNMENT_LEFT, -1, small, BalanceUI.COLOR_SIDE_BAR_ALLY)
	# enemy: the mirror - track, a fill hugging the RIGHT edge, its number to the bar's left
	var r_x := rx - bar_w
	p_ci.draw_rect(Rect2(r_x, y, bar_w, h), BalanceUI.COLOR_BAR_BG)
	if p_right_peak > 0:
		var rr := clampf(float(p_right_cur) / float(p_right_peak), 0.0, 1.0)
		p_ci.draw_rect(Rect2(r_x + bar_w * (1.0 - rr), y, bar_w * rr, h),
			BalanceUI.COLOR_SIDE_BAR_ENEMY)
	p_ci.draw_string(font, Vector2(r_x - gap - rn_w, y + h), rn,
		HORIZONTAL_ALIGNMENT_LEFT, -1, small, BalanceUI.COLOR_SIDE_BAR_ENEMY)


static func _text_width(p_font: Font, p_text: String, p_size: int) -> float:
	## The one measurement the tug-of-war layout needs: how wide a line-1 string actually is, so
	## the strips stop short of the text instead of assuming a fixed gutter that a wider language
	## would overrun.
	if p_font == null or p_text == "":
		return 0.0
	return p_font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_size).x
