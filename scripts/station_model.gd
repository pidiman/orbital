class_name StationModel
extends RefCounted
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

var decommission_rules: Dictionary = {}
var catalog: Dictionary = {}
var ship_catalog: Dictionary = {}
var ships: Dictionary = {}
var next_ship_id: int = 0
var module_tiers: Dictionary = {}
# Canonical continuous station-world centers, in world units (58 per module).
# Never round here: grid snapping belongs exclusively to the board input adapter.
var modules: Dictionary = {Vector2.ZERO: "habitat"}
var minerals: int = 0
var refinery_progress: Dictionary = {}
var total_refined: int = 0
var materials: int = 40
var capacity: int = 100
var power_output: int = 3
var power_use: int = 2
var level: int = 1
var ticks: int = 0

func _init() -> void:
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
	if not catalog.has(kind):
		return "Choose a module first."
	if not Geometry.contains_center(world_position):
		return "Build inside the station grid."
	for existing: Vector2 in modules:
		if Geometry.overlaps(world_position, existing):
			return "This cell already has a module."
	if not Geometry.touches_any(world_position, modules.keys()):
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
	modules[world_position] = kind
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

func _refine() -> void:
	var produced: int = 0
	for world_position: Vector2 in modules:
		var definition: Dictionary = definition_at(world_position)
		if not definition.has("conversion"):
			continue
		var recipe: Dictionary = definition.conversion
		# Pause without consuming input or discarding output when storage is full.
		if minerals < int(recipe.input) or capacity - materials < int(recipe.output):
			continue
		var progress: int = int(refinery_progress.get(world_position, 0)) + 1
		if progress >= int(recipe.seconds):
			minerals -= int(recipe.input)
			materials += int(recipe.output)
			produced += int(recipe.output)
			progress = 0
		refinery_progress[world_position] = progress
	if produced > 0:
		total_refined += produced
		refined.emit(produced)

func tier_at(world_position: Vector2) -> int:
	return int(module_tiers.get(world_position, 1))

func definition_at(world_position: Vector2) -> Dictionary:
	var definition: Dictionary = catalog[modules[world_position]].duplicate(true)
	var upgrades: Array = definition.get("upgrades", [])
	for index in range(mini(tier_at(world_position) - 1, upgrades.size())):
		definition.merge(upgrades[index].stats, true)
	return definition

func next_upgrade(world_position: Vector2) -> Dictionary:
	if not modules.has(world_position):
		return {}
	var upgrades: Array = catalog[modules[world_position]].get("upgrades", [])
	var index: int = tier_at(world_position) - 1
	return upgrades[index] if index < upgrades.size() else {}

func upgrade_error(world_position: Vector2) -> String:
	if not modules.has(world_position):
		return "Select an existing station module."
	var upgrade: Dictionary = next_upgrade(world_position)
	if upgrade.is_empty():
		return "Maximum tier reached."
	if materials < int(upgrade.cost.materials) or minerals < int(upgrade.cost.minerals):
		return "Upgrade needs %d Materials and %d Minerals." % [upgrade.cost.materials, upgrade.cost.minerals]
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
	materials -= int(upgrade.cost.materials)
	minerals -= int(upgrade.cost.minerals)
	module_tiers[world_position] = tier_at(world_position) + 1
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
	ships[next_ship_id] = kind
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
			invested += int(upgrades[index].cost.materials)
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
	modules.erase(world_position)
	module_tiers.erase(world_position)
	refinery_progress.erase(world_position)
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
	ships.erase(ship_id)
	recalculate()
	materials += refund
	ship_removed.emit(ship_id)
	changed.emit()
	return ""
