class_name Loc
extends RefCounted
## [P20] One language layer for the whole game: Chinese by default, English on
## request, switched live from the SETTINGS page.
##
## How a string is picked:
##   Loc.t("plant.peashooter")  ->  豌豆射手     (language == zh)
##                              ->  Peashooter   (language == en)
##   Loc.tf("hud.stat.round", [3]) -> "回合 3"  (translate + format in one call)
##
## The tables live in sibling files so each one stays readable:
##   loc_names.gd   units / plants / items / tools / talents / rarity / difficulty
##   loc_ui.gd      menu, HUD, garden, warehouse and shop chrome
##   loc_msgs.gd    battle messages and the result panel
##   loc_garden.gd  the persistent roster's own messages (water / fertilize / talent)
##   loc_run.gd     the adventure run (P31-A): squad, roadmap, node pages, rewards
## Loc itself owns the language state, the lookup and the self-check.
##
## Two rules every table entry obeys:
##   1. Every key carries BOTH "zh" and "en". A half-filled entry is reported by
##      self_check() instead of showing up as an empty label in the UI.
##   2. A translated FORMAT string keeps the same %-placeholders, in the same
##      order as its counterpart: Godot's % operator has no positional form
##      ("%1$s"), so both variants are fed the same argument array. self_check()
##      counts the placeholders of both variants and fails when they differ.
##   3. A literal percent inside a string that goes through tf() is written "%%".
##      A lone "%" is a format character to Godot, and an unsupported one logs an
##      ERROR and returns the template unformatted. self_check() scans every entry
##      that carries at least one placeholder for exactly that mistake.
##
## Missing CJK font: Chinese is served only when the loaded UI font can actually
## draw it (see UiFont.has_cjk). Otherwise the English variant is served, which is
## the rule the talent names already used - a row of tofu boxes is worse than a
## readable English label.

const ZH := "zh"
const EN := "en"
const DEFAULT_LANGUAGE := ZH
const ORDER: Array[String] = [ZH, EN]
## What the language is called IN that language, so the switch button never reads
## as a translation of itself.
const LABELS := {ZH: "中文", EN: "English"}

static var language: String = DEFAULT_LANGUAGE

static var _warned: Dictionary = {}      # key -> true, so a missing key warns once
static var _merged: Dictionary = {}      # [P38] key -> entry, indexed once (see _index)


static func _tables() -> Array:
	## Ordered domain tables. First hit wins, so a key must be unique across them
	## (self_check reports a duplicate instead of letting one silently shadow).
	## [P31-A] LocRun carries the adventure mode's own strings.
	return [LocNames.TABLE, LocUi.TABLE, LocMsgs.TABLE, LocGarden.TABLE, LocRun.TABLE]


static func _index() -> Dictionary:
	## [P38] OPTIMIZATIONS B6: t() / has_key() used to allocate the table ARRAY on every
	## query and then walk five dictionaries in order, and they are called from the
	## per-frame draw code for every label. The tables are `const`, so one merged index
	## answers the same question in a single lookup - and nothing invalidates it (the R
	## key reloads the CSV / JSON sheets, never a language table).
	## First table still wins, exactly like the old linear walk, so a duplicate key
	## cannot change which entry is served; self_check() walks _tables() directly, so
	## the merge never hides the duplicate it reports.
	if _merged.is_empty():
		for table in _tables():
			for key in (table as Dictionary).keys():
				if not _merged.has(key):
					_merged[key] = (table as Dictionary)[key]
	return _merged


static func normalize(p_code: String) -> String:
	## Anything unknown falls back to the default, so a hand-edited settings file
	## can never leave the game with no language at all.
	var code := p_code.strip_edges().to_lower()
	for known in ORDER:
		if code == known:
			return known
	return DEFAULT_LANGUAGE


static func set_language(p_code: String) -> bool:
	## True when this call actually CHANGED the language, which is what tells the
	## caller it has to rebuild the on-screen text (see Game.set_language).
	var code := normalize(p_code)
	if code == language:
		return false
	language = code
	print("[Loc] language -> " + language + " (" + str(LABELS.get(language, language)) + ")")
	return true


static func next_language() -> String:
	var i := ORDER.find(language)
	return str(ORDER[(i + 1) % ORDER.size()])


static func prefer_zh() -> bool:
	## Chinese was asked for AND the font can draw it.
	return language == ZH and UiFont.has_cjk()


static func language_button_text() -> String:
	## The SETTINGS toggle shows the language you are IN, so it reads correctly in
	## both directions. Falls back to the English wording with no CJK font.
	var name := str(LABELS.get(language, language))
	if prefer_zh():
		return "语言：" + name
	return "LANGUAGE: " + name


static func t(p_key: String, p_fallback: String = "") -> String:
	var d := _lookup(p_key)
	if d.is_empty():
		if p_fallback != "":
			return p_fallback
		if not bool(_warned.get(p_key, false)):
			_warned[p_key] = true
			push_warning("[Loc] no string for key '" + p_key + "'")
		return p_key
	var want := ZH if prefer_zh() else EN
	var text := str(d.get(want, ""))
	if text == "":
		## A half-filled entry still shows something readable rather than nothing.
		text = str(d.get(EN if want == ZH else ZH, p_fallback))
	return text


