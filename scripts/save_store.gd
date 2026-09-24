class_name OrbitalSaveStore
extends RefCounted
const Regions = preload("res://scripts/region_model.gd")
const Trade = preload("res://scripts/trade_model.gd")
const Fleet = preload("res://scripts/mining_fleet.gd")
const Supply = preload("res://scripts/region_supply.gd")
const Collection = preload("res://scripts/material_collection.gd")
const Research = preload("res://scripts/research_model.gd")
const Transport = preload("res://scripts/gate_transport.gd")
const Locations = preload("res://scripts/world_locations.gd")
const LocationValidation = preload("res://scripts/location_save_validation.gd")
const Hauling = preload("res://scripts/refinery_hauling.gd")
const Docking = preload("res://scripts/docking_model.gd")
const Cargo = preload("res://scripts/cargo_shuttle.gd")
const Repair = preload("res://scripts/repair_ship.gd")
const VERSION: int = 2
const DEFAULT_PATH: String = "user://orbital-save.json"
const STATION_FIELDS: Array[String] = ["modules", "module_tiers", "ships", "next_ship_id", "materials", "minerals", "capacity", "power_output", "power_use", "level", "ticks", "tick_elapsed", "refinery_progress", "total_refined"]
const FLEET_FIELDS: Array[String] = ["asteroids", "jobs", "total_mined", "next_discovery_id"]
const SUPPLY_FIELDS: Array[String] = ["rules", "debris", "home_asteroids", "next_debris_id", "next_home_id", "elapsed", "pending", "debris_elapsed", "asteroid_elapsed"]

var model: StationModel
var fleet: Fleet
var supply: Supply
var path: String = DEFAULT_PATH
var enabled: bool = true
var autosave_blocked: bool = false
var dirty: bool = false
var autosave_elapsed: float = 0.0
var autosave_debounce: float = 0.0
var last_error: String = ""
var preserved: Dictionary = {}
var decode_error: String = ""
var migration_notice: String = ""
signal restored
signal saved
signal failed(message: String)

func _init(station: StationModel, mining: Fleet, region_supply: Supply) -> void:
	model = station
	fleet = mining
	supply = region_supply
	fleet.hauling.changed.connect(request_autosave)
	fleet.docking.changed.connect(request_autosave)
	fleet.cargo.changed.connect(request_autosave)
	fleet.repairs.changed.connect(request_autosave)
	fleet.outposts.changed.connect(request_autosave)
	fleet.research.changed.connect(request_autosave)
	fleet.transport.changed.connect(request_autosave)
	fleet.auto_mining_changed.connect(request_autosave)
	supply.collection.changed.connect(request_autosave)
	model.module_built.connect(request_autosave.unbind(2))
	model.module_removed.connect(request_autosave.unbind(1))
	model.module_upgraded.connect(request_autosave.unbind(1))
	model.module_damaged.connect(request_autosave.unbind(1))
	model.module_hp_changed.connect(request_autosave.unbind(1))
	model.ship_built.connect(request_autosave.unbind(1))
	model.ship_upgraded.connect(request_autosave.unbind(1))
	model.ship_removed.connect(request_autosave.unbind(1))
	fleet.dispatched.connect(request_autosave.unbind(2))
	fleet.completed.connect(request_autosave.unbind(3))
	fleet.regions.survey_started.connect(request_autosave)
	fleet.regions.location_changed.connect(request_autosave)
	fleet.regions.discovered.connect(request_autosave.unbind(1))
	fleet.diplomacy.mission_started.connect(request_autosave)
	fleet.diplomacy.mission_completed.connect(request_autosave.unbind(2))

func request_autosave() -> void:
	dirty = true
	# Defer disk I/O until the placement/action frame has rendered. Multiple
	# model signals from one action share this short debounce window.
	autosave_debounce = maxf(autosave_debounce, 0.25)

func advance(delta: float) -> void:
	if not enabled or autosave_blocked:
		return
	autosave_elapsed += delta
	autosave_debounce = maxf(0.0, autosave_debounce - delta)
	if (dirty and autosave_debounce <= 0.0) or autosave_elapsed >= 10.0:
		save_game()

