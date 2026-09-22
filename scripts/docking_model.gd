extends RefCounted
# Parking is independent of work eligibility. Slots never make a ship busy.
signal changed
const FIELDS: Array[String] = ["ships", "usage"]
var ships: Dictionary = {}
var usage: Dictionary = {}
var suspended: bool = false
var fleet_ref: WeakRef
var fleet: RefCounted:
	get: return fleet_ref.get_ref()

func _init(owner_fleet: RefCounted) -> void:
	fleet_ref = weakref(owner_fleet)
	fleet.changed.connect(reconcile)
	fleet.model.changed.connect(reconcile)

func docks() -> Dictionary:
	var result: Dictionary = {}
	for id: String in fleet.model.locations.structures:
		var definition: Dictionary = fleet.model.structure_definition(id)
		if definition.has("docking") and fleet.model.is_structure_active(id):
			result[id] = definition.docking
	return result

func compatible(id: int, dock_id: String, available: Dictionary) -> bool:
	if not available.has(dock_id): return false
	var ship: Dictionary = fleet.model.locations.ships[id]
	var structure: Dictionary = fleet.model.locations.structures[dock_id]
	return structure.region == ship.region and structure.owner == ship.owner and (available[dock_id].ship_type == "*" or available[dock_id].ship_type == fleet.model.ship_catalog[ship.kind].get("dock_type", ship.kind))

func reconcile() -> void:
	if suspended: return
	var available: Dictionary = docks()
	var next_ships: Dictionary = {}
	var next_usage: Dictionary = {}
	for dock_id: String in available: next_usage[dock_id] = {}
	# Keep valid reservations before offering empty slots to waiting ships.
	for id: int in fleet.model.ships:
		var state: Dictionary = {"state": "working" if fleet.unit_busy(id) else "homeless", "region": fleet.model.locations.ship_region(id), "dock_id": "", "slot": -1}
		var previous: Dictionary = ships.get(id, {})
		if state.state == "homeless" and previous.get("state") == "parked":
			var dock_id: String = previous.dock_id
			var slot: int = int(previous.slot)
			if compatible(id, dock_id, available) and slot >= 0 and slot < int(available[dock_id].capacity) and not next_usage[dock_id].has(slot):
				state = previous.duplicate(true)
				state.region = fleet.model.locations.ship_region(id)
				next_usage[dock_id][slot] = id
		next_ships[id] = state
	for id: int in next_ships:
		if next_ships[id].state != "homeless": continue
		for dock_id: String in available:
			if not compatible(id, dock_id, available): continue
			for slot in range(int(available[dock_id].capacity)):
				if next_usage[dock_id].has(slot): continue
				next_usage[dock_id][slot] = id
				next_ships[id].merge({"state": "parked", "dock_id": dock_id, "slot": slot}, true)
				break
			if next_ships[id].state == "parked": break
	if ships != next_ships or usage != next_usage:
		ships = next_ships
		usage = next_usage
		changed.emit()

func status(id: int) -> String:
	return str(ships.get(id, {}).get("state", "homeless"))

func waiting_message() -> String:
	for id: int in ships:
		if status(id) == "homeless" and ships[id].region == fleet.regions.current_region:
			return homeless_message(id)
	return ""

func homeless_message(id: int) -> String:
	var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[id]]
	return "%s #%d idle — no free Space Dock slot. Ship can still take jobs." % [definition.name, id]

func validate(data: Dictionary) -> String:
	if not data.get("ships") is Dictionary or not data.get("usage") is Dictionary:
		return "Invalid docking state."
	for id: Variant in data.ships:
		var record: Variant = data.ships[id]
		if not id is int or not fleet.model.ships.has(id) or not record is Dictionary:
			return "Invalid docked ship identity."
		if not record.get("state") in ["working", "homeless", "parked"] or not record.get("region") is String or not record.get("dock_id") is String or not record.get("slot") is int:
			return "Invalid ship parking record."
	# Reconcile a candidate using the saved reservations; exact equality checks
	# capacity, duplicate slots, owner/region/type, missing ships and active jobs.
	ships = data.ships.duplicate(true)
	usage = data.usage.duplicate(true)
	reconcile()
	if ships != data.ships or usage != data.usage:
		return "Dock assignments disagree with ships, jobs or dock capacity."
	return ""
