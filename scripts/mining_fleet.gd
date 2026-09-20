class_name MiningFleet
extends RefCounted

signal changed
signal dispatched(unit: Variant, asteroid_id: int)
signal completed(unit: Variant, asteroid_id: int, amount: int)
signal surveyed(sector: Dictionary)
signal survey_started(ship_id: int, sector_id: String)

const Regions = preload("res://scripts/region_model.gd")
var regions: Regions
const Trade = preload("res://scripts/trade_model.gd")
var diplomacy: Trade
const Research = preload("res://scripts/research_model.gd")
const Transport = preload("res://scripts/gate_transport.gd")
var research: Research
var transport: Transport
var collection: RefCounted
var model: StationModel
var asteroids: Dictionary = {}
# Vector2 keys are Phase 1 station docks; integer keys are independent ships.
var jobs: Dictionary = {}
var survey_jobs: Dictionary = {}
var sectors: Array = []
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
	research.changed.connect(changed.emit)
	transport.changed.connect(changed.emit)
	diplomacy.changed.connect(changed.emit)
	model.module_removed.connect(cancel_unit)
	model.ship_removed.connect(cancel_unit)
	sectors = JSON.parse_string(FileAccess.get_file_as_string("res://data/sectors.json"))
	diplomacy.enrich_sectors(sectors)

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
		if definition.has("mining") and transport.work_error(ship_id).is_empty():
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
		return "That asteroid has left the sector."
	if asteroids[asteroid_id].claimed:
		return "A ship is already mining this asteroid."
	var units: Dictionary = mining_units()
	if units.is_empty():
		return "Build a Miner in Ships or a Mining Ship module first."
	if selected_ship != -1 and not units.has(selected_ship):
		return "Select a Miner ship to assign an asteroid."
	for unit: Variant in units:
		if selected_ship != -1 and (not unit is int or unit != selected_ship):
			continue
		if unit_busy(unit):
			continue
		var capability: Dictionary = units[unit]
		jobs[unit] = {"target": asteroid_id, "remaining": int(capability.seconds), "duration": int(capability.seconds), "yield": int(capability.yield), "repeat": bool(capability.get("repeat", false))}
		asteroids[asteroid_id].claimed = true
		dispatched.emit(unit, asteroid_id)
		changed.emit()
		return ""
	return "Selected Miner is busy." if selected_ship != -1 else "All Mining Ships are busy. Wait for a mission to finish."

func sector_by_id(sector_id: String) -> Dictionary:
	for sector: Dictionary in sectors:
		if sector.id == sector_id:
			return sector
	return {}

func sector_state(sector_id: String) -> String:
	var sector: Dictionary = sector_by_id(sector_id)
	if sector.is_empty():
		return "unknown"
	if sector.revealed:
		return "revealed"
	return "exploring" if not sector_job(sector_id).is_empty() else "unexplored"

func sector_job(sector_id: String) -> Dictionary:
	for job: Dictionary in survey_jobs.values():
		if job.sector_id == sector_id:
			return job
	return {}

func sector_reachable(sector_id: String) -> bool:
	var sector: Dictionary = sector_by_id(sector_id)
	if sector.is_empty():
		return false
	for origin: String in sector.get("reachable_from", []):
		if regions.is_discovered(origin):
			return true
		var predecessor: Dictionary = sector_by_id(origin)
		if not predecessor.is_empty() and predecessor.revealed:
			return true
	return false

func travel_duration(ship_id: int, sector_id: String) -> int:
	var sector: Dictionary = sector_by_id(sector_id)
	var capability: Dictionary = model.ship_catalog[model.ships[ship_id]].survey
	return maxi(1, int(ceil(float(sector.get("travel_seconds", capability.seconds)) / float(capability.get("travel_speed", 1.0)))))

func survey_error(ship_id: int, sector_id: String) -> String:
	if not transport.work_error(ship_id).is_empty():
		return transport.work_error(ship_id)
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("survey"):
		return "Build and select a Scout ship."
	if unit_busy(ship_id):
		return "This ship is already on a mission."
	if not sector_reachable(sector_id):
		return "That sector has no discovered route."
	if sector_state(sector_id) == "revealed":
		return "This sector is already revealed."
	if sector_state(sector_id) == "exploring":
		return "A Scout is already exploring this sector."
	return ""

