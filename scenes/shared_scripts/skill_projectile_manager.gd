extends Node

# =============================================================================
# SkillProjectileManager — Visual skill projectile system (Thai Festival theme)
# Autoloaded singleton.  Call: SkillProjectileManager.launch(caster, target, skill_name)
#
# Purely cosmetic — does NOT alter apply_prank() timing or gameplay balance.
# Projectile arcs from caster to target, then fires impact VFX, sound, and
# camera shake on arrival.
#
# Assets used (Brackeys VFX Bundle — alpha channel variants):
#   Projectile core  : particles/alpha/light_01_a.png  (golden glow)
#   Trail ribbon     : particles/alpha/trace_01_a.png  (silk-like)
#   Trail sparks     : particles/alpha/spark_07_a.png  (fine rice sparks)
#   Impact burst     : particles/alpha/muzzle_01_a.png (wide flash ring)
#   Impact scatter   : particles/alpha/star_01_a.png   (festival stars)
#   Impact ring      : particles/alpha/circle_03_a.png (shockwave circle)
#   Impact smoke     : particles/opague/smoke_03.png   (warm puff)
# =============================================================================

const _TEX_ALPHA  : String = "res://assets/textures/brackeys_vfx_bundle/particles/alpha/"
const _TEX_OPAGUE : String = "res://assets/textures/brackeys_vfx_bundle/particles/opague/"

var _tex: Dictionary = {}

# Each entry: { node, quad, glow, trail, sparks_trail, target, caster,
#               start_pos, elapsed, flight_time, skill_name, skill_color, arrived }
var _active_projectiles: Array = []

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_try_load("light",   _TEX_ALPHA  + "light_01_a.png")
	_try_load("flare",   _TEX_ALPHA  + "flare_01_a.png")
	_try_load("trace",   _TEX_ALPHA  + "trace_01_a.png")
	_try_load("spark7",  _TEX_ALPHA  + "spark_07_a.png")
	_try_load("muzzle",  _TEX_ALPHA  + "muzzle_01_a.png")
	_try_load("star",    _TEX_ALPHA  + "star_01_a.png")
	_try_load("circle3", _TEX_ALPHA  + "circle_03_a.png")
	_try_load("smoke",   _TEX_OPAGUE + "smoke_03.png")

