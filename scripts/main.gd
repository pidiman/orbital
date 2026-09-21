extends Node2D
const SaveStore = preload("res://scripts/save_store.gd")
var session_pause: CanvasLayer
var persistence: SaveStore
var save_path: String = SaveStore.DEFAULT_PATH
# Used only by isolated restart probes; never exposed as a gameplay control.
var verification_persistence: bool = false
const Supply = preload("res://scripts/region_supply.gd")
var supply: Supply
const RegionView = preload("res://scripts/region_view.gd")
var region_view: Node2D
var background: Node2D
const Backdrop = preload("res://scripts/space_backdrop.gd")
const Board = preload("res://scripts/station_board.gd")
const Debris = preload("res://scripts/debris_field.gd")
const Clock = preload("res://scripts/resource_clock.gd")
const Asteroids = preload("res://scripts/asteroid_field.gd")
const Fleet = preload("res://scripts/mining_fleet.gd")
const HUD = preload("res://scripts/hud.gd")
var fleet: Fleet
var asteroids: Node2D
var mineral_count: int = 0
var model: StationModel
var board: Node2D
var debris: Node2D
var preferences: RefCounted
var camera_input: Node
var ship_motion: Node
var hud: CanvasLayer
var ship_camera: Camera2D
var module_count: int = 1
var material_count: int = 40
var power_balance: int = 1
var colony_level: int = 1

func _ready() -> void:
	model = StationModel.new()
	fleet = Fleet.new(model)
	model.ticked.connect(fleet.tick)
	preferences = preload("res://scripts/client_preferences.gd").new()
	preferences.enabled = not OS.get_cmdline_args().has("--summer-verify") and not get_tree().root.has_node("SummerProbe")
	preferences.load_preferences()
	var floating_configuration: Dictionary = preferences.floating_defaults.duplicate(true)
	preferences.apply_tuning(floating_configuration)
	supply = Supply.new(model, fleet, -1, {}, floating_configuration)
	preferences.tuning_changed.connect(func() -> void: preferences.apply_tuning(supply.floating_rules))
	persistence = SaveStore.new(model, fleet, supply)
	# Disposable playtests must never read or overwrite the player's checkpoint.
	persistence.path = save_path
	persistence.enabled = verification_persistence or (not OS.get_cmdline_args().has("--summer-verify") and not get_tree().root.has_node("SummerProbe"))
	var resume_error: String = ""
	var resumed: bool = false
	if persistence.enabled and FileAccess.file_exists(persistence.path):
		resume_error = persistence.load_game()
		resumed = resume_error.is_empty()
	process_priority = 1000
	get_tree().auto_accept_quit = false
	background = Backdrop.new()
	background.name = "SpaceBackdrop"
	add_child(background)
	region_view = RegionView.new()
	region_view.name = "RegionView"
	region_view.regions = fleet.regions
	region_view.fleet = fleet
	add_child(region_view)
	board = Board.new()
	board.name = "StationBoard"
	board.model = model
	add_child(board)
	debris = Debris.new()
	debris.name = "DebrisField"
	debris.supply = supply
	add_child(debris)
	asteroids = Asteroids.new()
	asteroids.name = "AsteroidField"
	asteroids.supply = supply
	asteroids.fleet = fleet
	asteroids.board = board
	add_child(asteroids)
	var collectors := preload("res://scripts/material_ship_view.gd").new()
	collectors.name = "MaterialShips"
	collectors.supply = supply
	collectors.board = board
	add_child(collectors)
	var clock := Clock.new()
	clock.name = "ResourceClock"
	clock.model = model
	clock.supply = supply
	add_child(clock)
	ship_motion = preload("res://scripts/ship_motion.gd").new()
	ship_motion.name = "ShipMotion"
	ship_motion.game = self
	add_child(ship_motion)
	ship_camera = preload("res://scripts/ship_focus.gd").new()
	ship_camera.name = "ShipCamera"
	ship_camera.game = self
	add_child(ship_camera)
	hud = HUD.new()
	hud.name = "HUD"
	hud.model = model
	hud.fleet = fleet
	add_child(hud)
	var ship_interaction := preload("res://scripts/ship_interaction.gd").new()
	ship_interaction.name = "ShipInteraction"
	ship_interaction.game = self
	add_child(ship_interaction)
	camera_input = preload("res://scripts/camera_input.gd").new()
	camera_input.name = "CameraInput"
	camera_input.game = self
	add_child(camera_input)
	fleet.hauling.notice.connect(hud.message)
	supply.collection.notice.connect(hud.message)
	hud.tool_selected.connect(_select_tool)
	hud.ship_assignment_requested.connect(func(ship_id: int) -> void: asteroids.selected_ship = ship_id)
	board.module_selected.connect(hud.inspect_module)
	board.requested_build.connect(_build)
	debris.salvaged.connect(hud.show_salvage)
	debris.full_storage.connect(func() -> void: hud.message("Storage full. Build a module or add Storage capacity.", true))
	asteroids.notice.connect(hud.message)
	asteroids.minerals_delivered.connect(hud.show_minerals)
	model.refined.connect(hud.show_refining)
	model.changed.connect(_sync_readouts)
	persistence.restored.connect(_restore_presentation)
	persistence.failed.connect(_save_failure)
	hud.save_requested.connect(_manual_save)
	hud.load_requested.connect(_manual_load)
	fleet.regions.location_changed.connect(_update_region_view)
	fleet.outposts.changed.connect(_update_region_view)
	fleet.regions.discovered.connect(_region_discovered)
	session_pause = preload("res://scripts/session_pause.gd").new()
	session_pause.game = self
	session_pause.name = "SessionPause"
	add_child(session_pause)
	_update_region_view()
	_sync_readouts()
	if resumed:
		hud.message(persistence.migration_notice if not persistence.migration_notice.is_empty() else "Colony restored from your latest checkpoint.", false, 12.0)
	elif not resume_error.is_empty():
		hud.message(resume_error, true, 12.0)

