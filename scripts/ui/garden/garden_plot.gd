class_name GardenPlot
extends Control
## [P107] ONE POT ON THE GARDEN PAGE - its plant, its wounds, its click targets.
## It moved out of garden_view.gd's inner classes when the page became a scene
## (scripts/ui/garden/garden_view.gd + scenes/ui/garden.tscn): a node the scene declares has to be
## a file, and this is the node the page is made of.
##
## The rules shown here live in Garden / Balance: this class knows only what it was told
## (the slot, the hp, the tier) and reports a click. It owns its own drawing.


## A single pot in the flower bed: draws itself and reports a click. Every piece
## of game state stays in Garden, this class only knows what it was told.
signal picked(slot: int)
## [P24] right click while an item is in hand: put the item down. Not called
## "dropped": see the naming rule in this file's header.
signal drop_requested

var slot: int = -1
var plant_type: String = ""
var plant_name: String = ""
var hp: int = 0
var max_hp: int = 1
var downed: bool = false
var filled: bool = false
var selected: bool = false
## [P24] the pot the cursor is over while an item is in hand - the click target.
## NOT "target": a script may not redefine a native member (header note, P24).
var is_target: bool = false
## [P14] seconds until a DOWNED plant stands up on its own (0 when standing)
var recover_left: float = 0.0
var level: int = 1
var rarity: String = "common"

var _texture: Texture2D = null
## [P38] The last tick this pot was painted for: the countdown rounded to the whole
## second it is SHOWN as, and the language the state word came from (see setup()).
var _recover_secs: int = 0
var _lang: String = ""
## [P25] the pot art: one file shared by all 16 plots, so it is loaded once in
## _init() rather than on every refresh. A missing import (the editor has not
## scanned the SVG yet) simply leaves the pot out - the plant and the text still
## land in the right places, never a crash (HANDOFF 7.20).
var _pot_texture: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	## [P25] loaded once per plot (not once per refresh): the pot is the same file
	## for all 16 of them, and the page refreshes twice a second
	_pot_texture = UnitArt.load_texture(BalanceUI.ART_GARDEN_POT)


func setup(p_slot: int, p_type: String, p_name: String, p_hp: int, p_max_hp: int,
		p_downed: bool, p_filled: bool, p_recover_left: float = 0.0, p_level: int = 1,
		p_rarity: String = "common") -> void:
	## [P38] OPTIMIZATIONS B5: the page calls this for all 16 pots twice a second, so
	## it has to cost nothing when this pot looks exactly like it did last tick. The
	## comparison covers what _draw() and the tooltip actually paint, with the
	## countdown taken at the ONE-SECOND granularity it is shown with (see
	## _secs_left) - otherwise a DOWNED pot would rebuild its picture on every
	## other tick for nothing. The language belongs here too: the state word and the
	## tooltip are translated.
	## `selected` and `is_target` are deliberately NOT part of this: whoever changes
	## them already calls queue_redraw() itself (_on_plot_picked, _tick_armed).
	var max_hp_new := maxi(1, p_max_hp)
	var level_new := maxi(1, p_level)
	var secs := _secs_left(p_recover_left)
	if filled == p_filled and plant_type == p_type and plant_name == p_name and hp == p_hp \
			and max_hp == max_hp_new and downed == p_downed and level == level_new \
			and rarity == p_rarity and _recover_secs == secs and _lang == Loc.language:
		return
	slot = p_slot
	plant_type = p_type
	plant_name = p_name
	hp = p_hp
	max_hp = max_hp_new
	downed = p_downed
	filled = p_filled
	recover_left = p_recover_left
	level = level_new
	rarity = p_rarity
	_recover_secs = secs
	_lang = Loc.language
	_texture = null
	if p_filled:
		# the very same sprite the board draws, so a plot is recognisable
		_texture = UnitArt.load_texture(Balance.plant_art(p_type))
	tooltip_text = _tooltip_line()
	queue_redraw()


func _state_text() -> String:
	if not filled:
		return "-"
	if downed:
		# [P14] show how long the free recovery still needs
		return Loc.t("garden.state.downed") + " " + _mmss(recover_left)
	if hp < max_hp:
		return Loc.t("garden.state.wounded")
	return Loc.t("garden.state.healthy")


