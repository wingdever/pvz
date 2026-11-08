extends Node
class_name GameManager


## ======================= audio ===========================
const SFX := preload("res://scripts/core/sfx.gd")

## ======================= db ===========================
const ProjectileDB := preload("res://scripts/core/db/projectile_db.gd")
const DropDB := preload("res://scripts/core/db/drop_db.gd")
const RarityDB := preload("res://scripts/core/db/rarity_db.gd")
const StatusDB := preload("res://scripts/core/db/status_db.gd")

## ======================= check ===========================
const ArchCheck := preload("res://scripts/core/arch_check.gd")
const DocCheck := preload("res://scripts/core/doc_check.gd")


# ================================================================ state

## The three ledger objects. Game creates and loads them, then hands the references to
## SaveLedger. Everything else reads them through Game.
var garden: Garden = null                 # [P12] the persistent roster (= Garden.live)
var profile: Profile = null               # [P14] money + warehouse + backpack
var chapter: ChapterMap = null            # [P31-A] DATA, not a save
var run: RunState = null                  # [P31-A] SAVE; null = "no run in progress"
var run_flow: RunFlow = null              # [P36] the campaign flow object
var level: LevelData = null

## [P81] D3: the one difficulty number that outlives the level start, already carrying
## the run's mods (see _start_new_game's fold).
var difficulty_key: String = Difficulty.DEFAULT_KEY
var difficulty_zombie_hp_mult: float = Difficulty.zombie_hp_mult(Difficulty.DEFAULT_KEY)
var forced_difficulty: String = ""

## The two extracted collaborators. Both are created in _ready(); FrontEndFlow also
## needs the host scene's layers, which _bootstrap adopts into it once the scene exists.
var save: SaveLedger = null
var front: FrontEndFlow = null
var battle_main: BattleMain = null
## [B2] THE SECOND SESSION OWNER. A brawl bout is a scene too (scenes/brawl.tscn) and this is
## the object that puts it up - deliberately the same shape as battle_main, because "start a
## session / take it down / route what it reports" is one job with two implementations
## (docs/prompt/BRAWL.md §12 / D10).
var brawl_main: BrawlMain = null
## [W3] THE THIRD SESSION OWNER, the same shape one mode further along: a war match is a
## scene too (scenes/war.tscn) and this is the object that puts it up. No session state
## lives here - a war is one match (scripts/core/war/war_main.gd's header says the rest).
var war_main: WarMain = null

## The battle scene instance. Created by _start_new_game, torn down by _teardown_board.
## [P106] The board is its own scene now; this handle is the session's door onto it.
var battle: Node = null                   # [reconstructed] 名称是 Battle，避免循环 import 用 Node
## [B2] The arena instance, put up and taken down by BrawlMain. Typed Node for the same reason
## as battle above: naming Brawl here would close an import cycle. NULL BETWEEN BOUTS, and
## nothing outside BrawlMain / FrontEndFlow reads it.
var brawl: Node = null
## [W3] The war arena instance, put up and taken down by WarMain. Typed Node for the same
## reason as the two above. NULL BETWEEN MATCHES, and nothing outside WarMain / FrontEndFlow
## reads it.
var war: Node = null

## [P16] SETTINGS -> RESET GAME confirm window. Stays here: it is the session's clock.
var _reset_timer: float = 0.0
var _boot_done: bool = false
var _borderless_fallback: bool = false

## [P109] The deck page's scratch (`_battle_deck` / `_deck_pick`) moved to FrontEndFlow:
## it travels with `_pending_level_path` — the same baggage — and the page scene is built
## and freed on every visit, so the flow (not the page, not Game) holds the uncommitted
## pick. The reward LEDGER (`_reward_lines`) moved to BattleMain: the settle pipeline
## fills it, the result panel prints it.

## [P61] The backpack half of the reward report: `_settle_garden` merges the backpack
## when the board goes down, and the panel prints it beside the reward lines.
var _backpack_lines: Array[String] = []

## [P109] The shadow fields this block used to carry are DELETED, all of them never
## written since the port: `resolution_staged`, `_resolving`, `_resolve_gen`,
## `_pending_deaths`, `_drops_enabled` have live same-named fields on BATTLE (the unit
## scripts read `board.resolution_staged`, rewards.gd writes `battle._pending_deaths`),
## and `_summoned_spirits`, `_lawn_suns`, `_reward_picks` had no live reader anywhere.