static func tf(p_key: String, p_args: Array) -> String:
	## Translate + format: Loc.tf("hud.stat.round", [3]) == "回合 3" / "ROUND 3".
	return t(p_key) % p_args


static func has_key(p_key: String) -> bool:
	## [P22] Lets a caller offer a SPECIFIC key and fall back to a shared one without
	## having to know the table layout ("item.hint.fertilizer", else
	## "item.hint.kind.fertilizer"). Reading a key that does not exist never warns,
	## so a probe like this cannot pollute the log.
	return not _lookup(p_key).is_empty()


static func _lookup(p_key: String) -> Dictionary:
	## [P38] B6: one dictionary lookup instead of rebuilding the table list and
	## scanning five tables per call. The entry is still the live table dictionary
	## (t() only reads it), same object the old walk returned.
	return _index().get(p_key, {}) as Dictionary


## What Godot's % operator accepts between the '%' and the conversion letter.
const _SPEC_FLAGS := "-+ 0#"
const _SPEC_CONV := "dioxucsfxX"


static func _format_scan(p_text: String) -> Array:
	## [P37-A12] [how many %-specifiers this template really holds, how many lone '%'].
	## Counting them by parsing instead of counting the '%' characters is what tells
	## "+%d 生命" apart from "+50% 生命": the second one is a format character to Godot,
	## and an unsupported one makes tf() log "unsupported format character" and hand
	## the raw template back to the label. "%%" is the escape for a literal percent.
	var good := 0
	var bad := 0
	var i := 0
	while i < p_text.length():
		if p_text[i] != "%":
			i += 1
			continue
		var j := i + 1
		if j < p_text.length() and p_text[j] == "%":
			i = j + 1
			continue
		while j < p_text.length() and _SPEC_FLAGS.find(p_text[j]) >= 0:
			j += 1
		while j < p_text.length() and p_text[j] >= "0" and p_text[j] <= "9":
			j += 1
		if j < p_text.length() and p_text[j] == ".":
			j += 1
			while j < p_text.length() and p_text[j] >= "0" and p_text[j] <= "9":
				j += 1
		if j < p_text.length() and _SPEC_CONV.find(p_text[j]) >= 0:
			good += 1
			i = j + 1
		else:
			bad += 1
			i += 1
	return [good, bad]


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	## Printed once at start-up by Game, next to the other self-checks: it answers
	## "is my language machinery complete" (every key has both variants, no key is
	## defined twice, no translated format string lost a placeholder) without
	## having to click through every screen.
	print("[Loc] --- language: %s (%s) ---" % [language, str(LABELS.get(language, language))])
	print("[Loc] UI font: " + UiFont.status_text())
	if language == ZH and not UiFont.has_cjk():
		print("[Loc]        -> Chinese is selected but the font cannot draw it:")
		print("[Loc]        -> English text is served instead (no tofu boxes)")
	var ok := true
	var keys := 0
	var seen: Dictionary = {}
	for table in _tables():
		var names: Array = table.keys()
		names.sort()
		for item in names:
			var key := str(item)
			keys += 1
			if seen.has(key):
				ok = false
				print("[Loc] duplicate key '" + key + "' | FAIL")
			seen[key] = true
			var d: Dictionary = table[item]
			var zh := str(d.get(ZH, ""))
			var en := str(d.get(EN, ""))
			if zh == "" or en == "":
				ok = false
				print("[Loc] key '" + key + "' is missing a variant | FAIL")
				continue
			var scan_zh: Array = _format_scan(zh)
			var scan_en: Array = _format_scan(en)
			var n_zh := int(scan_zh[0])
			var n_en := int(scan_en[0])
			if n_zh != n_en:
				ok = false
				print("[Loc] key '" + key + "' has " + str(n_zh)
					+ " placeholder(s) in zh but " + str(n_en) + " in en | FAIL")
			## A label with no placeholder never reaches the % operator (Loc.t only), so a
			## bare "%" in it is harmless prose; once a string does format, every stray
			## "%" is a bug at run time rather than a copy-editing preference.
			if n_zh > 0 and int(scan_zh[1]) > 0:
				ok = false
				print("[Loc] key '" + key + "' zh has a lone '%' that is not a specifier"
					+ " - write '%%' | FAIL")
			if n_en > 0 and int(scan_en[1]) > 0:
				ok = false
				print("[Loc] key '" + key + "' en has a lone '%' that is not a specifier"
					+ " - write '%%' | FAIL")
	print("[Loc] %d keys, both variants + placeholder parity + specifier scan | %s"
		% [keys, "OK" if ok else "FAIL"])
	print("[Loc] sample: %s / %s / %s"
		% [t("plant.peashooter"), t("item.coin_gold"), t("tool.shovel")])
	print("[Loc] self-check %s" % ("PASSED" if ok else "FAILED"))
