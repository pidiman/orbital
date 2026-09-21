extends AudioStreamPlayer
# Non-spatial, session-only synthesis. Never uses gameplay RNG or save state.
const RATE: float = 22050.0
const CHORDS: Array = [[0, 7, 14], [0, 5, 12], [-2, 5, 12], [-5, 2, 9], [0, 7, 10]]
var preferences: RefCounted
var rng := RandomNumberGenerator.new()
var playback: AudioStreamGeneratorPlayback
var phases := PackedFloat64Array([0.0, 0.0, 0.0])
var frequencies := PackedFloat64Array([55.0, 82.4069, 123.4708])
var targets := PackedFloat64Array([55.0, 82.4069, 123.4708])
var clock: float = 0.0
var chord_at: float = 0.0
var ping_at: float = 3.0
var sweep_at: float = 15.0
var ping_age: float = 20.0
var ping_frequency: float = 440.0
var ping_phase: float = 0.0
var ping_pan: float = 0.0
var sweep_age: float = 20.0
var sweep_phase: float = 0.0
var chord: int = 0
var generated_frames: int = 0

func _ready() -> void:
	rng.randomize()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = RATE
	generator.buffer_length = 0.2
	stream = generator
	preferences.music_changed.connect(apply_preferences)
	apply_preferences()

func apply_preferences() -> void:
	volume_linear = preferences.music_volume
	if preferences.music_enabled:
		if not playing:
			play()
			playback = get_stream_playback()
	else:
		stop()
		playback = null

func _process(_delta: float) -> void:
	if playback == null: return
	var count: int = playback.get_frames_available()
	if count == 0: return
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in range(count): frames[i] = next_frame()
	playback.push_buffer(frames)
	generated_frames += count

func next_frame() -> Vector2:
	const STEP: float = 1.0 / RATE
	clock += STEP
	if clock >= chord_at:
		chord = (chord + rng.randi_range(1, CHORDS.size() - 1)) % CHORDS.size()
		for voice in range(3): targets[voice] = 55.0 * pow(2.0, float(CHORDS[chord][voice]) / 12.0)
		chord_at = clock + rng.randf_range(24.0, 48.0)
	if clock >= ping_at:
		ping_frequency = 220.0 * pow(2.0, float(CHORDS[chord][rng.randi_range(0, 2)] + 12) / 12.0)
		ping_age = 0.0
		ping_phase = 0.0
		ping_pan = rng.randf_range(-0.55, 0.55)
		ping_at = clock + rng.randf_range(5.0, 14.0)
	if clock >= sweep_at:
		sweep_age = 0.0
		sweep_at = clock + rng.randf_range(28.0, 55.0)
	var left: float = 0.0
	var right: float = 0.0
	for voice in range(3):
		frequencies[voice] = lerpf(frequencies[voice], targets[voice], STEP * 0.22)
		phases[voice] = fmod(phases[voice] + TAU * frequencies[voice] * STEP, TAU)
		var wave: float = (sin(phases[voice]) + 0.06 * sin(phases[voice] * 3.0)) * 0.055
		var breath: float = 0.72 + 0.22 * sin(clock * (0.071 + voice * 0.019) + voice)
		left += wave * breath * (1.0 - voice * 0.12)
		right += wave * breath * (0.76 + voice * 0.12)
	ping_age += STEP
	if ping_age < 8.0:
		ping_phase = fmod(ping_phase + TAU * ping_frequency * STEP, TAU)
		var envelope: float = minf(ping_age * 5.0, 1.0) * exp(-ping_age * 0.85)
		var ping: float = sin(ping_phase) * envelope * 0.035
		left += ping * (1.0 - ping_pan)
		right += ping * (1.0 + ping_pan)
	sweep_age += STEP
	if sweep_age < 9.0:
		sweep_phase = fmod(sweep_phase + TAU * (120.0 + 260.0 * sweep_age / 9.0) * STEP, TAU)
		var sweep: float = sin(sweep_phase) * pow(sin(PI * sweep_age / 9.0), 2.0) * 0.009
		left += sweep
		right += sweep * 0.8
	return Vector2(left, right) * minf(clock / 4.0, 1.0)
