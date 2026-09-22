class_name StationModel
extends RefCounted
const Locations = preload("res://scripts/world_locations.gd")
var station_id: String = ""
var locations: Locations
const Geometry = preload("res://scripts/station_geometry.gd")

signal module_removed(world_position: Vector2)
signal ship_removed(ship_id: int)
signal changed
signal ship_built(ship_id: int)
signal module_upgraded(world_position: Vector2)
signal ticked
signal refined(amount: int)
signal module_built(world_position: Vector2, kind: String)
signal level_reached(level: int)

# Default instance owns Home. Scoped adapters share canonical locations and target one outpost.
var research: RefCounted
var region_context: RefCounted
var decommission_rules: Dictionary = {}
var catalog: Dictionary = {}
var ship_catalog: Dictionary = {}
var ships: Dictionary:
	get: return locations.legacy_ships()
	set(value): locations.import_ships(value)
var next_ship_id: int = 0
var module_tiers: Dictionary:
	get: return locations.position_state("tier", station_id)
	set(value): locations.import_position_state("tier", value, station_id)
# Primary-station position view, in continuous world units (58 per module).
# Never round here: grid snapping belongs exclusively to the board input adapter.
var modules: Dictionary:
	get: return locations.legacy_modules(station_id)
	set(value): locations.import_modules(value, station_id)
var home_minerals: int = 0
var minerals: int:
	get: return home_minerals if station_id.is_empty() else int(locations.stations[station_id].inventory.get("minerals", 0))
	set(value):
		if station_id.is_empty(): home_minerals = value
		else: locations.stations[station_id].inventory["minerals"] = value
var refinery_progress: Dictionary:
	get: return locations.position_state("refinery_progress", station_id)
	set(value): locations.import_position_state("refinery_progress", value, station_id)
var total_refined: int = 0
var refinery_recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/refinery_recipes.json"))
var home_materials: int = 40
var materials: int:
	get: return home_materials if station_id.is_empty() else int(locations.stations[station_id].inventory.get("materials", 0))
	set(value):
		if station_id.is_empty(): home_materials = value
		else: locations.stations[station_id].inventory["materials"] = value
var capacity: int = 100
var power_output: int = 3
var power_use: int = 2
var level: int = 1
var ticks: int = 0
var tick_elapsed: float = 0.0

func _init() -> void:
	locations = Locations.new(self)
	locations.add_structure(locations.primary_station(), "habitat", Vector2.ZERO)
	decommission_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/decommission.json"))
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/modules.json"))
	ship_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json"))
	recalculate()

func recalculate() -> void:
	var is_home: bool = station_id.is_empty() or station_id == locations.primary_station()
	var station: Dictionary = locations.stations.get(station_id, {})
	var outpost: Dictionary = {} if is_home else locations.outpost_catalog.get(str(station.get("kind", "")), {})
	# Home never uses the outpost catalog; stale/unknown scopes have safe defaults.
	capacity = int(outpost.get("base_capacity", 100))
	power_output = int(outpost.get("base_power", 3))
	power_use = 0
	for world_position: Vector2 in modules:
		var definition: Dictionary = definition_at(world_position)
		capacity += int(definition.capacity)
		power_output += int(definition.power_output)
		power_use += int(definition.power_use)
	for ship: Dictionary in locations.ships.values():
		if ship.station_id == base_id():
			power_use += int(ship_catalog[ship.kind].power_use)
	level = 1 + int((modules.size() - 1) / 4.0)

func power_balance() -> int:
	return power_output - power_use

func tick() -> void:
	ticks += 1
	recalculate()
	_refine()
	ticked.emit()
	changed.emit()

