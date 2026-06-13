extends Area3D

var is_active = false
@onready var collision_shape = $CollisionShape3D

# These nodes may or may not exist depending on the obstacle type (firewood stacking)
var firewood_mid: Node3D = null
var firewood_top: Node3D = null

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Optional stacking nodes — only exist in firewood (zone 1)
	firewood_mid = get_node_or_null("firewood_mid")
	firewood_top = get_node_or_null("firewood_top")
	
	if firewood_mid and collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	
	# Start deactivated if instantiated through code
	if !is_active:
		deactivate()

func activate(pos: Vector3, height: float, high_obstacle: bool):
	is_active = true
	position = pos
	
	# Reset scale to its original editor value (1.5) since we use stacked models instead of stretching
	scale = Vector3(1.5, 1.5, 1.5)
	visible = true
	
	# Reset groups (important for pooling)
	if is_in_group("high_obstacle"): remove_from_group("high_obstacle")
	if is_in_group("low_obstacle"): remove_from_group("low_obstacle")
	
	if high_obstacle:
		add_to_group("high_obstacle")
		if firewood_mid:
			firewood_mid.visible = true
		if firewood_top:
			firewood_top.visible = true
		if collision_shape and collision_shape.shape is BoxShape3D:
			collision_shape.shape.size.y = 1.8
			collision_shape.position.y = 0.24
	else:
		add_to_group("low_obstacle")
		if firewood_mid:
			firewood_mid.visible = false
		if firewood_top:
			firewood_top.visible = false
		if collision_shape and collision_shape.shape is BoxShape3D:
			collision_shape.shape.size.y = 0.623
			collision_shape.position.y = -0.297
	
	# Enable processing and collision
	set_process(true)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

func deactivate():
	is_active = false
	visible = false
	
	# Move far away just in case (deferred to avoid Jolt physics errors during flush_events)
	call_deferred("set_position", Vector3(0, -100, 0))
	
	# Disable processing and collision
	set_process(false)
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)

func _on_body_entered(body) -> void:
	if !is_active: return
	
	var node_body := body as Node
	if node_body and node_body.has_method("stun"):
		node_body.call("stun", 2.0)
		AudioManager.play_sfx("obstacle_hit")
		# Instead of queue_free, we deactivate
		deactivate()
