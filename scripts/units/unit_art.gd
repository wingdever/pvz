class_name UnitArt
extends RefCounted
## [P11] Placeholder art v2: SVG sprites for the plants.
##
## Loading is defensive on purpose. A sprite that the editor has not imported yet
## (or a wrong path) must never break the game: the unit falls back to the flat
## placeholder shape drawn by Unit._draw_body(). self_check() reports which
## sprites are live, so "the art did not change" is answerable from a log line
## instead of a guess.
##
## Swapping in the real fusion assets later means touching this file and the
## art_path of each unit - nothing else.
##
## [P28] WHERE a sprite comes from is a spreadsheet cell now: the svg column of
## data/units/plants.csv and data/units/zombies.csv (through PlantDB / ZombieDB) and of
## data/items.csv (ItemDB). This file only loads what those tables resolved, so "why has
## this unit no picture" is answered by its own row - see art_paths() / self_check().
##
## [P28] The tscn column NEXT TO IT is the step above the sprite: a unit whose row
## registers a view scene is drawn by that scene, with its idle clip playing, and the
## sprite is only the fall-back (Unit._load_view / _draw_body). load_scene() is the
## loader for it, and self_check() reports both halves: what the sheets register and
## which of those parts really load.

static var _warned: Dictionary = {}      # path -> true, so warnings are printed once
## [P38] path -> loaded resource. A NULL answer is cached as well: "this file is not
## imported" used to be re-probed by every garden / almanac refresh.
static var _loaded: Dictionary = {}

## Every sprite of the game lives under this root, so a log line may drop it and keep the
## FOLDER (units/zombies/water/zombie_ducky.svg) - that is what tells two files apart.
const ART_ROOT := "res://assets/svg/"


static func short_art_path(p_path: String) -> String:
	## The path as a log line prints it. See ART_ROOT above.
	return p_path.trim_prefix(ART_ROOT)


static func load_texture(p_path: String) -> Texture2D:
	## [P38] OPTIMIZATIONS B4: cached. Every ask used to be an exists() + load() pair, and
	## the garden page (0.5 s), the almanac and every item cell ask for the same handful of
	## sprites over and over. A file the editor has not imported yet stays unanswered for
	## the life of the process - which is what the [Art] self-check already tells you to do
	## about it (reload the project), so the cache adds no new rule.
	if p_path == "":
		return null
	if _loaded.has(p_path):
		return _loaded[p_path] as Texture2D
	var res: Resource = null
	if ResourceLoader.exists(p_path):
		res = ResourceLoader.load(p_path)
	var tex := res as Texture2D
	_loaded[p_path] = tex
	return tex


static func load_scene(p_path: String) -> PackedScene:
	## [P38] The twin of load_texture(), cached the same way: a unit that respawns every
	## turn asked for its view scene again each time.
	if p_path == "":
		return null
	if _loaded.has(p_path):
		return _loaded[p_path] as PackedScene
	var res: Resource = null
	if ResourceLoader.exists(p_path):
		res = ResourceLoader.load(p_path)
	var packed := res as PackedScene
	_loaded[p_path] = packed
	return packed


# ---------------------------------------------------------------- the ink of a picture (B36)
## path -> the picture's ink as FRACTIONS of its own canvas (an empty size = "not measurable").
## Cached because the answer is a fact about a file and never changes; the measurement itself is
## BalanceUI.auto_ink_box()'s ([B35]: the bounding rect of the non-transparent pixels).
static var _ink: Dictionary = {}


static func ink_fractions(p_path: String) -> Rect2:
	## [B36] WHERE a picture's ink sits inside its canvas, as 0..1 fractions of that canvas.
	## Fractions and not pixels because every drawer scales the canvas differently - the arena
	## paints a body at Unit.art_box(), the formation page at its own icon side, the garden at a
	## pot rect - and none of them should have to know the file's size to place itself.
	if p_path == "":
		return Rect2()
	if _ink.has(p_path):
		return _ink[p_path]
	var tex := load_texture(p_path)
	var out := Rect2()
	if tex != null:
		var canvas := tex.get_size()
		var used := BalanceUI.auto_ink_box(tex)
		if used.size.x > 0.0 and used.size.y > 0.0 and canvas.x > 0.0 and canvas.y > 0.0:
			out = Rect2(used.position / canvas, used.size / canvas)
	_ink[p_path] = out
	return out


