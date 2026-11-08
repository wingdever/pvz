class_name CursorGhost
extends Control
## [P107] THE ITEM IN HAND: the picture that follows the cursor.
## Last child of the page on purpose: a Control paints above its earlier siblings, and this has
## to sit above every pot, label and button.
##
## It moved out of garden_view.gd's inner classes when the page became a scene.


## [P24] The picture of the item the player just picked up: it follows the mouse
## until the item is used on a plant or dropped again.
##
## It is a child of the page (added LAST, so it paints above the pots, the panel
## and the buttons) in a layer of its own, because a Control's own _draw() runs
## UNDER its children - drawing the ghost on the page itself would put it behind
## every pot. It ignores the mouse, so it never eats the click it is aiming with.

var _texture: Texture2D = null
var _mark_texture: Texture2D = null
## [P92] which item kind is in hand: the composite needs it to pick the mark geometry
## (a potion's cork, a scroll's page).
var _kind: String = ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func hold(p_icon: String, p_mark: String, p_kind: String = "") -> void:
	_texture = UnitArt.load_texture(p_icon)
	_mark_texture = UnitArt.load_texture(p_mark)
	_kind = p_kind
	visible = true
	set_process(true)
	queue_redraw()


func drop() -> void:
	_texture = null
	_mark_texture = null
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	## Cheap: the picture only moves, so one repaint per frame is all it needs.
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var side: float = BalanceUI.GARDEN_GHOST_SIZE
	var at: Vector2 = get_local_mouse_position() - Vector2(side, side) * 0.5
	UnitArt.draw_item_icon(self, Rect2(at, Vector2(side, side)), _texture, _mark_texture,
		_kind, Color(1.0, 1.0, 1.0, BalanceUI.GARDEN_GHOST_ALPHA))

