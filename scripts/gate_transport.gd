extends RefCounted
signal changed
signal arrived(ship_id: int, region_id: String)
const FIELDS: Array[String] = ["gates", "locations", "jobs"]
var gates: Dictionary = {}
var locations: Dictionary = {}
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
	for point: Vector2 in gates.keys():
		if not fleet.model.modules.has(point) or not fleet.model.definition_at(point).has("teleport"):
			gates.erase(point)
	for point: Vector2 in fleet.model.modules:
		if fleet.model.definition_at(point).has("teleport") and not gates.has(point):
			gates[point] = {"jumps": 0}

func location(ship_id: int) -> String:
	return str(locations.get(ship_id, fleet.regions.HOME))

func work_error(ship_id: int) -> String:
	if jobs.has(ship_id):
		return "Ship is in teleport transit."
	if location(ship_id) != fleet.regions.HOME:
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
	if destination == fleet.regions.HOME or not fleet.regions.adjacent(fleet.regions.HOME, destination):
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
	jobs[ship_id] = {"gate": gate, "origin": fleet.regions.HOME, "destination": destination, "remaining": duration, "duration": duration, "cost": capability.cost.duplicate(true)}
	gates[gate].jumps += 1
	changed.emit()
	fleet.diplomacy.changed.emit()
	return ""

func tick() -> void:
	for ship_id: int in jobs.keys():
		var job: Dictionary = jobs[ship_id]
		job.remaining -= 1
		if job.remaining <= 0:
			locations[ship_id] = job.destination
			jobs.erase(ship_id)
			arrived.emit(ship_id, job.destination)
			changed.emit()

func cancel(ship_id: int) -> void:
	if jobs.has(ship_id):
		for good: String in jobs[ship_id].cost:
			fleet.diplomacy.inventory[good] += int(jobs[ship_id].cost[good])
	jobs.erase(ship_id)
	locations.erase(ship_id)
	changed.emit()
