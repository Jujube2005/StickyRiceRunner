extends Area3D

# ============================================================
# ผ้าไหม (Silk) — collectible item
# Spawned when a player collects 10 Kratips.
# On pickup: grants 5s protection to the collecting player,
#            records the silk in CollectionManager.
# ============================================================

@export var float_speed     := 1.2
@export var float_amplitude := 0.18
@export var rotate_speed    := 1.5

var silk_data    : Dictionary = {}  # Set by spawner: { id, name, texture, rarity }
var is_active    := false
var is_collected := false
var start_y      := 0.0
var time_passed  := 0.0

var model_node : Node3D
var sprite     : Sprite3D

func _ready():
	_build_visuals()
	connect("body_entered", Callable(self, "_on_body_entered"))
	if !is_active:
		deactivate()

func _build_visuals():
	# Collision sphere
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.55
	col.shape = sphere
	col.position.y = 0.5
	add_child(col)

	# Model root
	model_node = Node3D.new()
	model_node.position.y = 0.7
	add_child(model_node)

	# Sprite3D — texture will be set when activate() is called
	sprite = Sprite3D.new()
	sprite.pixel_size   = 0.008
	sprite.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.double_sided = true
	model_node.add_child(sprite)

	# Glow light
	var light = OmniLight3D.new()
	light.light_color  = Color(0.95, 0.85, 1.0)
	light.light_energy = 1.8
	light.omni_range   = 2.0
	light.position.y   = 0.3
	add_child(light)

	# Sparkle particles (silky, soft)
	var particles = CPUParticles3D.new()
	particles.amount               = 14
	particles.lifetime             = 1.5
	particles.emission_shape       = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.direction            = Vector3(0, 1, 0)
	particles.spread               = 40.0
	particles.gravity              = Vector3(0, 0.15, 0)
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.35
	particles.color                = Color(0.9, 0.7, 1.0, 0.85)
	particles.position.y           = 0.5
	add_child(particles)

func _apply_texture():
	if sprite and silk_data.has("texture"):
		var tex_path = silk_data["texture"]
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)

func activate(pos: Vector3, data: Dictionary):
	silk_data    = data
	is_active    = true
	is_collected = false
	global_position = pos
	start_y      = pos.y
	time_passed  = randf() * TAU
	visible      = true
	set_process(true)
	set_deferred("monitoring",  true)
	set_deferred("monitorable", true)
	_apply_texture()

func deactivate():
	is_active = false
	visible   = false
	call_deferred("set_position", Vector3(0, -100, 0))
	set_deferred("monitorable", false)
	set_deferred("monitoring",  false)

func _process(delta):
	if !is_active or is_collected: return
	time_passed += delta
	# Float
	global_position.y = start_y + sin(time_passed * float_speed) * float_amplitude
	# Gentle sway on Y-axis
	rotation.y += rotate_speed * delta

func _on_body_entered(body):
	if !is_active or is_collected: return
	if not (body.name == "Player1" or body.name == "Player2"): return

	is_collected = true

	# 1. Grant silk protection to the player
	if body.has_method("grant_silk_protection"):
		body.grant_silk_protection()

	# 2. Record in CollectionManager
	var is_new: bool = false
	if silk_data.has("id"):
		is_new = CollectionManager.add_silk(silk_data["id"])

	# 3. SFX
	AudioManager.play_sfx("pickup")

	# 4. Unlock notification via HUD
	if is_new and silk_data.has("name"):
		var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
		if hud and hud.has_method("show_silk_unlock"):
			hud.show_silk_unlock(silk_data["name"])

	# 5. Pop-scale then deactivate
	var tween = create_tween()
	tween.tween_property(model_node, "scale", Vector3(1.6, 1.6, 1.6), 0.12)
	tween.tween_callback(deactivate)
