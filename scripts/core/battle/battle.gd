extends Node2D
class_name Battle
## [P106] THE BATTLE - one battle: its world, its HUD, its round machine, its state.
##
## This is the root script of `scenes/tscn` (the scene tree below IS the ownership
## diagram - docs/OPEN_ITEMS.md Q1 / docs/ARCHITECTURE.md §3.4):
##
##   Battle                (this, Node2D)   one battle's lifetime
##   ├─ LawnGrid           (Node2D)         the world: units / projectiles / sun / fx hang here
##   └─ HudLayer (10) ─ Hud (Control)       what a battle shows
##
## THE CONTRACT - four node names, read by the log, the checks and --preview:
##   Battle / LawnGrid / HudLayer / Hud.
##
## THE BOUNDARY. This file never names GameManager - not once, not in code. A preload cycle
## would be a parse error, but the rule is wider than that: the board knows the world and its
## own rules, and nothing else. It does NOT know the saves, the campaign or the pages. Everything
## that crosses the line crosses it through one of these:
##
##   DOWN (Game calls Battle)          UP (Battle tells Game)
##     begin(setup)                      settled(result)      the battle is decided
##     end_turn(staged)                  unit_died(unit)      roll this death's loot (Game does)
##     cancel()                          left(reason)          retreat / window close
##     set_visible(on)                   settings_requested() the SETTINGS overlay (hide, not free)
##     on_layout_changed()               ledger_changed()      an in-battle write needs saving
##     show_result(lines)                                      (Game owns every save; the battle
##     set_unsaved_note(text)                                   mutates the domain objects and says so)
##     spawn_pickup(...)                 (Game asks for a drop to land on the lawn)
##     retreat()
##
## WHAT THE BATTLE MAY TOUCH: the static modules (Balance / BalanceUI / BalanceAudio / Layout /
## Difficulty / Loc / Sfx / Music / Fx / Spawn / the sheets), the domain objects (Unit / Zombie /
## Projectile / Grid / SunField / LevelData) and Garden + Profile READ-ONLY-for-rules (the summon
## pool and the backpack the player is carrying). It may mutate Profile's in-battle ledgers (a
## spent scroll, a taken bean, a landed drop) - that is the battle's own book-keeping - and it
## reports every such write with ledger_changed so Game keeps the P65 rule (every change reaches
## the disk). What it may NOT do is call save_*(), settle anything, grant rewards, change screens,
## or hold a reference to Game.
##
## LIFETIME - three states, and only the third is subtle:
##   1. no battle         -> this node does not exist
##   2. in a battle       -> in the shell scene, visible
##   3. SETTINGS over it  -> still in the shell, HIDDEN but NOT freed (ARCHITECTURE.md §3.3)
## Leaving / settling / R all FREE it, and R is "free, then build a new one" - never a reuse:
## the garden rollback rule depends on this battle's ledger never having landed.
##
## WHY `class_name Battle`: the boundary has to be compile-checked. `Spawn.create_unit(board, ...)`,
## `hud.board` and `unit.board` are all typed against this class, and a new global name costs one
## `godot --headless --path . --import --quit-after 5` (AGENTS.md §1.4, ARCHITECTURE.md §1.3).

## THE MODULES WITHOUT A `class_name` (ARCHITECTURE.md §1.3). A preload constant is scoped to ONE
## file (PITFALLS 68) and `[Arch]`'s fifth rule fails any script that uses one without declaring
## it - Game's own header carries the same list for the same readers.

## [P109] The old public `var profile: Profile` that sat here was a SECOND handle on the
## same Profile the board already carries (`_profile`, assigned in `begin`). Nobody ever
## assigned it - the readers now go through `_profile` and the one door `has_scroll_for`,
## which is what the HUD knocked on with its own never-set field.

const ZOMBIE_SCRIPT := preload("res://scripts/units/zombie.gd")
const PEASHOOTER_SCRIPT := preload("res://scripts/units/peashooter.gd")
const SFX := preload("res://scripts/core/sfx.gd")
const Spawn := preload("res://scripts/core/spawn.gd")
const StatusDB := preload("res://scripts/core/db/status_db.gd")
const SunField := preload("res://scripts/core/battle/sun_field.gd")


signal settled(result: Dictionary)
signal unit_died(unit: Unit)
signal left(reason: String)
signal settings_requested()
signal ledger_changed()

enum Phase { BOOT, TURN_START, OPERATION, PLANT_ACTION, ZOMBIE_ACTION, TURN_END, WIN, LOSE }

const PHASE_NAME := {
	Phase.BOOT: "BOOT",
	Phase.TURN_START: "START",
	Phase.OPERATION: "OP",
	Phase.PLANT_ACTION: "PLANT",
	Phase.ZOMBIE_ACTION: "ZOMBIE",
	Phase.TURN_END: "END",
	Phase.WIN: "WIN",
	Phase.LOSE: "LOSE",
}

@onready var grid: Node2D = $LawnGrid
@onready var hud: Control = $HudLayer/Hud

# ---------------------------------------------------------------- one battle's inputs
var level: LevelData = null
var level_path: String = ""
var _garden: Garden = null              # READ-ONLY for rules: the summon pool
var _profile: Profile = null            # the carried backpack; in-battle ledgers only
var _deck: Array[String] = []
## [P31-A] A campaign battle summons only its SQUAD. Game hands the slot list over; the board
## never sees RunState (that is the boundary).
var _squad: Array[int] = []
var _run_battle: bool = false
var difficulty_key: String = ""
var difficulty_zombie_hp_mult: float = 1.0
var level_start_sun: int = 0
var level_sun_per_turn: int = 0
var level_sunflower_sun: int = 0

# ---------------------------------------------------------------- the board
var units: Array[Unit] = []
var phase: int = Phase.BOOT
var round_no: int = 0
var sun: int = 0
var brain_hp: int = 0
var selected_plant: String = ""
var selected_tool: String = ""
var glove_source := Vector2i(-1, -1)
var status_message: String = ""
var end_reason: String = ""
var tool_charge: Dictionary = {}
var tool_threshold: Dictionary = {}
var tools_used: Dictionary = {}
var plant_charge: Dictionary = {}
var plant_cooldown: Dictionary = {}
var summon_limit: int = 0
var summons_this_turn: int = 0
var _pending_spawns: Array = []
var _pending_deaths: Array[String] = []
var _next_uid: int = 1
var _deployed: Dictionary = {}
var _garden_ledger: Dictionary = {}
var _garden_settled: bool = true
var _spirit_summons: int = 0
var _bean_armed: bool = false
var _pack_open: bool = false
var _retreat_timer: float = 0.0
var _message_timer: float = 0.0
var sun_spent: int = 0
var rounds_run: int = 0
var zombies_killed: int = 0
var sun_collected_manual: int = 0
var sun_collected_auto: int = 0
var sun_from_natural: int = 0
var sun_from_sunflower: int = 0
var sun_from_debug: int = 0
var _sun_drops: Array = []

# ---------------------------------------------------------------- the round clock [P30-A2]
## Every resolution gets a number, and a TEARDOWN BUMPS IT - it is never reset: a coroutine
## from the old round that wakes up late sees a foreign generation and bails.
## [P106] THE NAMES ARE THE ORIGINAL ONES on purpose: a move keeps the bodies verbatim, so the
## fields they spell keep their spelling too. `resolve_gen` is P30-A2's generation counter.
var _resolve_gen: int = 0
var _resolving: bool = false
var resolution_staged: bool = false
var _pending_animations: int = 0

# ---------------------------------------------------------------- what the HUD shows back
var result_lines: Array[String] = []
var result_action: String = ""           # the result panel's button label ("" = default)
var result_action_id: String = "restart" # what that button reports through `left`
var unsaved_note: String = ""


func _enter_tree() -> void:
	## MUST be _enter_tree, not _ready: a child's _ready() runs BEFORE its parent's, so the Hud
	## would build its fifteen buttons against a null back-reference. Here every node of the
	## instantiated scene exists and none of them is ready yet.
	## [P106] @onready is NOT assigned yet here - that happens just before this node's _ready,
	## which a child's _ready() precedes. So the Hud is fetched by the contract path and wired
	## NOW; if it were left to _ready the Hud would build its fifteen buttons against null.
	hud = get_node_or_null("HudLayer/Hud") as Control
	if hud != null:
		hud.board = self


func begin(p_setup: BattleSetup) -> void:
	## One battle starts here - the only door in. Everything arrives through the setup object
	## (scripts/core/battle_setup.gd), so a new input never changes this signature.
	level = p_setup.level
	level_path = p_setup.level_path
	_garden = p_setup.garden
	_profile = p_setup.profile
	_deck = p_setup.deck
	_squad = p_setup.squad
	_run_battle = p_setup.run_battle
	difficulty_zombie_hp_mult = p_setup.zombie_hp_mult
	level_start_sun = p_setup.sun_start
	level_sun_per_turn = p_setup.sun_per_turn
	level_sunflower_sun = p_setup.sunflower_sun
	result_lines.clear()
	unsaved_note = ""
	## [P76] the board installs the one layer every effect lives under, and listens to its own
	## lawn: both used to be Game._bootstrap()'s lines, and both are the board's business.
	Fx.attach(grid)
	if not grid.cell_clicked.is_connected(_on_cell_clicked):
		grid.cell_clicked.connect(_on_cell_clicked)
	_reset_state()
	grid.set_enabled_rows(level.rows)
	_setup_starting_plants()
	_update_battle_music()
	## [P14] the self-check probes used to run in the middle of this list. [P106] they are
	## Game's business now: they test the sheets and the factories, not this board.
	print("")
	_begin_round()


func cancel() -> void:
	_resolving = false
	resolution_staged = false
	_pending_animations = 0
	_resolve_gen += 1
	_clear_sun_drops()


func set_board_visible(p_on: bool) -> void:
	## The world and what a battle shows travel together - this replaces the six lines
	## ScreenFlow.set_world_visible() used to spell out (grid.visible + grid.set_process
	## + hud.visible + hud.set_process).
	grid.visible = p_on
	grid.set_process(p_on)
	hud.visible = p_on
	hud.set_process(p_on)


func on_layout_changed() -> void:
	## The window moved: both halves of the board follow Layout.
	grid.on_layout_changed()
	hud.on_layout_changed()


func show_result(p_lines: Array[String], p_action_label: String = "",
		p_action_id: String = "restart") -> void:
	## Game has settled the battle (saves, rewards, campaign) and hands the finished lines
	## back for the panel. This is the return half of `settled` - and the reason the panel can
	## print reward lines the battle itself never computed.
	result_lines = p_lines.duplicate()
	## The panel's action button belongs to the SESSION: a free level restarts, a campaign node
	## walks into the next stage. Game names it here instead of letting the HUD ask about it.
	result_action = p_action_label
	result_action_id = p_action_id
	hud.refresh_texts()


func set_unsaved_note(p_text: String) -> void:
	## [P65] The save alarm rides on EVERY status line rather than only on the one that raised
	## it. Which lines are unsaved is Game's fact (it owns the ledgers and the writes), so it
	## arrives here as text and _set_message() appends it - the battle never reads a save.
	unsaved_note = p_text


func spawn_pickup(p_points: int, p_source: String, p_style: String, p_from: Vector2) -> Node2D:
	## The one thing Game may ask the lawn for: put a sun/pickup down at a spot. Used by the
	## loot path (Game rolls the drop, the battle owns the field it lies on).
	return spawn_sun_drop(p_points, p_source, p_style, p_from)


func retreat() -> void:
	## [P13] Leave the battle on purpose. The board owns the two-click confirmation (it is a
	## battle key, and a stray click must not be able to wound the garden for good); what
	## "leaving" MEANS - settling, which page comes up - is Game's, and it hears it through
	## `left`.
	if is_finished():
		left.emit("retreat")
		return
	if _retreat_timer <= 0.0:
		_retreat_timer = BalanceBattle.RETREAT_CONFIRM_TIME
		_set_message(Loc.t("msg.retreat.confirm"))
		return
	_retreat_timer = 0.0
	print("---------- retreat (garden is written back) ----------")
	left.emit("retreat")


