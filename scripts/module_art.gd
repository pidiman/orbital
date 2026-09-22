class_name ModuleArt
extends RefCounted

static func draw_module(canvas: CanvasItem, center: Vector2, kind: String, scale_factor: float = 1.0, opacity: float = 1.0, facing: float = 0.0, tier: int = 1) -> void:
	var ink := Color("c8dce7")
	var cyan := Color("71d8d0")
	var gold := Color("e8ba76")
	ink.a = opacity
	cyan.a = opacity
	gold.a = opacity
	canvas.draw_set_transform(center, facing, Vector2.ONE * scale_factor)
	if kind == "ship_dock":
		canvas.draw_rect(Rect2(-26, -22, 52, 44), Color(0.08, 0.16, 0.24, opacity))
		canvas.draw_line(Vector2(-26, 22), Vector2(-26, -22), ink, 3)
		canvas.draw_line(Vector2(-26, -22), Vector2(26, -22), ink, 3)
		canvas.draw_line(Vector2(26, -22), Vector2(26, 22), ink, 3)
		for x in [-13, 13]:
			canvas.draw_line(Vector2(x, -10), Vector2(x, 16), cyan, 2)
			canvas.draw_circle(Vector2(x, 20), 3, gold)
	elif kind == "teleport_gate":
		var violet := Color(0.73, 0.65, 0.96, opacity)
		canvas.draw_rect(Rect2(-27, -27, 54, 54), Color(0.08, 0.13, 0.22, opacity))
		canvas.draw_rect(Rect2(-27, -27, 54, 54), violet, false, 1)
		canvas.draw_circle(Vector2.ZERO, 22, violet, false, 3, true)
		canvas.draw_circle(Vector2.ZERO, 16, cyan, false, 1, true)
		for angle in [0.0, PI / 2, PI, PI * 1.5]:
			canvas.draw_line(Vector2.from_angle(angle) * 20, Vector2.from_angle(angle) * 26, ink, 3)
	elif kind == "research_lab":
		canvas.draw_rect(Rect2(-23, -23, 46, 46), Color(0.1, 0.2, 0.3, opacity))
		canvas.draw_rect(Rect2(-23, -23, 46, 46), cyan, false, 2)
		canvas.draw_circle(Vector2.ZERO, 6, gold)
		canvas.draw_arc(Vector2.ZERO, 15, 0, TAU, 32, cyan, 1.5, true)
		canvas.draw_line(Vector2(-17, 12), Vector2(17, -12), ink, 2)
	elif kind == "solar":
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
	elif kind == "material_depot":
		# Open industrial launch pad: visibly different from the enclosed Storage crate.
		var steel := Color("687f8b", opacity)
		canvas.draw_circle(Vector2.ZERO, 20, Color("172b36", opacity))
		canvas.draw_arc(Vector2.ZERO, 25, PI, TAU, 24, steel, 3, true)
		canvas.draw_line(Vector2(-22, 9), Vector2(22, 9), cyan, 3)
		canvas.draw_line(Vector2(-17, 9), Vector2(-17, -15), steel, 3)
		canvas.draw_line(Vector2(17, 9), Vector2(17, -15), steel, 3)
		canvas.draw_line(Vector2(17, -15), Vector2(27, -25), gold, 3)
		canvas.draw_circle(Vector2(27, -25), 4, gold)
		canvas.draw_line(Vector2(-10, 9), Vector2(-4, -2), cyan, 2)
		canvas.draw_line(Vector2(10, 9), Vector2(4, -2), cyan, 2)
	elif kind == "connector_tube":
		var tube := Color("4e9eaa", opacity)
		canvas.draw_rect(Rect2(-25, -11, 50, 22), Color(0.08, 0.18, 0.24, opacity))
		canvas.draw_rect(Rect2(-25, -11, 50, 22), tube, false, 2.5)
		canvas.draw_line(Vector2(-18, -6), Vector2(18, -6), Color("a5e4df", opacity), 2)
		canvas.draw_line(Vector2(-18, 6), Vector2(18, 6), Color("2c6675", opacity), 2)
		for x in [-18, 0, 18]: canvas.draw_line(Vector2(x, -9), Vector2(x, 9), tube.lightened(0.25), 2)
		for x in range(1, tier):
			canvas.draw_line(Vector2(-20 + x * 12, -12), Vector2(-20 + x * 12, 12), Color("d6f4e8", opacity), 1.5)
	elif kind == "cargo_ship":
		var violet := Color("b789e8", opacity)
		var dark := Color("3a2859", opacity)
		var hull := PackedVector2Array([Vector2(0, -38), Vector2(9, -25), Vector2(9, 28), Vector2(0, 36), Vector2(-9, 28), Vector2(-9, -25)])
		canvas.draw_colored_polygon(hull, dark)
		canvas.draw_polyline(PackedVector2Array([Vector2(0, -38), Vector2(9, -25), Vector2(9, 28), Vector2(0, 36), Vector2(-9, 28), Vector2(-9, -25), Vector2(0, -38)]), violet, 3, true)
		for y in [-20, 0, 20]:
			for side in [-1, 1]:
				canvas.draw_rect(Rect2(side * 21 - 8, y - 7, 16, 14), Color("7652a7", opacity))
				canvas.draw_rect(Rect2(side * 21 - 8, y - 7, 16, 14), violet, false, 1.5)
		canvas.draw_circle(Vector2(-5, 33), 4, Color("ff9be8", opacity * 0.8))
		canvas.draw_circle(Vector2(5, 33), 4, Color("ff9be8", opacity * 0.8))
		canvas.draw_line(Vector2(-5, 37), Vector2(-5, 46), Color("ffb4ee", opacity * 0.55), 3)
		canvas.draw_line(Vector2(5, 37), Vector2(5, 46), Color("ffb4ee", opacity * 0.55), 3)
	elif kind == "mining_ship" or kind == "xeno_mining_ship":
		var premium: bool = kind == "xeno_mining_ship"
		var accent := Color("62e4dc", opacity) if premium else Color("e8ad5b", opacity)
		var hull_color := Color("9aaebb", opacity) if not premium else Color("b8e5e0", opacity)
		var ship := PackedVector2Array([Vector2(0, -23), Vector2(9, -10), Vector2(11, 16), Vector2(4, 20), Vector2(0, 15), Vector2(-4, 20), Vector2(-11, 16), Vector2(-9, -10)])
		canvas.draw_colored_polygon(ship, hull_color)
		canvas.draw_polyline(PackedVector2Array([Vector2(0, -23), Vector2(9, -10), Vector2(11, 16), Vector2(4, 20), Vector2(0, 15), Vector2(-4, 20), Vector2(-11, 16), Vector2(-9, -10), Vector2(0, -23)]), accent, 2, true)
		canvas.draw_rect(Rect2(-5, -5, 10, 13), Color("273748", opacity))
		canvas.draw_line(Vector2(-10, 10), Vector2(-17, 19), accent, 3)
		canvas.draw_line(Vector2(10, 10), Vector2(17, 19), accent, 3)
		canvas.draw_circle(Vector2(0, -13), 3, accent)
	elif kind == "jump_ship":
		var jump := Color("6ce0d5", opacity)
		var heavy := Color("a9c2d5", opacity)
		var hull := PackedVector2Array([Vector2(0, -30), Vector2(15, -13), Vector2(17, 18), Vector2(7, 27), Vector2(-7, 27), Vector2(-17, 18), Vector2(-15, -13)])
		canvas.draw_colored_polygon(hull, heavy)
		canvas.draw_polyline(PackedVector2Array([Vector2(0, -30), Vector2(15, -13), Vector2(17, 18), Vector2(7, 27), Vector2(-7, 27), Vector2(-17, 18), Vector2(-15, -13), Vector2(0, -30)]), jump, 3, true)
		canvas.draw_rect(Rect2(-8, -8, 16, 19), Color("29364a", opacity))
		canvas.draw_circle(Vector2(0, 10), 8, Color("b18bea", opacity))
		canvas.draw_circle(Vector2(0, 10), 4, jump)
		canvas.draw_line(Vector2(-17, 4), Vector2(-28, 16), jump, 3)
		canvas.draw_line(Vector2(17, 4), Vector2(28, 16), jump, 3)
	elif kind == "trader":
		var hull := PackedVector2Array([Vector2(0, -22), Vector2(13, -8), Vector2(13, 18), Vector2(-13, 18), Vector2(-13, -8)])
		canvas.draw_colored_polygon(hull, ink)
		for x in [-23, 13]:
			canvas.draw_rect(Rect2(x, -5, 10, 23), gold)
		canvas.draw_rect(Rect2(-5, -12, 10, 9), cyan)
		canvas.draw_line(Vector2(-7, 22), Vector2(7, 22), gold, 3)
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
	if kind != "mining_ship" and kind != "xeno_mining_ship":
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			canvas.draw_circle(direction * 25, 2.3, ink)
	canvas.draw_set_transform(Vector2.ZERO)
