extends RefCounted
class_name RunFlow
## [P36] THE CAMPAIGN FLOW - the "adventure run (P31-A)" section that used to sit in
## game_manager.gd. The lifecycle of one campaign run: squad pick -> route map -> node
## -> node -> ... -> boss -> run end. The pointer model lives in RunState (node /
## active / visited), the graph in ChapterMap, and THIS file is the only code allowed to
## move between them. Design: README「游戏流程重构设计（P31）」.
## [P36] The state it owns is only the PAGES' scratch (the five vars below). `run` and
## `chapter` stay with the manager, exactly like `garden` and `profile`: this object is
## behaviour, not a save file.
## [P64] The one thing the campaign pages borrow from the front-end - "drop the board and
## the other screens" - is no longer a GameManager method: it is OPTIMIZATIONS C1's third
## cut, the FrontEndFlow object (`scripts/ui/front_end_flow.gd`, reached as `game.front`).
## The four RUN_* pages ride the same pipeline as the shop and the deck page, so they call
## it directly rather than through the manager's `show_*` delegates (which exist for the
## UI's BACK buttons).

var game: GameManager = null             # [P36] the autoload; set right after .new()
var garden: Garden = null

var _run_reward_options: Array = []      # the pending pick-one-of-three (reward stage 3)
var _run_end_lines: Array[String] = []   # what the run-end page shows
var _squad_pick: Array[int] = []         # the squad page's uncommitted selection
var _node_title_cache: Dictionary = {}   # level base name -> display title (per language)
var _node_effects: Array = []            # [P36] the treasure roll, made when the page opens


# ---------------------------------------------------------------- adventure run (P31-A)
func run_available() -> bool:
	## False = no loadable chapter file: the adventure entry stays greyed out.
	return game.chapter != null and game.chapter.loaded


func has_run_save() -> bool:
	## What the main menu asks before offering "继续冒险".
	if game.run != null and game.run.in_progress():
		return true
	return RunState.has_save()


func start_adventure() -> void:
	## The ADVENTURE menu button: continue when a run is waiting, else pick a squad.
	if not run_available():
		game._set_message(Loc.t("run.msg.no_chapter"))
		print("[Run] adventure refused: " + (game.chapter.summary_text() if game.chapter != null else "no chapter"))
		return
	if game.run == null:
		game.run = RunState.load_or_create()
	if game.run != null and game.run.in_progress():
		continue_run()
	else:
		begin_new_run()


func begin_new_run() -> void:
	## "NEW RUN". The old save file STAYS until the squad is confirmed: abandoning
	## the pick page must not be able to destroy a run nobody replaced yet.
	if not run_available():
		return
	_squad_pick.clear()
	show_run_squad()


func continue_run() -> void:
	if not run_available():
		return
	if game.run == null:
		game.run = RunState.load_or_create()
	if game.run == null:
		begin_new_run()
		return
	## An unfinished BATTLE stays active: the roadmap will offer nothing else, so
	## resuming after a quit walks straight back to the node that was being fought.
	show_run_map()


# ---------------------------------------------------------------- squad page
func show_run_squad() -> void:
	game.front.leave_game()
	game.screen = game.Screen.RUN_SQUAD
	if game.menu != null:
		game.menu.hide_menu()
	## [P107] the page is a SCENE: the flow brings it up (and instantiates it on the
	## first visit) instead of the campaign reaching for a handle that may be null.
	game.front.open_squad()
	Music.play(BalanceAudio.MUSIC_GARDEN)


func run_squad_limit() -> int:
	return game.chapter.squad_slots() if game.chapter != null else BalanceRun.RUN_SQUAD_SLOTS


func squad_pick_count() -> int:
	return _squad_pick.size()


