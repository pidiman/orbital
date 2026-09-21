extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m = game.model
	m.materials = 1000
	m.build(Vector2(58, 0), "solar")
	m.build(Vector2(116, 0), "solar")
	var ore := Vector2(0, 58)
	var tech := Vector2(58, 58)
	m.build(ore, "refinery")
	m.build(tech, "refinery")
	checks.defaults = m.refinery_recipe_id(ore) == "minerals_materials" and m.refinery_recipe_id(tech) == "minerals_materials"
	game.hud.inspect_module(tech)
	await settle(2)
	game.hud.refinery_selector.select(1)
	game.hud.refinery_selector.item_selected.emit(1)
	checks.independent_selection = m.refinery_recipe_id(tech) == "materials_tech" and m.refinery_recipe_id(ore) == "minerals_materials"
	m.materials = 40
	m.minerals = 20
	for tick in range(20): m.tick()
	checks.parallel_output = m.materials == 20 and m.minerals == 10 and game.fleet.diplomacy.inventory.tech == 0 and m.refinery_buffer(ore).materials == 30 and m.refinery_buffer(tech).tech == 1
	checks.progress = m.refinery_progress[ore] == 0 and m.refinery_progress[tech] == 0
	var before: Dictionary = game.persistence.snapshot()
	checks.roundtrip = game.persistence.restore(before).is_empty() and game.persistence.snapshot() == before
	m.materials = m.capacity
	m.refinery_buffer(tech)["tech"] = 30
	var minerals: int = m.minerals
	var progress: Dictionary = m.refinery_progress.duplicate()
	for tick in range(30): m.tick()
	checks.full_pauses_both = m.materials == m.capacity and m.minerals == minerals and m.refinery_buffer(tech).tech == 30 and m.refinery_progress == progress
	m.refinery_buffer(tech).erase("tech")
	for tick in range(20): m.tick()
	checks.tech_resumes = m.materials == m.capacity - 20 and m.refinery_buffer(tech).tech == 1
	m.refinery_buffer(ore)["materials"] = 24
	for tick in range(3): m.tick()
	checks.ore_resumes = m.materials == m.capacity - 20 and m.minerals == minerals - 2 and m.refinery_buffer(ore).materials == 30
	game.hud.inspect_module(tech)
	await settle(2)
	checks.ui_recipe = game.hud.refinery_selector.get_item_metadata(game.hud.refinery_selector.selected) == "materials_tech" and game.hud.upgrade_stats.text.contains("Tech")
	save_frame("refinery_tech_recipe")
	# A pre-recipe v2 save has no per-structure recipe key.
	var legacy: Dictionary = game.persistence.snapshot()
	var locations: Dictionary = game.persistence._decode(legacy.extensions.world_locations.structures)
	for record: Dictionary in locations.values(): record.state.erase("refinery_recipe")
	legacy.extensions.world_locations.structures = game.persistence._encode(locations)
	checks.old_save = game.persistence.restore(legacy).is_empty() and m.refinery_recipe_id(ore) == "minerals_materials" and m.refinery_recipe_id(tech) == "minerals_materials"
	var invalid: Dictionary = game.persistence.snapshot()
	locations = game.persistence._decode(invalid.extensions.world_locations.structures)
	locations[m.structure_id_at(tech)].state.refinery_recipe = "invalid"
	invalid.extensions.world_locations.structures = game.persistence._encode(locations)
	var unchanged: Dictionary = game.persistence.snapshot()
	checks.invalid_atomic = not game.persistence.restore(invalid).is_empty() and game.persistence.snapshot() == unchanged
	m.materials = 0
	m.set_refinery_recipe(tech, "minerals_materials")
	m.set_refinery_recipe(tech, "materials_tech")
	var tech_before: int = game.fleet.diplomacy.inventory.tech
	m.tick()
	checks.no_input = game.fleet.diplomacy.inventory.tech == tech_before and m.refinery_progress[tech] == 0
	m.materials = 50
	game.fleet.diplomacy.inventory.tech = 0
	m.tick()
	m.set_refinery_recipe(tech, "minerals_materials")
	checks.switch_resets_progress = m.refinery_progress[tech] == 0 and m.materials == 50
	m.set_refinery_recipe(tech, "materials_tech")
	checks.tech_tiers = true
	for tier in range(1, 6):
		checks.tech_tiers = checks.tech_tiers and m.refinery_recipe(tech, tier).seconds == [20, 18, 16, 14, 12][tier - 1]
	report("checks", checks)
	finish()
