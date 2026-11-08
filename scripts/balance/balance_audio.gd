class_name BalanceAudio
extends RefCounted
## [P69] The audio half of Balance, split out of scripts/balance/balance.gd (C9, at the user's
## request). The rule is [P28-UI]'s and it is still "WHO READS IT", not "what it is
## about": a number belongs to the file its readers agree on. Every constant here is read
## by exactly one of three kinds of code - the two players (scripts/core/music.gd and
## sfx.gd), the screens and the save file that name a track or hold the volume, and the
## battle hooks that name a CUE. Nothing in balance.gd reads this file, so the two
## classes cannot form a dependency cycle (the same one-way rule that keeps BalanceUI
## safe: Balance -> nobody, BalanceUI -> nobody, BalanceAudio -> nobody).
## What stays in Balance is what the GAME decides: economy, unit stats and their sheet
## fall-backs, tools, items, shop, garden rules, file paths.
##
## Two tables live here, and the difference between them is the whole design:
##   MUSIC_DEFS  id -> { file, loop, note }   a THEME: one long thing per SCREEN
##   SFX_DEFS    id -> { file, alt, db }      a CUE: a short sound some ACTION made
## Game code never names a sample - it names an id - so "what a bite sounds like" is a
## table edit, and a typo in one becomes a boot failure ([Music] / [Sfx] self-check)
## rather than a silent game.

# ---------------------------------------------------------------- background music (P21)
# The tracks are the ones listed under [背景音乐] in assets/audio/readme.md; they sit
# in assets/audio/ as plain .wav files that the editor imports as AudioStreamWAV.
# scripts/core/music.gd owns playback, this table is the ONLY id -> file mapping.
#
#   id -> { file, loop, note }
#     loop == true   a theme: it is looped while its screen is up
#     loop == false  a one-shot cue (the win / lose jingle): played once, then quiet
#
# A level picks its own theme with the optional "music" field of its JSON (any id
# from this table, e.g. "Night" / "Pool" / "Roof" / "Boss"); the default is the day
# lawn below. The "_drum" entries are the final-wave arrangements and are selected
# automatically (MUSIC_DRUMS_ON_FINAL_WAVE), never by hand.
const MUSIC_DIR := "res://assets/audio/"
const MUSIC_DEFS := {
	"MainMenu": {"file": "MainMenu.wav", "loop": true, "note": "main menu"},
	"SelectCard": {"file": "SelectCard.wav", "loop": true, "note": "picking seeds -> the level list uses it"},
	"Garden": {"file": "Garden.wav", "loop": true, "note": "the garden screen"},
	"Day": {"file": "Day.wav", "loop": true, "note": "day lawn battle (the default)"},
	"Day_drum": {"file": "Day_drum.wav", "loop": true, "note": "day lawn, final wave"},
	"Night": {"file": "Night.wav", "loop": true, "note": "night battle"},
	"Night_drum": {"file": "Night_drum.wav", "loop": true, "note": "night, final wave"},
	"NightSnow": {"file": "NightSnow.wav", "loop": true, "note": "snowy night battle"},
	"NightSnow_drum": {"file": "NightSnow_drum.wav", "loop": true, "note": "snowy night, final wave"},
	"Pool": {"file": "Pool.wav", "loop": true, "note": "pool battle"},
	"Pool_drum": {"file": "Pool_drum.wav", "loop": true, "note": "pool, final wave"},
	"Fog": {"file": "Fog.wav", "loop": true, "note": "fog battle"},
	"Fog_drum": {"file": "Fog_drum.wav", "loop": true, "note": "fog, final wave"},
	"Roof": {"file": "Roof.wav", "loop": true, "note": "roof battle"},
	"Roof_drum": {"file": "Roof_drum.wav", "loop": true, "note": "roof, final wave"},
	"RoofPool": {"file": "RoofPool.wav", "loop": true, "note": "roof pool battle"},
	"RoofPool_drum": {"file": "RoofPool_drum.wav", "loop": true, "note": "roof pool, final wave"},
	"Snow": {"file": "Snow.wav", "loop": true, "note": "snow battle"},
	"Snow_drum": {"file": "Snow_drum.wav", "loop": true, "note": "snow, final wave"},
	"Boss": {"file": "Boss.wav", "loop": true, "note": "boss fight"},
	"Boss2": {"file": "Boss2.wav", "loop": true, "note": "boss fight (variant)"},
	"HorseBoss": {"file": "HorseBoss.wav", "loop": true, "note": "horse boss fight"},
	"Snow_boss": {"file": "Snow_boss.wav", "loop": true, "note": "snow boss fight"},
	"Dancer": {"file": "Dancer.wav", "loop": true, "note": "dancing zombie battle"},
	"IZ": {"file": "IZ.wav", "loop": true, "note": "I, Zombie battle"},
	"loon": {"file": "loon.wav", "loop": true, "note": "battle (extra)"},
	"UltimateBattle": {"file": "UltimateBattle.wav", "loop": true, "note": "final battle"},
	"winmusic": {"file": "winmusic.wav", "loop": false, "note": "victory cue"},
	"LoseMusic": {"file": "LoseMusic.wav", "loop": false, "note": "defeat cue"},
}