func request_settings() -> void:
	## [P109] The board ASKS, the flow OPENS - the same direction every other HUD button
	## takes (`retreat()`, `end_turn()`, `toggle_pack()`). The HUD used to fire this class's
	## signal itself from outside, which is why the editor reported `settings_requested` as
	## declared-but-unused: the only signal on this node whose `emit` was not in this file.
	settings_requested.emit()


func _process(delta: float) -> void:
	## Only the battle's own clocks tick here. The SETTINGS confirm timer is Game's and stays
	## there; this was one function with both halves before [P106].
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			status_message = ""
	if _retreat_timer > 0.0:
		_retreat_timer -= delta
		if _retreat_timer <= 0.0:
			_retreat_timer = 0.0


func _input(event: InputEvent) -> void:
	## [P106] THE IN-GAME KEYS LIVE HERE, and this is _input() on purpose. The old code hung
	## them on Game._unhandled_input() and relied on the autoload being ahead of the whole main
	## scene: "a click that lands on a sun is swallowed here and never reaches Grid.cell_clicked"
	## (game_manager.gd, [P89]). Battle is now the PARENT of LawnGrid, and the order two nodes
	## see an unhandled event in is not something to bet a rule on. The _input() phase is
	## guaranteed to run before every _unhandled_input() in the tree, so the sun still wins.
	if not visible:
		return        # no board on screen, or the SETTINGS overlay covers it
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if collect_sun_at(grid.get_local_mouse_position()):
				get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			end_turn()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			## [P34] the plant keys arm the DECK SLOT, not a fixed plant (see BalanceBattle.DECK_HOTKEY_KEYS).
			_select_deck_card(BalanceBattle.DECK_HOTKEY_KEYS.find(int(key.keycode)))
		KEY_8, KEY_9, KEY_0:
			## [P34] tools moved off 4/5/6 to hand those keys to the deck.
			_select_tool_slot(BalanceBattle.TOOL_HOTKEY_KEYS.find(int(key.keycode)))
		KEY_ESCAPE:
			if _pack_open:
				close_pack()
				_set_message(Loc.t("msg.pack.closed"))
			else:
				clear_selection()
				_set_message(Loc.t("msg.selection.cleared"))
		KEY_P:
			toggle_pack()
		KEY_F:
			fast_forward(BalanceBattle.FAST_FORWARD_ROUNDS)
		KEY_G:
			add_debug_sun(BalanceBattle.DEBUG_SUN_AMOUNT)
		KEY_D:
			cycle_difficulty()
		KEY_K:
			_kill_all_zombies()
		KEY_R:
			print("---------- restart (reloading %s) ----------" % level_path)
			left.emit("restart")
		_:
			return
	get_viewport().set_input_as_handled()


func _reset_state() -> void:
	## [P106] WAS the "# 3. reset state" block of Game._start_new_game - the complete list of
	## what a battle forgets when it opens. Note what is NOT here, and stays with Game: carrying
	## the backpack's consumables (a session fact, printed before begin()), the garden's recovery
	## clock (`recover_garden`), and `_return_to_battle` (the front-end overlay). The garden
	## LEDGER is only CLEARED - it lands when Game settles this battle, which is what makes R a
	## rollback.
	phase = Phase.BOOT
	round_no = 0
	sun = level_start_sun
	brain_hp = level.brain_hp
	_disarm_all()             # [P54] nothing is armed when a battle opens
	status_message = ""
	end_reason = ""
	sun_from_natural = 0
	sun_from_sunflower = 0
	sun_from_debug = 0
	sun_spent = 0
	rounds_run = 0
	zombies_killed = 0
	sun_collected_manual = 0
	sun_collected_auto = 0
	_next_uid = 1
	_message_timer = 0.0
	_pending_deaths.clear()
	_pending_spawns.clear()                  # [P26] a new battle starts with an empty queue
	_reset_tools()
	# [P12] the battle opens with a clean ledger; nothing lands in the garden until
	# this battle settles (that is what makes R a rollback)
	_garden_ledger.clear()
	_deployed.clear()
	_spirit_summons = 0                    # [P31-B] spirit names restart at #1
	_garden_settled = false
	_reset_plant_cards()
	# [P13] one summon scroll per round by default; a level file (or, later, a
	# rogue-like item) may raise it
	summon_limit = level.summons_per_turn()
	_reset_summon_scrolls()
	_retreat_timer = 0.0
	_pack_open = false


func settle_ledger() -> Dictionary:
	## Hand the garden ledger over to be LANDED, exactly once: a battle that is already settled
	## answers {} (a quit right after a win comes through here twice). The rule that standing
	## plants write back the hp they ended on belongs to the board that watched them.
	if _garden_settled:
		return {}
	_garden_settled = true
	for item in _plants_sorted():
		var u := item as Unit
		if u != null and u.is_garden_plant():
			_ledger_set(u.garden_slot, u.hp, true)
	return _garden_ledger


func garden_settled() -> bool:
	return _garden_settled


func plants() -> Array:
	return _plants_sorted()


func result() -> Dictionary:
	## What the battle HANDS OVER - plain data, no session object, no reference back. Game settles
	## from this: the ledger tells it whose plants were hurt, the counters fill the summary, and
	## `win` / `run_battle` decide what a victory is worth.
	return {
		"win": phase == Phase.WIN,
		"reason": end_reason,
		"level_path": level_path,
		"run_battle": _run_battle,
		"rounds": round_no,
		"zombies_killed": zombies_killed,
		"sun_spent": sun_spent,
		"sun_collected_manual": sun_collected_manual,
		"sun_collected_auto": sun_collected_auto,
		"sun_from_natural": sun_from_natural,
		"sun_from_sunflower": sun_from_sunflower,
		"garden_ledger": _garden_ledger.duplicate(true),
	}


func _finish(p_win: bool, p_reason: String) -> void:
	## [P106] The battle's half of the old Game._end_game(): decide the outcome, set the phase,
	## play the jingle, print the receipt - and HAND OVER. Settling the garden, granting the
	## rewards, the campaign's three stages and the page that comes up are Game's, and it hears
	## about them through `settled`; the finished lines come back through show_result().
	## This is also why the reward roll is NOT here: what a victory pays out is a session rule.
	phase = Phase.WIN if p_win else Phase.LOSE
	end_reason = p_reason
	clear_selection()
	## [P21] the battle theme gives way to the one-shot result cue. It plays once and
	## then the result screen is quiet (see Music.play_jingle).
	Music.play_jingle(BalanceAudio.MUSIC_WIN if p_win else BalanceAudio.MUSIC_LOSE)
	print("")
	print("================ RESULT: %s ================" % ("WIN" if p_win else "LOSE"))
	print("level  : %s (%s)" % [level.level_name, Difficulty.label(difficulty_key)])
	print("reason : %s" % p_reason)
	print("rounds : %d   zombies killed: %d" % [round_no, zombies_killed])
	print("===========================================")
	settled.emit(result())


func cycle_difficulty() -> void:
	## [P106] The D key changes the DIFFICULTY and restarts the level. Which difficulty is a
	## SESSION choice (Game owns forced_difficulty and the restart), so the board only reports
	## the request; it keeps its own copy of the key for the log and the HUD's label.
	left.emit("cycle_difficulty")


# ---------------------------------------------------------------- helpers the rest of the board calls
func _select_deck_card(p_index: int) -> void:
	## [P34] Arm the plant card sitting at this deck slot (hotkeys 1..6 = battle_cards()
	## order, which is the order the rail is laid out in). A press past the deck is
	## nothing to arm, so it stays silent rather than refusing in words.
	var deck: Array = battle_cards()
	if p_index < 0 or p_index >= deck.size():
		return
	select_plant(str(deck[p_index]))


func _select_tool_slot(p_index: int) -> void:
	## [P34] Arm the tool card at this rail position (hotkeys 8/9/0, TOOL_CARDS order).
	if p_index < 0 or p_index >= BalanceBattle.TOOL_CARDS.size():
		return
	select_tool(str(BalanceBattle.TOOL_CARDS[p_index]))


func fast_forward(count: int) -> void:
	if is_finished():
		_set_message(Loc.t("msg.game.finished"))
		return
	_set_message(Loc.tf("msg.game.fast_forward", [count]))
	var i := 0
	while i < count and is_operation():
		end_turn(false)
		i += 1


func add_debug_sun(amount: int) -> void:
	sun_from_debug += amount
	sun = mini(sun + amount, BalanceBattle.SUN_MAX)
	_set_message(Loc.tf("msg.debug.sun", [amount, sun]))


func sun_drops() -> Array:
	## What is lying on the lawn, oldest first - read by the probes and by the cap.
	return _sun_drops.duplicate()


func collect_sun_at(p_at: Vector2) -> bool:
	return SunField.collect_at(self, p_at)


func _reset_summon_scrolls() -> void:
	summons_this_turn = 0


# ================================================================ moved from game_manager.gd [P106]
## Everything below this line is a VERBATIM MOVE (the project's "搬代码" rule: the bodies, their
## comments and their [Pxx] markers travel unchanged). The only edits are the seam edits listed in
## the batch's report: garden/profile -> _garden/_profile, _battle_deck -> _deck, _end_game -> _finish,
## save_profile() -> ledger_changed.emit(), Rewards.roll_drop -> unit_died.emit, and the two guards
## that used Game's `screen` (a battle IS the screen now).


func is_retreat_armed() -> bool:
	return _retreat_timer > 0.0


func arm_energy_bean() -> void:
	## Called by the backpack panel's USE row: the bean is spent when it lands on a
	## plant, not when it is picked up.
	if not is_operation():
		_refuse(Loc.t("msg.bean.operation_only"))
		return
	if not _has_bean():
		_refuse(Loc.t("msg.bean.none"))
		return
	_pack_open = false
	clear_selection()         # [P54] BEFORE arming: clearing now drops the bean too
	_bean_armed = true
	_sync_grid_hint()
	_set_message(Loc.tf("msg.bean.armed", [Balance.ENERGY_BEAN_HITS]))


func _has_bean() -> bool:
	## [P106] The board holds the backpack it was handed, so "is there a bean" is a READ it can
	## answer itself. Taking one (and saving afterwards) is the session's - see ledger_changed.
	if _profile == null:
		return false
	return _profile.has_item(Balance.ITEM_ENERGY_BEAN, 1, Profile.CONTAINER_BACKPACK)


func spawn_unit(script: GDScript, col: int, row: int) -> Unit:
	## THE BODY DOOR: build a unit of this script and put it on the lawn. `spawn_zombie` is the
	## typed sibling (it decides the type BEFORE the body is on screen, [P60]); this one is what
	## the factory (and the probes) use when the script is already known.
	var u := script.new() as Unit
	u.name = "%s_%d_%d" % [u.display_name.replace("-", ""), col, row]
	_attach_unit(u, col, row)
	return u


func backpack_total() -> int:
	## The bag readout in the top bar. The board holds the profile it was handed, so this is a
	## READ: every write (and every save) stays with Game.
	if _profile == null:
		return 0
	return _profile.backpack_total()


func brain_hp_max() -> int:
	return level.brain_hp if level != null else BalanceBattle.BRAIN_MAX_HP


func level_label() -> String:
	if level == null:
		return Loc.t("msg.level.none")
	return Loc.tf("msg.level.label", [level.display_name(), Difficulty.label(difficulty_key)])


func add_pending_animation() -> void:
	_pending_animations += 1
	print("[GAME] 添加待处理动画，当前总数：", _pending_animations)


func animation_generation() -> int:
	## [P33] Which round's book-keeping a visual was billed to: `_resolve_gen`
	## bumps on every end_turn (:3582) and every teardown (:974), so a projectile
	## created under round N can tell - at `_exit_tree` - whether its pending
	## animation still belongs to the round the engine is waiting on. Late
	## arrivals from a timed-out round must NOT debit the new one.
	return _resolve_gen


# 添加一个方法来减少待处理动画计数，当计数为0时触发下一阶段


func complete_animation() -> void:
	_pending_animations -= 1
	print("[GAME] 完成一个动画，剩余：", _pending_animations)
	if _pending_animations <= 0:
		_pending_animations = 0
		print("[GAME] 所有动画完成，发出信号！")


