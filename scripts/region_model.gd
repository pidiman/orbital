class_name RegionModel
extends RefCounted

signal changed
signal location_changed
signal survey_started
signal discovered(region_id: String)
const HOME: String = "home"
const FIELDS: Array[String] = ["current_region", "records", "survey_jobs"]
var catalog: Dictionary
var planets: Dictionary
var anomaly_catalog: Dictionary
var current_region: String = HOME
var records: Dictionary = {}
var survey_jobs: Dictionary = {}

func _init(seed_value: int = -1) -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	planets = JSON.parse_string(FileAccess.get_file_as_string("res://data/planets.json"))
	anomaly_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/region_anomalies.json"))
	var seeds := RandomNumberGenerator.new()
	if seed_value < 0:
		seeds.randomize()
	else:
		seeds.seed = seed_value
	for region_id: String in catalog:
		var rng := RandomNumberGenerator.new()
		rng.seed = seeds.randi()
		records[region_id] = {"discovered": region_id == HOME, "generated": region_id == HOME, "seed": str(rng.seed), "rng_state": str(rng.state), "contents": [], "asteroid_ids": [], "structures": {}}

func is_discovered(region_id: String) -> bool:
	return records.has(region_id) and bool(records[region_id].discovered)

func adjacent(origin: String, destination: String) -> bool:
	return catalog.has(origin) and catalog.has(destination) and catalog[origin].neighbors.has(destination)

func survey_job(region_id: String) -> Dictionary:
	for job: Dictionary in survey_jobs.values():
		if job.region_id == region_id:
			return job
	return {}

func state(region_id: String) -> String:
	if is_discovered(region_id):
		return "unlocked"
	return "surveying" if not survey_job(region_id).is_empty() else "unknown"

func survey_error(region_id: String) -> String:
	if not catalog.has(region_id):
		return "Unknown region."
	if not adjacent(current_region, region_id):
		return "Scout an adjacent region. Reach this route from " + ", ".join(catalog[region_id].neighbors) + "."
	if is_discovered(region_id):
		return "Region already surveyed and unlocked."
	if not survey_job(region_id).is_empty():
		return "A Scout is already surveying this region."
	return ""

# Abstract location transition. No scene, camera, input, distance or travel mode.
func set_location(region_id: String) -> String:
	if not is_discovered(region_id):
		return "Survey this region before visiting it."
	if current_region != region_id:
		current_region = region_id
		location_changed.emit()
		changed.emit()
	return ""

# Current travel adapter: permit a jump along an unlocked graph route.
func jump_error(destination: String) -> String:
	if not is_discovered(destination):
		return "Survey this region to unlock it."
	if destination == current_region:
		return "Already here."
	if not adjacent(current_region, destination):
		return "No direct route. Jump through an adjacent unlocked region."
	return ""

func jump(destination: String) -> String:
	var error: String = jump_error(destination)
	return error if not error.is_empty() else set_location(destination)

# Generation uses only a region's saved RNG stream, never viewport/time/global RNG.
func generate(region_id: String) -> bool:
	if not records.has(region_id) or records[region_id].generated:
		return false
	var record: Dictionary = records[region_id]
	var rules: Dictionary = catalog[region_id].content_rules
	var rng := RandomNumberGenerator.new()
	rng.seed = int(record.seed)
	rng.state = int(record.rng_state)
	var count: int = rng.randi_range(int(rules.asteroid_count[0]), int(rules.asteroid_count[1]))
	for index in range(count):
		# Local physical coordinates in abstract region units, projected only by views.
		var position := Vector2(140.0 + index * 150.0 + rng.randf_range(-25, 25), rng.randf_range(220, 470))
		record.contents.append({"type": "asteroid", "name": "%s deposit %d" % [catalog[region_id].name, index + 1], "minerals": rng.randi_range(int(rules.minerals[0]), int(rules.minerals[1])), "position": position})
	var anomalies: int = rng.randi_range(int(rules.anomaly_count[0]), int(rules.anomaly_count[1]))
	for index in range(anomalies):
		var kind: String = rules.anomaly_pool[rng.randi_range(0, rules.anomaly_pool.size() - 1)]
		var definition: Dictionary = anomaly_catalog[kind]
		record.contents.append({"type": "anomaly", "kind": kind, "name": definition.name, "description": definition.description, "good": definition.good, "amount": rng.randi_range(int(definition.amount[0]), int(definition.amount[1])), "position": Vector2(230 + index * 240, rng.randf_range(490, 540)), "resolved": true})
	record.rng_state = str(rng.state)
	record.generated = true
	record.discovered = true
	return true

func primary_station_visible() -> bool:
	return current_region == HOME

func allows_outposts(region_id: String) -> bool:
	return catalog.has(region_id) and bool(catalog[region_id].structures.get("outposts_enabled", false))