func squad_rows() -> Array:
	## One row per garden plant for the squad page. `picked` marks the current
	## (uncommitted) selection; `full` tells the view a NEW pick must be refused.
	var rows: Array = []
	if game.garden == null:
		return rows
	garden.recover_garden()
	var limit := run_squad_limit()
	for s in game.garden.slots:
		var slot := int(s["slot"])
		var type_id := str(s["type"])
		var picked: bool = _squad_pick.has(slot)
		rows.append({
			"slot": slot,
			"id": str(slot),
			"title": Balance.plant_name(type_id) + " #%d" % (slot + 1),
			"art": Balance.plant_art(type_id),
			"hp_text": "%d/%d" % [int(s["hp"]), int(s["max_hp"])],
			"state": game.garden.state_of(slot),
			"picked": picked,
			"pickable": not bool(s["downed"]),
			"full": not picked and _squad_pick.size() >= limit,
		})
	return rows


func squad_toggle(p_slot: int) -> Dictionary:
	## Click one plant on the squad page: join, or leave again. A DOWNED plant may
	## not enlist (it cannot answer a summon card anyway), the cap refuses the rest.
	if game.garden == null:
		return {"ok": false, "message": Loc.t("msg.garden.not_loaded")}
	var s := game.garden.slot_at(p_slot)
	if s.is_empty():
		return {"ok": false, "message": Loc.tf("roster.no_plant", [p_slot])}
	if _squad_pick.has(p_slot):
		_squad_pick.erase(p_slot)
		return {"ok": true, "message": ""}
	if bool(s["downed"]):
		return {"ok": false, "message": Loc.t("run.msg.squad_downed")}
	if _squad_pick.size() >= run_squad_limit():
		return {"ok": false, "message": Loc.t("run.msg.squad_full")}
	_squad_pick.append(p_slot)
	return {"ok": true, "message": ""}


func confirm_run_squad() -> Dictionary:
	## SET OUT: this is the moment run.json is first written (see begin_new_run).
	if _squad_pick.is_empty():
		return {"ok": false, "message": Loc.t("run.msg.squad_empty")}
	if not run_available():
		return {"ok": false, "message": Loc.t("run.msg.no_chapter")}
	var slots: Array[int] = _squad_pick.duplicate()
	slots.sort()
	game.run = RunState.new()
	game.run.start_new(game.chapter, slots)
	game.save_run()
	_squad_pick.clear()
	_run_reward_options.clear()
	_node_title_cache.clear()
	print("[Run] new adventure started: " + game.run.summary_text())
	show_run_map()
	return {"ok": true, "message": ""}


# ---------------------------------------------------------------- roadmap page
func show_run_map() -> void:
	game.front.leave_game()
	game.screen = game.Screen.RUN_MAP
	if game.menu != null:
		game.menu.hide_menu()
	## [P107] the page is a SCENE: the flow brings it up (and instantiates it on the
	## first visit) instead of the campaign reaching for a handle that may be null.
	game.front.open_roadmap()
	Music.play(BalanceAudio.MUSIC_LEVEL_SELECT)


func run_open_choices() -> Array:
	## The node ids the roadmap may light up RIGHT NOW (RunState.choices).
	if game.run == null or game.chapter == null:
		return []
	return game.run.choices(game.chapter)


func run_map_rows() -> Array:
	## The whole chapter in draw order plus where the run stands, one row per node.
	var rows: Array = []
	if game.chapter == null or game.run == null:
		return rows
	var open := run_open_choices()
	for li in game.chapter.layers.size():
		for idv in (game.chapter.layers[li] as Array):
			var id := str(idv)
			var node: Dictionary = game.chapter.node_at(id)
			var type_id := str(node.get("type", ""))
			var show_fee: bool = ChapterMap.BATTLE_TYPES.has(type_id) and game.run.retry_attempts(id) > 0
			rows.append({
				"id": id,
				"layer": li,
				"type": type_id,
				"title": run_node_title(id),
				"done": game.run.is_completed(id),
				"open": open.has(id),
				"current": game.run.active == id,
				"fee": game.run.retry_cost(id) if show_fee else 0,
				"next": (node.get("next", []) as Array).duplicate(),
			})
	return rows


func run_node_title(id: String) -> String:
	if game.chapter == null:
		return id
	var node := game.chapter.node_at(id)
	var type_id := str(node.get("type", ""))
	match type_id:
		"battle", "boss":
			return _level_display_name(str(node.get("level", "")))
		"event":
			var title := EventDB.title(str(node.get("event", "")))
			return title if title != "" else Loc.t("run.node.event")
		_:
			return Loc.t("run.node." + type_id)


