class_name RegionSupply
extends RefCounted

# Dimensionless region coordinates; no viewport, camera, nodes, or screen pixels.
const Collection = preload("res://scripts/material_collection.gd")
const FLOATING_FIELDS: Array[String] = ["floating"]
var floating: Dictionary = {}
var floating_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/floating_resources.json"))
var collection: Collection
var model: StationModel
var fleet: MiningFleet
var rules: Dictionary
var debris: Dictionary = {}
var home_asteroids: Dictionary = {}
var next_debris_id: int = 0
var next_home_id: int = 0
var elapsed: float = 0.0
var pending: float = 0.0
var debris_elapsed: float = 0.0
var asteroid_elapsed: float = 0.0
# View projections rebuild on simulation changes, not once per rendered frame.
# This is transient and intentionally excluded from save fields.
var presentation_revision: int = 0
var rng := RandomNumberGenerator.new()

func _init(station: StationModel, mining_fleet: MiningFleet, seed_value: int = -1, configuration: Dictionary = {}, floating_configuration: Dictionary = {}) -> void:
	if not floating_configuration.is_empty(): floating_rules = floating_configuration.duplicate(true)
	model = station
	fleet = mining_fleet
	collection = Collection.new(station, mining_fleet, self)
	fleet.collection = collection
	fleet.completed.connect(_on_mined)
	rules = configuration.duplicate(true) if not configuration.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://data/supply.json"))
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	ensure_floating_region(fleet.regions.HOME)
	for index in range(int(rules.asteroids.initial_count)):
		_spawn_asteroid(true)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	pending += delta
	var step: float = float(rules.step_seconds)
	while pending + 0.0000001 >= step:
		pending -= step
		_step(step)

func _step(delta: float) -> void:
	elapsed += delta
	presentation_revision += 1
	advance_floating(delta)
	sync_mining_nodes()
	collection.advance(delta)
	for debris_id: int in debris.keys():
		var piece: Dictionary = debris[debris_id]
		piece.position += piece.velocity * delta
		if piece.position.x > float(rules.debris.exit_x) or piece.position.y < float(rules.debris.min_y) or piece.position.y > float(rules.debris.max_y):
			debris.erase(debris_id)
	for asteroid_id: int in home_asteroids.keys():
		if not fleet.asteroids.has(asteroid_id):
			home_asteroids.erase(asteroid_id)
			continue
		var rock: Dictionary = home_asteroids[asteroid_id]
		if fleet.asteroids[asteroid_id].claimed:
			continue
		var next_x: float = rock.position.x + float(rock.speed) * delta
		for other_id: int in home_asteroids:
			var other: Dictionary = home_asteroids[other_id]
			if other_id != asteroid_id and other.position.y == rock.position.y and other.position.x > rock.position.x:
				next_x = minf(next_x, maxf(rock.position.x, other.position.x - float(rules.asteroids.spacing)))
		rock.position.x = next_x
		if rock.position.x > float(rules.asteroids.exit_x) and fleet.remove_asteroid(asteroid_id):
			home_asteroids.erase(asteroid_id)
	debris_elapsed += delta
	asteroid_elapsed += delta
	if debris_elapsed + 0.0000001 >= float(rules.debris.spawn_seconds):
		debris_elapsed -= float(rules.debris.spawn_seconds)
		# Legacy debris continues drifting; replacement comes from the regional pool.
	if asteroid_elapsed + 0.0000001 >= float(rules.asteroids.spawn_seconds):
		asteroid_elapsed -= float(rules.asteroids.spawn_seconds)
		if home_asteroids.size() < int(rules.asteroids.max_count):
			_spawn_asteroid()

