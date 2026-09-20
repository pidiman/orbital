extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	summer_max_seconds = 120
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	checks.isolated = not game.persistence.enabled
	game.get_node("ResourceClock").set_process(false)
	# Fixed funding/discovery fixture; purchases, research, gates, founding and
	# mining below use the player's real controls. Trade is covered separately.
	game.model.materials = 2000
	game.fleet.diplomacy.inventory.tech = 2
	game.model.changed.emit()
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		await use(game.hud.tool_buttons.solar)
		await click(game.board.cell_position(cell))
	await use(game.hud.tool_buttons.research_lab)
	await click(game.board.cell_position(Vector2i(0, 1)))
	await use(game.hud.research_button)
	await use(game.hud.research_panel.research_buttons.teleportation)
	await use(game.hud.research_panel.close_button)
	await use(game.hud.tool_buttons.teleport_gate)
	await click(game.board.world_to_screen(Vector2(-87, -29)))
	checks.gate_built = game.model.modules.get(Vector2(-87, -29)) == "teleport_gate"
	if not checks.gate_built:
		report("setup_failure", {"message": game.hud.status_label.text, "selected": game.board.selected, "modules": str(game.model.modules), "research": game.fleet.research.researched})
		save_frame("setup_failure")
		report("checks", checks)
		finish()
		return
	await page(1)
	var funds: int = game.model.materials
	await use(game.hud.ship_buttons.jump_ship)
	var jump: int = game.model.next_ship_id
	checks.jump_ship_purchase = game.model.ships.get(jump) == "jump_ship" and game.model.materials == funds - 65
	await use(game.hud.ship_buttons.miner)
	var miner: int = game.model.next_ship_id
	checks.capability_button = game.hud.capability_buttons[jump].has("founding")
	await use(game.hud.capability_buttons[jump].founding)
	checks.home_message = game.hud.status_label.text.contains("non-Home")
	game.fleet._discover_region("venus")
	game.fleet.diplomacy.inventory.xenocrystal = 2
	await use(game.hud.research_button)
	pick_ship(jump)
	await use(game.hud.research_panel.jump_button)
	checks.jump_paid = game.fleet.transport.jobs.has(jump) and game.fleet.diplomacy.inventory.xenocrystal == 1
	await use(game.hud.research_panel.close_button)
	checks.transit_blocks_founding = game.hud.capability_buttons[jump].founding.disabled
	game.get_node("ResourceClock").set_process(true)
	await arrive(jump)
	game.get_node("ResourceClock").set_process(false)
	await use(game.hud.region_navigation.region_buttons.venus)
	checks.physical_arrival = game.model.locations.ship_region(jump) == "venus" and not game.board.visible
	game.model.materials = 59
	game.model.changed.emit()
	await use(game.hud.capability_buttons[jump].founding)
	checks.insufficient_message = game.hud.status_label.text.contains("60 Home Materials") and game.model.locations.stations.size() == 1
	game.model.materials = 100
	game.model.changed.emit()
	await use(game.hud.capability_buttons[jump].founding)
	var outpost_id: String = game.model.locations.outpost_at("venus", "player")
	checks.founded = not outpost_id.is_empty() and game.model.materials == 40 and game.model.locations.stations[outpost_id].inventory.minerals == 0
	if not checks.founded:
		report("checks", checks)
		finish()
		return
	checks.local_storage_visible = game.hud.orbit_label.text.contains("0 local Minerals")
	checks.founding_message = game.hud.status_label.text.contains("Outpost founded")
	await use(game.hud.capability_buttons[jump].founding)
	checks.duplicate_message = game.hud.status_label.text.contains("already have an outpost") and game.model.materials == 40
	await settle(3)
	save_frame("outpost_founded")
	checks.panel_fits = game.hud.panel.get_global_rect().end.y <= game.get_viewport_rect().size.y - 68
	report("panel_geometry", {"panel":str(game.hud.panel.get_global_rect()), "viewport":str(game.get_viewport_rect())})
	await use(game.hud.research_button)
	pick_ship(miner)
	await use(game.hud.research_panel.jump_button)
	checks.miner_gate_paid = game.fleet.transport.jobs.has(miner) and game.fleet.diplomacy.inventory.xenocrystal == 0
	await use(game.hud.research_panel.close_button)
	game.get_node("ResourceClock").set_process(true)
	await arrive(miner)
	game.get_node("ResourceClock").set_process(false)
	var target: int = game.fleet.regions.records.venus.asteroid_ids[0]
	await use(game.hud.capability_buttons[miner].mining)
	await click(game.asteroids.rocks[target].point)
	checks.local_mining_command = game.fleet.jobs.has(miner) and game.fleet.mining_assignment(miner).destination.station_id == outpost_id
	var home_ore: int = game.model.minerals
	game.get_node("ResourceClock").set_process(true)
	var attempts: int = 0
	while game.model.locations.stations[outpost_id].inventory.minerals == 0 and attempts < 900:
		attempts += 1
		await get_tree().physics_frame
	game.get_node("ResourceClock").set_process(false)
	checks.local_credit = game.model.locations.stations[outpost_id].inventory.minerals == 18 and game.model.minerals == home_ore
	checks.local_readout = game.hud.orbit_label.text.contains("18 local Minerals") and game.hud.minerals_label.text == str(home_ore)
	checks.deposit_message = game.hud.status_label.text.contains("Home storage unchanged")
	await use(game.hud.region_navigation.region_buttons.home)
	checks.home_station_still_home = game.board.visible and game.model.locations.station_region("station:home") == "home"
	await use(game.hud.region_navigation.region_buttons.venus)
	await settle(3)
	save_frame("outpost_mining")
	var test_path: String = "user://orbital-outpost-ui-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	await use(game.hud.save_button)
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.model.locations.stations[outpost_id].inventory.minerals = 0
	await use(game.hud.load_button)
	checks.roundtrip = game.persistence.snapshot() == expected
	checks.restored_ui = game.hud.orbit_label.text.contains("18 local Minerals") and game.model.locations.ship_region(miner) == "venus"
	await settle(3)
	save_frame("outpost_restored")
	checks.only_2d = no_3d(game)
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	report("checks", checks)
	finish()

func pick_ship(ship_id: int) -> void:
	var panel: PanelContainer = game.hud.research_panel
	for i in range(panel.ship_picker.item_count):
		if panel.ship_picker.get_item_id(i) == ship_id: panel.ship_picker.select(i)
	panel.refresh()

func arrive(ship_id: int) -> void:
	var attempts: int = 0
	while game.fleet.transport.jobs.has(ship_id) and attempts < 500:
		attempts += 1
		await get_tree().physics_frame
	await settle(2)

func page(index: int) -> void:
	var bar: TabBar = game.hud.tabs.get_tab_bar()
	await click(bar.global_position + bar.get_tab_rect(index).get_center())

func use(button: Control) -> void:
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await settle(2)
	await click(button.get_global_rect().get_center())

func click(point: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down, true)
	await settle(2)
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(up, true)
	await settle(2)

func no_3d(node: Node) -> bool:
	if node is Node3D: return false
	for child: Node in node.get_children():
		if not no_3d(child): return false
	return true

func _on_deadline() -> void:
	report("checks", checks)
	save_frame("timeout")
	super._on_deadline()
