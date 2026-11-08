extends RefCounted
## [P89] THE SUN LYING ON THE LAWN - where a round's income waits to be picked up.
##
## WHY A MODULE OF ITS OWN: the rule "搬代码、留状态" (docs/ARCHITECTURE.md §1.4) - the STATE
## (the list of drops, the pool, the two counters) stays on Game, and the behaviour moved out
## here. It had to: the [Arch] ratchet caught game_manager.gd at 4012 lines the moment this
## feature landed, and the ceiling is 4000 (O3 is frozen until Q1 is answered, so the answer
## is to move code, not to raise a number).
##
## WHAT IT OWNS: making a sun land (the 落地 and 天际 styles live in sun_drop.gd, the choice
## between them is here), picking one up, ageing the ones that landed, banking the oldest when
## the lawn is full, and clearing the lawn when the battle ends.
##
## WHAT IT DOES NOT OWN: the two settings (SettingsStore), the amount (the producer decides
## it), and the pool cap (BalanceBattle.SUN_MAX, applied at the one collection point).
##
## BY PATH, no class_name: the reason Spawn / Rewards / StatusDB give.

const SunDrop := preload("res://scripts/core/battle/sun_drop.gd")
## the source tags: the books' own names for who paid a sun out.
const Spawn := preload("res://scripts/core/spawn.gd")
## the sound layer, by PATH for the reason sfx.gd itself gives (a const lives in one scope).
const SFX := preload("res://scripts/core/sfx.gd")


static func spawn(board, p_amount: int, p_source: String, p_style: String,
		p_at: Vector2, p_to: Vector2 = Vector2.INF) -> Node2D:
	## ONE SUN LANDS. The style says how it arrives: 落地 hops out of the plant that paid it,
	## 天际 drifts down from above the lawn at a random cell. Either way it is a world node
	## under the grid, so it shares the lawn's coordinates and never enters a cell registry -
	## a sun is not a unit, cannot be bitten and cannot be planted over.
	if board.grid == null:
		return null
	var from: Vector2 = p_at
	var to: Vector2 = p_at if p_to == Vector2.INF else p_to
	if p_style == SunDrop.STYLE_SKY:
		var cell := Vector2i(randi() % Balance.COLS, randi() % Balance.ROWS)
		to = board.grid.cell_center(cell.x, cell.y)
		from = Vector2(to.x, -BalanceUI.SUN_DROP_SKY_MARGIN)
	else:
		## Nudged a little, so two suns from the same plant do not sit exactly on top of each
		## other and answer one click twice.
		to += Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
	var drop: Node2D = SunDrop.new()
	drop.setup(p_amount, p_source, p_style, from, to, board.round_no)
	board.grid.add_child(drop)
	board._sun_drops.append(drop)
	## The cap: a lawn filling up with uncollected sun would hide the board and put the newest
	## one out of reach. The OLDEST is banked rather than discarded, so nothing a producer paid
	## out is ever lost.
	while board._sun_drops.size() > BalanceBattle.SUN_DROP_MAX:
		collect(board, board._sun_drops[0], "auto")
	print("[Sun] %s +%d (%s) landed on the lawn, %d lying there"
		% [p_style, p_amount, p_source, board._sun_drops.size()])
	return drop


static func collect_at(board, p_at: Vector2) -> bool:
	## THE CLICK: the sun under this point is gathered. Newest first, because a later sun lands
	## on top of an older one and the player is pointing at what they can see.
	for i in range(board._sun_drops.size() - 1, -1, -1):
		var drop: Node2D = board._sun_drops[i]
		if is_instance_valid(drop) and drop.contains_point(p_at):
			collect(board, drop, "manual")
			return true
	return false


static func tick(board) -> void:
	## One round boundary: every LANDED sun grows a round older, and the ones the player asked
	## to be gathered automatically are gathered. A sun still falling does not count yet -
	## "落地几回合后自动拾取" starts when it lands. Called from Game._begin_round, i.e. from the
	## same path the round itself advances on, so a fast-forwarded round (F) ages suns exactly
	## like a watched one.
	var auto_on: bool = SettingsStore.auto_collect_sun
	var patience: int = maxi(1, SettingsStore.sun_auto_rounds)
	for drop in board._sun_drops.duplicate():
		if not is_instance_valid(drop):
			continue
		if not drop.landed:
			continue
		drop.age_rounds = int(drop.age_rounds) + 1
		if auto_on and int(drop.age_rounds) >= patience:
			collect(board, drop, "auto")


static func collect(board, p_drop: Node2D, p_how: String) -> void:
	## The ONE place a sun reaches the pool: counter, stat, popup and sound. The pool cap can
	## swallow part of it (BalanceBattle.SUN_MAX), and the log says what really landed rather than
	## what was picked up - the "measure, do not trust" rule the item factory also follows.
	if p_drop == null or not is_instance_valid(p_drop):
		return
	var amount: int = int(p_drop.amount)
	var source: String = str(p_drop.source)
	var at: Vector2 = p_drop.position
	board._sun_drops.erase(p_drop)
	var before = board.sun
	board.sun = mini(board.sun + amount, BalanceBattle.SUN_MAX)
	var landed: int = board.sun - before
	if p_how == "manual":
		board.sun_collected_manual += landed
	else:
		board.sun_collected_auto += landed
	if source == Spawn.SOURCE_NATURAL:
		board.sun_from_natural += landed
	elif source == Spawn.SOURCE_PLAYER:
		## A sun the player asked for (the G-key debug amount goes through here one day) is
		## not a plant's income; the summary keeps the three columns it always had.
		board.sun_from_debug += landed
	else:
		board.sun_from_sunflower += landed
	SFX.play("sun")
	Fx.spawn_popup(at + Vector2(0.0, -26.0), "+%d" % landed, BalanceUI.COLOR_SUN_DROP)
	Fx.spawn_spark(at, BalanceUI.COLOR_SUN_DROP)
	board._log("SUN", "%s +%d sun (%s, %s) -> %d%s"
		% ["gathered" if p_how == "manual" else "collected", landed, source, p_how, board.sun,
		   (" (pool full, %d lost)" % (amount - landed)) if landed < amount else ""])
	p_drop.queue_free()


static func clear(board) -> void:
	## Leaving the battle (menu / retreat / restart / teardown) takes the lawn with it: an
	## uncollected sun is NOT banked, exactly like the original - what the player did not pick
	## up is what they did not get.
	for drop in board._sun_drops:
		if is_instance_valid(drop):
			drop.queue_free()
	board._sun_drops.clear()