## The track each screen asks for. LevelData may override MUSIC_BATTLE per level.
const MUSIC_MENU := "MainMenu"
const MUSIC_LEVEL_SELECT := "SelectCard"
const MUSIC_GARDEN := "Garden"
const MUSIC_BATTLE := "Day"            # fallback when a level names no music
## [B8+] THE BRAWL'S THEME. One track for the whole session - the arena, the formation page
## between bouts and the shop - because a brawl has no LEVEL to name a theme (it is a 60-minute
## ladder of ad-hoc battles, D18). 终结之战 is the closest thing this library has to "two armies
## and nobody giving orders"; change THIS LINE, not the code, when the ear disagrees.
const MUSIC_BRAWL := "UltimateBattle"
const MUSIC_WIN := "winmusic"
const MUSIC_LOSE := "LoseMusic"

## Last wave plays "<theme>_drum" when that arrangement exists. Only levels with
## more than one wave get it, otherwise a single wave level would drum from turn 1.
const MUSIC_DRUMS_ON_FINAL_WAVE := true

## Music ON/OFF and the volume are part of the saved settings (SettingsStore).
const MUSIC_VOLUME_DEFAULT := 0.7      # 70% - a menu theme should sit under the SFX
const MUSIC_VOLUME_STEPS := [1.0, 0.8, 0.6, 0.4, 0.2]   # the VOLUME button walks these
const MUSIC_FADE_TIME := 0.9           # crossfade when the screen changes
const MUSIC_VOLUME_FADE := 0.25        # turning the volume knob is quicker
const MUSIC_JINGLE_FADE := 0.35        # cutting to the win / lose cue
const MUSIC_SILENT_DB := -60.0         # "faded out" (-80 is the engine's own floor)

## Fallback looping (see Music.MusicPlayer._on_finished): a clip that really played
## through has to have run at least this fraction of its length to be replayed, and
## a clip that keeps finishing early gives up after this many strikes. Without both
## guards a broken loop point could turn into a busy loop.
const MUSIC_LOOP_MIN_RATIO := 0.8
const MUSIC_LOOP_MAX_STRIKES := 3


static func music_def(p_id: String) -> Dictionary:
	if not MUSIC_DEFS.has(p_id):
		return {}
	var d: Dictionary = MUSIC_DEFS[p_id]
	return d


static func is_music(p_id: String) -> bool:
	return MUSIC_DEFS.has(p_id)


static func music_ids() -> Array:
	var out: Array = MUSIC_DEFS.keys()
	out.sort()
	return out


static func music_path(p_id: String) -> String:
	## "" for an unknown id, so callers can treat it as "no music" instead of a path
	## that would fail at load time.
	var d := music_def(p_id)
	if d.is_empty():
		return ""
	return MUSIC_DIR + str(d.get("file", ""))


static func music_file(p_id: String) -> String:
	var d := music_def(p_id)
	return "" if d.is_empty() else str(d.get("file", ""))


static func music_loops(p_id: String) -> bool:
	## A theme loops, a jingle does not. An unknown id is "no music" -> not looping.
	var d := music_def(p_id)
	return bool(d.get("loop", false)) if not d.is_empty() else false


static func music_drum_variant(p_id: String) -> String:
	## "<theme>_drum" when that final wave arrangement exists, else "" (keep the theme).
	var drums := p_id + "_drum"
	return drums if MUSIC_DEFS.has(drums) else ""


static func next_music_volume(p_current: float) -> float:
	## The SETTINGS volume button walks MUSIC_VOLUME_STEPS. A value in between (say a
	## hand edited settings file) snaps to the nearest step first, so the cycle stays
	## predictable whatever the file says.
	var best := 0
	var best_delta := 999.0
	var current := clampf(p_current, 0.0, 1.0)
	for i in MUSIC_VOLUME_STEPS.size():
		var delta: float = absf(float(MUSIC_VOLUME_STEPS[i]) - current)
		if delta < best_delta:
			best_delta = delta
			best = i
	return float(MUSIC_VOLUME_STEPS[(best + 1) % MUSIC_VOLUME_STEPS.size()])


