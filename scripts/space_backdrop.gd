extends Node2D
var stars: Array[Vector3] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8472
	for i in range(160):
		stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.4)))
	get_viewport().size_changed.connect(queue_redraw)

func _draw() -> void:
	var area: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, area), Color("080f1d"))
	for star: Vector3 in stars:
		draw_circle(Vector2(star.x * area.x, star.y * area.y), star.z, Color(0.6, 0.75, 0.85, star.z * 0.34))
	var earth := Vector2(area.x * 0.36, area.y + 730.0)
	var radius: float = 1000.0
	for i in range(14, 0, -1):
		draw_arc(earth, radius + i * 2.3, PI, TAU, 140, Color(0.12, 0.55, 0.85, 0.025), 5.0, true)
	draw_circle(earth, radius, Color("10273e"))
	draw_arc(earth, radius, PI, TAU, 140, Color("529aac"), 2.0, true)
	draw_arc(earth, radius - 6, PI, TAU, 140, Color("234c66"), 7.0, true)
	for i in range(6):
		draw_arc(earth + Vector2(-150, 50), radius - 90 - i * 48, 3.85, 5.52, 100, Color(0.23, 0.46, 0.58, 0.075), 20.0, true)
	# Abstract continental silhouettes; the Earth stays subordinate to the station.
	var land := PackedVector2Array([Vector2(-420, -880), Vector2(-310, -930), Vector2(-205, -940), Vector2(-160, -890), Vector2(-190, -840), Vector2(-90, -805), Vector2(-130, -750), Vector2(-230, -755), Vector2(-255, -680), Vector2(-325, -660), Vector2(-330, -735), Vector2(-425, -790)])
	for i in range(land.size()):
		land[i] += earth
	draw_colored_polygon(land, Color("193b4b"))

func _process(_delta: float) -> void:
	# Sky remains viewport-filling while the world camera pans.
	position = -get_viewport().get_canvas_transform().origin
