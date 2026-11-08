extends RefCounted
## [P61] WHAT A BATTLE PAYS OUT - the loot a dying zombie leaves behind (P14) and the
## rewards a cleared level hands out (P14/P15/P31-B), which used to sit in the middle of
## `game_manager.gd`. This is the second cut of OPTIMIZATIONS C1 (the god object); the
## first two, `SelfChecks` (P35) and `RunFlow` (P36), moved OTHER kinds of code out and
## left this cluster as the audit named it: "奖励/掉落结算".
##
## DELIBERATELY WITHOUT `class_name`, and DELIBERATELY static (like `SafeIO` P37 and
## `Sfx` P50, unlike `RunFlow`): a brand-new global class is invisible to
## `godot --headless` until the editor rescans the project (HANDOFF §7.67), and the whole
## point of an extraction is that the headless run can prove it. Consumers preload this
## file under the same local name: `const Rewards := preload("res://scripts/core/rewards.gd")`.
## Static also means there is no instance to keep in step with the battle - see below for
## where the state actually lives.
##
## What did NOT move (until P109): THE STATE. P35/P36 left the ledgers on GameManager
## because they are read by code that is not loot at all. [P109] split that up by OWNER:
## `_pending_deaths` / `_drops_enabled` are BATTLE's fields (this file already reaches them
## through the `battle` argument), `_reward_lines` is BattleMain's (the settle pipeline
## fills it and the result panel prints it), and only `_backpack_lines` still lives on
## Game - it is written by `_settle_garden`, which is session business, not battle
## business. Every line below is reached through the typed `game`, exactly like the UI
## and the probes do.
##
## Two rules this file owns, worth knowing before editing either function:
##   * a drop goes to the BACKPACK, a reward to the WAREHOUSE - the backpack only exists
##     during a battle and is merged when it settles (`Profile.merge_backpack_into_warehouse`),
##     which is why a spectator watching an AI battle still collects loot;
##   * a snow goblin's diamond is its IDENTITY, not luck (BALANCE.md 8.2 "先结算专属掉落,
##     如果专属触发，不再结算通用掉落"), which is why `data/drops.csv` marks that row 专属
##     (P83) and `DropDB.has_exclusive()` short-circuits the ordinary rows rather than
##     adding to them. The table, not this file, now says which rows exist.
##
## `mark_cleared` / `save_to_disk` are called HERE rather than by the caller on purpose:
## [P31-B] the grants land after `_settle_garden()` already saved, and a reward that is
## never re-saved is a reward a player loses by closing the result panel (that is how the
## Lawn 1-4 spirit scroll vanished). The save belongs with the thing it protects.


## [P83] THE DROP TABLE, by PATH - and it has to be declared HERE even though
## `game_manager.gd` declares the very same const: a GDScript `const` lives in ONE
## script's scope, so a second script using it must preload it again (that is the whole
## reason this file is written without `class_name`, like `SafeIO` and `DropDB` itself).
const DropDB := preload("res://scripts/core/db/drop_db.gd")
## [P87] the item factory, by PATH for the same reason (see its header).
const Spawn := preload("res://scripts/core/spawn.gd")

static var _drops_enabled: bool = true

static func roll_drop(game: GameManager, battle: Battle, unit: Unit) -> void:
	## [P83] The TABLE says what this zombie may leave behind (`data/drops.csv`); this
	## function only rolls it and reports. Three rules survive from P14 unchanged:
	##   * a drop goes to the BACKPACK, which is merged into the warehouse when the battle
	##     settles - and it is rolled even when the player is only watching, because a drop
	##     is the zombie's doing, not the player's;
	##   * the rows are INDEPENDENT rolls, so two things can land on one death;
	##   * an EXCLUSIVE row (the snow goblin's diamond is its identity, not luck) REPLACES
	##     the ordinary rolls instead of adding to them - BALANCE 8.2.
	## [P76] The popups used to be wrapped in `if game.grid != null:` purely to keep
	## `add_child` off a dead parent. Effects now enter through the Fx layer, which answers
	## that question itself, so the loot rule reads as a loot rule.
	if not _drops_enabled or game.profile == null:
		return
	var zombie := unit as Zombie
	var type_id := "" if zombie == null else zombie.zombie_type
	var exclusive: bool = DropDB.has_exclusive(type_id)
	for entry in DropDB.entries_for(type_id):
		## An exclusive type rolls only its exclusive rows, and an ordinary type skips them:
		## the two kinds never meet on the same death.
		if bool(entry.get("exclusive", false)) != exclusive:
			continue
		if not exclusive and randf() >= float(entry.get("chance", 0.0)):
			continue
		_pay_drop(game, battle, unit, entry)


