extends RefCounted
# Local presentation preferences, entirely separate from OrbitalSaveStore.
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/camera_controls.json"))
signal tuning_changed
var values: Dictionary = {}
var tuning: Dictionary = {}
var floating_defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/floating_resources.json"))
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
	tuning.clear()
	for option: Dictionary in definitions.get("tuning_options", []):
		if not config.has_section_key("supply_tuning", option.id): continue
		var value: Variant = config.get_value("supply_tuning", option.id)
		if (value is float or value is int) and is_finite(float(value)):
			tuning[option.id] = clampf(roundf(float(value)), option.min, option.max)
	tuning_changed.emit()

func set_value(id: String, value: Variant) -> Error:
	if not values.has(id) or typeof(value) != typeof(values[id]): return ERR_INVALID_PARAMETER
	values[id] = value
	if not enabled: return OK
	var config := ConfigFile.new()
	config.load(path) # Preserve unrelated/future preferences.
	for key: String in values: config.set_value("camera", key, values[key])
	return config.save(path)

func tuning_value(option: Dictionary) -> float:
	return float(tuning.get(option.id, floating_defaults.types[option.resource].get(option.fields[0], floating_defaults.lifetime_seconds)))

func apply_tuning(rules: Dictionary) -> void:
	for option: Dictionary in definitions.get("tuning_options", []):
		# Unset preferences preserve the exact JSON defaults, including min/max.
		for field: String in option.fields:
			rules.types[option.resource][field] = tuning[option.id] if tuning.has(option.id) else floating_defaults.types[option.resource].get(field, floating_defaults.lifetime_seconds)

func set_tuning(option: Dictionary, value: float) -> Error:
	if not is_finite(value): return ERR_INVALID_PARAMETER
	tuning[option.id] = clampf(roundf(value), option.min, option.max)
	tuning_changed.emit()
	if not enabled: return OK
	var config := ConfigFile.new()
	config.load(path)
	for id: String in tuning: config.set_value("supply_tuning", id, tuning[id])
	return config.save(path)