func _level_display_name(base: String) -> String:
	## The roadmap names battle nodes after their level file. Cached per language
	## because loading eight JSONs every frame would be silly (the key carries the
	## language so a live switch re-reads instead of showing a stale name).
	if base == "":
		return "-"
	var key := base + "|" + Loc.language
	if _node_title_cache.has(key):
		return str(_node_title_cache[key])
	var ld := LevelData.new()
	var title := base
	if ld.load_from_file("%s/%s.json" % [Balance.LEVEL_DIR, base]):
		title = ld.display_name()
	_node_title_cache[key] = title
	return title


# ---------------------------------------------------------------- nodes
func enter_run_node(id: String) -> bool:
	## The roadmap's only write door: a node is entered through RunState.choices()
	## and nothing else, which is what keeps a quit-and-resume honest.
	if game.run == null or game.chapter == null or not run_available():
		return false
	if not run_open_choices().has(id):
		print("[Run] refused to enter '%s': not an open choice" % id)
		return false
	var node := game.chapter.node_at(id)
	match str(node.get("type", "")):
		"battle", "boss":
			game.run.enter(id)
			game.save_run()
			_enter_run_battle(node)
		"shop":
			game.run.enter(id)
			game.save_run()
			show_run_shop()
		"event", "treasure", "rest":
			game.run.enter(id)
			game.save_run()
			show_run_node_page()
		"":
			return false
	return true


func _enter_run_battle(node: Dictionary) -> void:
	game.level_path = "%s/%s.json" % [Balance.LEVEL_DIR, str(node.get("level", ""))]
	game._run_battle = true
	_run_reward_options.clear()
	# [P32] a run battle answers with the SQUAD's own cards: the squad page already
	# is the campaign's pick, so a deck left over from the last free level must not
	# shrink the cards here - and [P34] the no-pick fall-back is only the rail's
	# width deep, which would silently cut a squad plant further down the roster.
	game.front._battle_deck = _squad_deck()
	game.screen = game.Screen.GAME
	if game.menu != null:
		game.menu.hide_menu()
	game.front.hide_views()
	game.front.set_world_visible(true)
	print("---------- run battle: %s (node %s) ----------"
		% [str(node.get("level", "")), str(node.get("id", ""))])
	game._start_new_game()


func _squad_deck() -> Array[String]:
	## [P34] The campaign's deck, read off its squad: every plant TYPE standing in a
	## squad slot, in roster order (run.squad is a sorted list of GARDEN SLOTS, and
	## plant_cards() order keeps the same deck across retries and language switches).
	## A spirit card rides along with the squad plant it copies (it summons no garden
	## instance, so the squad says nothing about it either way - and the un-picked
	## battle used to hand it over as part of the whole roster).
	## A squad holds at most RUN_SQUAD_SLOTS plants, so this always fits the rail.
	var out: Array[String] = []
	if game.garden == null or game.run == null:
		return out
	for entry in Balance.plant_cards():
		var key := str(entry)
		var wanted := Balance.spirit_base(key)
		if wanted == "":
			wanted = key
		for slot in game.run.squad:
			var plant: Dictionary = game.garden.slot_at(int(slot))
			if not plant.is_empty() and str(plant["type"]) == wanted:
				out.append(key)
				break
	return out


func show_run_shop() -> void:
	## The shop node BORROWS the real shop screen (global stock for P31-A; per-node
	## stock is a P31-B item). Its BACK button is the node exit - see
	## back_from_front_end() and return_to_run_map().
	game.front.leave_game()
	garden.recover_garden()
	game.screen = game.Screen.SHOP
	if game.menu != null:
		game.menu.hide_menu()
	if game.shop_view != null:
		game.shop_view.open_view()
	Music.play(BalanceAudio.MUSIC_MENU)