func snapshot() -> Dictionary:
	fleet.docking.reconcile()
	var document: Dictionary = preserved.duplicate(true)
	document["format"] = "orbital.save"
	document["version"] = maxi(VERSION, int(document.get("version", VERSION)))
	document["min_reader_version"] = int(document.get("min_reader_version", VERSION))
	if not document.has("extensions"):
		document["extensions"] = {}
	# Connectivity is derived from the structure graph. The marker lets the
	# loader distinguish canonical economy fields from pre-connectivity saves.
	document.extensions["connectivity"] = {"schema_version": 2}
	if not document.extensions.has("outposts"):
		document.extensions["outposts"] = {}
	document.extensions.outposts["schema_version"] = 1
	_merge_fields(document.extensions, "refinery_hauling", fleet.hauling, Hauling.FIELDS)
	document.extensions.refinery_hauling["schema_version"] = 1
	_merge_fields(document.extensions, "docking", fleet.docking, Docking.FIELDS)
	document.extensions.docking["schema_version"] = 1
	_merge_fields(document.extensions, "cargo_shuttle", fleet.cargo, Cargo.FIELDS)
	document.extensions.cargo_shuttle["schema_version"] = 1
	_merge_fields(document.extensions, "repair_ship", fleet.repairs, Repair.FIELDS)
	document.extensions.repair_ship["schema_version"] = 1
	_merge_fields(document.extensions, "research", fleet.research, Research.FIELDS)
	document.extensions.research["schema_version"] = 1
	_merge_fields(document.extensions, "gate_transport", fleet.transport, Transport.FIELDS)
	document.extensions.gate_transport["schema_version"] = 1
	_merge_fields(document.extensions, "resource_mining", fleet, Fleet.RESOURCE_FIELDS)
	document.extensions.resource_mining["schema_version"] = 1
	# Automatic Miner switches are additive. Missing extension/state means off,
	# which is the migration default for pre-automatic-mining saves.
	document.extensions["miner_auto"] = {"schema_version": 1, "states": _encode(fleet.auto_mining)}
	_merge_fields(document.extensions, "floating_resources", supply, Supply.FLOATING_FIELDS)
	document.extensions.floating_resources["schema_version"] = 1
	_merge_fields(document.extensions, "material_collection", supply.collection, Collection.FIELDS)
	document.extensions.material_collection["schema_version"] = 1
	_merge_fields(document.extensions, "regions", fleet.regions, Regions.FIELDS)
	document.extensions.regions["schema_version"] = 1
	_merge_fields(document.extensions, "alien_trade", fleet.diplomacy, Trade.FIELDS)
	document.extensions.alien_trade["schema_version"] = 1
	_merge_fields(document.extensions, "world_locations", model.locations, Locations.FIELDS)
	document.extensions.world_locations["schema_version"] = 1
	document.extensions.world_locations["mining_assignments"] = _encode(fleet.mining_assignments)
	if not document.has("state"):
		document["state"] = {}
	_merge_fields(document.state, "station", model, STATION_FIELDS)
	_merge_fields(document.state, "fleet", fleet, FLEET_FIELDS)
	document.state.fleet.erase("sectors")
	document.state.fleet.erase("survey_jobs")
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
			# Godot's JSON-backed dictionaries often expose field names as
			# StringName. Treat them exactly like String so nested records (for
			# example asteroid fields) stay ordinary JSON objects.
			if not (key is String or key is StringName):
				ordinary = false
		if ordinary:
			var object: Dictionary = {}
			for key: Variant in value:
				object[str(key)] = _encode(value[key])
			return object
		var entries: Array = []
		for key: Variant in value:
			var encoded_key: Dictionary
			if key is Vector2 or key is Vector2i:
				# New saves use a stable string representation. The decoder still
				# accepts the old $vector2 payload for backward compatibility.
				encoded_key = {"type": "position", "value": "%s,%s" % [str(key.x), str(key.y)]}
			elif key is int:
				encoded_key = {"type": "id", "value": str(key)}
			elif key is String or key is StringName:
				encoded_key = {"type": "string", "value": str(key)}
			else:
				# Do not label an opaque key as an integer. It can then be
				# migrated as a string instead of triggering Unknown map key type.
				encoded_key = {"type": "string", "value": str(key)}
			entries.append({"key": encoded_key, "value": _encode(value[key])})
		return {"$entries": entries}
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_encode(item))
		return items
	return value

func _decode(value: Variant, depth: int = 0, path: String = "root") -> Variant:
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
			var x: Variant = _decode(pair[0], depth + 1, path + ".$vector2.x")
			var y: Variant = _decode(pair[1], depth + 1, path + ".$vector2.y")
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
					push_warning("Save decode: skipped malformed map entry at %s" % path)
					continue
				var key: Variant
				var key_type: String = str(entry.key.get("type", ""))
				var raw_key: Variant = entry.key.get("value")
				if key_type == "position":
					key = _decode_position_key(raw_key, depth + 1, path)
					if not key is Vector2:
						continue
				elif key_type == "id":
					if raw_key is String and raw_key.is_valid_int():
						key = int(raw_key)
					else:
						# Older encoders mislabeled StringName fields as id. Preserve
						# those field names as strings while recording the migration.
						if raw_key is String or raw_key is StringName:
							key = str(raw_key)
							push_warning("Save decode: legacy string key mislabeled as id at %s: %s" % [path, str(raw_key)])
						else:
							push_warning("Save decode: skipped unknown map key at %s type=%s value=%s" % [path, key_type, str(raw_key)])
							continue
				elif key_type == "string":
					if raw_key is String or raw_key is StringName:
						key = str(raw_key)
					else:
						push_warning("Save decode: skipped invalid string key at %s type=%s value=%s" % [path, key_type, str(raw_key)])
						continue
				else:
					push_warning("Save decode: skipped unknown map key at %s type=%s value=%s" % [path, key_type, str(raw_key)])
					continue
				if mapping.has(key):
					push_warning("Save decode: skipped duplicate map key at %s: %s" % [path, str(key)])
					continue
				mapping[key] = _decode(entry.value, depth + 1, "%s[%s]" % [path, str(key)])
			return mapping
		var object: Dictionary = {}
		for key: String in value:
			object[_coerce_json_key(key)] = _decode(value[key], depth + 1, path + "." + key)
		return object
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_decode(item, depth + 1, "%s[%d]" % [path, items.size()]))
		return items
	if value is float and _integer(value):
		return int(value)
	return value

