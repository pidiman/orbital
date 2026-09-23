extends Node2D
const RegionView = preload("res://scripts/region_view.gd")
const Fleet = preload("res://scripts/mining_fleet.gd")
signal notice(text: String, error: bool)
signal minerals_delivered(amount: int, point: Vector2)

const Supply = preload("res://scripts/region_supply.gd")
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
var last_revision: int = -1
var last_region: String = ""
var beam_render_state: Dictionary = {}

func _ready() -> void:
	fleet.completed.connect(_on_completed)
	fleet.model.ship_removed.connect(func(ship_id: int) -> void:
		if selected_ship == ship_id:
			selected_ship = -1)
	_sync_view()

func _process(_delta: float) -> void:
	var region: String = supply.fleet.regions.current_region
	var needs_redraw: bool = false
	if last_revision != supply.presentation_revision or last_region != region:
		_sync_view()
		needs_redraw = true
	# Ship sprites and mining beams move continuously; static asteroid/content
	# geometry only needs the presentation revision invalidation above.
	for unit: Variant in get_parent().ship_motion.visual_active:
		if get_parent().ship_motion.is_visual_active(unit):
			needs_redraw = true
			break
	# Beam visibility is an explicit extraction/repair state, independent of
	# whether the ship has stopped moving at its visual offset.
	if not needs_redraw:
		for unit: Variant in get_parent().ship_motion.beam_active:
			if get_parent().ship_motion.is_beam_active(unit):
				needs_redraw = true
				break
	if needs_redraw:
		queue_redraw()

func _sync_view() -> void:
	last_revision = supply.presentation_revision
	last_region = supply.fleet.regions.current_region
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
	for target: int in fleet.resource_targets:
		var binding: Dictionary = fleet.resource_targets[target]
		if binding.region != fleet.regions.current_region: continue
		var piece: Dictionary = supply.floating[binding.region].pieces[binding.piece_id]
		rocks[target] = {"point": Vector2(piece.position.x * (area.x - 380.0), 145.0 + piece.position.y * (area.y - 255.0)), "angle": supply.elapsed * 0.06}
	asteroid_count = rocks.size()

func handle_click(point: Vector2) -> bool:
	for asteroid_id: int in rocks:
		if (get_canvas_transform().affine_inverse() * point).distance_to(rocks[asteroid_id].point) <= 34.0 * _marker_scale(asteroid_id):
			var assignment_ship: int = selected_ship
			if assignment_ship == -1:
				var highlighted: int = get_parent().hud.selected_ship_id
				if fleet.model.ships.has(highlighted) and fleet.model.ship_catalog[fleet.model.ships[highlighted]].has("mining"):
					assignment_ship = highlighted
			# Dispatch never changes the player's camera framing.
			get_parent().ship_camera.ship_id = -1
			var error: String = fleet.dispatch(asteroid_id, assignment_ship)
			notice.emit("Mining ship dispatched. %s arrive when the timer ends." % fleet.target_resource(asteroid_id).capitalize() if error.is_empty() else error, not error.is_empty())
			if error.is_empty():
				selected_ship = -1
			get_viewport().set_input_as_handled()
			return true
	return false

