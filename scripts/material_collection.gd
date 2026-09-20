extends RefCounted
# Home-only logical sector movement. Cross-region hauling is future scope.
signal changed
signal notice(message: String)
const FIELDS: Array[String] = ["jobs", "depots"]
var jobs: Dictionary = {}
var depots: Dictionary = {}
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
	for point: Vector2 in depots.keys():
		if not model.modules.has(point) or not model.definition_at(point).has("material_depot"):
			depots.erase(point)
	for point: Vector2 in model.modules:
		if model.definition_at(point).has("material_depot") and not depots.has(point):
			depots[point] = {"delivered": 0}

static func depot_position(point: Vector2) -> Vector2:
	return Vector2(0.5, 0.5) + point / Vector2(900, 605)

func deploy(ship_id: int) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("collection"):
		return "Select a ship with material collection capability."
	if not fleet.transport.work_error(ship_id).is_empty():
		return fleet.transport.work_error(ship_id)
	if fleet.unit_busy(ship_id):
		return "This ship is already on a mission."
	if model.ship_catalog[model.ships[ship_id]].collection.get("region", "home") != fleet.regions.HOME:
		return "Cross-region material hauling is not available yet."
	if depots.is_empty():
		return "Build a Space Depot before deploying a Material Ship."
	jobs[ship_id] = {"region": fleet.regions.HOME, "position": Vector2(0.5, 0.5), "target": -1, "depot": depots.keys()[0], "cargo": 0, "waiting": false, "status": "Seeking debris"}
	changed.emit()
	fleet.changed.emit()
	return ""

func cancel(ship_id: int) -> void:
	if jobs.has(ship_id):
		# Recovery refunds are allowed above capacity, as with prepaid trade cargo.
		model.materials += int(jobs[ship_id].cargo)
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
		if depots.is_empty():
			_status(job, "Requires Space Depot", true)
			continue
		var capability: Dictionary = model.ship_catalog[model.ships[ship_id]].collection
		var step: float = float(capability.speed) * delta
		if not depots.has(job.depot):
			job.depot = depots.keys()[0]
		if job.cargo > 0:
			var destination: Vector2 = depot_position(job.depot)
			job.position = job.position.move_toward(destination, step)
			if job.position != destination:
				_status(job, "Returning · 1 M")
				continue
			var received: int = model.collect(int(job.cargo))
			if received == 0:
				_status(job, "Storage full", true)
				continue
			job.cargo -= received
			depots[job.depot].delivered += received
			_status(job, "Seeking debris")
			changed.emit()
			continue
		if not supply.debris.has(job.target):
			job.target = -1
			var distance: float = INF
			for debris_id: int in supply.debris:
				var reserved: bool = false
				for other: Dictionary in jobs.values():
					if other != job and other.target == debris_id:
						reserved = true
				var candidate: float = Vector2(0.5, 0.5).distance_squared_to(supply.debris[debris_id].position)
				if not reserved and candidate < distance:
					distance = candidate
					job.target = debris_id
		if job.target == -1:
			_status(job, "Seeking debris")
			continue
		_status(job, "Collecting")
		var target: Vector2 = supply.debris[job.target].position
		job.position = job.position.move_toward(target, step)
		if job.position == target:
			supply.salvage(int(job.target), _receive.bind(job), int(capability.cargo_capacity))
			job.target = -1
			_status(job, "Returning · 1 M")
			changed.emit()
