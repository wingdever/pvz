class_name WarehouseView
extends ItemScreen
## [P22] WAREHOUSE: everything the player owns, one tile per item kind, with the
## detail + actions of the selected one on the right.
##
## The rules this screen only SHOWS all live elsewhere:
##   profile.gd   coins are ITEMS - selling them is the only way money ever grows
##   profile.gd   scrolls carry durability, which the tile note and the panel show
##   Game         the backpack is merged in here when a battle settles
##
## Like the garden page this file owns no game state: it asks Game for the rows, the
## money and the sale, and displays whatever comes back (HANDOFF 7.18). Clicking a
## tile never acts - it only selects; acting is what the buttons below are for.

var profile: Profile
var garden: Garden
var save: SaveLedger

func _screen_title() -> String:
	return Loc.t("warehouse.title")


func _screen_subtitle() -> String:
	var money := "0"
	if game != null:
		money = str(profile.money_text())
	return Loc.tf("warehouse.subtitle", [money])


func _screen_hint() -> String:
	return Loc.t("warehouse.hint")


func _empty_desc() -> String:
	return Loc.t("warehouse.empty")


func warehouse_lines() -> Array[String]:
	if profile == null:
		return []
	return profile.warehouse_lines()


func warehouse_tiles() -> Array:
	return profile._container_tiles(Profile.CONTAINER_WAREHOUSE)


func _read_rows() -> Array:
	if game == null:
		return []
	return warehouse_tiles()


func _detail_lines(p_row: Dictionary) -> Array:
	var lines: Array = []
	lines.append(Loc.tf("item.panel.type", [str(p_row.get("kind_label", "-"))]))
	lines.append(Loc.tf("item.panel.count", [str(p_row.get("count_text", "-"))]))
	## The third line is kind specific: what a coin is worth, how much durability a
	## scroll has left, or where the rest of them are used.
	var third_key := str(p_row.get("value_key", "item.panel.use"))
	lines.append(Loc.tf(third_key, [str(p_row.get("value_text", "-"))]))
	return lines


func _action_specs() -> Array:
	## Slot 0 sells the whole selected stack - coins only, which is exactly why the
	## button is greyed out (never hidden) for everything else: the rule stays
	## visible instead of the button silently disappearing.
	var row := _find_row(_selected_id)
	if row.is_empty():
		return [{"text": Loc.t("warehouse.empty"), "enabled": false},
			{"text": Loc.t("warehouse.sell_all"), "enabled": _has_coins()}]
	if str(row.get("kind", "")) == "coin":
		return [{"text": Loc.tf("warehouse.sell_stack", [int(row.get("stack_value", 0))]),
			"enabled": true},
			{"text": Loc.t("warehouse.sell_all"), "enabled": _has_coins()}]
	## [P95] A 植物宝箱 is the one item slot 0 OPENS instead of sells: the chest the level
	## list handed over turns back into a garden plant here, so the plant waits in the
	## warehouse until the player has a pot free (Game.open_plant_chest).
	if str(row.get("kind", "")) == Balance.ITEM_KIND_PLANT_CHEST:
		return [{"text": Loc.t("warehouse.open"), "enabled": true},
			{"text": Loc.t("warehouse.sell_all"), "enabled": _has_coins()}]
	return [{"text": Loc.t("warehouse.no_sell"), "enabled": false},
		{"text": Loc.t("warehouse.sell_all"), "enabled": _has_coins()}]


func _on_action(p_index: int) -> void:
	if game == null:
		return
	if p_index == 0:
		if _selected_id == "":
			return
		## [P95] the row decides which action slot 0 is: a chest is opened, a coin is sold
		if Balance.item_kind(_selected_id) == Balance.ITEM_KIND_PLANT_CHEST:
			_report(game.open_plant_chest(_selected_id))
			return
		_report(game.sell_warehouse_item(_selected_id))
	elif p_index == 1:
		_report(game.sell_all_coins())


func _has_coins() -> bool:
	return game != null and bool(has_sellable_coins())


func has_sellable_coins() -> bool:
	if profile == null:
		return false
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		if Balance.item_kind(key) == "coin" and profile.count_of(key) > 0:
			return true
	return false


