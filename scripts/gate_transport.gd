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
	return ""

func gate_id(gate: Variant) -> String:
	return str(gate) if gate is String else fleet.model.locations.structure_at(fleet.model.locations.primary_station(), gate)

func all_gates() -> Array[String]:
	var result: Array[String] = []
	for id: String in fleet.model.locations.structures:
		if fleet.model.structure_definition(id).has("teleport"): result.append(id)
	return result

func has_gate(region: String) -> bool:
	for id: String in all_gates():
		var structure: Dictionary = fleet.model.locations.structures[id]
		if structure.region == region and structure.owner == fleet.model.locations.rules.primary_station.owner: return true
	return false

func can_pioneer(ship_id: int) -> bool:
	return fleet.model.ships.has(ship_id) and fleet.model.ship_catalog[fleet.model.ships[ship_id]].has("pioneer")

func is_pioneer(ship_id: int, destination: String) -> bool:
	return can_pioneer(ship_id) and not has_gate(destination)

func jump_error(gate: Variant, ship_id: int, destination: String, allow_cargo: bool = false) -> String:
	var id: String = gate_id(gate)
	if not all_gates().has(id): return "Build a Teleport Gate in the departure region first."
	if not fleet.model.ships.has(ship_id): return "Select an owned ship."
	var structure: Dictionary = fleet.model.locations.structures[id]
	if location(ship_id) != structure.region: return "Ship must be in the departure gate's region."
	if fleet.unit_busy(ship_id) and not (allow_cargo and fleet.cargo != null and fleet.cargo.routes.has(ship_id)): return "Ship is busy. Choose an idle ship."
	if not fleet.regions.is_discovered(destination): return "Survey the destination region first."
	if destination == structure.region: return "Choose another region."
	if not has_gate(destination) and not can_pioneer(ship_id): return "The destination region needs a Teleport Gate."
	var base: StationModel = fleet.model.scoped_station(structure.station_id)
	if base.power_balance() < 0: return "Departure station needs more Solar power."
	var inventory: Dictionary = fleet.diplomacy.inventory if structure.station_id == fleet.model.locations.primary_station() else fleet.model.locations.stations[structure.station_id].inventory
	for good: String in fleet.model.structure_definition(id).teleport.cost:
		var amount: int = int(fleet.model.structure_definition(id).teleport.cost[good])
		if int(inventory.get(good, 0)) < amount: return "Departure storage needs %d %s for this jump." % [amount, fleet.diplomacy.goods_catalog[good].name]
	return ""

func jump(gate: Variant, ship_id: int, destination: String, allow_cargo: bool = false) -> String:
	var error: String = jump_error(gate, ship_id, destination, allow_cargo)
	if not error.is_empty(): return error
	var id: String = gate_id(gate)
	var structure: Dictionary = fleet.model.locations.structures[id]
	var capability: Dictionary = fleet.model.structure_definition(id).teleport
	var inventory: Dictionary = fleet.diplomacy.inventory if structure.station_id == fleet.model.locations.primary_station() else fleet.model.locations.stations[structure.station_id].inventory
	for good: String in capability.cost: inventory[good] -= int(capability.cost[good])
	var duration: int = maxi(1, int(capability.seconds))
	fleet.model.locations.begin_transit(ship_id, destination)
	jobs[ship_id] = {"gate_id": id, "gate": structure.position, "origin": location(ship_id), "destination": destination, "remaining": duration, "duration": duration, "cost": capability.cost.duplicate(true)}
	if not structure.state.has("teleport"): structure.state["teleport"] = {"jumps": 0}
	structure.state.teleport.jumps += 1
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
			var origin: String = jobs[ship_id].origin
			var station: String = fleet.model.locations.outpost_at(origin, fleet.model.locations.rules.primary_station.owner)
			var inventory: Dictionary = fleet.diplomacy.inventory if station.is_empty() else fleet.model.locations.stations[station].inventory
			inventory[good] = int(inventory.get(good, 0)) + int(jobs[ship_id].cost[good])
		if fleet.model.locations.ships.has(ship_id):
			fleet.model.locations.ships[ship_id].region = jobs[ship_id].origin
			fleet.model.locations.ships[ship_id].transit = {}
	jobs.erase(ship_id)
	changed.emit()

func migrate_job_locations() -> void:
	for job: Dictionary in jobs.values():
		if not job.has("gate_id"):
			job["gate_id"] = fleet.model.structure_id_at(job.gate) if fleet.model.modules.has(job.gate) and fleet.model.definition_at(job.gate).has("teleport") else ""
