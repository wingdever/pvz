extends Node2D
## [P89] ONE SUN ON THE BOARD - what a producer pays out and what the sky drops. It is NOT a
## Unit: it takes no cell, cannot be bitten and never blocks planting (the original lets you
## plant on top of a sun, and so does this).
##
## TWO STYLES (user design, 2026-09-25):
##   落地 - a plant pays where it stands: the sun appears above it and hops to a spot beside
##          it, over in a fraction of a second;
##   天际 - the sky pays: it enters above the top of the lawn at a random column and drifts
##          down slowly, which is what makes a round's income visible instead of silent.
##
## WHAT IT DOES NOT OWN: the amount (the producer decides it), the pool and the two settings
## (Game), and the words (Loc). This file draws itself, falls, and answers "did that click
## land on me" - nothing else.
##
## BY PATH, no class_name: the reason Spawn / StatusDB / ProjectileDB give (a brand-new global
## class is invisible to `godot --headless` until the editor rescans).

## [P109] Balance and UnitArt are global classes (their files carry `class_name`), so a
## `const X := preload(...)` alias only shadowed the global name (SHADOWED_GLOBAL_IDENTIFIER).

const STYLE_TOSS := "落地"      # from somewhere on the lawn: a short hop, then it sits
const STYLE_SKY := "天际"       # from above the lawn: a slow fall, so it can be seen coming

var amount := 0                 # the sun points this one is worth
var source := ""                # Spawn.SOURCE_*: who produced it (a log/stat label)
var style := STYLE_TOSS
var born_round := 0             # the round it appeared in (the auto-collect clock)
var landed := false             # true once it has come to rest on the lawn
var age_rounds := 0             # whole rounds since it LANDED

var _to := Vector2.ZERO         # where it comes to rest
var _from := Vector2.ZERO       # where it entered the world
var _t := 0.0                   # 0..1 of the hop (the 天际 style moves at a constant speed)
var _texture: Texture2D = null


func setup(p_amount: int, p_source: String, p_style: String, p_from: Vector2,
		p_to: Vector2, p_round: int) -> void:
	amount = maxi(1, p_amount)
	source = p_source
	style = p_style
	_from = p_from
	_to = p_to
	position = p_from
	born_round = p_round
	_texture = UnitArt.load_texture(Balance.sun_drop_art())
	queue_redraw()


func _process(delta: float) -> void:
	if landed:
		return
	if style == STYLE_SKY:
		## The fall is speed based, not duration based: a sun that entered high and one that
		## entered low reach the lawn at the same speed, which is what makes the drift read as
		## gravity rather than as a scripted tween.
		position.y = minf(position.y + BalanceUI.SUN_DROP_FALL_SPEED * delta, _to.y)
		position.x = lerpf(_from.x, _to.x, _fall_ratio())
		if is_equal_approx(position.y, _to.y):
			_finish_fall()
		return
	## 落地: the producer's own sun hops out of the plant and settles beside it.
	_t = minf(_t + delta / BalanceUI.SUN_DROP_TOSS_TIME, 1.0)
	var lift := sin(_t * PI) * BalanceUI.SUN_DROP_TOSS_LIFT
	position = _from.lerp(_to, _t) + Vector2(0.0, -lift)
	if _t >= 1.0:
		_finish_fall()


func _fall_ratio() -> float:
	var span := _from.y - _to.y
	if absf(span) < 1.0:
		return 1.0
	return clampf((_from.y - position.y) / span, 0.0, 1.0)


func _finish_fall() -> void:
	landed = true
	position = _to
	queue_redraw()


func contains_point(p_at: Vector2) -> bool:
	## The click test, and the ONLY one: a radius around the sun's own centre. Deliberately
	## not an Area2D - the project has none (every other world click goes through the grid),
	## and a hand test can be run in a headless probe.
	return position.distance_to(p_at) <= BalanceUI.SUN_DROP_RADIUS * BalanceUI.SUN_DROP_CLICK_SLACK


func _draw() -> void:
	## The item art when it is there (assets/svg/items/sun.svg), a flat disc when the sheet's
	## icon has not been imported yet - the same three-level fall-back every unit obeys.
	if _texture != null:
		draw_texture_rect(_texture, Rect2(-BalanceUI.SUN_DROP_ART_SIZE * 0.5,
			BalanceUI.SUN_DROP_ART_SIZE), false)
		return
	draw_circle(Vector2.ZERO, BalanceUI.SUN_DROP_RADIUS, BalanceUI.COLOR_SUN_DROP)
	draw_circle(Vector2.ZERO, BalanceUI.SUN_DROP_RADIUS * 0.55, BalanceUI.COLOR_SUN_DROP_CORE)