func return_to_run_map() -> void:
	## Walking out of a node that ends by leaving (the shop). A battle is ended by
	## its result panel and a node page by its pick, so those stay untouched here.
	if game.run == null or game.chapter == null:
		game.show_main_menu()
		return
	if game.run.active != "" and str(game.chapter.node_at(game.run.active).get("type", "")) == "shop":
		_complete_run_node()
	if game.run != null and not game.run.finished:
		show_run_map()


func _complete_run_node() -> void:
	## The ONE place that advances the pointer, so "the last layer ends the run"
	## can never be forgotten by a future node type.
	if game.run == null or game.chapter == null or game.run.active == "":
		return
	var id := game.run.active
	game.run.complete(id)
	game.save_run()
	print("[Run] node %s done -> %s" % [id, game.run.summary_text()])
	if game.chapter.is_last_layer(id):
		_finish_run()


# ---------------------------------------------------------------- result panel (run)
func is_run_battle_result() -> bool:
	## The result panel asks this to swap its two buttons to the run wording.
	return game._run_battle and game.run != null and (game.battle != null and game.battle.is_finished())


func run_result_action_text() -> String:
	## The label of the panel's primary button (hud's RESTART in run battles).
	return Loc.t("run.result.claim") if game.battle.phase == game.Phase.WIN else Loc.t("run.result.retry")


func run_result_advance() -> void:
	if game.battle.phase != game.Phase.WIN:
		return
	show_run_reward()


func run_result_retry() -> void:
	## Retry in place: the fee was charged at the moment of the defeat and the
	## squad is already DOWNED - standing them up is garden business (time, water
	## buckets, fertilizer) exactly like the design's "small price" said.
	game._start_new_game()


# ---------------------------------------------------------------- rewards (three stages)
func _grant_run_base() -> void:
	## Stage 1: the fixed payout for clearing a battle node, money to the wallet
	## and exp to every squad plant (the garden ledger is NOT involved: the battle
	## already settled, this is the run paying on top).
	if game.run == null or game.chapter == null or game.profile == null:
		return
	var type_id := str(game.chapter.node_at(game.run.active).get("type", ""))
	var base: Dictionary = BalanceRun.RUN_BASE_REWARD.get(type_id, {})
	if base.is_empty():
		return
	var money := int(base.get("money", 0))
	var battle_exp := int(base.get("exp", 0))
	if money > 0:
		game.profile.money += money
		game.save_profile()
		game.run.stats["money"] = int(game.run.stats.get("money", 0)) + money
		game.battle_main.reward_lines.insert(0, Loc.tf("run.reward.money", [money]))
	if battle_exp > 0 and game.garden != null:
		for slot in game.run.squad:
			for line in game.garden.add_exp(slot, battle_exp):
				game.battle_main.reward_lines.append(line)
		game.save_garden()
		game.battle_main.reward_lines.append(Loc.tf("run.reward.exp", [battle_exp]))
	game.run.stats["wins"] = int(game.run.stats.get("wins", 0)) + 1


func _roll_run_reward_options() -> void:
	## Stage 3: three DIFFERENT candidates from the weighted pool, rolled now and
	## held until the pick page. One of them is the player's; the rest evaporate.
	_run_reward_options.clear()
	var pool: Array = BalanceRun.RUN_CHOICE_POOL
	if pool.is_empty():
		return
	var total := 0
	for entry in pool:
		total += maxi(1, int((entry as Dictionary).get("weight", 1)))
	var used: Dictionary = {}
	var guard := 0
	while _run_reward_options.size() < BalanceRun.RUN_CHOICE_ROLLS and used.size() < pool.size():
		guard += 1
		if guard > 64:
			break
		var roll := randi() % maxi(1, total)
		for i in pool.size():
			var entry: Dictionary = pool[i]
			var w: int = maxi(1, int(entry.get("weight", 1)))
			if roll < w:
				var sig := str(entry.get("kind", "")) + str(entry.get("amount", "")) + str(entry.get("id", ""))
				if not used.has(sig):
					used[sig] = true
					_run_reward_options.append(entry.duplicate())
				break
			roll -= w


