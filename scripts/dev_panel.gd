extends PanelContainer
const Config = preload("res://scripts/dev_config.gd")
var hud: CanvasLayer
var buttons: Dictionary = {}
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
	var title: Label = hud._label(header, "DEVELOPER · HOME", 18, Color("dca1eb"))
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
	var note: Label = hud._label(body, "Development tools. Grants target Home and are included in ordinary saves. Materials respect storage capacity.", 13, hud.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for resource: String in ["materials", "minerals"]:
		var button: Button = _button(body, "+100 " + resource.capitalize())
		button.pressed.connect(func() -> void: grant(resource, 100))
		buttons[resource] = button
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
	var received: int = locations.receive(locations.destination(locations.primary_station()), resource, amount)
	result_label.text = "Home: +%d %s." % [received, resource.capitalize()]
	hud.message("DEV · " + result_label.text)
