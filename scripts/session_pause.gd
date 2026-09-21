extends CanvasLayer
# Session-only engine pause. Gameplay and its HUD remain pausable.
var game: Node2D
var button: Button
var shade: ColorRect
var indicator: Label
var pressed_close: Button
var pressed_pause: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	indicator = Label.new()
	indicator.text = "PAUSED · Space to resume"
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	indicator.offset_left = -240
	indicator.offset_right = 240
	indicator.offset_top = 185
	indicator.add_theme_font_size_override("font_size", 24)
	indicator.add_theme_color_override("font_outline_color", Color("09111e"))
	indicator.add_theme_constant_override("outline_size", 5)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(indicator)
	button = Button.new()
	button.position = Vector2(220, 20)
	button.size = Vector2(44, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(toggle)
	add_child(button)
	game.persistence.restored.connect(func() -> void: set_paused(false))
	set_paused(false)

func toggle() -> void:
	set_paused(not get_tree().paused)

func set_paused(value: bool) -> void:
	game.camera_input.cancel_gesture()
	if value:
		_dismiss_popups(game.hud)
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null: focus.release_focus()
	get_tree().paused = value
	shade.visible = value
	indicator.visible = value
	button.text = "▶" if value else "Ⅱ"
	button.tooltip_text = "Resume · Space" if value else "Pause · Space"
	pressed_close = null
	pressed_pause = false

func _dismiss_popups(node: Node) -> void:
	if node is Popup: node.hide()
	for child: Node in node.get_children(): _dismiss_popups(child)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.echo: toggle()
		get_viewport().set_input_as_handled()
		return
	if not get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		game.hud.close_panels()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(event.position, event.pressed)
	elif event is InputEventScreenTouch:
		_pointer(event.position, event.pressed)
	# No gameplay GUI, shortcuts, camera gestures or world clicks while paused.
	get_viewport().set_input_as_handled()

func _pointer(point: Vector2, down: bool) -> void:
	if down:
		pressed_pause = button.get_global_rect().has_point(point)
		pressed_close = null
		var close_buttons: Array = game.hud.panel_closes.values()
		if is_instance_valid(game.hud.dev_panel): close_buttons.append(game.hud.dev_panel.close_button)
		for close: Button in close_buttons:
			if close.is_visible_in_tree() and close.get_global_rect().has_point(point): pressed_close = close
	else:
		if pressed_pause and button.get_global_rect().has_point(point):
			set_paused(false)
		elif is_instance_valid(pressed_close) and pressed_close.is_visible_in_tree() and pressed_close.get_global_rect().has_point(point):
			game.hud.close_panels()
		pressed_pause = false
		pressed_close = null
