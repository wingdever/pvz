extends RefCounted
## [P84] THE DOCS AUDIT - the structure built in P84 was only checked by hand, and a
## hand-checked structure rots (that is how `docs/HANDOFF.md` got 55 phases behind).
## Four claims, all about the DOCUMENT SET, none about the game:
##   1. every `docs/…md` / `scripts/…gd` / `data/…csv|json` path a LIVE doc mentions exists;
##   2. every file in `docs/history/` is listed in `docs/history/README.md`;
##   3. every file in `docs/history/` carries the archive banner;
##   4. the documents the entry points depend on are all present.
##
## What is NOT checked on purpose: whether the prose is TRUE. That needs a human, and the
## point of these four is to keep that human looking at meaning instead of at 404s.
##
## DELIBERATELY WITHOUT `class_name`, static, preloaded by the caller - same reasons as
## `SafeIO` / `Rewards` / `DropDB`.

const DOCS_DIR := "res://docs"
const HISTORY_DIR := "res://docs/history"
const HISTORY_README := "res://docs/history/README.md"
const ARCHIVE_BANNER := "历史档案"

## The documents a reader is told to start from (INDEX §1/§4 and `AGENTS.md` §4).
const ENTRY_DOCS: Array[String] = [
	"res://AGENTS.md",
	"res://README.md",
	"res://PROMPT.md",
	"res://docs/INDEX.md",
	"res://docs/ARCHITECTURE.md",
	"res://docs/DEV.md",
	"res://docs/STATE.md",
]

## The documents whose paths are checked (the live tier: entries + handbooks + ledger).
const LIVE_DOCS: Array[String] = [
	"res://AGENTS.md",
	"res://README.md",
	"res://PROMPT.md",
	"res://docs/INDEX.md",
	"res://docs/ARCHITECTURE.md",
	"res://docs/DEV.md",
	"res://docs/STATE.md",
	"res://docs/PITFALLS.md",
	"res://docs/OPEN_ITEMS.md",
	"res://docs/OPTIMIZATIONS.md",
	"res://docs/ADD_UNIT.md",
	"res://docs/UNIT_ART.md",
	"res://docs/BALANCE.md",
]

## Paths that are quoted from the REFERENCE PROJECT (the original game), not from this one.
## They are named in `docs/OPEN_ITEMS.md` as evidence and can never resolve here.
const UPSTREAM_PATHS: Array[String] = [
	"scripts/bullet/component/spatter_component_winter_melon.gd",
	"scripts/character/bullet/bullet_000_linear_base.gd",
]

const PATH_PATTERN := "(?:docs|scripts|data)/[A-Za-z0-9_\\-./]+\\.(?:md|gd|csv|json)"


static func _exists(p_path: String) -> bool:
	return FileAccess.file_exists(p_path)


static func _history_files() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(HISTORY_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with(".") and entry.ends_with(".md"):
			out.append(entry)
		entry = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


static func _text(p_path: String) -> String:
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


static func self_check() -> void:
	## One physical line per claim (ARCHITECTURE.md §5.3).
	var ok := true
	if not DirAccess.dir_exists_absolute(DOCS_DIR):
		print("[Docs] docs/ is not part of this build, so the audit is silent = true | OK")
		print("[Docs] self-check PASSED")
		return
	# [repo-slim] docs/history/ is an ignored local archive (not packed into git), so a
	# fresh clone has no such dir. Without this guard claim 1 would flag every live doc's
	# reference to the archive as "missing", and claims 2-3 would print a misleading
	# "0 of 0 history files" OK. The archive claims are silent when the dir is absent.
	var history_present := DirAccess.dir_exists_absolute(HISTORY_DIR)
	# 1. every path a live doc mentions exists
	var re := RegEx.new()
	re.compile(PATH_PATTERN)
	var missing: Array[String] = []
	var checked := 0
	for doc_path in LIVE_DOCS:
		var text := _text(doc_path)
		for m in re.search_all(text):
			var found := m.get_string(0)
			if found.contains("*") or UPSTREAM_PATHS.has(found):
				continue
			if not history_present and found.begins_with("docs/history/"):
				continue
			checked += 1
			if not _exists("res://" + found) and not missing.has(found):
				missing.append(found)
	var paths_ok: bool = missing.is_empty()
	print("[Docs] every one of the %d path(s) the live documents mention exists = %s | %s"
		% [checked, str(paths_ok), "OK" if paths_ok else "FAIL"])
	ok = ok and paths_ok
	for path in missing:
		print("[Docs] WARN no such file: " + path)
	# 2/3. archive claims - silent when the ignored docs/history/ dir is absent
	if history_present:
		# 2. every history file is listed in the history README
		var history_readme := _text(HISTORY_README)
		var unlisted: Array[String] = []
		var unbannered: Array[String] = []
		var history := _history_files()
		for name in history:
			if name == "README.md":
				continue
			if not history_readme.contains(name):
				unlisted.append(name)
			if not _text(HISTORY_DIR.path_join(name)).contains(ARCHIVE_BANNER):
				unbannered.append(name)
		var listed_ok: bool = unlisted.is_empty()
		print("[Docs] every one of the %d history file(s) is listed in docs/history/README.md = %s | %s"
			% [history.size() - 1, str(listed_ok), "OK" if listed_ok else "FAIL"])
		ok = ok and listed_ok
		for name in unlisted:
			print("[Docs] WARN not in the distribution table: " + name)
		var banner_ok: bool = unbannered.is_empty()
		print("[Docs] every history file carries the archive banner (so nobody reads it as current) = %s | %s"
			% [str(banner_ok), "OK" if banner_ok else "FAIL"])
		ok = ok and banner_ok
		for name in unbannered:
			print("[Docs] WARN no banner: " + name)
	else:
		print("[Docs] docs/history/ is not part of this build, so claims 2-3 are silent = true | OK")
	# 3. the entry documents exist
	var absent: Array[String] = []
	for path in ENTRY_DOCS:
		if not _exists(path):
			absent.append(path.trim_prefix("res://"))
	var entry_ok: bool = absent.is_empty()
	print("[Docs] every entry document exists (%d checked) = %s | %s"
		% [ENTRY_DOCS.size(), str(entry_ok), "OK" if entry_ok else "FAIL"])
	ok = ok and entry_ok
	print("[Docs] self-check %s" % ("PASSED" if ok else "FAILED"))