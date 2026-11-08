extends RefCounted
class_name SelfChecks
## [P35/P85] THE STARTUP PROBES - dispatch only, since P85.
##
## P35 moved these probes out of `game_manager.gd` (they had ZERO callers outside it); P85
## split the 2987-line result by DOMAIN into `scripts/checks/`. What is left here is the
## thing that must not move: THE ORDER. `run_battle_probes` is a contract (the sequence of
## sixteen stages), and a contract reads best as one visible list.
##
## Everything else is a one-line forward. `class_name SelfChecks` stays because
## `game_manager.gd` calls it at boot and at level start, and this batch changed no caller.
##
## The rule the whole family keeps: a probe exercises the REAL paths (`spawn_unit`,
## `try_place_at`, `_use_tool_at`), every print is ONE physical line, and the expected
## numbers are read from the sheets rather than re-typed as literals.

const BootChecks := preload("res://scripts/checks/boot_checks.gd")


static func run_battle_probes(game: GameManager) -> void:
	## The sixteen probes a level start runs, in the order game_manager used to call them
	## ([P39] added the one-shot family's behaviour probe next to the ultimates, because
	## the two read the same board state and the same restore discipline; [P49] added the
	## lobbers right after them for the same reason - a splash is the same kind of claim
	## a 3x3 blast makes about the cells around a unit; [P55] added the refusal funnel
	## right after the ones that arm things, because it is the negative image of all of
	## them: same gates, same entries, only ever the answer "no"; [P58] added the ring
	## directly after the lobbers, since a box of eight cells is the same claim with the
	## plant at its centre instead of at its edge; [P61] added the loot right after the
	## zombie probe, because a drop is what a death is WORTH and nothing else reads it;
	## [P63] added the spike right after the fear, since both ask the ZOMBIE's decision
	## instead of the plant's aim - and because a stab happens outside the plant's own slot,
	## nothing but a probe that runs it by hand can tell an AP price that is spent from one
	## that only sits in the sheet).
	## [P35] The order is part of the contract: the targeting/stack probes only need a
	## grid, the tool/card/spirit ones rewrite battle state and put it back, and the
	## language one goes last because it really switches the language twice.
	## [P35] Those probes exercise the REAL summon and tool paths, which means they
	## write into `profile` and `garden`. Each one restores what it touched, but a
	## GDScript error does not throw - it returns from the function - so a probe that
	## dies half way never reaches its own restore block and leaves dirty data in RAM
	## for the next save_to_disk() to flush. Hence the transaction: snapshot, run,
	## report, restore. The snapshot is taken AFTER the level is loaded and BEFORE any
	## probe runs, so nothing here changes what a clean run would have printed.
	var prof_json: String = game.profile.to_json_text()
	var garden_json: String = game.garden.to_json_text()
	var prof_snap: Dictionary = game.profile.snapshot()
	var garden_snap: Array[Dictionary] = game.garden.snapshot()
	_close_transaction(game, prof_json, garden_json, prof_snap, garden_snap)


static func _close_transaction(game: GameManager, p_prof_json: String, p_garden_json: String,
	p_prof_snap: Dictionary, p_garden_snap: Array[Dictionary]) -> void:
	## [P35] The verdict compares to_json_text() rather than the field lists on purpose:
	## that method sorts by Balance.ITEM_ORDER and prints only what reaches the disk, so
	## two equal strings mean "the player owns exactly what they owned before" without
	## this file having to keep its own copy of the schema. The restore is unconditional
	## - a probe that left data behind is exactly the case this exists to cover, and its
	## own verdict lines were already printed by the probes above.
	var prof_ok: bool = game.profile.to_json_text() == p_prof_json
	var garden_ok: bool = game.garden.to_json_text() == p_garden_json
	print("[SelfCheck] the player's save data survives the probes = %s | %s"
		% [str(prof_ok and garden_ok), "OK" if (prof_ok and garden_ok) else "FAIL"])
	if not (prof_ok and garden_ok):
		print("[SelfCheck]   which side drifted: profile = %s, garden = %s" % [prof_ok, garden_ok])
	game.profile.restore(p_prof_snap)
	game.garden.restore(p_garden_snap)
	## [P95] AND THE DISK. A probe that walks a real door (claim_first_clear(), which pays a
	## chest, or open_plant_chest(), which writes the roster) SAVES the real files as it goes,
	## so restoring memory alone is half a transaction: quitting right here would leave the
	## probe's payload on disk and the player's clean data only in RAM. Writing the restored
	## state back is what makes the two agree again.
	game.save_profile()
	game.save_garden()


# ---------------------------------------------------------------- boot-time forwarding
# One line each: the readers (`game_manager.gd`) and the prints stay exactly as P35-P84
# had them, so the boot log is unchanged by the split.


static func self_check() -> void:
	BootChecks.self_check()


static func persist(game: GameManager) -> void:
	BootChecks.persist(game)


static func recover(game: GameManager) -> void:
	BootChecks.recover(game)


static func item_rows(game: GameManager) -> void:
	BootChecks.item_rows(game)