static func ink_span_y(p_path: String) -> float:
	## [B36] How much of a picture's own canvas height is INK (D112) - the second reader of the
	## measurement, and the one the HEIGHT AXIS asks: `z_thickness` is how tall a body reaches from
	## its feet, and a canvas is only how tall the file was saved. An unmeasurable picture answers
	## 1.0, which is silently "believe the canvas": a file that imports but keeps no readable pixels
	## is then as tall as its box, the number this estimate used before the door existed. (A body
	## with NO file at all never reaches this line - `Unit.read_height()` answers that one from
	## Balance.UNIT_Z_THICKNESS_CELLS since [B37] D113 took the floor out from under the estimate.)
	var frac := ink_fractions(p_path)
	return frac.size.y if frac.size.y > 0.0 else 1.0


static func ink_rect(p_path: String, p_at: Vector2, p_size: float) -> Rect2:
	## [B36] The ink box of a picture drawn into the square that starts at p_at and is p_size on
	## a side - the same square draw_texture_rect() is handed, so the answer is in the pixels the
	## caller already draws in. It is what a shadow is made of: the bottom edge is where the SOLE
	## is and the width is how wide the body paints (the ellipse's ground depth is NOT read from
	## here - it is half the width, D111).
	## THE FALL-BACK IS THE AUTHORING CONTRACT, not the whole canvas: a picture that cannot be
	## measured (no file, or an import that keeps no readable pixels) spans the canvas width and
	## ends on VIEW_ART_FEET_LINE - the very line fit_view() puts a view scene's feet on, so a
	## sprite, a view and an unreadable one all stand on the same ground.
	var frac := ink_fractions(p_path)
	if frac.size.x <= 0.0 or frac.size.y <= 0.0:
		return Rect2(p_at, Vector2(p_size,
			p_size * BalanceUI.VIEW_ART_FEET_LINE / BalanceUI.VIEW_ART_CANVAS))
	return Rect2(p_at + frac.position * p_size, frac.size * p_size)


# ---------------------------------------------------------------- view scenes (P28)
## THE two things everyone who draws a view scene has to get right live here, so that a
## part looks the same wherever it is shown: fit_view() places it, play_view_idle()
## starts it. Today that is the board (Unit._load_view) and the almanac's detail panel
## (AlmanacView), which is exactly why they share this code instead of repeating it.
static func fit_view(p_view: Node2D, p_box_side: float) -> void:
	## Places a view scene in a square box of p_box_side pixels, CENTRED ON ITS PARENT's
	## origin. The part contract is what makes ONE scale and ONE offset enough for every
	## scene (see Balance's "unit VIEW scenes" block): the art is authored on a 128 px
	## canvas and the scene's origin is the unit's FEET CENTRE, so the scale is
	## box / VIEW_ART_CANVAS and the origin moves down to where a sprite of the same art
	## puts its ink bottom - (112 - 64) * k, i.e. +22.5 in a 60 px box. A view and a sprite
	## therefore cover the same pixels, and a view is the same size on the lawn and in the
	## almanac panel.
	if p_view == null or p_box_side <= 0.0:
		return
	var k := p_box_side / BalanceUI.VIEW_ART_CANVAS
	p_view.scale = Vector2(k, k)
	p_view.position = Vector2(0.0,
		(BalanceUI.VIEW_ART_FEET_LINE - BalanceUI.VIEW_ART_CANVAS * 0.5) * k)


static func view_animation_player(p_root: Node) -> AnimationPlayer:
	## The part's AnimationPlayer, SEARCHED for rather than hardcoded: where a view keeps
	## it is the part's own business (the preview fixture scenes/_preview/preview_view.tscn
	## searches the same way). The first one wins; a part with none answers null.
	if p_root == null:
		return null
	var found := p_root.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	return found[0] as AnimationPlayer


