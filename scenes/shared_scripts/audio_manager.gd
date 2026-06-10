extends Node

# =============================================================================
# AudioManager — Procedural SFX generator + player
# แทนที่ด้วย .wav จริงได้ โดยวางไฟล์ใน res://assets/audio/ ชื่อเดียวกัน
# เช่น pickup.wav, obstacle_hit.wav, skill_use.wav, shield_block.wav, charge_full.wav
# =============================================================================

const SAMPLE_RATE := 22050
const AUDIO_DIR := "res://assets/audio/"

var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var _music_volume_db: float = -6.0
var _sfx_volume_db: float = 0.0

# --- SFX โหลดจากไฟล์จริง หรือสร้าง procedural ---
const SFX_LIST := ["pickup", "obstacle_hit", "skill_use", "shield_block", "charge_full"]

func _ready():
	for sfx in SFX_LIST:
		var path = AUDIO_DIR + sfx + ".wav"
		if ResourceLoader.exists(path):
			_streams[sfx] = load(path)
			print("[Audio] Loaded: ", path)
		else:
			_streams[sfx] = _generate(sfx)
			print("[Audio] Generated procedural SFX: ", sfx)

# --- PUBLIC API ---

func play_sfx(sfx_name: String, volume_offset: float = 0.0):
	if not _streams.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = _streams[sfx_name]
	p.volume_db = _sfx_volume_db + volume_offset
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	p.play()
	p.finished.connect(p.queue_free)

func play_music(stream: AudioStream, loop := true):
	if _music_player:
		_music_player.stop()
		_music_player.queue_free()
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.stream = stream
	_music_player.volume_db = _music_volume_db
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	if loop and stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.play()

func set_sfx_volume(linear: float):
	_sfx_volume_db = linear_to_db(max(linear, 0.001))

func set_music_volume(linear: float):
	_music_volume_db = linear_to_db(max(linear, 0.001))
	if _music_player:
		_music_player.volume_db = _music_volume_db

# --- PROCEDURAL SOUND GENERATORS ---

func _generate(name: String) -> AudioStreamWAV:
	match name:
		"pickup":       return _gen_pickup()
		"obstacle_hit": return _gen_obstacle_hit()
		"skill_use":    return _gen_skill_use()
		"shield_block": return _gen_shield_block()
		"charge_full":  return _gen_charge_full()
	return _gen_pickup()

# ------- helpers -------

func _make_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var s := int(clamp(buf[i] * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _sine_segment(freq: float, dur: float, vol: float = 0.6) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := 1.0 - float(i) / n  # linear fade-out
		buf[i] = vol * env * sin(TAU * freq * t)
	return buf

func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size() + b.size())
	for i in a.size():  out[i]            = a[i]
	for i in b.size():  out[a.size() + i] = b[i]
	return out

# ------- individual sounds -------

# 🪙 Kratib picked up: C5 → E5 → G5 → C6 arpeggio
func _gen_pickup() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 784.0, 1046.5]  # C5, E5, G5, C6
	var buf := PackedFloat32Array()
	for f in notes:
		buf = _concat(buf, _sine_segment(f, 0.07, 0.55))
	return _make_wav(buf)

# 💥 Obstacle hit: low impact thud + noise burst
func _gen_obstacle_hit() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.22)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t    := float(i) / SAMPLE_RATE
		var env  := exp(-t * 18.0)
		var freq := 90.0 * exp(-t * 12.0)  # pitch drops fast
		var noise := randf_range(-1.0, 1.0) * 0.3
		buf[i] = env * (0.6 * sin(TAU * freq * t) + noise)
	return _make_wav(buf)

# ✨ Skill use: rising frequency sweep (whoosh)
func _gen_skill_use() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t   := float(i) / SAMPLE_RATE
		var env := sin(PI * t / dur)          # bell envelope
		var f   := 280.0 + 1400.0 * (t / dur) # 280→1680 Hz sweep
		phase  += TAU * f / SAMPLE_RATE
		buf[i]  = 0.5 * env * sin(phase)
	return _make_wav(buf)

# 🛡️ Shield block: 880 Hz bell with ring decay
func _gen_shield_block() -> AudioStreamWAV:
	var dur := 0.5
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t   := float(i) / SAMPLE_RATE
		var env := exp(-t * 7.0)
		buf[i]  = 0.6 * env * sin(TAU * 880.0 * t) \
		        + 0.25 * env * sin(TAU * 1320.0 * t) # overtone
	return _make_wav(buf)

# ⚡ Charge full: E5 + G5 quick fanfare
func _gen_charge_full() -> AudioStreamWAV:
	var a := _sine_segment(659.25, 0.1, 0.5)  # E5
	var b := _sine_segment(784.0,  0.15, 0.55) # G5
	return _make_wav(_concat(a, b))
