extends CanvasLayer
const DevConfig = preload("res://scripts/dev_config.gd")
var dev_panel: PanelContainer
const RegionNavigation = preload("res://scripts/region_navigation.gd")
var region_navigation: Control
var orbit_label: Label
const TradePanel = preload("res://scripts/trade_panel.gd")
var trade_panel: PanelContainer
var research_panel: PanelContainer
var research_button: Button
var gate_panel: PanelContainer
var tech_label: Label
var xenocrystal_label: Label
var menu_scroll: ScrollContainer
var toolbar: GridContainer
var title_label: Label
var ship_tray: ScrollContainer
var tray_rows: HBoxContainer
var ship_tiles: Dictionary = {}
var ship_context: PanelContainer
var empty_tray: Label
var context_title: Label
var context_detail: Label
var selected_ship_id: int = -1
var context_gate: Button
var station_view_button: Button
var grid_controls: HBoxContainer
var grid_buttons: Dictionary = {}
var menu_buttons: Dictionary = {}
var menu_panel: PanelContainer
var settings_button: Button
var footer_balance: Control
var settings_panel: PanelContainer
var settings_toggles: Dictionary = {}
var managed_panels: Array[PanelContainer] = []
var panel_closes: Dictionary = {}
var active_menu: String = ""
var footer: PanelContainer
var capability_buttons: Dictionary = {}
const SHIP_ACTIONS: Dictionary = {"mining": "Assign asteroid", "survey": "Survey sector", "trade": "Trade with contact", "collection": "Deploy at Home", "founding": "Found outpost"}
const SectorMap = preload("res://scripts/sector_map.gd")
var sector_map: PanelContainer
var map_button: Button
const Fleet = preload("res://scripts/mining_fleet.gd")
signal save_requested
signal load_requested
var save_button: Button
var load_button: Button
signal tool_selected(kind: String)
signal ship_assignment_requested(ship_id: int)
var model: StationModel
var fleet: Fleet
var minerals_label: Label
var fleet_label: Label
var refinery_label: Label
var materials_label: Label
var power_label: Label
var power_detail: Label
var level_label: Label
var count_label: Label
var status_label: Label
var goal_label: Label
var goal_bar: ProgressBar
var tabs: TabContainer
var ship_buttons: Dictionary = {}
var command_buttons: Dictionary = {}
var sell_buttons: Dictionary = {}
var ship_entries: Dictionary = {}
var demolish_button: Button
var ship_rows: VBoxContainer
var sector_label: Label
var upgrade_title: Label
var upgrade_stats: Label
var upgrade_detail: Label
var upgrade_button: Button
var selected_position: Vector2 = Vector2(99, 99)
var tool_buttons: Dictionary = {}
var selected: String = ""
var status_time: float = 0.0
var floating: Array[Dictionary] = []
var resource_bar: PanelContainer
var resource_status: HFlowContainer
var panel: PanelContainer
var root: Control
const INK := Color("dfebf2")
const MUTED := Color("7e95a9")
const CYAN := Color("72dbcb")
const GOLD := Color("eebd76")