func _spawn_debris(_initial: bool = false, region_id: String = "home") -> void:
	# One generator for all floating pickups, using the region's saved RNG stream.
	var record: Dictionary = fleet.regions.records[region_id]
	var random := RandomNumberGenerator.new()
	random.seed = int(record.seed)
	random.state = int(record.rng_state)
	var total: float = 0.0
	for definition: Dictionary in floating_rules.types.values(): total += float(definition.weight)
	var roll: float = random.randf() * total
	var resource: String = "materials"
	for kind: String in floating_rules.types:
		roll -= float(floating_rules.types[kind].weight)
		if roll < 0.0:
			resource = kind
			break
	var definition: Dictionary = floating_rules.types[resource]
	# Draw a uniform annulus around the local station/outpost. Sampling area
	# rather than a rectangle keeps pickups scattered and keeps their minimum
	# distance from the station predictable. Rejection keeps every point inside
	# the playable logical map, including the off-center outpost projection.
	var position: Vector2 = _spawn_position(random, region_id)
	next_debris_id += 1
	floating[region_id].pieces[next_debris_id] = {"position": position, "velocity": Vector2.ZERO, "resource": resource, "amount": random.randi_range(int(definition.amount_min), int(definition.amount_max)), "remaining": float(definition.get("lifetime_seconds", floating_rules.lifetime_seconds))}
	var variants: Array = definition.get("visual_variants", [])
	if not variants.is_empty():
		# Fork the per-region seeded stream: visual rolls never shift economy draws.
		var visual_random := RandomNumberGenerator.new()
		visual_random.seed = int(record.seed)
		visual_random.state = random.state
		floating[region_id].pieces[next_debris_id]["visual_variant"] = variants[visual_random.randi_range(0, variants.size() - 1)]
	record.rng_state = str(random.state)
	sync_mining_nodes()

func _spawn_position(random: RandomNumberGenerator, region_id: String) -> Vector2:
	var zones: Dictionary = floating_rules.get("spawn_zone", {})
	var zone_name: String = "home" if region_id == fleet.regions.HOME else "outpost"
	var zone: Dictionary = zones.get(zone_name, {})
	var center_values: Array = zone.get("center", [0.5, 0.5])
	var center := Vector2(float(center_values[0]), float(center_values[1]))
	var min_radius: float = maxf(0.0, float(zone.get("min_radius", 0.18)))
	var max_radius: float = maxf(min_radius, float(zone.get("max_radius", 0.4)))
	var edge_margin: float = clampf(float(zones.get("edge_margin", 0.04)), 0.0, 0.45)
	for _attempt in range(32):
		var angle: float = random.randf_range(0.0, TAU)
		# sqrt produces an even spread over the annulus area, avoiding a ring.
		var radius: float = sqrt(random.randf_range(min_radius * min_radius, max_radius * max_radius))
		var candidate := center + Vector2.from_angle(angle) * radius
		if candidate.x >= edge_margin and candidate.x <= 1.0 - edge_margin and candidate.y >= edge_margin and candidate.y <= 1.0 - edge_margin:
			return candidate
	# The fallback is still in-bounds if a future zone is tuned too close to an edge.
	return center.clamp(Vector2(edge_margin, edge_margin), Vector2(1.0 - edge_margin, 1.0 - edge_margin))

func ensure_floating_region(region_id: String) -> void:
	if floating.has(region_id) or not fleet.regions.is_discovered(region_id): return
	floating[region_id] = {"pieces": {}, "timer": 0.0}
	for index in range(int(floating_rules.initial_count)): _spawn_debris(true, region_id)

func advance_floating(delta: float) -> void:
	for region_id: String in fleet.regions.records:
		if not fleet.regions.is_discovered(region_id): continue
		ensure_floating_region(region_id)
		var pool: Dictionary = floating[region_id]
		for id: int in pool.pieces.keys():
			var target: int = mining_target(region_id, id)
			if target != -1 and fleet.asteroids.get(target, {}).get("claimed", false): continue
			pool.pieces[id].remaining -= delta
			if pool.pieces[id].remaining <= 0.0:
				pool.pieces.erase(id)
				if target != -1:
					fleet.asteroids.erase(target)
					fleet.resource_targets.erase(target)
		pool.timer += delta
		if pool.timer + 0.0000001 >= float(floating_rules.spawn_seconds):
			# The epsilon comparison can fire a few ulps early; keep saves valid.
			pool.timer = maxf(0.0, pool.timer - float(floating_rules.spawn_seconds))
			if pool.pieces.size() < int(floating_rules.max_count): _spawn_debris(false, region_id)

