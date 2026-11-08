extends RefCounted
## [P87] THE THREE FACTORIES: an ITEM, a PROJECTILE, a UNIT - one place that CREATES.
##
## WHY THIS FILE EXISTS (user design, 2026-09-25): "改玩法机制与内容只要按明确规则加改，
## 不必了解整个工程". Production used to be spread over four owners - a sunflower banked sun
## inside ProducerPlant.gain_sun(), a zombie death paid loot inside Rewards._pay_drop(), a
## cleared level paid its rewards inside Rewards.grant(), and a shot was launched by three
## unit scripts each building its own options dictionary for Projectile.fire(). Adding a fifth
## producer therefore meant reading all four.
##
## THE RULE THIS FILE EXISTS FOR: everything that PRODUCES something goes through a factory
## here. A factory owns WHAT is created and WHERE it lands, and nothing else:
##   * not the prose - the caller prints its own log line and pops its own text;
##   * not the rules - whether a summon is ALLOWED (sun, card charge, scroll, a free garden
##     instance, the round budget) stays in Game.try_place_at;
##   * not the numbers - those live in the sheets (AGENTS.md §2).
##
## IT ALSO MEASURES. `Profile.add_item` refuses an id the code tables do not know and says
## nothing about it, and a cap can swallow part of a flood, so every factory reports what
## actually LANDED rather than what was asked for (see create_items -> "landed").
##
## BY PATH, NO class_name - same reason as Rewards / SafeIO / DropDB: a brand-new global class
## is invisible to `godot --headless` until the editor rescans the project, and a check that
## cannot run headlessly is not a check (docs/ARCHITECTURE.md §1.3); where the three
## factories sit in the ownership map is written down in docs/ARCHITECTURE.md §2.

## [P109] ItemDB and PlantScripts are global classes (their files carry `class_name`), so a
## `const X := preload(...)` alias only shadowed the global name (SHADOWED_GLOBAL_IDENTIFIER).
const ProjectileBase := preload("res://scripts/projectiles/projectile.gd")
## [P89] the thing that lies on the lawn: its two styles are the constant names the field
## destination reads (天际 for the sky's own sun, 落地 for a producer's).
const SunDrop := preload("res://scripts/core/battle/sun_drop.gd")

## [P87] The CLOSED list of sources. A typo must not split the books in two, so an unknown
## tag is refused AND reported - the same rule [P86] gave a column name the sheet does not
## have. Add a source here when you add a producer; that is the whole registration.
const SOURCE_PLAYER := "player"
const SOURCE_SUNFLOWER := "sunflower"
const SOURCE_MARIGOLD := "marigold"
const SOURCE_NATURAL := "natural"
const SOURCE_ZOMBIE_DEATH := "zombie_death"
const SOURCE_LEVEL_CLEAR := "level_clear"
const SOURCES: Array[String] = [SOURCE_PLAYER, SOURCE_SUNFLOWER, SOURCE_MARIGOLD,
	SOURCE_NATURAL, SOURCE_ZOMBIE_DEATH, SOURCE_LEVEL_CLEAR]

## Destinations. AUTO is the default because the caller should not have to know which
## container is live: a battle collects into the BACKPACK (merged into the warehouse when
## the battle settles), everything else lands in the WAREHOUSE - the rule Rewards already
## follows, written down once here.
const WHERE_AUTO := "auto"
const WHERE_BACKPACK := "backpack"
const WHERE_WAREHOUSE := "warehouse"
const WHERE_FIELD := "field"           # [P88] on the board, waiting to be picked up

## What went wrong since the last clear - same shape as UnitCsv's complaint channel: a
## refusal nobody sees is a silent fallback, and this project counts those as bugs.
static var _problems: Array[String] = []


static func problems() -> Array[String]:
	return _problems.duplicate()


static func clear_problems() -> void:
	## For a caller that audits its own refusals (self_check does exactly that).
	_problems.clear()


static func _note(p_text: String) -> void:
	if not _problems.has(p_text):
		_problems.append(p_text)


static func source_known(p_source: String) -> bool:
	return SOURCES.has(p_source)


