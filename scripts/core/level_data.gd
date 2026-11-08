class_name LevelData
extends RefCounted
## [P8] External level definition loaded from a level pack file
## (res://data/level/Lawn_1_1.json ... Lawn_1_8.json).
## Never leaves the game unplayable: any parse or validation failure falls back
## to the built-in defaults taken from Balance and records the reason.
##
## [P26] TWO wave shapes are understood, and both end up in the same place:
##
##   pack shape (what data/level/*.json uses)
##     "waves": [ { "id": 1, "start_round": 1, "banner": false,
##                  "spawns": [ { "round": 6, "type": "zombie_cone", "count": 2,
##                                "cols": [7, 8] } ] } ]
##     A wave OWNS a list of spawn events; each event names how many of WHICH zombie
##     arrive on WHICH round. Several events may share a round, and two waves may
##     overlap - that is how the pack escalates.
##
##   legacy shape (the three level_0x.json files)
##     "waves": [ { "round": 3, "zombies": 2 } ]
##     Kept alive so old files (and the parser probes) still load: it becomes the
##     same plan with type "zombie".
##
## `waves` stays a round -> COUNT map (the HUD, the win check and the level list read
## it) and the typed plan rides alongside it in `spawn_plan`, so no existing caller
## had to change.
##
## NOTE: String.join() takes a PackedStringArray in Godot 4, so every join in
## this file builds one explicitly.

const DEFAULT_PATH := "res://data/level/Lawn_1_1.json"

var source: String = "<defaults>"
var loaded: bool = false
var problems: Array[String] = []

## [P97] The name, the Chinese name, the difficulty and the music come from
## data/levels.csv - a level file has no such cell any more (see _apply_sheet). What is
## left here are the CODE defaults, for a source that has no sheet row at all.
var level_name: String = "Fallback Lawn"
## [P20] Empty = fall back to `level_name`, which is what an English-only name gets.
var level_name_zh: String = ""
var difficulty_key: String = Difficulty.DEFAULT_KEY   # [P81] the preset itself owns the name
var initial_sun: int = 50
var brain_hp: int = 100
var zombie_hp: int = 270
var spawn_cols: Array[int] = [6, 7, 8]
## [P34] The lawn rows this battle plays on. Empty means "the whole lawn"
## (Balance.all_rows()); a level that names rows narrows the battlefield - which is
## how the packs tuned before the multi-row lawn keep their single-row difficulty.
## A spawn event may also name its own `rows` (see spawn_plan), exactly like `cols`.
var rows: Array[int] = []
var waves: Dictionary = {}                  # round(int) -> zombie count(int)
var starting_plants: Array[Dictionary] = [] # {plant: String, col: int, row: int}
var tool_thresholds: Dictionary = {}        # tool_id -> int
var plant_cooldowns: Dictionary = {}        # [P12] plant_id -> int (card cooldown in rounds)
var summon_quota: int = 0                   # [P13] 0 = use BalanceBattle.SUMMONS_PER_TURN
## [P26] round(int) -> Array of {type: String, count: int, cols: Array[int]}, in the
## order the file declares them. This is what makes a wave "one cone and two plain
## zombies" instead of just "three zombies".
var spawn_plan: Dictionary = {}
## [P26] round(int) -> true for a round a wave flagged with "banner": true, i.e. the
## round that gets the "a huge wave is coming" line instead of the ordinary one.
var banner_rounds: Dictionary = {}
## [P26] How many <wave> entries the file declared (the level list shows it) - a pack
## wave may carry several spawn events, so this is NOT waves.size().
var wave_ids: int = 0
# [P14] rewards + challenge type
var challenge: String = "normal"             # a label; only "normal" exists today
var scroll_durability_cost: int = 0          # durability a summon spends (normal = 0)
## [P21/P97] Background music for this level: an id from BalanceAudio.MUSIC_DEFS ("Day",
## "Night", "Pool", "Boss", ...). Empty = BalanceAudio.MUSIC_BATTLE. It is the sheet's
## `music` cell now (see _apply_sheet); an unknown id is reported by LevelDB and never
## reaches this field.
var music_id: String = ""
## [P80] D4 deleted `reward_items` from here. Its own comment promised "kept for old files"
## but nothing ever read it and NO parse path ever wrote it - so an old file's key was
## already ignored, and the field's only job was to look like it still meant something.
## (The live reward fields are the two below: `first_clear_items` and `rewards`.)
var first_clear_items: Dictionary = {}       # item_id -> count, granted on the FIRST WIN only
## [P94] AND the plant that first clear hands over, if any. A plant is not an ITEM - it joins
## the garden roster, not the warehouse - so it could never be expressed in the map above,
## which is why the first-clear chest could only ever pay scrolls. "" = no plant.
var first_clear_plant: String = ""
var rewards: Array[Dictionary] = []          # [P15] independent rolls, see parse_rewards()
## [P80] Was a bare `9999` - a SECOND copy of BalanceBattle.HAMMER_DAMAGE that happens to agree
## with it today. It never showed a symptom, and that is exactly why it survived: every path
## into a parsed or rejected level calls apply_defaults(), which overwrites the literal
## before anybody reads it. So the value was carried by a line nobody could reach, while
## BalanceBattle.HAMMER_DAMAGE had two spellings. One owner now; a level read without a file
## answers the SAME number as a level with one - see the boot claim
## "[SelfCheck] the hammer number has one owner".
var hammer_dmg: int = BalanceBattle.HAMMER_DAMAGE