func _try_load(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_tex[key] = load(path)

# ─────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────

## Launch a visual projectile from [caster] to [target].
## skill_name is used only for per-skill colour tinting.
func launch(caster: Node3D, target: Node3D, skill_name: String) -> void:
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	var scene_root : Node = get_tree().current_scene
	if not scene_root:
		return

	var spawn_pos   : Vector3 = caster.global_position + Vector3(0, 1.2, 0)
	var target_est  : Vector3 = target.global_position  + Vector3(0, 1.2, 0)
	var skill_color : Color   = _get_skill_color(skill_name)

	# Flight time scales with distance (0.45 – 0.85 s)
	var dist        : float   = spawn_pos.distance_to(target_est)
	var flight_time : float   = clamp(dist / 12.0, 0.45, 0.85)

	# ── Root node ──────────────────────────────────────────
	var proj := Node3D.new()
	proj.name = "SkillProjectile"
	scene_root.add_child(proj)
	proj.global_position = spawn_pos

	# ── Core visual: additive billboard quad ───────────────
	var quad := _make_quad(skill_color)
	proj.add_child(quad)

	# ── Warm golden glow light ──────────────────────────────
	var glow := OmniLight3D.new()
	glow.light_color    = Color(1.0, 0.78, 0.12)
	glow.light_energy   = 4.0
	glow.omni_range     = 3.5
	glow.shadow_enabled = false
	proj.add_child(glow)

	# ── Silk ribbon trail ───────────────────────────────────
	var trail := _make_cpu_particles(
		_tex.get("trace"),
		14, 0.38,
		Color(1.0, 0.88, 0.20, 0.90), Color(1.0, 0.50, 0.00, 0.00),
		0.06, 0.15,
		Vector3(0, 0.15, 0), 30.0, Vector3(0, 0.4, 0),
		0.4, 1.4
	)
	proj.add_child(trail)

	# ── Fine rice-grain sparks ──────────────────────────────
	var sparks_trail := _make_cpu_particles(
		_tex.get("spark7"),
		8, 0.22,
		Color(1.0, 0.95, 0.35, 1.00), Color(1.0, 0.60, 0.00, 0.00),
		0.03, 0.09,
		Vector3(0, 0.2, 0), 40.0, Vector3(0, -1.0, 0),
		0.8, 2.2
	)
	proj.add_child(sparks_trail)

	# ── Register ────────────────────────────────────────────
	_active_projectiles.append({
		"node":        proj,
		"quad":        quad,
		"glow":        glow,
		"trail":       trail,
		"sparks":      sparks_trail,
		"target":      target,
		"caster":      caster,
		"start_pos":   spawn_pos,
		"elapsed":     0.0,
		"flight_time": flight_time,
		"skill_name":  skill_name,
		"skill_color": skill_color,
		"arrived":     false,
	})

# ─────────────────────────────────────────────────────────────
# FRAME UPDATE — moves all active projectiles
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _active_projectiles.is_empty():
		return

	var to_remove: Array = []
	for pd in _active_projectiles:
		_update_projectile(pd, delta)
		if pd["arrived"]:
			to_remove.append(pd)
	for pd in to_remove:
		_active_projectiles.erase(pd)

func _update_projectile(pd: Dictionary, delta: float) -> void:
	var proj   : Node3D  = pd["node"]
	var target : Node3D  = pd["target"]

	# Safety guards
	if not is_instance_valid(proj):
		pd["arrived"] = true
		return
	if not is_instance_valid(target):
		if is_instance_valid(proj):
			proj.queue_free()
		pd["arrived"] = true
		return

	pd["elapsed"] += delta
	# Extract typed locals from Variant dictionary — prevents INFERRED_DECLARATION warnings
	var elapsed     : float   = pd["elapsed"]
	var flight_time : float   = pd["flight_time"]
	var start       : Vector3 = pd["start_pos"]
	var skill_name  : String  = pd["skill_name"]
	var skill_color : Color   = pd["skill_color"]
	var t           : float   = clamp(elapsed / flight_time, 0.0, 1.0)

	var end_pos   : Vector3 = target.global_position + Vector3(0, 1.2, 0)

	# ── Arc trajectory (linear lerp + sine arc in Y) ───────
	var lerp_pos  := start.lerp(end_pos, t)
	lerp_pos.y   += sin(t * PI) * 1.5  # graceful festival arc

	# ── Rotation toward movement direction (safe) ──────────
	var move_dir : Vector3 = lerp_pos - proj.global_position
	proj.global_position   = lerp_pos

	if move_dir.length_squared() > 0.0001:
		var dir_norm : Vector3 = move_dir.normalized()
		# Choose an up reference that is NOT parallel to the movement direction.
		# When dir_norm is close to UP or DOWN, use FORWARD to prevent det==0
		# inside Basis::invert() (triggered by look_at when up || forward).
		var up_ref : Vector3 = Vector3.UP
		if abs(dir_norm.dot(Vector3.UP)) > 0.90:
			up_ref = Vector3.FORWARD
		proj.look_at(proj.global_position + dir_norm, up_ref)

	# ── Pulsing scale on quad ────────────────
	var quad : MeshInstance3D = pd["quad"]
	if is_instance_valid(quad):
		var pulse : float = 1.0 + sin(elapsed * 18.0) * 0.15
		quad.scale = Vector3(pulse, pulse, pulse)

	# ── Pulsing light energy ──────────────────
	var glow : OmniLight3D = pd["glow"]
	if is_instance_valid(glow):
		glow.light_energy = 3.5 + sin(elapsed * 13.0) * 1.0

	# ── Impact on arrival ─────────────────────
	if t >= 1.0 and not pd["arrived"]:
		pd["arrived"] = true
		_on_impact(proj, target, skill_name, skill_color)

# ─────────────────────────────────────────────────────────────
# IMPACT
# ─────────────────────────────────────────────────────────────

func _on_impact(proj: Node3D, target: Node3D, _skill_name: String, skill_color: Color) -> void:
	var impact_pos : Vector3 = target.global_position + Vector3(0, 1.2, 0) \
		if is_instance_valid(target) else proj.global_position
	var scene_root : Node = get_tree().current_scene

	# ── Stop trail & implode the core ──────────────────────
	if is_instance_valid(proj):
		for child in proj.get_children():
			if child is CPUParticles3D:
				child.emitting = false
		var tw : Tween = proj.create_tween()
		tw.tween_property(proj, "scale", Vector3(2.2, 2.2, 2.2), 0.06)
		tw.parallel().tween_property(proj, "scale", Vector3(0.001, 0.001, 0.001), 0.12)
		tw.tween_callback(proj.queue_free)

	if not scene_root:
		return

	# ── Spawn hit VFX burst ─────────────────────────────────
	_spawn_impact_burst(scene_root, impact_pos, skill_color)

	# ── Impact sound ────────────────────────────────────────
	AudioManager.play_sfx("skill_impact")

	# ── Camera shake on both viewports ─────────────────────
	_shake_cameras(0.10, 0.14)

	# ── Half-screen flash on target player's side ───────────
	var is_right : bool = is_instance_valid(target) and target.name == "Player2"
	_trigger_screen_flash(is_right, skill_color)

# ─────────────────────────────────────────────────────────────
# IMPACT BURST EFFECTS
# ─────────────────────────────────────────────────────────────

func _spawn_impact_burst(root: Node, pos: Vector3, skill_color: Color) -> void:
	# Golden muzzle-flash burst ring
	var burst := _make_particles_at(root, pos)
	burst.amount               = 20
	burst.lifetime             = 0.55
	VfxManager._set_tex(burst, _tex.get("muzzle"))
	burst.direction            = Vector3(0, 1, 0)
	burst.spread               = 180.0
	burst.gravity              = Vector3(0, 0.5, 0)
	burst.initial_velocity_min = 2.5
	burst.initial_velocity_max = 6.0
	burst.scale_amount_min     = 0.12
	burst.scale_amount_max     = 0.30
	burst.color                = Color(1.0, 0.88, 0.20, 1.0)
	burst.color_ramp           = _make_gradient(Color(1.0, 0.94, 0.35, 1.0), Color(1.0, 0.42, 0.00, 0.00))

	# Festival star scatter (rice-grain feel)
	var stars := _make_particles_at(root, pos + Vector3(0, 0.2, 0))
	stars.amount               = 16
	stars.lifetime             = 0.75
	VfxManager._set_tex(stars, _tex.get("star"))
	stars.direction            = Vector3(0, 1, 0)
	stars.spread               = 180.0
	stars.gravity              = Vector3(0, -3.5, 0)
	stars.initial_velocity_min = 2.0
	stars.initial_velocity_max = 6.0
	stars.scale_amount_min     = 0.08
	stars.scale_amount_max     = 0.22
	stars.color                = Color(1.0, 0.92, 0.22, 1.0)
	stars.color_ramp           = _make_gradient(Color(1.0, 0.96, 0.38, 1.0), Color(1.0, 0.65, 0.00, 0.00))

	# Expanding shockwave ring
	var ring := _make_particles_at(root, pos + Vector3(0, 0.08, 0))
	ring.amount                = 32
	ring.lifetime              = 0.42
	VfxManager._set_tex(ring, _tex.get("circle3"))
	ring.emission_shape        = CPUParticles3D.EMISSION_SHAPE_RING
	ring.emission_ring_axis    = Vector3(0, 1, 0)
	ring.emission_ring_radius  = 0.05
	ring.emission_ring_inner_radius = 0.0
	ring.direction             = Vector3(0, 0.05, 0)
	ring.spread                = 5.0
	ring.gravity               = Vector3.ZERO
	ring.initial_velocity_min  = 5.0
	ring.initial_velocity_max  = 9.0
	ring.scale_amount_min      = 0.10
	ring.scale_amount_max      = 0.26
	ring.color                 = Color(1.0, 0.86, 0.20, 0.90)
	ring.color_ramp            = _make_gradient(Color(1.0, 0.96, 0.42, 1.0), Color(1.0, 0.72, 0.00, 0.00))

	# Warm smoke puff (soft, warm festival air)
	var smoke := _make_particles_at(root, pos + Vector3(0, 0.5, 0))
	smoke.amount               = 8
	smoke.lifetime             = 1.0
	VfxManager._set_tex(smoke, _tex.get("smoke"))
	smoke.direction            = Vector3(0, 1, 0)
	smoke.spread               = 50.0
	smoke.gravity              = Vector3(0, 0.25, 0)
	smoke.initial_velocity_min = 0.3
	smoke.initial_velocity_max = 1.2
	smoke.scale_amount_min     = 0.30
	smoke.scale_amount_max     = 0.65
	smoke.color                = Color(0.92, 0.80, 0.52, 0.55)

	# Skill-coloured flare pop (matches the skill type)
	var flare := _make_particles_at(root, pos)
	flare.amount               = 10
	flare.lifetime             = 0.30
	VfxManager._set_tex(flare, _tex.get("flare"))
	flare.direction            = Vector3(0, 0, 0)
	flare.spread               = 180.0
	flare.gravity              = Vector3.ZERO
	flare.initial_velocity_min = 1.5
	flare.initial_velocity_max = 4.0
	flare.scale_amount_min     = 0.18
	flare.scale_amount_max     = 0.40
	flare.color                = Color(skill_color.r, skill_color.g, skill_color.b, 0.85)
	flare.color_ramp           = _make_gradient(skill_color, Color(skill_color.r, skill_color.g, skill_color.b, 0.0))

	# Bright omni-light flash (replaces _flash helper to stay self-contained)
	var flash_light := OmniLight3D.new()
	flash_light.position      = pos
	flash_light.light_color   = Color(1.0, 0.86, 0.22)
	flash_light.light_energy  = 9.0
	flash_light.omni_range    = 6.0
	flash_light.shadow_enabled = false
	get_tree().current_scene.add_child(flash_light)
	var fl_tw : Tween = flash_light.create_tween()
	fl_tw.tween_property(flash_light, "light_energy", 0.0, 0.28)
	fl_tw.tween_callback(flash_light.queue_free)

	# Auto-cleanup
	_auto_free(burst,  1.2)
	_auto_free(stars,  1.5)
	_auto_free(ring,   1.0)
	_auto_free(smoke,  2.0)
	_auto_free(flare,  0.8)

# ─────────────────────────────────────────────────────────────
# CAMERA SHAKE
# ─────────────────────────────────────────────────────────────

func _shake_cameras(duration: float, intensity: float) -> void:
	var scene_root : Node = get_tree().current_scene
	if not scene_root:
		return
	for cam_name in ["CameraP1", "CameraP2"]:
		var cam = scene_root.find_child(cam_name, true, false)
		if cam and cam.has_method("shake"):
			cam.shake(duration, intensity)

# ─────────────────────────────────────────────────────────────
# SCREEN FLASH (delegates to HUD)
# ─────────────────────────────────────────────────────────────

func _trigger_screen_flash(is_right_half: bool, skill_color: Color) -> void:
	var scene_root : Node = get_tree().current_scene
	if not scene_root:
		return
	var hud = scene_root.find_child("GameplayHUD", true, false)
	if hud and hud.has_method("show_skill_flash"):
		hud.show_skill_flash(is_right_half, skill_color)

# ─────────────────────────────────────────────────────────────
# VFX CONSTRUCTION HELPERS
# ─────────────────────────────────────────────────────────────

func _make_quad(color: Color) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.9, 0.9)
	quad.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.transparency           = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode             = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode              = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode           = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode         = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color           = Color(color.r, color.g, color.b, 1.0)
	if _tex.has("light"):
		mat.albedo_texture     = _tex["light"]
	quad.material_override     = mat
	return quad

