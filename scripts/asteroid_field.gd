extends Node2D
const RegionView = preload("res://scripts/region_view.gd")
const Fleet = preload("res://scripts/mining_fleet.gd")
signal notice(text: String, error: bool)
signal minerals_delivered(amount: int, point: Vector2)

const Supply = preload("res://scripts/sector_supply.gd")
var supply: Supply
var fleet: Fleet
var board: Node2D
var rocks: Dictionary = {}
var next_id: int:
	get: return supply.next_home_id
var asteroid_count: int = 0
var selected_ship: int = -1
var font: Font = ThemeDB.fallback_font
const ORE := Color("baa1f5")

func _ready() -> void:
	fleet.completed.connect(_on_completed)
	fleet.surveyed.connect(_on_surveyed)
	fleet.model.ship_removed.connect(func(ship_id: int) -> void:
		if selected_ship == ship_id:
			selected_ship = -1)
	_sync_view()

func _process(_delta: float) -> void:
	_sync_view()
	queue_redraw()

func _sync_view() -> void:
	var area: Vector2 = get_viewport_rect().size
	for asteroid_id: int in rocks.keys():
		if not fleet.asteroids.has(asteroid_id) or fleet.asteroid_region(asteroid_id) != fleet.regions.current_region:
			rocks.erase(asteroid_id)
	for asteroid_id: int in supply.home_asteroids:
		if not fleet.asteroids.has(asteroid_id) or fleet.asteroid_region(asteroid_id) != fleet.regions.current_region:
			continue
		var source: Dictionary = supply.home_asteroids[asteroid_id]
		rocks[asteroid_id] = {"point": Vector2(source.position.x * (area.x - 380.0), 150.0 + source.position.y * (area.y - 276.0)), "angle": fmod(asteroid_id * 2.399, TAU) + supply.elapsed * 0.06}
	# Reconstruct discovered markers from model state, even after recreating the view.
	for asteroid_id: int in fleet.asteroids:
		if fleet.asteroids[asteroid_id].get("persistent", false) and fleet.asteroid_region(asteroid_id) == fleet.regions.current_region:
			_add_discovery_marker(asteroid_id)
	asteroid_count = rocks.size()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for asteroid_id: int in rocks:
		if (get_canvas_transform().affine_inverse() * event.position).distance_to(rocks[asteroid_id].point) <= 34.0:
			var error: String = fleet.dispatch(asteroid_id, selected_ship)
			notice.emit("Mining Ship dispatched. Minerals arrive when the timer ends." if error.is_empty() else error, not error.is_empty())
			if error.is_empty():
				selected_ship = -1
			get_viewport().set_input_as_handled()
			return

func _on_completed(unit: Variant, asteroid_id: int, amount: int) -> void:
	var point: Vector2 = rocks[asteroid_id].point if rocks.has(asteroid_id) else board.center
	var region: String = fleet.model.locations.actor_record(fleet.model.locations.actor_for(unit)).region
	if region == fleet.regions.current_region:
		minerals_delivered.emit(amount, point)
	if region != fleet.regions.HOME:
		notice.emit("%s outpost: +%d local Minerals. Home storage unchanged." % [fleet.regions.catalog[region].name, amount], false)
	else:
		notice.emit("+%d Minerals. Auto-mining continues." % amount if fleet.jobs.has(unit) else "Mining complete: +%d Minerals. Ship ready." % amount, false)
	if not fleet.asteroids.has(asteroid_id):
		rocks.erase(asteroid_id)
	asteroid_count = rocks.size()

