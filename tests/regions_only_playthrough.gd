extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m = game.model
	var fleet = game.fleet
	m.materials = 3000
	for i in range(1, 6): m.build(Vector2(i * 58, 0), "solar")
	m.buy_ship("scout")
	var scout: int = m.next_ship_id
	game.hud.select_ship(scout)
	await use(game.hud.capability_buttons[scout].survey)
	checks.scout_ui = game.hud.region_navigation.panel.visible
	checks.scout_region = fleet.survey_region(scout, "venus").is_empty()
	for i in range(10): fleet.tick()
	checks.discovered = fleet.regions.is_discovered("venus") and fleet.regions.records.venus.asteroid_ids.size() >= 2
	checks.contacts = fleet.diplomacy.contacts.has("lumen_envoy") and fleet.diplomacy.contacts.lumen_envoy.region_id == "venus"
	m.buy_ship("trader")
	var trader: int = m.next_ship_id
	m.minerals = 100
	var offer: String = ""
	for id: String in fleet.diplomacy.offers:
		if fleet.diplomacy.offers[id].faction == "lumen": offer = id; break
	checks.trade = fleet.trade(trader, "lumen_envoy", offer).is_empty()
	for i in range(20): fleet.tick()
	checks.trade_completed = not fleet.diplomacy.history.is_empty()
	var current: Dictionary = game.persistence.snapshot()
	checks.no_old_fields = not current.state.fleet.has("sectors") and not current.state.fleet.has("survey_jobs")
	checks.roundtrip = game.persistence.restore(current).is_empty() and game.persistence.snapshot() == current
	# A real v2-shaped legacy fixture: an ore discovery, already-earned contacts,
	# and an active old exploration mission. No player checkpoint is read/written.
	var old: Dictionary = current.duplicate(true)
	old.state.fleet["sectors"] = [{"id": "echo", "revealed": true, "contents": [{"type": "anomaly", "anomaly_id": "quiet_signal", "name": "Quiet signal"}]}]
	old.state.fleet["survey_jobs"] = game.persistence._encode({scout: {"sector_id": "quiet", "remaining": 3, "duration": 4}})
	var rocks: Dictionary = game.persistence._decode(old.state.fleet.asteroids)
	var target: int = int(old.state.fleet.next_discovery_id)
	rocks[target] = {"minerals": 37, "claimed": false, "persistent": true, "sector_id": "dawn", "name": "Legacy deposit", "position": Vector2(0.5, 0.1)}
	old.state.fleet.asteroids = game.persistence._encode(rocks)
	old.state.fleet.next_discovery_id = target - 1
	var contacts: Dictionary = game.persistence._decode(old.extensions.alien_trade.contacts)
	for contact: Dictionary in contacts.values():
		contact.erase("region_id")
		contact["sector_id"] = "echo"
	old.extensions.alien_trade.contacts = game.persistence._encode(contacts)
	var records: Dictionary = game.persistence._decode(old.extensions.regions.records)
	records.venus.contents = records.venus.contents.filter(func(content: Dictionary) -> bool: return not content.has("anomaly_id"))
	old.extensions.regions.records = game.persistence._encode(records)
	var inventory: Dictionary = fleet.diplomacy.inventory.duplicate(true)
	var standing: Dictionary = fleet.diplomacy.factions.duplicate(true)
	var error: String = game.persistence.restore(old)
	report("migration_error", error)
	checks.migrates = error.is_empty()
	checks.ore_preserved = fleet.asteroids.has(target) and fleet.asteroids[target].minerals == 37 and fleet.asteroid_region(target) == "home" and fleet.regions.records.home.asteroid_ids.has(target)
	checks.contact_migrated = fleet.diplomacy.contacts.lumen_envoy.region_id == "home"
	checks.earnings_preserved = fleet.diplomacy.inventory == inventory and fleet.diplomacy.factions == standing
	checks.old_mission_cancelled = not fleet.unit_busy(scout)
	current = game.persistence.snapshot()
	checks.migrated_roundtrip = game.persistence.restore(current).is_empty() and game.persistence.snapshot() == current
	# Existing outpost fixture: its founding ship had arrived before the new
	# paired-gate routing rule, as is possible in a migrated save.
	m.build(Vector2(0, 58), "research_lab")
	fleet.diplomacy.inventory.tech = 20
	fleet.research.research("teleportation")
	m.build(Vector2(-87, -29), "teleport_gate")
	m.buy_ship("jump_ship")
	var founder: int = m.next_ship_id
	fleet._discover_region("pluto")
	m.locations.ships[founder].region = "pluto"
	checks.legacy_outpost_found = fleet.outposts.found(founder).is_empty()
	var outpost: String = m.locations.outpost_at("pluto", "player")
	fleet.regions.set_location("pluto")
	var local: StationModel = game.board.model
	local.build(Vector2(58, 0), "solar")
	local.build(Vector2(-87, -29), "teleport_gate")
	m.locations.ships[founder].region = "home"
	fleet.diplomacy.inventory.xenocrystal = 5
	checks.nonadjacent = not fleet.regions.adjacent("home", "pluto")
	checks.direct_gate = fleet.transport.jump(Vector2(-87, -29), founder, "pluto").is_empty() and fleet.diplomacy.inventory.xenocrystal == 4
	current = game.persistence.snapshot()
	checks.direct_transit_save = game.persistence.restore(current).is_empty() and game.persistence.snapshot() == current
	for i in range(3): fleet.transport.tick()
	checks.direct_arrival = m.locations.ship_region(founder) == "pluto"
	checks.missing_gate_blocks = fleet.transport.jump(local.structure_id_at(Vector2(-87, -29)), founder, "venus").contains("needs a Teleport Gate")
	m.locations.stations[outpost].inventory.xenocrystal = 0
	checks.cost_blocks = not fleet.transport.jump(local.structure_id_at(Vector2(-87, -29)), founder, "home").is_empty()
	fleet.regions.set_location("home")
	await use(game.hud.menu_buttons["Trade/Contacts"])
	save_frame("regional_trade")
	report("checks", checks)
	finish()