# ---------------------------------------------------------------- items
static func create_items(profile: Profile, item: String = "coin_silver", count: int = 1,
		where: String = WHERE_AUTO, source: String = SOURCE_PLAYER,
		at: Vector2 = Vector2.INF, amount: int = 0, board = null) -> Dictionary:
	## THE ITEM FACTORY. Defaults say "one silver coin, from the player, to whichever
	## container is live" - a call with no arguments is legal and does something sensible.
	## [P106] THE FIRST PARAMETER IS THE LEDGER, NOT A MANAGER: `board` is only here for the one
	## destination that needs a lawn, and it doubles as the answer to "is a battle live?" -
	## a non-null board means the drop belongs in the backpack. That is the whole of the
	## session knowledge this factory used to reach for through Screen.GAME.
	## Returns {item, count, landed, where, source, at}: `count` is what was asked for and
	## `landed` is what the ledger actually took, which is what a caller must report.
	var out := {"item": item, "count": 0, "landed": 0, "where": "", "source": source, "at": at}
	if profile == null:
		_note("create_items: no profile to pay into (source %s)" % source)
		return out
	if not source_known(source):
		_note("create_items: unknown source \"%s\" - add it to SOURCES, nothing was created" % source)
		return out
	if count <= 0:
		_note("create_items: %s asked for %d %s (nothing created)" % [source, count, item])
		return out
	if not ItemDB.has(item) and not Balance.is_item(item):
		_note("create_items: \"%s\" is not an item any sheet knows" % item)
		return out
	## [P89] 落在棋盘上 IS a destination of its own: the payload becomes a thing lying on the
	## lawn (a sun) instead of a row in a ledger. It is the only destination that owes the
	## player an action, which is exactly why the pool is not filled here.
	if where == WHERE_FIELD:
		return _create_on_field(board, item, count, source, at, amount, out)
	var target := resolve_where(where, board != null)
	out["where"] = target
	var before := profile.count_of(item, target)
	profile.add_item(item, count, target, false)
	var landed := profile.count_of(item, target) - before
	out["count"] = count
	out["landed"] = landed
	if landed < count:
		## Profile.add_item drops an id the CODE tables do not know, in silence. Measuring
		## the container is the only way to notice, and a factory that reported success
		## while nothing landed would be the exact bug this project keeps digging out.
		_note("create_items: only %d of %d %s landed in %s (the profile refuses an item no ITEM_DEFS row owns)"
			% [landed, count, item, target])
	return out


static func resolve_where(where: String = WHERE_AUTO, live: bool = false) -> String:
	## The destination rule, in one place. An unknown destination falls back LOUDLY.
	## [P106] `live` is passed IN: who is asking already knows whether a battle is running
	## (its board is not null), and a factory that cannot see Game cannot ask it.
	if where == WHERE_AUTO:
		return WHERE_BACKPACK if live else WHERE_WAREHOUSE
	if where == WHERE_BACKPACK or where == WHERE_WAREHOUSE:
		return where
	_note("resolve_where: unknown destination \"%s\" -> warehouse" % where)
	return WHERE_WAREHOUSE



# ---------------------------------------------------------------- projectiles
static func create_projectile(shooter: Unit, target: Unit, damage: int = -1,
		opts: Dictionary = {}, shot: String = "") -> void:
	## THE PROJECTILE FACTORY: a thin shell over Projectile.fire(), which already owns the
	## flight, the collision and the staged/synchronous split. It fills in what the caller
	## left out and nothing else:
	##   shot   "" -> the plain pea row (data/projectiles.csv) - P91: the shot is a ROW, and
	##                 the base reads the trajectory, the look, the pierce/bounce budget,
	##                 the rider and the two cues out of it,
	##   damage -1 -> the shooter's own skill value.
	## The class is always PeaProjectile: since P91 no shot needs its own class unless the
	## TABLE cannot express it, and a shot that does inherits from the base.
	if shooter == null or target == null:
		_note("create_projectile: a shot needs both a shooter and a target")
		return
	var fired := opts.duplicate()
	if shot != "":
		fired["shot"] = shot
	ProjectileBase.fire(PeaProjectile, shooter, target,
		damage if damage >= 0 else shooter_damage(shooter), fired)

