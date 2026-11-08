extends RefCounted
class_name BattleMain
## [P109] THE BATTLE LIFECYCLE - the "start a level / put a board up / settle it / leave"
## chain that used to sit in game_manager.gd. Like RunFlow and FrontEndFlow, this is a
## behaviour object with an injected `game` pointer, NOT a save file and NOT a scene.
## Ownership after the cut:
## - Game keeps the handles the whole app shares: `battle` (the board node, typed Node on
##   purpose to avoid a circular import - this file reaches it through `_board()`), garden,
##   profile, level, chapter, run, run_flow, the difficulty fields, the save doors and the
##   status-line door `_set_message`.
## - FrontEndFlow owns the screen enum and `_run_battle` (this file reads both through
##   `game.front`).
## - This file owns `level_path` and the three folded sun numbers a board is started with,
##   because nothing outside the battle lifecycle reads them afterwards.
## [P106] THE BATTLE IS A SCENE (scenes/battle.tscn: Battle -> LawnGrid + HudLayer/Hud).
## Game puts one up when a battle starts and frees it when the board goes away; its script
## is scripts/core/battle/battle.gd.

const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const SFX := preload("res://scripts/core/sfx.gd")
## [P109] Rewards / StatusDB / ProjectileDB are DELIBERATELY without `class_name`, so this
## file preloads them like Game does (preload is cached - same object, no duplicate load).
const Rewards := preload("res://scripts/core/rewards.gd")
const StatusDB := preload("res://scripts/core/db/status_db.gd")
const ProjectileDB := preload("res://scripts/core/db/projectile_db.gd")

var game: GameManager = null             # [P109] the autoload; set right after .new()

## What this file owns: which level the running board came from, and the three sun
## numbers folded from difficulty + run mods at board-build time.
var level_path: String = Balance.LEVEL_PATH
var level_start_sun: int = BalanceBattle.START_SUN
var level_sun_per_turn: int = BalanceBattle.SUN_PER_TURN
var level_sunflower_sun: int = Balance.SUNFLOWER_SUN

## [P109] The reward LEDGER, moved off Game with the settle pipeline that fills it:
## Rewards.grant writes the WIN lines, the LOSE path writes its one line, RunFlow
## appends the campaign stages on top, and `stats_lines` prints it to the result panel.
## It is rewritten whole at every settlement, so it needs no reset hook.
var reward_lines: Array[String] = []


# ---------------------------------------------------------------- the board handle

func _board() -> Battle:
	## [P109] `game.battle` is typed Node on purpose (no circular import). One cast door,
	## so every read below is compile-checked and null between battles.
	return game.battle as Battle


# ---------------------------------------------------------------- starting a level

func start_level(p_path: String) -> void:
	## Called by the deck page's DEPLOY (and, unchanged, by anything that starts a
	## level with the deck as it stands). Loads that JSON and runs it like a normal game.
	if p_path == "":
		return
	## [P37] OPTIMIZATIONS A9: the level used to be parsed only AFTER the board was torn
	## down and the GAME screen was up, so a broken JSON silently played as the built-in
	## default level - the player never learned the edit had failed. Probe on a scratch
	## instance first and stay on the page we are on.
	var probe := LevelData.new()
	if not probe.load_from_file(p_path):
		push_warning("[Level] refusing to start %s: %s" % [p_path, probe.problems_text()])
		return
	level_path = p_path
	SettingsStore.set_last_level(p_path.get_file().get_basename())
	game.front.screen = FrontEndFlow.Screen.GAME
	## [P64] The same pipeline every page runs, backwards: entering a battle is not a page
	## switch, which is why `start_level` keeps its own body and only borrows the helpers.
	game.front.hide_views()
	game.front.set_world_visible(true)
	var board := _board()
	if board != null:
		board.hud.on_layout_changed()          # [P32] the card rail re-compacts to the deck
	print("---------- starting level %s ----------" % level_path)
	_start_new_game()


