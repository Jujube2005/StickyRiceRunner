extends Node3D

@export var spawn_distance_interval := 55.0 # Average distance between skill item spawns
@export var spawn_distance_random := 15.0  # Random variance in spawn distance
@export var pool_size := 15

var player1: CharacterBody3D = null
var player2: CharacterBody3D = null
var spawn_z := -30.0
var lanes := [-3, 0, 3]
var pool := []

func _ready():
	randomize()
	_init_pool()

func _init_pool():
	for i in range(pool_size):
		var item = _create_skill_item_programmatically()
		add_child(item)
		item.deactivate()
		pool.append(item)

func _create_skill_item_programmatically() -> Node:
	var script_res = load("res://scenes/skill_item/skill_item.gd")
	
	var item = Area3D.new()
	item.name = "SkillItem"
	item.set_script(script_res)
	item.collision_layer = 16
	item.collision_mask = 3
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.position.y = 0.35
	var sphere = SphereShape3D.new()
	sphere.radius = 0.7
	collision.shape = sphere
	item.add_child(collision)
	
	var model = Node3D.new()
	model.name = "Model"
	model.position.y = 0.35
	item.add_child(model)
	
	var body = MeshInstance3D.new()
	body.name = "RocketBody"
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.18
	body_mesh.bottom_radius = 0.18
	body_mesh.height = 0.7
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(1, 0.2, 0.5)
	mat_body.metallic = 0.8
	mat_body.roughness = 0.2
	mat_body.emission_enabled = true
	mat_body.emission = Color(1, 0.1, 0.4)
	mat_body.emission_energy_multiplier = 0.8
	body_mesh.material = mat_body
	body.mesh = body_mesh
	model.add_child(body)
	
	var nose = MeshInstance3D.new()
	nose.name = "RocketNose"
	var nose_mesh = CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.2
	nose_mesh.height = 0.3
	var mat_nose = StandardMaterial3D.new()
	mat_nose.albedo_color = Color(1, 0.75, 0)
	mat_nose.metallic = 0.9
	mat_nose.roughness = 0.1
	mat_nose.emission_enabled = true
	mat_nose.emission = Color(1, 0.7, 0)
	mat_nose.emission_energy_multiplier = 1.0
	nose_mesh.material = mat_nose
	nose.mesh = nose_mesh
	nose.position.y = 0.5
	model.add_child(nose)
	
	var fin_left = MeshInstance3D.new()
	fin_left.name = "FinLeft"
	var fin_mesh = BoxMesh.new()
	fin_mesh.size = Vector3(0.04, 0.2, 0.15)
	var mat_fin = StandardMaterial3D.new()
	mat_fin.albedo_color = Color(0, 0.8, 1)
	mat_fin.metallic = 0.6
	mat_fin.roughness = 0.3
	fin_mesh.material = mat_fin
	fin_left.mesh = fin_mesh
	fin_left.position = Vector3(-0.22, -0.25, 0)
	model.add_child(fin_left)
	
	var fin_right = fin_left.duplicate()
	fin_right.name = "FinRight"
	fin_right.position = Vector3(0.22, -0.25, 0)
	model.add_child(fin_right)
	
	var light = OmniLight3D.new()
	light.name = "GlowLight"
	light.light_color = Color(1, 0.2, 0.8)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 0.35
	item.add_child(light)
	
	var particles = CPUParticles3D.new()
	particles.name = "CPUParticles3D"
	particles.amount = 12
	particles.lifetime = 1.0
	particles.preprocess = 0.5
	particles.position.y = 0.35
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 20.0
	particles.gravity = Vector3(0, 0.2, 0)
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	
	var spark_mat = StandardMaterial3D.new()
	spark_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	spark_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1, 0.4, 0.8, 0.8)
	spark_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.12, 0.12)
	quad_mesh.material = spark_mat
	particles.mesh = quad_mesh
	
	var size_curve = Curve.new()
	size_curve.add_point(Vector2(0, 0))
	size_curve.add_point(Vector2(0.2, 1))
	size_curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = size_curve
	particles.color = Color(1, 0.6, 0.9, 1)
	item.add_child(particles)
	
	return item

func _get_from_pool() -> Node:
	for item in pool:
		if !item.is_active:
			return item
	return null

func _process(_delta):
	# Safe check/re-find players
	if !is_instance_valid(player1) or !is_instance_valid(player2):
		var scene = get_tree().current_scene
		player1 = scene.find_child("Player1", true, false)
		player2 = scene.find_child("Player2", true, false)
		if !is_instance_valid(player1) or !is_instance_valid(player2):
			return

	var lead_z = min(player1.global_position.z, player2.global_position.z)
	if lead_z < spawn_z + 80.0:
		spawn_skill_item()
		_cleanup_old_items()

func spawn_skill_item():
	var item = _get_from_pool()
	if item:
		var lane_x = lanes[randi() % lanes.size()]
		var pos = Vector3(lane_x, 0.5, spawn_z)
		item.activate(pos)
		print("[SPAWN] Skill Item spawned at lane %d, Z %d" % [lane_x, int(spawn_z)])

	# Determine next spawn Z
	var interval = spawn_distance_interval + randf_range(-spawn_distance_random, spawn_distance_random)
	# Avoid spawning exactly at Kratip rows (which spawn at multiples of 50m).
	# If next Z is close to a multiple of 50m, offset it by 10-15m
	var next_z = spawn_z - interval
	if abs(fmod(next_z, 50.0)) < 8.0:
		next_z -= 12.0
		
	spawn_z = next_z

func _cleanup_old_items():
	if !is_instance_valid(player1) or !is_instance_valid(player2): return
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	for item in pool:
		if item.is_active and item.global_position.z > trail_z + 20.0:
			item.deactivate()
