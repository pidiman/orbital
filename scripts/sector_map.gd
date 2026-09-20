extends PanelContainer

var hud: CanvasLayer
var fleet: MiningFleet
var selected_sector: String = "dawn"
var sector_buttons: Dictionary = {}
var target_buttons: Dictionary = {}
var scout_picker: OptionButton
var miner_picker: OptionButton
var send_button: Button
var close_button: Button
var title_label: Label
var state_label: Label
var result_label: Label
var progress: ProgressBar
var target_rows: VBoxContainer
var ship_signature: String = ""

func _ready() -> void:
	name = "SectorMap"
	position = Vector2(40, 140)
	custom_minimum_size = Vector2(750, 450)
	add_theme_stylebox_override("panel", hud._style(Color("101e2d"), Color("51828d")))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label: Label = hud._label(heading, "SECTOR MAP  /  HOME ORBIT", 20, hud.CYAN)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = make_button(heading, "Close")
	close_button.pressed.connect(hide)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	var routes := VBoxContainer.new()
	routes.custom_minimum_size.x = 238
	row.add_child(routes)
	hud._label(routes, "ROUTES FROM HOME", 12, hud.MUTED)
	var route_scroll := ScrollContainer.new()
	route_scroll.custom_minimum_size = Vector2(238, 328)
	route_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	routes.add_child(route_scroll)
	var route_rows := VBoxContainer.new()
	route_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_scroll.add_child(route_rows)
	for sector: Dictionary in fleet.sectors:
		var button: Button = make_button(route_rows, sector.name)
		button.custom_minimum_size.y = 57
		button.pressed.connect(func() -> void: select_sector(sector.id))
		sector_buttons[sector.id] = button
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 440
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	row.add_child(detail)
	title_label = hud._label(detail, "", 22, hud.INK)
	state_label = hud._label(detail, "", 14, hud.CYAN)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	detail.add_child(progress)
	result_label = hud._label(detail, "", 14, hud.MUTED)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size.y = 62
	var scout_row := HBoxContainer.new()
	detail.add_child(scout_row)
	scout_picker = OptionButton.new()
	scout_picker.custom_minimum_size = Vector2(175, 38)
	scout_row.add_child(scout_picker)
	scout_picker.item_selected.connect(func(_index: int) -> void: refresh())
	send_button = make_button(scout_row, "Send Scout")
	send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_button.pressed.connect(_send_scout)
	hud._label(detail, "MINING ASSIGNMENT", 12, hud.MUTED)
	miner_picker = OptionButton.new()
	miner_picker.custom_minimum_size.y = 36
	detail.add_child(miner_picker)
	miner_picker.item_selected.connect(func(_index: int) -> void: refresh())
	var target_scroll := ScrollContainer.new()
	target_scroll.custom_minimum_size.y = 90
	target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(target_scroll)
	target_rows = VBoxContainer.new()
	target_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_scroll.add_child(target_rows)
	fleet.changed.connect(refresh)
	fleet.model.changed.connect(refresh)
	refresh()
	hide()

func make_button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", hud.INK)
	button.add_theme_color_override("font_disabled_color", hud.MUTED)
	button.add_theme_stylebox_override("normal", hud._style(Color("1a3041"), Color("365469")))
	button.add_theme_stylebox_override("hover", hud._style(Color("254452"), hud.CYAN))
	parent.add_child(button)
	return button

func open_map() -> void:
	hud.choose("")
	refresh()
	show()

func select_sector(sector_id: String) -> void:
	selected_sector = sector_id
	refresh()

func fill_picker(picker: OptionButton, capability: String) -> void:
	var previous: int = picker.get_selected_id()
	picker.clear()
	for ship_id: int in fleet.model.ships:
		var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
		if definition.has(capability):
			picker.add_item("%s #%d" % [definition.name, ship_id], ship_id)
	if picker.item_count == 0:
		picker.add_item("Build a " + ("Scout" if capability == "survey" else "Miner"), -1)
		picker.set_item_id(0, -1)
	for index in range(picker.item_count):
		if picker.get_item_id(index) == previous:
			picker.select(index)

