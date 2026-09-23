extends Node2D

const DevConfig = preload("res://scripts/dev_config.gd")
var game: Node2D
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/threats.json"))
var threats: Dictionary = {}
var projectiles: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var turret_angles: Dictionary = {}
var turret_cooldowns: Dictionary = {}
var silo_angles: Dictionary = {}
var silo_cooldowns: Dictionary = {}
var silo_tube_indices: Dictionary = {}
var next_id: int = 1
var spawn_remaining: float = 45.0
var active: bool = true
var region_id: String = ""
var rng := RandomNumberGenerator.new()
const TURRET_TURN_SPEED: float = 3.8
const TURRET_NEUTRAL_ANGLE: float = 0.0

func _ready() -> void:
	process_priority = 8
	_set_region()

func _set_region() -> void:
	var next_region: String = game.fleet.regions.current_region
	if region_id == next_region: return
	region_id = next_region
	threats.clear()
	projectiles.clear()
	missiles.clear()
	bursts.clear()
	turret_angles.clear()
	turret_cooldowns.clear()
	silo_angles.clear()
	silo_cooldowns.clear()
	silo_tube_indices.clear()
	var record: Dictionary = game.fleet.regions.records.get(region_id, {})
	rng.seed = int(record.get("seed", 1)) ^ 0x5EED7
	spawn_remaining = _next_spawn_delay()

func set_threats_enabled(value: bool) -> void:
	active = value

func reset_transient() -> void:
	# Threat positions/projectiles are intentionally not part of v2 saves.
	threats.clear()
	projectiles.clear()
	missiles.clear()
	bursts.clear()
	turret_angles.clear()
	turret_cooldowns.clear()
	silo_angles.clear()
	silo_cooldowns.clear()
	silo_tube_indices.clear()
	spawn_remaining = _next_spawn_delay()

func spawn_now() -> void:
	_spawn_threat("")

func _process(delta: float) -> void:
	if game == null or game.get_tree().paused: return
	_set_region()
	if DevConfig.DEBUG_MODE and active:
		spawn_remaining -= delta
		if spawn_remaining <= 0.0:
			var count: int = 1
			if rng.randf() < float(rules.spawn.wave_chance): count = rng.randi_range(int(rules.spawn.wave_size_min), int(rules.spawn.wave_size_max))
			for _index in range(count):
				if threats.size() >= int(rules.spawn.max_active): break
				_spawn_threat("")
			spawn_remaining = _next_spawn_delay()
	_move_threats(delta)
	_update_turrets(delta)
	_update_silos(delta)
	_update_projectiles(delta)
	_update_missiles(delta)
	for burst: Dictionary in bursts:
		burst.time += delta
	bursts = bursts.filter(func(item: Dictionary) -> bool: return item.time < 0.45)
	queue_redraw()

func _next_spawn_delay() -> float:
	return rng.randf_range(float(rules.spawn.interval_min), float(rules.spawn.interval_max))

func _spawn_threat(size_override: String) -> void:
	if threats.size() >= int(rules.spawn.max_active): return
	var size: String = size_override
	if size.is_empty():
		var roll: float = rng.randf()
		size = "small" if roll < 0.55 else ("medium" if roll < 0.88 else "large")
	var definition: Dictionary = rules.sizes[size]
	var area: Vector2 = get_viewport_rect().size
	var margin: float = float(rules.spawn.edge_margin)
	var position := Vector2.ZERO
	match rng.randi_range(0, 3):
		0: position = Vector2(-margin, rng.randf_range(80.0, area.y - 100.0))
		1: position = Vector2(area.x + margin, rng.randf_range(80.0, area.y - 100.0))
		2: position = Vector2(rng.randf_range(40.0, area.x - 40.0), -margin)
		_: position = Vector2(rng.randf_range(40.0, area.x - 40.0), area.y + margin)
	var target: Vector2 = game.board.center + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
	var velocity: Vector2 = (target - position).normalized() * rng.randf_range(float(definition.speed_min), float(definition.speed_max))
	var health: int = rng.randi_range(int(definition.health_min), int(definition.health_max))
	threats[next_id] = {"position": position, "velocity": velocity, "target": target, "size": size, "radius": float(definition.radius), "health": health, "max_health": health, "angle": velocity.angle() + PI / 2.0, "impact_emitted": false}
	next_id += 1

func _move_threats(delta: float) -> void:
	var area := get_viewport_rect().size
	var margin: float = float(rules.spawn.edge_margin) * 1.5
	for id: int in threats.keys():
		var threat: Dictionary = threats[id]
		threat.position += threat.velocity * delta
		threat.angle = threat.velocity.angle() + PI / 2.0
		if not threat.impact_emitted and threat.position.distance_to(threat.target) <= float(rules.spawn.impact_radius):
			_impact(id)
		elif not Rect2(-margin, -margin, area.x + margin * 2.0, area.y + margin * 2.0).has_point(threat.position):
			threats.erase(id)

