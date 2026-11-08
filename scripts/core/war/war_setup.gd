class_name WarSetup
extends RefCounted
## [W3] WHAT ONE WAR MATCH IS TOLD - the whole input of a match, in one object.
##
## BrawlSetup's twin (scripts/core/brawl/brawl_setup.gd) for the same reason: what a side
## brings and WHERE the fight happens travel as DATA, so the formation page, a probe or F6
## on scenes/war.tscn can each start a match without knowing about the others.
##
## The shape differs from the brawl's in exactly one place: there is no right side handed
## over as a roster. [W5] wrote that the enemy was a TIMELINE the map owned; [W8] amended
## it - the enemy is a ROLDED ROUND LIST (WarWaveGen draws it from data/war/waves.csv at
## session birth), still the map's and the session's business rather than a page's, and this
## object is where both halves travel: `left` is what the deployment table committed,
## `rounds`/`round_no` say which rolled bout the arena fields next.
##
## A left-side row is {piece, col, row} - integer board cells of THIS map's grid, the same
## shape data/brawl/formation_pieces.csv writes and the arena already turns into float
## centres. No "mods" in v1: war has no gear economy, and the row shape stays a subset of
## the brawl's so _spawn_piece can take either.

const WaveGen := preload("res://scripts/core/war/war_wave_gen.gd")
## [W8] BY PATH, the batch's own alias rule: WarWaveGen is a class_name born in THIS batch
## and invisible to a headless run until the project has been rescanned (§1.4) - fixture
## below needs the roller, so it borrows the file the way war.gd borrows this one.

var map_id: String = ""            # the maps.csv id; "" = "whatever the field falls back to"
var map_name: String = ""          # the name the player is reading (B29's rule: it travels in)
var left: Array = []               # the player's side, placed by the formation page (W4)

## [W5] THE DICE SEED for the wave scheduler's 概率 rolls. One object, one seed: begin() hands
## the setup over once and R replays the SAME object, so a replay rolls the same wave and
## lands the same army - the brawl's reproduction rule (BRAWL.md §14) with the session
## taken out. Picked once at construction from the machine, never from randf() mid-battle.
## [W8] the dice it seeds moved OUT of the arena and into WarWaveGen (the roller walks the
## whole round list off THIS seed at session birth), so the sentence "one object, one seed,
## R replays the same roll" is truer than ever - the roll just happens earlier.
var roll_seed := 0

## [W8] THE ROUNDED SESSION. `rounds` is WarWaveGen's whole output - one Array per round of
## {piece, col, row} rows, the same row shape `left` carries - rolled ONCE from roll_seed and
## READ ever after: the deployment page previews rounds[round_no] before 出征, the arena
## fields exactly it when the bout opens, and every re-formation in between changes only
## `left` and `round_no`. WarMain owns the pair; these two fields are how it hands both
## across the page / arena doors without either one re-rolling behind the other's back.
var rounds: Array = []
var round_no := 0                 # the bout to fight NOW, 0-based


func _init() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	roll_seed = r.seed


static func fixture() -> WarSetup:
	## THE NO-WIRING SETUP: what F6 on scenes/war.tscn runs, and [W8] since the round list
	## became something a SESSION must know before its first page opens, the skeleton WarMain
	## starts a session with too. The map comes from the MAP SHEET even here (so which board
	## stands has one owner), and an unreadable sheet leaves the arena to its own fallback
	## rather than inventing one.
	## [W8] The round list is rolled AT BIRTH, off this object's own seed: the F6 harness
	## then gets a real enemy marching across an army-less field (the outcome rule's
	## `left.is_empty()` exemption is what keeps that picture from ever calling itself a
	## loss), and a wired session gets the scouted army the deployment page previews.
	## The player's side is still empty by design: the deployment page is what fills it.
	var setup := WarSetup.new()
	var ids := WarDB.map_ids()
	if not ids.is_empty():
		setup.map_id = ids[0]
		setup.map_name = WarDB.display_name(setup.map_id)
	if setup.map_id != "":
		var rng := RandomNumberGenerator.new()
		rng.seed = setup.roll_seed
		setup.rounds = WaveGen.roll(rng, setup.map_id)
	return setup


static func from_placement(p_map_id: String, p_rows: Array) -> WarSetup:
	## [W4] THE COMMITTED SETUP: what the deployment table hands over when 出征 is pressed.
	## THE PAGE'S RULES ARE RE-CHECKED HERE, not trusted: the arena would field an off-board
	## cell as a body standing in the wall and a duplicate as two bodies on one cell, and the
	## page enforces both only as long as the page is the way in. A row that fails is dropped
	## (the sheet-reading rule everywhere else: a shorter army is playable, a false cell is
	## not) - so this door is the match's last line of defence, not a second opinion.
	var setup := WarSetup.new()
	setup.map_id = p_map_id if WarDB.has_map(p_map_id) else BalanceWar.WAR_DEFAULT_MAP
	if not WarDB.has_map(setup.map_id):
		var ids := WarDB.map_ids()
		setup.map_id = ids[0] if not ids.is_empty() else ""
	if setup.map_id == "":
		return setup
	setup.map_name = WarDB.display_name(setup.map_id)
	var cols := WarDB.cols_of(setup.map_id)
	var rows := WarDB.rows_of(setup.map_id)
	var taken := {}
	for entry in p_rows:
		var row := entry as Dictionary
		if row == null:
			continue
		var piece := str(row.get("piece", ""))
		var col := int(row.get("col", -1))
		var row_y := int(row.get("row", -1))
		if piece == "" or col < 0 or col >= cols or row_y < 0 or row_y >= rows:
			continue
		var cell := Vector2i(col, row_y)
		if taken.has(cell):
			continue
		taken[cell] = true
		setup.left.append({"piece": piece, "col": col, "row": row_y})
	return setup


# ---------------------------------------------------------------- the rounds [W8]
func round_total() -> int:
	return rounds.size()


func current_round() -> Array:
	## The ONE bout this match fields: round `round_no` of the session's rolled list. An
	## index outside the list answers [] - "no enemy this bout" - which the arena reads the
	## same way the F6 fixture always has: nothing marches, nothing is decided (the fixture
	## setup never rolls at all, its rounds stay empty by construction).
	if round_no < 0 or round_no >= rounds.size():
		return []
	return rounds[round_no] as Array
