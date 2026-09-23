extends RefCounted
signal changed
const FIELDS: Array[String] = ["researched", "labs"]
var catalog: Dictionary
var researched: Dictionary = {}
var labs: Dictionary:
	get: return model.capability_states("research", {"completed": 0})
	set(value): model.import_capability_states("research", value)
var model_ref: WeakRef
var trade_ref: WeakRef
var lab_sync_key: String = ""
var model: StationModel:
	get: return model_ref.get_ref()
var trade: RefCounted:
	get: return trade_ref.get_ref()

func _init(station: StationModel, diplomacy: RefCounted) -> void:
	model_ref = weakref(station)
	trade_ref = weakref(diplomacy)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/technologies.json"))
	model.module_removed.connect(sync_labs.unbind(1))
	model.module_built.connect(sync_labs.unbind(2))
	model.changed.connect(sync_labs)
	sync_labs()

func sync_labs() -> void:
	var key: String = str(model.modules)
	if key == lab_sync_key: return
	lab_sync_key = key
	model.capability_states("research", {"completed": 0})

func unlocked(category: String, item: String) -> bool:
	var gated: bool = false
	for id: String in catalog:
		if catalog[id].unlocks.get(category, []).has(item):
			gated = true
			if researched.has(id):
				return true
	return not gated

func research_error(id: String) -> String:
	if not catalog.has(id):
		return "Unknown technology."
	if researched.has(id):
		return "Technology already researched."
	if labs.is_empty():
		return "Build a Research Lab to research technologies."
	for prerequisite: String in catalog[id].get("requires", []):
		if not researched.has(prerequisite):
			return "Requires research: " + str(catalog.get(prerequisite, {}).get("name", prerequisite))
	if int(trade.inventory.get("tech", 0)) < int(catalog[id].tech_cost):
		return "Need %d Tech to research %s. Acquire Tech through trade." % [catalog[id].tech_cost, catalog[id].name]
	return ""

func state(id: String) -> String:
	if researched.has(id):
		return "Researched"
	return "Available" if research_error(id).is_empty() else "Locked"

func research(id: String) -> String:
	var error: String = research_error(id)
	if not error.is_empty():
		return error
	trade.inventory.tech -= int(catalog[id].tech_cost)
	researched[id] = true
	labs[labs.keys()[0]].completed += 1
	changed.emit()
	trade.changed.emit()
	model.changed.emit()
	return ""