func _ready() -> void:
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := PanelContainer.new()
	resource_bar = header
	header.name = "ResourceBar"
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 28
	header.offset_top = 80
	header.offset_right = -28
	header.offset_bottom = 160
	header.add_theme_stylebox_override("panel", _style(Color("111d2c"), Color("253647")))
	root.add_child(header)
	var header_margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		header_margin.add_theme_constant_override("margin_" + side, 24)
	header.add_child(header_margin)
	var header_rows := VBoxContainer.new()
	header_rows.add_theme_constant_override("separation", 8)
	header_margin.add_child(header_rows)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 6)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	header_rows.add_child(row)
	resource_status = HFlowContainer.new()
	resource_status.name = "ColonyStatus"
	resource_status.alignment = FlowContainer.ALIGNMENT_CENTER
	resource_status.add_theme_constant_override("h_separation", 24)
	resource_status.add_theme_constant_override("v_separation", 4)
	header_rows.add_child(resource_status)
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branding.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(branding)
	title_label = _label(branding, "O R B I T A L", 22, INK)
	branding.hide()
	var persistence := HBoxContainer.new()
	persistence.alignment = BoxContainer.ALIGNMENT_CENTER
	persistence.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(persistence)
	save_button = Button.new()
	save_button.text = "Save"
	save_button.custom_minimum_size = Vector2(62, 44)
	save_button.tooltip_text = "Save latest checkpoint. Autosaves also run after actions and every 10 seconds."
	save_button.pressed.connect(func() -> void:
		save_requested.emit()
		close_panels())
	persistence.add_child(save_button)
	load_button = Button.new()
	load_button.text = "Load"
	load_button.custom_minimum_size = Vector2(62, 44)
	load_button.tooltip_text = "Restore the latest manual or automatic checkpoint."
	load_button.pressed.connect(func() -> void: load_requested.emit())
	persistence.add_child(load_button)
	for action: Button in [save_button, load_button]:
		action.add_theme_font_size_override("font_size", 13)
		action.add_theme_color_override("font_color", INK)
		action.add_theme_stylebox_override("normal", _style(Color("172738"), Color("314454")))
		action.add_theme_stylebox_override("hover", _style(Color("25404b"), CYAN))
	var resources := VBoxContainer.new()
	resources.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(resources)
	_label(resources, "MATERIALS", 11, GOLD)
	materials_label = _label(resources, "", 24, INK)
	var ore := VBoxContainer.new()
	ore.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ore)
	_label(ore, "MINERALS", 11, Color("baa1f5"))
	minerals_label = _label(ore, "0", 24, Color("d2c1fa"))
	var power := VBoxContainer.new()
	power.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(power)
	power_label = _label(power, "", 24, CYAN)
	power_detail = _label(power, "", 11, MUTED)
	for good: String in ["Tech", "Xenocrystals"]:
		var group := VBoxContainer.new()
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(group)
		_label(group, good.to_upper(), 11, GOLD)
		var value := _label(group, "0", 24, INK)
		if good == "Tech": tech_label = value
		else: xenocrystal_label = value
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -332
	panel.offset_right = -28
	panel.offset_top = 124
	panel.add_theme_stylebox_override("panel", _style(Color("111c2b"), Color("2a3b4b")))
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8 if side == "bottom" else 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	tabs = TabContainer.new()
	tabs.name = "BuildTabs"
	tabs.custom_minimum_size = Vector2(272, 340)
	tabs.add_theme_stylebox_override("panel", _style(Color("111c2b"), Color("111c2b")))
	tabs.add_theme_stylebox_override("tab_selected", _style(Color("25404b"), CYAN))
	tabs.add_theme_stylebox_override("tab_unselected", _style(Color("162636"), Color("314454")))
	for style_name: String in ["tab_selected", "tab_unselected"]:
		var tab_style: StyleBox = tabs.get_theme_stylebox(style_name)
		tab_style.content_margin_left = 10
		tab_style.content_margin_right = 10
		tab_style.content_margin_top = 7
		tab_style.content_margin_bottom = 7
	tabs.add_theme_color_override("font_selected_color", INK)
	tabs.add_theme_color_override("font_unselected_color", MUTED)
	tabs.add_theme_font_size_override("font_size", 14)
	column.add_child(tabs)
	var module_scroll := ScrollContainer.new()
	module_scroll.name = "Modules"
	module_scroll.custom_minimum_size.y = 340
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(module_scroll)
	var module_page := VBoxContainer.new()
	module_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module_page.add_theme_constant_override("separation", 4)
	module_scroll.add_child(module_page)
	var instruction := _label(module_page, "Choose a module, then a green cell.", 12, MUTED)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for kind: String in model.catalog:
		var definition: Dictionary = model.catalog[kind]
		if not definition.get("buildable", true): continue
		var button: Button = _catalog_button(module_page, definition)
		button.name = kind.capitalize() + "Button"
		button.pressed.connect(func() -> void: choose(kind))
		tool_buttons[kind] = button
	_build_ships_page()
	_build_upgrade_page()
	map_button = Button.new()
	map_button.text = "Sector map / Exploration"
	map_button.custom_minimum_size.y = 34
	map_button.pressed.connect(func() -> void: sector_map.open_map())
	column.add_child(map_button)
	research_button = Button.new()
	research_button.text = "Research"
	research_button.custom_minimum_size.y = 34
	research_button.pressed.connect(func() -> void: research_panel.open_panel())
	column.add_child(research_button)
	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "Inspect / cancel command"
	cancel.custom_minimum_size.y = 34
	cancel.add_theme_stylebox_override("normal", _style(Color("111c2b"), Color("314254")))
	cancel.add_theme_stylebox_override("hover", _style(Color("20374a"), CYAN))
	cancel.pressed.connect(func() -> void: choose(""); close_panels())
	column.add_child(cancel)
	fleet_label = _label(resource_status, "", 12, Color("baa1f5"))
	refinery_label = _label(resource_status, "", 12, GOLD)
	level_label = _label(resource_status, "", 12, INK)
	count_label = _label(column, "", 12, MUTED)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size.y = 6
	goal_bar.add_theme_stylebox_override("background", _style(Color("283848"), Color("283848"), 2))
	goal_bar.add_theme_stylebox_override("fill", _style(CYAN, CYAN, 2))
	column.add_child(goal_bar)
	goal_label = _label(column, "", 13, CYAN)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -84
	footer.offset_bottom = -24
	footer.add_theme_stylebox_override("panel", _style(Color("101c2a"), Color("2b3a4a")))
	root.add_child(footer)
	status_label = _label(footer, "", 14, INK)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orbit_label = _label(root, "EARTH  /  408 KM\nA small beginning. An infinite horizon.", 13, Color("6894aa"))
	orbit_label.position = Vector2(42, 0)
	orbit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	orbit_label.position = Vector2(42, get_viewport().get_visible_rect().size.y - 124)
	sector_map = SectorMap.new()
	sector_map.hud = self
	sector_map.fleet = fleet
	root.add_child(sector_map)
	trade_panel = TradePanel.new()
	trade_panel.hud = self
	trade_panel.fleet = fleet
	root.add_child(trade_panel)
	_create_region_navigation()
	research_panel = preload("res://scripts/research_panel.gd").new()
	research_panel.hud = self
	research_panel.fleet = fleet
	root.add_child(research_panel)
	gate_panel = preload("res://scripts/gate_panel.gd").new()
	gate_panel.hud = self
	gate_panel.fleet = fleet
	root.add_child(gate_panel)
	_setup_menus()
	_setup_ship_tray()
	fleet.docking.changed.connect(_refresh_ships)
	_setup_grid_controls()
	if DevConfig.DEBUG_MODE:
		dev_panel = preload("res://scripts/dev_panel.gd").new()
		dev_panel.hud = self
		root.add_child(dev_panel)
	fleet.transport.arrived.connect(func(ship_id: int, region_id: String) -> void: message("Ship #%d arrived at %s. Use Ships commands for local operations." % [ship_id, fleet.regions.catalog[region_id].name]))
	fleet.diplomacy.mission_completed.connect(_trade_completed)
	model.changed.connect(refresh)
	fleet.changed.connect(refresh)
	model.level_reached.connect(_level_up)
	refresh()
	message("Welcome, commander. Click amber debris to collect materials.", false, 7.0)

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _style(fill: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func choose(kind: String) -> void:
	if not kind.is_empty() and not fleet.regions.primary_station_visible():
		message("Jump Home to construct station modules.", true)
		return
	if not kind.is_empty(): close_panels()
	selected = kind
	for id: String in tool_buttons:
		tool_buttons[id].add_theme_stylebox_override("normal", _style(Color("1f3a3c") if id == selected else Color("172738"), CYAN if id == selected else Color("304557")))
	tool_selected.emit(kind)
	message("Click labeled floating resources to collect; violet asteroids dispatch a Miner." if kind.is_empty() else "%s selected. Click a green cell beside the station." % model.catalog[kind].name)

func refresh() -> void:
	var home: bool = fleet.regions.primary_station_visible()
	for kind: String in tool_buttons:
		tool_buttons[kind].visible = model.module_unlocked(kind)
		tool_buttons[kind].disabled = not home
	orbit_label.text = "EARTH  /  408 KM\nA small beginning. An infinite horizon." if home else "%s / EXPLORATION\n%s" % [str(fleet.regions.catalog[fleet.regions.current_region].name).to_upper(), fleet.outposts.short_summary(fleet.regions.current_region)]
	tech_label.text = str(fleet.diplomacy.inventory.get("tech", 0))
	xenocrystal_label.text = str(fleet.diplomacy.inventory.get("xenocrystal", 0))
	minerals_label.text = str(model.minerals)
	fleet_label.text = "MINERS  %d idle / %d total" % [fleet.idle_count(), fleet.mining_units().size()]
	var refinery_count: int = model.module_count_with("conversion")
	refinery_label.text = "REFINERIES  %d · %s" % [refinery_count, _refinery_status()]
	materials_label.text = "%d / %d" % [model.materials, model.capacity]
	power_label.text = "+%d POWER" % model.power_balance()
	power_detail.text = "%d generated  /  %d used" % [model.power_output, model.power_use]
	level_label.text = "Level %02d  ·  %s" % [model.level, "Outpost" if model.level == 1 else ("Settlement" if model.level == 2 else "Colony")]
	count_label.text = ("" if home else "HOME / ") + "%02d modules connected" % model.modules.size()
	goal_bar.max_value = 9
	goal_bar.value = mini(model.modules.size(), 9)
	_refresh_ships()
	_refresh_upgrade()
	goal_label.text = "Build %d more modules to establish your colony." % (9 - model.modules.size()) if model.modules.size() < 9 else "Colony established. Keep growing."

func message(text: String, error: bool = false, duration: float = 4.0) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("f0a197") if error else INK)
	status_time = duration

