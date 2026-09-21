extends "res://tests/outpost_playthrough.gd"
const Config = preload("res://scripts/dev_config.gd")

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	var before: Dictionary = game.persistence.snapshot()
	if not Config.DEBUG_MODE:
		checks.disabled_absent = not is_instance_valid(hud.dev_panel) and hud.root.find_child("DeveloperTools", true, false) == null
		await f9()
		checks.disabled_hotkey_inert = before == game.persistence.snapshot() and hud.active_menu.is_empty()
		await use(hud.menu_buttons.Build)
		checks.normal_hud_unchanged = hud.active_menu == "Build" and before == game.persistence.snapshot()
		report("checks", checks)
		finish()
		return
	var panel = hud.dev_panel
	checks.hidden_by_default = not panel.visible
	await f9()
	checks.hotkey_opens = panel.visible
	checks.open_is_read_only = before == game.persistence.snapshot()
	checks.separate_from_hud = not hud.menu_buttons.has("Developer") and hud.managed_panels.all(func(p: Control) -> bool: return not p.visible)
	await use(panel.buttons.materials)
	checks.materials_authority_and_capacity = game.model.materials == game.model.capacity
	await use(panel.buttons.minerals)
	checks.minerals_grant = game.model.minerals == 100 and hud.minerals_label.text == "100"
	checks.no_message_overlap = panel.get_global_rect().end.y < hud.footer.get_global_rect().position.y
	await f9()
	checks.hotkey_closes = not panel.visible
	await f9()
	save_frame("dev_panel")
	await use(panel.close_button)
	checks.close_button = not panel.visible
	var path: String = "user://orbital-dev-test-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	await use(hud.save_button)
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.model.add_minerals(1)
	await use(hud.load_button)
	checks.save_load_exact = expected == game.persistence.snapshot()
	checks.no_new_save_fields = before.keys() == expected.keys() and before.extensions.keys() == expected.extensions.keys()
	checks.load_hides_dev_panel = not panel.visible
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	report("checks", checks)
	finish()

func f9() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F9
	event.pressed = true
	get_viewport().push_input(event, true)
	await settle(2)
	event = InputEventKey.new()
	event.keycode = KEY_F9
	get_viewport().push_input(event, true)
	await settle(2)