func _wait_animations(p_timeout: float) -> void:
	## [P30-B] Wait for the airborne visuals WITHOUT a hang option: poll the
	## counter to zero (a pea that lands late is still waited for) but give up at
	## the cap and let the round resolve anyway. The old bare
	## `await all_animations_completed` had no exit for the case where a pending
	## animation's callback never fires (its node was freed mid-flight) - the
	## player would have been staring at a frozen lawn instead of a finished turn.
	var waited := 0.0
	while _pending_animations > 0 and waited < p_timeout:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	if _pending_animations > 0:
		print("[GAME] animation wait capped at %.1fs (%d stuck visual(s) dropped) - the round resolves"
			% [p_timeout, _pending_animations])
		_pending_animations = 0


func battle_music() -> String:
	## [P21] The battle theme is DATA: a level may name any track of BalanceAudio.MUSIC_DEFS
	## ("Night", "Pool", "Roof", "Boss", ...), the default is the day lawn.
	return level.battle_music() if level != null else BalanceAudio.MUSIC_BATTLE


func _update_battle_music() -> void:
	## [P21] The last wave plays the drum arrangement of the level's theme, when the
	## assets have one. Only a level with more than one wave gets it: a single wave level
	## would otherwise drum from the first turn. Idempotent, so it can be called on
	## every round (and when a battle is resumed from the SETTINGS overlay).
	var id := battle_music()
	if BalanceAudio.MUSIC_DRUMS_ON_FINAL_WAVE and level != null and level.waves.size() > 1:
		if round_no >= level.last_wave_round():
			var drums := BalanceAudio.music_drum_variant(id)
			if drums != "":
				id = drums
	Music.play(id)


func battle_cards() -> Array:
	## The plant cards the live (or next) battle plays with: the deck confirmed on
	## the seed-picking page, or the FIRST BATTLE_DECK_SLOTS of the roster when no
	## pick was made - run battles, the self-checks and any entry that never saw
	## the page all answer through this one fall-back.
	## [P34] The fall-back used to hand back the WHOLE roster, which was fine while
	## it held three cards; the roster grows past a dozen in the all-plants program
	## and the HUD would have squeezed them all into the deck band (Layout floors a
	## card at MIN_CARD_WIDTH, so 13 x 96 px is already wider than the 1280 stage).
	## Truncating to the same slot count the picking page offers keeps the deck the
	## un-picked path plays with a legal deck instead of an overflowing one.
	## (Untyped return on purpose: Balance.plant_cards() is an untyped const array.)
	if not _deck.is_empty():
		return _deck
	var out: Array = []
	for entry in Balance.plant_cards():
		if out.size() >= BalanceBattle.BATTLE_DECK_SLOTS:
			break
		out.append(entry)
	return out


func _setup_starting_plants() -> void:
	var placed := 0
	for entry in level.starting_plants:
		var pid := str(entry.get("plant", ""))
		var col := int(entry.get("col", -1))
		var row := int(entry.get("row", -1))
		if not grid.in_bounds(col, row) or not grid.is_free(col, row):
			print("[Setup] starting plant %s at (%d,%d) skipped: cell unavailable" % [pid, col, row])
			continue
		## [P87] through the factory: a plant the sheets list but no script implements is
		## refused LOUDLY here instead of quietly becoming a peashooter.
		if Spawn.create_unit(self, pid, Vector2i(col, row)) == null:
			print("[Setup] starting plant %s at (%d,%d) refused: %s"
				% [pid, col, row, Spawn.problems().back() if not Spawn.problems().is_empty() else "unknown"])
			continue
		placed += 1
	print("[Setup] %d starting plants placed (from the level file: garden_slot -1, they cost nothing and write nothing back)" % placed)


# ---------------------------------------------------------------- tools


func _reset_tools() -> void:
	tool_charge = {}
	tool_threshold = {}
	tools_used = {}
	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		tool_threshold[key] = level.tool_threshold(key)
		tool_charge[key] = 0
		tools_used[key] = 0


func _charge_list(p_roster: Array, p_thresholds: Dictionary, p_charges: Dictionary) -> void:
	## [P53] Tools and plant cards tick the same way: one step per wave, capped at that
	## id's own threshold. The loop used to be spelled out twice and the copies were
	## byte-identical apart from which dictionary they touched, so a rule change had to
	## be made in two places. Dictionaries are passed by reference, so this updates the
	## caller's state in place.
	for id in p_roster:
		var key := str(id)
		var th: int = int(p_thresholds[key])
		var c: int = int(p_charges[key])
		if c < th:
			p_charges[key] = mini(c + 1, th)


func _charge_tools() -> void:
	_charge_list(BalanceBattle.TOOL_CARDS, tool_threshold, tool_charge)


func tool_charge_of(tool_id: String) -> int:
	return int(tool_charge.get(tool_id, 0))


func tool_threshold_of(tool_id: String) -> int:
	return int(tool_threshold.get(tool_id, 1))


func is_tool_ready(tool_id: String) -> bool:
	return tool_charge_of(tool_id) >= tool_threshold_of(tool_id)


func tools_state_text() -> String:
	var parts: PackedStringArray = []
	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		var tag := Loc.t("msg.tool.ready") if is_tool_ready(key) else Loc.t("msg.tool.charging")
		parts.append(Loc.tf("msg.tool.state", [BalanceBattle.tool_name(key), tool_charge_of(key), tool_threshold_of(key), tag]))
	return " | ".join(parts)


func select_tool(tool_id: String) -> void:
	if not is_operation():
		_refuse(Loc.t("msg.tool.operation_only"))
		return
	if selected_tool == tool_id:
		clear_selection()
		_set_message(Loc.t("msg.tool.deselected"))
		return
	if not is_tool_ready(tool_id):
		_refuse(Loc.tf("msg.tool.still_charging", [BalanceBattle.tool_name(tool_id),
			tool_charge_of(tool_id), tool_threshold_of(tool_id)]))
		return
	_disarm_all()             # [P54] one answer for the other three, the bean included
	selected_tool = tool_id
	_sync_grid_hint()
	_set_message(tool_prompt())


func tool_prompt() -> String:
	match selected_tool:
		"shovel":
			return Loc.t("msg.prompt.shovel")
		"glove":
			if glove_source.x < 0:
				return Loc.t("msg.prompt.glove_pick")
			return Loc.t("msg.prompt.glove_drop")
		"hammer":
			return Loc.tf("msg.prompt.hammer", [level.hammer_damage()])
	return ""


func _consume_tool(tool_id: String) -> void:
	tools_used[tool_id] = int(tools_used.get(tool_id, 0)) + 1
	tool_charge[tool_id] = 0
	_disarm_all()             # [P54] a spent tool takes the glove's carry with it
	_sync_grid_hint()


func _use_tool_at(col: int, row: int) -> bool:
	if not is_operation():
		_refuse(Loc.t("msg.phase.not_operation"))
		return false
	if not grid.in_bounds(col, row):
		_refuse(Loc.t("msg.cell.outside"))
		return false
	if selected_tool == "":
		return false
	var done := false
	match selected_tool:
		"shovel":
			done = _apply_shovel(col, row)
		"glove":
			done = _apply_glove(col, row)
		"hammer":
			done = _apply_hammer(col, row)
	if done:
		_consume_tool(selected_tool)
		_check_early_win()
	return done


func _apply_shovel(col: int, row: int) -> bool:
	var plant: Unit = grid.get_plant_at(col, row)
	if plant == null:
		_refuse(Loc.tf("msg.shovel.none", [col, row]))
		return false
	var plant_name := plant.display_name
	var hp_left := plant.hp
	var slot := plant.garden_slot
	var note := ""
	if slot >= 0:
		note = Loc.tf("msg.shovel.note_home", [slot])
	_dig_up(plant)
	_log("TOOL", "SHOVEL dug up %s at (%d,%d) (hp %d, no sun refund)%s; charge reset 0/%d"
		% [plant_name, col, row, hp_left, note, tool_threshold_of("shovel")])
	_set_message(Loc.tf("msg.shovel.dug", [plant_name, note]))
	return true


func _apply_glove(col: int, row: int) -> bool:
	if glove_source.x < 0:
		var picked: Unit = grid.get_plant_at(col, row)
		if picked == null:
			_refuse(Loc.tf("msg.glove.none", [col, row]))
			return false
		glove_source = Vector2i(col, row)
		_sync_grid_hint()
		_set_message(Loc.tf("msg.glove.picked",
			[picked.display_name, col, row]))
		return false

	if Vector2i(col, row) == glove_source:
		_refuse(Loc.t("msg.glove.same_cell"))
		return false
	if not grid.is_enabled(col, row):
		_refuse(Loc.tf("msg.glove.row_inactive", [row, grid.enabled_rows_text()]))
		return false
	if not grid.is_free(col, row):
		_refuse(Loc.tf("msg.glove.occupied", [col, row]))
		return false

	var src: Unit = grid.get_plant_at(glove_source.x, glove_source.y)
	if src == null:
		_refuse(Loc.t("msg.glove.gone"))
		clear_selection()
		return false

	var from_col := glove_source.x
	var from_row := glove_source.y
	grid.unregister_plant(from_col, from_row, src)
	src.move_to_cell(col, row)           # hp and unspent AP are preserved
	grid.register_plant(col, row, src)
	_log("TOOL", "GLOVE moved %s (%d,%d) -> (%d,%d) hp=%d/%d ap=%d cost=%d; charge reset 0/%d"
		% [src.display_name, from_col, from_row, col, row, src.hp, src.max_hp,
		   src.ap, src.threshold, tool_threshold_of("glove")])
	_set_message(Loc.tf("msg.glove.moved", [src.display_name, col, row]))
	return true


func _apply_hammer(col: int, row: int) -> bool:
	var list: Array = grid.get_zombies_at(col, row)
	if list.is_empty():
		_refuse(Loc.tf("msg.hammer.none", [col, row]))
		return false
	var damage := level.hammer_damage()
	var hit := 0
	for item in list:
		var z := item as Unit
		if z == null or not z.is_alive():
			continue
		hit += 1
		if grid != null:
			Fx.spawn_spark(z.position, BalanceBattle.COLOR_TOOL_HAMMER)
			z.shake(Vector2.DOWN, BalanceUI.ANIM_SHAKE_DIST)
		z.take_damage(damage)
	_log("TOOL", "HAMMER smashed (%d,%d): %d zombie(s) x %d damage; charge reset 0/%d"
		% [col, row, hit, damage, tool_threshold_of("hammer")])
	_set_message(Loc.tf("msg.hammer.smashed", [hit]))
	return true


# ---------------------------------------------------------------- plant cards + garden (P12)


func _reset_plant_cards() -> void:
	## A card starts READY: the cooldown is the price of a summon, not a warm-up.
	plant_charge = {}
	plant_cooldown = {}
	for id in Balance.plant_cards():
		var key := str(id)
		plant_cooldown[key] = level.plant_card_cooldown(key)
		plant_charge[key] = int(plant_cooldown[key])


# ---------------------------------------------------------------- scrolls (P14)


func _spend_scroll_durability(plant_id: String) -> String:
	## [P14] Only a challenge that says so spends durability; a normal challenge
	## (every level that exists today) spends nothing. Returns a log fragment.
	if not level.spends_scroll_durability():
		return "durability intact (normal challenge)"
	var item := Balance.scroll_item_for(plant_id)
	if item == "" or _profile == null:
		return "no scroll to spend"
	var cost := maxi(1, level.scroll_durability_cost)
	var durability_left := _profile.durability_of(item) - cost
	if durability_left > 0:
		_profile.durability[item] = durability_left
		return "durability %d/%d" % [durability_left, Balance.item_max_durability(item)]
	## the scroll broke: fall back to the next one, or lose the card entirely
	_profile.take_item(item, 1, Profile.CONTAINER_WAREHOUSE)
	var owned := _profile.count_of(item)
	if owned > 0:
		_profile.durability[item] = Balance.item_max_durability(item)
		return "scroll broke, %d durability_left" % owned
	_profile.durability.erase(item)
	return "scroll broke, none durability_left"


func _charge_plant_cards() -> void:
	_charge_list(Balance.plant_cards(), plant_cooldown, plant_charge)


func plant_charge_of(plant_id: String) -> int:
	return int(plant_charge.get(plant_id, 0))


