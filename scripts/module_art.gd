class_name ModuleArt
extends RefCounted

static func draw_exhaust(canvas: CanvasItem, center: Vector2, kind: String, scale_factor: float, facing: float, accent: Color, config: Dictionary) -> void:
	var base_length: float = float(config.get("length", 18.0))
	var base_width: float = float(config.get("width", 5.0))
	var base_opacity: float = float(config.get("opacity", 0.78))
	var pulse_speed: float = float(config.get("pulse_speed", 8.0))
	var pulse_amount: float = clampf(float(config.get("pulse_amount", 0.22)), 0.0, 0.8)
	var phase: float = float(abs(kind.hash()) % 1000) * 0.01
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.001 * pulse_speed + phase) * pulse_amount
	var length: float = base_length * pulse
	var width: float = base_width * (0.9 + pulse * 0.1)
	var hot := Color("fff1c2", base_opacity)
	var core := accent
	core.a = base_opacity
	var outer := accent.darkened(0.2)
	outer.a = base_opacity * 0.72
	canvas.draw_set_transform(center, facing, Vector2.ONE * scale_factor)
	# Ship art points up, so +Y is the rear. Layered tapered polygons create
	# a small engine plume without adding particles or gameplay nodes.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-width, 15), Vector2(width, 15), Vector2(width * 0.55, 15 + length), Vector2(0, 15 + length * 1.12), Vector2(-width * 0.55, 15 + length)
	]), outer)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-width * 0.48, 15), Vector2(width * 0.48, 15), Vector2(width * 0.22, 15 + length * 0.72), Vector2(0, 15 + length * 0.86), Vector2(-width * 0.22, 15 + length * 0.72)
	]), core)
	canvas.draw_line(Vector2(0, 15), Vector2(0, 15 + length * 0.56), hot, maxf(1.0, width * 0.35), true)