func validate(data: Dictionary, station: Dictionary, fleet_data: Dictionary, trade_jobs: Dictionary, ship_catalog: Dictionary) -> String:
	if not data.current_region is String or not data.records.has(data.current_region) or not catalog.has(data.current_region):
		return "Invalid current region."
	for region_id: String in catalog:
		if not data.records.has(region_id):
			return "Missing region discovery record."
	var ownership: Dictionary = {}
	for region_id: Variant in data.records:
		var record: Variant = data.records[region_id]
		if not region_id is String or not catalog.has(region_id) or not record is Dictionary:
			return "Unknown or invalid region."
		if not record.get("discovered") is bool or not record.get("generated") is bool or record.discovered != record.generated or not record.get("contents") is Array or not record.get("asteroid_ids") is Array or not record.get("structures") is Dictionary:
			return "Invalid region generation state."
		for field: String in ["seed", "rng_state"]:
			if not record.get(field) is String or not record[field].is_valid_int() or str(int(record[field])) != record[field]:
				return "Invalid region RNG state."
		if not record.generated and (not record.contents.is_empty() or not record.asteroid_ids.is_empty()):
			return "Undiscovered region contains generated content."
		if region_id == HOME and (not record.discovered or not record.contents.is_empty() or not record.asteroid_ids.is_empty()):
			return "Home must retain its original station and content."
		var deposits: int = 0
		for content: Variant in record.contents:
			if not content is Dictionary or not content.get("name") is String or not content.get("position") is Vector2 or not content.position.is_finite():
				return "Invalid region content position or name."
			if content.get("type") == "asteroid":
				if not _integer(content.get("minerals"), 1):
					return "Invalid generated deposit."
				deposits += 1
			elif content.get("type") == "anomaly":
				if not content.get("kind") is String or not anomaly_catalog.has(content.kind) or not content.get("good") is String or content.good != anomaly_catalog[content.kind].good or not _integer(content.get("amount"), 1) or content.get("resolved") != true or not content.get("description") is String:
					return "Invalid region anomaly."
			else:
				return "Unknown region content type."
		if deposits != record.asteroid_ids.size():
			return "Region deposit IDs disagree with generation."
		for asteroid_id: Variant in record.asteroid_ids:
			if not _integer(asteroid_id, int(fleet_data.next_discovery_id) + 1) or asteroid_id >= -1 or ownership.has(asteroid_id):
				return "Invalid or duplicated region asteroid ID."
			ownership[asteroid_id] = region_id
			if fleet_data.asteroids.has(int(asteroid_id)):
				var rock: Dictionary = fleet_data.asteroids[int(asteroid_id)]
				if rock.get("region_id", "") != region_id or not rock.get("persistent", false):
					return "Regional asteroid ownership mismatch."
	for asteroid_id: int in fleet_data.asteroids:
		var rock: Dictionary = fleet_data.asteroids[asteroid_id]
		if rock.has("region_id"):
			if not rock.region_id is String or ownership.get(asteroid_id, "") != rock.region_id or not data.records[rock.region_id].discovered:
				return "Asteroid references an undiscovered region."
	if not data.records[data.current_region].discovered:
		return "Current region is not unlocked."
	var destinations: Dictionary = {}
	for ship_id: Variant in data.survey_jobs:
		var job: Variant = data.survey_jobs[ship_id]
		if not ship_id is int or not station.ships.has(ship_id) or not ship_catalog[station.ships[ship_id]].has("survey"):
			return "Regional survey needs an existing Scout."
		if fleet_data.jobs.has(ship_id) or fleet_data.survey_jobs.has(ship_id) or trade_jobs.has(ship_id):
			return "Ship assigned to multiple mission roles."
		if not job is Dictionary or not job.get("region_id") is String or not job.get("origin") is String or not _integer(job.get("duration"), 1) or not _integer(job.get("remaining"), 1) or job.remaining > job.duration:
			return "Invalid regional survey timer."
		if not adjacent(job.origin, job.region_id) or not data.records[job.origin].discovered or data.records[job.region_id].discovered or destinations.has(job.region_id):
			return "Invalid regional survey route or reservation."
		destinations[job.region_id] = true
	return ""

func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= minimum and absf(float(value)) <= 9007199254740991.0

# Fleet validates capabilities/occupancy before starting the location-specific job.
func begin_survey(ship_id: int, region_id: String, duration: int) -> void:
	survey_jobs[ship_id] = {"region_id": region_id, "origin": current_region, "remaining": duration, "duration": duration}
	survey_started.emit()
	changed.emit()

# Called after generated deposits/rewards have been registered atomically by Fleet.
func announce_discovery(region_id: String) -> void:
	discovered.emit(region_id)
	changed.emit()
