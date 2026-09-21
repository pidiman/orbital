extends RefCounted
# Validation of the additive canonical graph; legacy projections remain checked
# by SaveStore. This never mutates live state.
static func integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= 9007199254740991

static func validate_graph(data: Dictionary, model: StationModel, region_data: Dictionary, transport: Dictionary) -> String:
	var primary: String = model.locations.primary_station()
	if not integer(data.next_structure_id) or not data.stations.has(primary) or data.stations[primary] != model.locations.rules.primary_station:
		return "Invalid primary station ownership or structure allocator."
	for id: Variant in data.stations:
		var station: Variant = data.stations[id]
		if not id is String or not station is Dictionary or station.get("id") != id or not station.get("region") is String or not region_data.records.has(station.region) or not station.get("owner") is String or station.owner.is_empty():
			return "Invalid station location or owner."
	var positions: Dictionary = {}
	for id: Variant in data.structures:
		var record: Variant = data.structures[id]
		if not id is String or not id.begins_with("structure:") or not id.trim_prefix("structure:").is_valid_int() or str(int(id.trim_prefix("structure:"))) != id.trim_prefix("structure:") or int(id.trim_prefix("structure:")) < 1 or int(id.trim_prefix("structure:")) > data.next_structure_id:
			return "Invalid structure identity."
		if not record is Dictionary or record.get("id") != id or not record.get("station_id") is String or not data.stations.has(record.station_id):
			return "Invalid structure owner station."
		var station: Dictionary = data.stations[record.station_id]
		if record.get("owner") != station.owner or record.get("region") != station.region or not record.get("position") is Vector2 or not record.position.is_finite() or not record.get("kind") is String or (not model.catalog.has(record.kind) and not model.locations.outpost_catalog.has(record.kind)) or not record.get("state") is Dictionary:
			return "Invalid structure location, definition or state."
		if not positions.has(record.station_id):
			positions[record.station_id] = {}
		if positions[record.station_id].has(record.position):
			return "Duplicate structure position within a station."
		positions[record.station_id][record.position] = id
		if record.state.has("refinery_recipe"):
			var recipe: Variant = record.state.refinery_recipe
			if not recipe is String or not model.refinery_recipes.has(recipe) or not model.catalog.get(record.kind, {}).get("recipes", []).has(recipe):
				return "Invalid refinery recipe."
		for field: String in ["tier", "refinery_progress"]:
			if record.state.has(field) and not integer(record.state[field], 1 if field == "tier" else 0):
				return "Invalid structure progress."
		for pair: Array in [["research", "completed"], ["material_depot", "delivered"], ["teleport", "jumps"]]:
			if record.state.has(pair[0]) and (not record.state[pair[0]] is Dictionary or not integer(record.state[pair[0]].get(pair[1]))):
				return "Invalid structure capability state."
	if data.ships.size() != model.ships.size():
		return "Ship ownership count disagrees with fleet."
	for id: Variant in data.ships:
		var ship: Variant = data.ships[id]
		if not id is int or not model.ships.has(id) or not ship is Dictionary or ship.get("id") != id or ship.get("kind") != model.ships[id] or not ship.get("station_id") is String or not data.stations.has(ship.station_id):
			return "Invalid ship identity or owner station."
		if ship.get("owner") != data.stations[ship.station_id].owner or not ship.get("region") is String or not region_data.records.has(ship.region) or not region_data.records[ship.region].discovered or not ship.get("transit") is Dictionary:
			return "Invalid physical ship location."
		if ship.region != transport.locations.get(id, model.locations.station_region(primary)):
			return "Ship location disagrees with legacy gate projection."
		var expected_transit: Dictionary = {}
		if transport.jobs.has(id):
			expected_transit = {"origin": transport.jobs[id].origin, "destination": transport.jobs[id].destination}
		if ship.transit != expected_transit:
			return "Ship transit disagrees with gate mission."
	return ""

static func validate_projections(model: StationModel, station_data: Dictionary, research: Dictionary, transport: Dictionary, collection: Dictionary) -> String:
	for field: String in ["modules", "module_tiers", "refinery_progress", "ships"]:
		if model.get(field) != station_data[field]:
			return "Canonical structure state disagrees with legacy " + field + "."
	for pair: Array in [["research", research.labs], ["teleport", transport.gates], ["material_depot", collection.depots]]:
		if model.locations.position_state(pair[0]) != pair[1]:
			return "Canonical capability state disagrees with legacy " + str(pair[0]) + "."
	return ""

static func validate_assignments(assignments: Dictionary, fleet: MiningFleet, old_jobs: Dictionary, legacy: bool = false) -> String:
	if assignments.size() != old_jobs.size():
		return "Mining identity count disagrees with active missions."
	var seen: Dictionary = {}
	for key: Variant in assignments:
		var assignment: Variant = assignments[key]
		if not key is String or not assignment is Dictionary or not assignment.get("actor") is Dictionary:
			return "Invalid mining actor identity."
		var actor: Dictionary = assignment.actor
		if not ["ship", "structure"].has(actor.get("type")) or not actor.has("id") or key != fleet.model.locations.actor_key(actor):
			return "Invalid mining actor key."
		var record: Dictionary = fleet.model.locations.actor_record(actor)
		if record.is_empty():
			return "Mining actor no longer exists."
		var unit: Variant = actor.id if actor.type == "ship" else record.position
		if not old_jobs.has(unit) or seen.has(unit) or typeof(assignment.get("legacy_unit")) != typeof(unit) or assignment.get("legacy_unit") != unit or assignment.get("job") != old_jobs[unit]:
			return "Mining identity disagrees with legacy mission."
		seen[unit] = true
		var target: int = int(old_jobs[unit].target)
		var expected: Dictionary = fleet.mining_route(actor, target, legacy)
		if expected.is_empty():
			return "Mining route is not supported by current location policy."
		for field: String in expected:
			if assignment.get(field) != expected[field]:
				return "Invalid mining location, destination or cargo."
	return ""

static func validate_collection(collection: Dictionary, model: StationModel) -> String:
	for ship_id: int in collection.jobs:
		var job: Dictionary = collection.jobs[ship_id]
		if job.get("destination") != model.locations.ship_destination(ship_id) or job.region != model.locations.ship_region(ship_id) or not job.get("depot_id") is String:
			return "Invalid collection owner, region or destination."
		# A removed depot may remain assigned until the next supply step, as before.
		if model.locations.structures.has(job.depot_id):
			var depot: Dictionary = model.locations.structures[job.depot_id]
			if depot.position != job.depot or depot.region != job.region or not model.catalog[depot.kind].has("material_depot") or depot.station_id != job.destination.station_id:
				return "Invalid collection depot identity."
	return ""

static func validate_gate_bindings(transport: Dictionary, model: StationModel) -> String:
	for job: Dictionary in transport.jobs.values():
		if not job.get("gate_id") is String:
			return "Missing gate identity."
		# Demolition never cancels a launched jump. Missing gates stay historical IDs.
		if model.locations.structures.has(job.gate_id):
			var gate: Dictionary = model.locations.structures[job.gate_id]
			if gate.position != job.gate or gate.region != job.origin or not model.catalog[gate.kind].has("teleport"):
				return "Invalid gate identity binding."
	return ""
