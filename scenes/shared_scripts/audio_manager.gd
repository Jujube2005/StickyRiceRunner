extends Node

# =============================================================================
# AudioManager — Procedural SFX generator + player
# หากมีไฟล์จริง ให้วางใน res://assets/audio/<name>.wav แล้วจะโหลดแทนอัตโนมัติ
# Keys: pickup, skill_pickup, obstacle_hit, skill_bang_fai, skill_dust,
#       skill_wind, skill_use, shield_block, charge_full
# =============================================================================

const SAMPLE_RATE := 22050
const AUDIO_DIR   := "res://assets/audio/"

var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var _music_volume_db: float = -6.0
var _sfx_volume_db:   float = 0.0

const SFX_LIST := [
	"pickup",         # เก็บกระติ๊บข้าวเหนียว
	"skill_pickup",   # เก็บกล่องสกิล (ยาวกว่า + แมจิก)
	"obstacle_hit",   # ชนสิ่งกีดขวาง
	"skill_bang_fai", # ใช้สกิล บั้งไฟ
	"skill_dust",     # ใช้สกิล ฝุ่นลาน
	"skill_wind",     # ใช้สกิล ลมทุ่ง / Wind Push
	"skill_use",      # generic fallback
	"shield_block",   # ผ้าขาวม้ากันสกิล
	"charge_full",    # ชาร์จครบ
]

func _ready():
	for sfx in SFX_LIST:
		var sfx_name: String = sfx
		var path: String = AUDIO_DIR + sfx_name + ".wav"
		if ResourceLoader.exists(path):
			_streams[sfx_name] = load(path)
			print("[Audio] Loaded: ", path)
		else:
			_streams[sfx_name] = _generate(sfx_name)
			print("[Audio] Procedural SFX: ", sfx_name)

# --- PUBLIC API ---

func play_sfx(sfx_name: String, volume_offset: float = 0.0):
	if not _streams.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream      = _streams[sfx_name]
	p.volume_db   = _sfx_volume_db + volume_offset
	p.bus         = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	p.play()
	p.finished.connect(p.queue_free)

func play_music(stream: AudioStream, loop := true):
	if _music_player:
		_music_player.stop()
		_music_player.queue_free()
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.stream     = stream
	_music_player.volume_db  = _music_volume_db
	_music_player.bus        = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	if loop and stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.play()

func set_sfx_volume(linear: float):
	_sfx_volume_db = linear_to_db(max(linear, 0.001))

func set_music_volume(linear: float):
	_music_volume_db = linear_to_db(max(linear, 0.001))
	if _music_player:
		_music_player.volume_db = _music_volume_db

# --- ROUTER ---

func _generate(name: String) -> AudioStreamWAV:
	match name:
		"pickup":         return _gen_pickup()
		"skill_pickup":   return _gen_skill_pickup()
		"obstacle_hit":   return _gen_obstacle_hit()
		"skill_bang_fai": return _gen_skill_bang_fai()
		"skill_dust":     return _gen_skill_dust()
		"skill_wind":     return _gen_skill_wind()
		"skill_use":      return _gen_skill_use_generic()
		"shield_block":   return _gen_shield_block()
		"charge_full":    return _gen_charge_full()
	return _gen_pickup()

# ═══════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════

func _adsr(i: int, total: int, attack_frac: float, decay_frac: float,
		sustain_level: float, release_frac: float) -> float:
	var t := float(i) / float(total)
	if t < attack_frac:
		return t / attack_frac
	elif t < attack_frac + decay_frac:
		return lerp(1.0, sustain_level, (t - attack_frac) / decay_frac)
	elif t < 1.0 - release_frac:
		return sustain_level
	else:
		return sustain_level * (1.0 - (t - (1.0 - release_frac)) / release_frac)

func _soft_clip(v: float, threshold: float = 0.85) -> float:
	if abs(v) <= threshold:
		return v
	var sign_v: float = sign(v)
	var excess: float = (abs(v) - threshold) / (1.0 - threshold)
	return sign_v * (threshold + (1.0 - threshold) * (1.0 - exp(-excess * 3.0)))

