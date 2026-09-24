extends Node
# View-only positions. Never advances jobs or writes model/save state.
const ModuleArt = preload("res://scripts/module_art.gd")
var game: Node2D
var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_motion.json"))
var points: Dictionary = {}
var angles: Dictionary = {}
var origins: Dictionary = {}
var missions: Dictionary = {}
var mining_states: Dictionary = {}
var visual_targets: Dictionary = {}
var visual_moving: Dictionary = {}
var visual_active: Dictionary = {}
var beam_active: Dictionary = {}
var regions: Dictionary = {}
var ship_kinds: Dictionary = {}
var mining_jobs: Dictionary = {}
var viewed_region: String = ""
var units: Array[Variant] = []
var units_dirty: bool = true
var jobs_dirty: bool = true
var alive_units: Dictionary = {}
var stale_units: Array[Variant] = []

func _ready() -> void:
	process_priority = 10 # After model clock/field layout, before following camera.
	get_viewport().size_changed.connect(reset)
	game.model.module_removed.connect(_module_removed)
	game.model.module_built.connect(_module_built)
	game.model.ship_built.connect(_ship_purchased)
	game.model.ship_removed.connect(_ship_removed)
	game.fleet.changed.connect(_jobs_changed)

func _ship_purchased(id: int) -> void:
	units_dirty = true
	jobs_dirty = true
	angles[id] = deg_to_rad(float(settings.idle_angle_degrees))
	points[id] = game.asteroids.home_position(id)
	origins[id] = points[id]
	regions[id] = game.model.locations.ship_region(id)

func reset() -> void:
	angles.clear()
	points.clear()
	origins.clear()
	missions.clear()
	mining_states.clear()
	visual_targets.clear()
	visual_moving.clear()
	visual_active.clear()
	beam_active.clear()
	regions.clear()
	units.clear()
	alive_units.clear()
	stale_units.clear()
	units_dirty = true
	jobs_dirty = true

func _module_removed(point: Vector2) -> void:
	units_dirty = true
	angles.erase(point)
	points.erase(point)
	origins.erase(point)
	missions.erase(point)
	mining_states.erase(point)
	visual_targets.erase(point)
	visual_moving.erase(point)
	visual_active.erase(point)
	beam_active.erase(point)
	regions.erase(point)

func _module_built(_point: Vector2, _kind: String) -> void:
	units_dirty = true
	# Dock/build changes can move a parked ship's resolved visual target.
	visual_targets.clear()

func _ship_removed(ship_id: int) -> void:
	units_dirty = true
	jobs_dirty = true
	angles.erase(ship_id)
	points.erase(ship_id)
	origins.erase(ship_id)
	missions.erase(ship_id)
	mining_states.erase(ship_id)
	visual_targets.erase(ship_id)
	visual_moving.erase(ship_id)
	visual_active.erase(ship_id)
	beam_active.erase(ship_id)
	regions.erase(ship_id)

func _jobs_changed() -> void:
	# MiningFleet.jobs is a compatibility getter that allocates a projection.
	# Refresh it once per model change, never once per rendered frame.
	jobs_dirty = true

func _refresh_units() -> void:
	units.clear()
	for unit: Variant in game.model.ships:
		units.append(unit)
	for structure: Dictionary in game.model.locations.structures.values():
		if structure.station_id == game.model.locations.primary_station() and game.model.catalog.get(structure.kind, {}).has("mining"):
			units.append(structure.position)
	units_dirty = false

func speed_for(unit: Variant) -> float:
	var kind: String = str(ship_kinds.get(unit, ""))
	return maxf(1.0, float(settings.ship_speeds.get(kind, settings.speed)))

func angle_for(unit: Variant) -> float:
	return float(angles.get(unit, deg_to_rad(float(settings.idle_angle_degrees))))

