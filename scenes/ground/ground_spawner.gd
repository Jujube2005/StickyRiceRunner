extends Node3D

@export var ground_zone1 : PackedScene = preload("res://scenes/ground/ground_zone1.tscn")
@export var ground_zone2 : PackedScene = preload("res://scenes/ground/ground_zone2.tscn")
@export var ground_zone3 : PackedScene = preload("res://scenes/ground/ground_zone3.tscn")

@export var player1 : CharacterBody3D
@export var player2 : CharacterBody3D

@export var pool_size = 120 
@export var tile_length = 10.4
@export var despawn_threshold = 100.0 

var spawn_z = 0.0
var pool = []

func _ready():
	# Initial Pool Creation (Always Zone 1)
	for i in range(pool_size):
		_create_pool_tile()

func _get_current_zone_scene() -> PackedScene:
	# Calculate zone based on where the tile is actually being placed (spawn_z)
	var distance = abs(spawn_z)
	
	if distance >= 666.0:
		return ground_zone3
	elif distance >= 333.0:
		return ground_zone2
	else:
		return ground_zone1

func _process(_delta):
	# เช็กตำแหน่งผู้เล่นทั้งคู่
	if !is_instance_valid(player1) or !is_instance_valid(player2):
		var scene = get_tree().current_scene
		player1 = scene.find_child("Player1", true, false)
		player2 = scene.find_child("Player2", true, false)
		if !is_instance_valid(player1) or !is_instance_valid(player2): return

	var lead_z = min(player1.global_position.z, player2.global_position.z)
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	
	while spawn_z > lead_z - 200.0 and pool.size() > 0:
		# ถ้าถนนข้างหน้าสั้นไป ให้พยายาม Recycle แผ่นที่อยู่หลังสุดมาวางข้างหน้าทันที
		var oldest_tile = pool[0]
		if oldest_tile.global_position.z > trail_z + despawn_threshold:
			_recycle_tile(oldest_tile)
		else:
			break
	
	while pool.size() > 0:
		var oldest_tile = pool[0]
		if oldest_tile.global_position.z > trail_z + despawn_threshold:
			_recycle_tile(oldest_tile)
		else:
			break

func _create_pool_tile():
	var scene_to_spawn = _get_current_zone_scene()
	if !scene_to_spawn: return
	
	var ground = scene_to_spawn.instantiate()
	
	# Randomize decorations to prevent them from repeating every 10 meters and looking like a wall
	var preserve_names = ["CollisionShape3D", "road01", "road02", "SideGroundLeft", "SideGroundRight", "SceneryPoints"]
	for child in ground.get_children():
		if child.name in preserve_names:
			continue
		
		# 55% chance to spawn each decoration, 45% chance to delete it
		if randf() > 0.55:
			child.queue_free()
	
	# Rotation disabled: keeping all tiles forward-facing so roadside trees,
	# poles, and buildings always align toward the same vanishing point,
	# creating a strong sense of forward perspective depth.
	
	ground.position = Vector3(0, 0, spawn_z)
	get_parent().get_node("World").add_child(ground)
	pool.append(ground)
	
	# Tag it so we know which zone it belongs to
	var gm = get_tree().current_scene.find_child("GameManager", true, false)
	ground.set_meta("zone", gm.current_zone if gm else 1)
	
	spawn_z -= tile_length

func _recycle_tile(tile):
	var gm = get_tree().current_scene.find_child("GameManager", true, false)
	var active_zone = gm.current_zone if gm else 1
	var tile_zone = tile.get_meta("zone") if tile.has_meta("zone") else 1
	
	pool.remove_at(0)
	
	# If the tile belongs to an old zone, delete it and spawn a new one in its place!
	if tile_zone != active_zone:
		tile.queue_free()
		_create_pool_tile()
	else:
		# Recycle the existing tile
		tile.global_position = Vector3(0, 0, spawn_z)
		spawn_z -= tile_length
		pool.append(tile)
