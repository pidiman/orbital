extends Node2D
const Geometry = preload("res://scripts/station_geometry.gd")
signal requested_build(world_position: Vector2)
signal module_selected(world_position: Vector2)
var model: StationModel
var selected: String = ""
var inspected_position: Vector2 = Vector2.INF
const GRID_RADIUS: int = 4
var snap_enabled: bool = true
var snap_spacing: float = Geometry.MODULE_SIZE
var cell_size: float = 55.0
var center: Vector2 = Vector2.ZERO
var hover_cell: Vector2i = Vector2i(99, 99)
var pulses: Array[Dictionary] = []

func _ready() -> void:
	model.changed.connect(queue_redraw)
	model.module_built.connect(_on_built)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var area: Vector2 = get_viewport_rect().size
	center = Vector2((area.x - 350) * 0.5, area.y * 0.5 + 10)
	cell_size = minf(58, (area.y - 230) / 9.0)
	queue_redraw()

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floor((point.x - center.x) / cell_size + 0.5), floor((point.y - center.y) / cell_size + 0.5))

func cell_position(cell: Vector2i) -> Vector2:
	return center + Vector2(cell) * cell_size

func _process(delta: float) -> void:
	hover_cell = cell_at(get_global_mouse_position())
	for pulse: Dictionary in pulses:
		pulse.time += delta
	pulses = pulses.filter(func(p: Dictionary) -> bool: return p.time < 0.65)
	queue_redraw()

func _on_built(world_position: Vector2, _kind: String) -> void:
	pulses.append({"position": world_position, "time": 0.0})

func _unhandled_input(event: InputEvent) -> void:
	if model.region_context != null and not model.region_context.primary_station_visible():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not selected.is_empty():
			requested_build.emit(placement_position(get_canvas_transform().affine_inverse() * event.position))
			get_viewport().set_input_as_handled()
		elif module_at_screen(get_canvas_transform().affine_inverse() * event.position) != Vector2.INF:
			inspected_position = module_at_screen(get_canvas_transform().affine_inverse() * event.position)
			module_selected.emit(inspected_position)
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var grid_color := Color(0.39, 0.57, 0.68, 0.10 if selected.is_empty() else 0.21)
	var edge: float = (GRID_RADIUS + 0.5) * cell_size
	for x in range(-4, 5):
		for y in range(-4, 5):
			var point := cell_position(Vector2i(x, y))
			draw_circle(point, 1.2, grid_color)
	if not selected.is_empty():
		for i in range(10):
			var offset: float = -edge + i * cell_size
			draw_line(center + Vector2(offset, -edge), center + Vector2(offset, edge), grid_color, 1)
			draw_line(center + Vector2(-edge, offset), center + Vector2(edge, offset), grid_color, 1)
		for x in range(-4, 5):
			for y in range(-4, 5):
				var cell := Vector2i(x, y)
				if model.placement_error(cell_to_world(cell) + snap_offset(), selected).is_empty():
					draw_rect(Rect2(cell_position(cell) - Vector2.ONE * (cell_size / 2 - 3), Vector2.ONE * (cell_size - 6)), Color(0.3, 0.83, 0.73, 0.07))
	var positions: Array = model.modules.keys()
	for index in range(positions.size()):
		var world_position: Vector2 = positions[index]
		for other_index in range(index + 1, positions.size()):
			var other: Vector2 = positions[other_index]
			if model.modules_connected(world_position, other):
				draw_line(world_to_screen(world_position), world_to_screen(other), Color("627c8d"), 8)
	for world_position: Vector2 in model.modules:
		ModuleArt.draw_module(self, world_to_screen(world_position), model.catalog[model.modules[world_position]].get("art", model.modules[world_position]), cell_size / 58.0 * model.footprint_size(model.modules[world_position]).x)
	for world_position: Vector2 in model.modules:
		if model.catalog[model.modules[world_position]].has("upgrades"):
			var point: Vector2 = world_to_screen(world_position) + Vector2(12, -19)
			draw_rect(Rect2(point - Vector2(2, 10), Vector2(20, 14)), Color("102332"))
			draw_string(ThemeDB.fallback_font, point, "T%d" % model.tier_at(world_position), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("7ce8ce") if model.tier_at(world_position) > 1 else Color("a2b5c3"))
	if model.modules.has(inspected_position):
		draw_rect(screen_footprint(inspected_position, model.modules[inspected_position]), Color("88d9c6"), false, 1.5)
	if not selected.is_empty() and absi(hover_cell.x) <= 4 and absi(hover_cell.y) <= 4:
		var valid: bool = model.placement_error(placement_position(get_global_mouse_position()), selected).is_empty()
		var color := Color("75e1c5") if valid else Color("ee8c86")
		var rect := screen_footprint(placement_position(get_global_mouse_position()), selected)
		draw_rect(rect, color * Color(1, 1, 1, 0.12))
		draw_rect(rect, color, false, 1.5)
		if not model.modules.has(placement_position(get_global_mouse_position())):
			ModuleArt.draw_module(self, world_to_screen(placement_position(get_global_mouse_position())), model.catalog[selected].get("art", selected), cell_size / 58.0 * model.footprint_size(selected).x, 0.55)
	for pulse: Dictionary in pulses:
		draw_circle(world_to_screen(pulse.position), 30 + pulse.time * 55, Color(0.45, 0.9, 0.8, (1.0 - pulse.time / 0.65) * 0.65), false, 2, true)

# Presentation/input boundary: no viewport pixels or cell indices enter the model.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Geometry.MODULE_SIZE

func world_to_screen(world_position: Vector2) -> Vector2:
	return center + world_position * (cell_size / Geometry.MODULE_SIZE)

func screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - center) * (Geometry.MODULE_SIZE / cell_size)

func placement_position(screen_position: Vector2) -> Vector2:
	var world_position: Vector2 = screen_to_world(screen_position)
	if not snap_enabled:
		return world_position
	return ((world_position - snap_offset()) / snap_spacing + Vector2.ONE * 0.5).floor() * snap_spacing + snap_offset()

func module_at_screen(screen_position: Vector2) -> Vector2:
	var world_position: Vector2 = screen_to_world(screen_position)
	for existing: Vector2 in model.modules:
		if model.footprint_rect(existing, model.modules[existing]).has_point(world_position):
			return existing
	return Vector2.INF

func snap_offset() -> Vector2:
	if selected.is_empty():
		return Vector2.ZERO
	var size: Vector2 = model.footprint_size(selected)
	return Vector2(0.5 if int(size.x) % 2 == 0 else 0.0, 0.5 if int(size.y) % 2 == 0 else 0.0) * snap_spacing

func screen_footprint(origin: Vector2, kind: String) -> Rect2:
	var rect: Rect2 = model.footprint_rect(origin, kind)
	return Rect2(world_to_screen(rect.position), rect.size * cell_size / Geometry.MODULE_SIZE).grow(-2)
