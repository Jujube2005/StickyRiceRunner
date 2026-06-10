extends Area3D

var is_active = false

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Start deactivated if instantiated through code
	if !is_active:
		deactivate()

func activate(pos: Vector3, height: float, high_obstacle: bool):
	is_active = true
	position = pos
	scale.y = height
	visible = true
	
	# Reset groups (important for pooling)
	if is_in_group("high_obstacle"): remove_from_group("high_obstacle")
	if is_in_group("low_obstacle"): remove_from_group("low_obstacle")
	
	if high_obstacle:
		add_to_group("high_obstacle")
	else:
		add_to_group("low_obstacle")
	
	# Enable processing and collision
	set_process(true)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

func deactivate():
	is_active = false
	visible = false
	# Move far away just in case
	position = Vector3(0, -100, 0)
	
	# Disable processing and collision
	set_process(false)
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)

func _on_body_entered(body) -> void:
	if !is_active: return
	
	var node_body := body as Node
	if node_body and node_body.has_method("stun"):
		node_body.call("stun", 2.0)
		# VFX at player's chest position
		#VfxManager.spawn("obstacle_hit", node_body.global_position + Vector3(0, 1.0, 0))
		AudioManager.play_sfx("obstacle_hit")
		# Instead of queue_free, we deactivate
		deactivate()
