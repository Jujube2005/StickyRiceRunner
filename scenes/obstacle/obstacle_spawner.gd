extends Node

@export var obstacle_zone1: PackedScene = preload("res://scenes/obstacle/obstacle.tscn")
@export var obstacle_zone2: PackedScene = preload("res://scenes/obstacle/obstacle_zone2.tscn")
@export var obstacle_zone3: PackedScene = preload("res://scenes/obstacle/obstacle_zone3.tscn")

@export var player1: CharacterBody3D
@export var player2: CharacterBody3D

@export var pool_size = 60
var obstacle_pool = []

var lanes = [-3, 0, 3]
var spawn_z = -20
@export var spawn_interval = 12
@export var spawn_interval_random = 4
@export var spawn_chance = 0.6

var _current_zone: int = 1

func _ready():
	randomize()
	_init_pool()
	
	# Initial spawn
	for i in range(10):
		spawn_obstacle()

func _get_zone_scene() -> PackedScene:
	var distance = abs(spawn_z)
	if distance >= 666.0:
		return obstacle_zone3
	elif distance >= 333.0:
		return obstacle_zone2
	else:
		return obstacle_zone1

func _init_pool():
	for i in range(pool_size):
		var obs = obstacle_zone1.instantiate()
		obs.set_script(load("res://scenes/obstacle/obstacle.gd"))
		obs.add_to_group("obstacle")
		get_parent().add_child.call_deferred(obs)
		obstacle_pool.append(obs)

func _get_from_pool_for_zone(zone_scene: PackedScene):
	# Try to find an inactive obstacle of the same scene type
	for obs in obstacle_pool:
		if !obs.is_active and obs.get_meta("zone_scene", "") == zone_scene.resource_path:
			return obs
	
	# No matching inactive — get any inactive and swap its visual
	for obs in obstacle_pool:
		if !obs.is_active:
			return obs
	
	# Pool exhausted — grow dynamically
	push_warning("Obstacle pool exhausted! Growing pool dynamically.")
	if zone_scene:
		var obs = zone_scene.instantiate()
		obs.set_script(load("res://scenes/obstacle/obstacle.gd"))
		obs.add_to_group("obstacle")
		obs.set_meta("zone_scene", zone_scene.resource_path)
		get_parent().add_child(obs)
		obstacle_pool.append(obs)
		return obs
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
	var zone_scene = _get_zone_scene()
	var obs = _get_from_pool_for_zone(zone_scene)
	if obs:
		var is_high = randf() < 0.5
		var pos = Vector3(lane_x, 1.0, z)
		obs.activate(pos, 1.0, is_high)

func _cleanup_old_obstacles():
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	for obs in obstacle_pool:
		if obs.is_active and obs.global_position.z > trail_z + 20:
			obs.deactivate()

func spawn_block_in_lane(lane_x: float, from_z: float):
	var zone_scene = _get_zone_scene()
	var obs = _get_from_pool_for_zone(zone_scene)
	if obs:
		var pos = Vector3(lane_x, 1.0, from_z - 10)
		obs.activate(pos, 1.0, true)
