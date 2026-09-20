extends SceneTree
func _initialize() -> void:
	var checks: Dictionary = preload("res://tests/collection_checks.gd").run()
	print(JSON.stringify(checks))
	quit(1 if checks.values().has(false) else 0)
