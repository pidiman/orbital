extends Node2D

const DevConfig = preload("res://scripts/dev_config.gd")
var game: Node2D
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/threats.json"))
var threats: Dictionary = {}
var projectiles: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var turret_angles: Dictionary = {}
var turret_cooldowns: Dictionary = {}
var next_id: int = 1
var spawn_remaining: float = 45.0
var active: bool = true
var region_id: String = ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_priority = 8
	_set_region()

func _set_region() -> void:
	var next_region: String = game.fleet.regions.current_region
	if region_id == next_region: return
	region_id = next_region
	threats.clear()
	projectiles.clear()
	bursts.clear()
	turret_angles.clear()
	turret_cooldowns.clear()
	var record: Dictionary = game.fleet.regions.records.get(region_id, {})
	rng.seed = int(record.get("seed", 1)) ^ 0x5EED7
	spawn_remaining = _next_spawn_delay()

func set_threats_enabled(value: bool) -> void:
	active = value

func reset_transient() -> void:
	# Threat positions/projectiles are intentionally not part of v2 saves.
	threats.clear()
	projectiles.clear()
	bursts.clear()
	turret_angles.clear()
	turret_cooldowns.clear()
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
	_update_projectiles(delta)
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
		var definition: Dictionary = station.definition_at(point).defense_turret
		var target_id: int = _closest_threat(origin, float(definition.range))
		var desired: float = -PI / 2.0
		if target_id != -1: desired = (threats[target_id].position - origin).angle()
		turret_angles[structure_id] = rotate_toward(float(turret_angles.get(structure_id, desired)), desired, 3.8 * delta)
		var cooldown: float = maxf(0.0, float(turret_cooldowns.get(structure_id, 0.0)) - delta)
		if target_id != -1 and cooldown <= 0.0:
			_fire(structure_id, origin, target_id, definition)
			cooldown = float(definition.fire_seconds)
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

func _fire(structure_id: String, origin: Vector2, target_id: int, definition: Dictionary) -> void:
	var direction: Vector2 = (threats[target_id].position - origin).normalized()
	projectiles.append({"position": origin, "velocity": direction * float(definition.projectile_speed), "target_id": target_id, "turret_id": structure_id})

func _update_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for projectile: Dictionary in projectiles:
		var target_id: int = int(projectile.target_id)
		if target_id < 0 or not threats.has(target_id): continue
		var target: Vector2 = threats[target_id].position
		var step: Vector2 = projectile.velocity * delta
		if projectile.position.distance_to(target) <= step.length():
			threats[target_id].health -= 1
			if threats[target_id].health <= 0: _destroy(target_id)
			continue
		projectile.position += step
		remaining.append(projectile)
	projectiles = remaining

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
	if game.board.inspected_position != Vector2.INF and station.modules.has(game.board.inspected_position) and station.modules[game.board.inspected_position] == "defense_turret":
		var point: Vector2 = game.board.world_to_screen(game.board.inspected_position)
		var definition: Dictionary = station.definition_at(game.board.inspected_position).defense_turret
		draw_circle(point, float(definition.range), Color(0.94, 0.45, 0.32, 0.08), false, 1.5, true)
	for point: Vector2 in station.modules:
		if station.modules[point] != "defense_turret" or not station.is_module_active(point): continue
		var id: String = station.structure_id_at(point)
		var origin: Vector2 = game.board.world_to_screen(point)
		draw_set_transform(origin, float(turret_angles.get(id, -PI / 2.0)))
		draw_line(Vector2(0, 0), Vector2(0, -25), Color("ef8b67"), 5.0, true)
		draw_circle(Vector2(0, -25), 3.0, Color("ffb478"))
		draw_set_transform(Vector2.ZERO)
	for projectile: Dictionary in projectiles:
		var direction: Vector2 = projectile.velocity.normalized()
		draw_line(projectile.position - direction * 9.0, projectile.position + direction * 4.0, Color("ff9a70"), 3.0, true)
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
