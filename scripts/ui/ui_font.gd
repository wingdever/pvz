class_name UiFont
extends RefCounted
## [P19] One UI font for the whole game, so non-ASCII text (the Chinese talent
## names) can actually be drawn.
##
## Why this file exists: Godot's built-in font has no CJK glyphs, so Chinese text
## used to render as tofu boxes (docs/HANDOFF.md 4.4). Rather than hand-tune every
## control, this loads ONE font and applies it in the two places that matter:
##   1. ThemeDB.fallback_font - what every draw_string() call in this project uses
##   2. the root Window's Theme - what every Label / Button resolves
##
## Drop any .ttf / .otf into res://assets/fonts/ and it is picked up; nothing else
## has to change. With no font there, everything still works with the built-in font
## (Chinese strings then fall back to their English names - see Balance.talent_name).

const FONT_DIR := "res://assets/fonts"
const FONT_EXTS := [".ttf", ".otf", ".woff2", ".woff"]
## Deliberately NOT BalanceUI.FONT_SIZE_HUD_SMALL: keeping this file free of any
## reference to Balance leaves the dependency one-way (Balance -> UiFont), which
## cannot turn into a cyclic class reference.
const DEFAULT_FONT_SIZE := 15

static var font: Font = null
static var source: String = ""
static var cjk_ok: bool = false


static func ensure_loaded() -> void:
	## Called once by Game._ready(). Prints exactly one line either way, so "why is
	## my Chinese text boxes" is answerable from the log.
	if font != null:
		return
	var path := _first_font_file()
	if path == "":
		print("[Font] no font in " + FONT_DIR + " -> built-in font (Chinese text will not render)")
		print("[Font] drop a .ttf/.otf there (any CJK font) to enable it")
		return
	var loaded := ResourceLoader.load(path) as Font
	if loaded == null:
		push_warning("[Font] cannot load " + path + " -> built-in font")
		return
	font = loaded
	source = path
	## probe two common CJK glyphs rather than trusting the file name
	cjk_ok = font.has_char(0x786C) and font.has_char(0x8BED)   # 硬 / 语
	ThemeDB.fallback_font = font
	print("[Font] using " + path + "   CJK glyphs: " + str(cjk_ok))


static func apply_to_window(p_window: Window) -> void:
	## Labels and Buttons resolve their font through the theme tree, so the root
	## window gets a theme whose default font is ours. A fresh Theme only defines
	## the font: every stylebox still comes from the default theme.
	if p_window == null or font == null:
		return
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = DEFAULT_FONT_SIZE
	p_window.theme = ui_theme


static func has_cjk() -> bool:
	return cjk_ok


static func status_text() -> String:
	if font == null:
		return "built-in font (no CJK)"
	return source.get_file() + (" (CJK ok)" if cjk_ok else " (no CJK glyphs)")


static func _first_font_file() -> String:
	## Deterministic pick: alphabetically first usable font in FONT_DIR.
	var dir := DirAccess.open(FONT_DIR)
	if dir == null:
		return ""
	var names: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and not entry.begins_with("."):
			var lower := entry.to_lower()
			for ext in FONT_EXTS:
				if lower.ends_with(str(ext)):
					names.append(entry)
					break
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for item in names:
		var path := FONT_DIR + "/" + str(item)
		if ResourceLoader.exists(path):
			return path
	return ""
