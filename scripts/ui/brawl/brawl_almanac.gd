class_name BrawlAlmanacView
extends AlmanacView
## [D75] THE CLASSIC MODE'S OWN 图鉴 - the turn mode's page (AlmanacView), reading the classic
## mode's sheets.
##
## WHY A SUBCLASS AND NOT A SECOND PAGE. The two almanacs answer the same four questions - which
## units exist, what is this thing, what can I meet, where do I read the numbers - and the turn
## page already owns the machinery for them: the paged cell grid (ItemGrid), the detail panel with
## its own SubViewport for a unit's idle animation, the tab/race/group rows, the pure layout
## maths. Copying that would be a second owner of "how this page is laid out" (AGENTS §2's rule
## about one owner per fact). What DIFFERS is only the DATA and the WORDS, and those are exactly
## the seams the base class leaves open: _read_rows / _detail_lines / _description / the title
## functions. Everything else is inherited on purpose.
##
## WHAT IT SHOWS (BRAWL.md §10.3):
##
##   UNITS / PLANTS | ZOMBIES | HUMANS | MONSTERS | MACHINE | POKEMON | ANIMALS: the units whose
##                                       units.csv row says `timed` - i.e. the ones this mode
##                                       introduces - through UnitSheet (the one roster reader)
##                                       and, per race, the sheets that own their own numbers
##                                       (plants.csv / zombies.csv / humans.csv / monsters.csv /
##                                       machine.csv / pokemon.csv / [B39] animals.csv)
##   GEAR                                data/brawl/gear.csv through GearDB: the augments and the
##                                       equipment a piece can wear (D42-D55)
##   FORMATIONS                          data/brawl/formations.csv through FormationDB: the three
##                                       opponents a round can offer (D34's numbers)
##
## THE RACE ROW has SEVEN buttons here, not the turn page's two: the classic mode fields five
## PIECE factions (the humans of D7, then [P110f] the monsters, [B19] the machines, [B38] the
## pokemon and [B39] the animals), and the base class wires whatever the scene declares -
## _collect_and_wire below appends the ones the base does not know about, up to
## BalanceUI.ALMANAC_BRAWL_RACE_COUNT.
##
## NO LEVELS, NO ITEMS: the classic mode has no level pack (its "levels" are the formations) and
## its items are the brawl's gear, not the turn mode's data/items.csv. The base's `_levels` list
## is therefore left EMPTY and never read - refresh() below says so by not discovering it.

## The classic mode's races, in the order the race buttons stand. The first two keep the base
## class's values (its Race enum is PLANTS/ZOMBIES); the other five are this page's own, and
## their order is PieceDB.FACTIONS' order (the one table that knows what a faction is).
const RACE_PLANTS := 0
const RACE_ZOMBIES := 1
const RACE_HUMANS := 2
const RACE_MONSTERS := 3
const RACE_MACHINE := 4
## [B38] The fourth piece faction (宝可梦), and the reason the note above says "adding a faction is
## one scene node, one row and one branch": this line, three branches below and RaceButton5 are the
## whole change - the panel, the picture column and the roster list all ask _race_root() instead of
## keeping their own list.
const RACE_POKEMON := 5
## [B39] The fifth piece faction (动物), by exactly the same four moves: this line, the three
## branches below, RaceButton6 in the scene, and ALMANAC_BRAWL_RACE_COUNT.
const RACE_ANIMALS := 6


# ---------------------------------------------------------------- lifecycle
func open_view(p_section: int = -1) -> void:
	## The base remembers its tab in SettingsStore.almanac_tab (P107). This page must NOT share
	## that cell - its tabs mean different things - so it keeps its own, and everything else is
	## the base's behaviour.
	if p_section >= 0 and p_section < BalanceUI.ALMANAC_TAB_COUNT:
		_section = p_section
	else:
		_section = clampi(SettingsStore.brawl_almanac_tab, 0, BalanceUI.ALMANAC_TAB_COUNT - 1)
	_selected_id = ""
	visible = true
	refresh()
	_sync_panel_view()
	if _back != null and not _back.disabled:
		_back.grab_focus()


func refresh() -> void:
	## The base's refresh() reads the LEVEL PACK first (LevelList.discover()) because its third
	## tab lists levels. This mode has no level pack: the third tab is the enemy formations, which
	## FormationDB already owns. Everything after that line is the base's.
	_apply_static_texts()
	_rows = _read_rows()
	if _selected_id != "" and _find_row(_selected_id).is_empty():
		_selected_id = ""
	if _selected_id == "" and not _rows.is_empty():
		_selected_id = str((_rows[0] as Dictionary).get("id", ""))
	on_layout_changed()


