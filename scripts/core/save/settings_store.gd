class_name SettingsStore
extends RefCounted
## [P10] Persisted display settings + a little progress, kept in user://.
##
## Deliberately NOT in project.godot: the editor rewrites that file from its own
## in-memory settings and silently reverts outside edits (docs/HANDOFF.md 7.15).
## user:// belongs to the game, so it survives.
##
## The window size is stored as two plain ints on purpose - a ConfigFile value is
## written through the Variant serialiser and ints are the one thing that never
## surprises anyone.

const SECTION_WINDOW := "window"
const SECTION_PROGRESS := "progress"
const SECTION_DISPLAY := "display"
const SECTION_AUDIO := "audio"           # [P21] music + [P50] sound effects: on/off + volume
## [P89] HOW THE BATTLE PLAYS, as opposed to how it looks or sounds: today the two sun
## collecting choices. Its own section so a future rule has somewhere to go that is not
## [display].
const SECTION_BATTLE := "battle"
## [P107] Which almanac tab the player left the page on. A page is FREED when it is left, so
## anything that should survive it has to live in a save file - this is the one piece of page
## state that earns that (settings.cfg), because losing your place in the 图鉴 is annoying.
const SECTION_UI := "ui"
## [B2] THE TWO SHELLS of the front end (docs/prompt/BRAWL.md §10 / D20): the turn-based game
## and the classic real-time one. The TOKENS live here because this file owns the settings.cfg
## key that stores one - a second spelling of "classic" anywhere else would be a second
## vocabulary for the same fact.
const SHELL_TURN := "turn"
const SHELL_CLASSIC := "classic"

## [P56] The one writer/reader of "never a half file" (see scripts/core/safe_io.gd).
## Preloaded under a local name rather than given a class_name, for HANDOFF 7.67's reason.
const SafeIO := preload("res://scripts/core/save/safe_io.gd")
## [P56] Where self_check() practises on a save file it does not own. The probe creates
## and deletes this on every boot; the player's real settings.cfg is never written by it.
const PROBE_PATH := "user://settings_probe.cfg"
## [P56] The marker value the probe writes and expects back. A level id shape on purpose:
## it goes through the same `cleared` array serialisation the real ones do.
const PROBE_KEY := "Probe_9_9"

static var window_size := Vector2i(Balance.WINDOW_SIZE)
static var fullscreen := false
## [P20] Persisted language code ("zh" / "en"). It is stored here rather than in
## Loc so a hand-edited settings file cannot leave the game with no language:
## load_from_disk() normalises whatever it reads.
static var language := Loc.DEFAULT_LANGUAGE
## [P21] Music. Same defensive rule as the language: whatever the file says is
## clamped/normalised here, so a hand-edited value can never leave the game with an
## unusable volume. Music OFF is a saved choice, not a per-run mute.
static var music_on := true
static var music_volume := BalanceAudio.MUSIC_VOLUME_DEFAULT
## [P50] The SAME rule for the cues: two more keys of the same [audio] section, clamped
## on the way in, and a switch that is a saved choice rather than a per-run mute. Music
## and SFX are separate on purpose - a player who wants the theme out of the way may
## still want to hear the melon land.
static var sfx_on := true
static var sfx_volume := BalanceAudio.SFX_VOLUME_DEFAULT
## [P89] The sun collecting choices. Both are SAVED (not per-run): whether a landed sun
## gathers itself, and after how many ROUNDS. The default asks the auto-collect to do the
## job after two rounds, because a sun nobody picks up is income nobody gets and the
## setting exists precisely to be turned off.
static var auto_collect_sun := true
static var sun_auto_rounds := BalanceBattle.SUN_AUTO_ROUNDS_DEFAULT
## [B2c] Whether the formation page shows WHAT the enemy's pieces are, or only that a slot is
## taken. A formation's size, strength and reward are on the page either way (D34) - this switch
## is about the UNITS ("can I see which one stands on that cell"), and it is a design lever as
## much as a convenience: a player who can read the enemy line-up picks a counter, one who cannot
## picks a plan. Default ON, which is exactly what the page did before the switch existed.
## The ARENA ignores it on purpose - a fight is watched, not read.
static var show_enemy_pieces := true
## [B21] THE FRIENDLY FIRE SWITCH, saved with the other [battle] choices. ON (the default)
## means a brawl shot's damage can reach its OWN side: a shell's blast clips allied bodies the
## same way it clips enemies, and a straight or homing shot that physically meets an ally pays
## for it like any other body in the road. The shooter's OWN body is never the victim of its own
## shot (a gun does not hit the platform that fired it), and aiming still only looks for enemies -
## this switch changes what a shot can HURT, not what a shooter will TARGET. OFF restores the old
## rule exactly: same-side bodies are ghosts to every shot.
static var friendly_fire := true
static var last_level := ""
static var cleared: Dictionary = {}      # level id -> true
## [P93] level id -> true once the player has OPENED that level's first-clear chest. A
## first clear no longer pays on the spot (it leaves a chest beside the level), so "has
## been cleared" and "has been paid for" are two different facts and need two maps.
static var claimed: Dictionary = {}
## [P107] the almanac tab (see SECTION_UI)
static var almanac_tab := 0
## [D75] and the CLASSIC almanac's own tab: the two pages' tabs mean different things (the turn
## one's third tab is the level pack, the classic one's is the enemy formations), so sharing one
## cell would make leaving one page move the other. Same rule, same file, one key further down.
static var brawl_almanac_tab := 0
## [B2] which shell the main menu is showing (see SHELL_TURN / SHELL_CLASSIC). Defaults to the
## turn shell, which is the game as it has always been - the classic shell is opt-in.
static var ui_shell := SHELL_TURN
## [W11] Whether the WAR mode draws its grid lattice - the deployment table and the battlefield
## both read this one switch (one generator, two grounds: WarField.for_each_grid_segment).
## A display choice, saved in [ui] with the tab memories; default ON is exactly what both
## screens did before the switch existed.
static var war_grid := true
static var loaded := false