func apply_defaults() -> void:
	## Defaults come from Balance so there is still exactly one place for numbers.
	level_name = "Fallback Lawn"
	level_name_zh = ""
	difficulty_key = Difficulty.DEFAULT_KEY   # [P81] not a Balance number: a preset name
	initial_sun = BalanceBattle.START_SUN
	brain_hp = BalanceBattle.BRAIN_MAX_HP
	zombie_hp = Balance.ZOMBIE_HP
	spawn_cols = []
	for c in BalanceBattle.ZOMBIE_SPAWN_COLS:
		spawn_cols.append(int(c))
	## [P34] No `rows` in the file means the whole lawn plays.
	rows = []
	waves = BalanceBattle.WAVE_TABLE.duplicate()
	## [P26] The fall-back plan is the same fall-back count table, typed as plain
	## zombies: one code path feeds the spawner whatever the file said.
	spawn_plan = {}
	banner_rounds = {}
	wave_ids = 0
	for r in waves.keys():
		var count := int(waves[r])
		spawn_plan[int(r)] = [{"type": ZombieDB.BASE_ID, "count": count,
			"cols": [], "rows": []}]     # [P34] no rows named = the whole lawn
		wave_ids += 1
	starting_plants = [
		{"plant": "peashooter", "col": 0, "row": Balance.MVP_ROW},
		{"plant": "sunflower", "col": 1, "row": Balance.MVP_ROW},
		{"plant": "wallnut", "col": 2, "row": Balance.MVP_ROW},
	]
	tool_thresholds = {}
	for id in BalanceBattle.TOOL_CARDS:
		tool_thresholds[str(id)] = BalanceBattle.tool_default_threshold(str(id))
	plant_cooldowns = {}
	summon_quota = 0
	challenge = "normal"
	scroll_durability_cost = 0
	music_id = ""
	first_clear_items = {}
	## [P94] the plant half of the same block: a rejected file must forget it like the rest.
	first_clear_plant = ""
	rewards = []
	hammer_dmg = BalanceBattle.HAMMER_DAMAGE


func _reject(msg: String) -> bool:
	problems.append(msg)
	var keep := source
	apply_defaults()
	source = keep
	problems.append("rejected -> using built-in defaults")
	return false