# ================================================================ lifecycle

func _ready() -> void:
	SettingsStore.load_from_disk()
	_apply_language_override()            # [P20] "-- --lang=en" for one run
	UiFont.ensure_loaded()                # [P19] before anything draws text
	PlantDB.load_from_disk()
	ZombieDB.load_from_disk()
	ItemDB.load_from_disk()
	SkillDB.load_from_disk()
	EventDB.load_from_disk()
	StatusDB.load_from_disk()
	## [B2b] the brawl's formation sheets (data/brawl/*.csv): their own reader, loaded with the
	## other sheets so "the tables were read" is one habit instead of a per-mode surprise.
	FormationDB.load_from_disk()
	## [B5] the third roster (data/units/humans.csv, read through the same UnitSheet), the brawl's
	## own piece roster (data/brawl/roster.csv) and [B7] its gear sheet (data/brawl/gear.csv - the
	## augments and the equipment in one table, read by GearDB). They are read with the other
	## sheets so "the tables were read" stays one habit.
	PieceDB.load_from_disk()
	RosterDB.load_from_disk()
	GearDB.load_from_disk()
	## [D75] and the race sheet (data/units/races.csv): one row per race, naming the unit that
	## STANDS FOR it. Read at boot with the others, so a row that names nothing is reported
	## before any page asks for a default.
	RaceDB.load_from_disk()
	## [W2] the war sheets (data/war/maps.csv + data/war/waves.csv): one reader, validated at
	## read time like every other table, loaded with the others so "the tables were read"
	## stays one habit.
	WarDB.load_from_disk()
	print("[Data] " + PlantDB.status_text())
	print("[Data] " + ZombieDB.status_text())
	print("[Data] " + UnitSheet.live().status_text())   # [P29]
	print("[Data] " + ItemDB.status_text())
	print("[Data] " + SkillDB.status_text())
	print("[Data] " + EventDB.status_text())
	print("[Data] " + FormationDB.status_text())
	print("[Data] " + PieceDB.status_text())
	print("[Data] " + RosterDB.status_text())
	print("[Data] " + GearDB.status_text())
	print("[Data] " + RaceDB.status_text())
	print("[Data] " + WarDB.status_text())

	# ---- LoadSave 1: create the three ledgers ----
	garden = Garden.load_or_create()
	profile = Profile.load_or_create()
	chapter = ChapterMap.load_first()
	print("[Chapter] " + chapter.summary_text())
	run = RunState.load_or_create()
	run_flow = RunFlow.new()
	run_flow.game = self

	# ---- LoadSave 2: wire SaveLedger ----
	## SaveLedger owns the writes and the `_unsaved` fact; Game owns only the wiring
	## that turns a refusal / a landing into the player-visible message.
	save = SaveLedger.new()
	save.garden = garden
	save.profile = profile
	save.run = run
	save.write_refused.connect(_on_save_write_refused)
	save.ledger_landed.connect(_on_save_ledger_landed)

	garden.profile = profile
	garden.save = save

	# ---- LoadSave 3: create FrontEndFlow ----
	## The host scene's two CanvasLayers are adopted in _bootstrap once current_scene
	## exists; FrontEndFlow starts with them null and _bring_up() bails loudly if a page
	## is asked to open before adoption.
	front = FrontEndFlow.new()
	front.game = self

	battle_main = BattleMain.new()
	battle_main.game = self

	brawl_main = BrawlMain.new()
	brawl_main.game = self

	## [W3] the war's owner, same door as the other two session owners.
	war_main = WarMain.new()
	war_main.game = self

	_apply_window_policy()
	_apply_display_settings()
	_bootstrap.call_deferred()


func _notification(what: int) -> void:
	## [P12] Closing the window counts as settling the battle: the wounds earned in
	## it belong to the garden, otherwise alt-F4 would be a free heal. R (restart)
	## is the one key that rolls the garden back, and it does so by not settling.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_settle_garden("window closed")


func _process(delta: float) -> void:
	## [P106] Only the SESSION's clock ticks here: the reset confirmation belongs to the
	## settings page. The message line and the retreat confirmation moved to the board.
	if _reset_timer > 0.0:
		_reset_timer -= delta
		if _reset_timer <= 0.0:
			_reset_timer = 0.0
			if front != null and front.screen == front.Screen.SETTINGS:
				front.refresh_page()