static func load_from_disk(p_path: String = Balance.SETTINGS_PATH) -> void:
	loaded = true
	var cfg := ConfigFile.new()
	var err := cfg.load(p_path)
	if err != OK:
		## [P56] Two very different situations used to print the same reassuring line.
		## No file at all IS a first launch. A file that is THERE but will not parse is a
		## damaged save, and the defaults now in memory are one keystroke away from
		## overwriting it: `set_last_level()` runs the moment any level is entered, and
		## `mark_cleared()` after the first win - so the cleared-level list is buried
		## within seconds of anything looking wrong. Park the bytes first, the same rule
		## profile / garden / run have had since P37 (OPTIMIZATIONS A1).
		if not FileAccess.file_exists(p_path):
			print("[Settings] no settings file yet (" + p_path + ") -> defaults")
			return
		## The severity follows the outcome, not the event: damage that was parked is a
		## recoverable fact and prints, damage that could NOT be parked is the incident.
		## It also keeps a deliberate probe of this path out of the warning channel, which
		## the boot log counts.
		if SafeIO.keep_broken(p_path):
			print("[Settings] %s will not parse (error %d), parked as %s.bak -> defaults"
				% [p_path, err, p_path])
		else:
			push_warning("[Settings] %s will not parse (error %d) and could NOT be parked"
				% [p_path, err])
		return
	window_size = Vector2i(int(cfg.get_value(SECTION_WINDOW, "width", Balance.WINDOW_SIZE.x)),
		int(cfg.get_value(SECTION_WINDOW, "height", Balance.WINDOW_SIZE.y)))
	fullscreen = bool(cfg.get_value(SECTION_WINDOW, "fullscreen", false))
	last_level = str(cfg.get_value(SECTION_PROGRESS, "last_level", ""))
	## [P20] the language is applied here so every screen built afterwards is
	## already in the right language, and the font has not loaded yet - that only
	## decides whether Chinese can be DRAWN, not which language is selected.
	language = Loc.normalize(str(cfg.get_value(SECTION_DISPLAY, "language", Loc.DEFAULT_LANGUAGE)))
	Loc.set_language(language)
	## [P21] the music choice is only READ here: Music pushes it into its players in
	## Game._apply_audio_settings(), because the players need the scene to exist.
	music_on = bool(cfg.get_value(SECTION_AUDIO, "music", true))
	music_volume = clampf(float(cfg.get_value(SECTION_AUDIO, "volume", BalanceAudio.MUSIC_VOLUME_DEFAULT)), 0.0, 1.0)
	sfx_on = bool(cfg.get_value(SECTION_AUDIO, "sfx", true))
	sfx_volume = clampf(float(cfg.get_value(SECTION_AUDIO, "sfx_volume", BalanceAudio.SFX_VOLUME_DEFAULT)), 0.0, 1.0)
	## [P89] The battle section: normalised on the way in, like every other setting (a
	## hand-edited file must not leave the game waiting 999 rounds for a sun).
	auto_collect_sun = bool(cfg.get_value(SECTION_BATTLE, "auto_collect_sun", true))
	show_enemy_pieces = bool(cfg.get_value(SECTION_BATTLE, "show_enemy_pieces", true))
	friendly_fire = bool(cfg.get_value(SECTION_BATTLE, "friendly_fire", true))
	almanac_tab = maxi(0, int(cfg.get_value(SECTION_UI, "almanac_tab", 0)))
	brawl_almanac_tab = maxi(0, int(cfg.get_value(SECTION_UI, "brawl_almanac_tab", 0)))
	ui_shell = _normalise_shell(str(cfg.get_value(SECTION_UI, "shell", SHELL_TURN)))
	war_grid = bool(cfg.get_value(SECTION_UI, "war_grid", true))
	sun_auto_rounds = maxi(1, int(cfg.get_value(SECTION_BATTLE, "sun_auto_rounds",
		BalanceBattle.SUN_AUTO_ROUNDS_DEFAULT)))
	cleared = {}
	claimed = {}
	var raw: Variant = cfg.get_value(SECTION_PROGRESS, "cleared", [])
	if typeof(raw) == TYPE_ARRAY:
		for id in (raw as Array):
			cleared[str(id)] = true
	## [P93] and the chests already opened, on the same rule: whatever the file says is
	## normalised here, so a hand-edited save cannot make a level claimable twice.
	var raw_claimed: Variant = cfg.get_value(SECTION_PROGRESS, "claimed", [])
	if typeof(raw_claimed) == TYPE_ARRAY:
		for id in (raw_claimed as Array):
			claimed[str(id)] = true
	print("[Settings] loaded " + p_path)
	print("[Settings] " + summary_text())


