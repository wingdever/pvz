extends RefCounted
class_name WarMain
## [W3] THE WAR MATCH'S LIFECYCLE - who puts the arena up, and where its reports land.
##
## BrawlMain's shape (scripts/core/brawl/brawl_main.gd) with the SESSION taken out: a brawl
## is rounds, a purse and offers - a war WAS one match on one map, with nothing here that
## outlives a bout and nothing to route between rounds. [W8] AMENDED: the war grew ROUNDS -
## the field is cleared when a rolled enemy line-up falls, the deployment table reopens for
## the next one, and this file is where the between-bouts state now lives: the session's
## setup (map, seed, army, rolled round list) and the round cursor, neither of which the
## arena or the page may own because BOTH of them get rebuilt every bout. Still no save,
## no purse, no offers: leave the door and the session is simply gone.
##
## Like the brawl's owner and unlike BattleMain's: no save, no garden, no RunState (D17's
## rule is the classic family's). Leaving a match is free and restarting it is the same door.

const WAR_SCENE := preload("res://scenes/war.tscn")
## WarSetup BY PATH - the batch-alias rule war.gd follows for the same reason.
const Setup := preload("res://scripts/core/war/war_setup.gd")

var game: GameManager = null             # the autoload; set right after .new()

## [W4] The committed setup, staged HERE instead of on the page: the deployment table only
## has a `rows()` door to offer it, and R-replay inside the arena never re-reads this (the
## arena holds its own `setup`). null = "nobody committed yet", which only the F6 fixture
## path (or a start_match that read an empty page) can ever produce.
## [W8] This object is now also the SESSION: the same setup carries the rolled round list
## (fixture-born, one seed), and `_round` is the cursor into it. A war is no longer one
## match this file shepherds - it is a string of bouts between re-opened deployment tables,
## and this cursor is the only thing that knows which one is standing.
var _setup = null
var _round := 0


func _arena():
	## game.war is typed Node on purpose (naming War there would close an import cycle, the
	## brawl's comment says). The return stays UNtyped for the batch's own reason: the War
	## class is this file's sibling and the first rescan has not seen it yet.
	return game.war


# ---------------------------------------------------------------- the door
func start() -> void:
	## The classic shell's entry (main_menu's WAR row). [W4] the door opens on the
	## DEPLOYMENT TABLE, not on the field: a war match is placed before it is fought, and
	## 出征 on that page is what calls start_match() below.
	## [W8] A new session is BORN here, army still unwritten: Setup.fixture() resolves the
	## map and rolls the whole round list off the fresh seed, because the page must be able
	## to scout round 1 BEFORE the first 出征 commits to it. Everything a later bout needs
	## - the same rolls, the same cells - already lives in `_setup` from this moment.
	if game == null:
		return
	print("[War] " + WarDB.status_text())
	if WarDB.is_empty():
		push_warning("[War] no map to fight: check data/war/maps.csv")
		return
	_setup = Setup.fixture()
	_round = 0
	## open_war_formation() runs leave_game() (every page opener does): the menu comes down
	## and whatever world was last up is torn down, which is what makes WAR, BRAWL and the
	## battle mutually exclusive without any of them knowing the others exist.
	game.front.open_war_formation()
	_brief_formation()


func start_match() -> void:
	## [W4] THE COMMIT: 出征 pressed on the deployment table. [W8] AMENDED - a commit is
	## now PER ROUND, and it harvests exactly one field: the page's rows go through
	## from_placement's re-check and only their vetted `left` is taken into the session's
	## setup. The map, the seed and the rolled rounds STAY - re-running from_placement for
	## the whole setup would mint a fresh seed and reroll the war behind the preview's back,
	## which is precisely what scouting an enemy line-up forbids.
	if game == null:
		return
	if _setup == null:
		_setup = Setup.fixture()
	var page = game.front.war_formation_view
	var rows: Array = page.rows() if page != null and page.has_method("rows") else []
	var map_id := ""
	if page != null and page.has_method("map_id"):
		map_id = str(page.map_id())
	_setup.left = Setup.from_placement(map_id, rows).left
	_setup.round_no = _round
	game.front.leave_game()
	game.front.screen = FrontEndFlow.Screen.WAR
	## [W3] The brawl's theme stands in until the war has its own track - one place plays it,
	## one place (show_main_menu -> the menu page) crossfades back.
	Music.play(BalanceAudio.MUSIC_BRAWL)
	_set_up_arena()


