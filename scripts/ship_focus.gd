extends Camera2D
# Presentation coordinates only; never writes ship, station, or mission state.
var game: Node2D
var ship_id: int = -1
var focus_region: String = ""

func _ready() -> void:
	process_priority = 20
	position = get_viewport_rect().size * 0.5
	get_viewport().size_changed.connect(reset_view)

func reset_view() -> void:
	ship_id = -1
	zoom = Vector2.ONE
	position = get_viewport_rect().size * 0.5
	force_update_scroll()

func focus_ship(id: int) -> void:
	zoom = Vector2.ONE
	ship_id = id
	focus_region = game.fleet.transport.location(id)
	_update_focus()

func _process(_delta: float) -> void:
	_update_focus()

func _update_focus() -> void:
	if ship_id < 0: return
	if not game.model.ships.has(ship_id) or game.fleet.regions.current_region != focus_region or game.fleet.transport.location(ship_id) != focus_region:
		reset_view()
		return
	position = ship_point(ship_id)
	force_update_scroll()

func ship_point(id: int) -> Vector2:
	return game.ship_motion.position_for(id)

func pan_view(direction: Vector2) -> void:
	ship_id = -1
	position += direction * 120.0 / zoom
	force_update_scroll()

func zoom_view(factor: float) -> void:
	ship_id = -1
	zoom = Vector2.ONE * clampf(zoom.x * factor, 0.15, 2.0)
	force_update_scroll()

func fit_grid() -> void:
	ship_id = -1
	var viewport_size: Vector2 = get_viewport_rect().size
	var area := Rect2(28, 300, maxf(200, viewport_size.x - 440), maxf(160, viewport_size.y - 448))
	var grid_size: Vector2 = Vector2(StationGeometry.grid_dimensions) * game.board.cell_size
	zoom = Vector2.ONE * minf(area.size.x / grid_size.x, area.size.y / grid_size.y)
	position = game.board.center + (viewport_size * 0.5 - area.get_center()) / zoom
	force_update_scroll()
