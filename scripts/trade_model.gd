class_name AlienTradeModel
extends RefCounted

signal changed
signal mission_started
signal mission_completed(contact_id: String, offer_id: String)
const FIELDS: Array[String] = ["factions", "contacts", "inventory", "jobs", "history", "processed_anomalies", "next_trade_id"]
var model: StationModel
var faction_catalog: Dictionary
var alien_catalog: Dictionary
var goods_catalog: Dictionary
var offers: Dictionary
var factions: Dictionary = {}
var contacts: Dictionary = {}
var inventory: Dictionary = {}
var jobs: Dictionary = {}
var history: Array = []
var processed_anomalies: Array = []
var next_trade_id: int = 0

func _init(station: StationModel) -> void:
	model = station
	faction_catalog = _read("factions")
	alien_catalog = _read("aliens")
	goods_catalog = _read("trade_goods")
	offers = _read("trade_offers")
	for id: String in faction_catalog:
		factions[id] = {"name": faction_catalog[id].name, "standing": int(faction_catalog[id].initial_standing), "met": false}
	for id: String in goods_catalog:
		inventory[id] = 0

func _read(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % file))

# Additive content upgrade: old v2 sector records retain discoveries and timers.
func enrich_sectors(sectors: Array) -> void:
	for sector: Dictionary in sectors:
		for anomaly_id: String in alien_catalog:
			var definition: Dictionary = alien_catalog[anomaly_id]
			if definition.sector_id != sector.id:
				continue
			var found: bool = false
			for content: Dictionary in sector.contents:
				if content.get("anomaly_id", "") == anomaly_id or (content.type == "anomaly" and content.get("name") == definition.name):
					content["anomaly_id"] = anomaly_id
					content["description"] = definition.description
					found = true
			if not found:
				sector.contents.append({"type": "anomaly", "name": definition.name, "description": definition.description, "anomaly_id": anomaly_id})

func discover(sector: Dictionary) -> void:
	if not sector.revealed:
		return
	for content: Dictionary in sector.contents:
		var anomaly_id: String = str(content.get("anomaly_id", ""))
		if not alien_catalog.has(anomaly_id) or processed_anomalies.has(anomaly_id):
			continue
		var definition: Dictionary = alien_catalog[anomaly_id]
		processed_anomalies.append(anomaly_id)
		for contact_id: String in definition.contacts:
			var contact: Dictionary = definition.contacts[contact_id].duplicate(true)
			contact["sector_id"] = sector.id
			contact["anomaly_id"] = anomaly_id
			contacts[contact_id] = contact
			factions[contact.faction].met = true
		for good: String in definition.reward:
			inventory[good] = int(inventory.get(good, 0)) + int(definition.reward[good])
	changed.emit()

func trade_error(ship_id: int, contact_id: String, offer_id: String) -> String:
	if not model.ships.has(ship_id) or not model.ship_catalog[model.ships[ship_id]].has("trade"):
		return "Build and select a Trade Ship."
	if jobs.has(ship_id):
		return "This ship is already trading."
	if not contacts.has(contact_id):
		return "Survey an alien anomaly to establish contact first."
	if not offers.has(offer_id) or offers[offer_id].faction != contacts[contact_id].faction:
		return "This contact does not offer that exchange."
	var offer: Dictionary = offers[offer_id]
	if int(factions[offer.faction].standing) < int(offer.requires_standing):
		return "Requires %d standing with %s." % [offer.requires_standing, factions[offer.faction].name]
	for resource: String in offer.cost:
		if int(model.get(resource)) < int(offer.cost[resource]):
			return "Cargo needs " + cost_text(offer.cost) + "."
	return ""

# Fleet checks cross-role occupancy before calling this transaction.
func dispatch(ship_id: int, contact_id: String, offer_id: String) -> String:
	var error: String = trade_error(ship_id, contact_id, offer_id)
	if not error.is_empty():
		return error
	var offer: Dictionary = offers[offer_id]
	for resource: String in offer.cost:
		model.set(resource, int(model.get(resource)) - int(offer.cost[resource]))
	var duration: int = maxi(1, int(model.ship_catalog[model.ships[ship_id]].trade.seconds))
	next_trade_id += 1
	jobs[ship_id] = {"id": next_trade_id, "contact_id": contact_id, "offer_id": offer_id, "faction": offer.faction, "cost": offer.cost.duplicate(true), "goods": offer.goods.duplicate(true), "standing": int(offer.standing), "duration": duration, "remaining": duration}
	mission_started.emit()
	model.changed.emit()
	changed.emit()
	return ""

func tick() -> void:
	for ship_id: int in jobs.keys():
		var job: Dictionary = jobs[ship_id]
		job.remaining -= 1
		if job.remaining > 0:
			continue
		jobs.erase(ship_id)
		for good: String in job.goods:
			inventory[good] = int(inventory.get(good, 0)) + int(job.goods[good])
		var before: int = int(factions[job.faction].standing)
		factions[job.faction].standing = clampi(before + int(job.standing), -100, 100)
		_record(job, "completed", int(factions[job.faction].standing) - before)
		mission_completed.emit(job.contact_id, job.offer_id)
	changed.emit()

func cancel(ship_id: int) -> void:
	if not jobs.has(ship_id):
		return
	var job: Dictionary = jobs[ship_id]
	jobs.erase(ship_id)
	# Escrow is returned in full, even when storage was decommissioned in transit.
	for resource: String in job.cost:
		model.set(resource, int(model.get(resource)) + int(job.cost[resource]))
	_record(job, "cancelled", 0)
	changed.emit()

