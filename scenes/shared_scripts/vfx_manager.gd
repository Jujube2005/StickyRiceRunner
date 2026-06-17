extends Node

# =============================================================================
# VfxManager — One-shot visual effects using Brackeys VFX textures
# Autoloaded singleton. Call: VfxManager.spawn("effect_name", world_position)
#
# Effects:
#   "obstacle_hit"   — Red/orange impact burst + smoke
#   "kratip_pickup"  — Gold sparkles float upward
#   "silk_pickup"    — Purple/gold magic radiate outward
#   "skill_use"      — Blue/white energy burst
#   "skill_bang_fai" — Orange fire burst
#   "skill_dust"     — Brown/beige dust puff
#   "skill_wind"     — Cyan/white wind swirl
#   "shield_block"   — Green deflect flash + sparks
# =============================================================================

const _VFX_ALPHA  := "res://assets/textures/brackeys_vfx_bundle/particles/alpha/"

# Cached textures (graceful — works without textures too)
var _tex: Dictionary = {}

func _ready() -> void:
	_try_load("spark",  _VFX_ALPHA + "spark_01_a.png")
	_try_load("spark2", _VFX_ALPHA + "spark_03_a.png")
	_try_load("star",   _VFX_ALPHA + "star_01_a.png")
	_try_load("smoke",  _VFX_ALPHA + "smoke_01_a.png")
	_try_load("smoke2", _VFX_ALPHA + "smoke_04_a.png")
	_try_load("magic",  _VFX_ALPHA + "magic_01_a.png")
	_try_load("light",  _VFX_ALPHA + "light_01_a.png")
	_try_load("fire",   _VFX_ALPHA + "fire_01_a.png")
	_try_load("flame",  _VFX_ALPHA + "flame_01_a.png")
	_try_load("wind",   _VFX_ALPHA + "twirl_01_a.png")
	_try_load("circle", _VFX_ALPHA + "circle_01_a.png")
	_try_load("slash",  _VFX_ALPHA + "slash_01_a.png")
	_try_load("muzzle", _VFX_ALPHA + "muzzle_01_a.png")

