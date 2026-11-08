extends RefCounted
## [P84] THE ARCHITECTURE CHECKS - claims about the SHAPE of the source tree, not about the
## game: a walk of `scripts/` with a line count per file, a set comparison of constant names
## between the number tables, and a preload-scope test.
##
## [P99] THE SIZE BUDGET IS LIFTED - by user decision (2026-09-26). The three numbers are
## still MEASURED and printed at every boot ("did the god file grow again?" is still worth
## answering), but they no longer FAIL anything. History: the ratchet was raised once
## (36000 -> 39000, P88) and by P98 it was down to 7 lines of headroom, at which point
## adding a feature meant shaving comments and deleting API to fit a number. The owner of
## the budget called that off; `docs/OPTIMIZATIONS.md` §0 still lists the debt itself.
##
## The two claims that are about CORRECTNESS still FAIL: a constant with two owners, and a
## preload constant used without being declared. Those are rules, not budgets.
##
## DELIBERATELY WITHOUT `class_name`, static, preloaded by the caller (the `SafeIO` /
## `Rewards` / `DropDB` family): a new global class is invisible to `godot --headless`
## until the editor rescans, and a check that cannot run headlessly is not a check.

const SCRIPT_ROOT := "res://scripts"

## What "god file" means in the report below (P85 measured 5 of them; the count is a
## readout now, not a limit).
const BIG_FILE_LINES := 1000

## [P106] THE BOUNDARY, AS A RULE - and the reason it is a RULE and not a memory: four earlier
## cuts (P35 / P36 / P61 / P64) moved about a thousand lines out of the manager and it grew
## straight back, because moving CODE does not move OWNERSHIP. The battle now owns one battle
## (scripts/core/battle/battle.gd) and the manager owns the session, the front-end and the
## saves. A name declared in BOTH files therefore has two owners - the exact thing AGENTS.md
## §2 forbids - so this fails on it.
##
## The allowlist is deliberate and small: the INPUTS Game folds and hands over (which level,
## which difficulty, whether a campaign node sent us), the doors each side keeps (a message
## wrapper, the per-frame tick, the two doors screen_flow calls), and the questions both answer
## by reading the SAME profile (owning a scroll is a backpack fact). Everything else is a leak.
const BATTLE_SCRIPT := "res://scripts/core/battle/battle.gd"
const GAME_SCRIPT := "res://scripts/core/game_manager.gd"
const SHARED_ALLOWED: Array[String] = [
	"level", "level_path", "difficulty_key", "difficulty_zombie_hp_mult",
	"level_start_sun", "level_sun_per_turn", "level_sunflower_sun", "_run_battle",
	"_set_message", "set_message", "_process", "retreat", "has_scroll_for", "backpack_total",
	"_sort_by_col", "_sort_by_row_col", "damage_brain", "get_zombies_ahead",
	"sunflower_sun_value", "set_board_visible", "garden_settled", "settle_ledger",
]


static func _declared_names(p_path: String) -> Array[String]:
	## Every name a script DECLARES (a function, a field, a constant, a signal). Comments and
	## string contents declare nothing, so `_code_of` runs first: a name that only appears in a
	## doc line must not count as an owner.
	var re := RegEx.new()
	re.compile("^(?:@onready )?(?:static )?(?:func|var|const|signal) ([A-Za-z_][A-Za-z0-9_]*)")
	var out: Array[String] = []
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return out
	var text := _code_of(f.get_as_text())
	f.close()
	for line in text.split("\n"):
		## A preload constant is FILE-scoped by design (PITFALLS 68): the same name in two
		## scripts is not two owners, it is the rule working. Everything else counts.
		if line.contains("preload("):
			continue
		var m := re.search(line)
		if m != null and not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out

