class_name OrbitalSaveStore
extends RefCounted
const Regions = preload("res://scripts/region_model.gd")
const Trade = preload("res://scripts/trade_model.gd")
const Fleet = preload("res://scripts/mining_fleet.gd")
const Supply = preload("res://scripts/sector_supply.gd")
const VERSION: int = 2
const DEFAULT_PATH: String = "user://orbital-save.json"
const STATION_FIELDS: Array[String] = ["modules", "module_tiers", "ships", "next_ship_id", "materials", "minerals", "capacity", "power_output", "power_use", "level", "ticks", "tick_elapsed", "refinery_progress", "total_refined"]
const FLEET_FIELDS: Array[String] = ["asteroids", "jobs", "survey_jobs", "sectors", "total_mined", "next_discovery_id"]
const SUPPLY_FIELDS: Array[String] = ["rules", "debris", "home_asteroids", "next_debris_id", "next_home_id", "elapsed", "pending", "debris_elapsed", "asteroid_elapsed"]

var model: StationModel
var fleet: Fleet
var supply: Supply
var path: String = DEFAULT_PATH
var enabled: bool = true
var autosave_blocked: bool = false
var dirty: bool = false
var autosave_elapsed: float = 0.0
var last_error: String = ""
var preserved: Dictionary = {}
var decode_error: String = ""
signal restored
signal saved
signal failed(message: String)

func _init(station: StationModel, mining: Fleet, sector_supply: Supply) -> void:
	model = station
	fleet = mining
	supply = sector_supply
	model.module_built.connect(request_autosave.unbind(2))
	model.module_removed.connect(request_autosave.unbind(1))
	model.module_upgraded.connect(request_autosave.unbind(1))
	model.ship_built.connect(request_autosave.unbind(1))
	model.ship_removed.connect(request_autosave.unbind(1))
	fleet.surveyed.connect(request_autosave.unbind(1))
	fleet.survey_started.connect(request_autosave.unbind(2))
	fleet.dispatched.connect(request_autosave.unbind(2))
	fleet.completed.connect(request_autosave.unbind(3))
	fleet.regions.survey_started.connect(request_autosave)
	fleet.regions.location_changed.connect(request_autosave)
	fleet.regions.discovered.connect(request_autosave.unbind(1))
	fleet.diplomacy.mission_started.connect(request_autosave)
	fleet.diplomacy.mission_completed.connect(request_autosave.unbind(2))

func request_autosave() -> void:
	dirty = true

func advance(delta: float) -> void:
	if not enabled or autosave_blocked:
		return
	autosave_elapsed += delta
	if dirty or autosave_elapsed >= 10.0:
		save_game()

func snapshot() -> Dictionary:
	var document: Dictionary = preserved.duplicate(true)
	document["format"] = "orbital.save"
	document["version"] = maxi(VERSION, int(document.get("version", VERSION)))
	document["min_reader_version"] = int(document.get("min_reader_version", VERSION))
	if not document.has("extensions"):
		document["extensions"] = {}
	_merge_fields(document.extensions, "regions", fleet.regions, Regions.FIELDS)
	document.extensions.regions["schema_version"] = 1
	_merge_fields(document.extensions, "alien_trade", fleet.diplomacy, Trade.FIELDS)
	document.extensions.alien_trade["schema_version"] = 1
	if not document.has("state"):
		document["state"] = {}
	_merge_fields(document.state, "station", model, STATION_FIELDS)
	_merge_fields(document.state, "fleet", fleet, FLEET_FIELDS)
	_merge_fields(document.state, "supply", supply, SUPPLY_FIELDS)
	# RNG is signed 64-bit; strings avoid JSON's 53-bit numeric precision ceiling.
	document.state.supply["rng_seed"] = str(supply.rng.seed)
	document.state.supply["rng_state"] = str(supply.rng.state)
	return _json_numbers(document)

