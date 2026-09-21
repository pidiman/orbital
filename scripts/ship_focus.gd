extends Camera2D
# Presentation coordinates only; never writes ship, station, or mission state.
var game: Node2D
var ship_id: int = -1
var focus_region: String = ""

func _ready() -> void:
	position = get_viewport_rect().size * 0.5
	get_viewport().size_changed.connect(reset_view)

func reset_view() -> void:
	ship_id = -1
	position = get_viewport_rect().size * 0.5
	force_update_scroll()

func focus_ship(id: int) -> void:
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
	if game.fleet.transport.jobs.has(id):
		return game.board.world_to_screen(game.fleet.transport.jobs[id].gate)
	if game.fleet.collection.jobs.has(id):
		return game.get_node("MaterialShips").ship_position(id)
	return game.asteroids.ship_position(id)