func _impact(id: int) -> void:
	# Phase B hook: an impact currently has no damage consequence. The threat
	# keeps drifting so an undestroyed asteroid exits at the far edge naturally.
	if threats.has(id) and not threats[id].impact_emitted:
		threats[id].impact_emitted = true
		bursts.append({"position": threats[id].position, "time": 0.0, "color": Color("67727e")})

func _update_turrets(delta: float) -> void:
	if not game.board.visible: return
	var station: StationModel = game.board.model
	var live: Dictionary = {}
	for point: Vector2 in station.modules:
		if station.modules[point] != "defense_turret" or not station.is_module_active(point): continue
		var structure_id: String = station.structure_id_at(point)
		live[structure_id] = true
		var origin: Vector2 = game.board.world_to_screen(point)
		var definition: Dictionary = _turret_stats(station, point)
		var target_id: int = _closest_threat(origin, float(definition.get("range", 220.0)))
		# The barrel is drawn along local up (Vector2(0, -25)), so compensate
		# by PI/2 when converting the target direction into its visual rotation.
		var current_angle: float = float(turret_angles.get(structure_id, TURRET_NEUTRAL_ANGLE))
		if target_id != -1:
			var desired: float = (threats[target_id].position - origin).angle() + PI / 2.0
			current_angle = rotate_toward(current_angle, desired, TURRET_TURN_SPEED * delta)
		else:
			# A slow continuous scan keeps idle turrets visually active. It is
			# presentation-only and immediately gives way to target tracking.
			var scan_speed: float = float(rules.get("turret", {}).get("idle_scan_speed", 0.32))
			current_angle = fmod(current_angle + scan_speed * delta, TAU)
		turret_angles[structure_id] = current_angle
		var cooldown: float = maxf(0.0, float(turret_cooldowns.get(structure_id, 0.0)) - delta)
		if target_id != -1 and cooldown <= 0.0:
			_fire(structure_id, origin, target_id, definition)
			cooldown = float(definition.get("fire_seconds", 1.0))
		turret_cooldowns[structure_id] = cooldown
	for id: Variant in turret_angles.keys():
		if not live.has(id):
			turret_angles.erase(id)
			turret_cooldowns.erase(id)

func _closest_threat(origin: Vector2, range: float) -> int:
	var selected: int = -1
	var distance: float = range
	for id: int in threats:
		var candidate: float = origin.distance_to(threats[id].position)
		if candidate <= distance:
			distance = candidate
			selected = id
	return selected

func _update_silos(delta: float) -> void:
	if not game.board.visible: return
	var station: StationModel = game.board.model
	var live: Dictionary = {}
	for point: Vector2 in station.modules:
		if station.modules[point] != "missile_silo" or not station.is_module_active(point): continue
		var structure_id: String = station.structure_id_at(point)
		live[structure_id] = true
		var origin: Vector2 = game.board.world_to_screen(point)
		var definition: Dictionary = _silo_stats(station, point)
		var target_id: int = _closest_threat(origin, float(definition.get("range", 260.0)))
		var current_angle: float = float(silo_angles.get(structure_id, TURRET_NEUTRAL_ANGLE))
		if target_id != -1:
			var desired: float = (threats[target_id].position - origin).angle() + PI / 2.0
			current_angle = rotate_toward(current_angle, desired, TURRET_TURN_SPEED * delta)
		else:
			var scan_speed: float = float(rules.get("turret", {}).get("idle_scan_speed", 0.32))
			current_angle = fmod(current_angle + scan_speed * delta, TAU)
		silo_angles[structure_id] = current_angle
		var cooldown: float = maxf(0.0, float(silo_cooldowns.get(structure_id, 0.0)) - delta)
		if target_id != -1 and cooldown <= 0.0:
			_fire_missile(structure_id, origin, target_id, definition, int(silo_tube_indices.get(structure_id, 0)))
			silo_tube_indices[structure_id] = (int(silo_tube_indices.get(structure_id, 0)) + 1) % 3
			cooldown = float(definition.get("fire_seconds", 4.0))
		silo_cooldowns[structure_id] = cooldown
	for id: Variant in silo_cooldowns.keys():
		if not live.has(id):
			silo_cooldowns.erase(id)
			silo_angles.erase(id)
			silo_tube_indices.erase(id)

