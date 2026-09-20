extends PanelContainer

var hud: CanvasLayer
var fleet: MiningFleet
var contact_picker: OptionButton
var ship_picker: OptionButton
var standing_label: Label
var inventory_label: Label
var mission_label: Label
var history_label: Label
var offer_rows: VBoxContainer
var offer_buttons: Dictionary = {}
var close_button: Button
var contact_signature: String = ""
var ship_signature: String = ""

func _ready() -> void:
	name = "AlienContacts"
	position = Vector2(40, 156)
	custom_minimum_size = Vector2(750, 480)
	add_theme_stylebox_override("panel", hud._style(Color("101e2d"), Color("9f8bb8")))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title: Label = hud._label(heading, "ALIEN CONTACTS / TRADE", 20, hud.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(heading, "Close")
	close_button.pressed.connect(hide)
	contact_picker = OptionButton.new()
	contact_picker.custom_minimum_size.y = 38
	column.add_child(contact_picker)
	contact_picker.item_selected.connect(func(_index: int) -> void: refresh())
	standing_label = hud._label(column, "", 14, hud.INK)
	standing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_label = hud._label(column, "", 14, hud.GOLD)
	ship_picker = OptionButton.new()
	ship_picker.custom_minimum_size.y = 38
	column.add_child(ship_picker)
	ship_picker.item_selected.connect(func(_index: int) -> void: refresh())
	mission_label = hud._label(column, "", 14, hud.CYAN)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 155
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	offer_rows = VBoxContainer.new()
	offer_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(offer_rows)
	for offer_id: String in fleet.diplomacy.offers:
		var button: Button = _button(offer_rows, "")
		button.custom_minimum_size.y = 68
		button.pressed.connect(func() -> void: _send(offer_id))
		offer_buttons[offer_id] = button
	history_label = hud._label(column, "", 13, hud.MUTED)
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._label(column, "Cargo paid at launch. Decommissioning returns cargo. Standing caps at 100.", 12, hud.MUTED)
	fleet.changed.connect(refresh)
	fleet.model.changed.connect(refresh)
	refresh()
	hide()

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", hud.INK)
	button.add_theme_color_override("font_disabled_color", hud.MUTED)
	button.add_theme_stylebox_override("normal", hud._style(Color("1a3041"), Color("365469")))
	button.add_theme_stylebox_override("hover", hud._style(Color("254452"), hud.CYAN))
	parent.add_child(button)
	return button

func selected_contact() -> String:
	return str(contact_picker.get_item_metadata(contact_picker.selected)) if contact_picker.selected >= 0 else ""

func open_contacts(ship_id: int = -1) -> void:
	hud.choose("")
	hud.sector_map.hide()
	refresh()
	if ship_id > 0:
		for index in range(ship_picker.item_count):
			if ship_picker.get_item_id(index) == ship_id:
				ship_picker.select(index)
	refresh()
	show()

func refresh() -> void:
	if not is_instance_valid(contact_picker):
		return
	var diplomacy: RefCounted = fleet.diplomacy
	var signature: String = str(diplomacy.contacts.keys())
	if signature != contact_signature:
		var previous: String = selected_contact()
		contact_signature = signature
		contact_picker.clear()
		for contact_id: String in diplomacy.contacts:
			var listed_contact: Dictionary = diplomacy.contacts[contact_id]
			contact_picker.add_item("%s · %s" % [listed_contact.name, diplomacy.factions[listed_contact.faction].name])
			var index: int = contact_picker.item_count - 1
			contact_picker.set_item_metadata(index, contact_id)
			if contact_id == previous:
				contact_picker.select(index)
	if str(fleet.model.ships) != ship_signature:
		ship_signature = str(fleet.model.ships)
		var previous: int = ship_picker.get_selected_id()
		ship_picker.clear()
		for ship_id: int in fleet.model.ships:
			var definition: Dictionary = fleet.model.ship_catalog[fleet.model.ships[ship_id]]
			if definition.has("trade"):
				ship_picker.add_item("%s #%d" % [definition.name, ship_id], ship_id)
		if ship_picker.item_count == 0:
			ship_picker.add_item("Build a Trade Ship in Ships", 0)
		for index in range(ship_picker.item_count):
			if ship_picker.get_item_id(index) == previous:
				ship_picker.select(index)
	var contact_id: String = selected_contact()
	var contact: Dictionary = diplomacy.contacts.get(contact_id, {})
	standing_label.text = "No contacts yet. Send a Scout to Echo pocket using the Sector map."
	if not contact.is_empty():
		var faction: Dictionary = diplomacy.factions[contact.faction]
		standing_label.text = "%s · Standing %d / 100\n%s" % [faction.name, faction.standing, diplomacy.faction_catalog.get(contact.faction, {}).get("description", "Alien contact")]
	var goods: Array[String] = []
	for good: String in diplomacy.goods_catalog:
		goods.append("%s: %d" % [diplomacy.goods_catalog[good].name, diplomacy.inventory.get(good, 0)])
	inventory_label.text = "   ·   ".join(goods)
	var ship_id: int = ship_picker.get_selected_id()
	var job: Dictionary = diplomacy.jobs.get(ship_id, {})
	mission_label.text = "Select an exchange below. Research and rare goods are held in inventory."
	if not job.is_empty():
		mission_label.text = "IN TRANSIT · %s · arrival in %ds" % [diplomacy.contacts[job.contact_id].name, job.remaining]
	elif fleet.unit_busy(ship_id):
		mission_label.text = "Ship is busy on another mission."
	for offer_id: String in offer_buttons:
		var offer: Dictionary = diplomacy.offers[offer_id]
		var button: Button = offer_buttons[offer_id]
		button.visible = not contact.is_empty() and contact.faction == offer.faction
		var error: String = fleet.trade_error(ship_id, contact_id, offer_id)
		button.disabled = not error.is_empty()
		button.text = "%s · %s\nReceive %s" % [offer.name, diplomacy.cost_text(offer.cost), diplomacy.reward_text(offer)]
		if int(offer.requires_standing) > 0:
			button.text += " · needs %d standing" % offer.requires_standing
		button.tooltip_text = error if not error.is_empty() else "Send cargo · %ds round trip" % fleet.model.ship_catalog[fleet.model.ships[ship_id]].trade.seconds
	var recent: Array[String] = []
	for index in range(maxi(0, diplomacy.history.size() - 3), diplomacy.history.size()):
		var entry: Dictionary = diplomacy.history[index]
		recent.append("#%d %s · %s · +%d standing" % [entry.id, str(entry.result).capitalize(), diplomacy.offers.get(entry.offer_id, {}).get("name", entry.offer_id), entry.standing_delta])
	history_label.text = "TRADE LOG\n" + ("\n".join(recent) if not recent.is_empty() else "No voyages completed yet.")

func _send(offer_id: String) -> void:
	var error: String = fleet.trade(ship_picker.get_selected_id(), selected_contact(), offer_id)
	hud.message("Trade Ship launched. Cargo secured; rewards on arrival." if error.is_empty() else error, not error.is_empty())
	refresh()