# The no-destination shortcut remains available for the Phase 2 ship command.
func survey(ship_id: int, sector_id: String = "") -> String:
	if sector_id.is_empty():
		for sector: Dictionary in sectors:
			if sector_state(sector.id) == "unexplored" and sector_reachable(sector.id):
				sector_id = sector.id
				break
		if sector_id.is_empty():
			return "All adjacent sectors are revealed or being explored."
	var error: String = survey_error(ship_id, sector_id)
	if not error.is_empty():
		return error
	var duration: int = travel_duration(ship_id, sector_id)
	survey_jobs[ship_id] = {"sector_id": sector_id, "remaining": duration, "duration": duration}
	survey_started.emit(ship_id, sector_id)
	changed.emit()
	return ""

func _reveal(sector_id: String) -> void:
	var sector: Dictionary = sector_by_id(sector_id)
	if sector.revealed:
		return
	sector.revealed = true
	sector["asteroid_ids"] = []
	for content: Dictionary in sector.get("contents", []):
		if content.type == "asteroid" and int(content.get("minerals", 0)) > 0:
			var asteroid_id: int = next_discovery_id
			next_discovery_id -= 1
			asteroids[asteroid_id] = {"minerals": int(content.minerals), "claimed": false, "persistent": true, "sector_id": sector_id, "name": content.get("name", "Deposit"), "position": discovery_position(asteroid_id)}
			sector.asteroid_ids.append(asteroid_id)
	diplomacy.discover(sector)
	surveyed.emit(sector)

func revealed_count() -> int:
	var count: int = 0
	for sector: Dictionary in sectors:
		if sector.revealed:
			count += 1
	return count

func tick() -> void:
	transport.tick()
	diplomacy.tick()
	_tick_regions()
	for unit: Variant in jobs.keys():
		var job: Dictionary = jobs[unit]
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
			jobs.erase(unit)
			if asteroid.minerals <= 0:
				asteroids.erase(job.target)
		model.add_minerals(amount)
		total_mined += amount
		completed.emit(unit, int(job.target), amount)
	for ship_id: int in survey_jobs.keys():
		var job: Dictionary = survey_jobs[ship_id]
		job.remaining -= 1
		if job.remaining <= 0:
			survey_jobs.erase(ship_id)
			_reveal(job.sector_id)
	changed.emit()

func cancel_unit(unit: Variant) -> void:
	if jobs.has(unit):
		var target: int = jobs[unit].target
		if asteroids.has(target):
			asteroids[target].claimed = false
		jobs.erase(unit)
	if unit is int:
		survey_jobs.erase(unit)
		regions.survey_jobs.erase(unit)
		transport.cancel(unit)
		diplomacy.cancel(unit)
		if collection != null:
			collection.cancel(unit)
	changed.emit()

# Logical marker coordinates, owned by the model so a checkpoint restores the same view.
static func discovery_position(asteroid_id: int) -> Vector2:
	var slots: Array[Vector2] = [Vector2(5.0 / 6.0, 1.0), Vector2(1.0 / 3.0, 0.0), Vector2(2.0 / 3.0, 0.0), Vector2(0.5, 1.0)]
	return slots[posmod(-asteroid_id - 1000, slots.size())]

func unit_busy(unit: Variant) -> bool:
	return transport.jobs.has(unit) or (collection != null and collection.jobs.has(unit)) or jobs.has(unit) or survey_jobs.has(unit) or diplomacy.jobs.has(unit) or regions.survey_jobs.has(unit)

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
	if not transport.work_error(ship_id).is_empty():
		return transport.work_error(ship_id)
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("survey"):
		return "Build and select a Scout ship."
	if unit_busy(ship_id):
		return "This ship is already on a mission."
	return regions.survey_error(region_id)

func region_survey_duration(ship_id: int, region_id: String) -> int:
	var capability: Dictionary = model.ship_catalog[model.ships[ship_id]].survey
	return maxi(1, int(ceil(float(regions.catalog[region_id].survey_seconds) / float(capability.get("travel_speed", 1.0)))))

func survey_region(ship_id: int, region_id: String) -> String:
	var error: String = region_survey_error(ship_id, region_id)
	if not error.is_empty():
		return error
	var duration: int = region_survey_duration(ship_id, region_id)
	regions.begin_survey(ship_id, region_id, duration)
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
		elif content.type == "anomaly":
			diplomacy.inventory[content.good] = int(diplomacy.inventory.get(content.good, 0)) + int(content.amount)
	regions.announce_discovery(region_id)

func asteroid_region(asteroid_id: int) -> String:
	return str(asteroids.get(asteroid_id, {}).get("region_id", Regions.HOME))
