extends Node2D
const Regions = preload("res://scripts/region_model.gd")
var regions: Regions
var fleet: MiningFleet
var stars: Array[Vector2] = []
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9472
	for i in range(150):
		stars.append(Vector2(rng.randf(), rng.randf()))
	get_viewport().size_changed.connect(queue_redraw)
	regions.changed.connect(queue_redraw)
	fleet.changed.connect(queue_redraw)

# This projection is presentation only. Content coordinates never change on jump/resize.
static func project(point: Vector2, area: Vector2) -> Vector2:
	return Vector2(40, 160) + point * Vector2(maxf(300, area.x - 450) / 800.0, maxf(260, area.y - 310) / 600.0)

func _draw() -> void:
	if regions.primary_station_visible():
		return
	var area: Vector2 = get_viewport_rect().size
	draw_set_transform_matrix(get_canvas_transform().affine_inverse())
	var definition: Dictionary = regions.catalog[regions.current_region]
	var planet: Dictionary = regions.planets[definition.planet]
	draw_rect(Rect2(Vector2.ZERO, area), Color(planet.background))
	for index in range(stars.size()):
		draw_circle(stars[index] * area, 0.7 + (index % 3) * 0.3, Color(0.7, 0.77, 0.87, 0.45))
	var center := Vector2((area.x - 350) * 0.46, area.y * 0.83)
	var radius: float = minf(210, area.y * 0.25)
	for index in range(8, 0, -1):
		var glow := Color(planet.rim)
		glow.a = 0.035
		draw_circle(center, radius + index * 3, glow)
	draw_circle(center, radius, Color(planet.surface))
	draw_arc(center, radius, 0, TAU, 100, Color(planet.rim), 2, true)
	for index in range(5):
		var band := Color(planet.bands)
		band.a = 0.38
		var curve := PackedVector2Array()
		for step in range(65):
			var x: float = lerpf(-radius, radius, step / 64.0)
			var y: float = radius * (-0.48 + index * 0.18) + 0.12 * radius * sin(step / 64.0 * PI)
			var offset := Vector2(x, y)
			if offset.length() < radius - 10:
				curve.append(center + offset)
		if curve.size() > 1:
			draw_polyline(curve, band, 10, true)
	draw_set_transform(Vector2.ZERO)
	for content: Dictionary in regions.records[regions.current_region].contents:
		if content.type != "anomaly":
			continue
		var point: Vector2 = project(content.position, area)
		var tint := Color(definition.visuals_hint.accent)
		draw_arc(point, 15, 0, TAU, 6, tint, 2, true)
		draw_circle(point, 4, tint)
		draw_string(font, point + Vector2(-40, 30), content.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		draw_string(font, point + Vector2(-40, 45), "Studied · +%d %s" % [content.amount, str(content.good).capitalize()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)

	var world: RefCounted = fleet.model.locations
	var outpost_id: String = world.outpost_at(regions.current_region, world.rules.primary_station.owner)
	if not outpost_id.is_empty():
		var station: Dictionary = world.stations[outpost_id]
		var structure: Dictionary = world.structures[station.structure_id]
		var outpost: Dictionary = world.outpost_catalog[station.kind]
		var point: Vector2 = project(structure.position, area)
		ModuleArt.draw_module(self, point, outpost.art, 0.85)
		draw_string(font, point + Vector2(-75, 40), "%s · %d Minerals" % [outpost.name, station.inventory.minerals], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(outpost.color))

func _process(_delta: float) -> void:
	if visible: queue_redraw()