func _fire(structure_id: String, origin: Vector2, target_id: int, definition: Dictionary) -> void:
	if not threats.has(target_id): return
	var speed: float = maxf(1.0, float(definition.get("projectile_speed", 330.0)))
	var barrel_length: float = float(rules.get("turret", {}).get("barrel_length", 25.0))
	var barrel_angle: float = float(turret_angles.get(structure_id, TURRET_NEUTRAL_ANGLE))
	var direction: Vector2 = Vector2(0.0, -1.0).rotated(barrel_angle).normalized()
	var muzzle: Vector2 = origin + direction * barrel_length
	var distance: float = muzzle.distance_to(threats[target_id].position)
	# The locked target ID is authoritative. The projectile remains visible in
	# flight, then applies its hit when this travel time elapses; it does not
	# depend on a physics overlap with a moving asteroid.
	projectiles.append({
		"position": muzzle,
		"velocity": direction * speed,
		"speed": speed,
		"time_remaining": maxf(0.05, distance / speed),
		"target_id": target_id,
		"turret_id": structure_id
	})

func _turret_stats(station: StationModel, point: Vector2) -> Dictionary:
	# Tier upgrade dictionaries intentionally contain only changed fields. Merge
	# them over the base definition so unchanged stats remain available at T2+.
	var base: Dictionary = station.catalog.get("defense_turret", {}).get("defense_turret", {}).duplicate(true)
	var current: Dictionary = station.definition_at(point).get("defense_turret", {})
	for key: String in current:
		base[key] = current[key]
	return base

func _silo_stats(station: StationModel, point: Vector2) -> Dictionary:
	var base: Dictionary = station.catalog.get("missile_silo", {}).get("missile_silo", {}).duplicate(true)
	var current: Dictionary = station.definition_at(point).get("missile_silo", {})
	for key: String in current:
		base[key] = current[key]
	return base

func _fire_missile(structure_id: String, origin: Vector2, target_id: int, definition: Dictionary, tube_index: int) -> void:
	if not threats.has(target_id): return
	var speed: float = maxf(1.0, float(definition.get("projectile_speed", 150.0)))
	var launcher_angle: float = float(silo_angles.get(structure_id, TURRET_NEUTRAL_ANGLE))
	var tube_offset: float = float(tube_index - 1) * 10.0
	var direction: Vector2 = Vector2(0.0, -1.0).rotated(launcher_angle).normalized()
	var muzzle: Vector2 = origin + Vector2(tube_offset, -22.0).rotated(launcher_angle)
	var distance: float = muzzle.distance_to(threats[target_id].position)
	missiles.append({
		"position": muzzle,
		"velocity": direction * speed,
		"speed": speed,
		"time_remaining": maxf(0.08, distance / speed),
		"target_id": target_id,
		"silo_id": structure_id,
		"damage": maxi(1, int(definition.get("damage", 4)))
	})

func _update_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for projectile: Dictionary in projectiles:
		var target_id: int = int(projectile.target_id)
		if target_id < 0 or not threats.has(target_id): continue
		var target: Vector2 = threats[target_id].position
		var direction: Vector2 = (target - projectile.position).normalized()
		var speed: float = maxf(1.0, float(projectile.get("speed", 330.0)))
		projectile.velocity = direction * speed
		projectile.position += projectile.velocity * delta
		projectile.time_remaining = float(projectile.get("time_remaining", 0.0)) - delta
		# Arrival is time-based and tied to the locked target ID. If another
		# turret destroyed it or it left the map, the guard above discards this
		# projectile without applying damage.
		if float(projectile.time_remaining) <= 0.0:
			projectile.position = target
			threats[target_id].health -= 1
			if threats[target_id].health <= 0: _destroy(target_id)
			continue
		remaining.append(projectile)
	projectiles = remaining

func _update_missiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for missile: Dictionary in missiles:
		var target_id: int = int(missile.target_id)
		if target_id < 0 or not threats.has(target_id): continue
		var target: Vector2 = threats[target_id].position
		var direction: Vector2 = (target - missile.position).normalized()
		var speed: float = maxf(1.0, float(missile.get("speed", 150.0)))
		missile.velocity = direction * speed
		missile.position += missile.velocity * delta
		missile.time_remaining = float(missile.get("time_remaining", 0.0)) - delta
		# Missile arrival is tied to its locked target ID, matching turret
		# guaranteed-hit behavior while allowing the target to move visually.
		if float(missile.time_remaining) <= 0.0:
			missile.position = target
			threats[target_id].health -= int(missile.get("damage", 4))
			if threats[target_id].health <= 0: _destroy(target_id)
			continue
		remaining.append(missile)
	missiles = remaining

