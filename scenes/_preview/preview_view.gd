extends Node2D
## Preview fixture: a DEVELOPER TOOL, not part of the game.
##
## It previews ONE view scene at a time: point `View Scene` at a part, press F6, and the
## part appears on the 128 px guide with every animation it contains listed in the corner.
## Clicking a name (or pressing 1..9) plays it; SPACE pauses.
##
## Why a fixture and not a test scene: the animation list is read FROM THE PART
## (AnimationPlayer.get_animation_list()), so a new animation shows up the moment it is
## saved. Nothing here has to be kept in sync by hand - that is the whole point.
##
## Boundaries this file exists to protect:
##   * the fixture may carry logic, a camera and UI; the part it previews may carry NONE
##     of those (a Camera2D inside a part would hijack the whole battle view)
##   * it lives in scenes/_preview/, so no part and no game code ever references it
##
## [P28] Part contract it relies on: root origin = feet centre, art on a 128 px canvas,
## no script on the root, and one AnimationPlayer somewhere inside.

@export var view_scene: PackedScene

const MARGIN := 12.0
const PANEL_WIDTH := 200.0
const COL_BG := Color(0.06, 0.08, 0.11, 0.90)
const COL_TEXT := Color(0.90, 0.93, 0.96)
const COL_DIM := Color(0.55, 0.60, 0.66)
const COL_ACCENT := Color(0.35, 0.85, 1.0)
const COL_PLAYING := Color(1.0, 0.75, 0.35)

var _view: Node2D = null
var _player: AnimationPlayer = null
var _animations: Array = []
var _list: VBoxContainer = null
var _status: Label = null
var _buttons: Dictionary = {}          # animation name -> Button, so the playing one glows
var _paused: bool = false              # our own flag: AnimationPlayer has no `paused`


func _ready() -> void:
	_instantiate_view()
	_build_ui()
	_fill_animation_list()
	_autoplay_something()


# ---------------------------------------------------------------- the part
func _instantiate_view() -> void:
	if view_scene == null:
		push_warning("[Preview] no View Scene set (Inspector) -> nothing to preview")
		return
	_view = view_scene.instantiate() as Node2D
	if _view == null:
		push_warning("[Preview] the view scene has no Node2D root: "
			+ str(view_scene.resource_path))
		return
	## Appended LAST, i.e. after the guide and the camera: tree order is paint order, so
	## the part lands ON TOP of the guide without a single z_index.
	add_child(_view)
	_player = _find_player(_view)
	if _player == null:
		push_warning("[Preview] no AnimationPlayer inside " + str(view_scene.resource_path)
			+ " -> the animation list will be empty")


func _find_player(p_node: Node) -> AnimationPlayer:
	## SEARCHED, not hardcoded: where a part keeps its AnimationPlayer is its own business.
	var found := p_node.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	if found.size() > 1:
		push_warning("[Preview] %d AnimationPlayers found, using the first one" % found.size())
	return found[0] as AnimationPlayer


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	## A CanvasLayer, so the camera's zoom does not scale the buttons (and so the panel
	## stays put when the camera moves). Same reason the game keeps its HUD on layer 10.
	var layer := CanvasLayer.new()
	layer.name = "UiLayer"
	layer.layer = 10
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(MARGIN, MARGIN)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box := StyleBoxFlat.new()
	box.bg_color = COL_BG
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", box)
	layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var title := Label.new()
	title.text = "ANIMATIONS"
	title.add_theme_color_override("font_color", COL_ACCENT)
	col.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	col.add_child(_list)

	_status = Label.new()
	_status.add_theme_color_override("font_color", COL_DIM)
	col.add_child(_status)


func _fill_animation_list() -> void:
	if _player == null:
		_status.text = "no AnimationPlayer in the part"
		return
	for entry in _player.get_animation_list():
		var anim_name := str(entry)
		_animations.append(anim_name)
		var btn := Button.new()
		btn.text = anim_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_play_animation.bind(anim_name))
		_list.add_child(btn)
		_buttons[anim_name] = btn
	if _animations.is_empty():
		_status.text = "no animation saved in the part yet"
	else:
		_status.text = "%d animation(s) - click one, or press 1..9" % _animations.size()


func _autoplay_something() -> void:
	## Something must move the moment F6 lands, otherwise a part with autoplay OFF looks
	## broken. The first animation that is not the editor's own RESET is the best guess.
	if _player == null:
		return
	if _player.autoplay != "":
		_mark_playing(_player.autoplay)
		return
	for anim_name in _animations:
		if anim_name != "RESET":
			_play_animation(anim_name)
			return


# ---------------------------------------------------------------- playing
func _play_animation(anim_name: String) -> void:
	if _player == null or not _player.has_animation(anim_name):
		return
	## stop() first: play() on the animation that is ALREADY playing continues it instead
	## of restarting, and "click again to watch it once more" is the gesture you want here.
	_player.stop()
	_paused = false
	_player.speed_scale = 1.0
	_player.play(anim_name)
	_mark_playing(anim_name)


func _mark_playing(anim_name: String) -> void:
	for key in _buttons.keys():
		var btn := _buttons[key] as Button
		var playing: bool = str(key) == anim_name
		btn.add_theme_color_override("font_color", COL_PLAYING if playing else COL_TEXT)
	_status.text = "playing: " + anim_name


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or _player == null:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		_paused = not _paused
		_player.speed_scale = 0.0 if  _paused else 1.0
		_status.text = ("paused: " if _paused else "playing: ") + _player.current_animation
		get_viewport().set_input_as_handled()
		return
	var index := int(key.keycode) - int(KEY_1)
	if index >= 0 and index < _animations.size():
		_play_animation(str(_animations[index]))
		get_viewport().set_input_as_handled()