static func _secs_left(p_seconds: float) -> int:
	## [P53] The rounding rule of the free-recovery countdown, in ONE place: the label
	## and the tick-skip comparison in set_visual() have to agree on it, otherwise the
	## pot redraws itself twice a second for a digit that never changed. Ceil, so a
	## partly-elapsed second reads 0:01 and a pot is never "0:00" while downed.
	## (Named `_secs_left`, not `_recover_secs`: this class already stores a member of
	## that name - HANDOFF §7.53 says a script cannot collide with what it already has.)
	return int(ceil(maxf(0.0, p_seconds)))


static func _mmss(p_seconds: float) -> String:
	## [P53] The one mm:ss spelling of a countdown: this used to be written twice, once
	## here and once as a GardenView static the page below still calls. It lives on the
	## plot class so the page never has to name its own class to reach it.
	var secs := _secs_left(p_seconds)
	## [P109] floori on a float division, not `secs / 60`: two ints divided are integers
	## all the way down, which is the right ANSWER here but is exactly what the editor's
	## INTEGER_DIVISION warning points at (it cannot tell "I meant to truncate" from "I
	## lost a fraction by accident"). Writing the truncation as floori() says the intent.
	return "%d:%02d" % [floori(secs / 60.0), secs % 60]


func _state_color() -> Color:
	if downed:
		return BalanceUI.COLOR_GARDEN_DOWNED
	if hp < max_hp:
		return BalanceUI.COLOR_GARDEN_WOUNDED
	return BalanceUI.COLOR_GARDEN_OK


func _tooltip_line() -> String:
	if not filled:
		return Loc.tf("garden.plot.empty_tooltip", [slot + 1])
	return Loc.tf("garden.plot.tooltip", [plant_name, slot + 1, level,
		Balance.rarity_label(rarity), hp, max_hp, _state_text()])


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(slot)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		## [P24] a plot stops the mouse, so the page never sees this click:
		## the plot forwards it, or an item in hand could not be dropped here.
		drop_requested.emit()
		accept_event()