func _on_section_pressed(p_index: int) -> void:
	## Same reset the base performs, but the tab is remembered in THIS page's own settings cell.
	if p_index == _section:
		return
	_section = p_index
	SettingsStore.set_brawl_almanac_tab(p_index)
	_selected_id = ""
	_page = 0
	refresh()


func _collect_and_wire() -> void:
	## The base wires the tabs, the races and the groups the SCENE declares, counted by
	## BalanceUI's constants (3 tabs, 2 races, 4 groups). This page has FIVE races more - the
	## piece factions (人类 / 怪兽 / 机械 / 宝可梦 / 动物), whose buttons exist in
	## scenes/ui/brawl_almanac.tscn and nowhere else - so they are appended here, from the first
	## index the base stops at up to ALMANAC_BRAWL_RACE_COUNT. `get_node_or_null` because a scene
	## that declares fewer buttons
	## than the count promises leaves the row short rather than crashing the page.
	super()
	for i in range(BalanceUI.ALMANAC_RACE_COUNT, BalanceUI.ALMANAC_BRAWL_RACE_COUNT):
		var extra := get_node_or_null("RaceButton%d" % i) as Button
		if extra == null:
			continue
		_dress_button(extra, _on_race_pressed.bind(i))
		_races.append(extra)


# ---------------------------------------------------------------- layout
func _layout() -> void:
	## The base lays out the tabs, the race row, the group row, the panel and the page bar from
	## ONE pure metrics call. Two things differ on this page, and both are decided here rather
	## than by a second copy of that maths:
	##   * the GROUP row is the turn mode's four item kinds (工具 / 装备 / 材料 / 货币) - the
	##     classic mode's gear has two kinds and one list, so the row is never shown;
	##   * the RACE row has SEVEN buttons (the classic mode's five piece factions on top of the
	##     turn page's two races) while the base's metrics centre ALMANAC_RACE_COUNT (two) of
	##     them - so the row is re-centred on the grid's own width here.
	super()
	for group in _groups:
		var btn := group as Button
		if btn != null:
			btn.visible = false
	_relayout_races()


func _relayout_races() -> void:
	if _races.is_empty() or _grid == null:
		return
	var m := metrics_for(Layout.size, maxi(_rows.size(), 1))
	var area: Vector2 = m["grid"]
	var x0 := float(m["x0"])
	var gap := BalanceUI.ALMANAC_RACE_GAP
	var h := float(m["race_h"])
	var count := float(_races.size())
	var w := minf(BalanceUI.ALMANAC_RACE_SIZE.x, (area.x - gap * (count - 1.0)) / count)
	var left := floorf(x0 + (area.x - (w * count + gap * (count - 1.0))) * 0.5)
	for i in _races.size():
		var btn := _races[i] as Button
		if btn == null:
			continue
		## The base's rule: the band is reserved on every section, only the VISIBILITY follows
		## the section - so switching tabs never moves the grid.
		btn.visible = _section == Section.UNITS
		btn.position = Vector2(left + float(i) * (w + gap), float(m["race_y"]))
		btn.custom_minimum_size = Vector2(w, h)
		btn.size = Vector2(w, h)


# ---------------------------------------------------------------- the words
func _apply_static_texts() -> void:
	## Everything the page SAYS. The base's version names the turn mode's four rosters; this one
	## counts the classic mode's own three, which is also the fastest way to see that a sheet
	## failed to load (0 units / 0 gear / 0 formations).
	_title = Loc.t("brawl.almanac.title")
	_hint = Loc.t("brawl.almanac.hint")
	_subtitle = Loc.tf("brawl.almanac.subtitle",
		[_timed_count(), GearDB.count(), FormationDB.ids().size()])
	for i in _tabs.size():
		var tab := _tabs[i] as Button
		if tab != null:
			tab.text = _section_title(i)
	for i in _races.size():
		var race := _races[i] as Button
		if race != null:
			race.text = _race_title(i)
	for i in _groups.size():
		var group := _groups[i] as Button
		if group != null:
			group.text = _group_title(i)
	if _back != null:
		_back.text = Loc.t("menu.back")
	if _prev != null:
		_prev.text = Loc.t("grid.page.prev")
	if _next != null:
		_next.text = Loc.t("grid.page.next")
	_update_tab_styles()