static func play_view_idle(p_root: Node) -> String:
	## Asks a view instance for its IDLE clip and answers which animation it started ("" =
	## nothing to play). THE one place that decides this, so a part behaves identically on
	## the board and in the almanac panel.
	##
	## Best effort by design: a part with no AnimationPlayer, or none with an "idle" clip,
	## is a legitimate part - it may be completely still, or its own script may drive the
	## animation (spikerock_view.tscn plays "spike_attack" and has no idle at all) - so
	## nothing is warned here. The part's own `autoplay` is honoured as the second choice.
	## UnitArt.self_check() prints, per registered part, which of the two it will get.
	var player := view_animation_player(p_root)
	if player == null:
		return ""
	if player.has_animation(BalanceUI.VIEW_IDLE_ANIMATION):
		player.play(BalanceUI.VIEW_IDLE_ANIMATION)
		return BalanceUI.VIEW_IDLE_ANIMATION
	if player.autoplay != "":
		player.play(player.autoplay)
		return player.autoplay
	return ""


static func play_view_clip(p_root: Node, p_clip: String) -> bool:
	## [P110] "Does this part have an animation for THIS event - and if so, play it." This is
	## the question the named unit effects ask before falling back to their generic pose
	## (Unit.fx_body_plays, docs/prompt/FX.md §6), so a unit that can speak for itself about a hit is
	## never given one it did not ask for.
	##
	## Deliberately narrow: FALSE when the clip is missing, with no fall-back to the idle clip
	## or to `autoplay` - the caller is not asking "play something", it is asking "can this
	## body answer for itself here?", and a "no" is the signal to use the generic effect. That
	## is why nothing warns. Today no registered part carries any of these clips, which makes
	## this the branch nothing takes yet.
	##
	## ⚠ NOT DONE YET, and it only matters the day the first part does carry one: nothing
	## walks the part back to its idle clip after such a clip finishes. Whoever authors the
	## first one decides that here (AnimationPlayer.animation_finished -> play_view_idle).
	if p_root == null or p_clip == "":
		return false
	var player := view_animation_player(p_root)
	if player == null or not player.has_animation(p_clip):
		return false
	player.play(p_clip)
	return true


static func warn_once(p_path: String) -> void:
	if bool(_warned.get(p_path, false)):
		return
	_warned[p_path] = true
	push_warning("[Art] cannot load " + p_path
		+ " -> flat placeholder shape (is the editor still importing it?)")


## [P92] kinds already warned about, so a per-frame draw cannot flood the log.
static var _unplaced_warned: Dictionary = {}


static func draw_item_icon(ci: CanvasItem, p_box: Rect2, p_base: Texture2D,
		p_mark: Texture2D, p_kind: String, p_tint: Color = Color.WHITE) -> void:
	## [P23/P24/P92] Draws one composed item icon into p_box: the item's base picture over
	## the whole box, then the plant mark scaled into the blank area that KIND of item has
	## for it. A null texture is simply skipped, exactly like load_texture() tolerates a
	## missing import, so a caller can hand over whatever it has.
	##
	## This is THE place that knows the mark geometry (BalanceUI.mark_geometry): a talent
	## potion puts the plant on the bottle's cork, a summon scroll puts it on the
	## parchment. Both the item cells (ui/item_tile.gd, i.e. warehouse / shop / backpack)
	## and the garden's tool icons go through it, which is what keeps one item looking the
	## same on every screen. A kind with no geometry draws its base picture alone.
	if p_base == null:
		return
	ci.draw_texture_rect(p_base, p_box, false, p_tint)
	if p_mark == null:
		return
	var geometry := BalanceUI.mark_geometry(p_kind)
	if geometry.is_empty():
		## [P92] A mark that cannot be placed is a WIRING bug, not an empty picture: the
		## caller asked for a composite and handed over a kind nobody measured. It happens
		## on every repaint, so it is said once per kind - and the [Almanac] boot claim
		## ("every row with a mark names a kind its geometry knows") is the same rule
		## caught before the window ever opens.
		if p_mark != null and not _unplaced_warned.has(p_kind):
			_unplaced_warned[p_kind] = true
			push_warning("[Art] a plant mark was loaded for kind \"%s\", which has no mark geometry - drawn flat" % p_kind)
		return
	var area: Rect2 = geometry["area"]
	var side: float = p_box.size.x * float(geometry["scale"])
	var frac: Vector2 = area.get_center() / float(geometry["canvas"])
	var centre: Vector2 = p_box.position + frac * p_box.size
	ci.draw_texture_rect(p_mark, Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)),
		false, p_tint)


