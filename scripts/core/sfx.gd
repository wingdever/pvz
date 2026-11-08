class_name Sfx
extends RefCounted
## [P50] SOUND EFFECTS - the second half of the audio layer, and the reason every
## mechanic P39-P49 added finally says something out loud (a melon landing, a hammer
## falling, a 铁门 taking the shot).
##
## Why a separate class when Music already owns players: a theme is ONE thing that
## changes when the screen changes, so it wants two players, crossfades and loop
## bookkeeping. A cue is a dozen short sounds per round that must not interrupt each
## other, must not leak a player per shot, and must not stutter when eight zombies
## chomp in the same frame. Those two jobs do not share a data structure, and HANDOFF
## §9.13 said so before this file existed: `Sfx` on its own, not squeezed into Music.
##
##   BalanceAudio.SFX_DEFS   cue id -> { file, alt, db }   the ONLY id -> file mapping
##   Sfx.play(cue)      fire a cue; unknown id or a silent setting is a no-op
##   Sfx.set_enabled() / set_volume()   the SETTINGS switch and knob (sibling of music)
##   Sfx.set_quiet()    the start-up probes hold the sound layer, not the rules
##
## Three rules this file exists to enforce, because each one is a bug that was easy to
## write on purpose:
##   1. THE POOL IS FIXED. Players are made once in setup() and reused, so a long
##      battle neither grows the tree nor frees nodes at random (the 4 ObjectDB leaks
##      of §5 are exactly what free()/queue_free() in a hot path tends to leave behind).
##   2. THE SAME CUE CANNOT STACK IN ONE FRAME. A round resolves several bites and
##      several shots at once; without SFX_SAME_CUE_MS the third chomp of the same
##      zombie is just the same sample three times louder, which reads as a glitch.
##   3. A MISSING FILE IS NEVER FATAL - and never silent either: the first attempt
##      warns once and [Sfx] self-check FAILS at boot, so "we shipped a cue nobody
##      imported" cannot wait for someone to play a level to notice.
##
## Pitch jitter (SFX_PITCH_JITTER) is why a repeated chomp stays listenable: the cue's
## own `alt` variant plus a few percent of tempo make two plays of one file different
## sounds without needing a third file.

## The pool. Every player is a plain AudioStreamPlayer on the Master bus - an "Sfx" bus
## would be tidier, but a bus lives in default_bus_layout.tres / project.godot, and
## this project keeps its hands off the editor-managed audio config (AGENTS §2).
static var _host: Node = null
static var _players: Array = []
static var _next := 0                     # round-robin cursor for the steal path
static var _streams: Dictionary = {}      # path -> AudioStream (load once, play often)
static var _last: Dictionary = {}         # cue id -> the tick it last sounded
static var _asked: Dictionary = {}        # cue id -> it was asked for at least once
static var _warned: Dictionary = {}
static var _enabled := true
static var _volume := 1.0
static var _up := false
static var _quiet := false                # the probes: rules run, nothing is heard


# ---------------------------------------------------------------- setup
static func setup(p_host: Node) -> void:
	## Called once by Game._bootstrap() with the main scene, next to Music.setup().
	## Safe to call again; it does not rebuild the players.
	if _up and _host != null and is_instance_valid(_host):
		return
	if p_host == null:
		return
	_host = p_host
	_players.clear()
	_next = 0
	for i in BalanceAudio.SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = "Master"
		p.volume_db = 0.0
		_host.add_child(p)
		_players.append(p)
	_up = true


static func is_ready() -> bool:
	return _up


static func is_enabled() -> bool:
	return _enabled


static func volume() -> float:
	return _volume


static func volume_percent() -> int:
	return int(round(_volume * 100.0))


static func set_quiet(p_quiet: bool) -> void:
	## The start-up probes act units out on a live board; that is the engine being
	## tested, not the player being entertained. Everything still runs while quiet -
	## play() returns before it touches a player.
	_quiet = p_quiet


static func status_text() -> String:
	## One English log line for the boot banner and every SETTINGS change.
	var line := "sfx " + ("on" if _enabled else "off")
	line += "  volume=%d%%" % volume_percent()
	line += "  pool=%d" % _players.size()
	line += "  cues=%d" % BalanceAudio.sfx_ids().size()
	line += "  asked=%d" % _asked.size()
	return line


# ---------------------------------------------------------------- playback
static func play(p_cue: String) -> void:
	## Fire one cue. Unknown ids warn once (see self_check for the gate that catches
	## them at boot instead); a silent setting or a quiet probe returns without even
	## loading the file.
	if p_cue == "" or not _up or _quiet:
		return
	if not BalanceAudio.is_sfx(p_cue):
		_warn_once("unknown cue id '" + p_cue + "' (see BalanceAudio.SFX_DEFS)")
		return
	_asked[p_cue] = true
	if not _enabled or _volume <= 0.0:
		return
	if _in_debounce(p_cue):
		return
	var path := BalanceAudio.sfx_pick(p_cue)
	var stream := _load(path)
	if stream == null:
		return
	var player := _free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = BalanceAudio.sfx_db(p_cue) + linear_to_db(_volume)
	player.pitch_scale = _pitch()
	player.play()


static func stop_all() -> void:
	## Leaving a battle: a chomp that started one frame before the result panel would
	## otherwise keep playing over the menu theme.
	for p in _players:
		var player := p as AudioStreamPlayer
		if player != null and player.playing:
			player.stop()


static func set_enabled(p_on: bool) -> void:
	## The SETTINGS "SFX: ON/OFF" switch. Off stops what is already playing; the next
	## play() is what stays quiet.
	_enabled = p_on
	if not p_on:
		stop_all()


