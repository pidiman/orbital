extends RefCounted
# Canonical identity, ownership and physical location. Never stores camera/view state.
const FIELDS: Array[String] = ["stations", "structures", "ships", "next_structure_id"]
var rules: Dictionary
var stations: Dictionary = {}
var structures: Dictionary = {}
var ships: Dictionary = {}
var next_structure_id: int = 0
var model_ref: WeakRef

func _init(station_model: RefCounted = null) -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/location_rules.json"))
	stations[rules.primary_station.id] = rules.primary_station.duplicate(true)
	if station_model != null:
		model_ref = weakref(station_model)

func primary_station() -> String:
	return str(rules.primary_station.id)

func station_region(station_id: String) -> String:
	return str(stations.get(station_id, {}).get("region", ""))

func structure_at(station_id: String, position: Vector2) -> String:
	for id: String in structures:
		var record: Dictionary = structures[id]
		if record.station_id == station_id and record.position == position:
			return id
	return ""

func add_structure(station_id: String, kind: String, position: Vector2) -> String:
	if not stations.has(station_id) or not structure_at(station_id, position).is_empty():
		return ""
	next_structure_id += 1
	var id: String = "structure:%d" % next_structure_id
	structures[id] = {"id": id, "station_id": station_id, "owner": stations[station_id].owner, "region": stations[station_id].region, "kind": kind, "position": position, "state": {}}
	return id

func add_ship(ship_id: int, kind: String, station_id: String) -> void:
	ships[ship_id] = {"id": ship_id, "kind": kind, "station_id": station_id, "owner": stations[station_id].owner, "region": stations[station_id].region, "transit": {}}

func ship_region(ship_id: int) -> String:
	return str(ships.get(ship_id, {}).get("region", station_region(primary_station())))

func ship_destination(ship_id: int) -> Dictionary:
	return destination(str(ships[ship_id].station_id)) if ships.has(ship_id) else {}

func destination(station_id: String) -> Dictionary:
	return {"station_id": station_id, "region": station_region(station_id)}

func actor_for(unit: Variant) -> Dictionary:
	if unit is int:
		return {"type": "ship", "id": unit}
	return {"type": "structure", "id": structure_at(primary_station(), unit)}

static func actor_key(actor: Dictionary) -> String:
	return "%s/%s" % [actor.type, actor.id]

func actor_record(actor: Dictionary) -> Dictionary:
	return ships.get(actor.id, {}) if actor.type == "ship" else structures.get(actor.id, {})

func mining_route(actor: Dictionary, target_id: int, target_region: String) -> Dictionary:
	var record: Dictionary = actor_record(actor)
	if record.is_empty():
		return {}
	var remote: bool = record.region != target_region
	if remote and not (rules.mining.allow_remote_from_primary and record.region == station_region(primary_station())):
		return {}
	return {"actor": actor, "origin_region": record.region, "target": {"type": "asteroid", "id": target_id, "region": target_region}, "destination": destination(record.station_id), "cargo": {"minerals": 0}, "policy": "legacy_remote_home" if remote else "local"}

func receive(destination_record: Dictionary, resource: String, amount: int) -> int:
	# One inventory adapter currently exists. Future outposts register their own
	# inventories here; unsupported destinations never silently credit Home.
	if destination_record != destination(primary_station()) or model_ref == null:
		return 0
	var model: RefCounted = model_ref.get_ref()
	if model == null:
		return 0
	if resource == "materials":
		return model.collect(amount)
	if resource == "minerals":
		model.add_minerals(amount)
		return amount
	return 0

func begin_transit(ship_id: int, destination_region: String) -> void:
	ships[ship_id].transit = {"origin": ship_region(ship_id), "destination": destination_region}

func finish_transit(ship_id: int) -> void:
	ships[ship_id].region = ships[ship_id].transit.destination
	ships[ship_id].transit = {}

func legacy_modules() -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in structures.values():
		if record.station_id == primary_station():
			result[record.position] = record.kind
	return result

func import_modules(values: Dictionary) -> void:
	# Only used by old-save adapters. New saves overwrite this deterministic
	# migration with their canonical identities before any signals are emitted.
	structures.clear()
	next_structure_id = 0
	for point: Vector2 in values:
		add_structure(primary_station(), values[point], point)

func legacy_ships() -> Dictionary:
	var result: Dictionary = {}
	for id: int in ships:
		result[id] = ships[id].kind
	return result

func import_ships(values: Dictionary) -> void:
	ships.clear()
	for id: int in values:
		add_ship(id, values[id], primary_station())

func position_state(field: String) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in structures.values():
		if record.station_id == primary_station() and record.state.has(field):
			result[record.position] = record.state[field]
	return result

func import_position_state(field: String, values: Dictionary) -> void:
	for record: Dictionary in structures.values():
		if record.station_id == primary_station():
			record.state.erase(field)
	for point: Vector2 in values:
		var id: String = structure_at(primary_station(), point)
		if not id.is_empty():
			structures[id].state[field] = values[point]

func legacy_locations() -> Dictionary:
	var result: Dictionary = {}
	for id: int in ships:
		if ship_region(id) != station_region(primary_station()):
			result[id] = ship_region(id)
	return result

func import_locations(values: Dictionary) -> void:
	for id: int in ships:
		ships[id].region = values.get(id, station_region(primary_station()))

func regional_survey_origin(ship_id: int, viewed_region: String) -> String:
	# REVIEW before outposts: legacy regional surveys use the viewed route while
	# their physical Home ship remains at Home. This explicit policy freezes play.
	if rules.regional_survey.origin == "viewed_region_legacy":
		return viewed_region
	return ship_region(ship_id)
