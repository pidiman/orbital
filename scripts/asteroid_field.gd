extends Node2D
const Fleet = preload("res://scripts/mining_fleet.gd")
signal notice(text: String, error: bool)
signal minerals_delivered(amount: int, point: Vector2)

@export var spawn_interval: float = 12.0
@export var max_asteroids: int = 3
@export var asteroid_minerals: int = 18
var fleet: Fleet
var board: Node2D
var rocks: Dictionary = {}
var next_id: int = 0
var spawn_elapsed: float = 0.0
var asteroid_count: int = 0
var selected_ship: int = -1
var font: Font = ThemeDB.fallback_font
const ORE := Color("baa1f5")

func _ready() -> void:
	fleet.completed.connect(_on_completed)
	fleet.surveyed.connect(_on_surveyed)
	_spawn(true)

func _spawn(initial: bool = false) -> void:
	var area: Vector2 = get_viewport_rect().size
	next_id += 1
	var upper_lane: bool = next_id % 2 == 1
	var point := Vector2(160.0 if initial else -48.0, 150.0 if upper_lane else area.y - 126.0)
	rocks[next_id] = {"point": point, "speed": randf_range(9.0, 13.0), "angle": randf_range(0.0, TAU)}
	fleet.register_asteroid(next_id, asteroid_minerals)
	asteroid_count = rocks.size()

func _process(delta: float) -> void:
	spawn_elapsed += delta
	if spawn_elapsed >= spawn_interval:
		spawn_elapsed = 0.0
		if home_asteroid_count() < max_asteroids:
			_spawn()
	var edge: float = get_viewport_rect().size.x - 378.0
	for asteroid_id: int in rocks.keys():
		if not fleet.asteroids.has(asteroid_id):
			rocks.erase(asteroid_id)
			continue
		var rock: Dictionary = rocks[asteroid_id]
		if not fleet.asteroids[asteroid_id].claimed:
			var next_x: float = rock.point.x + float(rock.speed) * delta
			for other_id: int in rocks:
				if other_id == asteroid_id:
					continue
				var other: Vector2 = rocks[other_id].point
				if absf(other.y - rock.point.y) < 65 and other.x > rock.point.x:
					next_x = minf(next_x, maxf(rock.point.x, other.x - 88))
			rock.point.x = next_x
		rock.angle += delta * 0.06
		if rock.point.x > edge and fleet.remove_asteroid(asteroid_id):
			rocks.erase(asteroid_id)
	asteroid_count = rocks.size()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for asteroid_id: int in rocks:
		if event.position.distance_to(rocks[asteroid_id].point) <= 34.0:
			var error: String = fleet.dispatch(asteroid_id, selected_ship)
			notice.emit("Mining Ship dispatched. Minerals arrive when the timer ends." if error.is_empty() else error, not error.is_empty())
			if error.is_empty():
				selected_ship = -1
			get_viewport().set_input_as_handled()
			return

func _on_completed(unit: Variant, asteroid_id: int, amount: int) -> void:
	var point: Vector2 = rocks[asteroid_id].point if rocks.has(asteroid_id) else board.center
	minerals_delivered.emit(amount, point)
	notice.emit("+%d Minerals. Auto-mining continues." % amount if fleet.jobs.has(unit) else "Mining complete: +%d Minerals. Ship ready." % amount, false)
	if not fleet.asteroids.has(asteroid_id):
		rocks.erase(asteroid_id)
	asteroid_count = rocks.size()

