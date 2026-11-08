extends Node

const EXPECTED_MAJOR := 4
const EXPECTED_MINOR := 7

func _ready() -> void:
	var info: Dictionary = Engine.get_version_info()
	print("=== PvZ turn-based boot OK ===")
	print("Godot version : %d.%d.%d (%s)" % [info.major, info.minor, info.patch, info.status])
	print("Project name  : %s" % ProjectSettings.get_setting("application/config/name", "?"))
	print("Main scene    : %s" % ProjectSettings.get_setting("application/run/main_scene", "?"))
	print("Project path  : %s" % ProjectSettings.globalize_path("res://"))
	if int(info.major) != EXPECTED_MAJOR:
		push_warning("Version mismatch: expected %d.x but got %d.%d.%d"
			% [EXPECTED_MAJOR, info.major, info.minor, info.patch])
	elif int(info.minor) != EXPECTED_MINOR:
		## [P37] A different 4.x minor is worth KNOWING about but not worth a warning
		## on every launch: the project runs on 4.x broadly, and an unconditional
		## minor-version warning trains everyone to ignore the boot log
		## (OPTIMIZATIONS A10).
		print("Note: built and tested on %d.%d, running on %d.%d.%d"
			% [EXPECTED_MAJOR, EXPECTED_MINOR, info.major, info.minor, info.patch])
	print("=== boot check finished ===")