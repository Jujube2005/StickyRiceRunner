extends Area3D

@export var rotate_speed := 3.0
@export var float_speed := 2.0
@export var float_amplitude := 0.25

var is_collected := false
var is_active := false
var start_y := 0.0
var time_passed := 0.0
var assigned_skill := ""

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	if !is_active:
		deactivate()

func activate(pos: Vector3, skill_name: String = ""):
	is_active = true
	is_collected = false
	position = pos
	start_y = pos.y
	time_passed = randf() * PI * 2
	assigned_skill = skill_name
	visible = true
	
	set_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func deactivate():
	is_active = false
	visible = false
	position = Vector3(0, -100, 0)
	
	set_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _process(delta):
	if !is_active or is_collected: return
	
	time_passed += delta
	
	# Rotate the model
	$Model.rotate_y(rotate_speed * delta)
	
	# Hovering effect
	position.y = start_y + sin(time_passed * float_speed) * float_amplitude

func _on_body_entered(body):
	if !is_active or is_collected:
		return
		
	if body.name == "Player1" or body.name == "Player2":
		# Choose a skill if none assigned
		var skill_to_give = assigned_skill
		if skill_to_give == "":
			var scene = get_tree().current_scene
			var game_manager = scene.find_child("GameManager", true, false)
			if game_manager and game_manager.has_method("get_random_skill"):
				skill_to_give = game_manager.get_random_skill()
			else:
				# Fallback skills
				var fallback = ["Slow Floor", "Slow Speed", "Shield"]
				skill_to_give = fallback[randi() % fallback.size()]
		
		# Try to add skill to player's slot
		if body.has_method("add_skill"):
			var success = body.add_skill(skill_to_give)
			if success:
				is_collected = true
				
				# Play pickup pop/fade out tween
				var tween = create_tween()
				tween.tween_property($Model, "scale", Vector3(1.6, 1.6, 1.6), 0.1)
				tween.parallel().tween_property($Model, "position:y", $Model.position.y + 1.0, 0.15)
				tween.tween_callback(deactivate)
				# Reset scale for next pool use
				tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.0)
				tween.tween_property($Model, "position:y", 0.0, 0.0)
