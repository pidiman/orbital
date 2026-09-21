extends Control
var kind: int = 0
var tint: Color = Color.WHITE

func _ready() -> void:
	custom_minimum_size = Vector2(14, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _draw() -> void:
	match kind:
		0: # Cube.
			draw_polyline(PackedVector2Array([Vector2(7,1),Vector2(13,4),Vector2(13,10),Vector2(7,13),Vector2(1,10),Vector2(1,4),Vector2(7,1)]), tint, 1, true)
			draw_polyline(PackedVector2Array([Vector2(1,4),Vector2(7,7),Vector2(13,4)]), tint, 1, true)
			draw_line(Vector2(7,7),Vector2(7,13),tint,1,true)
		1: draw_colored_polygon(PackedVector2Array([Vector2(7,1),Vector2(12,7),Vector2(7,13),Vector2(2,7)]),tint)
		2: draw_colored_polygon(PackedVector2Array([Vector2(8,0),Vector2(2,8),Vector2(6,8),Vector2(5,14),Vector2(12,5),Vector2(8,5)]),tint)
		3:
			draw_rect(Rect2(3,3,8,8),tint,false,1)
			for offset in [4,7,10]:
				draw_line(Vector2(offset,0),Vector2(offset,3),tint)
				draw_line(Vector2(offset,11),Vector2(offset,14),tint)
				draw_line(Vector2(0,offset),Vector2(3,offset),tint)
				draw_line(Vector2(11,offset),Vector2(14,offset),tint)
		4: draw_polyline(PackedVector2Array([Vector2(4,1),Vector2(10,1),Vector2(13,7),Vector2(10,13),Vector2(4,13),Vector2(1,7),Vector2(4,1)]),tint,1,true)
