extends Node3D

@export var player1_path: NodePath = "../Players/Player1"
@export var player2_path: NodePath = "../Players/Player2"
@export var skill_cooldown_min := 3.0
@export var skill_cooldown_max := 5.0
const GOAL_DISTANCE = 1000

@onready var p1 = get_node(player1_path)
@onready var p2 = get_node(player2_path)
@onready var ui_gameover = get_node("../UI/GameOverPanel")

var death_frames = {"p1": null, "p2": null}
var skill_cooldown_active := false
var pending_pranks = {}
var game_ended = false

func _ready():
	ui_gameover.visible = false
	p1.connect("died", Callable(self, "_on_p1_died"))
	p2.connect("died", Callable(self, "_on_p2_died"))
	
	# Connect to distance changes to check for goal
	p1.distance_changed.connect(_check_distance_goal)
	p2.distance_changed.connect(_check_distance_goal)

	# Apply Curvature Effect INSIDE each SubViewport for perfect split-screen isolation
	_apply_curvature_effect("../Cameras/SubViewportContainerP1er/SubViewportP1", 0.4)
	_apply_curvature_effect("../Cameras/SubViewportContainerP2/SubViewportP2", 0.4)

func _apply_curvature_effect(viewport_path: String, amount: float):
	var viewport = get_node_or_null(viewport_path)
	if not viewport: return
	
	# Create a CanvasLayer inside the SubViewport
	# This ensures SCREEN_UV is local to THIS viewport only (0.0 to 1.0)
	var canvas_layer = CanvasLayer.new()
	viewport.add_child(canvas_layer)
	
	var color_rect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://scenes/shared_scripts/curvature.gdshader")
	mat.set_shader_parameter("curve_y", amount)
	
	color_rect.material = mat
	canvas_layer.add_child(color_rect)

func _input(event):
	# Debug keys for testing goal
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1: # Set both players near goal
				p1.debug_set_distance(980)
				p2.debug_set_distance(980)
				print("DEBUG: Set distance to 980m")
			KEY_F2: # Give P1 full charge
				p1.debug_add_charge(5)
				print("DEBUG: P1 Charge Full")
			KEY_F3: # Give P2 full charge
				p2.debug_add_charge(5)
				print("DEBUG: P2 Charge Full")
			KEY_F4: # Fast forward current player slightly
				p1.debug_set_distance(p1.distance + 50)
				print("DEBUG: P1 jumped +50m")

func _check_distance_goal(_new_dist):
	if game_ended:
		return
		
	if p1.distance >= GOAL_DISTANCE or p2.distance >= GOAL_DISTANCE:
		game_ended = true
		_determine_winner_by_score()

func _determine_winner_by_score():
	var winner = "Draw"
	if p1.score > p2.score:
		winner = "Player 1"
	elif p2.score > p1.score:
		winner = "Player 2"
	elif p1.distance > p2.distance:
		winner = "Player 1"
	elif p2.distance > p1.distance:
		winner = "Player 2"
	
	game_over(winner)

func _on_p1_died():
	death_frames["p1"] = Engine.get_physics_frames()
	_check_game_over()

func _on_p2_died():
	death_frames["p2"] = Engine.get_physics_frames()
	_check_game_over()

func _check_game_over():
	if death_frames["p1"] != null and death_frames["p2"] != null:
		var p1_frame = death_frames["p1"]
		var p2_frame = death_frames["p2"]
		var winner = "Draw"
		if p1_frame == p2_frame:
			winner = "Draw"
		elif p1.score > p2.score:
			winner = "Player 1"
		elif p2.score > p1.score:
			winner = "Player 2"
		elif p1.distance > p2.distance:
			winner = "Player 1"
		elif p2.distance > p1.distance:
			winner = "Player 2"
		game_over(winner)

func request_skill(attacker):
	if skill_cooldown_active:
		return
	var target = p1
	if attacker == p1:
		target = p2
	if !target:
		return
	if attacker.has_method("deduct_charges"):
		attacker.deduct_charges(attacker.MAX_CHARGES)
	_start_global_cooldown()
	_queue_prank(target, _choose_skill())

func try_block_prank(player):
	pass

func _choose_skill():
	var common = ["Slow Floor", "Lane Swap", "Slow Speed", "Screen Blur"]
	var uncommon = ["Pull to Center", "Invert Controls"]
	var rare = ["Lane Block", "Wind Push", "Transformation Debuff"]
	var roll = randf()
	if roll < 0.6:
		return common[randi() % common.size()]
	elif roll < 0.9:
		return uncommon[randi() % uncommon.size()]
	return rare[randi() % rare.size()]

func _queue_prank(target, skill_name):
	target.set_warning(skill_name + " incoming!")
	var warning_timer = get_tree().create_timer(0.8)
	await warning_timer.timeout
	target.apply_prank(skill_name)

func _start_global_cooldown():
	skill_cooldown_active = true
	var cooldown_length = randf_range(skill_cooldown_min, skill_cooldown_max)
	var cooldown_timer = get_tree().create_timer(cooldown_length)
	await cooldown_timer.timeout
	skill_cooldown_active = false

func spawn_lane_block(target):
	var spawner = get_parent().get_node("ObstacleSpawner")
	if spawner and spawner.has_method("spawn_block_in_lane"):
		spawner.spawn_block_in_lane(target.lane, target.global_position.z)

func clear_warning(player):
	if player and player.has_method("clear_warning"):
		player.clear_warning()

func game_over(winner_text: String):
	var spawner = get_parent().get_node("ObstacleSpawner")
	if spawner:
		spawner.set_process(false)
	var players_root = get_parent().get_node("Players")
	if players_root:
		for child in players_root.get_children():
			if child.has_method("set_process"):
				child.set_process(false)

	ui_gameover.show_result(winner_text, p1.score, p2.score, p1.distance, p2.distance)
