class_name MiningFleet
extends RefCounted

signal changed
signal dispatched(unit: Variant, asteroid_id: int)
signal completed(unit: Variant, asteroid_id: int, amount: int)

const Regions = preload("res://scripts/region_model.gd")
var regions: Regions
const Trade = preload("res://scripts/trade_model.gd")
var diplomacy: Trade
const Research = preload("res://scripts/research_model.gd")
const Transport = preload("res://scripts/gate_transport.gd")
var research: Research
var transport: Transport
const Outposts = preload("res://scripts/outpost_model.gd")
var outposts: Outposts
var docking: RefCounted
var hauling: RefCounted
var collection: RefCounted
var cargo: RefCounted
var repairs: RefCounted
var model: StationModel
var asteroids: Dictionary = {}
const RESOURCE_FIELDS: Array[String] = ["resource_targets"]
# Typed floating-node bindings; asteroids retains the legacy quantity/job projection.
var resource_targets: Dictionary = {}
# Canonical mining assignments are keyed by stable, typed actor identity.
var mining_assignments: Dictionary = {}
# Legacy primary-station/UI/save adapter. Values reference the canonical job timers.
var jobs: Dictionary:
	get:
		var result: Dictionary = {}
		for assignment: Dictionary in mining_assignments.values():
			result[assignment.legacy_unit] = assignment.job
		return result
	set(value): import_mining_jobs(value)
var total_mined: int = 0
var next_discovery_id: int = -1000 # Keep -1 reserved for no-selection sentinels.

func _init(station: StationModel) -> void:
	model = station
	regions = Regions.new()
	model.region_context = regions
	regions.changed.connect(changed.emit)
	diplomacy = Trade.new(model)
	research = Research.new(model, diplomacy)
	model.research = research
	transport = Transport.new(self)
	outposts = Outposts.new(self)
	outposts.changed.connect(changed.emit)
	research.changed.connect(changed.emit)
	transport.changed.connect(changed.emit)
	diplomacy.changed.connect(changed.emit)
	model.module_removed.connect(cancel_unit)
	model.ship_removed.connect(cancel_unit)
	hauling = preload("res://scripts/refinery_hauling.gd").new(self)
	cargo = preload("res://scripts/cargo_shuttle.gd").new(self)
	repairs = preload("res://scripts/repair_ship.gd").new(self)
	docking = preload("res://scripts/docking_model.gd").new(self)
	repairs.changed.connect(changed.emit)
	cargo.changed.connect(func() -> void:
		changed.emit()
		model.changed.emit())

func register_asteroid(asteroid_id: int, amount: int) -> void:
	if not asteroids.has(asteroid_id) and amount > 0:
		asteroids[asteroid_id] = {"minerals": amount, "claimed": false}
		changed.emit()

func remove_asteroid(asteroid_id: int) -> bool:
	if not asteroids.has(asteroid_id) or asteroids[asteroid_id].claimed or asteroids[asteroid_id].get("persistent", false):
		return false
	asteroids.erase(asteroid_id)
	changed.emit()
	return true

func mining_units() -> Dictionary:
	var units: Dictionary = {}
	for world_position: Vector2 in model.modules:
		var definition: Dictionary = model.definition_at(world_position)
		if definition.has("mining"):
			units[world_position] = definition.mining
	for ship_id: int in model.ships:
		var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
		if definition.has("mining") and mining_work_error(ship_id).is_empty():
			units[ship_id] = definition.mining
	return units

func idle_count() -> int:
	var count: int = 0
	for unit: Variant in mining_units():
		if not unit_busy(unit):
			count += 1
	return count

func dispatch(asteroid_id: int, selected_ship: int = -1) -> String:
	if not asteroids.has(asteroid_id):
		return "That asteroid has left the region."
	if asteroids[asteroid_id].claimed:
		return "A ship is already mining this asteroid."
	if selected_ship != -1:
		var error: String = mining_error(selected_ship, asteroid_id)
		if not error.is_empty():
			return error
	var units: Dictionary = mining_units()
	if units.is_empty():
		if target_resource(asteroid_id) != "minerals":
			return "Build a Xeno Miner in this region to extract Xenocrystal nodes. Remote mining requires an outpost."
		if asteroid_region(asteroid_id) != regions.HOME:
			return "Local mining requires an outpost and a Miner sent through a Teleport Gate."
		return "Build a Miner in Ships or a Mining Ship module first."
	if selected_ship != -1 and not units.has(selected_ship):
		return "Select a Miner ship to assign an asteroid."
	for unit: Variant in units:
		if selected_ship != -1 and (not unit is int or unit != selected_ship):
			continue
		if unit_busy(unit):
			continue
		var capability: Dictionary = units[unit]
		if str(capability.get("resource", "minerals")) != target_resource(asteroid_id): continue
		var actor: Dictionary = model.locations.actor_for(unit)
		var route: Dictionary = mining_route(actor, asteroid_id)
		if route.is_empty():
			continue
		route["legacy_unit"] = unit
		route["job"] = {"target": asteroid_id, "remaining": int(capability.seconds), "duration": int(capability.seconds), "yield": int(capability.yield), "repeat": bool(capability.get("repeat", false))}
		mining_assignments[model.locations.actor_key(actor)] = route
		asteroids[asteroid_id].claimed = true
		dispatched.emit(unit, asteroid_id)
		changed.emit()
		return ""
	if target_resource(asteroid_id) != "minerals":
		return "No idle mining ship with the matching resource capability is in this region. Build a Xeno Miner for Xenocrystals."
	if asteroid_region(asteroid_id) == regions.HOME:
		return "Selected Miner is busy." if selected_ship != -1 else "All Mining Ships are busy. Wait for a mission to finish."
	return "No idle Miner is in this region. Remote mining requires a local outpost and a Miner sent through a gate."

