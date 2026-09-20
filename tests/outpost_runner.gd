extends SceneTree
func _initialize() -> void:
	var checks: Dictionary = preload("res://tests/outpost_checks.gd").run()
	print(JSON.stringify(checks))
	quit(1 if checks.size() < 40 or checks.values().has(false) else 0)