func _section_title(p_section: int) -> String:
	## One literal key per branch: a key built by concatenation would be invisible to a key
	## audit (the rule the base class states).
	match p_section:
		Section.UNITS:
			return Loc.t("brawl.almanac.tab.units")
		Section.ITEMS:
			return Loc.t("brawl.almanac.tab.gear")
		Section.LEVELS:
			return Loc.t("brawl.almanac.tab.formations")
	## [D78] ...and everything else is the SHARED sub-almanac (射弹): one implementation, in the
	## base class, reached from both pages through super - the whole point of D78.
	return super._section_title(p_section)


func _race_title(p_race: int) -> String:
	if p_race == RACE_ZOMBIES:
		return Loc.t("almanac.race.zombies")
	if p_race == RACE_HUMANS:
		return Loc.t("brawl.almanac.race.humans")
	if p_race == RACE_MONSTERS:
		return Loc.t("brawl.almanac.race.monsters")      # [B24]
	if p_race == RACE_MACHINE:
		return Loc.t("brawl.almanac.race.machine")       # [B24]
	if p_race == RACE_POKEMON:
		return Loc.t("brawl.almanac.race.pokemon")       # [B38]
	if p_race == RACE_ANIMALS:
		return Loc.t("brawl.almanac.race.animals")       # [B39]
	return Loc.t("almanac.race.plants")


func _race_root() -> String:
	## The units.csv race ROOT the race button stands for - what UnitSheet.ids_for() is asked.
	## The five piece roots are also PieceDB.FACTIONS' keys, which is what lets _is_piece_race()
	## below ask the faction table instead of keeping a second list of the same names.
	match _race:
		RACE_ZOMBIES:
			return "zombies"
		RACE_HUMANS:
			return "humans"
		RACE_MONSTERS:
			return "monsters"
		RACE_MACHINE:
			return "machine"
		RACE_POKEMON:
			return "pokemon"
		RACE_ANIMALS:
			return "animals"
	return "plants"


func _is_piece_race() -> bool:
	## [B24] "Is this a PIECE?" - the question the panel and the picture column both ask, and it
	## has to be ONE question: the humans, the monsters, the machines, [B38]'s pokemon and
	## [B39]'s animals are read by the same facade (PieceDB serves every faction, see its header)
	## and share the five real-time lines
	## (费用 / attack距离 / 移速 / attack间隔 / 射弹) that no plant or zombie row has. Testing the
	## race against RACE_HUMANS - which is what this page did until the second faction arrived -
	## silently draws the monsters and the machines with the plants' short panel.
	return PieceDB.FACTIONS.has(_race_root())


func _timed_count() -> int:
	## How many units this mode introduces, counted across every race: the number the subtitle
	## promises and the one a designer checks after editing the timed column.
	var total := 0
	for id in UnitSheet.live().ids():
		if UnitSheet.timed(str(id)):
			total += 1
	return total


# ---------------------------------------------------------------- the rows
func _read_rows() -> Array:
	match _section:
		Section.ITEMS:
			return _gear_rows()
		Section.LEVELS:
			return _formation_rows()
		Section.UNITS:
			return _unit_rows()
	return super._read_rows()          # [D78] 射弹: the shared section


func shows_whirlwind() -> bool:
	## [B42] This is the page that CAN: the whirlwind is a brawl object (Brawl.tornadoes), so the
	## classic arena is the only one whose projectile tab has a funnel to list. One line, and it is the
	## whole difference between the two pages on this tab - which is why the base class asks instead of
	## deciding.
	return true


func _unit_rows() -> Array:
	## ONE RACE'S CLASSIC ROSTER, in units.csv order, with the race's DEFAULT UNIT first (D75:
	## data/units/races.csv says which one stands for the race). The default keeps its sheet
	## order too - it is moved to the front, not added twice.
	var root := _race_root()
	var default_id: String = RaceDB.default_unit(root)
	var out: Array = []
	for entry in _ordered_ids(root, default_id):
		var id := str(entry)
		var art := Balance.unit_art(id)
		var view := ""
		if root == "plants":
			view = Balance.plant_view(id)
		elif root == "zombies":
			view = Balance.zombie_view(id)
		elif PieceDB.FACTIONS.has(root):
			## [B24] Every piece faction, not just the humans: PieceDB resolves a row's view
			## scene under ITS OWN faction's root, so one door serves all three.
			view = PieceDB.view(id)
		out.append({
			"id": id,
			"title": Balance.unit_name(id),
			"art": art,
			"view": view,
			"badge": str(UnitSheet.live().cell(id, UnitSheet.COL_HP)),
			"note": _unit_note(id, default_id),
			"dimmed": not _has_art(art, view),
			"badge_color": _race_badge_color(),
		})
	return out


