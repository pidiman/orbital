extends RefCounted
signal changed
signal notice(message: String)
const FIELDS: Array[String] = ["routes"]
var routes: Dictionary = {}
var fleet_ref: WeakRef
var fleet: RefCounted:
	get: return fleet_ref.get_ref()

func _init(owner: RefCounted) -> void:
	fleet_ref = weakref(owner)

func capability(id: int) -> Dictionary:
	return fleet.model.ship_catalog[fleet.model.ships[id]].get("cargo_shuttle", {})

func storage(region: String) -> Dictionary:
	var station: String = fleet.model.locations.primary_station() if region == fleet.regions.HOME else fleet.model.locations.outpost_at(region, fleet.model.locations.rules.primary_station.owner)
	if station.is_empty(): return {}
	if station == fleet.model.locations.primary_station(): return fleet.diplomacy.inventory
	return fleet.model.locations.stations[station].inventory

func station_for(region: String) -> String:
	return fleet.model.locations.primary_station() if region == fleet.regions.HOME else fleet.model.locations.outpost_at(region, fleet.model.locations.rules.primary_station.owner)

func amount(region: String, resource: String) -> int:
	var station: String = station_for(region)
	if station.is_empty(): return 0
	if station == fleet.model.locations.primary_station():
		if resource == "materials": return fleet.model.materials
		if resource == "minerals": return fleet.model.minerals
		return int(fleet.diplomacy.inventory.get(resource, 0))
	return int(fleet.model.locations.stations[station].inventory.get(resource, 0))

func take(region: String, resource: String, value: int) -> void:
	var station: String = station_for(region)
	if station == fleet.model.locations.primary_station():
		if resource == "materials": fleet.model.materials -= value
		elif resource == "minerals": fleet.model.minerals -= value
		else: fleet.diplomacy.inventory[resource] = int(fleet.diplomacy.inventory.get(resource, 0)) - value
	else: fleet.model.locations.stations[station].inventory[resource] = int(fleet.model.locations.stations[station].inventory.get(resource, 0)) - value

func add(region: String, resource: String, value: int) -> void:
	var station: String = station_for(region)
	if station == fleet.model.locations.primary_station():
		if resource == "materials": fleet.model.materials += value
		elif resource == "minerals": fleet.model.minerals += value
		else: fleet.diplomacy.inventory[resource] = int(fleet.diplomacy.inventory.get(resource, 0)) + value
	else: fleet.model.locations.stations[station].inventory[resource] = int(fleet.model.locations.stations[station].inventory.get(resource, 0)) + value

func assign(id: int, source: String, destination: String) -> String:
	if not fleet.model.ships.has(id) or not fleet.model.ship_catalog[fleet.model.ships[id]].has("cargo_shuttle"): return "Select a Cargo Ship."
	if source == destination or not fleet.regions.is_discovered(source) or not fleet.regions.is_discovered(destination): return "Choose two different discovered regions."
	if not fleet.transport.has_gate(source) or not fleet.transport.has_gate(destination): return "Both route regions need a Teleport Gate."
	if fleet.unit_busy(id): return "Cargo Ship is already busy."
	var current: String = fleet.transport.location(id)
	if not fleet.transport.has_gate(current): return "Cargo Ship must be in a gated region to start its route."
	var route: Dictionary = {"source": source, "destination": destination, "phase": "to_source", "remaining": 0, "cargo": {}, "status": "In transit to source", "waiting": false}
	routes[id] = route
	if current == source:
		route.phase = "loading"
		route.remaining = int(capability(id).get("load_seconds", 2))
		_set_status(route, "Loading")
	else:
		var gate: String = _gate(current)
		var error: String = fleet.transport.jump(gate, id, source, true)
		if not error.is_empty():
			routes.erase(id)
			return error
	changed.emit()
	return ""

func _gate(region: String) -> String:
	for id: String in fleet.transport.all_gates():
		if fleet.model.locations.structures[id].region == region: return id
	return ""

func cancel(id: int) -> void:
	if routes.has(id):
		var route: Dictionary = routes[id]
		var region: String = fleet.transport.location(id)
		for resource: String in route.get("cargo", {}):
			add(region, resource, int(route.cargo[resource]))
	routes.erase(id)
	changed.emit()

func waiting_message() -> String:
	for route: Dictionary in routes.values():
		if route.get("waiting", false): return "Cargo Ship waiting — " + str(route.status).to_lower()
	return ""

func _set_status(route: Dictionary, status: String, waiting: bool = false) -> void:
	route.status = status
	route.waiting = waiting
	if waiting: notice.emit("Cargo Ship waiting — " + status.to_lower())

