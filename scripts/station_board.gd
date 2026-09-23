extends Node2D
const Geometry = preload("res://scripts/station_geometry.gd")
signal requested_build(world_position: Vector2)
signal requested_demolish(world_position: Vector2)
signal module_selected(world_position: Vector2)
var model: StationModel
var selected: String = ""
var inspected_position: Vector2 = Vector2.INF
var grid_radius: Vector2i = Geometry.grid_radius()
var snap_enabled: bool = true
var snap_spacing: float = Geometry.MODULE_SIZE
var cell_size: float = 55.0
var center: Vector2 = Vector2.ZERO
var hover_cell: Vector2i = Vector2i(99, 99)
var pulses: Array[Dictionary] = []
var placement_cache: Array[Vector2i] = []
var placement_cache_key: String = ""
var connector_masks: Dictionary = {}
var connector_module_masks: Dictionary = {}
var connector_masks_dirty: bool = true

func _ready() -> void:
	model.changed.connect(_invalidate_placement_cache)
	model.module_built.connect(_on_built)
	model.module_built.connect(_connector_structure_changed)
	model.module_removed.connect(_connector_structure_changed)
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
	var next_hover: Vector2i = cell_at(get_global_mouse_position())
	var needs_redraw: bool = next_hover != hover_cell
	hover_cell = next_hover
	for pulse: Dictionary in pulses:
		pulse.time += delta
	var pulse_count: int = pulses.size()
	pulses = pulses.filter(func(p: Dictionary) -> bool: return p.time < 0.65)
	needs_redraw = needs_redraw or pulse_count > 0 or not pulses.is_empty()
	if needs_redraw: queue_redraw()

func _on_built(world_position: Vector2, _kind: String) -> void:
	pulses.append({"position": world_position, "time": 0.0})

func _connector_structure_changed(_position: Vector2, _kind: String = "") -> void:
	connector_masks_dirty = true
	queue_redraw()

func handle_click(point: Vector2) -> bool:
	if not visible: return false
	var world_point: Vector2 = get_canvas_transform().affine_inverse() * point
	if selected == "__demolish__":
		var demolition_target: Vector2 = module_at_screen(world_point)
		if demolition_target != Vector2.INF:
			requested_demolish.emit(demolition_target)
		return true
	if not selected.is_empty() and selected != "__demolish__":
		requested_build.emit(placement_position(world_point))
		return true
	if module_at_screen(world_point) != Vector2.INF:
		inspected_position = module_at_screen(world_point)
		module_selected.emit(inspected_position)
		return true
	return false

