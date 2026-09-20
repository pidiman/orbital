extends Node2D
const Supply = preload("res://scripts/sector_supply.gd")
var supply: Supply
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
	var background := Backdrop.new()
	background.name = "SpaceBackdrop"
	add_child(background)
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
