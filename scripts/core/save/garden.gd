class_name Garden
extends RefCounted
## [P12] The garden: the persistent, cross-level roster of plants the player owns.
##
## Why it exists: a plant card no longer conjures a plant out of nothing. It
## SUMMONS a random available instance of its type out of this roster, and the
## instance keeps its wounds - the hp it ends a battle with is written back, and a
## plant that dies in battle comes home DOWNED (it needs FERTILIZER to stand up
## again, which also restores half of its health).
##
## Storage: user://garden.json, plain JSON so it can be hand-edited while
## balancing. Deliberately NOT in project.godot (the editor rewrites that file,
## see HANDOFF 7.15) and NOT in user://settings.cfg (that one is for display
## settings; mixing progress into it would make both harder to reason about).
##
## Write-back policy, agreed with the designer: the roster is NEVER touched while
## a battle runs. Game keeps a battle-scoped ledger of what happened and calls
## apply_results() only when the battle settles (WIN / LOSE / leaving to the menu
## / closing the window). Restarting a level therefore rolls the garden back for
## free: no settlement, no write-back.
##
## The class is INSTANCE based (like LevelData) so self_check() can run every rule
## on a scratch roster without ever touching the player's real file. Garden.live is
## the one instance the game actually plays with; nothing else should be saved.

## [P37] `preload` rather than a global class name: see safe_io.gd for why.
const SafeIO := preload("res://scripts/core/save/safe_io.gd")

static var live: Garden = null          # the loaded roster the game uses
var profile: Profile = null               # the profile that owns this roster (Game sets it)
## [P109] The old `var garden: Garden = null` was a second handle on THIS very roster -
## the care methods below are instance methods and act on `self`. Keeping it would mean
## a scratch roster used by `self_check` could reach (and write) the live one through a
## field, which is exactly what the instance-based design at the top of this file forbids.
var save: SaveLedger = null



var source: String = "<defaults>"
var loaded: bool = false
var problems: Array[String] = []
## {slot:int, type:String, hp:int, max_hp:int, downed:bool, level:int, rarity:String,
##  downed_at:int}. The dictionaries are shared by reference (that is how
## water()/fertilize() mutate the roster), so a caller must treat what slot_at()
## returns as read-only.
##
## [P14] `downed_at` is an absolute unix timestamp (0 = not downed): a DOWNED plant
## recovers on its own once `recovery_seconds(level, rarity)` have passed in REAL
## time, so the clock keeps running while the game is closed.
var slots: Array[Dictionary] = []


# ---------------------------------------------------------------- construction
static func load_or_create() -> Garden:
	## Called once by Game at start-up. Creates the starting garden on first run.
	if live == null:
		live = Garden.new()
	live.load_from_disk()
	return live


func apply_defaults() -> void:
	## Defaults come from Balance, so there is still exactly one place for numbers.
	slots = []
	var index := 0
	for item in BalanceGarden.GARDEN_START_ROSTER:
		var type_id := str(item)
		var max_hp := Balance.plant_max_hp(type_id)
		slots.append(new_slot(index, type_id, max_hp, Balance.plant_rarity(type_id), 1))
		index += 1


static func new_slot(p_slot: int, p_type: String, p_hp: int, p_rarity: String,
		p_level: int) -> Dictionary:
	## [P14] One garden plant. `downed` always means exactly "hp == 0", and
	## `downed_at` is the wall-clock moment it went down (0 while it is standing).
	## [P15] `exp` counts towards the next level, `talents` records which talent
	## potions this instance has already taken (each one only works once), and
	## `max_hp` is DERIVED from type + level + talents.
	return {
		"slot": p_slot,
		"type": p_type,
		"hp": p_hp,
		"max_hp": Balance.plant_attr_hp(p_type, maxi(1, p_level), false),
		"downed": p_hp <= 0,
		"level": maxi(1, p_level),
		"rarity": p_rarity,
		"downed_at": 0,
		"exp": 0,
		"talents": {},
	}


func max_hp_of(p_slot: int) -> int:
	## The single source of truth for a plant's health ceiling: DERIVED from type +
	## level + talent (and the plant sheet carries the base hp), never read from the
	## stored value.
	var s := slot_at(p_slot)
	if s.is_empty():
		return 1
	return Balance.plant_attr_hp(str(s["type"]), int(s["level"]), has_talent(p_slot))


func refresh_max_hp() -> int:
	## [P26] Re-derive every slot's ceiling from type + level + talent. Called right
	## after the unit sheets are re-read (R in game), because a data edit must not
	## leave an old ceiling behind in the roster. The same rules the save-file loader
	## uses:
	##   a plant at FULL health stays at full health (it gains the difference)
	##   a wounded plant keeps its wounds, clamped to the new ceiling
	##   a DOWNED plant (hp 0) stays down
	## Returns how many slots actually changed, which is what the caller logs.
	var changed := 0
	for s in slots:
		var type_id := str(s.get("type", ""))
		var level := maxi(1, int(s.get("level", 1)))
		var talents: Dictionary = s.get("talents", {})
		var new_max := Balance.plant_attr_hp(type_id, level, not talents.is_empty())
		var old_max := int(s.get("max_hp", new_max))
		if new_max == old_max:
			continue
		changed += 1
		var hp := int(s.get("hp", 0))
		s["max_hp"] = new_max
		if bool(s.get("downed", false)) or hp <= 0:
			s["hp"] = 0
		elif hp >= old_max:
			s["hp"] = new_max
		else:
			s["hp"] = mini(hp, new_max)
	return changed


