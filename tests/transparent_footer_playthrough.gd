extends "res://tests/menu_controls_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	var before: Dictionary = game.persistence.snapshot()
	hud.message("Material Ship waiting — storage full", false, 30)
	await settle(2)
	checks.height_30 = is_equal_approx(hud.footer.size.y, 30)
	checks.transparent = hud.footer.get_theme_stylebox("panel") is StyleBoxEmpty
	checks.centered = is_equal_approx(hud.status_label.get_global_rect().get_center().x, hud.footer.get_global_rect().get_center().x)
	checks.no_overlap = not hud.status_label.get_global_rect().intersects(hud.grid_controls.get_global_rect())
	checks.outline = hud.status_label.get_theme_constant("outline_size") == 3 and hud.zoom_label.get_theme_constant("outline_size") == 3
	for caption: String in hud.grid_buttons:
		checks[caption + " transparent"] = hud.grid_buttons[caption].get_theme_stylebox("normal") is StyleBoxEmpty
	save_frame("transparent_footer")
	await use(hud.menu_buttons.Menu)
	await use(hud.settings_button)
	await use(hud.settings_toggles.show_grid_controls)
	checks.hidden = not hud.grid_controls.visible
	await use(hud.settings_toggles.show_grid_controls)
	checks.shown = hud.grid_controls.visible
	hud.close_panels()
	await use(hud.grid_buttons["+"])
	checks.zoom = game.ship_camera.zoom.x > 1.0
	checks.game_unchanged = game.persistence.snapshot() == before
	get_window().content_scale_size = Vector2i(960, 720)
	get_window().size = Vector2i(960, 720)
	await settle(4)
	checks.small_height = is_equal_approx(hud.footer.size.y, 30)
	checks.small_no_overlap = not hud.status_label.get_global_rect().intersects(hud.grid_controls.get_global_rect())
	save_frame("transparent_footer_small")
	report("checks", checks)
	finish()
