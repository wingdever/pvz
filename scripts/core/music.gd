class_name Music
extends RefCounted
## [P21] Background music: the one place that decides which track belongs to which
## screen, and the only owner of the audio players.
##
## Why not an autoload: project.godot is editor managed in this project (the editor
## rewrites it from its own in-memory settings and has already reverted hand edits),
## and Layout / Fx / Garden / Profile are plain static classes for the same reason.
## Game calls Music.setup(scene) once from _bootstrap(); after that every screen only
## says Music.play("<id>").
##
##   BalanceAudio.MUSIC_DEFS   id -> { file, loop }  (the tracks of assets/audio/readme.md)
##   Music.play(id)       a looped theme, crossfaded in over the previous one
##   Music.play_jingle(id) a one-shot cue (win / lose), never looped
##   Music.set_enabled() / set_volume()   the ON/OFF and volume from SETTINGS
##
## A missing or not-yet-imported file is never fatal: the music simply does not start
## and a warning is printed once (same rule as UnitArt and the sprites).
##
## Looping is belt and braces:
##   1. the loaded AudioStreamWAV is given LOOP_FORWARD with the loop covering the
##      whole clip, which is what lets the engine loop it gaplessly;
##   2. `finished` is connected as a safety net, because an import setting or a codec
##      can ignore those loop points: a clip that plays through once is replayed by
##      MusicPlayer._on_finished, and one whose loop point cuts it short has that loop
##      point switched off so the replay can take over. Guards on both paths stop a
##      broken clip from turning into a busy loop (MUSIC_LOOP_MIN_RATIO / _MAX_STRIKES).
## The console says which of the two paths a track ended up on, once per track.

## A player that also knows what it is supposed to be doing, so the "did that clip
## really loop?" decision lives next to the signal that asks the question.
class MusicPlayer extends AudioStreamPlayer:
	var track_id := ""
	var loops := false
	var clip_length := 0.0
	var strikes := 0
	var played := 0.0
	var manual := false            # a stop() WE asked for, not the clip reaching its end

	func _ready() -> void:
		finished.connect(_on_finished)

	func _process(delta: float) -> void:
		if playing:
			played += delta

	func arm(p_id: String, p_loops: bool, p_length: float) -> void:
		track_id = p_id
		loops = p_loops
		clip_length = p_length
		strikes = 0
		played = 0.0
		manual = false

	func halt() -> void:
		## Every manual stop goes through here, so the finished handler can tell a
		## crossfade (us) from a clip that really ran out (the fallback loop).
		manual = true
		stop()

	func _on_finished() -> void:
		## A one-shot cue (the win / lose jingle) ends here on purpose: the result
		## panel is read, not listened to. A theme is put back on instead.
		var was_manual := manual
		manual = false
		var ran_through: bool = clip_length > 0.0 and played >= clip_length * BalanceAudio.MUSIC_LOOP_MIN_RATIO
		played = 0.0
		if was_manual or not loops or track_id == "":
			return
		if not ran_through:
			## It ended well before its own length, so the native loop point is the
			## prime suspect: take it out of the equation and let the replay below
			## carry the theme instead of leaving the game silent.
			strikes += 1
			if strikes > BalanceAudio.MUSIC_LOOP_MAX_STRIKES:
				push_warning("[Music] %s keeps finishing early; not replaying it any more" % track_id)
				loops = false
				return
			var wav := stream as AudioStreamWAV
			if wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
				wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
				Music._note_replay(track_id, "its loop point cut the clip short -> looping by hand")
		Music._replay(self)


static var _host: Node = null                  # the scene the players are children of
static var _players: Array = []                # [MusicPlayer] x2, so themes crossfade
static var _fades: Dictionary = {}             # MusicPlayer -> the Tween moving it
static var _active := 0                        # index of the player that is fading in
static var _current_id := ""                   # the track the current screen asked for
static var _current_loops := false
static var _enabled := true
static var _volume := 1.0
static var _up := false                        # setup() ran and the players exist
static var _warned: Dictionary = {}
static var _replay_logged: Dictionary = {}


# ---------------------------------------------------------------- setup
static func setup(p_host: Node) -> void:
	## Called once by Game._bootstrap() with the main scene. Safe to call again.
	if _up and _host != null and is_instance_valid(_host):
		return
	if p_host == null:
		return
	_host = p_host
	_players.clear()
	_fades.clear()
	_active = 0
	for i in 2:
		var p := MusicPlayer.new()
		p.name = "MusicPlayer%d" % i
		p.bus = "Master"
		p.volume_db = BalanceAudio.MUSIC_SILENT_DB
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


static func status_text() -> String:
	## One English log line for the boot banner and the SETTINGS changes.
	var now := "silent"
	if _current_id != "":
		now = "'%s' (%s)" % [_current_id, BalanceAudio.music_file(_current_id)]
	var line := "music " + ("on" if _enabled else "off")
	line += "  volume=%d%%" % volume_percent()
	line += "  now=" + now
	return line