static func _pay_drop(game: GameManager, battle: Battle, unit: Unit, p_entry: Dictionary) -> void:
	## One landed row: the item into the backpack, a line into the battle log (English,
	## name included - see DropDB.LABEL) and the float-up text the player sees.
	var item_id := str(p_entry.get("item", ""))
	if item_id == "":
		return
	var n := maxi(1, int(p_entry.get("count", 1)))
	## [P87] through the item factory, which reports what LANDED (a cap or a profile that
	## refuses the id can swallow part of it; the log must not claim what did not arrive).
	var made := Spawn.create_items(game.profile, item_id, n, Spawn.WHERE_BACKPACK,
		Spawn.SOURCE_ZOMBIE_DEATH, unit.position, 0, battle)
	battle._pending_deaths.append("[Drop] %s dropped %d %s -> backpack"
		% [unit.tag(), int(made["landed"]), DropDB.label(item_id)])
	var popup := DropDB.popup(item_id)
	var loc_key := str(popup.get("loc", ""))
	Fx.spawn_popup(unit.position + Vector2(0.0, float(popup.get("dy", 0.0))),
		Loc.t(loc_key, Balance.item_name(item_id)), popup.get("color", BalanceUI.COLOR_TEXT))


static func grant(game: GameManager, battle: Battle) -> void:
	## [P14/P15] Called once, on a WIN. Every reward entry is a SEPARATE probability
	## roll (the designer asked for that explicitly): a level with a 100% coin entry
	## and a 25% plant entry can hand out both, either, or neither of the last two.
	## Everything goes to the warehouse - a battle is over, so the backpack rule does
	## not apply - and every line is remembered for the result panel.
	game.battle_main.reward_lines.clear()
	game._backpack_lines.clear()
	if game.profile == null:
		return
	var level_id : String= game.level_path.get_file().get_basename()
	var first_clear := SettingsStore.mark_cleared(level_id)
	## [P93] THE FIRST CLEAR NO LONGER PAYS HERE. It leaves a CHEST beside the level on the
	## level list, and the player opens it by clicking (Rewards.claim_first_clear) - so a
	## level can be won long before its reward is taken, and "cleared" and "paid" became
	## two different facts (SettingsStore.cleared / claimed). The panel says where it went
	## instead of listing items the warehouse has not been given yet.
	if first_clear and not battle.level.first_clear_items.is_empty():
		game.battle_main.reward_lines.append(Loc.t("panel.reward.first_clear_pending"))
	for entry in battle.level.rewards:
		var roll: Dictionary = entry
		var chance := float(roll.get("chance", 1.0))
		if randf() >= chance:
			if chance < 1.0:
				game.battle_main.reward_lines.append(Loc.tf("panel.reward.no_luck", [chance * 100.0, describe_roll(roll)]))
			continue
		var items: Dictionary = roll.get("items", {})
		for id in items.keys():
			var key := str(id)
			var n := int(items[key])
			Spawn.create_items(game.profile, key, n, Spawn.WHERE_WAREHOUSE, Spawn.SOURCE_LEVEL_CLEAR)
			game.battle_main.reward_lines.append(Loc.tf("panel.reward.item", [n, Balance.item_name(key), roll_tag(chance)]))
		var plant_id := str(roll.get("plant", ""))
		if plant_id != "":
			var slot := game.garden.add_plant(plant_id)
			if slot >= 0:
				game.battle_main.reward_lines.append(Loc.tf("panel.reward.plant", [Balance.plant_name(plant_id), slot + 1, roll_tag(chance)]))
			else:
				game.battle_main.reward_lines.append(Loc.tf("panel.reward.garden_full", [Balance.plant_name(plant_id)]))
	if game.battle_main.reward_lines.is_empty():
		game.battle_main.reward_lines.append(Loc.t("panel.reward.nothing"))
	## [P31-B] The grants land AFTER _settle_garden() already saved the profile and
	## the roster (it runs first in _end_game, so a plant that died in this battle
	## still goes DOWNED before the reward). Without this save the rewards lived
	## only in memory: quitting from the result panel ate them - that is how the
	## Lawn 1-4 spirit scroll vanished (and it ate coin / potion / plant rolls too).
	if game.profile != null:
		game.save_profile()
	if game.garden != null:
		game.save_garden()
	print("[Reward] --- level cleared: " + battle.level.level_name + " ---")
	for line in game.battle_main.reward_lines:
		print("[Reward] " + line)


