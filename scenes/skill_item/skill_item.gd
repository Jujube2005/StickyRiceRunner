extends Area3D

@export var float_speed := 2.0
@export var float_amplitude := 0.5
@export var rotation_speed := 1.5

var start_y: float = 0.0
var is_active := true

func _ready():
	add_to_group("skill_item")
	start_y = global_position.y
	body_entered.connect(_on_body_entered)

func _process(delta):
	if !is_active: return
	
	# Float animation
	global_position.y = start_y + sin(Time.get_ticks_msec() * 0.001 * float_speed) * float_amplitude
	
	# Rotation animation
	rotation.y += rotation_speed * delta

func activate(pos: Vector3):
	global_position = pos
	start_y = pos.y
	is_active = true
	visible = true
	$CollisionShape3D.set_deferred("disabled", false)

func deactivate():
	is_active = false
	visible = false
	call_deferred("set_position", Vector3(0, -100, 0))
	set_deferred("monitorable", false)

func _on_body_entered(body):
	if !is_active: return
	
	# Detect player by capability, not group (players.gd may not be in "player" group)
	if not body.has_method("add_skill"):
		return
	
	var gm = get_tree().current_scene.find_child("GameManager", true, false)
	var skill_name := ""
	
	if gm and gm.has_method("get_random_skill"):
		skill_name = gm.get_random_skill()
	else:
		var fallbacks = ["Rice Yard Dust", "Boon Bang Fai", "Pha Khao Ma", "Field Wind", "Screen Blur"]
		skill_name = fallbacks[randi() % fallbacks.size()]
	
	var skill_added: bool = body.add_skill(skill_name)
	if skill_added:
		# VFX + SFX
		#VfxManager.spawn("skill_use", global_position)
		AudioManager.play_sfx("skill_pickup")
		deactivate()