func _draw_right(font: Font, right_x: float, y: float, text: String, font_size: int,
		color: Color) -> void:
	## draw_string() only honours `alignment` with a positive width, so right
	## aligned text is measured and drawn left (same trick as hud.gd).
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(right_x - tw, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# ------------------------------------------------------------ pot + plant (P25)
func _pot_rect() -> Rect2:
	## The pot, placed by its INK (BalanceUI.GARDEN_POT_CONTENT), not by its canvas:
	## the ink is drawn GARDEN_POT_W_RATIO of the cell wide, centred, with its base
	## GARDEN_POT_BOTTOM_PAD above the bottom edge of the cell. Redrawing the SVG
	## with different margins therefore cannot move the pot.
	var content: Rect2 = BalanceUI.GARDEN_POT_CONTENT
	var wide: float = size.x * BalanceUI.GARDEN_POT_W_RATIO
	var tall: float = wide * content.size.y / content.size.x
	return Rect2(Vector2((size.x - wide) * 0.5,
		size.y - BalanceUI.GARDEN_POT_BOTTOM_PAD - tall), Vector2(wide, tall))


func _plant_ink_rect(p_pot: Rect2) -> Rect2:
	## [P25] THE pot -> plant relationship, in one place. Everything about where a
	## plant stands is derived here:
	##   * it is centred horizontally on the POT (not on the cell), so a pot that is
	##     ever moved sideways takes its plant with it;
	##   * it is sized by its INK height (BalanceUI.PLANT_ART_INK), not by its canvas,
	##     so the three sprites stand the same size even though the wall-nut fills
	##     its canvas while the peashooter keeps 12% of it empty under the stem;
	##   * its ink BOTTOM (the feet) ends GARDEN_PLANT_SINK of that height BELOW the
	##     pot's soil surface - that overlap is what reads as "planted in the pot".
	## The returned rect is where the INK goes: the caller draws the ink box of the
	## texture into it with draw_texture_rect_region().
	var ink := BalanceUI.plant_art_ink(plant_type, _texture)
	var tall: float = size.y * BalanceUI.GARDEN_PLANT_INK_H_RATIO
	var wide: float = tall * ink.size.x / ink.size.y
	var soil: float = p_pot.position.y + p_pot.size.y * BalanceUI.GARDEN_POT_SOIL_RATIO
	var feet: float = soil + tall * BalanceUI.GARDEN_PLANT_SINK
	return Rect2(Vector2((size.x - wide) * 0.5, feet - tall), Vector2(wide, tall))


func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), BalanceUI.COLOR_GARDEN_EMPTY)

	# the pot first, then the plant standing in it
	var pot := _pot_rect()
	if _pot_texture != null:
		draw_texture_rect(_pot_texture, pot, false, Color.WHITE)
	if filled and _texture != null:
		## the sprite is drawn by its INK box: see _plant_ink_rect()
		var ink := BalanceUI.plant_art_ink(plant_type, _texture)
		var tint: Color = BalanceUI.COLOR_GARDEN_DOWNED_TINT if downed else Color.WHITE
		draw_texture_rect_region(_texture, _plant_ink_rect(pot), ink, tint)

	# --- health ribbon: the state of the plant at a glance, along the top edge ---
	var ribbon := Rect2(Vector2.ZERO, Vector2(w, BalanceUI.GARDEN_HP_RIBBON_H))
	draw_rect(ribbon, BalanceUI.COLOR_HP_BG)
	if filled:
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		if ratio > 0.0:
			draw_rect(Rect2(ribbon.position, Vector2(w * ratio, ribbon.size.y)),
				BalanceUI.COLOR_HP_FILL)

	# --- the two text rows ---------------------------------------------------
	var inset := w * BalanceUI.GARDEN_INSET_RATIO
	var slot_y := h * BalanceUI.GARDEN_SLOT_Y_RATIO
	draw_string(font, Vector2(inset, slot_y), Loc.tf("garden.plot.slot", [slot + 1]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, BalanceUI.FONT_SIZE_GARDEN_STATE, BalanceUI.COLOR_TEXT_DIM)
	if filled:
		_draw_right(font, w - inset, slot_y, _state_text(),
			BalanceUI.FONT_SIZE_GARDEN_STATE, _state_color())
		## [P105] The plant's NAME is painted in its RARITY's colour - the first place in
		## the game where a tier is visible as a colour rather than as a word: Balance.
		## rarity_color reads data/rarity.csv (white / green / blue / purple / gold / red for
		## common..mythic) and answers a neutral grey for a tier the sheet cannot name, so an
		## unreadable sheet costs a shade and never a missing line. The plot is dark
		## (COLOR_GARDEN_EMPTY), which is what makes all six read.
		draw_string(font, Vector2(0.0, h * BalanceUI.GARDEN_NAME_Y_RATIO), plant_name.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, w, BalanceUI.FONT_SIZE_CARD + 1, Balance.rarity_color(rarity))
	else:
		draw_string(font, Vector2(0.0, h * BalanceUI.GARDEN_NAME_Y_RATIO),
			Loc.t("garden.plot.empty"), HORIZONTAL_ALIGNMENT_CENTER, w,
			BalanceUI.FONT_SIZE_GARDEN_LINE, BalanceUI.COLOR_TEXT_DIM)

	# --- frames last, so nothing is ever drawn over them ---------------------
	var frame := BalanceUI.COLOR_GARDEN_SELECTED if selected else BalanceUI.COLOR_GARDEN_EMPTY_LINE
	draw_rect(Rect2(Vector2.ZERO, size), frame, false, 3.0 if selected else 2.0)
	if is_target:
		## [P24] where the item in hand would land: drawn last so it is never
		## hidden behind the selection frame of another pot.
		draw_rect(Rect2(Vector2.ZERO, size), BalanceUI.COLOR_GARDEN_SELECTED, false,
			BalanceUI.GARDEN_TARGET_FRAME_W)


## ---------------------------------------------------------------- one tool cell
