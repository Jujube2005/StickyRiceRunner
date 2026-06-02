extends Node3D

@export var ground_scene : PackedScene
@export var player1 : CharacterBody3D
@export var player2 : CharacterBody3D

var spawn_z = 0
var tile_length = 20
var spawned_tiles = []

func _ready():
	for i in range(15):
		spawn_ground()

func _process(_delta):
	# Use the player who is furthest ahead (most negative Z)
	var lead_z = min(player1.global_position.z, player2.global_position.z)
	
	if lead_z < spawn_z + 100:
		spawn_ground()
		_cleanup_old_tiles()

func spawn_ground():
	var ground = ground_scene.instantiate()
	ground.position = Vector3(0, -1, spawn_z)
	get_parent().get_node("World").add_child(ground)
	spawned_tiles.append(ground)
	
	# Add Random Scenery (Houses)
	_add_scenery(ground)
	
	spawn_z -= tile_length

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

func _cleanup_old_tiles():
	# Keep track of the trailing player
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	
	# Remove tiles that are far behind both players
	var i = 0
	while i < spawned_tiles.size():
		var tile = spawned_tiles[i]
		if is_instance_valid(tile) and tile.global_position.z > trail_z + 40:
			tile.queue_free()
			spawned_tiles.remove_at(i)
		else:
			i += 1