func run_reward_options() -> Array:
	## The pick page's display rows: [{text, kind}].
	var out: Array = []
	for entry in _run_reward_options:
		var opt: Dictionary = entry
		if str(opt.get("kind", "")) == "money":
			out.append({"kind": "money", "text": Loc.tf("run.reward.money", [int(opt.get("amount", 0))])})
		else:
			out.append({"kind": "item",
				"text": Loc.tf("run.reward.item",
					[Balance.item_name(str(opt.get("id", ""))), int(opt.get("count", 1))])})
	return out


func show_run_reward() -> void:
	if game.run == null:
		game.show_main_menu()
		return
	game.front.leave_game()
	game.screen = game.Screen.RUN_REWARD
	if game.menu != null:
		game.menu.hide_menu()
	## [P107] the page is a SCENE: the flow brings it up (and instantiates it on the
	## first visit) instead of the campaign reaching for a handle that may be null.
	game.front.open_reward()
	if game.reward_view == null:
		## [P107] the old "no view" branch, kept as the failure guard: a page that could not be
		## built must not trap the player.
		## [P31-A dev] the pick page lands later in this phase; without it the flow
		## must not trap the player - take nothing and move on.
		_run_reward_options.clear()
		_complete_run_node()
		if game.run != null and not game.run.finished:
			show_run_map()
		return
	Music.play(BalanceAudio.MUSIC_MENU)


func run_reward_pick(index: int) -> bool:
	## The pick commits: stage-1/2 were already paid, this applies stage-3 and ends
	## the node (which ends the CHAPTER - and the run - when it was the last layer).
	if game.run == null or index < 0 or index >= _run_reward_options.size():
		return false
	var opt: Dictionary = _run_reward_options[index]
	var lines: Array[String] = []
	if str(opt.get("kind", "")) == "money":
		var amount := int(opt.get("amount", 0))
		if amount > 0 and game.profile != null:
			game.profile.money += amount
			game.save_profile()
			game.run.stats["money"] = int(game.run.stats.get("money", 0)) + amount
			lines.append(Loc.tf("run.effect.gain_money", [amount]))
	else:
		var id := str(opt.get("id", ""))
		var n := maxi(1, int(opt.get("count", 1)))
		if Balance.is_item(id):
			game.run.pouch_add(id, n)
			lines.append(Loc.tf("run.reward.item", [Balance.item_name(id), n]))
	_run_reward_options.clear()
	for line in lines:
		print("[Run] reward picked: " + line)
	_complete_run_node()
	if game.run != null and not game.run.finished:
		game._set_message(Loc.t("run.msg.node_done"))
		show_run_map()
	return true


# ---------------------------------------------------------------- defeat (retry in place)
func _apply_run_defeat() -> void:
	## The "small price": the wallet pays the escalating fee RIGHT here (the retry
	## button itself is then free), and every standing squad plant goes DOWNED.
	if game.run == null or game.chapter == null or game.run.active == "":
		return
	var id := game.run.active
	var fee := game.run.note_defeat(id)
	var paid := 0
	if game.profile != null and fee > 0:
		paid = mini(game.profile.money, fee)
		if paid > 0:
			game.profile.money -= paid
			game.save_profile()
	game.run.stats["money"] = int(game.run.stats.get("money", 0)) - paid
	game.run.stats["losses"] = int(game.run.stats.get("losses", 0)) + 1
	var downed := _force_squad_downed()
	game.battle_main.reward_lines.append(Loc.tf("run.defeat.fee", [paid, fee]))
	print("[Run] defeat at %s: paid %d of %d, %d squad plant(s) went DOWN" % [id, paid, fee, downed])
	game.save_run()


func _force_squad_downed() -> int:
	## Writes DOWNED onto every standing squad plant through the live slot dicts
	## (the same shape apply_results uses - downed always means hp == 0).
	if game.garden == null or game.run == null:
		return 0
	var n := 0
	for slot in game.run.squad:
		var s := game.garden.slot_at(slot)
		if s.is_empty() or bool(s["downed"]):
			continue
		s["hp"] = 0
		s["downed"] = true
		s["downed_at"] = Garden.now_unix()
		n += 1
	if n > 0:
		game.save_garden()
	return n