func has_talent(p_slot: int, p_talent: String = "") -> bool:
	## With no argument: "does this plant have ANY talent potion in it". With an
	## item id: "has it already taken this particular one" (they never stack).
	var s := slot_at(p_slot)
	if s.is_empty():
		return false
	var talents: Dictionary = s.get("talents", {})
	if p_talent == "":
		return not talents.is_empty()
	return bool(talents.get(p_talent, false))


func skill_value_of(p_slot: int) -> int:
	## What this instance's skill is worth right now (0 = it has no skill).
	var s := slot_at(p_slot)
	if s.is_empty():
		return 0
	return Balance.plant_skill_value(str(s["type"]), int(s["level"]), has_talent(p_slot))


func apply_talent(p_slot: int, p_item: String) -> Dictionary:
	## Talent potions are per INSTANCE and never stack: a plant that already has
	## its talent refuses a second one (the designer asked for that message).
	var s := slot_at(p_slot)
	if s.is_empty():
		return _result(false, Loc.tf("roster.no_plant", [p_slot]))
	var type_id := str(s["type"])
	var wanted := Balance.plant_potion_item(type_id)
	if wanted == "" or p_item != wanted:
		return _result(false, Loc.tf("roster.talent.wrong_type", [Balance.plant_name(type_id), Balance.item_name(p_item)]))
	if has_talent(p_slot, p_item):
		return _result(false, Loc.tf("roster.talent.already", [Balance.plant_name(type_id)]))
	var talents: Dictionary = s.get("talents", {})
	talents[p_item] = true
	s["talents"] = talents
	## the ceiling moves, so the plant immediately gains the health it just earned
	var old_max := int(s["max_hp"])
	var new_max := max_hp_of(p_slot)
	s["max_hp"] = new_max
	if old_max > 0 and int(s["hp"]) > 0:
		s["hp"] = mini(new_max, int(s["hp"]) + (new_max - old_max))
	## [P20] the message the GARDEN page shows, so it follows the language too
	var line := Loc.tf("roster.talent.ok", [Balance.plant_name(type_id), p_slot,
		Balance.item_name(p_item), Balance.plant_potion_text(type_id)])
	return _result(true, line)


func add_exp(p_slot: int, p_amount: int) -> Array[String]:
	## Exp for THIS instance (the designer's rule: the plant that lands the killing
	## blow gets it). Levels up as often as it can afford; each level raises the
	## health ceiling and heals the difference.
	var lines: Array[String] = []
	var s := slot_at(p_slot)
	if s.is_empty() or p_amount <= 0:
		return lines
	s["exp"] = int(s.get("exp", 0)) + p_amount
	while int(s["exp"]) >= Balance.exp_to_next_level(int(s["level"])):
		var cost := Balance.exp_to_next_level(int(s["level"]))
		s["exp"] = int(s["exp"]) - cost
		var old_max := int(s["max_hp"])
		s["level"] = int(s["level"]) + 1
		var new_max := max_hp_of(p_slot)
		s["max_hp"] = new_max
		if int(s["hp"]) > 0:
			s["hp"] = mini(new_max, int(s["hp"]) + (new_max - old_max))
		var line := "%s slot %d reached level %d (max hp %d -> %d)" % [Balance.plant_name(str(s["type"])), p_slot, int(s["level"]), old_max, new_max]
		lines.append(line)
	return lines


func exp_text(p_slot: int) -> String:
	var s := slot_at(p_slot)
	if s.is_empty():
		return "-"
	return "%d / %d" % [int(s.get("exp", 0)), Balance.exp_to_next_level(int(s["level"]))]


func add_plant(p_type: String) -> int:
	## [P14] Reward path: a clear reward can hand the player a whole new plant.
	## Returns the new slot, or -1 when the garden is full / the type is unknown.
	if not Balance.PLANT_DEFS.has(p_type):
		return -1
	var used: Dictionary = {}
	for s in slots:
		used[int(s["slot"])] = true
	var free := -1
	for i in BalanceGarden.GARDEN_CAPACITY:
		if not used.has(i):
			free = i
			break
	if free < 0:
		return -1
	var fresh := new_slot(free, p_type, Balance.plant_attr_hp(p_type, 1, false),
		Balance.plant_rarity(p_type), 1)
	slots.append(fresh)
	slots.sort_custom(_sort_by_slot)
	return free


func _reject(msg: String) -> bool:
	problems.append(msg)
	var keep := source
	apply_defaults()
	source = keep
	problems.append("rejected -> rebuilt the starting garden")
	return false


# ---------------------------------------------------------------- loading
func load_from_disk() -> bool:
	problems.clear()
	source = BalanceGarden.GARDEN_PATH
	if not FileAccess.file_exists(BalanceGarden.GARDEN_PATH):
		apply_defaults()
		loaded = true
		print("[Garden] no garden file yet -> created the starting garden")
		print("[Garden] " + summary_text())
		save_to_disk()
		return true
	var f := FileAccess.open(BalanceGarden.GARDEN_PATH, FileAccess.READ)
	if f == null:
		SafeIO.keep_broken(BalanceGarden.GARDEN_PATH)
		return _reject("cannot open %s (error %d)" % [BalanceGarden.GARDEN_PATH, FileAccess.get_open_error()])
	var text := f.get_as_text()
	f.close()
	var ok := parse_text(text, BalanceGarden.GARDEN_PATH)
	if ok:
		print("[Garden] loaded " + BalanceGarden.GARDEN_PATH)
		print("[Garden] " + summary_text())
		return true
	for line in problems:
		print("[Garden]   " + line)
	print("[Garden] " + summary_text())
	## [P37] Keep the refused file: save_to_disk() below writes the rebuilt roster to
	## the same path, and a garden that cannot be read must still not be lost
	## (OPTIMIZATIONS A1).
	SafeIO.keep_broken(BalanceGarden.GARDEN_PATH)
	save_to_disk()
	return false