static func _create_on_field(board, item: String, count: int, source: String,
		at: Vector2, amount: int, out: Dictionary) -> Dictionary:
	## [P89] The 落地 destination: only the sun knows how to lie on a lawn today, and a drop is
	## worth `amount` sun points (the producer decides that number - the item's `price` is what
	## it SELLS for, which is a different fact).
	if item != "sun":
		_note("create_items: \"%s\" cannot be dropped on the field (only sun can)" % item)
		return out
	if board == null or board.grid == null:
		_note("create_items: no lawn to drop a sun on")
		return out
	var points := amount if amount > 0 else maxi(1, count)
	## Typed, not `:=`: a ternary mixing a Vector2 with Vector2.INF hands back a Variant and
	## 4.7 refuses to infer a type from it (a trap this project has hit in probes too).
	var from: Vector2 = at if at != Vector2.INF else board.grid.cell_center(0, 0)
	var style := SunDrop.STYLE_SKY if source == SOURCE_NATURAL else SunDrop.STYLE_TOSS
	var drop: Node2D = board.spawn_sun_drop(points, source, style, from)
	out["where"] = WHERE_FIELD
	out["count"] = count
	out["landed"] = points if drop != null else 0
	return out


static func shooter_damage(shooter: Unit) -> int:
	## What this shooter's action is worth when a caller does not say. The plant families
	## answer skill_damage(); everything else falls back to the instance's own skill value.
	if shooter == null:
		return 0
	if shooter.has_method("skill_damage"):
		return int(shooter.call("skill_damage"))
	return shooter.skill_value


# ---------------------------------------------------------------- units
static func is_known(type: String) -> bool:
	## [B31] DOES ANY ROSTER IMPLEMENT THIS ID? - the first three tests of create_unit() below, in
	## the same order and with the same doors, asked WITHOUT a board. Two callers need exactly this
	## answer (the sheet-side validators: `data/brawl/roster.csv` and the enemy generator) and a
	## fourth copy of the dispatch list is how a roster gets a new family and a sheet keeps calling
	## its units "not implemented". A PLANT with a sheet row but no script is false here, which is
	## the [P86] rule (almanac-only is not summonable), not a new one.
	if type == "":
		return false
	return ZombieDB.has(type) or PlantScripts.is_registered(type) or PieceDB.has(type)


static func create_unit(board, type: String = "", at: Vector2i = Vector2i.ZERO,
		opts: Dictionary = {}) -> Unit:
	## THE UNIT FACTORY: a TYPE ID in, a node on the board out. It is deliberately NOT the
	## rule entry - "may this be summoned at all" stays in Game.try_place_at, so nothing can
	## reach the board while skipping the sun cost, the card charge, the scroll or the garden
	## ledger. Returns null (and says why) when the type cannot be built.
	## [P106] The TYPE is judged against the sheets FIRST, so a caller with no board still gets
	## the honest answer ("this id implements nothing") instead of a flat "no battle". Only the
	## two branches that actually put a body on a lawn need one.
	if type == "":
		_note("create_unit: no type id")
		return null
	if ZombieDB.has(type):
		if board == null:
			_note("create_unit: no battle to put %s on" % type)
			return null
		return board.spawn_zombie(type, at.x, at.y)
	## `is_registered` answers for a spirit copy too (PlantScripts strips the spirit prefix),
	## which is why the spirit summon - a copy that is NOT a roster row - comes through this
	## same door instead of needing a second one of its own.
	if PlantScripts.is_registered(type):
		if board == null:
			_note("create_unit: no battle to put %s on" % type)
			return null
		var unit = board.spawn_unit(PlantScripts.script_for(type), at.x, at.y)
		if unit != null and int(opts.get("hp", -1)) >= 0:
			unit.hp = mini(int(opts["hp"]), unit.max_hp)
		return unit
	## [B5] THE THIRD ROSTER: a BRAWL PIECE - any faction of that mode, which is the humans
	## (data/units/humans.csv) and, since [P110f], the monsters (data/units/monsters.csv). It is
	## its own branch because its DOOR is its own - Brawl.spawn_human() is where a body is told
	## what it is (the id is not a const in a file, see HumanPiece's header), and the turn engine
	## has no such door: a brawl faction is not fielded in a battle, so a battle asking for one is
	## a loud refusal rather than a call that blows up at run time.
	if PieceDB.has(type):
		if board == null:
			_note("create_unit: no battle to put %s on" % type)
			return null
		if not board.has_method("spawn_human"):
			_note("create_unit: \"%s\" is a brawl piece and this board cannot field one" % type)
			return null
		return board.spawn_human(type, at.x, at.y)
	if PlantDB.has(type):
		## [P86] rule: a plant with no script is ALMANAC-ONLY. Silently handing out a
		## peashooter (what the old fall-back did) is the "looks right, is wrong" case.
		_note("create_unit: \"%s\" has no script yet - it is almanac-only, not summonable" % type)
	else:
		_note("create_unit: \"%s\" is neither a zombie nor a plant any script implements" % type)
	return null