func _unhandled_input(event: InputEvent) -> void:
	if not _boot_done:
		return
	## [P89] A SUN IS PICKED UP BEFORE THE LAWN SEES THE CLICK. Game is an autoload and
	## sits ahead of the main scene, so its _unhandled_input runs first.
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11:
		set_fullscreen(not SettingsStore.fullscreen)
		get_viewport().set_input_as_handled()
		return
	## [P106] The in-game keys live on the BOARD now (battle.gd `_input`). What is left
	## here is the session: F11 above, and the front-end's own L / ESC below.
	## [B2] A live brawl bout keeps the in-game keys to itself for the same reason a battle
	## does: the arena's own _input() handles ESC / SPACE / F / R and marks them handled.
	## [W3] So does a live war match - and its camera adds ctrl-gestures and +/- on top, all
	## answered below the front end's notice for the same reason.
	if front != null and (front.screen == front.Screen.GAME or front.screen == front.Screen.BRAWL
			or front.screen == front.Screen.WAR):
		return
	# Front-end: the in-game keys must stay silent here.
	## [P31-A] L opens the level list.
	if key.keycode == KEY_L:
		show_level_select()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE:
		## [P22]/[P26] The four screens that are their own view all leave the same way.
		if front.screen == front.Screen.GARDEN or front.screen == front.Screen.WAREHOUSE \
				or front.screen == front.Screen.SHOP or front.screen == front.Screen.BACKPACK \
				or front.screen == front.Screen.ALMANAC \
				or front.screen == front.Screen.BRAWL_ALMANAC:
			back_from_front_end()
			get_viewport().set_input_as_handled()
		elif front.screen == front.Screen.RUN_SQUAD or front.screen == front.Screen.RUN_MAP:
			show_main_menu()
			get_viewport().set_input_as_handled()
		elif front.screen == front.Screen.DECK:
			## [P32] the deck page's ESC returns to the list.
			show_level_select()
			get_viewport().set_input_as_handled()
		elif front.screen == front.Screen.RUN_NODE or front.screen == front.Screen.RUN_REWARD \
				or front.screen == front.Screen.RUN_END:
			## A node page, the reward and the end screen each END by their own button.
			get_viewport().set_input_as_handled()
		elif front.screen == front.Screen.BRAWL_ROUND or front.screen == front.Screen.BRAWL_FORMATION:
			## [B2b] ESC on the brawl's round page ENDS THE SESSION (D17: nothing was ever
			## written down, so there is nothing to unwind) and returns to the classic menu.
			brawl_main.leave_session()
			get_viewport().set_input_as_handled()
		elif front.screen == front.Screen.WAR_FORMATION:
			## [W4] ESC on the war's deployment table drops the rows (nothing was ever written
			## down - the same D17 promise the brawl's pages run on) and returns to the menu.
			war_main.leave_formation()
			get_viewport().set_input_as_handled()
		elif front.screen == front.Screen.SETTINGS or front.screen == front.Screen.LEVEL_SELECT:
			back_from_front_end()
			get_viewport().set_input_as_handled()
	return


# ================================================================ boot

func _apply_window_policy() -> void:
	## [P9] The window stretch policy is applied at RUNTIME, not only through project.godot.
	var win := get_window()
	if win == null:
		return
	win.content_scale_size = Balance.WINDOW_SIZE
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	win.min_size = Balance.MIN_WINDOW_SIZE
	print("[Layout] window policy: canvas_items + expand + fractional  design "
		+ str(Balance.WINDOW_SIZE) + "  min " + str(Balance.MIN_WINDOW_SIZE))
	print("[Settings] display server: " + DisplayServer.get_name()
		+ "   running from the editor: " + str(OS.has_feature("editor")))


func _window_size() -> Vector2i:
	var win := get_window()
	return win.size if win != null else Vector2i.ZERO


# ---------------------------------------------------------------- display settings (P10)
func _apply_display_settings() -> void:
	var win := get_window()
	if win == null:
		return
	if SettingsStore.fullscreen:
		win.mode = Window.MODE_FULLSCREEN
		_borderless_fallback = false
	else:
		win.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		win.size = SettingsStore.window_size
		_borderless_fallback = false
	print("[Settings] display -> " + SettingsStore.summary_text())
	_report_window_mode.call_deferred()