# ---------------------------------------------------------------- sound effects (P50)
# Music (above) owns a THEME: one long thing that changes when the screen changes.
# This owns a CUE: a short sound that some action on the board made. The game code
# never names a sample, it names a cue id, so "what a bite sounds like" stays a table
# edit and a typo becomes a boot failure ([Sfx] self-check) instead of a silent game.
#
# One row of SFX_DEFS:
#   file  the sample
#   alt   an optional twin of the SAME sound, picked at random - together with the
#         pitch jitter this is why eight chomps do not sound like one chomp eight times
#   db    ATTENUATION, and only ever <= 0. The SETTINGS knob is the gain on top of it,
#         so a cue with a positive number here would be the one sound the knob cannot
#         turn down. The self-check FAILS on a positive value for exactly that reason.
#
# A cue that no code asks for is dead weight, so this table holds ONLY the events the
# battle and the UI actually raise (see docs/OPTIMIZATION_PLAN.md P50 for the hook list).
const SFX_DIR := "res://assets/audio/"
const SFX_DEFS := {
	# ---------------------------------------------------------------- UI
	## `ButtonClick`, not the tempting `SelectCard.wav`: that file is the seed-choice THEME
	## - it is BalanceAudio.MUSIC_LEVEL_SELECT two screens up - and the first run of
	## [Sfx] self-check printed 108 seconds on a card click, which is what SFX_MAX_LENGTH
	## now exists to fail out loud.
	"card_pick":     {"file": "ButtonClick.wav",      "db": -10.0},
	"plant_place":   {"file": "Plant.wav", "alt": "Plant2.wav", "db": -8.0},
	"shovel":        {"file": "Shovel.wav",           "db": -8.0},
	"sun":           {"file": "Points.wav",           "db": -10.0},
	## [P55] The sound of "that click did not happen", fired by `GameManager._refuse()`
	## and by nothing else. P50 left this cue out on purpose: there were 31 places that
	## answer a refused click and none of them shared an exit, so a sound would have had
	## to be glued on gate by gate (see that batch's judgement 6). The exit exists now,
	## so the cue has exactly one caller.
	## The sample is `SquashHmm`, which this folder's OWN readme labels 疑惑 / 疑惑-闷音 -
	## the closest thing in 173 files to the game going "hmm, no". `Buzzer.wav` was the
	## other candidate and is NOT used: the readme files it under 听不出来 (nobody could
	## tell what it is), which is the same gamble P50 refused with `SelectCard.wav`.
	## The name is not a clash with 窝瓜 either: that plant's blast is `squash` (Gulp.wav).
	"refused":       {"file": "SquashHmm.wav", "alt": "SquashHmm2.wav", "db": -10.0},
	# ---------------------------------------------------------------- shots
	## The two launch sounds are split because a pea and a lobed melon are different
	## events; a rapid-fire pea is the loudest thing in a battle if it is not turned down.
	"shoot":         {"file": "Puff.wav",             "db": -14.0},
	"lob":           {"file": "KernelPult.wav",       "db": -12.0},
	"impact":        {"file": "Floop.wav",            "db": -12.0},
	"melon_impact":  {"file": "MelonImpact.wav", "alt": "MelonImpact2.wav", "db": -6.0},
	"bite":          {"file": "Chomp.wav", "alt": "Chomp2.wav", "db": -10.0},
	## The plant's answer to the zombie's bite, and deliberately a heavier sample: 大嘴花
	## takes a whole body, which is the one attack in this game that skips damage. Named
	## after the plant's skill id, not after 暴食 (whose own id is big_chomp): the ordinary
	## bite and the 大招 swallow with the same mouth.
	"chomp":         {"file": "BigChomp.wav",         "db": -8.0},
	# ---------------------------------------------------------------- the brawl's two shots [B7+]
	## 火枪手 and 弓手 are the brawl's ranged pieces, and a shot is the one event in that mode
	## the ear can follow (the arena has no HUD yet - B4). Two pairs, not one: a musket and a
	## bow are different events and the whole point is telling them apart across the field.
	##
	## THE CHOICE OF SAMPLES, honestly: the folder's own readme files CannonShoot as 加农炮射击
	## and DoomSniperShoot as 毁灭狙击射手射击 - two labeled gunshots - so the musket is on solid
	## ground. There is NO labeled bowstring anywhere in the 173 files; the two nearest are
	## Throw / Throw2, which the readme puts under 听不出来 (nobody could tell what they are).
	## They are used anyway because a release whoosh beats silence, and they are 0.14 s / 0.34 s
	## - the right SIZE for a shot that repeats every 1.3 s. SWAP THE FILE, NOT THE CODE, if the
	## ear disagrees: this line is the only place a sample is named.
	"musket":        {"file": "CannonShoot.wav", "alt": "DoomSniperShoot.wav", "db": -10.0},
	"musket_hit":    {"file": "PlasticHit.wav",  "alt": "PlasticHit2.wav",     "db": -12.0},
	"bow":           {"file": "Throw.wav",       "alt": "Throw2.wav",          "db": -12.0},
	"bow_hit":       {"file": "Splat.wav",       "alt": "Splat2.wav",          "db": -12.0},
	"smash":         {"file": "GargantuarThump.wav",  "db": -6.0},
	# ---------------------------------------------------------------- riders
	"freeze":        {"file": "Frozen.wav", "alt": "SnowPeaSparkles.wav", "db": -10.0},
	"armour":        {"file": "ShieldHit.wav", "alt": "ShieldHit2.wav",  "db": -10.0},
	# ---------------------------------------------------------------- blasts
	## The default for a 一次性植物, then the three that landed in P34 override it:
	## PotatoMine's is its own pop, Jalapeño's is a burn and not a crater.
	"blast":         {"file": "Explosion.wav",        "db": -2.0},
	"blast_cherry":  {"file": "CherryBomb.wav",       "db": -2.0},
	"blast_potato":  {"file": "PotatoMine.wav",       "db": -4.0},
	"blast_jalapeno": {"file": "Ignite.wav", "alt": "Ignite2.wav", "db": -2.0},
	## 窝瓜 is not an explosion, so it is not filed under `blast_*`: the name says which
	## one-shot body fell on whom.
	"squash":        {"file": "Gulp.wav",             "db": -6.0},
	# ---------------------------------------------------------------- waves
	"wave":          {"file": "Awooga.wav",           "db": -4.0},
	"final_wave":    {"file": "FinalWave.wav",        "db": -4.0},
}