func _ordered_ids(p_root: String, p_default: String) -> Array:
	## The race's units that this mode introduces, the default one first.
	var out: Array = []
	if p_default != "" and UnitSheet.timed(p_default):
		out.append(p_default)
	for id in UnitSheet.live().ids_for(p_root):
		var text := str(id)
		if text == p_default or not UnitSheet.timed(text):
			continue
		out.append(text)
	return out


func _unit_note(p_id: String, p_default: String) -> String:
	## The one short line under a cell's name: "this is the race's default" wins, then whether
	## the art folder has a picture at all (the same priority the base class's note follows).
	if p_id == p_default:
		return Loc.t("brawl.almanac.note.default")
	var art := Balance.unit_art(p_id)
	return "" if art != "" else Loc.t("almanac.value.no_art")


func _has_art(p_art: String, p_view: String) -> bool:
	return p_art != "" or p_view != ""


func _race_badge_color() -> Color:
	match _race:
		RACE_ZOMBIES:
			return BalanceUI.COLOR_ALMANAC_BADGE_ZOMBIE
		RACE_HUMANS:
			return BalanceUI.COLOR_ALMANAC_BADGE_PIECE     # [D75] the classic mode's own race
		RACE_MONSTERS:
			return BalanceUI.COLOR_ALMANAC_BADGE_MONSTER   # [B24] ...and its two younger ones
		RACE_MACHINE:
			return BalanceUI.COLOR_ALMANAC_BADGE_MACHINE
		RACE_POKEMON:
			return BalanceUI.COLOR_ALMANAC_BADGE_POKEMON  # [B38]
		RACE_ANIMALS:
			return BalanceUI.COLOR_ALMANAC_BADGE_ANIMAL   # [B39]
	return BalanceUI.COLOR_ALMANAC_BADGE_PLANT


func _gear_rows() -> Array:
	## Every row of data/brawl/gear.csv: the augments and the equipment a piece can wear. The
	## kind is the note (强化 / 装备), the tier's price is the badge - both read from GearDB,
	## which is the only thing that knows what a kind or a tier means.
	var out: Array = []
	for id in GearDB.ids():
		out.append({
			"id": id,
			"title": GearDB.display_name(id),
			"art": GearDB.art(id),
			"badge": str(GearDB.price(id)),
			"note": _gear_kind_text(id),
			"dimmed": GearDB.art(id) == "",
			"badge_color": BalanceUI.COLOR_ALMANAC_BADGE_ITEM,
		})
	return out


func _formation_rows() -> Array:
	## The opponents a round can offer (D34 / D35): the classic mode's answer to the turn page's
	## LEVELS tab. A formation has no picture - its numbers are what a player picks by.
	var out: Array = []
	for id in FormationDB.ids():
		var rows := FormationDB.pieces(id)
		out.append({
			"id": id,
			"title": FormationDB.display_name(id),
			"art": "",
			"badge": str(FormationDB.coins(id)),
			"note": Loc.tf("brawl.almanac.note.pieces", [FormationDB.count_of(rows)]),
			"dimmed": false,
			"badge_color": BalanceUI.COLOR_MENU_MARK,       # the same mark a level row wears
		})
	return out


# ---------------------------------------------------------------- the panel
func _detail_lines(p_id: String) -> Array:
	match _section:
		Section.ITEMS:
			return _gear_lines(p_id)
		Section.LEVELS:
			return _formation_lines(p_id)
		Section.UNITS:
			return _unit_lines(p_id)
	return super._detail_lines(p_id)   # [D78] 射弹: the shared section


