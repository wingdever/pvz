class_name LevelList
extends RefCounted
## [P10] Discovers playable levels: every *.json sitting in Balance.LEVEL_DIR.
##
## [P26] That folder is the level PACK (res://data/level) and its files are named
## `Lawn_<world>_<stage>.json`. When at least one file follows that naming, the files
## that do NOT are skipped (and printed by self_check), which is what keeps the three
## superseded level_0x.json files out of the list without deleting them. Remove every
## Lawn_*.json and "any *.json in the folder" is the rule again.
##
## A file that does not parse is NOT hidden any more: it becomes a row marked
## `playable: false` with the reason in `broken`, so the level list can show it greyed
## out ("Lawn 1-5.json - the file is empty") and the almanac can explain it. A level
## that silently disappears is much harder to debug than one that says what is wrong.
##
## If the folder cannot be read at all, Balance.LEVEL_PATH is used so the list is
## never empty.

## [P75] THE PACK IS PARSED ONCE. OPTIMIZATIONS B4's second bullet: `menu.gd`, the almanac
## (twice over - its row list AND a `.size()` for a footer line) and this module's own
## self_check all called discover(), and every call re-read and re-parsed all nine JSON
## files. What the cache holds is the DISK FACT - a parsed LevelData per path - keyed by a
## signature of the folder. What it must NOT hold is anything the SESSION decides:
## `cleared` / `last_played` come from SettingsStore, and every text readout carries the
## current language's unit and item names. So discover() still rebuilds its rows on every
## call; it just never touches the disk twice for the same folder. `_cache_contract()` is
## the gate that keeps those two halves on their own sides of the line.

## path -> {"data": LevelData} | {"broken": reason} - the disk facts, see above.
static var _parsed: Dictionary = {}
static var _folder_sig := ""
## [P75] What `_cache_contract()` counts: a parse is a disk read, a projection is a row.
static var _parses := 0
static var _projections := 0

## The files the pack naming filtered out, as of the last discover(): the self-check
## prints them, which is the answer to "where did level_02.json go".
## [P75] PRIVATE, with `skipped()` as its only door - the same mutable public static B4
## named in its own remedy ("包级缓存 … skipped 可变 static 也顺手处理"). Nothing outside this
## file ever read it; a caller can no longer write it either.
static var _skipped: PackedStringArray = PackedStringArray()

static func skipped() -> PackedStringArray:
	return _skipped

static func discover() -> Array:
	## [P97] THE PACK IS THE SHEET: data/levels.csv names every level that exists, in its own
	## order; the *.json is that level's CONTENT. A file nobody lists is not a level (skipped),
	## and a row whose file is missing becomes a BROKEN row. The folder scan survives as the
	## FALL-BACK for a sheet that cannot be read.
	var out: Array = []
	var files := _json_files()
	_sync_cache(files)
	_skipped = PackedStringArray()
	if LevelDB.is_loaded():
		for id in LevelDB.ids():
			var entry := describe(LevelDB.path_of(str(id)))
			if not entry.is_empty():
				out.append(entry)
		for f in files:
			if LevelDB.id_for_path(Balance.LEVEL_DIR + "/" + str(f)) == "":
				_skipped.append(str(f))
		return out
	var pack := PackedStringArray()
	for f in files:
		if str(f).begins_with(Balance.LEVEL_PACK_PREFIX):
			pack.append(f)
	var wanted: PackedStringArray = pack if not pack.is_empty() else files
	for f in files:
		if not wanted.has(f):
			_skipped.append(str(f))
	for f in wanted:
		var scraped := describe(Balance.LEVEL_DIR + "/" + str(f))
		if not scraped.is_empty():
			out.append(scraped)
	if out.is_empty():
		var fallback := describe(Balance.LEVEL_PATH)
		if not fallback.is_empty():
			out.append(fallback)
	return out