# JSON has one numeric type. Canonicalize snapshots so equivalent int/float
# values (including opaque future extensions) compare exactly after parsing.
func _json_numbers(value: Variant) -> Variant:
	if value is int or value is float:
		return float(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value:
			result[key] = _json_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_numbers(item))
		return result
	return value

func _merge_fields(state: Dictionary, section: String, source: Object, fields: Array[String]) -> void:
	var values: Dictionary = state.get(section, {}).duplicate(true)
	for field: String in fields:
		values[field] = _encode(source.get(field))
	state[section] = values

func _encode(value: Variant) -> Variant:
	if value is Vector2:
		return {"$vector2": [_encode(value.x), _encode(value.y)]}
	if value is float:
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return {"$float64": bytes.hex_encode()}
	if value is Dictionary:
		var ordinary: bool = true
		for key: Variant in value:
			if not key is String:
				ordinary = false
		if ordinary:
			var object: Dictionary = {}
			for key: String in value:
				object[key] = _encode(value[key])
			return object
		var entries: Array = []
		for key: Variant in value:
			var encoded_key: Dictionary = {"type": "position", "value": _encode(key)} if key is Vector2 else {"type": "id", "value": str(key)}
			entries.append({"key": encoded_key, "value": _encode(value[key])})
		return {"$entries": entries}
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_encode(item))
		return items
	return value

func _decode(value: Variant, depth: int = 0) -> Variant:
	if depth > 40:
		decode_error = "Save nesting exceeds the supported limit."
		return null
	if value is Dictionary:
		if value.has("$float64"):
			var hex: Variant = value["$float64"]
			if not hex is String or hex.length() != 16:
				decode_error = "Invalid exact float encoding."
				return null
			for character: String in hex:
				if not "0123456789abcdef".contains(character.to_lower()):
					decode_error = "Invalid float bytes."
					return null
			var precise: float = hex.hex_decode().decode_double(0)
			if not is_finite(precise):
				decode_error = "Non-finite saved value."
			return precise
		if value.has("$vector2"):
			var pair: Variant = value["$vector2"]
			if not pair is Array or pair.size() != 2:
				decode_error = "Invalid world position in save."
				return null
			var x: Variant = _decode(pair[0], depth + 1)
			var y: Variant = _decode(pair[1], depth + 1)
			if not _number(x) or not _number(y):
				decode_error = "Invalid world position components."
				return null
			return Vector2(float(x), float(y))
		if value.has("$entries"):
			var entries: Variant = value["$entries"]
			if not entries is Array:
				decode_error = "Invalid keyed state in save."
				return null
			var mapping: Dictionary = {}
			for entry: Variant in entries:
				if not entry is Dictionary or not entry.get("key") is Dictionary or not entry.has("value"):
					decode_error = "Invalid map entry in save."
					return null
				var key: Variant
				if entry.key.get("type") == "position":
					key = _decode(entry.key.get("value"), depth + 1)
					if not key is Vector2:
						decode_error = "Invalid module key."
						return null
				elif entry.key.get("type") == "id" and entry.key.get("value") is String and entry.key.value.is_valid_int():
					key = int(entry.key.value)
				else:
					decode_error = "Unknown map key type."
					return null
				if mapping.has(key):
					decode_error = "Duplicate state key."
					return null
				mapping[key] = _decode(entry.value, depth + 1)
			return mapping
		var object: Dictionary = {}
		for key: String in value:
			object[key] = _decode(value[key], depth + 1)
		return object
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_decode(item, depth + 1))
		return items
	if value is float and _integer(value):
		return int(value)
	return value

# Migration entry point: future breaking changes add one explicit step here.
func migrate(document: Dictionary) -> Dictionary:
	var migrated: Dictionary = document.duplicate(true)
	if migrated.get("version") == 1:
		if migrated.get("state") is Dictionary and migrated.state.get("station") is Dictionary:
			if not migrated.state.station.has("tick_elapsed"):
				migrated.state.station["tick_elapsed"] = 0.0
		if not migrated.has("extensions"):
			migrated["extensions"] = {}
		migrated["version"] = 2
		migrated["min_reader_version"] = 2
	return migrated

