extends RefCounted
signal changed
signal notice(message: String)
const FIELDS: Array[String] = ["jobs"]
var jobs: Dictionary = {}
var fleet_ref: WeakRef
var fleet: RefCounted:
	get: return fleet_ref.get_ref()

func _init(owner_fleet: RefCounted) -> void:
	fleet_ref = weakref(owner_fleet)

func assign(id: int, point: Vector2) -> String:
	var model: StationModel = fleet.model
	if not model.ships.has(id) or not model.ship_catalog[model.ships[id]].has("hauling"): return "Select a hauling-capable ship."
	var error: String = fleet.transport.work_error(id)
	if not error.is_empty(): return error
	if fleet.unit_busy(id): return "This ship already has a job. Stop hauling before reassigning."
	var destination: Dictionary = model.locations.local_destination(id)
	if destination.is_empty(): return "Found a local outpost before assigning hauling."
	var local: StationModel = model.scoped_station(destination.station_id)
	if not local.modules.has(point) or not local.definition_at(point).has("conversion"): return "Click a Refinery in this ship’s region."
	var duration: int = int(model.ship_definition(id).hauling.travel_seconds)
	jobs[id] = {"refinery_id": local.structure_id_at(point), "region": model.locations.ship_region(id), "destination": destination, "phase": "pickup", "remaining": duration, "cargo": {}, "waiting": false, "status": "To refinery"}
	changed.emit()
	fleet.changed.emit()
	return ""

func stop(id: int) -> void:
	if not jobs.has(id): return
	if jobs[id].cargo.is_empty():
		cancel(id)
	else:
		jobs[id]["stop_after_delivery"] = true
		changed.emit()
		fleet.changed.emit()

func cancel(id: int) -> void:
	if not jobs.has(id): return
	# Stop/decommission recovery never destroys carried goods or bypasses normal deliveries.
	var job: Dictionary = jobs[id]
	for resource: String in job.cargo:
		if job.destination.station_id == fleet.model.locations.primary_station(): fleet.model.recover_goods(resource, int(job.cargo[resource]))
		else:
			var inventory: Dictionary = fleet.model.locations.stations[job.destination.station_id].inventory
			inventory[resource] = int(inventory.get(resource, 0)) + int(job.cargo[resource])
	jobs.erase(id)
	changed.emit()
	fleet.changed.emit()

func set_status(job: Dictionary, text: String, waiting: bool = false) -> void:
	if job.status == text and job.waiting == waiting: return
	job.status = text
	job.waiting = waiting
	if waiting and text == "Storage full": notice.emit("Hauler waiting — storage full")
	changed.emit()

func waiting_message() -> String:
	for job: Dictionary in jobs.values():
		if job.waiting and job.status == "Storage full": return "Hauler waiting — storage full"
	return ""

func tick() -> void:
	if jobs.is_empty(): return
	var model: StationModel = fleet.model
	for id: int in jobs.keys():
		var job: Dictionary = jobs[id]
		var local: StationModel = model.scoped_station(job.destination.station_id)
		var capability: Dictionary = model.ship_definition(id).hauling
		if job.remaining > 0:
			job.remaining -= 1
			if job.remaining > 0: continue
		if job.phase == "delivery":
			for resource: String in job.cargo.keys():
				var room: int = maxi(0, local.capacity - local.upgrade_resource_amount(resource))
				var amount: int = mini(int(job.cargo[resource]), room)
				if amount > 0:
					if job.destination.station_id == model.locations.primary_station() and fleet.diplomacy.inventory.has(resource): fleet.diplomacy.receive_goods(resource, amount)
					elif job.destination.station_id != model.locations.primary_station():
						var inventory: Dictionary = model.locations.stations[job.destination.station_id].inventory
						inventory[resource] = int(inventory.get(resource, 0)) + amount
					else: model.locations.receive(job.destination, resource, amount)
					job.cargo[resource] -= amount
					if job.cargo[resource] == 0: job.cargo.erase(resource)
			if not job.cargo.is_empty():
				set_status(job, "Storage full", true)
				continue
			if job.get("stop_after_delivery", false) or not model.locations.structures.has(job.refinery_id):
				cancel(id)
				continue
			job.phase = "pickup"
			job.remaining = int(capability.travel_seconds)
			set_status(job, "To refinery")
		else:
			if not model.locations.structures.has(job.refinery_id):
				cancel(id)
				continue
			var point: Vector2 = model.locations.structures[job.refinery_id].position
			var buffer: Dictionary = local.refinery_buffer(point)
			var room: int = int(capability.batch_size)
			for resource: String in buffer.keys():
				var amount: int = mini(room, int(buffer[resource]))
				if amount <= 0: continue
				job.cargo[resource] = amount
				buffer[resource] -= amount
				room -= amount
				if buffer[resource] == 0: buffer.erase(resource)
			if job.cargo.is_empty():
				set_status(job, "Waiting for refinery output", true)
				continue
			job.phase = "delivery"
			job.remaining = int(capability.travel_seconds)
			set_status(job, "Delivering · %d units" % (int(capability.batch_size) - room))
	changed.emit()
	fleet.changed.emit()
	model.changed.emit()

func validate(data: Dictionary) -> String:
	if not data.get("jobs") is Dictionary: return "Invalid hauling jobs."
	for id: Variant in data.jobs:
		var job: Variant = data.jobs[id]
		if not id is int or not fleet.model.ships.has(id) or not fleet.model.ship_catalog[fleet.model.ships[id]].has("hauling") or fleet.unit_busy(id): return "Invalid Hauler assignment."
		var capability: Dictionary = fleet.model.ship_definition(id).hauling
		if not job is Dictionary or not job.get("refinery_id") is String or fleet.model.locations.ship_region(id) != job.region or job.get("destination") != fleet.model.locations.local_destination(id): return "Invalid hauling location."
		if not job.get("phase") in ["pickup", "delivery"] or not job.get("remaining") is int or job.remaining < 0 or job.remaining > int(capability.travel_seconds) or not job.get("waiting") is bool or not job.get("status") is String or not job.get("cargo") is Dictionary: return "Invalid hauling state."
		if job.has("stop_after_delivery") and not job.stop_after_delivery is bool: return "Invalid hauling stop state."
		var cargo: int = 0
		for resource: Variant in job.cargo:
			if not resource is String or not resource in ["materials", "minerals"] + fleet.diplomacy.inventory.keys() or not job.cargo[resource] is int or job.cargo[resource] <= 0: return "Invalid hauling cargo."
			cargo += job.cargo[resource]
		if cargo > int(capability.batch_size) or (job.phase == "pickup" and cargo != 0) or (job.phase == "delivery" and cargo == 0): return "Invalid hauling load."
		if fleet.model.locations.structures.has(job.refinery_id):
			var structure: Dictionary = fleet.model.locations.structures[job.refinery_id]
			if structure.region != job.region or structure.station_id != job.destination.station_id or not fleet.model.structure_definition(job.refinery_id).has("conversion"): return "Invalid hauling refinery."
		elif job.phase != "delivery": return "Missing hauling refinery."
	return ""