func tick() -> void:
	hauling.tick()
	cargo.tick()
	repairs.advance(1.0)
	transport.tick()
	diplomacy.tick()
	_tick_regions()
	for unit: Variant in jobs.keys():
		var assignment: Dictionary = mining_assignment(unit)
		var job: Dictionary = assignment.job
		job.remaining -= 1
		if job.remaining > 0:
			continue
		var asteroid: Dictionary = asteroids[job.target]
		var amount: int = mini(int(job.yield), int(asteroid.minerals))
		asteroid.minerals -= amount
		if asteroid.minerals > 0 and job.repeat:
			job.remaining = job.duration
		else:
			asteroid.claimed = false
			erase_mining_assignment(unit)
			if asteroid.minerals <= 0:
				asteroids.erase(job.target)
		# Cargo is delivered on the same completion tick as before; no new travel leg.
		var resource: String = target_resource(int(job.target))
		assignment.cargo[resource] = amount
		var delivered: int = diplomacy.receive_goods(resource, amount) if assignment.destination.station_id == model.locations.primary_station() and diplomacy.goods_catalog.has(resource) else model.locations.receive(assignment.destination, resource, amount)
		assignment.cargo[resource] -= delivered
		if resource == "minerals": total_mined += amount
		completed.emit(unit, int(job.target), amount)
	changed.emit()

func cancel_unit(unit: Variant) -> void:
	if unit is Vector2 and hauling != null:
		for id: int in hauling.jobs.keys():
			if not model.locations.structures.has(hauling.jobs[id].refinery_id) and hauling.jobs[id].phase == "pickup": hauling.cancel(id)
	if jobs.has(unit):
		var target: int = jobs[unit].target
		if asteroids.has(target):
			asteroids[target].claimed = false
		erase_mining_assignment(unit)
	if unit is int:
		regions.survey_jobs.erase(unit)
		transport.cancel(unit)
		diplomacy.cancel(unit)
		hauling.cancel(unit)
		if collection != null:
			collection.cancel(unit)
		if cargo != null:
			cargo.cancel(unit)
		if repairs != null:
			repairs.cancel(unit)
	changed.emit()

# Logical marker coordinates, owned by the model so a checkpoint restores the same view.
static func discovery_position(asteroid_id: int) -> Vector2:
	var slots: Array[Vector2] = [Vector2(5.0 / 6.0, 1.0), Vector2(1.0 / 3.0, 0.0), Vector2(2.0 / 3.0, 0.0), Vector2(0.5, 1.0)]
	return slots[posmod(-asteroid_id - 1000, slots.size())]

func unit_busy(unit: Variant) -> bool:
	return (hauling != null and hauling.jobs.has(unit)) or cargo.routes.has(unit) or repairs.jobs.has(unit) or transport.jobs.has(unit) or (collection != null and collection.jobs.has(unit)) or jobs.has(unit) or diplomacy.jobs.has(unit) or regions.survey_jobs.has(unit)

func trade_error(ship_id: int, contact_id: String, offer_id: String) -> String:
	if not transport.work_error(ship_id).is_empty():
		return transport.work_error(ship_id)
	if unit_busy(ship_id):
		return "This ship is already on a mission."
	return diplomacy.trade_error(ship_id, contact_id, offer_id)

func trade(ship_id: int, contact_id: String, offer_id: String) -> String:
	var error: String = trade_error(ship_id, contact_id, offer_id)
	if not error.is_empty():
		return error
	return diplomacy.dispatch(ship_id, contact_id, offer_id)

func region_survey_error(ship_id: int, region_id: String) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("survey"):
		return "Build and select a Scout ship."
	if unit_busy(ship_id):
		return "This ship is already on a mission."
	return regions.survey_error(region_id, model.locations.regional_survey_origin(ship_id, regions.viewed_region))

