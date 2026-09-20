extends CanvasLayer
const SectorMap = preload("res://scripts/sector_map.gd")
var sector_map: PanelContainer
var map_button: Button
const Fleet = preload("res://scripts/mining_fleet.gd")
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
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 28
	header.offset_top = 24
	header.offset_right = -28
	header.offset_bottom = 108
	header.add_theme_stylebox_override("panel", _style(Color("111d2c"), Color("253647")))
	root.add_child(header)
	var header_margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		header_margin.add_theme_constant_override("margin_" + side, 24)
	header.add_child(header_margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	header_margin.add_child(row)
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branding.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(branding)
	_label(branding, "O R B I T A L", 28, INK)
	_label(branding, "LOW EARTH ORBIT  /  COLONY PROGRAM", 11, MUTED)
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
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -332
	panel.offset_right = -28
	panel.offset_top = 124
	panel.add_theme_stylebox_override("panel", _style(Color("111c2b"), Color("2a3b4b")))
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
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
	var module_page := VBoxContainer.new()
	module_page.name = "Modules"
	module_page.add_theme_constant_override("separation", 4)
	tabs.add_child(module_page)
	var instruction := _label(module_page, "Choose a module, then a green cell.", 12, MUTED)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for kind: String in model.catalog:
		var definition: Dictionary = model.catalog[kind]
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
	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "Inspect / cancel command"
	cancel.custom_minimum_size.y = 34
	cancel.add_theme_stylebox_override("normal", _style(Color("111c2b"), Color("314254")))
	cancel.add_theme_stylebox_override("hover", _style(Color("20374a"), CYAN))
	cancel.pressed.connect(func() -> void: choose(""))
	column.add_child(cancel)
	fleet_label = _label(column, "", 12, Color("baa1f5"))
	refinery_label = _label(column, "", 12, GOLD)
	level_label = _label(column, "", 20, INK)
	count_label = _label(column, "", 12, MUTED)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size.y = 6
	goal_bar.add_theme_stylebox_override("background", _style(Color("283848"), Color("283848"), 2))
	goal_bar.add_theme_stylebox_override("fill", _style(CYAN, CYAN, 2))
	column.add_child(goal_bar)
	goal_label = _label(column, "", 13, CYAN)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -68
	footer.offset_bottom = -24
	footer.add_theme_stylebox_override("panel", _style(Color("101c2a"), Color("2b3a4a")))
	root.add_child(footer)
	status_label = _label(footer, "", 14, INK)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var orbit_label := _label(root, "EARTH  /  408 KM\nA small beginning. An infinite horizon.", 13, Color("6894aa"))
	orbit_label.position = Vector2(42, 0)
	orbit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	orbit_label.position = Vector2(42, get_viewport().get_visible_rect().size.y - 124)
	sector_map = SectorMap.new()
	sector_map.hud = self
	sector_map.fleet = fleet
	root.add_child(sector_map)
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
	selected = kind
	for id: String in tool_buttons:
		tool_buttons[id].add_theme_stylebox_override("normal", _style(Color("1f3a3c") if id == selected else Color("172738"), CYAN if id == selected else Color("304557")))
	tool_selected.emit(kind)
	message("Click amber debris for Materials or violet asteroids to send a ship." if kind.is_empty() else "%s selected. Click a green cell beside the station." % model.catalog[kind].name)

func refresh() -> void:
	minerals_label.text = str(model.minerals)
	fleet_label.text = "MINERS  %d idle / %d total" % [fleet.idle_count(), fleet.mining_units().size()]
	var refinery_count: int = model.module_count_with("conversion")
	refinery_label.text = "REFINERIES  %d · %s" % [refinery_count, _refinery_status()]
	materials_label.text = "%d / %d" % [model.materials, model.capacity]
	power_label.text = "+%d POWER" % model.power_balance()
	power_detail.text = "%d generated  /  %d used" % [model.power_output, model.power_use]
	level_label.text = "Level %02d  ·  %s" % [model.level, "Outpost" if model.level == 1 else ("Settlement" if model.level == 2 else "Colony")]
	count_label.text = "%02d modules connected" % model.modules.size()
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
	title.position = Vector2(150, 160)
	floating.append({"label": title, "time": 0.0, "duration": 4.0})

func show_salvage(amount: int, point: Vector2) -> void:
	var label := _label(root, "+%d MATERIALS" % amount, 16, GOLD)
	label.position = point + Vector2(-35, -30)
	floating.append({"label": label, "time": 0.0, "duration": 1.2})

func _process(delta: float) -> void:
	status_time -= delta
	if status_time <= 0:
		status_label.text = "Amber: salvage  ·  Violet: mine  ·  Inspect a module to upgrade  ·  Ships tab: fleet commands"
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
	label.position = Vector2(clampf(point.x - 40, 32, 800), point.y + 22)
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
	for kind: String in model.ship_catalog:
		var definition: Dictionary = model.ship_catalog[kind]
		var button: Button = _catalog_button(page, definition)
		ship_buttons[kind] = button
		button.pressed.connect(func() -> void: _buy_ship(kind))
	sector_label = _label(page, "", 12, Color("8bcdf1"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 135)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	ship_rows = VBoxContainer.new()
	ship_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ship_rows)
	var hint := _label(page, "Assign a Miner to ore. Open Sector map to choose a Scout destination.", 11, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _buy_ship(kind: String) -> void:
	var error: String = model.buy_ship(kind)
	if not error.is_empty():
		message(error, true)
		return
	choose("")
	message("%s #%d ready. Use its command below." % [model.ship_catalog[kind].name, model.next_ship_id])

func _refresh_ships() -> void:
	sector_label.text = "SECTORS  %d / %d revealed" % [fleet.revealed_count(), fleet.sectors.size()]
	for ship_id: int in model.ships:
		var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
		if not command_buttons.has(ship_id):
			var button := Button.new()
			button.custom_minimum_size.y = 39
			button.add_theme_font_size_override("font_size", 12)
			button.add_theme_color_override("font_disabled_color", Color("b9a6f5"))
			button.add_theme_stylebox_override("disabled", _style(Color("172738"), Color("304557")))
			button.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))
			button.add_theme_stylebox_override("hover", _style(Color("20374a"), CYAN))
			button.pressed.connect(func() -> void: _command_ship(ship_id))
			ship_rows.add_child(button)
			command_buttons[ship_id] = button
		var command: String = "Assign asteroid" if definition.has("mining") else "Survey sector"
		if fleet.jobs.has(ship_id):
			var target: int = fleet.jobs[ship_id].target
			command = "Mining · %ds" % fleet.jobs[ship_id].remaining if target < 0 else "Mining #%d · %ds" % [target, fleet.jobs[ship_id].remaining]
		elif fleet.survey_jobs.has(ship_id):
			command = "Surveying · %ds" % fleet.survey_jobs[ship_id].remaining
		command_buttons[ship_id].text = "%s #%d · %s" % [definition.name, ship_id, command]
		command_buttons[ship_id].disabled = fleet.jobs.has(ship_id) or fleet.survey_jobs.has(ship_id)

