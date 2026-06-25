extends Node3D

const HOMEKORAT = preload("res://assets/models/ground/homekorat.glb")
const KILN = preload("res://assets/models/ground/Kiln.glb")
const TREEV3 = preload("res://assets/models/ground/treeV3.glb")
const CLAYJAR = preload("res://assets/models/ground/clayjar.glb")
const TREEV1 = preload("res://assets/models/ground/treeV1.glb")
const HAYSTACKV1 = preload("res://assets/models/ground/haystackV1.glb")
const HAYSTACKV2 = preload("res://assets/models/ground/haystackV2.glb")
const OLDSPIRITHOUSE = preload("res://assets/models/ground/oldSpirithouse.glb")
const BUFFALO = preload("res://assets/models/ground/buffalo.glb")
const ISANTHAIHOUSE = preload("res://assets/models/ground/isanthaihouse.glb")

var _used_positions = []

func _ready():
	randomize()
	_used_positions.clear()
	
	# Spawn densities per tile (approximate numbers, randomly varied)
	_spawn_random(HOMEKORAT, randi_range(0, 1), Vector3(1, 1, 1), Vector3(deg_to_rad(-90.0), deg_to_rad(90.0), 0.0), 8.0)
	_spawn_random(KILN, randi_range(0, 1), Vector3(2.27, 3.17, 2.18), Vector3(0.0, deg_to_rad(65.0), 0.0), 6.0)
	_spawn_random(TREEV3, randi_range(3, 7), Vector3(0.05, 0.07, 0.05), Vector3(0.0, 0.0, 0.0), 3.0, true) # Random Y rot
	_spawn_random(CLAYJAR, randi_range(2, 6), Vector3(1.0, 1.0, 1.0), Vector3.ZERO, 1.0, true, true) # Special scale logic later
	_spawn_random(TREEV1, randi_range(5, 12), Vector3(1500, 1500, 1500), Vector3.ZERO, 4.0, true, false, true) # scale 1500-2000
	_spawn_random(HAYSTACKV1, randi_range(1, 3), Vector3(15, 15, 15), Vector3.ZERO, 4.0, true)
	_spawn_random(HAYSTACKV2, randi_range(1, 3), Vector3(5, 5, 5), Vector3.ZERO, 3.0, true)
	_spawn_random(OLDSPIRITHOUSE, randi_range(0, 1), Vector3(5, 5, 5), Vector3(0.0, deg_to_rad(-90.0), 0.0), 3.0)
	_spawn_random(BUFFALO, randi_range(1, 3), Vector3(2, 2, 2), Vector3(0.0, deg_to_rad(-180.0), 0.0), 4.0)
	_spawn_random(ISANTHAIHOUSE, randi_range(0, 1), Vector3(4, 4, 4), Vector3(0.0, deg_to_rad(-180.0), 0.0), 10.0)

func _spawn_random(scene: PackedScene, count: int, scale_vec: Vector3, rot_vec: Vector3, radius: float, random_y_rot: bool = false, random_scale_clayjar: bool = false, random_scale_tree: bool = false):
	for _i in range(count):
		for _attempt in range(5):
			# Randomly pick left or right side of the road, and keep off the road based on object radius!
			var min_x = 5.0 + radius
			var is_left = randf() < 0.5
			var tx = randf_range(-25.0, -min_x) if is_left else randf_range(min_x, 25.0)
			var tz = randf_range(-4.0, 4.0)
			var pos = Vector3(tx, 0.0, tz)
			
			if scene == HOMEKORAT:
				pos.x = -5.565 if is_left else 5.565
				pos.y = 0.068
			elif scene == ISANTHAIHOUSE:
				pos.x = -13.46 if is_left else 13.46
				pos.y = -0.34
			
			var final_scale = scale_vec
			if random_scale_clayjar:
				var s = randf_range(0.2, 0.8)
				final_scale = Vector3(s, s, s)
			elif random_scale_tree:
				var sy = randf_range(1500.0, 2000.0)
				final_scale = Vector3(scale_vec.x, sy, scale_vec.z)
				
			var final_rot = rot_vec
			if random_y_rot:
				final_rot.y = randf_range(0.0, PI * 2)
				
			if _place(scene, pos, final_scale, final_rot, radius):
				break

func _place(scene: PackedScene, local_pos: Vector3, scale_vec: Vector3, rotation_vec: Vector3, radius: float) -> bool:
	for item in _used_positions:
		if local_pos.distance_to(item.pos) < (radius + item.radius):
			return false
	
	_used_positions.append({"pos": local_pos, "radius": radius})
	
	var inst = scene.instantiate()
	var points = get_node_or_null("SceneryPoints")
	if points:
		points.add_child(inst)
	else:
		add_child(inst)
		
	inst.position = local_pos
	inst.rotation = rotation_vec
	inst.scale = scale_vec
	return true