func _spawn_asteroid(initial: bool = false) -> void:
	next_home_id += 1
	var definition: Dictionary = rules.asteroids
	home_asteroids[next_home_id] = {"position": Vector2(float(definition.initial_x) if initial else float(definition.entry_x), 0.0 if next_home_id % 2 == 1 else 1.0), "speed": rng.randf_range(definition.speed_min, definition.speed_max)}
	fleet.register_asteroid(next_home_id, int(definition.minerals))

func spawn_loot(region_id: String, position: Vector2, resource: String, amount: int) -> int:
	# Threat rewards enter the same floating-resource pool used by salvage and
	# Material Ships; only the source event is different.
	if not floating_rules.types.has(resource) or amount < 1 or not fleet.regions.is_discovered(region_id): return -1
	ensure_floating_region(region_id)
	next_debris_id += 1
	var definition: Dictionary = floating_rules.types[resource]
	floating[region_id].pieces[next_debris_id] = {
		"position": position.clamp(Vector2(0.01, 0.01), Vector2(0.99, 0.99)),
		"velocity": Vector2.ZERO,
		"resource": resource,
		"amount": amount,
		"remaining": float(definition.get("lifetime_seconds", floating_rules.lifetime_seconds))
	}
	var variants: Array = definition.get("visual_variants", [])
	if not variants.is_empty():
		var visual_random := RandomNumberGenerator.new()
		visual_random.seed = int(fleet.regions.records[region_id].seed) ^ next_debris_id
		floating[region_id].pieces[next_debris_id]["visual_variant"] = variants[visual_random.randi_range(0, variants.size() - 1)]
	presentation_revision += 1
	sync_mining_nodes()
	return next_debris_id

func salvage(debris_id: int, receiver: Callable = Callable(), limit: int = -1, region_id: String = "home") -> int:
	var available: Dictionary = debris_in(region_id)
	if not available.has(debris_id): return 0
	var piece: Dictionary = available[debris_id]
	var resource: String = str(piece.get("resource", "materials"))
	if floating_rules.types.get(resource, {}).get("requires_mining", false): return 0
	# Existing ship cargo is Materials-only; do not mislabel other resources.
	if receiver.is_valid() and resource != "materials": return 0
	var amount: int = int(piece.amount) if limit < 0 else mini(int(piece.amount), limit)
	var received: int = 0
	if receiver.is_valid(): received = int(receiver.call(amount))
	else:
		var destination_record: Dictionary = destination_for_region(region_id)
		if destination_record.is_empty(): return 0
		var deliver_amount: int = amount
		if destination_record.station_id != model.locations.primary_station() and resource == "materials":
			var local: StationModel = model.scoped_station(destination_record.station_id)
			deliver_amount = mini(amount, maxi(0, local.capacity - local.materials))
		if resource == "xenocrystal":
			# Xenocrystals remain a non-click-collectible mining resource, but keep
			# this routing correct for any future collectible configuration.
			received = fleet.diplomacy.receive_goods(resource, deliver_amount) if region_id == fleet.regions.HOME else model.locations.receive(destination_record, resource, deliver_amount)
		else: received = model.locations.receive(destination_record, resource, deliver_amount)
	piece.amount -= received
	if piece.amount == 0:
		if debris.has(debris_id): debris.erase(debris_id)
		if floating.has(region_id): floating[region_id].pieces.erase(debris_id)
	return received

func destination_for_region(region_id: String) -> Dictionary:
	if region_id == fleet.regions.HOME:
		return model.locations.destination(model.locations.primary_station())
	var outpost: String = model.locations.outpost_at(region_id, model.locations.rules.primary_station.owner)
	return {} if outpost.is_empty() else model.locations.destination(outpost)

func content_region() -> String:
	return str(model.locations.rules.collection.supply_region)

func debris_in(region_id: String) -> Dictionary:
	var result: Dictionary = debris.duplicate() if region_id == content_region() else {}
	if floating.has(region_id): result.merge(floating[region_id].pieces)
	return result

