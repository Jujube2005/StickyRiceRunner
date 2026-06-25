extends StaticBody3D

# Ground Zone 4 - Khon Kaen theme
# khonkaencitygate: centered on road (like an arch you run under), spaced 300-400m
# Khaen:           random on one side, same spacing logic (~200-300m)
# sirindhornae:    random, skip if gate is here
# Kinareemimus:    random both sides
# treeV1:          random scatter

const KHAEN        = preload("res://assets/models/ground/Khaen.glb")
const CITYGATE     = preload("res://assets/models/ground/khonkaencitygate.glb")
const SIRINDHORNAE = preload("res://assets/models/ground/Phuwiangosaurus sirindhornae.glb")
const KINARE       = preload("res://assets/models/ground/Kinareemimus khonkaenesis.glb")
const TREEV1       = preload("res://assets/models/ground/treeV1.glb")

# Shared across all tile instances
static var _last_citygate_z: float = -99999.0
static var _last_khaen_z: float    = -99999.0

const LEFT_SIDE_X  := -12.0
const RIGHT_SIDE_X :=  12.0
const FAR_LEFT_X   := -18.0
const FAR_RIGHT_X  :=  18.0

var _used_positions: Array[Dictionary] = []

func _ready():
	_spawn_decorations()

func _spawn_decorations():
	_used_positions.clear()
	var my_global_z = global_position.z

	# 1. khonkaencitygate — single, centered on road (X=0), spaced 300-400m apart
	#    Rotation Y=0 so the gate faces forward (player runs through it)
	var gate_placed_this_tile := false
	var dist_since_gate = abs(my_global_z - _last_citygate_z)
	if dist_since_gate >= 300.0:
		var chance = clamp((dist_since_gate - 300.0) / 100.0, 0.0, 1.0)
		if randf() < chance:
			_place(CITYGATE, Vector3(0.0, 0.0, 0.0), Vector3(9.0, 9.0, 9.0), 0.0, 10.0)
			_last_citygate_z = my_global_z
			gate_placed_this_tile = true

	# 2. Khaen — random one side, spaced 200-300m apart (not too frequent)
	var dist_since_khaen = abs(my_global_z - _last_khaen_z)
	if dist_since_khaen >= 200.0:
		var chance = clamp((dist_since_khaen - 200.0) / 100.0, 0.0, 1.0)
		if randf() < chance:
			var side_x = LEFT_SIDE_X if randf() < 0.5 else RIGHT_SIDE_X
			var rot_y = 90.0 if side_x < 0 else -90.0
			_place(KHAEN, Vector3(side_x, 0.0, randf_range(-3.0, 3.0)), Vector3(0.2, 0.2, 0.2), rot_y, 3.0)
			_last_khaen_z = my_global_z

	# 3. sirindhornae — random 40%, skip if gate is here, varied near/far + size
	if not gate_placed_this_tile and randf() < 0.4:
		# Randomize which side, how far from road, and how big
		var side_sign = -1.0 if randf() < 0.5 else 1.0
		var dist_from_road = randf_range(8.0, 20.0)   # Push further from road (was 5.0)
		var dino_scale = randf_range(0.6, 1.6)         # small to large
		var rot_y = 90.0 if side_sign < 0 else -90.0
		# Give it 5 retry attempts to find an empty spot
		for _attempt in range(5):
			var test_pos = Vector3(side_sign * randf_range(8.0, 20.0), 0.0, randf_range(-4.0, 4.0))
			if _place(SIRINDHORNAE, test_pos, Vector3(dino_scale, dino_scale, dino_scale), rot_y, 3.0 * dino_scale):
				break

	# 4. Kinareemimus — random, varied near/far + size per side
	if randf() < 0.5:
		var s = randf_range(0.15, 0.4)
		for _attempt in range(3):
			var test_pos = Vector3(-randf_range(6.0, 16.0), 0.0, randf_range(-4.0, 4.0))
			if _place(KINARE, test_pos, Vector3(s, s, s), 90.0, 2.0): break
	if randf() < 0.5:
		var s = randf_range(0.15, 0.4)
		for _attempt in range(3):
			var test_pos = Vector3(randf_range(6.0, 16.0), 0.0, randf_range(-4.0, 4.0))
			if _place(KINARE, test_pos, Vector3(s, s, s), -90.0, 2.0): break

	# 5. Trees — varied near/far and size, both sides, organic scatter
	var tree_count_left  = randi_range(2, 5)
	var tree_count_right = randi_range(2, 5)

	for _i in range(tree_count_left):
		var ts = randf_range(800.0, 2000.0)
		for _attempt in range(3):
			var tx = randf_range(-18.0, -8.0)
			if _place(TREEV1, Vector3(tx, 0.0, randf_range(-5.0, 5.0)), Vector3(ts, ts, ts), randf_range(0.0, 360.0), 4.0): break

	for _i in range(tree_count_right):
		var ts = randf_range(800.0, 2000.0)
		for _attempt in range(3):
			var tx = randf_range(8.0, 18.0)
			if _place(TREEV1, Vector3(tx, 0.0, randf_range(-5.0, 5.0)), Vector3(ts, ts, ts), randf_range(0.0, 360.0), 4.0): break

func _place(scene: PackedScene, local_pos: Vector3, scale_vec: Vector3, rotation_y: float, radius: float) -> bool:
	for item in _used_positions:
		if item.pos.distance_to(local_pos) < (item.radius + radius):
			return false # Overlaps with an existing object
			
	_used_positions.append({"pos": local_pos, "radius": radius})
	
	if not scene:
		return false
	var inst = scene.instantiate()
	inst.position = local_pos
	inst.scale = scale_vec
	inst.rotation_degrees.y = rotation_y
	add_child(inst)
	return true