func refresh() -> void:
	if not is_instance_valid(scout_picker):
		return
	var signature: String = str(fleet.model.ships)
	if signature != ship_signature:
		ship_signature = signature
		fill_picker(scout_picker, "survey")
		fill_picker(miner_picker, "mining")
	for sector: Dictionary in fleet.sectors:
		var route_state: String = fleet.sector_state(sector.id)
		sector_buttons[sector.id].text = "%s%s\n%s" % ["> " if selected_sector == sector.id else "", sector.name, route_state.capitalize()]
	var selected: Dictionary = fleet.sector_by_id(selected_sector)
	if selected.is_empty():
		return
	var state: String = fleet.sector_state(selected_sector)
	title_label.text = selected.name
	state_label.text = state.to_upper()
	progress.visible = state == "exploring"
	if state == "exploring":
		var job: Dictionary = fleet.sector_job(selected_sector)
		state_label.text += "  ·  arrival in %ds" % job.remaining
		progress.max_value = job.duration
		progress.value = int(job.duration) - int(job.remaining)
	var scout_id: int = scout_picker.get_selected_id()
	var error: String = fleet.survey_error(scout_id, selected_sector)
	send_button.disabled = not error.is_empty()
	send_button.tooltip_text = error
	send_button.text = "Send Scout · %ds" % fleet.travel_duration(scout_id, selected_sector) if error.is_empty() else "Send Scout"
	if state != "revealed":
		result_label.text = "Contents unknown. Scout travelling from Home orbit." if state == "exploring" else "Contents unknown. Send a Scout to discover this sector."
	elif selected_sector == "home":
		result_label.text = "Your colony. Salvage and drifting asteroids remain available in Home orbit."
	else:
		var reports: Array[String] = []
		for content: Dictionary in selected.get("contents", []):
			if content.type == "asteroid":
				reports.append("Asteroid: " + str(content.get("name", "Deposit")))
			elif content.type == "anomaly":
				reports.append("Anomaly: %s. %s" % [content.name, content.get("description", "Logged for future investigation.")])
			else:
				reports.append("Discovery logged: " + str(content.get("name", content.type)))
		result_label.text = "\n".join(reports) if not reports.is_empty() else "Empty sector. No mineable resources or anomalies detected."
	for button: Button in target_buttons.values():
		button.hide()
	for asteroid_id: int in selected.get("asteroid_ids", []):
		if not target_buttons.has(asteroid_id):
			var new_button: Button = make_button(target_rows, "")
			new_button.pressed.connect(func() -> void: _mine(asteroid_id))
			target_buttons[asteroid_id] = new_button
		var button: Button = target_buttons[asteroid_id]
		button.show()
		var asteroid: Dictionary = fleet.asteroids.get(asteroid_id, {})
		var miner_id: int = miner_picker.get_selected_id()
		button.disabled = asteroid.is_empty() or bool(asteroid.get("claimed", false)) or miner_id < 0 or fleet.jobs.has(miner_id)
		button.text = "Deposit depleted" if asteroid.is_empty() else "%s · %d Minerals" % ["Mining" if asteroid.claimed else "Mine deposit", asteroid.minerals]
		button.tooltip_text = "Choose an idle Miner. Mining repeats until this deposit is depleted."

func _send_scout() -> void:
	var error: String = fleet.survey(scout_picker.get_selected_id(), selected_sector)
	hud.message("Scout launched. Sector discovery follows arrival." if error.is_empty() else error, not error.is_empty())
	refresh()

func _mine(asteroid_id: int) -> void:
	var miner_id: int = miner_picker.get_selected_id()
	if miner_id < 0:
		hud.message("Build and select a Miner ship.", true)
		return
	var error: String = fleet.dispatch(asteroid_id, miner_id)
	hud.message("Miner assigned to the discovered deposit. Auto-mining started." if error.is_empty() else error, not error.is_empty())
	refresh()
