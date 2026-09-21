extends Control

var hud: CanvasLayer
var fleet: MiningFleet
var location_label: Label
var region_buttons: Dictionary = {}
var route_buttons: Dictionary = {}
var panel: PanelContainer
var title_label: Label
var detail_label: Label
var status_label: Label
var scout_picker: OptionButton
var miner_picker: OptionButton
var send_button: Button
var jump_button: Button
var close_button: Button
var target_rows: VBoxContainer
var target_buttons: Dictionary = {}
var selected_region: String = "venus"
var ship_signature: String = ""

func _ready() -> void:
	name = "RegionNavigation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overview := PanelContainer.new()
	overview.position = Vector2(40, 112)
	overview.custom_minimum_size = Vector2(750, 34)
	overview.add_theme_stylebox_override("panel", hud._style(Color("111d2c"), Color("365469")))
	add_child(overview)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	overview.add_child(bar)
	location_label = hud._label(bar, "", 14, hud.CYAN)
	location_label.custom_minimum_size.x = 200
	location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for region_id: String in fleet.regions.catalog:
		var button: Button = _button(bar, "")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: _overview(region_id))
		region_buttons[region_id] = button
	panel = PanelContainer.new()
	panel.position = Vector2(40, 160)
	panel.custom_minimum_size = Vector2(750, 470)
	panel.add_theme_stylebox_override("panel", hud._style(Color("101e2d"), hud.CYAN))
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label: Label = hud._label(heading, "REGIONS / SCOUT & JUMP", 20, hud.CYAN)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(heading, "Close")
	close_button.pressed.connect(panel.hide)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var routes := VBoxContainer.new()
	routes.custom_minimum_size.x = 210
	body.add_child(routes)
	for region_id: String in fleet.regions.catalog:
		var button: Button = _button(routes, "")
		button.custom_minimum_size.y = 55
		button.pressed.connect(func() -> void: select_region(region_id))
		route_buttons[region_id] = button
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 480
	detail.add_theme_constant_override("separation", 10)
	body.add_child(detail)
	title_label = hud._label(detail, "", 22, hud.INK)
	status_label = hud._label(detail, "", 14, hud.CYAN)
	detail_label = hud._label(detail, "", 13, hud.MUTED)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.y = 66
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	scout_picker = OptionButton.new()
	scout_picker.custom_minimum_size = Vector2(170, 36)
	actions.add_child(scout_picker)
	scout_picker.item_selected.connect(func(_index: int) -> void: refresh())
	send_button = _button(actions, "Send Scout")
	send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_button.pressed.connect(_survey)
	jump_button = _button(detail, "Jump")
	jump_button.pressed.connect(func() -> void: _jump(selected_region))
	miner_picker = OptionButton.new()
	miner_picker.custom_minimum_size.y = 32
	detail.add_child(miner_picker)
	miner_picker.item_selected.connect(func(_index: int) -> void: refresh())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 110
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(scroll)
	target_rows = VBoxContainer.new()
	target_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(target_rows)
	hud._label(column, "Mining requires a local outpost and Miner. Hauling to Home is not available yet.", 12, hud.MUTED)
	fleet.changed.connect(refresh)
	fleet.model.changed.connect(refresh)
	refresh()
	# Keep location persistent; region shortcuts belong inside the Regions menu.
	location_label.reparent(hud.root)
	overview.reparent(column)
	overview.custom_minimum_size = Vector2.ZERO
	column.move_child(overview, 1)
	panel.hide()

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", hud.INK)
	button.add_theme_color_override("font_disabled_color", hud.MUTED)
	button.add_theme_stylebox_override("normal", hud._style(Color("1a3041"), Color("365469")))
	button.add_theme_stylebox_override("hover", hud._style(Color("254452"), hud.CYAN))
	parent.add_child(button)
	return button

func open_region(region_id: String, ship_id: int = -1) -> void:
	hud.activate_panel(panel, "Outposts/Regions")
	selected_region = region_id
	refresh()
	for index in range(scout_picker.item_count):
		if scout_picker.get_item_id(index) == ship_id:
			scout_picker.select(index)
	refresh()
	panel.show()

func select_region(region_id: String) -> void:
	selected_region = region_id
	refresh()

func _overview(region_id: String) -> void:
	if fleet.regions.jump_error(region_id).is_empty():
		_jump(region_id)
	else:
		open_region(region_id)

func _jump(region_id: String) -> void:
	var error: String = fleet.regions.jump(region_id)
	if error.is_empty():
		hud.close_panels()
		hud.message("Location: %s. The station remains at Earth." % fleet.regions.catalog[region_id].name)
	else:
		hud.message(error, true)
	refresh()