func validate_floating(data: Dictionary, records: Dictionary, allocator: int) -> String:
	var ids: Dictionary = {}
	for region: Variant in data:
		if not region is String or not records.has(region) or not records[region].discovered: return "Invalid floating-resource region."
		var pool: Variant = data[region]
		if not pool is Dictionary or not pool.get("pieces") is Dictionary or pool.pieces.size() > 10000: return "Invalid floating-resource pool."
		var timer: Variant = pool.get("timer")
		if not (timer is int or timer is float) or not is_finite(timer) or timer < 0.0: return "Invalid floating-resource clock."
		for id: Variant in pool.pieces:
			var piece: Variant = pool.pieces[id]
			if not id is int or id <= 0 or id > allocator or ids.has(id): return "Invalid floating-resource ID."
			ids[id] = true
			if not piece is Dictionary or not floating_rules.types.has(piece.get("resource", "")): return "Invalid floating-resource type."
			if not piece.get("position") is Vector2 or not piece.position.is_finite() or not piece.get("velocity") is Vector2 or not piece.velocity.is_finite(): return "Invalid floating-resource position."
			if piece.has("visual_variant") and not piece.visual_variant is String: return "Invalid floating visual variant."
			var amount: Variant = piece.get("amount")
			var remaining: Variant = piece.get("remaining")
			if not (amount is int or amount is float) or not is_finite(amount) or amount < 1 or amount != floor(amount) or amount > 9007199254740991: return "Invalid floating-resource amount."
			if not (remaining is int or remaining is float) or not is_finite(remaining) or remaining <= 0.0: return "Invalid floating-resource lifetime."
	return ""

func mining_target(region: String, piece_id: int) -> int:
	for target: int in fleet.resource_targets:
		var binding: Dictionary = fleet.resource_targets[target]
		if binding.region == region and binding.piece_id == piece_id: return target
	return -1

func sync_mining_nodes() -> void:
	for region: String in floating:
		for piece_id: int in floating[region].pieces:
			var piece: Dictionary = floating[region].pieces[piece_id]
			if not floating_rules.types[piece.resource].get("requires_mining", false) or mining_target(region, piece_id) != -1: continue
			var target: int = fleet.next_discovery_id
			fleet.next_discovery_id -= 1
			fleet.resource_targets[target] = {"region": region, "piece_id": piece_id, "resource": piece.resource}
			fleet.asteroids[target] = {"minerals": int(piece.amount), "claimed": false}

func _on_mined(_unit: Variant, target: int, _amount: int) -> void:
	if not fleet.resource_targets.has(target): return
	var binding: Dictionary = fleet.resource_targets[target]
	var pool: Dictionary = floating[binding.region].pieces
	if fleet.asteroids.has(target):
		pool[binding.piece_id].amount = fleet.asteroids[target].minerals
	else:
		pool.erase(binding.piece_id)
		fleet.resource_targets.erase(target)

func validate_mining_nodes(bindings: Dictionary, pools: Dictionary, fleet_data: Dictionary) -> String:
	var seen: Dictionary = {}
	for id: int in fleet_data.asteroids:
		if id < 0 and not fleet_data.asteroids[id].get("persistent", false) and not bindings.has(id): return "Missing resource mining binding."
	for id: Variant in bindings:
		var binding: Variant = bindings[id]
		if not id is int or id >= -1 or id <= fleet_data.next_discovery_id or not fleet_data.asteroids.has(id): return "Invalid resource mining target ID."
		if not binding is Dictionary or not binding.get("region") is String or not pools.has(binding.region) or not binding.get("piece_id") is int or not pools[binding.region].pieces.has(binding.piece_id): return "Missing floating mining node."
		var piece: Dictionary = pools[binding.region].pieces[binding.piece_id]
		if binding.get("resource") != piece.resource or not floating_rules.types[piece.resource].get("requires_mining", false): return "Invalid mining resource."
		var key: String = "%s/%s" % [binding.region, binding.piece_id]
		if seen.has(key): return "Duplicate floating mining node."
		seen[key] = true
		var rock: Dictionary = fleet_data.asteroids[id]
		if rock.minerals != piece.amount or rock.has("region_id") or rock.get("persistent", false): return "Mining node quantity or ownership mismatch."
	return ""