func plant_cooldown_of(plant_id: String) -> int:
	return int(plant_cooldown.get(plant_id, 1))


func is_plant_card_ready(plant_id: String) -> bool:
	## [P95] Balance.has_plant(), not PLANT_DEFS.has(): a spirit card is fielded through
	## this same rail, and the code table alone would answer "not a plant" for all 24 of them.
	if not Balance.has_plant(plant_id):
		return false
	return plant_charge_of(plant_id) >= plant_cooldown_of(plant_id)


func garden_available_count(plant_id: String) -> int:
	## How many garden instances of this type could be summoned right now.
	## [P31-A] In a run battle that pool is the SQUAD, not the whole _garden.
	if _garden == null:
		return 0
	return _summon_pool_slots(plant_id).size()


func _summon_pool_slots(plant_id: String) -> Array[int]:
	## [P31-A] The ONE filter every summon read goes through: a plain battle summons
	## any standing garden plant, a run battle only the ones its squad carries.
	if _garden == null:
		return []
	var pool: Array[int] = _garden.available_slots(plant_id, _deployed)
	if _squad.is_empty():
		return pool
	var kept: Array[int] = []
	for s in pool:
		if _squad.has(int(s)):
			kept.append(s)
	return kept


func _pick_summon_slot(plant_id: String) -> int:
	## The card summons a RANDOM instance of its POOL: which one is not the
	## player's choice. Returns -1 when nothing is free.
	var pool := _summon_pool_slots(plant_id)
	if pool.is_empty():
		return -1
	return pool[randi() % pool.size()]


# ---------------------------------------------------------------- summon scrolls (P13)


func summons_left() -> int:
	## Summon scrolls still usable this round (across all plant cards).
	return maxi(0, summon_limit - summons_this_turn)


func can_summon_more() -> bool:
	return summons_left() > 0


func summon_scrolls_state() -> String:
	return "%d/%d" % [summons_left(), summon_limit]


func _spend_summon_scroll() -> void:
	summons_this_turn += 1


func has_scroll_for(plant_id: String) -> bool:
	## [P109] The card rail's scroll gate, as the board's one door: the HUD used to hold a
	## `profile` handle of its own that nobody assigned after the page/scene split.
	return _profile != null and _profile.has_scroll_for(plant_id)


func summon_blocker(plant_id: String) -> String:
	## [P40-C2] The FOUR summon gates in one place:
	##   owning the scroll that unlocks the card (P14) - the most basic one of all,
	##   this round's scroll budget (P13),
	##   the card's cooldown (P12),
	##   and whether the garden really has an instance to give (P12) - waived for a
	##   spirit copy, which is called out of the scroll itself (P31-B).
	## Returns "" when the card may be armed / summoned, otherwise the refusal text
	## for the player. Order is part of the contract: the two callers used to carry
	## these checks as VERBATIM duplicates, so a gate changed in one place would have
	## armed a card that the board then refused (or the other way round) with nobody
	## printing a difference. A refused check still costs nothing: sun, charge and
	## the scroll are only paid for a summon that actually happens.
	if not has_scroll_for(plant_id):
		return Loc.tf("msg.card.no_scroll", [Balance.plant_name(plant_id)])
	if not can_summon_more():
		return Loc.tf("msg.card.no_summon_left", [summon_limit])
	if not is_plant_card_ready(plant_id):
		return Loc.tf("msg.card.cooling_down",
			[Balance.plant_name(plant_id), plant_charge_of(plant_id), plant_cooldown_of(plant_id)])
	if Balance.spirit_base(plant_id) == "" and garden_available_count(plant_id) <= 0:
		return Loc.tf("msg.card.none_free",
			[Balance.plant_name(plant_id), garden_availability_note(plant_id)])
	return ""


# ---------------------------------------------------------------- retreat (P13)


func garden_availability_note(plant_id: String) -> String:
	## Why a card cannot be used, in words the player can act on.
	if _garden == null:
		return Loc.t("msg.garden.not_loaded")
	var free: int = garden_available_count(plant_id)
	var total := 0
	var out := 0
	var downed := 0
	for s in _garden.slots:
		if str(s["type"]) != plant_id:
			continue
		## [P31-A] in a run battle the note describes the SQUAD's supply of this
		## plant, not the whole garden - the rest cannot answer the card anyway.
		if not _squad.is_empty() and not _squad.has(int(s["slot"])):
			continue
		total += 1
		if bool(s["downed"]):
			downed += 1
		elif _deployed.has(int(s["slot"])):
			out += 1
	return Loc.tf("msg._garden.available_note", [free, total, Balance.plant_name(plant_id), out, downed])


func plant_cards_state_text() -> String:
	var parts: PackedStringArray = []
	for id in Balance.plant_cards():
		var key := str(id)
		var tag := Loc.t("msg.card.ready") if is_plant_card_ready(key) else Loc.t("msg.card.cooling")
		parts.append(Loc.tf("msg.card.state", [Balance.plant_name(key), plant_charge_of(key),
			plant_cooldown_of(key), tag, garden_available_count(key)]))
	return " | ".join(parts)


func _attach_garden_slot(u: Unit, plant_id: String, slot: int) -> void:
	## A summoned plant deploys with the wounds it already has in the garden - that
	## is exactly why healing it matters. The "#n" suffix keeps the instance
	## recognisable on the board and in the garden screen.
	## [P15] Its LEVEL and SKILL VALUE travel with it too: the peashooter fires its
	## owner's attack value, not a global constant.
	var info: Dictionary = _garden.slot_at(slot)
	if info.is_empty():
		return
	var max_hp := int(info.get("max_hp", u.max_hp))
	var hp := int(info.get("hp", u.max_hp))
	# Inside a battle the ledger is the truth: a plant that was dug up and summoned
	# again comes back with the wounds it had, NOT with its pre-battle hp (otherwise
	# shovel + resummon would be a free heal).
	var previous: Dictionary = _garden_ledger.get(slot, {})
	if not previous.is_empty():
		hp = int(previous.get("hp", hp))
	u.garden_slot = slot
	u.max_hp = maxi(1, max_hp)
	u.hp = clampi(hp, 1, u.max_hp)
	u.level = int(info.get("level", 1))
	u.skill_value = _garden.skill_value_of(slot)
	## [B11] ...and the THIRD dimension a level raises: 防御, re-derived the way the ceiling and
	## the skill number above are. No talent term - a potion doses health or skill (see
	## Balance.plant_attr_defence), so a level is the only thing that moves this one.
	u.defence = Balance.plant_attr_defence(plant_id, u.level)
	u.set_display_name("plant." + plant_id, " #%d" % (slot + 1))
	_ledger_set(slot, u.hp, true)
	u.queue_redraw()


func _ledger_set(p_slot: int, p_hp: int, p_alive: bool) -> void:
	## One place that writes a ledger row, so the exp that rides along in it is
	## never accidentally dropped (see Garden.apply_results).
	var entry: Dictionary = _garden_ledger.get(p_slot, {})
	entry["hp"] = p_hp
	entry["alive"] = p_alive
	_garden_ledger[p_slot] = entry


func _ledger_add_exp(p_slot: int, p_amount: int) -> int:
	var entry: Dictionary = _garden_ledger.get(p_slot, {})
	var gained: int = int(entry.get("exp", 0)) + p_amount
	entry["exp"] = gained
	_garden_ledger[p_slot] = entry
	return gained


func _dig_up(plant: Unit) -> void:
	## Shovelling is not killing: a garden plant goes home ALIVE with the wounds it
	## has. It never emits `died`, so there is no death bookkeeping and no DOWNED
	## state for a plant the player simply picked back up.
	var slot := plant.garden_slot
	if slot >= 0:
		_ledger_set(slot, maxi(1, plant.hp), true)
		_deployed.erase(slot)
	grid.unregister_plant(plant.col, plant.row, plant)
	units.erase(plant)
	## [P50] The only dig path, and after the guards above: `_apply_shovel` has already
	## decided there is something to lift, so this is the shovel actually biting.
	SFX.play("shovel")
	## [B25] The shovel asks for the PLAIN fade by name: the plant was lifted out of the lawn,
	## it did not fall over, and a topple here would read as the plant dying in its bed.
	plant.play_death(UnitFx.DEATH_FADE)


func is_pack_open() -> bool:
	return _pack_open


func toggle_pack() -> void:
	## [P15] The backpack panel is a mode of the battle screen (it never changes
	## `screen`), so opening it does not pause or settle anything.
	if not visible:
		return
	_pack_open = not _pack_open
	clear_selection()         # [P54] this is now the one line that drops the bean as well


func close_pack() -> void:
	_pack_open = false


func pack_rows() -> Array:
	## [P22] What the in-battle backpack panel shows, in the ItemGrid row shape: one
	## cell per item kind carried in this  `usable` marks the ones that do
	## something during a battle (today only the energy bean; the rest are dimmed and
	## explain where they ARE used). An empty backpack returns no rows at all - the
	## panel then says so in its own words instead of showing a blank cell.
	var rows: Array = []
	if _profile == null:
		return rows
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		var n := _profile.count_of(key, Profile.CONTAINER_BACKPACK)
		if n <= 0:
			continue
		var kind := Balance.item_kind(key)
		var usable := kind == "battle"
		rows.append({
			"id": key,
			"kind": kind,
			"title": Balance.item_name(key),
			"art": Balance.item_art(key),
			"badge": Loc.tf("item.tile.count", [n]),
			"note": "",
			"dimmed": not usable,
			"badge_color": BalanceUI.COLOR_TEXT,
			"desc": Balance.item_hint(key),
			"usable": usable,
			"count": n,
		})
	return rows


func _take_bean() -> bool:
	## Backpack first (that is where a bean carried into the battle lives).
	if _profile == null:
		return false
	if _profile.take_item(Balance.ITEM_ENERGY_BEAN, 1, Profile.CONTAINER_BACKPACK):
		return true
	return _profile.take_item(Balance.ITEM_ENERGY_BEAN, 1, Profile.CONTAINER_WAREHOUSE)


func _apply_energy_bean(col: int, row: int) -> void:
	clear_selection()         # [P54] whatever happens below, the bean is no longer held
	var plant: Unit = grid.get_plant_at(col, row)
	if plant == null:
		_refuse(Loc.tf("msg.bean.no_plant", [col, row]))
		return
	if not plant.has_skill():
		_refuse(Loc.tf("msg.bean.no_skill", [plant.display_name]))
		return
	## [P37] OPTIMIZATIONS A8: the bean used to be taken AFTER the skill had already
	## resolved, so a failed take left the player the kills, the drops AND the bean.
	## Pay first; refund only when the very first resolution refused (nothing happened).
	if not _take_bean():
		_refuse(Loc.t("msg.bean.none"))
		return
	var done := 0
	for i in Balance.ENERGY_BEAN_HITS:
		if not plant.resolve_skill_once():
			break
		done += 1
	if done <= 0:
		_profile.add_item(Balance.ITEM_ENERGY_BEAN, 1, Profile.CONTAINER_BACKPACK, false)
		ledger_changed.emit()
		_refuse(Loc.tf("msg.bean.idle", [plant.display_name]))
		return
	ledger_changed.emit()
	_log("BEAN", "%s resolved its skill %d time(s) (base %d); bean spent"
		% [plant.display_name, done, plant.skill_value])
	_set_message(Loc.tf("msg.bean.resolved", [plant.display_name, done]))
	_flush_deaths()


# ---------------------------------------------------------------- shop (P15)


