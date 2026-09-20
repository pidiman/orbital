extends RefCounted
signal changed
signal arrived(ship_id: int, region_id: String)
const FIELDS: Array[String] = ["gates", "locations", "jobs"]
var gates: Dictionary:
	get: return fleet.model.capability_states("teleport", {"jumps": 0})
	set(value): fleet.model.import_capability_states("teleport", value)
var locations: Dictionary:
	get: return fleet.model.locations.legacy_locations()
	set(value): fleet.model.locations.import_locations(value)
var jobs: Dictionary = {}
var fleet_ref: WeakRef
var fleet: RefCounted:
	get: return fleet_ref.get_ref()

func _init(ships: RefCounted) -> void:
	fleet_ref = weakref(ships)
	fleet.model.module_removed.connect(sync_gates.unbind(1))
	fleet.model.module_built.connect(sync_gates.unbind(2))
	fleet.model.changed.connect(sync_gates)
	sync_gates()

func sync_gates() -> void:
	fleet.model.capability_states("teleport", {"jumps": 0})

func location(ship_id: int) -> String:
	return fleet.model.locations.ship_region(ship_id)

func work_error(ship_id: int) -> String:
	if jobs.has(ship_id):
		return "Ship is in teleport transit."
	if not fleet.model.locations.rules.work_regions.has(location(ship_id)):
		return "Ship is stationed in %s. Remote ship operations are future scope." % fleet.regions.catalog[location(ship_id)].name
	return ""

func jump_error(gate: Vector2, ship_id: int, destination: String) -> String:
	if not gates.has(gate):
		return "Build a Teleport Gate at Earth first."
	if not fleet.model.ships.has(ship_id):
		return "Select an owned ship."
	if not work_error(ship_id).is_empty():
		return work_error(ship_id)
	if fleet.unit_busy(ship_id):
		return "Ship is busy. Choose an idle Home ship."
	if not fleet.regions.is_discovered(destination):
		return "Survey the destination region first."
	var origin: String = fleet.model.locations.structures[fleet.model.structure_id_at(gate)].region
	if destination == origin or not fleet.regions.adjacent(origin, destination):
		return "No direct gate route from Home to this region."
	var capability: Dictionary = fleet.model.definition_at(gate).teleport
	for good: String in capability.cost:
		if int(fleet.diplomacy.inventory.get(good, 0)) < int(capability.cost[good]):
			return "Gate jump requires %d %s." % [capability.cost[good], fleet.diplomacy.goods_catalog[good].name]
	return ""

func jump(gate: Vector2, ship_id: int, destination: String) -> String:
	var error: String = jump_error(gate, ship_id, destination)
	if not error.is_empty():
		return error
	var capability: Dictionary = fleet.model.definition_at(gate).teleport
	for good: String in capability.cost:
		fleet.diplomacy.inventory[good] -= int(capability.cost[good])
	var duration: int = maxi(1, int(capability.seconds))
	fleet.model.locations.begin_transit(ship_id, destination)
	jobs[ship_id] = {"gate_id": fleet.model.structure_id_at(gate), "gate": gate, "origin": location(ship_id), "destination": destination, "remaining": duration, "duration": duration, "cost": capability.cost.duplicate(true)}
	gates[gate].jumps += 1
	changed.emit()
	fleet.diplomacy.changed.emit()
	return ""

func tick() -> void:
	for ship_id: int in jobs.keys():
		var job: Dictionary = jobs[ship_id]
		job.remaining -= 1
		if job.remaining <= 0:
			fleet.model.locations.finish_transit(ship_id)
			jobs.erase(ship_id)
			arrived.emit(ship_id, job.destination)
			changed.emit()

func cancel(ship_id: int) -> void:
	if jobs.has(ship_id):
		for good: String in jobs[ship_id].cost:
			fleet.diplomacy.inventory[good] += int(jobs[ship_id].cost[good])
	jobs.erase(ship_id)
	if fleet.model.locations.ships.has(ship_id):
		fleet.model.locations.ships[ship_id].transit = {}
		fleet.model.locations.ships[ship_id].region = fleet.model.locations.station_region(fleet.model.locations.primary_station())
	changed.emit()

func migrate_job_locations() -> void:
	for job: Dictionary in jobs.values():
		if not job.has("gate_id"):
			job["gate_id"] = fleet.model.structure_id_at(job.gate) if fleet.model.modules.has(job.gate) and fleet.model.definition_at(job.gate).has("teleport") else ""
