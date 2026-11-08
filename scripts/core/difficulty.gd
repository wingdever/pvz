class_name Difficulty
extends RefCounted
## [P6] Difficulty presets. Everything here is a multiplier applied on top of
## the level data, so tuning difficulty never means editing gameplay code.
##
## [P81] OPTIMIZATIONS D3. The table below is still a Dictionary - it is DATA - but
## nothing leaves this file as one any more. `preset()` used to hand a caller the whole
## copied preset, and the caller picked values out by bracket, which gave one question
## ("what does a key nobody spelled answer?") two different answers in the SAME battle:
## `float(diff["sun_mult"])` crashed, `diff.get("zombie_hp_mult", 1.0)` silently scaled
## by 1.0. Three typed accessors now own the conversion, so the bracket spellings that
## can still be wrong are the ones INSIDE this file, next to the data they name.

const ORDER: Array[String] = ["easy", "normal", "hard"]
## [P81] The preset that answers when nobody named one - or when a name landed that is
## not on the list. It was spelled three times in here and twice more outside
## (`LevelData.difficulty_key`, `GameManager.difficulty_key`); those three readers are
## the field defaults a battle plays with before a level has been chosen.
const DEFAULT_KEY := "normal"
## [P81] The three names the data spells for its numbers. They are not decoration: the
## battle's run-mod fold (`game_manager.gd`) looks mods up BY these constants, and the
## boot claim below compares them with `BalanceRun.RUN_MOD_KEYS`, which owns the list
## `RunState.add_mod` accepts. That is what makes "a mod the run carries but the battle
## never folds" - the silent half of this bug family - a red line instead of a wash.
const ZOMBIE_HP_MULT_KEY := "zombie_hp_mult"
const SUN_MULT_KEY := "sun_mult"
const START_SUN_BONUS_KEY := "start_sun_bonus"

const PRESETS := {
	"easy": {
		"label": "EASY",
		"zombie_hp_mult": 0.75,
		"sun_mult": 1.30,
		"start_sun_bonus": 25,
	},
	"normal": {
		"label": "NORMAL",
		"zombie_hp_mult": 1.00,
		"sun_mult": 1.00,
		"start_sun_bonus": 0,
	},
	"hard": {
		"label": "HARD",
		"zombie_hp_mult": 1.35,
		"sun_mult": 0.80,
		"start_sun_bonus": 0,
	},
}


static func has_key(key: String) -> bool:
	return PRESETS.has(key)


static func _preset(key: String) -> Dictionary:
	## [P81] The table's own row - and the reason this one is named with an underscore is
	## that nothing outside it may hold a row any more. GDScript cannot *enforce* that, so
	## what keeps it true is the work below: three typed readers, each asking for one
	## number, and no caller that needs a whole row. It hands out the const row itself
	## rather than the `duplicate(true)` copy the old `preset()` returned, because a copy
	## a caller may tweak is one more place where these six numbers live.
	return PRESETS.get(key, PRESETS[DEFAULT_KEY])


static func zombie_hp_mult(key: String) -> float:
	## [P81] The typed door to one number, and the ONLY one a caller may knock at. A row
	## that spells its keys wrong is an "Invalid get index" here - next to the data -
	## rather than a crash in the middle of a battle, which is what the old
	## `float(diff["sun_mult"])` at the call site was.
	return float(_preset(key)[ZOMBIE_HP_MULT_KEY])


static func sun_mult(key: String) -> float:
	## [P81] Read once, at level start, and folded into the three sun numbers the battle
	## actually plays with - so unlike the zombie multiplier, it needs no home afterwards.
	return float(_preset(key)[SUN_MULT_KEY])


static func start_sun_bonus(key: String) -> int:
	## [P81] The one number that is ADDED rather than multiplied, which is why the run-mod
	## fold in game_manager multiplies two of them and sums the third.
	return int(_preset(key)[START_SUN_BONUS_KEY])