func _command_ship(ship_id: int) -> void:
	choose("")
	var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
	if definition.has("mining"):
		ship_assignment_requested.emit(ship_id)
		message("Miner #%d selected. Click a violet asteroid; mining repeats until depleted." % ship_id, false, 8.0)
	else:
		var error: String = fleet.survey(ship_id)
		message("Scout exploring the next sector. Open Sector map to view its destination." if error.is_empty() else error, not error.is_empty())

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
	var hint := _label(page, "Inspect mode: click any station module to see its tier and available upgrade.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func inspect_module(world_position: Vector2) -> void:
	choose("")
	selected_position = world_position
	tabs.current_tab = 2
	_refresh_upgrade()

func _refresh_upgrade() -> void:
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
	if definition.has("conversion"):
		upgrade_stats.text += "\n%d Minerals → %d Materials / %ds" % [definition.conversion.input, definition.conversion.output, definition.conversion.seconds]
	var next: Dictionary = model.next_upgrade(selected_position)
	if next.is_empty():
		upgrade_detail.text = "This module is at its maximum available tier."
		upgrade_button.text = "Maximum tier"
		upgrade_button.disabled = true
		return
	upgrade_detail.text = "NEXT TIER\n" + str(next.description)
	upgrade_button.text = "Upgrade to T%d · %d M + %d Minerals" % [model.tier_at(selected_position) + 1, next.cost.materials, next.cost.minerals]
	var error: String = model.upgrade_error(selected_position)
	upgrade_button.disabled = not error.is_empty()
	upgrade_button.tooltip_text = error

func _upgrade_selected() -> void:
	var error: String = model.upgrade_module(selected_position)
	message("Module upgraded to Tier %d." % model.tier_at(selected_position) if error.is_empty() else error, not error.is_empty())
