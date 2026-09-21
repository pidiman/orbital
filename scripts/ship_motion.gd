extends Node
# View-only positions. Never advances jobs or writes model/save state.
var game: Node2D
var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_motion.json"))
var points: Dictionary = {}
var origins: Dictionary = {}
var missions: Dictionary = {}
var regions: Dictionary = {}
var ship_kinds: Dictionary = {}
var mining_jobs: Dictionary = {}
var viewed_region: String = ""

func _ready() -> void:
	process_priority = 10 # After model clock/field layout, before following camera.
	get_viewport().size_changed.connect(reset)
	game.model.module_removed.connect(_module_removed)

func reset() -> void:
	points.clear()
	origins.clear()
	missions.clear()
	regions.clear()

func _module_removed(point: Vector2) -> void:
	points.erase(point)
	origins.erase(point)
	missions.erase(point)
	regions.erase(point)

func speed_for(unit: Variant) -> float:
	var kind: String = str(ship_kinds.get(unit, ""))
	return maxf(1.0, float(settings.ship_speeds.get(kind, settings.speed)))

func position_for(unit: Variant) -> Vector2:
	return points.get(unit, game.asteroids.home_position(unit))

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	var fleet: RefCounted = game.fleet
	if viewed_region != fleet.regions.current_region:
		reset()
		viewed_region = fleet.regions.current_region
	# Copy legacy projections once per frame, not once per ship.
	ship_kinds = game.model.ships
	mining_jobs = fleet.jobs
	var units: Array = ship_kinds.keys()
	for structure: Dictionary in game.model.locations.structures.values():
		if structure.station_id == game.model.locations.primary_station() and game.model.catalog.get(structure.kind, {}).has("mining"):
			units.append(structure.position)
	var alive: Dictionary = {}
	for unit: Variant in units:
		alive[unit] = true
		var region: String = fleet.transport.location(unit) if unit is int else fleet.regions.HOME
		if region != viewed_region: continue
		if regions.get(unit, region) != region:
			points.erase(unit)
			origins.erase(unit)
			missions.erase(unit)
		regions[unit] = region
		var mission: String = mission_key(unit)
		if missions.get(unit, "") != mission:
			origins[unit] = position_for(unit)
			missions[unit] = mission
		var target: Vector2 = target_for(unit)
		if not points.has(unit):
			# Newly created view/load/region: choose a valid current-phase point.
			points[unit] = target
		else:
			var step: float = clampf(delta, 0.0, float(settings.max_frame_delta))
			var distance: float = Vector2(points[unit]).distance_to(target)
			# Ease small supply/timer target updates instead of reaching each
			# quantized point in one frame and pausing until the next model tick.
			var eased: float = distance * (1.0 - exp(-float(settings.follow_rate) * step))
			points[unit] = Vector2(points[unit]).move_toward(target, minf(eased, speed_for(unit) * step))
	for unit: Variant in points.keys():
		if not alive.has(unit):
			points.erase(unit)
			origins.erase(unit)
			missions.erase(unit)
			regions.erase(unit)

func mission_key(unit: Variant) -> String:
	var fleet: RefCounted = game.fleet
	if mining_jobs.has(unit): return "mining:" + str(mining_jobs[unit].target)
	if fleet.transport.jobs.has(unit): return "gate:" + str(fleet.transport.jobs[unit].destination)
	if fleet.hauling.jobs.has(unit): return "hauling:" + str(fleet.hauling.jobs[unit].refinery_id)
	if fleet.collection.jobs.has(unit): return "collection"
	if fleet.diplomacy.jobs.has(unit): return "trade:" + str(fleet.diplomacy.jobs[unit].id)
	if fleet.survey_jobs.has(unit): return "survey:" + str(fleet.survey_jobs[unit].sector_id)
	if fleet.regions.survey_jobs.has(unit): return "region:" + str(fleet.regions.survey_jobs[unit].region_id)
	return ""

func returning(job: Dictionary) -> bool:
	return float(job.remaining) <= float(job.duration) * float(settings.return_fraction)

func target_for(unit: Variant) -> Vector2:
	var fleet: RefCounted = game.fleet
	var origin: Vector2 = origins.get(unit, game.asteroids.home_position(unit))
	if fleet.transport.jobs.has(unit):
		return game.board.world_to_screen(fleet.transport.jobs[unit].gate)
	if fleet.hauling.jobs.has(unit):
		var job: Dictionary = fleet.hauling.jobs[unit]
		var target: Vector2 = Vector2.ZERO
		if job.phase == "pickup" and fleet.model.locations.structures.has(job.refinery_id): target = fleet.model.locations.structures[job.refinery_id].position
		return game.board.world_to_screen(target) + Vector2(0, 30)
	if fleet.collection.jobs.has(unit):
		return game.get_node("MaterialShips").target_position(unit)
	if mining_jobs.has(unit):
		var job: Dictionary = mining_jobs[unit]
		if returning(job) or not game.asteroids.rocks.has(job.target): return origin
		return game.asteroids.rocks[job.target].point + Vector2(0, 30)
	for pair: Array in [[fleet.diplomacy.jobs, "trade"], [fleet.survey_jobs, "survey"], [fleet.regions.survey_jobs, "regional_survey"]]:
		if pair[0].has(unit):
			if returning(pair[0][unit]): return origin
			var marker: Array = settings.mission_markers[pair[1]]
			var area: Vector2 = game.get_viewport_rect().size
			# Cosmetic destinations: these jobs have no spatial destination model.
			return Vector2(40, 290) + Vector2(marker[0], marker[1]) * Vector2(maxf(300, area.x - 480), maxf(180, area.y - 440))
	if unit is int and fleet.docking.status(unit) == "parked": return game.asteroids.dock_point(unit)
	return game.asteroids.home_position(unit)
