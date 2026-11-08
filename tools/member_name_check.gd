extends SceneTree
## [P24] THROWAWAY diagnostic, NOT part of the game - delete it when you are done.
##
## Why it exists: a script may NOT redefine a member a native class already has.
## Godot then refuses to parse the file and takes the whole screen down with
##   Member "ready" redefined (original in native class 'Control')
## which costs one full run per bad name to find. This prints a verdict for every
## PUBLIC name the new garden UI adds, so the whole list is checked in ONE run:
##
##   godot --headless --path . --script res://tools/member_name_check.gd 2>&1 | grep "\[Names\]"
##
## Notes:
##   * It loads no project script, opens no window and quits immediately.
##   * Only REAL (non-virtual) members can collide: overriding _init / _ready /
##     _process / _draw / _gui_input is normal and is not reported here.
##   * Methods, properties and signals all count - "ready" is a Node SIGNAL.
##   * Private names (leading "_") cannot collide with a native member, so only the
##     public ones are listed. "Control" already covers everything Node declares,
##     because get_property_list() / get_signal_list() include the inherited members.

const CHECKS := {
	"Control": [
		## GardenView / GardenPlot / GardenTool / CursorGhost, as they are declared
		"game", "picked", "drop_requested", "dropped", "kind", "title", "badge",
		"in_stock", "armed", "hovered", "is_target", "target",
		"slot", "filled", "downed", "level", "rarity", "hp", "max_hp", "selected",
		"recover_left", "plant_type", "plant_name",
		"setup", "hold", "drop", "metrics_for",
		## [P26] AlmanacView: the tabs, the grid host and its layout helper
		"open_view", "hide_view", "on_layout_changed", "refresh", "design_area",
		## [P27] the almanac's per-grid overrides and its panel picture
		"tile_size", "max_cols", "top_align",
		## [P75] the almanac's page counter and the two section doors the boot probe reads.
		## `page_builds` is here because it is a public VAR on a Control - the only new
		## storage this batch adds anywhere - and the two methods are the pair that lets the
		## probe put the tab back without rebuilding the page (ScreenFlow.self_check).
		"page_builds", "current_section", "restore_section",
	],
	"Node": [
		## [P24] `ready` stays on this list ON PURPOSE: it is the collision this probe was
		## written to demonstrate (docs/HANDOFF.md §7.53 - a script that declared a member
		## called `ready` took the whole screen down). Nothing declares it any more, so the
		## one FAIL line below is the expected answer, not a regression: watch the COUNT.
		"ready", "kind", "armed", "in_stock", "is_target", "drop_requested",
		## [P40-C2] GameManager (extends Node) new public helper: the four summon gates
		## in one answer, shared by select_plant() and try_place_at().
		"summon_blocker",
		## [P50] GameManager's four SETTINGS helpers for the cue layer - the twins of the
		## music ones, which never needed listing because they predate this probe.
		"toggle_sfx", "cycle_sfx_volume", "sfx_button_text", "sfx_volume_text",
		## [P60] the one door an arriving zombie walks through (GameManager, a Node). Its
		## two collaborators in the same cut are NOT here: `_attach_unit` is private, and
		## `apply_type` / `place` are already listed under Node2D - this batch changed what
		## they DO, not who they are called.
		"spawn_zombie",
	],
	"Node2D": [
		## [P26] Zombie's typed-zombie members (Unit extends Node2D)
		"zombie_type", "move_threshold", "bite_damage", "brain_damage", "armor", "armor_max",
		"executes", "armored_downgrade", "vault_charges", "drops_diamond", "executed",
		"apply_type", "can_vault", "type_label",
		## [P45] the 铁门's two rules: the flags Zombie.apply_type reads off the sheet,
		## and the one helper that decides which side a hit came from.
		"blocks_projectiles", "back_attack_ignores_armor", "_struck_from_behind",
		## [P47] the summoner's plan (three sheet columns + the clock that runs it) and
		## the two helpers around that clock. `summon_children` lives on GameManager
		## (a Node), so it is not this list's business.
		"summon_rounds", "summon_count", "summon_id", "summon_countdown",
		"summon_is_due", "tick_summon",
		## [P48] the giant's hammer: the two sheet numbers, the swing's own state, and
		## the four helpers around it. `can_smash` is checked here because it is a public
		## method on a Node2D subclass; the identically named one on ZombieDB is a static
		## on a plain RefCounted class and cannot collide with anything.
		"smash_windup", "smash_recovery", "smash_armed", "smash_countdown",
		"can_smash", "begin_smash_windup", "smash_is_due", "tick_smash",
		"cancel_smash_windup",
		## [P68] the newspaper's rage: the two sheet numbers it swaps onto its own body and
		## the one flag that says they are in. `can_rage` is checked here for `can_smash`'s
		## reason - a public method on a Node2D subclass. The ZombieDB twins of three of
		## these names are statics on a RefCounted and are listed below instead.
		"rage_move", "rage_bite", "enraged", "can_rage",
		## [P28] Unit's art + view-scene members (a view scene is a child Node2D)
		"art_path", "view_path", "art_view", "has_art", "has_view", "set_view_path",
		## [P43] the one-shot family (P39 added the names, this probe never caught up):
		## OneShotPlant's two hooks + its own vocabulary, and the six plants' members.
		## Only vars and funcs are listed - a `const` is not in get_property_list(),
		## so ID / SKILL / ARM_ROUNDS / FREEZE_ROUNDS cannot be checked here at all.
		"plant_id", "chew_rounds",
		"setup_one_shot", "skill_damage", "blast_targets", "blast_effects", "detonate",
		"spend_self", "has_target", "has_skill", "resolve_skill_once", "action_text",
		"prey", "devour", "ult_implemented", "ult_can_fire", "act_ultimate",
		## [P49] the throwing family: Projectile's new shared `splash`, PultPlant's three
		## parameters and its two hooks, and the shot class a shooter now names. Listed
		## whether or not they override anything, because the point is the NAME.
		"splash", "splash_ratio", "ult_own_effects", "ult_side_effects", "shot_class",
		"setup_pult", "adjacent_rows", "storm_rows", "shot_options", "fire_shot",
		"fire_lane_storm",
		## [P50] the three cue names the battle hooks carry: two on a shot (the throw and
		## the landing) and one on a 一次性 plant. A `const SFX` is not listed anywhere -
		## see the note above about consts.
		"launch_cue", "hit_cue", "blast_cue",
		## [P51] the sheet read that decides a pult's splash: the question it answers lives
		## on the plant (`spreads`), the column it reads lives on the sheet (`has_splash`,
		## in the RefCounted list below).
		"spreads",
		## [P58] the ring batch: the box query the grid now owns, the storm body the lane
		## storms and the ring's 大招 both shoot through, and the names the ring plant adds.
		## `volley` is listed here although it predates this batch (P33 introduced it) - the
		## list never caught up, and the ring's whole answer is built on that one query.
		"get_zombies_around", "fire_storm", "ring_bodies", "volley",
		## [P59] the displacement batch: the one way a zombie changes cell (which the ADVANCE
		## and VAULT branches now share), the shove that uses it, and the fear question the
		## scaredy asks of the ring box. `afraid_up_close` is the plant-side half of the pair
		## the RefCounted list below spells out (the sheet column writes it, the var answers
		## the volley - the same split P51 made of 溅射). `zombie_next_to_me` is the only other
		## plant-side name here - `volley` / `act_ultimate` are already listed above.
		"relocate_to", "push_back", "zombie_next_to_me", "afraid_up_close",
		## [P63] the spike batch: the flag the sheet's 不会被啃食 leaves on the body (the
		## zombie's decision asks THIS, not "is this a spike"), and the four public names of
		## the sixth plant family. `skill_damage` / `has_target` / `resolve_skill_once` /
		## `ult_can_fire` / `act_ultimate` are already listed above, so only this family's own
		## vocabulary is new - `_stab_walkers` is private and cannot collide with anything.
		"ignores_biting", "setup_spike", "walkers", "stab_the_walker", "storm_lane",
		## [P65] OPTIMIZATIONS A3: the three persist doors. They are on THIS list rather than
		## the RefCounted one because a door that other modules call has to be PUBLIC, and
		## public means it lands on `GameManager` - a `Node` - where `get_tree()`, `name` and
		## the rest of that class's vocabulary already live. `save` alone would have been the
		## risky spelling (an ordinary verb, and `ResourceSaver` exists in the engine); the
		## ledger noun after it is what makes each name safe, which is worth recording as the
		## reason for the shape rather than the taste. `_record_write` / `_unsaved` are private.
		"save_garden", "save_profile", "save_run",
		## [P66] A4's other door, and the second name on this list that is here because of a
		## REASON rather than a taste: `recover_garden` had to lose its underscore so the
		## garden page could stop owning a copy of the rule, which makes it a public member of
		## a `Node` - and `recover` alone is the kind of word an engine class could take.
		## `_recover_garden` (the old private spelling) needs no entry: a name nothing can call
		## cannot collide, and the [Recover] probe asserts it is gone instead.
		"recover_garden",
	],
	"RefCounted": [
		## UnitArt / UiStyle / Balance additions and the helpers they sit next to
		"fit_text", "draw_potion_icon", "load_texture", "art_paths", "capacity_for",
		## [P53] the two halves of the single tail-trim rule that `fit_text` is now built
		## from (the four copies this replaced were all private, so only these two names
		## are new public vocabulary).
		"width_of", "trim_tail",
		"item_art", "item_tier", "item_mark_art", "potion_bottle_art", "plant_art_ink",
		## [P26] the two data sheets and their reader
		"load_from_disk", "is_loaded", "error_text", "count", "ids", "has", "row",
		"name", "text", "hp", "attack", "cost", "cooldown", "is_one_shot",
		"is_playable", "problems", "status_text", "playable_count", "self_check",
		"art", "has_flag", "is_simulated", "unsimulated_flags", "stats", "base_hp",
		"armor", "move", "bite", "read_table", "cell", "cell_en", "cell_any",
		"int_cell", "int_of", "has_en", "clean",
		## [P51] the second prose mechanic the battle reads off units.csv 特殊机制 (the first
		## is `is_one_shot` above), and the sheet column that answers it.
		"has_splash",
		## [P59] the third prose mechanic of that same column - and the first one that takes
		## an action AWAY rather than adding a consequence to it.
		"fears_adjacent",
		## [P63] the fourth: the phrase the spike's row spells and the two neighbours that
		## almost do (地刺王 不被啃食 / 大蒜 被啃食时) make this one a MATCHING question, so
		## it is the mechanic whose name has to say "the whole five characters".
		"is_uneatable",
		## [P72] PlantDB's prose report: the row-aware twin of the zombie side's `simulates`,
		## and the two readers of the 特殊机制 audit (`prose_state` classifies one row,
		## `prose_audit` groups the whole column). `has_flag` / `is_simulated` /
		## `unsimulated_flags` are already above - the plant twins reuse the sheet side's
		## names, which is exactly what this list is for: one probe per NAME, whoever declares
		## it. The new PHRASES / FLAGS_* tables are consts and consts cannot collide.
		"simulates", "prose_state", "prose_audit",
		## [P68] the rage gate: the two column readers the newspaper's row now answers with,
		## the row-aware `can_rage` and the gap list that keeps a 暴怒 without its two cells
		## a word rather than a rule. The matching phrase itself (`PHRASES`) is a const and
		## cannot be checked here - see the note above about consts.
		"rage_move", "rage_bite", "can_rage", "rage_gaps",
		## [P57] UnitCsv's complaint channel: one list, one writer, one printer, plus the
		## two helpers the numeric readers now need (`cell_hit` keeps the column NAME so a
		## complaint can be traced, `row_label` names the row). `int_of` / `rate_of` are
		## already above - they grew two OPTIONAL parameters, which is not a new name.
		"note_complaint", "complaint_count", "clear_complaints", "report_complaints",
		"cell_hit", "row_label",
		## [P26] the roster sprite map and the sheet-backed plant numbers
		"has_art", "roster_art_paths",
		## [P28] the svg column of the unit sheets and the art lists it feeds
		"svg_file", "art_count", "code_art_paths", "sheet_art_paths",
		"short_art_path",
		## [P28] the tscn column of the unit sheets (the view-scene step above the sprite)
		"scene_path", "scene_rel", "scene_file", "view", "has_view", "view_count",
		"load_scene", "plant_view", "zombie_view",
		"plant_attrs", "plant_cost", "plant_def", "plant_base_skill", "plant_attr_hp",
		"brain_damage", "rates", "rate", "rate_of", "rate_cell", "int_of",
		"refresh_max_hp", "max_hp_of", "skill_value_of",
		## [P27] ItemDB (data/items.csv) - the item page's own registry
		"source", "kind", "kind_label", "value", "plant", "svg_rel", "svg_path",
		"art_from_sheet", "mark_art", "is_battle_known", "known_count",
		## [P35] SelfChecks (scripts/core/game_self_checks.gd) - the startup probes that
		## moved out of game_manager.gd. Only the public name is listed; a leading "_"
		## cannot collide with a native member.
		"run_battle_probes",
		## [P35] the transaction the probes now run inside (Profile / Garden are RefCounted)
		"snapshot", "restore",
		## [P36] RunFlow (scripts/core/run_flow.gd) - the campaign's 33 public names, the
		## one new scratch clearer and its back-reference. A leading "_" cannot collide,
		## so the 15 private ones stay off this list.
		"game", "clear_page_state",
		"run_available", "has_run_save", "start_adventure", "begin_new_run",
		"continue_run", "show_run_squad", "run_squad_limit", "squad_pick_count",
		"squad_rows", "squad_toggle", "confirm_run_squad", "show_run_map",
		"run_open_choices", "run_map_rows", "run_node_title", "enter_run_node",
		"show_run_shop", "return_to_run_map", "is_run_battle_result",
		"run_result_action_text", "run_result_advance", "run_result_retry",
		"run_reward_options", "show_run_reward", "run_reward_pick",
		"show_run_node_page", "run_screen_kind", "run_choice_title",
		"run_choice_body", "run_choice_options", "run_choice_pick",
		"apply_run_effects", "show_run_end",
		## [P50] the cue layer. Sfx is a static class on a RefCounted like Music, so its
		## own vocabulary has to clear Object's members; `status_text` and `self_check` are
		## already above from the sheet readers, and the balance table's helpers plus the
		## two SettingsStore setters sit in the same list because all three are RefCounted.
		"setup", "is_ready", "is_enabled", "volume", "volume_percent",
		"play", "stop_all", "set_enabled", "set_volume", "set_quiet",
		"sfx_def", "is_sfx", "sfx_ids", "sfx_files", "sfx_path", "sfx_pick", "sfx_db",
		"next_sfx_volume", "set_sfx_on", "set_sfx_volume",
		## [P56] SafeIO's second writer (it is `extends RefCounted`, no class_name) plus the
		## settings round trip it now serves. `self_check` is already above; `PROBE_PATH`,
		## `PROBE_KEY` are consts, which get_property_list() never reports, so they cannot be
		## checked here (same note as [P43]'s), and `_text_of` / `_clear_probe_files` are
		## private and therefore cannot collide.
		"write_config_atomic", "write_text_atomic", "keep_broken",
		## [P61] rewards.gd - the third module extracted from GameManager, also without a
		## `class_name`, so its four public verbs have to clear Object's members on their
		## own. `grant` is the one worth checking precisely because it is an ordinary word.
		## `_pack_counts` / `_rewards` (the probe this batch adds to SelfChecks) are private.
		"roll_drop", "grant", "roll_tag", "describe_roll",
		## [P64] screen_flow.gd - the fourth module extracted from GameManager, again with no
		## `class_name`, so its eighteen public names clear Object's members here. Two of them
		## are ordinary words worth checking: `back` (a BACK button's destination - and
		## `Array.back()` exists, which is exactly the kind of collision this tool catches on
		## the class it lands on) and `resume_battle`. `self_check` is already in this list
		## from the sheet readers, and the four private helpers cannot collide.
		"leave_game", "hide_views", "set_world_visible", "resume_battle",
		"open_main_menu", "open_level_select", "open_settings", "open_settings_overlay",
		"open_garden", "open_warehouse", "open_backpack", "open_almanac", "open_shop",
		"open_deck_select", "back", "refresh_page", "views_of", "visible_views",
		## [P75] LevelList's one reader for the filtered-out files. The cache itself is private
		## (`_parsed` / `_folder_sig` / `_sync_cache` / `_folder_signature` cannot collide), but
		## `skipped` was a public `static var` until this batch made it a method - and it is a
		## past participle used as a noun, which is the kind of name an engine class might own.
		## `discover` / `describe` predate the probe and were never registered; they did not move.
		"skipped",
		## [P76] Fx's three layer doors. The module has owned a node since the effect layer
		## landed (OPTIMIZATIONS B7), and all three names are ones the engine uses for
		## something else somewhere: `attach` / `detach` reads like an Object method, `layer`
		## is CanvasLayer's and TileMap's, `clear` is every container's. `_layer` / `_put` are
		## private and cannot collide, so the storage half of this batch is not listed.
		"attach", "layer", "clear",
	],
}


func _initialize() -> void:
	print("[Names] --- new garden members vs Godot's native classes (P24/P26/P27) ---")
	var probes := {
		"Control": Control.new(),
		"Node": Node.new(),
		"Node2D": Node2D.new(),
		"RefCounted": RefCounted.new(),
	}
	var bad := 0
	var checked := 0
	for cls in CHECKS.keys():
		var obj: Object = probes[cls]
		var taken: Dictionary = {}
		for p in obj.get_property_list():
			taken[str(p["name"])] = "property"
		for m in obj.get_method_list():
			taken[str(m["name"])] = "method"
		for sg in obj.get_signal_list():
			taken[str(sg["name"])] = "signal"
		for item in CHECKS[cls]:
			var name := str(item)
			checked += 1
			if taken.has(name):
				bad += 1
				print("[Names] %s.%s is TAKEN (%s) -> rename it | FAIL"
					% [cls, name, taken[name]])
	print("[Names] %d name(s) checked, %d collision(s) | %s"
		% [checked, bad, "OK" if bad == 0 else "FAIL"])
	quit()