# ---------------------------------------------------------------- playback
static func play(p_id: String) -> void:
	## Switch to a theme. Calling it with the track that is already playing is a no-op,
	## which is what lets every screen - and every round - simply state what it wants.
	if p_id == "" or not _up:
		return
	if not BalanceAudio.is_music(p_id):
		_warn_once("unknown track id '" + p_id + "' (see BalanceAudio.MUSIC_DEFS)")
		return
	if p_id == _current_id and _is_playing(_active):
		return
	_start(p_id, BalanceAudio.music_loops(p_id), BalanceAudio.MUSIC_FADE_TIME)


static func play_jingle(p_id: String) -> void:
	## A one-shot cue: the victory / defeat jingle. It never loops, and when it ends the
	## result screen stays quiet - the player is reading numbers there, not a music screen.
	if p_id == "" or not _up:
		return
	if not BalanceAudio.is_music(p_id):
		_warn_once("unknown track id '" + p_id + "' (see BalanceAudio.MUSIC_DEFS)")
		return
	_start(p_id, false, BalanceAudio.MUSIC_JINGLE_FADE)


static func stop(p_fade: float = -1.0) -> void:
	_current_id = ""
	_current_loops = false
	_stop_players(p_fade if p_fade >= 0.0 else BalanceAudio.MUSIC_FADE_TIME)


static func set_enabled(p_on: bool) -> void:
	## The SETTINGS "MUSIC: ON/OFF" switch. Turning it off silences the game; turning it
	## back on picks up whatever the current screen asked for, from the start.
	_enabled = p_on
	if not _up:
		return
	if not _enabled:
		_stop_players(BalanceAudio.MUSIC_FADE_TIME)
		return
	if _current_id != "":
		_start(_current_id, _current_loops, BalanceAudio.MUSIC_FADE_TIME)


static func set_volume(p_linear: float) -> void:
	## The SETTINGS volume button. 0 is legal in a hand edited settings file: it means
	## silence, and raising it again brings the current theme back.
	_volume = clampf(p_linear, 0.0, 1.0)
	if not _up:
		return
	if _volume <= 0.0:
		_stop_players(BalanceAudio.MUSIC_VOLUME_FADE)
		return
	if not _enabled or _current_id == "":
		return
	var player := _players[_active] as MusicPlayer
	if player == null or not player.playing:
		_start(_current_id, _current_loops, BalanceAudio.MUSIC_VOLUME_FADE)
		return
	_fade_to(player, _volume_db(), BalanceAudio.MUSIC_VOLUME_FADE, false)


# ---------------------------------------------------------------- internals
static func _start(p_id: String, p_loops: bool, p_fade: float) -> void:
	_current_id = p_id
	_current_loops = p_loops
	if not _enabled or _volume <= 0.0:
		## Music is off: remember the request (that is what comes back when it is turned
		## on again) but do not even load the file.
		return
	var stream := _load_track(p_id, p_loops)
	if stream == null:
		_current_id = ""
		_current_loops = false
		_stop_players(p_fade)
		return
	var old := _players[_active] as MusicPlayer
	if old != null and old.playing:
		_fade_to(old, BalanceAudio.MUSIC_SILENT_DB, p_fade, true)    # crossfade the old theme out
	var next := 1 - _active
	var player := _players[next] as MusicPlayer
	player.halt()                    # in case this player is still fading out
	player.stream = stream
	player.arm(p_id, p_loops, stream.get_length())
	player.volume_db = BalanceAudio.MUSIC_SILENT_DB
	player.play()
	_fade_to(player, _volume_db(), p_fade, false)
	_active = next
	print("[Music] playing %s (%s, %s)" % [p_id, BalanceAudio.music_file(p_id), "loop" if p_loops else "one-shot"])


