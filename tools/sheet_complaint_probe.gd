extends SceneTree
## [P57] THROWAWAY probe, NOT part of the game - delete it when you are done.
##
## Question it answers: the shipped sheets are clean, or does my new complaint
## channel simply never fire? `godot --headless ... --quit-after 240` printed
## ZERO "sheet complaint" lines, which is the same evidence as "the rule holds"
## and "the rule is dead" - the P56 lesson from the other side (a green assertion
## that provokes nothing tests nothing).
##
## This asks the real reader to read a real cell that is really broken, through the
## real `PlantDB`/`ZombieDB`/`ItemDB`/`SkillDB` code paths, and prints what comes back.
##
##   godot --headless --path . --script res://tools/sheet_complaint_probe.gd 2>&1 | grep "\[Probe\]"

const FIXTURE := """英文名称\tHP\tattack
probe_good\t300\t20
probe_bad_hp\t三百\t20
probe_bad_atk\t100\tn/a2
probe_dash\t—\t15
"""


func _initialize() -> void:
	var path := "user://sheet_probe_fixture.csv"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("[Probe] cannot write the fixture (error %d) | FAIL" % FileAccess.get_open_error())
		quit(1)
		return
	f.store_string(FIXTURE)
	f.close()

	var table := UnitCsvManager.read_table(path)
	if not bool(table.get("ok", false)):
		print("[Probe] fixture not readable: %s | FAIL" % str(table.get("error", "?")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		quit(1)
		return
	var rows: Array = table.get("rows", [])
	print("[Probe] fixture rows: %d (1 good, 2 bad numbers, 1 dash)" % rows.size())

	# Read every numeric column of every fixture row the way the DBs do.
	var before := UnitCsvManager.complaint_count()
	for row in rows:
		var raw: Dictionary = row
		var hp := UnitCsvManager.int_cell(raw, ["HP"], 4242)
		var atk := UnitCsvManager.int_cell(raw, ["attack"], 4242)
		var id := UnitCsvManager.cell_any(raw, UnitCsvManager.ID_COLUMNS)
		print("[Probe]   %-13s HP=%-5d attack=%-5d" % [id, hp, atk])
	var after := UnitCsvManager.complaint_count()
	print("[Probe] complaints: %d before, %d after -> %d new (expected 2) | %s"
		% [before, after, after - before,
		"OK" if after - before == 2 else "FAIL"])
	print("[Probe] dash row read as 4242 (a blank is NOT a complaint) = %s | %s"
		% [str(UnitCsvManager.int_cell(rows[3] as Dictionary, ["HP"], 4242)),
		"OK" if UnitCsvManager.int_cell(rows[3] as Dictionary, ["HP"], 4242) == 4242 else "FAIL"])
	## The flush contract, and the half of D2 that lives in the HEADER row.
	## `report_complaints()` answers false when it had something to say - that is what
	## lets a sheet self-check fold it into its own `ok` - and clears, so the next block
	## only reports its own. The second call is the proof that it really cleared.
	var first := UnitCsvManager.report_complaints("[Probe]")
	var second := UnitCsvManager.report_complaints("[Probe]")
	var flush_ok := (not first and second and UnitCsvManager.complaint_count() == 0)
	print("[Probe] flush: 1st call said %s (false = it had the two above to print), "
		% [str(first)]
		+ "2nd said %s with %d pending (true/0, nothing printed between them) | %s"
		% [str(second), UnitCsvManager.complaint_count(), "OK" if flush_ok else "FAIL"])
	## A header that spells one column twice: the Dictionary is keyed by name, so the
	## right-hand copy wins and the left one becomes unreadable - in the file it looks
	## like a healthy column with values in it.
	var dup := "英文名称\tID\tID\tHP\npea\tleft\tright\t300\n"
	var g := FileAccess.open(path, FileAccess.WRITE)
	if g == null:
		print("[Probe] cannot write the duplicate-header fixture (error %d) | FAIL"
			% FileAccess.get_open_error())
	else:
		g.store_string(dup)
		g.close()
		var dtable := UnitCsvManager.read_table(path)
		var drows: Array = dtable.get("rows", [])
		var won := ""
		if not drows.is_empty():
			won = UnitCsvManager.cell(drows[0] as Dictionary, "ID")
		var dcount := UnitCsvManager.complaint_count()
		var dup_ok := (bool(dtable.get("ok", false))
			and dcount == 1 and won == "right")
		print("[Probe] duplicate header: %d complaint(s) (expected 1), the value that "
			% [dcount]
			+ "wins is \"%s\" (expected \"right\", the left one is gone) | %s"
			% [won, "OK" if dup_ok else "FAIL"])
		UnitCsvManager.report_complaints("[Probe]")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("[Probe] fixture removed: %s"
		% ("OK" if not FileAccess.file_exists(path) else "FAIL, left behind"))
	quit()