# ---------------------------------------------------------------- self check
static func self_check(game: GameManager) -> void:
	## Printed at start-up next to the sheets. Every REFUSAL is provoked here on purpose:
	## a guard nobody ever fired is a guard nobody knows works, so the check records the
	## note it expects, counts it, and clears the channel afterwards.
	print("[Spawn] --- factories: item, projectile, unit ---")
	var ok := true
	clear_problems()

	## 1. the closed source list
	var dup := 0
	var seen := {}
	for tag in SOURCES:
		if seen.has(tag):
			dup += 1
		seen[tag] = true
	var sources_ok: bool = dup == 0 and source_known(SOURCE_PLAYER) and not source_known("playr")
	ok = ok and sources_ok
	print("[Spawn] %d source(s), no duplicate, an unknown tag is refused = %s | %s"
		% [SOURCES.size(), str(sources_ok), "OK" if sources_ok else "FAIL"])

	## 2. the default destination (no battle is live at start-up: the warehouse)
	var auto_ok: bool = resolve_where(WHERE_AUTO, false) == WHERE_WAREHOUSE \
		and resolve_where(WHERE_AUTO, true) == WHERE_BACKPACK \
		and resolve_where(WHERE_BACKPACK, true) == WHERE_BACKPACK \
		and resolve_where(WHERE_WAREHOUSE, true) == WHERE_WAREHOUSE
	ok = ok and auto_ok
	print("[Spawn] destination default: no battle -> %s, explicit destinations kept = %s | %s"
		% [WHERE_WAREHOUSE, str(auto_ok), "OK" if auto_ok else "FAIL"])

	## 3. every refusal, one at a time (each must record exactly one note)
	var refusals := 0
	var refused := 0
	clear_problems()
	create_items(game.profile, "coin_silver", 1, WHERE_WAREHOUSE, "playr")
	refusals += 1
	refused += 1 if problems().size() == 1 else 0
	clear_problems()
	create_items(game.profile, "coin_silver", 0, WHERE_WAREHOUSE, SOURCE_PLAYER)
	refusals += 1
	refused += 1 if problems().size() == 1 else 0
	clear_problems()
	create_items(game.profile, "no_such_item_at_all", 1, WHERE_WAREHOUSE, SOURCE_PLAYER)
	refusals += 1
	refused += 1 if problems().size() == 1 else 0
	clear_problems()
	var unknown_dest: bool = resolve_where("somewhere", false) == WHERE_WAREHOUSE
	refusals += 1
	refused += 1 if problems().size() == 1 and unknown_dest else 0
	clear_problems()
	var bad_unit: Unit = create_unit(null, "no_such_unit_at_all", Vector2i.ZERO)
	refusals += 1
	refused += 1 if bad_unit == null and problems().size() == 1 else 0
	clear_problems()
	create_projectile(null, null)
	refusals += 1
	refused += 1 if problems().size() == 1 else 0
	clear_problems()
	## A plant the sheets list but no script implements must NOT become a peashooter.
	## Found by walking the roster, so this stays true when marigold is finally written.
	var scriptless := ""
	for id in PlantDB.ids():
		if not PlantScripts.is_registered(str(id)):
			scriptless = str(id)
			break
	var scriptless_ok := true
	if scriptless != "":
		var made: Unit = create_unit(null, scriptless, Vector2i(0, 0))
		scriptless_ok = made == null and problems().size() == 1
		refusals += 1
		refused += 1 if scriptless_ok else 0
		clear_problems()
	ok = ok and refused == refusals
	print("[Spawn] %d refusal(s) provoked (%s), each recorded exactly once = %d/%d | %s"
		% [refusals, (scriptless if scriptless != "" else "no script-less plant left"),
		   refused, refusals, "OK" if refused == refusals else "FAIL"])

	## 4. the projectile default: the class a bare shot gets, and the damage rule
	var proj_ok: bool = shooter_damage(null) == 0
	ok = ok and proj_ok
	print("[Spawn] a bare shot defaults to the straight round, damage falls back to the shooter (null -> 0) = %s | %s"
		% [str(proj_ok), "OK" if proj_ok else "FAIL"])

	clear_problems()
	print("[Spawn] self-check %s" % ("PASSED" if ok else "FAILED"))
