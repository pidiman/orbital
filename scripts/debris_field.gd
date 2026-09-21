extends Node2D
signal salvaged(amount: int, point: Vector2)
signal full_storage
const Supply = preload("res://scripts/sector_supply.gd")
var supply: Supply
# Projected snapshots only; authority lives in SectorSupply.
var pieces: Array[Dictionary] = []
var debris_count: int = 0

func _ready() -> void:
	_sync_view()

func _process(_delta: float) -> void:
	_sync_view()
	queue_redraw()

func _sync_view() -> void:
	pieces.clear()
	if not supply.fleet.regions.primary_station_visible():
		debris_count = 0
		return
	var area: Vector2 = get_viewport_rect().size
	for debris_id: int in supply.debris:
		var source: Dictionary = supply.debris[debris_id]
		var point := Vector2(source.position.x * (area.x - 380.0), 145.0 + source.position.y * (area.y - 255.0))
		pieces.append({"id": debris_id, "point": point, "angle": fmod(debris_id * 2.399, TAU) + supply.elapsed * 0.2})
	debris_count = pieces.size()

func handle_click(point: Vector2) -> bool:
	if not supply.fleet.regions.primary_station_visible():
		return false
	for i in range(pieces.size() - 1, -1, -1):
		var piece: Dictionary = pieces[i]
		if (get_canvas_transform().affine_inverse() * point).distance_to(piece.point) <= 27:
			var collected: int = supply.salvage(int(piece.id))
			if collected == 0:
				full_storage.emit()
			else:
				salvaged.emit(collected, piece.point)
			_sync_view()
			get_viewport().set_input_as_handled()
			queue_redraw()
			return true
	return false

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
