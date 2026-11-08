class_name BrawlSession
extends RefCounted
## [B2b] ONE SESSION OF THE BRAWL - the thing that outlives a bout.
##
## Arenas come and go (BrawlMain puts one up per round and frees it when it is decided); the
## SESSION is what stays: the round counter, the purse, and the three offers the round is
## decided among. D17 says it is never written to a disk, so "start a session" and "start
## over" are the same door and closing the game costs nothing but the run itself.
##
## [B5 / B26] WHAT THE SESSION OWNS NOW: the roster's opening line-up (data/brawl/roster.csv
## through RosterDB), the deploy cap, the three opponents a round offers (D35), the win's reward
## cards, and the shop's shelf - which [B26] lies ON the board (over the enemy half) rather than on
## a page of its own, so the shelf is a fact of the ROUND while "which screen shows it" stopped
## being one.
##
## [B7] ...AND THE ATTACHMENTS (挂件): every piece carries up to BalanceBrawl.ATTACH_SLOTS rows
## it WEARS (pool[i]["attach"]) and the ones nobody wears yet wait in the BAG (bag). That is the
## whole difference between B5 and B7 on this object: an augment used to be a property of the
## SESSION (one list, summed once for the whole side); [D43] it is now a property of ONE PIECE,
## which is why augment_mods() became mods_for(index) and why fielded() puts numbers on each row
## instead of on the setup. The two code
## fixtures B2c shipped with (STANDIN_POOL / STANDIN_ROWS) are gone: a session's pieces are a
## sheet now, and so is everything the shelf sells.
##
## [B29] ...AND THE OFFERS ARE NO LONGER ALL THE SHEET'S. Each round deals GEN_OFFERS opponents the
## formation sheet never wrote (BrawlFormationGen, built up to the ROUND's power floor) beside the
## window's own, and a written roster gets reinforcements on the cells its author left free until it
## reaches ITS OWN floor - the 战力 it rolled plus 100 a round (BalanceBrawl.POWER_PER_ROUND, the
## user's "预设敌阵每回合增长100战力总值水平"). Two floors, one slope: the generated fight grows from
## a base nobody authored, the authored one grows from the row's own size.
## Both kinds ride in `offers` as the SAME shape - {kind, id, rows, gen, coins}
## - so nothing downstream had to learn that a second kind of opponent exists; the two doors that name
## and price one (offer_title / offer_coins) are the only places the difference is answered.
##
## THE SEED IS THE SESSION'S, and the RNG is an instance: the brawl never calls randf(), so a
## session can be reproduced from its seed alone (BRAWL.md §14).

var round_no := 1
## [B5] The purse opens at BalanceBrawl.START_COINS (not 0: the shelf is on the FIRST round's page,
## and a shop nobody can afford on the first look is a dead column). Wins add the
## opponent's 金币 row (D4); buying spends it (D33).
var coins := BalanceBrawl.START_COINS
## [D35 / B26 / B29] the three OPPONENTS this round offers, each {kind, id, rows, gen, coins}: kind is
## BalanceBrawl.EVENT_BATTLE, id is a formation id OR - since [B29] - a generated opponent's own
## "gen7.1", and gen says which. rows is the shape both kinds share (FormationDB's own
## {piece, col, row, chance}) and coins is what a win pays, which a generated opponent has to be told
## because it has no 金币 column. The CHOICE is an INDEX into this
## array, made on the formation page (the page that also shows the board and the enemy half),
## which is why there is no phase flag here: a page knows which face it is showing, a session
## only knows what is on the table. [B26] A row used to be able to say "shop" instead of naming a
## formation; the shelf lies on this same page's board now, so a round always has an opponent.
## -1 = nothing picked yet.
var offers: Array = []
var chosen := -1
var last: Dictionary = {}              # the arena's own report, kept for the result face
var seed := 0
## [B5] THE WIN'S THREE CARDS, rolled when a won bout settles and emptied when one is taken.
## {kind, id, amount} - the same shape the shop's rows have minus the price.
var reward_cards: Array = []
## [B5] THE SHOPPING: one stock per round, rolled with the offers ({kind, id, price, sold}),
## so the shelf cannot change between walking in and walking back out.
var shop_stock: Array = []
## [B7] THE BAG (背包): every attachment won or bought and NOT yet put on a piece, as
## {kind, id} in the order it arrived. ONE list for both kinds - an augment and a piece of
## equipment are the same object to everything downstream (BRAWL.md §8.6.3), and "what have I
## not worn yet" is one question, not two. It has NO capacity (O38): an attachment takes neither
## a board cell nor a bench slot, so there is no second "it does not fit" answer to give.
var bag: Array = []
## [B2c] THE ROSTER: every piece the player owns, each one either FIELDED (col >= 0) or in
## reserve (col < 0). ONE array, because "which pieces do I have" and "which of them are on the
## board" are one question with two answers - a piece that is fielded must not also be lying in
## a pool somewhere, and the formation page edits exactly this.
var pool: Array = []
## [D16] how many of them may be fielded at once. Grows with a reward (B5); the page shows it.
var deploy_cap := BalanceBrawl.DEPLOY_CAP_START

var _rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	seed = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system())
	_rng.seed = seed
	pool = opening_pool()
	roll_offers()