func spawn_zombie(p_type: String, p_col: int, p_row: int) -> Zombie:
	## [P60] THE ONE DOOR AN ARRIVING ZOMBIE WALKS THROUGH. Until now the wave and the
	## dancer's call each wrote the same five steps in six lines (build, take a uid - two
	## lines - mark the arrival idle, apply the type from the sheet and this level's
	## scaling, name the node). The ORDER they wrote them in is what D1 was about:
	## `spawn_unit` builds AND places in one go, so a zombie reached the board as the base
	## zombie and was only then told what
	## it really is - every decision `apply_type` makes (sprite, view scene, freeze
	## immunity, hammer, numbers) was taken twice, the first wrong one while the body was
	## already on screen. P38's texture cache means no file was read twice, so this is not
	## an IO fix; it is the ordering promise. Through this door the type is decided BEFORE
	## the board sees the body, so `Unit.place()` asks for the one sprite and the one view
	## the arrival keeps - `Zombie.apply_type`'s [P60] note is the other half of that.
	## Probe bodies still come through `spawn_unit` on purpose: a test that wants "a
	## zombie, any zombie" should not have to name a type, and re-typing one in front of
	## the camera is exactly the runtime path a downgrade takes.
	var z := ZOMBIE_SCRIPT.new() as Zombie
	z.name = "%s_%d_%d" % [p_type, p_col, p_row]
	z.uid = _next_uid
	_next_uid += 1
	z.just_spawned = true
	## [P26] the sheet, the level and the difficulty decide the numbers; the unit only
	## reports what it was handed. [P60] hands them over BEFORE the body goes on screen.
	z.apply_type(p_type, zombie_hp_for(p_type), zombie_armor_for(p_type))
	_attach_unit(z, p_col, p_row)
	return z


func _attach_unit(u: Unit, col: int, row: int) -> void:
	## [P60] Everything a unit needs from the game once it is ON the board, in one place
	## (it was the tail of `spawn_unit`, which the two zombie arrivals had to copy).
	## Named away from `Unit.place()` (the unit's own half of the same handshake) and from
	## `_place_zombie()` (which only decides WHERE a wave may stand).
	u.board = self
	grid.add_child(u)
	u.place(grid, col, row)
	u.died.connect(_on_unit_died)
	units.append(u)
	if u.is_zombie:
		grid.register_zombie(col, row, u)
	else:
		grid.register_plant(col, row, u)


func _script_for(plant_id: String) -> GDScript:
	## [P34] One roster lookup (scripts/units/plant_scripts.gd), and a loud miss
	## instead of the old silent peashooter. A spirit copy runs its BASE plant's
	## script; PlantScripts strips the prefix.
	var script: GDScript = PlantScripts.script_for(plant_id)
	if script != null:
		return script
	push_warning("[WARN] no script registered for plant '%s' - summoning a peashooter instead"
		% plant_id)
	return PEASHOOTER_SCRIPT


func _on_unit_died(unit: Unit) -> void:
	if unit.is_zombie:
		grid.unregister_zombie(unit.col, unit.row, unit)
		zombies_killed += 1
		## [P26] The base zombie's own rule kills it below a third of its health, which
		## is not what the damaging hit did: the death line says which of the two it was,
		## otherwise "the pea did not kill it" would look like a bug.
		var note := ""
		var zombie := unit as Zombie
		if zombie != null and zombie.executed:
			note = " (below 1/3 hp: executed)"
		_pending_deaths.append("[Death] %s at (%d,%d)%s" % [unit.tag(), unit.col, unit.row, note])
		_credit_kill_exp(unit)
		unit_died.emit(unit)   # [P61] the loot rules live in rewards.gd now
	else:
		grid.unregister_plant(unit.col, unit.row, unit)
		if unit.is_garden_plant():
			## The instance stays in _deployed on purpose: a plant that died in this
			## battle is never summoned again during it, and the ledger already says
			## it is DOWNED.
			_ledger_set(unit.garden_slot, 0, false)
			var line := "[Death] %s at (%d,%d) - garden slot %d is DOWNED" % [unit.display_name, unit.col, unit.row, unit.garden_slot]
			_pending_deaths.append(line)
		else:
			_pending_deaths.append("[Death] %s at (%d,%d)" % [unit.display_name, unit.col, unit.row])
	units.erase(unit)
	unit.play_death()


func _credit_kill_exp(unit: Unit) -> void:
	## [P15] The plant that landed the killing blow gets the experience. It rides in
	## the battle ledger, so pressing R also rolls the exp back (no farming).
	var killer := unit.last_attacker
	if killer == null or not killer.is_garden_plant():
		return
	var slot: int = killer.garden_slot
	var total := _ledger_add_exp(slot, Balance.ZOMBIE_EXP)
	_pending_deaths.append("[EXP] %s killed %s: +%d exp (this battle %d)"
		% [killer.display_name, unit.tag(), Balance.ZOMBIE_EXP, total])


func _flush_deaths() -> void:
	for line in _pending_deaths:
		print(line)
	_pending_deaths.clear()


func _remove_unit(u: Unit) -> void:
	if grid != null:
		if u.is_zombie:
			grid.unregister_zombie(u.col, u.row, u)
		else:
			grid.unregister_plant(u.col, u.row, u)
	units.erase(u)
	u.queue_free()


func zombie_hp_for(p_type: String) -> int:
	## [P26] A typed zombie's hp. Its own row in data/units/zombies.csv is scaled by
	##   level.zombie_hp / <base zombie hp>   - a level asking for 405 wants EVERY type
	##                                          50% tougher, not just the plain ones -
	## x the difficulty's zombie_hp_mult.
	## That keeps the old meaning of the field (it was "the zombie's hp" when there was
	## exactly one zombie) while making it a global knob rather than a per-type one.
	## [P81] The multiplier is a plain float on this instance, so asking before a level has
	## been started answers what the DEFAULT preset writes. It used to answer a literal
	## 1.0 written at THIS call site - by luck the same number the normal preset holds, and
	## that luck is the other half of D3: two owners of one number, neither able to be wrong.
	var base := float(ZombieDB.base_hp())
	var level_scale := float(level.zombie_hp) / base
	return maxi(1, int(round(float(ZombieDB.hp(p_type)) * level_scale
		* difficulty_zombie_hp_mult)))


func zombie_armor_for(p_type: String) -> int:
	## Armour follows the same two scalings as hp: a tougher variant of a level must not
	## hand out a bucket that still breaks in one pea.
	var armor := ZombieDB.armor(p_type)
	if armor <= 0:
		return 0
	var level_scale := float(level.zombie_hp) / float(ZombieDB.base_hp())
	return maxi(1, int(round(float(armor) * level_scale
		* difficulty_zombie_hp_mult)))


func _spawn_wave() -> void:
	## [P26] The round's SPAWN PLAN: what the level declared for this round, plus
	## anything that did not fit last round (BALANCE.md 11.3). Every event carries its
	## own zombie type and optionally its own entry columns.
	var queue: Array = []
	if not _pending_spawns.is_empty():
		_log("SPAWN", "%d delayed spawn(s) from the previous round" % _pending_spawns.size())
		for entry in _pending_spawns:
			queue.append(entry)
		_pending_spawns.clear()
	for entry in level.spawn_plan_at(round_no):
		queue.append(entry)
	if queue.is_empty():
		return
	for entry in queue:
		var event: Dictionary = entry
		var ztype := str(event.get("type", ZombieDB.BASE_ID))
		var count := int(event.get("count", 0))
		var cols: Array = event.get("cols", [])
		## [P34] the lanes this event wants (empty = every lane the level plays on).
		var rows: Array = event.get("rows", [])
		for i in count:
			if _place_zombie(ztype, cols, rows):
				continue
			## Nowhere to put it: the REST of this event waits for the next round, and it
			## keeps its type, so a delayed conehead is still a conehead.
			var zombie_left := count - i
			_pending_spawns.append({"type": ztype, "count": zombie_left, "cols": cols, "rows": rows})
			_log("SPAWN", "%d x %s delayed to the next round (cols %s full)"
				% [zombie_left, ZombieDB.name(ztype), _cols_text(cols)])
			break


func _cols_text(p_cols: Array) -> String:
	## The entry columns of one spawn event, or the level's own list when the event did
	## not name any - the string the log line shows.
	if p_cols.is_empty():
		return level.spawn_cols_text()
	var parts := PackedStringArray()
	for c in p_cols:
		parts.append(str(int(c)))
	return ", ".join(parts)


func _place_zombie(p_type: String, p_cols: Array, p_rows: Array) -> bool:
	## One zombie of one type in the first free entry cell. False means "nowhere to put
	## it", which is what makes the caller delay the rest of the event.
	## [P34] The cell is now a (col, row) pair picked off the lanes this battle plays
	## on. The ROW order rotates with the round number, which keeps a wave spreading
	## over the lawn instead of stacking in lane 0, and - because it is a pure function
	## of the round - stays reproducible for the self-checks and a replayed R.
	var cols: Array = p_cols if not p_cols.is_empty() else level.spawn_cols
	var live: Array = grid.enabled_rows()
	var wanted: Array = p_rows if not p_rows.is_empty() else live
	var rows: Array = []
	for r in wanted:
		if live.has(int(r)):
			rows.append(int(r))          # an event cannot spawn onto a dead lane
	var order: Array = []
	var n := rows.size()
	if n > 0:
		var start := round_no % n
		for k in n:
			order.append(rows[(start + k) % n])
	for c in cols:
		var col := int(c)
		for r in order:
			var row := int(r)
			if not grid.is_free(col, row):
				continue
			var z := spawn_zombie(p_type, col, row)
			_log("SPAWN", "%s enters at (%d,%d) type=%s hp=%d armor=%d move=%d bite=%d (idles this turn)"
				% [z.tag(), col, row, p_type, z.hp, z.armor, z.move_threshold, z.bite_damage])
			return true
	_log("SPAWN", "no free cell in cols %s / rows %s - wave delayed"
		% [_cols_text(p_cols), _cols_text(wanted)])
	return false


func summon_children(p_summoner: Zombie) -> PackedStringArray:
	## [P47] The summoned half of a zombie's own summon plan: put 召唤数量 units of
	## 召唤单位 into the FREE CELLS BEHIND the summoner. A zombie walks LEFT, so the
	## cells behind it are the HIGHER columns - the ones the walk has not needed yet,
	## and where an arriving body cannot cut anybody's line. Everything else is the
	## wave's own rule, reused rather than imitated: the sheet plus this level's
	## scaling decide the numbers (zombie_hp_for), and an arrival idles the round it
	## appears (just_spawned) instead of acting twice in its first round.
	## An EMPTY answer means nothing could be placed, and Zombie.act() keeps the call
	## owed - a full lawn must not quietly eat a promise the round clock made.
	var out := PackedStringArray()
	if p_summoner == null or not is_instance_valid(p_summoner) or not p_summoner.is_alive():
		return out
	var child_type := p_summoner.summon_id
	if child_type == "" or not ZombieDB.has(child_type):
		## A row that names a unit this roster does not have is a broken reference, not
		## a summon: say so loudly instead of spawning the base zombie under a new name.
		push_warning("[WARN] %s summons '%s', which is no zombie of this roster"
			% [p_summoner.tag(), child_type])
		return out
	for c in range(p_summoner.col + 1, Balance.COLS):
		if out.size() >= p_summoner.summon_count:
			break
		if not grid.is_free(c, p_summoner.row):
			continue
		var z := spawn_zombie(child_type, c, p_summoner.row)
		out.append("%s(%d,%d)" % [z.type_label(), c, p_summoner.row])
		_log("SUMMON", "%s calls %s at (%d,%d) type=%s hp=%d move=%d (idles this round)"
			% [p_summoner.tag(), z.tag(), c, p_summoner.row, child_type,
			   z.hp, z.move_threshold])
	if out.size() < p_summoner.summon_count:
		_log("SUMMON", "%s wanted %d, got %d - lane %d has no room behind it"
			% [p_summoner.tag(), p_summoner.summon_count, out.size(), p_summoner.row])
	return out


# ---------------------------------------------------------------- player interaction


func is_operation() -> bool:
	return phase == Phase.OPERATION


func is_finished() -> bool:
	return phase == Phase.WIN or phase == Phase.LOSE


func _sync_grid_hint() -> void:
	if grid == null:
		return
	grid.tool_mode = selected_tool
	grid.glove_source = glove_source
	grid.glove_has_source = glove_source.x >= 0
	grid.selection_active = selected_plant != ""
	grid.queue_redraw()


