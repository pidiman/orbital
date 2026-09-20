extends SceneTree
var failures: int = 0
var total: int = 0
func _initialize() -> void:
	preload("res://tests/trade_history_checks.gd").new().run(check)
	print("Trade history checks: %d/%d passed" % [total - failures, total])
	quit(1 if failures else 0)
func check(condition: bool, label: String) -> void:
	total += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
