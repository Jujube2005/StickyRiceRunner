extends Area3D

@export var value := 1
@export var rotate_speed := 2.5
@export var float_speed := 1.5
@export var float_amplitude := 0.2

var collected_by: Array = []
var is_active := false
var start_y := 0.0
var time_passed := 0.0

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Start deactivated if instantiated through code
	if !is_active:
		deactivate()

func activate(pos: Vector3):
	is_active = true
	collected_by.clear()
	if $Model:
		$Model.set_layer_mask_value(1, true)
		$Model.set_layer_mask_value(2, false)
		$Model.set_layer_mask_value(3, false)
		
	position = pos
	start_y = pos.y
	time_passed = randf() * PI * 2
	visible = true
	
	set_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func deactivate():
	is_active = false
	visible = false
	call_deferred("set_position", Vector3(0, -100, 0))
	
	set_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _process(delta):
	if !is_active: return
	
	time_passed += delta
	
	# Rotation
	$Model.rotate_y(rotate_speed * delta)
	
	# Hovering effect
	position.y = start_y + sin(time_passed * float_speed) * float_amplitude

func _on_body_entered(body):
	if !is_active or body in collected_by:
		return
		
	if body.name == "Player1" or body.name == "Player2":
		collected_by.append(body)
		body.add_score(value)
		if body.has_method("add_charge"):
			body.add_charge(value)
		
		AudioManager.play_sfx("pickup")
		
		# Visual hide per player
		if body.name == "Player1":
			if $Model:
				_set_layer_mask($Model, 1, false)
				_set_layer_mask($Model, 3, true) # Only P2 can see now
		elif body.name == "Player2":
			if $Model:
				_set_layer_mask($Model, 1, false)
				_set_layer_mask($Model, 2, true) # Only P1 can see now
		
		# If both players collected it (or single player edge case), fully deactivate
		if collected_by.size() >= 2:
			deactivate()

func _set_layer_mask(node: Node, layer: int, value: bool):
	if node is VisualInstance3D:
		node.set_layer_mask_value(layer, value)
	for child in node.get_children():
		_set_layer_mask(child, layer, value)