# ---------------------------------------------------------------- node pages (event / treasure / rest)
func show_run_node_page() -> void:
	game.front.leave_game()
	game.screen = game.Screen.RUN_NODE
	## [P36] The treasure roll is made ONCE, here. The page re-reads its options on
	## every refresh (and the pick reads them again), so rolling inside
	## run_choice_options() means the chest the player SEES is not the chest they
	## OPEN - the reward page already has the rule this copies.
	_node_effects = _roll_treasure_effects() if run_screen_kind() == "treasure" else []
	if game.menu != null:
		game.menu.hide_menu()
	## [P107] the page is a SCENE: the flow brings it up (and instantiates it on the
	## first visit) instead of the campaign reaching for a handle that may be null.
	game.front.open_choice()
	if game.choice_view == null:
		## [P107] the old "no view" branch, kept as the failure guard: a page that could not be
		## built must not trap the player.
		## [P31-A dev] same rule as the reward page: no view, no trap - pass the
		## node without taking anything (its effects are a bonus, not a gate).
		_complete_run_node()
		if game.run != null and not game.run.finished:
			show_run_map()
		return
	Music.play(BalanceAudio.MUSIC_MENU)


func run_screen_kind() -> String:
	## What the generic choice page is currently showing. "end" is the run-end
	## summary - the same view serves it, so the flow has one screen less.
	if game.screen == game.Screen.RUN_END:
		return "end"
	if game.screen != game.Screen.RUN_NODE or game.run == null or game.chapter == null or game.run.active == "":
		return ""
	var type_id := str(game.chapter.node_at(game.run.active).get("type", ""))
	if type_id == "event" or type_id == "treasure" or type_id == "rest":
		return type_id
	return ""


func run_choice_title() -> String:
	var kind := run_screen_kind()
	match kind:
		"event":
			var title := EventDB.title(str(game.chapter.node_at(game.run.active).get("event", "")))
			return title if title != "" else Loc.t("run.node.event")
		"treasure":
			return Loc.t("run.node.treasure")
		"rest":
			return Loc.t("run.node.rest")
		"end":
			return Loc.t("run.end.title")
	return ""


func run_choice_body() -> Array[String]:
	var out: Array[String] = []
	match run_screen_kind():
		"event":
			var text := EventDB.text(str(game.chapter.node_at(game.run.active).get("event", "")))
			if text != "":
				out.append(text)
		"treasure":
			out.append(Loc.t("run.treasure.text"))
		"rest":
			out.append(Loc.t("run.rest.text"))
		"end":
			for line in _run_end_lines:
				out.append(line)
	return out


func run_choice_options() -> Array:
	## [{text, enabled, effects:[...]}] - the buttons of the node page. The effects
	## arrays speak the EventDB mini-language, so ONE applier serves every node.
	var out: Array = []
	match run_screen_kind():
		"end":
			out.append({"text": Loc.t("run.end.close"), "enabled": true, "effects": []})
		"event":
			var eid := str(game.chapter.node_at(game.run.active).get("event", ""))
			for i in EventDB.option_count(eid):
				var effects: Array = EventDB.option_effects(eid, i)
				out.append({"text": EventDB.option_text(eid, i),
					"enabled": _run_can_afford(effects), "effects": effects})
		"treasure":
			out.append({"text": Loc.t("run.treasure.open"), "enabled": true,
				"effects": _node_effects.duplicate()})
		"rest":
			out.append({"text": Loc.t("run.rest.heal"), "enabled": _squad_has_downed(),
				"effects": [{"kind": "heal", "all": false}]})
			var patrol: Dictionary = BalanceRun.RUN_REST_PATROL_MOD
			out.append({"text": Loc.tf("run.rest.patrol",
				[int(patrol["left"]), int(round((float(patrol["value"]) - 1.0) * 100.0))]),
				"enabled": true,
				"effects": [{"kind": "mod", "key": str(patrol["key"]),
					"value": float(patrol["value"]), "left": int(patrol["left"])}]})
			out.append({"text": Loc.tf("run.rest.camp", [BalanceRun.RUN_REST_CAMP_MONEY]),
				"enabled": true,
				"effects": [{"kind": "money", "amount": BalanceRun.RUN_REST_CAMP_MONEY}]})
	return out