func _record(job: Dictionary, result: String, standing_delta: int) -> void:
	var entry: Dictionary = job.duplicate(true)
	entry["result"] = result
	entry["tick"] = model.ticks
	entry["standing_delta"] = standing_delta
	history.append(entry)

func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource: String in cost:
		parts.append("%d %s" % [cost[resource], resource.capitalize()])
	return " + ".join(parts)

func reward_text(offer: Dictionary) -> String:
	var parts: Array[String] = []
	for good: String in offer.goods:
		parts.append("%d %s" % [offer.goods[good], goods_catalog.get(good, {}).get("name", good)])
	parts.append("+%d standing" % offer.standing)
	return ", ".join(parts)

# Validate decoded extension state before SaveStore commits any model mutation.
func validate(data: Dictionary, station: Dictionary, mining: Dictionary) -> String:
	for faction_id: Variant in data.factions:
		var faction: Variant = data.factions[faction_id]
		if not faction_id is String or not faction is Dictionary or not faction.get("name") is String or not faction.get("met") is bool or not _integer(faction.get("standing"), -100, 100):
			return "Invalid alien standing or faction."
	for good: Variant in data.inventory:
		if not good is String or not _integer(data.inventory[good], 0):
			return "Invalid trade inventory."
	var revealed: Dictionary = {}
	for sector: Dictionary in mining.sectors:
		if sector.revealed:
			revealed[sector.id] = true
	var processed: Dictionary = {}
	for anomaly: Variant in data.processed_anomalies:
		if not anomaly is String or processed.has(anomaly):
			return "Invalid processed anomaly."
		if alien_catalog.has(anomaly) and not revealed.has(alien_catalog[anomaly].sector_id):
			return "Anomaly was processed before discovery."
		processed[anomaly] = true
	for contact_id: Variant in data.contacts:
		var contact: Variant = data.contacts[contact_id]
		if not contact_id is String or not contact is Dictionary or not contact.get("name") is String or not contact.get("faction") is String or not contact.get("sector_id") is String or not contact.get("anomaly_id") is String:
			return "Invalid alien contact."
		if not data.factions.has(contact.faction) or not data.factions[contact.faction].met or not revealed.has(contact.sector_id) or not processed.has(contact.anomaly_id):
			return "Contact references an undiscovered faction or anomaly."
	for anomaly_id: String in processed:
		if not alien_catalog.has(anomaly_id):
			continue
		for contact_id: String in alien_catalog[anomaly_id].contacts:
			if not data.contacts.has(contact_id) or data.contacts[contact_id].faction != alien_catalog[anomaly_id].contacts[contact_id].faction or data.contacts[contact_id].sector_id != alien_catalog[anomaly_id].sector_id:
				return "Processed alien anomaly is missing its contact."
	if not _integer(data.next_trade_id, 0):
		return "Invalid trade ID allocator."
	var ids: Dictionary = {}
	for ship_id: Variant in data.jobs:
		if not ship_id is int or not station.ships.has(ship_id) or not model.ship_catalog[station.ships[ship_id]].has("trade"):
			return "Trade references a missing Trade Ship."
		if mining.jobs.has(ship_id) or mining.survey_jobs.has(ship_id):
			return "Ship assigned to more than one mission."
		var error: String = _validate_record(data.jobs[ship_id], data, ids, true)
		if not error.is_empty():
			return error
	for entry: Variant in data.history:
		var error: String = _validate_record(entry, data, ids, false)
		if not error.is_empty():
			return error
	return ""

func _validate_record(entry: Variant, data: Dictionary, ids: Dictionary, active: bool) -> String:
	if not entry is Dictionary or not _integer(entry.get("id"), 1, int(data.next_trade_id)) or ids.has(entry.get("id")):
		return "Invalid or duplicate trade transaction."
	ids[entry.id] = true
	if not entry.get("contact_id") is String or not data.contacts.has(entry.contact_id) or not entry.get("offer_id") is String or not entry.get("faction") is String:
		return "Invalid trade destination."
	if entry.faction != data.contacts[entry.contact_id].faction:
		return "Trade faction and contact disagree."
	if not entry.get("cost") is Dictionary or not entry.get("goods") is Dictionary or not _integer(entry.get("standing"), 0, 100):
		return "Invalid trade cargo or rewards."
	for resource: Variant in entry.cost:
		if not ["materials", "minerals"].has(resource) or not _integer(entry.cost[resource], 1):
			return "Invalid cargo escrow."
	for good: Variant in entry.goods:
		if not good is String or not data.inventory.has(good) or not _integer(entry.goods[good], 1):
			return "Invalid trade goods."
	if not _integer(entry.get("duration"), 1) or not _integer(entry.get("remaining"), 1 if active else 0, int(entry.duration)):
		return "Invalid trade timer."
	if not active:
		if not ["completed", "cancelled"].has(entry.get("result")) or not _integer(entry.get("tick"), 0) or not _integer(entry.get("standing_delta"), 0, 100):
			return "Invalid trade history."
		if entry.result == "completed" and entry.remaining != 0:
			return "Completed trade still has travel time."
		if entry.result == "cancelled" and entry.standing_delta != 0:
			return "Cancelled trade granted standing."
	return ""

func _integer(value: Variant, minimum: int, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

# Newly installed catalog entries are additive to an existing extension.
func add_catalog_defaults() -> void:
	for faction_id: String in faction_catalog:
		if not factions.has(faction_id):
			factions[faction_id] = {"name": faction_catalog[faction_id].name, "standing": int(faction_catalog[faction_id].initial_standing), "met": false}
	for good: String in goods_catalog:
		if not inventory.has(good):
			inventory[good] = 0