func select_plant(plant_id: String) -> void:
	if not is_operation():
		_refuse(Loc.t("msg.card.operation_only"))
		return
	if selected_plant == plant_id:
		clear_selection()     # [P54] the same answer ESC and an outside click give
		_set_message(Loc.t("msg.selection.cleared"))
		return
	if not Balance.has_plant(plant_id):
		return
	# [P32] the deck gate: a card the seed-picking page left out cannot be armed,
	# whatever route asked for it (the rail's button, or a hotkey press).
	# [P34] an un-picked battle answers with the HEAD of the roster (the rail's
	# width), so a battle that wants a specific set - the campaign's squad - hands
	# that set over as its deck in _enter_run_battle instead of hoping the
	# fall-back window covers it.
	if not battle_cards().has(plant_id):
		_refuse(Loc.tf("msg.card.not_in_deck",
			[Balance.plant_name(plant_id)]))
		return
	# [P40-C2] the four gates (P12 / P13 / P14, and the spirit waiver of P31-B) used
	# to be copied here word for word; summon_blocker() is now the one wording.
	var blocker := summon_blocker(plant_id)
	if blocker != "":
		_refuse(blocker)
		return
	_disarm_all()             # [P54] the fix: this used to leave an armed bean in place
	selected_plant = plant_id
	_sync_grid_hint()
	## [P50] Past every gate, and only on the way that arms the card: the clicks that
	## answer with 阳光不足 / 不在本场牌组 do not get the pick sound, because a sound for a
	## refusal would read as a confirmation of it.
	SFX.play("card_pick")
	var def: Dictionary = Balance.plant_def(plant_id)
	## [P31-B] a spirit card has no garden pool, so it must not quote one
	if Balance.spirit_base(plant_id) != "":
		_set_message(Loc.tf("msg.card.selected.spirit",
			[Balance.plant_name(plant_id), int(def["cost"])]))
	else:
		_set_message(Loc.tf("msg.card.selected",
			[Balance.plant_name(plant_id), int(def["cost"]), garden_available_count(plant_id)]))


func _disarm_all() -> void:
	## [P54] OPTIMIZATIONS C4: the ONE place that answers "nothing is armed right now".
	## A card, a tool, a glove holding a plant mid-carry and an energy bean all want the
	## next click for themselves, so the rule between them is mutual exclusion - and it
	## used to be re-spelled at every site that armed something. That is how the bean,
	## added by P15 after the other three existed, never joined the list: `select_plant()`
	## cleared the tool and the glove but not the bean, so picking up a bean and then
	## clicking a card armed BOTH, and the click on the lawn fed the bean while the rail
	## showed the card as selected. `_bean_armed` is private to this file, so only a
	## helper inside the manager can own all four.
	selected_plant = ""
	selected_tool = ""
	glove_source = Vector2i(-1, -1)
	_bean_armed = false


func clear_selection() -> void:
	## [P54] The public exit: it now drops an armed bean with the rest, and it is the
	## only way to reach `_disarm_all()` that also repaints the board's hint.
	_disarm_all()
	_sync_grid_hint()


func _on_cell_clicked(cell: Vector2i) -> void:
	if not visible:
		return                       # the board is off screen: clicks belong to the menu
	if _pack_open:
		## [P22] The backpack panel is up: its tiles sit on top of the board, so a
		## click that misses them must not place a plant or spend an armed bean.
		return
	if cell.x < 0:
		if selected_tool != "" or selected_plant != "" or _bean_armed:
			clear_selection()
			_set_message(Loc.t("msg.selection.cleared_outside"))
		return
	if _bean_armed:
		_apply_energy_bean(cell.x, cell.y)
		return
	if selected_tool != "":
		if _use_tool_at(cell.x, cell.y):
			_flush_deaths()
		return
	try_place_at(cell.x, cell.y)


func try_place_at(col: int, row: int) -> bool:
	if not is_operation():
		_refuse(Loc.t("msg.phase.not_operation"))
		return false
	if selected_plant == "":
		_refuse(Loc.t("msg.card.pick_first"))
		return false
	if not grid.in_bounds(col, row):
		_refuse(Loc.t("msg.cell.outside"))
		return false
	if not grid.is_enabled(col, row):
		_refuse(Loc.tf("msg.cell.row_inactive", [row, grid.enabled_rows_text()]))
		return false
	if not grid.is_free(col, row):
		_refuse(Loc.tf("msg.cell.occupied", [col, row]))
		return false
	var def: Dictionary = Balance.plant_def(selected_plant)
	var cost: int = int(def["cost"])
	# [P40-C2] the same four gates the card rail answers with (P12 / P13 / P14 and
	# the P31-B spirit waiver), now shared instead of copied. A refusal here still
	# leaves sun, charge and the scroll untouched: you pay for a summon that happens.
	var blocker := summon_blocker(selected_plant)
	if blocker != "":
		_refuse(blocker)
		return false
	if sun < cost:
		_refuse(Loc.tf("msg.sun.not_enough", [sun, cost]))
		return false

	## [P31-B] SPIRIT SUMMON: the copy walks onto the board straight from the
	## scroll - no garden slot, no ledger row, nothing written back (the same
	## no-owner channel a level's starting plants use). Death is final.
	if Balance.spirit_base(selected_plant) != "":
		var spirit := Spawn.create_unit(self, selected_plant, Vector2i(col, row))
		_spirit_summons += 1
		spirit.set_display_name("plant." + selected_plant, " #%d" % _spirit_summons)
		sun -= cost
		sun_spent += cost
		plant_charge[selected_plant] = 0
		_spend_summon_scroll()
		var spirit_note := _spend_scroll_durability(selected_plant)
		var sline := "[SUMMON] %s (spirit copy, no garden slot) at (%d,%d) cost %d -> sun %d; card 0/%d, budget %s, %s" % [spirit.display_name, col, row, cost, sun, plant_cooldown_of(selected_plant), summon_scrolls_state(), spirit_note]
		_log("SUMMON", sline)
		_set_message(Loc.tf("msg.summon.spirit", [spirit.display_name, cost, summons_left()]))
		## [P50] Both placement exits share one cue: what the player did is the same act,
		## whether the copy came off a scroll or out of the _garden.
		SFX.play("plant_place")
		clear_selection()
		return true

	# the card summons a RANDOM instance of its type: which one is not the player's choice
	# [P31-A] through the squad filter: in a run battle only squad plants answer the card
	var slot: int = _pick_summon_slot(selected_plant)
	if slot < 0:
		_refuse(Loc.tf("msg._garden.none_free", [Balance.plant_name(selected_plant)]))
		return false

	sun -= cost
	sun_spent += cost
	var u := Spawn.create_unit(self, selected_plant, Vector2i(col, row))
	_attach_garden_slot(u, selected_plant, slot)
	_deployed[slot] = u
	plant_charge[selected_plant] = 0
	_spend_summon_scroll()
	var scroll_note := _spend_scroll_durability(selected_plant)
	var line := "%s (garden slot %d) at (%d,%d) cost %d -> sun %d; card 0/%d, %d %s still free, budget %s, %s" % [u.display_name, slot, col, row, cost, sun, plant_cooldown_of(selected_plant), garden_available_count(selected_plant), Balance.plant_name(selected_plant), summon_scrolls_state(), scroll_note]
	_log("SUMMON", line)
	_set_message(Loc.tf("msg.summon.done",
		[u.display_name, cost, garden_available_count(selected_plant), summons_left()]))
	SFX.play("plant_place")
	clear_selection()
	return true


func end_turn(p_staged: bool = true) -> void:
	## [P30-A2] The round now RESOLVES IN BEATS: every unit action is followed by a
	## short pause so the player sees each of the peashooter's three shots, and the
	## peas carry their damage to the impact (Peashooter reads resolution_staged).
	## p_staged=false keeps the old one-frame resolution - that is what fast_forward
	## and the self-checks use. With await anywhere in the body the function is a
	## coroutine, but a call that never reaches an await still runs to completion
	## synchronously, so the sync callers need no changes.
	if _resolving:
		return            # a round is still playing out; END TURN is disabled anyway
	if not is_operation():
		if not is_finished():
			_refuse(Loc.t("msg.turn.end_operation_only"))
		return

	_resolving = true
	_resolve_gen += 1
	var gen := _resolve_gen
	resolution_staged = p_staged
	# 每回合开始前重置动画计数器
	_pending_animations = 0
	## [P54] A round boundary now drops an armed bean along with the card it already
	## dropped: an armed bean is a *pending click*, and once the board has resolved, the
	## cell the player means is no longer the one next to that click. Nothing is lost -
	## the bean is only spent when it lands, so the item is still in the backpack.
	clear_selection()
	phase = Phase.PLANT_ACTION
	_do_plant_action(p_staged, gen)

	# 如果是分阶段结算，等待所有动画完成
	if p_staged:
		# 只有当有待处理的动画时才需要等待，避免无动画场景卡住
		# [P30-B] capped: the pea releases its pending animation on every landing
		# path now, but a visual that is killed MID-FLIGHT (a restart, a freed
		# tree) never fires its tween callback at all - the round waits for the
		# peas, not the other way round.
		await _wait_animations(BalanceUI.ANIM_RESOLVE_TIMEOUT)
		if not _resolving or gen != _resolve_gen:
			return
		# 额外等待一小段时间让最后的特效也播放完
		await get_tree().create_timer(0.3).timeout

	if not _resolving or gen != _resolve_gen:
		return
	_flush_deaths()
	if p_staged:
		await _beat()
		if not _resolving or gen != _resolve_gen:
			return

	phase = Phase.ZOMBIE_ACTION
	_do_zombie_action(p_staged, gen)

	# 僵尸行动阶段使用原有的await _beat()逻辑，不需要等待植物动画的信号
	if p_staged:
		await _beat()
	
	if not _resolving or gen != _resolve_gen:
		return
	_flush_deaths()
	if p_staged:
		await _beat()
		if not _resolving or gen != _resolve_gen:
			return

	if brain_hp <= 0:
		_finish(false, Loc.tf("msg.end.brain_eaten", [round_no]))
		_resolving = false
		return

	phase = Phase.TURN_END
	_do_turn_end()
	_flush_deaths()
	if not _resolving:
		return

	if _zombies_sorted().is_empty() and round_no >= level.last_wave_round():
		_finish(true, Loc.t("msg.end.all_cleared"))
		_resolving = false
		return

	_begin_round()
	_resolving = false


func _beat() -> void:
	## One step of the staged resolver: ACTION_STEP_TIME of real time between two
	## unit actions. Callers must re-check `_resolving` after awaiting it - a
	## teardown / restart pressed the flag false and the round must bail.
	await get_tree().create_timer(BalanceBattle.ACTION_STEP_TIME).timeout


func _begin_round() -> void:
	if is_finished():
		return
	phase = Phase.TURN_START
	_do_turn_start()
	## [P89] The round boundary is where a landed sun gets older: the clock is ROUNDS, and
	## it is ticked on the same path the round itself advances on - which is what keeps a
	## fast-forwarded round (F) from collecting differently than a watched one.
	_tick_sun_drops()
	phase = Phase.OPERATION
	_log("OP", "awaiting player: sun=%d  tools: %s" % [sun, tools_state_text()])
	if grid != null:
		var incoming: int = level.wave_at(round_no)
		var title := Loc.tf("msg.banner.your_turn", [round_no])
		if incoming > 0:
			title = Loc.tf("msg.banner.incoming", [round_no, incoming])
			## [P26] a wave the file flagged with "banner" gets the big-wave line: that
			## flag is the pack's own pacing marker (BALANCE.md 11.2).
			if level.has_banner(round_no):
				title = Loc.tf("msg.banner.big_wave", [round_no])
		Fx.spawn_banner(Layout.banner_pos(), title, BalanceUI.COLOR_MESSAGE)
		## [P50] The groan belongs to the WAVE, not to the banner: a round that only says
		## "your turn" would otherwise honk every single turn. The last wave gets the
		## shout, which is the same round the drum arrangement takes over the theme - the
		## two audio layers marking the one moment the pack's data calls the last wave.
		## The test is spelled out here rather than borrowed from _update_battle_music
		## because that one also asks whether a drum file exists, and a shout should not
		## depend on an extra music asset.
		if incoming > 0:
			var last_wave: bool = level.waves.size() > 1 and round_no >= level.last_wave_round()
			SFX.play("final_wave" if last_wave else "wave")