func restore(document: Variant) -> String:
	if not document is Dictionary or document.get("format") != "orbital.save":
		return "This is not an Orbital save."
	if not _integer(document.get("version"), 1) or not _integer(document.get("min_reader_version", 1), 1):
		return "Invalid save version."
	if int(document.get("min_reader_version", 1)) > VERSION:
		return "This save requires a newer Orbital version."
	var migrated: Dictionary = migrate(document)
	if not migrated.get("state") is Dictionary or not migrated.get("extensions", {}) is Dictionary:
		return "Missing save state or invalid extensions."
	var state: Dictionary = migrated.state
	for section: String in ["station", "fleet", "supply"]:
		if not state.get(section) is Dictionary:
			return "Missing save section: " + section
	decode_error = ""
	var station_data: Dictionary = _decode_fields(state.station, STATION_FIELDS)
	var fleet_data: Dictionary = _decode_fields(state.fleet, FLEET_FIELDS)
	var supply_data: Dictionary = _decode_fields(state.supply, SUPPLY_FIELDS)
	supply_data["rng_seed"] = state.supply.get("rng_seed")
	supply_data["rng_state"] = state.supply.get("rng_state")
	if not decode_error.is_empty():
		return decode_error
	var candidate := StationModel.new()
	var candidate_fleet := Fleet.new(candidate)
	var candidate_supply := Supply.new(candidate, candidate_fleet, 0)
	var error: String = _field_types(station_data, candidate, STATION_FIELDS)
	if error.is_empty():
		error = _field_types(fleet_data, candidate_fleet, FLEET_FIELDS)
	if error.is_empty():
		error = _field_types(supply_data, candidate_supply, SUPPLY_FIELDS)
	if not error.is_empty():
		return error
	error = _validate(station_data, fleet_data, supply_data, candidate)
	if not error.is_empty():
		return error
	_apply_fields(candidate, station_data, STATION_FIELDS)
	candidate.recalculate()
	if candidate.power_output != int(station_data.power_output) or candidate.power_use != int(station_data.power_use) or candidate.capacity != int(station_data.capacity) or candidate.level != int(station_data.level):
		return "Saved economy disagrees with installed module/ship definitions."
	var trade_data: Dictionary = {}
	var extension: Variant = migrated.get("extensions", {}).get("alien_trade", {})
	if not extension is Dictionary:
		return "Invalid alien trade extension."
	if migrated.get("extensions", {}).has("alien_trade"):
		if extension.get("schema_version") != 1:
			return "This alien trade extension requires a newer reader."
		trade_data = _decode_fields(extension, Trade.FIELDS)
		if not decode_error.is_empty():
			return decode_error
		error = _field_types(trade_data, candidate_fleet.diplomacy, Trade.FIELDS)
		if not error.is_empty():
			return error
		error = candidate_fleet.diplomacy.validate(trade_data, station_data, fleet_data)
		if not error.is_empty():
			return error
		_apply_fields(candidate_fleet.diplomacy, trade_data, Trade.FIELDS)
	candidate_fleet.diplomacy.add_catalog_defaults()
	# Old v2 saves have no extension. Add content without resetting discovered ore.
	candidate_fleet.diplomacy.enrich_sectors(fleet_data.sectors)
	for sector: Dictionary in fleet_data.sectors:
		candidate_fleet.diplomacy.discover(sector)
	var region_data: Dictionary = {}
	if migrated.get("extensions", {}).has("regions"):
		var region_extension: Variant = migrated.extensions.regions
		if not region_extension is Dictionary or region_extension.get("schema_version") != 1:
			return "Unsupported or invalid region extension."
		region_data = _decode_fields(region_extension, Regions.FIELDS)
		if not decode_error.is_empty():
			return decode_error
		error = _field_types(region_data, candidate_fleet.regions, Regions.FIELDS)
		if not error.is_empty():
			return error
	else:
		for field: String in Regions.FIELDS:
			region_data[field] = candidate_fleet.regions.get(field)
	error = candidate_fleet.regions.validate(region_data, station_data, fleet_data, candidate_fleet.diplomacy.jobs, candidate.ship_catalog)
	if not error.is_empty():
		return error
	# Commit only after the whole graph has passed validation. Existing model references survive.
	_apply_fields(fleet.regions, region_data, Regions.FIELDS)
	_apply_fields(model, station_data, STATION_FIELDS)
	_apply_fields(fleet, fleet_data, FLEET_FIELDS)
	_apply_fields(supply, supply_data, SUPPLY_FIELDS)
	for field: String in Trade.FIELDS:
		fleet.diplomacy.set(field, candidate_fleet.diplomacy.get(field))
	supply.rng.seed = int(supply_data.rng_seed)
	supply.rng.state = int(supply_data.rng_state)
	autosave_blocked = false
	preserved = migrated.duplicate(true)
	dirty = false
	autosave_elapsed = 0.0
	restored.emit()
	model.changed.emit()
	fleet.changed.emit()
	return ""