func _teardown_board() -> void:
	## [P106] TAKING THE BOARD DOWN IS FREEING THE SCENE. Everything the old body did by hand -
	## stopping the cues, clearing the lawn, dropping the sun, disarming, resetting the phase -
	## is now either the board's own `cancel()` (the round clock and the sun field, which must
	## happen BEFORE the nodes go) or follows the nodes out of the tree.
	SFX.stop_all()
	var board := _board()
	if board == null:
		return
	board.cancel()
	board.queue_free()
	game.battle = null


func _start_new_game() -> void:
	# 1. clear the board (including units already fading out and thus not in `units`)
	_teardown_board()

	# 2. (re)load external data - this is why R lets you edit the JSON live
	## [P26] The two UNIT SHEETS are re-read on the same key: editing
	## data/units/plants.csv or zombies.csv and pressing R is now the same loop the
	## level JSON already had (no game restart). Order matters - the sheet is read
	## first, so the level parse right below validates zombie types against the file
	## the player just edited.
	PlantDB.load_from_disk()
	ZombieDB.load_from_disk()
	## [P27] the third sheet: data/items.csv (the almanac's item registry). Editing it
	## and pressing R re-reads it just like the other two - no restart needed.
	ItemDB.load_from_disk()
	## [P30-A] the fourth sheet: data/units/skills.csv (skill AP prices). Same loop.
	SkillDB.load_from_disk()
	## [P31-A] the adventure tables: the event JSON and the chapter graph. Editing
	## data/adventure/*.json and pressing R is the same no-restart loop.
	EventDB.load_from_disk()
	## [P90] and the status sheet, which the zombie riders read every hit.
	StatusDB.load_from_disk()
	## [P91] and the shot sheet, which the projectiles read on every launch.
	ProjectileDB.load_from_disk()
	var chapter_reload := ChapterMap.load_first()
	if chapter_reload.loaded:
		game.chapter = chapter_reload
	## The garden stores a health ceiling per slot; re-derive them from the (possibly
	## new) sheet so a data edit lands without touching the save file.
	var resynced: int = game.garden.refresh_max_hp() if game.garden != null else 0
	print("[Data] reloaded " + PlantDB.status_text())
	print("[Data] reloaded " + ZombieDB.status_text())
	print("[Data] reloaded " + UnitSheet.live().status_text())   # [P29]
	print("[Data] reloaded " + ItemDB.status_text())
	print("[Data] reloaded " + SkillDB.status_text())
	print("[Data] reloaded " + EventDB.status_text())      # [P31-A]
	if resynced > 0:
		print("[Data] garden health ceilings re-derived for %d plant(s)" % resynced)
		game.save_garden()    # the file must not keep the old ceilings either

	if not game.level.load_from_file(level_path):
		push_warning("[Level] re-parse of %s FAILED, this board is the built-in defaults: %s"
			% [level_path, game.level.problems_text()])
	game.difficulty_key = game.forced_difficulty if game.forced_difficulty != "" else game.level.difficulty_key
	## [P31-A] A run battle folds its mods INTO the difficulty preset before anything
	## reads it: multiplicative keys multiply, the start-sun bonus adds. Doing it here
	## means sun / zombie HP / the log line all agree on the same folded numbers.
	## [P81] The three reads are typed accessors now, so the fold writes typed fields and
	## LOCALS instead of brackets: the multiplier is the only number with a life after this
	## function, and a mod key the run carries but this list does not name is caught at
	## boot by `[Diff] the three numbers a preset answers are exactly the keys ...`.
	game.difficulty_zombie_hp_mult = Difficulty.zombie_hp_mult(game.difficulty_key)
	var sun_mult: float = Difficulty.sun_mult(game.difficulty_key)
	var start_sun_bonus: int = Difficulty.start_sun_bonus(game.difficulty_key)
	if game.front._run_battle and game.run != null:
		game.difficulty_zombie_hp_mult *= game.run.mod_product(Difficulty.ZOMBIE_HP_MULT_KEY)
		sun_mult *= game.run.mod_product(Difficulty.SUN_MULT_KEY)
		start_sun_bonus += game.run.mod_bonus(Difficulty.START_SUN_BONUS_KEY)
		print("[Run] mods folded into this battle: " + game.run.mods_text())
	level_start_sun = maxi(0, game.level.initial_sun + start_sun_bonus)
	level_sun_per_turn = maxi(1, int(round(float(BalanceBattle.SUN_PER_TURN) * sun_mult)))
	## [P26] A sunflower's own rate comes from its sheet row (the attack column is the sun
	## it produces); Balance.SUNFLOWER_SUN is the fall-back when the sheet is missing it.
	var sunflower_base := Balance.plant_base_skill("sunflower")
	if sunflower_base <= 0:
		sunflower_base = Balance.SUNFLOWER_SUN
	level_sunflower_sun = maxi(1, int(round(float(sunflower_base) * sun_mult)))

	# 3. put a board up (the reset itself is the board's: Battle._reset_state)
	set_up_battle()


