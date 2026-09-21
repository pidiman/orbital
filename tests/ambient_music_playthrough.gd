extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	var music = game.get_node("AmbientMusic")
	checks.defaults = game.preferences.music_enabled and is_equal_approx(music.volume_linear, 0.3)
	await get_tree().create_timer(1.0).timeout
	checks.generates = music.playing and music.generated_frames > 0
	var peak: float = AudioServer.get_bus_peak_volume_left_db(0, 0)
	checks.audible_signal = peak > -80.0 and peak < -20.0
	game.hud.open_menu("Settings")
	await settle(2)
	game.hud.settings_toggles.music.button_pressed = false
	checks.off = not music.playing and music.playback == null
	game.hud.settings_toggles.music.button_pressed = true
	checks.on = music.playing and music.playback != null
	game.hud.settings_numbers.music_volume.value = 55
	checks.volume = is_equal_approx(music.volume_linear, 0.55)
	game.session_pause.set_paused(true)
	var frozen: float = music.clock
	await get_tree().create_timer(0.3).timeout
	checks.paused = music.clock == frozen and music.stream_paused
	game.session_pause.set_paused(false)
	await get_tree().create_timer(0.3).timeout
	checks.resumed = music.clock > frozen and not music.stream_paused
	var pref := preload("res://scripts/client_preferences.gd").new()
	pref.path = "user://music-test-%d.cfg" % Time.get_ticks_usec()
	pref.set_music(false, 0.47)
	var reload := preload("res://scripts/client_preferences.gd").new()
	reload.path = pref.path
	reload.load_preferences()
	checks.persisted = not reload.music_enabled and is_equal_approx(reload.music_volume, 0.47)
	DirAccess.remove_absolute(pref.path)
	var start: int = Time.get_ticks_usec()
	var maximum: float = 0.0
	# Exercise over a minute of synthesis, including all randomized layers.
	for i in range(1500000):
		var frame: Vector2 = music.next_frame()
		maximum = maxf(maximum, maxf(absf(frame.x), absf(frame.y)))
	var seconds: float = (Time.get_ticks_usec() - start) / 1000000.0
	checks.bounded_output = maximum < 0.25 and maximum > 0.02
	checks.layers_evolve = music.chord_at > 48.0 and music.ping_at > 60.0 and music.sweep_at > 55.0
	report("synthesis", {"seconds_for_68_seconds_audio": seconds, "maximum_amplitude": maximum, "bus_peak_db_at_default": peak})
	report("checks", checks)
	finish()