func _do_turn_start() -> void:
	round_no += 1
	rounds_run += 1
	## [P30-B] 铁壁 lasts EXACTLY one round: TURN_START runs before the plant phase,
	## so clearing the flag here means the wall-nut shrugged off the whole zombie
	## phase that followed its ult - and nothing more.
	for u in units:
		if u.ult_immune:
			## [P34] The flag now carries its own round count, so a wall whose sheet
			## says 2 回合无敌 keeps its brace for a second round; with the default of
			## 1 this spends the one point and clears, exactly as P30-B did.
			u.immune_rounds -= 1
			if u.immune_rounds <= 0:
				u.ult_immune = false
				u.immune_rounds = 1
		## [P34] Status riders count down once per round, here, so a rider the plant
		## phase applied in round N still holds through the zombie phase of N, and the
		## round it runs out in is the first one the zombie acts again. Zombies only -
		## no plant can be affected yet - hence the cast instead of a field on Unit.
		var z := u as Zombie
		if z != null and not z.effect_rounds.is_empty():
			var thawed := z.tick_effects()
			if not thawed.is_empty():
				_log("EFFECT", "%s(%d,%d) %s expired -> acts again"
					% [z.tag(), z.col, z.row, ", ".join(thawed)])
		## [P39] A plant's own busy rounds tick in the same breath: TURN_START runs
		## before the plant phase, so a chomper that swallowed in round N misses N (its
		## chew is set inside that phase), N+1 and N+2, and bites again in N+3 - which
		## is what 咀嚼3回合 means. [P48] A giant's hammer recovery rides this same
		## counter and counts the round it was written in the same way, because
		## _do_zombie_action gives up on a stand_down unit both before its phase and
		## inside the AP loop: 锤击后摇 2 costs the rest of the round the hammer fell in
		## plus the whole of the next one, and the giant is free again in the round
		## after that.
		if u.stand_down_rounds > 0:
			u.stand_down_rounds -= 1
			if u.stand_down_rounds <= 0:
				u.stand_down_note = ""
				_log("EFFECT", "%s(%d,%d) done being busy -> acts again"
					% [u.tag(), u.col, u.row])
		## [P47] The summoner's countdown runs on the same clock as every other per-round
		## rider, i.e. TURN_START before either phase. It counts rounds the zombie has
		## been on the lawn (apply_type arms it at spawn), not rounds it actually acted -
		## which is what 每7回合召唤1只伴舞 reads as. Only the tick is logged here; the
		## zombie still pays AP for the call in its own phase.
		if z != null and z.tick_summon():
			_log("SUMMON", "%s(%d,%d) is due: will call %s this round"
				% [z.tag(), z.col, z.row, z.summon_id])
		## [P48] The wind-up counts rounds the same way, i.e. board rounds rather than
		## "rounds the giant happened to act": a hammer frozen by a winter melon still
		## tires, which is the whole point of ice against it. Only the moment it becomes
		## due is logged - the swing itself is an action the zombie phase pays for.
		if z != null and z.tick_smash():
			_log("SMASH", "%s(%d,%d) hammer is due: it falls this round"
				% [z.tag(), z.col, z.row])
	_charge_tools()
	_charge_plant_cards()
	_reset_summon_scrolls()
	_log("START", "round %d  sun=%d  brain=%d  plants=%d  zombies=%d"
		% [round_no, sun, brain_hp, _plants_sorted().size(), _zombies_sorted().size()])
	_log("TOOLS", tools_state_text())
	_log("CARDS", plant_cards_state_text())
	_log("SCROLL", "%d of %d summon(s) left this round" % [summons_left(), summon_limit])
	_spawn_wave()
	_update_battle_music()                   # [P21] the last wave switches to the drum arrangement


func _do_plant_action(p_staged: bool = false, p_gen: int = 0) -> void:
	## [P30-A] AP model: every plant is granted BalanceBattle.ROUND_AP action points, then
	## keeps firing its skill for `threshold` points at a time until it cannot pay
	## (or the round was never long enough for one use at all). Unspent AP expire with
	## the phase - they are NOT banked (confirmed rule). A cost of 1 means three
	## actions per round, the sunflower's 3 means one.
	## [P30-A2] p_staged: one beat of showtime between every two actions, so three
	## shots READ as three shots instead of one damage tick.
	for item in _plants_sorted():
		var u := item as Unit
		if not u.is_alive():
			continue
		u.grant_ap()
		if not u.can_act():
			## [P39] The reason comes from the unit: a wall-nut is a threshold-0 blocker,
			## a chomper is chewing, and printing the first for the second would read as
			## a wiring bug in a log nobody can otherwise tell apart.
			_log("PLANT", "%s(%d,%d) %s, no action" % [u.display_name, u.col, u.row, u.stand_down_text()])
		elif not u.has_target():
			_log("PLANT", "%s(%d,%d) %d AP held -> no target" % [u.display_name, u.col, u.row, u.ap])
		else:
			var acts := 0
			while u.is_alive() and u.has_target() and u.can_afford_action():
				u.spend_action_ap()
				acts += 1
				_log("PLANT", "%s(%d,%d) act %d for %d AP (left %d) %s" % [u.display_name, u.col, u.row, acts, u.threshold, u.ap, u.act()])
				# 移除原来的await _beat()，改为每个attack后等待一小段时间，让attack依次播放
				if p_staged:
					await get_tree().create_timer(0.2).timeout  # 每个植物attack间隔0.2秒
					if not _resolving or p_gen != _resolve_gen:
						break  # 使用break而不是return，退出当前植物的attack循环，继续处理下一个植物
		## [P30-B] the loaded ultimate fires by itself at the END of its owner's
		## action slot (the confirmed rule: full bar -> automatic). It runs even
		## for a plant that never acts (the wall-nut's 铁壁 is exactly the case),
		## but only when firing would do something (ult_can_fire) - a full bar on
		## an empty lane is held, never spent.
		if u.is_alive() and u.ult_ready() and u.ult_can_fire():
			u.consume_ult_charge()
			_log("ULT", "%s(%d,%d) %s" % [u.display_name, u.col, u.row, u.act_ultimate()])
			## [P112] An ultimate always shouts - the cry is the name the ult bar already carries
			## (a plant's 大招 from plants.csv, via ult_shout_text). This is the ONE turn-mode cast
			## that speaks: the plant's act() above is its ordinary attack and stays silent (the
			## user's rule 普攻不喊). A zombie never reaches this branch (ult_shown is plant-only).
			u.shout(u.ult_shout_text(), true)
			if p_staged:
				await get_tree().create_timer(0.2).timeout
				if not _resolving or p_gen != _resolve_gen:
					break


func _do_zombie_action(p_staged: bool = false, p_gen: int = 0) -> void:
	## [P30-A] Every zombie gets the same ROUND_AP budget, but it RE-DECIDES its
	## action before every single use (the plant it was biting may have died from an
	## earlier zombie's bite, the cell it walked into may open a new lane), and each
	## action has its own price: walking costs all 3 AP and only charges +1 move
	## progress - the step itself happens when the progress bar (the sheet's 移动)
	## fills; bites and brain-munches cost 1 AP at 30% damage each.
	## [P30-A2] p_staged adds the same beat-per-action as the plant phase.
	for item in _zombies_sorted():
		var z := item as Zombie
		if not z.is_alive():
			continue
		z.grant_ap()
		if z.just_spawned:
			z.just_spawned = false
			_log("ZOMBIE", "%s(%d,%d) just entered -> idle this turn" % [z.tag(), z.col, z.row])
			continue
		if z.blocked_status() != "":
			## [P34/P90] A status whose 影响 is 禁行动 takes the WHOLE action phase, and it
			## is checked before the entry idle and before any bite is decided: a frozen
			## zombie standing in front of a plant does not nibble it either. The AP it was
			## granted expire with the phase like any other unspent point, and the move
			## progress is left alone, so it resumes the very step it was on.
			_log("ZOMBIE", "%s(%d,%d) %s (%s) -> no action"
				% [z.tag(), z.col, z.row, StatusDB.name_of(z.blocked_status()), z.effect_text()])
			continue
		if z.stand_down_rounds > 0:
			## [P48] The counter a zombie was always missing: standing down is the plant
			## side's rule (a chewing chomper, [P39]) and the zombie phase used to read
			## right past it. It needs to be honoured here for the hammer's recovery, so
			## the same "give up the whole phase, keep the move progress" shape as ice is
			## used - and the same guard goes into the AP loop below, which is what makes
			## the round of the swing itself count as busy.
			_log("ZOMBIE", "%s(%d,%d) %s -> no action"
				% [z.tag(), z.col, z.row, z.stand_down_text()])
			continue

		# every zombie action costs at least 1 AP, so this guard can never out-run
		# the budget; it only bounds the log
		var acts := 0
		while z.is_alive() and z.stand_down_rounds <= 0 and acts < BalanceBattle.ROUND_AP:
			acts += 1
			var next_act: int = _decide_zombie_act(z)
			if z.set_act(next_act):
				_log("ZOMBIE", "%s(%d,%d) switch -> %s (move progress reset)"
					% [z.tag(), z.col, z.row, z.action_label])
			if not z.can_afford_action():
				break
			z.spend_action_ap()
			if next_act == Zombie.Act.ADVANCE:
				z.move_progress += 1
				if z.move_progress >= z.move_threshold:
					z.move_progress = 0
					_log("ZOMBIE", "%s move %d/%d full (AP %d left) %s"
						% [z.tag(), z.move_threshold, z.move_threshold, z.ap, z.act()])
				else:
					_log("ZOMBIE", "%s(%d,%d) advance charged %d/%d (AP %d left)"
						% [z.tag(), z.col, z.row, z.move_progress, z.move_threshold, z.ap])
			else:
				_log("ZOMBIE", "%s(%d,%d) act %d for %d AP (left %d) %s"
					% [z.tag(), z.col, z.row, acts, z.threshold, z.ap, z.act()])
			## [P63] The step is over, so wherever the body now stands is where a spike
			## gets its say. Inside the loop rather than after it, because the loop is what
			## re-decides and re-moves: a zombie that bites three times pays three stabs and
			## a zombie that walks once pays one, on the cell it ended on.
			if z.is_alive():
				_stab_walkers(z)
			if p_staged:
				await _beat()
				if not _resolving or p_gen != _resolve_gen:
					return


func _decide_zombie_act(z: Zombie) -> int:
	## [P48] A hammer that is already in the air is settled FIRST - ahead of the brain,
	## of an owed summon and of the walk: it is the one zombie state that says "this
	## round is already spoken for", and a giant that reached the brain mid-swing would
	## otherwise stand there eating brains forever with its hammer raised (and labelled
	## "winding up"). If the plant the wind-up was aimed at died in the meantime, the
	## swing is called off rather than dropped on an empty cell.
	if z.smash_armed:
		if grid.get_plant_at(z.col - 1, z.row) == null:
			z.cancel_smash_windup()
			_log("ZOMBIE", "%s(%d,%d) the plant it was winding up at is gone -> hammer lowered"
				% [z.tag(), z.col, z.row])
		else:
			return Zombie.Act.SMASH if z.smash_is_due() else Zombie.Act.WINDUP
	if z.col <= 0:
		return Zombie.Act.EAT_BRAIN
	## [P47] An OWED summon outranks the walk and the bite: the round clock promised
	## "每7回合召唤1只", and a dancer that happens to stand in front of a plant when the
	## clock runs out would otherwise spend that round biting and lose the call. It
	## costs 1 AP, so the bite still fits afterwards in the same round.
	if z.summon_is_due():
		return Zombie.Act.SUMMON
	var ahead: Unit = grid.get_plant_at(z.col - 1, z.row) as Unit
	if ahead != null:
		## [P26] a pole vaulter clears the first plant instead of eating it ("不咬，
		## 直接越过1格"); every other type bites.
		## [P48] And a type WITH a hammer does neither: the first plant in front of it
		## starts a wind-up instead, because the 9999 in its attack column is the hammer's
		## number and the 30% bite ratio is not what the sheet means by it.
		## [P63] 地刺 says it is not something a mouth closes on (units.csv 不会被啃食 ->
		## PlantDB.is_uneatable -> the instance flag). That answers the BITE branch and
		## ONLY the bite branch: the hammer row of the sheet proves a giant brings its
		## 9999 down on a spike the same as on a wall-nut, and the vaulter clears the first
		## plant it meets whatever that plant is. So the two tests above stay unfiltered
		## and the walker simply keeps advancing, onto the spike's own cell - which is
		## where `_stab_walkers` is waiting for it.
		if z.can_smash():
			return Zombie.Act.WINDUP
		if z.can_vault():
			return Zombie.Act.VAULT
		if not ahead.ignores_biting:
			return Zombie.Act.BITE
	return Zombie.Act.ADVANCE


