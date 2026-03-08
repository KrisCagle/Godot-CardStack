extends Node
class_name AudioManager

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _sfx_playback: AudioStreamGeneratorPlayback
var _music_playback: AudioStreamGeneratorPlayback
var _music_timer: Timer

var _peg_cooldown: float = 0.0
var _music_step: int = 0
var _peg_arp_index: int = 0
var _music_phrase: int = 0
var _sfx_volume_db: float = -4.0
var _music_volume_db: float = -13.0

const MIX_RATE: float = 44100.0
const PEG_ARP_STEPS: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16]

func _ready() -> void:
	_setup_sfx()
	_setup_music()

func _process(delta: float) -> void:
	_peg_cooldown = maxf(0.0, _peg_cooldown - delta)

func play_drop() -> void:
	_push_sfx_tone(180.0, 0.045, 0.20, true)
	_push_sfx_tone(130.0, 0.08, 0.14, true)

func play_menu_click() -> void:
	_push_sfx_tone(720.0, 0.03, 0.16)
	_push_sfx_tone(980.0, 0.03, 0.12)

func play_menu_open() -> void:
	_push_sfx_tone(340.0, 0.04, 0.13)
	_push_sfx_tone(520.0, 0.05, 0.12)

func play_peg_hit(peg_type: int) -> void:
	if _peg_cooldown > 0.0:
		return
	_peg_cooldown = 0.012

	var root: float = 246.94
	var gain: float = 0.07
	match peg_type:
		0: # Damage tick
			root = 220.0
			gain = 0.08
		1: # Gold ping
			root = 246.94
			gain = 0.08
		2: # Shield thunk
			root = 174.61
			gain = 0.09
		3: # Multiplier chime
			root = 293.66
			gain = 0.07
		_:
			root = 246.94
	var step_idx: int = _peg_arp_index % PEG_ARP_STEPS.size()
	var semitone: int = int(PEG_ARP_STEPS[step_idx])
	_peg_arp_index += 1
	var freq: float = root * pow(2.0, float(semitone) / 12.0)
	_push_reward_arp(freq, 0.065, gain)
	if peg_type == 1:
		_push_sfx_tone(freq * 1.98, 0.03, 0.06)
	elif peg_type == 2:
		_push_sfx_tone(freq * 0.5, 0.05, 0.08, true)
	elif peg_type == 3:
		_push_sfx_tone(freq * 2.0, 0.04, 0.05)

func play_pocket_land() -> void:
	_push_sfx_tone(460.0, 0.05, 0.16)
	_push_sfx_tone(690.0, 0.06, 0.14)
	_push_sfx_tone(920.0, 0.07, 0.12)

func play_target_box_hit() -> void:
	_push_sfx_tone(380.0, 0.03, 0.12, true)
	_push_sfx_tone(770.0, 0.05, 0.14)

func play_enemy_hit() -> void:
	_push_sfx_tone(160.0, 0.05, 0.15, true)

func play_shield_block() -> void:
	_push_sfx_tone(196.0, 0.045, 0.10, true)
	_push_sfx_tone(132.0, 0.07, 0.08, true)

func play_tier_shimmer() -> void:
	_push_sfx_tone(880.0, 0.04, 0.08)
	_push_sfx_tone(1174.0, 0.05, 0.06)

func _setup_sfx() -> void:
	_sfx_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.25
	_sfx_player.stream = stream
	_sfx_player.volume_db = _sfx_volume_db
	add_child(_sfx_player)
	_sfx_player.play()
	_sfx_playback = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = _music_volume_db
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.8
	_music_player.stream = stream
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback

	_music_timer = Timer.new()
	_music_timer.wait_time = 0.16
	_music_timer.autostart = true
	_music_timer.timeout.connect(_on_music_tick)
	add_child(_music_timer)

func _on_music_tick() -> void:
	var roots: Array[float] = [110.0, 87.31, 98.0, 130.81] # Am, F, G, C
	var lead_sequences: Array = [
		[7, 9, 10, -1, 7, 9, 12, -1, 7, 9, 10, -1, 14, 12, 10, -1],
		[5, 7, 9, -1, 5, 7, 10, -1, 5, 7, 9, -1, 12, 10, 9, -1],
		[7, 5, 4, -1, 7, 9, 10, -1, 7, 5, 4, -1, 12, 10, 9, -1],
	]
	var bass_sequence: Array[int] = [0, -1, 0, -1, 7, -1, 0, -1, 5, -1, 0, -1, 7, -1, 0, -1]
	var idx: int = _music_step
	_music_step += 1
	var step: int = idx % 16
	if step == 0:
		_music_phrase += 1
	var root: float = roots[_music_phrase % roots.size()]
	var lead_pattern: Array = lead_sequences[_music_phrase % lead_sequences.size()] as Array

	var bass_semi: int = bass_sequence[step]
	if bass_semi >= 0:
		var bass_freq: float = root * pow(2.0, float(bass_semi) / 12.0) * 0.5
		var bass_len: float = 0.20 if step % 4 == 0 else 0.10
		_push_music_voice(bass_freq, bass_len, 0.076, true)

	var lead_semi: int = int(lead_pattern[step])
	if lead_semi >= 0:
		var lead_freq: float = root * pow(2.0, float(lead_semi) / 12.0)
		_push_music_voice(lead_freq, 0.11, 0.032, false)
		if step % 4 == 2:
			var harm_freq: float = lead_freq * pow(2.0, -3.0 / 12.0)
			_push_music_voice(harm_freq, 0.09, 0.017, false)

	if step % 2 == 1:
		_push_music_noise(0.016, 0.008)
	if step == 7 or step == 15:
		_push_music_noise(0.024, 0.013)