func _report_window_mode() -> void:
	var win := get_window()
	if win == null:
		return
	var wanted: int = Window.MODE_FULLSCREEN if SettingsStore.fullscreen else Window.MODE_WINDOWED
	if win.mode == wanted:
		print("[Settings] window mode OK: " + SettingsStore.mode_text(win.mode))
		if front != null:
			front.refresh_settings_screen()
		return
	print("[Settings] window mode REFUSED: asked " + SettingsStore.mode_text(wanted)
		+ ", got " + SettingsStore.mode_text(win.mode))
	if OS.has_feature("editor"):
		print("[Settings]   the game is running inside the editor, and a game embedded in the")
		print("[Settings]   Game panel cannot go fullscreen. Make that panel floating, or run")
		print("[Settings]   the project in its own window.")
		if front != null:
			front.refresh_settings_screen()
		return
	if not SettingsStore.fullscreen:
		if front != null:
			front.refresh_settings_screen()
		return
	_borderless_fallback = true
	win.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	win.size = DisplayServer.screen_get_size()
	win.position = Vector2i.ZERO
	print("[Settings] falling back to a borderless window at " + str(DisplayServer.screen_get_size()))
	print("[Settings] (F11, or SETTINGS -> FULLSCREEN: OFF, brings the title bar back)")
	if front != null:
		front.refresh_settings_screen()


func display_status_text() -> String:
	var win := get_window()
	if win == null:
		return Loc.t("msg.display.unknown")
	if _borderless_fallback:
		return Loc.t("msg.display.borderless")
	return Loc.tf("msg.display.mode", [_window_mode_name(win.mode)])


func _window_mode_name(p_mode: int) -> String:
	match p_mode:
		Window.MODE_FULLSCREEN:            return Loc.t("msg.display.fullscreen")
		Window.MODE_EXCLUSIVE_FULLSCREEN:  return Loc.t("msg.display.exclusive_fullscreen")
		Window.MODE_MAXIMIZED:             return Loc.t("msg.display.maximized")
		Window.MODE_MINIMIZED:             return Loc.t("msg.display.minimized")
	return Loc.t("msg.display.windowed")


func set_fullscreen(p_on: bool) -> void:
	SettingsStore.set_fullscreen(p_on)
	_apply_display_settings()
	if front != null:
		front.refresh_settings_screen()


func set_window_size(p_size: Vector2i) -> void:
	SettingsStore.set_window_size(p_size)
	_apply_display_settings()
	if front != null:
		front.refresh_settings_screen()


# ---------------------------------------------------------------- music (P21)
func _apply_audio_settings() -> void:
	Music.set_enabled(SettingsStore.music_on)
	Music.set_volume(SettingsStore.music_volume)
	SFX.set_enabled(SettingsStore.sfx_on)
	SFX.set_volume(SettingsStore.sfx_volume)
	print("[Music] " + Music.status_text())
	print("[Sfx] " + SFX.status_text())


func toggle_music() -> void:
	SettingsStore.set_music_on(not SettingsStore.music_on)
	Music.set_enabled(SettingsStore.music_on)
	if front != null:
		front.refresh_settings_screen()
	print("[Music] " + Music.status_text())


func cycle_music_volume() -> void:
	SettingsStore.set_music_volume(BalanceAudio.next_music_volume(SettingsStore.music_volume))
	Music.set_volume(SettingsStore.music_volume)
	if front != null:
		front.refresh_settings_screen()
	print("[Music] " + Music.status_text())


func music_button_text() -> String:
	return Loc.t("menu.settings.music_on" if SettingsStore.music_on else "menu.settings.music_off")


func music_volume_text() -> String:
	return Loc.tf("menu.settings.music_volume", [Music.volume_percent()])


# ---------------------------------------------------------------- sfx (P50)
func toggle_sfx() -> void:
	SettingsStore.set_sfx_on(not SettingsStore.sfx_on)
	SFX.set_enabled(SettingsStore.sfx_on)
	if front != null:
		front.refresh_settings_screen()
	print("[Sfx] " + SFX.status_text())