func _decode_position_key(raw_key: Variant, depth: int, path: String) -> Variant:
	if raw_key is String:
		var parts: PackedStringArray = raw_key.split(",")
		if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
			return Vector2(float(parts[0]), float(parts[1]))
	var decoded: Variant = _decode(raw_key, depth, path + ".position")
	if decoded is Vector2:
		return decoded
	push_warning("Save decode: skipped invalid position key at %s: %s" % [path, str(raw_key)])
	return null

func _coerce_json_key(key: String) -> Variant:
	# JSON object keys are always strings. Recover the two key forms used by
	# legacy saves; named region/technology keys remain strings.
	if key.is_valid_int():
		return int(key)
	var parts: PackedStringArray = key.split(",")
	if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
		return Vector2(float(parts[0]), float(parts[1]))
	return key

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
	var connectivity_extension: Variant = migrated.extensions.get("connectivity", {})
	if not connectivity_extension is Dictionary:
		return "Invalid connectivity extension."
	var connectivity_schema: int = int(connectivity_extension.get("schema_version", 0))
	var strict_connectivity_economy: bool = connectivity_schema == 2
	if connectivity_extension.has("schema_version") and connectivity_schema > 2:
		return "This connectivity extension requires a newer reader."
	# A save is current only when it carries the latest structural markers. Any
	# older v2 save enters one tolerant migration pass; its cached derived
	# economy is never treated as authoritative.
	var strict_current_save: bool = strict_connectivity_economy and migrated.extensions.has("world_locations") and migrated.extensions.has("docking") and migrated.extensions.has("outposts")
	var legacy_migration_mode: bool = not strict_current_save
	var legacy_outposts: bool = not migrated.extensions.has("outposts")
	if not legacy_outposts:
		if not migrated.extensions.outposts is Dictionary or migrated.extensions.outposts.get("schema_version") != 1 or not migrated.extensions.has("world_locations"):
			return "Invalid outpost extension or missing location graph."
	var state: Dictionary = migrated.state
	for section: String in ["station", "fleet", "supply"]:
		if not state.get(section) is Dictionary:
			return "Missing save section: " + section
	decode_error = ""
	var station_data: Dictionary = _decode_fields(state.station, STATION_FIELDS, "state.station")
	var fleet_data: Dictionary = _decode_fields(state.fleet, FLEET_FIELDS, "state.fleet")
	var retired_exploration: bool = state.fleet.has("sectors") or state.fleet.has("survey_jobs")
	var old_exploration: Variant = _decode(state.fleet.get("sectors", []), 0, "state.fleet.sectors")
	if not old_exploration is Array: return "Invalid retired exploration data."
	var supply_data: Dictionary = _decode_fields(state.supply, SUPPLY_FIELDS, "state.supply")
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
	# Applying the serialized module graph invalidates the candidate's initial
	# one-module connectivity cache before validating derived economy fields.
	candidate.connectivity_dirty = true
	candidate.recalculate()
	if candidate.power_output != int(station_data.power_output) or candidate.power_use != int(station_data.power_use) or candidate.capacity != int(station_data.capacity) or candidate.level != int(station_data.level):
		if strict_connectivity_economy:
			return "Saved economy disagrees with installed module/ship definitions."
		# Pre-connectivity v2 saves cached economy from a model where every
		# module was active. Connectivity is now derived on load, so adopt the
		# canonical values before continuing instead of rejecting valid progress.
		station_data.capacity = candidate.capacity
		station_data.power_output = candidate.power_output
		station_data.power_use = candidate.power_use
		station_data.level = candidate.level
	var trade_data: Dictionary = {}
	var extension: Variant = migrated.get("extensions", {}).get("alien_trade", {})
	if not extension is Dictionary:
		return "Invalid alien trade extension."
	if migrated.get("extensions", {}).has("alien_trade"):
		if extension.get("schema_version") != 1:
			return "This alien trade extension requires a newer reader."
		trade_data = _decode_fields(extension, Trade.FIELDS, "extensions.alien_trade")
		if not decode_error.is_empty():
			return decode_error
		error = _field_types(trade_data, candidate_fleet.diplomacy, Trade.FIELDS)
		if not error.is_empty():
			return error
		_apply_fields(candidate_fleet.diplomacy, trade_data, Trade.FIELDS)
	# Accept valid older logs, then bound them before committing the candidate.
	# Validate first so trimming cannot hide corrupt records in the old prefix.
	var region_data: Dictionary = {}
	if migrated.get("extensions", {}).has("regions"):
		var region_extension: Variant = migrated.extensions.regions
		if not region_extension is Dictionary or region_extension.get("schema_version") != 1:
			return "Unsupported or invalid region extension."
		region_data = _decode_fields(region_extension, Regions.FIELDS, "extensions.regions")
		if not decode_error.is_empty():
			return decode_error
		error = _field_types(region_data, candidate_fleet.regions, Regions.FIELDS)
		if not error.is_empty():
			return error
	else:
		for field: String in Regions.FIELDS:
			region_data[field] = candidate_fleet.regions.get(field)
	error = candidate_fleet.regions.validate(region_data, station_data, fleet_data, candidate_fleet.diplomacy.jobs, candidate.ship_catalog)
	if not error.is_empty(): return error
	error = preload("res://scripts/legacy_exploration_migration.gd").validate_input(old_exploration, trade_data)
	if not error.is_empty(): return error
	preload("res://scripts/legacy_exploration_migration.gd").migrate(old_exploration, fleet_data, region_data, trade_data)
	candidate_fleet.regions.records = region_data.records
	for region_id: String in region_data.records:
		if region_data.records[region_id].discovered: candidate_fleet.regions.ensure_alien_anomalies(region_id)
	if not trade_data.is_empty():
		error = candidate_fleet.diplomacy.validate(trade_data, station_data, fleet_data, region_data)
		if not error.is_empty(): return error
		_apply_fields(candidate_fleet.diplomacy, trade_data, Trade.FIELDS)
	candidate_fleet.diplomacy.trim_history()
	candidate_fleet.diplomacy.add_catalog_defaults()
	for region_id: String in region_data.records:
		candidate_fleet.diplomacy.discover_region(region_id, region_data.records[region_id])
	error = candidate_fleet.regions.validate(region_data, station_data, fleet_data, candidate_fleet.diplomacy.jobs, candidate.ship_catalog)
	if not error.is_empty():
		return error
	var floating_data: Dictionary = {}
	if migrated.extensions.has("floating_resources"):
		var decoded: Dictionary = _extension_fields(migrated.extensions, "floating_resources", candidate_supply, Supply.FLOATING_FIELDS)
		if not decode_error.is_empty(): return decode_error
		floating_data = decoded.floating
		error = candidate_supply.validate_floating(floating_data, region_data.records, int(supply_data.next_debris_id))
		if not error.is_empty(): return error
		for pool: Dictionary in floating_data.values():
			for id: int in pool.pieces:
				if supply_data.debris.has(id): return "Duplicate legacy/floating resource ID."
	var resource_data: Dictionary = {"resource_targets": {}}
	if migrated.extensions.has("resource_mining"):
		resource_data = _extension_fields(migrated.extensions, "resource_mining", candidate_fleet, Fleet.RESOURCE_FIELDS)
		if not decode_error.is_empty(): return decode_error
	error = candidate_supply.validate_mining_nodes(resource_data.resource_targets, floating_data, fleet_data)
	if not error.is_empty(): return error
	candidate_fleet.resource_targets = resource_data.resource_targets
	var auto_mining_data: Dictionary = {}
	var cancelled_legacy_mining: int = 0
	if migrated.extensions.has("miner_auto"):
		var auto_extension: Variant = migrated.extensions.miner_auto
		if not auto_extension is Dictionary or auto_extension.get("schema_version") != 1:
			return "Invalid automatic mining extension."
		var saved_states: Variant = auto_extension.get("states", {})
		if not saved_states is Dictionary:
			return "Invalid automatic mining state."
		auto_mining_data = _decode(saved_states, 0, "extensions.miner_auto.states")
		if decode_error.is_empty() and not auto_mining_data is Dictionary:
			return "Invalid automatic mining state."
		if not decode_error.is_empty(): return decode_error
	for raw_ship_id: Variant in auto_mining_data:
		if not raw_ship_id is int or not station_data.ships.has(raw_ship_id) or not candidate.ship_catalog[station_data.ships[raw_ship_id]].has("mining") or not auto_mining_data[raw_ship_id] is bool:
			return "Invalid automatic mining ship state."
	candidate_fleet.auto_mining = auto_mining_data
	for unit: Variant in fleet_data.jobs:
		var capability: Dictionary = candidate.ship_catalog[station_data.ships[unit]].mining if unit is int else candidate.definition_at(unit).mining
		if str(capability.get("resource", "minerals")) != candidate_fleet.target_resource(int(fleet_data.jobs[unit].target)):
			return "Mining capability does not match target resource."
	candidate_supply.collection.sync_depots()
	var collection_data: Dictionary = {"jobs": {}, "depots": candidate_supply.collection.depots.duplicate(true)}
	if migrated.extensions.has("material_collection"):
		var collection_extension: Variant = migrated.extensions.material_collection
		if not collection_extension is Dictionary or collection_extension.get("schema_version") != 1:
			return "Unsupported material collection extension."
		collection_data = _decode_fields(collection_extension, Collection.FIELDS, "extensions.material_collection")
		if not decode_error.is_empty():
			return decode_error
		error = _field_types(collection_data, candidate_supply.collection, Collection.FIELDS)
		if not error.is_empty():
			return error
	error = _validate_collection(collection_data, station_data, fleet_data, region_data, candidate_fleet.diplomacy.jobs, candidate)
	if not error.is_empty():
		return error
	candidate_fleet.research.sync_labs()
	candidate_fleet.transport.sync_gates()
	var research_data: Dictionary = _extension_fields(migrated.extensions, "research", candidate_fleet.research, Research.FIELDS)
	var transport_data: Dictionary = _extension_fields(migrated.extensions, "gate_transport", candidate_fleet.transport, Transport.FIELDS)
	if not decode_error.is_empty():
		return decode_error
	error = _validate_research_transport(research_data, transport_data, station_data, fleet_data, region_data, candidate_fleet.diplomacy.jobs, collection_data.jobs, candidate_fleet, not legacy_outposts)
	if not error.is_empty():
		return error
	# Build a complete isolated candidate, migrating pre-location v2 saves first.
	_apply_fields(candidate_fleet.regions, region_data, Regions.FIELDS)
	_apply_fields(candidate_fleet, fleet_data, FLEET_FIELDS)
	_apply_fields(candidate_fleet.research, research_data, Research.FIELDS)
	_apply_fields(candidate_fleet.transport, transport_data, Transport.FIELDS)
	_apply_fields(candidate_supply.collection, collection_data, Collection.FIELDS)
	var migrated_dock_ids: Dictionary = {}
	var migrated_dock_refund: int = 0
	for ship_id: int in candidate_fleet.transport.jobs:
		candidate.locations.begin_transit(ship_id, candidate_fleet.transport.jobs[ship_id].destination)
	if migrated.extensions.has("world_locations"):
		var location_data: Dictionary = _extension_fields(migrated.extensions, "world_locations", candidate.locations, Locations.FIELDS)
		if not decode_error.is_empty():
			return decode_error
		# Ship tiers were added after the original v2 location extension. Legacy
		# records default to T1; current records are checked against definitions.
		for ship_id: Variant in location_data.ships:
			if not location_data.ships[ship_id] is Dictionary:
				return "Invalid ship identity or owner station."
			var ship_record: Dictionary = location_data.ships[ship_id]
			if not ship_record.has("tier"):
				ship_record["tier"] = 1
			elif not _integer(ship_record.tier, 1):
				return "Invalid ship tier."
			var ship_kind: String = str(ship_record.get("kind", ""))
			var max_ship_tier: int = candidate.ship_catalog.get(ship_kind, {}).get("upgrades", []).size() + 1
			if int(ship_record.tier) > max_ship_tier:
				return "Save requires an unavailable ship tier."
		error = LocationValidation.validate_graph(location_data, candidate, region_data, transport_data)
		if not error.is_empty():
			return error
		if legacy_outposts and location_data.stations.size() != 1:
			return "Outpost state requires its extension."
		for station: Dictionary in location_data.stations.values():
			if station.has("inventory") and station.inventory is Dictionary and not station.inventory.has("xenocrystal"):
				station.inventory["xenocrystal"] = 0
		for station: Dictionary in location_data.stations.values():
			if station.has("inventory") and station.inventory is Dictionary and not station.inventory.has("materials"):
				station.inventory["materials"] = 0
				# Old outposts had only a marker and mining inventory; no built grid to move.
				if location_data.structures.has(station.get("structure_id", "")):
					location_data.structures[station.structure_id].position = Vector2.ZERO
		# Normalize retired per-type docks before any docking reservation is
		# validated. Their stable structure IDs remain valid for old assignments.
		for structure_id: String in location_data.structures:
			var structure: Dictionary = location_data.structures[structure_id]
			var definition: Dictionary = candidate.catalog.get(structure.kind, {})
			if not definition.has("docking") or not definition.has("migration_replacement"):
				continue
			var old_tier: int = maxi(1, int(structure.state.get("tier", 1)))
			var tier_map: Dictionary = definition.get("migration_tiers", {})
			var mapped_tier: int = int(tier_map.get(str(old_tier), 1))
			var replacement: String = str(definition.migration_replacement)
			structure.kind = replacement
			structure.state["tier"] = mapped_tier
			migrated_dock_ids[structure_id] = true
			migrated_dock_refund += maxi(0, int(definition.cost) - int(candidate.catalog[replacement].cost))
		error = candidate_fleet.outposts.validate(location_data, region_data, int(station_data.next_ship_id))
		if not error.is_empty():
			return error
		_apply_fields(candidate.locations, location_data, Locations.FIELDS)
		for structure_id: String in migrated_dock_ids:
			var migrated_structure: Dictionary = candidate.locations.structures[structure_id]
			station_data.modules[migrated_structure.position] = migrated_structure.kind
			station_data.module_tiers[migrated_structure.position] = int(migrated_structure.state.get("tier", 1))
		error = LocationValidation.validate_projections(candidate, station_data, research_data, transport_data, collection_data)
		if not error.is_empty():
			return error
		var assignments: Variant = _decode(migrated.extensions.world_locations.get("mining_assignments"), 0, "extensions.world_locations.mining_assignments")
		if not decode_error.is_empty() or not assignments is Dictionary:
			return "Invalid canonical mining assignments."
		error = LocationValidation.validate_assignments(assignments, candidate_fleet, fleet_data.jobs, legacy_outposts)
		if not error.is_empty():
			return error
		candidate_fleet.mining_assignments = assignments
		if not migrated.extensions.has("miner_auto"):
			# Manual mining orders predate the automatic toggle. Release their
			# claims during migration so legacy Miners load genuinely stopped.
			for unit: Variant in candidate_fleet.jobs.keys():
				if not unit is int or not station_data.ships.has(unit) or not candidate.ship_catalog[station_data.ships[unit]].has("mining"):
					continue
				var legacy_target: int = int(candidate_fleet.jobs[unit].get("target", -1))
				if candidate_fleet.asteroids.has(legacy_target): candidate_fleet.asteroids[legacy_target].claimed = false
				candidate_fleet.erase_mining_assignment(unit)
				cancelled_legacy_mining += 1
			fleet_data.jobs = candidate_fleet.jobs
	else:
		candidate_supply.collection.migrate_job_locations()
		candidate_fleet.transport.migrate_job_locations()
		if not migrated.extensions.has("miner_auto"):
			for unit: Variant in candidate_fleet.jobs.keys():
				if not unit is int or not station_data.ships.has(unit) or not candidate.ship_catalog[station_data.ships[unit]].has("mining"):
					continue
				var legacy_target: int = int(candidate_fleet.jobs[unit].get("target", -1))
				if candidate_fleet.asteroids.has(legacy_target): candidate_fleet.asteroids[legacy_target].claimed = false
				candidate_fleet.erase_mining_assignment(unit)
				cancelled_legacy_mining += 1
			fleet_data.jobs = candidate_fleet.jobs
	var repair_data: Dictionary = _extension_fields(migrated.extensions, "repair_ship", candidate_fleet.repairs, Repair.FIELDS)
	if not decode_error.is_empty(): return decode_error
	error = candidate_fleet.repairs.validate(repair_data)
	if not error.is_empty(): return error
	_apply_fields(candidate_fleet.repairs, repair_data, Repair.FIELDS)
	for ship_id: int in trade_data.jobs:
		var job: Dictionary = trade_data.jobs[ship_id]
		if job.has("destination") and job.destination != candidate.locations.local_destination(ship_id): return "Invalid trade storage destination."
	candidate.recalculate()
	if not legacy_migration_mode and candidate.power_use != int(station_data.power_use):
		return "Saved power disagrees with station ship ownership."
	error = LocationValidation.validate_gate_bindings(transport_data, candidate)
	if not error.is_empty():
		return error
	error = LocationValidation.validate_collection(collection_data, candidate)
	if not error.is_empty():
		return error
	var cancelled_remote: int = 0
	if legacy_outposts:
		# Retire the old cross-region shortcut without spending or destroying ore.
		for unit: Variant in candidate_fleet.jobs.keys():
			var assignment: Dictionary = candidate_fleet.mining_assignment(unit)
			if assignment.origin_region != assignment.target.region:
				candidate_fleet.asteroids[assignment.job.target].claimed = false
				candidate_fleet.erase_mining_assignment(unit)
				cancelled_remote += 1
		fleet_data.jobs = candidate_fleet.jobs
	var hauling_data: Dictionary = _extension_fields(migrated.extensions, "refinery_hauling", candidate_fleet.hauling, Hauling.FIELDS)
	if not decode_error.is_empty(): return decode_error
	error = candidate_fleet.hauling.validate(hauling_data)
	if not error.is_empty(): return error
	_apply_fields(candidate_fleet.hauling, hauling_data, Hauling.FIELDS)
	var cargo_data: Dictionary = _extension_fields(migrated.extensions, "cargo_shuttle", candidate_fleet.cargo, Cargo.FIELDS)
	if not decode_error.is_empty(): return decode_error
	error = candidate_fleet.cargo.validate(cargo_data)
	if not error.is_empty(): return error
	_apply_fields(candidate_fleet.cargo, cargo_data, Cargo.FIELDS)
	if migrated.extensions.has("docking") and not retired_exploration and migrated.extensions.has("world_locations"):
		var docking_data: Dictionary = _extension_fields(migrated.extensions, "docking", candidate_fleet.docking, Docking.FIELDS)
		if not decode_error.is_empty(): return decode_error
		candidate_fleet.docking.ships = docking_data.ships.duplicate(true)
		candidate_fleet.docking.usage = docking_data.usage.duplicate(true)
		error = candidate_fleet.docking.validate(docking_data)
		if not error.is_empty():
			# Saves written before the universal Space Dock migration may contain
			# stale reservations. Reconcile them after migration; invalid slots
			# become homeless instead of blocking the whole save.
			candidate_fleet.docking.reconcile()
	else:
		candidate_fleet.docking.reconcile()
	# Migrate any remaining retired structures. Dock structures were normalized
	# above so reservation validation could use universal Space Dock capacity.
	# Same identity/position preserves connectivity, references and station layout.
	var replaced_modules: int = 0
	var replaced_docks: int = migrated_dock_ids.size()
	var replacement_refund: int = migrated_dock_refund
	for structure: Dictionary in candidate.locations.structures.values():
		var definition: Dictionary = candidate.catalog.get(structure.kind, {})
		if not definition.has("migration_replacement"): continue
		var replacement: String = definition.migration_replacement
		if not definition.has("docking"):
			candidate_fleet.cancel_unit(structure.position)
			replaced_modules += 1
		replacement_refund += maxi(0, int(definition.cost) - int(candidate.catalog[replacement].cost))
		structure.kind = replacement
	if replaced_modules + replaced_docks > 0:
		candidate.materials += replacement_refund
		candidate.recalculate()
		for field: String in STATION_FIELDS: station_data[field] = candidate.get(field)
		fleet_data.jobs = candidate_fleet.jobs
		candidate_fleet.docking.reconcile()
	if legacy_migration_mode:
		# All migrations are complete. Recompute every derived station value from
		# the canonical migrated graph and discard stale legacy projections.
		candidate.connectivity_dirty = true
		candidate.recalculate()
		station_data.capacity = candidate.capacity
		station_data.power_output = candidate.power_output
		station_data.power_use = candidate.power_use
		station_data.level = candidate.level
		var ownership_rows: Array[String] = []
		for ship_id: int in candidate.locations.ships:
			var ship_record: Dictionary = candidate.locations.ships[ship_id]
			var ship_kind: String = str(ship_record.kind)
			var ship_power: int = int(candidate.ship_catalog.get(ship_kind, {}).get("power_use", 0))
			ownership_rows.append("#%d:%s:%s:%d" % [ship_id, ship_kind, str(ship_record.station_id), ship_power])
		print("Legacy migration canonical power: generated=%d used=%d ships=%s" % [candidate.power_output, candidate.power_use, ", ".join(ownership_rows)])
	fleet.docking.suspended = true
	# Commit only after the whole graph has passed validation. Existing model references survive.
	_apply_fields(fleet.research, research_data, Research.FIELDS)
	_apply_fields(fleet.transport, transport_data, Transport.FIELDS)
	_apply_fields(fleet.regions, region_data, Regions.FIELDS)
	_apply_fields(model, station_data, STATION_FIELDS)
	fleet.resource_targets = resource_data.resource_targets
	_apply_fields(fleet, fleet_data, FLEET_FIELDS)
	_apply_fields(supply, supply_data, SUPPLY_FIELDS)
	supply.floating = floating_data
	_apply_fields(supply.collection, collection_data, Collection.FIELDS)
	# Apply canonical locations after legacy projection setters (notably the
	# station ship projection) so they cannot overwrite migrated ownership.
	# Recalculate only after this copy: power_use includes station-owned ships.
	for field: String in Locations.FIELDS:
		model.locations.set(field, candidate.locations.get(field))
	model.scoped_cache.clear()
	model.connectivity_dirty = true
	model.recalculate()
	fleet.mining_assignments = candidate_fleet.mining_assignments
	fleet.auto_mining = candidate_fleet.auto_mining
	fleet.hauling.jobs = candidate_fleet.hauling.jobs
	fleet.cargo.routes = candidate_fleet.cargo.routes
	fleet.repairs.jobs = candidate_fleet.repairs.jobs
	fleet.docking.ships = candidate_fleet.docking.ships
	fleet.docking.usage = candidate_fleet.docking.usage
	fleet.docking.suspended = false
	for field: String in Trade.FIELDS:
		fleet.diplomacy.set(field, candidate_fleet.diplomacy.get(field))
	supply.rng.seed = int(supply_data.rng_seed)
	supply.rng.state = int(supply_data.rng_state)
	migration_notice = "Legacy remote mining orders released; ore preserved. Send Miners through a gate and found a local outpost." if cancelled_remote > 0 else ""
	if cancelled_legacy_mining > 0:
		migration_notice += (" " if not migration_notice.is_empty() else "") + "Released %d legacy Miner order(s); Miners load stopped. Start auto-mining from their ship panels." % cancelled_legacy_mining
	if replaced_modules > 0:
		migration_notice += " Converted %d legacy Mining Ship modules to Space Docks in place; refunded %d Materials. Module mining jobs released; Ore preserved." % [replaced_modules, replacement_refund]
	if replaced_docks > 0:
		migration_notice += " Converted %d typed docks to Space Docks (old T1→T2, T2→T3, T3–T5→T4). Excess parked ships wait for a free slot and remain usable." % replaced_docks
	autosave_blocked = false
	preserved = migrated.duplicate(true)
	dirty = false
	autosave_elapsed = 0.0
	autosave_debounce = 0.0
	restored.emit()
	model.changed.emit()
	fleet.changed.emit()
	return ""