func _try_load(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_tex[key] = load(path)

# --- PUBLIC API ---------------------------------------------------------------

func spawn(effect_name: String, world_pos: Vector3) -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	match effect_name:
		"obstacle_hit":   _fx_obstacle_hit(scene_root, world_pos)
		"kratip_pickup":  _fx_kratip_pickup(scene_root, world_pos)
		"silk_pickup":    _fx_silk_pickup(scene_root, world_pos)
		"skill_use":      _fx_skill_use(scene_root, world_pos)
		"skill_bang_fai": _fx_bang_fai(scene_root, world_pos)
		"skill_dust":     _fx_skill_dust(scene_root, world_pos)
		"skill_wind":     _fx_skill_wind(scene_root, world_pos)
		"shield_block":   _fx_shield_block(scene_root, world_pos)

# --- EFFECT DEFINITIONS -------------------------------------------------------

# 💥 ชนสิ่งกีดขวาง — Impact burst (orange sparks + smoke)
func _fx_obstacle_hit(root: Node, pos: Vector3) -> void:
	# Spark burst (fast, outward)
	var sparks := _make_particles(root, pos)
	sparks.amount               = 24
	sparks.lifetime             = 0.6
	sparks.texture              = _tex.get("spark")
	sparks.direction            = Vector3(0, 1, 0)
	sparks.spread               = 180.0
	sparks.gravity              = Vector3(0, -6.0, 0)
	sparks.initial_velocity_min = 3.5
	sparks.initial_velocity_max = 7.0
	sparks.scale_amount_min     = 0.12
	sparks.scale_amount_max     = 0.28
	sparks.color                = Color(1.0, 0.5, 0.1, 1.0)
	sparks.color_ramp           = _gradient([Color(1.0, 0.6, 0.1, 1.0), Color(1.0, 0.2, 0.0, 0.0)])

	# Smoke puff (slow, floats up)
	var smoke := _make_particles(root, pos + Vector3(0, 0.5, 0))
	smoke.amount               = 10
	smoke.lifetime             = 0.8
	smoke.texture              = _tex.get("smoke")
	smoke.direction            = Vector3(0, 1, 0)
	smoke.spread               = 40.0
	smoke.gravity              = Vector3(0, 0.5, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.5
	smoke.scale_amount_min     = 0.3
	smoke.scale_amount_max     = 0.6
	smoke.color                = Color(0.9, 0.8, 0.7, 0.7)

	_flash(root, pos + Vector3(0, 1.0, 0), Color(1.0, 0.4, 0.0, 0.9), 1.0, 0.18)
	_auto_free(sparks, 1.2)
	_auto_free(smoke,  1.5)

# ✨ เก็บกระติ๊บ — Gold sparkles float upward
func _fx_kratip_pickup(root: Node, pos: Vector3) -> void:
	var stars := _make_particles(root, pos + Vector3(0, 0.6, 0))
	stars.amount               = 16
	stars.lifetime             = 0.7
	stars.texture              = _tex.get("star", _tex.get("spark"))
	stars.direction            = Vector3(0, 1, 0)
	stars.spread               = 50.0
	stars.gravity              = Vector3(0, -1.0, 0)
	stars.initial_velocity_min = 1.5
	stars.initial_velocity_max = 3.5
	stars.scale_amount_min     = 0.08
	stars.scale_amount_max     = 0.18
	stars.color                = Color(1.0, 0.92, 0.2, 1.0)
	stars.color_ramp           = _gradient([Color(1.0, 0.95, 0.3, 1.0), Color(1.0, 0.8, 0.0, 0.0)])

	_flash(root, pos + Vector3(0, 0.8, 0), Color(1.0, 0.95, 0.2, 0.7), 0.6, 0.12)
	_auto_free(stars, 1.2)

# 🎀 เก็บผ้าไหม — Purple/gold magic radiates outward
func _fx_silk_pickup(root: Node, pos: Vector3) -> void:
	var magic := _make_particles(root, pos + Vector3(0, 0.8, 0))
	magic.amount               = 28
	magic.lifetime             = 1.0
	magic.texture              = _tex.get("magic", _tex.get("star"))
	magic.direction            = Vector3(0, 1, 0)
	magic.spread               = 180.0
	magic.gravity              = Vector3(0, 0.3, 0)
	magic.initial_velocity_min = 1.0
	magic.initial_velocity_max = 3.5
	magic.scale_amount_min     = 0.10
	magic.scale_amount_max     = 0.25
	magic.color                = Color(0.85, 0.5, 1.0, 1.0)
	magic.color_ramp           = _gradient([Color(0.9, 0.6, 1.0, 1.0), Color(1.0, 0.8, 1.0, 0.0)])

	var light := _make_particles(root, pos + Vector3(0, 1.0, 0))
	light.amount               = 10
	light.lifetime             = 0.5
	light.texture              = _tex.get("light", _tex.get("circle"))
	light.direction            = Vector3(0, 0, 0)
	light.spread               = 180.0
	light.gravity              = Vector3.ZERO
	light.initial_velocity_min = 0.5
	light.initial_velocity_max = 2.0
	light.scale_amount_min     = 0.15
	light.scale_amount_max     = 0.35
	light.color                = Color(1.0, 0.85, 1.0, 0.8)

	_flash(root, pos + Vector3(0, 0.8, 0), Color(0.8, 0.4, 1.0, 0.8), 1.2, 0.22)
	_auto_free(magic, 1.8)
	_auto_free(light, 1.2)

# ⚙️ ใช้สกิล (generic) — Blue/white energy burst
func _fx_skill_use(root: Node, pos: Vector3) -> void:
	var energy := _make_particles(root, pos + Vector3(0, 1.0, 0))
	energy.amount               = 20
	energy.lifetime             = 0.6
	energy.texture              = _tex.get("muzzle", _tex.get("magic"))
	energy.direction            = Vector3(0, 1, 0)
	energy.spread               = 90.0
	energy.gravity              = Vector3(0, 1.0, 0)
	energy.initial_velocity_min = 2.0
	energy.initial_velocity_max = 5.0
	energy.scale_amount_min     = 0.10
	energy.scale_amount_max     = 0.22
	energy.color                = Color(0.3, 0.7, 1.0, 1.0)
	energy.color_ramp           = _gradient([Color(0.5, 0.9, 1.0, 1.0), Color(0.2, 0.5, 1.0, 0.0)])

	_flash(root, pos + Vector3(0, 1.0, 0), Color(0.4, 0.8, 1.0, 0.8), 0.8, 0.18)
	_auto_free(energy, 1.2)

# 🚀 บั้งไฟ — Orange fire burst upward
func _fx_bang_fai(root: Node, pos: Vector3) -> void:
	var fire := _make_particles(root, pos + Vector3(0, 0.5, 0))
	fire.amount               = 30
	fire.lifetime             = 0.8
	fire.texture              = _tex.get("flame", _tex.get("fire"))
	fire.direction            = Vector3(0, 1, 0)
	fire.spread               = 30.0
	fire.gravity              = Vector3(0, 2.0, 0)
	fire.initial_velocity_min = 3.0
	fire.initial_velocity_max = 8.0
	fire.scale_amount_min     = 0.12
	fire.scale_amount_max     = 0.28
	fire.color                = Color(1.0, 0.45, 0.05, 1.0)
	fire.color_ramp           = _gradient([Color(1.0, 0.8, 0.1, 1.0), Color(1.0, 0.1, 0.0, 0.0)])

	var smoke := _make_particles(root, pos + Vector3(0, 1.5, 0))
	smoke.amount               = 8
	smoke.lifetime             = 1.0
	smoke.texture              = _tex.get("smoke")
	smoke.direction            = Vector3(0, 1, 0)
	smoke.spread               = 20.0
	smoke.gravity              = Vector3(0, 0.3, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.5
	smoke.scale_amount_min     = 0.4
	smoke.scale_amount_max     = 0.8
	smoke.color                = Color(0.3, 0.3, 0.3, 0.5)

	_flash(root, pos + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.0, 0.9), 1.2, 0.22)
	_auto_free(fire,  1.5)
	_auto_free(smoke, 2.0)

# 💨 ฝุ่นลาน — Brown dust cloud
func _fx_skill_dust(root: Node, pos: Vector3) -> void:
	var dust := _make_particles(root, pos + Vector3(0, 0.3, 0))
	dust.amount               = 22
	dust.lifetime             = 1.0
	dust.texture              = _tex.get("smoke2", _tex.get("smoke"))
	dust.direction            = Vector3(0, 0.5, 0)
	dust.spread               = 120.0
	dust.gravity              = Vector3(0, -0.5, 0)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.5
	dust.scale_amount_min     = 0.25
	dust.scale_amount_max     = 0.55
	dust.color                = Color(0.85, 0.72, 0.45, 0.85)
	dust.color_ramp           = _gradient([Color(0.9, 0.78, 0.5, 0.9), Color(0.7, 0.6, 0.35, 0.0)])
	_auto_free(dust, 2.0)

# 🌬️ ลมทุ่ง — Cyan wind swirl
func _fx_skill_wind(root: Node, pos: Vector3) -> void:
	var wind := _make_particles(root, pos + Vector3(0, 1.0, 0))
	wind.amount               = 20
	wind.lifetime             = 0.7
	wind.texture              = _tex.get("wind", _tex.get("circle"))
	wind.direction            = Vector3(1, 0.3, 0)
	wind.spread               = 60.0
	wind.gravity              = Vector3(0, 0.2, 0)
	wind.initial_velocity_min = 2.0
	wind.initial_velocity_max = 6.0
	wind.scale_amount_min     = 0.12
	wind.scale_amount_max     = 0.30
	wind.color                = Color(0.5, 0.95, 1.0, 0.9)
	wind.color_ramp           = _gradient([Color(0.7, 1.0, 1.0, 1.0), Color(0.3, 0.8, 1.0, 0.0)])

	_flash(root, pos + Vector3(0, 1.0, 0), Color(0.4, 0.9, 1.0, 0.6), 0.7, 0.20)
	_auto_free(wind, 1.4)

# 🛡️ ผ้าขาวม้ากัน — Green deflect flash + sparks
func _fx_shield_block(root: Node, pos: Vector3) -> void:
	var sparks := _make_particles(root, pos + Vector3(0, 1.0, 0))
	sparks.amount               = 16
	sparks.lifetime             = 0.5
	sparks.texture              = _tex.get("slash", _tex.get("spark"))
	sparks.direction            = Vector3(0, 1, 0)
	sparks.spread               = 180.0
	sparks.gravity              = Vector3(0, -4.0, 0)
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.5
	sparks.scale_amount_min     = 0.08
	sparks.scale_amount_max     = 0.20
	sparks.color                = Color(0.2, 1.0, 0.4, 1.0)
	sparks.color_ramp           = _gradient([Color(0.5, 1.0, 0.5, 1.0), Color(1.0, 1.0, 0.5, 0.0)])

	_flash(root, pos + Vector3(0, 1.0, 0), Color(0.3, 1.0, 0.5, 0.8), 0.8, 0.18)
	_auto_free(sparks, 1.2)

# --- HELPERS ------------------------------------------------------------------

func _make_particles(root: Node, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot  = true
	p.emitting  = true
	p.position  = pos
	root.add_child(p)
	return p

func _flash(root: Node, pos: Vector3, color: Color, size: float, duration: float) -> void:
	var flash := MeshInstance3D.new()
	var quad  := QuadMesh.new()
	quad.size  = Vector2(size, size)
	flash.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency               = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color               = color
	mat.emission_enabled           = true
	mat.emission                   = color
	mat.emission_energy_multiplier = 2.5
	mat.billboard_mode             = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test              = true
	flash.material_override = mat
	flash.position = pos
	root.add_child(flash)

	var tw := flash.create_tween()
	tw.tween_property(flash, "material_override:albedo_color:a", 0.0, duration)
	tw.tween_callback(flash.queue_free)

func _gradient(colors: Array[Color]) -> GradientTexture1D:
	var g  := Gradient.new()
	g.colors  = colors
	g.offsets = [0.0, 1.0]
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt

func _auto_free(node: Node, after_sec: float = 2.0) -> void:
	get_tree().create_timer(after_sec).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)
