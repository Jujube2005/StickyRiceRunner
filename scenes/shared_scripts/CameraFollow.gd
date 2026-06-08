extends Camera3D

@export var target : Node3D
@export var follow_speed : float = 8.0
@export var roll_amount : float = 0.05
@export var fov_target : float = 75.0

var offset = Vector3(0, 4.5, 6.5)
var look_offset = Vector3(0, 2.5, 0)

func _ready():
	fov = fov_target

func _process(delta):
	if !is_instance_valid(target):
		return

	# Smooth Position
	var target_pos = target.global_position + offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Base Rotation
	var look_target = target.global_position + look_offset
	look_at(look_target)

	# Camera Roll based on lateral distance to target
	var lateral_diff = target.global_position.x - (global_position.x - offset.x)
	var target_roll = clamp(-lateral_diff * roll_amount, -0.12, 0.12)
	rotation.z = lerp(rotation.z, target_roll, follow_speed * delta)