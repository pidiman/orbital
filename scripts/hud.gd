extends CanvasLayer
const DevConfig = preload("res://scripts/dev_config.gd")
var build_model: StationModel:
	get: return get_parent().board.model
var dev_panel: PanelContainer
const RegionNavigation = preload("res://scripts/region_navigation.gd")
var region_navigation: Control
var orbit_label: Label
const TradePanel = preload("res://scripts/trade_panel.gd")
var trade_panel: PanelContainer
var research_panel: PanelContainer
var research_button: Button
var gate_panel: PanelContainer
var cargo_route_panel: PanelContainer
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
var hauling_assignment: int = -1
var context_gate: Button
var station_view_button: Button
var zoom_label: Label
var grid_controls_panel: PanelContainer
var grid_controls: HBoxContainer
var grid_buttons: Dictionary = {}
var menu_buttons: Dictionary = {}
var demolish_top_button: Button
var menu_panel: PanelContainer
var settings_button: Button
var footer_balance: Control
var settings_panel: PanelContainer
var settings_toggles: Dictionary = {}
var settings_numbers: Dictionary = {}
var managed_panels: Array[PanelContainer] = []
var panel_closes: Dictionary = {}
var active_menu: String = ""
var footer: PanelContainer
var capability_buttons: Dictionary = {}
const SHIP_ACTIONS: Dictionary = {"hauling": "Assign refinery", "mining": "Start auto miner", "survey": "Explore regions", "trade": "Trade with contact", "collection": "Deploy locally", "founding": "Found outpost", "gate_building": "Build Teleport Gate", "cargo_shuttle": "Assign shuttle route"}
const Fleet = preload("res://scripts/mining_fleet.gd")
signal new_game_requested
signal save_requested
signal load_requested
var save_button: Button
var load_button: Button
signal tool_selected(kind: String)
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
var fps_label: Label
var fps_refresh_remaining: float = 0.0
var fps_visibility_state: int = -1
var goal_bar: ProgressBar
var tabs: TabContainer
var ship_buttons: Dictionary = {}
var command_buttons: Dictionary = {}
var sell_buttons: Dictionary = {}
var ship_entries: Dictionary = {}
var ship_tier_labels: Dictionary = {}
var ship_upgrade_buttons: Dictionary = {}
var demolish_button: Button
var ship_rows: VBoxContainer
var upgrade_title: Label
var upgrade_stats: Label
var upgrade_detail: Label
var refinery_selector: OptionButton
var refinery_run_button: Button
var upgrade_button: Button
var selected_position: Vector2 = Vector2(99, 99)
var tool_buttons: Dictionary = {}
var selected: String = ""
var status_time: float = 0.0
var refresh_pending: bool = false
var floating: Array[Dictionary] = []
var compact_resources: HBoxContainer
var resource_bar: PanelContainer
var resource_status: HFlowContainer
var status_row: HBoxContainer
var top_bar: PanelContainer
var top_bar_content: Control
var status_capsule: PanelContainer
var miner_segment: PanelContainer
var refinery_segment: PanelContainer
var module_segment: PanelContainer
var miner_alert: Label
var refinery_alert: Label
var module_alert: Label
var colony_group: HBoxContainer
var colony_percent: Label
var panel_fit_pending: bool = false
var panel: PanelContainer
var root: Control
const INK := Color("dfebf2")
const MUTED := Color("7e95a9")
const CYAN := Color("72dbcb")
const GOLD := Color("eebd76")

class StatusArt extends Control:
	var art_kind: String = "mining_ship"
	var tint: Color = Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(13, 13)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		ModuleArt.draw_module(self, Vector2(6.5, 6.5), art_kind, 0.30)

func _status_art(kind: String, tint: Color) -> StatusArt:
	var icon := StatusArt.new()
	icon.art_kind = kind
	icon.tint = tint
	icon.modulate = tint
	return icon

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
	fps_label = _label(root, "FPS --", 11, MUTED)
	fps_label.name = "FPSCounter"
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -82
	fps_label.offset_right = -12
	fps_label.offset_top = 104
	fps_label.offset_bottom = 122
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.z_index = 100
	fps_label.add_theme_color_override("font_outline_color", Color("09121c", 0.95))
	fps_label.add_theme_constant_override("outline_size", 3)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("FPS counter initialized at %s; Show FPS=%s" % [str(fps_label.get_path()), str(get_parent().preferences.values.get("show_fps", true))])
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
	# Let the panel derive its height from content; _layout_menus() applies the
	# viewport cap only when a catalog is genuinely long.
	tabs.custom_minimum_size = Vector2(272, 0)
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
	module_scroll.custom_minimum_size.y = 0
	module_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	research_button = Button.new()
	research_button.text = "Research"
	research_button.custom_minimum_size.y = 34
	research_button.pressed.connect(func() -> void: research_panel.open_panel())
	column.add_child(research_button)
	# Module inspection is entered through the existing map interaction; keep
	# the popup focused on its details and actions.
	fleet_label = _status_indicator(resource_status, 5, Color("baa1f5"))
	refinery_label = _status_indicator(resource_status, 6, GOLD)
	level_label = _status_indicator(resource_status, 7, INK)
	count_label = _status_indicator(resource_status, 8, MUTED)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(110, 5)
	goal_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_bar.tooltip_text = "Colony growth"
	goal_bar.add_theme_stylebox_override("background", _style(Color("283848"), Color("283848"), 2))
	goal_bar.add_theme_stylebox_override("fill", _style(CYAN, CYAN, 2))
	resource_status.add_child(goal_bar)
	footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -44
	footer.offset_bottom = -14
	footer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(footer)
	status_label = _label(footer, "", 14, INK)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_footer_text_style(status_label)
	orbit_label = _label(root, "EARTH  /  408 KM\nA small beginning. An infinite horizon.", 13, Color("6894aa"))
	orbit_label.position = Vector2(42, 0)
	orbit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	orbit_label.position = Vector2(42, get_viewport().get_visible_rect().size.y - 124)
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
	cargo_route_panel = preload("res://scripts/cargo_route_panel.gd").new()
	cargo_route_panel.hud = self
	cargo_route_panel.fleet = fleet
	root.add_child(cargo_route_panel)
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
	# Coalesce the many model/fleet signals emitted by one simulation tick. The
	# previous direct connections refreshed the entire HUD synchronously for each
	# signal, creating periodic frame-time spikes.
	model.changed.connect(_queue_refresh)
	fleet.changed.connect(_queue_refresh)
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

func _status_indicator(parent: Node, icon_kind: int, tint: Color) -> Label:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 3)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(group)
	var icon = preload("res://scripts/resource_icon.gd").new()
	icon.kind = icon_kind
	icon.tint = tint
	group.add_child(icon)
	var label := _label(group, "", 12, tint)
	return label