static func _sync_cache(p_files: PackedStringArray) -> void:
	## [P75] Drop the whole parse when the folder itself changed. `res://` is read-only while
	## the game runs, so the only way this moves is a designer editing a level file under a
	## running game - exactly the case a cache must not swallow. A packed export reports the
	## same byte length for every file it was built with, so the signature is stable there and
	## the pack is parsed once per run.
	var sig := _folder_signature(p_files)
	if sig == _folder_sig:
		return
	_folder_sig = sig
	_parsed = {}


static func _file_stamp(p_path: String) -> String:
	## Name + byte length (see the signature's own note about same-length edits).
	var fa := FileAccess.open(p_path, FileAccess.READ)
	var length := 0
	if fa != null:
		length = fa.get_length()
		fa.close()
	return "%s:%d" % [p_path, length]


static func _folder_signature(p_files: PackedStringArray) -> String:
	## [P75] File name + byte length. The input has to come from an API the engine really
	## answers: this Godot's DirAccess has NO get_size() and NO get_modification_time(), and
	## the probe found that out the hard way - calling a method that is not there returns
	## nothing, an empty signature never moves, and the cache then looks perfectly fresh
	## while it is frozen. Opening a file for its length reads no content, so the check costs
	## nine handles instead of nine parses.
	## What it cannot see is an edit that keeps the byte count exactly equal; that one needs
	## the process restarted, like every other run-time cache of a read-only resource.
	var parts: PackedStringArray = []
	## [P97] The SHEET is part of the pack now, so it is part of the signature: editing
	## levels.csv under a running game must drop the parses exactly like editing a level
	## file does, or the page would serve the previous pack until the process restarted.
	parts.append(_file_stamp(LevelDB.PATH))
	for f in p_files:
		parts.append(_file_stamp(Balance.LEVEL_DIR + "/" + str(f)))
	return "|".join(parts)


static func _read_level(p_path: String) -> Dictionary:
	## The one place the disk is touched, and the one place a parse is counted.
	if _parsed.has(p_path):
		return _parsed[p_path]
	_parses += 1
	var entry := _parse_level(p_path)
	_parsed[p_path] = entry
	return entry


static func _parse_level(p_path: String) -> Dictionary:
	if not FileAccess.file_exists(p_path):
		return {"broken": "file not found"}
	var text := FileAccess.get_file_as_string(p_path)
	if text.strip_edges() == "":
		return {"broken": "the file is empty"}
	var probe := LevelData.new()
	if not probe.parse_text(text, p_path):
		return {"broken": probe.problems_text()}
	return {"data": probe}


static func describe(p_path: String) -> Dictionary:
	## One row of the level list: everything the menu, the almanac and the log need
	## about a level file, read from the file itself. `playable: false` marks a file
	## that is there but cannot be played; `broken` says why.
	## [P75] The parse behind it is cached (see _read_level), the row is not.
	var id := p_path.get_file().get_basename()
	var cached := _read_level(p_path)
	if cached.has("broken"):
		return _broken(id, p_path, str(cached["broken"]))
	return _project(cached["data"] as LevelData, id, p_path)


