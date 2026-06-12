extends Area3D

# ============================================================
# Luang Por Khoon Coin — collectible item
# Spawned when a player collects 10 Kratips.
# On pickup: grants 5s protection to the collecting player,
#            records the coin in CollectionManager.
# ============================================================

@export var float_speed    := 1.2
@export var float_amplitude := 0.18
@export var rotate_speed   := 2.0

var coin_data    : Dictionary = {}  # Set by spawner: { id, name, ... }
var is_active    := false
var is_collected := false
var start_y      := 0.0
var time_passed  := 0.0

var model_node: Node3D

func _ready():
	_build_visuals()
	connect("body_entered", Callable(self, "_on_body_entered"))
	if !is_active:
		deactivate()

func _build_visuals():
	# Collision
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.55
	col.shape = sphere
	col.position.y = 0.5
	add_child(col)
	
	# Model Root
	model_node = Node3D.new()
	model_node.position.y = 0.5
	add_child(model_node)
	
	# Materials
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.78, 0.1)
	gold_mat.metallic = 1.0
	gold_mat.roughness = 0.15
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.65, 0.0)
	gold_mat.emission_energy_multiplier = 1.2
	
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.85, 0.55, 0.05)
	rim_mat.metallic = 1.0
	rim_mat.roughness = 0.08
	
	# Meshes
	var face_mesh = CylinderMesh.new()
	face_mesh.top_radius = 0.45
	face_mesh.bottom_radius = 0.45
	face_mesh.height = 0.12
	face_mesh.radial_segments = 32
	var face_inst = MeshInstance3D.new()
	face_inst.mesh = face_mesh
	face_inst.set_surface_override_material(0, gold_mat)
	model_node.add_child(face_inst)
	
	var rim_mesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.46
	rim_mesh.bottom_radius = 0.46
	rim_mesh.height = 0.14
	rim_mesh.radial_segments = 32
	var rim_inst = MeshInstance3D.new()
	rim_inst.mesh = rim_mesh
	rim_inst.set_surface_override_material(0, rim_mat)
	model_node.add_child(rim_inst)
	
	# Light
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.75, 0.1)
	light.light_energy = 2.5
	light.omni_range = 2.5
	light.position.y = 0.6
	add_child(light)
	
	# Particles
	var particles = CPUParticles3D.new()
	particles.amount = 16
	particles.lifetime = 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.5
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 30.0
	particles.gravity = Vector3(0, 0.3, 0)
	particles.initial_velocity_min = 0.15
	particles.initial_velocity_max = 0.4
	particles.color = Color(1, 0.85, 0.2, 0.9)
	particles.position.y = 0.5
	add_child(particles)

func activate(pos: Vector3, data: Dictionary):
	coin_data    = data
	is_active    = true
	is_collected = false
	global_position = pos
	start_y      = pos.y
	time_passed  = randf() * TAU
	visible      = true
	set_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func deactivate():
	is_active = false
	visible   = false
	global_position = Vector3(0, -200, 0)
	set_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _process(delta):
	if !is_active or is_collected: return
	time_passed += delta
	# Float
	global_position.y = start_y + sin(time_passed * float_speed) * float_amplitude
	# Spin
	rotation.y += rotate_speed * delta

func _on_body_entered(body):
	if !is_active or is_collected: return
	if not (body.name == "Player1" or body.name == "Player2"): return

	is_collected = true

	# 1. Grant protection to the player
	if body.has_method("grant_coin_protection"):
		body.grant_coin_protection()

	# 2. Record in Collection
	var is_new: bool = false
	if coin_data.has("id"):
		is_new = CollectionManager.add_coin(coin_data["id"])

	# 3. SFX
	AudioManager.play_sfx("pickup")

	# 4. Unlock notification via HUD
	if is_new and coin_data.has("name"):
		var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
		if hud and hud.has_method("show_coin_unlock"):
			hud.show_coin_unlock(coin_data["name"])

	# 5. Pop-scale then deactivate
	var tween = create_tween()
	tween.tween_property(model_node, "scale", Vector3(1.6, 1.6, 1.6), 0.12)
	tween.tween_callback(deactivate)
