extends Node3D

@export var ground_scene : PackedScene
@export var player1 : CharacterBody3D
@export var player2 : CharacterBody3D

@export var pool_size = 40 
@export var tile_length = 20.0
@export var despawn_threshold = 100.0 

var spawn_z = 0.0
var pool = []

func _ready():
	# Initial Pool Creation
	for i in range(pool_size):
		_create_pool_tile()

func _process(_delta):
	# เช็กตำแหน่งผู้เล่นทั้งคู่
	var lead_z = min(player1.global_position.z, player2.global_position.z)
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	
	while spawn_z > lead_z - 200.0:
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
	ground.position = Vector3(0, -1, spawn_z)
	get_parent().get_node("World").add_child(ground)
	pool.append(ground)
	
	# Initial Scenery
	_add_scenery(ground)
	
	spawn_z -= tile_length

func _recycle_tile(tile):
	# ย้ายไปข้างหน้าและล็อคค่า X, Y ให้ตรง
	tile.global_position = Vector3(0, -1, spawn_z)
	
	# Refresh scenery
	_refresh_scenery(tile)
	
	# เตรียมตำแหน่งถัดไป
	spawn_z -= tile_length
	
	# จัดลำดับ Array ใหม่
	pool.remove_at(0)
	pool.append(tile)

func _refresh_scenery(ground_node):
	# Clear old houses from the recycled tile
	var points = [
		ground_node.get_node("SceneryPoints/Left"),
		ground_node.get_node("SceneryPoints/Right"),
		ground_node.get_node("SceneryPoints/LeftFar"),
		ground_node.get_node("SceneryPoints/RightFar")
	]
	
	for p in points:
		for child in p.get_children():
			child.queue_free()
		
		# Add new random houses
		if randf() < 0.5: 
			var house = _create_prototype_house()
			p.add_child(house)
			house.rotation.y = randf() * PI * 2

func _add_scenery(ground_node):
	var points = [
		ground_node.get_node("SceneryPoints/Left"),
		ground_node.get_node("SceneryPoints/Right"),
		ground_node.get_node("SceneryPoints/LeftFar"),
		ground_node.get_node("SceneryPoints/RightFar")
	]
	
	for p in points:
		if randf() < 0.5: 
			var house = _create_prototype_house()
			p.add_child(house)
			house.rotation.y = randf() * PI * 2

func _create_prototype_house():
	var house_node = Node3D.new()
	
	# Randomize house size
	var h = randf_range(3.0, 7.0) # Height
	var w = randf_range(3.5, 5.5) # Width/Depth
	
	# Body
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(w, h, w)
	var mat = StandardMaterial3D.new()
	# Random house color (Cream, Gray, White, Light Blue)
	var colors = [Color(0.9, 0.8, 0.6), Color(0.5, 0.5, 0.5), Color(0.9, 0.9, 0.9), Color(0.7, 0.8, 0.9)]
	mat.albedo_color = colors[randi() % colors.size()]
	body_mesh.material = mat
	body.mesh = body_mesh
	# Position body so base is at Y=0 (relative to SceneryPoint)
	body.position.y = h / 2.0
	house_node.add_child(body)
	
	# Roof
	var roof = MeshInstance3D.new()
	var roof_mesh = PrismMesh.new()
	# Roof should be slightly wider than the house
	roof_mesh.size = Vector3(w + 1.0, 2.0, w + 1.0)
	var r_mat = StandardMaterial3D.new()
	# Random roof color (Orange, Blue, Brown, Dark Gray)
	var r_colors = [Color(0.8, 0.3, 0.1), Color(0.1, 0.3, 0.6), Color(0.4, 0.2, 0.1), Color(0.2, 0.2, 0.2)]
	r_mat.albedo_color = r_colors[randi() % r_colors.size()]
	roof_mesh.material = r_mat
	roof.mesh = roof_mesh
	# Position roof on top of the body
	roof.position.y = h + 1.0
	house_node.add_child(roof)
	
	return house_node
