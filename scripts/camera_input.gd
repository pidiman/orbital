extends Node
# GUI gets the initial press first. World gestures are committed only on release.
var game: Node2D
var pending: bool = false
var dragging: bool = false
var start: Vector2
var last: Vector2
var region: String
var focused: bool = true
var pointer: Vector2 = Vector2(-1, -1)

func _ready() -> void:
	process_priority = 21
	get_viewport().mouse_exited.connect(func() -> void: pointer = Vector2(-1, -1))

func cancel_gesture() -> void:
	pending = false
	dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		cancel_gesture()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focused = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not game.hud.pointer_over_ui(event.position):
		pending = true
		dragging = false
		start = event.position
		last = start
		region = game.fleet.regions.current_region
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: pointer = event.position
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: cancel_gesture()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: cancel_gesture()
	if not pending: return
	if region != game.fleet.regions.current_region:
		cancel_gesture()
		return
	if event is InputEventMouseMotion:
		_drag_to(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drag_to(event.position)
		var click: bool = not dragging and not game.hud.pointer_over_ui(event.position)
		cancel_gesture()
		get_viewport().set_input_as_handled()
		if click: _click(start)

func _drag_to(point: Vector2) -> void:
	if not dragging and point.distance_to(start) > float(game.preferences.definitions.drag_threshold):
		dragging = true
		last = start
	if dragging:
		# Grab the field: contents follow the pointer in its drag direction.
		game.ship_camera.pan_pixels(last - point)
	last = point

func _click(point: Vector2) -> void:
	# Same precedence and original command handlers; no simulated input replay.
	if game.get_node("ShipInteraction").handle_click(point): return
	if game.asteroids.handle_click(point): return
	if game.debris.handle_click(point): return
	game.board.handle_click(point)

func edge_direction(point: Vector2) -> Vector2:
	if not game.preferences.values.edge_scrolling or pending or game.hud.has_open_panel() or game.hud.pointer_over_ui(point): return Vector2.ZERO
	var area := get_viewport().get_visible_rect()
	if not area.has_point(point): return Vector2.ZERO
	var band: float = float(game.preferences.definitions.edge_width)
	return Vector2(float(point.x >= area.end.x - band) - float(point.x < band), float(point.y >= area.end.y - band) - float(point.y < band)).normalized()

func _process(delta: float) -> void:
	if not focused or pending: return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner is TextEdit: return
	var zoom_direction := float(Input.is_physical_key_pressed(KEY_BRACKETRIGHT)) - float(Input.is_physical_key_pressed(KEY_BRACKETLEFT))
	if zoom_direction != 0.0:
		game.ship_camera.zoom_view(exp(zoom_direction * float(game.preferences.definitions.keyboard_zoom_rate) * minf(delta, 0.05)))
	if game.hud.has_open_panel(): return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if direction == Vector2.ZERO: direction = edge_direction(pointer)
	if direction != Vector2.ZERO:
		game.ship_camera.pan_pixels(direction.normalized() * float(game.preferences.definitions.pan_speed) * minf(delta, 0.05))