func _unit_lines(p_id: String) -> Array:
	## The numbers of ONE classic unit. The sheet owns every one of them: units.csv through
	## UnitSheet for what every race shares, and the race's own family sheet for the rest
	## (the piece factions' 费用 / attack距离 / 移速 / attack间隔 / 射弹, zombies.csv's
	## 护甲 / 移动 / 啃脑伤害).
	##
	## [B24] THE PANEL HAS NINE ROWS (BalanceUI.ALMANAC_PANEL_LINES) and AlmanacView fills no
	## tenth - the page used to SPILL: a piece asked for ten lines and its 技能 row never
	## appeared. Two went to pay for the two that came in (防御 / 战力): 模式, because the race
	## button one row above says the same word, and 技能, because _unit_description() below opens
	## the prose block with the fuller spelling of the same cell. A row the sheet leaves blank is
	## now skipped instead of printed as "—" - that row, too, was part of the budget.
	var lines: Array = [
		Loc.tf("almanac.line.hp", [_sheet_number(p_id, UnitSheet.COL_HP)]),
		Loc.tf("almanac.line.attack", [_sheet_number(p_id, UnitSheet.COL_ATTACK)]),
		Loc.tf("almanac.line.defence", [UnitSheet.defence(p_id)]),
		## The estimate over the THREE lines above it, divided down to a readable scale
		## (Balance.estimate_power, POWER_SCALE): the panel prints its own inputs, so the figure is
		## checkable by hand rather than asked to be trusted.
		Loc.tf("almanac.line.power", [Balance.unit_power(p_id)]),
	]
	if _is_piece_race():
		lines.append(Loc.tf("almanac.line.cost", [str(PieceDB.cost(p_id))]))
		lines.append(Loc.tf("brawl.almanac.line.reach", ["%.2f" % PieceDB.reach(p_id)]))
		lines.append(Loc.tf("brawl.almanac.line.move_speed", ["%.2f" % PieceDB.move_speed(p_id)]))
		lines.append(Loc.tf("brawl.almanac.line.interval",
			["%.2f" % PieceDB.strike_seconds(p_id)]))
		lines.append(Loc.tf("brawl.almanac.line.shot", [_dash(PieceDB.shot(p_id))]))
	elif _race == RACE_ZOMBIES:
		lines.append(Loc.tf("almanac.line.armor", [_number(ZombieDB.armor(p_id))]))
		lines.append(Loc.tf("almanac.line.move",
			[Loc.tf("almanac.value.per_cell", [_number(ZombieDB.move(p_id))])]))
		lines.append(Loc.tf("almanac.desc.brain", [ZombieDB.brain_damage(p_id)]))
	var talent := _sheet_text(p_id, UnitSheet.COL_TALENT)
	if talent != Loc.t("almanac.value.none"):
		lines.append(Loc.tf("almanac.line.talent", [talent]))
	return lines


func _gear_lines(p_id: String) -> Array:
	return [
		Loc.tf("brawl.almanac.line.kind", [_gear_kind_text(p_id)]),
		Loc.tf("brawl.almanac.line.tier", [_dash(GearDB.tier(p_id))]),
		Loc.tf("brawl.almanac.line.effect", [_dash(GearDB.effect_text(p_id))]),
		Loc.tf("brawl.almanac.line.price", [str(GearDB.price(p_id))]),
	]


func _formation_lines(p_id: String) -> Array:
	var rows := FormationDB.pieces(p_id)
	return [
		Loc.tf("brawl.almanac.line.pieces", [FormationDB.count_of(rows)]),
		## [B24] 战力合计 now means what the label says: FormationDB.power_total_of() sums the
		## same Balance.unit_power() figure this page prints per unit, so an opponent's total is
		## the sum of the numbers on its pieces' own cells. What stood here before was
		## hp_total_of() - a bare HP sum under a 战力 label - and it stays in the code because the
		## 编阵 page's offer card still reads that one (brawl_formation.gd).
		## [B29] This line counts the WRITTEN formation - every row the sheet lists, no dice and no
		## reinforcements - so an offer card may well read HIGHER than it: the card shows one round's
		## roll raised to that round's power floor. That is the difference between a catalogue and a
		## fight, and it is deliberate: 图鉴 is the paper, 编阵 is what walked in.
		Loc.tf("brawl.almanac.line.power", [FormationDB.power_total_of(rows)]),
		Loc.tf("brawl.almanac.line.coins", [FormationDB.coins(p_id)]),
		Loc.tf("brawl.almanac.line.roster", [_formation_roster(p_id)]),
	]


func _formation_roster(p_id: String) -> String:
	## WHO stands in that formation, name and count - the one line the turn page's level list
	## answers with its zombie types.
	var seen: Dictionary = {}
	var order: Array = []
	for entry in FormationDB.pieces(p_id):
		var piece := str((entry as Dictionary).get("piece", ""))
		if piece == "":
			continue
		if not seen.has(piece):
			seen[piece] = 0
			order.append(piece)
		seen[piece] = int(seen[piece]) + 1
	## PackedStringArray, not Array: String.join() takes one (the base class's _joined() is for
	## lists that may legitimately be empty - this one never is, a formation with no rows is a
	## data problem FormationDB already reports).
	var parts := PackedStringArray()
	for piece in order:
		parts.append("%s x%d" % [Balance.unit_name(str(piece)), int(seen[piece])])
	return "、".join(parts) if Loc.prefer_zh() else ", ".join(parts)