## How many samples may sound at once. Eight is more than a round can show: the last
## wave of a lane puts down a few chomps, two peas and one impact in the same frame, and
## past that a new cue steals the oldest player instead of growing the tree (Sfx._free_player).
const SFX_POOL := 8
## One cue cannot stack inside this window (milliseconds). A round resolves many bites
## at once; three copies of the same sample in one frame is the same sound three times
## louder, which reads as a glitch and not as a bigger bite.
const SFX_SAME_CUE_MS := 90
## Random tempo change per play, as a fraction. 6% is enough to tell two chomps apart
## without making a plant sound like a different instrument.
const SFX_PITCH_JITTER := 0.06
## The longest a cue's sample may be. assets/audio holds 173 files and plenty of them are
## THEMES, not cues (SelectCard.wav is the seed-choice track, LoseMusic.wav sits under the
## 音效 heading of the folder's own readme), and one of those landed on a card button until
## [Sfx] self-check printed its length. 6 s is over twice the longest legitimate cue here
## (the wave groan), and short enough that no theme can hide behind it.
const SFX_MAX_LENGTH := 6.0

## Saved like the music choice, one step louder than the theme by default so a cue is
## audible over the menu music without the player having to open SETTINGS first.
const SFX_VOLUME_DEFAULT := 0.8
const SFX_VOLUME_STEPS := [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]   # the SFX VOLUME button walks these


static func sfx_def(p_id: String) -> Dictionary:
	if not SFX_DEFS.has(p_id):
		return {}
	var d: Dictionary = SFX_DEFS[p_id]
	return d


static func is_sfx(p_id: String) -> bool:
	return SFX_DEFS.has(p_id)


static func sfx_ids() -> Array:
	var out: Array = SFX_DEFS.keys()
	out.sort()
	return out


static func sfx_files(p_id: String) -> Array[String]:
	## Every sample a cue may use, as full paths, "" dropped. The self-check walks this
	## so a cue's variant cannot be missing until someone happens to roll it in battle.
	var out: Array[String] = []
	var d := sfx_def(p_id)
	for key in ["file", "alt"]:
		var name := str(d.get(key, ""))
		if name != "":
			out.append(SFX_DIR + name)
	return out


static func sfx_pick(p_id: String) -> String:
	## The sample this one play uses: a cue's twin is rolled per call, so the alternation
	## is live rather than fixed by row order.
	var files := sfx_files(p_id)
	if files.is_empty():
		return ""
	return files[randi() % files.size()]


static func sfx_db(p_id: String) -> float:
	## The cue's own attenuation; a positive value here is a table bug, so it is clamped
	## rather than trusted (and [Sfx] self-check reports the row).
	return minf(0.0, float(sfx_def(p_id).get("db", 0.0)))


static func next_sfx_volume(p_current: float) -> float:
	## Same rule as the music knob: snap to the nearest step, then take the next one.
	var best := 0
	var best_delta := 999.0
	var current := clampf(p_current, 0.0, 1.0)
	for i in SFX_VOLUME_STEPS.size():
		var delta: float = absf(float(SFX_VOLUME_STEPS[i]) - current)
		if delta < best_delta:
			best_delta = delta
			best = i
	return float(SFX_VOLUME_STEPS[(best + 1) % SFX_VOLUME_STEPS.size()])