static func _project(probe: LevelData, p_id: String, p_path: String) -> Dictionary:
	## [P75] Every language-dependent and every session-dependent readout of a row, which
	## is why this runs per call rather than being cached with the parse.
	_projections += 1
	return {
		"id": p_id,
		"path": p_path,
		## [P20] "name" is already in the current language (the menu shows it as-is);
		## "name_en" is kept for the log line, which stays English.
		"name": probe.display_name(),
		"name_en": probe.level_name,
		"difficulty": probe.difficulty_key,
		"waves": probe.wave_count(),
		"wave_ids": probe.wave_id_count(),
		"zombies": probe.total_zombies(),
		"last_round": probe.last_wave_round(),
		"cleared": SettingsStore.is_cleared(p_id),
		## [P93] The first-clear CHEST beside the row: a level that has been cleared and not
		## yet paid for, and that actually has something in its `first_clear` map, shows a
		## closed chest the player can open. `first_clear_items` is handed over as the DICT
		## (not the readout text) so the claim needs no second parse of the file.
		"claimed": SettingsStore.is_claimed(p_id),
		"first_clear_items": probe.first_clear_items.duplicate(),
		## [P94] and the PLANT the chest hands over, if the level names one (a plant is not an
		## item: it joins the garden roster). Either half being present makes a chest worth
		## drawing - a level whose first clear is "one plant" alone still owes the player one.
		"first_clear_plant": probe.first_clear_plant,
		"claimable": SettingsStore.is_cleared(p_id) and not SettingsStore.is_claimed(p_id) \
			and (not probe.first_clear_items.is_empty() or probe.first_clear_plant != ""),
		"last_played": SettingsStore.last_level == p_id,
		"playable": true,
		"broken": "",
		## [P26] the readouts the almanac's LEVELS tab shows, so that page needs no
		## second parser of its own.
		"sun": probe.initial_sun,
		"brain_hp": probe.brain_hp,
		"zombie_hp": probe.zombie_hp,
		"spawn_cols": probe.spawn_cols_text(),
		"cards": probe.cards_text(),
		"tools": probe.tools_text(),
		"summons": probe.summons_per_turn(),
		"music": probe.battle_music(),
		"challenge": probe.challenge,
		"types": probe.zombie_types(),
		"type_counts": probe.zombie_type_counts(),
		"types_text": probe.zombie_types_text(),
		"wave_table": probe.wave_table_text(),
		"spawn_plan": probe.spawn_plan_text(),
		"plants_text": probe.starting_plants_text(),
		"rewards": probe.rewards_text(),
		"first_clear": _first_clear_text(probe.first_clear_items, probe.first_clear_plant),
		"warnings": probe.problems.duplicate(),
		"warnings_text": probe.problems_text(),
	}


static func _broken(p_id: String, p_path: String, p_reason: String) -> Dictionary:
	## A row for a file that cannot be played. It keeps the same keys as a good row
	## (empty / zero) so a caller never has to test two layouts - it only has to look
	## at `playable`.
	## [P97] The name still comes from the sheet when it has a row for this id: a level
	## whose file broke is a level the player knows by name, and "Lawn 1-7 - the file is
	## empty" reads better than the bare file name it used to print.
	var shown := p_id
	var shown_zh := ""
	if LevelDB.is_loaded() and LevelDB.has(p_id):
		var sheet_row := LevelDB.row(p_id)
		shown = str(sheet_row.get("name", p_id))
		shown_zh = str(sheet_row.get("name_zh", ""))
	var display := shown_zh if (shown_zh != "" and Loc.prefer_zh()) else shown
	return {
		"id": p_id,
		"path": p_path,
		"name": display,
		"name_en": shown,
		"difficulty": "",
		"waves": 0,
		"wave_ids": 0,
		"zombies": 0,
		"last_round": 0,
		"cleared": false,
		## [P93] a broken file owes nobody a chest either (same keys as a good row).
		"claimed": false,
		"first_clear_items": {},
		"first_clear_plant": "",
		"claimable": false,
		"last_played": false,
		"playable": false,
		"broken": p_reason,
		"sun": 0,
		"brain_hp": 0,
		"zombie_hp": 0,
		"spawn_cols": "",
		"cards": "",
		"tools": "",
		"summons": 0,
		"music": "",
		"challenge": "",
		"types": [],
		"type_counts": {},
		"types_text": "none",
		"wave_table": "none",
		"spawn_plan": "none",
		"plants_text": "none",
		"rewards": "none",
		"first_clear": "none",
		"warnings": [p_reason],
		"warnings_text": p_reason,
	}


static func _first_clear_text(p_items: Dictionary, p_plant: String) -> String:
	## [P94] One line for the chest's tooltip: the plant first (that is what the player
	## recognises), then the items the same chest pays out.
	## [P95] The plant is listed as the CHEST it now arrives in (its own item name says
	## which plant it holds), so the tooltip says what actually lands in the warehouse;
	## a plant with no chest row still prints as the plant itself (the P94 wording).
	var parts: PackedStringArray = []
	if p_plant != "":
		var chest := Balance.plant_chest_item_for(p_plant)
		if chest != "":
			parts.append("1 x " + Balance.item_name(chest))
		else:
			parts.append(Balance.plant_name(p_plant))
	var items := _item_map_text(p_items)
	if items != "none":
		parts.append(items)
	if parts.is_empty():
		return "none"
	return ", ".join(parts)