# ---------------------------------------------------------------- the roster
# [B5+] A PIECE IS IN EXACTLY ONE PLACE, and the two fields that say which are mutually
# exclusive: col/row >= 0 means it stands on the board (and its "slot" is -1), slot >= 0 means
# it waits in the bench (and its col/row are -1). Every door below writes BOTH halves in one
# place (_seat / _bench_seat), so the two can never disagree - which is what lets the page draw
# the bench as nine fixed slots and trust it.
func opening_pool() -> Array:
	## WHAT A SESSION STARTS WITH: data/brawl/roster.csv (RosterDB) in sheet order. A row the
	## sheet PLACES starts on the board (up to the opening cap, D16); every other row takes a
	## bench slot in sheet order. A roster sheet that names more pieces than the furniture holds
	## (cap + BENCH_SLOTS) has its overflow DROPPED here and said out loud: a piece with no cell
	## and no slot would be invisible and unreachable, which is worse than a bossy log line.
	var out: Array = []
	var placed := 0
	var dropped := 0
	for entry in RosterDB.opening_pool():
		var row := (entry as Dictionary).duplicate()
		var col := int(row.get("col", -1))
		var r := int(row.get("row", -1))
		## [B7] Every piece starts wearing nothing. A sheet that wants an opening piece - or an
		## enemy - to already wear something needs a column on roster.csv; today the only ways an
		## attachment arrives are a reward card and a shelf row.
		row["attach"] = []
		if col >= 0 and r >= 0 and placed < deploy_cap:
			row["slot"] = -1
			placed += 1
		else:
			row["col"] = -1
			row["row"] = -1
			row["slot"] = _free_slot_in(out)
			if int(row["slot"]) < 0:
				dropped += 1
				continue
		out.append(row)
	if dropped > 0:
		print("[Brawl] the roster sheet names %d piece(s) more than a session can hold (%d on the board + %d in the bench) - dropped"
			% [dropped, deploy_cap, BalanceBrawl.BENCH_SLOTS])
	return out


static func _free_slot_in(p_entries: Array) -> int:
	## The lowest bench slot nobody in this (half-built) roster sits in.
	for slot in BalanceBrawl.BENCH_SLOTS:
		var taken := false
		for entry in p_entries:
			if int((entry as Dictionary).get("slot", -1)) == slot:
				taken = true
				break
		if not taken:
			return slot
	return -1


func free_bench_slot() -> int:
	## The lowest EMPTY bench slot, or -1 when the bench is full (which is a real answer: nine
	## slots is capacity, and a full bench refuses a piece).
	for slot in BalanceBrawl.BENCH_SLOTS:
		if bench_piece_at_slot(slot) < 0:
			return slot
	return -1


func bench_piece_at_slot(p_slot: int) -> int:
	## Which roster entry waits in a bench slot, or -1. The mirror of index_at_cell().
	for i in pool.size():
		if int((pool[i] as Dictionary).get("slot", -1)) == p_slot:
			return i
	return -1


func reserve_count() -> int:
	var n := 0
	for entry in pool:
		if int((entry as Dictionary).get("slot", -1)) >= 0:
			n += 1
	return n


func can_hold_more() -> bool:
	return free_bench_slot() >= 0


func add_piece(p_piece: String) -> bool:
	## A reward or a purchase: a NEW piece, and it lands in the BENCH - where it stands is the
	## player's call and the formation page is where it is made. Duplicates are legal on purpose:
	## two copies of one id are two pieces, and the page has to be able to tell them apart.
	## FALSE WHEN THE BENCH IS FULL: the piece has nowhere to be (a reward roll and the shop both
	## ask can_hold_more() first, so this is the second line of defence, not the first).
	if p_piece == "":
		return false
	var slot := free_bench_slot()
	if slot < 0:
		return false
	pool.append({"piece": p_piece, "col": -1, "row": -1, "slot": slot, "attach": []})
	return true


func add_gear(p_kind: String, p_id: String) -> bool:
	## A reward card or a purchase: a NEW attachment, and it lands in the BAG - where it ends up
	## is the player's call and the formation page is where it is made (D44: acquiring is not
	## equipping). False when the id is not a row of that kind, which is the ONLY way this can be
	## refused: the bag never fills up (O38).
	if p_id == "" or not GearDB.has(p_id) or GearDB.kind(p_id) != p_kind:
		return false
	bag.append({"kind": p_kind, "id": p_id})
	return true


func raise_cap(p_amount: int = BalanceBrawl.DEPLOY_CAP_STEP) -> int:
	## What a cap reward or a shop rung does. Answers how much the cap ACTUALLY rose, so a
	## card taken at the ceiling can report "nothing" instead of pretending it paid.
	var before := deploy_cap
	deploy_cap = mini(deploy_cap + maxi(0, p_amount), BalanceBrawl.DEPLOY_CAP_MAX)
	return deploy_cap - before


func mods_for(p_index: int) -> Dictionary:
	## [B7] THE ONE PLACE what a piece wears becomes numbers for the fight: key -> summed value,
	## keys from BalanceBrawl.EFFECT_KEYS. BrawlSetup carries the result ON THAT PIECE'S ROW and
	## BrawlActor applies it, so neither the arena nor a page ever walks an attachment list.
	## (B5's augment_mods() summed the player's whole list for the whole side; D43 moved the sum
	## onto one piece, which is why this takes an index.)
	var out: Dictionary = {}
	for gear in attach_slots(p_index):
		var id := str((gear as Dictionary).get("id", ""))
		var key := GearDB.effect(id)
		if key == "":
			continue
		out[key] = float(out.get(key, 0.0)) + GearDB.value(id)
	return out


# ---------------------------------------------------------------- the attachments (挂件) [B7]
# A PIECE WEARS AT MOST BalanceBrawl.ATTACH_SLOTS ROWS, and the array is ALWAYS CONTIGUOUS: a
# removal shifts the rest down. That is why "the first free slot" is simply its size, and why no
# code anywhere has to go looking for a hole - slots are CAPACITY, not positions.
func attach_slots(p_index: int) -> Array:
	## What ONE piece wears, in slot order: at most BalanceBrawl.ATTACH_SLOTS {kind, id} rows.
	## Empty for an index that is not a piece, so both readers below may ask without checking.
	if p_index < 0 or p_index >= pool.size():
		return []
	return (pool[p_index] as Dictionary).get("attach", []) as Array


