extends Node2D
var supply: RefCounted
var board: Node2D

func _process(_delta: float) -> void:
	visible = supply.fleet.regions.primary_station_visible()
	queue_redraw()

func _draw() -> void:
	for ship_id: int in supply.collection.jobs:
		var job: Dictionary = supply.collection.jobs[ship_id]
		var point: Vector2 = ship_position(ship_id)
		var definition: Dictionary = supply.model.ship_catalog[supply.model.ships[ship_id]]
		ModuleArt.draw_module(self, point, definition.get("art", "trader"), 0.45)
		if job.cargo > 0:
			draw_circle(point + Vector2(13, 0), 4, Color("eebd76"))

func ship_position(ship_id: int) -> Vector2:
	return get_parent().ship_motion.position_for(ship_id)

func target_position(ship_id: int) -> Vector2:
	var area: Vector2 = get_viewport_rect().size
	var job: Dictionary = supply.collection.jobs[ship_id]
	var point := Vector2(job.position.x * (area.x - 380), 145 + job.position.y * (area.y - 255))
	# Blend the logical depot anchor onto the actual continuous station position.
	var anchor: Vector2 = supply.collection.depot_position(job.depot)
	var projected := Vector2(anchor.x * (area.x - 380), 145 + anchor.y * (area.y - 255))
	var weight: float = clampf(1.0 - job.position.distance_to(anchor) / 0.15, 0.0, 1.0)
	point += (board.world_to_screen(job.depot) - projected) * weight
	return point