func _make_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var s := int(clamp(buf[i] * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo   = false
	wav.data     = data
	return wav

func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size() + b.size())
	for i in a.size():  out[i]            = a[i]
	for i in b.size():  out[a.size() + i] = b[i]
	return out

# ═══════════════════════════════════════════════════════════
# SOUND GENERATORS
# ═══════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────
# 🎋 เก็บกระติ๊บข้าวเหนียว — Pop / Wood Click / Bamboo Tap
#    สั้น กระชับ เสียงไม้กระทบกันเป็นหลัก
# ───────────────────────────────────────────────────────────
func _gen_pickup() -> AudioStreamWAV:
	var dur := 0.16
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t     := float(i) / SAMPLE_RATE
		# Sharp click transient (ตีไม้ไผ่)
		var click := exp(-t * 280.0) * randf_range(-1.0, 1.0) * 0.55
		# Bamboo resonance ~900 Hz decay เร็ว
		var wood  := exp(-t * 26.0) * sin(TAU * 900.0 * t) * 0.50
		# Hollow overtone (ไม้ไผ่กลวง)
		var hollow := exp(-t * 50.0) * sin(TAU * 1800.0 * t) * 0.18
		# Pop burst of air
		var pop   := exp(-t * 90.0) * randf_range(-1.0, 1.0) * 0.15
		buf[i] = _soft_clip(click + wood + hollow + pop)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# ✨ เก็บกล่องสกิล — Magic Powerup / Reward Sparkle
#    ยาวกว่า บิ๊กกว่า ไต่โน้ตขึ้น เสียงวิเศษ
# ───────────────────────────────────────────────────────────
func _gen_skill_pickup() -> AudioStreamWAV:
	var dur   := 0.70
	var n     := int(SAMPLE_RATE * dur)
	var buf   := PackedFloat32Array()
	buf.resize(n)
	# Ascending arpeggio: C5 E5 G5 B5 E6
	var notes: Array[float] = [523.25, 659.25, 784.0, 987.77, 1318.51]
	var note_len := dur / float(notes.size())
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var v := 0.0
		for ni in notes.size():
			var nt := t - float(ni) * note_len
			if nt >= 0.0 and nt < note_len:
				var nn   := int(note_len * SAMPLE_RATE)
				var ii   := int(nt * SAMPLE_RATE)
				var env  := _adsr(ii, nn, 0.04, 0.08, 0.55, 0.35)
				var f: float = notes[ni]
				v += env * (0.40 * sin(TAU * f * nt) +
							0.20 * sin(TAU * f * 2.0 * nt) +
							0.08 * sin(TAU * f * 3.0 * nt))
		# Persistent sparkle shimmer
		var sp_env := sin(PI * t / dur) * exp(-t * 2.0)
		v += 0.06 * sp_env * sin(TAU * 2637.0 * t)   # E7 twinkle
		v += 0.04 * randf_range(-1.0, 1.0) * sp_env  # noise shimmer
		buf[i] = _soft_clip(v * 0.88)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# 💥 ชนสิ่งกีดขวาง — Cartoon Thud / Body Impact
#    เสียงทึบหนัก + crack + bounce เล็กน้อย
# ───────────────────────────────────────────────────────────
func _gen_obstacle_hit() -> AudioStreamWAV:
	var dur := 0.35
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t       := float(i) / SAMPLE_RATE
		# Deep cartoon thud — pitch slides down fast
		var thud_f  := 60.0 + 200.0 * exp(-t * 28.0)
		var thud    := exp(-t * 11.0) * sin(TAU * thud_f * t) * 0.70
		# Body smack crack transient
		var crack   := exp(-t * 45.0) * randf_range(-1.0, 1.0) * 0.45
		# Cartoon "oof" mid resonance
		var oof     := exp(-t * 18.0) * sin(TAU * 230.0 * t) * 0.22
		# Tiny spring bounce after ~80ms (cartoon feel)
		var spring  := 0.0
		if t > 0.075:
			var ts  := t - 0.075
			spring  = exp(-ts * 22.0) * sin(TAU * 370.0 * ts) * 0.12
		buf[i] = _soft_clip(thud + crack + oof + spring)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# 🚀 สกิล บั้งไฟ — ฟิ้วววว! (Rocket whoosh → explosion)
# ───────────────────────────────────────────────────────────
func _gen_skill_bang_fai() -> AudioStreamWAV:
	var dur   := 0.55
	var n     := int(SAMPLE_RATE * dur)
	var buf   := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var v := 0.0
		if t < 0.32:
			# Rocket whoosh: rising 80Hz → 3200Hz (ฟิ้วววว)
			var prog := t / 0.32
			var f: float = 80.0 + 3120.0 * pow(prog, 2.2)
			phase   += TAU * f / SAMPLE_RATE
			var env  := sin(PI * prog)
			v = env * (0.65 * sin(phase) + 0.18 * randf_range(-1.0, 1.0))
		else:
			# Explosion: noise + low rumble
			var te      := t - 0.32
			var exp_env := exp(-te * 14.0)
			v = exp_env * (0.55 * randf_range(-1.0, 1.0) +
						   0.35 * sin(TAU * 70.0 * te))
		buf[i] = _soft_clip(v * 0.90)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# 💨 สกิล ฝุ่นลาน — ฟุ่บ! (Dust puff, short & muffled)
# ───────────────────────────────────────────────────────────
func _gen_skill_dust() -> AudioStreamWAV:
	var dur := 0.22
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t   := float(i) / SAMPLE_RATE
		# Bell envelope — quick puff
		var env := sin(PI * t / dur) * exp(-t * 9.0)
		# Sub thump (ฟุ่บ)
		var sub := sin(TAU * 180.0 * t) * exp(-t * 25.0) * 0.40
		# Filtered dust noise (mid band)
		var noise := randf_range(-1.0, 1.0) * 0.60
		buf[i] = _soft_clip(env * (sub + noise) * 0.82)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# 🌬️ สกิล ลมทุ่ง / Wind Push — ฟรึ่บ! (Whooshing wind gust)
# ───────────────────────────────────────────────────────────
func _gen_skill_wind() -> AudioStreamWAV:
	var dur := 0.48
	var n   := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t       := float(i) / SAMPLE_RATE
		# Wind envelope: quick rise, slow fall
		var env     := sin(PI * pow(t / dur, 0.6))
		# Tremolo modulation (wind flicker 6Hz)
		var mod     := 0.55 + 0.45 * sin(TAU * 6.0 * t)
		var noise   := randf_range(-1.0, 1.0)
		# Whistle tone: slight pitch wobble
		var w_freq  := 750.0 + 280.0 * sin(TAU * 2.8 * t)
		var whistle := sin(TAU * w_freq * t) * 0.12 * env
		buf[i] = _soft_clip(env * (0.72 * noise * mod + whistle) * 0.80)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# ⚙️ Generic skill use fallback
# ───────────────────────────────────────────────────────────
func _gen_skill_use_generic() -> AudioStreamWAV:
	var dur    := 0.38
	var n      := int(SAMPLE_RATE * dur)
	var buf    := PackedFloat32Array()
	buf.resize(n)
	var phase  := 0.0
	var phase2 := 0.0
	for i in n:
		var t     := float(i) / SAMPLE_RATE
		var env   := sin(PI * t / dur)
		var f: float = 300.0 + 1100.0 * pow(t / dur, 1.3)
		phase    += TAU * f / SAMPLE_RATE
		phase2   += TAU * (f * 3.0) / SAMPLE_RATE
		buf[i]    = _soft_clip(env * (0.68 * sin(phase) + 0.16 * sin(phase2) +
				0.10 * randf_range(-1.0, 1.0) * env))
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# 🛡️ ผ้าขาวม้ากันสกิล — Shield Parry / Reflect
#    คลิกกระทบ + เสียงโลหะ + reflect shimmer กระเด็น
# ───────────────────────────────────────────────────────────
func _gen_shield_block() -> AudioStreamWAV:
	var dur   := 0.52
	var n     := int(SAMPLE_RATE * dur)
	var buf   := PackedFloat32Array()
	buf.resize(n)
	var r_phase := 0.0
	for i in n:
		var t      := float(i) / SAMPLE_RATE
		# Impact click
		var click  := exp(-t * 160.0) * randf_range(-1.0, 1.0) * 0.45
		# Metallic ring: parry sound (inharmonic partials)
		var ring   := exp(-t * 9.0) * (
			0.48 * sin(TAU * 1150.0 * t) +
			0.28 * sin(TAU * 1820.0 * t + 0.5) +
			0.14 * sin(TAU * 2550.0 * t + 1.1) +
			0.08 * sin(TAU * 3800.0 * t + 1.8)
		)
		# Magic reflect shimmer (rising tone that "bounces back")
		var rt: float = min(t / 0.15, 1.0)
		var r_f: float = 500.0 + 1500.0 * rt
		r_phase   += TAU * r_f / SAMPLE_RATE
		var reflect := exp(-t * 14.0) * (1.0 - exp(-t * 40.0)) * sin(r_phase) * 0.22
		buf[i] = _soft_clip(click + ring + reflect)
	return _make_wav(buf)

# ───────────────────────────────────────────────────────────
# ⚡ Charge full — 3-note fanfare G→B→D
# ───────────────────────────────────────────────────────────
func _gen_charge_full() -> AudioStreamWAV:
	var note_freqs: Array[float] = [784.0, 987.77, 1174.66]
	var note_dur   := 0.11
	var buf        := PackedFloat32Array()
	for f_val in note_freqs:
		var f: float = f_val
		var nn  := int(SAMPLE_RATE * note_dur)
		var seg := PackedFloat32Array()
		seg.resize(nn)
		for i in nn:
			var t   := float(i) / SAMPLE_RATE
			var env := _adsr(i, nn, 0.02, 0.06, 0.5, 0.30)
			seg[i]  = _soft_clip(env * (0.55 * sin(TAU * f * t) +
									   0.25 * sin(TAU * f * 2.0 * t) +
									   0.12 * sin(TAU * f * 3.0 * t)))
		buf = _concat(buf, seg)
	return _make_wav(buf)
