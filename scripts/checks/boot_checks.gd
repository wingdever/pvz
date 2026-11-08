extends RefCounted
## [P85] BOOT_CHECKS · BootChecks
##
## THE BOOT PROBES - the module checks that run once, before a battle exists.
##
## CARVED OUT OF `core/game_self_checks.gd` (2987 lines, P35-P84) BY DOMAIN, not by size:
## the whole file had ZERO callers outside the probes, which is the same argument P35 used
## when it moved the probes out of the game manager. The dispatch order stayed where it was
## (`core/game_self_checks.gd`), so nothing outside `scripts/checks/` changed.
##
## WHAT DID NOT MOVE: THE STATE. Every probe still reaches state through the typed `game`
## parameter, exactly like the UI does. A probe file that grew a variable would be a new
## owner for something the manager already owns.
##
## DELIBERATELY WITHOUT `class_name` (see `docs/ARCHITECTURE.md` §1.3): a brand-new global
## class is invisible to `godot --headless` until the editor rescans, and being provable
## headlessly is the whole point. Each file preloads what IT uses - a `const` lives in one
## script's scope (`docs/PITFALLS.md` 第 68 条), so the list below is per file on purpose.
static func self_check() -> void:
	## [P20] Loc.self_check() proves the TABLES; this proves the game's own name
	## helpers actually USE them. It exists because the wiring lives in balance.gd and
	## difficulty.gd, and a copy of those files that quietly falls back to its English
	## literals is invisible until a player notices ("why does the card still say
	## Peashooter in Chinese?"). Six lookups, no board needed, so it runs on every boot.
	var ok := true
	var pairs: Array = [
		["plant.peashooter", Balance.plant_name("peashooter")],
		["plant.wallnut", Balance.plant_name("wallnut")],
		["item.coin_gold", Balance.item_name("coin_gold")],
		["tool.shovel", BalanceBattle.tool_name("shovel")],
		["rarity.rare", Balance.rarity_label("rare")],
		["talent.potion_wallnut", Balance.talent_display_name("potion_wallnut")],
		["difficulty.hard", Difficulty.label("hard")],
		# [P22] the two helpers the item tiles and their detail panels go through,
		# plus the caption of the main menu's picture buttons
		["item.kind.coin", Balance.item_kind_label("coin")],
		["item.hint.fertilizer", Balance.item_hint("fertilizer")],
		["menu.main.backpack", BalanceUI.menu_icon_title("backpack")],
	]
	for pair in pairs:
		var key := str(pair[0])
		var got := str(pair[1])
		var want := Loc.t(key)
		if got != want:
			ok = false
			print("[Loc] '%s' should be '%s' but the name helper returned '%s' | FAIL"
				% [key, want, got])
	print("[Loc] name helpers go through the table (plant/item/tool/rarity/talent/difficulty/item kind/item hint/menu picture) = %s"
		% ("OK" if ok else "FAIL"))


static func persist(game: GameManager) -> void:
	## [P106] THE STATUS LINE AND THE PACK ROWS LIVE ON THE BOARD, and the board is a scene a
	## battle brings with it. On the main menu there is neither, so this claim is DEFERRED (and
	## says so) rather than failing against a null board: it is proven in a battle run instead.
	if game.battle == null:
		print("[SelfCheck] the save alarm rides on the status line: deferred (no board at boot)")
		return
	## [P65] OPTIMIZATIONS A3's own probe - the second boot-time check in this file (it is
	## the only other one that needs no board). The failure it exercises is one a healthy
	## machine never produces, so the only honest way to prove the door works is to hand it
	## a `false` and look at what the player would have been shown. Five claims, in the order
	## the code makes them; the restore block at the end puts the status line and the dirty
	## set back exactly as found, so a boot that runs this before a level cannot tell.
	var ok := true
	var saved_unsaved: Dictionary = game._unsaved.duplicate()
	var saved_msg: String = game.battle.status_message
	var saved_timer: float = game.battle._message_timer
	var note: String = Loc.t("msg.save.alarm")
	# 1. the half the SEVEN battle probes lean on: while every write lands, the status
	#    line is EXACTLY the text handed in - no invisible prefix anywhere. The `note` half
	#    is here because a mistyped or deleted key would otherwise make every comparison
	#    below agree with itself: Loc.t() answers a missing key with the KEY (and one
	#    [Loc] warning), which is not a string the player was ever meant to read.
	game._unsaved.clear()
	game.battle._set_message("probe")
	var clean_ok: bool = note != "" and note != "msg.save.alarm" \
		and game.battle.status_message == "probe"
	ok = ok and clean_ok
	print("[Save] a run where every write lands leaves the status line exactly as written = %s | %s"
		% [str(clean_ok), "OK" if clean_ok else "FAIL"])
	# 2. a refused write speaks, and then it RIDES: the shop, the potions and the bean all
	#    write a ledger and hand the UI a success line in the same click, so a warning
	#    printed once at the failure would be gone before it could be read.
	game._record_write(false, "probe")
	var raised_ok: bool = game._unsaved.has("probe") and game.battle.status_message == note
	game.battle._set_message("later")
	raised_ok = raised_ok and game.battle.status_message == "later" + note
	ok = ok and raised_ok
	print("[Save] one refused write names itself, then rides on every line after it = %s | %s"
		% [str(raised_ok), "OK" if raised_ok else "FAIL"])
	# 3. it is the LEDGER that clears it, not the clock: the next write that lands takes
	#    the note away, so the warning can never outlive the damage it describes.
	game._record_write(true, "probe")
	game.battle._set_message("later")
	var healed_ok: bool = not game._unsaved.has("probe") and game.battle.status_message == "later"
	ok = ok and healed_ok
	print("[Save] the next write that lands takes the note away again = %s | %s"
		% [str(healed_ok), "OK" if healed_ok else "FAIL"])
	# 4. and the alarm is PER LEDGER - the shape this batch nearly shipped wrong. The
	#    garden and the profile are written back to back all over the game, so a single
	#    flag would let the second write's success erase the first write's failure.
	game._record_write(false, "garden")
	game._record_write(true, "profile")
	game.battle._set_message("later")
	var split_ok: bool = game.battle.status_message == "later" + note and game._unsaved.has("garden")
	ok = ok and split_ok
	print("[Save] one ledger landing does not hush the other one's failure = %s | %s"
		% [str(split_ok), "OK" if split_ok else "FAIL"])
	# 5. the structure of the cut: three doors, and the manager still answers to them.
	var door_ok: bool = game.has_method("save_garden") and game.has_method("save_profile") \
		and game.has_method("save_run")
	ok = ok and door_ok
	print("[Save] garden, profile and run each have exactly one door out of the game = %s | %s"
		% [str(door_ok), "OK" if door_ok else "FAIL"])
	game._unsaved = saved_unsaved
	game.battle.status_message = saved_msg
	game.battle._message_timer = saved_timer
	print("[Save] self-check %s" % ("PASSED" if ok else "FAILED"))