static func save_to_disk(p_path: String = Balance.SETTINGS_PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_WINDOW, "width", window_size.x)
	cfg.set_value(SECTION_WINDOW, "height", window_size.y)
	cfg.set_value(SECTION_WINDOW, "fullscreen", fullscreen)
	cfg.set_value(SECTION_DISPLAY, "language", language)
	cfg.set_value(SECTION_AUDIO, "music", music_on)
	cfg.set_value(SECTION_AUDIO, "volume", music_volume)
	cfg.set_value(SECTION_AUDIO, "sfx", sfx_on)
	cfg.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION_UI, "almanac_tab", almanac_tab)
	cfg.set_value(SECTION_UI, "brawl_almanac_tab", brawl_almanac_tab)
	cfg.set_value(SECTION_UI, "shell", ui_shell)
	cfg.set_value(SECTION_UI, "war_grid", war_grid)
	cfg.set_value(SECTION_BATTLE, "auto_collect_sun", auto_collect_sun)
	cfg.set_value(SECTION_BATTLE, "show_enemy_pieces", show_enemy_pieces)
	cfg.set_value(SECTION_BATTLE, "friendly_fire", friendly_fire)
	cfg.set_value(SECTION_BATTLE, "sun_auto_rounds", sun_auto_rounds)
	cfg.set_value(SECTION_PROGRESS, "last_level", last_level)
	var ids: Array = cleared.keys()
	ids.sort()
	cfg.set_value(SECTION_PROGRESS, "cleared", ids)
	cfg.set_value(SECTION_PROGRESS, "claimed", claimed.keys())
	## [P56] Through SafeIO, like the three JSON saves. This file used to carry its own
	## copy of "write a .tmp, then rename it" because ConfigFile cannot go through
	## write_text_atomic() - the rule was the same, only the writer differed, and that is
	## how it ended up protected by half of the safety net (no keep_broken on the read
	## side, and a rule that would have had to be changed twice).
	return SafeIO.write_config_atomic(cfg, p_path)


