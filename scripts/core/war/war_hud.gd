class_name WarHud
extends Control
## [W5] THE COMMANDER'S ONLY INSTRUMENT PANEL - what a spectator who commands nothing but
## their eyes is shown: which round is fighting, who is left, the clock - and after the
## curtain, the receipt. ([W8] retired the "when the next wave comes" slot: rounds are
## fielded whole at the bout's opening, so the arena pushes "" there and it draws nothing.)
##
## It lives on a CanvasLayer ABOVE the arena because the camera transforms everything hung
## in the world: a HUD drawn as world pixels would pan and zoom away with the map (the plan's
## section C, kept as structure). As a full-rect Control it follows the window on its own,
## and every number arrives THROUGH `tick()` from the arena - this node owns no rule, no
## clock, no plan; it only ever draws what it was told last frame.
##
## The top band is drawn through BrawlHUD.draw_top_bar (D66's single drawer, the same one
## the brawl arena and the brawl formation page wear) on the same band rectangle - so the
## two modes' headers cannot drift apart, and the only war-owned picture is the receipt
## under it. Nothing here owns a string (AGENTS §3): the words come from the language layer,
## and the arena re-pushes every frame, so a mid-match language switch needs no wiring.

var _round_text := ""
var _next_text := ""
var _score_text := ""
var _clock_text := ""
var _hint_text := ""
## The receipt, set once by show_result and cleared by the next match's begin_match. An
## empty _result means "still fighting" - and only still-fighting, because the arena keeps
## ticking the band through the curtain; the receipt never lies about a live match.
var _result := ""
var _result_line := ""
var _result_hint := ""
## [P111] The four side-HP numbers the tug-of-war bar is drawn from (current / bout-open peak per
## side), pushed every frame by the arena through `set_side_hp` - this node owns no rule, so it
## never reads an actor, it just paints what it was told. All zero until the first bout opens.
var _hp: Array[int] = [0, 0, 0, 0]


func set_side_hp(p_left_cur: int, p_left_peak: int, p_right_cur: int, p_right_peak: int) -> void:
	## [P111] The arena's side totals, handed over as they are (it owns the facts). Kept whole for
	## the next `_draw`, which lays them in the band's line-1 middle through the brawl's shared drawer.
	_hp = [p_left_cur, p_left_peak, p_right_cur, p_right_peak]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	## The eyes command nothing - clicks belong to the camera (pan) and the arena's own
	## _input (keys), never to a panel.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_p_delta: float) -> void:
	## Redraw every frame like the brawl's root does: the band's numbers move constantly,
	## and a language switch must repaint within one frame without any page knowing.
	queue_redraw()


func begin_match(_p_round_total: int) -> void:
	## restart / R: whatever receipt the last match left is wiped. The count itself is not
	## kept here - the arena prints it inside the round string every frame, so this door only
	## clears, and the argument exists to say "a NEW match of N rounds has begun" out loud.
	_result = ""
	_result_line = ""
	_result_hint = ""


func tick(p_round: String, p_next: String, p_score: String, p_clock: String,
		p_hint: String) -> void:
	## The five band strings, already translated by the arena (which owns the facts). An
	## empty p_next means "nothing to count down" - [W8]'s rounds have no second hand, so
	## the arena pushes "" and the slot simply draws nothing.
	_round_text = p_round
	_next_text = p_next
	_score_text = p_score
	_clock_text = p_clock
	_hint_text = p_hint


func show_result(p_word: String, p_line: String, p_hint: String) -> void:
	## The receipt, handed over whole after the curtain (the arena formats every string -
	## this node never asks a rule a question).
	_result = p_word
	_result_line = p_line
	_result_hint = p_hint


func _draw() -> void:
	## WHY THE WAR ASKS FOR A BRAWL LAYOUT: the band is drawn through BrawlHUD, whose
	## rectangle is BrawlLayout.top_bar - and a war field deliberately never refreshes that
	## layout (WarField._on_viewport_resized says no, its board is a fixed world). The HUD is
	## a window-side picture, so it keeps the ONE number its drawer reads current: refresh is
	## idempotent and returns false untouched while Layout.size stands still. Only top_bar is
	## ever consumed here - no war board geometry goes through this door.
	BrawlLayout.refresh(Layout.size)
	BrawlHUD.draw_top_bar(self, _round_text, _clock_text, _hint_text, _next_text)
	## [P111] The two armies' total HP in the band's line-1 middle, through the SAME drawer the
	## brawl arena uses - measured against the round / clock strings that line 1 just painted.
	BrawlHUD.draw_side_hp_bars(self, _round_text, _clock_text,
		_hp[0], _hp[1], _hp[2], _hp[3])
	if _result == "":
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	## The wash first: the frozen battlefield stays readable under the verdict, which is the
	## brawl's curtain promise kept on the picture side.
	var dim := BalanceUI.COLOR_MENU_BG
	dim.a = BalanceWar.WAR_HUD_DIM_ALPHA
	draw_rect(Rect2(Vector2.ZERO, size), dim)
	var w := size.x
	draw_string(font, Vector2(0.0, size.y * BalanceWar.WAR_HUD_RESULT_Y), _result,
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceWar.WAR_HUD_RESULT_FONT_SIZE,
		BalanceUI.COLOR_MENU_TITLE)
	draw_string(font, Vector2(0.0, size.y * BalanceWar.WAR_HUD_RESULT_LINE_Y), _result_line,
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceWar.WAR_HUD_RESULT_LINE_FONT_SIZE,
		BalanceUI.COLOR_MENU_SUB)
	draw_string(font, Vector2(0.0, size.y * BalanceWar.WAR_HUD_RESULT_HINT_Y), _result_hint,
		HORIZONTAL_ALIGNMENT_CENTER, w, BalanceWar.WAR_HUD_RESULT_HINT_FONT_SIZE,
		BalanceUI.COLOR_TEXT_DIM)