func _level_up(level: int) -> void:
	message("COLONY ESTABLISHED  ·  Your little corner of the cosmos is thriving." if level == 3 else "LEVEL %d REACHED  ·  A new chapter above Earth." % level, false, 8.0)
	var title := _label(root, "COLONY ESTABLISHED" if level == 3 else "LEVEL %d REACHED" % level, 30, CYAN)
	title.position = Vector2(150, 440)
	floating.append({"label": title, "time": 0.0, "duration": 4.0})

func show_salvage(amount: int, point: Vector2, resource: String = "materials") -> void:
	var label := _label(root, "+%d %s" % [amount, resource.to_upper()], 16, GOLD)
	label.position = get_viewport().get_canvas_transform() * point + Vector2(-35, -30)
	floating.append({"label": label, "time": 0.0, "duration": 1.2})

func _process(delta: float) -> void:
	if is_instance_valid(grid_controls):
		grid_controls.visible = get_parent().preferences.values.show_grid_controls
		footer_balance.visible = grid_controls.visible
	status_time -= delta
	if status_time <= 0:
		status_label.text = "Labeled pickups: salvage  ·  Violet asteroids: mine  ·  Inspect a module to upgrade  ·  Ships: fleet commands" if fleet.regions.primary_station_visible() else "Labeled pickups: salvage  ·  Violet: mine  ·  Outposts/Regions: Scout / view region  ·  Station construction remains at Home"
		if fleet.collection != null and not fleet.collection.waiting_message().is_empty():
			status_label.text = fleet.collection.waiting_message()
		if not fleet.docking.waiting_message().is_empty() and fleet.collection.waiting_message().is_empty():
			status_label.text = fleet.docking.waiting_message()
		status_label.add_theme_color_override("font_color", MUTED)
	for item: Dictionary in floating:
		item.time += delta
		item.label.position.y -= delta * 20
		item.label.modulate.a = clampf((item.duration - item.time) * 2, 0, 1)
		if item.time >= item.duration:
			item.label.queue_free()
	floating = floating.filter(func(item: Dictionary) -> bool: return item.time < item.duration)

func _refinery_status() -> String:
	if model.module_count_with("conversion") == 0:
		return "build to process ore"
	for world_position: Vector2 in model.modules:
		var definition: Dictionary = model.definition_at(world_position)
		if not definition.has("conversion"):
			continue
		var recipe: Dictionary = definition.conversion
		if model.minerals < int(recipe.input):
			return "waiting for minerals"
		if model.capacity - model.materials < int(recipe.output):
			return "storage full · paused"
		return "next batch in %ds" % (int(recipe.seconds) - int(model.refinery_progress.get(world_position, 0)))
	return "idle"

func show_minerals(amount: int, point: Vector2) -> void:
	var label := _label(root, "+%d MINERALS" % amount, 18, Color("cdb6ff"))
	var screen_point: Vector2 = get_viewport().get_canvas_transform() * point
	label.position = Vector2(clampf(screen_point.x - 40, 32, 800), screen_point.y + 22)
	floating.append({"label": label, "time": 0.0, "duration": 2.0})

func show_refining(amount: int) -> void:
	message("Refinery output: +%d Materials from Minerals." % amount)

func _catalog_button(parent: Node, definition: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(270, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = definition.description
	button.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))
	button.add_theme_stylebox_override("hover", _style(Color("20374a"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("214439"), CYAN))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), CYAN))
	parent.add_child(button)
	var text_column := VBoxContainer.new()
	text_column.position = Vector2(10, 4)
	text_column.add_theme_constant_override("separation", 0)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(text_column)
	_label(text_column, "%s · %d M" % [definition.name, definition.cost], 15, Color(definition.color))
	_label(text_column, definition.effect, 11, INK)
	return button

