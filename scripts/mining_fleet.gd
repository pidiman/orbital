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

func _init(station: StationModel) -> void:
	model = station
	sectors = JSON.parse_string(FileAccess.get_file_as_string("res://data/sectors.json"))

func register_asteroid(asteroid_id: int, amount: int) -> void:
	if not asteroids.has(asteroid_id) and amount > 0:
		asteroids[asteroid_id] = {"minerals": amount, "claimed": false}
		changed.emit()

func remove_asteroid(asteroid_id: int) -> bool:
	if not asteroids.has(asteroid_id) or asteroids[asteroid_id].claimed:
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

func survey(ship_id: int) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("survey"):
		return "Select a Scout ship."
	if survey_jobs.has(ship_id):
		return "This Scout is already surveying."
	var reserved: Array = []
	for job: Dictionary in survey_jobs.values():
		reserved.append(job.sector)
	for index in range(sectors.size()):
		if sectors[index].revealed or reserved.has(index):
			continue
		var duration: int = int(model.ship_catalog[model.ships[ship_id]].survey.seconds)
		survey_jobs[ship_id] = {"sector": index, "remaining": duration, "duration": duration}
		changed.emit()
		return ""
	return "All adjacent sectors are revealed or being surveyed."

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
			sectors[job.sector].revealed = true
			survey_jobs.erase(ship_id)
			surveyed.emit(sectors[job.sector])
	changed.emit()
