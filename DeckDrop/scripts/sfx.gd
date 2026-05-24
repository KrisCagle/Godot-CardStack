extends Node
## Procedural sound effects. Bakes a small library of blips/chords/sweeps/noise
## into AudioStreamWAV resources once at startup, then plays them through a
## round-robin pool of AudioStreamPlayer nodes for overlap-safe playback.
##
## Autoloaded as `Sfx`. Call `Sfx.play("clear")` etc. from anywhere.
##
## All samples are mono 16-bit at SAMPLE_RATE. Each sample gets a short attack
## (2ms) and release (8ms) ramp applied so we don't pop on start/end.

const SAMPLE_RATE := 22050
const N_PLAYERS := 8
const MASTER_DB := -4.0  # Master attenuation across every sound.

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _streams: Dictionary = {}

# Background music — dedicated player + a single long looping AudioStreamWAV
# baked at startup. Lower volume so it sits under the SFX.
const MUSIC_DB := -12.0
var _music_player: AudioStreamPlayer = null


func _ready() -> void:
	for i in N_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.volume_db = MASTER_DB
		add_child(p)
		_players.append(p)
	_bake_sounds()
	_setup_music()
	play_music()


func play_music() -> void:
	if _music_player != null and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func play(name: String) -> void:
	var s: AudioStreamWAV = _streams.get(name)
	if s == null:
		push_warning("[sfx] no stream named: " + name)
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % N_PLAYERS
	p.stream = s
	p.play()


# --- background music ---


func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_DB
	add_child(_music_player)
	_music_player.stream = _bake_ambient_loop()


# 16-second ambient pad: four-chord progression (Am - F - C - G), three voices
# per chord, gentle amplitude pulse per voice. Smoothed at the loop seam so we
# don't pop on each loop back. Tuned quiet and slow so it doesn't fight SFX.
func _bake_ambient_loop() -> AudioStreamWAV:
	var duration: float = 16.0
	var n: int = int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var vol: float = db_to_linear(-4.0)

	# Each chord = three voices (root / third / fifth-ish).
	var chords: Array = [
		[220.00, 261.63, 329.63],  # Am  (A3 / C4 / E4)
		[174.61, 220.00, 261.63],  # F   (F3 / A3 / C4)
		[261.63, 329.63, 392.00],  # C   (C4 / E4 / G4)
		[196.00, 246.94, 293.66],  # G   (G3 / B3 / D4)
	]
	var samples_per_chord: int = n / chords.size()

	for ci in chords.size():
		var freqs: Array = chords[ci]
		var start: int = ci * samples_per_chord
		for i in samples_per_chord:
			var t: float = float(i) / float(SAMPLE_RATE)
			# 0.25 Hz amplitude pulse — gives the pad a breath.
			var env: float = 0.55 + 0.20 * sin(t * 0.25 * TAU)
			var s: float = 0.0
			for f in freqs:
				s += sin(t * float(f) * TAU)
			s /= float(freqs.size())
			samples[start + i] = s * env * vol

	# Cross-fade the loop boundary (50ms each side) — kills the "tick" you
	# normally hear when a non-zero sample repeats.
	var fade: int = int(SAMPLE_RATE * 0.05)
	for i in fade:
		var k: float = float(i) / float(fade)
		samples[i] *= k
		samples[n - 1 - i] *= k

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false

	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: float = clampf(samples[i], -1.0, 1.0)
		var v: int = int(s * 32767.0) & 0xFFFF
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream


# --- procedural baking ---


func _bake_sounds() -> void:
	# Card lands in cell — soft mid thunk.
	_streams["place"] = _gen_blip(380.0, 0.10, 12.0, -8.0)
	# Scoring hand clears — bright major chord.
	_streams["clear"] = _gen_chord([523.0, 659.0, 784.0], 0.42, 5.0, -5.0)
	# Combo step — quick up-sweep, climbs the player's ear.
	_streams["combo"] = _gen_sweep(440.0, 980.0, 0.16, 7.0, -9.0)
	# Bomb — burst of noise + low decay.
	_streams["boom"] = _gen_noise(0.34, 6.0, -3.0)
	# Beat the dealer — fuller major chord, longer hold.
	_streams["win"] = _gen_chord([523.0, 659.0, 784.0, 1047.0], 0.55, 3.5, -3.0)
	# Dealer wins (you survive the round but eat the loss).
	_streams["lose"] = _gen_sweep(440.0, 110.0, 0.50, 3.5, -3.0)
	# Game over — long descending sweep.
	_streams["game_over"] = _gen_sweep(330.0, 65.0, 0.75, 3.0, -1.0)


func _gen_blip(freq: float, dur: float, decay: float, vol_db: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var vol := db_to_linear(vol_db)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * decay)
		samples[i] = sin(t * freq * TAU) * env * vol
	_apply_fade(samples)
	return _make_wav(samples)


func _gen_chord(freqs: Array, dur: float, decay: float, vol_db: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var vol := db_to_linear(vol_db) / float(freqs.size())
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * decay)
		var s := 0.0
		for f in freqs:
			s += sin(t * float(f) * TAU)
		samples[i] = s * env * vol
	_apply_fade(samples)
	return _make_wav(samples)


func _gen_sweep(start_freq: float, end_freq: float, dur: float, decay: float, vol_db: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var vol := db_to_linear(vol_db)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var lerp_amt := t / dur
		var freq := lerpf(start_freq, end_freq, lerp_amt)
		phase += freq * TAU / float(SAMPLE_RATE)
		var env := exp(-t * decay)
		samples[i] = sin(phase) * env * vol
	_apply_fade(samples)
	return _make_wav(samples)


func _gen_noise(dur: float, decay: float, vol_db: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var vol := db_to_linear(vol_db)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * decay)
		samples[i] = (randf() * 2.0 - 1.0) * env * vol
	_apply_fade(samples)
	return _make_wav(samples)


# Tiny attack + release ramps prevent sample-discontinuity clicks.
func _apply_fade(samples: PackedFloat32Array) -> void:
	var n := samples.size()
	var attack := mini(int(SAMPLE_RATE * 0.002), n / 8)
	var release := mini(int(SAMPLE_RATE * 0.008), n / 4)
	for i in attack:
		samples[i] *= float(i) / float(attack)
	var release_start := n - release
	for i in range(release_start, n):
		var idx := i - release_start
		samples[i] *= 1.0 - float(idx) / float(release)


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s := clampf(samples[i], -1.0, 1.0)
		var v: int = int(s * 32767.0) & 0xFFFF
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	stream.data = bytes
	return stream
