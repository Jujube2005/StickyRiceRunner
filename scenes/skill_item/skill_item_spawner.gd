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
	var scene = load("res://scenes/skill_item/skill_item.tscn")
	for i in range(pool_size):
		var item = scene.instantiate()
		add_child(item)
		item.deactivate()
		pool.append(item)


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
