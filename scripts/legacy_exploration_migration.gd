extends RefCounted
# Compatibility boundary only: retired exploration data never enters live models.
static func migrate(old: Array, mining: Dictionary, regions: Dictionary, trade: Dictionary) -> void:
	var home: Dictionary = regions.records.home
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/aliens.json"))
	for id: int in mining.asteroids:
		var rock: Dictionary = mining.asteroids[id]
		if not rock.has("sector_id"): continue
		rock.erase("sector_id")
		rock["region_id"] = "home"
		if not home.asteroid_ids.has(id):
			home.asteroid_ids.append(id)
			home.contents.append({"type": "asteroid", "name": rock.get("name", "Recovered deposit"), "minerals": rock.minerals, "position": rock.get("position", Vector2.ZERO)})
	for contact: Dictionary in trade.get("contacts", {}).values():
		if contact.has("sector_id"):
			contact.erase("sector_id")
			contact["region_id"] = "home"
			add_anomaly(home, contact.anomaly_id, contact.get("name", "Recovered contact"))
	for record: Dictionary in old:
		if not record.get("revealed", false): continue
		for content: Dictionary in record.get("contents", []):
			if content.has("anomaly_id"): add_anomaly(home, content.anomaly_id, content.get("name", "Recovered anomaly"))
			else:
				for id: String in definitions:
					if content.get("name", "") == definitions[id].name: add_anomaly(home, id, definitions[id].name)
	for id: String in trade.get("processed_anomalies", []):
		var found: bool = false
		for record: Dictionary in regions.records.values():
			for content: Dictionary in record.contents:
				if content.get("anomaly_id", "") == id: found = true
		if not found: add_anomaly(home, id, "Recovered anomaly")

static func add_anomaly(home: Dictionary, id: String, title: String) -> void:
	for content: Dictionary in home.contents:
		if content.get("anomaly_id", "") == id: return
	home.contents.append({"type": "alien_anomaly", "anomaly_id": id, "name": title, "description": "Previously discovered contact.", "position": Vector2(350, 560)})

static func validate_input(old: Array, trade: Dictionary) -> String:
	for record: Variant in old:
		if not record is Dictionary or not record.get("contents", []) is Array: return "Invalid retired exploration record."
		for content: Variant in record.get("contents", []):
			if not content is Dictionary: return "Invalid retired discovery."
	for contact: Variant in trade.get("contacts", {}).values():
		if not contact is Dictionary or not contact.get("anomaly_id") is String: return "Invalid migrated contact."
	for id: Variant in trade.get("processed_anomalies", []):
		if not id is String: return "Invalid migrated anomaly flag."
	return ""