# ---------------------------------------------------------------- window
static func set_almanac_tab(p_index: int) -> void:
	## [P107] Remember the almanac tab. Clamped here so a hand-edited settings.cfg cannot put the
	## page on a tab that does not exist.
	almanac_tab = clampi(p_index, 0, BalanceUI.ALMANAC_TAB_COUNT - 1)
	save_to_disk()


static func set_brawl_almanac_tab(p_index: int) -> void:
	## [D75] ...and the classic almanac's, on the same rule and the same clamp (the two pages
	## have the same number of tabs - BalanceUI.ALMANAC_TAB_COUNT - and different words for them).
	brawl_almanac_tab = clampi(p_index, 0, BalanceUI.ALMANAC_TAB_COUNT - 1)
	save_to_disk()


static func set_show_enemy_pieces(p_on: bool) -> void:
	## [B2c] The brawl's enemy-visibility switch, saved with the other [battle] choices so it
	## survives a restart like every other setting.
	show_enemy_pieces = p_on
	save_to_disk()


static func set_friendly_fire(p_on: bool) -> void:
	## [B21] The friendly fire switch, on the same [battle] footing as the two above. Shots
	## capture the value at LAUNCH (BrawlShot.launch), so flipping it mid-bout never makes one
	## shell obey two different rules on its way.
	friendly_fire = p_on
	save_to_disk()


static func set_ui_shell(p_shell: String) -> void:
	## [B2] Remember which shell the main menu shows. Normalised through the SAME door the
	## loader uses, so a hand-edited settings.cfg and a click can never disagree.
	ui_shell = _normalise_shell(p_shell)
	save_to_disk()


static func set_war_grid(p_on: bool) -> void:
	## [W11] The war lattice switch, saved with the other [ui] page preferences. Both war
	## screens re-read the variable when they open next; neither holds a copy that could
	## go stale, so one click is honest the whole way down.
	war_grid = p_on
	save_to_disk()


static func flipped_shell() -> String:
	## The other shell - what the switcher asks for, so the menu never has to spell the pair
	## out and a third shell later has exactly one place to join.
	return SHELL_CLASSIC if ui_shell == SHELL_TURN else SHELL_TURN


static func _normalise_shell(p_shell: String) -> String:
	## Anything that is not the classic shell IS the turn shell: an unknown token in a
	## hand-edited file must not be able to strand the player in a shell that does not exist
	## (the same rule the language code and the almanac tab already obey).
	return p_shell if p_shell == SHELL_CLASSIC else SHELL_TURN


static func set_window_size(p_size: Vector2i) -> void:
	window_size = p_size
	save_to_disk()


static func set_fullscreen(p_on: bool) -> void:
	fullscreen = p_on
	save_to_disk()


# ---------------------------------------------------------------- language (P20)
static func set_language(p_code: String) -> bool:
	## Persist a new language and put Loc in sync with it. Returns true when the
	## language really changed, which is what tells Game to re-draw the UI.
	language = Loc.normalize(p_code)
	var changed := Loc.set_language(language)
	save_to_disk()
	return changed


# ---------------------------------------------------------------- audio (P21)
static func set_music_on(p_on: bool) -> void:
	## Persist the music switch. The caller (Game) pushes it into Music afterwards:
	## this class deliberately knows nothing about the audio players.
	if music_on == p_on:
		return
	music_on = p_on
	save_to_disk()


static func set_music_volume(p_linear: float) -> void:
	music_volume = clampf(p_linear, 0.0, 1.0)
	save_to_disk()


# ---------------------------------------------------------------- sfx (P50)
static func set_sfx_on(p_on: bool) -> void:
	## Persist the SFX switch; Game pushes it into Sfx, exactly as it does for music.
	if sfx_on == p_on:
		return
	sfx_on = p_on
	save_to_disk()


static func set_sfx_volume(p_linear: float) -> void:
	## 0 is a legal value here (the last step of BalanceAudio.SFX_VOLUME_STEPS), so the knob
	## alone can silence the cues without touching the switch.
	sfx_volume = clampf(p_linear, 0.0, 1.0)
	save_to_disk()


