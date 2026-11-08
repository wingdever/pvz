extends RefCounted
class_name BrawlMain
## [B2b] THE BRAWL SESSION'S LIFECYCLE - a session, its rounds, and the arena each round puts up.
##
## The same shape BattleMain has for a battle, for the same reason: Game is the composition
## root and owns no bout logic. What this object owns:
##   the SESSION (BrawlSession: round counter, purse, offers - the thing that outlives a bout),
##   the arena HANDLE (game.brawl, null between bouts),
##   putting scenes/brawl.tscn up and taking it down,
##   and the routing: round page -> bout -> round page.
##
## WHAT IT DELIBERATELY DOES NOT DO (BRAWL.md §12): no save, no garden, no RunState. D17 says a
## session is never written to a disk, so leaving is free and starting over is the same door.
##
## [B5] NOTHING IS A STAND-IN ANY MORE: the player's pieces come from data/brawl/roster.csv
## (RosterDB) and the ones a reward or the shop adds are the same rows, and the enemy's come
## from data/brawl/formations.csv - both are sheets, and this file only carries them into a
## bout. [B26] took the ROUND's fork out again: an offer used to be a battle or the shop (D22) and
## confirm() was where the formation page's single button became "fight this" or "go shopping". The
## shelf lies on the board now (over the enemy half), so a round is one thing only - a bout - and
## start_bout() is the door the page's 出战 opens.

const BRAWL_SCENE := preload("res://scenes/brawl.tscn")

var game: GameManager = null             # the autoload; set right after .new()
var session: BrawlSession = null         # null between sessions (the round page says so)


func _arena() -> Brawl:
	## game.brawl is typed Node on purpose (Brawl's class would close an import cycle). One cast
	## door, so every read below is compile-checked and null between bouts.
	return game.brawl as Brawl


# ---------------------------------------------------------------- a session
func start_session() -> void:
	## The classic shell's entry. A NEW session every time: it keeps nothing on disk, so "start"
	## and "start over" are the same door (D17).
	if game == null:
		return
	session = BrawlSession.new()
	## [B8+] The mode's own theme, crossfaded in by Music.play over the menu's. Leaving the
	## session lands back on the main menu, and that page asks for MUSIC_MENU itself - so there is
	## exactly one place the brawl starts its music and none where it has to stop it.
	Music.play(BalanceAudio.MUSIC_BRAWL)
	print("[Brawl] " + FormationDB.status_text())
	if session.offers.is_empty():
		push_warning("[Brawl] no formation to fight: check data/brawl/formations.csv")
	open_formation()


func leave_session() -> void:
	## ESC on the round page, and the only way a session ends. Nothing to unwind: the purse and
	## the roster were never written anywhere (D17).
	if session != null:
		print("[Brawl] session ended: %d round(s), %d coin" % [session.round_no, session.coins])
	session = null
	_teardown_arena()
	game.show_main_menu()


func open_formation() -> void:
	## [B2c] D3's first two steps: arrange the roster BEFORE choosing an opponent. A session opens
	## here and every NEW round comes back here, so "which pieces do I field" is asked once per
	## round, always in the same place.
	_teardown_arena()
	game.show_brawl_formation()


func open_result() -> void:
	## The receipt of the bout that just ended. The three OFFERS are not here any more: they moved
	## to the formation page (B2c), which is the page that shows the board the choice is about -
	## picking an opponent and arranging your own half are one decision, and it is made in one
	## place. This door is therefore opened by exactly one thing: a settled bout.
	_teardown_arena()
	game.show_brawl_round()


# ---------------------------------------------------------------- a bout
func take_reward(p_index: int) -> void:
	## [B5] The result page's three cards. The session applies the one picked and the round
	## advances - and a page with nothing to take must not move the round on, which is what the
	## session's answer is checked for.
	if session == null:
		return
	if not session.take_reward(p_index):
		return
	next_round()