static func draw_module(canvas: CanvasItem, center: Vector2, kind: String, scale_factor: float = 1.0, opacity: float = 1.0, facing: float = 0.0, tier: int = 1, connector_mask: int = 0, module_mask: int = 0) -> void:
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
	elif kind == "defense_turret":
		# The base is drawn with the module; ThreatField overlays the rotating barrel.
		var steel := Color("334858", opacity)
		var accent := Color("ef8b67", opacity)
		canvas.draw_circle(Vector2.ZERO, 18, Color("172733", opacity))
		canvas.draw_circle(Vector2.ZERO, 18, steel, false, 2.0, true)
		canvas.draw_circle(Vector2.ZERO, 9, Color("263b4a", opacity))
		canvas.draw_circle(Vector2.ZERO, 6, accent, false, 2.0, true)
	elif kind == "missile_silo":
		# Fixed launch rack: missiles steer after launch, so the silo remains
		# visually distinct from the turret's rotating barrel.
		var steel := Color("3d4b59", opacity)
		var red := Color("d97863", opacity)
		canvas.draw_rect(Rect2(-21, -20, 42, 40), Color("17232e", opacity))
		canvas.draw_rect(Rect2(-21, -20, 42, 40), steel, false, 2.5)
		for x in [-11, 0, 11]:
			canvas.draw_rect(Rect2(x - 4, -13, 8, 24), Color("253746", opacity))
			canvas.draw_circle(Vector2(x, -14), 3.5, red)
		canvas.draw_line(Vector2(-14, 16), Vector2(14, 16), red, 2.0, true)
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
		var sealed := Color("24414b", opacity)
		var inner := Color("b2e8df", opacity)
		var width: float = 14.0
		# Rounded central corridor chamber; arms are added only where a neighbor opens.
		canvas.draw_circle(Vector2.ZERO, 13, Color("0b2029", opacity))
		canvas.draw_circle(Vector2.ZERO, 13, tube, false, 2.5, true)
		var arms: Array[Dictionary] = [
			{"bit": 1, "rect": Rect2(-25, -width * 0.5, 18, width), "a": Vector2(-25, 0), "b": Vector2(-12, 0)},
			{"bit": 2, "rect": Rect2(7, -width * 0.5, 18, width), "a": Vector2(12, 0), "b": Vector2(25, 0)},
			{"bit": 4, "rect": Rect2(-width * 0.5, -25, width, 18), "a": Vector2(0, -25), "b": Vector2(0, -12)},
			{"bit": 8, "rect": Rect2(-width * 0.5, 7, width, 18), "a": Vector2(0, 12), "b": Vector2(0, 25)}
		]
		for arm: Dictionary in arms:
			var connected: bool = (connector_mask & int(arm.bit)) != 0
			if connected:
				# Only connected tube sides extend into an open passage. This is
				# what makes a straight tube visually different from a cross.
				canvas.draw_rect(arm.rect, Color("102a34", opacity))
				canvas.draw_line(arm.a, arm.b, inner, 3.0, true)
			else:
				# Seal the chamber at the inner edge; do not draw a dark arm.
				var direction: Vector2 = (arm.a - arm.b).normalized()
				var wall_center: Vector2 = arm.b + direction * 1.5
				var tangent: Vector2 = Vector2(-direction.y, direction.x) * (width * 0.5)
				canvas.draw_line(wall_center - tangent, wall_center + tangent, sealed, 4.0, true)
		# A neighboring non-tube gets a small hatch, without opening the corridor topology.
		for hatch: Dictionary in [{"bit": 1, "point": Vector2(-21, 0), "normal": Vector2.RIGHT}, {"bit": 2, "point": Vector2(21, 0), "normal": Vector2.LEFT}, {"bit": 4, "point": Vector2(0, -21), "normal": Vector2.DOWN}, {"bit": 8, "point": Vector2(0, 21), "normal": Vector2.UP}]:
			if (module_mask & int(hatch.bit)) != 0 and (connector_mask & int(hatch.bit)) == 0:
				canvas.draw_circle(hatch.point, 4, sealed)
				canvas.draw_line(hatch.point, hatch.point + hatch.normal * 4.0, inner, 2.0, true)
		for x in range(1, tier): canvas.draw_circle(Vector2(-6 + x * 6, 0), 1.5, inner)
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
	elif kind == "material_ship":
		# Salvage vessel: a broad amber scoop leads into a compact cargo hold,
		# with small rear thrusters. It shares the normal ship scale.
		var amber := Color("e8ad5b", opacity)
		var hull := Color("a9b7bd", opacity)
		var dark := Color("263746", opacity)
		var salvage_hull := PackedVector2Array([Vector2(0, -22), Vector2(10, -9), Vector2(9, 17), Vector2(0, 21), Vector2(-9, 17), Vector2(-10, -9)])
		canvas.draw_colored_polygon(salvage_hull, hull)
		canvas.draw_polyline(PackedVector2Array([Vector2(0, -22), Vector2(10, -9), Vector2(9, 17), Vector2(0, 21), Vector2(-9, 17), Vector2(-10, -9), Vector2(0, -22)]), amber, 2.0, true)
		# Wide forward scoop/claw for grabbing floating debris.
		canvas.draw_line(Vector2(-9, -9), Vector2(-18, -17), amber, 3, true)
		canvas.draw_line(Vector2(9, -9), Vector2(18, -17), amber, 3, true)
		canvas.draw_line(Vector2(-18, -17), Vector2(-12, -21), amber, 3, true)
		canvas.draw_line(Vector2(18, -17), Vector2(12, -21), amber, 3, true)
		canvas.draw_line(Vector2(-12, -21), Vector2(12, -21), amber, 2, true)
		# Compact cargo hold behind the scoop.
		canvas.draw_rect(Rect2(-7, -3, 14, 15), dark)
		canvas.draw_rect(Rect2(-7, -3, 14, 15), amber, false, 1.5)
		canvas.draw_line(Vector2(-5, 4), Vector2(5, 4), Color("f1c77e", opacity * 0.7), 1.5, true)
		# Twin rear thrusters.
		canvas.draw_circle(Vector2(-5, 20), 3, amber)
		canvas.draw_circle(Vector2(5, 20), 3, amber)
		canvas.draw_line(Vector2(-5, 22), Vector2(-5, 28), Color("f6d28d", opacity * 0.55), 2, true)
		canvas.draw_line(Vector2(5, 22), Vector2(5, 28), Color("f6d28d", opacity * 0.55), 2, true)
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
	if kind != "mining_ship" and kind != "xeno_mining_ship" and kind != "connector_tube" and kind != "material_ship":
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			canvas.draw_circle(direction * 25, 2.3, ink)
	canvas.draw_set_transform(Vector2.ZERO)
