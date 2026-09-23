extends Button
var art: String = "scout"
var role: String = ""
var status: String = "Idle"
var selected_ship: bool = false
var status_color: Color = Color("72dbcb")
var region_id: String = "home"
var planet: Dictionary = {}

func _ready() -> void:
	# Keep the tray dense while retaining a comfortable click target.
	custom_minimum_size = Vector2(84, 24)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	ModuleArt.draw_module(self, Vector2(12, 12), art, 0.20)
	draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(23, 16), role, HORIZONTAL_ALIGNMENT_LEFT, size.x - 39, 10, Color("dfebf2"))
	# Compact planet marker reuses the region planet palette used by RegionView.
	var surface: Color = Color(str(planet.get("surface", "4f9e9b")))
	var rim: Color = Color(str(planet.get("rim", "72dbcb")))
	var region_point := Vector2(size.x - 8, 12)
	draw_circle(region_point, 5, surface)
	draw_arc(region_point, 5, 0, TAU, 16, rim, 1.0, true)
	if region_id != "home":
		var bands: Color = Color(str(planet.get("bands", "6fb9ad")))
		bands.a = 0.55
		draw_line(region_point + Vector2(-3, -1), region_point + Vector2(3, -1), bands, 1.0, true)
		draw_line(region_point + Vector2(-2, 2), region_point + Vector2(2, 2), bands, 1.0, true)

	if selected_ship:
		draw_line(Vector2(9, 21), Vector2(size.x - 9, 21), Color("72dbcb"), 2)