func position_for(unit: Variant) -> Vector2:
	return points.get(unit, game.asteroids.home_position(unit))

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	var fleet: RefCounted = game.fleet
	if viewed_region != fleet.regions.current_region:
		reset()
		viewed_region = fleet.regions.current_region
	# Keep the canonical dictionaries by reference and rebuild the compatibility
	# projection only when MiningFleet emits a change. The unit list is likewise
	# invalidated only by ship/module topology changes.
	ship_kinds = game.model.ships
	if jobs_dirty:
		mining_jobs = fleet.jobs
		jobs_dirty = false
	if units_dirty:
		_refresh_units()
	alive_units.clear()
	for unit: Variant in units:
		alive_units[unit] = true
		var region: String = fleet.transport.location(unit) if unit is int else fleet.regions.HOME
		if region != viewed_region: continue
		if regions.get(unit, region) != region:
			angles.erase(unit)
			points.erase(unit)
			origins.erase(unit)
			missions.erase(unit)
		regions[unit] = region
		var mission: String = mission_key(unit)
		var mission_changed: bool = missions.get(unit, "") != mission
		if mission_changed:
			origins[unit] = position_for(unit)
			missions[unit] = mission
			if mining_jobs.has(unit): _set_mining_state(unit, "FLYING_TO")
		# Targets for parked/idle ships are stable. Reuse the last resolved target
		# instead of traversing every job registry and rebuilding screen positions
		# on every rendered frame. Active missions still resolve their target each
		# tick so movement and beams remain responsive.
		var target: Vector2
		if mission_changed or not visual_targets.has(unit) or not mission.is_empty():
			target = target_for(unit)
			visual_targets[unit] = target
		else:
			target = Vector2(visual_targets[unit])
		_update_mining_state(unit, target)
		var distance_to_target: float = Vector2(points.get(unit, origins.get(unit, target))).distance_to(target)
		var repairing: bool = fleet.repairs != null and fleet.repairs.jobs.has(unit) and str(fleet.repairs.jobs[unit].get("phase", "")) == "repairing"
		var arrived: bool = points.has(unit) and Vector2(points[unit]).distance_to(target) <= float(settings.get("facing_arrival_distance", 1.0))
		beam_active[unit] = beam_visible_for(mining_state(unit), arrived) or (repairing and arrived)
		visual_moving[unit] = not mission.is_empty() and distance_to_target > float(settings.facing_arrival_distance)
		visual_active[unit] = bool(visual_moving[unit]) or bool(beam_active[unit])
		# Idle ships at their resolved destination have no visual state to update.
		# They are still present in the cached unit list and redraw when selection
		# or camera state changes, but avoid repeated math and dictionary writes.
		if not visual_active[unit] and points.has(unit) and Vector2(points[unit]).distance_to(target) <= float(settings.facing_arrival_distance):
			continue
		var direction: Vector2 = target - Vector2(points.get(unit, origins.get(unit, game.asteroids.home_position(unit))))
		var busy: bool = not mission.is_empty()
		var desired: float = angle_for(unit) if busy else deg_to_rad(float(settings.idle_angle_degrees))
		if direction.length() > float(settings.facing_arrival_distance):
			desired = direction.angle() + PI / 2.0 # All current ship art noses point up.
		if not points.has(unit) and not busy:
			desired = deg_to_rad(float(settings.idle_angle_degrees))
		if not angles.has(unit):
			angles[unit] = desired
		else:
			angles[unit] = rotate_toward(float(angles[unit]), desired, deg_to_rad(float(settings.turn_speed_degrees)) * clampf(delta, 0.0, float(settings.max_frame_delta)))
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
	stale_units.clear()
	for unit: Variant in points:
		if not alive_units.has(unit):
			stale_units.append(unit)
	for unit: Variant in stale_units:
		if not alive_units.has(unit):
			angles.erase(unit)
			points.erase(unit)
			origins.erase(unit)
			missions.erase(unit)
			mining_states.erase(unit)
			regions.erase(unit)
			visual_targets.erase(unit)
			visual_moving.erase(unit)
			visual_active.erase(unit)
			beam_active.erase(unit)

func _update_mining_state(unit: Variant, target: Vector2) -> void:
	var next_state: String = "IDLE"
	if mining_jobs.has(unit):
		var job: Dictionary = mining_jobs[unit]
		var arrived: bool = points.has(unit) and Vector2(points[unit]).distance_to(target) <= float(settings.get("facing_arrival_distance", 1.0))
		if returning(job):
			next_state = "FLYING_BACK"
		# Visual movement eases toward the stop point and may never become
		# bit-for-bit equal. Treat the configured arrival radius as arrival so
		# extraction can begin and its beam can render.
		elif arrived:
			next_state = "EXTRACTING"
		else:
			next_state = "FLYING_TO"
	_set_mining_state(unit, next_state)

func _set_mining_state(unit: Variant, next_state: String) -> void:
	if mining_states.get(unit, "") == next_state: return
	mining_states[unit] = next_state
	# A transition invalidates the cached visual state immediately. The next
	# visual tick recomputes beam visibility from the new state and arrival.
	beam_active[unit] = false
	visual_active[unit] = true
	# Stationary extraction is intentionally outside the movement fast path.
	# Invalidate the asteroid view explicitly when the beam state changes.
	if is_instance_valid(game) and is_instance_valid(game.asteroids): game.asteroids.queue_redraw()

static func beam_visible_for(state: String, arrived: bool) -> bool:
	return arrived and state in ["EXTRACTING", "REPAIRING"]

func mining_state(unit: Variant) -> String:
	return str(mining_states.get(unit, "IDLE"))

func is_moving(unit: Variant) -> bool:
	return bool(visual_moving.get(unit, false))

func is_visual_active(unit: Variant) -> bool:
	return bool(visual_active.get(unit, false))

func is_beam_active(unit: Variant) -> bool:
	return bool(beam_active.get(unit, false))