static func art_paths() -> Array:
	## EVERY sprite the game may draw: the paths the CODE names plus [P28] the paths the
	## SHEETS register (the svg column of data/units/plants.csv, data/units/zombies.csv and
	## data/items.csv). self_check() walks this list, so a sprite that no longer resolves -
	## a typo in an svg cell, a file that moved - shows up as NOT IMPORTED instead of as
	## "the art did not change".
	var out: Array = code_art_paths()
	_append_new(out, sheet_art_paths())
	return out


static func code_art_paths() -> Array:
	## The paths the CODE itself names: the garden pot, every item icon and the four main
	## menu pictures. The game draws these whatever the sheets say, so a missing import here
	## IS a failure - the unit sprites are NOT in this list, because the sheets own them now
	## (sheet_art_paths(); a path only the sheet names may well be one nobody has drawn).
	var out: Array = [BalanceUI.ART_GARDEN_POT]
	_append_new(out, Balance.item_art_paths())
	_append_new(out, BalanceUI.menu_icon_paths())
	## [P93] the level list's first-clear chest: also code-named, so a missing file FAILs.
	_append_new(out, BalanceUI.chest_art_paths())
	return out


## [D79] The projectile sheet, by path: it deliberately has no class_name (the "ProjectileDB
## doctrine" its own header explains), and a script that uses a preloaded constant must declare it.
const ShotDB := preload("res://scripts/core/db/projectile_db.gd")


static func sheet_art_paths() -> Array:
	## [P28] What the SHEETS register, imported or not. The unit sheets name the WHOLE
	## roster of the design far ahead of the art folder, so a path that does not resolve
	## here is counted by self_check() rather than failed.
	var out: Array = []
	_append_new(out, PlantDB.art_paths())
	_append_new(out, ZombieDB.art_paths())
	_append_new(out, ItemDB.art_paths())
	## [D79] ...and the shots' pictures (data/projectiles.csv's 贴图 column). Preloaded by path for
	## the reason ProjectileDB has no class_name at all (see its header).
	_append_new(out, ShotDB.art_paths())
	return out


static func _append_new(p_out: Array, p_paths: Array) -> void:
	for item in p_paths:
		var path := str(item)
		if path != "" and not p_out.has(path):
			p_out.append(path)


