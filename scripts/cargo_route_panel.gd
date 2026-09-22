extends PanelContainer
var hud: CanvasLayer
var fleet: RefCounted
var ship_id: int = -1
var source_picker: OptionButton
var destination_picker: OptionButton
var detail: Label
var confirm_button: Button
var close_button: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", hud._style(Color("101e2d"), Color("8bcdf1")))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	hud._label(heading, "CARGO SHUTTLE ROUTE", 18, hud.CYAN).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(heading, "Close")
	close_button.pressed.connect(hud.close_panels)
	hud._label(column, "Both regions must be discovered and have Teleport Gates. Each jump uses the gate's Xenocrystal cost.", 12, hud.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._label(column, "Source region", 12, hud.MUTED)
	source_picker = OptionButton.new(); column.add_child(source_picker)
	hud._label(column, "Destination region", 12, hud.MUTED)
	destination_picker = OptionButton.new(); column.add_child(destination_picker)
	detail = hud._label(column, "", 13, hud.GOLD); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_button = _button(column, "Confirm route")
	confirm_button.pressed.connect(_confirm)
	hide()

func _button(parent: Node, label: String) -> Button:
	var button := Button.new(); button.text = label; button.custom_minimum_size.y = 34; parent.add_child(button); return button

func open_for(id: int) -> void:
	ship_id = id
	hud.activate_panel(self, "Cargo route")
	_refresh()
	show()

func _refresh() -> void:
	if not is_instance_valid(source_picker): return
	source_picker.clear(); destination_picker.clear()
	var gated: Array[String] = []
	for region: String in fleet.regions.catalog:
		if fleet.regions.is_discovered(region) and fleet.transport.has_gate(region): gated.append(region)
	for region: String in gated:
		source_picker.add_item(fleet.regions.catalog[region].name); source_picker.set_item_metadata(source_picker.item_count - 1, region)
		destination_picker.add_item(fleet.regions.catalog[region].name); destination_picker.set_item_metadata(destination_picker.item_count - 1, region)
	var route: Dictionary = fleet.cargo.routes.get(ship_id, {})
	if not route.is_empty():
		for picker: OptionButton in [source_picker, destination_picker]:
			for i in picker.item_count:
				if str(picker.get_item_metadata(i)) == str(route.source if picker == source_picker else route.destination): picker.select(i)
		detail.text = "Current route: %s → %s · %s" % [fleet.regions.catalog[route.source].name, fleet.regions.catalog[route.destination].name, route.status]
		confirm_button.text = "Cancel route"
	else:
		detail.text = "Cargo Ship capacity: %d units." % int(fleet.cargo.capability(ship_id).get("capacity", 50))
		confirm_button.text = "Confirm route"
	confirm_button.disabled = gated.size() < 2

func _confirm() -> void:
	if fleet.cargo.routes.has(ship_id):
		fleet.cargo.cancel(ship_id); hud.message("Cargo Ship route cancelled."); hud.close_panels(); return
	var source := str(source_picker.get_item_metadata(source_picker.selected)) if source_picker.selected >= 0 else ""
	var destination := str(destination_picker.get_item_metadata(destination_picker.selected)) if destination_picker.selected >= 0 else ""
	var error: String = fleet.cargo.assign(ship_id, source, destination)
	if not error.is_empty(): hud.message(error, true); return
	hud.message("Cargo Ship route assigned: %s → %s." % [fleet.regions.catalog[source].name, fleet.regions.catalog[destination].name]); hud.close_panels()