func run_choice_pick(index: int) -> bool:
	## The node page's answer button: apply the option, then the node is DONE.
	var kind := run_screen_kind()
	if kind == "":
		return false
	var options := run_choice_options()
	if index < 0 or index >= options.size():
		return false
	var opt: Dictionary = options[index]
	if not bool(opt.get("enabled", false)):
		return false
	if kind == "end":
		_close_run_end()
		return true
	var lines := apply_run_effects(opt.get("effects", []))
	if lines.is_empty():
		lines.append(Loc.t("run.treasure.empty") if kind == "treasure"
			else Loc.t("run.msg.node_done"))
	for line in lines:
		print("[Run] node: " + line)
	var msg: PackedStringArray = []
	for line in lines:
		msg.append(line)
	game._set_message("; ".join(msg))
	_node_effects.clear()      ## [P36] the chest is spent, whatever the page showed
	_complete_run_node()
	if game.run != null and not game.run.finished:
		show_run_map()
	return true


# ---------------------------------------------------------------- effect mini-language
func apply_run_effects(p_effects: Array) -> Array[String]:
	## Executes money / item / plant / heal / mod / down (grammar: EventDB header
	## comment). Shared by event, treasure and rest, so a new node type needs no
	## new applier - only new data.
	var lines: Array[String] = []
	if game.run == null:
		return lines
	var garden_touched := false
	for entry in p_effects:
		var eff: Dictionary = entry
		match str(eff.get("kind", "")):
			"money":
				var amount := int(eff.get("amount", 0))
				if game.profile == null or amount == 0:
					continue
				if amount < 0:
					amount = -mini(game.profile.money, -amount)
				game.profile.money += amount
				game.save_profile()
				game.run.stats["money"] = int(game.run.stats.get("money", 0)) + amount
				lines.append(Loc.tf("run.effect.gain_money", [amount]) if amount >= 0
					else Loc.tf("run.effect.lose_money", [-amount]))
			"item":
				var id := str(eff.get("id", ""))
				var n := maxi(1, int(eff.get("count", 1)))
				if Balance.is_item(id):
					game.run.pouch_add(id, n)
					lines.append(Loc.tf("run.reward.item", [Balance.item_name(id), n]))
			"plant":
				var pid := str(eff.get("id", ""))
				if game.garden == null or not PlantDB.has(pid):
					continue
				var slot := game.garden.add_plant(pid)
				if slot >= 0:
					garden_touched = true
					lines.append(Loc.tf("run.effect.plant", [Balance.plant_name(pid), slot + 1]))
				else:
					lines.append(Loc.t("msg.shop.garden_full"))
			"heal":
				var healed := _squad_heal(bool(eff.get("all", false)))
				if not healed.is_empty():
					garden_touched = true
				for line in healed:
					lines.append(line)
			"mod":
				var key := str(eff.get("key", ""))
				var value := float(eff.get("value", 1.0))
				var left := maxi(0, int(eff.get("left", 0)))
				game.run.add_mod(key, value, left)
				lines.append(Loc.tf("run.effect.mod", [key, str(value)]))
			"down":
				var line := _squad_down(str(eff.get("id", "")))
				if line != "":
					garden_touched = true
					lines.append(line)
	if garden_touched and game.garden != null:
		game.save_garden()
	return lines


func _roll_treasure_effects() -> Array:
	## Independent rolls, same shape as a level's `rewards` but paying into the
	## pouch. Empty is a legal (and humbling) outcome.
	## [P36] ONE caller: show_run_node_page(). What the page then holds is what the
	## pick pays out.
	var out: Array = []
	for entry in BalanceRun.RUN_TREASURE_ROLLS:
		var roll: Dictionary = entry
		if randf() < float(roll.get("chance", 0.0)):
			out.append({"kind": "item", "id": str(roll.get("id", "")),
				"count": int(roll.get("count", 1))})
	return out


