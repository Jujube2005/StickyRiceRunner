extends Area3D

@export var value := 1
@export var rotate_speed := 2.5
@export var float_speed := 1.5
@export var float_amplitude := 0.2

var is_collected := false
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
	is_collected = false
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
	if !is_active or is_collected: return
	
	time_passed += delta
	
	# Rotation
	$Model.rotate_y(rotate_speed * delta)
	
	# Hovering effect
	position.y = start_y + sin(time_passed * float_speed) * float_amplitude

func _on_body_entered(body):
	if !is_active or is_collected:
		return
		
	if body.name == "Player1" or body.name == "Player2":
		is_collected = true
		body.add_score(value)
		if body.has_method("add_charge"):
			body.add_charge(value)
		
		# VFX + SFX
		#VfxManager.spawn("kratib_pickup", global_position)
		AudioManager.play_sfx("pickup")
		
		# Pulse effect before deactivating (optional juice)
		var tween = create_tween()
		tween.tween_property($Model, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
		tween.tween_callback(deactivate)
		tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.0)