static func label(key: String) -> String:
	## [P20] 简单 / 普通 / 困难 in Chinese, EASY / NORMAL / HARD in English
	## (LocNames "difficulty.<key>"). An unknown key reports the default preset.
	var k := key if PRESETS.has(key) else DEFAULT_KEY
	return Loc.t("difficulty." + k, str(_preset(k)["label"]))


static func next_key(key: String) -> String:
	var i := ORDER.find(key)
	if i < 0:
		return DEFAULT_KEY
	var next_i: int = (i + 1) % ORDER.size()
	return str(ORDER[next_i])


static func self_check() -> void:
	## [P81] OPTIMIZATIONS D3's own gate, and it belongs here rather than in a battle
	## probe because nothing about it needs a board: these are claims about how a table is
	## spelled and how it is read. Three lines, one per way this file can go wrong now.
	print("[Diff] --- difficulty presets (P6, typed by P81) ---")
	var ok := true

	## 1. every preset actually spells the three numbers its accessors ask for, and
	##    answers them as numbers of the right sign.
	var typed := true
	for k in ORDER:
		var row: Dictionary = PRESETS[k]
		## Asking an accessor for a key a row does not have is a SCRIPT ERROR, not a FAIL
		## line - and a probe that dies half way never reaches its verdict (P79's lesson,
		## learned the hard way). Hence the `has` gate BEFORE the reads.
		if not (row.has(ZOMBIE_HP_MULT_KEY) and row.has(SUN_MULT_KEY) and row.has(START_SUN_BONUS_KEY)):
			typed = false
			continue
		typed = typed and zombie_hp_mult(str(k)) > 0.0 and sun_mult(str(k)) > 0.0 \
			and start_sun_bonus(str(k)) >= 0
	print("[Diff] every preset spells the three numbers and answers them as numbers = %s | %s"
		% [str(typed), "OK" if typed else "FAIL"])
	ok = ok and typed

	## 2. the half the split readers could not promise: ONE answer for a key nobody named.
	## `EASY` is the honest unknown - same letters, wrong case - so this also proves a
	## near-miss is treated as unknown rather than quietly matching.
	var unknown := str(ORDER[0]).to_upper()
	var fallback_ok: bool = not has_key(unknown) \
		and zombie_hp_mult(unknown) == zombie_hp_mult(DEFAULT_KEY) \
		and sun_mult(unknown) == sun_mult(DEFAULT_KEY) \
		and start_sun_bonus(unknown) == start_sun_bonus(DEFAULT_KEY) \
		and label(unknown) == label(DEFAULT_KEY) and next_key(unknown) == DEFAULT_KEY
	print("[Diff] a key nobody named answers the default preset instead of crashing or answering nothing = %s | %s"
		% [str(fallback_ok), "OK" if fallback_ok else "FAIL"])
	ok = ok and fallback_ok

	## 3. the silent half of the family: a run mod the battle never folds is inert without
	## a trace. BalanceRun.RUN_MOD_KEYS owns the list RunState.add_mod accepts, and the
	## constants here are the very tokens game_manager's fold looks mods up by - so a key
	## added on one side and forgotten on the other reddens in this line.
	var fold_ok: bool = BalanceRun.RUN_MOD_KEYS.has(SUN_MULT_KEY) \
		and BalanceRun.RUN_MOD_KEYS.has(ZOMBIE_HP_MULT_KEY) \
		and BalanceRun.RUN_MOD_KEYS.has(START_SUN_BONUS_KEY) \
		and BalanceRun.RUN_MOD_KEYS.size() == 3
	print("[Diff] the three numbers a preset answers are exactly the keys a run mod can fold = %s | %s"
		% [str(fold_ok), "OK" if fold_ok else "FAIL"])
	ok = ok and fold_ok

	print("[Diff] self-check %s" % ("PASSED" if ok else "FAILED"))