static func _load_track(p_id: String, p_loops: bool) -> AudioStream:
	## Loads a track and puts the loop flag on the STREAM, so the engine (not a timer)
	## is what repeats it. The imported resource is shared and cached, which is fine:
	## only Music plays these files.
	var path := BalanceAudio.music_path(p_id)
	if path == "" or not ResourceLoader.exists(path):
		_warn_once("cannot load " + (path if path != "" else "'" + p_id + "'")
			+ " (is the editor still importing assets/audio?)")
		return null
	var stream := ResourceLoader.load(path)
	if stream == null:
		_warn_once("cannot load " + path + " (is the editor still importing assets/audio?)")
		return null
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_begin = 0
		if p_loops:
			## The whole clip loops. loop_end is written explicitly: its default is 0,
			## i.e. an empty loop, which would be silent (or a busy loop) on its own.
			var frames := int(round(wav.get_length() * float(wav.mix_rate)))
			wav.loop_end = maxi(frames, 0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


static func _replay(p: MusicPlayer) -> void:
	## Called by MusicPlayer when a looping clip reached its end: it did not loop
	## natively, so start it again by hand. Guarded, because a clip that ends the
	## moment it starts would otherwise be restarted forever.
	if not _up or p == null or not _enabled or _volume <= 0.0:
		return
	if p != _players[_active] or p.track_id != _current_id:
		return
	_note_replay(p.track_id, "replayed on finish")
	p.play()


static func _note_replay(p_id: String, p_why: String) -> void:
	## Printed once per track: it is how a log tells "the engine loops this" from
	## "the game loops this on its own".
	if _replay_logged.has(p_id):
		return
	_replay_logged[p_id] = true
	print("[Music] %s does not loop natively (%s)" % [p_id, p_why])


static func _stop_players(p_fade: float) -> void:
	for item in _players:
		var p := item as MusicPlayer
		if p == null:
			continue
		if p.playing:
			_fade_to(p, BalanceAudio.MUSIC_SILENT_DB, p_fade, true)
		else:
			p.halt()


static func _is_playing(p_index: int) -> bool:
	if p_index < 0 or p_index >= _players.size():
		return false
	var p := _players[p_index] as MusicPlayer
	return p != null and p.playing


static func _volume_db() -> float:
	## -60 dB is quiet enough to read as silence, and stays away from -inf.
	return linear_to_db(maxf(_volume, 0.001))


static func _fade_to(p: MusicPlayer, p_db: float, p_time: float, p_stop_after: bool) -> void:
	## Kill the fade this player is already on, otherwise two tweens would fight over
	## volume_db. is_instance_valid comes first because a finished tween can be freed.
	var previous: Variant = _fades.get(p)
	_fades.erase(p)
	if is_instance_valid(previous):
		var running := previous as Tween
		if running != null and running.is_valid():
			running.kill()
	if p_time <= 0.0 or _host == null or not is_instance_valid(_host) or not is_instance_valid(p):
		p.volume_db = p_db
		if p_stop_after:
			p.halt()
		return
	var tween := _host.create_tween()
	_fades[p] = tween
	tween.tween_property(p, "volume_db", p_db, p_time)
	if p_stop_after:
		tween.tween_callback(p.halt)


static func _warn_once(p_text: String) -> void:
	if bool(_warned.get(p_text, false)):
		return
	_warned[p_text] = true
	push_warning("[Music] " + p_text)


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up next to [Art] / [Loc]: it answers "is the music table
	## complete, are the files imported, and does every track carry the loop flag it
	## claims", which is invisible until a screen goes quiet. Every id in the table is
	## checked for existence (cheap); the tracks the game asks for on its own are fully
	## loaded, so their length and loop points are reported too.
	print("[Music] --- background music (assets/audio) ---")
	var ids := BalanceAudio.music_ids()
	var missing: Array[String] = []
	for item in ids:
		var id := str(item)
		var path := BalanceAudio.music_path(id)
		if path == "" or not ResourceLoader.exists(path):
			missing.append(id + " -> " + (path if path != "" else "<unknown>"))
	var all_present: bool = missing.is_empty()
	for line in missing:
		print("[Music] NOT IMPORTED " + line + " | FAIL")
	print("[Music] %d tracks in BalanceAudio.MUSIC_DEFS, files present = %s | %s"
		% [ids.size(), all_present, "OK" if all_present else "FAIL"])

	# The screens drive these; a level may name any other track, so only the built-in
	# set is inspected in detail.
	var used: Array = [BalanceAudio.MUSIC_MENU, BalanceAudio.MUSIC_LEVEL_SELECT, BalanceAudio.MUSIC_GARDEN,
		BalanceAudio.MUSIC_BATTLE, BalanceAudio.MUSIC_WIN, BalanceAudio.MUSIC_LOSE]
	var ok := all_present
	for item in used:
		var id := str(item)
		var loops := BalanceAudio.music_loops(id)
		var stream := _load_track(id, loops)
		if stream == null:
			ok = false
			print("[Music] %s cannot load %s | FAIL" % [id, BalanceAudio.music_path(id)])
			continue
		var good := _loop_matches(stream, loops)
		ok = ok and good
		print("[Music] %s  %s  %.1f s  %s | %s"
			% [id, BalanceAudio.music_file(id), stream.get_length(), _loop_text(stream),
			   "OK" if good else "FAIL"])
	if not ok:
		print("[Music]        -> let the editor finish importing assets/audio/**/*.wav,")
		print("[Music]        -> then reload the project (Project > Reload Current Project)")
	print("[Music] self-check %s" % ("PASSED" if ok else "FAILED"))


static func _loop_text(p_stream: AudioStream) -> String:
	if not (p_stream is AudioStreamWAV):
		return "loop=? (not a wav)"
	var wav := p_stream as AudioStreamWAV
	var mode := "forward" if wav.loop_mode == AudioStreamWAV.LOOP_FORWARD else str(wav.loop_mode)
	return "loop=%s(%d..%d)" % [mode, wav.loop_begin, wav.loop_end]


static func _loop_matches(p_stream: AudioStream, p_loops: bool) -> bool:
	## The theme has to be able to repeat and the jingle has to NOT repeat.
	if not (p_stream is AudioStreamWAV):
		return not p_loops
	var wav := p_stream as AudioStreamWAV
	if not p_loops:
		return wav.loop_mode == AudioStreamWAV.LOOP_DISABLED
	return wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end > wav.loop_begin