func bag_gear(p_index: int) -> Dictionary:
	## The attachment waiting in one bag position, or {} - the page draws the bag by index.
	if p_index < 0 or p_index >= bag.size():
		return {}
	return bag[p_index] as Dictionary


func free_slot_in(p_index: int) -> int:
	## The first empty slot of a piece, or -1 when it already wears three things. The page asks
	## this to know whether a drop can land at all, so "why can I not put this here" is answered
	## by the same rule equip() enforces instead of by a second copy of it in the drawing code.
	var worn := attach_slots(p_index)
	if worn.size() >= BalanceBrawl.ATTACH_SLOTS:
		return -1
	return worn.size()


func equip(p_piece: int, p_bag_index: int) -> bool:
	## THE DROP DOOR, bag -> piece: the attachment leaves the bag and lands in the first free
	## slot. WHICH square of the piece the pointer was over does not matter while the piece has
	## room - slots fill in order, so the answer is the same either way. A FULL piece is REFUSED
	## rather than shuffled (O37): three rows have nowhere to shuffle TO.
	if p_bag_index < 0 or p_bag_index >= bag.size():
		return false
	if free_slot_in(p_piece) < 0:
		return false
	attach_slots(p_piece).append(bag[p_bag_index])
	bag.remove_at(p_bag_index)
	return true


func unequip(p_piece: int, p_slot: int) -> bool:
	## OFF THE PIECE AND BACK IN THE BAG (O36: an attachment is never locked on). This is a PvE
	## ladder with no opponent to punish a rethink, and a mis-drop would otherwise cost a whole
	## session - so a rethink is free, and the remaining rows shift down (see the note above).
	if p_piece < 0 or p_piece >= pool.size():
		return false
	var worn := attach_slots(p_piece)
	if p_slot < 0 or p_slot >= worn.size():
		return false
	bag.append(worn[p_slot])
	worn.remove_at(p_slot)
	return true


func move_attach(p_from_piece: int, p_from_slot: int, p_to_piece: int, p_to_slot: int = -1) -> bool:
	## THE SECOND DROP DOOR, piece -> piece:
	##   the target has room            -> it lands in the first free slot;
	##   the target is FULL, slot named -> the two SWAP, the only way to rearrange a full piece;
	##   the target is FULL, none named -> refused (O37).
	## Dropping a row back onto its own piece is TRUE and does nothing: not an error, and the
	## page should not have to special-case it.
	if p_from_piece < 0 or p_from_piece >= pool.size():
		return false
	if p_to_piece < 0 or p_to_piece >= pool.size():
		return false
	var from := attach_slots(p_from_piece)
	if p_from_slot < 0 or p_from_slot >= from.size():
		return false
	if p_from_piece == p_to_piece:
		return true
	var to := attach_slots(p_to_piece)
	if to.size() < BalanceBrawl.ATTACH_SLOTS:
		to.append(from[p_from_slot])
		from.remove_at(p_from_slot)
		return true
	if p_to_slot < 0 or p_to_slot >= to.size():
		return false
	var carried = from[p_from_slot]
	from[p_from_slot] = to[p_to_slot]
	to[p_to_slot] = carried
	return true


func attachment_report() -> String:
	## "attachments: militia <- iron_sword, leather_armor | archer <- sharp_blade (bag 2)" - one
	## line saying which piece wears what and how much is still waiting. BrawlMain prints it once
	## per bout because the ARENA only ever sees numbers: AGENTS §2 forbids test scripts, so this
	## line is how the manual pass answers "did the drop actually reach the fight".
	var parts := PackedStringArray()
	for i in pool.size():
		var worn := attach_slots(i)
		if worn.is_empty():
			continue
		var ids := PackedStringArray()
		for gear in worn:
			ids.append(str((gear as Dictionary).get("id", "")))
		parts.append("%s <- %s" % [str((pool[i] as Dictionary).get("piece", "")), ", ".join(ids)])
	var line := "attachments: " + ("none" if parts.is_empty() else " | ".join(parts))
	if not bag.is_empty():
		line += " (bag %d)" % bag.size()
	return line



func dismiss(p_index: int) -> bool:
	## [B15] 遣散: ONE OWNED PIECE LEAVES THE SESSION FOR GOOD, whether it was standing on the
	## board or waiting in the bench. It is the answer to O47 that D71 left open - and it is
	## deliberately NOT a sale: NOTHING IS PAID BACK (see the guard and the note below), because
	## a piece won as a reward and sold at the shop's price would be a coin faucet. A refund is
	## the half of O47 nobody has asked for yet: the day it is asked for, it is one line HERE.
	##
	## WHAT IT WEARS COMES BACK FIRST (O36): an attachment is never locked on, so the rows go
	## back to the bag BEFORE the piece goes. A piece that walked away wearing three of them
	## would take them out of the session for good, which is the one way this could lose value
	## silently. The bag has no capacity (O38), so there is no room to check.
	##
	## THE LAST PIECE IS REFUSED: a roster with nothing in it has nothing to field, and the arena
	## decides a bout with an empty half on the spot - every later round would be an instant loss
	## with no piece left to fix it with. The page says so in words (brawl.form.dismiss_last),
	## because a button that is simply dead gives the player no reason.
	if p_index < 0 or p_index >= pool.size():
		return false
	if pool.size() <= 1:
		return false
	var piece := str((pool[p_index] as Dictionary).get("piece", ""))
	var worn := attach_slots(p_index).size()
	for gear in attach_slots(p_index):
		bag.append(gear)
	pool.remove_at(p_index)
	## English, like every log line: the id and the counts, so a reader can reconstruct the
	## roster without the language layer (AGENTS.md §3).
	print("[Brawl] dismissed %s (wearing %d) - %d piece(s) left, bag %d"
		% [piece, worn, pool.size(), bag.size()])
	return true


