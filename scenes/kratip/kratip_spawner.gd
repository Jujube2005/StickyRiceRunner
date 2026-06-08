extends Node

@export var kratip_scene: PackedScene
@export var player1: CharacterBody3D
@export var player2: CharacterBody3D

@export var pool_size = 20
var kratip_pool = []

var lanes = [-3, 0, 3]
var spawn_z = -20
@export var spawn_interval = 10

func _ready():
	_init_pool()

func _init_pool():
	for i in range(pool_size):
		var k = kratip_scene.instantiate()
		k.add_to_group("kratip")
		get_parent().add_child.call_deferred(k)
		kratip_pool.append(k)

func _get_from_pool():
	for k in kratip_pool:
		if !k.is_active:
			return k
	
	push_warning("Kratip pool exhausted! Increase pool_size in KratipSpawner.")
	return null

func _process(_delta):
	if !is_instance_valid(player1) or !is_instance_valid(player2):
		var scene = get_tree().current_scene
		player1 = scene.find_child("Player1", true, false)
		player2 = scene.find_child("Player2", true, false)
		if !is_instance_valid(player1) or !is_instance_valid(player2): return

	var lead_z = min(player1.global_position.z, player2.global_position.z)
	if lead_z < spawn_z + 80:
		spawn_kratip()
		_cleanup_old_kratips()

func spawn_kratip():
	if !is_instance_valid(player1) or !is_instance_valid(player2): return
	var used_lanes = []
	for obstacle in get_tree().get_nodes_in_group("obstacle"):
		if is_instance_valid(obstacle) and obstacle.is_active and abs(obstacle.global_position.z - spawn_z) < 1.0:
			used_lanes.append(obstacle.global_position.x)

	var free_lanes = []
	for lane_x in lanes:
		var blocked = false
		for used in used_lanes:
			if abs(used - lane_x) < 0.1:
				blocked = true
				break
		if not blocked:
			free_lanes.append(lane_x)

	if free_lanes.size() == 0:
		spawn_z -= spawn_interval
		return

	var lane_x = free_lanes[randi() % free_lanes.size()]
	var k = _get_from_pool()
	if k:
		k.activate(Vector3(lane_x, 1.2, spawn_z))
	
	spawn_z -= spawn_interval

func _cleanup_old_kratips():
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	for k in kratip_pool:
		if k.is_active and k.global_position.z > trail_z + 20:
			k.deactivate()