static func _item_map_text(p_items: Dictionary) -> String:
	## "1 x Sunflower Scroll" for the first-clear block, which is an item id -> count
	## map rather than a roll list.
	if p_items.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for id in p_items.keys():
		var key := str(id)
		parts.append("%d x %s" % [int(p_items[key]), Balance.item_name(key)])
	return ", ".join(parts)


static func _json_files() -> PackedStringArray:
	var out: PackedStringArray = []
	var files := DirAccess.get_files_at(Balance.LEVEL_DIR)
	for f in files:
		var name := str(f)
		if name.to_lower().ends_with(".json"):
			out.append(name)
	out.sort()
	return out


# ---------------------------------------------------------------- self check
static func _shape_drift(p_rows: Array) -> PackedStringArray:
	## [P53] Every way in which a BROKEN row's keys differ from a good row's (empty = the
	## two builders still agree). Only ever called from self_check(), so it costs nothing
	## at runtime; see the note there for why the pair is checked rather than merged.
	var good: Dictionary = {}
	for entry in p_rows:
		var row: Dictionary = entry
		if bool(row.get("playable", false)):
			good = row
			break
	if good.is_empty():
		return PackedStringArray(["no playable row to compare against"])
	var probe := _broken("shape", "res://shape.json", "shape probe")
	var drift: PackedStringArray = []
	for key in good.keys():
		if not probe.has(key):
			drift.append("_broken() lacks '%s'" % str(key))
	for key in probe.keys():
		if not good.has(key):
			drift.append("describe() lacks '%s'" % str(key))
	return drift