func fielded() -> Array:
	## What the next bout fields, in roster order - exactly the shape
	## data/brawl/formation_pieces.csv uses for the other side, so a BrawlSetup carries two of
	## the same thing and the arena cannot tell which one is the player.
	var out: Array = []
	for i in pool.size():
		var row := pool[i] as Dictionary
		var col := int(row.get("col", -1))
		var r := int(row.get("row", -1))
		if col >= 0 and r >= 0:
			## [B7] "mods" is what THIS piece wears, summed here so the arena needs no branch to
			## tell a rewarded piece from a plain one (D43).
			out.append({"piece": str(row.get("piece", "")), "col": col, "row": r,
				"mods": mods_for(i)})
	return out


func fielded_count() -> int:
	var n := 0
	for entry in pool:
		if int((entry as Dictionary).get("col", -1)) >= 0:
			n += 1
	return n


func can_field_more() -> bool:
	return fielded_count() < deploy_cap


func index_at_cell(p_col: int, p_row: int) -> int:
	## Which roster entry stands on a cell, or -1. The page asks this to know whether a click on
	## the board is a PLACEMENT or a PICK-UP.
	for i in pool.size():
		var row := pool[i] as Dictionary
		if int(row.get("col", -1)) == p_col and int(row.get("row", -1)) == p_row:
			return i
	return -1


func field_at(p_index: int, p_col: int, p_row: int) -> bool:
	## Put one owned piece on a FREE cell of the player's half. False when the index is not a
	## piece, the cell is outside the half or already taken, or the piece is coming out of the
	## bench with the cap already full - a piece that is ALREADY on the board may always move,
	## which is why the cap is only checked on the way out of the bench.
	if p_index < 0 or p_index >= pool.size():
		return false
	if not _is_home_cell(p_col, p_row):
		return false
	if index_at_cell(p_col, p_row) >= 0:
		return false
	var row := pool[p_index] as Dictionary
	if int(row.get("col", -1)) < 0 and not can_field_more():
		return false
	_seat(p_index, p_col, p_row)
	return true


func place(p_index: int, p_col: int, p_row: int) -> bool:
	## THE DROP DOOR: put a piece on a cell, and settle whoever stands there.
	##   this one came from the BENCH -> the piece on the cell takes its bench slot (a trade);
	##   this one came from the BOARD -> the two simply trade cells.
	## ONE door rather than the page doing it in two steps, because those steps need a free bench
	## slot that the steps themselves free and take.
	if p_index < 0 or p_index >= pool.size():
		return false
	if not _is_home_cell(p_col, p_row):
		return false
	var me := pool[p_index] as Dictionary
	if int(me.get("col", -1)) == p_col and int(me.get("row", -1)) == p_row:
		return true                       ## already standing there: nothing to do
	var occupant := index_at_cell(p_col, p_row)
	var from_bench: bool = int(me.get("col", -1)) < 0
	## The cap only ever stops a piece coming OUT OF THE BENCH onto a FREE cell: a trade leaves the
	## number of pieces standing on the board exactly as it was.
	if from_bench and occupant < 0 and not can_field_more():
		return false
	if occupant >= 0 and occupant != p_index:
		var other := pool[occupant] as Dictionary
		if from_bench:
			other["col"] = -1
			other["row"] = -1
			other["slot"] = int(me.get("slot", -1))
		else:
			other["col"] = int(me.get("col", -1))
			other["row"] = int(me.get("row", -1))
	_seat(p_index, p_col, p_row)
	return true


func send_to_bench(p_index: int, p_slot: int = -1) -> bool:
	## THE BENCH DOOR: take a piece off the board - or move one that is already waiting - into a
	## bench slot. p_slot < 0 means "the lowest free slot"; a named slot TRADES places with
	## whoever waits there. False when the index is not a piece, the slot is out of range, or the
	## bench has no room: nine slots is capacity, so a full bench really does refuse.
	if p_index < 0 or p_index >= pool.size():
		return false
	var me := pool[p_index] as Dictionary
	var target := p_slot
	if target < 0:
		if int(me.get("slot", -1)) >= 0:
			return true                   ## already waiting, and nobody asked for a slot
		target = free_bench_slot()
	if target < 0 or target >= BalanceBrawl.BENCH_SLOTS:
		return false
	if target == int(me.get("slot", -1)):
		return true
	return _bench_seat(p_index, target)


func reserve(p_index: int) -> bool:
	## The short spelling of send_to_bench(): off the board, into the lowest free slot.
	return send_to_bench(p_index)


func _seat(p_index: int, p_col: int, p_row: int) -> void:
	## The ONLY writer of "this piece stands on the board": the cell and the freed slot, in one
	## place, so the two halves of "where is it" can never disagree.
	var row := pool[p_index] as Dictionary
	row["col"] = p_col
	row["row"] = p_row
	row["slot"] = -1


func _bench_seat(p_index: int, p_slot: int) -> bool:
	## The ONLY writer of "this piece waits in the bench". Seat it in the slot and let whoever sits
	## there take what THIS one leaves behind - its CELL when it came off the board, its old SLOT
	## when it was already waiting. A bench is a grid of places: a slot is traded, never a shuffle
	## of everything after it.
	var me := pool[p_index] as Dictionary
	var old_col := int(me.get("col", -1))
	var old_row := int(me.get("row", -1))
	var old_slot := int(me.get("slot", -1))
	var occupant := bench_piece_at_slot(p_slot)
	me["col"] = -1
	me["row"] = -1
	me["slot"] = p_slot
	if occupant >= 0 and occupant != p_index:
		var other := pool[occupant] as Dictionary
		if old_col >= 0:
			other["col"] = old_col
			other["row"] = old_row
			other["slot"] = -1
		else:
			other["slot"] = old_slot
	return true