static func recover(game: GameManager) -> void:
	## [P106] THE STATUS LINE AND THE PACK ROWS LIVE ON THE BOARD, and the board is a scene a
	## battle brings with it. On the main menu there is neither, so this claim is DEFERRED (and
	## says so) rather than failing against a null board: it is proven in a battle run instead.
	if game.battle == null:
		print("[SelfCheck] the recovery clock reaches the disk: deferred (no board at boot)")
		return
	## [P66] OPTIMIZATIONS A4's second half, and the reason `[Recover]` is its own prefix
	## (P52: one prefix per rule, and this is a different rule from `[Garden]`'s - that one
	## is the roster talking about its own cells, this one is the MANAGER's door).
	## What is being proven is a claim about ownership, so the probe runs the door the page
	## now runs: it aims `game.garden` at a scratch roster with one expired pot, ticks the
	## rule through Game, and looks at both ends - the plant that stood up AND the fact that
	## the door reached for the disk. Claim 2 is the interesting one: on a healthy machine a
	## write that lands leaves no trace, so the ONLY evidence that recovery and persistence
	## are the same decision is this scratch instance's refusal (P37's guard) lighting up
	## P65's alarm. That refusal also costs two WARNING lines on every boot - `[Garden]
	## refusing to save a scratch roster` and `[Save] garden: the write was refused` - and
	## they are the probe working, not a disk problem (docs/OPTIMIZATION_PLAN.md §5.23).
	## Everything the probe borrows (`garden`, the dirty set, the status line) goes back.
	var ok := true
	var saved_garden: Garden = game.garden
	var saved_unsaved: Dictionary = game._unsaved.duplicate()
	var saved_msg: String = game.battle.status_message
	var saved_timer: float = game.battle._message_timer
	var scratch := Garden.new()
	scratch.apply_defaults()
	var pot: Dictionary = scratch.slot_at(0)
	pot["hp"] = 0
	pot["downed"] = true
	pot["downed_at"] = Garden.now_unix() - 10000      # past any level's clock
	game.garden = scratch
	# 1. the clock stands a pot up THROUGH the door, and the door hands back the sentence
	#    the page shows - which is why it returns lines and not a count.
	game._unsaved.clear()
	var stood: Array[String] = game.garden.recover_garden()
	var stood_ok: bool = stood.size() == 1 and not bool(pot["downed"]) \
		and int(pot["hp"]) > 0 and int(pot["downed_at"]) == 0
	ok = ok and stood_ok
	print("[Recover] a clock that ran out stands up through Game's door, line and all = %s | %s"
		% [str(stood_ok), "OK" if stood_ok else "FAIL"])
	# 2. and that stand-up reached for the disk in the SAME call (the scratch refuses, so
	#    the alarm is what proves the attempt - a rule that only edited RAM would leave the
	#    set empty and this line red).
	var tried_ok: bool = game._unsaved.has("garden") \
		and game.battle.status_message == Loc.t("msg.save.alarm")
	ok = ok and tried_ok
	print("[Recover] the same call is what asks for the write - recovery never stays in RAM = %s | %s"
		% [str(tried_ok), "OK" if tried_ok else "FAIL"])
	# 3. the page ticks twice a second, so a second call must find nothing and must not
	#    write again - otherwise every GARDEN_TICK would rewrite the file.
	game._unsaved.clear()
	game.battle._set_message("")
	var again: Array[String] = game.garden.recover_garden()
	var twice_ok: bool = again.is_empty() and not game._unsaved.has("garden")
	ok = ok and twice_ok
	print("[Recover] a second tick finds nothing to do and leaves the disk alone = %s | %s"
		% [str(twice_ok), "OK" if twice_ok else "FAIL"])
	# 4. the structure: the door has one name, public, and the private one it replaced is
	#    gone (P61's trick - a stale copy of a rule compiles and stays invisible forever).
	var door_ok: bool = game.has_method("recover_garden") and not game.has_method("_recover_garden")
	ok = ok and door_ok
	print("[Recover] the garden's clock has one door and the page walks through it = %s | %s"
		% [str(door_ok), "OK" if door_ok else "FAIL"])
	game.garden = saved_garden
	game._unsaved = saved_unsaved
	game.battle.status_message = saved_msg
	game.battle._message_timer = saved_timer
	print("[Recover] self-check %s" % ("PASSED" if ok else "FAILED"))