func _decode_fields(data: Dictionary, fields: Array[String], context: String = "") -> Dictionary:
	var known: Dictionary = {}
	for field: String in fields:
		if data.has(field):
			known[field] = _decode(data[field], 0, (context + "." + field) if not context.is_empty() else field)
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
	for asteroid_id: Variant in mining.asteroids:
		var rock: Variant = mining.asteroids[asteroid_id]
		if not asteroid_id is int or not rock is Dictionary or not _integer(rock.get("minerals"), 1) or not rock.get("claimed") is bool:
			return "Invalid asteroid state."
		if rock.has("persistent") and not rock.persistent is bool:
			return "Invalid asteroid persistence flag."
		if rock.has("position") and not _valid_vector(rock.position):
			return "Invalid discovery position."
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

func _validate_collection(data: Dictionary, station: Dictionary, mining: Dictionary, regions: Dictionary, trade_jobs: Dictionary, definitions: StationModel) -> String:
	for point: Variant in data.depots:
		if not point is Vector2 or not station.modules.has(point) or not definitions.catalog[station.modules[point]].has("material_depot"):
			return "Invalid Space Depot assignment."
		if not data.depots[point] is Dictionary or not _integer(data.depots[point].get("delivered"), 0):
			return "Invalid depot delivery count."
	for point: Vector2 in station.modules:
		if definitions.catalog[station.modules[point]].has("material_depot") and not data.depots.has(point):
			return "Missing Space Depot state."
	var targets: Dictionary = {}
	for ship_id: Variant in data.jobs:
		if not ship_id is int or not station.ships.has(ship_id) or not definitions.ship_catalog[station.ships[ship_id]].has("collection"):
			return "Invalid material collection ship."
		if mining.jobs.has(ship_id) or regions.survey_jobs.has(ship_id) or trade_jobs.has(ship_id):
			return "Collection ship is assigned twice."
		var job: Variant = data.jobs[ship_id]
		if not job is Dictionary:
			return "Invalid collection assignment."
		if not regions.records.has(job.get("region")) or not _valid_vector(job.get("position")) or not _valid_vector(job.get("depot")):
			return "Invalid regional collection position."
		var collection_definition: Dictionary = definitions.ship_catalog[station.ships[ship_id]]
		var max_collection: int = int(collection_definition.collection.cargo_capacity)
		for upgrade: Dictionary in collection_definition.get("upgrades", []):
			max_collection = maxi(max_collection, int(upgrade.get("stats", {}).get("collection", {}).get("cargo_capacity", max_collection)))
		if not _integer(job.get("cargo"), 0) or job.cargo > max_collection or not _integer(job.get("target"), -1):
			return "Invalid collection cargo or target."
		if not job.get("waiting") is bool or not job.get("status") is String:
			return "Invalid collection waiting state."
		if job.target != -1:
			if job.cargo > 0 or targets.has(str(job.region) + ":" + str(job.target)):
				return "Duplicate collection reservation."
			targets[str(job.region) + ":" + str(job.target)] = true
	return ""

