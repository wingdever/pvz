class_name BackpackView
extends ItemScreen
## [P22] BACKPACK: the main menu picture of the bag opens this page.
##
## It is the SAME container the in-battle panel shows (Profile.CONTAINER_BACKPACK),
## only read-only: outside a battle there is nothing to do with it, and the two rules
## that make that true both live in Game / Profile, not here:
##   loadout_for_battle()             a battle STARTS by moving the warehouse's
##                                    battle consumables into the backpack
##   _settle_garden()                 a battle ENDS by merging the backpack back into
##                                    the warehouse
## So on the main menu the bag is normally EMPTY, which is exactly what the empty
## state says in plain words instead of leaving the player with a blank grid.

var profile: Profile

func _screen_title() -> String:
	return Loc.t("backpack.title")


func _screen_subtitle() -> String:
	var kinds := 0
	var total := 0
	if game != null:
		kinds = int(game.backpack_kinds())
		total = int(game.backpack_total())
	return Loc.tf("backpack.subtitle", [kinds, total])


func _screen_hint() -> String:
	return Loc.t("backpack.hint")


func _empty_desc() -> String:
	return Loc.t("backpack.empty_desc")


func backpack_tiles() -> Array:
	return profile._container_tiles(Profile.CONTAINER_BACKPACK)
	
	
func _read_rows() -> Array:
	if game == null:
		return []
	return backpack_tiles()


func _detail_lines(p_row: Dictionary) -> Array:
	var lines: Array = []
	lines.append(Loc.tf("item.panel.type", [str(p_row.get("kind_label", "-"))]))
	lines.append(Loc.tf("item.panel.count", [str(p_row.get("count_text", "-"))]))
	lines.append(Loc.tf("item.panel.use", [str(p_row.get("value_text", "-"))]))
	return lines


func _action_specs() -> Array:
	## Nothing to DO here: a backpack item is used during a battle (the energy bean)
	## or in the garden (everything else). The first slot says where instead of
	## offering a button that would only refuse, the second stays empty.
	return [{"text": Loc.t("backpack.use_in_battle"), "enabled": false},
		{"text": "", "enabled": false}]