static func claim_first_clear(game: GameManager, p_path: String) -> Array[String]:
	## [P93] OPEN THE CHEST. Called from the level list when the player clicks a closed one;
	## returns the lines to show (a refusal is a line too, so the caller has one code path).
	##
	## Three rules, and each one is a fact about a DIFFERENT map: the level must have been
	## CLEARED (SettingsStore.cleared), the chest must not have been opened (claimed), and
	## the payout itself is the level file's own `first_clear` map - read here rather than
	## handed in by the page, so a claim works without any page being open.
	var out: Array[String] = []
	if game == null or game.profile == null:
		return out
	var level_id := p_path.get_file().get_basename()
	if not SettingsStore.is_cleared(level_id):
		out.append(Loc.t("msg.chest.not_cleared"))
		return out
	if SettingsStore.is_claimed(level_id):
		out.append(Loc.t("msg.chest.already"))
		return out
	var data := LevelData.new()
	if not data.load_from_file(p_path):
		out.append(Loc.tf("msg.chest.broken", [level_id]))
		return out
	## Marked BEFORE the payout, on purpose: a crash between the two must lose the items
	## rather than hand them out twice on the next click.
	SettingsStore.mark_claimed(level_id)
	## [P95] The PLANT half travels as an ITEM now: the chest pays a 植物宝箱 (the sheet row
	## names the plant) and opening THAT in the warehouse is what puts the plant in the
	## garden (Game.open_plant_chest). So a claim no longer needs garden room at the moment
	## it is made - the plant waits in the warehouse until the player has a pot for it,
	## which is what 24 plant-granting chests need (a full garden used to eat the reward).
	if data.first_clear_plant != "":
		var chest := Balance.plant_chest_item_for(data.first_clear_plant)
		if chest != "":
			var packed := Spawn.create_items(game.profile, chest, 1, Spawn.WHERE_WAREHOUSE,
				Spawn.SOURCE_LEVEL_CLEAR)
			if int(packed.get("landed", 0)) > 0:
				out.append(Loc.tf("panel.reward.first_clear",
					[int(packed["landed"]), Balance.item_name(chest)]))
		else:
			## No chest row for this plant (a level whose file names a plant the sheet does
			## not pack yet): grant it the P94 way rather than swallow a promised reward.
			## The [Items] probe sweeps all 24 levels, so this branch is the safety net and
			## not the road - a missing row is reported there, not here.
			var slot: int = game.garden.add_plant(data.first_clear_plant) if game.garden != null else -1
			if slot >= 0:
				out.append(Loc.tf("panel.reward.plant", [Balance.plant_name(data.first_clear_plant),
					slot + 1, ""]))
			else:
				out.append(Loc.tf("panel.reward.garden_full",
					[Balance.plant_name(data.first_clear_plant)]))
	for id in data.first_clear_items.keys():
		var key := str(id)
		var n := int(data.first_clear_items[key])
		var made := Spawn.create_items(game.profile, key, n, Spawn.WHERE_WAREHOUSE,
			Spawn.SOURCE_LEVEL_CLEAR)
		if int(made.get("landed", 0)) > 0:
			out.append(Loc.tf("panel.reward.first_clear", [int(made["landed"]), Balance.item_name(key)]))
	if out.is_empty():
		out.append(Loc.t("msg.chest.empty"))
	game.save_profile()
	print("[Reward] --- first-clear chest opened: %s ---" % level_id)
	for line in out:
		print("[Reward] " + line)
	return out


static func roll_tag(p_chance: float) -> String:
	## [P61] PUBLIC now, and the reason it is: the suffix is the only place a player is
	## told "this line was a chance, not a promise", so the probes can assert it without
	## rolling one. A guaranteed roll says nothing (an empty tag), which is what keeps the
	## 100% reward lines readable.
	if p_chance >= 1.0:
		return ""
	return Loc.tf("panel.reward.roll_tag", [p_chance * 100.0])


static func describe_roll(p_roll: Dictionary) -> String:
	## [P61] What a missed roll WOULD have paid, for the "no luck" line. The plant wins
	## over the items on purpose: an entry that summons something is remembered by what
	## it grows, not by the coins riding with it.
	if str(p_roll.get("plant", "")) != "":
		return Balance.plant_name(str(p_roll["plant"]))
	var items: Dictionary = p_roll.get("items", {})
	for id in items.keys():
		return Balance.item_name(str(id))
	return Loc.t("panel.reward.generic")