# ---------------------------------------------------------------- progress
static func set_last_level(p_id: String) -> void:
	if last_level == p_id:
		return
	last_level = p_id
	save_to_disk()


## [P89] THE TWO SUN COLLECTING CHOICES. Both are saved, because a player who wants the
## lawn to tidy itself should not have to answer that again every session.
static func set_auto_collect_sun(p_on: bool) -> void:
	auto_collect_sun = p_on
	save_to_disk()


static func set_sun_auto_rounds(p_rounds: int) -> void:
	## The patience, in ROUNDS. Clamped to the nearest entry of Balance.SUN_AUTO_ROUNDS_
	## CHOICES, so a hand-edited settings file cannot invent "wait 999 rounds".
	var pick: int = BalanceBattle.SUN_AUTO_ROUNDS_CHOICES[0]
	var best := 1 << 30
	for choice in BalanceBattle.SUN_AUTO_ROUNDS_CHOICES:
		if absi(int(choice) - p_rounds) < best:
			best = absi(int(choice) - p_rounds)
			pick = int(choice)
	sun_auto_rounds = pick
	save_to_disk()


static func mark_cleared(p_id: String) -> bool:
	## Returns true when this call is what FIRST cleared the level - the caller uses
	## that to hand out the first-clear reward exactly once (P14).
	if p_id == "":
		return false
	if bool(cleared.get(p_id, false)):
		return false
	cleared[p_id] = true
	print("[Settings] level cleared: " + p_id)
	save_to_disk()
	return true


static func is_cleared(p_id: String) -> bool:
	return bool(cleared.get(p_id, false))


static func is_claimed(p_id: String) -> bool:
	## [P93] Has this level's first-clear chest been opened?
	return bool(claimed.get(p_id, false))


static func mark_claimed(p_id: String) -> bool:
	## [P93] Returns true when THIS call is what opened the chest - the same contract
	## mark_cleared() has, and what makes a second click harmless rather than a second payout.
	if bool(claimed.get(p_id, false)):
		return false
	claimed[p_id] = true
	save_to_disk()
	print("[Settings] first-clear chest opened: " + p_id)
	return true


static func reset_progress() -> void:
	## [P14] Forget which levels were cleared, which is what re-arms every
	## first-clear reward. Called by the debug reset (key N).
	## [P21] The audio choices are DISPLAY settings and therefore kept: resetting the
	## game must not turn the player's music (or [P50] their cues) back on.
	cleared = {}
	## [P93] and the chests go back to unopened with them: a level that is cleared again
	## must be able to pay again, or the debug reset would leave a chest that never opens.
	claimed = {}
	last_level = ""
	save_to_disk()
	print("[Settings] progress reset: cleared levels and opened chests forgotten, display settings kept")


static func summary_text() -> String:
	var line := "window %dx%d" % [window_size.x, window_size.y]
	line += "  fullscreen=" + str(fullscreen)
	line += "  language=" + language                    # [P20] diagnostic stays English
	line += "  music=" + ("on" if music_on else "off")  # [P21]
	line += " %d%%" % int(round(music_volume * 100.0))
	line += "  sfx=" + ("on" if sfx_on else "off")      # [P50]
	line += " %d%%" % int(round(sfx_volume * 100.0))
	line += "  cleared=%d" % cleared.size()
	line += "  chests=%d" % claimed.size()
	return line


static func mode_text(p_mode: int) -> String:
	## Human readable Window.mode, used by the log and by the settings screen.
	match p_mode:
		Window.MODE_FULLSCREEN:
			return "FULLSCREEN"
		Window.MODE_EXCLUSIVE_FULLSCREEN:
			return "EXCLUSIVE_FULLSCREEN"
		Window.MODE_MAXIMIZED:
			return "MAXIMIZED"
		Window.MODE_MINIMIZED:
			return "MINIMIZED"
	return "WINDOWED"