func is_home_cell(p_col: int, p_row: int) -> bool:
	return _is_home_cell(p_col, p_row)


static func _is_home_cell(p_col: int, p_row: int) -> bool:
	## D11's partition, the same one the arena enforces: columns 0-3 are the player's half.
	return p_col >= 0 and p_col < BalanceBrawl.HALF_COLS and p_row >= 0 and p_row < Balance.ROWS


func roll_offers() -> void:
	## [D35 / B26 / B29] A round offers three OPPONENTS. They used to be one thing: a WINDOW over the
	## formation roster that slides one row per round, which is the difficulty ramp for exactly as many
	## rounds as the sheet has rows - four today - and then parks. [B29] broke the two halves of that
	## apart: GEN_OFFERS of the three are GENERATED up to the round's power floor, the rest are still
	## the window's and are raised to their OWN floor - rolled 战力 plus 100 a round. Either way the
	## ramp is a number on the round, not an index into a file. The
	## whole list is shuffled with this session's own RNG, which keeps both promises it made before:
	## the order is not the sheet's, and a seed replays the random opponents too (BRAWL.md §14).
	##
	## THE SHELF IS ROLLED HERE and not when the page is opened: a stock that re-rolled on every
	## visit would let a player reroll the shop for free by leaving the round and coming back.
	offers.clear()
	shop_stock.clear()
	var ids := FormationDB.ids()
	var battles := maxi(BalanceBrawl.OFFER_BATTLES_MIN, BalanceBrawl.OFFER_COUNT)
	var generated := mini(BalanceBrawl.GEN_OFFERS, battles)
	var authored := battles - generated
	if ids.is_empty():
		## No sheet to walk is not no opponents. The round is generated in full, and the mode keeps
		## playing with the reason printed at boot (FormationDB.status_text() says which sheet failed);
		## this used to be where a round dealt nobody and the page could only say so.
		authored = 0
		generated = battles
	var list: Array = []
	var start := mini(round_no - 1, maxi(0, ids.size() - maxi(1, authored)))
	for i in range(start, mini(ids.size(), start + authored)):
		list.append(_battle_offer(ids[i]))
	while list.size() < authored:
		## A short roster (fewer formations than a round's authored slots) pads with the last one
		## rather than offering an empty slot - the floor OFFER_BATTLES_MIN promises.
		list.append(_battle_offer(ids[ids.size() - 1]))
	for i in generated:
		list.append(_generated_offer(i))
	_shuffle(list)
	offers = list
	roll_shop_stock()
	## A round always has an opponent SELECTED, the way it always has pieces fielded: the first
	## offer is the default, and the formation page is where a player changes it. Without this a
	## player who never touches the band would have nothing to fight.
	chosen = 0


func _battle_offer(p_formation: String) -> Dictionary:
	## [B8+] ONE BATTLE OFFER, WITH ITS ROSTER ALREADY ROLLED. A formation's sheet lists what MAY
	## stand in it (FormationDB's 概率 column), so the roll happens ONCE and early: the card the
	## player reads, the half the formation page previews and the side the arena fields are three
	## views of this one array, and a roll taken at any of those moments separately would make the
	## preview a lie. It rides on the OFFER and not on the session because a round may offer two
	## different opponents, each with its own dice.
	## [B29] ...and the rolled roster is then RAISED TO ITS ROUND'S FLOOR, which is where "the same
	## 哨兵 in round nine" stops being the same 哨兵. For a WRITTEN row the floor is its own rolled 战力
	## plus BalanceBrawl.POWER_PER_ROUND per round past the first - the user's "预设敌阵每回合增长100
	## 战力总值水平", measured FROM the row rather than from a curve it would have to catch up to. The
	## sheet's own bodies keep their cells; the reinforcements take the cells the sheet left free.
	## The two extra keys are what a generated opponent has to carry anyway (a reward its 金币 column
	## cannot express for a roster that grew past it, and - for the random one - a name the sheet does
	## not own), so an offer is now self-describing either way and every reader asks the offer instead
	## of the sheet: see offer_title() / offer_coins().
	var rows := FormationDB.roll_pieces(p_formation, _rng)
	rows = BrawlFormationGen.top_up(_rng, rows,
		BalanceBrawl.authored_floor(FormationDB.power_total_of(rows), round_no))
	return {"kind": BalanceBrawl.EVENT_BATTLE, "id": p_formation, "rows": rows,
		"gen": false,
		"coins": maxi(FormationDB.coins(p_formation),
			BrawlFormationGen.reward(FormationDB.power_total_of(rows)))}


func _generated_offer(p_slot: int) -> Dictionary:
	## [B29] ONE OPPONENT NOBODY WROTE. The id it carries is not a row of formations.csv and never
	## will be asked of it (FormationDB answers a stranger with the stranger); it exists so the log and
	## the result line can name what happened ("gen5.0" = round 5's first generated offer). The name the
	## player sees is the drawn INDEX into the language layer's list, not a resolved string: switching
	## language mid-session must re-read the same entry in the new language, and a bout only learns its
	## opponent's title at the moment it is labelled.
	var target := BrawlFormationGen.round_target(_rng, round_no)
	var rows := BrawlFormationGen.make(_rng, target)
	return {"kind": BalanceBrawl.EVENT_BATTLE,
		"id": BalanceBrawl.GEN_ID_PREFIX + str(round_no) + "." + str(p_slot), "rows": rows,
		"gen": true, "name_index": BrawlFormationGen.name_index(_rng),
		"coins": BrawlFormationGen.reward(FormationDB.power_total_of(rows))}