func placement_error(world_position: Vector2, kind: String) -> String:
	if region_context != null and region_context.current_region != locations.station_region(base_id()):
		return "View this station’s region before building."
	if not station_id.is_empty() and not locations.outpost_catalog[locations.stations[station_id].kind].buildable_modules.has(kind):
		return "Outposts support Solar, Storage, Space Dock and Teleport Gate only."
	if not catalog.has(kind):
		return "Choose a module first."
	if not catalog[kind].get("buildable", true):
		return "This legacy module is retired. Use Space Dock for parking and ships for missions."
	if not module_unlocked(kind):
		return "Research this module's technology in a Research Lab first."
	var points: Array[Vector2] = footprint_points(world_position, kind)
	var touching: bool = modules.is_empty()
	for point: Vector2 in points:
		if not grid_contains(point):
			return "Build the entire footprint inside the station grid."
		for existing: Vector2 in modules:
			for occupied: Vector2 in footprint_points(existing, modules[existing]):
				if Geometry.overlaps(point, occupied):
					return "This footprint overlaps an existing module."
				if Geometry.connected(point, occupied):
					touching = true
	if not touching:
		return "Must be placed next to an existing module or tube."
	var definition: Dictionary = catalog[kind]
	if materials < int(definition.cost):
		return "Need %d more %sMaterials." % [int(definition.cost) - materials, "local " if not station_id.is_empty() else ""]
	if power_balance() + int(definition.power_output) - int(definition.power_use) < 0:
		return "Not enough power. Build a Solar Panel."
	return ""

func build(world_position: Vector2, kind: String) -> String:
	var error: String = placement_error(world_position, kind)
	if not error.is_empty():
		return error
	var old_level: int = level
	materials -= int(catalog[kind].cost)
	locations.add_structure(base_id(), kind, world_position)
	recalculate()
	module_built.emit(world_position, kind)
	changed.emit()
	if level > old_level:
		level_reached.emit(level)
	return ""

func collect(amount: int) -> int:
	var received: int = mini(maxi(amount, 0), maxi(0, capacity - materials))
	materials += received
	if received > 0:
		changed.emit()
	return received

func add_minerals(amount: int) -> void:
	minerals += maxi(0, amount)
	changed.emit()

func module_count_with(capability: String) -> int:
	var count: int = 0
	for kind: String in modules.values():
		if catalog.get(kind, {}).has(capability):
			count += 1
	return count

func refinery_buffer(world_position: Vector2) -> Dictionary:
	var state: Dictionary = structure_state(world_position)
	if not state.has("output_buffer"): state["output_buffer"] = {}
	return state.output_buffer

func refinery_buffer_space(world_position: Vector2) -> int:
	var used: int = 0
	for amount: int in refinery_buffer(world_position).values(): used += amount
	return int(definition_at(world_position).get("output_buffer_capacity", 30)) - used

# Recovery on demolition/decommission preserves already produced goods, like trade cargo.
func recover_goods(resource: String, amount: int) -> void:
	if resource == "materials": materials += amount
	elif resource == "minerals": minerals += amount
	elif research != null: research.trade.receive_goods(resource, amount)

func refinery_recipe_id(world_position: Vector2) -> String:
	var definition: Dictionary = definition_at(world_position)
	return str(structure_state(world_position).get("refinery_recipe", definition.get("default_recipe", "minerals_materials")))

func refinery_recipe(world_position: Vector2, tier: int = -1) -> Dictionary:
	var recipe: Dictionary = refinery_recipes[refinery_recipe_id(world_position)].duplicate(true)
	var effective_tier: int = tier_at(world_position) if tier < 0 else tier
	if recipe.get("module_conversion", false):
		recipe.merge(definition_for(modules[world_position], effective_tier).conversion, true)
	elif recipe.has("tier_seconds"):
		recipe.seconds = recipe.tier_seconds[mini(effective_tier - 1, recipe.tier_seconds.size() - 1)]
	return recipe

func set_refinery_recipe(world_position: Vector2, recipe_id: String) -> String:
	if not modules.has(world_position) or not definition_at(world_position).get("recipes", []).has(recipe_id): return "Choose a valid Refinery recipe."
	if refinery_recipe_id(world_position) == recipe_id: return ""
	structure_state(world_position)["refinery_recipe"] = recipe_id
	structure_state(world_position)["refinery_progress"] = 0
	changed.emit()
	return ""

func refinery_running(world_position: Vector2) -> bool:
	return bool(structure_state(world_position).get("refinery_running", true))

func set_refinery_running(world_position: Vector2, running: bool) -> String:
	if not modules.has(world_position) or not definition_at(world_position).has("conversion"): return "Choose a Refinery."
	if refinery_running(world_position) == running: return ""
	structure_state(world_position)["refinery_running"] = running
	changed.emit()
	return ""