func cycle_sfx_volume() -> void:
	SettingsStore.set_sfx_volume(BalanceAudio.next_sfx_volume(SettingsStore.sfx_volume))
	SFX.set_volume(SettingsStore.sfx_volume)
	if front != null:
		front.refresh_settings_screen()
	print("[Sfx] " + SFX.status_text())


func sfx_button_text() -> String:
	return Loc.t("menu.settings.sfx_on" if SettingsStore.sfx_on else "menu.settings.sfx_off")


func sfx_volume_text() -> String:
	return Loc.tf("menu.settings.sfx_volume", [SFX.volume_percent()])


func quit_game() -> void:
	_settle_garden("quit")
	Music.stop(0.0)
	print("[Menu] quit")
	get_tree().quit()


func _apply_language_override() -> void:
	## [P20] `godot ... -- --lang=en` starts one run in that language WITHOUT touching
	## the saved settings.
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--lang="):
			var code := text.substr("--lang=".length())
			for known in Loc.ORDER:
				if code == known:
					Loc.set_language(code)
					print("[Loc] command line override -> " + code)


static func _battle_flag_path(p_wanted: String) -> String:
	## The three spellings _apply_battle_override accepts.
	if p_wanted == "":
		return ""
	if p_wanted.begins_with("res://"):
		return p_wanted if FileAccess.file_exists(p_wanted) else ""
	var base := p_wanted
	if base.ends_with(".json"):
		base = base.substr(0, base.length() - 5)
	var path := "%s/%s.json" % [Balance.LEVEL_DIR, base]
	return path if FileAccess.file_exists(path) else ""


func _is_part_preview(p_scene: Node) -> bool:
	## [P28] True when the run was started with a PART scene instead of the game.
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--preview":
			return true
	if p_scene == null:
		return false
	return p_scene.scene_file_path.get_file().ends_with("_view.tscn")


func _bootstrap() -> void:
	var frames := 0
	while get_tree().current_scene == null and frames < 120:
		await get_tree().process_frame
		frames += 1

	var scene := get_tree().current_scene
	if scene == null:
		push_error("[Game] current_scene is still null after %d frames; grid not created." % frames)
		return

	# P9: settle the responsive geometry before the grid and the HUD read it
	Layout.refresh(get_viewport().get_visible_rect().size, _window_size())
	UiFont.apply_to_window(get_window())

	## [P28] F6 on a part scene: show the PART.
	if _is_part_preview(scene):
		print("[Preview] part scene, front-end skipped: " + scene.scene_file_path)
		return

	print("[Font] UI text: " + UiFont.status_text())
	Music.setup(scene)
	SFX.setup(scene)
	_apply_audio_settings()

	# ---------------- self-checks ----------------
	Loc.self_check()
	SelfChecks.self_check()
	Layout.self_check()
	LevelList.self_check()
	PlantDB.self_check()
	ZombieDB.self_check()
	ItemDB.self_check()
	DropDB.self_check()
	RarityDB.self_check(Balance.RARITY_ORDER)
	ArchCheck.self_check()
	DocCheck.self_check()
	SkillDB.self_check()
	EventDB.self_check()
	UnitArt.self_check()
	Music.self_check()
	SFX.self_check()
	UiStyle.self_check()
	Fx.self_check()
	ItemGrid.self_check()
	GardenView.self_check()
	AlmanacView.self_check()
	DeckView.self_check()
	Garden.self_check()
	Profile.self_check()
	ChapterMap.self_check()
	RunState.self_check()
	Difficulty.self_check()
	SettingsStore.self_check()
	SelfChecks.persist(self)              # [P65] A3: the 3 ledgers' door
	SelfChecks.recover(self)              # [P66] A4: the clock's door
	SelfChecks.item_rows(self)            # [P74] C5: the three item-row shapes
	StatusDB.self_check()
	ProjectileDB.self_check()

	# ---------------- adopt the host shell ----------------
	## [P107d] THE SHELL IS DECLARED BY THE HOST SCENE, NOT BUILT HERE. scenes/main.tscn
	## owns the two CanvasLayers; this ADOPTS them into FrontEndFlow.
	front.menu_layer = scene.get_node_or_null("MenuLayer") as CanvasLayer
	front.garden_layer = scene.get_node_or_null("GardenLayer") as CanvasLayer
	if front.menu_layer == null or front.garden_layer == null:
		push_error("[Shell] scenes/main.tscn must declare MenuLayer(20) and GardenLayer(20)")
		return

	# ---------------- viewport resize ----------------
	## The callback is now a BOUND method on the FrontEndFlow instance (it was a static
	## method on the ScreenFlow script before the cut).
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(front.on_viewport_resized):
		vp.size_changed.connect(front.on_viewport_resized)

	level = LevelData.new()
	_boot_done = true
	print("front-end: main menu (levels are discovered in %s)" % Balance.LEVEL_DIR)
	show_main_menu()
	## [P64] The one self-check that runs AFTER the front-end exists: the data modules
	## only need tables, but this one walks the real page switches.
	front.self_check()