func _extension_fields(extensions: Dictionary, key: String, target: Object, fields: Array[String]) -> Dictionary:
	if not extensions.has(key):
		var defaults: Dictionary = {}
		for field: String in fields:
			defaults[field] = target.get(field).duplicate(true)
		return defaults
	var extension: Variant = extensions[key]
	if not extension is Dictionary or extension.get("schema_version") != 1:
		decode_error = "Unsupported " + key + " extension."
		return {}
	var decoded: Dictionary = _decode_fields(extension, fields, "extensions." + key)
	if decode_error.is_empty():
		decode_error = _field_types(decoded, target, fields)
	return decoded

func _validate_research_transport(research_data: Dictionary, transport_data: Dictionary, station: Dictionary, mining: Dictionary, region_data: Dictionary, trades: Dictionary, collectors: Dictionary, candidate: Fleet, allow_local_mining: bool = false) -> String:
	for id: Variant in research_data.researched:
		if not id is String or not candidate.research.catalog.has(id) or research_data.researched[id] != true:
			return "Invalid researched technology."
		for prerequisite: String in candidate.research.catalog[id].get("requires", []):
			if not research_data.researched.has(prerequisite):
				return "Missing research prerequisite."
	candidate.research.researched = research_data.researched
	for pair: Array in [[research_data.labs, "research", "completed"], [transport_data.gates, "teleport", "jumps"]]:
		var records: Dictionary = pair[0]
		for point: Variant in records:
			if not point is Vector2 or not station.modules.has(point) or not candidate.model.definition_at(point).has(pair[1]):
				return "Invalid research or gate module state."
			if not records[point] is Dictionary or not _integer(records[point].get(pair[2]), 0):
				return "Invalid research or gate counter."
		for point: Vector2 in station.modules:
			if candidate.model.definition_at(point).has(pair[1]) and not records.has(point):
				return "Missing research or gate module state."
	var occupied: Array[Vector2] = []
	for point: Vector2 in station.modules:
		if not candidate.model.module_unlocked(station.modules[point]):
			return "Installed module requires unresearched technology."
		for cell: Vector2 in candidate.model.footprint_points(point, station.modules[point]):
			if not StationGeometry.contains_center(cell):
				return "Saved module footprint is outside the station grid."
			for other: Vector2 in occupied:
				if StationGeometry.overlaps(cell, other):
					return "Saved module footprints overlap."
			occupied.append(cell)
	for ship_id: Variant in transport_data.locations:
		var destination: Variant = transport_data.locations[ship_id]
		if not ship_id is int or not station.ships.has(ship_id) or not destination is String or not region_data.records.has(destination) or not region_data.records[destination].discovered:
			return "Invalid relocated ship."
	for ship_id: Variant in transport_data.jobs:
		var job: Variant = transport_data.jobs[ship_id]
		if not ship_id is int or not station.ships.has(ship_id) or not _valid_job(job) or not _valid_vector(job.get("gate")):
			return "Invalid gate transit."
		if not job.get("origin") is String or not region_data.records.has(job.origin) or transport_data.locations.get(ship_id, Regions.HOME) != job.origin:
			return "Gate departure must match the ship region."
		if not job.get("destination") is String or not region_data.records.has(job.destination) or not region_data.records[job.destination].discovered:
			return "Invalid gate route."
		if not job.get("cost") is Dictionary:
			return "Invalid gate cost escrow."
		for good: Variant in job.cost:
			if not good is String or not candidate.diplomacy.goods_catalog.has(good) or not _integer(job.cost[good], 0):
				return "Invalid gate cost escrow."
	for ship_id: int in station.ships:
		if transport_data.jobs.has(ship_id):
			if (mining.jobs.has(ship_id) and (transport_data.jobs.has(ship_id) or not allow_local_mining)) or region_data.survey_jobs.has(ship_id) or trades.has(ship_id) or collectors.has(ship_id):
				return "Relocated or in-transit ship has a conflicting work mission."
	return ""
