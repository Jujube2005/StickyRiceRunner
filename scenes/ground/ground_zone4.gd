extends StaticBody3D

# Ground Zone 4 - Khon Kaen theme
# Khaen:          always both sides of road
# khonkaencitygate: spaced 300-400m apart, must not overlap sirindhornae
# sirindhornae:   random, must not be placed if citygate is here this tile
# Kinareemimus:   random both sides
# treeV1:         random scatter

const KHAEN        = preload("res://assets/models/ground/Khaen.glb")
const CITYGATE     = preload("res://assets/models/ground/khonkaencitygate.glb")
const SIRINDHORNAE = preload("res://assets/models/ground/Phuwiangosaurus sirindhornae.glb")
const KINARE       = preload("res://assets/models/ground/Kinareemimus khonkaenesis.glb")
const TREEV1       = preload("res://assets/models/ground/treeV1.glb")

# Shared across all tile instances — tracks the last citygate global Z
static var _last_citygate_z: float = -99999.0

const LEFT_SIDE_X  := -12.0
const RIGHT_SIDE_X :=  12.0
const FAR_LEFT_X   := -18.0
const FAR_RIGHT_X  :=  18.0

func _ready():
	_spawn_decorations()

func _spawn_decorations():
	var my_global_z = global_position.z

	# 1. Khaen — always on both sides, facing road
	_place(KHAEN, Vector3(LEFT_SIDE_X, 0.0, randf_range(-3.0, 3.0)),  Vector3(0.2, 0.2, 0.2),    90.0)
	_place(KHAEN, Vector3(RIGHT_SIDE_X, 0.0, randf_range(-3.0, 3.0)), Vector3(0.2, 0.2, 0.2),   -90.0)

	# 2. khonkaencitygate — spaced 300-400m apart, facing road
	var gate_placed_this_tile := false
	var dist_since_gate = abs(my_global_z - _last_citygate_z)
	if dist_since_gate >= 300.0:
		var chance = clamp((dist_since_gate - 300.0) / 100.0, 0.0, 1.0)
		if randf() < chance:
			# Left gate faces right (+90), right gate faces left (-90)
			_place(CITYGATE, Vector3(LEFT_SIDE_X, 0.0, 0.0),  Vector3(9.0, 9.0, 9.0),  90.0)
			_place(CITYGATE, Vector3(RIGHT_SIDE_X, 0.0, 0.0), Vector3(9.0, 9.0, 9.0), -90.0)
			_last_citygate_z = my_global_z
			gate_placed_this_tile = true

	# 3. sirindhornae — random, skip if gate is here (avoid overlap)
	if not gate_placed_this_tile and randf() < 0.4:
		var side_x = FAR_LEFT_X if randf() < 0.5 else FAR_RIGHT_X
		var rot_y = 90.0 if side_x < 0 else -90.0
		_place(SIRINDHORNAE, Vector3(side_x, 0.0, randf_range(-3.0, 3.0)), Vector3(1.0, 1.0, 1.0), rot_y)

	# 4. Kinareemimus — random on each side independently
	if randf() < 0.5:
		var s = randf_range(0.2, 0.3)
		_place(KINARE, Vector3(LEFT_SIDE_X + randf_range(-2.0, 2.0), 0.0, randf_range(-4.0, 4.0)),  Vector3(s, s, s),  90.0)
	if randf() < 0.5:
		var s = randf_range(0.2, 0.3)
		_place(KINARE, Vector3(RIGHT_SIDE_X + randf_range(-2.0, 2.0), 0.0, randf_range(-4.0, 4.0)), Vector3(s, s, s), -90.0)

	# 5. Trees — treeV1 only, random scatter on far sides
	for _i in range(randi_range(1, 3)):
		var side_x = FAR_LEFT_X + randf_range(-3.0, 0.0) if randf() < 0.5 else FAR_RIGHT_X + randf_range(0.0, 3.0)
		_place(TREEV1, Vector3(side_x, 0.0, randf_range(-4.0, 4.0)), Vector3(1500.0, 1500.0, 1500.0), randf_range(0.0, 360.0))

# rotation_y: exact degrees to apply (use randf_range(0,360) call-site for random trees)
func _place(scene: PackedScene, local_pos: Vector3, scale_vec: Vector3, rotation_y: float):
	if not scene:
		return
	var inst = scene.instantiate()
	inst.position = local_pos
	inst.scale = scale_vec
	inst.rotation_degrees.y = rotation_y
	add_child(inst)