func _stab_walkers(z: Zombie) -> void:
	## [P63] The spike's stab, asked once per zombie ACTION rather than once per round:
	## 地刺's 踩过时 is a step, and a step is exactly what the loop in `_do_zombie_action`
	## takes. Sitting there - after the act, before the beat - covers both readings of the
	## sheet's words at one call site: the body that walked ONTO the spike is stabbed by the
	## same line that stabs the body that has been standing on it (a bite, a summon or a
	## hammer all spend an action in place), and it costs the zombie nothing, because the
	## price is the plant's own AP (SpikePlant.stab_the_walker).
	##
	## Why this is not part of the plant phase: a spike that fired in its own slot AND
	## under a walker would get two bites of the same round out of three points, and the
	## one that is dropped is its own - the plant's `has_target()` answers false precisely
	## so the whole budget is left for the walkers. A frozen or standing-down zombie is
	## not stabbed either, because it gave up its whole phase before reaching here (the
	## P34/P48 rule), and a spike does not hurt a body that is not walking on it.
	if grid == null:
		return
	for entry in grid.get_plants_at(z.col, z.row):
		var plant := entry as Unit
		if plant == null or not plant.is_alive():
			continue
		if not plant.has_method("stab_the_walker"):
			continue          # a row that only says "cannot be eaten", and stabs nothing
		var line: String = plant.stab_the_walker(z)
		if line != "":
			## Logged under PLANT, not ZOMBIE: this is the plant spending its points and
			## dealing its number, and a reader tracing a spike's three stabs wants them
			## beside the rest of what that plant did.
			_log("PLANT", "%s(%d,%d) stabs a walker %s" % [plant.display_name, plant.col, plant.row, line])


func _do_turn_end() -> void:
	## [P89] The round's income is no longer banked here: the sky drops it and the player
	## picks it up (or lets the auto-collect do it). One rule for every sun on this board -
	## what a plant pays and what the sky pays arrive the SAME way.
	Spawn.create_items(_profile, "sun", 1, Spawn.WHERE_FIELD, Spawn.SOURCE_NATURAL,
		Vector2.ZERO, level_sun_per_turn)
	_log("END", "natural sun %d dropped from the sky  brain=%d  plants=%d  zombies=%d"
		% [level_sun_per_turn, brain_hp, _plants_sorted().size(), _zombies_sorted().size()])


func _check_early_win() -> void:
	## [P12 / HANDOFF 6-b] Killing the last zombie with a tool used to leave the
	## player staring at an empty lawn until they pressed END TURN. The board is
	## clear and no wave is left, so the battle is over right now - and settling
	## here is also what writes the garden back without another round.
	if is_finished() or not is_operation():
		return
	if not _zombies_sorted().is_empty():
		return
	if round_no < level.last_wave_round():
		return
	_finish(true, Loc.t("msg.end.all_cleared_tool"))


func spawn_sun_drop(p_amount: int, p_source: String, p_style: String, p_at: Vector2,
		p_to: Vector2 = Vector2.INF) -> Node2D:
	return SunField.spawn(self, p_amount, p_source, p_style, p_at, p_to)


func _tick_sun_drops() -> void:
	SunField.tick(self)


func _collect_sun_drop(p_drop: Node2D, p_how: String) -> void:
	SunField.collect(self, p_drop, p_how)


func _clear_sun_drops() -> void:
	SunField.clear(self)
# ---------------------------------------------------------------- helpers used by units


func get_closest_zombie_in_row(p_row: int, from_col: int, allow_behind: bool) -> Unit:
	var best: Unit = null
	for u in units:
		if not u.is_zombie or not u.is_alive() or u.row != p_row:
			continue
		if not allow_behind and u.col <= from_col:
			continue
		if best == null or u.col < best.col:
			best = u
	return best


func get_zombies_in_row(p_row: int) -> Array:
	## [P30-B] Every living zombie in one lane, leftmost first - the target list a
	## 大招 that sweeps its whole row iterates (see Peashooter.act_ultimate). The
	## engine hands act_ultimate() a fresh copy, so hitting one and killing it can
	## never disturb the loop that is still walking the list.
	var out: Array = []
	for u in units:
		if u.is_zombie and u.is_alive() and u.row == p_row:
			out.append(u)
	out.sort_custom(_sort_by_col)
	return out


func get_zombies_in_rows(p_rows: Array, from_col: int) -> Array:
	## [P34] The multi-lane version of get_zombies_in_row: every living zombie in ANY
	## of these lanes, ahead of from_col, leftmost first. A plant that fires up and
	## down the lawn asks "is there prey on any of MY rows" in one call here instead
	## of looping the single-row query and de-duplicating the result itself - the
	## threepeater's volley and its 大招 are the same question with different rows.
	var out: Array = []
	for u in units:
		if not u.is_zombie or not u.is_alive() or not p_rows.has(u.row):
			continue
		if u.col <= from_col:
			continue
		out.append(u)
	out.sort_custom(_sort_by_col)
	return out


func plant_total() -> int:
	return _plants_sorted().size()


func zombie_total() -> int:
	return _zombies_sorted().size()


func _sort_by_col(a, b) -> bool:
	if a.col != b.col:
		return a.col < b.col
	return a.row < b.row


# ---------------------------------------------------------------- HUD text


func _sort_by_row_col(a, b) -> bool:
	if a.row != b.row:
		return a.row < b.row
	return a.col < b.col


func get_zombies_ahead(p_rows: Array, from_col: int, range_cells: int) -> Array:
	## [P34] The forward box a short-range shooter breathes into: living zombies in
	## these lanes, strictly ahead of the plant, within `range_cells` columns. A
	## puff-shroom (one victim in its 3 cells) and a fume-shroom (every body in them,
	## armour ignored) differ only in how many of these they hit, not in how they
	## ask - which is why the box is a query and not per-plant code.
	var out: Array = []
	for u in get_zombies_in_rows(p_rows, from_col):
		if u.col <= from_col + range_cells:
			out.append(u)
	return out


func damage_brain(amount: int) -> void:
	brain_hp = maxi(0, brain_hp - amount)


func sunflower_sun_value() -> int:
	return level_sunflower_sun


func _plants_sorted() -> Array:
	var out: Array = []
	for u in units:
		if u.is_alive() and not u.is_zombie:
			out.append(u)
	out.sort_custom(_sort_by_row_col)
	return out


func _zombies_sorted() -> Array:
	var out: Array = []
	for u in units:
		if u.is_alive() and u.is_zombie:
			out.append(u)
	out.sort_custom(_sort_by_col)
	return out


func phase_hint() -> String:
	match phase:
		Phase.OPERATION:
			return Loc.t("msg.phase.operation")
		Phase.PLANT_ACTION:
			return Loc.t("msg.phase.plant_action")
		Phase.ZOMBIE_ACTION:
			return Loc.t("msg.phase.zombie_action")
		Phase.TURN_START:
			return Loc.t("msg.phase.turn_start")
		Phase.TURN_END:
			return Loc.t("msg.phase.turn_end")
		Phase.WIN:
			return Loc.t("msg.phase.win")
		Phase.LOSE:
			return Loc.t("msg.phase.lose")
	return Loc.t("msg.phase.boot")


func hover_text() -> String:
	var c: Vector2i = grid.get_hover_cell()
	if not grid.in_bounds(c.x, c.y):
		return Loc.t("msg.hover.none")
	var state := Loc.t("msg.hover.free") if grid.is_free(c.x, c.y) else Loc.t("msg.hover.occupied")
	var extra := "-"
	if selected_tool != "":
		extra = Loc.t("msg.hover.tool_target") if grid.is_tool_target(c.x, c.y) else Loc.t("msg.hover.not_target")
	elif selected_plant != "":
		extra = Loc.t("msg.hover.placeable") if grid.is_placeable(c.x, c.y) else Loc.t("msg.hover.blocked")
	return Loc.tf("msg.hover.line", [c.x, c.y, state, extra,
		grid.plant_count(), grid.zombie_count()])


func next_wave_text() -> String:
	var rounds: Array = level.waves.keys()
	rounds.sort()
	for r in rounds:
		if int(r) > round_no:
			return Loc.tf("msg.wave.next", [int(r), int(level.waves[r])])
	return Loc.t("msg.wave.final")


# ---------------------------------------------------------------- logging


func _log(tag: String, text: String) -> void:
	print("[T%02d][%-6s] %s" % [round_no, tag, text])


func set_message(text: String) -> void:
	## The public door for Game's front-end messages (the shop, the potions, the reset
	## confirmation): the status LINE is drawn by the HUD, which lives on the board.
	_set_message(text)


func _set_message(text: String) -> void:
	## [P65] The save alarm rides on EVERY line rather than only the one that raised it.
	## Many of the thirty-eight writes sit inside a function that then hands the UI its
	## own success message (`buy`, the two sells, the three potions, the bean), so a warning
	## printed once at the moment of the failure would be overwritten in the same click -
	## which is exactly the silence A3 is about. The startup probes that compare
	## `status_message` with a `Loc` string LITERALLY still pass, because a healthy run
	## never latches this; if a disk ever does refuse, those probes failing would be the
	## truth, not a bug.
	## [P106] The save alarm is Game's fact, so the text arrives here already carrying it (see
	## set_unsaved_note). A battle never reads a save ledger.
	status_message = text + unsaved_note
	_message_timer = BalanceBattle.MESSAGE_DURATION


func _refuse(text: String) -> void:
	## [P55] OPTIMIZATIONS C-group debt / P50's deferred funnel: the ONE exit for "the
	## player clicked, and this click did not happen". Every gate in the battle used to
	## spell `_set_message(...)` + `return` on its own - 31 of them - which is why P50
	## could not hang a sound on a refusal: it would have meant 31 hook points, each one
	## a place to forget. The line still shows the reason (a refusal must be EXPLAINED,
	## never just buzzed), and now the reason also sounds like one.
	## What deliberately does NOT come through here: a success (`msg.summon.done`,
	## `msg.glove.moved`), a prompt that asks for a second click (`msg.retreat.confirm`),
	## and a toggle that worked (`msg.selection.cleared`, `msg.tool.deselected`). Those
	## are answers too, but a "no" sound on them would read as "you did it wrong".
	## No log line: the text is player-facing and therefore LOCALIZED, and §2 keeps the
	## log in English, so logging it here would put Chinese into the boot log on a
	## Chinese client. A gate that wants an English trace already prints its own.
	_set_message(text)
	SFX.play("refused")


## ---------------------------------------------------------------- ledgers to disk (P65)
## [P65] OPTIMIZATIONS A3, the last open entry of the A group. The three functions below
## are the ONLY way anything writes a save file, and they are PUBLIC for exactly that
## reason: `run_flow.gd`, `rewards.gd` and `garden_view.gd` all persist a ledger too, so a
## private door would have left two thirds of the sites outside it. Before this batch
## thirty-eight call sites dropped the `bool` P37 had started returning, so a disk that
## said "no" cost the player that progress in silence - A1 made a failed write HARMLESS
## (the old file survives); this makes it SEEN.
## A `false` reaching these doors can only mean a write failure: the "refusing to save a
## scratch instance" branch inside each ledger belongs to that class's own `self_check()`
## probes, which build their own instances and never come through Game.


func _kill_all_zombies() -> void:
	if is_finished():
		print("[Debug] game already finished (%s); press R to restart" % PHASE_NAME.get(phase, "?"))
		return
	var list := _zombies_sorted()
	print("---------- debug: killing %d zombie(s) ----------" % list.size())
	for item in list:
		var z := item as Unit
		## [P26] The debug kill drops the armour layer first: damage alone would be
		## ABSORBED by a buckethead's 600 armour and leave it standing, which would make
		## this key look broken exactly where it is most useful.
		var zombie := z as Zombie
		if zombie != null:
			zombie.armor = 0
		z.take_damage(z.hp)
	_flush_deaths()