func _build_ships_page() -> void:
	var page := VBoxContainer.new()
	page.name = "Ships"
	page.add_theme_constant_override("separation", 5)
	tabs.add_child(page)
	_label(page, "Independent ships · no grid cell needed", 12, MUTED)
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.custom_minimum_size.y = 0
	catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(catalog_scroll)
	var catalog_rows := VBoxContainer.new()
	catalog_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_scroll.add_child(catalog_rows)
	for kind: String in model.ship_catalog:
		var definition: Dictionary = model.ship_catalog[kind]
		var button: Button = _catalog_button(catalog_rows, definition)
		ship_buttons[kind] = button
		button.pressed.connect(func() -> void: _buy_ship(kind))
	sector_label = _label(page, "", 12, Color("8bcdf1"))
	var scroll := ScrollContainer.new()
	scroll.hide()
	scroll.custom_minimum_size = Vector2(270, 0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	ship_rows = VBoxContainer.new()
	ship_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ship_rows)
	var hint := _label(page, "Select an owned ship in the icon tray for commands.", 11, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _buy_ship(kind: String) -> void:
	var error: String = model.buy_ship(kind)
	if not error.is_empty():
		message(error, true)
		return
	choose("")
	message(fleet.docking.homeless_message(model.next_ship_id) if fleet.docking.status(model.next_ship_id) == "homeless" else "%s #%d ready. Select its tile for commands." % [model.ship_catalog[kind].name, model.next_ship_id])

func _refresh_ships() -> void:
	for removed_id: int in ship_entries.keys():
		if not model.ships.has(removed_id):
			ship_entries[removed_id].hide()
			ship_entries[removed_id].queue_free()
			ship_entries.erase(removed_id)
			command_buttons.erase(removed_id)
			capability_buttons.erase(removed_id)
			sell_buttons.erase(removed_id)
	sector_label.text = "SECTORS  %d / %d revealed" % [fleet.revealed_count(), fleet.sectors.size()]
	for ship_id: int in model.ships:
		var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
		if not ship_entries.has(ship_id):
			var entry := VBoxContainer.new()
			ship_rows.add_child(entry)
			ship_entries[ship_id] = entry
			capability_buttons[ship_id] = {}
			for capability: String in SHIP_ACTIONS:
				if not definition.has(capability):
					continue
				var button := Button.new()
				button.custom_minimum_size.y = 44
				button.add_theme_font_size_override("font_size", 12)
				button.add_theme_color_override("font_disabled_color", Color("b9a6f5"))
				button.add_theme_stylebox_override("disabled", _style(Color("172738"), Color("304557")))
				button.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))
				button.add_theme_stylebox_override("hover", _style(Color("20374a"), CYAN))
				button.pressed.connect(func() -> void: _command_ship(ship_id, capability))
				entry.add_child(button)
				capability_buttons[ship_id][capability] = button
				if not command_buttons.has(ship_id):
					command_buttons[ship_id] = button
			if capability_buttons[ship_id].is_empty():
				_label(entry, "%s #%d · No commands" % [definition.name, ship_id], 12, MUTED)
			var sell := Button.new()
			sell.custom_minimum_size.y = 44
			sell.add_theme_font_size_override("font_size", 12)
			sell.tooltip_text = "Cancels missions; refunds trade cargo and frees power. Refunds survive full storage."
			sell.pressed.connect(func() -> void: _sell_ship(ship_id))
			entry.add_child(sell)
			sell_buttons[ship_id] = sell
		ship_entries[ship_id].visible = ship_id == selected_ship_id
		var status: String = ""
		if fleet.transport.jobs.has(ship_id):
			status = "In transit"
		elif fleet.collection != null and fleet.collection.jobs.has(ship_id):
			status = fleet.collection.jobs[ship_id].status
		elif fleet.jobs.has(ship_id):
			status = "Mining · %ds" % fleet.jobs[ship_id].remaining
		elif fleet.regions.survey_jobs.has(ship_id):
			status = "Scouting · %ds" % fleet.regions.survey_jobs[ship_id].remaining
		elif fleet.survey_jobs.has(ship_id):
			status = "Surveying · %ds" % fleet.survey_jobs[ship_id].remaining
		elif fleet.diplomacy.jobs.has(ship_id):
			status = "Trading · %ds" % fleet.diplomacy.jobs[ship_id].remaining
		for capability: String in capability_buttons[ship_id]:
			var button: Button = capability_buttons[ship_id][capability]
			button.text = "%s #%d · %s" % [definition.name, ship_id, status if not status.is_empty() else str(definition[capability].get("assignment_label", SHIP_ACTIONS[capability]))]
			var work_error: String = fleet.mining_work_error(ship_id) if capability == "mining" else fleet.transport.work_error(ship_id)
			if capability == "founding":
				work_error = ""
				button.text = "%s #%d · Found outpost" % [definition.name, ship_id]
				button.tooltip_text = fleet.outposts.cost_text(ship_id) + "\n" + fleet.outposts.founding_error(ship_id)
			elif status.is_empty() and fleet.transport.location(ship_id) != fleet.regions.HOME:
				button.text += " · " + str(fleet.regions.catalog[fleet.transport.location(ship_id)].name)
			button.disabled = fleet.unit_busy(ship_id) or not work_error.is_empty()
			if capability != "founding": button.tooltip_text = work_error
		sell_buttons[ship_id].text = "Decommission · +%d M" % model.ship_refund(ship_id)

	_refresh_tray()

