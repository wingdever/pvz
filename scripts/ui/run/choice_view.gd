class_name ChoiceView
extends RunScreen
## [P31-A] The ONE page that serves every non-battle stop of the run: event,
## treasure, rest - and the run-end summary. Game already speaks to them all in
## the same three words (run_screen_kind names it, run_choice_title /
## run_choice_body / run_choice_options say it, run_choice_pick commits it), so
## a new node type needs new DATA (events.json, Balance) and not a new screen.
##
## Like the reward page this one has no BACK: the pick IS the exit - leaving a
## rest or an event unanswered would be the roadmap's "entered but undecided"
## limbo, which only a battle is allowed to be in (Game consumes ESC here).

func _screen_title() -> String:
	return game.run_flow.run_choice_title() if game != null else ""


func _screen_hint() -> String:
	## The body text already tells what happened; the footer keys of the options
	## speak for themselves. No hint line, so the prose gets the room.
	return ""


func _body_line_h() -> float:
	## The event / treasure / rest paragraphs are prose: two wrapped lines' worth.
	return BalanceUI.RUN_BODY_LINE_H * 2.0


func _body_lines() -> Array[String]:
	if game == null:
		var empty: Array[String] = []
		return empty
	return game.run_flow.run_choice_body()


func _read_rows() -> Array:
	var out: Array = []
	if game == null:
		return out
	for entry in game.run_flow.run_choice_options():
		var opt: Dictionary = entry
		out.append([{"text": str(opt.get("text", "?")),
			"enabled": bool(opt.get("enabled", true)),
			"color": BalanceUI.COLOR_TEXT if bool(opt.get("enabled", true))
				else BalanceUI.COLOR_RUN_LOCKED}])
	return out


func _on_row_pressed(p_group: int, _p_index: int) -> void:
	if game == null:
		return
	## Same contract as the reward page: the pick advances the node and swaps the
	## screen; a refused pick (stale frame, unaffordable) just re-reads the page.
	if not bool(game.run_flow.run_choice_pick(p_group)):
		refresh()


func _wants_back() -> bool:
	return false
