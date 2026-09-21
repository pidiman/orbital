class_name StationModel
extends RefCounted
const Locations = preload("res://scripts/world_locations.gd")
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

# This model always owns the primary station at Earth; region structures are separate.
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
	get: return locations.position_state("tier")
	set(value): locations.import_position_state("tier", value)
# Primary-station position view, in continuous world units (58 per module).
# Never round here: grid snapping belongs exclusively to the board input adapter.
var modules: Dictionary:
	get: return locations.legacy_modules()
	set(value): locations.import_modules(value)
var minerals: int = 0
var refinery_progress: Dictionary:
	get: return locations.position_state("refinery_progress")
	set(value): locations.import_position_state("refinery_progress", value)
var total_refined: int = 0
var refinery_recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/refinery_recipes.json"))
var materials: int = 40
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
	capacity = 100
	power_output = 3
	power_use = 0
	for world_position: Vector2 in modules:
		var definition: Dictionary = definition_at(world_position)
		capacity += int(definition.capacity)
		power_output += int(definition.power_output)
		power_use += int(definition.power_use)
	for kind: String in ships.values():
		power_use += int(ship_catalog[kind].power_use)
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
	if region_context != null and not region_context.primary_station_visible():
		return "Station construction is Home-only. Jump back to Earth."
	if not catalog.has(kind):
		return "Choose a module first."
	if not catalog[kind].get("buildable", true):
		return "This legacy module is retired. Buy a Miner ship and build a Miner Dock instead."
	if not module_unlocked(kind):
		return "Research this module's technology in a Research Lab first."
	var points: Array[Vector2] = footprint_points(world_position, kind)
	var touching: bool = false
	for point: Vector2 in points:
		if not Geometry.contains_center(point):
			return "Build the entire footprint inside the station grid."
		for existing: Vector2 in modules:
			for occupied: Vector2 in footprint_points(existing, modules[existing]):
				if Geometry.overlaps(point, occupied):
					return "This footprint overlaps an existing module."
				if Geometry.connected(point, occupied):
					touching = true
	if not touching:
		return "Connect to an existing module's edge."
	var definition: Dictionary = catalog[kind]
	if materials < int(definition.cost):
		return "Need %d more materials. Click drifting debris." % (int(definition.cost) - materials)
	if power_balance() + int(definition.power_output) - int(definition.power_use) < 0:
		return "Not enough power. Build a Solar Panel."
	return ""

func build(world_position: Vector2, kind: String) -> String:
	var error: String = placement_error(world_position, kind)
	if not error.is_empty():
		return error
	var old_level: int = level
	materials -= int(catalog[kind].cost)
	locations.add_structure(locations.primary_station(), kind, world_position)
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
		if catalog[kind].has(capability):
			count += 1
	return count

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

func refinery_pause_reason(world_position: Vector2) -> String:
	var recipe: Dictionary = refinery_recipe(world_position)
	if upgrade_resource_amount(recipe.input_resource) < int(recipe.input): return "waiting for " + recipe.input_resource
	var output_stock: int = upgrade_resource_amount(recipe.output_resource)
	if output_stock < 0: return "output inventory unavailable"
	if recipe.get("output_capacity", "") == "station" and capacity - output_stock < int(recipe.output): return "storage full · paused"
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
			if recipe.output_resource == "materials":
				materials += int(recipe.output)
				produced += int(recipe.output)
			elif recipe.output_resource == "minerals": add_minerals(int(recipe.output))
			else: research.trade.receive_goods(recipe.output_resource, int(recipe.output))
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
	var definition: Dictionary = catalog.get(kind, {}).duplicate(true)
	var upgrades: Array = definition.get("upgrades", [])
	for index in range(mini(tier - 1, upgrades.size())):
		definition.merge(upgrades[index].stats, true)
	return definition

func next_upgrade(world_position: Vector2) -> Dictionary:
	if not modules.has(world_position):
		return {}
	var upgrades: Array = catalog[modules[world_position]].get("upgrades", [])
	var index: int = tier_at(world_position) - 1
	return upgrades[index] if index < upgrades.size() else {}

func upgrade_resource_amount(resource: String) -> int:
	match resource:
		"materials": return materials
		"minerals": return minerals
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
			_: research.trade.inventory[resource] -= amount
	structure_state(world_position)["tier"] = tier_at(world_position) + 1
	recalculate()
	module_upgraded.emit(world_position)
	changed.emit()
	return ""

func ship_error(kind: String) -> String:
	if not ship_catalog.has(kind):
		return "Unknown ship type."
	var definition: Dictionary = ship_catalog[kind]
	if materials < int(definition.cost):
		return "Need %d more Materials for this ship." % (int(definition.cost) - materials)
	if power_balance() < int(definition.power_use):
		return "Not enough power. Add or upgrade a Solar Panel."
	return ""

func buy_ship(kind: String) -> String:
	var error: String = ship_error(kind)
	if not error.is_empty():
		return error
	materials -= int(ship_catalog[kind].cost)
	next_ship_id += 1
	locations.add_ship(next_ship_id, kind, locations.primary_station())
	recalculate()
	ship_built.emit(next_ship_id)
	changed.emit()
	return ""

func module_refund(world_position: Vector2) -> int:
	if not modules.has(world_position):
		return 0
	var definition: Dictionary = catalog[modules[world_position]]
	var invested: int = int(definition.cost)
	if decommission_rules.refund_upgrade_materials:
		var upgrades: Array = definition.get("upgrades", [])
		for index in range(mini(tier_at(world_position) - 1, upgrades.size())):
			invested += int(upgrades[index].cost.get("materials", 0))
	return int(floor(invested * float(definition.get("refund_ratio", decommission_rules.materials_refund_ratio))))

func demolition_error(world_position: Vector2) -> String:
	if not modules.has(world_position):
		return "Select a placed module."
	if decommission_rules.protect_starting_habitat and world_position == Vector2.ZERO:
		return "The starting habitat is your permanent colony core."
	var definition: Dictionary = definition_at(world_position)
	if power_balance() - int(definition.power_output) + int(definition.power_use) < 0:
		return "Decommission power consumers first, or add generation."
	return ""

func demolish_module(world_position: Vector2) -> String:
	var error: String = demolition_error(world_position)
	if not error.is_empty():
		return error
	var refund: int = module_refund(world_position)
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
	var size: Array = catalog[kind].get("footprint", [1, 1])
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
	return locations.structure_at(locations.primary_station(), point)

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
	locations.import_position_state(capability, values)
