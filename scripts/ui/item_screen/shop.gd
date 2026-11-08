class_name ShopView
extends ItemScreen
## [P22] SHOP: the one place money goes. Every entry of BalanceShop.SHOP_STOCK is a tile,
## and the detail panel on the right says what the thing does and what it costs.
##
## Money only ever comes from selling coins in the WAREHOUSE, which is why the
## subtitle repeats the balance and why an unaffordable tile is dimmed with the BUY
## button greyed out rather than hidden - the player should see what they are saving
## for. The purchase itself is Game's (it owns the profile AND the garden, and a
## plant purchase touches both).

var profile: Profile
var garden: Garden
var save: SaveLedger
var battle: Battle

func _screen_title() -> String:
	return Loc.t("shop.title")


func _screen_subtitle() -> String:
	var money := "0"
	if game != null:
		money = str(profile.money_text())
	return Loc.tf("shop.subtitle", [money])


func _screen_hint() -> String:
	return Loc.t("shop.hint")


func _read_rows() -> Array:
	if game == null:
		return []
	return shop_tiles()


func _detail_lines(p_row: Dictionary) -> Array:
	var lines: Array = []
	lines.append(Loc.tf("item.panel.price", [str(p_row.get("price_text", "-"))]))
	lines.append(Loc.tf("item.panel.owned", [str(p_row.get("owned_text", "-"))]))
	lines.append(Loc.tf("item.panel.type", [str(p_row.get("kind_label", "-"))]))
	return lines


func _action_specs() -> Array:
	var row := _find_row(_selected_id)
	if row.is_empty():
		return [{"text": Loc.t("item.panel.empty_title"), "enabled": false},
			{"text": "", "enabled": false}]
	var affordable := bool(row.get("affordable", false))
	var price := int(row.get("price", 0))
	return [{"text": Loc.tf("shop.buy", [price]), "enabled": affordable},
		{"text": "", "enabled": false}]


func _on_action(p_index: int) -> void:
	if game == null or p_index != 0:
		return
	var row := _find_row(_selected_id)
	if row.is_empty():
		return
	_report(game.buy(str(row.get("kind", "item")), str(row.get("id", ""))))


func show_shop() -> void:
	game.show_shop()


func shop_tiles() -> Array:
	## [P22] One entry per SHOP_STOCK line, in the row shape ItemGrid expects. The
	## three detail lines are built here rather than in the view, exactly like the
	## warehouse rows were: the view only prints what Game hands it.
	var rows: Array = []
	var money: int = profile.money if profile != null else 0
	for entry in BalanceShop.SHOP_STOCK:
		var row: Dictionary = entry
		var kind := str(row.get("kind", "item"))
		var id := str(row.get("id", ""))
		var price := int(row.get("price", 0))
		var is_plant := kind == "plant"
		var title := Balance.plant_name(id) if is_plant else Balance.item_name(id)
		var affordable: bool = profile != null and money >= price
		var desc := Loc.t("shop.detail.plant") if is_plant else Balance.item_hint(id)
		rows.append({
			"id": id,
			"kind": kind,
			"title": title,
			"art": Balance.plant_art(id) if is_plant else Balance.item_art(id),
			"badge": str(price),
			"note": "" if affordable else Loc.t("shop.too_expensive"),
			"dimmed": not affordable,
			"badge_color": BalanceUI.COLOR_MONEY if affordable else BalanceUI.COLOR_TEXT_DIM,
			"desc": desc,
			"price": price,
			"price_text": str(price),
			"owned_text": _shop_owned_text(id, kind),
			"kind_label": Balance.item_kind_label("plant" if is_plant else Balance.item_kind(id)),
			"affordable": affordable,
		})
	return rows


func _shop_owned_text(p_id: String, p_kind: String) -> String:
	## How many of this good the player already has: a plant is counted in the
	## garden (it is a roster entry, not a stack), everything else in the warehouse.
	if p_kind == "plant":
		if garden == null:
			return "0"
		return str(garden.count_type(p_id))
	if profile == null:
		return "0"
	return str(profile.count_of(p_id))


func buy(kind: String, id: String) -> Dictionary:
	## [P22] Returns {ok, message} so the SHOP screen can show what happened on its
	## status line; the English line still goes to the log.
	if profile == null:
		return {"ok": false, "message": Loc.t("msg.buy.no_profile")}
	var price := _shop_price(kind, id)
	if price <= 0:
		return {"ok": false, "message": Loc.t("msg.buy.no_profile")}
	if profile.money < price:
		battle._refuse(Loc.tf("msg.shop.not_enough_money", [profile.money, price]))
		print("[Shop] refused %s: money %d < %d" % [id, profile.money, price])
		return {"ok": false, "message": Loc.tf("msg.shop.not_enough_money", [profile.money, price])}
	## What was actually spent: price is what the stock table says, but reading the
	## balance before and after keeps the message honest even if a price ever gets a
	## discount that is not reflected in the table.
	var money_before := profile.money
	if kind == "plant":
		var slot := garden.add_plant(id)
		if slot < 0:
			battle._refuse(Loc.t("msg.shop.garden_full"))
			return {"ok": false, "message": Loc.t("msg.shop.garden_full")}
		save.save_garden()
		profile.money -= price
		save.save_profile()
		print("[Shop] bought %s for %d money -> garden slot %d" % [Balance.plant_name(id), price, slot + 1])
		game.front.refresh_page()
		return {"ok": true, "message": Loc.tf("msg.buy.done_plant",
			[Balance.plant_name(id), money_before - profile.money, profile.money])}
	profile.add_item(id, 1, Profile.CONTAINER_WAREHOUSE, false)
	profile.money -= price
	save.save_profile()
	print("[Shop] bought 1 x %s for %d money" % [Balance.item_name(id), price])
	game.front.refresh_page()
	return {"ok": true, "message": Loc.tf("msg.buy.done",
		[Balance.item_name(id), money_before - profile.money, profile.money])}


func _shop_price(kind: String, id: String) -> int:
	for entry in BalanceShop.SHOP_STOCK:
		var row: Dictionary = entry
		if str(row.get("kind", "item")) == kind and str(row.get("id", "")) == id:
			return int(row.get("price", 0))
	return 0


func money_amount() -> int:
	return profile.money if profile != null else 0
