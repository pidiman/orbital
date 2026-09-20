extends Node
const Supply = preload("res://scripts/sector_supply.gd")
var supply: Supply
var model: StationModel
var elapsed: float = 0.0

func _process(delta: float) -> void:
	supply.advance(delta)
	elapsed += delta
	while elapsed >= 1.0:
		elapsed -= 1.0
		model.tick()