# ---------------------------------------------------------------- spawning

func set_up_battle() -> void:
	## [P106] ONE BOARD, ON DEMAND. The scene is instantiated here, told everything it needs
	## through ONE object (BattleSetup), and wired to the five things only the session can do:
	## land the result, roll a death's loot, leave, open the settings overlay, save a write.
	## The board holds no reference back - it reports through signals (see battle.gd's header).
	## [P109] The handle stays on Game (`game.battle`); this object is the one that puts it up.
	if game.battle != null:
		_teardown_board()
	var battle := BATTLE_SCENE.instantiate() as Battle
	if battle == null:
		push_error("[Battle] scenes/battle.tscn did not instantiate as a Battle")
		return
	game.battle = battle
	battle.settled.connect(_on_battle_settled)
	battle.unit_died.connect(_on_unit_died_loot)
	battle.left.connect(_on_battle_left)
	battle.settings_requested.connect(game.show_settings_overlay)
	battle.ledger_changed.connect(game.save_profile)
	var setup := BattleSetup.new()
	setup.level = game.level
	setup.level_path = level_path
	setup.garden = game.garden
	setup.profile = game.profile
	setup.deck = game.front._battle_deck.duplicate()
	setup.zombie_hp_mult = game.difficulty_zombie_hp_mult
	setup.sun_start = level_start_sun
	setup.sun_per_turn = level_sun_per_turn
	setup.sunflower_sun = level_sunflower_sun
	setup.run_battle = game.front._run_battle
	## [P31-A] The squad filter travels as a LIST of slots: the board must not know RunState.
	setup.squad = []
	if game.front._run_battle and game.run != null:
		for slot in game.run.squad:
			setup.squad.append(int(slot))
	var shell := game.get_tree().current_scene
	if shell == null:
		push_error("[Battle] no current scene to put the board in")
		return
	shell.add_child(battle)
	game._sync_unsaved_note()
	battle.begin(setup)


func _on_battle_settled(result: Dictionary) -> void:
	## [P106] The board decided the battle (Battle._finish). What it MEANS - writing the garden
	## back, paying the rewards, the campaign's three stages, and which button the result panel
	## offers next - is the session's business, and this is the whole of it.
	## [P109] Landing the ledger (`_settle_garden`) and the save doors stay on Game: a quit or
	## a window-close settles through the same door, so it must not live in the battle object.
	var win: bool = bool(result.get("win", false))
	var reason := str(result.get("reason", ""))
	game._settle_garden("WIN" if win else "LOSE")
	var board := _board()
	# [P14] rewards are granted AFTER the settle, so a plant that died in the very battle that
	# unlocked the reward still comes home DOWNED first
	if win:
		Rewards.grant(game, board)
		if game.front._run_battle and game.run != null:
			game.run_flow._grant_run_base()
			game.run_flow._roll_run_reward_options()
	else:
		reward_lines.clear()
		reward_lines.append(Loc.t("panel.reward.none_on_lose"))
		if game.front._run_battle and game.run != null:
			game.run_flow._apply_run_defeat()
	print("")
	print("================ RESULT: %s ================" % ("WIN" if win else "LOSE"))
	print("level  : %s (%s)" % [game.level.level_name, Difficulty.label(game.difficulty_key)])
	print("reason : %s" % reason)
	if board != null:
		print("rounds : %d   zombies killed: %d" % [board.round_no, board.zombies_killed])
	print("===========================================")
	_print_summary()
	## [P31-A] A campaign battle's button walks into the pick-one-of-three page; a free
	## level's restarts. The board only prints the label it is handed.
	var label := ""
	var action := "restart"
	if game.front._run_battle and game.run != null and game.run_flow.is_run_battle_result():
		label = str(game.run_flow.run_result_action_text())
		action = "run_next"
	if board != null:
		board.show_result(stats_lines(), label, action)