func _destroy(id: int) -> void:
	if not threats.has(id): return
	var threat: Dictionary = threats[id]
	var definition: Dictionary = rules.sizes[threat.size]
	var resource: String = "xenocrystal" if rng.randf() < float(definition.xenocrystal_chance) else ("minerals" if rng.randf() < 0.48 else "materials")
	var amount: int = 1 if resource == "xenocrystal" else rng.randi_range(int(definition.loot_min), int(definition.loot_max))
	var area: Vector2 = get_viewport_rect().size
	var logical := Vector2(clampf(threat.position.x / maxf(1.0, area.x - 380.0), 0.02, 0.98), clampf((threat.position.y - 145.0) / maxf(1.0, area.y - 255.0), 0.02, 0.98))
	game.supply.spawn_loot(region_id, logical, resource, amount)
	bursts.append({"position": threat.position, "time": 0.0, "color": Color("efb466")})
	threats.erase(id)
	game.hud.message("Turret destroyed a %s asteroid · +%d %s." % [threat.size, amount, resource.capitalize()])

func _draw() -> void:
	var station: StationModel = game.board.model
	if not game.board.visible: return
	if game.board.inspected_position != Vector2.INF and station.modules.has(game.board.inspected_position) and station.modules[game.board.inspected_position] in ["defense_turret", "missile_silo"]:
		var point: Vector2 = game.board.world_to_screen(game.board.inspected_position)
		var definition: Dictionary = _turret_stats(station, game.board.inspected_position) if station.modules[game.board.inspected_position] == "defense_turret" else _silo_stats(station, game.board.inspected_position)
		draw_circle(point, float(definition.get("range", 220.0)), Color(0.94, 0.45, 0.32, 0.08), false, 1.5, true)
	for point: Vector2 in station.modules:
		if station.modules[point] != "defense_turret" or not station.is_module_active(point): continue
		var id: String = station.structure_id_at(point)
		var origin: Vector2 = game.board.world_to_screen(point)
		var barrel_length: float = float(rules.get("turret", {}).get("barrel_length", 25.0))
		draw_set_transform(origin, float(turret_angles.get(id, TURRET_NEUTRAL_ANGLE)))
		draw_line(Vector2.ZERO, Vector2(0, -barrel_length), Color("ef8b67"), 5.0, true)
		draw_circle(Vector2(0, -barrel_length), 3.0, Color("ffb478"))
		draw_set_transform(Vector2.ZERO)
	for point: Vector2 in station.modules:
		if station.modules[point] != "missile_silo" or not station.is_module_active(point): continue
		var id: String = station.structure_id_at(point)
		var origin: Vector2 = game.board.world_to_screen(point)
		var barrel_length: float = 22.0
		draw_set_transform(origin, float(silo_angles.get(id, TURRET_NEUTRAL_ANGLE)))
		# Rotating upper rack: all three tubes track as one launcher.
		draw_circle(Vector2.ZERO, 14.0, Color("263b4a"))
		draw_circle(Vector2.ZERO, 14.0, Color("d97863"), false, 1.8, true)
		for x in [-10.0, 0.0, 10.0]:
			draw_line(Vector2(x, 3), Vector2(x, -barrel_length), Color("586a76"), 5.0, true)
			draw_circle(Vector2(x, -barrel_length), 3.0, Color("e9a070"))
		draw_set_transform(Vector2.ZERO)
	for projectile: Dictionary in projectiles:
		var direction: Vector2 = projectile.velocity.normalized()
		draw_line(projectile.position - direction * 9.0, projectile.position + direction * 4.0, Color("ff9a70"), 3.0, true)
	for missile: Dictionary in missiles:
		var direction: Vector2 = missile.velocity.normalized()
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([
			missile.position + direction * 7.0,
			missile.position - direction * 6.0 + side * 3.0,
			missile.position - direction * 6.0 - side * 3.0
		]), Color("d98c72"))
		draw_line(missile.position - direction * 7.0, missile.position - direction * 17.0, Color("ffb478", 0.75), 3.0, true)
		draw_circle(missile.position - direction * 18.0, 2.0, Color("fff1c2", 0.8))
	for id: int in threats:
		var threat: Dictionary = threats[id]
		draw_set_transform(threat.position, threat.angle)
		var radius: float = threat.radius
		var points := PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.85, -radius * 0.55), Vector2(radius, radius * 0.55), Vector2(radius * 0.25, radius), Vector2(-radius * 0.85, radius * 0.65), Vector2(-radius, -radius * 0.35)])
		draw_colored_polygon(points, Color("3a3437"))
		points.append(points[0])
		draw_polyline(points, Color("a06d58"), 1.8, true)
		draw_set_transform(Vector2.ZERO)
		var health_ratio: float = float(threat.health) / float(threat.max_health)
		draw_rect(Rect2(threat.position + Vector2(-radius, radius + 5), Vector2(radius * 2.0 * health_ratio, 2)), Color("ef8b67"))
	for burst: Dictionary in bursts:
		var progress: float = burst.time / 0.45
		draw_circle(burst.position, 8.0 + progress * 24.0, Color(burst.color, 0.55 * (1.0 - progress)), false, 2.0, true)
