extends Node
const Supply = preload("res://scripts/sector_supply.gd")
var supply: Supply
var model: StationModel

func _process(delta: float) -> void:
	supply.advance(delta)
	model.tick_elapsed += delta
	while model.tick_elapsed >= 1.0:
		model.tick_elapsed -= 1.0
		model.tick()