func refinery_pause_reason(world_position: Vector2) -> String:
	if not refinery_running(world_position): return "Stopped"
	var recipe: Dictionary = refinery_recipe(world_position)
	if refinery_buffer_space(world_position) < int(recipe.output): return "buffer full · paused"
	if upgrade_resource_amount(recipe.input_resource) < int(recipe.input): return "waiting for " + recipe.input_resource
	return ""

func refinery_status(world_position: Vector2) -> String:
	var reason: String = refinery_pause_reason(world_position)
	if not reason.is_empty(): return reason
	var recipe: Dictionary = refinery_recipe(world_position)
	return "next batch in %ds" % (int(recipe.seconds) - int(refinery_progress.get(world_position, 0)))

func _refine() -> void:
	var produced: int = 0
	for world_position: Vector2 in modules:
		if not definition_at(world_position).has("conversion"): continue
		var recipe: Dictionary = refinery_recipe(world_position)
		if not refinery_pause_reason(world_position).is_empty(): continue
		var progress: int = int(refinery_progress.get(world_position, 0)) + 1
		if progress >= int(recipe.seconds):
			match recipe.input_resource:
				"minerals": minerals -= int(recipe.input)
				"materials": materials -= int(recipe.input)
				_: research.trade.inventory[recipe.input_resource] -= int(recipe.input)
			var buffer: Dictionary = refinery_buffer(world_position)
			buffer[recipe.output_resource] = int(buffer.get(recipe.output_resource, 0)) + int(recipe.output)
			if recipe.output_resource == "materials": produced += int(recipe.output)
			progress = 0
		structure_state(world_position)["refinery_progress"] = progress
	if produced > 0:
		total_refined += produced
		refined.emit(produced)

func tier_at(world_position: Vector2) -> int:
	return int(module_tiers.get(world_position, 1))

func definition_at(world_position: Vector2) -> Dictionary:
	return definition_for(modules[world_position], tier_at(world_position))

func structure_definition(structure_id: String) -> Dictionary:
	var structure: Dictionary = locations.structures[structure_id]
	return definition_for(structure.kind, int(structure.state.get("tier", 1)))

func definition_for(kind: String, tier: int) -> Dictionary:
	var definition: Dictionary = catalog.get(kind, locations.outpost_catalog.get(kind, {})).duplicate(true)
	if not catalog.has(kind): definition.merge({"cost": 0, "power_output": 0, "power_use": 0, "capacity": 0}, true)
	var upgrades: Array = definition.get("upgrades", [])
	for index in range(mini(tier - 1, upgrades.size())):
		definition.merge(upgrades[index].stats, true)
	return definition

func next_upgrade(world_position: Vector2) -> Dictionary:
	if not modules.has(world_position):
		return {}
	var upgrades: Array = catalog.get(modules[world_position], {}).get("upgrades", [])
	var index: int = tier_at(world_position) - 1
	return upgrades[index] if index < upgrades.size() else {}

func upgrade_resource_amount(resource: String) -> int:
	match resource:
		"materials": return materials
		"minerals": return minerals
	if not station_id.is_empty(): return int(locations.stations[station_id].inventory.get(resource, -1))
	return int(research.trade.inventory.get(resource, -1)) if research != null else -1

func upgrade_cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for resource: String in cost:
		parts.append("%d %s" % [int(cost[resource]), resource.capitalize()])
	return " + ".join(parts) if not parts.is_empty() else "Free"

func upgrade_error(world_position: Vector2) -> String:
	if not modules.has(world_position):
		return "Select an existing station module."
	var upgrade: Dictionary = next_upgrade(world_position)
	if upgrade.is_empty():
		return "Maximum tier reached."
	for resource: String in upgrade.cost:
		if upgrade_resource_amount(resource) < int(upgrade.cost[resource]):
			return "Upgrade needs " + upgrade_cost_text(upgrade.cost) + "."
	var current: Dictionary = definition_at(world_position)
	var future: Dictionary = current.duplicate(true)
	future.merge(upgrade.stats, true)
	var power_delta: int = int(future.power_output) - int(current.power_output) - int(future.power_use) + int(current.power_use)
	if power_balance() + power_delta < 0:
		return "Not enough power for this upgrade."
	return ""

