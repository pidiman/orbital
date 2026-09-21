extends Button
var art: String = "scout"
var role: String = ""
var status: String = "Idle"
var selected_ship: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(132, 78)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	ModuleArt.draw_module(self, Vector2(28, 29), art, 0.48)
	draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(53, 25), role, HORIZONTAL_ALIGNMENT_LEFT, 75, 12, Color("dfebf2"))
	draw_string(font, Vector2(10, 64), status, HORIZONTAL_ALIGNMENT_LEFT, 114, 11, Color("72dbcb"))
	if selected_ship:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("72dbcb"), false, 2)