# ---------------------------------------------------------------- self check
static func self_check() -> void:
	print("[Art] --- unit sprites (placeholder art v2) ---")
	var head := "[Art] sprite box %d px" % int(BalanceUI.UNIT_ART_SIZE)
	head += ", cell %d px" % Balance.CELL_SIZE
	head += ", linear filter override = " + str(BalanceUI.UNIT_ART_LINEAR_FILTER)
	print(head)
	var ok := true
	## [P28] A path the CODE names must resolve - the game draws it whatever the sheets
	## say. A path only the SHEETS name may well be one nobody has drawn yet (the sheets
	## list the whole design), so those are counted below instead of failed; the [Plants] /
	## [Zombies] lines marked NOT IMPORTED say which cell asked for which file.
	var code := code_art_paths()
	var pending := 0
	for item in art_paths():
		var path := str(item)
		var tex := load_texture(path)
		if tex == null and not code.has(path):
			pending += 1
			continue
		var good := tex != null
		ok = ok and good
		var line := "[Art] " + short_art_path(path)
		if tex != null:
			line += "  %dx%d px" % [tex.get_width(), tex.get_height()]
			line += "  drawn at %d px" % int(BalanceUI.UNIT_ART_SIZE)
		else:
			line += "  NOT IMPORTED (flat placeholder shape in use)"
		line += "  | " + ("OK" if good else "FAIL")
		print(line)
	if pending > 0:
		print("[Art] %d sprite path(s) named by the sheets are not imported yet (not a failure)"
			% pending)
		print("[Art]        -> see the [Plants] / [Zombies] lines marked NOT IMPORTED")
	if not ok:
		print("[Art]        -> let the editor finish importing assets/svg/**/*.svg,")
		print("[Art]        -> then reload the project (Project > Reload Current Project)")

	# the sprite box must not collide with the name, the HP bar or the action bar
	var half := BalanceUI.UNIT_ART_SIZE * 0.5
	var fits_cell: bool = half <= float(Balance.CELL_SIZE) * 0.5 - 2.0
	var fits_bars: bool = half < absf(BalanceUI.UNIT_HP_BAR_Y) and half < BalanceUI.UNIT_ACTION_BAR_Y
	var fits: bool = fits_cell and fits_bars
	ok = ok and fits
	print("[Art] sprite box clears the cell edge and both bars (half %d px) = %s | %s"
		% [int(half), fits, "OK" if fits else "FAIL"])

	# [P26/P28] How much of the roster the art folder really covers, counted through the
	# SHEETS' own svg column (PlantDB / ZombieDB). The sheets register a picture for
	# nearly every row - the whole design - while only part of those files exist yet, so a
	# gap is NOT a failure (the plant falls back to the flat shape, the zombie to the base
	# picture); it is the number to look at when "the new plant has no picture" comes up.
	print("[Art] unit art: %d of %d plant(s) from %s and %d of %d zombie type(s) from %s draw their own file"
		% [PlantDB.art_count(), PlantDB.count(), PlantDB.PATH.get_file(),
		   ZombieDB.art_count(), ZombieDB.count(), ZombieDB.PATH.get_file()])

	# [P27] How much of the ITEM registry resolves. The sheet itself is the source of
	# those paths (ItemDB): the ones it shares with Balance's icon table are in the
	# checked list above, the rest is counted here. This line is the count to look at when
	# "the new item has no picture" comes up.
	var item_paths: Array = ItemDB.art_paths()
	var item_live := 0
	for item_path in item_paths:
		if load_texture(str(item_path)) != null:
			item_live += 1
	print("[Art] item art: %d of %d svg path(s) registered by %s resolve (%d item row(s))"
		% [item_live, item_paths.size(), ItemDB.PATH.get_file(), ItemDB.count()])

	# [P23/P92] A composite item icon is TWO files: the item's own picture, plus the plant
	# mark laid over it. Two kinds carry one - a talent potion (the plant it strengthens,
	# over the generic bottle of its tier) and a summon scroll (the plant it unlocks, over
	# the one shared scroll) - and each kind has its OWN place for the mark, so this loop
	# asks the kind instead of assuming the bottle.
	print("[Art] --- composite item icons: picture + plant mark (P23 potion, P92 scroll) ---")
	var composite_ok := true
	var kinds_seen: Array[String] = []
	for entry in Balance.ITEM_ORDER:
		var item := str(entry)
		var mark := Balance.item_mark_art(item)
		if mark == "":
			continue
		var kind := Balance.item_kind(item)
		var geometry := BalanceUI.mark_geometry(kind)
		var base := Balance.item_art(item)
		var base_tex := load_texture(base)
		var mark_tex := load_texture(mark)
		## A potion resolves its bottle through the TIER, so a potion without one is a bug;
		## a scroll needs no tier at all.
		var tier_ok: bool = kind != "talent" or Balance.item_tier(item) != ""
		var good: bool = not geometry.is_empty() and base_tex != null and mark_tex != null and tier_ok
		composite_ok = composite_ok and good
		if not kinds_seen.has(kind):
			kinds_seen.append(kind)
		print("[Art] %s: %s + %s mark drawn at %d%% of the icon | %s"
			% [Balance.item_name(item), base.get_file(), mark.get_file(),
			   int(float(geometry.get("scale", 0.0)) * 100.0), "OK" if good else "FAIL"])
	## The mark box is centred on its kind's area and never wider than it: a wider one would
	## spill past the blank face it was measured for (the bottle's shoulder, the scroll's axle).
	for kind in kinds_seen:
		var geometry := BalanceUI.mark_geometry(kind)
		var area: Rect2 = geometry["area"]
		var side: float = float(geometry["scale"]) * float(geometry["canvas"])
		var box := Rect2(area.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
		var placed: bool = area.get_center().is_equal_approx(box.get_center()) \
			and box.size.x <= area.size.x + 0.5
		composite_ok = composite_ok and placed
		print("[Art] %s mark area %dx%d at (%d,%d) -> mark box %dx%d | %s"
			% [kind, int(area.size.x), int(area.size.y), int(area.position.x), int(area.position.y),
			   int(box.size.x), int(box.size.y), "OK" if placed else "FAIL"])
	ok = ok and composite_ok

	# [P28] --- unit VIEW scenes: the tscn column of the two unit sheets ---
	# The board draws a view scene INSTEAD of the sprite whenever it resolves, and it asks
	# that scene to play "idle" (UnitArt.play_view_idle). Both halves are reported here:
	#   * a tscn cell naming a part nobody has built yet is the ordinary "not yet" state -
	#     the sprites of the same sheets work exactly that way - so it is COUNTED, and the
	#     sprite it falls back to is named on the line;
	#   * a part that loads but carries no idle clip is fine (a still view, or a part whose
	#     own script plays its animation), so that is reported, not failed;
	#   * a part whose ROOT is not a Node2D IS a failure: the board cannot place it and
	#     would silently keep drawing the sprite.
	print("[Art] --- unit view scenes: the tscn column is the board's body (P28) ---")
	var views_ok := true
	var registered := 0
	var built := 0
	for entry in _view_registry():
		var owner := str(entry[0])
		var id := str(entry[1])
		var path := str(entry[2])
		registered += 1
		var packed := load_scene(path)
		if packed == null:
			print("[Art] view %s %s: %s NOT FOUND (the sprite stays in use) | -"
				% [owner, id, path.get_file()])
			continue
		var node := packed.instantiate()
		var placeable: bool = node is Node2D
		var clip := _view_idle_state(node)
		node.free()                 # not in the tree, so this is immediate and safe
		built += 1
		var line := "[Art] view %s %s: %s  %s" % [owner, id, path.get_file(), clip]
		if not placeable:
			line += "  root is not a Node2D"
		views_ok = views_ok and placeable
		print(line + " | " + ("OK" if placeable else "FAIL"))
	print("[Art] unit views: %d of %d plant(s) and %d of %d zombie type(s) draw a scene (%d registered cell(s), %d of them built)"
		% [PlantDB.view_count(), PlantDB.count(), ZombieDB.view_count(), ZombieDB.count(),
		   registered, built])
	if registered == 0:
		print("[Art] -> no tscn cell is filled in yet: every unit draws its sprite (or the flat shape)")
	ok = ok and views_ok
	print("[Art] self-check %s" % ("PASSED" if ok else "FAILED"))


static func _view_registry() -> Array:
	## [P28] Every view scene the two UNIT sheets register, as [owner, id, res:// path]
	## triples in sheet order. Built from the sheets and not from a table in the code, so a
	## tscn cell becomes a log line the moment it is typed into the spreadsheet.
	var out: Array = []
	for id in PlantDB.ids():
		var path := PlantDB.scene_file(id)
		if path != "":
			out.append(["plant", id, path])
	for id in ZombieDB.ids():
		var path := ZombieDB.scene_file(id)
		if path != "":
			out.append(["zombie", id, path])
	return out


static func _view_idle_state(p_view: Node) -> String:
	## [P28] What the board will manage to play in this part, as one short phrase: the idle
	## clip itself, the part's OWN autoplay when there is no idle clip, or a plain note -
	## a still view is a legitimate view, so none of these is a failure.
	var player := view_animation_player(p_view)
	if player == null:
		return "no AnimationPlayer (nothing to play)"
	var idle := BalanceUI.VIEW_IDLE_ANIMATION
	if player.has_animation(idle):
		return "plays \"%s\"" % idle
	if player.autoplay != "":
		return "no \"%s\" clip; plays its own autoplay \"%s\"" % [idle, player.autoplay]
	return "no \"%s\" clip (stays still)" % idle