func upgrade_module(world_position: Vector2) -> String:
	var error: String = upgrade_error(world_position)
	if not error.is_empty():
		return error
	var upgrade: Dictionary = next_upgrade(world_position)
	for resource: String in upgrade.cost:
		var amount: int = int(upgrade.cost[resource])
		match resource:
			"materials": materials -= amount
			"minerals": minerals -= amount
			_:
				if station_id.is_empty(): research.trade.inventory[resource] -= amount
				else: locations.stations[station_id].inventory[resource] -= amount
	structure_state(world_position)["tier"] = tier_at(world_position) + 1
	recalculate()
	module_upgraded.emit(world_position)
	changed.emit()
	return ""

func apply_starting_resources() -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/new_game.json"))
	materials = int(rules.materials_buffer)
	for kind: String in rules.starter_modules: materials += int(catalog[kind].cost)
	# Starter infrastructure is deliberately structural and free; it gives a
	# fresh colony a connected expansion path without changing the economy.
	for raw_position: Array in rules.get("starter_tubes", []):
		locations.add_structure(base_id(), "connector_tube", Vector2(raw_position[0], raw_position[1]))
	recalculate()

func purchase_base() -> String:
	if not station_id.is_empty(): return station_id
	if region_context == null or region_context.current_region == locations.station_region(locations.primary_station()): return locations.primary_station()
	return locations.outpost_at(region_context.current_region, locations.rules.primary_station.owner)

func purchase_depot(base: String) -> String:
	for id: String in locations.structures:
		var structure: Dictionary = locations.structures[id]
		if structure.station_id == base and catalog.get(structure.kind, {}).has("material_depot"): return id
	return ""

func ship_error(kind: String) -> String:
	var base: String = purchase_base()
	if base.is_empty() or purchase_depot(base).is_empty(): return "Build a Space Depot first."
	if not ship_catalog.has(kind): return "Unknown ship type."
	var local: StationModel = self if base == base_id() else scoped_station(base)
	local.recalculate()
	var definition: Dictionary = ship_catalog[kind]
	if local.materials < int(definition.cost):
		return "Need %d more Materials for this ship." % (int(definition.cost) - local.materials)
	if local.power_balance() < int(definition.power_use):
		return "Not enough power. Add or upgrade a Solar Panel."
	return ""

func buy_ship(kind: String) -> String:
	var error: String = ship_error(kind)
	if not error.is_empty(): return error
	var base: String = purchase_base()
	var local: StationModel = self if base == base_id() else scoped_station(base)
	local.materials -= int(ship_catalog[kind].cost)
	# Canonical IDs remain global even when buying at an outpost.
	for id: int in locations.ships: next_ship_id = maxi(next_ship_id, id)
	next_ship_id += 1
	locations.add_ship(next_ship_id, kind, base)
	locations.ships[next_ship_id]["purchase_position"] = locations.structures[purchase_depot(base)].position
	recalculate()
	ship_built.emit(next_ship_id)
	changed.emit()
	return ""

func module_refund(world_position: Vector2) -> int:
	if not modules.has(world_position):
		return 0
	var definition: Dictionary = definition_for(modules[world_position], 1)
	var invested: int = int(definition.cost)
	if decommission_rules.refund_upgrade_materials:
		var upgrades: Array = definition.get("upgrades", [])
		for index in range(mini(tier_at(world_position) - 1, upgrades.size())):
			invested += int(upgrades[index].cost.get("materials", 0))
	return int(floor(invested * float(definition.get("refund_ratio", decommission_rules.materials_refund_ratio))))

func demolition_error(world_position: Vector2) -> String:
	if not modules.has(world_position):
		return "Select a placed module."
	if (station_id.is_empty() and decommission_rules.protect_starting_habitat and world_position == Vector2.ZERO) or (not station_id.is_empty() and structure_id_at(world_position) == locations.stations[station_id].structure_id):
		return "The starting habitat is your permanent colony core." if station_id.is_empty() else "The outpost core cannot be demolished."
	var definition: Dictionary = definition_at(world_position)
	if power_balance() - int(definition.power_output) + int(definition.power_use) < 0:
		return "Decommission power consumers first, or add generation."
	return ""

func demolish_module(world_position: Vector2) -> String:
	var error: String = demolition_error(world_position)
	if not error.is_empty():
		return error
	var refund: int = module_refund(world_position)
	for resource: String in structure_state(world_position).get("output_buffer", {}):
		recover_goods(resource, int(structure_state(world_position).output_buffer[resource]))
	locations.structures.erase(structure_id_at(world_position))
	recalculate()
	# Keep existing stock and the full refund, even after removing Storage.
	# Above-capacity stock can be spent; salvage/refining pause until there is room.
	materials += refund
	module_removed.emit(world_position)
	changed.emit()
	return ""

