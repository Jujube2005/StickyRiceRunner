extends Node

@export var kratip_scene: PackedScene
@export var spawn_distance := 50.0 # Distance between pattern spawns
@export var lane_width := 3.0

# Pattern Definitions (Offsets from center spawn_z)
const PATTERNS = {
	"straight": [
		Vector3(-3, 0.5, 0), Vector3(-3, 0.5, -4), Vector3(-3, 0.5, -8), # Left
		Vector3(0, 0.5, 0), Vector3(0, 0.5, -4), Vector3(0, 0.5, -8),   # Center
		Vector3(3, 0.5, 0), Vector3(3, 0.5, -4), Vector3(3, 0.5, -8)    # Right
	],
	"arc_jump": [
		Vector3(-3, 0.5, 0), Vector3(-3, 1.5, -4), Vector3(-3, 0.5, -8), # Left Arc
		Vector3(3, 0.5, 0), Vector3(3, 1.5, -4), Vector3(3, 0.5, -8)     # Right Arc
	],
	"zigzag": [
		Vector3(-3, 0.5, 0), Vector3(0, 0.5, -4), Vector3(3, 0.5, -8)
	]
}

var player1 = null
var player2 = null
var spawn_z := 0.0
var pool = []
var max_pool_size := 80

func _ready():
	spawn_z = -20.0 # Start spawning ahead
	# Pre-allocate pool
	for i in range(max_pool_size):
		var k = kratip_scene.instantiate()
		add_child(k)
		k.deactivate()
		pool.append(k)

func _process(_delta):
	if !is_instance_valid(player1) or !is_instance_valid(player2):
		var scene = get_tree().current_scene
		player1 = scene.find_child("Player1", true, false)
		player2 = scene.find_child("Player2", true, false)
		if !is_instance_valid(player1) or !is_instance_valid(player2): return

	var lead_z = min(player1.global_position.z, player2.global_position.z)

	# Auto-recycle kratips that are far behind both players (passed and uncollected)
	var recycle_z = max(player1.global_position.z, player2.global_position.z) + 30.0
	for k in pool:
		if k.is_active and k.global_position.z > recycle_z:
			k.deactivate()

	if lead_z < spawn_z + 80:
		spawn_pattern()

func spawn_pattern():
	# Pick a random pattern
	var p_keys = PATTERNS.keys()
	var p_name = p_keys[randi() % p_keys.size()]
	var offsets = PATTERNS[p_name]
	
	# Pick random lane multiplier (to shift whole pattern if needed)
	# For simplicity, we use the hardcoded lane positions in offsets (-3, 0, 3)
	
	for offset in offsets:
		var y_pos = 0.4 if offset.y < 1.0 else offset.y
		var spawn_pos = Vector3(offset.x, y_pos, spawn_z + offset.z)
		_get_from_pool(spawn_pos)
	
	spawn_z -= spawn_distance

func _get_from_pool(pos: Vector3):
	for k in pool:
		if !k.is_active:
			k.activate(pos)
			return k
	return null
