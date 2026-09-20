extends SceneTree
func _initialize() -> void:
	var checks: Dictionary = preload("res://tests/location_checks.gd").run()
	print(JSON.stringify(checks))
	quit(1 if checks.is_empty() or checks.values().has(false) else 0)
