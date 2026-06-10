extends Node3D

@export var ground_scene : PackedScene
@export var player1 : CharacterBody3D
@export var player2 : CharacterBody3D

@export var pool_size = 120 
@export var tile_length = 10.4
@export var despawn_threshold = 100.0 

var spawn_z = 0.0
var pool = []

func _ready():
	# Automatically stretch the collision shape and side grounds to match the tile_length
	var temp_ground = ground_scene.instantiate()
	var col = temp_ground.get_node_or_null("CollisionShape3D")
	if col and col.shape is BoxShape3D:
		col.shape.size.z = tile_length
		
	var side_left = temp_ground.get_node_or_null("SideGroundLeft")
	if side_left and side_left.mesh is BoxMesh:
		side_left.mesh.size.z = tile_length
		
	temp_ground.free()

	# Initial Pool Creation
	for i in range(pool_size):
		_create_pool_tile()

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
	var ground = ground_scene.instantiate()
	ground.position = Vector3(0, 0, spawn_z)
	get_parent().get_node("World").add_child(ground)
	pool.append(ground)
	
	spawn_z -= tile_length

func _recycle_tile(tile):
	# ย้ายไปข้างหน้าและล็อคค่า X, Y ให้ตรง
	tile.global_position = Vector3(0, 0, spawn_z)
	
	# เตรียมตำแหน่งถัดไป
	spawn_z -= tile_length
	
	# จัดลำดับ Array ใหม่
	pool.remove_at(0)
	pool.append(tile)
