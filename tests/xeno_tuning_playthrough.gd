extends "res://tests/outpost_playthrough.gd"

func edit_number(control: SpinBox, value: String) -> void:
	control.get_line_edit().grab_focus()
	control.get_line_edit().text = value
	control.get_line_edit().text_submitted.emit(value)
	control.apply()
	await settle(2)

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var prefs = game.preferences
	prefs.path = "user://xeno-tuning-test-%d.cfg" % OS.get_process_id()
	prefs.enabled = true
	var before: Dictionary = game.persistence.snapshot()
	var old_pieces: Dictionary = game.supply.floating.duplicate(true)
	await use(game.hud.menu_buttons.Menu)
	await use(game.hud.settings_button)
	checks.settings_excludes_tuning = not game.hud.settings_numbers.has("xeno_amount") and not game.hud.settings_numbers.has("xeno_lifetime") and not has_text(game.hud.settings_panel, "Xenocrystals") and not has_text(game.hud.settings_panel, "Amount per node") and not has_text(game.hud.settings_panel, "Lifetime (seconds)")
	await f9()
	var tuning: Dictionary = game.hud.dev_panel.tuning_numbers
	checks.defaults = tuning.xeno_amount.value == prefs.floating_defaults.types.xenocrystal.amount_min and tuning.xeno_lifetime.value == prefs.floating_defaults.types.xenocrystal.lifetime_seconds
	await edit_number(tuning.xeno_amount, "7")
	await edit_number(tuning.xeno_lifetime, "420")
	checks.live_rules = game.supply.floating_rules.types.xenocrystal.amount_min == 7 and game.supply.floating_rules.types.xenocrystal.amount_max == 7 and game.supply.floating_rules.types.xenocrystal.lifetime_seconds == 420
	checks.existing_unchanged = game.supply.floating == old_pieces
	checks.save_unchanged = game.persistence.snapshot() == before
	checks.weight_unchanged = game.supply.floating_rules.types.xenocrystal.weight == prefs.floating_defaults.types.xenocrystal.weight
	var spawned: bool = false
	for i in range(1000):
		game.supply._spawn_debris()
		var piece: Dictionary = game.supply.floating.home.pieces[game.supply.next_debris_id]
		if piece.resource == "xenocrystal":
			spawned = piece.amount == 7 and piece.remaining == 420
			break
	checks.new_node = spawned
	var reloaded = preload("res://scripts/client_preferences.gd").new()
	reloaded.path = prefs.path
	reloaded.load_preferences()
	var rules: Dictionary = reloaded.floating_defaults.duplicate(true)
	reloaded.apply_tuning(rules)
	checks.restart = rules.types.xenocrystal.amount_min == 7 and rules.types.xenocrystal.amount_max == 7 and rules.types.xenocrystal.lifetime_seconds == 420
	checks.controls_ranges = tuning.xeno_amount.min_value == 1 and tuning.xeno_amount.max_value == 10 and tuning.xeno_lifetime.min_value == 30 and tuning.xeno_lifetime.max_value == 600
	var missing = preload("res://scripts/client_preferences.gd").new()
	missing.path = prefs.path + ".missing"
	missing.load_preferences()
	var defaults: Dictionary = missing.floating_defaults.duplicate(true)
	missing.apply_tuning(defaults)
	checks.unset_defaults = defaults == missing.floating_defaults
	checks.panel_clear_footer = game.hud.dev_panel.get_global_rect().end.y < game.hud.footer.position.y
	save_frame("xeno_debug")
	prefs.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
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

func has_text(node: Node, expected: String) -> bool:
	if node is Label and node.text == expected: return true
	for child: Node in node.get_children():
		if has_text(child, expected): return true
	return false