func _command_ship(ship_id: int, capability: String = "") -> void:
	choose("")
	var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
	if capability.is_empty():
		for action: String in SHIP_ACTIONS:
			if definition.has(action):
				capability = action
				break
	if not definition.has(capability) or fleet.unit_busy(ship_id):
		return
	match capability:
		"founding":
			var error: String = fleet.outposts.found(ship_id)
			message("Outpost founded. Local Minerals stay here; hauling is not available yet." if error.is_empty() else error, not error.is_empty(), 8.0)
		"collection":
			var error: String = fleet.collection.deploy(ship_id)
			message("Material Ship deployed at Earth." if error.is_empty() else error, not error.is_empty())
		"mining":
			close_panels()
			ship_assignment_requested.emit(ship_id)
			message("%s #%d selected. Click a %s; mining repeats until depleted." % [definition.name, ship_id, definition.mining.get("target_label", "violet Ore asteroid")], false, 8.0)
		"survey":
			if not fleet.regions.primary_station_visible():
				region_navigation.open_region(fleet.regions.current_region, ship_id)
				message("Choose an adjacent region and send your Scout.")
				return
			var error: String = fleet.survey(ship_id)
			message("Scout exploring the next sector. Open Sector map to view its destination." if error.is_empty() else error, not error.is_empty())
		"trade":
			region_navigation.panel.hide()
			trade_panel.open_contacts(ship_id)

func _trade_completed(contact_id: String, offer_id: String) -> void:
	var diplomacy: RefCounted = fleet.diplomacy
	message("Trade complete with %s: %s." % [diplomacy.contacts[contact_id].name, diplomacy.reward_text(diplomacy.offers.get(offer_id, diplomacy.history.back()))], false, 8.0)

func _build_upgrade_page() -> void:
	var page := VBoxContainer.new()
	page.name = "Upgrade"
	page.add_theme_constant_override("separation", 12)
	tabs.add_child(page)
	upgrade_title = _label(page, "", 20, CYAN)
	upgrade_stats = _label(page, "", 14, INK)
	upgrade_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_detail = _label(page, "", 13, MUTED)
	upgrade_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_button = Button.new()
	upgrade_button.custom_minimum_size.y = 54
	upgrade_button.add_theme_font_size_override("font_size", 13)
	upgrade_button.add_theme_color_override("font_disabled_color", MUTED)
	upgrade_button.add_theme_stylebox_override("normal", _style(Color("214139"), CYAN))
	upgrade_button.add_theme_stylebox_override("hover", _style(Color("31534a"), CYAN))
	upgrade_button.pressed.connect(_upgrade_selected)
	page.add_child(upgrade_button)
	demolish_button = Button.new()
	demolish_button.custom_minimum_size.y = 38
	demolish_button.add_theme_font_size_override("font_size", 13)
	demolish_button.pressed.connect(_demolish_selected)
	page.add_child(demolish_button)
	var hint := _label(page, "Inspect mode: click any station module to see its tier and available upgrade.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func inspect_module(world_position: Vector2) -> void:
	choose("")
	selected_position = world_position
	activate_panel(panel, "Build")
	tabs.current_tab = 2
	_refresh_upgrade()

func _refresh_upgrade() -> void:
	if not fleet.regions.primary_station_visible():
		upgrade_title.text = "Station at Earth"
		upgrade_stats.text = "Jump Home to inspect or modify modules."
		upgrade_detail.text = "This region is exploration-only."
		upgrade_button.disabled = true
		demolish_button.disabled = true
		return
	var demolition_error: String = model.demolition_error(selected_position)
	demolish_button.disabled = not demolition_error.is_empty()
	demolish_button.text = "Demolish · +%d M" % model.module_refund(selected_position)
	demolish_button.tooltip_text = demolition_error if not demolition_error.is_empty() else "Frees position and power; cancels dock missions. Remaining modules stay operational. Stock and refund are retained above capacity."
	if not model.modules.has(selected_position):
		upgrade_title.text = "Select a module"
		upgrade_stats.text = "Use Inspect, then click a station module."
		upgrade_detail.text = "Habitat · Solar · Storage · Refinery"
		upgrade_button.text = "Select a module to upgrade"
		upgrade_button.disabled = true
		return
	var definition: Dictionary = model.definition_at(selected_position)
	upgrade_title.text = "%s · Tier %d" % [definition.name, model.tier_at(selected_position)]
	upgrade_stats.text = "Generates %d Power · uses %d\nMaterial capacity bonus: %d" % [definition.power_output, definition.power_use, definition.capacity]
	if definition.has("docking"):
		var dock_id: String = model.structure_id_at(selected_position)
		upgrade_stats.text += "\nParking: %d / %d ships" % [fleet.docking.usage.get(dock_id, {}).size(), int(definition.docking.capacity)]
	if definition.has("conversion"):
		upgrade_stats.text += "\n%d Minerals → %d Materials / %ds" % [definition.conversion.input, definition.conversion.output, definition.conversion.seconds]
	var current_tier: int = model.tier_at(selected_position)
	var next: Dictionary = model.next_upgrade(selected_position)
	if next.is_empty():
		upgrade_detail.text = "Maxed · Maximum tier reached."
		upgrade_button.text = "Maximum tier"
		upgrade_button.disabled = true
		return
	upgrade_detail.text = "Next: %s for %s" % [next.description, model.upgrade_cost_text(next.cost)]
	upgrade_button.text = "Upgrade to T%d" % (current_tier + 1)
	var error: String = model.upgrade_error(selected_position)
	upgrade_button.disabled = not error.is_empty()
	upgrade_button.tooltip_text = error
	if not error.is_empty(): upgrade_detail.text += "\n\n" + error

func _upgrade_selected() -> void:
	var error: String = model.upgrade_module(selected_position)
	message("Module upgraded to Tier %d." % model.tier_at(selected_position) if error.is_empty() else error, not error.is_empty())

func _demolish_selected() -> void:
	var refund: int = model.module_refund(selected_position)
	var error: String = model.demolish_module(selected_position)
	message("Module decommissioned. +%d Materials; position freed." % refund if error.is_empty() else error, not error.is_empty())

func _sell_ship(ship_id: int) -> void:
	var cargo: Dictionary = fleet.diplomacy.jobs.get(ship_id, {}).get("cost", {}).duplicate(true)
	var refund: int = model.ship_refund(ship_id)
	var error: String = model.decommission_ship(ship_id)
	var success: String = "Ship decommissioned. +%d Materials; power freed." % refund
	if not cargo.is_empty():
		success += " Cargo returned: " + fleet.diplomacy.cost_text(cargo) + "."
	message(success if error.is_empty() else error, not error.is_empty())

func reset_after_load() -> void:
	research_panel.hide()
	close_panels()
	gate_panel.picker_signature = ""
	gate_panel.refresh()
	research_panel.refresh()
	choose("")
	selected_position = Vector2.INF
	selected_ship_id = -1
	for tile: Control in ship_tiles.values(): tile.queue_free()
	ship_tiles.clear()
	for item: Dictionary in floating:
		item.label.queue_free()
	floating.clear()
	for entry: Control in ship_entries.values():
		entry.hide()
		entry.queue_free()
	ship_entries.clear()
	command_buttons.clear()
	capability_buttons.clear()
	sell_buttons.clear()
	fleet.changed.disconnect(sector_map.refresh)
	model.changed.disconnect(sector_map.refresh)
	root.remove_child(sector_map)
	sector_map.queue_free()
	sector_map = SectorMap.new()
	sector_map.hud = self
	sector_map.fleet = fleet
	root.add_child(sector_map)
	fleet.changed.disconnect(trade_panel.refresh)
	model.changed.disconnect(trade_panel.refresh)
	root.remove_child(trade_panel)
	trade_panel.queue_free()
	trade_panel = TradePanel.new()
	trade_panel.hud = self
	trade_panel.fleet = fleet
	root.add_child(trade_panel)
	fleet.changed.disconnect(region_navigation.refresh)
	model.changed.disconnect(region_navigation.refresh)
	region_navigation.location_label.queue_free()
	root.remove_child(region_navigation)
	region_navigation.queue_free()
	_create_region_navigation()
	_install_secondary_panels()
	refresh()

func _create_region_navigation() -> void:
	region_navigation = RegionNavigation.new()
	region_navigation.hud = self
	region_navigation.fleet = fleet
	root.add_child(region_navigation)

# All menu state is presentation-only. Model calls remain in the original handlers.
func _setup_menus() -> void:
	tabs.tabs_visible = false
	tabs.use_hidden_tabs_for_min_size = false
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 28
	top_bar.offset_right = -28
	top_bar.offset_top = 8
	top_bar.offset_bottom = 76
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", _style(Color("111d2c"), Color("253647")))
	root.add_child(top_bar)
	title_label.reparent(root)
	toolbar = GridContainer.new()
	toolbar.columns = 7
	toolbar.add_theme_constant_override("h_separation", 8)
	toolbar.add_theme_constant_override("v_separation", 8)
	menu_scroll = ScrollContainer.new()
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(menu_scroll)
	menu_scroll.add_child(toolbar)
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for caption: String in ["Build", "Ships", "Research", "Gate/Travel", "Outposts/Regions", "Trade/Contacts", "Menu"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))
		button.add_theme_stylebox_override("hover", _style(Color("25404b"), CYAN))
		button.pressed.connect(func() -> void: open_menu(caption))
		toolbar.add_child(button)
		menu_buttons[caption] = button
	research_button.get_parent().remove_child(research_button)
	research_button.queue_free()
	research_button = menu_buttons["Research"]
	_setup_settings()
	_setup_menu()
	_wrap_panel(panel, "Build / Ships")
	_wrap_panel(research_panel, "Research")
	_wrap_panel(gate_panel, "Gate / Travel")
	_install_secondary_panels()
	resource_bar.resized.connect(_layout_menus)
	get_viewport().size_changed.connect(_layout_menus)
	close_panels()
	_layout_menus()