# ================================================================ screens (P10)
## [P64]/[P109] The bodies moved to FrontEndFlow; these stay as entry points because
## "Game is the one owner of which screen is up" is a [P12] design rule. The UI asks
## GAME for a page; FrontEndFlow decides HOW. Each page's own explanation travelled
## with its body.

func show_main_menu() -> void:
	front.open_main_menu()


func show_level_select() -> void:
	front.open_level_select()


func apply_language() -> void:
	## [B2c] THE DOOR THAT WAS MISSING. Five call sites (the settings page after every toggle, the
	## menu host after a language switch) already said game.apply_language(), but the method only
	## ever existed on FrontEndFlow - so each of those clicks saved its setting and then died on
	## the relabel with "Invalid call to function 'apply_language' in base 'Node (GameManager)'".
	## The forwarder is one line, and it is the shape every other door in this block has.
	front.apply_language()


func show_brawl_round() -> void:
	## [B2b] The brawl's round page (offers / result). It is a door like the others even though
	## BrawlMain is its only caller: "the UI asks GAME for a page; FrontEndFlow decides HOW" stays
	## one rule instead of an exception per mode.
	front.open_brawl_round()


func show_brawl_formation() -> void:
	## [B2c] The brawl's formation page (the player's half + their roster). Same rule as above.
	front.open_brawl_formation()


func show_settings() -> void:
	front.open_settings()


func show_garden() -> void:
	front.open_garden()


func show_warehouse() -> void:
	front.open_warehouse()


func show_backpack() -> void:
	front.open_backpack()


func show_almanac() -> void:
	front.open_almanac()


func show_brawl_almanac() -> void:
	## [D75] The classic mode's almanac: the same door shape as show_almanac() above, a different
	## page (scripts/ui/brawl/brawl_almanac.gd reads the classic mode's sheets).
	front.open_brawl_almanac()


func show_shop() -> void:
	front.open_shop()


func show_settings_overlay() -> void:
	front.open_settings_overlay()


func show_deck_select(p_path: String) -> void:
	front.open_deck_select(p_path)


func back_from_front_end() -> void:
	## [P13] The single entry point for every BACK button and ESC in the front-end.
	front.back()


func pick_level(p_path: String) -> void:
	if p_path == "":
		return
	show_deck_select(p_path)


# ================================================================ save (P65 / A3)
## The three doors. Every write reaches the disk through one of these and nowhere
## else; the ledger object behind them is the fact owner. The 40 call sites keep
## calling `game.save_garden()` / `save_profile()` / `save_run()` unchanged.

func save_garden() -> void:
	save.save_garden()


func save_profile() -> void:
	save.save_profile()


func save_run() -> void:
	save.save_run()


func _on_save_write_refused(_ledger: String) -> void:
	## [P65] An EMPTY base line: the appended note IS the message.
	_set_message("")


func _on_save_ledger_landed(_ledger: String) -> void:
	## The save alarm rides on EVERY status line; which lines are unsaved is Game's
	## fact (it owns the ledgers through SaveLedger).
	_sync_unsaved_note()


func _sync_unsaved_note() -> void:
	if battle != null:
		battle.set_unsaved_note(Loc.t("msg.save.alarm") if save.is_dirty() else "")


# ================================================================ reset game
func is_reset_armed() -> bool:
	return _reset_timer > 0.0


