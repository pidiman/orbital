extends Button
var art: String = "scout"
var role: String = ""
var status: String = "Idle"
var selected_ship: bool = false
var status_color: Color = Color("72dbcb")
var region_id: String = "home"
var planet: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(98, 28)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	ModuleArt.draw_module(self, Vector2(15, 14), art, 0.23)
	draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(29, 18), role, HORIZONTAL_ALIGNMENT_LEFT, size.x - 49, 11, Color("dfebf2"))
	# Compact planet marker reuses the region planet palette used by RegionView.
	var surface: Color = Color(str(planet.get("surface", "4f9e9b")))
	var rim: Color = Color(str(planet.get("rim", "72dbcb")))
	var region_point := Vector2(size.x - 10, 14)
	draw_circle(region_point, 6, surface)
	draw_arc(region_point, 6, 0, TAU, 16, rim, 1.2, true)
	if region_id != "home":
		var bands: Color = Color(str(planet.get("bands", "6fb9ad")))
		bands.a = 0.55
		draw_line(region_point + Vector2(-4, -1), region_point + Vector2(4, -1), bands, 1.0, true)
		draw_line(region_point + Vector2(-3, 2), region_point + Vector2(3, 2), bands, 1.0, true)

	if selected_ship:
		draw_line(Vector2(12, 25), Vector2(size.x - 12, 25), Color("72dbcb"), 2)