func _on_unit_died_loot(unit: Unit) -> void:
	## [P106] A zombie died on the board: WHAT IT DROPS is a session rule (data/drops.csv and
	## the live ledger), so the roll happens here. If the roll puts a sun on the lawn, the
	## caller asks the board to place it - `spawn_pickup` is the one thing the board is asked
	## for from above.
	Rewards.roll_drop(game, _board(), unit)


# ---------------------------------------------------------------- leaving

func retreat() -> void:
	## [P13] Leave the battle on purpose. This SETTLES the garden (the wounds the
	## battle earned belong to your plants) and returns to the main menu - exactly
	## what the M key does. A battle that is already decided leaves at once; a live
	## one needs two clicks, because a stray click must not be able to wound the
	## garden for good.
	var board := _board()
	if board == null or board.is_finished() or not game._boot_done:
		game.show_main_menu()
		return
	if board._retreat_timer <= 0.0:
		board._retreat_timer = BalanceBattle.RETREAT_CONFIRM_TIME
		game._set_message(Loc.t("msg.retreat.confirm"))
		return
	board._retreat_timer = 0.0
	print("---------- retreat (garden is written back) ----------")
	game.show_main_menu()


func restart() -> void:
	## [P31-A] On a run battle the result panel's one button does the run-aware
	## thing: a WIN walks to the pick-one-of-three page, a LOSE re-deploys the same
	## node (the retry fee was already charged the moment the defeat happened).
	var board := _board()
	if game.front._run_battle and game.run != null and board != null and board.is_finished():
		if board.phase == Battle.Phase.WIN:
			game.run_flow.run_result_advance()
		else:
			game.run_flow.run_result_retry()
		return
	_start_new_game()


func _on_battle_left(reason: String) -> void:
	## [P106] The board asked to leave: retreat, R, the result panel's button, the menu button,
	## or the D key. Where that goes is the session's routing, and every arm ends in a page.
	match reason:
		"restart", "run_next":
			restart()
		"retreat", "menu":
			game.show_main_menu()
		"cycle_difficulty":
			game.forced_difficulty = Difficulty.next_key(game.difficulty_key)
			print("---------- difficulty -> %s (restarting) ----------" % Difficulty.label(game.forced_difficulty))
			restart()
		_:
			print("[Battle] the board asked to leave for an unknown reason: " + reason)


# ---------------------------------------------------------------- HUD text

func stats_lines() -> PackedStringArray:
	## Result panel lines. [P14] ends with the rewards, what the backpack collected,
	## and where the money stands.
	var board := _board()
	var out: PackedStringArray = []
	out.append(Loc.tf("panel.result.level", [game.level.display_name(), Difficulty.label(game.difficulty_key)]))
	if board != null:
		out.append(Loc.tf("panel.result.rounds", [board.round_no]))
		out.append(Loc.tf("panel.result.zombies", [board.zombies_killed, game.level.total_zombies()]))
		out.append(Loc.tf("panel.result.sun", [board.sun, board.sun_spent]))
		out.append(Loc.tf("panel.result.brain", [board.brain_hp, board.brain_hp_max()]))
		out.append(Loc.tf("panel.result.tools",
			[int(board.tools_used.get("shovel", 0)), int(board.tools_used.get("glove", 0)), int(board.tools_used.get("hammer", 0))]))
	out.append(game.garden_state_text())
	for line in reward_lines:
		out.append(Loc.tf("panel.result.reward", [line]))
	if not game._backpack_lines.is_empty():
		## join() needs a PackedStringArray (HANDOFF 7.3), not an Array[String]
		var packed: PackedStringArray = []
		for line in game._backpack_lines:
			packed.append(line)
		out.append(Loc.tf("panel.result.backpack", [", ".join(packed)]))
	out.append(Loc.tf("panel.result.money", [_money_text()]))
	return out