static func self_check(game: GameManager) -> void:
	## [P61] The part of this file a headless run CAN see. Two kinds of claim are here on
	## purpose, and neither one is a copy of a number:
	##   * the two rules that are pure vocabulary (what a chance looks like in a line, and
	##     what a missed roll is named by) - the loot itself needs a battle and is asserted
	##     at level start by `ProbeEconomy._rewards` (P85 split the probes by domain);
	##   * the STRUCTURE: that the manager no longer owns these rules. A cut that leaves a
	##     private copy behind is invisible to every other probe (the copy still compiles,
	##     and nothing calls it until someone reaches for `_roll_drop` again), so the only
	##     way to lose this batch is to not check it. P57's lesson reversed: a green that
	##     would also be green with a stale copy in the file is not evidence.
	## The `[Reward]` prefix is the same one `grant()` prints on a win: P52's rule is one
	## prefix per module, and both lines are the same module talking.
	var ok := true
	# 1. a guaranteed roll carries no tag at all, and a chance says which chance it was.
	var tag_ok: bool = roll_tag(1.0) == "" and roll_tag(0.25).contains("25")
	ok = ok and tag_ok
	print("[Reward] a 100%% roll is left untagged and a 25%% one carries its own number ('%s') = %s | %s"
		% [roll_tag(0.25), str(tag_ok), "OK" if tag_ok else "FAIL"])
	# 2. what a missed roll is named by: the plant beats the coins, coins beat the
	#    generic word, and an empty entry still produces a sentence rather than nothing.
	var both := {"plant": "peashooter", "items": {"coin_gold": 1}}
	var only_items := {"items": {"coin_gold": 1}}
	var desc_ok: bool = describe_roll(both) == Balance.plant_name("peashooter") \
		and describe_roll(only_items) == Balance.item_name("coin_gold") \
		and describe_roll({}) == Loc.t("panel.reward.generic")
	ok = ok and desc_ok
	print("[Reward] a missed roll is described by its plant, then its item, then the generic word = %s | %s"
		% [str(desc_ok), "OK" if desc_ok else "FAIL"])
	# 3. the door is this file's now: the manager must not still carry the rules it handed
	#    over (see the note above about a stale private copy).
	var gone_ok: bool = not game.has_method("_roll_drop") and not game.has_method("_grant_rewards") \
		and not game.has_method("_roll_tag") and not game.has_method("_describe_roll")
	ok = ok and gone_ok
	print("[Reward] game_manager.gd keeps the ledger but no longer owns a drop or a pay-out rule of its own = %s | %s"
		% [str(gone_ok), "OK" if gone_ok else "FAIL"])
	# 4. [P93] the first-clear CHEST's two maps: a level is not claimable until it has been
	#    cleared, and mark_claimed() answers true exactly once - which is what makes a second
	#    click harmless instead of a second payout. The payout itself needs real items and is
	#    asserted inside the battle transaction (ProbeEconomy._rewards restores the profile).
	var probe_id := "__chest_probe__"
	var s_cleared: bool = SettingsStore.is_cleared(probe_id)
	var s_claimed: bool = SettingsStore.is_claimed(probe_id)
	SettingsStore.cleared.erase(probe_id)
	SettingsStore.claimed.erase(probe_id)
	var not_cleared_ok: bool = not SettingsStore.is_claimed(probe_id) \
		and not claim_first_clear(game, Balance.LEVEL_DIR + probe_id + ".json").is_empty()
	SettingsStore.cleared[probe_id] = true
	var first_ok: bool = SettingsStore.mark_claimed(probe_id)
	var second_ok: bool = not SettingsStore.mark_claimed(probe_id)
	var state_ok: bool = SettingsStore.is_claimed(probe_id)
	SettingsStore.cleared.erase(probe_id)
	SettingsStore.claimed.erase(probe_id)
	if s_cleared:
		SettingsStore.cleared[probe_id] = true
	if s_claimed:
		SettingsStore.claimed[probe_id] = true
	var chest_ok: bool = not_cleared_ok and first_ok and second_ok and state_ok
	ok = ok and chest_ok
	print("[Reward] first clear leaves a chest: uncleared refuses (%s), the first claim wins (%s), the second is refused (%s) = %s | %s"
		% [str(not_cleared_ok), str(first_ok), str(second_ok), str(chest_ok),
		   "OK" if chest_ok else "FAIL"])
	print("[Reward] self-check %s" % ("PASSED" if ok else "FAILED"))