func _decode_fields(data: Dictionary, fields: Array[String]) -> Dictionary:
	var known: Dictionary = {}
	for field: String in fields:
		if data.has(field):
			known[field] = _decode(data[field])
	return known

func _field_types(data: Dictionary, target: Object, fields: Array[String]) -> String:
	for field: String in fields:
		if not data.has(field):
			return "Missing state field: " + field
		var expected: Variant = target.get(field)
		if expected is int:
			if not _integer(data[field]):
				return "Invalid integer: " + field
		elif expected is float:
			if not _number(data[field]):
				return "Invalid number: " + field
		elif typeof(data[field]) != typeof(expected):
			return "Invalid state type: " + field
	return ""

func _apply_fields(target: Object, data: Dictionary, fields: Array[String]) -> void:
	for field: String in fields:
		target.set(field, data[field])

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _integer(value: Variant, minimum: int = -9007199254740991) -> bool:
	return _number(value) and float(value) == floor(float(value)) and float(value) >= minimum and absf(float(value)) <= 9007199254740991.0

func _validate(station: Dictionary, mining: Dictionary, stock: Dictionary, definitions: StationModel) -> String:
	for field: String in ["materials", "minerals", "capacity", "power_output", "power_use", "level", "ticks", "next_ship_id", "total_refined"]:
		if not _integer(station[field], 0):
			return "Invalid station quantity: " + field
	if station.tick_elapsed < 0 or station.tick_elapsed >= 1.0:
		return "Invalid resource clock phase."
	if station.modules.get(Vector2.ZERO) != "habitat":
		return "The colony core is missing."
	for point: Variant in station.modules:
		if not point is Vector2 or not point.is_finite() or not station.modules[point] is String or not definitions.catalog.has(station.modules[point]):
			return "Invalid module position or unknown module definition."
	for point: Variant in station.module_tiers:
		if not station.modules.has(point) or not _integer(station.module_tiers[point], 1):
			return "Invalid module tier."
		if int(station.module_tiers[point]) > definitions.catalog[station.modules[point]].get("upgrades", []).size() + 1:
			return "Save requires an unavailable upgrade tier."
	for point: Variant in station.refinery_progress:
		if not station.modules.has(point) or not definitions.catalog[station.modules[point]].has("conversion") or not _integer(station.refinery_progress[point], 0):
			return "Invalid refinery progress."
	for ship_id: Variant in station.ships:
		if not ship_id is int or ship_id <= 0 or ship_id > int(station.next_ship_id) or not station.ships[ship_id] is String or not definitions.ship_catalog.has(station.ships[ship_id]):
			return "Invalid ship or ship ID allocator."
	var sector_ids: Dictionary = {}
	for sector: Variant in mining.sectors:
		if not sector is Dictionary or not sector.get("id") is String or not sector.get("name") is String or not sector.get("revealed") is bool or not sector.get("contents") is Array or not sector.get("reachable_from") is Array:
			return "Invalid sector record."
		if sector_ids.has(sector.id) or not _integer(sector.get("travel_seconds"), 0):
			return "Invalid sector ID or travel duration."
		sector_ids[sector.id] = sector
		for content: Variant in sector.contents:
			if not content is Dictionary or not content.get("type") is String:
				return "Invalid sector contents."
			if content.type == "asteroid" and not _integer(content.get("minerals"), 1):
				return "Invalid discovery ore amount."
			if content.type == "anomaly" and not content.get("name") is String:
				return "Invalid anomaly record."
		if sector.has("asteroid_ids"):
			if not sector.asteroid_ids is Array:
				return "Invalid discovered asteroid list."
			for asteroid_id: Variant in sector.asteroid_ids:
				if not _integer(asteroid_id) or asteroid_id >= -1 or asteroid_id <= mining.next_discovery_id:
					return "Invalid discovery ID allocator."
	for asteroid_id: Variant in mining.asteroids:
		var rock: Variant = mining.asteroids[asteroid_id]
		if not asteroid_id is int or not rock is Dictionary or not _integer(rock.get("minerals"), 1) or not rock.get("claimed") is bool:
			return "Invalid asteroid state."
		if rock.has("persistent") and not rock.persistent is bool:
			return "Invalid asteroid persistence flag."
		if rock.has("position") and not _valid_vector(rock.position):
			return "Invalid discovery position."
		if rock.get("persistent", false) and not rock.has("region_id"):
			if not sector_ids.has(rock.get("sector_id")) or not sector_ids[rock.sector_id].revealed or not sector_ids[rock.sector_id].get("asteroid_ids", []).has(asteroid_id):
				return "Discovery references an unrevealed sector."
	var claimed: Dictionary = {}
	for unit: Variant in mining.jobs:
		var capability: Dictionary = {}
		if unit is int and station.ships.has(unit):
			capability = definitions.ship_catalog[station.ships[unit]]
		elif unit is Vector2 and station.modules.has(unit):
			capability = definitions.catalog[station.modules[unit]]
		if not capability.has("mining"):
			return "Mining mission references a missing unit."
		var job: Variant = mining.jobs[unit]
		if not _valid_job(job) or not _integer(job.get("yield"), 1) or not job.get("repeat") is bool or not _integer(job.get("target")):
			return "Invalid mining job."
		var target: int = int(job.target)
		if not mining.asteroids.has(target) or claimed.has(target):
			return "Invalid or duplicate mining reservation."
		claimed[target] = true
	for asteroid_id: int in mining.asteroids:
		if mining.asteroids[asteroid_id].claimed != claimed.has(asteroid_id):
			return "Asteroid reservation and mission disagree."
	var destinations: Dictionary = {}
	for ship_id: Variant in mining.survey_jobs:
		var job: Variant = mining.survey_jobs[ship_id]
		if mining.jobs.has(ship_id):
			return "Ship assigned to more than one mission."
		if not station.ships.has(ship_id) or not definitions.ship_catalog[station.ships[ship_id]].has("survey") or not _valid_job(job):
			return "Survey references a missing Scout or invalid timer."
		if not job.get("sector_id") is String or not sector_ids.has(job.sector_id) or sector_ids[job.sector_id].revealed or destinations.has(job.sector_id):
			return "Invalid or duplicate survey destination."
		destinations[job.sector_id] = true
	if not _integer(mining.total_mined, 0) or not _integer(mining.next_discovery_id) or mining.next_discovery_id > -1000:
		return "Invalid mining counters."
	if not stock.get("rng_seed") is String or not stock.rng_seed.is_valid_int() or not stock.get("rng_state") is String or not stock.rng_state.is_valid_int():
		return "Missing RNG state."
	for field: String in ["elapsed", "pending", "debris_elapsed", "asteroid_elapsed"]:
		if not _number(stock[field]) or stock[field] < -0.000001:
			return "Invalid supply clock."
	for field: String in ["next_debris_id", "next_home_id"]:
		if not _integer(stock[field], 0):
			return "Invalid supply ID allocator."
	var defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/supply.json"))
	if not _valid_rules(stock.rules, defaults):
		return "Invalid supply definitions."
	if float(stock.rules.step_seconds) <= 0 or float(stock.rules.debris.spawn_seconds) <= 0 or float(stock.rules.asteroids.spawn_seconds) <= 0:
		return "Invalid supply intervals."
	if stock.rules.step_seconds < 0.001 or stock.rules.step_seconds > 1.0 or stock.pending >= stock.rules.step_seconds + 0.000001 or stock.debris_elapsed >= stock.rules.debris.spawn_seconds + 0.000001 or stock.asteroid_elapsed >= stock.rules.asteroids.spawn_seconds + 0.000001:
		return "Invalid supply timing phase."
	for section: String in ["debris", "asteroids"]:
		for field: String in ["initial_count", "max_count"]:
			if not _integer(stock.rules[section][field], 0) or stock.rules[section][field] > 10000:
				return "Invalid supply population limits."
	if stock.rules.debris.amount_min < 1 or stock.rules.debris.amount_max < stock.rules.debris.amount_min or stock.rules.asteroids.minerals < 1:
		return "Invalid supply resource amounts."
	for debris_id: Variant in stock.debris:
		var piece: Variant = stock.debris[debris_id]
		if not debris_id is int or debris_id <= 0 or debris_id > stock.next_debris_id or not piece is Dictionary or not _valid_vector(piece.get("position")) or not _valid_vector(piece.get("velocity")) or not _integer(piece.get("amount"), 1):
			return "Invalid salvage state."
	for asteroid_id: Variant in stock.home_asteroids:
		var rock: Variant = stock.home_asteroids[asteroid_id]
		if not asteroid_id is int or asteroid_id <= 0 or asteroid_id > stock.next_home_id or not rock is Dictionary or not _valid_vector(rock.get("position")) or not _number(rock.get("speed")):
			return "Invalid home asteroid supply."
		# Depleted home records may await the next fixed supply step; they are harmless.
	for asteroid_id: int in mining.asteroids:
		if asteroid_id > 0 and not stock.home_asteroids.has(asteroid_id):
			return "Home asteroid has no supply record."
	return ""