func request_reset() -> void:
	## [P16] SETTINGS -> RESET GAME. Two clicks, because it wipes the whole save and
	## there is no undo. [P37] The debug key N comes through here too.
	if _reset_timer <= 0.0:
		_reset_timer = Balance.RESET_CONFIRM_TIME
		_set_message(Loc.t("msg.reset.confirm"))
		if front != null:
			front.refresh_page()
		return
	_reset_timer = 0.0
	reset_progress()


func reset_progress() -> void:
	## [P16] Wipe the meta progression on purpose so the new-player experience can be
	## seen again. DISPLAY settings are kept.
	var had_battle: bool = battle != null and not battle.garden_settled()
	_discard_battle_without_settling()
	SettingsStore.reset_progress()
	garden.apply_defaults()
	## [P65] The one site where a refused write is the FRIENDLY kind.
	save_garden()
	if profile != null:
		profile.apply_defaults()
		save_profile()
	## [P36] The run pages' scratch is RunFlow's.
	run_flow.clear_page_state()
	## The run SAVE is deliberately NOT cleared here - ending a run is still only
	## _close_run_end's job.
	print("---------- progress reset (garden / money / items / first clears) ----------")
	print("[Reset] " + garden.summary_text())
	if profile != null:
		print("[Reset] " + profile.summary_text())
	if had_battle or (front != null and front.screen == front.Screen.GAME):
		show_main_menu()
	elif front != null:
		front.refresh_page()


func _discard_battle_without_settling() -> void:
	## Reset must NOT settle the running battle. [P106] Dropping the BOARD does that
	## by itself - the ledger dies with the scene.
	if battle != null:
		battle.cancel()
		battle.queue_free()
		battle = null


# ================================================================ garden settle (P106)
func _settle_garden(p_reason: String) -> void:
	## The battle ledger lands in the roster. Called when a battle really ends:
	## WIN / LOSE, leaving to the front-end, quitting, and closing the window.
	## R (restart) never calls this, so it rolls the garden back.
	if garden == null:
		return
	var ledger: Dictionary = battle.settle_ledger() if battle != null else {}
	print("[Garden] --- battle settled (" + p_reason + ") ---")
	if ledger.is_empty():
		print("[Garden] no garden plants were out on the lawn: nothing to write back")
	else:
		var lines: Array[String] = garden.apply_results(ledger)
		for line in lines:
			print("[Garden] " + line)
		save_garden()
		print("[Garden] " + garden.summary_text())
	# [P14] the backpack is a battle-only pocket.
	if profile != null:
		_backpack_lines = profile.merge_backpack_into_warehouse()
		if not _backpack_lines.is_empty():
			var moved: PackedStringArray = []
			for line in _backpack_lines:
				moved.append(line)
			print("[Backpack] moved to the warehouse: " + ", ".join(moved))
		save_profile()


# ================================================================ data helpers
func backpack_total() -> int:
	## [P107] The FACT is Profile's; this and Battle's copy are two doors onto the same
	## profile, which is why the [Arch] boundary check allows the name on both sides.
	if profile == null:
		return 0
	return profile.backpack_total()


func backpack_kinds() -> int:
	if profile == null:
		return 0
	var kinds := 0
	for id in Balance.ITEM_ORDER:
		if profile.count_of(str(id), Profile.CONTAINER_BACKPACK) > 0:
			kinds += 1
	return kinds


func scroll_text_for(plant_id: String) -> String:
	if not profile.has_scroll_for(plant_id):
		return Loc.t("msg.scroll.none")
	var item := Balance.scroll_item_for(plant_id)
	return Loc.tf("msg.scroll.state", [profile.durability_text(item)])


func garden_state_text() -> String:
	if garden == null:
		return Loc.t("msg.garden.state_none")
	return Loc.tf("msg.garden.state", [garden.total(), garden.wounded_count(), garden.downed_count()])


func backpack_text() -> String:
	if profile == null or profile.backpack_total() <= 0:
		return Loc.t("msg.backpack.empty")
	return profile.backpack_text()


# ================================================================ internal
## [reconstructed] `_set_message` was not shown in the file you pasted; the slices
## (save.gd, ScreenFlow) both call it, so it stays here as the session's status-line door.
func _set_message(p_text: String) -> void:
	if battle != null:
		battle.hud.set_message(p_text)


## [reconstructed] Used by resume_battle in FrontEndFlow.
func _update_battle_music() -> void:
	if battle != null and battle.has_method("update_music"):
		battle.update_music()
