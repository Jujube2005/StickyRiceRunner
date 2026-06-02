extends Area3D

@export var value := 1
@export var rotate_speed := 2.5
@export var float_speed := 1.5
@export var float_amplitude := 0.2

var is_collected := false
var start_y := 0.0
var time_passed := 0.0

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Wait one frame to get the correct global position from spawner
	await get_tree().process_frame
	start_y = global_position.y
	time_passed = randf() * PI * 2

func _process(delta):
	if is_collected: return
	
	time_passed += delta
	
	# Rotation
	$Model.rotate_y(rotate_speed * delta)
	
	# Hovering effect using global_position to avoid local transform issues
	global_position.y = start_y + sin(time_passed * float_speed) * float_amplitude

func _on_body_entered(body):
	if is_collected:
		return
		
	if body.name == "Player1" or body.name == "Player2":
		is_collected = true
		body.add_score(value)
		if body.has_method("add_charge"):
			body.add_charge(value)
		
		queue_free()