func _load(route: Dictionary) -> void:
	if station_for(route.source).is_empty():
		_set_status(route, "no local storage", true)
		return
	var remaining: int = int(capability_for(route).capacity)
	for resource: String in capability_for(route).resource_order:
		var load_amount: int = mini(remaining, amount(route.source, resource))
		if load_amount > 0:
			route.cargo[resource] = load_amount
			take(route.source, resource, load_amount)
			remaining -= load_amount
		if remaining <= 0: break
	_set_status(route, "Loaded %d units" % (int(capability_for(route).capacity) - remaining))

func capability_for(route: Dictionary) -> Dictionary:
	for id: int in routes:
		if routes[id] == route: return capability(id)
	return {"capacity": 50, "load_seconds": 2, "resource_order": ["materials", "minerals", "tech", "xenocrystal"]}

func _unload(id: int, route: Dictionary) -> bool:
	if station_for(route.destination).is_empty():
		_set_status(route, "no local storage", true)
		return false
	var station: String = station_for(route.destination)
	var local: StationModel = fleet.model if station == fleet.model.locations.primary_station() else fleet.model.scoped_station(station)
	var moved: int = 0
	for resource: String in route.cargo.keys():
		var amount: int = int(route.cargo[resource])
		var room: int = maxi(0, local.capacity - local.upgrade_resource_amount(resource))
		if resource in ["tech", "xenocrystal"] and station == fleet.model.locations.primary_station(): room = 999999
		var delivered: int = mini(amount, room)
		if delivered > 0:
			add(route.destination, resource, delivered)
			route.cargo[resource] -= delivered
			moved += delivered
		if route.cargo[resource] <= 0: route.cargo.erase(resource)
	if not route.cargo.is_empty():
		_set_status(route, "storage full", true)
		return false
	_set_status(route, "Unloaded %d units" % moved)
	return true

func tick() -> void:
	for id: int in routes.keys():
		if not fleet.model.ships.has(id): routes.erase(id); continue
		var route: Dictionary = routes[id]
		if fleet.transport.jobs.has(id): continue
		var region: String = fleet.transport.location(id)
		if route.phase == "to_source":
			if region != route.source: continue
			route.phase = "loading"; route.remaining = int(capability(id).get("load_seconds", 2)); _set_status(route, "Loading")
		elif route.phase == "loading":
			route.remaining -= 1
			if route.remaining <= 0:
				if route.cargo.is_empty(): _load(route)
				if route.cargo.is_empty(): route.remaining = int(capability(id).get("load_seconds", 2)); continue
				var error: String = fleet.transport.jump(_gate(route.source), id, route.destination, true)
				if not error.is_empty(): route.phase = "waiting_destination_jump"; _set_status(route, "not enough Xenocrystals for jump", true); continue
				route.phase = "to_destination"; _set_status(route, "In transit to destination")
		elif route.phase == "waiting_destination_jump":
			var error: String = fleet.transport.jump(_gate(route.source), id, route.destination, true)
			if error.is_empty(): route.phase = "to_destination"; _set_status(route, "In transit to destination")
			else: _set_status(route, "not enough Xenocrystals for jump", true)
		elif route.phase == "to_destination":
			if region == route.destination: route.phase = "unloading"; _set_status(route, "Unloading")
		elif route.phase == "unloading":
			if _unload(id, route):
				var error: String = fleet.transport.jump(_gate(route.destination), id, route.source, true)
				if error.is_empty(): route.phase = "to_source"; _set_status(route, "In transit to source")
				else: _set_status(route, "not enough Xenocrystals for jump", true)
	changed.emit()

func validate(data: Dictionary) -> String:
	if not data.get("routes", {}) is Dictionary: return "Invalid cargo shuttle state."
	for key: Variant in data.routes:
		if not key is int or not fleet.model.ships.has(key): return "Invalid cargo shuttle ship."
		var route: Variant = data.routes[key]
		if not route is Dictionary or not route.get("source", "") is String or not route.get("destination", "") is String: return "Invalid cargo shuttle route."
		if route.source == route.destination or not fleet.regions.catalog.has(route.source) or not fleet.regions.catalog.has(route.destination): return "Invalid cargo shuttle regions."
		if not route.get("phase", "") in ["to_source", "loading", "waiting_destination_jump", "to_destination", "unloading"] or not route.get("remaining", 0) is int or route.remaining < 0: return "Invalid cargo shuttle phase."
		if not route.get("cargo", {}) is Dictionary or not route.get("waiting", false) is bool or not route.get("status", "") is String: return "Invalid cargo shuttle state."
		var total: int = 0
		for resource: Variant in route.cargo:
			if not resource is String or not resource in ["materials", "minerals", "tech", "xenocrystal"] or not route.cargo[resource] is int or route.cargo[resource] < 0: return "Invalid cargo shuttle cargo."
			total += route.cargo[resource]
		if total > int(capability(key).get("capacity", 50)): return "Cargo shuttle load exceeds capacity."
	return ""