func _install_secondary_panels() -> void:
	for id: int in panel_closes.keys():
		if not is_instance_valid(panel_closes[id]) or not panel_closes[id].is_inside_tree(): panel_closes.erase(id)
	managed_panels = managed_panels.filter(func(item: PanelContainer) -> bool: return is_instance_valid(item) and item.is_inside_tree())
	_wrap_panel(sector_map, "Home sectors / Exploration")
	_wrap_panel(trade_panel, "Trade / Contacts")
	_wrap_panel(region_navigation.panel, "Outposts / Regions")
	# The existing Home-sector action lives alongside the region overview.
	map_button.reparent(region_navigation.panel.get_node("MenuFrame/Content/Body"))
	map_button.get_parent().move_child(map_button, 0)
	map_button.text = "Home sectors / Exploration"
	map_button.custom_minimum_size.y = 44
	_layout_menus()

func _wrap_panel(target: PanelContainer, title: String) -> void:
	var children := target.get_children()
	var frame := VBoxContainer.new()
	frame.name = "MenuFrame"
	target.add_child(frame)
	var heading := HBoxContainer.new()
	frame.add_child(heading)
	var label := _label(heading, title, 18, CYAN)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Close ×"
	close.custom_minimum_size = Vector2(88, 44)
	close.pressed.connect(close_panels)
	heading.add_child(close)
	panel_closes[target.get_instance_id()] = close
	var view: Node = region_navigation if target == region_navigation.panel else target
	if view != panel and view != ship_context and view != settings_panel and view != menu_panel:
		var old_close: Button = view.close_button
		old_close.get_parent().hide()
		view.close_button = close
		if target == sector_map:
			sector_map.contacts_button.reparent(heading)
			heading.move_child(sector_map.contacts_button, 1)
	var scroll := ScrollContainer.new()
	scroll.name = "Content"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for child: Node in children: child.reparent(body)
	target.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	target.custom_minimum_size = Vector2.ZERO
	var panel_style := target.get_theme_stylebox("panel").duplicate()
	for side: String in ["left", "right", "top", "bottom"]: panel_style.set("content_margin_" + side, 10.0)
	target.add_theme_stylebox_override("panel", panel_style)
	managed_panels.append(target)
	_touch_targets(target)
	target.hide()

