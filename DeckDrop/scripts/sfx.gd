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
	_music_player.stream = _bake_casino_loop()


# 8-second upbeat casino loop, 120 BPM, 4 measures of 4/4. Each measure has:
#   - Walking bass on every beat (root → third → fifth → third, octave-doubled)
#   - Chord stab on beats 2 and 4 (snappy attack, fast decay)
#   - White-noise hi-hat tick on every beat (very short, gives drive)
# Progression: C major - A minor - F major - G major. Cross-faded loop seam.
func _bake_casino_loop() -> AudioStreamWAV:
	var bpm: float = 120.0
	var beat_duration: float = 60.0 / bpm
	var measures: int = 4
	var beats_per_measure: int = 4
	var total_beats: int = measures * beats_per_measure
	var duration: float = float(total_beats) * beat_duration
	var n: int = int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)

	# Each measure: {chord stab voices, walking bass per beat}.
	# Bass frequencies are an octave below the chord root for body.
	var progression: Array = [
		{
			"chord": [130.81, 164.81, 196.00],          # C major triad
			"bass":  [65.40, 82.40, 98.00, 82.40],      # C E G E
		},
		{
			"chord": [110.00, 130.81, 164.81],          # A minor
			"bass":  [55.00, 65.40, 82.40, 65.40],      # A C E C
		},
		{
			"chord": [174.61, 220.00, 261.63],          # F major
			"bass":  [87.30, 110.00, 130.81, 110.00],   # F A C A
		},
		{
			"chord": [196.00, 246.94, 293.66],          # G major
			"bass":  [98.00, 123.47, 146.83, 123.47],   # G B D B
		},
	]
	var samples_per_beat: int = int(SAMPLE_RATE * beat_duration)
	var bass_vol: float = db_to_linear(-6.0)
	var chord_vol: float = db_to_linear(-9.0)
	var hat_vol: float = db_to_linear(-18.0)

	for measure in measures:
		var prog: Dictionary = progression[measure]
		var chord_freqs: Array = prog.chord
		var bass_freqs: Array = prog.bass

		for beat in beats_per_measure:
			var beat_start: int = (measure * beats_per_measure + beat) * samples_per_beat
			var bass_freq: float = float(bass_freqs[beat])

			# Walking bass note — slightly warmer than pure sine via subtle 3rd harmonic.
			for i in samples_per_beat:
				var t: float = float(i) / float(SAMPLE_RATE)
				var env: float = exp(-t * 3.5)
				var s: float = sin(t * bass_freq * TAU) - 0.25 * sin(t * bass_freq * 3.0 * TAU)
				samples[beat_start + i] += s * env * bass_vol

			# Chord stab on beats 2 and 4 — short, punchy.
			if beat == 1 or beat == 3:
				for i in samples_per_beat:
					var t: float = float(i) / float(SAMPLE_RATE)
					var env: float = exp(-t * 14.0)
					var s: float = 0.0
					for f in chord_freqs:
						s += sin(t * float(f) * TAU)
					s /= float(chord_freqs.size())
					samples[beat_start + i] += s * env * chord_vol

			# Hi-hat tick on every beat — 40ms noise burst, very quick decay.
			var hat_samples: int = mini(int(SAMPLE_RATE * 0.04), samples_per_beat)
			for i in hat_samples:
				var t: float = float(i) / float(SAMPLE_RATE)
				var env: float = exp(-t * 80.0)
				var noise: float = (randf() * 2.0 - 1.0)
				samples[beat_start + i] += noise * env * hat_vol

	# Clamp + cross-fade loop seam (50ms each side) so the repeat doesn't tick.
	for i in n:
		samples[i] = clampf(samples[i], -1.0, 1.0)
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
		var s: float = samples[i]
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
