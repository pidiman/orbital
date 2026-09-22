extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	var store = game.persistence
	var folder: String = "user://named-save-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	store.enabled = true
	var library := preload("res://scripts/save_library.gd").new(store, folder, folder.path_join("orbital-save.json"))
	library.legacy_path = folder.path_join("orbital-save.json")
	game.save_library = library
	game.save_dialogs.library = library
	store.path = library.slot_path("Autosave")
	library.mark_clean()
	await use(game.hud.menu_buttons.Menu)
	await use(game.hud.save_button)
	checks.dialog_pauses = game.get_tree().paused and game.save_dialogs.screen.visible
	var ticks: int = game.model.ticks
	await settle(5)
	checks.time_frozen = game.model.ticks == ticks
	game.save_dialogs.name_input.text = "First colony"
	await use(game.save_dialogs.body.get_child(2))
	checks.saved_and_closed = not game.get_tree().paused and not game.save_dialogs.screen.visible and FileAccess.file_exists(library.slot_path("First colony"))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	checks.version_unchanged = document.version == 2 and not document.has("save_name")
	game.save_dialogs.show_save()
	checks.prefilled = game.save_dialogs.name_input.text == "First colony"
	game.save_dialogs.close()
	game.model.materials += 17
	store.advance(10.0)
	checks.autosave_same_slot = store.path == library.slot_path("First colony") and not library.has_unsaved_changes()
	var saved_materials: int = game.model.materials
	game.model.materials += 1
	game.save_dialogs.show_load()
	checks.browser = library.entries().size() == 1 and library.entries()[0].detail.contains("Colony level")
	await settle(3)
	save_frame("named_save_browser")
	game.save_dialogs.request_load(library.entries()[0])
	checks.unsaved_confirmation = game.save_dialogs.body.get_child(0).text.contains("Unsaved progress")
	await use(game.save_dialogs.body.get_child(1))
	checks.loaded = game.model.materials == saved_materials and not game.get_tree().paused
	var restored_library := preload("res://scripts/save_library.gd").new(store, folder, folder.path_join("orbital-save.json"))
	checks.slot_survives_restart = restored_library.current_name == "First colony" and store.path == library.slot_path("First colony")
	game.save_dialogs.show_new()
	await use(game.save_dialogs.body.get_child(1))
	checks.fresh = game.model.materials == 130 and game.model.ships.is_empty() and game.fleet.research.researched.is_empty() and library.current_name.is_empty()
	report("fresh_state", {"materials": game.model.materials, "ships": game.model.ships.size(), "research": game.fleet.research.researched.size(), "name": library.current_name, "error": game.hud.status_label.text})
	checks.old_retained = FileAccess.file_exists(library.slot_path("First colony"))
	store.advance(10.0)
	checks.unnamed_autosave = FileAccess.file_exists(library.slot_path("Autosave")) and library.current_name.is_empty()
	game.save_dialogs.show_new()
	await use(game.save_dialogs.body.get_child(1))
	checks.new_preserves_autosave = store.path != library.slot_path("Autosave") and FileAccess.file_exists(library.slot_path("Autosave"))
	var legacy := FileAccess.open(library.legacy_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify(document))
	legacy.close()
	checks.legacy_listed = library.entries().any(func(entry: Dictionary) -> bool: return entry.name == "Legacy save")
	checks.legacy_load = library.load_entry({"name": "Legacy save", "path": library.legacy_path}).is_empty() and store.path == library.slot_path("Legacy save")
	game.save_dialogs.show_save()
	game.save_dialogs.name_input.text = "Typing"
	game.save_dialogs.name_input.caret_column = 6
	game.save_dialogs.name_input.deselect()
	var typed := InputEventKey.new()
	typed.keycode = KEY_SPACE
	typed.unicode = 32
	typed.pressed = true
	Input.parse_input_event(typed)
	await settle(2)
	typed.pressed = false
	Input.parse_input_event(typed)
	checks.dialog_accepts_typing = game.save_dialogs.name_input.text == "Typing "
	checks.space_does_not_resume = game.get_tree().paused
	game.save_dialogs.close()
	store.enabled = false
	for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	report("checks", checks)
	finish()