## The tables that own numbers. If a constant name appears in two of them, the number has two
## owners - the exact thing AGENTS.md §2 forbids (Balance must not read BalanceUI).
## [P108] The four SCENE tables joined this list when the scene constants left balance.gd
## (battle / garden / run / shop): a scene may not re-spell a number Balance already owns, and
## no two scenes may own the same name.
const TABLES: Array[String] = [
	"res://scripts/balance/balance.gd",
	"res://scripts/balance/balance_ui.gd",
	"res://scripts/balance/balance_audio.gd",
	"res://scripts/balance/balance_battle.gd",
	"res://scripts/balance/balance_garden.gd",
	"res://scripts/balance/balance_run.gd",
	"res://scripts/balance/balance_shop.gd",
	## [B1] the brawl's own table: the real-time mode's numbers, joining the list under the
	## same rule as the four scene tables above (a scene may not re-spell a number Balance
	## already owns, and no two scenes may own the same name).
	"res://scripts/balance/balance_brawl.gd",
	## [W2] the war's own table: the fixed-world/camera numbers of the war mode, joining the
	## list under the same rule as balance_brawl above (its constants all carry WORLD_/WAR_/
	## CAMERA_ prefixes precisely so this check has no twin to find).
	"res://scripts/balance/balance_war.gd",
]


static func _gd_files() -> Array[String]:
	var out: Array[String] = []
	_walk(SCRIPT_ROOT, out)
	out.sort()
	return out


static func _walk(p_dir: String, p_out: Array[String]) -> void:
	var d := DirAccess.open(p_dir)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var path := p_dir.path_join(entry)
			if d.current_is_dir():
				_walk(path, p_out)
			elif entry.ends_with(".gd"):
				p_out.append(path)
		entry = d.get_next()
	d.list_dir_end()


static func _line_count(p_path: String) -> int:
	## Counts the way `wc -l` does (a trailing newline is not an extra line), because the
	## numbers quoted in the docs were measured that way.
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return 0
	var parts := f.get_as_text().split("\n")
	f.close()
	var n := parts.size()
	if n > 0 and parts[n - 1] == "":
		n -= 1
	return n


static func _const_names(p_path: String) -> Array[String]:
	var re := RegEx.new()
	## [P85] ANY identifier, not just UPPER_SNAKE: `const Rewards := preload(...)` is exactly
	## the declaration this has to see, and matching only `[A-Z0-9_]+` made the scope check
	## report 18 correct files as broken on its first run.
	re.compile("^const ([A-Za-z_][A-Za-z0-9_]*)")
	var out: Array[String] = []
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var m := re.search(f.get_line())
		if m != null:
			out.append(m.get_string(1))
	f.close()
	return out


static func _declared_preloads() -> Dictionary:
	## Every name the project hands around as `const X := preload(...)`, from every file.
	## This is the set that a `const` is scoped to ONE script (`docs/PITFALLS.md` 第 68 条).
	var re := RegEx.new()
	re.compile("^const ([A-Za-z_][A-Za-z0-9_]*)\\s*:=\\s*preload\\(")
	var out := {}
	for path in _gd_files():
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		while not f.eof_reached():
			var m := re.search(f.get_line())
			if m != null:
				out[m.get_string(1)] = true
		f.close()
	return out


static func _class_names() -> Dictionary:
	## A `class_name` really is global, so using one without declaring it is CORRECT -
	## those names must not be reported.
	var re := RegEx.new()
	re.compile("^class_name ([A-Za-z_][A-Za-z0-9_]*)")
	var out := {}
	for path in _gd_files():
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		while not f.eof_reached():
			var m := re.search(f.get_line())
			if m != null:
				out[m.get_string(1)] = true
		f.close()
	return out


static func _code_of(p_text: String) -> String:
	## The source with comments removed and string CONTENTS blanked, because a name that
	## only appears inside a message ("[SafeIO] ...") or a doc line is not a use of it.
	## Written by hand rather than with a regex: GDScript has no non-greedy multi-line
	## comment match, and a wrong answer here would be a check that cries wolf.
	var out := ""
	var quote := ""
	var i := 0
	while i < p_text.length():
		var c := p_text[i]
		if quote != "":
			if c == quote:
				quote = ""
				out += c
			elif c == "\n":
				out += "\n"
			else:
				out += " "
			i += 1
			continue
		if c == "\"" or c == "'":
			quote = c
			out += c
			i += 1
			continue
		if c == "#":
			while i < p_text.length() and p_text[i] != "\n":
				i += 1
			continue
		out += c
		i += 1
	return out


