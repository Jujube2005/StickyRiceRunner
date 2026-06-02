extends Node

@export var obstacle_scene: PackedScene
@export var player1: CharacterBody3D
@export var player2: CharacterBody3D

var lanes = [-3, 0, 3]

var spawn_z = -20
@export var spawn_interval = 12
@export var spawn_interval_random = 4
@export var spawn_chance = 0.6

var spawned_obstacles = []

func _ready():
	randomize()
	await get_tree().process_frame
	for i in range(10):
		spawn_obstacle()

func _process(_delta):
	var lead_z = min(player1.global_position.z, player2.global_position.z)
	if lead_z < spawn_z + 80:
		spawn_obstacle()
		_cleanup_old_obstacles()

func spawn_obstacle():
	var selected_lanes = []
	for lane_x in lanes:
		if randf() < spawn_chance:
			selected_lanes.append(lane_x)

	if selected_lanes.size() == 3:
		selected_lanes.remove_at(randi() % selected_lanes.size())

	if selected_lanes.size() == 0:
		selected_lanes.append(lanes[randi() % lanes.size()])

	for lane_x in selected_lanes:
		_create_obstacle(lane_x)

	var interval = spawn_interval + randf_range(-spawn_interval_random, spawn_interval_random)
	spawn_z -= interval

func _create_obstacle(lane_x: float):
	var obs = obstacle_scene.instantiate()
	obs.set_script(load("res://scenes/obstacle/obstacle.gd"))
	obs.add_to_group("obstacle")
	get_parent().add_child(obs)
	
	# Balanced heights:
	# High = Human height (~1.8 - 2.2), must dodge
	# Low = Jumpable (~0.8 - 1.0), same as before
	var is_high = randf() < 0.6 # 60% are high obstacles
	var random_height = randf_range(1.8, 2.2) if is_high else randf_range(0.8, 1.0)
	obs.scale.y = random_height
	
	# Tag the obstacle for the bot to recognize
	if is_high:
		obs.add_to_group("high_obstacle")
	else:
		obs.add_to_group("low_obstacle")
	
	# Adjust Y position so it sits on the ground
	obs.position = Vector3(lane_x, random_height * 0.5, spawn_z)
	spawned_obstacles.append(obs)

func _cleanup_old_obstacles():
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	var i = 0
	while i < spawned_obstacles.size():
		var obs = spawned_obstacles[i]
		if is_instance_valid(obs) and obs.global_position.z > trail_z + 20:
			obs.queue_free()
			spawned_obstacles.remove_at(i)
		else:
			i += 1

func spawn_block_in_lane(lane_x: float, from_z: float):
	var obs = obstacle_scene.instantiate()
	obs.set_script(load("res://scenes/obstacle/obstacle.gd"))
	obs.add_to_group("obstacle")
	get_parent().add_child(obs)
	
	# Lane blocks (from Prank) are human-height
	var h = 2.0
	obs.scale.y = h
	obs.position = Vector3(lane_x, h * 0.5, from_z - 10)
	obs.add_to_group("high_obstacle")
	spawned_obstacles.append(obs)