func _run_can_afford(p_effects: Array) -> bool:
	## A buy option is only tappable when the WALLET can carry its whole cost -
	## the pouch never pays, the single shared money does.
	var cost := 0
	for entry in p_effects:
		var eff: Dictionary = entry
		if str(eff.get("kind", "")) == "money":
			var amount := int(eff.get("amount", 0))
			if amount < 0:
				cost += -amount
	var wallet: int = game.profile.money if game.profile != null else 0
	return wallet >= cost


func _squad_heal(p_all: bool) -> Array[String]:
	## Cure DOWNED squad members: the first one, or every one. The garden file is
	## saved by the caller (apply_run_effects) exactly once.
	var lines: Array[String] = []
	if game.garden == null or game.run == null:
		return lines
	for slot in game.run.squad:
		var s := game.garden.slot_at(slot)
		if s.is_empty() or not bool(s["downed"]):
			continue
		s["downed"] = false
		s["downed_at"] = 0
		s["hp"] = int(s["max_hp"])
		lines.append(Loc.tf("run.effect.heal", [Balance.plant_name(str(s["type"]))]))
		if not p_all:
			break
	return lines


func _squad_down(p_plant_id: String) -> String:
	## The FIRST standing squad member growing this plant goes DOWNED - an event's
	## "someone got hurt" outcome. "" when the squad has none (silently legal).
	if game.garden == null or game.run == null:
		return ""
	for slot in game.run.squad:
		var s := game.garden.slot_at(slot)
		if s.is_empty() or str(s["type"]) != p_plant_id or bool(s["downed"]):
			continue
		s["hp"] = 0
		s["downed"] = true
		s["downed_at"] = Garden.now_unix()
		return Loc.tf("run.effect.down", [Balance.plant_name(p_plant_id)])
	return ""


func _squad_has_downed() -> bool:
	if game.garden == null or game.run == null:
		return false
	for slot in game.run.squad:
		var s := game.garden.slot_at(slot)
		if not s.is_empty() and bool(s["downed"]):
			return true
	return false


# ---------------------------------------------------------------- run end
func _finish_run() -> void:
	## The last layer was cleared: freeze the run's story on the end page. The
	## pouch is merged (and the save deleted) only when that page closes, so the
	## player can read what they found before it joins the warehouse.
	if game.run == null:
		return
	game.run.finished = true
	game.save_run()
	_run_end_lines.clear()
	_run_end_lines.append(Loc.tf("run.end.stats", [
		int(game.run.stats.get("wins", 0)), int(game.run.stats.get("losses", 0)),
		int(game.run.stats.get("nodes", 0)), int(game.run.stats.get("money", 0))]))
	if not game.run.pouch_is_empty():
		_run_end_lines.append(Loc.tf("run.end.pouch", [game.run.pouch_text()]))
	print("[Run] === chapter cleared: " + game.run.summary_text() + " ===")
	show_run_end()


func show_run_end() -> void:
	game.front.leave_game()
	game.screen = game.Screen.RUN_END
	if game.menu != null:
		game.menu.hide_menu()
	if game.choice_view != null:
		game.choice_view.open_view()
	else:
		_close_run_end()
		return
	Music.play(BalanceAudio.MUSIC_MENU)


func _close_run_end() -> void:
	## The run's LAST write: pouch -> warehouse, run.json away, back to the menu.
	if game.run != null and game.profile != null and not game.run.pouch_is_empty():
		for id in game.run.pouch.keys():
			var key := str(id)
			game.profile.add_item(key, int(game.run.pouch[key]), Profile.CONTAINER_WAREHOUSE, false)
		game.save_profile()
		print("[Run] pouch merged into the warehouse: " + game.run.pouch_text())
	RunState.clear_save()
	game.run = null
	_run_reward_options.clear()
	game.show_main_menu()


# ---------------------------------------------------------------- page scratch (P36)
func clear_page_state() -> void:
	## [P36] Every page-level scratch the run owns, in one place, so 清档 cannot half
	## reset. run.json is not touched: only _close_run_end ends a run.
	_squad_pick.clear()
	_run_reward_options.clear()
	_run_end_lines.clear()
	_node_title_cache.clear()
	_node_effects.clear()