func _money_text() -> String:
	## [P109] Game's `money_text` door is a front-end fact (the HUD and the shop pages read
	## it too); the result panel just needs the same string, so this object keeps a private
	## one-line reading of the same profile instead of waiting on a door that was cut away.
	if game.profile == null:
		return "0"
	return game.profile.money_text()


func _print_summary() -> void:
	## [P109] THE SAVE DOORS ARE NOT HERE: `save_garden()` / `save_profile()` / `save_run()`
	## and the saved/unsaved alarm they feed belong to scripts/core/save/save_ledger.gd,
	## reached through Game's doors. `_settle_garden` (landing the battle ledger) and
	## `_set_message` (the HUD status line) likewise stayed on Game - a quit and a
	## window-close walk through the same doors, so this file only borrows them.
	var board := _board()
	if board == null:
		return
	var produces := 0
	if level_sunflower_sun > 0:
		produces = int(round(float(board.sun_from_sunflower) / float(level_sunflower_sun)))
	var income: int = level_start_sun + board.sun_from_natural + board.sun_from_sunflower + board.sun_from_debug
	var expected: int = income - board.sun_spent
	var ok: bool = expected == board.sun
	print("---------------- summary ----------------")
	print("level           : %s (%s)" % [game.level.level_name, Difficulty.label(game.difficulty_key)])
	print("rounds run      : %d" % board.rounds_run)
	print("phase           : %s" % Battle.PHASE_NAME.get(board.phase, "?"))
	print("zombies killed  : %d of %d" % [board.zombies_killed, game.level.total_zombies()])
	print("tools used      : shovel %d, glove %d, hammer %d"
		% [int(board.tools_used.get("shovel", 0)), int(board.tools_used.get("glove", 0)), int(board.tools_used.get("hammer", 0))])
	print("sun             : %d" % board.sun)
	print("  income        : start %d + natural %d + sunflower %d + debug %d = %d"
		% [level_start_sun, board.sun_from_natural, board.sun_from_sunflower, board.sun_from_debug, income])
	print("  spent         : %d" % board.sun_spent)
	print("  natural       : %d rounds x %d" % [board.rounds_run, level_sun_per_turn])
	print("  sunflower     : %d produces x %d" % [produces, level_sunflower_sun])
	print("  economy check : expected %d -> %s" % [expected, "OK" if ok else "FAIL"])
	print("brain hp        : %d/%d" % [board.brain_hp, board.brain_hp_max()])
	print("plants alive    : %d" % board.plant_total())
	print("zombies alive   : %d" % board.zombie_total())
	print("-----------------------------------------")
	print("")


# ---------------------------------------------------------------- command line door

func _apply_battle_override() -> void:
	## [P78] `godot ... -- --battle=Lawn_1_1` starts that level the moment the front-end
	## exists. It is a VERIFICATION door, not a player feature.
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if not text.begins_with("--battle="):
			continue
		var wanted := text.substr("--battle=".length()).strip_edges()
		var path := _battle_flag_path(wanted)
		if path == "":
			push_warning("[Battle] --battle=%s is not a level in %s (ignored)"
				% [wanted, Balance.LEVEL_DIR])
			return
		var was_last := SettingsStore.last_level
		print("[Battle] command line override -> " + path)
		start_level(path)
		SettingsStore.last_level = was_last
		if not SettingsStore.save_to_disk():
			push_warning("[Battle] last_level could not be put back on disk: " + was_last)
		## One battle is all a run can be, so the first flag wins and the loop ends.
		return


static func _battle_flag_path(p_wanted: String) -> String:
	## The three spellings _apply_battle_override accepts, resolved to a path that exists.
	## "" means "no such level" and the caller says so out loud.
	if p_wanted == "":
		return ""
	if p_wanted.begins_with("res://"):
		return p_wanted if FileAccess.file_exists(p_wanted) else ""
	var base := p_wanted
	if base.ends_with(".json"):
		base = base.substr(0, base.length() - 5)
	var path := "%s/%s.json" % [Balance.LEVEL_DIR, base]
	return path if FileAccess.file_exists(path) else ""