func region_survey_duration(ship_id: int, region_id: String) -> int:
	var capability: Dictionary = model.ship_catalog[model.ships[ship_id]].survey
	return maxi(1, int(ceil(float(regions.catalog[region_id].survey_seconds) / float(capability.get("travel_speed", 1.0)))))

func survey_region(ship_id: int, region_id: String) -> String:
	var error: String = region_survey_error(ship_id, region_id)
	if not error.is_empty():
		return error
	var duration: int = region_survey_duration(ship_id, region_id)
	regions.begin_survey(ship_id, region_id, duration, model.locations.regional_survey_origin(ship_id, regions.viewed_region))
	changed.emit()
	return ""

func _tick_regions() -> void:
	for ship_id: int in regions.survey_jobs.keys():
		var job: Dictionary = regions.survey_jobs[ship_id]
		job.remaining -= 1
		if job.remaining <= 0:
			regions.survey_jobs.erase(ship_id)
			_discover_region(job.region_id)

func _discover_region(region_id: String) -> void:
	if not regions.generate(region_id):
		return
	var record: Dictionary = regions.records[region_id]
	for content: Dictionary in record.contents:
		if content.type == "asteroid":
			var asteroid_id: int = next_discovery_id
			next_discovery_id -= 1
			asteroids[asteroid_id] = {"minerals": int(content.minerals), "claimed": false, "persistent": true, "region_id": region_id, "name": content.name, "position": content.position}
			record.asteroid_ids.append(asteroid_id)
		elif content.type == "anomaly" and content.has("good"):
			diplomacy.inventory[content.good] = int(diplomacy.inventory.get(content.good, 0)) + int(content.amount)
	diplomacy.discover_region(region_id, regions.records[region_id])
	regions.announce_discovery(region_id)

func asteroid_region(asteroid_id: int) -> String:
	if resource_targets.has(asteroid_id): return resource_targets[asteroid_id].region
	return str(asteroids.get(asteroid_id, {}).get("region_id", Regions.HOME))

func mining_assignment(unit: Variant) -> Dictionary:
	for assignment: Dictionary in mining_assignments.values():
		if typeof(assignment.legacy_unit) == typeof(unit) and assignment.legacy_unit == unit:
			return assignment
	return {}

func erase_mining_assignment(unit: Variant) -> void:
	for key: String in mining_assignments.keys():
		if typeof(mining_assignments[key].legacy_unit) == typeof(unit) and mining_assignments[key].legacy_unit == unit:
			mining_assignments.erase(key)
			return

func import_mining_jobs(values: Dictionary) -> void:
	mining_assignments.clear()
	for unit: Variant in values:
		var actor: Dictionary = model.locations.actor_for(unit)
		var route: Dictionary = mining_route(actor, int(values[unit].target), true)
		if route.is_empty():
			continue
		route["legacy_unit"] = unit
		route["job"] = values[unit]
		mining_assignments[model.locations.actor_key(actor)] = route

func mining_work_error(ship_id: int) -> String:
	if transport.jobs.has(ship_id):
		return "Ship is in teleport transit."
	var world: RefCounted = model.locations
	if world.ship_region(ship_id) == regions.HOME:
		return ""
	if not world.ships.has(ship_id) or world.outpost_at(world.ship_region(ship_id), world.ships[ship_id].owner).is_empty():
		return "Found an outpost in this ship's region before mining."
	return ""

func mining_error(ship_id: int, asteroid_id: int) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("mining"):
		return "Select a Miner ship to assign an asteroid."
	if unit_busy(ship_id):
		return "Selected Miner is busy."
	if not asteroids.has(asteroid_id):
		return "That asteroid has left the region."
	if mining_resource(ship_id) != target_resource(asteroid_id):
		return "This ship mines %s only; choose a matching node." % mining_resource(ship_id).capitalize()
	if model.locations.ship_region(ship_id) != asteroid_region(asteroid_id):
		return "Send the Miner through a Teleport Gate to the asteroid's region first."
	return mining_work_error(ship_id)

func target_resource(target: int) -> String:
	return str(resource_targets.get(target, {}).get("resource", "minerals"))

func mining_resource(unit: Variant) -> String:
	var definition: Dictionary = model.ship_catalog[model.ships[unit]] if unit is int else model.definition_at(unit)
	return str(definition.get("mining", {}).get("resource", "minerals"))

func mining_route(actor: Dictionary, target: int, legacy: bool = false) -> Dictionary:
	var route: Dictionary = model.locations.mining_route(actor, target, asteroid_region(target), legacy)
	if not route.is_empty(): route.cargo = {target_resource(target): 0}
	return route
