extends RefCounted
# Collection stays within the ship’s physical region and local storage.
signal changed
signal notice(message: String)
const FIELDS: Array[String] = ["jobs", "depots"]
var jobs: Dictionary = {}
var depots: Dictionary:
	get: return model.capability_states("material_depot", {"delivered": 0})
	set(value): model.import_capability_states("material_depot", value)
var model: StationModel
var fleet_ref: WeakRef
var supply_ref: WeakRef
var fleet: RefCounted:
	get: return fleet_ref.get_ref()
var supply: RefCounted:
	get: return supply_ref.get_ref()

func _init(station: StationModel, ships: RefCounted, stock: RefCounted) -> void:
	model = station
	fleet_ref = weakref(ships)
	supply_ref = weakref(stock)
	model.changed.connect(sync_depots)
	sync_depots()

func sync_depots() -> void:
	model.capability_states("material_depot", {"delivered": 0})

static func depot_position(point: Vector2) -> Vector2:
	return Vector2(0.5, 0.5) + point / Vector2(900, 605)

func deploy(ship_id: int) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("collection"):
		return "Select a ship with material collection capability."
	if not fleet.transport.work_error(ship_id).is_empty():
		return fleet.transport.work_error(ship_id)
	if fleet.unit_busy(ship_id):
		return "This ship is already on a mission."
	var destination: Dictionary = model.locations.local_destination(ship_id)
	if destination.is_empty(): return "Found an outpost in this region before collecting Materials."
	var local_depots: Dictionary = depots_in(model.locations.ship_region(ship_id))
	if local_depots.is_empty(): return "Build a Space Depot in this region before deploying a Material Ship."
	var depot: Vector2 = local_depots.keys()[0]
	jobs[ship_id] = {"depot_id": model.locations.structure_at(destination.station_id, depot), "destination": destination, "region": model.locations.ship_region(ship_id), "position": depot_position(depot), "target": -1, "depot": depot, "cargo": 0, "waiting": false, "status": "Seeking debris"}
	changed.emit()
	fleet.changed.emit()
	return ""

func cancel(ship_id: int) -> void:
	if jobs.has(ship_id):
		# Recovery refunds are allowed above capacity, as with prepaid trade cargo.
		var destination: Dictionary = jobs[ship_id].destination
		if destination.station_id == model.locations.primary_station(): model.materials += int(jobs[ship_id].cargo)
		elif model.locations.stations.has(destination.station_id): model.locations.stations[destination.station_id].inventory.materials += int(jobs[ship_id].cargo)
		jobs.erase(ship_id)
		model.changed.emit()
		changed.emit()

func _status(job: Dictionary, value: String, waiting: bool = false) -> void:
	if job.status == value and job.waiting == waiting:
		return
	job.status = value
	job.waiting = waiting
	if waiting:
		notice.emit("Material Ship waiting — " + value.to_lower())
	changed.emit()
	fleet.changed.emit()

func waiting_message() -> String:
	for job: Dictionary in jobs.values():
		if job.waiting:
			return "Material Ship waiting — " + str(job.status).to_lower()
	return ""

func _receive(amount: int, job: Dictionary) -> int:
	job.cargo += amount
	return amount

func advance(delta: float) -> void:
	for ship_id: int in jobs:
		var job: Dictionary = jobs[ship_id]
		var local_depots: Dictionary = depots_in(model.locations.ship_region(ship_id))
		if local_depots.is_empty():
			_status(job, "Requires Space Depot", true)
			continue
		var capability: Dictionary = model.ship_catalog[model.ships[ship_id]].collection
		var step: float = float(capability.speed) * delta
		if not local_depots.has(job.depot):
			job.depot = local_depots.keys()[0]
		# Preserve the old same-cell replacement preference, but bind its new ID.
		job.depot_id = model.locations.structure_at(job.destination.station_id, job.depot)
		job.destination = model.locations.destination(model.locations.structures[job.depot_id].station_id)
		var available_debris: Dictionary = supply.debris_in(model.locations.ship_region(ship_id))
		if job.cargo > 0:
			var destination: Vector2 = depot_position(job.depot)
			job.position = job.position.move_toward(destination, step)
			if job.position != destination:
				_status(job, "Returning · 1 M")
				continue
			var local: StationModel = model.scoped_station(job.destination.station_id)
			var received: int = model.locations.receive(job.destination, "materials", mini(int(job.cargo), maxi(0, local.capacity - local.materials)))
			if received == 0:
				_status(job, "Storage full", true)
				continue
			job.cargo -= received
			local_depots[job.depot].delivered += received
			_status(job, "Seeking debris")
			changed.emit()
			continue
		if not available_debris.has(job.target):
			job.target = -1
			var distance: float = INF
			for debris_id: int in available_debris:
				if available_debris[debris_id].get("resource", "materials") != "materials": continue
				var reserved: bool = false
				for other: Dictionary in jobs.values():
					if other != job and other.region == job.region and other.target == debris_id:
						reserved = true
				var candidate: float = Vector2(0.5, 0.5).distance_squared_to(available_debris[debris_id].position)
				if not reserved and candidate < distance:
					distance = candidate
					job.target = debris_id
		if job.target == -1:
			_status(job, "Seeking debris")
			continue
		_status(job, "Collecting")
		var target: Vector2 = available_debris[job.target].position
		job.position = job.position.move_toward(target, step)
		if job.position == target:
			supply.salvage(int(job.target), _receive.bind(job), int(capability.cargo_capacity), job.region)
			job.target = -1
			_status(job, "Returning · 1 M")
			changed.emit()

func depots_in(region_id: String) -> Dictionary:
	var result: Dictionary = {}
	for id: String in model.locations.structures:
		var structure: Dictionary = model.locations.structures[id]
		if structure.region == region_id and structure.owner == model.locations.rules.primary_station.owner and model.catalog.get(structure.kind, {}).has("material_depot"):
			if not structure.state.has("material_depot"): structure.state["material_depot"] = {"delivered": 0}
			result[structure.position] = structure.state.material_depot
	return result

func migrate_job_locations() -> void:
	for ship_id: int in jobs:
		var job: Dictionary = jobs[ship_id]
		if not job.has("depot_id"):
			job["depot_id"] = model.structure_id_at(job.depot) if model.modules.has(job.depot) and model.definition_at(job.depot).has("material_depot") else ""
		if not job.has("destination"):
			job["destination"] = model.locations.ship_destination(ship_id)