func chosen_rows() -> Array:
	## [B8+] What the round's opponent actually fields - the roll above. Every reader of "who is
	## over there" goes through this door. (It used to answer [] for a SHOP round; since [B26] a
	## round always has an opponent, there is no third answer left.)
	return offer_rows(chosen)


func _shuffle(p_list: Array) -> void:
	## Fisher-Yates with THIS session's RNG. The brawl never calls randf() (BRAWL.md §14), so
	## one seed reproduces the offers, the shelf, the rewards and the bout that followed.
	for i in range(p_list.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap = p_list[i]
		p_list[i] = p_list[j]
		p_list[j] = swap


func pick(p_index: int) -> bool:
	## The opponent a round is committed to. Nothing is spent by picking: the cost of a lost round
	## is the round itself (D23).
	if p_index < 0 or p_index >= offers.size():
		return false
	chosen = p_index
	return true


func chosen_offer() -> Dictionary:
	## What the round is committed to, or {} when nothing is picked yet. The door below is what
	## every former reader of the chosen id asks now: that string used to carry two facts (which
	## event, and which formation), and only the formation is left to ask about.
	if chosen < 0 or chosen >= offers.size():
		return {}
	return offers[chosen] as Dictionary


func chosen_formation() -> String:
	## The formation this round fights, or "" when nothing has been picked - so "start a bout" has
	## one thing to check instead of two. [B26] It used to answer "" for a SHOP round as well, which
	## is why it asked the offer's kind; the kind is EVENT_BATTLE on every row now. [B29] A generated
	## opponent answers its own id (gen5.0), which is a LOG name and nothing else: it is deliberately
	## not a row of data/brawl/formations.csv, so nobody may hand it to the sheet for a name or a
	## reward. Those two questions have doors of their own now.
	var offer := chosen_offer()
	if str(offer.get("kind", "")) != BalanceBrawl.EVENT_BATTLE:
		return ""
	return str(offer.get("id", ""))


func offer_rows(p_index: int) -> Array:
	## [B29] One offer's rows, which is the shape BOTH kinds of opponent share (BrawlFormationGen
	## writes exactly what FormationDB.roll_pieces() does). The page reads a card through this instead
	## of reaching into the offer dictionary, so the offer's keys have one owner.
	return _offer_at(p_index).get("rows", []) as Array


func offer_title(p_index: int) -> String:
	## [B29] What an offer is CALLED, whichever kind it is: the sheet's own name door for a written
	## formation, the language layer's generated name for a random one. RESOLVED AT CALL TIME, not
	## stored on the offer - FormationDB.display_name() answers in the language that is live NOW, so a
	## name cached at roll time would still be in the old language after a switch. Every reader that
	## used to hand the id to FormationDB itself asks this instead, which is the one door where "is
	## this opponent in the sheet at all" stops being the reader's problem.
	var offer := _offer_at(p_index)
	if bool(offer.get("gen", false)):
		return BrawlFormationGen.title_of(int(offer.get("name_index", 0)))
	return FormationDB.display_name(str(offer.get("id", "")))


func offer_coins(p_index: int) -> int:
	## [B29] What a win over this offer pays. A written formation's 金币 column is the FLOOR it was
	## authored with, and the round's floor can lift it: an opponent reinforced to this round's power
	## is paid for at that power, or the deep rounds would be the cheap ones. A generated one has no
	## column to fall back on and is paid from its own measured 战力.
	return int(_offer_at(p_index).get("coins", 0))


func chosen_title() -> String:
	## The round's opponent, by name - what the arena's header and the result page print.
	return offer_title(chosen)


func chosen_coins() -> int:
	return offer_coins(chosen)


func _offer_at(p_index: int) -> Dictionary:
	## One index into the round's offers, {} for anything out of range - the door the four accessors
	## above share, so a stray index is a blank label rather than a crash on page repaint.
	if p_index < 0 or p_index >= offers.size():
		return {}
	return offers[p_index] as Dictionary


func note_result(p_result: Dictionary) -> void:
	## The arena's report, kept whole plus the three things only the session can add: who was
	## fought, what the win paid (D4 read through the opponent's row), and [B5] the three reward
	## cards the win opens. A loss or a draw pays nothing and opens no cards (D23) - which is
	## why the coin line and the card roll are conditioned on the same "won".
	## [B29] Both halves of "who was fought" travel: the id for the log, the TITLE for the page. The
	## result page used to take the id to FormationDB itself, which quietly assumed every opponent is
	## a row of formations.csv - a generated one is not, and its name is the language layer's.
	last = p_result.duplicate()
	var opponent := chosen_formation()
	last["opponent"] = opponent
	last["opponent_name"] = chosen_title()
	var won: bool = str(last.get("winner", "")) == BalanceBrawl.SIDE_NAMES[BalanceBrawl.SIDE_LEFT]
	last["coin_reward"] = chosen_coins() if won else 0
	coins += int(last["coin_reward"])
	reward_cards.clear()
	if won:
		roll_rewards()
	print("[Brawl] round %d vs %s (%s): %s  (+%d coin, purse %d, %d reward card(s))"
		% [round_no, opponent, chosen_title(), str(last.get("winner", "?")),
		   int(last["coin_reward"]), coins, reward_cards.size()])


func roll_rewards() -> void:
	## [B5] THE WIN'S THREE CARDS (D16's list: a piece / an augment / [B7] an equipment / the
	## deploy cap / coins). The kinds are drawn WITHOUT replacement, so the three cards are three
	## DIFFERENT kinds - the same guarantee roll_offers() gives for battles, and the reason they
	## are weights rather than chances: a hand of three coin cards would not be a choice.
	reward_cards.clear()
	var kinds: Array[String] = [BalanceBrawl.REWARD_KIND_PIECE, BalanceBrawl.REWARD_KIND_AUGMENT,
		BalanceBrawl.REWARD_KIND_EQUIPMENT, BalanceBrawl.REWARD_KIND_CAP,
		BalanceBrawl.REWARD_KIND_COINS]
	var weights: Array[int] = []
	for kind in kinds:
		weights.append(maxi(0, int(BalanceBrawl.REWARD_WEIGHTS.get(kind, 0))))
	for i in mini(BalanceBrawl.REWARD_PICKS, kinds.size()):
		var at := _weighted_index(weights)
		if at < 0:
			break
		var kind := kinds[at]
		kinds.remove_at(at)
		weights.remove_at(at)
		var card := _card_for(kind)
		if card.is_empty():
			## The kind could not be paid right now (the cap is at its ceiling, the BENCH IS FULL,
			## every augment is already owned, the sheets are empty). Try the kinds STILL ON THE
			## TABLE before falling back to coin, so a hand never shows the same card twice.
			for j in kinds.size():
				var other := _card_for(kinds[j])
				if other.is_empty():
					continue
				card = other
				kinds.remove_at(j)
				weights.remove_at(j)
				break
		if card.is_empty() and not _hand_has(BalanceBrawl.REWARD_KIND_COINS):
			card = _card_for(BalanceBrawl.REWARD_KIND_COINS)
		if not card.is_empty():
			reward_cards.append(card)


func _hand_has(p_kind: String) -> bool:
	## Whether the hand already holds a card of this kind - the guard that keeps the coin fall-back
	## from dealing a second coin card into a hand that was meant to be three DIFFERENT things.
	for card in reward_cards:
		if str((card as Dictionary).get("kind", "")) == p_kind:
			return true
	return false


func _weighted_index(p_weights: Array) -> int:
	## One index, drawn by weight, from THIS session's RNG. -1 when every weight is 0, and the
	## caller then falls back rather than inventing a card.
	var total := 0
	for w in p_weights:
		total += maxi(0, int(w))
	if total <= 0:
		return -1
	var roll := _rng.randi_range(1, total)
	for i in p_weights.size():
		roll -= maxi(0, int(p_weights[i]))
		if roll <= 0:
			return i
	return p_weights.size() - 1


func _card_for(p_kind: String) -> Dictionary:
	## One card of one kind, or {} when that kind cannot be paid right now. Which piece and
	## which attachment comes from the sheets (RosterDB / GearDB), so a reward can never offer
	## something the shop does not know how to price.
	if p_kind == BalanceBrawl.REWARD_KIND_PIECE:
		## [B5+] A piece needs somewhere to stand: with all nine bench slots taken the card cannot
		## be paid, so it is not offered (roll_rewards falls back to the coin card instead of
		## handing over a piece that would have to be refused).
		if not can_hold_more():
			return {}
		var piece := RosterDB.draw_piece(_rng)
		return {} if piece == "" else {"kind": p_kind, "id": piece, "amount": 1}
	if p_kind == BalanceBrawl.REWARD_KIND_AUGMENT or p_kind == BalanceBrawl.REWARD_KIND_EQUIPMENT:
		## [B7] Either attachment kind, drawn from its own rows of data/brawl/gear.csv. NO
		## EXCLUSION and no fall-back: the bag has no capacity (O38), and a duplicate is not a
		## dead card any more - two iron swords on two pieces (or three on one) are three real
		## rows, which is why a piece wears an ARRAY and not a set.
		var gear := GearDB.draw(_rng, [], p_kind)
		return {} if gear == "" else {"kind": p_kind, "id": gear, "amount": 1}
	if p_kind == BalanceBrawl.REWARD_KIND_CAP:
		if deploy_cap >= BalanceBrawl.DEPLOY_CAP_MAX:
			return {}
		return {"kind": p_kind, "id": "", "amount": BalanceBrawl.DEPLOY_CAP_STEP}
	if p_kind == BalanceBrawl.REWARD_KIND_COINS:
		return {"kind": p_kind, "id": "", "amount": BalanceBrawl.REWARD_COINS}
	return {}


func take_reward(p_index: int) -> bool:
	## The card the player picked: applied to the session, and the hand is emptied. False when
	## there is nothing to take, so a page can refuse to move on rather than advancing a round
	## that paid nothing.
	if p_index < 0 or p_index >= reward_cards.size():
		return false
	var card := reward_cards[p_index] as Dictionary
	var line := _grant(card)
	reward_cards.clear()
	print("[Brawl] reward taken: " + line)
	return true


func _grant(p_card: Dictionary) -> String:
	## One card, applied. THE one place a card becomes state, so the shop's purchases below go
	## through the same door with a price in front of them instead of a second copy of this.
	var kind := str(p_card.get("kind", ""))
	var id := str(p_card.get("id", ""))
	var amount := maxi(0, int(p_card.get("amount", 1)))
	if kind == BalanceBrawl.REWARD_KIND_PIECE:
		if id == "":
			return "nothing (no piece named)"
		## The refusal now has two causes, and they want different answers from the player: the
		## bench is full (field something) or the id is not a piece at all (a sheet bug).
		return ("piece " + id) if add_piece(id) else "nothing (the bench is full)"
	if kind == BalanceBrawl.REWARD_KIND_AUGMENT or kind == BalanceBrawl.REWARD_KIND_EQUIPMENT:
		## [B7] Both attachment kinds take the same door - the bag. The log line says which one
		## it was, because that is the only place the two kinds are distinguishable at all.
		return ("bag: " + id) if add_gear(kind, id) else "nothing (no such " + kind + " '" + id + "')"
	if kind == BalanceBrawl.REWARD_KIND_CAP:
		return "deploy cap +%d (now %d of %d)" % [raise_cap(amount), deploy_cap, BalanceBrawl.DEPLOY_CAP_MAX]
	if kind == BalanceBrawl.REWARD_KIND_COINS:
		coins += amount
		return "coins +%d (purse %d)" % [amount, coins]
	return "nothing (unknown kind '" + kind + "')"


func next_round() -> void:
	round_no += 1
	_clear_round()
	roll_offers()


func repick() -> void:
	## D23: a loss pays nothing but does not cost the round - the player picks another
	## opponent from what is still on the table.
	_clear_round()


# ---------------------------------------------------------------- the shelf [D33 / B26]
func roll_shop_stock() -> void:
	## [B5] THE SHELF, rolled once with the round (roll_offers) and drawn since [B26] OVER the board's
	## enemy half - the four columns a foe would stand in, not a region of the page's own.
	## Prices are the sheets' own: a piece costs its TIER times
	## PIECE_PRICE_PER_COST (RosterDB.cost_tier, which asks PieceDB for the ids PieceDB prices and
	## the roster's 档位 for the ones it cannot - [B31]'s campaign plant; [B31] a timed unit NO row
	## names, `zombie` today, takes the same floor PieceDB uses for an unstated tier, so the shelf
	## can sell a unit the brawl sheet never mentions rather than skip it), an attachment costs its
	## tier's rung (GearDB.price), and only the +1 cap rung is authored here. So a row that gets
	## dearer in its own sheet gets dearer in the shop without a second table to keep in step.
	shop_stock.clear()
	## Whatever is ALREADY on the shelf is excluded from the next draw: two identical champions
	## in one stock would waste a slot the player can see (an attachment row is held to the same
	## rule - two iron swords side by side would read as a bug, even though wearing two is legal).
	var on_shelf: Array = []
	for i in BalanceBrawl.SHOP_PIECE_SLOTS:
		var piece := RosterDB.draw_piece(_rng, on_shelf)
		if piece == "":
			continue
		on_shelf.append(piece)
		shop_stock.append({"kind": BalanceBrawl.REWARD_KIND_PIECE, "id": piece,
			"price": RosterDB.cost_tier(piece) * BalanceBrawl.PIECE_PRICE_PER_COST, "sold": false})
	for i in BalanceBrawl.SHOP_AUGMENT_SLOTS:
		var augment := GearDB.draw(_rng, on_shelf, BalanceBrawl.KIND_AUGMENT)
		if augment == "":
			continue
		on_shelf.append(augment)
		shop_stock.append({"kind": BalanceBrawl.REWARD_KIND_AUGMENT, "id": augment,
			"price": GearDB.price(augment), "sold": false})
	for i in BalanceBrawl.SHOP_EQUIPMENT_SLOTS:
		## [B7] The fifth slot (O39): one piece of equipment per shelf, priced off the same tier
		## ladder an augment uses - equipment is SMALLER than an augment of its tier, not cheaper.
		var gear := GearDB.draw(_rng, on_shelf, BalanceBrawl.KIND_EQUIPMENT)
		if gear == "":
			continue
		on_shelf.append(gear)
		shop_stock.append({"kind": BalanceBrawl.REWARD_KIND_EQUIPMENT, "id": gear,
			"price": GearDB.price(gear), "sold": false})
	for i in BalanceBrawl.SHOP_CAP_SLOTS:
		shop_stock.append({"kind": BalanceBrawl.REWARD_KIND_CAP, "id": "",
			"price": BalanceBrawl.SHOP_CAP_PRICE, "sold": false})


func stock_row(p_index: int) -> Dictionary:
	if p_index < 0 or p_index >= shop_stock.size():
		return {}
	return shop_stock[p_index] as Dictionary


func can_buy(p_index: int) -> bool:
	## The page asks this to grey a row out, so "why can I not buy it" is answered by the same
	## rules buy() enforces instead of by a second copy of them in the drawing code.
	var row := stock_row(p_index)
	if row.is_empty() or bool(row.get("sold", false)):
		return false
	if coins < int(row.get("price", 0)):
		return false
	## [B5+] ...and a piece needs a free bench slot to land in (the shelf says which of the two
	## reasons greyed the row out, so "too dear" and "no room" do not look alike).
	if str(row.get("kind", "")) == BalanceBrawl.REWARD_KIND_PIECE and not can_hold_more():
		return false
	if str(row.get("kind", "")) == BalanceBrawl.REWARD_KIND_CAP 			and deploy_cap >= BalanceBrawl.DEPLOY_CAP_MAX:
		return false
	return true


func buy(p_index: int) -> String:
	## One purchase: pay, mark the row sold, and hand the goods to the SAME door a reward goes
	## through. Answers the log line, or "" when nothing was bought - the page asks can_buy()
	## first, so a refusal here is a double click rather than a story.
	if not can_buy(p_index):
		return ""
	var row := stock_row(p_index)
	var price := int(row.get("price", 0))
	var kind := str(row.get("kind", ""))
	coins -= price
	row["sold"] = true
	var line := _grant({"kind": kind, "id": str(row.get("id", "")),
		"amount": BalanceBrawl.DEPLOY_CAP_STEP if kind == BalanceBrawl.REWARD_KIND_CAP else 1})
	print("[Brawl] bought %s for %d coin (purse %d)" % [line, price, coins])
	return line


func _clear_round() -> void:
	chosen = -1
	last = {}
	reward_cards.clear()
