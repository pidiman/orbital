extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await get_tree().process_frame
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	var before: Dictionary = game.persistence.snapshot()
	for menu: String in hud.menu_buttons:
		await use(hud.menu_buttons[menu])
		var visible_panels: Array = hud.managed_panels.filter(func(p: Control) -> bool: return p.visible)
		checks[menu + " exclusive"] = visible_panels.size() == 1 and hud.active_menu == menu
		var open: Control = visible_panels[0]
		checks[menu + " message clearance"] = open.get_global_rect().end.y <= hud.footer.get_global_rect().position.y - 8
		checks[menu + " persistent bars"] = hud.materials_label.is_visible_in_tree() and hud.power_label.is_visible_in_tree() and hud.minerals_label.is_visible_in_tree() and hud.tech_label.is_visible_in_tree() and hud.xenocrystal_label.is_visible_in_tree() and hud.region_navigation.location_label.is_visible_in_tree() and hud.status_label.is_visible_in_tree()
		save_frame(menu.replace("/", "_"))
		await use(hud.menu_buttons[menu])
		checks[menu + " toggle close"] = hud.managed_panels.all(func(p: Control) -> bool: return not p.visible)
	checks.menus_do_not_mutate_game = before == game.persistence.snapshot()
	await use(hud.menu_buttons.Research)
	checks.research_separate = hud.research_panel.visible and not hud.gate_panel.visible
	await use(hud.menu_buttons["Gate/Travel"])
	checks.gate_separate = hud.gate_panel.visible and not hud.research_panel.visible
	await use(hud.gate_panel.close_button)
	checks.close_button = hud.active_menu.is_empty()
	await use(hud.menu_buttons.Build)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	await settle(2)
	checks.escape_closes = hud.active_menu.is_empty()
	# Native touch events use the engine's normal mouse emulation, without
	# invoking a signal or HUD method in place of player input.
	checks.touch_emulation_enabled = Input.emulate_mouse_from_touch
	await touch(hud.menu_buttons.Ships)
	checks.touch_opens = hud.active_menu == "Ships" and hud.panel.visible
	await touch(hud.panel_closes[hud.panel.get_instance_id()])
	checks.touch_closes = not hud.panel.visible
	# Existing module inspection / upgrade / recovery controls remain usable.
	game.model.materials = 1000
	game.model.minerals = 1000
	game.model.changed.emit()
	await use(hud.tool_buttons.solar)
	checks.placement_exposes_world = hud.managed_panels.all(func(p: Control) -> bool: return not p.visible)
	await click(game.board.cell_position(Vector2i(1, 0)))
	hud.choose("")
	await click(game.board.cell_position(Vector2i(1, 0)))
	checks.inspection_opens_build = hud.active_menu == "Build" and hud.tabs.current_tab == 2
	var tier: int = game.model.tier_at(Vector2(58, 0))
	await use(hud.upgrade_button)
	checks.upgrade_reachable = game.model.tier_at(Vector2(58, 0)) == tier + 1
	await use(hud.demolish_button)
	checks.demolish_reachable = not game.model.modules.has(Vector2(58, 0))
	await use(hud.menu_buttons.Ships)
	await use(hud.ship_buttons.scout)
	var ship: int = game.model.next_ship_id
	await use(hud.sell_buttons[ship])
	checks.decommission_reachable = not game.model.ships.has(ship)
	checks.all_module_actions = hud.tool_buttons.size() == game.model.catalog.size()
	checks.all_ship_roles = hud.ship_buttons.size() == game.model.ship_catalog.size()
	# Smaller landscape layout: menus stay bounded above the footer.
	hud.close_panels()
	get_window().content_scale_size = Vector2i(960, 720)
	get_window().size = Vector2i(960, 720)
	await settle(5)
	for menu: String in hud.menu_buttons:
		await use(hud.menu_buttons[menu])
		var open: Control = hud.managed_panels.filter(func(p: Control) -> bool: return p.visible)[0]
		checks[menu + " small viewport"] = open.get_global_rect().end.y <= hud.footer.get_global_rect().position.y - 8 and open.get_global_rect().end.x <= game.get_viewport_rect().size.x - 20
	await settle(3)
	save_frame("small_layout")
	report("checks", checks)
	finish()

func touch(control: Control) -> void:
	var point: Vector2 = get_viewport().get_final_transform() * control.get_global_rect().get_center()
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	Input.parse_input_event(event)
	await settle(2)
