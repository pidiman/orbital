extends RefCounted
signal changed
var fleet_ref: WeakRef
var fleet: RefCounted:
	get: return fleet_ref.get_ref()
var catalog: Dictionary:
	get: return fleet.model.locations.outpost_catalog

func _init(ships: RefCounted) -> void:
	fleet_ref = weakref(ships)

func definition_for(ship_id: int) -> Dictionary:
	if not fleet.model.ships.has(ship_id):
		return {}
	var capability: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]].get("founding", {})
	return catalog.get(capability.get("outpost", ""), {})

func cost_text(ship_id: int) -> String:
	var definition: Dictionary = definition_for(ship_id)
	var parts: Array[String] = []
	for resource: String in founding_cost(definition):
		parts.append("%d Home %s" % [founding_cost(definition)[resource], resource.capitalize()])
	return " + ".join(parts)

func founding_error(ship_id: int) -> String:
	var definition: Dictionary = definition_for(ship_id)
	if definition.is_empty():
		return "Select a ship with outpost founding capability."
	if fleet.unit_busy(ship_id):
		return "Ship is busy or in transit. Wait for arrival."
	var world: RefCounted = fleet.model.locations
	var region: String = world.ship_region(ship_id)
	if region == world.station_region(world.primary_station()):
		return "Send this ship through a Teleport Gate to a non-Home region first."
	if not fleet.regions.is_discovered(region) or not fleet.regions.allows_outposts(region):
		return "This region is not unlocked for outpost founding."
	if not world.outpost_at(region, world.ships[ship_id].owner).is_empty():
		return "You already have an outpost in this region."
	for resource: String in founding_cost(definition):
		var available: int = fleet.model.materials if resource == "materials" else int(fleet.diplomacy.inventory.get(resource, 0))
		if available < int(founding_cost(definition)[resource]):
			return "Founding + starter transfer requires " + cost_text(ship_id) + "."
	return ""

func found(ship_id: int) -> String:
	var error: String = founding_error(ship_id)
	if not error.is_empty():
		return error
	var world: RefCounted = fleet.model.locations
	var ship: Dictionary = world.ships[ship_id]
	var kind: String = fleet.model.ship_catalog[ship.kind].founding.outpost
	var definition: Dictionary = catalog[kind]
	var station_id: String = "station:outpost:%d" % (world.next_structure_id + 1)
	# Instant transaction: one cost, one outpost, no pending UI-owned founding state.
	for resource: String in founding_cost(definition):
		if resource == "materials":
			fleet.model.materials -= int(founding_cost(definition)[resource])
		else:
			fleet.diplomacy.inventory[resource] -= int(founding_cost(definition)[resource])
	var inventory: Dictionary = {}
	for resource: String in definition.storage:
		inventory[resource] = int(definition.storage[resource]) + int(definition.get("starter_transfer", {}).get(resource, 0))
	world.stations[station_id] = {"id": station_id, "owner": ship.owner, "region": ship.region, "kind": kind, "inventory": inventory, "grid": {"columns": StationGeometry.grid_dimensions.x, "rows": StationGeometry.grid_dimensions.y}, "founding": {"state": "established", "ship_id": ship_id, "paid": definition.cost.duplicate(true), "starter_transfer": definition.get("starter_transfer", {}).duplicate(true)}}
	var point := Vector2(definition.position[0], definition.position[1])
	var structure_id: String = world.add_structure(station_id, kind, point)
	world.stations[station_id]["structure_id"] = structure_id
	ship["founding"] = {"state": "established", "station_id": station_id}
	changed.emit()
	fleet.model.changed.emit()
	fleet.diplomacy.changed.emit()
	return ""

func summary(region_id: String) -> String:
	var world: RefCounted = fleet.model.locations
	var id: String = world.outpost_at(region_id, world.rules.primary_station.owner)
	if id.is_empty():
		return "No outpost. Send a Jump Ship through a gate, then use Found outpost in Ships."
	var station: Dictionary = world.stations[id]
	var local: StationModel = fleet.model.scoped_station(id)
	return "%s · Local Materials %d/%d · Minerals %d · Xenocrystals %d · Power %+d (%d generated / %d used). No Home hauling." % [catalog[station.kind].name, local.materials, local.capacity, local.minerals, station.inventory.get("xenocrystal", 0), local.power_balance(), local.power_output, local.power_use]