## [P62] The parser's contract, asserted on the way past because this is the only place
## it can be checked without a board. OPTIMIZATIONS C8 split `LevelData.parse_text` (279
## lines, the longest function in the project) into ten methods, one per subject; a move
## like that has exactly two failure modes, and "[Levels] is still PASSED" catches
## NEITHER of them:
##   - a block that stops being called → the field silently keeps Balance's default, and
##     every real level file already agrees with those defaults, so the pack rows look
##     identical;
##   - a block that stops reporting → a bad file parses "cleanly" and the designer never
##     hears that their `rows` was thrown away.
## So the probe brings one file that is right about every subject and one that is wrong
## about every subject, and checks what comes back. Every value in the good file differs
## from the default it would fall back to - that is the whole trick: "the field says 123"
## is only evidence because Balance says 50.
static func _parse_contract() -> bool:
	var good := LevelData.new()
	var applied := good.parse_text(
		'{"initial_sun":123,'
		+ '"brain_hp":20,"zombie_hp":300,"hammer_damage":7,"summons_per_turn":2,'
		+ '"challenge":"hard","scroll_durability_cost":1,'
		+ '"rewards":[{"chance":0.5,"items":{"coin_gold":3}},{"chance":1.0,"plant":"peashooter"}],'
		+ '"first_clear":{"coin_gold":9},"spawn_cols":[6],"rows":[2],'
		+ '"starting_plants":[{"plant":"wallnut","col":1,"row":2}],'
		+ '"tools":{"shovel":{"threshold":4}},"cards":{"peashooter":{"cooldown":6}},'
		+ '"waves":[{"id":1,"banner":true,"spawns":[{"round":2,"type":"zombie","count":3,'
		+ '"cols":[7],"rows":[2]}]}]}', "<contract>") \
		and good.loaded \
		and good.initial_sun == 123 and good.brain_hp == 20 and good.zombie_hp == 300 \
		and good.hammer_damage() == 7 \
		and good.summons_per_turn() == 2 and good.challenge == "hard" \
		and good.spends_scroll_durability() and good.scroll_durability_cost == 1 \
		and good.rewards.size() == 2 and int(good.first_clear_items.get("coin_gold", 0)) == 9 \
		and good.spawn_cols_text() == "6" and good.rows_text() == "2" \
		and good.starting_plants.size() == 1 \
		and good.tool_threshold("shovel") == 4 and good.plant_card_cooldown("peashooter") == 6 \
		and good.wave_at(2) == 3 and good.has_banner(2) and good.wave_id_count() == 1 \
		and good.problems.is_empty()
	var plan: Array = good.spawn_plan_at(2)
	applied = applied and plan.size() == 1 and (plan[0] as Dictionary).get("cols", []) == [7] \
		and (plan[0] as Dictionary).get("rows", []) == [2]
	## NOTE the parentheses around the format string: `%` binds tighter than `+` in
	## GDScript, so `A + B % args` formats only B. The first run of this probe printed
	## `(%d/%d heard …) = %s` verbatim and left an ERROR line in the log saying so.
	print(("[Levels] parser contract: each block APPLIES its own field"
		+ " (nothing falls back to Balance silently) = %s")
		% ["OK" if applied else "FAIL"])

	## The mirror image: one wrong entry per subject, and waves that end up unusable. The
	## markers are what each block has always reported, quoted from the parser.
	var hostile := LevelData.new()
	var rejected := not hostile.parse_text(
		'{"summons_per_turn":0,"scroll_durability_cost":-1,'
		+ '"rewards":"x","spawn_cols":[99],"rows":[99],'
		+ '"starting_plants":[{"plant":"nope","col":0,"row":0}],'
		+ '"tools":{"nope":{"threshold":1}},"cards":{"nope":{"cooldown":1}},'
		+ '"waves":[[],{"id":9,"spawns":[{"round":0,"count":1},{"round":2,"count":-5}]},'
		+ '{"id":10,"spawns":"x"},{"round":3,"zombies":-1}]}', "<contract>")
	## [P97] `difficulty` and `music` are NOT in this list any more: they are the SHEET's
	## cells now (LevelDB reports an unknown word), and this probe brings FILES.
	var marks: PackedStringArray = [
		"summons_per_turn", "scroll_durability_cost",   # _parse_quotas
		"'rewards' must be",                            # _parse_rewards
		"spawn_cols usable", "'rows' usable",           # _parse_lawn
		"unknown starting plant",                       # _parse_starting_plants
		"unknown tool",                                 # _parse_tools
		"unknown plant card",                           # _parse_cards
		"wave entry is not an object", "no valid wave entries",   # _parse_waves
		"spawn round=0", "no usable spawn event", "'spawns' must be an array",
		"wave round=3",                                 # _parse_wave_spawns + legacy shape
	]
	## _parse_stats is not in the list on purpose: it clamps and never questions a number,
	## so the only thing it can be caught doing wrong is the `applied` half above.
	var heard := 0
	for mark in marks:
		for problem in hostile.problems:
			if str(problem).contains(mark):
				heard += 1
				break
	var reported := rejected and heard == marks.size()
	print(("[Levels] parser contract: each block REPORTS its own repair (%d/%d heard,"
		+ " file rejected = %s) = %s")
		% [heard, marks.size(), str(rejected), "OK" if reported else "FAIL"])
	return applied and reported


