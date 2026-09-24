extends Node2D

const Geometry = preload("res://scripts/station_geometry.gd")
const TURRET_TINT := Color("ef8b67")
const SILO_TINT := Color("a78aff")
const DASH_COUNT: int = 16
const DASH_FRACTION: float = 0.58

var game: Node2D
var station: StationModel
var enabled: bool = false

func _ready() -> void:
	set_process(false)
	enabled = bool(game.preferences.values.get("show_defense_radius", false))
	game.preferences.defense_radius_changed.connect(set_enabled)
	game.ship_camera.view_changed.connect(_on_camera_changed)
	game.model.ship_built.connect(_on_ship_energy_changed)
	game.model.ship_removed.connect(_on_ship_energy_changed)
	game.model.ship_upgraded.connect(_on_ship_energy_changed)
	_refresh_visibility()

func bind_station(next_station: StationModel) -> void:
	if is_instance_valid(station):
		if station.module_built.is_connected(_on_module_built): station.module_built.disconnect(_on_module_built)
		if station.module_removed.is_connected(_on_module_removed): station.module_removed.disconnect(_on_module_removed)
		if station.module_upgraded.is_connected(_on_module_changed): station.module_upgraded.disconnect(_on_module_changed)
		if station.module_hp_changed.is_connected(_on_module_changed): station.module_hp_changed.disconnect(_on_module_changed)
	station = next_station
	if is_instance_valid(station):
		station.module_built.connect(_on_module_built)
		station.module_removed.connect(_on_module_removed)
		station.module_upgraded.connect(_on_module_changed)
		station.module_hp_changed.connect(_on_module_changed)
	_refresh_visibility()
	_redraw_if_visible()

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	_refresh_visibility()
	queue_redraw()

func _refresh_visibility() -> void:
	visible = enabled and is_instance_valid(game.board) and game.board.visible

func _on_camera_changed() -> void:
	_redraw_if_visible()

func _on_module_built(_position: Vector2, _kind: String) -> void:
	_redraw_if_visible()

func _on_module_removed(_position: Vector2) -> void:
	_redraw_if_visible()

func _on_module_changed(_position: Vector2) -> void:
	_redraw_if_visible()

func _on_ship_energy_changed(_ship_id: int) -> void:
	_redraw_if_visible()

func _redraw_if_visible() -> void:
	if visible: queue_redraw()

func _draw() -> void:
	if not enabled or not game.board.visible or not is_instance_valid(station): return
	for position: Vector2 in station.modules:
		var kind: String = str(station.modules[position])
		if kind not in ["defense_turret", "missile_silo"]: continue
		var radius: float = coverage_radius(position)
		var center: Vector2 = game.board.world_to_screen(position)
		var tint: Color = TURRET_TINT if kind == "defense_turret" else SILO_TINT
		if is_coverage_active(position):
			draw_circle(center, radius, Color(tint.r, tint.g, tint.b, 0.035), true)
			draw_circle(center, radius, Color(tint.r, tint.g, tint.b, 0.36), false, 1.1, true)
		else:
			draw_circle(center, radius, Color(tint.r, tint.g, tint.b, 0.012), true)
			_draw_dashed_outline(center, radius, Color(tint.r, tint.g, tint.b, 0.18))

func coverage_radius(position: Vector2) -> float:
	if not is_instance_valid(station) or not station.modules.has(position): return 0.0
	var kind: String = str(station.modules[position])
	if kind not in ["defense_turret", "missile_silo"]: return 0.0
	var definition: Dictionary = station.definition_at(position)
	var fallback: float = 220.0 if kind == "defense_turret" else 260.0
	return float(definition.get(kind, {}).get("range", fallback)) * game.board.cell_size / Geometry.MODULE_SIZE

func is_coverage_active(position: Vector2) -> bool:
	return is_instance_valid(station) and station.modules.has(position) and station.power_balance() >= 0 and station.is_module_active(position)

func _draw_dashed_outline(center: Vector2, radius: float, color: Color) -> void:
	for dash: int in range(DASH_COUNT):
		var start: float = TAU * float(dash) / float(DASH_COUNT)
		var finish: float = start + TAU * DASH_FRACTION / float(DASH_COUNT)
		var points := PackedVector2Array()
		for point_index: int in range(6):
			var ratio: float = float(point_index) / 5.0
			var angle: float = lerpf(start, finish, ratio)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(points, color, 1.0, true)