static func set_volume(p_linear: float) -> void:
	_volume = clampf(p_linear, 0.0, 1.0)
	if _volume <= 0.0:
		stop_all()


# ---------------------------------------------------------------- internals
static func _in_debounce(p_cue: String) -> bool:
	## Same cue, same instant -> one sound. Milliseconds, because a whole round resolves
	## inside one frame and the rules still call play() once per bite: what is being
	## deduplicated is the SAMPLE, not the event, so the window is a time and not a tick.
	var now := Time.get_ticks_msec()
	var was := int(_last.get(p_cue, -999999))
	if now - was < BalanceAudio.SFX_SAME_CUE_MS:
		return true
	_last[p_cue] = now
	return false


static func _free_player() -> AudioStreamPlayer:
	## A silent player is handed out as-is; when all of them are busy the oldest
	## (round-robin) is cut rather than growing the pool - a dozen overlapping cues
	## a round is a lot, and the tail of the last one is not what the player is missing.
	for p in _players:
		var idle := p as AudioStreamPlayer
		if idle != null and not idle.playing:
			return idle
	if _players.is_empty():
		return null
	var steal := _players[_next % _players.size()] as AudioStreamPlayer
	_next += 1
	if steal != null and steal.playing:
		steal.stop()
	return steal


static func _pitch() -> float:
	## Jitter only ever speeds a cue up or down by a few percent, so a repeated
	## planting still sounds like the same event and not like a different instrument.
	var spread := BalanceAudio.SFX_PITCH_JITTER
	if spread <= 0.0:
		return 1.0
	return 1.0 + (randf() * 2.0 - 1.0) * spread


static func _load(path: String) -> AudioStream:
	## Cached by path: the same chomp is loaded once for the whole session, so a
	## hundred bites do not mean a hundred ResourceLoader calls.
	if _streams.has(path):
		return _streams[path] as AudioStream
	if path == "" or not ResourceLoader.exists(path):
		_warn_once("cannot load " + (path if path != "" else "<no file>")
			+ " (is the editor still importing assets/audio?)")
		_streams[path] = null
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		_warn_once("cannot load " + path + " (is the editor still importing assets/audio?)")
		_streams[path] = null
		return null
	_streams[path] = stream
	return stream


static func _warn_once(p_text: String) -> void:
	if bool(_warned.get(p_text, false)):
		return
	_warned[p_text] = true
	push_warning("[Sfx] " + p_text)


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up next to [Music] / [Art] / [Loc]. It answers the two
	## questions the boot log cannot otherwise see: is every cue of BalanceAudio.SFX_DEFS
	## imported, and does the table have the shape the code reads (a file, an optional
	## 变调 twin, and a volume that is an ATTENUATION and not a gain).
	print("[Sfx] --- sound effects (assets/audio) ---")
	var ids := BalanceAudio.sfx_ids()
	var ok := not ids.is_empty()
	if ids.is_empty():
		print("[Sfx] BalanceAudio.SFX_DEFS is empty | FAIL")
	for item in ids:
		var cue := str(item)
		var files: Array = BalanceAudio.sfx_files(cue)
		var missing: Array[String] = []
		var longest := 0.0
		var loaded_any := false
		for path in files:
			var p := str(path)
			if not ResourceLoader.exists(p):
				missing.append(p.get_file())
				continue
			var stream := ResourceLoader.load(p) as AudioStream
			if stream != null:
				loaded_any = true
				longest = maxf(longest, stream.get_length())
		## The table value is read RAW here: sfx_db() clamps a positive number away, so
		## checking through it would let "a cue louder than the knob" pass forever.
		var db := float(BalanceAudio.sfx_def(cue).get("db", 0.0))
		## And the LENGTH is a real gate, not a curiosity column: assets/audio is full of
		## themes, and a theme wired to a button is exactly the mistake nobody hears until
		## they press it. This is how SelectCard.wav (the seed-choice track, 108 s) got
		## caught on the first run of this check.
		var too_long := longest > BalanceAudio.SFX_MAX_LENGTH
		var cue_ok := not files.is_empty() and missing.is_empty() and loaded_any \
			and db <= 0.0 and not too_long
		ok = ok and cue_ok
		var twin := str(BalanceAudio.sfx_def(cue).get("alt", ""))
		print("[Sfx] %s  %s%s  %.2f s  %+.1f dB | %s" % [
			cue.lpad(14),
			str(files[0]).get_file() if not files.is_empty() else "<none>",
			" (+" + twin + ")" if twin != "" else "",
			longest,
			db,
			"OK" if cue_ok else "FAIL",
		])
		if not missing.is_empty():
			print("[Sfx]        -> not imported: " + ", ".join(missing)
				+ " (let the editor finish importing assets/audio/**/*.wav)")
		if too_long:
			print("[Sfx]        %.2f s is longer than a cue is allowed (%.0f s): this is a "
				% [longest, BalanceAudio.SFX_MAX_LENGTH] + "theme or an ambience loop, pick a sample")
		if db > 0.0:
			print("[Sfx]        -> db is a GAIN: SFX_DEFS.db must be <= 0, only the "
				+ "SETTINGS volume is allowed to make a cue louder")
	print("[Sfx] %d cue(s), %d player(s), debounce %d ms, pitch jitter %.0f%%"
		% [ids.size(), BalanceAudio.SFX_POOL, BalanceAudio.SFX_SAME_CUE_MS, BalanceAudio.SFX_PITCH_JITTER * 100.0])
	print("[Sfx] self-check %s" % ("PASSED" if ok else "FAILED"))