# ---------------------------------------------------------------- loading
func load_from_file(path: String) -> bool:
	problems.clear()
	source = path
	if not FileAccess.file_exists(path):
		return _reject("file not found: " + path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _reject("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
	var text := f.get_as_text()
	f.close()
	return parse_text(text, path)


func parse_text(text: String, p_source: String) -> bool:
	problems.clear()
	apply_defaults()
	source = p_source
	loaded = false

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return _reject("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _reject("root element must be a JSON object")
	var d: Dictionary = json.data

	## [P62] OPTIMIZATIONS C8: this function was 277 lines (`:144-420` before the cut),
	## the longest in the project.
	## It now says only the ORDER, and one method per subject holds the CONTENT. The
	## order is part of the contract: every block before `waves` can only REPAIR (report
	## the bad field and carry on), while the waves block is the one allowed to throw the
	## file away - so what a rejected level still reports is exactly what its earlier
	## fields earned. Each method appends to `problems` with the same wording it had here.
	_parse_stats(d)
	_parse_quotas(d)
	_parse_rewards(d)
	_parse_lawn(d)
	_parse_starting_plants(d)
	_parse_tools(d)
	_parse_cards(d)
	if not _parse_waves(d):
		return false

	loaded = true
	## [P97] And the four GENERAL cells (name / name_zh / difficulty / music) come from
	## data/levels.csv, which is their ONLY owner - the file does not carry them at all.
	_apply_sheet()
	return true


func _apply_sheet() -> void:
	## [P97] THE FOUR GENERAL CELLS COME FROM THE SHEET AND NOWHERE ELSE: data/levels.csv says
	## which levels exist and what they are called; this file owns their CONTENT, and a level
	## JSON has no such cells at all (they were deleted from all 24 files).
	##
	## A source with no sheet row keeps the code defaults apply_defaults() just set ("Fallback
	## Lawn", Difficulty.DEFAULT_KEY, no music) - the answer for a synthetic source too. LevelDB
	## validates the two word cells, so an unknown one never reaches here.
	if not LevelDB.is_loaded():
		return
	var id := LevelDB.id_for_path(source)
	if id == "":
		return
	var row := LevelDB.row(id)
	## A blank cell is "no value" (LevelDB already dropped an unknown word): the default
	## apply_defaults() just set stays, which is what a gap in the sheet means. The four
	## assignments are spelled out rather than driven by a name list: a typo in a string
	## would write nowhere and say nothing.
	if str(row.get("name", "")) != "":
		level_name = str(row["name"])
	if str(row.get("name_zh", "")) != "":
		level_name_zh = str(row["name_zh"])
	if str(row.get("difficulty", "")) != "":
		difficulty_key = str(row["difficulty"])
	if str(row.get("music", "")) != "":
		music_id = str(row["music"])


# ---------------------------------------------------------------- field blocks
## [P62] One method per subject, in the order `parse_text` calls them. Each one reports
## its own repairs into `problems` and stops there: none of them may reject the level,
## because "this file is unusable" is a decision about the whole document and only the
## waves block - which owns the spawner's plan - is allowed to make it.
## [P97] There is no identity block any more: `name` / `name_zh` / `difficulty` are the
## sheet's cells (see _apply_sheet), and a file that still carries them is simply ignored.
func _parse_stats(d: Dictionary) -> void:
	## The plain numbers a level may override: each is clamped into a usable range and
	## never questioned, because a too-small number is a balance mistake, not a broken
	## file - and Balance is what they all fall back to anyway (see apply_defaults).
	if d.has("initial_sun"):
		initial_sun = maxi(0, int(d["initial_sun"]))
	if d.has("brain_hp"):
		brain_hp = maxi(1, int(d["brain_hp"]))
	if d.has("zombie_hp"):
		zombie_hp = maxi(1, int(d["zombie_hp"]))
	if d.has("hammer_damage"):
		## [P80] The three numbers above are read RAW by their callers, so the clamp here is
		## their only floor. The hammer is not: every reader goes through hammer_damage(),
		## which already floors it - so this second `maxi` could not protect anything
		## that the first one did not, and it hid the file's own value on the way in.
		## Dropping it is behaviour-preserving (0 or -5 still reach the player as 1) and now
		## the field honestly says what the level file said.
		hammer_dmg = int(d["hammer_damage"])


func _parse_quotas(d: Dictionary) -> void:
	## The three numbers that are NOT clamped: each has a "the file said something
	## impossible" report, because silently rounding a quota up would change the level's
	## difficulty without anybody reading a warning.
	if d.has("summons_per_turn"):
		## [P13] Optional override of how many summon scrolls a round gives you.
		## Default (0) means "use BalanceBattle.SUMMONS_PER_TURN".
		var quota := int(d["summons_per_turn"])
		if quota <= 0:
			problems.append("summons_per_turn %d invalid (kept the default)" % quota)
		else:
			summon_quota = quota

	if d.has("challenge"):
		# [P14] A label for the kind of level this is. Only "normal" exists today,
		# and a normal challenge never spends scroll durability.
		challenge = str(d["challenge"]).to_lower()
	if d.has("scroll_durability_cost"):
		var cost := int(d["scroll_durability_cost"])
		if cost < 0:
			problems.append("scroll_durability_cost %d invalid (kept 0)" % cost)
		else:
			scroll_durability_cost = cost


## [P97] No music block either: which theme a level asks for is the sheet's `music` cell
## (LevelDB checks the id against BalanceAudio.MUSIC_DEFS before handing it over).


func _parse_rewards(d: Dictionary) -> void:
	if d.has("rewards"):
		## [P15] Rewards are a LIST of independent rolls. Every entry is checked on
		## its own, so "100% coins + 25% plant + 25% potion" can give any combination.
		##   { "chance": 0.25, "items": { "potion_peashooter": 1 } }
		##   { "chance": 0.25, "plant": "peashooter" }
		## An entry may carry both. `chance` defaults to 1.0.
		var raw_rewards: Variant = d["rewards"]
		if typeof(raw_rewards) != TYPE_ARRAY:
			problems.append("'rewards' must be an array of rolls (ignored)")
		else:
			var rolls: Array[Dictionary] = []
			for entry in (raw_rewards as Array):
				if typeof(entry) != TYPE_DICTIONARY:
					problems.append("reward entry is not an object (ignored)")
					continue
				var roll: Dictionary = entry
				var chance := clampf(float(roll.get("chance", 1.0)), 0.0, 1.0)
				var parsed_items := _parse_item_map(roll.get("items", {}), "rewards.items")
				var pid := str(roll.get("plant", ""))
				if pid != "" and not Balance.PLANT_DEFS.has(pid):
					problems.append("reward plant '%s' is not a plant (ignored)" % pid)
					pid = ""
				if parsed_items.is_empty() and pid == "":
					problems.append("reward entry has neither items nor a plant (ignored)")
					continue
				rolls.append({"chance": chance, "items": parsed_items, "plant": pid})
			rewards = rolls

	if d.has("first_clear"):
		## Kept as its own guaranteed block: first-clear rewards are deliberately
		## independent of the per-clear rolls (the designer asked for that).
		first_clear_items = _parse_item_map(d["first_clear"], "first_clear")
	## [P94] and the plant half of the same chest, checked against the card roster: a plant
	## nobody can summon would be a chest that opens onto nothing.
	var plant_id := str(d.get("first_clear_plant", ""))
	if plant_id == "":
		pass
	elif Balance.plant_cards().has(plant_id):
		first_clear_plant = plant_id
	else:
		_reject("first_clear_plant names \"%s\", which is not a plant card (ignored)" % plant_id)


func _parse_lawn(d: Dictionary) -> void:
	## Where zombies may enter (cols) and which lanes the battle plays on (rows).
	## [P34] Both use the same repair policy, which is why they share a method: a bad
	## entry is reported and dropped, and "nothing usable" means the default - the
	## spawn columns from Balance, or the whole lawn.
	if d.has("spawn_cols"):
		var raw_cols: Variant = d["spawn_cols"]
		if typeof(raw_cols) != TYPE_ARRAY:
			problems.append("'spawn_cols' must be an array -> kept defaults")
		else:
			var cols: Array[int] = []
			for c in (raw_cols as Array):
				var ci := int(c)
				if ci >= 0 and ci < Balance.COLS:
					cols.append(ci)
				else:
					problems.append("spawn col %d out of range 0..%d (ignored)" % [ci, Balance.COLS - 1])
			if cols.is_empty():
				problems.append("spawn_cols usable = 0 -> kept defaults")
			else:
				spawn_cols = cols

	if d.has("rows"):
		var raw_rows: Variant = d["rows"]
		if typeof(raw_rows) != TYPE_ARRAY:
			problems.append("'rows' must be an array -> kept the whole lawn")
		else:
			var kept_rows: Array[int] = []
			for r in (raw_rows as Array):
				var ri := int(r)
				if ri >= 0 and ri < Balance.ROWS:
					if not kept_rows.has(ri):
						kept_rows.append(ri)
				else:
					problems.append("row %d out of range 0..%d (ignored)" % [ri, Balance.ROWS - 1])
			if kept_rows.is_empty():
				problems.append("'rows' usable = 0 -> the whole lawn")
			rows = kept_rows


func _parse_starting_plants(d: Dictionary) -> void:
	if d.has("starting_plants"):
		var raw_plants: Variant = d["starting_plants"]
		if typeof(raw_plants) != TYPE_ARRAY:
			problems.append("'starting_plants' must be an array -> kept defaults")
		else:
			var plants: Array[Dictionary] = []
			var used: Dictionary = {}
			for entry in (raw_plants as Array):
				if typeof(entry) != TYPE_DICTIONARY:
					problems.append("starting plant entry is not an object (ignored)")
					continue
				var e: Dictionary = entry
				var pid := str(e.get("plant", ""))
				var col := int(e.get("col", -1))
				var row := int(e.get("row", -1))
				if not Balance.PLANT_DEFS.has(pid):
					problems.append("unknown starting plant '%s' (ignored)" % pid)
					continue
				if col < 0 or col >= Balance.COLS or row < 0 or row >= Balance.ROWS:
					problems.append("starting plant %s cell (%d,%d) out of range (ignored)" % [pid, col, row])
					continue
				var key := Vector2i(col, row)
				if used.has(key):
					problems.append("two starting plants want cell (%d,%d); kept the first (ignored)" % [col, row])
					continue
				used[key] = true
				plants.append({"plant": pid, "col": col, "row": row})
			starting_plants = plants


func _parse_tools(d: Dictionary) -> void:
	if d.has("tools"):
		var raw_tools: Variant = d["tools"]
		if typeof(raw_tools) != TYPE_DICTIONARY:
			problems.append("'tools' must be an object -> kept defaults")
		else:
			var td: Dictionary = raw_tools
			for key in td.keys():
				var tid := str(key)
				if not BalanceBattle.TOOL_DEFS.has(tid):
					problems.append("unknown tool '%s' (ignored)" % tid)
					continue
				var entry: Variant = td[key]
				if typeof(entry) != TYPE_DICTIONARY:
					problems.append("tool '%s' entry must be an object (ignored)" % tid)
					continue
				var th := int((entry as Dictionary).get("threshold", 0))
				if th <= 0:
					problems.append("tool '%s' threshold %d invalid (ignored)" % [tid, th])
					continue
				tool_thresholds[tid] = th


func _parse_cards(d: Dictionary) -> void:
	if d.has("cards"):
		## [P12] Card cooldown override, parsed exactly like the tool thresholds:
		## an unknown or unusable entry is ignored with a warning, never fatal.
		var raw_cards: Variant = d["cards"]
		if typeof(raw_cards) != TYPE_DICTIONARY:
			problems.append("'cards' must be an object -> kept defaults")
		else:
			var cd: Dictionary = raw_cards
			for key in cd.keys():
				var pid := str(key)
				## [P95] has_plant() so a level may override a SPIRIT card's numbers too.
				if not Balance.has_plant(pid):
					problems.append("unknown plant card '%s' (ignored)" % pid)
					continue
				var centry: Variant = cd[key]
				if typeof(centry) != TYPE_DICTIONARY:
					problems.append("card '%s' entry must be an object (ignored)" % pid)
					continue
				var cooldown := int((centry as Dictionary).get("cooldown", 0))
				if cooldown <= 0:
					problems.append("card '%s' cooldown %d invalid (ignored)" % [pid, cooldown])
					continue
				plant_cooldowns[pid] = cooldown


## [P26] Both wave shapes land in the same two accumulators, so the spawner, the HUD and
## the win check never learn which shape a file used.
func _parse_waves(d: Dictionary) -> bool:
	var raw_waves: Variant = d.get("waves", null)
	if typeof(raw_waves) != TYPE_ARRAY:
		return _reject("'waves' must be a non-empty array")

	var counts: Dictionary = {}
	var plan: Dictionary = {}
	var banners: Dictionary = {}
	var declared := 0
	for entry in (raw_waves as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("wave entry is not an object (ignored)")
			continue
		var e: Dictionary = entry
		declared += 1
		var wave_label := str(e.get("id", declared))
		var banner := bool(e.get("banner", false))
		if e.has("spawns"):
			## --- the pack shape ----------------------------------------------------
			_parse_wave_spawns(e, wave_label, banner, plan, counts, banners)
		else:
			## --- the legacy shape: {"round": n, "zombies": k} ----------------------
			## Kept so the three level_0x.json files (and the parser probes) still
			## load; it becomes the same plan, typed as the base zombie.
			var r := int(e.get("round", 0))
			var z := int(e.get("zombies", 0))
			if r <= 0 or z <= 0:
				problems.append("wave round=%d zombies=%d is invalid (ignored)" % [r, z])
				continue
			_plan_add(plan, counts, r, ZombieDB.BASE_ID, z, [], [])
			if banner:
				banners[r] = true
	if counts.is_empty():
		return _reject("no valid wave entries")
	waves = counts
	spawn_plan = plan
	banner_rounds = banners
	wave_ids = declared
	return true


func _parse_wave_spawns(e: Dictionary, wave_label: String, banner: bool,
		plan: Dictionary, counts: Dictionary, banners: Dictionary) -> void:
	## [P26] One wave of the pack shape: its `spawns` list, into the shared accumulators.
	## Several events may share a round, and an event may name its own `cols` and `rows`,
	## so "one cone down lane 7 while two plain zombies use the usual lanes" is
	## expressible without a new mechanism. A wave whose every event was refused is
	## reported once, because "wave 3 spawned nothing" is the thing a designer needs to
	## see - not the fifteen reasons underneath it.
	var raw_spawns: Variant = e["spawns"]
	if typeof(raw_spawns) != TYPE_ARRAY:
		problems.append("wave %s: 'spawns' must be an array (wave ignored)" % wave_label)
		return
	var events := 0
	for item in (raw_spawns as Array):
		if typeof(item) != TYPE_DICTIONARY:
			problems.append("wave %s: a spawn event is not an object (ignored)" % wave_label)
			continue
		var s: Dictionary = item
		var r := int(s.get("round", 0))
		var z := int(s.get("count", 0))
		if r <= 0 or z <= 0:
			problems.append("wave %s: spawn round=%d count=%d is invalid (ignored)"
				% [wave_label, r, z])
			continue
		var ztype := _known_zombie(str(s.get("type", ZombieDB.BASE_ID)), wave_label)
		var cols := _parse_spawn_cols(s.get("cols", null), wave_label)
		## [P34] an event may also name the lanes it walks onto.
		var ev_rows := _parse_event_rows(s.get("rows", null), wave_label)
		_plan_add(plan, counts, r, ztype, z, cols, ev_rows)
		if banner:
			banners[r] = true
		events += 1
	if events == 0:
		problems.append("wave %s has no usable spawn event (ignored)" % wave_label)


func _known_zombie(p_type: String, p_wave: String) -> String:
	## [P26] An unknown type is REPORTED and replaced by the base zombie: the level is
	## still playable and the log names the bad id, which is better than a silently
	## missing zombie or an unplayable file.
	var id := p_type if p_type != "" else ZombieDB.BASE_ID
	if ZombieDB.has(id):
		return id
	problems.append("wave %s: unknown zombie type '%s' -> '%s'"
		% [p_wave, p_type, ZombieDB.BASE_ID])
	return ZombieDB.BASE_ID


func _parse_spawn_cols(p_raw: Variant, p_wave: String) -> Array:
	## The optional per-event `cols` (BALANCE.md 11.2): where THIS event's zombies
	## enter. Empty means "use the level's spawn_cols".
	var out: Array = []
	if p_raw == null:
		return out
	if typeof(p_raw) != TYPE_ARRAY:
		problems.append("wave %s: 'cols' must be an array (ignored)" % p_wave)
		return out
	for c in (p_raw as Array):
		var ci := int(c)
		if ci < 0 or ci >= Balance.COLS:
			problems.append("wave %s: spawn col %d out of range 0..%d (ignored)"
				% [p_wave, ci, Balance.COLS - 1])
			continue
		if not out.has(ci):
			out.append(ci)
	return out


func _parse_event_rows(p_raw: Variant, p_wave: String) -> Array:
	## [P34] The optional per-event `rows`: which lanes THIS event's zombies may
	## enter. Empty means "the level's rows" - exactly like `cols` against spawn_cols.
	var out: Array = []
	if p_raw == null:
		return out
	if typeof(p_raw) != TYPE_ARRAY:
		problems.append("wave %s: 'rows' must be an array (ignored)" % p_wave)
		return out
	for r in (p_raw as Array):
		var ri := int(r)
		if ri < 0 or ri >= Balance.ROWS:
			problems.append("wave %s: spawn row %d out of range 0..%d (ignored)"
				% [p_wave, ri, Balance.ROWS - 1])
			continue
		if not out.has(ri):
			out.append(ri)
	return out


func _plan_add(p_plan: Dictionary, p_counts: Dictionary, p_round: int, p_type: String,
		p_count: int, p_cols: Array, p_rows: Array) -> void:
	## The one place a parsed event lands, in BOTH shapes at once: the typed plan the
	## spawner walks and the round -> count map the HUD and the win check read.
	var entries: Array = p_plan.get(p_round, [])
	entries.append({"type": p_type, "count": p_count, "cols": p_cols, "rows": p_rows})
	p_plan[p_round] = entries
	p_counts[p_round] = int(p_counts.get(p_round, 0)) + p_count


func _parse_item_map(raw: Variant, p_where: String) -> Dictionary:
	## [P14] item_id -> count, with unknown items and bad counts ignored loudly.
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("%s must be an object (ignored)" % p_where)
		return out
	for key in (raw as Dictionary).keys():
		var id := str(key)
		var count := int((raw as Dictionary)[key])
		if not Balance.is_item(id):
			problems.append("%s has unknown item '%s' (ignored)" % [p_where, id])
			continue
		if count <= 0:
			problems.append("%s item '%s' count %d invalid (ignored)" % [p_where, id, count])
			continue
		out[id] = count
	return out


# ---------------------------------------------------------------- queries
func wave_at(round_no: int) -> int:
	return int(waves.get(round_no, 0))


func wave_rounds() -> Array:
	## The rounds that spawn something, ascending. Built here so every caller gets the
	## same order (waves.keys() order is insertion order, not round order).
	var out: Array = waves.keys()
	out.sort()
	return out


func spawn_plan_at(round_no: int) -> Array:
	## [P26] What enters on this round, exactly as the file declared it:
	## [{type: String, count: int, cols: Array[int], rows: Array[int]}].
	## Empty for a round with no spawn. [P34] An empty `rows` means the level's rows.
	return spawn_plan.get(round_no, [])


func has_banner(round_no: int) -> bool:
	## [P26] True for the round a wave flagged as the big one ("banner": true).
	return bool(banner_rounds.get(round_no, false))


func wave_count() -> int:
	## Rounds that spawn something - what the level list shows as "N waves".
	return waves.size()


func wave_id_count() -> int:
	## How many <wave> blocks the file declared (a pack wave holds several events).
	return wave_ids


func zombie_types() -> Array[String]:
	## [P26] Every zombie type this level sends, in the order it first appears. The
	## almanac lists them and the level list uses them to say what a level is about.
	var out: Array[String] = []
	for r in wave_rounds():
		for entry in spawn_plan_at(int(r)):
			var t := str((entry as Dictionary).get("type", ZombieDB.BASE_ID))
			if not out.has(t):
				out.append(t)
	return out


func zombie_type_counts() -> Dictionary:
	## type -> how many of it this level sends in total.
	var out: Dictionary = {}
	for r in wave_rounds():
		for entry in spawn_plan_at(int(r)):
			var d: Dictionary = entry
			var t := str(d.get("type", ZombieDB.BASE_ID))
			out[t] = int(out.get(t, 0)) + int(d.get("count", 0))
	return out


func zombie_types_text() -> String:
	var counts := zombie_type_counts()
	var parts: PackedStringArray = []
	for t in zombie_types():
		parts.append("%s x%d" % [ZombieDB.name(t), int(counts.get(t, 0))])
	return "none" if parts.is_empty() else ", ".join(parts)


func last_wave_round() -> int:
	var m := 0
	for k in waves.keys():
		m = maxi(m, int(k))
	return m


func total_zombies() -> int:
	var t := 0
	for k in waves.keys():
		t += int(waves[k])
	return t


func display_name() -> String:
	## [P20] The level name in the current language: the file's own `name_zh` when it
	## has one, otherwise the English `name`. Levels that predate the field (or an
	## English-only level) simply keep showing their English name.
	if level_name_zh != "" and Loc.prefer_zh():
		return level_name_zh
	return level_name


func tool_threshold(tool_id: String) -> int:
	return maxi(1, int(tool_thresholds.get(tool_id, BalanceBattle.tool_default_threshold(tool_id))))


func plant_card_cooldown(plant_id: String) -> int:
	## [P12] Rounds the card needs to become READY again after a summon.
	return maxi(1, int(plant_cooldowns.get(plant_id, Balance.plant_card_cooldown(plant_id))))


func summons_per_turn() -> int:
	## [P13] How many summon scrolls (= plant cards) this level grants per round.
	if summon_quota > 0:
		return summon_quota
	return BalanceBattle.SUMMONS_PER_TURN


func battle_music() -> String:
	## [P21] The track this level asks for, or the default battle theme when the file
	## says nothing (which is also what an unknown id falls back to).
	return music_id if music_id != "" else BalanceAudio.MUSIC_BATTLE


func spends_scroll_durability() -> bool:
	## [P14] False for every level that exists today: a normal challenge is free to
	## summon from. A future hard/elite challenge sets scroll_durability_cost > 0.
	return scroll_durability_cost > 0


func rewards_text() -> String:
	var parts: PackedStringArray = []
	for entry in rewards:
		var roll: Dictionary = entry
		var chance := float(roll.get("chance", 1.0))
		var what: PackedStringArray = []
		var items: Dictionary = roll.get("items", {})
		for id in items.keys():
			var key := str(id)
			what.append("%d x %s" % [int(items[key]), Balance.item_name(key)])
		var pid := str(roll.get("plant", ""))
		if pid != "":
			what.append("1 x %s (plant)" % Balance.plant_name(pid))
		parts.append("%d%%: %s" % [int(round(chance * 100.0)), ", ".join(what)])
	var line := "none" if parts.is_empty() else "; ".join(parts)
	if not first_clear_items.is_empty():
		var first: PackedStringArray = []
		for id in first_clear_items.keys():
			var key := str(id)
			first.append("%d x %s" % [int(first_clear_items[key]), Balance.item_name(key)])
		line += "   first clear (guaranteed): " + ", ".join(first)
	if spends_scroll_durability():
		line += "   summon costs %d scroll durability" % scroll_durability_cost
	return line


func hammer_damage() -> int:
	return maxi(1, hammer_dmg)


func wave_table_text() -> String:
	var rounds: Array = waves.keys()
	rounds.sort()
	var parts: PackedStringArray = []
	for r in rounds:
		parts.append("T%d x%d" % [int(r), int(waves[r])])
	return ", ".join(parts)


func rows_text() -> String:
	## [P34] "0, 1, 2, 3, 4" (the whole lawn) or the level's own narrow list.
	var live := rows if not rows.is_empty() else Balance.all_rows()
	var sorted := live.duplicate()
	sorted.sort()
	var parts := PackedStringArray()
	for r in sorted:
		parts.append(str(int(r)))
	return ", ".join(parts)


func spawn_cols_text() -> String:
	var parts: PackedStringArray = []
	for c in spawn_cols:
		parts.append(str(c))
	return ", ".join(parts)


func starting_plants_text() -> String:
	if starting_plants.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for p in starting_plants:
		parts.append("%s(%d,%d)" % [str(p["plant"]), int(p["col"]), int(p["row"])])
	return ", ".join(parts)


func tools_text() -> String:
	var parts: PackedStringArray = []
	for id in BalanceBattle.TOOL_CARDS:
		var key := str(id)
		parts.append("%s %d" % [BalanceBattle.tool_name(key), tool_threshold(key)])
	return ", ".join(parts)


func cards_text() -> String:
	## [P12] "Peashooter 3, Sunflower 2, Wall-nut 5" - the card cooldown per plant.
	var parts: PackedStringArray = []
	for id in Balance.plant_cards():
		var key := str(id)
		parts.append("%s %d" % [Balance.plant_name(key), plant_card_cooldown(key)])
	return ", ".join(parts)


func spawn_plan_text() -> String:
	## [P26] The wave plan as the file declared it - the almanac's readout, and the log
	## line that answers "which zombie arrives when". A round carrying a banner wave is
	## marked so the pack's own pacing is visible.
	var parts: PackedStringArray = []
	for r in wave_rounds():
		var what: PackedStringArray = []
		for entry in spawn_plan_at(int(r)):
			var d: Dictionary = entry
			what.append("%d x %s" % [int(d.get("count", 0)),
				ZombieDB.name(str(d.get("type", ZombieDB.BASE_ID)))])
		var line := "T%d %s" % [int(r), ", ".join(what)]
		if has_banner(int(r)):
			line += " [BANNER]"
		parts.append(line)
	return "none" if parts.is_empty() else "; ".join(parts)


func problems_text() -> String:
	## [P26] Everything the parser refused or repaired, as one line. The almanac shows
	## it under a level so a data gap (an unknown reward item, a bad column) is visible
	## in the game instead of only in the log.
	if problems.is_empty():
		return "none"
	var packed := PackedStringArray()
	for problem in problems:
		packed.append(problem)
	return "; ".join(packed)
