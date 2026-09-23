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
		if scope.module_hp(structure.position) >= scope.module_max_hp(structure.position):
			jobs.erase(ship_id)
			continue
		if str(job.region) != model.locations.ship_region(ship_id):
			jobs.erase(ship_id)
			continue
		if str(job.phase) == "travel":
			job.travel_remaining = float(job.travel_remaining) - delta
			if float(job.travel_remaining) > 0.0: continue
			job.phase = "repairing"
		job.progress = float(job.get("progress", 0.0)) + delta
		var repair_defaults: Dictionary = model.durability_rules.get("repair", {})
		var seconds_per_hp: float = maxf(0.1, float(job.get("seconds_per_hp", repair_defaults.get("seconds_per_hp", 0.8))))
		var repaired: bool = false
		while float(job.progress) >= seconds_per_hp and scope.module_hp(structure.position) < scope.module_max_hp(structure.position):
			var cost_per_hp: int = maxi(1, int(job.get("materials_per_hp", repair_defaults.get("materials_per_hp", 3))))
			if scope.materials < cost_per_hp:
				if not bool(job.get("waiting", false)):
					job.waiting = true
					notice.emit("Repair Ship waiting — insufficient Materials")
				# Do not bank elapsed repair time while waiting for input.
				job.progress = minf(float(job.progress), seconds_per_hp)
				changed.emit()
				break
			scope.materials -= cost_per_hp
			scope.repair_module(structure.position, 1)
			job.progress = float(job.progress) - seconds_per_hp
			job.waiting = false
			repaired = true
		if repaired: changed.emit()
		if scope.module_hp(structure.position) >= scope.module_max_hp(structure.position):
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
		var capability: Dictionary = definition.repair
		var repair_defaults: Dictionary = model.durability_rules.get("repair", {})
		jobs[ship_id] = {"target": target, "region": region, "phase": "travel", "travel_remaining": float(capability.get("travel_seconds", 2)), "progress": 0.0, "seconds_per_hp": float(capability.get("seconds_per_hp", repair_defaults.get("seconds_per_hp", 0.8))), "materials_per_hp": int(capability.get("materials_per_hp", repair_defaults.get("materials_per_hp", 3))), "waiting": false}
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
		var hp: int = scope.module_hp(structure.position)
		var maximum: int = scope.module_max_hp(structure.position)
		if hp >= maximum: continue
		# Prioritize the lowest HP percentage, then the nearest module.
		var candidate: float = float(hp) / float(maximum) * 100000.0 + origin.distance_squared_to(structure.position)
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
