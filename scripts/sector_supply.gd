class_name SectorSupply
extends RefCounted

# Dimensionless sector coordinates; no viewport, camera, nodes, or screen pixels.
const Collection = preload("res://scripts/material_collection.gd")
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
var rng := RandomNumberGenerator.new()

func _init(station: StationModel, mining_fleet: MiningFleet, seed_value: int = -1, configuration: Dictionary = {}) -> void:
	model = station
	fleet = mining_fleet
	collection = Collection.new(station, mining_fleet, self)
	fleet.collection = collection
	rules = configuration.duplicate(true) if not configuration.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://data/supply.json"))
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	for index in range(int(rules.debris.initial_count)):
		_spawn_debris(true)
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
		if debris.size() < int(rules.debris.max_count):
			_spawn_debris()
	if asteroid_elapsed + 0.0000001 >= float(rules.asteroids.spawn_seconds):
		asteroid_elapsed -= float(rules.asteroids.spawn_seconds)
		if home_asteroids.size() < int(rules.asteroids.max_count):
			_spawn_asteroid()

func _spawn_debris(initial: bool = false) -> void:
	next_debris_id += 1
	var definition: Dictionary = rules.debris
	var x: float = rng.randf_range(definition.initial_x_min, definition.initial_x_max) if initial else float(definition.entry_x)
	debris[next_debris_id] = {"position": Vector2(x, rng.randf()), "velocity": Vector2(rng.randf_range(definition.speed_x_min, definition.speed_x_max), rng.randf_range(definition.speed_y_min, definition.speed_y_max)), "amount": rng.randi_range(int(definition.amount_min), int(definition.amount_max))}

func _spawn_asteroid(initial: bool = false) -> void:
	next_home_id += 1
	var definition: Dictionary = rules.asteroids
	home_asteroids[next_home_id] = {"position": Vector2(float(definition.initial_x) if initial else float(definition.entry_x), 0.0 if next_home_id % 2 == 1 else 1.0), "speed": rng.randf_range(definition.speed_min, definition.speed_max)}
	fleet.register_asteroid(next_home_id, int(definition.minerals))

func salvage(debris_id: int, receiver: Callable = Callable(), limit: int = -1) -> int:
	if not debris.has(debris_id):
		return 0
	var piece: Dictionary = debris[debris_id]
	var amount: int = int(piece.amount) if limit < 0 else mini(int(piece.amount), limit)
	var received: int = model.collect(amount) if not receiver.is_valid() else int(receiver.call(amount))
	piece.amount -= received
	if piece.amount == 0:
		debris.erase(debris_id)
	return received

func content_region() -> String:
	return str(model.locations.rules.collection.supply_region)

func debris_in(region_id: String) -> Dictionary:
	return debris if region_id == content_region() else {}
