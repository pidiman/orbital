class_name ModuleArt
extends RefCounted

static func draw_module(canvas: CanvasItem, center: Vector2, kind: String, scale_factor: float = 1.0, opacity: float = 1.0) -> void:
	var ink := Color("c8dce7")
	var cyan := Color("71d8d0")
	var gold := Color("e8ba76")
	ink.a = opacity
	cyan.a = opacity
	gold.a = opacity
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	if kind == "solar":
		canvas.draw_line(Vector2(-22, 0), Vector2(22, 0), ink, 3)
		for x in [-24, 6]:
			canvas.draw_rect(Rect2(x, -20, 18, 40), Color(0.1, 0.35, 0.43, opacity))
			canvas.draw_rect(Rect2(x, -20, 18, 40), cyan, false, 1.3)
			for offset in [10, 20, 30]:
				canvas.draw_line(Vector2(x, -20 + offset), Vector2(x + 18, -20 + offset), Color(0.35, 0.7, 0.74, opacity * 0.6), 1)
			canvas.draw_line(Vector2(x + 9, -20), Vector2(x + 9, 20), cyan * Color(1, 1, 1, 0.5), 1)
		canvas.draw_rect(Rect2(-4, -12, 8, 24), ink)
	elif kind == "storage":
		canvas.draw_rect(Rect2(-21, -18, 42, 36), Color(0.23, 0.24, 0.27, opacity))
		canvas.draw_rect(Rect2(-21, -18, 42, 36), gold, false, 2)
		for x in [-12, 0, 12]:
			canvas.draw_line(Vector2(x, -16), Vector2(x, 16), gold * Color(1, 1, 1, 0.45), 2)
		canvas.draw_rect(Rect2(-7, -5, 14, 10), Color(0.08, 0.12, 0.18, opacity))
		canvas.draw_line(Vector2(-3, 0), Vector2(3, 0), gold, 2)
	elif kind == "mining_ship":
		var violet := Color(0.73, 0.65, 0.96, opacity)
		canvas.draw_rect(Rect2(-23, -22, 46, 44), Color(0.12, 0.16, 0.23, opacity))
		canvas.draw_rect(Rect2(-23, -22, 46, 44), violet, false, 1.0)
		var ship := PackedVector2Array([Vector2(0, -19), Vector2(13, 6), Vector2(18, 14), Vector2(5, 10), Vector2(0, 15), Vector2(-5, 10), Vector2(-18, 14), Vector2(-13, 6)])
		canvas.draw_colored_polygon(ship, ink)
		canvas.draw_rect(Rect2(-4, -5, 8, 9), violet)
		canvas.draw_line(Vector2(-4, 17), Vector2(4, 17), cyan, 3)
	elif kind == "scout":
		var blue := Color(0.55, 0.81, 0.96, opacity)
		var hull := PackedVector2Array([Vector2(0, -21), Vector2(22, 15), Vector2(0, 6), Vector2(-22, 15)])
		canvas.draw_colored_polygon(hull, blue)
		canvas.draw_circle(Vector2(0, -2), 4, ink)
		canvas.draw_arc(Vector2(0, -2), 27, PI * 1.15, PI * 1.85, 20, blue, 1.5, true)
	elif kind == "refinery":
		canvas.draw_rect(Rect2(-21, -19, 42, 38), Color(0.25, 0.20, 0.24, opacity))
		canvas.draw_rect(Rect2(-21, -19, 42, 38), gold, false, 2.0)
		canvas.draw_circle(Vector2(-7, 0), 9, Color(0.66, 0.5, 0.84, opacity))
		canvas.draw_circle(Vector2(9, 0), 9, gold)
		canvas.draw_circle(Vector2(-7, 0), 4, Color(0.16, 0.19, 0.24, opacity))
		canvas.draw_circle(Vector2(9, 0), 4, Color(0.16, 0.19, 0.24, opacity))
		canvas.draw_line(Vector2(-14, -13), Vector2(14, -13), ink, 2)
		canvas.draw_line(Vector2(-14, 13), Vector2(14, 13), ink, 2)
	else:
		var hull := PackedVector2Array([Vector2(-20, -15), Vector2(-13, -22), Vector2(13, -22), Vector2(20, -15), Vector2(20, 15), Vector2(13, 22), Vector2(-13, 22), Vector2(-20, 15)])
		canvas.draw_colored_polygon(hull, Color(0.18, 0.25, 0.32, opacity))
		var outline := hull.duplicate()
		outline.append(hull[0])
		canvas.draw_polyline(outline, ink, 2, true)
		canvas.draw_rect(Rect2(-13, -11, 26, 22), Color(0.07, 0.13, 0.2, opacity))
		for x in [-9, 3]:
			canvas.draw_rect(Rect2(x, -7, 6, 14), cyan)
		canvas.draw_line(Vector2(-12, 16), Vector2(12, 16), ink * Color(1, 1, 1, 0.5), 2)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		canvas.draw_circle(direction * 25, 2.3, ink)
	canvas.draw_set_transform(Vector2.ZERO)