static func _cache_contract() -> bool:
	## [P75] The four things that have to stay true for B4's cache to be a saving rather
	## than a lie. Two of them are one rule seen from each side: the PARSE is cached, the
	## ROW is not, because a row quotes SettingsStore and the current language. A cache that
	## swallowed the rows would still print nine green level files - it would only be the
	## menu's `cleared` ticks and the almanac's translated names that quietly froze.
	discover()                                  # warm: whatever ran before, this is the cache now
	var parses := _parses
	var projections := _projections
	var rows := discover()
	var playable := _playable_count(rows)
	discover()
	var read_nothing := _parses == parses
	var still_built := _projections == projections + 2 * playable
	print("[Levels] the cache: two further discover()s re-parsed %d file(s) and projected %d row(s)"
		% [_parses - parses, _projections - projections])
	print(("[Levels] cache: a second look at the same folder re-parses no file (%d parse(s)) = %s | %s")
		% [_parses - parses, str(read_nothing), "OK" if read_nothing else "FAIL"])
	print(("[Levels] cache: but every call still projects every row (%d expected, %d counted"
		+ " - the rows are NOT what is cached) = %s | %s")
		% [2 * playable, _projections - projections, str(still_built),
			"OK" if still_built else "FAIL"])
	## The behavioural half of the same claim: flip the language over the SAME cache.
	var own := _translated_text(discover())
	var was := Loc.language
	Loc.set_language(Loc.next_language())
	var flipped := Loc.language
	var other := _translated_text(discover())
	Loc.set_language(was)
	var follows := own != other
	print(("[Levels] cache: the level text still follows the language across it (%s -> %s changed"
		+ " the readouts = %s) = %s | %s")
		% [was, flipped, str(own != other), str(follows), "OK" if follows else "FAIL"])
	## And the other side: a folder that changed must NOT be served from the old parse.
	var cleared := _folder_changed_loses_cache()
	print(("[Levels] cache: a folder whose signature moved drops every parsed file and the next"
		+ " look refills it (%d file(s) back) = %s | %s")
		% [_parsed.size(), str(cleared), "OK" if cleared else "FAIL"])
	return read_nothing and still_built and follows and cleared


static func _playable_count(p_rows: Array) -> int:
	## [P75] `_project()` answers for a row the file really produced; a BROKEN row is built by
	## `_broken()` without one, so the projection count only lines up with the playable rows.
	var n := 0
	for entry in p_rows:
		if bool((entry as Dictionary).get("playable", false)):
			n += 1
	return n


static func _translated_text(p_rows: Array) -> String:
	## Everything a row spells out in the player's language, as one string to compare.
	var parts: PackedStringArray = []
	for entry in p_rows:
		var row: Dictionary = entry
		parts.append("%s;%s;%s;%s;%s;%s" % [str(row.get("name", "")), str(row.get("cards", "")),
			str(row.get("tools", "")), str(row.get("types_text", "")),
			str(row.get("rewards", "")), str(row.get("first_clear", ""))])
	return " ".join(parts)


static func _folder_changed_loses_cache() -> bool:
	## [P75] The invalidation cannot be provoked from inside a running game (`res://` is
	## read-only), so the probe drives the one input `_sync_cache()` actually reads: the
	## signature. A different file list must empty the parse cache, coming back to the real
	## folder must leave it cold rather than half-filled - which is exactly the state a
	## designer editing Lawn_1_2.json sees, and the reason the next discover() re-parses -
	## and that next discover() must really refill it, because every screen after this probe
	## reads through the cache.
	var real := _json_files()
	var sig_real := _folder_signature(real)
	var filled := _parsed.size()
	_sync_cache(PackedStringArray(["Lawn_zz_moved.json"]))
	var emptied := _parsed.is_empty()
	_sync_cache(real)
	var back := _parsed.is_empty() and _folder_sig == sig_real
	discover()                                 # leave the cache warm for the screens to come
	return emptied and back and _parsed.size() == filled and filled > 0