# ---------------------------------------------------------------- self-check (P56)
static func self_check() -> void:
	## The save round trip of THIS file, practised on PROBE_PATH. settings.cfg is the
	## fourth save file in the game and was the only one without a gate: profile / garden /
	## run each print a self-check that proves a bad file is refused and parked, while this
	## one carried its own copy of the atomic swap and called a damaged file "no file yet".
	print("[Settings] --- save round trip (P56) ---")
	var ok := true
	## Every field this probe can move, put back at the end: these are statics, and a value
	## left changed here would silently re-skin the client that is about to be drawn.
	var s_window := window_size
	var s_full := fullscreen
	var s_lang := language
	var s_music := music_on
	var s_music_v := music_volume
	var s_sfx := sfx_on
	var s_sfx_v := sfx_volume
	var s_last := last_level
	var s_cleared: Dictionary = cleared.duplicate()
	var s_claimed: Dictionary = claimed.duplicate()
	var real_before := _text_of(Balance.SETTINGS_PATH)
	_clear_probe_files()

	# 1. the swap itself, with a value the player would grieve if it were lost.
	cleared[PROBE_KEY] = true
	claimed[PROBE_KEY] = true      # [P93] the chest map rides the same round trip
	last_level = PROBE_KEY
	var swap_ok := (save_to_disk(PROBE_PATH)
		and FileAccess.file_exists(PROBE_PATH)
		and not FileAccess.file_exists(PROBE_PATH + ".tmp"))
	ok = ok and swap_ok
	print("[Settings] atomic swap: probe file written, no .tmp left behind = "
		+ str(swap_ok) + " | " + ("OK" if swap_ok else "FAIL"))

	# 2. back from disk, with the in-memory copy wiped first so a hit cannot be the value
	#    that was still sitting there.
	cleared = {}
	claimed = {}
	last_level = ""
	load_from_disk(PROBE_PATH)
	var read_ok: bool = bool(cleared.get(PROBE_KEY, false)) and last_level == PROBE_KEY \
		and bool(claimed.get(PROBE_KEY, false))
	ok = ok and read_ok
	print("[Settings] round trip: cleared level, opened chest and last_level come back off disk = "
		+ str(read_ok) + " | " + ("OK" if read_ok else "FAIL"))

	# 3. [P109] THE DAMAGED-FILE PROBE WAS REMOVED BY USER REQUEST (the C++
	#    `ConfigFile._parse` push_error it provokes cannot be muted from GDScript, and the
	#    user wants a zero-error boot). The PARK path itself is still production code in
	#    `load_from_disk` (park to .bak, delete the live file, keep defaults) - it is now
	#    simply not exercised at boot. Two facts worth remembering if this is ever rebuilt:
	#    the junk must be a TRUNCATED SECTION (`"[window\n..."`, the shape ConfigFile
	#    refuses), because a line of prose PARSES and the probe would run green testing
	#    nothing; and the check is bytes-based (.bak content / live path gone / values at
	#    default), not message-based.

	# 4. and the whole probe must not have written one byte to the player's real file -
	#    checked by bytes, not by trusting that every call site passed the path argument.
	var untouched: bool = _text_of(Balance.SETTINGS_PATH) == real_before
	ok = ok and untouched
	print("[Settings] the probe never wrote " + Balance.SETTINGS_PATH + " = "
		+ str(untouched) + " | " + ("OK" if untouched else "FAIL"))

	window_size = s_window
	fullscreen = s_full
	language = s_lang
	music_on = s_music
	music_volume = s_music_v
	sfx_on = s_sfx
	sfx_volume = s_sfx_v
	last_level = s_last
	cleared = s_cleared
	claimed = s_claimed
	_clear_probe_files()
	## No `Loc.set_language()` in the restore above: the probe file is written from the
	## language already in effect, so the two cannot drift apart here.
	print("[Settings] self-check %s" % ("PASSED" if ok else "FAILED"))


static func _text_of(p_path: String) -> String:
	## The whole file as text, "" when it is absent or unreadable - only used by
	## self_check() to compare bytes before and after.
	if not FileAccess.file_exists(p_path):
		return ""
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


static func _clear_probe_files() -> void:
	## All three names, every time. A `.bak` left by an interrupted earlier boot would make
	## keep_broken() refuse to park (it deliberately keeps the FIRST broken copy), and the
	## probe above would then report a failure it did not cause.
	var names: Array[String] = [PROBE_PATH, PROBE_PATH + ".bak", PROBE_PATH + ".tmp"]
	for p in names:
		if FileAccess.file_exists(p):
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			if err != OK:
				push_warning("[Settings] probe cannot remove %s (error %d)" % [p, err])