# ---------------------------------------------------------------- the prose
func _description(p_id: String) -> String:
	match _section:
		Section.ITEMS:
			return _gear_description(p_id)
		Section.LEVELS:
			return _formation_description(p_id)
		Section.UNITS:
			return _unit_description(p_id)
	return super._description(p_id)    # [D78] 射弹: the shared section


func _unit_description(p_id: String) -> String:
	## What the sheet says the unit DOES, in the designer's own words: the skill's effect and the
	## special mechanic, plus the ultimate when the row has one. Nothing is invented here - a row
	## that states neither reads as "—" rather than as a promise.
	var parts := PackedStringArray()
	## [P113] The two human labels lead the prose (helper inherited from the shared AlmanacView);
	## they are the same range_type / role cells the turn page reads, so both almanacs agree.
	var tags := _unit_tags_text(p_id)
	if tags != "":
		parts.append(tags)
	parts.append(Loc.tf("almanac.desc.skill", [_named_effect(p_id, UnitSheet.COL_SKILL, "技能效果")]))
	parts.append(Loc.tf("almanac.desc.special", [_sheet_text(p_id, UnitSheet.COL_SPECIAL)]))
	if _sheet_text(p_id, UnitSheet.COL_ULTIMATE_CODE) != Loc.t("almanac.value.none"):
		parts.append(Loc.tf("almanac.desc.ultimate", [_sheet_text(p_id, "大招")]))
	return "   ".join(parts)


func _gear_description(p_id: String) -> String:
	## What the row does, spelled out by GearDB (effect key -> sentence) and the tier's own words.
	var parts := PackedStringArray()
	parts.append(Loc.tf("almanac.desc.usage", [_dash(GearDB.effect_text(p_id))]))
	parts.append(Loc.tf("brawl.almanac.desc.tier",
		[Loc.tf("brawl.almanac.desc.tier_line", [_dash(GearDB.tier(p_id)), str(GearDB.price(p_id))])]))
	parts.append(Loc.tf("almanac.desc.art",
		[_dash(GearDB.svg_rel(p_id)) if GearDB.art(p_id) != "" else Loc.t("almanac.value.none")]))
	return "   ".join(parts)


func _formation_description(p_id: String) -> String:
	## Where this opponent stands and what beating it pays - the two things a formation row is.
	var parts := PackedStringArray()
	parts.append(Loc.tf("brawl.almanac.desc.pieces", [_formation_roster(p_id)]))
	parts.append(Loc.tf("brawl.almanac.desc.reward", [FormationDB.coins(p_id)]))
	return "   ".join(parts)


# ---------------------------------------------------------------- small doors
func _sheet_text(p_id: String, p_column: String) -> String:
	## One prose cell of a unit's merged row, in the player's language, with "—" for a row that
	## states nothing. UnitCsvManager.cell_en is the twin-aware reader every sheet cell uses.
	var text := UnitCsvManager.cell_en(UnitSheet.live().get_flat(p_id), p_column)
	return text if text != "" else Loc.t("almanac.value.none")


func _sheet_number(p_id: String, p_column: String) -> String:
	var text := UnitSheet.live().cell(p_id, p_column)
	return text if text != "" else Loc.t("almanac.value.none")


func _named_effect(p_id: String, p_name: String, p_effect: String) -> String:
	## "技能名（效果）" - the shape the turn page's _name_and_effect uses for the same pair.
	var name := _sheet_text(p_id, p_name)
	var effect := _sheet_text(p_id, p_effect)
	if effect == Loc.t("almanac.value.none"):
		return name
	return "%s (%s)" % [name, effect]


func _gear_kind_text(p_id: String) -> String:
	var kind := GearDB.kind(p_id)
	if kind == BalanceBrawl.KIND_EQUIPMENT:
		return Loc.t("brawl.almanac.kind.equipment")
	if kind == BalanceBrawl.KIND_AUGMENT:
		return Loc.t("brawl.almanac.kind.augment")
	return _dash(kind)


func _dash(p_text: String) -> String:
	return p_text if p_text != "" and p_text != "—" else Loc.t("almanac.value.none")
