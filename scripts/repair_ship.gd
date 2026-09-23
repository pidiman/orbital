class_name RepairShip
extends RefCounted

# Automatic regional repair jobs. Travel is represented in the job state for
# persistence, while ShipMotion supplies the presentation flight.
signal changed
signal notice(message: String)
const FIELDS: Array[String] = ["jobs"]
var fleet_ref: WeakRef
var jobs: Dictionary = {}
var fleet: RefCounted:
	get: return fleet_ref.get_ref()
var model: StationModel:
	get: return fleet.model

func _init(owner_fleet: RefCounted) -> void:
	fleet_ref = weakref(owner_fleet)

func advance(delta: float) -> void:
	_assign_idle_ships()
	for ship_id: int in jobs.keys():
		if not model.ships.has(ship_id):
			jobs.erase(ship_id)
			continue
		var job: Dictionary = jobs[ship_id]
		if not model.locations.structures.has(job.target):
			jobs.erase(ship_id)
			continue
		var structure: Dictionary = model.locations.structures[job.target]
		var scope: StationModel = model if structure.station_id == model.locations.primary_station() else model.scoped_station(structure.station_id)
		if not scope.is_module_damaged(structure.position):
			jobs.erase(ship_id)
			continue
		if str(job.region) != model.locations.ship_region(ship_id):
			jobs.erase(ship_id)
			continue
		if str(job.phase) == "travel":
			job.travel_remaining = float(job.travel_remaining) - delta
			if float(job.travel_remaining) > 0.0: continue
			job.phase = "repairing"
		if not bool(job.get("cost_paid", false)):
			var cost: int = int(job.cost)
			if scope.materials < cost:
				if not bool(job.get("waiting", false)):
					job.waiting = true
					notice.emit("Repair Ship waiting — insufficient Materials")
				changed.emit()
				continue
			scope.materials -= cost
			job.cost_paid = true
			job.waiting = false
			changed.emit()
		job.remaining = float(job.remaining) - delta
		if float(job.remaining) <= 0.0:
			scope.repair_module(structure.position)
			jobs.erase(ship_id)
			changed.emit()
	changed.emit()

func _assign_idle_ships() -> void:
	var claimed: Dictionary = {}
	for job: Dictionary in jobs.values(): claimed[job.target] = true
	for ship_id: int in model.ships:
		var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
		if not definition.has("repair") or jobs.has(ship_id) or fleet.unit_busy(ship_id): continue
		var region: String = model.locations.ship_region(ship_id)
		var target: String = _nearest_damaged(region, claimed, ship_id)
		if target.is_empty(): continue
		var structure: Dictionary = model.locations.structures[target]
		var tier: int = int(structure.state.get("tier", 1))
		var capability: Dictionary = definition.repair
		var cost: int = int(capability.get("materials_base", 15)) + maxi(0, tier - 1) * int(capability.get("materials_per_tier", 10))
		jobs[ship_id] = {"target": target, "region": region, "phase": "travel", "travel_remaining": float(capability.get("travel_seconds", 2)), "remaining": float(capability.get("seconds", 5)) + float(tier - 1), "duration": float(capability.get("seconds", 5)) + float(tier - 1), "cost": cost, "cost_paid": false, "waiting": false}
		claimed[target] = true
		changed.emit()

func _nearest_damaged(region: String, claimed: Dictionary, ship_id: int) -> String:
	var best: String = ""
	var distance: float = INF
	var ship_record: Dictionary = model.locations.ships.get(ship_id, {})
	var origin: Vector2 = Vector2.ZERO
	if ship_record.has("purchase_position"): origin = ship_record.purchase_position
	for id: String in model.locations.structures:
		var structure: Dictionary = model.locations.structures[id]
		if structure.region != region or structure.owner != model.locations.rules.primary_station.owner or claimed.has(id): continue
		var scope: StationModel = model if structure.station_id == model.locations.primary_station() else model.scoped_station(structure.station_id)
		if not scope.is_module_damaged(structure.position): continue
		var candidate: float = origin.distance_squared_to(structure.position)
		if candidate < distance:
			distance = candidate
			best = id
	return best

func cancel(ship_id: int) -> void:
	if jobs.has(ship_id):
		jobs.erase(ship_id)
		changed.emit()

func waiting_message() -> String:
	for job: Dictionary in jobs.values():
		if bool(job.get("waiting", false)): return "Repair Ship waiting — insufficient Materials"
	return ""

func validate(data: Dictionary) -> String:
	if not data.get("jobs") is Dictionary: return "Invalid repair ship state."
	for id: Variant in data.jobs:
		if not id is int or not model.ships.has(id) or not model.ship_catalog[model.ships[id]].has("repair"): return "Invalid Repair Ship job."
		if not data.jobs[id] is Dictionary or not model.locations.structures.has(data.jobs[id].get("target", "")): return "Invalid Repair Ship target."
	return ""