func _touch_targets(node: Node) -> void:
	if node is BaseButton: node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 44)
	for child: Node in node.get_children(): _touch_targets(child)

func _layout_menus() -> void:
	if not is_instance_valid(toolbar): return
	var viewport_size := get_viewport().get_visible_rect().size
	toolbar.columns = 7
	menu_scroll.position = Vector2(230, 12)
	menu_scroll.size = Vector2(viewport_size.x - 258, 60)
	toolbar.custom_minimum_size.y = 44
	title_label.position = Vector2(42, 20)
	var tray_top: float = resource_bar.position.y + resource_bar.size.y + 8.0
	var top: float = tray_top + 146.0
	if is_instance_valid(ship_tray):
		ship_tray.position = Vector2(28, tray_top)
		ship_tray.size = Vector2(viewport_size.x - 56, 94)
		station_view_button.position = Vector2(viewport_size.x - 172, tray_top + 96)
		station_view_button.size = Vector2(144, 44)
	region_navigation.location_label.position = Vector2(40, tray_top + 108)
	region_navigation.location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbit_label.hide() # Replaced by the always-visible location indicator and Regions details.
	for target: PanelContainer in managed_panels:
		var width: float = minf(380 if target == panel or target == ship_context or target == settings_panel or target == menu_panel else 820, viewport_size.x - 56)
		target.position = Vector2(viewport_size.x - width - 28, top)
		var height: float = maxf(100, viewport_size.y - top - 100)
		target.size = Vector2(width, minf(height, 220) if target == menu_panel else (minf(height, 360) if target == ship_context else height))

func close_panels() -> void:
	if is_instance_valid(dev_panel): dev_panel.hide()
	for target: PanelContainer in managed_panels:
		if is_instance_valid(target): target.hide()
	active_menu = ""
	for button: Button in menu_buttons.values(): button.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))

func activate_panel(target: PanelContainer, menu: String) -> void:
	close_panels()
	choose("")
	active_menu = menu
	for readout: Control in [count_label, goal_bar, goal_label]: readout.visible = menu != "Ships"
	if target == panel: target.get_node("MenuFrame").get_child(0).get_child(0).text = menu
	if menu_buttons.has(menu): menu_buttons[menu].add_theme_stylebox_override("normal", _style(Color("25404b"), CYAN))
	target.show()
	_touch_targets(target)
	_layout_menus()

func open_menu(menu: String) -> void:
	if active_menu == menu and managed_panels.any(func(target: PanelContainer) -> bool: return target.visible):
		close_panels()
		return
	match menu:
		"Build", "Ships":
			activate_panel(panel, menu)
			tabs.current_tab = 0 if menu == "Build" else 1
		"Menu": activate_panel(menu_panel, "Menu")
		"Settings": activate_panel(settings_panel, "Menu")
		"Research": research_panel.open_panel()
		"Gate/Travel": gate_panel.open_panel()
		"Outposts/Regions": region_navigation.open_region(fleet.regions.current_region)
		"Trade/Contacts": trade_panel.open_contacts()

func _input(event: InputEvent) -> void:
	if DevConfig.DEBUG_MODE and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		dev_panel.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if has_open_panel():
			close_panels()
		else:
			deselect_ship()
		choose("")
		get_viewport().set_input_as_handled()

func _setup_ship_tray() -> void:
	ship_tray = ScrollContainer.new()
	ship_tray.name = "OwnedShipTray"
	ship_tray.mouse_filter = Control.MOUSE_FILTER_PASS
	ship_tray.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(ship_tray)
	tray_rows = HBoxContainer.new()
	tray_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_rows.add_theme_constant_override("separation", 8)
	ship_tray.add_child(tray_rows)
	empty_tray = _label(tray_rows, "No ships yet. Open Ships to buy your first ship.", 14, MUTED)
	empty_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_context = PanelContainer.new()
	ship_context.name = "SelectedShipCommands"
	ship_context.add_theme_stylebox_override("panel", _style(Color("111c2b"), CYAN))
	root.add_child(ship_context)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	ship_context.add_child(body)
	context_title = _label(body, "", 18, CYAN)
	context_detail = _label(body, "", 13, MUTED)
	context_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_rows.reparent(body)
	context_gate = Button.new()
	context_gate.text = "Gate / Travel…"
	context_gate.pressed.connect(_selected_ship_gate)
	body.add_child(context_gate)
	_wrap_panel(ship_context, "Ship commands")
	station_view_button = Button.new()
	station_view_button.text = "Reset view"
	station_view_button.tooltip_text = "Reset the camera in this region. Ship locations do not change."
	station_view_button.pressed.connect(func() -> void: get_parent().ship_camera.reset_view())
	root.add_child(station_view_button)
	_layout_menus()