func _draw() -> void:
	for ship_id: int in fleet.model.ships:
		var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
		if not fleet.jobs.has(ship_id):
			var point: Vector2 = home_position(ship_id)
			ModuleArt.draw_module(self, point, definition.get("art", "scout"), 0.55)
			var text: String = "%s #%d" % [definition.name, ship_id]
			if fleet.survey_jobs.has(ship_id):
				text = "Survey %ds" % fleet.survey_jobs[ship_id].remaining
				draw_arc(point, 26, 0, TAU, 32, Color("8bcdf1"), 1.5, true)
			draw_string(font, point + Vector2(-28, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(definition.color))
	for unit: Variant in fleet.jobs:
		var job: Dictionary = fleet.jobs[unit]
		if not rocks.has(job.target):
			continue
		var start: Vector2 = home_position(unit)
		var target: Vector2 = rocks[job.target].point
		draw_dashed_line(start, target, Color(0.72, 0.62, 0.96, 0.4), 1.5, 7.0)
		var progress: float = 1.0 - float(job.remaining) / float(job.duration)
		var flight: float = clampf(progress * 4.0, 0.0, 1.0) if progress < 0.75 else clampf((1.0 - progress) * 4.0, 0.0, 1.0)
		var ship_point: Vector2 = start.lerp(target + Vector2(0, 30), flight)
		ModuleArt.draw_module(self, ship_point, "mining_ship", 0.55)
		draw_arc(target, 34.0, -PI / 2, -PI / 2 + TAU * maxf(0.01, progress), 48, ORE, 3.0, true)
		draw_string(font, target + Vector2(-21, 51), "%ds" % job.remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ORE)
	for asteroid_id: int in rocks:
		if not fleet.asteroids.has(asteroid_id):
			continue
		var rock: Dictionary = rocks[asteroid_id]
		var point: Vector2 = rock.point
		var hovered: bool = get_global_mouse_position().distance_to(point) <= 34.0
		draw_circle(point, 34, Color(0.57, 0.39, 0.86, 0.17 if hovered else 0.07))
		draw_set_transform(point, rock.angle)
		var polygon := PackedVector2Array([Vector2(-24, -8), Vector2(-14, -25), Vector2(8, -27), Vector2(25, -10), Vector2(21, 15), Vector2(1, 26), Vector2(-22, 16)])
		draw_colored_polygon(polygon, Color("393249"))
		polygon.append(polygon[0])
		draw_polyline(polygon, ORE, 2.0, true)
		draw_circle(Vector2(-8, -6), 7.0, Color("242738"))
		draw_circle(Vector2(10, 8), 5.0, Color("242738"))
		draw_polyline(PackedVector2Array([Vector2(-5, 15), Vector2(0, 5), Vector2(13, -5), Vector2(10, -18)]), Color("9273c5"), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		if not fleet.asteroids[asteroid_id].claimed:
			draw_string(font, point + Vector2(-41, 48), "ORE · %d" % fleet.asteroids[asteroid_id].minerals, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ORE)

func home_position(unit: Variant) -> Vector2:
	if unit is Vector2:
		return board.world_to_screen(unit)
	var index: int = int(unit) - 1
	return Vector2(get_viewport_rect().size.x - 410.0 - int(index / 7.0) * 62, 235 + (index % 7) * 63)

func _on_surveyed(sector: Dictionary) -> void:
	for asteroid_id: int in sector.get("asteroid_ids", []):
		var point := Vector2(650, 150)
		var best_gap: float = -1.0
		for lane_y: float in [230.0, get_viewport_rect().size.y - 206.0]:
			for lane_x: float in [300.0, 450.0, 600.0, 750.0]:
				var candidate := Vector2(lane_x, lane_y)
				var gap: float = 10000.0
				for existing: Dictionary in rocks.values():
					gap = minf(gap, candidate.distance_to(existing.point))
				if gap > best_gap:
					point = candidate
					best_gap = gap
		# A projected discovery marker stays available; it is not a drifting home rock.
		rocks[asteroid_id] = {"point": point, "speed": 0.0, "angle": 0.2}
	asteroid_count = rocks.size()
	notice.emit("%s revealed. Open Sector map for the discovery report." % sector.name, false)

func home_asteroid_count() -> int:
	var count: int = 0
	for asteroid_id: int in rocks:
		if asteroid_id > 0:
			count += 1
	return count