func parse_text(text: String, p_source: String) -> bool:
	## Never leaves the game without a garden: any parse or validation failure
	## falls back to the starting roster and records the reason.
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
	var raw: Variant = d.get("plants", null)
	if typeof(raw) != TYPE_ARRAY:
		return _reject("'plants' must be an array")

	var parsed: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry in (raw as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("plant entry is not an object (ignored)")
			continue
		var e: Dictionary = entry
		var type_id := str(e.get("type", ""))
		if not Balance.PLANT_DEFS.has(type_id):
			problems.append("unknown plant type '%s' (ignored)" % type_id)
			continue
		var slot := int(e.get("slot", parsed.size()))
		if slot < 0 or slot >= BalanceGarden.GARDEN_CAPACITY or seen.has(slot):
			problems.append("plant '%s' has an unusable slot %d (ignored)" % [type_id, slot])
			continue
		seen[slot] = true
		var max_hp := Balance.plant_max_hp(type_id)
		var hp := int(e.get("hp", max_hp))
		var level := maxi(1, int(e.get("level", 1)))
		var rarity := str(e.get("rarity", Balance.plant_rarity(type_id)))
		if not Balance.has_rarity(rarity):
			problems.append("plant '%s' rarity '%s' is unknown (reset to its default)" % [type_id, rarity])
			rarity = Balance.plant_rarity(type_id)
		var downed := bool(e.get("downed", false)) or hp <= 0
		var downed_at := int(e.get("downed_at", 0))
		if downed:
			hp = 0                      # DOWNED is exactly "hp is 0": they can never disagree
			if downed_at <= 0:
				## An older save (or a hand-edited file) with no timestamp: start the
				## recovery clock now rather than recovering instantly.
				downed_at = now_unix()
		else:
			downed_at = 0
		hp = mini(hp, max_hp)
		var slot_data := new_slot(slot, type_id, hp, rarity, level)
		slot_data["hp"] = hp
		slot_data["downed"] = downed
		slot_data["downed_at"] = downed_at
		## [P15] experience and talents, then re-derive the health ceiling from
		## type + level + talents (a hand-edited level must not keep a stale max hp)
		slot_data["exp"] = maxi(0, int(e.get("exp", 0)))
		var talents: Dictionary = {}
		var raw_talents: Variant = e.get("talents", {})
		if typeof(raw_talents) == TYPE_DICTIONARY:
			for tkey in (raw_talents as Dictionary).keys():
				var tid := str(tkey)
				if Balance.item_kind(tid) == "talent" and bool((raw_talents as Dictionary)[tkey]):
					talents[tid] = true
		slot_data["talents"] = talents
		var true_max := Balance.plant_attr_hp(type_id, level, not talents.is_empty())
		slot_data["max_hp"] = true_max
		if bool(slot_data["downed"]):
			slot_data["hp"] = 0
		elif hp >= max_hp:
			slot_data["hp"] = true_max      # it was at full health: keep it there
		else:
			slot_data["hp"] = mini(hp, true_max)
		parsed.append(slot_data)

	if parsed.is_empty():
		return _reject("no usable plant entries")
	parsed.sort_custom(_sort_by_slot)
	slots = parsed
	loaded = true
	## [P14] a plant whose recovery clock ran out while the game was closed stands
	## up right here, before anything else looks at the roster
	apply_natural_recovery()
	return true


func to_json_text() -> String:
	var arr: Array = []
	for s in slots:
		arr.append({
			"slot": int(s["slot"]),
			"type": str(s["type"]),
			"hp": int(s["hp"]),
			"max_hp": int(s["max_hp"]),
			"downed": bool(s["downed"]),
			"level": int(s["level"]),
			"rarity": str(s["rarity"]),
			"downed_at": int(s["downed_at"]),
			"exp": int(s.get("exp", 0)),
			"talents": s.get("talents", {}),
		})
	var d := {
		"version": BalanceGarden.GARDEN_VERSION,
		"capacity": BalanceGarden.GARDEN_CAPACITY,
		"_comment": "The plants you own. hp carries over between levels. A DOWNED plant (downed=true, hp=0) recovers by itself after level+rarity decide how long - see downed_at, an absolute unix timestamp - but it comes back with only 1/10 of its health. Fertilizer cures it instantly with half of its health.",
		"plants": arr,
	}
	return JSON.stringify(d, "  ")


func save_to_disk() -> bool:
	if source.begins_with("<"):
		## A scratch instance from self_check(): it must never overwrite the real
		## save file. Refusing loudly is better than corrupting a garden silently.
		push_warning("[Garden] refusing to save a scratch roster (" + source + ")")
		return false
	## [P37] Written to a `.tmp` and renamed in, so an interrupted save leaves the
	## previous garden intact instead of a half file the loader would rebuild
	## from the defaults (OPTIMIZATIONS A1).
	return SafeIO.write_text_atomic(BalanceGarden.GARDEN_PATH, to_json_text())


func snapshot() -> Array[Dictionary]:
	## [P35] One deep copy PER ENTRY: slot_at() hands out the live dictionary and
	## callers write into it, so a shallow copy of the array would not be a snapshot
	## at all (the "talents" sub-dictionary is live for the same reason).
	var out: Array[Dictionary] = []
	for s in slots:
		out.append(s.duplicate(true))
	return out


func restore(p_snap: Array[Dictionary]) -> void:
	## [P35] `slots = []` is the style apply_defaults() already uses; both ends copy,
	## so the snapshot can never be aliased into the live roster.
	slots = []
	for s in p_snap:
		slots.append(s.duplicate(true))


# ---------------------------------------------------------------- queries
func _sort_by_slot(a, b) -> bool:
	return int(a["slot"]) < int(b["slot"])


func slot_at(p_slot: int) -> Dictionary:
	## The LIVE dictionary, not a copy: callers may read it freely, but writing to
	## it changes the roster (that is how water()/fertilize() work).
	for s in slots:
		if int(s["slot"]) == p_slot:
			return s
	return {}


func total() -> int:
	return slots.size()


func count_type(p_type: String) -> int:
	var n := 0
	for s in slots:
		if str(s["type"]) == p_type:
			n += 1
	return n


func downed_count() -> int:
	var n := 0
	for s in slots:
		if bool(s["downed"]):
			n += 1
	return n


func wounded_count() -> int:
	## Wounded = hurt but still standing, i.e. the state WATER can fix.
	var n := 0
	for s in slots:
		if not bool(s["downed"]) and int(s["hp"]) < int(s["max_hp"]):
			n += 1
	return n


func state_of(p_slot: int) -> String:
	var s := slot_at(p_slot)
	if s.is_empty():
		return "-"
	if bool(s["downed"]):
		return BalanceGarden.GARDEN_STATE_DOWNED
	if int(s["hp"]) < int(s["max_hp"]):
		return BalanceGarden.GARDEN_STATE_WOUNDED
	return BalanceGarden.GARDEN_STATE_HEALTHY


func available_slots(p_type: String, p_exclude: Dictionary) -> Array[int]:
	## A garden plant can be summoned when it is neither DOWNED nor already out on
	## the lawn: p_exclude holds the slots this battle has deployed (a slot stays
	## excluded even after its plant dies, so a dead instance is never re-summoned).
	var out: Array[int] = []
	for s in slots:
		if str(s["type"]) != p_type:
			continue
		if bool(s["downed"]):
			continue
		var slot := int(s["slot"])
		if p_exclude.has(slot):
			continue
		out.append(slot)
	return out


func pick_random_available(p_type: String, p_exclude: Dictionary) -> int:
	## The card summons a RANDOM instance of its type: which one you get is not up
	## to you, that is the point of the garden. Returns -1 when nothing is free.
	var pool := available_slots(p_type, p_exclude)
	if pool.is_empty():
		return -1
	return pool[randi() % pool.size()]


func availability_text(p_exclude: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item in Balance.plant_cards():
		var key := str(item)
		## [P31-B] a spirit card never draws from the garden: counting its (always
		## empty) pool here would only mislead the boot log
		if Balance.spirit_base(key) != "":
			continue
		parts.append("%s %d" % [Balance.plant_name(key), available_slots(key, p_exclude).size()])
	return ", ".join(parts)


func summary_text() -> String:
	var parts: PackedStringArray = []
	for s in slots:
		var state := " DOWNED" if bool(s["downed"]) else ""
		parts.append("%s %d/%d%s" % [str(s["type"]), int(s["hp"]), int(s["max_hp"]), state])
	var line := "%d plants: " % slots.size()
	line += ", ".join(parts)
	line += " | %d wounded, %d downed" % [wounded_count(), downed_count()]
	return line


# ---------------------------------------------------------------- care
static func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func recover_seconds_remaining(p_slot: int) -> float:
	## [P14] Seconds until a DOWNED plant stands up on its own. 0.0 when it is not
	## DOWNED or the wait is already over. Wall-clock based on purpose: the timer
	## keeps running while the game is closed.
	var s := slot_at(p_slot)
	if s.is_empty() or not bool(s["downed"]):
		return 0.0
	var secs := Balance.recovery_seconds(int(s["level"]), str(s["rarity"]))
	var elapsed := float(now_unix() - int(s["downed_at"]))
	return maxf(0.0, secs - elapsed)


func apply_natural_recovery() -> Array[String]:
	## [P14] Every DOWNED plant whose clock has run out stands up again with 1/10 of
	## its maximum hp - never with the half a bag of fertilizer gives. Called before
	## anything reads the roster (load, garden page, battle start).
	var lines: Array[String] = []
	for s in slots:
		if not bool(s["downed"]):
			continue
		var secs := Balance.recovery_seconds(int(s["level"]), str(s["rarity"]))
		if float(now_unix() - int(s["downed_at"])) < secs:
			continue
		var max_hp := int(s["max_hp"])
		s["downed"] = false
		s["hp"] = maxi(1, int(ceil(float(max_hp) * Balance.NATURAL_RECOVERY_HP_RATIO)))
		s["downed_at"] = 0
		## [P20] the message the caller shows, so it follows the language
		var line := Loc.tf("roster.recover.self", [Balance.plant_name(str(s["type"])), int(s["slot"]), int(s["hp"]), max_hp])
		lines.append(line)
	return lines


static func _result(p_ok: bool, p_message: String) -> Dictionary:
	return {"ok": p_ok, "message": p_message}


static func _care_amount(p_max_hp: int, p_ratio: float) -> int:
	return maxi(1, int(round(float(p_max_hp) * p_ratio)))


func water(p_slot: int) -> Dictionary:
	## Restores half of the MAX hp, capped. A DOWNED plant cannot be watered: it
	## has to be fertilized first, which is the whole point of the two actions.
	var s := slot_at(p_slot)
	if s.is_empty():
		return _result(false, Loc.tf("roster.no_plant", [p_slot]))
	if bool(s["downed"]):
		return _result(false, Loc.t("roster.water.downed"))
	var max_hp := int(s["max_hp"])
	var before := int(s["hp"])
	if before >= max_hp:
		return _result(false, Loc.tf("roster.water.full", [before, max_hp]))
	var healed := before + _care_amount(max_hp, BalanceGarden.WATER_HEAL_RATIO)
	s["hp"] = mini(healed, max_hp)
	var line := Loc.tf("roster.water.ok", [Balance.plant_name(str(s["type"])), p_slot, before, int(s["hp"])])
	return _result(true, line)


func fertilize(p_slot: int) -> Dictionary:
	## Cures DOWNED and restores half of the MAX hp in the same action - a plant
	## that died in battle comes home at 0 hp, so the heal is what brings it back.
	## [P14] The caller must have spent a bag of fertilizer first (Game does that),
	## and that is the ONLY difference from waiting for natural recovery: a bag is
	## instant and gives half the health, waiting is free and gives a tenth.
	var s := slot_at(p_slot)
	if s.is_empty():
		return _result(false, Loc.tf("roster.no_plant", [p_slot]))
	if not bool(s["downed"]):
		return _result(false, Loc.t("roster.fertilize.healthy"))
	var max_hp := int(s["max_hp"])
	s["downed"] = false
	s["downed_at"] = 0
	s["hp"] = mini(_care_amount(max_hp, BalanceGarden.FERTILIZE_HEAL_RATIO), max_hp)
	var line := Loc.tf("roster.fertilize.ok", [Balance.plant_name(str(s["type"])), p_slot, int(s["hp"])])
	return _result(true, line)


# ---------------------------------------------------------------- battle ledger
func apply_results(results: Dictionary) -> Array[String]:
	## The battle ledger landing for real. `results` is slot -> {hp:int, alive:bool,
	## exp:int} for every garden plant that was out on the lawn this battle. Returns
	## one log line per plant that actually changed (or that went missing).
	## [P15] exp rides along in the same ledger on purpose: if it were written the
	## moment a zombie died, pressing R would leave the experience behind and
	## farming a level could be exploited.
	var lines: Array[String] = []
	var keys: Array = results.keys()
	keys.sort()
	for key in keys:
		var slot := int(key)
		var s := slot_at(slot)
		if s.is_empty():
			lines.append("slot %d is no longer in the garden (result ignored)" % slot)
			continue
		var r: Dictionary = results[key]
		var plant_label := Balance.plant_name(str(s["type"]))
		var before := int(s["hp"])
		var gained := int(r.get("exp", 0))
		if gained > 0:
			for line in add_exp(slot, gained):
				lines.append(line)
		if not bool(r.get("alive", true)):
			s["downed"] = true
			s["hp"] = 0
			s["downed_at"] = now_unix()   # [P14] the natural recovery clock starts here
			lines.append("%s slot %d died in battle (hp %d) -> DOWNED" % [plant_label, slot, before])
			continue
		var hp := clampi(int(r.get("hp", before)), 1, int(s["max_hp"]))
		s["hp"] = hp
		s["downed"] = false
		s["downed_at"] = 0
		var note := "unchanged"
		if hp < before:
			note = "wounded"
		elif hp > before:
			note = "healed"
		lines.append("%s slot %d hp %d -> %d (%s)" % [plant_label, slot, before, hp, note])
	return lines


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game. Every line is a single physical line on
	## purpose (HANDOFF 7.1), and everything runs on scratch instances so the
	## player's own garden is never touched or overwritten.
	print("[Garden] --- persistent roster (starting garden + care rules) ---")
	var ok := true

	var start := Garden.new()
	start.apply_defaults()
	print("[Garden] starting garden: " + start.summary_text())
	# [P14] the starting garden is exactly one peashooter; everything else is earned
	var start_ok: bool = start.total() == 1 and start.count_type("peashooter") == 1
	start_ok = start_ok and start.downed_count() == 0 and start.wounded_count() == 0
	var s0: Dictionary = start.slot_at(0)
	start_ok = start_ok and int(s0["level"]) == 1 and str(s0["rarity"]) == Balance.RARITY_COMMON
	ok = ok and start_ok
	print("[Garden] starting garden = 1 peashooter (common L1), nothing else: " + str(start_ok)
		+ " | " + ("OK" if start_ok else "FAIL"))

	# the recovery formula: base x rarity x level, peashooter (common L1) == 60 s
	var formula_ok: bool = is_equal_approx(Balance.recovery_seconds(1, Balance.RARITY_COMMON), 60.0)
	formula_ok = formula_ok and is_equal_approx(Balance.recovery_seconds(1, Balance.RARITY_UNCOMMON), 90.0)
	formula_ok = formula_ok and is_equal_approx(Balance.recovery_seconds(2, Balance.RARITY_COMMON), 78.0)
	formula_ok = formula_ok and is_equal_approx(Balance.recovery_seconds(1, Balance.RARITY_RARE), 150.0)
	ok = ok and formula_ok
	print("[Garden] recovery seconds: common L1 60 / uncommon L1 90 / common L2 78 / rare L1 150: "
		+ str(formula_ok) + " | " + ("OK" if formula_ok else "FAIL"))

	# rewards can add whole plants; the garden has a hard capacity
	var grown := Garden.new()
	grown.apply_defaults()
	var add_ok: bool = grown.add_plant("sunflower") == 1 and grown.add_plant("wallnut") == 2
	add_ok = add_ok and grown.add_plant("triffid") == -1 and grown.total() == 3
	## [P95] fill the REST of the roster without naming the capacity twice (add_plant()
	## answers -1 once it is full, so this loop is a no-op for the extra iterations)
	for i in BalanceGarden.GARDEN_CAPACITY:
		grown.add_plant("sunflower")
	add_ok = add_ok and grown.total() == BalanceGarden.GARDEN_CAPACITY and grown.add_plant("sunflower") == -1
	ok = ok and add_ok
	print("[Garden] reward plants land in free slots, garden stops at capacity "
		+ str(BalanceGarden.GARDEN_CAPACITY) + ": " + str(add_ok) + " | " + ("OK" if add_ok else "FAIL"))

	# save -> load round trip: hp, DOWNED, level, rarity and the recovery clock
	var saved := Garden.new()
	saved.apply_defaults()
	saved.add_plant("sunflower")
	saved.add_plant("wallnut")
	var w0: Dictionary = saved.slot_at(0)
	var w1: Dictionary = saved.slot_at(1)
	w0["hp"] = 137
	w0["level"] = 3
	w1["hp"] = 0
	w1["downed"] = true
	w1["rarity"] = Balance.RARITY_RARE
	## [P37] A LIVE clock, not an old one: parse_text() applies natural recovery
	## before anything reads the roster (P14), so a timestamp from 1970 would be
	## revived on the way in and this would be testing the recovery rule by accident.
	w1["downed_at"] = now_unix() - 1
	var reloaded := Garden.new()
	var parsed: bool = reloaded.parse_text(saved.to_json_text(), "<probe>")
	var r0: Dictionary = reloaded.slot_at(0)
	var r1: Dictionary = reloaded.slot_at(1)
	var trip_ok: bool = parsed and int(r0["hp"]) == 137 and int(r0["level"]) == 3
	trip_ok = trip_ok and bool(r1["downed"]) and int(r1["hp"]) == 0
	trip_ok = trip_ok and str(r1["rarity"]) == Balance.RARITY_RARE
	trip_ok = trip_ok and int(r1["downed_at"]) > 0
	ok = ok and trip_ok
	print("[Garden] save -> load keeps hp 137, level 3, DOWNED + rarity + clock: " + str(trip_ok)
		+ " | " + ("OK" if trip_ok else "FAIL"))

	var broken := Garden.new()
	var broken_ok: bool = not broken.parse_text("{ this is not json", "<probe>")
	broken_ok = broken_ok and broken.total() == BalanceGarden.GARDEN_START_ROSTER.size()
	broken_ok = broken_ok and broken.downed_count() == 0
	ok = ok and broken_ok
	print("[Garden] broken json rejected, starting garden rebuilt: " + str(broken_ok)
		+ " | " + ("OK" if broken_ok else "FAIL"))

	var mixed := Garden.new()
	var mixed_parsed: bool = mixed.parse_text('{"plants":[{"slot":0,"type":"sunflower","hp":300},{"slot":1,"type":"triffid","hp":10},{"slot":2,"type":"wallnut","hp":0,"downed":true}]}', "<probe>")
	var mixed_ok: bool = mixed_parsed and mixed.total() == 2 and mixed.count_type("sunflower") == 1
	mixed_ok = mixed_ok and mixed.downed_count() == 1
	mixed_ok = mixed_ok and mixed.available_slots("wallnut", {}).is_empty()
	ok = ok and mixed_ok
	print("[Garden] unknown plant type dropped, DOWNED wall-nut not summonable: " + str(mixed_ok)
		+ " | " + ("OK" if mixed_ok else "FAIL"))

	# the random draw must never hand out a DOWNED or an already deployed instance
	var draws := Garden.new()
	draws.apply_defaults()
	draws.add_plant("sunflower")
	draws.add_plant("sunflower")
	draws.add_plant("sunflower")
	var d_down: Dictionary = draws.slot_at(3)
	d_down["hp"] = 0
	d_down["downed"] = true
	var exclude: Dictionary = {0: true}
	var draws_ok := true
	## [P37] The pool is the two STANDING sunflowers (slots 1 and 2): the old
	## assertion demanded the answer be exactly 1 every time, which a random pick
	## cannot promise - it only ever passed while the starting roster happened to
	## leave one candidate. Demand the legal set instead, and demand that 50 draws
	## actually reach BOTH instances (missing one would be a 2^-49 chance, and a
	## picker that always returns the first cell is exactly what that catches).
	var seen: Dictionary = {}
	for i in 50:
		var got := draws.pick_random_available("sunflower", exclude)
		if got != 1 and got != 2:
			draws_ok = false
		seen[got] = true
	draws_ok = draws_ok and seen.has(1) and seen.has(2)
	draws_ok = draws_ok and draws.available_slots("sunflower", {}).size() == 2
	draws_ok = draws_ok and draws.pick_random_available("sunflower", {1: true, 2: true}) == -1
	ok = ok and draws_ok
	print("[Garden] 50 draws never returned a DOWNED or excluded instance: " + str(draws_ok)
		+ " | " + ("OK" if draws_ok else "FAIL"))

	# watering: +50% of max hp, capped, refused when full or DOWNED
	var care := Garden.new()
	care.apply_defaults()
	care.add_plant("sunflower")
	care.add_plant("wallnut")
	var c0: Dictionary = care.slot_at(0)          # peashooter, 300 hp
	c0["hp"] = 100
	var w_a: Dictionary = care.water(0)
	var h_a: Dictionary = care.slot_at(0)
	var water_ok: bool = bool(w_a["ok"]) and int(h_a["hp"]) == 250
	c0["hp"] = 300
	var w_b: Dictionary = care.water(0)
	water_ok = water_ok and not bool(w_b["ok"])
	c0["hp"] = 100
	var w_c: Dictionary = care.water(0)
	var h_c: Dictionary = care.slot_at(0)
	water_ok = water_ok and bool(w_c["ok"]) and int(h_c["hp"]) == 250
	var w_d: Dictionary = care.water(0)
	var h_d: Dictionary = care.slot_at(0)
	water_ok = water_ok and bool(w_d["ok"]) and int(h_d["hp"]) == 300
	var c2: Dictionary = care.slot_at(2)          # wall-nut, 1000 hp
	c2["hp"] = 0
	c2["downed"] = true
	c2["downed_at"] = now_unix()
	var w_e: Dictionary = care.water(2)
	var h_e: Dictionary = care.slot_at(2)
	water_ok = water_ok and not bool(w_e["ok"]) and int(h_e["hp"]) == 0
	ok = ok and water_ok
	print("[Garden] water: 100 -> 250 -> 300 (capped), refused at full hp and when DOWNED: "
		+ str(water_ok) + " | " + ("OK" if water_ok else "FAIL"))

	# fertilizing: cures DOWNED and restores half of max hp; useless on a healthy plant
	var fert: Dictionary = care.fertilize(2)
	var f2: Dictionary = care.slot_at(2)
	var fert_ok: bool = bool(fert["ok"]) and not bool(f2["downed"]) and int(f2["hp"]) == 500
	fert_ok = fert_ok and int(f2["downed_at"]) == 0
	var fert_bad: Dictionary = care.fertilize(0)
	fert_ok = fert_ok and not bool(fert_bad["ok"])
	ok = ok and fert_ok
	print("[Garden] fertilize: DOWNED cured 0 -> 500 hp and clock cleared, refused when healthy: "
		+ str(fert_ok) + " | " + ("OK" if fert_ok else "FAIL"))

	# [P14] natural recovery: free, wall-clock, and only a tenth of the health
	var rec := Garden.new()
	rec.apply_defaults()
	rec.add_plant("wallnut")
	var p0: Dictionary = rec.slot_at(0)           # peashooter, common L1 = 60 s
	p0["hp"] = 0
	p0["downed"] = true
	p0["downed_at"] = now_unix()
	var p1: Dictionary = rec.slot_at(1)           # wall-nut, uncommon L1 = 90 s
	p1["hp"] = 0
	p1["downed"] = true
	p1["downed_at"] = now_unix() - 100            # its clock already ran out
	var waiting: float = rec.recover_seconds_remaining(0)
	var rec_lines: Array[String] = rec.apply_natural_recovery()
	var rec_ok: bool = waiting > 0.0 and bool(p0["downed"])
	rec_ok = rec_ok and not bool(p1["downed"]) and int(p1["hp"]) == 100
	rec_ok = rec_ok and int(p1["downed_at"]) == 0 and rec_lines.size() == 1
	rec_ok = rec_ok and int(ceil(1000.0 * Balance.NATURAL_RECOVERY_HP_RATIO)) == 100
	# a recovered plant can be summoned again, the waiting one cannot
	rec_ok = rec_ok and rec.available_slots("wallnut", {}).size() == 1
	rec_ok = rec_ok and rec.available_slots("peashooter", {}).is_empty()
	ok = ok and rec_ok
	print("[Garden] natural recovery: free, 1/10 hp (1000 -> 100), clock keeps the other one DOWNED: "
		+ str(rec_ok) + " | " + ("OK" if rec_ok else "FAIL"))

	# the battle ledger
	var settled := Garden.new()
	settled.apply_defaults()
	settled.add_plant("sunflower")
	var lines: Array[String] = settled.apply_results({0: {"hp": 120, "alive": true}, 1: {"hp": 0, "alive": false}})
	var l0: Dictionary = settled.slot_at(0)
	var l1: Dictionary = settled.slot_at(1)
	var ledger_ok: bool = int(l0["hp"]) == 120 and not bool(l0["downed"])
	ledger_ok = ledger_ok and bool(l1["downed"]) and int(l1["hp"]) == 0
	ledger_ok = ledger_ok and int(l1["downed_at"]) > 0
	ledger_ok = ledger_ok and lines.size() == 2
	ok = ok and ledger_ok
	print("[Garden] ledger: death -> DOWNED + clock started, survivor keeps 120 hp: "
		+ str(ledger_ok) + " | " + ("OK" if ledger_ok else "FAIL"))

	# [P15] levels, exp and talent potions
	var grow := Garden.new()
	grow.apply_defaults()
	var g0: Dictionary = grow.slot_at(0)
	var skill_ok: bool = grow.skill_value_of(0) == Balance.plant_base_skill("peashooter")
	grow.add_exp(0, 0)
	grow.add_exp(0, 100)                                   # exactly one level
	skill_ok = skill_ok and int(g0["level"]) == 2 and int(g0["exp"]) == 0
	skill_ok = skill_ok and grow.skill_value_of(0) == 22   # 20 x 1.1
	skill_ok = skill_ok and int(g0["max_hp"]) == 330       # 300 x 1.1
	grow.add_exp(0, 450)                                   # 200 for L3 + 250 left
	skill_ok = skill_ok and int(g0["level"]) == 3 and int(g0["exp"]) == 250
	var talent: Dictionary = grow.apply_talent(0, Balance.ITEM_POTION_PEASHOOTER)
	var talent_again: Dictionary = grow.apply_talent(0, Balance.ITEM_POTION_PEASHOOTER)
	skill_ok = skill_ok and bool(talent["ok"]) and not bool(talent_again["ok"])
	skill_ok = skill_ok and int(g0["max_hp"]) == 360
	## [P37] 36, not 40: the pea line's potion lifts its SKILL (P34 decided a shooter's
	## bottle is damage and a wall's is hp), so the value is 20 x 1.2 (level 3)
	## x 1.5 (talent) = 36. The old literal was the number from the hp-potion era.
	skill_ok = skill_ok and grow.skill_value_of(0) == 36
	var wrong: Dictionary = grow.apply_talent(0, Balance.ITEM_POTION_WALLNUT)
	skill_ok = skill_ok and not bool(wrong["ok"])
	ok = ok and skill_ok
	print("[Garden] level/exp/talent: L3 in 550 exp, skill 20 -> 22 -> 36 with the potion, no stacking: "
		+ str(skill_ok) + " | " + ("OK" if skill_ok else "FAIL"))

	print("[Garden] self-check %s" % ("PASSED" if ok else "FAILED"))


func use_exp_potion(slot: int) -> Dictionary:
	## [P15] Spend one EXP Potion on a chosen plant. Bought in the SHOP, used here:
	## the player decides which plant grows, which is the point of per-plant exp.
	## [P109] Reads `slot_at` on SELF since the self-referencing `garden` field is gone;
	## "not loaded" now means "the profile handle was never injected".
	if profile == null:
		return {"ok": false, "message": Loc.t("msg.garden.not_loaded")}
	if slot_at(slot).is_empty():
		return {"ok": false, "message": Loc.tf("msg.garden.slot_empty", [slot])}
	if not profile.take_item(Balance.ITEM_EXP_POTION, 1, Profile.CONTAINER_WAREHOUSE):
		return {"ok": false, "message": Loc.t("msg.potion.no_exp")}
	var before_level: int = int(slot_at(slot)["level"])
	save.save_garden()
	save.save_profile()
	var plant_name := Balance.plant_name(str(slot_at(slot)["type"]))
	var message := Loc.tf("msg.potion.exp", [plant_name, Balance.EXP_POTION_AMOUNT])
	var after_level: int = int(slot_at(slot)["level"])
	if after_level > before_level:
		message += Loc.tf("msg.potion.level_up", [after_level])
	return {"ok": true, "message": message}


func use_talent_potion(slot: int) -> Dictionary:
	## [P15] Spend the talent potion that belongs to this plant's type. Refuses when
	## the plant already has it (talents never stack) or when none is in stock.
	if profile == null:
		return {"ok": false, "message": Loc.t("msg.garden.not_loaded")}
	var info: Dictionary = slot_at(slot)
	if info.is_empty():
		return {"ok": false, "message": Loc.tf("msg.garden.slot_empty", [slot])}
	var item := Balance.plant_potion_item(str(info["type"]))
	if item == "":
		return {"ok": false, "message": Loc.tf("msg.talent.no_potion", [Balance.plant_name(str(info["type"]))])}
	if has_talent(slot, item):
		return {"ok": false, "message": Loc.tf("msg.talent.already", [Balance.plant_name(str(info["type"]))])}
	if not profile.take_item(item, 1, Profile.CONTAINER_WAREHOUSE):
		return {"ok": false, "message": Loc.tf("msg.talent.none_in_stock", [Balance.item_name(item)])}
	var result: Dictionary = apply_talent(slot, item)
	if not bool(result.get("ok", false)):
		profile.add_item(item, 1, Profile.CONTAINER_WAREHOUSE, false)
		return result
	save.save_garden()
	save.save_profile()
	return result


func fertilize_plant(slot: int) -> Dictionary:
	## [P14] Fertilizing costs a bag, so it goes through Game: the garden itself
	## stays free of inventory knowledge. Returns {ok, message} for the garden page.
	if profile == null:
		return {"ok": false, "message": Loc.t("msg.garden.not_loaded")}
	var info: Dictionary = slot_at(slot)
	if info.is_empty():
		return {"ok": false, "message": Loc.tf("msg.garden.slot_empty", [slot])}
	if not bool(info["downed"]):
		return {"ok": false, "message": Loc.t("msg.fertilize.not_downed")}
	if not profile.take_item(Balance.ITEM_FERTILIZER, 1, Profile.CONTAINER_WAREHOUSE):
		return {"ok": false, "message": Loc.t("msg.fertilize.none_in_stock")}
	var result: Dictionary = fertilize(slot)
	if not bool(result.get("ok", false)):
		## give the bag back rather than eating it on a refused fertilize
		profile.add_item(Balance.ITEM_FERTILIZER, 1, Profile.CONTAINER_WAREHOUSE, false)
		return result
	save.save_garden()
	save.save_profile()
	return result


func recover_garden() -> Array[String]:
	## [P37] OPTIMIZATIONS A4: four screens used to apply the natural recovery and then
	## DROP the result, so a plant whose clock ran out while the player was browsing the
	## menu stood up on screen and went back down on the next launch. One helper, one
	## write-back - recovery only counts once it is on disk.
	## [P66] A4's second half, and the reason this name lost its underscore and its `int`
	## grew into the lines: the GARDEN PAGE had kept its own copy of the rule - its tick
	## applied the recovery, took the first line for its own status label and saved on its
	## own - so "one helper" was only ever true of the MENU screens. A second owner is not
	## a cosmetic problem: the two copies could disagree about whether a stand-up counts,
	## because only one of them had ever been made to go through the save door.
	## It returns the LINES rather than a count because the caller that needs it needs the
	## sentence (the page shows `recovered[0]`), and it is PUBLIC for the same reason P65's
	## three save doors are: a private door leaves the page with no legal way in.
	var recovered: Array[String] = apply_natural_recovery()
	for line in recovered:
		print("[Garden] " + line)
	if not recovered.is_empty():
		save.save_garden()
	return recovered
