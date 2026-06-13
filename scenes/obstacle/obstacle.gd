extends Area3D

@export var low_shape_size: Vector3 = Vector3(1.18, 0.623, 1.0)
@export var low_shape_pos: Vector3 = Vector3(0.034, -0.297, 0.0)
@export var high_shape_size: Vector3 = Vector3(1.18, 1.8, 1.0)
@export var high_shape_pos: Vector3 = Vector3(0.034, 0.24, 0.0)

var is_active = false
@onready var collision_shape = $CollisionShape3D

# These nodes may or may not exist depending on the obstacle type (firewood stacking)
var firewood_mid: Node3D = null
var firewood_top: Node3D = null

# These nodes exist for zone 2 and 3 alternate models
var model_low: Node3D = null
var model_high: Node3D = null

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Optional stacking nodes — only exist in firewood (zone 1)
	firewood_mid = get_node_or_null("firewood_mid")
	firewood_top = get_node_or_null("firewood_top")
	
	# Alternate models — exist in zone 2 and 3
	model_low = get_node_or_null("model_low")
	model_high = get_node_or_null("model_high")
	
	if collision_shape and collision_shape.shape:
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
		
		if model_low: model_low.visible = false
		if model_high: model_high.visible = true
				
		if collision_shape and collision_shape.shape is BoxShape3D:
			collision_shape.shape.size = high_shape_size
			collision_shape.position = high_shape_pos
	else:
		add_to_group("low_obstacle")
		if firewood_mid:
			firewood_mid.visible = false
			if firewood_top:
				firewood_top.visible = false
				
		if model_low: model_low.visible = true
		if model_high: model_high.visible = false
		
		if collision_shape and collision_shape.shape is BoxShape3D:
			collision_shape.shape.size = low_shape_size
			collision_shape.position = low_shape_pos
	
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