func _draw() -> void:
	var grid_color := Color(0.39, 0.57, 0.68, 0.10 if selected.is_empty() else 0.21)
	var edge: Vector2 = (Vector2(grid_radius) + Vector2.ONE * 0.5) * cell_size
	for x in range(-grid_radius.x, grid_radius.x + 1):
		for y in range(-grid_radius.y, grid_radius.y + 1):
			draw_circle(cell_position(Vector2i(x, y)), 1.2, grid_color)
	if not selected.is_empty():
		for x in range(model.build_grid_dimensions().x + 1):
			var offset: float = -edge.x + x * cell_size
			draw_line(center + Vector2(offset, -edge.y), center + Vector2(offset, edge.y), grid_color, 1)
		for y in range(model.build_grid_dimensions().y + 1):
			var offset: float = -edge.y + y * cell_size
			draw_line(center + Vector2(-edge.x, offset), center + Vector2(edge.x, offset), grid_color, 1)
		_update_placement_cache()
		for cell: Vector2i in placement_cache:
			draw_rect(Rect2(cell_position(cell) - Vector2.ONE * (cell_size / 2 - 3), Vector2.ONE * (cell_size - 6)), Color(0.3, 0.83, 0.73, 0.07))
	var positions: Array = model.modules.keys()
	if connector_masks_dirty:
		connector_masks.clear()
		connector_module_masks.clear()
		for tube_position: Vector2 in model.modules:
			if model.modules[tube_position] == "connector_tube":
				var mask: int = connector_neighbor_mask(tube_position, false)
				connector_masks[tube_position] = mask
				connector_module_masks[tube_position] = connector_module_mask(tube_position)
				print("Tube tiling recalculated at %s: mask=%d -> %s" % [str(tube_position), mask, connector_variant(mask)])
		connector_masks_dirty = false
	for index in range(positions.size()):
		var world_position: Vector2 = positions[index]
		for other_index in range(index + 1, positions.size()):
			var other: Vector2 = positions[other_index]
			if model.modules[world_position] == "connector_tube" and model.modules[other] == "connector_tube" and model.modules_connected(world_position, other):
				draw_line(world_to_screen(world_position), world_to_screen(other), Color("627c8d"), 8)
	for world_position: Vector2 in model.modules:
		var kind: String = model.modules[world_position]
		var art: String = model.catalog[kind].get("art", kind)
		var connector_mask: int = int(connector_masks.get(world_position, 0)) if kind == "connector_tube" else 0
		var module_mask: int = int(connector_module_masks.get(world_position, 0)) if kind == "connector_tube" else 0
		var active: bool = model.is_module_active(world_position)
		ModuleArt.draw_module(self, world_to_screen(world_position), art, cell_size / 58.0 * model.footprint_size(kind).x, 1.0 if active else 0.32, module_facing(world_position), model.tier_at(world_position), connector_mask, module_mask)
		if model.is_module_damaged(world_position):
			var damaged_point: Vector2 = world_to_screen(world_position) + Vector2(0, -20)
			draw_circle(damaged_point, 7, Color("8e5d4d", 0.95))
			draw_line(damaged_point - Vector2(4, 4), damaged_point + Vector2(4, 4), Color("ffc06b"), 2)
			draw_line(damaged_point + Vector2(-4, 4), damaged_point + Vector2(4, -4), Color("ffc06b"), 2)
		elif not active:
			var inactive_point: Vector2 = world_to_screen(world_position) + Vector2(0, -20)
			draw_circle(inactive_point, 7, Color("6b7780", 0.9))
			draw_line(inactive_point - Vector2(3, 3), inactive_point + Vector2(3, 3), Color("e88982"), 2)
			draw_line(inactive_point + Vector2(-3, 3), inactive_point + Vector2(3, -3), Color("e88982"), 2)
		if inspected_position == world_position:
			var hp: int = model.module_hp(world_position)
			var maximum_hp: int = model.module_max_hp(world_position)
			if hp < maximum_hp:
				var hp_point: Vector2 = world_to_screen(world_position) + Vector2(-25, 32)
				draw_rect(Rect2(hp_point, Vector2(50, 4)), Color("263848"))
				draw_rect(Rect2(hp_point, Vector2(50.0 * float(hp) / float(maximum_hp), 4)), Color("8ee6ad") if hp > 0 else Color("e88982"))
				draw_string(ThemeDB.fallback_font, hp_point + Vector2(0, 16), "HP %d/%d" % [hp, maximum_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d6e5ec"))
	for world_position: Vector2 in model.modules:
		if model.catalog[model.modules[world_position]].has("upgrades"):
			var point: Vector2 = world_to_screen(world_position) + Vector2(12, -19)
			draw_rect(Rect2(point - Vector2(2, 10), Vector2(20, 14)), Color("102332"))
			draw_string(ThemeDB.fallback_font, point, "T%d" % model.tier_at(world_position), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("7ce8ce") if model.tier_at(world_position) > 1 else Color("a2b5c3"))
	if model.modules.has(inspected_position):
		draw_rect(screen_footprint(inspected_position, model.modules[inspected_position]), Color("88d9c6"), false, 1.5)
	if not selected.is_empty() and selected != "__demolish__" and absi(hover_cell.x) <= grid_radius.x and absi(hover_cell.y) <= grid_radius.y:
		var valid: bool = model.placement_error(placement_position(get_global_mouse_position()), selected).is_empty()
		var color := Color("75e1c5") if valid else Color("ee8c86")
		var rect := screen_footprint(placement_position(get_global_mouse_position()), selected)
		draw_rect(rect, color * Color(1, 1, 1, 0.12))
		draw_rect(rect, color, false, 1.5)
		if not model.modules.has(placement_position(get_global_mouse_position())):
			var preview_position: Vector2 = placement_position(get_global_mouse_position())
			var preview_mask: int = connector_neighbor_mask(preview_position, false) if selected == "connector_tube" else 0
			ModuleArt.draw_module(self, world_to_screen(preview_position), model.catalog[selected].get("art", selected), cell_size / 58.0 * model.footprint_size(selected).x, 0.55, 0.0, 1, preview_mask, connector_module_mask(preview_position))
	for pulse: Dictionary in pulses:
		draw_circle(world_to_screen(pulse.position), 30 + pulse.time * 55, Color(0.45, 0.9, 0.8, (1.0 - pulse.time / 0.65) * 0.65), false, 2, true)

func connector_neighbor_mask(world_position: Vector2, use_cache: bool = true) -> int:
	if use_cache and connector_masks.has(world_position): return int(connector_masks[world_position])
	var mask: int = 0
	var offsets: Array[Dictionary] = [
		{"bit": 1, "offset": Vector2.LEFT},
		{"bit": 2, "offset": Vector2.RIGHT},
		{"bit": 4, "offset": Vector2.UP},
		{"bit": 8, "offset": Vector2.DOWN}
	]
	for neighbor: Dictionary in offsets:
		var cell: Vector2 = world_position + neighbor.offset * Geometry.MODULE_SIZE
		for existing: Vector2 in model.modules:
			if existing == world_position or model.modules[existing] != "connector_tube": continue
			if model.footprint_rect(existing, model.modules[existing]).has_point(cell):
				mask |= int(neighbor.bit)
				break
	return mask

func connector_variant(mask: int) -> String:
	match mask:
		0: return "ISOLATED"
		1, 2, 4, 8: return "DEAD_END"
		3: return "STRAIGHT_HORIZONTAL"
		12: return "STRAIGHT_VERTICAL"
		5, 6, 9, 10: return "CORNER"
		7, 11, 13, 14: return "T_JUNCTION"
		15: return "CROSSROADS"
	return "ISOLATED"

func connector_module_mask(world_position: Vector2) -> int:
	var mask: int = 0
	var offsets: Array[Dictionary] = [{"bit": 1, "offset": Vector2.LEFT}, {"bit": 2, "offset": Vector2.RIGHT}, {"bit": 4, "offset": Vector2.UP}, {"bit": 8, "offset": Vector2.DOWN}]
	for neighbor: Dictionary in offsets:
		var cell: Vector2 = world_position + neighbor.offset * Geometry.MODULE_SIZE
		for existing: Vector2 in model.modules:
			if existing == world_position or model.modules[existing] == "connector_tube": continue
			if model.footprint_rect(existing, model.modules[existing]).has_point(cell):
				mask |= int(neighbor.bit)
				break
	return mask

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

func module_facing(world_position: Vector2) -> float:
	if model.modules.get(world_position, "") != "connector_tube":
		return 0.0
	var cached_mask: int = int(connector_masks.get(world_position, -1))
	if cached_mask >= 0:
		var horizontal_cached: bool = (cached_mask & 3) != 0
		var vertical_cached: bool = (cached_mask & 12) != 0
		return PI / 2.0 if vertical_cached and not horizontal_cached else 0.0
	var horizontal: bool = false
	var vertical: bool = false
	for other: Vector2 in model.modules:
		if other == world_position or not model.modules_connected(world_position, other):
			continue
		var delta: Vector2 = other - world_position
		if absf(delta.x) >= absf(delta.y): horizontal = true
		else: vertical = true
	return PI / 2.0 if vertical and not horizontal else 0.0

func _invalidate_placement_cache() -> void:
	placement_cache_key = ""
	queue_redraw()

func _update_placement_cache() -> void:
	var key: String = model.station_id + str(model.modules) + str(model.materials) + selected + str(snap_spacing) + str(snap_enabled)
	if key == placement_cache_key: return
	placement_cache_key = key
	placement_cache.clear()
	for x in range(-grid_radius.x, grid_radius.x + 1):
		for y in range(-grid_radius.y, grid_radius.y + 1):
			var cell := Vector2i(x, y)
			if model.placement_error(cell_to_world(cell) + snap_offset(), selected).is_empty():
				placement_cache.append(cell)