func ship_refund(ship_id: int) -> int:
	if not ships.has(ship_id):
		return 0
	var definition: Dictionary = ship_catalog[ships[ship_id]]
	return int(floor(int(definition.cost) * float(definition.get("refund_ratio", decommission_rules.materials_refund_ratio))))

func decommission_ship(ship_id: int) -> String:
	if not ships.has(ship_id):
		return "This ship has already been decommissioned."
	var refund: int = ship_refund(ship_id)
	locations.ships.erase(ship_id)
	recalculate()
	materials += refund
	ship_removed.emit(ship_id)
	changed.emit()
	return ""

func module_unlocked(kind: String) -> bool:
	if research != null:
		return research.unlocked("modules", kind)
	# Station-only callers still enforce catalog locks before a fleet is attached.
	var technologies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/technologies.json"))
	for technology: Dictionary in technologies.values():
		if technology.unlocks.get("modules", []).has(kind):
			return false
	return true

func footprint_size(kind: String) -> Vector2:
	var size: Array = catalog.get(kind, {}).get("footprint", [1, 1])
	return Vector2(size[0], size[1])

func footprint_points(origin: Vector2, kind: String) -> Array[Vector2]:
	var size: Vector2 = footprint_size(kind)
	var points: Array[Vector2] = []
	for x in range(int(size.x)):
		for y in range(int(size.y)):
			points.append(origin + (Vector2(x, y) - (size - Vector2.ONE) * 0.5) * Geometry.MODULE_SIZE)
	return points

func footprint_rect(origin: Vector2, kind: String) -> Rect2:
	var size: Vector2 = footprint_size(kind) * Geometry.MODULE_SIZE
	return Rect2(origin - size * 0.5, size)

func modules_connected(a: Vector2, b: Vector2) -> bool:
	for first: Vector2 in footprint_points(a, modules[a]):
		for second: Vector2 in footprint_points(b, modules[b]):
			if Geometry.connected(first, second):
				return true
	return false

# Position APIs are primary-station adapters, not global structure identity.
func structure_id_at(point: Vector2) -> String:
	return locations.structure_at(base_id(), point)

func structure_state(point: Vector2) -> Dictionary:
	return locations.structures[structure_id_at(point)].state

func capability_states(capability: String, defaults: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for point: Vector2 in modules:
		if definition_at(point).has(capability):
			var state: Dictionary = structure_state(point)
			if not state.has(capability):
				state[capability] = defaults.duplicate(true)
			result[point] = state[capability]
	return result

func import_capability_states(capability: String, values: Dictionary) -> void:
	locations.import_position_state(capability, values, station_id)

func base_id() -> String:
	return locations.primary_station() if station_id.is_empty() else station_id

func scoped_station(id: String) -> StationModel:
	if id == locations.primary_station(): return self
	var scoped := StationModel.new()
	scoped.locations = locations
	scoped.station_id = id
	scoped.catalog = catalog.duplicate(true)
	var core: String = locations.stations[id].kind
	scoped.catalog[core] = definition_for(core, 1)
	scoped.research = research
	scoped.region_context = region_context
	scoped.recalculate()
	scoped.ship_built.connect(func(id: int) -> void:
		next_ship_id = maxi(next_ship_id, id)
		ship_built.emit(id))
	scoped.changed.connect(func() -> void:
		recalculate()
		changed.emit())
	return scoped

func build_grid_dimensions() -> Vector2i:
	if station_id.is_empty(): return Geometry.grid_dimensions
	var grid: Dictionary = locations.stations[station_id].get("grid", {})
	return Vector2i(int(grid.get("columns", Geometry.grid_dimensions.x)), int(grid.get("rows", Geometry.grid_dimensions.y)))

func grid_contains(point: Vector2) -> bool:
	var extent: Vector2 = Vector2(build_grid_dimensions() - Vector2i.ONE) * 0.5 * Geometry.MODULE_SIZE
	return point.is_finite() and absf(point.x) <= extent.x and absf(point.y) <= extent.y