func _push_sfx_tone(freq: float, duration: float, gain: float, square: bool = false) -> void:
	if _sfx_playback == null:
		return
	var frames := int(duration * MIX_RATE)
	for i in range(frames):
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / float(frames))
		var wave := sin(TAU * freq * t)
		if square:
			wave = sign(wave)
		var sample := wave * gain * env
		_sfx_playback.push_frame(Vector2(sample, sample))

func _push_music_tone(freq: float, duration: float, gain: float, square: bool = false) -> void:
	if _music_playback == null:
		return
	var frames := int(duration * MIX_RATE)
	for i in range(frames):
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / float(frames))
		var wave := sin(TAU * freq * t)
		if square:
			wave = sign(wave)
		var sample := wave * gain * env
		_music_playback.push_frame(Vector2(sample, sample))

func _push_reward_arp(freq: float, duration: float, gain: float) -> void:
	if _sfx_playback == null:
		return
	var frames: int = int(duration * MIX_RATE)
	var lp: float = 0.0
	var echo: float = 0.0
	for i in range(frames):
		var t: float = float(i) / MIX_RATE
		var n: float = float(i) / float(frames)
		var env: float = 1.0 - n
		env = env * env * env
		var attack: float = minf(1.0, n * 20.0)
		var pitch_env: float = 1.0 + (1.0 - n) * 0.04
		var f: float = freq * pitch_env
		var saw_a: float = _saw_wave(f * t)
		var saw_b: float = _saw_wave(f * 1.004 * t)
		var tri: float = _tri_wave(f * 0.5 * t)
		var raw: float = saw_a * 0.45 + saw_b * 0.27 + tri * 0.28
		var cutoff: float = 0.08 + (1.0 - n) * 0.18
		lp += (raw - lp) * cutoff
		echo = echo * 0.72 + lp * 0.28
		var sample: float = (lp + echo * 0.22) * gain * env * attack
		sample = tanh(sample * 1.35) * 0.9
		_sfx_playback.push_frame(Vector2(sample, sample))

func _push_music_voice(freq: float, duration: float, gain: float, bass: bool) -> void:
	if _music_playback == null:
		return
	var frames: int = int(duration * MIX_RATE)
	var lowpass: float = 0.0
	for i in range(frames):
		var t: float = float(i) / MIX_RATE
		var n: float = float(i) / float(frames)
		var attack: float = minf(1.0, n * 16.0)
		var env: float = 1.0 - n
		env = env * env
		var vibrato: float = 1.0 + sin(TAU * 4.6 * t) * 0.003
		var f: float = freq * vibrato
		var pulse_width: float = 0.48 + sin(TAU * 0.7 * t) * 0.07
		var pulse_phase: float = fposmod(f * t, 1.0)
		var pulse: float = 1.0 if pulse_phase < pulse_width else -1.0
		var body: float
		if bass:
			body = pulse * 0.70 + sin(TAU * f * 0.5 * t) * 0.30
		else:
			body = pulse * 0.42 + _tri_wave(f * t) * 0.38 + sin(TAU * f * 2.0 * t) * 0.20
		lowpass += (body - lowpass) * (0.12 + (1.0 - n) * 0.08)
		var sample: float = lowpass * gain * env * attack
		_music_playback.push_frame(Vector2(sample, sample))

func _tri_wave(x: float) -> float:
	var p: float = fposmod(x, 1.0)
	return 2.0 * abs(2.0 * p - 1.0) - 1.0

func _saw_wave(x: float) -> float:
	var p: float = fposmod(x, 1.0)
	return p * 2.0 - 1.0

func _push_music_noise(duration: float, gain: float) -> void:
	if _music_playback == null:
		return
	var frames: int = int(duration * MIX_RATE)
	for i in range(frames):
		var n: float = float(i) / float(frames)
		var env: float = (1.0 - n)
		env = env * env
		var sample: float = randf_range(-1.0, 1.0) * gain * env
		_music_playback.push_frame(Vector2(sample, sample))

func set_sfx_volume_db(value: float) -> void:
	_sfx_volume_db = clampf(value, -30.0, 6.0)
	if _sfx_player:
		_sfx_player.volume_db = _sfx_volume_db

func set_music_volume_db(value: float) -> void:
	_music_volume_db = clampf(value, -30.0, 2.0)
	if _music_player:
		_music_player.volume_db = _music_volume_db

func get_sfx_volume_db() -> float:
	return _sfx_volume_db

func get_music_volume_db() -> float:
	return _music_volume_db
