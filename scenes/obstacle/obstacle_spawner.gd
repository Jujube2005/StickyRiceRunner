extends Node

@export var obstacle_scene: PackedScene
@export var player1: CharacterBody3D
@export var player2: CharacterBody3D

@export var pool_size = 40
var obstacle_pool = []

var lanes = [-3, 0, 3]
var spawn_z = -20
@export var spawn_interval = 12
@export var spawn_interval_random = 4
@export var spawn_chance = 0.6

func _ready():
	randomize()
	_init_pool()
	
	# Initial spawn
	for i in range(10):
		spawn_obstacle()

func _init_pool():
	for i in range(pool_size):
		var obs = obstacle_scene.instantiate()
		# Ensure script is attached
		obs.set_script(load("res://scenes/obstacle/obstacle.gd"))
		obs.add_to_group("obstacle")
		get_parent().add_child.call_deferred(obs)
		obstacle_pool.append(obs)

func _get_from_pool():
	for obs in obstacle_pool:
		if !obs.is_active:
			return obs
	
	# Pool is empty: push warning and return null to skip spawning
	push_warning("Obstacle pool exhausted! Increase pool_size in ObstacleSpawner.")
	return null

func _process(_delta):
	if !is_instance_valid(player1) or !is_instance_valid(player2):
		var scene = get_tree().current_scene
		player1 = scene.find_child("Player1", true, false)
		player2 = scene.find_child("Player2", true, false)
		if !is_instance_valid(player1) or !is_instance_valid(player2): return

	var lead_z = min(player1.global_position.z, player2.global_position.z)
	if lead_z < spawn_z + 80:
		spawn_obstacle()
		_cleanup_old_obstacles()

func spawn_obstacle():
	if !is_instance_valid(player1) or !is_instance_valid(player2): return
	var selected_lanes = []
	for lane_x in lanes:
		if randf() < spawn_chance:
			selected_lanes.append(lane_x)

	if selected_lanes.size() == 3:
		selected_lanes.remove_at(randi() % selected_lanes.size())

	if selected_lanes.size() == 0:
		selected_lanes.append(lanes[randi() % lanes.size()])

	for lane_x in selected_lanes:
		_spawn_obstacle_from_pool(lane_x, spawn_z)

	var interval = spawn_interval + randf_range(-spawn_interval_random, spawn_interval_random)
	spawn_z -= interval

func _spawn_obstacle_from_pool(lane_x: float, z: float):
	var obs = _get_from_pool()
	if obs:
		var is_high = randf() < 0.6
		var random_height = randf_range(1.8, 2.2) if is_high else randf_range(0.8, 1.0)
		var pos = Vector3(lane_x, random_height * 0.5, z)
		obs.activate(pos, random_height, is_high)

func _cleanup_old_obstacles():
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	for obs in obstacle_pool:
		if obs.is_active and obs.global_position.z > trail_z + 20:
			obs.deactivate()

func spawn_block_in_lane(lane_x: float, from_z: float):
	var obs = _get_from_pool()
	if obs:
		var h = 2.0
		var pos = Vector3(lane_x, h * 0.5, from_z - 10)
		obs.activate(pos, h, true)
