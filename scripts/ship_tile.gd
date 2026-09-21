extends Button
var art: String = "scout"
var role: String = ""
var status: String = "Idle"
var selected_ship: bool = false
var status_color: Color = Color("72dbcb")

func _ready() -> void:
	custom_minimum_size = Vector2(98, 28)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	ModuleArt.draw_module(self, Vector2(15, 14), art, 0.23)
	draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(29, 18), role, HORIZONTAL_ALIGNMENT_LEFT, 68, 11, Color("dfebf2"))

	if selected_ship:
		draw_line(Vector2(12, 25), Vector2(size.x - 12, 25), Color("72dbcb"), 2)
