class_name SquadView
extends RunScreen
## [P31-A] PICK YOUR SQUAD: one line per two garden plants, a SET OUT footer and
## BACK. The page reads the run through Game.run_flow (squad_rows / squad_toggle /
## confirm_run_squad) and holds no state itself - the uncommitted selection lives
## in RunFlow._squad_pick, so leaving mid-pick and coming back cannot lose it, and
## run.json is only written when the pick is committed.
##
## A DOWNED plant is still clickable ON PURPOSE: the toggle refuses it with
## "a DOWNED plant cannot enlist" in words, which teaches the rule instead of
## hiding behind a greyed button (the cap answers the same way).

const _PER_LINE := 2                   # garden plants per row group (names stay readable)


func _screen_title() -> String:
	return Loc.t("run.squad.title")


func _screen_subtitle() -> String:
	var picked: int = game.run_flow.squad_pick_count() if game != null else 0
	return Loc.tf("run.squad.subtitle", [picked, _limit()])


func _screen_hint() -> String:
	return Loc.tf("run.squad.hint", [_limit()])


func _limit() -> int:
	return game.run_flow.run_squad_limit() if game != null else BalanceRun.RUN_SQUAD_SLOTS


func _read_rows() -> Array:
	var out: Array = []
	if game == null:
		return out
	var batch: Array = []
	for entry in game.run_flow.squad_rows():
		var row: Dictionary = entry
		batch.append(_row_dict(row))
		if batch.size() == _PER_LINE:
			out.append(batch)
			batch = []
	if not batch.is_empty():
		out.append(batch)
	return out


func _row_dict(p_row: Dictionary) -> Dictionary:
	var picked := bool(p_row.get("picked", false))
	var pickable := bool(p_row.get("pickable", true))
	var marker := "[x]" if picked else ("[-]" if not pickable else "[ ]")
	var text := "%s %s  %s  %s" % [marker, str(p_row.get("title", "")),
		str(p_row.get("hp_text", "")), _state_word(str(p_row.get("state", "")))]
	var color: Color = BalanceUI.COLOR_TEXT
	if picked:
		color = BalanceUI.COLOR_RUN_PICKED
	elif not pickable:
		color = BalanceUI.COLOR_RUN_LOCKED
	return {"text": text, "enabled": true, "color": color,
		"slot": int(p_row.get("slot", -1))}


func _state_word(p_state: String) -> String:
	## Garden speaks its state in Balance tokens (the same ones the garden page
	## translates); LocUi owns the player-facing words.
	match p_state:
		BalanceGarden.GARDEN_STATE_DOWNED:
			return Loc.t("garden.state.downed")
		BalanceGarden.GARDEN_STATE_WOUNDED:
			return Loc.t("garden.state.wounded")
		BalanceGarden.GARDEN_STATE_HEALTHY:
			return Loc.t("garden.state.healthy")
	return p_state


func _on_row_pressed(p_group: int, p_index: int) -> void:
	if game == null:
		return
	var row: Dictionary = (_groups[p_group] as Array)[p_index] as Dictionary
	_report(game.run_flow.squad_toggle(int(row.get("slot", -1))))


func _footer_specs() -> Array:
	var picked: int = game.run_flow.squad_pick_count() if game != null else 0
	return [{"text": Loc.t("run.squad.confirm"), "enabled": picked > 0}]


func _on_footer_pressed(p_index: int) -> void:
	if game == null or p_index != 0:
		return
	_report(game.run_flow.confirm_run_squad())