func _survey() -> void:
	var error: String = fleet.survey_region(scout_picker.get_selected_id(), selected_region)
	hud.message("Scout launched. Region unlocks on arrival." if error.is_empty() else error, not error.is_empty())
	refresh()

func _mine(asteroid_id: int) -> void:
	var error: String = fleet.dispatch(asteroid_id, miner_picker.get_selected_id())
	hud.message("Miner assigned. Minerals go to this region’s local storage." if error.is_empty() else error, not error.is_empty())

func _fill(picker: OptionButton, capability: String) -> void:
	var previous: int = picker.get_selected_id()
	picker.clear()
	for ship_id: int in fleet.model.ships:
		var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
		if definition.has(capability):
			picker.add_item("%s #%d" % [definition.name, ship_id], ship_id)
	if picker.item_count == 0:
		picker.add_item("No " + capability + " ships", 0)
	for index in range(picker.item_count):
		if picker.get_item_id(index) == previous:
			picker.select(index)

func refresh() -> void:
	if not is_instance_valid(scout_picker):
		return
	var regions: RefCounted = fleet.regions
	location_label.text = "LOCATION · " + str(regions.catalog[regions.current_region].name).to_upper()
	if str(fleet.model.ships) != ship_signature:
		ship_signature = str(fleet.model.ships)
		_fill(scout_picker, "survey")
		_fill(miner_picker, "mining")
	for region_id: String in regions.catalog:
		var state: String = regions.state(region_id)
		var caption: String = "Here" if region_id == regions.current_region else ("View" if regions.jump_error(region_id).is_empty() else state.capitalize())
		region_buttons[region_id].text = "%s · %s" % [regions.catalog[region_id].name, caption]
		region_buttons[region_id].tooltip_text = "View this region" if caption == "View" else "Open region details and Scout routes"
		route_buttons[region_id].text = "%s\n%s" % [regions.catalog[region_id].name, caption]
	var definition: Dictionary = regions.catalog[selected_region]
	var record: Dictionary = regions.records[selected_region]
	title_label.text = definition.name + " / " + regions.planets[definition.planet].name
	var job: Dictionary = regions.survey_job(selected_region)
	status_label.text = regions.state(selected_region).to_upper() + (" · %ds" % job.remaining if not job.is_empty() else "")
	var routes: Array[String] = []
	for neighbor: String in definition.neighbors:
		routes.append(regions.catalog[neighbor].name)
	detail_label.text = "Scout routes: " + ", ".join(routes) + ". "
	if not record.discovered:
		detail_label.text += "Unsurveyed. Send a Scout from an adjacent region to reveal its contents."
	elif selected_region == regions.HOME:
		detail_label.text += "Your permanent Earth station. Local salvage, mining and trade remain available."
	else:
		var anomalies: Array[String] = []
		for content: Dictionary in record.contents:
			if content.type == "alien_anomaly":
				anomalies.append(content.name + " · Trade/Contacts")
			elif content.type == "anomaly":
				anomalies.append("%s: +%d %s" % [content.name, content.amount, str(content.good).capitalize()])
		detail_label.text += fleet.outposts.summary(selected_region) + "\n"
		detail_label.text += "%d deposits. Studied: %s." % [record.asteroid_ids.size(), "; ".join(anomalies)]
	var ship_id: int = scout_picker.get_selected_id()
	var error: String = fleet.region_survey_error(ship_id, selected_region)
	send_button.disabled = not error.is_empty()
	send_button.text = "Scout · %ds" % fleet.region_survey_duration(ship_id, selected_region) if error.is_empty() else "Send Scout"
	send_button.tooltip_text = error
	error = regions.jump_error(selected_region)
	jump_button.disabled = not error.is_empty()
	jump_button.text = "Jump to " + definition.name
	jump_button.tooltip_text = error
	for asteroid_id: int in target_buttons:
		target_buttons[asteroid_id].visible = record.asteroid_ids.has(asteroid_id)
	for asteroid_id: int in record.asteroid_ids:
		if not target_buttons.has(asteroid_id):
			var new_button: Button = _button(target_rows, "")
			new_button.pressed.connect(func() -> void: _mine(asteroid_id))
			target_buttons[asteroid_id] = new_button
		var rock: Dictionary = fleet.asteroids.get(asteroid_id, {})
		var button: Button = target_buttons[asteroid_id]
		button.disabled = rock.is_empty() or bool(rock.get("claimed", false)) or miner_picker.get_selected_id() <= 0 or not fleet.mining_error(miner_picker.get_selected_id(), asteroid_id).is_empty()
		button.tooltip_text = fleet.mining_error(miner_picker.get_selected_id(), asteroid_id)
		button.text = "Depleted deposit" if rock.is_empty() else "%s · %d Minerals" % ["Mining" if rock.claimed else "Assign Miner", rock.minerals]
