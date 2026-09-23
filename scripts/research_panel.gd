extends PanelContainer
var hud: CanvasLayer
var fleet: MiningFleet
var research_buttons: Dictionary = {}
var research_labels: Dictionary = {}
var inventory_label: Label
var close_button: Button

func _ready() -> void:
	name = "Research"
	position = Vector2(40, 156)
	custom_minimum_size = Vector2(750, 0)
	add_theme_stylebox_override("panel", hud._style(Color("101e2d"), Color("8bcdf1")))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title: Label = hud._label(heading, "RESEARCH", 20, hud.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(heading, "Close")
	close_button.pressed.connect(hide)
	inventory_label = hud._label(column, "", 15, hud.GOLD)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 145
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var technologies := VBoxContainer.new()
	technologies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(technologies)
	for id: String in fleet.research.catalog:
		var definition: Dictionary = fleet.research.catalog[id]
		var label: Label = hud._label(technologies, "", 14, hud.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		research_labels[id] = label
		var button: Button = _button(technologies, "Research %s · %d Tech" % [definition.name, definition.tech_cost])
		button.tooltip_text = definition.description
		button.pressed.connect(func() -> void:
			var error: String = fleet.research.research(id)
			hud.message("%s researched. Module unlocked permanently." % definition.name if error.is_empty() else error, not error.is_empty())
			refresh())
		research_buttons[id] = button
	refresh()
	hide()

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 14)
	parent.add_child(button)
	return button

func open_panel() -> void:
	hud.activate_panel(self, "Research")
	refresh()
	show()

func refresh() -> void:
	if not is_instance_valid(inventory_label):
		return
	inventory_label.text = "Tech: %d   ·   Xenocrystals: %d   ·   Research Labs: %d" % [fleet.diplomacy.inventory.get("tech", 0), fleet.diplomacy.inventory.get("xenocrystal", 0), fleet.research.labs.size()]
	for id: String in research_buttons:
		var definition: Dictionary = fleet.research.catalog[id]
		var state: String = fleet.research.state(id)
		var error: String = fleet.research.research_error(id)
		research_labels[id].text = "%s · %s\n%s" % [definition.name, state, definition.description if state != "Locked" else error]
		research_buttons[id].disabled = state == "Researched"
