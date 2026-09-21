extends RefCounted
# Client-side slot metadata. Gameplay files retain the existing v2 document.
var store: OrbitalSaveStore
var directory: String = "user://saves"
var legacy_path: String = OrbitalSaveStore.DEFAULT_PATH
var current_name: String = ""
var autosave_name: String = "Autosave"
var index := ConfigFile.new()
var baseline: Dictionary = {}
var enabled: bool = false

func _init(value: OrbitalSaveStore, folder: String = "user://saves", legacy: String = OrbitalSaveStore.DEFAULT_PATH) -> void:
	store = value
	directory = folder
	legacy_path = legacy
	enabled = store.enabled
	if store.enabled:
		DirAccess.make_dir_recursive_absolute(directory)
		index.load(directory.path_join("slots.cfg"))
		current_name = str(index.get_value("session", "name", ""))
		autosave_name = str(index.get_value("session", "autosave", "Autosave"))
		store.path = slot_path(current_name if not current_name.is_empty() else autosave_name)
		if not FileAccess.file_exists(store.path) and FileAccess.file_exists(legacy_path): store.path = legacy_path
	store.saved.connect(_saved)

func slot_path(label: String) -> String:
	return directory.path_join(label.sha256_text() + ".json")

func mark_clean() -> void:
	baseline = store.snapshot()

func has_unsaved_changes() -> bool:
	return baseline != store.snapshot()

func _saved() -> void:
	if not enabled or not store.enabled: return
	var label: String = current_name if not current_name.is_empty() else autosave_name
	index.set_value("names", store.path.get_file(), label)
	index.set_value("session", "name", current_name)
	index.set_value("session", "autosave", autosave_name)
	index.save(directory.path_join("slots.cfg"))
	mark_clean()

func save_named(label: String) -> String:
	label = label.strip_edges().left(64)
	if label.is_empty(): return "Enter a save name."
	var previous: String = current_name
	var previous_path: String = store.path
	current_name = label
	store.path = slot_path(label)
	var error: String = store.save_game()
	if not error.is_empty():
		current_name = previous
		store.path = previous_path
	return error

func load_entry(entry: Dictionary) -> String:
	var previous_path: String = store.path
	var blocked: bool = store.autosave_blocked
	store.path = entry.path
	var error: String = store.load_game()
	if not error.is_empty():
		store.path = previous_path
		store.autosave_blocked = blocked
		return error
	current_name = entry.name
	store.path = slot_path(current_name)
	store.autosave_blocked = false
	index.set_value("session", "name", current_name)
	index.set_value("session", "autosave", autosave_name)
	index.save(directory.path_join("slots.cfg"))
	mark_clean()
	return ""

func unnamed() -> void:
	current_name = ""
	autosave_name = "Autosave"
	var number: int = 2
	while FileAccess.file_exists(slot_path(autosave_name)):
		autosave_name = "Autosave %d" % number
		number += 1
	store.path = slot_path(autosave_name)
	store.autosave_blocked = false
	store.autosave_elapsed = 0.0
	store.dirty = false
	index.set_value("session", "name", "")
	index.set_value("session", "autosave", autosave_name)
	if store.enabled: index.save(directory.path_join("slots.cfg"))
	baseline = {}

func suggested_name() -> String:
	if not current_name.is_empty(): return current_name
	var number: int = 1
	while FileAccess.file_exists(slot_path("Save %d" % number)): number += 1
	return "Save %d" % number

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".json"):
			result.append(_entry(directory.path_join(file), str(index.get_value("names", file, file.get_basename()))))
	if FileAccess.file_exists(legacy_path): result.append(_entry(legacy_path, "Legacy save"))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.modified > b.modified)
	return result

func _entry(file: String, label: String) -> Dictionary:
	var level: String = "Unknown colony"
	var handle := FileAccess.open(file, FileAccess.READ)
	if handle != null and handle.get_length() <= 8 * 1024 * 1024:
		var document: Variant = JSON.parse_string(handle.get_as_text())
		if document is Dictionary and document.get("state") is Dictionary:
			level = "Colony level %d" % int(document.state.get("station", {}).get("level", 1))
	var modified: int = FileAccess.get_modified_time(file)
	return {"path": file, "name": label, "modified": modified, "detail": "%s · %s" % [Time.get_datetime_string_from_unix_time(modified).replace("T", " ") + " UTC", level]}
