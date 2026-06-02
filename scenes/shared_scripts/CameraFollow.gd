extends Camera3D

@export var target : Node3D
@export var follow_speed : float = 8.0
@export var roll_amount : float = 0.15
@export var fov_target : float = 115.0

var offset = Vector3(0, 1.5, 2.2)

func _ready():
	fov = fov_target

func _process(delta):
	if target == null:
		return

	# Smooth Position
	var target_pos = target.global_position + offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Base Rotation
	var look_target = target.global_position + Vector3(0, 1.5, 0)
	look_at(look_target)

	# Camera Roll based on lateral distance to target
	# When target is to the left of where camera "expects" it, roll accordingly
	var lateral_diff = target.global_position.x - (global_position.x - offset.x)
	var target_roll = clamp(-lateral_diff * roll_amount, -0.15, 0.15)
	rotation.z = lerp(rotation.z, target_roll, follow_speed * delta)