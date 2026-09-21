extends PanelContainer
var hud: CanvasLayer
var fleet: MiningFleet
var inventory_label: Label
var gate_picker: OptionButton
var ship_picker: OptionButton
var destination_picker: OptionButton
var jump_button: Button
var jump_detail: Label
var locations_label: Label
var close_button: Button
var picker_signature: String = ""

func _ready() -> void:
	name = "GateTravel"
	position = Vector2(40, 156)
	custom_minimum_size = Vector2(750, 570)
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
	var title: Label = hud._label(heading, "GATE / TRAVEL", 20, hud.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(heading, "Close")
	close_button.pressed.connect(hide)
	inventory_label = hud._label(column, "", 15, hud.GOLD)
	hud._label(column, "TELEPORT GATE · outbound from Earth", 16, hud.CYAN)
	hud._label(column, "Departure gate", 12, hud.MUTED)
	gate_picker = _picker(column)
	hud._label(column, "Ship to transport", 12, hud.MUTED)
	ship_picker = _picker(column)
	hud._label(column, "Destination region", 12, hud.MUTED)
	destination_picker = _picker(column)
	jump_detail = hud._label(column, "", 13, hud.GOLD)
	jump_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jump_button = _button(column, "Transport ship")
	jump_button.pressed.connect(func() -> void:
		var error: String = fleet.transport.jump(selected_gate(), selected_ship(), selected_destination())
		hud.message("Ship in transit. Station remains at Earth." if error.is_empty() else error, not error.is_empty())
		refresh())
	var locations_scroll := ScrollContainer.new()
	locations_scroll.custom_minimum_size.y = 72
	locations_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(locations_scroll)
	locations_label = hud._label(locations_scroll, "", 13, hud.INK)
	var note: Label = hud._label(column, "Jump Ships can found outposts. Local Miners deposit there. Return hauling and module construction are future scope.", 12, hud.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fleet.changed.connect(refresh)
	fleet.model.changed.connect(refresh)
	refresh()
	hide()

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 14)
	parent.add_child(button)
	return button

func _picker(parent: Node) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 32
	parent.add_child(picker)
	picker.item_selected.connect(func(_index: int) -> void: refresh())
	return picker

func selected_gate() -> Vector2:
	return gate_picker.get_item_metadata(gate_picker.selected) if gate_picker.selected >= 0 else Vector2.INF

func selected_ship() -> int:
	return ship_picker.get_item_id(ship_picker.selected) if ship_picker.selected >= 0 else -1

func selected_destination() -> String:
	return str(destination_picker.get_item_metadata(destination_picker.selected)) if destination_picker.selected >= 0 else ""

func open_panel() -> void:
	hud.activate_panel(self, "Gate/Travel")
	refresh()
	show()

func refresh() -> void:
	if not is_instance_valid(jump_button):
		return
	inventory_label.text = "Xenocrystals available: %d" % fleet.diplomacy.inventory.get("xenocrystal", 0)
	var signature: String = str(fleet.transport.gates.keys()) + str(fleet.model.ships) + str(fleet.regions.records.keys())
	if signature != picker_signature:
		picker_signature = signature
		var gate: Vector2 = selected_gate()
		var ship: int = selected_ship()
		var destination: String = selected_destination()
		gate_picker.clear()
		ship_picker.clear()
		destination_picker.clear()
		for point: Vector2 in fleet.transport.gates:
			gate_picker.add_item("Gate at %s" % point)
			gate_picker.set_item_metadata(gate_picker.item_count - 1, point)
			if point == gate:
				gate_picker.select(gate_picker.item_count - 1)
		for ship_id: int in fleet.model.ships:
			ship_picker.add_item("%s #%d" % [fleet.model.ship_catalog[fleet.model.ships[ship_id]].name, ship_id], ship_id)
			if ship_id == ship:
				ship_picker.select(ship_picker.item_count - 1)
		for region_id: String in fleet.regions.catalog:
			if region_id == fleet.regions.HOME:
				continue
			destination_picker.add_item(fleet.regions.catalog[region_id].name)
			destination_picker.set_item_metadata(destination_picker.item_count - 1, region_id)
			if region_id == destination:
				destination_picker.select(destination_picker.item_count - 1)
	for index in range(destination_picker.item_count):
		var id: String = str(destination_picker.get_item_metadata(index))
		destination_picker.set_item_text(index, "%s · %s" % [fleet.regions.catalog[id].name, "Discovered" if fleet.regions.is_discovered(id) else "Unknown"])
	var costs: Array[String] = []
	if fleet.transport.gates.has(selected_gate()):
		var capability: Dictionary = fleet.model.definition_at(selected_gate()).teleport
		for good: String in capability.cost:
			costs.append("%d %s" % [capability.cost[good], fleet.diplomacy.goods_catalog[good].name])
	jump_button.text = "Transport ship" + (" · " + " + ".join(costs) if not costs.is_empty() else "")
	jump_detail.text = fleet.transport.jump_error(selected_gate(), selected_ship(), selected_destination())
	if jump_detail.text.is_empty():
		jump_detail.text = "Ready. Only the selected ship will travel."
	var lines: Array[String] = []
	for ship_id: int in fleet.model.ships:
		var status: String = fleet.regions.catalog[fleet.transport.location(ship_id)].name
		if fleet.transport.jobs.has(ship_id):
			var job: Dictionary = fleet.transport.jobs[ship_id]
			status = "In transit to %s · %ds" % [fleet.regions.catalog[job.destination].name, job.remaining]
		lines.append("%s #%d · %s" % [fleet.model.ship_catalog[fleet.model.ships[ship_id]].name, ship_id, status])
	locations_label.text = "\n".join(lines)