func _draw() -> void:
	for ship_id: int in fleet.model.ships:
		if fleet.transport.location(ship_id) != fleet.regions.current_region:
			continue
		if fleet.transport.jobs.has(ship_id):
			var point: Vector2 = ship_position(ship_id)
			var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
			ModuleArt.draw_module(self, point, definition.get("art", "scout"), 0.55, 0.5)
			draw_string(font, point + Vector2(-30, 40), "In transit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ORE)
			continue
		if fleet.collection != null and fleet.collection.jobs.has(ship_id):
			continue
		var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
		if not fleet.jobs.has(ship_id):
			var point: Vector2 = ship_position(ship_id)
			ModuleArt.draw_module(self, point, definition.get("art", "scout"), 0.55)
			var text: String = "%s #%d" % [definition.name, ship_id]
			if fleet.regions.survey_jobs.has(ship_id):
				text = "Scouting %ds" % fleet.regions.survey_jobs[ship_id].remaining
			elif fleet.survey_jobs.has(ship_id):
				text = "Survey %ds" % fleet.survey_jobs[ship_id].remaining
				draw_arc(point, 26, 0, TAU, 32, Color("8bcdf1"), 1.5, true)
			elif fleet.diplomacy.jobs.has(ship_id):
				text = "Trade %ds" % fleet.diplomacy.jobs[ship_id].remaining
				draw_arc(point, 26, 0, TAU, 32, Color("eebd76"), 1.5, true)
			draw_string(font, point + Vector2(-28, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(definition.color))
	for unit: Variant in fleet.jobs:
		var job: Dictionary = fleet.jobs[unit]
		if not rocks.has(job.target):
			continue
		var start: Vector2 = get_parent().ship_motion.origins.get(unit, home_position(unit))
		var target: Vector2 = rocks[job.target].point
		draw_dashed_line(start, target, Color(0.72, 0.62, 0.96, 0.4), 1.5, 7.0)
		var progress: float = 1.0 - float(job.remaining) / float(job.duration)
		var ship_point: Vector2 = ship_position(unit)
		ModuleArt.draw_module(self, ship_point, "mining_ship", 0.55)
		draw_arc(target, 34.0, -PI / 2, -PI / 2 + TAU * maxf(0.01, progress), 48, ORE, 3.0, true)
		draw_string(font, target + Vector2(-21, 51), "%ds" % job.remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ORE)
	# Legacy module-owned miners also finish their cosmetic return after the
	# model removes the job; hide the extra sprite once it reaches its module.
	for unit: Variant in get_parent().ship_motion.points:
		if unit is Vector2 and not fleet.jobs.has(unit) and fleet.regions.primary_station_visible():
			var point: Vector2 = ship_position(unit)
			if point.distance_to(home_position(unit)) > 1.0:
				ModuleArt.draw_module(self, point, "mining_ship", 0.55)
	for asteroid_id: int in rocks:
		if not fleet.asteroids.has(asteroid_id) or fleet.asteroid_region(asteroid_id) != fleet.regions.current_region:
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
	_sync_view()
	notice.emit("%s revealed. Open Sector map for the discovery report." % sector.name, false)

func _add_discovery_marker(asteroid_id: int) -> void:
	if fleet.asteroids[asteroid_id].has("region_id"):
		rocks[asteroid_id] = {"point": RegionView.project(fleet.asteroids[asteroid_id].position, get_viewport_rect().size), "angle": 0.2}
		return
	var logical: Vector2 = fleet.asteroids[asteroid_id].get("position", Fleet.discovery_position(asteroid_id))
	var area: Vector2 = get_viewport_rect().size
	rocks[asteroid_id] = {"point": Vector2(logical.x * (area.x - 380.0), 230.0 + logical.y * (area.y - 436.0)), "angle": 0.2}

func home_asteroid_count() -> int:
	return supply.home_asteroids.size()

func dock_point(id: int) -> Vector2:
	var reservation: Dictionary = fleet.docking.ships[id]
	var structure: Dictionary = fleet.model.locations.structures[reservation.dock_id]
	var point: Vector2 = board.world_to_screen(structure.position) if structure.region == fleet.regions.HOME else RegionView.project(structure.position, get_viewport_rect().size)
	var capacity: int = int(fleet.model.structure_definition(reservation.dock_id).docking.capacity)
	return point + Vector2((float(reservation.slot) - (capacity - 1) * 0.5) * 40.0, 38.0)

func ship_position(unit: Variant) -> Vector2:
	return get_parent().ship_motion.position_for(unit)