func leave_formation() -> void:
	## [W4] ESC from the deployment table. Nothing to unwind (the rows lived on the page and
	## the page is leaving), and the menu's own door takes it down on the way.
	print("[War] left the deployment table")
	if game != null:
		game.show_main_menu()


func leave_war() -> void:
	## ESC from the arena (the `left` signal's only landing today) - and later from the
	## formation page. Nothing to unwind: no save was ever opened.
	print("[War] left the battlefield")
	_teardown_arena()
	game.show_main_menu()


# ---------------------------------------------------------------- the arena
func _set_up_arena() -> void:
	if game == null:
		return
	if game.war != null:
		_teardown_arena()
	var arena = WAR_SCENE.instantiate()
	if arena == null or not arena.has_method("begin"):
		push_error("[War] scenes/war.tscn did not instantiate as a War arena")
		return
	game.war = arena
	arena.settled.connect(_on_match_settled)
	arena.left.connect(_on_arena_left)
	var shell := game.get_tree().current_scene
	if shell == null:
		push_error("[War] no current scene to put the arena in")
		return
	shell.add_child(arena)
	arena.begin(_match_setup())


func _match_setup():
	## What this match fights: [W4]'s commit if there is one, the fixture otherwise (F6 on
	## scenes/war.tscn, or a start_match that somehow carried no rows - an empty field the
	## page's own 出征 rule never lets through, but the arena does not trust that either).
	return _setup if _setup != null else Setup.fixture()


func _teardown_arena() -> void:
	## Freeing the scene is taking it down: clock, field and camera go with the nodes, and
	## the camera leaves the viewport with them.
	if game == null:
		return
	var arena = _arena()
	if arena == null:
		game.war = null
		return
	arena.queue_free()
	game.war = null


func _on_match_settled(result: Dictionary) -> void:
	## A decided BOUT. [W8] the curtain's word splits the road in two:
	##   "round" - a middle bout fell, the war is NOT over: no receipt stands here, the
	##     arena is torn down and the deployment table reopens for the next scouted line-up
	##     (the user's 每回合清场重置 - "all units reset" is exactly what rebuilding the
	##     arena and the page from the session's stored setup means);
	##   anything else - win / lose / draw, the war's ending: the arena STAYS UP and its
	##     HUD draws the receipt (no separate result page in v1), R replays the bout, ESC
	##     leaves.
	if str(result.get("winner", "")) == "round":
		_next_round()
		return
	print("")
	print("================ WAR RESULT: %s ================" % str(result.get("winner", "?")))
	print("arena  : %s" % str(result.get("summary", "")))
	print("=================================================")


func _next_round() -> void:
	## The round step: cursor up, battlefield down, table back up. Order matters only
	## against the stale-cursor bug - `_setup.round_no` is written by the NEXT
	## start_match() from wherever `_round` stands now, so nothing may begin() an arena
	## between these lines.
	_round += 1
	_teardown_arena()
	game.front.open_war_formation()
	_brief_formation()


func _brief_formation() -> void:
	## Hand the fresh page everything the SESSION already knows: which round of how many
	## it is, what that round's roller put where (the scouted line-up, drawn before the
	## march because the march must answer to it), and the army that fought last time
	## (first opening: none - a prefill of [] says so by doing nothing). Every door is
	## has_method-guarded like the arena's HUD ones: the page owns these names, this file
	## only knocks.
	if _setup == null:
		return
	var page = game.front.war_formation_view
	if page == null:
		return
	var rows: Array = []
	if _round < _setup.rounds.size():
		rows = _setup.rounds[_round] as Array
	if page.has_method("show_round"):
		page.show_round(_round + 1, _setup.rounds.size())
	if page.has_method("show_enemy"):
		page.show_enemy(rows)
	if page.has_method("prefill"):
		page.prefill(_setup.left)


func _on_arena_left(reason: String) -> void:
	## The arena asked to leave; where that goes is this object's routing, and every arm
	## ends on a page.
	match reason:
		"menu", "retreat":
			leave_war()
		_:
			print("[War] the arena asked to leave for an unknown reason: " + reason)
