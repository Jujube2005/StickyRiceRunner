## SkyEffects – atmospheric particle systems that track the lead player.
## Keeps dust motes, drifting clouds, and birds in view throughout the run.
extends Node3D

var _p1: CharacterBody3D
var _p2: CharacterBody3D

# Local-space offsets from this node to each effect group.
# This node follows the lead player's Z; offsets place effects correctly.
const DUST_OFFSET   := Vector3(0.0,  0.4,   5.0)   # near, ground level
const CLOUD_OFFSET  := Vector3(0.0, 10.0, -70.0)   # far ahead, sky height
const BIRD_OFFSET   := Vector3(0.0, 13.0, -45.0)   # mid-distance, sky height

func _ready() -> void:
	# Pre-position children using their constant offsets so they start correct.
	if has_node("DustParticles"):
		$DustParticles.position = DUST_OFFSET
	if has_node("CloudParticles"):
		$CloudParticles.position = CLOUD_OFFSET
	if has_node("BirdsParticles"):
		$BirdsParticles.position = BIRD_OFFSET

func _process(_delta: float) -> void:
	# Lazily find players (spawned after GameManager sets them up).
	if not is_instance_valid(_p1):
		var scene := get_tree().current_scene
		_p1 = scene.find_child("Player1", true, false) as CharacterBody3D
		_p2 = scene.find_child("Player2", true, false) as CharacterBody3D
		if not is_instance_valid(_p1):
			return

	# Lead player = the one furthest ahead (smallest Z in Godot's -Z forward axis).
	var p2_z: float = _p2.global_position.z if is_instance_valid(_p2) else _p1.global_position.z
	var lead_z: float = minf(_p1.global_position.z, p2_z)

	# Slide this node in Z so all child particles stay around the action.
	global_position.z = lead_z - 10.0