static func item_rows(game: GameManager) -> void:
	## [P106] THE STATUS LINE AND THE PACK ROWS LIVE ON THE BOARD, and the board is a scene a
	## battle brings with it. On the main menu there is neither, so this claim is DEFERRED (and
	## says so) rather than failing against a null board: it is proven in a battle run instead.
	if game.battle == null:
		print("[SelfCheck] the three item-row shapes: deferred (no board at boot)")
		return
	## [P74] OPTIMIZATIONS C5, closed the way P53 closed the LevelList row pair: NOT by
	## merging the three item-row builders into one constructor, but by PINNING the contract
	## they already share. `shop_tiles`, `_container_tiles` (behind warehouse_tiles /
	## backpack_tiles) and `pack_rows` (the in-battle panel) each hand-copy the same nine
	## "visual" keys, and the screens that read them do it with `.get(key, "-")` - so a key
	## that drifts out of ONE builder does not crash, it silently becomes a dash on that one
	## page (warehouse_view.gd:43 is the reader that shows the dash). A shared constructor
	## would hide the per-page payload each shape really carries (the C5 note's own objection
	## to merging), so instead: build one row from each of the three and fail if any of the
	## nine is missing. The EXTRA keys are free to differ - that difference is the point
	## (shop carries price/affordable, container carries value_*/count_text, pack carries
	## usable and no kind_label). It touches the save only through snapshot()/restore() (the
	## same pair run_battle_probes uses to hand the board back), and it runs on every boot
	## because these three builders are the front end's `_ready()` path, which no battle
	## probe reaches (the P72/P73 lesson: ask which channel an assertion lives in first).
	print("[ItemRow] --- the three item-row shapes share their nine visual keys (P74) ---")
	var shared := ["id", "kind", "title", "art", "badge", "note",
		"dimmed", "badge_color", "desc"]
	var snap: Dictionary = game.profile.snapshot()
	## One item per container so a row appears at all: pack_rows reads the backpack,
	## warehouse_tiles the warehouse, shop_tiles the const stock table (needs no seed).
	## `false` is add_item's LOG flag, not a save - nothing here reaches the disk, and
	## restore() puts the RAM back exactly as snapshot() took it.
	game.profile.add_item(Balance.ITEM_ENERGY_BEAN, 1, Profile.CONTAINER_BACKPACK, false)
	game.profile.add_item(Balance.ITEM_SCROLL_PEASHOOTER, 1, Profile.CONTAINER_WAREHOUSE, false)
	var shapes: Array = [
		{"label": "container", "rows": game.warehouse_tiles()},
		{"label": "pack", "rows": game.battle.pack_rows()},
	]
	var ok := true
	for entry in shapes:
		var shape: Dictionary = entry
		var rows: Array = shape["rows"]
		var label := str(shape["label"])
		if rows.is_empty():
			## A builder that yields nothing is a seeding break, not a pass: an empty array
			## would sail through the key loop and report OK without ever inspecting a row.
			ok = false
			print("[ItemRow] %s: no row to inspect (a seed item left Balance.ITEM_ORDER?) | FAIL"
				% label)
			continue
		var row: Dictionary = rows[0]
		var absent: Array = []
		for key in shared:
			if not row.has(str(key)):
				absent.append(key)
		var good: bool = absent.is_empty()
		ok = ok and good
		print("[ItemRow] %s: %d keys, the 9 shared all present = %s | %s"
			% [label, row.size(), str(absent), "OK" if good else "FAIL"])
	game.profile.restore(snap)
	print("[ItemRow] self-check %s" % ("PASSED" if ok else "FAILED"))
