extends Node
var model: StationModel
var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	while elapsed >= 1.0:
		elapsed -= 1.0
		model.tick()
