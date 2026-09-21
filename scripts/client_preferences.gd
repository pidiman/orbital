extends RefCounted
# Local presentation preferences, entirely separate from OrbitalSaveStore.
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/camera_controls.json"))
var values: Dictionary = {}
var path: String = "user://orbital-client.cfg"
var enabled: bool = true

func _init() -> void:
	for option: Dictionary in definitions.options: values[option.id] = option.default

func load_preferences() -> void:
	if not enabled: return
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	for option: Dictionary in definitions.options:
		var value: Variant = config.get_value("camera", option.id, option.default)
		if typeof(value) == typeof(option.default): values[option.id] = value

func set_value(id: String, value: Variant) -> Error:
	if not values.has(id) or typeof(value) != typeof(values[id]): return ERR_INVALID_PARAMETER
	values[id] = value
	if not enabled: return OK
	var config := ConfigFile.new()
	config.load(path) # Preserve unrelated/future preferences.
	for key: String in values: config.set_value("camera", key, values[key])
	return config.save(path)