func _valid_job(job: Variant) -> bool:
	return job is Dictionary and _integer(job.get("remaining"), 1) and _integer(job.get("duration"), 1) and job.remaining <= job.duration

func _valid_vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite()

func _valid_rules(values: Dictionary, defaults: Dictionary) -> bool:
	for key: String in defaults:
		if defaults[key] is Dictionary:
			if not values.get(key) is Dictionary or not _valid_rules(values[key], defaults[key]):
				return false
		elif not _number(values.get(key)):
			return false
	return true

func save_game() -> String:
	if not enabled:
		return "Persistence is disabled for this verification instance."
	dirty = false
	autosave_elapsed = 0.0
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Could not create save: " + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot(), "\t", false, true))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _fail("Could not write save: " + error_string(write_error))
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		return _fail("Could not replace save: " + error_string(rename_error))
	last_error = ""
	autosave_blocked = false
	saved.emit()
	return ""

func load_game() -> String:
	if not enabled:
		return "Persistence is disabled for this verification instance."
	if not FileAccess.file_exists(path):
		return _load_fail("No saved colony exists yet.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _load_fail("Could not open save.")
	if file.get_length() > 8 * 1024 * 1024:
		return _load_fail("Save exceeds the supported size limit.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _load_fail("Save JSON is damaged: " + parser.get_error_message())
	var error: String = restore(parser.data)
	if not error.is_empty():
		return _load_fail(error)
	last_error = ""
	return ""

func _fail(message: String) -> String:
	last_error = message
	failed.emit(message)
	return message

func _load_fail(message: String) -> String:
	# A bad or newer checkpoint is never silently overwritten by autosave.
	autosave_blocked = FileAccess.file_exists(path)
	return _fail(message + " Autosave paused; Save replaces the checkpoint." if autosave_blocked else message)
