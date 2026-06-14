extends Camera3D

@export var target : Node3D
@export var follow_speed : float = 8.0
@export var roll_amount : float = 0.05
@export var fov_target : float = 75.0

var offset = Vector3(0, 4.5, 6.5)
var look_offset = Vector3(0, 2.5, 0)

func _ready():
	fov = fov_target

func _physics_process(delta):
	if !is_instance_valid(target):
		return

	# Target position with offset
	var target_pos = target.global_position + offset

	# Strictly lock Z position to prevent forward-axis shaking (Rubber-banding)
	# Lerp only X and Y for smooth lane changes and jumping
	var new_x = lerp(global_position.x, target_pos.x, follow_speed * delta)
	var new_y = lerp(global_position.y, target_pos.y, (follow_speed * 1.5) * delta)
	global_position = Vector3(new_x, new_y, target_pos.z)

	# Base Rotation
	var look_target = target.global_position + look_offset
	# strictly lock the look target Z as well
	look_target.z = target.global_position.z + look_offset.z
	look_target.x = lerp(global_position.x - offset.x, target.global_position.x + look_offset.x, follow_speed * delta)
	
	look_at(look_target)

	# Camera Roll based on lateral distance to target
	var lateral_diff = target.global_position.x - (global_position.x - offset.x)
	var target_roll = clamp(-lateral_diff * roll_amount, -0.12, 0.12)
	rotation.z = lerp(rotation.z, target_roll, follow_speed * delta)