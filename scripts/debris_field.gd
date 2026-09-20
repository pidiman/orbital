extends Node2D
signal salvaged(amount: int, point: Vector2)
signal full_storage
var model: StationModel
var pieces: Array[Dictionary] = []
var spawn_elapsed: float = 0.0
var next_id: int = 0
var debris_count: int = 0

func _ready() -> void:
	for i in range(5):
		_spawn(true)

func _spawn(initial: bool = false) -> void:
	var area: Vector2 = get_viewport_rect().size
	next_id += 1
	pieces.append({"id": next_id, "point": Vector2(randf_range(65, area.x - 380) if initial else -30.0, randf_range(145, area.y - 110)), "velocity": Vector2(randf_range(13, 23), randf_range(-5, 5)), "angle": randf_range(0, TAU), "amount": randi_range(8, 14)})
	debris_count = pieces.size()

func _process(delta: float) -> void:
	spawn_elapsed += delta
	if spawn_elapsed >= 3.0:
		spawn_elapsed -= 3.0
		if pieces.size() < 12:
			_spawn()
	var area: Vector2 = get_viewport_rect().size
	for piece: Dictionary in pieces:
		piece.point += piece.velocity * delta
		piece.angle += delta * 0.20
	pieces = pieces.filter(func(p: Dictionary) -> bool: return p.point.x < area.x - 340 and p.point.y > 112 and p.point.y < area.y - 80)
	debris_count = pieces.size()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in range(pieces.size() - 1, -1, -1):
		var piece: Dictionary = pieces[i]
		if event.position.distance_to(piece.point) <= 27:
			var collected: int = model.collect(piece.amount)
			if collected == 0:
				full_storage.emit()
			else:
				piece.amount -= collected
				salvaged.emit(collected, piece.point)
				if piece.amount == 0:
					pieces.remove_at(i)
			debris_count = pieces.size()
			get_viewport().set_input_as_handled()
			queue_redraw()
			return

func _draw() -> void:
	for piece: Dictionary in pieces:
		var hovered: bool = get_global_mouse_position().distance_to(piece.point) <= 27
		draw_circle(piece.point, 25, Color(0.94, 0.72, 0.40, 0.07 if not hovered else 0.18))
		draw_arc(piece.point, 23, -0.3, 1.0, 14, Color("b28a53"), 1, true)
		draw_arc(piece.point, 23, 2.8, 4.1, 14, Color("b28a53"), 1, true)
		draw_set_transform(piece.point, piece.angle)
		var polygon := PackedVector2Array([Vector2(-10, -5), Vector2(-2, -11), Vector2(10, -5), Vector2(8, 8), Vector2(-5, 10)])
		draw_colored_polygon(polygon, Color("8f795a"))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("f1c47e"), 1.5, true)
		draw_line(Vector2(-3, -5), Vector2(4, 3), Color("c9aa78"), 2)
		draw_set_transform(Vector2.ZERO)
