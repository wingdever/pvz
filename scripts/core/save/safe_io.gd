extends RefCounted
## [P37] A save file must never be readable while only half written.
##
## DELIBERATELY WITHOUT `class_name`: a brand-new global class is invisible to
## `godot --headless` until the editor rescans the project (HANDOFF 7.67), which
## would make every save path fail to compile right after a checkout. Consumers
## `preload()` it under the same local name instead:
## `const SafeIO := preload("res://scripts/core/safe_io.gd")`.
##
## The rule this one helper exists for (docs/OPTIMIZATIONS.md A1): opening the real
## file with WRITE truncates it FIRST, so a crash or a power cut halfway through the
## write leaves a half-JSON file behind - and the loader's answer to a half file is
## "rebuild the defaults", which used to overwrite the player's progress for good.
##
## So every save goes through one of the two writers below - write_text_atomic() for
## the JSON files, write_config_atomic() [P56] for the ConfigFile one: the new content
## lands in a `.tmp` beside the real file, and only then is swapped in by a rename, which
## a filesystem performs or does not perform - it never does half of it. A failed
## save now leaves the previous, still-valid file in place.
##
## keep_broken() is the other half: when a file that IS on disk cannot be parsed,
## the bytes are moved to `.bak` before the defaults are written, so one bad update
## is a recoverable event instead of a lost account.


static func write_text_atomic(p_path: String, p_text: String) -> bool:
	## True only when p_path now holds exactly p_text. On false the original file is
	## untouched (that is the whole point), and the caller logs the failure.
	var tmp := p_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[SafeIO] cannot open %s for writing (error %d)"
			% [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(p_text)
	## flush() is what pushes the bytes out of the process; without it the rename
	## could swap in a file the OS has not written yet.
	f.flush()
	f.close()
	var err := DirAccess.rename_absolute(tmp, p_path)
	if err != OK:
		## Leave the .tmp where it is: the data is not lost, it is just not live yet,
		## and the next successful save overwrites it.
		push_warning("[SafeIO] cannot replace %s with %s (error %d)"
			% [p_path, tmp, err])
		return false
	return true


static func write_config_atomic(p_cfg: ConfigFile, p_path: String) -> bool:
	## [P56] The ConfigFile twin of write_text_atomic(), and now the ONLY way a
	## settings file gets swapped in. It exists because `ConfigFile` can only save to a
	## path - it cannot go through the function above - so `settings_store.gd` had to
	## carry its own copy of these same five lines. A rule with two implementations is
	## a rule that gets changed once (OPTIMIZATIONS C7), and the copy is exactly why
	## `keep_broken()` protected three save files but not the one holding the player's
	## cleared levels.
	##
	## Same contract as above: false means p_path still holds what it held before.
	var tmp := p_path + ".tmp"
	var err := p_cfg.save(tmp)
	if err != OK:
		push_warning("[SafeIO] cannot save %s (error %d)" % [tmp, err])
		return false
	## No flush() here on purpose: `save()` opens, writes and closes the file itself,
	## so the bytes are already out of the process by the time it returns.
	err = DirAccess.rename_absolute(tmp, p_path)
	if err != OK:
		push_warning("[SafeIO] cannot replace %s with %s (error %d)"
			% [p_path, tmp, err])
		return false
	return true


static func keep_broken(p_path: String) -> bool:
	## Park an unreadable save file as `<path>.bak` so the rebuilt defaults cannot
	## bury it. Returns true when the bytes are safe under the .bak name.
	if not FileAccess.file_exists(p_path):
		return false
	var bak := p_path + ".bak"
	if FileAccess.file_exists(bak):
		## Keep the FIRST broken file: overwriting it with each new launch would
		## replace the last salvageable copy with an empty-defaults stub.
		push_warning("[SafeIO] %s already holds a broken copy, keeping it" % bak)
		return false
	var err := DirAccess.rename_absolute(p_path, bak)
	if err != OK:
		push_warning("[SafeIO] cannot move the broken %s to %s (error %d)"
			% [p_path, bak, err])
		return false
	print("[SafeIO] moved the unreadable %s aside as %s" % [p_path, bak])
	return true