func start_bout() -> void:
	## The formation page's 出战 button. [B26] There is no fork any more - a round is a battle and
	## buying is a thing you do on the same page - so this is the one door the band's button opens.
	## The opponent was chosen THERE - session.chosen_formation() is the
	## default roll_offers put on the table - so this door takes no argument, and refuses to
	## start a bout nobody picked.
	if session == null or session.chosen_formation() == "":
		return
	game.front.hide_views()
	game.front.screen = FrontEndFlow.Screen.BRAWL
	## [B29] The line names the opponent BOTH ways (the sheet's id or the generated one, and the name
	## the player is reading) and prints what the round actually assembled: the body count and the 战力
	## sum. Those two are how the power floor is watched climbing without a test script (AGENTS §2).
	print("---------- brawl round %d vs %s (%s): %d piece(s), power %d ----------"
		% [session.round_no, session.chosen_formation(), session.chosen_title(),
		   session.chosen_rows().size(),
		   FormationDB.power_total_of(session.chosen_rows())])
	## [B7] WHAT EVERY PIECE WEARS, printed once per bout. The arena only ever sees numbers
	## (BrawlSetup carries "mods" per row), so this is the one place the link between "I dropped
	## an iron sword on the archer" and "the archer hits for +8" is visible - and with AGENTS §2
	## forbidding test scripts, a line like this IS the acceptance tool.
	print("[Brawl] " + session.attachment_report())
	_set_up_arena()


func next_round() -> void:
	## A WIN's road: the reward card has been taken (take_reward), the round advances, and the
	## player lands back on the formation page - where the piece it just paid is already in the
	## roster and can be put on the board.
	if session == null:
		return
	session.next_round()
	open_formation()


func repick() -> void:
	## D23: a loss pays nothing and does not cost the round - the SAME round's offers are still on
	## the table, on the formation page, where another opponent is one click away.
	if session == null:
		return
	session.repick()
	open_formation()


func _set_up_arena() -> void:
	if game == null:
		return
	if game.brawl != null:
		_teardown_arena()
	var arena := BRAWL_SCENE.instantiate() as Brawl
	if arena == null:
		push_error("[Brawl] scenes/brawl.tscn did not instantiate as a Brawl")
		return
	game.brawl = arena
	arena.settled.connect(_on_bout_settled)
	arena.left.connect(_on_arena_left)
	var shell := game.get_tree().current_scene
	if shell == null:
		push_error("[Brawl] no current scene to put the arena in")
		return
	shell.add_child(arena)
	arena.begin(_bout_setup())


func _bout_setup() -> BrawlSetup:
	## What this round fights: the player's stand-in line-up against the chosen formation. The
	## sheets speak in cells and the arena does the rest.
	var setup := BrawlSetup.new()
	setup.round_no = session.round_no
	setup.opponent = session.chosen_formation()
	## [B29] The NAME travels with the id: since a round can be dealt an opponent that is not a row of
	## formations.csv, the arena cannot look it up and the header would otherwise print "gen5.0".
	setup.opponent_name = session.chosen_title()
	## [B2c] the player's side is whatever the formation page left in the roster: fielded()
	## returns exactly the {piece, col, row} shape the enemy's own sheet rows have.
	setup.left = session.fielded()
	## [B8+] ...and the enemy side is the ROSTER THE ROUND ROLLED (BrawlSession.chosen_rows),
	## not the sheet's list of maybes: what the player previewed is what walks in.
	setup.right = session.chosen_rows()
	## [B7] What each piece wears rides on ITS OWN ROW of setup.left (fielded() puts "mods" there)
	## - there is no setup-wide dictionary any more (D43). The arena applies key -> value per
	## piece (BrawlActor) and never learns what an augment or a piece of equipment is.
	return setup


func _teardown_arena() -> void:
	## Taking the arena down is freeing the scene: the clock, the actors and the field go with
	## the nodes (the same rule BattleMain._teardown_board follows).
	if game == null:
		return
	var arena := _arena()
	if arena == null:
		game.brawl = null
		return
	arena.queue_free()
	game.brawl = null


func _on_bout_settled(result: Dictionary) -> void:
	## A decided bout: the session files the report (the purse lives there, and [B5] the win
	## rolls its three reward cards), the arena goes down and the round page comes back up
	## wearing its RESULT face.
	if session != null:
		session.note_result(result)
	print("")
	print("================ BRAWL RESULT: %s ================" % str(result.get("winner", "?")))
	print("arena  : %s" % str(result.get("summary", "")))
	print("=================================================")
	open_result()


func _on_arena_left(reason: String) -> void:
	## The arena asked to leave. Where that goes is the session's routing (the same shape
	## BattleMain._on_battle_left has), and every arm ends on a page.
	match reason:
		"menu", "retreat":
			leave_session()
		_:
			print("[Brawl] the arena asked to leave for an unknown reason: " + reason)
