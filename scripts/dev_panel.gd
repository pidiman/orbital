extends PanelContainer
const Config = preload("res://scripts/dev_config.gd")
var hud: CanvasLayer
var buttons: Dictionary = {}
var tuning_numbers: Dictionary = {}
var close_button: Button
var result_label: Label

func _ready() -> void:
	name = "DeveloperTools"
	if not Config.DEBUG_MODE:
		queue_free()
		return
	add_theme_stylebox_override("panel", hud._style(Color("241b2c"), Color("dca1eb")))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = hud._label(header, "DEVELOPER", 18, Color("dca1eb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(header, "Close / F9")
	close_button.pressed.connect(hide)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	var note: Label = hud._label(body, "Development tools. Grants target the viewed station and are included in ordinary saves. Materials respect storage capacity.", 13, hud.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._label(body, "Xenocrystals", 18, hud.INK)
	for option: Dictionary in hud.get_parent().preferences.definitions.get("tuning_options", []):
		var row := HBoxContainer.new()
		body.add_child(row)
		var caption: Label = hud._label(row, option.label, 14, hud.MUTED)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var number := SpinBox.new()
		number.min_value = option.min
		number.max_value = option.max
		number.step = option.step
		number.value = hud.get_parent().preferences.tuning_value(option)
		number.custom_minimum_size = Vector2(115, 44)
		number.value_changed.connect(func(value: float) -> void:
			if hud.get_parent().preferences.set_tuning(option, value) != OK:
				hud.message("Could not save local tuning settings."))
		row.add_child(number)
		tuning_numbers[option.id] = number
	var tuning_note: Label = hud._label(body, "Applies to newly spawned nodes.", 13, hud.MUTED)
	tuning_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var threat_toggle := CheckButton.new()
	threat_toggle.text = "Asteroid threats"
	threat_toggle.button_pressed = hud.get_parent().threat_field.active
	threat_toggle.custom_minimum_size.y = 44
	threat_toggle.toggled.connect(func(value: bool) -> void: hud.get_parent().threat_field.set_threats_enabled(value))
	body.add_child(threat_toggle)
	var spawn_button: Button = _button(body, "Spawn asteroid now")
	spawn_button.pressed.connect(func() -> void: hud.get_parent().threat_field.spawn_now())
	for resource: String in ["materials", "minerals", "tech", "xenocrystal"]:
		var amount: int = 10 if resource in ["tech", "xenocrystal"] else 100
		var name: String = "Xenocrystals" if resource == "xenocrystal" else resource.capitalize()
		var button: Button = _button(body, "+%d %s" % [amount, name])
		button.pressed.connect(func() -> void: grant(resource, amount))
		buttons[resource] = button
	var all_button: Button = _button(body, "+1000 All Resources")
	all_button.pressed.connect(func() -> void:
		grant("materials", 1000)
		grant("minerals", 1000)
		grant("tech", 1000)
		grant("xenocrystal", 1000))
	result_label = hud._label(body, "F9 toggles this developer panel.", 13, hud.INK)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(layout)
	layout()
	hide()

func _button(parent: Node, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	return button

func layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position = Vector2(28, hud.ship_tray.position.y + hud.ship_tray.size.y + 28)
	size = Vector2(minf(480, viewport_size.x - 56), maxf(100, viewport_size.y - position.y - 84))

func toggle() -> void:
	if not Config.DEBUG_MODE: return
	if visible:
		hide()
	else:
		hud.close_panels()
		hud.choose("")
		layout()
		show()

func grant(resource: String, amount: int) -> void:
	if not Config.DEBUG_MODE: return
	var locations = hud.model.locations
	var region: String = hud.fleet.regions.current_region
	var home_region: String = locations.station_region(locations.primary_station())
	var station_id: String = locations.primary_station() if region == home_region else locations.outpost_at(region, locations.rules.primary_station.owner)
	if station_id.is_empty():
		result_label.text = "No outpost in this region. Build one before granting local resources."
		hud.message("DEV · " + result_label.text, true)
		return
	var destination: Dictionary = locations.destination(station_id)
	var received: int = 0
	if station_id == locations.primary_station() and hud.fleet.diplomacy.goods_catalog.has(resource):
		received = hud.fleet.diplomacy.receive_goods(resource, amount)
	else:
		if station_id != locations.primary_station() and resource == "materials":
			var local: StationModel = hud.model.scoped_station(station_id)
			amount = mini(amount, maxi(0, local.capacity - local.materials))
		received = locations.receive(destination, resource, amount)
	var label: String = "Home" if station_id == locations.primary_station() else str(locations.stations[station_id].get("kind", "Outpost")).capitalize()
	result_label.text = "%s: +%d %s." % [label, received, resource.capitalize()]
	hud.message("DEV · " + result_label.text)
