extends CanvasLayer
var game: Node
var library: RefCounted
var screen: ColorRect
var body: VBoxContainer
var name_input: LineEdit
var prior_pause: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	screen = ColorRect.new()
	screen.color = Color(0.01, 0.025, 0.05, 0.85)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	screen.hide()

func _input(event: InputEvent) -> void:
	if screen.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func begin(title: String) -> void:
	if not screen.visible:
		prior_pause = get_tree().paused
		game.hud.close_panels()
		game.session_pause.set_paused(true)
		game.session_pause.modal_active = true
		game.session_pause.indicator.text = "PAUSED"
		game.session_pause.button.disabled = true
		screen.show()
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 22)
	body.add_child(heading)

func action(label: String, callback: Callable, parent: Node = body) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func close() -> void:
	screen.hide()
	game.session_pause.modal_active = false
	game.session_pause.button.disabled = false
	game.session_pause.set_paused(prior_pause)

func show_save() -> void:
	begin("Save colony")
	name_input = LineEdit.new()
	name_input.max_length = 64
	name_input.text = library.suggested_name()
	name_input.custom_minimum_size.y = 44
	body.add_child(name_input)
	action("Save", confirm_save)
	action("Cancel", close)
	name_input.text_submitted.connect(func(_text: String) -> void: confirm_save())
	name_input.grab_focus()
	name_input.select_all()

func confirm_save() -> void:
	var label: String = name_input.text.strip_edges()
	if label != library.current_name and FileAccess.file_exists(library.slot_path(label)):
		confirm("Replace “%s”?" % label, func() -> void: _save(label))
	else: _save(label)

func _save(label: String) -> void:
	var error: String = library.save_named(label)
	if error.is_empty():
		close()
		game.hud.message("Saved “%s”." % library.current_name)
	else:
		var warning := Label.new()
		warning.text = error
		body.add_child(warning)

func show_load() -> void:
	begin("Load colony")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 300)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var entries: Array = library.entries()
	for entry: Dictionary in entries:
		action(entry.name + "\n" + entry.detail, func() -> void: request_load(entry), list)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No saved colonies yet."
		list.add_child(empty)
	action("Cancel", close)

func request_load(entry: Dictionary) -> void:
	if library.has_unsaved_changes():
		confirm("Load this save? Unsaved progress will be lost.", func() -> void: _load(entry))
	else: _load(entry)

func _load(entry: Dictionary) -> void:
	var error: String = library.load_entry(entry)
	if error.is_empty():
		prior_pause = false
		close()
		game.hud.message("Loaded “%s”." % entry.name)
	else:
		game.session_pause.set_paused(true)
		begin("Could not load colony")
		var warning := Label.new()
		warning.text = error
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(warning)
		action("Back", show_load)
		action("Cancel", close)

func confirm(message: String, callback: Callable) -> void:
	begin(message)
	action("Confirm", callback)
	action("Cancel", close)

func show_new() -> void:
	confirm("Start a new game? Unsaved progress will be lost.", func() -> void:
		var station := StationModel.new()
		var fleet := preload("res://scripts/mining_fleet.gd").new(station)
		var rules: Dictionary = game.preferences.floating_defaults.duplicate(true)
		game.preferences.apply_tuning(rules)
		var supply := preload("res://scripts/region_supply.gd").new(station, fleet, -1, {}, rules)
		var fresh := OrbitalSaveStore.new(station, fleet, supply)
		fresh.enabled = false
		var error: String = game.persistence.restore(fresh.snapshot())
		if error.is_empty(): library.unnamed()
		prior_pause = false
		close()
		game.hud.message("New colony started." if error.is_empty() else error, not error.is_empty()))
