extends Node2D
const SaveStore = preload("res://scripts/save_store.gd")
var persistence: SaveStore
var save_path: String = SaveStore.DEFAULT_PATH
# Used only by isolated restart probes; never exposed as a gameplay control.
var verification_persistence: bool = false
const Supply = preload("res://scripts/sector_supply.gd")
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
var hud: CanvasLayer
var module_count: int = 1
var material_count: int = 40
var power_balance: int = 1
var colony_level: int = 1

func _ready() -> void:
	model = StationModel.new()
	fleet = Fleet.new(model)
	model.ticked.connect(fleet.tick)
	supply = Supply.new(model, fleet)
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
	hud = HUD.new()
	hud.name = "HUD"
	hud.model = model
	hud.fleet = fleet
	add_child(hud)
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
	fleet.regions.discovered.connect(_region_discovered)
	_update_region_view()
	_sync_readouts()
	if resumed:
		hud.message("Colony restored from your latest checkpoint.", false, 7.0)
	elif not resume_error.is_empty():
		hud.message(resume_error, true, 12.0)

func _build(world_position: Vector2) -> void:
	var previous_level: int = model.level
	var error: String = model.build(world_position, board.selected)
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
	hud.message("Latest checkpoint restored." if error.is_empty() else error, not error.is_empty())

func _save_failure(message: String) -> void:
	if is_instance_valid(hud):
		hud.message(message, true, 8.0)

func _restore_presentation() -> void:
	board.selected = ""
	board.inspected_position = Vector2.INF
	board.pulses.clear()
	asteroids.selected_ship = -1
	asteroids.rocks.clear()
	asteroids._sync_view()
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
	var home: bool = fleet.regions.primary_station_visible()
	background.visible = home
	region_view.visible = not home
	region_view.queue_redraw()
	board.visible = home
	board.set_process_unhandled_input(home)
	debris.visible = home
	debris.set_process_unhandled_input(home)
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
	hud.message("%s surveyed. Jump unlocked; deposits and anomaly findings recorded." % fleet.regions.catalog[region_id].name, false, 8.0)