func _refresh_tray() -> void:
	if not is_instance_valid(tray_rows): return
	empty_tray.visible = model.ships.is_empty()
	for id: int in ship_tiles.keys():
		if not model.ships.has(id):
			ship_tiles[id].queue_free()
			ship_tiles.erase(id)
	if selected_ship_id > 0 and not model.ships.has(selected_ship_id):
		selected_ship_id = -1
		if ship_context.visible: close_panels()
	for id: int in model.ships:
		var definition: Dictionary = model.ship_catalog[model.ships[id]]
		if not ship_tiles.has(id):
			var tile = preload("res://scripts/ship_tile.gd").new()
			tile.art = definition.get("art", "scout")
			tile.role = "%s #%d" % [definition.name.replace(" Ship", ""), id]
			tile.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))
			tile.pressed.connect(func() -> void: select_ship(id))
			tray_rows.add_child(tile)
			ship_tiles[id] = tile
		var status: String = "Working" if fleet.unit_busy(id) else ("Parked" if fleet.docking.status(id) == "parked" else "Idle · no dock")
		if fleet.collection.jobs.has(id): status = str(fleet.collection.jobs[id].status)
		if fleet.transport.jobs.has(id): status = "In transit"
		var tile = ship_tiles[id]
		tile.status = status
		tile.selected_ship = id == selected_ship_id
		tile.tooltip_text = "%s #%d · %s · %s" % [definition.name, id, fleet.regions.catalog[fleet.transport.location(id)].name, status]
		tile.queue_redraw()
		if id == selected_ship_id:
			context_title.text = "%s #%d" % [definition.name, id]
			context_detail.text = "%s · %s" % [fleet.regions.catalog[fleet.transport.location(id)].name, status]
			if fleet.transport.jobs.has(id): context_detail.text += " → " + str(fleet.regions.catalog[fleet.transport.jobs[id].destination].name)

func deselect_ship() -> void:
	selected_ship_id = -1
	get_parent().asteroids.selected_ship = -1
	# Release visual following at the current camera position; jobs are untouched.
	get_parent().ship_camera.ship_id = -1
	_refresh_ships()

func select_ship(id: int) -> void:
	if not model.ships.has(id): return
	var region: String = fleet.transport.location(id)
	# Viewing a discovered region is the existing presentation-location command.
	var error: String = fleet.regions.set_location(region)
	if not error.is_empty():
		message(error, true)
		return
	selected_ship_id = id
	activate_panel(ship_context, "Ship")
	get_parent().ship_camera.focus_ship(id)
	_refresh_ships()

func _selected_ship_gate() -> void:
	if not model.ships.has(selected_ship_id): return
	gate_panel.open_panel()
	for index in range(gate_panel.ship_picker.item_count):
		if gate_panel.ship_picker.get_item_id(index) == selected_ship_id:
			gate_panel.ship_picker.select(index)
	gate_panel.refresh()

func _setup_grid_controls() -> void:
	grid_controls = HBoxContainer.new()
	grid_controls.name = "GridViewControls"
	grid_controls.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	footer.add_child(row)
	status_label.reparent(row)
	row.add_child(grid_controls)
	row.move_child(grid_controls, 0)
	grid_controls.custom_minimum_size.x = 210
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_balance = Control.new()
	footer_balance.custom_minimum_size.x = 210
	footer_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(footer_balance)
	for caption: String in ["Fit grid", "−", "+"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(48, 44)
		button.tooltip_text = "Change the view only; station positions stay fixed."
		button.pressed.connect(_grid_action.bind(caption))
		grid_controls.add_child(button)
		grid_buttons[caption] = button
	get_viewport().size_changed.connect(_layout_grid_controls)
	_layout_grid_controls()
	grid_controls.visible = get_parent().preferences.values.show_grid_controls
	footer_balance.visible = grid_controls.visible

func _layout_grid_controls() -> void:
	grid_controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _grid_action(caption: String) -> void:
	var camera: Camera2D = get_parent().ship_camera
	match caption:
		"Fit grid": camera.fit_grid()
		"−": camera.zoom_view(1.0 / 1.25)
		"+": camera.zoom_view(1.25)

func _setup_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "Settings"
	root.add_child(settings_panel)
	var body := VBoxContainer.new()
	settings_panel.add_child(body)
	for option: Dictionary in get_parent().preferences.definitions.options:
		if option.type != "bool": continue
		var toggle := CheckButton.new()
		toggle.text = option.label
		toggle.button_pressed = get_parent().preferences.values[option.id]
		toggle.toggled.connect(func(value: bool) -> void:
			if get_parent().preferences.set_value(option.id, value) != OK:
				message("Could not save local settings."))
		body.add_child(toggle)
		settings_toggles[option.id] = toggle
	_label(body, "Drag the field or use W/A/S/D to pan.", 14, MUTED)
	_wrap_panel(settings_panel, "Settings")

func has_open_panel() -> bool:
	return managed_panels.any(func(item: PanelContainer) -> bool: return item.visible) or (is_instance_valid(dev_panel) and dev_panel.visible)

func pointer_over_ui(point: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO, viewport_size).has_point(point): return true
	if Rect2(28, 8, viewport_size.x - 56, 68).has_point(point): return true
	var controls: Array[Control] = [resource_bar, ship_tray, station_view_button, region_navigation.location_label, footer]
	for target: PanelContainer in managed_panels: controls.append(target)
	if is_instance_valid(dev_panel): controls.append(dev_panel)
	for control: Control in controls:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	var hovered := get_viewport().gui_get_hovered_control()
	return is_instance_valid(hovered) and hovered != root and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _setup_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.name = "MainMenu"
	root.add_child(menu_panel)
	var body := VBoxContainer.new()
	menu_panel.add_child(body)
	var old_row := save_button.get_parent()
	save_button.reparent(body)
	load_button.reparent(body)
	old_row.queue_free()
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.theme = save_button.theme
	settings_button.add_theme_font_size_override("font_size", save_button.get_theme_font_size("font_size"))
	settings_button.add_theme_color_override("font_color", save_button.get_theme_color("font_color"))
	for style: String in ["normal", "hover"]:
		settings_button.add_theme_stylebox_override(style, save_button.get_theme_stylebox(style))
		load_button.add_theme_stylebox_override(style, save_button.get_theme_stylebox(style))
	settings_button.pressed.connect(func() -> void: open_menu("Settings"))
	body.add_child(settings_button)
	_wrap_panel(menu_panel, "Menu")
