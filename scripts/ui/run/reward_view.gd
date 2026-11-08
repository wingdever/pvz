class_name RewardView
extends RunScreen
## [P31-A] The pick-one-of-three page (stage 3 of the run reward). Stages 1 and 2
## were already paid out by the time this page opens - RunFlow._grant_run_base ran
## with the result panel and the level's own `rewards` rolls went through the
## normal settlement - so this page shows NOTHING but the three candidates and
## the wallet they join.
##
## There is no BACK and no ESC here (Game consumes both on RUN_REWARD): the pick
## is the node's completion, so leaving without choosing would silently forfeit
## it. One group per candidate, so each gets a full-width line.

func _screen_title() -> String:
	return Loc.t("run.reward.title")


func _screen_subtitle() -> String:
	var wallet: int = game.money_amount() if game != null else 0
	return Loc.tf("run.map.wallet", [wallet])


func _screen_hint() -> String:
	return Loc.t("run.reward.hint")


func _read_rows() -> Array:
	var out: Array = []
	if game == null:
		return out
	for entry in game.run_flow.run_reward_options():
		var opt: Dictionary = entry
		out.append([{"text": str(opt.get("text", "?")), "enabled": true,
			"color": BalanceUI.COLOR_TEXT}])
	return out


func _on_row_pressed(p_group: int, _p_index: int) -> void:
	if game == null:
		return
	## The pick commits and advances the pointer; on success this page is gone
	## (roadmap or run-end takes over). False = stale frame - stay and re-read.
	if not bool(game.run_flow.run_reward_pick(p_group)):
		refresh()


func _wants_back() -> bool:
	return false
