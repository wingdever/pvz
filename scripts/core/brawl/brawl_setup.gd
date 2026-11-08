class_name BrawlSetup
extends RefCounted
## [B2b] WHAT ONE BOUT IS TOLD - the whole input of a real-time fight, in one object.
##
## BattleSetup's twin (scripts/core/battle/battle_setup.gd) for the same reason: two sides and
## a label travel as DATA, so the menu, a probe or F6 on the arena scene can each start a bout
## without knowing about the others.
##
## A side is an Array of {piece, col, row, mods}: piece is a unit id the sheets implement, col /
## row are INTEGER board cells (0-8 / 0-4) exactly as data/brawl/formation_pieces.csv writes
## them, and [B7] mods is what THAT ONE PIECE WEARS, already summed by the session
## (BrawlSession.mods_for). The arena turns a cell into a float centre - the table never speaks
## in pixels. An enemy row simply leaves mods out.
##
## [B7] THE OLD SETUP-WIDE "mods" DICTIONARY IS GONE (D43): B5 applied one dictionary to every
## piece on the player's side because an augment belonged to the whole team; B7 attaches rows to
## individual pieces, so the numbers travel on the ROW and two pieces of one side may differ.

var round_no: int = 1
var opponent: String = ""            # the formation's id: the log and the result page read it
## [B29] ...and what that opponent is CALLED. The id used to be enough because every opponent was a
## row of formations.csv and the arena could look its name up there; a GENERATED one is not, so the
## name travels in as its own fact and the arena stops reading sheets it has no business reading.
var opponent_name: String = ""
var left: Array = []                 # the player's side (D11: the left half is the player's)
var right: Array = []                # the opponent's side
## NOTE (B7): there is deliberately no "mods" field here any more. What a piece wears rides in
## its own row of left / right, so the two sides are described by the same three-or-four keys and
## the arena needs no branch to tell a rewarded piece from a plain one.


static func fixture() -> BrawlSetup:
	## THE NO-WIRING SETUP: what F6 on scenes/brawl.tscn runs, and the shape BrawlMain fills in
	## for real. The enemy comes from the FORMATION SHEET even here (so who stands on the right
	## has one owner), and an unreadable sheet leaves that side empty rather than inventing one.
	FormationDB.load_from_disk()
	var setup := BrawlSetup.new()
	## The player's side comes from a throwaway SESSION rather than from a second copy of the
	## stand-in line-up: where a session's pieces start is the session's fact.
	## The same throwaway session answers the other half of "what the player brings": what each
	## of its pieces wears, summed the way BrawlMain sums it for a real round (fielded() puts
	## "mods" on every row it answers).
	var stand_in := BrawlSession.new()
	setup.left = stand_in.fielded()
	var ids := FormationDB.ids()
	if not ids.is_empty():
		setup.opponent = ids[0]
		setup.opponent_name = FormationDB.display_name(ids[0])
		## [B8+] The fixture rolls the roster too (FormationDB's 概率 column): a scene opened on
		## its own should fight a formation the way a real round would, dice and all. Its own RNG,
		## because there is no session seed here to reproduce.
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		setup.right = FormationDB.roll_pieces(setup.opponent, rng)
	return setup