func _on_completed(unit: Variant, asteroid_id: int, amount: int) -> void:
	var point: Vector2 = rocks[asteroid_id].point if rocks.has(asteroid_id) else board.center
	var resource: String = fleet.mining_resource(unit)
	if resource != "minerals":
		var region: String = fleet.model.locations.actor_record(fleet.model.locations.actor_for(unit)).region
		notice.emit("+%d %s%s. Extraction complete." % [amount, resource.capitalize(), " in local outpost storage" if region != fleet.regions.HOME else ""], false)
		if not fleet.asteroids.has(asteroid_id): rocks.erase(asteroid_id)
		return
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
			get_parent().ship_motion.draw_exhaust(self, ship_id, point, definition.get("art", "scout"), _ship_scale(definition), get_parent().ship_motion.angle_for(ship_id), Color(definition.get("color", "8bcdf1")))
			ModuleArt.draw_module(self, point, definition.get("art", "scout"), _ship_scale(definition), 0.5, get_parent().ship_motion.angle_for(ship_id))
			draw_string(font, point + Vector2(-30, 40), "In transit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ORE)
			continue
		if fleet.collection != null and fleet.collection.jobs.has(ship_id):
			continue
		var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
		if not fleet.jobs.has(ship_id):
			var point: Vector2 = ship_position(ship_id)
			get_parent().ship_motion.draw_exhaust(self, ship_id, point, definition.get("art", "scout"), _ship_scale(definition), get_parent().ship_motion.angle_for(ship_id), Color(definition.get("color", "8bcdf1")))
			ModuleArt.draw_module(self, point, definition.get("art", "scout"), _ship_scale(definition), 1.0, get_parent().ship_motion.angle_for(ship_id))
			if fleet.repairs != null and fleet.repairs.jobs.has(ship_id):
				var repair_job: Dictionary = fleet.repairs.jobs[ship_id]
				if fleet.model.locations.structures.has(repair_job.target) and repair_job.phase == "repairing":
					var repair_target: Vector2 = get_parent().board.world_to_screen(fleet.model.locations.structures[repair_job.target].position)
					var repair_direction: Vector2 = repair_target - point
					if repair_direction.length() > 1.0:
						draw_line(point + repair_direction.normalized() * 9.0, repair_target, Color("9af0b1", 0.18), 7.0, true)
						draw_line(point + repair_direction.normalized() * 9.0, repair_target, Color("c9ffd4"), 1.8, true)
			var text: String = "%s #%d" % [definition.name, ship_id]
			if fleet.regions.survey_jobs.has(ship_id):
				text = "Scouting %ds" % fleet.regions.survey_jobs[ship_id].remaining
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
		if get_parent().preferences.values.show_ship_trajectories:
			draw_dashed_line(start, target, Color(0.72, 0.62, 0.96, 0.4), 1.5, 7.0)
		var progress: float = 1.0 - float(job.remaining) / float(job.duration)
		var ship_point: Vector2 = ship_position(unit)
		var mining_art: String = "mining_ship"
		if unit is int and fleet.model.ships.has(unit): mining_art = fleet.model.ship_catalog[fleet.model.ships[unit]].get("art", "mining_ship")
		var mining_definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[unit]] if unit is int and fleet.model.ships.has(unit) else {"color": "e8ad5b"}
		get_parent().ship_motion.draw_exhaust(self, unit, ship_point, mining_art, 0.55, get_parent().ship_motion.angle_for(unit), Color(mining_definition.get("color", "e8ad5b")))
		ModuleArt.draw_module(self, ship_point, mining_art, 0.55, 1.0, get_parent().ship_motion.angle_for(unit))
	# Beam visibility is state-gated: only the stationary extraction phase emits it.
		var extraction_state: String = get_parent().ship_motion.mining_state(unit)
		var beam_should_draw: bool = extraction_state == "EXTRACTING"
		var beam_trace: String = "VISIBLE" if beam_should_draw else "HIDDEN"
		if beam_render_state.get(unit, "") != beam_trace:
			beam_render_state[unit] = beam_trace
			print("Beam render ship %s: state=%s -> beam %s (AsteroidField._draw mining path)" % [str(unit), extraction_state, beam_trace])
		if beam_should_draw:
			var beam_color: Color = Color("62e4dc") if fleet.target_resource(job.target) == "xenocrystal" else Color("f0aa55")
			var beam_direction: Vector2 = target - ship_point
			if beam_direction.length() > 1.0:
				draw_line(ship_point + beam_direction.normalized() * 9.0, target, Color(beam_color, 0.18), 7.0, true)
				draw_line(ship_point + beam_direction.normalized() * 9.0, target, beam_color, 1.8, true)
		draw_arc(target, 34.0, -PI / 2, -PI / 2 + TAU * maxf(0.01, progress), 48, ORE, 3.0, true)
		draw_string(font, target + Vector2(-21, 51), "%ds" % job.remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ORE)
	# Legacy module-owned miners also finish their cosmetic return after the
	# model removes the job; hide the extra sprite once it reaches its module.
	for unit: Variant in get_parent().ship_motion.points:
		if unit is Vector2 and not fleet.jobs.has(unit) and fleet.regions.primary_station_visible():
			var point: Vector2 = ship_position(unit)
			if point.distance_to(home_position(unit)) > 1.0:
				ModuleArt.draw_module(self, point, "mining_ship", 0.55, 1.0, get_parent().ship_motion.angle_for(unit))
	for asteroid_id: int in rocks:
		if not fleet.asteroids.has(asteroid_id) or fleet.asteroid_region(asteroid_id) != fleet.regions.current_region:
			continue
		var rock: Dictionary = rocks[asteroid_id]
		var resource: String = fleet.target_resource(asteroid_id)
		var tint: Color = Color(supply.floating_rules.types[resource].color) if resource != "minerals" else ORE
		var point: Vector2 = rock.point
		var definition: Dictionary = supply.floating_rules.types.get(resource, {})
		if definition.get("visual", "") == "crystal":
			_draw_crystal(asteroid_id, point, tint, definition)
			continue
		var hovered: bool = get_global_mouse_position().distance_to(point) <= 34.0
		draw_circle(point, 34, Color(0.57, 0.39, 0.86, 0.17 if hovered else 0.07))
		var angle: float = fmod(float(asteroid_id) * 2.399 + supply.elapsed * 0.06, TAU)
		draw_set_transform(point, angle)
		var polygon := PackedVector2Array([Vector2(-24, -8), Vector2(-14, -25), Vector2(8, -27), Vector2(25, -10), Vector2(21, 15), Vector2(1, 26), Vector2(-22, 16)])
		draw_colored_polygon(polygon, Color("393249"))
		polygon.append(polygon[0])
		draw_polyline(polygon, tint, 2.0, true)
		draw_circle(Vector2(-8, -6), 7.0, Color("242738"))
		draw_circle(Vector2(10, 8), 5.0, Color("242738"))
		draw_polyline(PackedVector2Array([Vector2(-5, 15), Vector2(0, 5), Vector2(13, -5), Vector2(10, -18)]), Color("9273c5"), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		if not fleet.asteroids[asteroid_id].claimed:
			draw_string(font, point + Vector2(-41, 48), "%s · %d" % ["ORE" if resource == "minerals" else resource.to_upper(), fleet.asteroids[asteroid_id].minerals], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ORE)

func home_position(unit: Variant) -> Vector2:
	if unit is Vector2:
		return board.world_to_screen(unit)
	var ship: Dictionary = fleet.model.locations.ships.get(unit, {})
	if ship.has("purchase_position") and ship.region == fleet.model.locations.station_region(ship.station_id):
		return board.world_to_screen(ship.purchase_position) + Vector2(0, 30)
	var index: int = int(unit) - 1
	return Vector2(get_viewport_rect().size.x - 410.0 - int(index / 7.0) * 62, 235 + (index % 7) * 63)

func _ship_scale(definition: Dictionary) -> float:
	return 1.65 if definition.get("art", "") == "cargo_ship" else 0.55

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
	var point: Vector2 = board.world_to_screen(structure.position)
	var capacity: int = int(fleet.model.structure_definition(reservation.dock_id).docking.capacity)
	return point + Vector2((float(reservation.slot) - (capacity - 1) * 0.5) * 40.0, 38.0)

func ship_position(unit: Variant) -> Vector2:
	return get_parent().ship_motion.position_for(unit)

func _marker_scale(target: int) -> float:
	var definition: Dictionary = supply.floating_rules.types.get(fleet.target_resource(target), {})
	return float(definition.get("visual_scale", 1.0)) * board.cell_size / 58.0 if definition.get("visual", "") == "crystal" else 1.0

func _draw_crystal(target: int, point: Vector2, tint: Color, definition: Dictionary) -> void:
	# Constant world scale: camera zoom affects crystals exactly like modules.
	var scale_factor: float = _marker_scale(target)
	draw_set_transform(point, 0.0, Vector2.ONE * scale_factor)
	draw_circle(Vector2.ZERO, 32, Color(tint, 0.12))
	for shard: Dictionary in [{"offset": Vector2(-16, 5), "scale": 0.65}, {"offset": Vector2(16, 9), "scale": 0.55}, {"offset": Vector2.ZERO, "scale": 1.0}]:
		var shape := PackedVector2Array()
		for vertex: Vector2 in [Vector2(0, -29), Vector2(12, -9), Vector2(9, 16), Vector2(0, 27), Vector2(-11, 11), Vector2(-12, -9)]:
			shape.append(shard.offset + vertex * shard.scale)
		draw_colored_polygon(shape, tint.darkened(0.65))
		shape.append(shape[0])
		draw_polyline(shape, tint, 2.0, true)
		draw_line(shard.offset + Vector2(0, -29) * shard.scale, shard.offset + Vector2(0, 27) * shard.scale, tint.lightened(0.55), 1.5, true)
	var label: String = "%s · %d" % [definition.get("label", fleet.target_resource(target).capitalize()), fleet.asteroids[target].minerals]
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_rect(Rect2(-width * 0.5 - 4, 34, width + 8, 22), Color(0.02, 0.06, 0.09, 0.9))
	draw_string(font, Vector2(-width * 0.5, 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
	draw_set_transform(Vector2.ZERO)