func draw_exhaust(canvas: CanvasItem, unit: Variant, center: Vector2, kind: String, scale_factor: float, facing: float, accent: Color) -> void:
	if not is_moving(unit): return
	ModuleArt.draw_exhaust(canvas, center, kind, scale_factor, facing, accent, settings.get("exhaust", {}))

func mission_key(unit: Variant) -> String:
	var fleet: RefCounted = game.fleet
	if mining_jobs.has(unit): return "mining:" + str(mining_jobs[unit].target)
	if fleet.transport.jobs.has(unit): return "gate:" + str(fleet.transport.jobs[unit].destination)
	if fleet.cargo != null and fleet.cargo.routes.has(unit): return "cargo:" + str(fleet.cargo.routes[unit].phase) + ":" + str(fleet.cargo.routes[unit].destination)
	if fleet.hauling.jobs.has(unit): return "hauling:" + str(fleet.hauling.jobs[unit].refinery_id)
	if fleet.repairs != null and fleet.repairs.jobs.has(unit): return "repair:" + str(fleet.repairs.jobs[unit].target)
	if fleet.collection.jobs.has(unit): return "collection"
	if fleet.diplomacy.jobs.has(unit): return "trade:" + str(fleet.diplomacy.jobs[unit].id)
	if fleet.regions.survey_jobs.has(unit): return "region:" + str(fleet.regions.survey_jobs[unit].region_id)
	return ""

func returning(job: Dictionary) -> bool:
	return float(job.remaining) <= float(job.duration) * float(settings.return_fraction)

func target_for(unit: Variant) -> Vector2:
	var fleet: RefCounted = game.fleet
	var origin: Vector2 = origins.get(unit, game.asteroids.home_position(unit))
	if fleet.transport.jobs.has(unit):
		return game.board.world_to_screen(fleet.transport.jobs[unit].gate)
	if fleet.cargo != null and fleet.cargo.routes.has(unit):
		var cargo_route: Dictionary = fleet.cargo.routes[unit]
		if cargo_route.phase in ["loading", "unloading"]: return game.board.world_to_screen(Vector2.ZERO) + Vector2(0, 30)
	if fleet.hauling.jobs.has(unit):
		var job: Dictionary = fleet.hauling.jobs[unit]
		var target: Vector2 = Vector2.ZERO
		if job.phase == "pickup" and fleet.model.locations.structures.has(job.refinery_id): target = fleet.model.locations.structures[job.refinery_id].position
		return game.board.world_to_screen(target) + Vector2(0, 30)
	if fleet.repairs != null and fleet.repairs.jobs.has(unit):
		var repair_job: Dictionary = fleet.repairs.jobs[unit]
		if fleet.model.locations.structures.has(repair_job.target):
			var repair_structure: Dictionary = fleet.model.locations.structures[repair_job.target]
			var approach: Vector2 = game.board.world_to_screen(repair_structure.position) - origin
			if approach.length() < 1.0: approach = Vector2.UP
			return game.board.world_to_screen(repair_structure.position) - approach.normalized() * float(fleet.model.ship_catalog[fleet.model.ships[unit]].repair.get("stop_offset", 58.0))
	if fleet.collection.jobs.has(unit):
		return game.get_node("MaterialShips").target_position(unit)
	if mining_jobs.has(unit):
		var job: Dictionary = mining_jobs[unit]
		if returning(job) or not game.asteroids.rocks.has(job.target): return origin
		var asteroid_point: Vector2 = game.asteroids.rocks[job.target].point
		var approach: Vector2 = asteroid_point - origin
		if approach.length() < 1.0: approach = Vector2.UP
		return asteroid_point - approach.normalized() * float(settings.get("mining_stop_offset", 58.0))
	if fleet.diplomacy.jobs.has(unit):
		if returning(fleet.diplomacy.jobs[unit]): return origin
		var trade_marker: Array = settings.mission_markers.trade
		var trade_area: Vector2 = game.get_viewport_rect().size
		# Cosmetic destinations: these jobs have no spatial destination model.
		return Vector2(40, 290) + Vector2(trade_marker[0], trade_marker[1]) * Vector2(maxf(300, trade_area.x - 480), maxf(180, trade_area.y - 440))
	if fleet.regions.survey_jobs.has(unit):
		if returning(fleet.regions.survey_jobs[unit]): return origin
		var survey_marker: Array = settings.mission_markers.regional_survey
		var survey_area: Vector2 = game.get_viewport_rect().size
		return Vector2(40, 290) + Vector2(survey_marker[0], survey_marker[1]) * Vector2(maxf(300, survey_area.x - 480), maxf(180, survey_area.y - 440))
	if unit is int and fleet.docking.status(unit) == "parked": return game.asteroids.dock_point(unit)
	return game.asteroids.home_position(unit)