func money_text() -> String:
	if profile == null:
		return "0"
	return profile.money_text()


func warehouse_item_count(p_item: String) -> int:
	if profile == null:
		return 0
	return profile.count_of(p_item, Profile.CONTAINER_WAREHOUSE)


func open_plant_chest(item_id: String) -> Dictionary:
	## [P95] The warehouse's OPEN action for a 植物宝箱. A cleared level hands the PLANT over
	## as this item now (see Rewards.claim_first_clear), and this is the one door that turns
	## it back into a garden plant - the reward waits in the warehouse until the player has
	## room for it, which is what a 24-plant pack needs. ORDER MATTERS: the chest is spent
	## only after the garden has accepted the plant, so a full roster can never eat one.
	if profile == null or garden == null:
		return {"ok": false, "message": Loc.t("msg.chest.none")}
	if Balance.item_kind(item_id) != Balance.ITEM_KIND_PLANT_CHEST:
		return {"ok": false, "message": Loc.t("msg.chest.none")}
	var plant_id := Balance.item_plant(item_id)
	if plant_id == "" or not Balance.PLANT_DEFS.has(plant_id):
		return {"ok": false, "message": Loc.t("msg.chest.none")}
	if not profile.has_item(item_id, 1, Profile.CONTAINER_WAREHOUSE):
		return {"ok": false, "message": Loc.t("msg.chest.none")}
	var slot := garden.add_plant(plant_id)
	if slot < 0:
		return {"ok": false, "message": Loc.tf("msg.chest.full", [Balance.plant_name(plant_id)])}
	profile.take_item(item_id, 1, Profile.CONTAINER_WAREHOUSE)
	save.save_garden()
	save.save_profile()
	print("[Chest] opened %s -> %s in garden slot %d"
		% [Balance.item_name(item_id), Balance.plant_name(plant_id), slot + 1])
	game.front.refresh_page()
	return {"ok": true, "message": Loc.tf("msg.chest.opened",
		[Balance.item_name(item_id), Balance.plant_name(plant_id), slot + 1])}


func sell_warehouse_item(item_id: String) -> Dictionary:
	## [P14] The only way money ever grows. Sells the WHOLE stack of one coin kind.
	## [P22] Returns {ok, message} for the warehouse screen's status line - the
	## message is the player's (localised); the English accounting line still goes to
	## the log through profile.sell().
	if profile == null:
		return {"ok": false, "message": Loc.t("msg.sell.none")}
	var amount: int = profile.count_of(item_id)
	if amount <= 0:
		return {"ok": false, "message": Loc.t("msg.sell.none")}
	if Balance.item_kind(item_id) != "coin":
		return {"ok": false, "message": Loc.t("msg.sell.coins_only")}
	var gain: int = profile.sell_price(item_id, amount)
	var result: Dictionary = profile.sell(item_id, amount)
	print("[Warehouse] " + str(result.get("message", "")))
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": Loc.t("msg.sell.none")}
	save.save_profile()
	game.front.refresh_page()
	return {"ok": true, "message": Loc.tf("msg.sell.done",
		[amount, Balance.item_name(item_id), gain, profile.money])}


func sell_all_coins() -> Dictionary:
	## [P22] Same contract as sell_warehouse_item(): every coin stack at once.
	if profile == null:
		return {"ok": false, "message": Loc.t("msg.sell.none")}
	var coins := 0
	var gain := 0
	for id in Balance.ITEM_ORDER:
		var key := str(id)
		var n := profile.count_of(key)
		if n <= 0 or Balance.item_kind(key) != "coin":
			continue
		coins += n
		gain += profile.sell_price(key, n)
	if coins <= 0:
		return {"ok": false, "message": Loc.t("msg.sell.none")}
	var result: Dictionary = profile.sell_all_coins()
	print("[Warehouse] " + str(result.get("message", "")))
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": Loc.t("msg.sell.none")}
	save.save_profile()
	game.front.refresh_page()
	return {"ok": true, "message": Loc.tf("msg.sell.all_done", [coins, gain, profile.money])}