func _status_segment(parent: HBoxContainer, icon_kind: Variant, tint: Color, segment_name: String, widest_text: String) -> PanelContainer:
	if parent.get_child_count() > 0:
		var divider := ColorRect.new()
		divider.custom_minimum_size = Vector2(1, 14)
		divider.color = Color("304353")
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(divider)
	var segment := PanelContainer.new()
	segment.name = segment_name
	segment.custom_minimum_size = Vector2(_status_segment_width(widest_text), 20)
	segment.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	segment.mouse_filter = Control.MOUSE_FILTER_STOP
	segment.add_theme_stylebox_override("panel", _segment_style(Color("101b29"), segment_name))
	parent.add_child(segment)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.alignment = BoxContainer.ALIGNMENT_BEGIN
	inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_child(inner)
	var icon: Control
	if icon_kind is String:
		icon = _status_art(str(icon_kind), tint)
	else:
		icon = preload("res://scripts/resource_icon.gd").new()
		icon.kind = int(icon_kind)
		icon.tint = tint
		icon.custom_minimum_size = Vector2(13, 13)
		icon.scale = Vector2(0.93, 0.93)
	inner.add_child(icon)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.custom_minimum_size.x = _status_body_width(widest_text)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(body)
	return segment

func _status_body_width(widest_text: String) -> float:
	var font := ThemeDB.fallback_font
	return ceilf(font.get_string_size(widest_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)

func _status_segment_width(widest_text: String) -> float:
	var body_width := _status_body_width(widest_text)
	var font := ThemeDB.fallback_font
	var alert_width := font.get_string_size("Ⅱ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	return ceilf(8.0 + 13.0 + 4.0 + body_width + 4.0 + alert_width + 8.0)

func _segment_alert(segment: PanelContainer) -> Label:
	var glyph := _label(segment, "", 11, Color("f5c36c"))
	glyph.name = "Alert"
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.hide()
	var inner: HBoxContainer = segment.get_child(0)
	glyph.reparent(inner)
	return glyph

func _status_body(segment: PanelContainer) -> HBoxContainer:
	var inner: HBoxContainer = segment.get_child(0)
	return inner.get_node("Body") as HBoxContainer

func _segment_style(fill: Color, segment_name: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	if segment_name == "Miners":
		style.corner_radius_top_left = 10
		style.corner_radius_bottom_left = 10
	elif segment_name == "Modules":
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_right = 10
	return style

func _set_status_segment(segment: PanelContainer, alert: Label, state: String, glyph: String) -> void:
	var fill := Color("101b29")
	var tint := Color("baa1f5") if segment.name == "Miners" else (GOLD if segment.name == "Refineries" else Color("9aa9b5"))
	if state == "warning":
		fill = Color("2a1f10")
		tint = Color("f0bf64")
	elif state == "damaged":
		fill = Color("2a1212")
		tint = Color("ed8b84")
	alert.add_theme_color_override("font_color", tint)
	var inner: HBoxContainer = segment.get_child(0)
	var icon = inner.get_child(0)
	icon.tint = tint
	if icon is StatusArt: icon.modulate = tint
	icon.queue_redraw()
	var body: HBoxContainer = inner.get_node("Body") as HBoxContainer
	for child: Node in body.get_children():
		if child is Label: child.add_theme_color_override("font_color", tint)
	segment.add_theme_stylebox_override("panel", _segment_style(fill, segment.name))
	alert.text = glyph
	alert.visible = not glyph.is_empty()

func _update_status_indicators() -> void:
	var units: Dictionary = fleet.mining_units()
	var total_miners := units.size()
	var idle_miners := fleet.idle_count()
	var working_miners := maxi(0, total_miners - idle_miners)
	fleet_label.text = "%d/%d" % [working_miners, total_miners]
	var miners_warning := total_miners > 0 and working_miners == 0
	_set_status_segment(miner_segment, miner_alert, "warning" if miners_warning else "", "Ⅱ" if miners_warning else "")
	fleet_label.tooltip_text = "Miners: %d working of %d total%s" % [working_miners, total_miners, " · all idle" if miners_warning else ""]
	miner_segment.tooltip_text = fleet_label.tooltip_text

	var refinery_count := 0
	var running_count := 0
	var buffer_full_count := 0
	var paused_count := 0
	var refinery_details: Array[String] = []
	for world_position: Vector2 in model.modules:
		if not model.definition_at(world_position).has("conversion"): continue
		refinery_count += 1
		var reason := model.refinery_pause_reason(world_position)
		if reason.is_empty():
			running_count += 1
		else:
			paused_count += 1
			if reason.to_lower().contains("buffer"):
				buffer_full_count += 1
			refinery_details.append("Refinery #%d: %s" % [refinery_count, reason])
	var refinery_text := "none" if refinery_count == 0 else ("%d running" % running_count if buffer_full_count == 0 and paused_count == 0 else ("%d buffer full" % buffer_full_count if buffer_full_count > 0 else "%d paused" % paused_count))
	refinery_label.text = refinery_text
	var refinery_warning := paused_count > 0
	_set_status_segment(refinery_segment, refinery_alert, "warning" if refinery_warning else "", "Ⅱ" if refinery_warning else "")
	refinery_label.tooltip_text = "No refineries" if refinery_count == 0 else "; ".join(refinery_details) if not refinery_details.is_empty() else "%d refineries running" % running_count
	refinery_segment.tooltip_text = refinery_label.tooltip_text

	var connected_count := 0
	var damaged_count := 0
	var disconnected_count := 0
	for world_position: Vector2 in model.modules:
		if model.is_module_damaged(world_position): damaged_count += 1
		if bool(model.connected_modules.get(world_position, false)): connected_count += 1
		else: disconnected_count += 1
	count_label.text = "%d" % connected_count
	var module_state := "damaged" if damaged_count > 0 else ("warning" if disconnected_count > 0 else "")
	_set_status_segment(module_segment, module_alert, module_state, "!" if damaged_count > 0 else ("•" if disconnected_count > 0 else ""))
	count_label.tooltip_text = "Modules: %d connected" % connected_count
	if disconnected_count > 0: count_label.tooltip_text += " · %d disconnected" % disconnected_count
	if damaged_count > 0: count_label.tooltip_text += " · %d damaged" % damaged_count
	module_segment.tooltip_text = count_label.tooltip_text

	var module_count := model.modules.size()
	var level_start := maxi(1, (model.level - 1) * 4 + 1)
	var next_level := level_start + 4
	var progress_percent := 100 if model.level <= 0 else clampi(int(round(float(module_count - level_start) / float(maxi(1, next_level - level_start)) * 100.0)), 0, 99)
	colony_percent.text = "%d%%" % progress_percent
	goal_bar.max_value = 100
	goal_bar.value = progress_percent
	level_label.tooltip_text = "Colony Lv %d · %d%% to Lv %d" % [model.level, progress_percent, model.level + 1]
	colony_group.tooltip_text = level_label.tooltip_text

func _style(fill: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func choose(kind: String) -> void:
	hauling_assignment = -1
	if not kind.is_empty() and not get_parent().board.visible:
		message("Jump Home to construct station modules.", true)
		return
	if not kind.is_empty(): close_panels()
	selected = kind
	for id: String in tool_buttons:
		tool_buttons[id].add_theme_stylebox_override("normal", _style(Color("1f3a3c") if id == selected else Color("172738"), CYAN if id == selected else Color("304557")))
	tool_selected.emit(kind)
	_refresh_demolish_button()
	if kind == "__demolish__":
		message("Demolish mode active. Click a placed module to remove it.", true)
	elif kind.is_empty():
		message("Click labeled floating resources to collect; start Miners from their ship commands.")
	else:
		message("%s selected. Click a green cell beside the station." % model.catalog[kind].name)

func toggle_demolish_mode() -> void:
	choose("" if selected == "__demolish__" else "__demolish__")

func _refresh_demolish_button() -> void:
	if not is_instance_valid(demolish_top_button): return
	var active: bool = selected == "__demolish__"
	demolish_top_button.add_theme_stylebox_override("normal", _style(Color("25404b") if active else Color("172738"), CYAN if active else Color("304557")))
	demolish_top_button.add_theme_stylebox_override("hover", _style(Color("315463") if active else Color("25404b"), CYAN))

func refresh() -> void:
	build_model.recalculate()
	var home: bool = fleet.regions.primary_station_visible()
	for kind: String in tool_buttons:
		tool_buttons[kind].visible = model.module_unlocked(kind) and (home or (not build_model.station_id.is_empty() and model.locations.outpost_catalog[model.locations.stations[build_model.station_id].kind].buildable_modules.has(kind)))
		tool_buttons[kind].disabled = not get_parent().board.visible
	orbit_label.text = "EARTH  /  408 KM\nA small beginning. An infinite horizon." if home else "%s / EXPLORATION\n%s" % [str(fleet.regions.catalog[fleet.regions.current_region].name).to_upper(), fleet.outposts.short_summary(fleet.regions.current_region)]
	tech_label.text = "%s" % fleet.diplomacy.inventory.get("tech", 0)
	xenocrystal_label.text = "%s" % (fleet.diplomacy.inventory.get("xenocrystal", 0) if build_model.station_id.is_empty() else model.locations.stations[build_model.station_id].inventory.get("xenocrystal", 0))
	minerals_label.text = "%d" % build_model.minerals
	_update_status_indicators()
	materials_label.text = "%d" % build_model.materials
	materials_label.tooltip_text = "Materials: %d / %d capacity" % [build_model.materials, build_model.capacity]
	power_label.text = "%+d" % build_model.power_balance()
	power_label.tooltip_text = "Power: %d generated / %d used" % [build_model.power_output, build_model.power_use]
	power_detail.text = "%d generated  /  %d used" % [build_model.power_output, build_model.power_use]
	level_label.text = "Lv %02d" % model.level
	_refresh_ships()
	_refresh_upgrade()
	if is_instance_valid(gate_panel) and gate_panel.visible: gate_panel.refresh()
	if is_instance_valid(research_panel) and research_panel.visible: research_panel.refresh()
	if is_instance_valid(trade_panel) and trade_panel.visible: trade_panel.refresh()
	if is_instance_valid(region_navigation) and region_navigation.visible: region_navigation.refresh()

func _queue_refresh() -> void:
	refresh_pending = true

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
	if refresh_pending:
		refresh_pending = false
		refresh()
	status_label.tooltip_text = status_label.text
	fps_refresh_remaining -= delta
	if fps_refresh_remaining <= 0.0:
		fps_refresh_remaining = 0.25
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	if is_instance_valid(fps_label):
		var show_fps: bool = bool(get_parent().preferences.values.get("show_fps", true))
		fps_label.visible = show_fps
		if fps_visibility_state != int(show_fps):
			fps_visibility_state = int(show_fps)
			print("FPS counter visibility set to %s (Show FPS preference)" % str(show_fps))
	if is_instance_valid(zoom_label):
		zoom_label.text = ("%.2f" % get_parent().ship_camera.zoom.x).trim_suffix("0") + "x"
	if is_instance_valid(grid_controls):
		grid_controls.visible = get_parent().preferences.values.show_grid_controls
		grid_controls_panel.visible = grid_controls.visible
		footer_balance.visible = grid_controls.visible
	status_time -= delta
	if status_time <= 0:
		status_label.text = "Labeled pickups: salvage  ·  Miners: automatic  ·  Inspect a module to upgrade  ·  Ships: fleet commands" if fleet.regions.primary_station_visible() else "Labeled pickups: salvage  ·  Miners: automatic  ·  Outposts/Regions: Scout / view region  ·  Outpost construction uses local storage"
		if fleet.collection != null and not fleet.collection.waiting_message().is_empty():
			status_label.text = fleet.collection.waiting_message()
		if not fleet.docking.waiting_message().is_empty() and fleet.collection.waiting_message().is_empty() and fleet.hauling.waiting_message().is_empty():
			status_label.text = fleet.docking.waiting_message()
		if not fleet.hauling.waiting_message().is_empty(): status_label.text = fleet.hauling.waiting_message()
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
		return model.refinery_status(world_position)
	return "idle"

func show_minerals(amount: int, point: Vector2) -> void:
	var label := _label(root, "+%d MINERALS" % amount, 18, Color("cdb6ff"))
	var screen_point: Vector2 = get_viewport().get_canvas_transform() * point
	label.position = Vector2(clampf(screen_point.x - 40, 32, 800), screen_point.y + 22)
	floating.append({"label": label, "time": 0.0, "duration": 2.0})

func show_refining(amount: int) -> void:
	message("Refinery buffered: +%d Materials. Assign a Hauler to deliver." % amount)

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
			ship_tier_labels.erase(removed_id)
			ship_upgrade_buttons.erase(removed_id)
			sell_buttons.erase(removed_id)
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
			if definition.has("upgrades"):
				var tier_label := _label(entry, "", 12, MUTED)
				tier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				ship_tier_labels[ship_id] = tier_label
				var tier_button := Button.new()
				tier_button.custom_minimum_size.y = 42
				tier_button.add_theme_font_size_override("font_size", 12)
				tier_button.add_theme_stylebox_override("normal", _style(Color("172738"), Color("304557")))
				tier_button.add_theme_stylebox_override("hover", _style(Color("20374a"), CYAN))
				tier_button.pressed.connect(func() -> void: _upgrade_ship(ship_id))
				entry.add_child(tier_button)
				ship_upgrade_buttons[ship_id] = tier_button
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
		elif definition.has("mining") and fleet.auto_mining_enabled(ship_id):
			status = "Auto mining · seeking"
		elif fleet.regions.survey_jobs.has(ship_id):
			status = "Scouting · %ds" % fleet.regions.survey_jobs[ship_id].remaining
		elif fleet.diplomacy.jobs.has(ship_id):
			status = "Trading · %ds" % fleet.diplomacy.jobs[ship_id].remaining
		elif fleet.cargo.routes.has(ship_id):
			status = str(fleet.cargo.routes[ship_id].status)
		elif fleet.repairs.jobs.has(ship_id):
			var repair_job: Dictionary = fleet.repairs.jobs[ship_id]
			status = "Repairing · waiting" if bool(repair_job.get("waiting", false)) else ("Repairing" if str(repair_job.phase) == "repairing" else "Repair transit")
		for capability: String in capability_buttons[ship_id]:
			var button: Button = capability_buttons[ship_id][capability]
			button.text = "%s #%d · %s" % [definition.name, ship_id, status if not status.is_empty() else str(definition[capability].get("assignment_label", SHIP_ACTIONS[capability]))]
			if capability == "mining":
				button.text = "Stop auto miner" if fleet.auto_mining_enabled(ship_id) else "Start auto miner"
			var work_error: String = fleet.mining_work_error(ship_id) if capability == "mining" else fleet.transport.work_error(ship_id)
			if capability == "mining" and fleet.auto_mining_enabled(ship_id):
				# Stopping remains available even if the running Miner is currently
				# in transit or waiting for a local outpost.
				work_error = ""
			if capability == "gate_building":
				work_error = ""
				button.visible = not fleet.transport.has_gate(fleet.transport.location(ship_id))
			if capability == "founding":
				work_error = ""
				button.text = "%s #%d · Found outpost" % [definition.name, ship_id]
				button.tooltip_text = fleet.outposts.cost_text(ship_id) + "\n" + fleet.outposts.founding_error(ship_id)
			elif status.is_empty() and fleet.transport.location(ship_id) != fleet.regions.HOME:
				button.text += " · " + str(fleet.regions.catalog[fleet.transport.location(ship_id)].name)
			var mining_toggle_available: bool = capability == "mining" and (fleet.auto_mining_enabled(ship_id) or fleet.jobs.has(ship_id))
			button.disabled = ((fleet.unit_busy(ship_id) and not mining_toggle_available) or not work_error.is_empty())
			if capability == "hauling" and fleet.hauling.jobs.has(ship_id):
				button.text = "Stop hauling"
				button.disabled = false
			if capability == "cargo_shuttle" and fleet.cargo.routes.has(ship_id):
				button.text = "Cancel shuttle route"
				button.disabled = false
			if capability != "founding": button.tooltip_text = work_error
		sell_buttons[ship_id].text = "Decommission · +%d M" % model.ship_refund(ship_id)
		if ship_tier_labels.has(ship_id):
			var current_tier: int = model.ship_tier(ship_id)
			var current_definition: Dictionary = model.ship_definition(ship_id)
			var next: Dictionary = model.next_ship_upgrade(ship_id)
			ship_tier_labels[ship_id].text = "Tier %d · %s" % [current_tier, _ship_tier_effect(current_definition)]
			if next.is_empty():
				ship_upgrade_buttons[ship_id].text = "Maximum ship tier"
				ship_upgrade_buttons[ship_id].disabled = true
				ship_upgrade_buttons[ship_id].tooltip_text = "This ship is fully upgraded."
			else:
				var preview: Dictionary = current_definition.duplicate(true)
				_merge_ship_stats_for_preview(preview, next.get("stats", {}))
				var upgrade_error: String = model.ship_upgrade_error(ship_id)
				ship_tier_labels[ship_id].text += "\nNext: %s for %s" % [_ship_tier_effect(preview), model.upgrade_cost_text(next.cost)]
				if not upgrade_error.is_empty(): ship_tier_labels[ship_id].text += "\n" + upgrade_error
				ship_upgrade_buttons[ship_id].text = "Upgrade to T%d · %s" % [current_tier + 1, model.upgrade_cost_text(next.cost)]
				ship_upgrade_buttons[ship_id].disabled = not upgrade_error.is_empty()
				ship_upgrade_buttons[ship_id].tooltip_text = "Next: %s" % _ship_tier_effect(preview)

	_refresh_tray()
	# Command labels and buttons can change the selected-ship panel's natural
	# height, so update its layout after refreshing the contents.
	if is_instance_valid(ship_context) and ship_context.visible:
		_layout_menus()

func _merge_ship_stats_for_preview(target: Dictionary, patch: Dictionary) -> void:
	for key: String in patch:
		if target.get(key) is Dictionary and patch[key] is Dictionary:
			var nested: Dictionary = target[key]
			_merge_ship_stats_for_preview(nested, patch[key])
		else:
			target[key] = patch[key]

func _ship_tier_effect(definition: Dictionary) -> String:
	if definition.has("collection"):
		return "Collects %d Materials / pickup" % int(definition.collection.cargo_capacity)
	if definition.has("mining"):
		return "Mines %d %s / cycle" % [int(definition.mining.yield), str(definition.mining.get("resource", "minerals")).capitalize()]
	if definition.has("hauling"):
		return "Carries %d units / trip" % int(definition.hauling.batch_size)
	return "No tier effect"

func _upgrade_ship(ship_id: int) -> void:
	var error: String = model.upgrade_ship(ship_id)
	message("Ship upgraded to Tier %d." % model.ship_tier(ship_id) if error.is_empty() else error, not error.is_empty())

func _command_ship(ship_id: int, capability: String = "") -> void:
	choose("")
	var definition: Dictionary = model.ship_catalog[model.ships[ship_id]]
	if capability.is_empty():
		for action: String in SHIP_ACTIONS:
			if definition.has(action):
				capability = action
				break
	if capability == "hauling" and fleet.hauling.jobs.has(ship_id):
		fleet.hauling.stop(ship_id)
		message("Hauler will stop after delivering its cargo." if fleet.hauling.jobs.has(ship_id) else "Hauling stopped.")
		return
	if capability == "cargo_shuttle" and fleet.cargo.routes.has(ship_id):
		fleet.cargo.cancel(ship_id)
		message("Cargo Ship route cancelled.")
		return
	if capability == "mining":
		var auto_error: String = fleet.toggle_auto_mining(ship_id)
		message(("Auto-mining started for %s #%d." if fleet.auto_mining_enabled(ship_id) else "Auto-mining stopped; ship is returning to idle.") % [definition.name, ship_id] if auto_error.is_empty() else auto_error, not auto_error.is_empty(), 8.0)
		return
	if not definition.has(capability) or fleet.unit_busy(ship_id):
		return
	match capability:
		"gate_building":
			var region: String = fleet.transport.location(ship_id)
			var outpost: String = model.locations.outpost_at(region, model.locations.ships[ship_id].owner)
			if outpost.is_empty():
				message("Found an outpost first, then build its Teleport Gate using local Materials.", true)
				return
			var module: String = definition.gate_building.module
			if not model.module_unlocked(module):
				message("Research Teleport Gate technology first.", true)
				return
			fleet.regions.set_location(region)
			choose(module)
			message("Place the 2×2 Teleport Gate on the outpost grid. Uses local Materials and power.", false, 10.0)
		"hauling":
			close_panels()
			hauling_assignment = ship_id
			message("Click a local Refinery to assign hauling. ESC cancels selection.", false, 8.0)
		"founding":
			var error: String = fleet.outposts.found(ship_id)
			message("Outpost founded with starter Materials. Build locally; hauling to Home is not available yet." if error.is_empty() else error, not error.is_empty(), 8.0)
		"collection":
			var error: String = fleet.collection.deploy(ship_id)
			message("Material Ship deployed in its region." if error.is_empty() else error, not error.is_empty())
		"survey":
			region_navigation.open_region(fleet.regions.current_region, ship_id)
			message("Choose an adjacent undiscovered region for this Scout.")
		"trade":
			region_navigation.panel.hide()
			trade_panel.open_contacts(ship_id)
		"cargo_shuttle":
			cargo_route_panel.open_for(ship_id)

func _trade_completed(contact_id: String, offer_id: String) -> void:
	var diplomacy: RefCounted = fleet.diplomacy
	message("Trade complete with %s: %s." % [diplomacy.contacts[contact_id].name, diplomacy.reward_text(diplomacy.offers.get(offer_id, diplomacy.history.back()))], false, 8.0)

func _build_upgrade_page() -> void:
	var page := VBoxContainer.new()
	page.name = "Upgrade"
	page.custom_minimum_size.x = 272
	page.add_theme_constant_override("separation", 12)
	tabs.add_child(page)
	upgrade_title = _label(page, "", 20, CYAN)
	upgrade_stats = _label(page, "", 14, INK)
	upgrade_stats.custom_minimum_size.x = 272
	upgrade_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_detail = _label(page, "", 13, MUTED)
	upgrade_detail.custom_minimum_size.x = 272
	upgrade_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refinery_selector = OptionButton.new()
	refinery_selector.custom_minimum_size.y = 44
	refinery_selector.item_selected.connect(func(index: int) -> void:
		var error: String = model.set_refinery_recipe(selected_position, refinery_selector.get_item_metadata(index))
		if not error.is_empty(): message(error, true))
	page.add_child(refinery_selector)
	refinery_run_button = Button.new()
	refinery_run_button.custom_minimum_size.y = 44
	refinery_run_button.pressed.connect(func() -> void:
		var error: String = model.set_refinery_running(selected_position, not model.refinery_running(selected_position))
		if not error.is_empty(): message(error, true))
	page.add_child(refinery_run_button)
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

func inspect_module(world_position: Vector2) -> void:
	if hauling_assignment >= 0:
		var error: String = fleet.hauling.assign(hauling_assignment, world_position)
		message("Hauler assigned; repeats trips from this Refinery." if error.is_empty() else error, not error.is_empty())
		if error.is_empty(): hauling_assignment = -1
		return
	# Module selection replaces ship selection visually; jobs remain untouched.
	deselect_ship()
	choose("")
	selected_position = world_position
	activate_panel(panel, "Build")
	tabs.current_tab = 2
	_refresh_upgrade()
	_request_panel_fit()

func deselect_module() -> void:
	selected_position = Vector2.INF
	# StationBoard owns the actual drawn inspect frame separately from the HUD
	# selection value. Clear it explicitly and redraw so the frame disappears
	# immediately on both ESC and empty-map clicks.
	var board: Node = get_parent().board
	board.inspected_position = Vector2.INF
	board.queue_redraw()
	# Deselecting is view-only. If its detail panel is open, dismiss that panel
	# while leaving the underlying module and all of its state untouched.
	if is_instance_valid(panel) and panel.visible: close_panels()

func _refresh_upgrade() -> void:
	var is_refinery: bool = get_parent().board.visible and build_model.modules.has(selected_position) and build_model.definition_at(selected_position).has("conversion")
	refinery_selector.visible = is_refinery
	refinery_run_button.visible = is_refinery
	upgrade_title.show()
	if is_instance_valid(tabs) and tabs.current_tab == 2 and panel.has_node("MenuFrame"):
		panel.get_node("MenuFrame").get_child(0).get_child(0).text = "Build"
	if not get_parent().board.visible:
		upgrade_title.text = "Station at Earth"
		upgrade_stats.text = "Jump Home to inspect or modify modules."
		upgrade_detail.text = "This region is exploration-only."
		upgrade_button.disabled = true
		demolish_button.disabled = true
		return
	var demolition_error: String = build_model.demolition_error(selected_position)
	demolish_button.disabled = not demolition_error.is_empty()
	demolish_button.text = "Demolish · +%d M" % build_model.module_refund(selected_position)
	demolish_button.tooltip_text = demolition_error if not demolition_error.is_empty() else "Frees position and power; cancels dock missions. Remaining modules stay operational. Stock and refund are retained above capacity."
	if not build_model.modules.has(selected_position):
		upgrade_title.text = "Select a module"
		upgrade_stats.text = "Use Inspect, then click a station module."
		upgrade_detail.text = "Habitat · Solar · Storage · Refinery"
		upgrade_button.text = "Select a module to upgrade"
		upgrade_button.disabled = true
		return
	var definition: Dictionary = build_model.definition_at(selected_position)
	upgrade_title.hide() # The inspect header carries the module name and tier.
	if tabs.current_tab == 2 and panel.has_node("MenuFrame"):
		panel.get_node("MenuFrame").get_child(0).get_child(0).text = "%s · Tier %d" % [definition.name, build_model.tier_at(selected_position)]
	var current_hp: int = build_model.module_hp(selected_position)
	var maximum_hp: int = build_model.module_max_hp(selected_position)
	if current_hp < maximum_hp:
		var hp_status: String = "Damaged" if current_hp <= 0 else "Operational · damaged"
		upgrade_stats.text = "HP: %d / %d · %s\nGenerates %d Power · uses %d\nMaterial capacity bonus: %d" % [current_hp, maximum_hp, hp_status, definition.power_output, definition.power_use, definition.capacity]
	else:
		upgrade_stats.text = "Generates %d Power · uses %d\nMaterial capacity bonus: %d" % [definition.power_output, definition.power_use, definition.capacity]
	if definition.has("docking"):
		var dock_id: String = build_model.structure_id_at(selected_position)
		upgrade_stats.text += "\nParking: %d / %d ships" % [fleet.docking.usage.get(dock_id, {}).size(), int(definition.docking.capacity)]
	if definition.has("conversion"):
		var recipe: Dictionary = build_model.refinery_recipe(selected_position)
		upgrade_stats.text += "\n%d %s → %d %s / %ds\n%s" % [recipe.input, recipe.input_resource.capitalize(), recipe.output, recipe.output_resource.capitalize(), recipe.seconds, build_model.refinery_status(selected_position)]
		var buffer: Dictionary = build_model.refinery_buffer(selected_position)
		var capacity: int = int(definition.output_buffer_capacity)
		upgrade_stats.text += "\nBuffer: %d / %d · %s" % [capacity - build_model.refinery_buffer_space(selected_position), capacity, build_model.upgrade_cost_text(buffer) if not buffer.is_empty() else "empty"]
		var assigned: int = 0
		for job: Dictionary in fleet.hauling.jobs.values():
			if job.refinery_id == build_model.structure_id_at(selected_position): assigned += 1
		upgrade_stats.text += "\nHaulers assigned: %d" % assigned
		# Preserve an open popup across model/fleet refreshes; rebuild only if its choices change.
		var recipe_ids: Array = definition.recipes
		var displayed_ids: Array = []
		for index in range(refinery_selector.item_count): displayed_ids.append(refinery_selector.get_item_metadata(index))
		if displayed_ids != recipe_ids:
			refinery_selector.clear()
			for recipe_id: String in recipe_ids:
				refinery_selector.add_item(build_model.refinery_recipes[recipe_id].name)
				refinery_selector.set_item_metadata(refinery_selector.item_count - 1, recipe_id)
		refinery_selector.select(recipe_ids.find(build_model.refinery_recipe_id(selected_position)))
		refinery_run_button.text = "Stop production" if build_model.refinery_running(selected_position) else "Run production · Stopped"

	var current_tier: int = build_model.tier_at(selected_position)
	var next: Dictionary = build_model.next_upgrade(selected_position)
	if next.is_empty():
		upgrade_detail.text = "Maxed · Maximum tier reached."
		upgrade_button.text = "Maximum tier"
		upgrade_button.disabled = true
		_layout_menus()
		return
	upgrade_detail.text = "Next: %s for %s" % [next.description, build_model.upgrade_cost_text(next.cost)]
	if definition.has("conversion"):
		var next_recipe: Dictionary = build_model.refinery_recipe(selected_position, current_tier + 1)
		upgrade_detail.text = "Next: %d %s → %d %s / %ds for %s" % [next_recipe.input, next_recipe.input_resource.capitalize(), next_recipe.output, next_recipe.output_resource.capitalize(), next_recipe.seconds, build_model.upgrade_cost_text(next.cost)]
	upgrade_button.text = "Upgrade to T%d" % (current_tier + 1)
	var error: String = build_model.upgrade_error(selected_position)
	upgrade_button.disabled = not error.is_empty()
	upgrade_button.tooltip_text = error
	if not error.is_empty(): upgrade_detail.text += "\n\n" + error
	_layout_menus()

func _upgrade_selected() -> void:
	var error: String = build_model.upgrade_module(selected_position)
	message("Module upgraded to Tier %d." % build_model.tier_at(selected_position) if error.is_empty() else error, not error.is_empty())

func _demolish_selected() -> void:
	var refund: int = build_model.module_refund(selected_position)
	var error: String = build_model.demolish_module(selected_position)
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
	root.remove_child(trade_panel)
	trade_panel.queue_free()
	trade_panel = TradePanel.new()
	trade_panel.hud = self
	trade_panel.fleet = fleet
	root.add_child(trade_panel)
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
	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 12
	top_bar.offset_right = -12
	top_bar.offset_top = 8
	top_bar.offset_bottom = 68
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", _style(Color("111d2c"), Color("253647")))
	root.add_child(top_bar)
	top_bar_content = Control.new()
	top_bar_content.name = "TopBarContent"
	top_bar_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_bar_content)
	title_label.reparent(root)
	title_label.text = "ORBITAL"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", CYAN)
	# Replace the old loose labels with one compact, alertable status row.
	resource_status.hide()
	status_row = HBoxContainer.new()
	status_row.name = "StatusRow"
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar_content.add_child(status_row)
	status_capsule = PanelContainer.new()
	status_capsule.name = "StatusCapsule"
	status_capsule.mouse_filter = Control.MOUSE_FILTER_STOP
	status_capsule.custom_minimum_size = Vector2(0, 20)
	status_capsule.clip_contents = true
	status_capsule.add_theme_stylebox_override("panel", _style(Color("101b29"), Color("304353"), 10))
	status_row.add_child(status_capsule)
	var capsule_row := HBoxContainer.new()
	capsule_row.add_theme_constant_override("separation", 0)
	status_capsule.add_child(capsule_row)
	miner_segment = _status_segment(capsule_row, "mining_ship", Color("baa1f5"), "Miners", "10/10")
	refinery_segment = _status_segment(capsule_row, "refinery", GOLD, "Refineries", "10 buffer full")
	module_segment = _status_segment(capsule_row, 0, Color("9aa9b5"), "Modules", "999")
	miner_alert = _segment_alert(miner_segment)
	refinery_alert = _segment_alert(refinery_segment)
	module_alert = _segment_alert(module_segment)
	for label: Label in [fleet_label, refinery_label, count_label]: label.hide()
	fleet_label = _label(_status_body(miner_segment), "", 12, Color("baa1f5"))
	refinery_label = _label(_status_body(refinery_segment), "", 12, GOLD)
	count_label = _label(_status_body(module_segment), "", 12, Color("9aa9b5"))
	for label: Label in [fleet_label, refinery_label, count_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	colony_group = HBoxContainer.new()
	colony_group.name = "ColonyLevel"
	colony_group.add_theme_constant_override("separation", 6)
	colony_group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colony_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colony_group.mouse_filter = Control.MOUSE_FILTER_STOP
	status_row.add_child(colony_group)
	level_label.reparent(colony_group)
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", CYAN)
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	goal_bar.reparent(colony_group)
	colony_percent = _label(colony_group, "0%", 11, Color("6da9a8"))
	colony_percent.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_row.add_theme_constant_override("separation", 16)
	status_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for child: Node in resource_bar.get_children(): child.hide()
	compact_resources = HBoxContainer.new()
	compact_resources.add_theme_constant_override("separation", 10)
	root.add_child(compact_resources)
	var names: Array = ["Materials / capacity", "Minerals", "Power", "Tech", "Xenocrystals"]
	var readouts: Array = [materials_label, minerals_label, power_label, tech_label, xenocrystal_label]
	for i in range(readouts.size()):
		var label: Label = readouts[i]
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		compact_resources.add_child(group)
		var icon = preload("res://scripts/resource_icon.gd").new()
		icon.kind = i
		icon.tint = [GOLD, Color("baa1f5"), CYAN, Color("e4bc70"), Color("67f5e1")][i]
		group.add_child(icon)
		label.reparent(group)
		label.add_theme_font_size_override("font_size", 12)
		label.tooltip_text = names[i]
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	resource_bar.hide()
	toolbar = GridContainer.new()
	toolbar.columns = 8
	toolbar.add_theme_constant_override("h_separation", 3)
	toolbar.add_theme_constant_override("v_separation", 8)
	menu_scroll = ScrollContainer.new()
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(menu_scroll)
	menu_scroll.add_child(toolbar)
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var menu_labels: Dictionary = {"Build": "Build", "Ships": "Ships", "Research": "Research", "Gate/Travel": "Gate", "Outposts/Regions": "Outposts", "Trade/Contacts": "Trade", "Menu": "Menu"}
	for caption: String in menu_labels:
		var button := Button.new()
		button.text = str(menu_labels[caption])
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 10)
		var menu_style := _style(Color("172738"), Color("304557"), 5)
		menu_style.content_margin_left = 3
		menu_style.content_margin_right = 3
		menu_style.content_margin_top = 2
		menu_style.content_margin_bottom = 2
		button.add_theme_stylebox_override("normal", menu_style)
		var menu_hover := _style(Color("25404b"), CYAN, 5)
		menu_hover.content_margin_left = 3
		menu_hover.content_margin_right = 3
		menu_hover.content_margin_top = 2
		menu_hover.content_margin_bottom = 2
		button.add_theme_stylebox_override("hover", menu_hover)
		button.pressed.connect(func() -> void: open_menu(caption))
		toolbar.add_child(button)
		menu_buttons[caption] = button
		if caption == "Build":
			demolish_top_button = Button.new()
			demolish_top_button.text = "Demolish"
			demolish_top_button.custom_minimum_size = Vector2(0, 28)
			demolish_top_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			demolish_top_button.add_theme_font_size_override("font_size", 10)
			demolish_top_button.tooltip_text = "Toggle demolish mode, then click one of your placed modules."
			demolish_top_button.pressed.connect(toggle_demolish_mode)
			toolbar.add_child(demolish_top_button)
			_refresh_demolish_button()
	research_button.get_parent().remove_child(research_button)
	research_button.queue_free()
	research_button = menu_buttons["Research"]
	_setup_settings()
	_setup_menu()
	_wrap_panel(panel, "Build / Ships")
	_wrap_panel(research_panel, "Research")
	_wrap_panel(gate_panel, "Gate / Travel")
	_wrap_panel(cargo_route_panel, "Cargo Route")
	_install_secondary_panels()
	resource_bar.resized.connect(_layout_menus)
	get_viewport().size_changed.connect(_layout_menus)
	close_panels()
	_layout_menus()

func _install_secondary_panels() -> void:
	for id: int in panel_closes.keys():
		if not is_instance_valid(panel_closes[id]) or not panel_closes[id].is_inside_tree(): panel_closes.erase(id)
	managed_panels = managed_panels.filter(func(item: PanelContainer) -> bool: return is_instance_valid(item) and item.is_inside_tree())
	_wrap_panel(trade_panel, "Trade / Contacts")
	_wrap_panel(region_navigation.panel, "Outposts / Regions")
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
	if target == panel: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var scroll := ScrollContainer.new()
	scroll.name = "Content"
	# The viewport must expand to the measured panel height; collapsing this
	# container also collapses all detail controls inside it.
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 0
	frame.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for child: Node in children: child.reparent(body)
	# ScrollContainer does not automatically contribute its child's minimum
	# height when its own minimum is zero. Seed it from the populated body so
	# the wrapper can measure real detail content instead of only the heading.
	scroll.custom_minimum_size.y = body.get_combined_minimum_size().y
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
	toolbar.columns = 8
	toolbar.add_theme_constant_override("h_separation", 2)
	menu_scroll.position = Vector2(140, 8)
	menu_scroll.size = Vector2(maxf(160, viewport_size.x - 486), 28)
	toolbar.custom_minimum_size.y = 28
	title_label.position = Vector2(22, 13)
	if is_instance_valid(compact_resources):
		compact_resources.position = Vector2(viewport_size.x - 336, 12)
		compact_resources.size = Vector2(320, 24)
	if is_instance_valid(fps_label):
		fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		fps_label.offset_left = -82
		fps_label.offset_right = -12
		fps_label.offset_top = 104
		fps_label.offset_bottom = 122
	if is_instance_valid(status_row):
		status_row.position = Vector2(128, 32)
		status_row.size = Vector2(viewport_size.x - 152, 22)
		status_capsule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		colony_group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tray_top: float = 69.0
	var top: float = 137.0
	if is_instance_valid(ship_tray):
		ship_tray.position = Vector2(24, tray_top)
		ship_tray.size = Vector2(viewport_size.x - 48, 32)
		station_view_button.position = Vector2(viewport_size.x - 150, 104)
		station_view_button.size = Vector2(126, 32)
		station_view_button.add_theme_font_size_override("font_size", 12)
	region_navigation.location_label.position = Vector2(24, 113)
	region_navigation.location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbit_label.hide() # Replaced by the always-visible location indicator and Regions details.
	var max_panel_height: float = maxf(180.0, minf(viewport_size.y - top - 52.0, viewport_size.y * 0.72))
	for target: PanelContainer in managed_panels:
		_sync_scroll_minimums(target)
		if target == panel and is_instance_valid(tabs):
			var current_page: Control = tabs.get_current_tab_control()
			if is_instance_valid(current_page):
				tabs.custom_minimum_size.y = current_page.get_combined_minimum_size().y
		var content: Node = target.get_node_or_null("MenuFrame/Content")
		if is_instance_valid(content):
			var body: Node = content.get_node_or_null("Body")
			if is_instance_valid(body):
				content.custom_minimum_size.y = body.get_combined_minimum_size().y
		var width: float = minf(380 if target == panel or target == ship_context or target == settings_panel or target == menu_panel else 820, viewport_size.x - 56)
		target.position = Vector2(viewport_size.x - width - 28, top)
		var natural_height: float = target.get_combined_minimum_size().y
		var height: float = clampf(natural_height, 56.0, max_panel_height)
		target.size = Vector2(width, height)

func _sync_scroll_minimums(node: Node) -> void:
	for child: Node in node.get_children():
		_sync_scroll_minimums(child)
	if node is ScrollContainer and node.get_child_count() > 0:
		var content_node: Node = node.get_child(0)
		if content_node is Control:
			node.custom_minimum_size.y = (content_node as Control).get_combined_minimum_size().y

func _request_panel_fit() -> void:
	if panel_fit_pending:
		return
	panel_fit_pending = true
	call_deferred("_fit_panels_after_layout")

func _fit_panels_after_layout() -> void:
	# Let Containers process the new tab/content minimums before measuring them.
	await get_tree().process_frame
	panel_fit_pending = false
	_layout_menus()

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
	if target == panel: target.get_node("MenuFrame").get_child(0).get_child(0).text = menu
	if menu_buttons.has(menu): menu_buttons[menu].add_theme_stylebox_override("normal", _style(Color("25404b"), CYAN))
	target.show()
	_touch_targets(target)
	_layout_menus()
	_request_panel_fit()

func open_menu(menu: String) -> void:
	if active_menu == menu and managed_panels.any(func(target: PanelContainer) -> bool: return target.visible):
		close_panels()
		return
	match menu:
		"Build", "Ships":
			activate_panel(panel, menu)
			tabs.current_tab = 0 if menu == "Build" else 1
			_request_panel_fit()
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
		hauling_assignment = -1
		if has_open_panel():
			close_panels()
		else:
			deselect_ship()
			deselect_module()
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
	tray_rows.add_theme_constant_override("separation", 4)
	ship_tray.add_child(tray_rows)
	empty_tray = _label(tray_rows, "No ships yet. Open Ships to buy your first ship.", 12, MUTED)
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
			tile.role = "%s %d" % [definition.name.replace(" Ship", "").replace("Xeno Miner", "Xeno"), id]
			tile.add_theme_stylebox_override("normal", _style(Color("111e29"), Color("304557"), 12))
			tile.pressed.connect(func() -> void: select_ship(id))
			tray_rows.add_child(tile)
			ship_tiles[id] = tile
		var status: String = "Working" if fleet.unit_busy(id) else ("Parked" if fleet.docking.status(id) == "parked" else "Idle · no dock")
		if fleet.hauling.jobs.has(id): status = str(fleet.hauling.jobs[id].status)
		if fleet.collection.jobs.has(id): status = str(fleet.collection.jobs[id].status)
		if fleet.transport.jobs.has(id): status = "In transit"
		if fleet.repairs.jobs.has(id):
			var repair_job: Dictionary = fleet.repairs.jobs[id]
			status = "Repairing · waiting" if bool(repair_job.get("waiting", false)) else ("Repairing" if str(repair_job.phase) == "repairing" else "Repair transit")
		var tile = ship_tiles[id]
		var ship_region: String = fleet.transport.location(id)
		tile.region_id = ship_region
		tile.planet = fleet.regions.planets.get(fleet.regions.catalog.get(ship_region, {}).get("planet", "earth"), {})
		tile.status = status
		tile.status_color = GOLD if status.to_lower().contains("wait") or status.to_lower().contains("full") else (CYAN if fleet.unit_busy(id) else MUTED)
		tile.selected_ship = id == selected_ship_id
		tile.add_theme_stylebox_override("normal", _style(Color("111e29"), CYAN if tile.selected_ship else tile.status_color.darkened(0.2), 12))
		tile.add_theme_stylebox_override("hover", _style(Color("1c303b"), CYAN if tile.selected_ship else tile.status_color, 12))
		tile.tooltip_text = "%s #%d · %s · %s" % [definition.name, id, fleet.regions.catalog[ship_region].name, status]
		tile.queue_redraw()
		if id == selected_ship_id:
			context_title.text = "%s #%d" % [definition.name, id]
			context_detail.text = "%s · %s" % [fleet.regions.catalog[fleet.transport.location(id)].name, status]
			if fleet.transport.jobs.has(id): context_detail.text += " → " + str(fleet.regions.catalog[fleet.transport.jobs[id].destination].name)

func deselect_ship() -> void:
	hauling_assignment = -1
	selected_ship_id = -1
	get_parent().asteroids.selected_ship = -1
	# Release visual following at the current camera position; jobs are untouched.
	get_parent().ship_camera.ship_id = -1
	_refresh_ships()

func select_ship(id: int) -> void:
	hauling_assignment = -1
	if not model.ships.has(id): return
	# Ship selection replaces module selection visually; the module itself is
	# unaffected and any open detail panel is closed by activate_panel below.
	selected_position = Vector2.INF
	get_parent().board.inspected_position = Vector2.INF
	get_parent().board.queue_redraw()
	var region: String = fleet.transport.location(id)
	var different_region: bool = region != fleet.regions.current_region
	# Viewing a discovered region is the existing presentation-location command.
	var error: String = fleet.regions.set_location(region)
	if not error.is_empty():
		message(error, true)
		return
	selected_ship_id = id
	activate_panel(ship_context, "Ship")
	get_parent().ship_camera.ship_id = -1
	if different_region: get_parent().ship_camera.focus_ship(id)
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
	grid_controls_panel = PanelContainer.new()
	grid_controls_panel.name = "GridControlsPanel"
	grid_controls_panel.custom_minimum_size.x = 250
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.04, 0.08, 0.12, 0.68)
	backdrop.set_corner_radius_all(5)
	backdrop.content_margin_left = 6
	backdrop.content_margin_right = 6
	backdrop.content_margin_top = 0
	backdrop.content_margin_bottom = 0
	grid_controls_panel.add_theme_stylebox_override("panel", backdrop)
	row.add_child(grid_controls_panel)
	row.move_child(grid_controls_panel, 0)
	grid_controls_panel.add_child(grid_controls)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_balance = Control.new()
	footer_balance.custom_minimum_size.x = 250
	footer_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(footer_balance)
	for caption: String in ["Fit grid", "−", "+"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(48, 30)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_hover_color", CYAN)
		button.add_theme_color_override("font_focus_color", CYAN)
		_footer_text_style(button)
		button.tooltip_text = "Change the view only; station positions stay fixed."
		button.pressed.connect(_grid_action.bind(caption))
		grid_controls.add_child(button)
		grid_buttons[caption] = button
	zoom_label = _label(grid_controls, "1.0x", 14, INK)
	_footer_text_style(zoom_label)
	zoom_label.custom_minimum_size.x = 50
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid_controls.move_child(zoom_label, 2)
	get_viewport().size_changed.connect(_layout_grid_controls)
	_layout_grid_controls()
	grid_controls.visible = get_parent().preferences.values.show_grid_controls
	grid_controls_panel.visible = grid_controls.visible
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
	_label(body, "Audio", 18, INK)
	var music_toggle := CheckButton.new()
	music_toggle.text = "Music"
	music_toggle.custom_minimum_size.y = 44
	music_toggle.button_pressed = get_parent().preferences.music_enabled
	body.add_child(music_toggle)
	settings_toggles["music"] = music_toggle
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = get_parent().preferences.music_volume * 100.0
	volume.custom_minimum_size = Vector2(200, 44)
	var volume_label: Label = _label(body, "Music volume · %d%%" % volume.value, 14, MUTED)
	body.add_child(volume)
	settings_numbers["music_volume"] = volume
	music_toggle.toggled.connect(func(on: bool) -> void:
		if get_parent().preferences.set_music(on, volume.value / 100.0) != OK:
			message("Could not save audio settings."))
	volume.value_changed.connect(func(value: float) -> void:
		volume_label.text = "Music volume · %d%%" % value
		if get_parent().preferences.set_music(music_toggle.button_pressed, value / 100.0) != OK:
			message("Could not save audio settings."))
	_label(body, "Drag the field or use W/A/S/D to pan.", 14, MUTED)
	_wrap_panel(settings_panel, "Settings")

func has_open_panel() -> bool:
	return managed_panels.any(func(item: PanelContainer) -> bool: return item.visible) or (is_instance_valid(dev_panel) and dev_panel.visible)

func pointer_over_ui(point: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO, viewport_size).has_point(point): return true
	if Rect2(28, 8, viewport_size.x - 56, 60).has_point(point): return true
	var controls: Array[Control] = [compact_resources, status_row, ship_tray, station_view_button, region_navigation.location_label, footer]
	for target: PanelContainer in managed_panels: controls.append(target)
	if is_instance_valid(dev_panel): controls.append(dev_panel)
	for control: Control in controls:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	var hovered := get_viewport().gui_get_hovered_control()
	# gui_get_hovered_control() can remain on the last panel control while the
	# pointer has moved onto the map. Only block world input when its bounds
	# actually contain this click; otherwise empty-map clicks can close a ship
	# panel and clear its selection as intended.
	return is_instance_valid(hovered) and hovered != root and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE and hovered.get_global_rect().has_point(point)

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
	var new_button := Button.new()
	new_button.text = "New game"
	new_button.custom_minimum_size.y = 44
	for style: String in ["normal", "hover", "pressed", "focus"]:
		new_button.add_theme_stylebox_override(style, save_button.get_theme_stylebox(style))
	new_button.pressed.connect(func() -> void: new_game_requested.emit())
	body.add_child(new_button)
	_wrap_panel(menu_panel, "Menu")

func _footer_text_style(control: Control) -> void:
	control.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.95))
	control.add_theme_constant_override("outline_size", 3)
	if control is Label:
		control.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		control.add_theme_constant_override("shadow_offset_x", 1)
		control.add_theme_constant_override("shadow_offset_y", 1)