func _build(world_position: Vector2) -> void:
	var previous_level: int = model.level
	var error: String = board.model.build(world_position, board.selected)
	if not error.is_empty():
		hud.message(error, true)
	elif previous_level == model.level:
		hud.message("%s connected. Your station is growing." % model.catalog[board.selected].name)

func _sync_readouts() -> void:
	module_count = model.modules.size()
	material_count = model.materials
	mineral_count = model.minerals
	power_balance = model.power_balance()
	colony_level = model.level

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		hud.choose("")

func _select_tool(kind: String) -> void:
	board.selected = kind
	asteroids.selected_ship = -1

func _process(delta: float) -> void:
	persistence.advance(delta)

func _manual_save() -> void:
	var error: String = persistence.save_game()
	hud.message("Colony saved to user://orbital-save.json" if error.is_empty() else error, not error.is_empty())

func _manual_load() -> void:
	var error: String = persistence.load_game()
	hud.message((persistence.migration_notice if not persistence.migration_notice.is_empty() else "Latest checkpoint restored.") if error.is_empty() else error, not error.is_empty(), 12.0)

func _save_failure(message: String) -> void:
	if is_instance_valid(hud):
		hud.message(message, true, 8.0)

func _restore_presentation() -> void:
	hud.hauling_assignment = -1
	board.selected = ""
	board.inspected_position = Vector2.INF
	board.pulses.clear()
	asteroids.selected_ship = -1
	asteroids.rocks.clear()
	asteroids._sync_view()
	ship_motion.reset()
	ship_motion.advance_visual(0.0)
	debris._sync_view()
	hud.reset_after_load()
	_update_region_view()
	_sync_readouts()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_on_exit()
		get_tree().quit()

func _exit_tree() -> void:
	_save_on_exit()

func _save_on_exit() -> void:
	if persistence != null and persistence.enabled and not persistence.autosave_blocked:
		persistence.save_game()

func _update_region_view() -> void:
	ship_camera.reset_view(true)
	var home: bool = fleet.regions.primary_station_visible()
	background.visible = home
	region_view.visible = not home
	region_view.queue_redraw()
	var outpost: String = model.locations.outpost_at(fleet.regions.current_region, model.locations.rules.primary_station.owner)
	board.model = model if outpost.is_empty() else model.scoped_station(outpost)
	board.grid_radius = (board.model.build_grid_dimensions() - Vector2i.ONE) / 2
	board.placement_cache_key = ""
	board.visible = home or not outpost.is_empty()
	board.set_process_unhandled_input(board.visible)
	debris.visible = true
	debris.set_process_unhandled_input(true)
	board.selected = ""
	board.inspected_position = Vector2.INF
	asteroids.selected_ship = -1
	asteroids.rocks.clear()
	asteroids._sync_view()
	debris._sync_view()
	hud.choose("")
	hud.selected_position = Vector2.INF
	hud.refresh()

func _region_discovered(region_id: String) -> void:
	hud.message("%s surveyed. Deposits and anomalies recorded; ship travel requires gates at both ends." % fleet.regions.catalog[region_id].name, false, 8.0)