func validate(world: Dictionary, regions: Dictionary, next_ship_id: int) -> String:
	var seen: Dictionary = {}
	for id: String in world.stations:
		if id == fleet.model.locations.primary_station():
			continue
		var station: Dictionary = world.stations[id]
		if not station.get("kind") is String or not catalog.has(station.kind) or station.region == fleet.regions.HOME or not fleet.regions.allows_outposts(station.region) or not regions.records[station.region].discovered or station.owner != fleet.model.locations.rules.primary_station.owner or seen.has(station.region):
			return "Invalid or duplicate outpost region/owner."
		seen[station.region] = true
		if not station.get("structure_id") is String or not world.structures.has(station.structure_id) or id != "station:outpost:" + station.structure_id.trim_prefix("structure:"):
			return "Missing outpost structure identity."
		var structure: Dictionary = world.structures[station.structure_id]
		if structure.station_id != id or structure.kind != station.kind:
			return "Outpost structure disagrees with its station."
		if not station.get("inventory") is Dictionary or station.inventory.keys().size() != catalog[station.kind].storage.keys().size():
			return "Invalid outpost inventory."
		for resource: String in catalog[station.kind].storage:
			if not quantity(station.inventory.get(resource)):
				return "Invalid local resource quantity."
		if station.has("grid"):
			if not station.grid is Dictionary: return "Invalid outpost grid."
			for axis: String in ["columns", "rows"]:
				if not quantity(station.grid.get(axis)) or station.grid[axis] < 9 or station.grid[axis] > 257 or int(station.grid[axis]) % 2 != 1: return "Invalid outpost grid dimensions."
		var founding: Variant = station.get("founding")
		if not founding is Dictionary or founding.get("state") != "established" or not quantity(founding.get("ship_id")) or founding.ship_id < 1 or founding.ship_id > next_ship_id or not founding.get("paid") is Dictionary:
			return "Invalid founding state."
		for resource: Variant in founding.paid:
			if not resource is String or (resource != "materials" and not fleet.diplomacy.goods_catalog.has(resource)) or not quantity(founding.paid[resource]):
				return "Invalid founding cost record."
		if founding.has("starter_transfer"):
			if not founding.starter_transfer is Dictionary: return "Invalid starter transfer record."
			for resource: Variant in founding.starter_transfer:
				if not resource is String or not catalog[station.kind].storage.has(resource) or not quantity(founding.starter_transfer[resource]): return "Invalid starter transfer quantity."
		var power: int = int(catalog[station.kind].base_power)
		for module: Dictionary in world.structures.values():
			if module.station_id != id: continue
			var definition: Dictionary = fleet.model.definition_for(module.kind, int(module.state.get("tier", 1)))
			power += int(definition.power_output) - int(definition.power_use)
		if power < 0: return "Outpost has insufficient local power."
		# The founding hull may have been decommissioned; its historical ID remains.
		if world.ships.has(int(founding.ship_id)):
			var ship: Dictionary = world.ships[int(founding.ship_id)]
			if ship.get("founding") != {"state": "established", "station_id": id} or ship.owner != station.owner or not fleet.model.ship_catalog[ship.kind].has("founding"):
				return "Founding ship disagrees with outpost."
	for structure: Dictionary in world.structures.values():
		if structure.station_id == fleet.model.locations.primary_station(): continue
		var station: Dictionary = world.stations[structure.station_id]
		if station.structure_id == structure.id: continue
		if not catalog[station.kind].buildable_modules.has(structure.kind): return "Unsupported outpost module."
		var tier: int = int(structure.state.get("tier", 1))
		if tier < 1 or tier > fleet.model.catalog[structure.kind].get("upgrades", []).size() + 1: return "Invalid outpost module tier."
		if not fleet.model.module_unlocked(structure.kind): return "Outpost module technology is locked."
		for cell: Vector2 in fleet.model.footprint_points(structure.position, structure.kind):
			var grid: Dictionary = station.get("grid", {"columns": StationGeometry.grid_dimensions.x, "rows": StationGeometry.grid_dimensions.y})
			var extent := Vector2((int(grid.columns) - 1) / 2.0, (int(grid.rows) - 1) / 2.0) * StationGeometry.MODULE_SIZE
			if not cell.is_finite() or absf(cell.x) > extent.x or absf(cell.y) > extent.y: return "Outpost module outside grid."
			for other: Dictionary in world.structures.values():
				if other.id == structure.id or other.station_id != structure.station_id: continue
				for occupied: Vector2 in fleet.model.footprint_points(other.position, other.kind):
					if StationGeometry.overlaps(cell, occupied): return "Overlapping outpost modules."

	for ship: Dictionary in world.ships.values():
		if ship.has("founding"):
			var founding: Variant = ship.founding
			if not founding is Dictionary or founding.get("state") != "established" or not founding.get("station_id") is String or not world.stations.has(founding.station_id) or world.stations[founding.station_id].get("founding", {}).get("ship_id") != ship.id:
				return "Invalid ship founding reference."
	return ""

static func quantity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= 9007199254740991

func short_summary(region_id: String) -> String:
	var world: RefCounted = fleet.model.locations
	var id: String = world.outpost_at(region_id, world.rules.primary_station.owner)
	return "No outpost · Found one with a Jump Ship." if id.is_empty() else "Outpost · %d local Minerals · No Home hauling" % world.stations[id].inventory.minerals

func founding_cost(definition: Dictionary) -> Dictionary:
	var result: Dictionary = definition.get("cost", {}).duplicate(true)
	for resource: String in definition.get("starter_transfer", {}):
		result[resource] = int(result.get(resource, 0)) + int(definition.starter_transfer[resource])
	return result
