extends Camera3D

@export var target : Node3D

func _process(delta):

	if target == null:
		return

	global_position = target.global_position + Vector3(0, 5, 10)

	look_at(target.global_position + Vector3(0,2,0))