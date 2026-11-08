class_name PlantScripts
extends RefCounted
## [P34/P104] THE ONE ROSTER of "which plant id runs which script" - read from the 脚本 column
## of data/units/plants.csv (PlantDB.script_file), not from a preload list.
##
## Why a TABLE instead of the `match` game_manager used to carry: that match ended in
## `_: return PEASHOOTER_SCRIPT`, so a plant whose card, scroll, sheet rows and loc entries
## were wired but whose script was NOT still summoned happily - as a pea. Here a missing id
## is a name the start-up check prints, and PlantDB.self_check() turns it into a FAIL line
## ("wired False") before anyone plays.
##
## [P104] WHAT CHANGED: the table is the SHEET's 脚本 cell now. The 24 preload consts and
## the 24-entry SCRIPTS dict that used to live here are gone, so adding a plant no longer
## touches this file - and the roster cannot drift from the sheet that already lists the row.
## THE COST, said plainly: a script that does not exist (or a typo in the cell) is no longer
## a PARSE error - it is a load() that answers null, which is a `wired False` FAIL at boot
## and a loud fall-back to the peashooter at summon time. The load is cached per sheet
## generation (PlantDB.loads()), so the answer costs one file read per plant per reload.
##
## A script is only half of a plant: the id must also carry a `卡片` number to be in the
## roster, and have its sheet rows / loc entries (docs/ADD_UNIT.md §C.2 lists every place).
## This class is the half the battle dispatches on.
##
## Only the id KEY matters to the check; a spirit copy ("spirit_<base>") owns no script of
## its own - it runs its base plant's, which is why base_id() strips the prefix through
## Balance.spirit_base() rather than the sheet listing spirit ids.

static var _scripts: Dictionary = {}       # id -> GDScript (null = the cell names no script)
static var _at := -1                       # the PlantDB.loads() generation that filled it


static func base_id(plant_id: String) -> String:
	## The id whose script actually runs: the plant itself, or the base behind a
	## spirit copy ("" stays "" - Balance.spirit_base only answers for spirit ids).
	var base := Balance.spirit_base(plant_id)
	return base if base != "" else plant_id


static func script_for(plant_id: String) -> GDScript:
	## The script that runs this plant (a spirit copy answers with its base's), or null when
	## the sheet's 脚本 cell is empty or names a file that does not load. Cached per sheet
	## generation: this is asked on every summon AND once per card by the start-up check.
	var at := PlantDB.loads()
	if at != _at:
		_scripts.clear()
		_at = at
	var id := base_id(plant_id)
	if _scripts.has(id):
		return _scripts[id] as GDScript
	var path := PlantDB.script_file(id)
	var script: GDScript = null
	if path != "":
		script = load(path) as GDScript
	_scripts[id] = script
	return script


static func is_registered(plant_id: String) -> bool:
	## "Does a script implement this plant?" - what the [Plants] wiring claim, the summon
	## path and the spirit probe all ask.
	return script_for(plant_id) != null