static func self_check() -> void:
	## Printed once at start-up by Game: shows exactly what the level list will offer
	## (and what the pack naming left out), so "my new JSON does not show up" is
	## answerable from the log.
	print("[Levels] --- level pack: %s ---" % LevelDB.PATH)
	## [P97] The SHEET is audited first and its verdict is this module's: it owns the roster.
	## An unreadable sheet still plays (the scan) but FAILs, like a missing item sheet. Every
	## row it names must come back as a ROW, playable or BROKEN.
	var sheet_ok := LevelDB.self_check()
	print("[Levels] pack source: %s" % (LevelDB.error_text() if not LevelDB.is_loaded() \
		else "%d row(s) from %s" % [LevelDB.ids().size(), LevelDB.PATH.get_file()]))
	var rows := discover()
	var listed_ok: bool = not LevelDB.is_loaded() or rows.size() == LevelDB.ids().size()
	var ok := sheet_ok and listed_ok and not rows.is_empty()
	print("[Levels] the sheet names %d level(s) and the pack built %d row(s) = %s | %s"
		% [LevelDB.ids().size(), rows.size(), str(listed_ok), "OK" if listed_ok else "FAIL"])
	var warn_total := 0                  # [P44] the summary line quotes it, see below
	for entry in rows:
		var row: Dictionary = entry
		var id := str(row.get("id", "?"))
		## [P20] logs stay English, so the probe reads the English name explicitly
		var level_name := str(row.get("name_en", row.get("name", id)))
		var waves := int(row.get("waves", 0))
		var zombies := int(row.get("zombies", 0))
		var mark := "CLEARED" if bool(row.get("cleared", false)) else "-"
		var playable := bool(row.get("playable", false))
		var good := id != "" and waves > 0 and zombies > 0
		## [P44] A data warning is part of the verdict now, not a footnote. `scroll_mystic`
		## (the pre-P31 name of the spirit scroll) sat in two level files for three batches
		## precisely because this module printed the warning, kept the line `OK` and still
		## said PASSED - while the reward it describes can never reach the player. That is
		## the same rule `[Items]` already applies to its own `_problems`.
		var warns: Array = row.get("warnings", []) as Array
		var verdict: bool = good and warns.is_empty()
		ok = ok and verdict
		if playable:
			## A BROKEN file already failed on its own account; counting its reason as a
			## data warning too would make the summary quote the same problem twice.
			warn_total += warns.size()
		var line := "[Levels] "
		line += id + ".json -> " + level_name
		line += "  (%d wave(s) / %d zombies, %s)" % [waves, zombies, str(row.get("difficulty", "?"))]
		line += "  [" + mark + "]"
		if playable:
			line += "  zombies: " + str(row.get("types_text", "none"))
			line += "  | " + ("OK" if verdict else "FAIL")
		else:
			line += "  | BROKEN: " + str(row.get("broken", "?"))
		print(line)
		if bool(row.get("playable", false)) and not warns.is_empty():
			print("[Levels]        -> %d data warning(s) (see FAIL above): %s"
				% [warns.size(), str(row.get("warnings_text", ""))])
	if rows.is_empty():
		print("[Levels]        -> no level file found in " + Balance.LEVEL_DIR)
	## [P53] `describe()` and `_broken()` each hand-write the same 32 keys, and the whole
	## reason a broken row spells them all out is the promise quoted on `_broken()`: "a
	## caller never has to test two layouts". That promise holds only until somebody adds
	## a key to one of the two builders, and the failure then surfaces as a missing readout
	## three screens away in the almanac. The builders stay duplicated on purpose (a shared
	## blank row would hide which key means what); what is no longer trusted is the pairing.
	var drift := _shape_drift(rows)
	if not drift.is_empty():
		ok = false
		print("[Levels]        -> row shape drift between describe() and _broken(): "
			+ ", ".join(drift))
	## [P62] The parser contract counts towards this module's verdict, for the same
	## reason [P44] made a data warning count: a green that would still be green with the
	## rule gone is not evidence, and `describe()` is where the rule is used.
	ok = _parse_contract() and ok
	## [P75] Same argument for the cache: "[Levels] is green" would stay green if the cache
	## served a row captured in another language, or if it never cached at all.
	ok = _cache_contract() and ok
	for name in skipped():
		## [P97] Two worlds, two reasons a *.json is not played: with the sheet up, "the sheet
		## does not name it" IS the pack rule; on the fall-back scan it is the old naming rule.
		var why := ("not in " + LevelDB.PATH.get_file()) if LevelDB.is_loaded() \
			else ("not " + Balance.LEVEL_PACK_PREFIX + "*.json while the pack exists")
		print("[Levels] skipped: " + str(name) + " (" + why + ")")
	print("[Levels] %d level(s), %d skipped, %d data warning(s) | %s"
		% [rows.size(), skipped().size(), warn_total, "PASSED" if ok else "FAILED"])