static func self_check() -> void:
	## One physical line per claim (ARCHITECTURE.md §5.3). Every number here is counted,
	## never typed. [P99] the size lines are readouts; the two rule lines below still FAIL.
	var ok := true
	var files := _gd_files()
	var total := 0
	var biggest := 0
	var biggest_path := "-"
	var big := 0
	for path in files:
		var n := _line_count(path)
		total += n
		if n > biggest:
			biggest = n
			biggest_path = path.trim_prefix("res://")
		if n > BIG_FILE_LINES:
			big += 1
	## [P99] Three READOUTS (the budget is lifted - see the header). They still answer the
	## question the ratchet was written for, and a batch that grows a file by a thousand
	## lines should still see it in the log; nothing here FAILs.
	ok = ok and files.size() > 0
	print("[Arch] the largest script is %s at %d line(s)" % [biggest_path, biggest])
	print("[Arch] %d file(s) are over %d lines (every one of them is debt in OPTIMIZATIONS.md §0)"
		% [big, BIG_FILE_LINES])
	print("[Arch] %d GDScript line(s) across %d file(s)" % [total, files.size()])
	var seen := {}
	var dups: Array[String] = []
	for path in TABLES:
		for name in _const_names(path):
			if seen.has(name) and not dups.has(name):
				dups.append(name)
			seen[name] = true
	var owner_ok: bool = dups.is_empty()
	print("[Arch] no constant name is declared by two of the %d number tables = %s | %s"
		% [TABLES.size(), str(owner_ok), "OK" if owner_ok else "FAIL"])
	ok = ok and owner_ok
	if not dups.is_empty():
		print("[Arch] WARN the shared names are: " + ", ".join(dups))
	## A `const` lives in ONE script's scope (docs/PITFALLS.md 第 68 条). P83 shipped a
	## `DropDB` reference in `rewards.gd` without the declaration and P85 the same in
	## `probe_board.gd`; both cost a whole debugging round, because the symptom is a script
	## that silently fails to compile and takes its callers with it. This is the check that
	## makes that mistake impossible rather than merely remembered.
	var declared := _declared_preloads()
	var global := _class_names()
	var use_re := RegEx.new()
	use_re.compile("[A-Za-z_][A-Za-z0-9_]*")
	var undeclared: Array[String] = []
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var mine := {}
		for name in _const_names(path):
			mine[name] = true
		var text := _code_of(f.get_as_text())
		f.close()
		for m in use_re.search_all(text):
			var name := m.get_string(0)
			if not declared.has(name) or global.has(name) or mine.has(name):
				continue
			var where := "%s uses %s" % [path.trim_prefix("res://"), name]
			if not undeclared.has(where):
				undeclared.append(where)
	var scope_ok: bool = undeclared.is_empty()
	print("[Arch] every script that uses a preload constant declares it itself (%d name(s) tracked) = %s | %s"
		% [declared.size(), str(scope_ok), "OK" if scope_ok else "FAIL"])
	ok = ok and scope_ok
	for line in undeclared:
		print("[Arch] WARN " + line)
	## [P106] the boundary between one battle and the session (see the constants at the top).
	var battle_names := _declared_names(BATTLE_SCRIPT)
	var game_names := _declared_names(GAME_SCRIPT)
	var shared: Array[String] = []
	for name in battle_names:
		if game_names.has(name) and not SHARED_ALLOWED.has(name):
			shared.append(name)
	shared.sort()
	var split_ok: bool = shared.is_empty()
	print("[Arch] no per-battle name is also declared by the manager (%d battle name(s), %d allowed to overlap) = %s | %s"
		% [battle_names.size(), SHARED_ALLOWED.size(), str(split_ok), "OK" if split_ok else "FAIL"])
	ok = ok and split_ok
	for name in shared:
		print("[Arch] WARN two owners: " + name + " is declared by both the battle and the manager")
	print("[Arch] self-check %s" % ("PASSED" if ok else "FAILED"))