## Builds a CPUParticles3D trail emitter (attached as child later by caller).
func _make_cpu_particles(tex, amount: int, lifetime: float,
		c_start: Color, c_end: Color,
		scale_min: float, scale_max: float,
		direction: Vector3, spread: float, gravity: Vector3,
		vel_min: float, vel_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount               = amount
	p.lifetime             = lifetime
	p.one_shot             = false
	p.emitting             = true
	p.direction            = direction
	p.spread               = spread
	p.gravity              = gravity
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min     = scale_min
	p.scale_amount_max     = scale_max
	p.color                = c_start
	p.color_ramp           = _make_gradient(c_start, c_end)
	if tex != null:
		VfxManager._set_tex(p, tex)
	return p

## Allocates a one-shot CPUParticles3D at a world position under [root].
func _make_particles_at(root: Node, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.position = pos
	root.add_child(p)
	return p

func _make_gradient(c1: Color, c2: Color) -> Gradient:
	var g      := Gradient.new()
	g.colors   = PackedColorArray([c1, c2])
	g.offsets  = PackedFloat32Array([0.0, 1.0])
	return g

func _auto_free(node: Node, after_sec: float = 2.0) -> void:
	if not is_instance_valid(node): return
	var tw = node.create_tween()
	tw.tween_interval(after_sec)
	tw.tween_callback(node.queue_free)

# ─────────────────────────────────────────────────────────────
# SKILL → COLOUR MAP  (mirrors gameplay_hud.gd get_skill_color)
# ─────────────────────────────────────────────────────────────

func _get_skill_color(skill_name: String) -> Color:
	match skill_name:
		"Rice Yard Dust":            return Color(1.0,  0.70, 0.15)
		"Boon Bang Fai":             return Color(1.0,  0.35, 0.00)
		"Lane Swap":                 return Color(0.85, 0.25, 0.95)
		"Screen Blur":               return Color(0.55, 0.55, 0.60)
		"Pull to Center":            return Color(1.0,  0.45, 0.75)
		"Lane Block":                return Color(1.0,  0.82, 0.00)
		"Field Wind", "Wind Push":   return Color(0.35, 0.88, 0.25)
		"Pha Khao Ma":               return Color(0.95, 0.75, 0.10)
		_:                           return Color(1.0,  0.82, 0.10)  # Thai golden
