class_name MiningFleet
extends RefCounted

signal changed
signal dispatched(unit: Variant, asteroid_id: int)
signal completed(unit: Variant, asteroid_id: int, amount: int)
signal surveyed(sector: Dictionary)

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
	model.module_removed.connect(cancel_unit)
	model.ship_removed.connect(cancel_unit)
	sectors = JSON.parse_string(FileAccess.get_file_as_string("res://data/sectors.json"))

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
		if definition.has("mining"):
			units[ship_id] = definition.mining
	return units

func idle_count() -> int:
	return mining_units().size() - jobs.size()

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
		if jobs.has(unit):
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
	return not sector.is_empty() and sector.get("reachable_from", []).has("home")

func travel_duration(ship_id: int, sector_id: String) -> int:
	var sector: Dictionary = sector_by_id(sector_id)
	var capability: Dictionary = model.ship_catalog[model.ships[ship_id]].survey
	return maxi(1, int(ceil(float(sector.get("travel_seconds", capability.seconds)) / float(capability.get("travel_speed", 1.0)))))

func survey_error(ship_id: int, sector_id: String) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("survey"):
		return "Build and select a Scout ship."
	if survey_jobs.has(ship_id):
		return "This Scout is already exploring."
	if not sector_reachable(sector_id):
		return "That sector is not reachable from Home orbit."
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
			asteroids[asteroid_id] = {"minerals": int(content.minerals), "claimed": false, "persistent": true, "sector_id": sector_id, "name": content.get("name", "Deposit")}
			sector.asteroid_ids.append(asteroid_id)
	surveyed.emit(sector)

func revealed_count() -> int:
	var count: int = 0
	for sector: Dictionary in sectors:
		if sector.revealed:
			count += 1
	return count

func tick() -> void:
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
	changed.emit()
