extends Node2D
# Added after world fields: GUI gets first refusal, then ship sprites, then world
# placement/salvage/mining. The tray and this adapter share HUD.select_ship().
var game: Node2D
const HIT_RADIUS: float = 22.0

func _process(_delta: float) -> void:
	queue_redraw()

func hits_at(screen_point: Vector2) -> Array[int]:
	var hits: Array[int] = []
	for id: int in game.model.ships:
		if game.fleet.transport.location(id) != game.fleet.regions.current_region:
			continue
		var point: Vector2 = get_canvas_transform() * game.ship_camera.ship_point(id)
		if point.distance_to(screen_point) <= HIT_RADIUS:
			hits.append(id)
	hits.sort_custom(func(a: int, b: int) -> bool:
		var first: Vector2 = get_canvas_transform() * game.ship_camera.ship_point(a)
		var second: Vector2 = get_canvas_transform() * game.ship_camera.ship_point(b)
		return first.distance_squared_to(screen_point) < second.distance_squared_to(screen_point))
	return hits

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var hits: Array[int] = hits_at(event.position)
	if hits.is_empty(): return
	var id: int = hits[0]
	# Overlapping transit sprites at the same gate are individually reachable.
	if hits.size() > 1 and hits.has(game.hud.selected_ship_id):
		id = hits[(hits.find(game.hud.selected_ship_id) + 1) % hits.size()]
	game.hud.select_ship(id)
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var id: int = game.hud.selected_ship_id
	if not game.model.ships.has(id) or game.fleet.transport.location(id) != game.fleet.regions.current_region: return
	var point: Vector2 = game.ship_camera.ship_point(id)
	var radius: float = HIT_RADIUS / game.ship_camera.zoom.x
	draw_arc(point, radius, 0, TAU, 48, Color("72dbcb"), 2.0 / game.ship_camera.zoom.x, true)
