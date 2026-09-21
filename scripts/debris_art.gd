extends RefCounted
# Data-authored 2D primitives; adding a variant requires only JSON edits.
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/material_debris.json"))

func _init() -> void:
	for shapes: Array in definitions.variants.values():
		for shape: Dictionary in shapes:
			if shape.has("points"):
				var points := PackedVector2Array()
				for point: Array in shape.points: points.append(Vector2(point[0], point[1]))
				shape.points = points

func draw_variant(canvas: Node2D, id: String) -> void:
	for shape: Dictionary in definitions.variants.get(id, []):
		match shape.kind:
			"polygon":
				canvas.draw_colored_polygon(shape.points, Color(definitions.palette[shape.fill]))
				var outline: PackedVector2Array = shape.points.duplicate()
				outline.append(outline[0])
				canvas.draw_polyline(outline, Color(definitions.palette[shape.stroke]), shape.width, true)
			"line": canvas.draw_polyline(shape.points, Color(definitions.palette[shape.color]), shape.width, true)
			"circle": canvas.draw_circle(Vector2(shape.center[0], shape.center[1]), shape.radius, Color(definitions.palette[shape.color]))
