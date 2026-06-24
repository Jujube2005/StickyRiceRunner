extends Area3D

@export var float_speed := 2.0
@export var float_amplitude := 0.5
@export var rotation_speed := 1.5

var start_y: float = 0.0
var is_active := true
@export var box_type := "good" # "good" or "bad"
var collected_by: Array = []
var active_timer := 0.0

func _ready():
	add_to_group("skill_item")
	start_y = global_position.y
	body_entered.connect(_on_body_entered)
	_tint_box_mesh()

func _tint_box_mesh():
	var mesh_node = find_child("MeshInstance3D", true, false)
	if mesh_node and mesh_node.get_surface_override_material(0):
		var mat = mesh_node.get_surface_override_material(0).duplicate()
		if box_type == "good":
			mat.emission = Color(0.2, 1.0, 0.4)
		else:
			mat.emission = Color(1.0, 0.2, 0.2)
		mesh_node.set_surface_override_material(0, mat)

func _process(delta):
	if !is_active: return
	
	if active_timer > 0:
		active_timer -= delta
		if active_timer <= 0:
			deactivate()
			return
			
	# Float animation
	global_position.y = start_y + sin(Time.get_ticks_msec() * 0.001 * float_speed) * float_amplitude
	
	# Rotation animation
	rotation.y += rotation_speed * delta

func activate(pos: Vector3, type: String = "good"):
	global_position = pos
	start_y = pos.y
	is_active = true
	visible = true
	box_type = type
	collected_by.clear()
	
	if $MeshInstance3D:
		$MeshInstance3D.set_layer_mask_value(1, true)
		$MeshInstance3D.set_layer_mask_value(2, false)
		$MeshInstance3D.set_layer_mask_value(3, false)
		
	$CollisionShape3D.set_deferred("disabled", false)
	_tint_box_mesh()

func deactivate():
	is_active = false
	visible = false
	call_deferred("set_position", Vector3(0, -100, 0))
	set_deferred("monitorable", false)

func _on_body_entered(body):
	if !is_active: return
	
	# Detect player by capability
	if not body.has_method("add_skill"):
		return
		
	if body in collected_by:
		return
		
	collected_by.append(body)
	
	if box_type == "good":
		var gm = get_tree().current_scene.find_child("GameManager", true, false)
		var skill_name := ""
		
		if gm and gm.has_method("get_random_skill"):
			skill_name = gm.get_random_skill()
		else:
			var fallbacks = ["Rice Yard Dust", "Boon Bang Fai", "Pha Khao Ma", "Field Wind", "Screen Blur"]
			skill_name = fallbacks[randi() % fallbacks.size()]
		
		var skill_added: bool = body.add_skill(skill_name)
		if skill_added:
			AudioManager.play_sfx("skill_pickup")
	else:
		# Bad box logic
		var bad_skills = ["Boon Bang Fai", "Rice Yard Dust", "Screen Blur", "Lane Swap", "Invert Controls", "Pull to Center"]
		var bad_skill = bad_skills[randi() % bad_skills.size()]
		body.apply_prank(bad_skill)
		VfxManager.spawn("bad_box_pickup", global_position)
		AudioManager.play_sfx("obstacle_hit") # Play a negative sound

	# Visual hide per player
	if body.name == "Player1":
		if $MeshInstance3D:
			$MeshInstance3D.set_layer_mask_value(1, false)
			$MeshInstance3D.set_layer_mask_value(3, true) # Only P2 can see
	elif body.name == "Player2":
		if $MeshInstance3D:
			$MeshInstance3D.set_layer_mask_value(1, false)
			$MeshInstance3D.set_layer_mask_value(2, true) # Only P1 can see

	if collected_by.size() >= 2:
		deactivate()
