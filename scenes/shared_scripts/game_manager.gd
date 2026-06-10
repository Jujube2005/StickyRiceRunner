extends Node3D

# --- FESTIVAL CHARM SYSTEM ENGINE (SINGLE SOURCE OF TRUTH) ---
enum PrankState { QUEUED, PREPARED, ARMED, ACTIVE, BLOCKED, FINISHED, CANCELLED }

class Prank:
	var id: int
	var type: String
	var owner: Node
	var target: Node
	var state: PrankState = PrankState.QUEUED
	var timer: float = 0.0
	var executed: bool = false
	
	func _init(_id: int, _type: String, _owner: Node, _target: Node):
		id = _id
		type = _type
		owner = _owner
		target = _target

# --- SIGNALS ---
signal prank_state_changed(prank: Prank)
signal global_cooldown_changed(active: bool)

# --- CONFIGURATION ---
@export var player_scene: PackedScene = preload("res://scenes/player/players.tscn")
@export var skill_cooldown_min := 3.0
@export var skill_cooldown_max := 5.0
const WARNING_DURATION = 0.8
const GOAL_DISTANCE = 1000

# --- STATE ---
var p1 = null
var p2 = null
@onready var ui_gameover = get_node("../UI/GameOverPanel")

var active_pranks: Array[Prank] = []
var prank_id_counter = 0
var skill_cooldown_timer = 0.0
var game_ended = false

func _ready():
	ui_gameover.visible = false
	_spawn_players()

func _spawn_players():
	var players_node = get_node("../Players")
	if !players_node:
		players_node = Node3D.new()
		players_node.name = "Players"
		get_parent().add_child(players_node)
	
	# Spawn Player 1
	p1 = player_scene.instantiate()
	p1.name = "Player1"
	p1.collision_mask = 4
	p1.left_action = "p1_left"
	p1.right_action = "p1_right"
	p1.jump_action = "p1_jump"
	p1.skill_action = "p1_skill"
	p1.defend_action = "p1_defend"
	p1.game_manager = self
	p1.position = Vector3(-3, 0, 0)
	players_node.add_child(p1)
	
	# Spawn Player 2
	p2 = player_scene.instantiate()
	p2.name = "Player2"
	p2.collision_layer = 2
	p2.collision_mask = 4
	p2.left_action = "p2_left"
	p2.right_action = "p2_right"
	p2.jump_action = "p2_jump"
	p2.skill_action = "p2_skill"
	p2.defend_action = "p2_defend"
	p2.game_manager = self
	p2.position = Vector3(3, 0, 0)
	players_node.add_child(p2)
	
	# Connect signals
	p1.distance_changed.connect(_check_distance_goal)
	p2.distance_changed.connect(_check_distance_goal)
	
	# Update Camera targets if they exist
	var cam_p1 = get_tree().current_scene.find_child("CameraP1", true, false)
	if cam_p1: cam_p1.target = p1
	
	var cam_p2 = get_tree().current_scene.find_child("CameraP2", true, false)
	if cam_p2: cam_p2.target = p2
	
	# Inform HUD about new players
	var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
	if hud and hud.has_method("_ready"):
		hud._ready() # Re-run ready to find players

func _process(delta):
	if game_ended: return
	
	# Update Global Cooldown
	if skill_cooldown_timer > 0:
		skill_cooldown_timer -= delta
		if skill_cooldown_timer <= 0:
			emit_signal("global_cooldown_changed", false)

	# Update Prank State Machine (Deterministic Tick)
	_update_pranks(delta)

# --- CENTRAL UPDATE LOOP ---
func _update_pranks(delta):
	var to_remove = []
	
	# Loop backwards to handle removal if needed, but we keep them for state history usually
	# For performance, we only process non-terminal states
	for prank in active_pranks:
		if prank.state == PrankState.ARMED:
			prank.timer -= delta
			if prank.timer <= 0:
				_transition_prank(prank, PrankState.ACTIVE)
		
		if prank.state == PrankState.ACTIVE:
			_execute_prank_effect(prank)
			_transition_prank(prank, PrankState.FINISHED)
		
		# Cleanup finished/blocked/cancelled pranks from processing list after a delay or immediately
		if prank.state in [PrankState.FINISHED, PrankState.BLOCKED, PrankState.CANCELLED]:
			to_remove.append(prank)
	
	for p in to_remove:
		active_pranks.erase(p)

func _transition_prank(prank: Prank, new_state: PrankState):
	var old_state = prank.state
	prank.state = new_state
	
	# Debug Logging
	print("[PRANK DEBUG] ID:%d | %s -> %s | Type:%s" % [prank.id, PrankState.keys()[old_state], PrankState.keys()[new_state], prank.type])
	
	# Inform Target/UI
	if prank.target.has_method("on_prank_state_updated"):
		prank.target.on_prank_state_updated(prank)
	
	emit_signal("prank_state_changed", prank)

# --- COMMANDS ---
func request_skill(attacker, skill_name = "") -> bool:
	if skill_cooldown_timer > 0: return false
	
	var target = p2 if attacker == p1 else p1
	if !target: return false
	
	var type = skill_name if skill_name != "" else _choose_skill()
	
	prank_id_counter += 1
	var new_prank = Prank.new(prank_id_counter, type, attacker, target)
	active_pranks.append(new_prank)
	
	# Start Global Cooldown
	skill_cooldown_timer = randf_range(skill_cooldown_min, skill_cooldown_max)
	emit_signal("global_cooldown_changed", true)
	
	# Arm the prank
	new_prank.timer = WARNING_DURATION
	_transition_prank(new_prank, PrankState.ARMED)
	return true

func try_block_prank(player):
	# Find the oldest ARMED prank targeting this player (FIFO)
	for prank in active_pranks:
		if prank.target == player and prank.state == PrankState.ARMED:
			_transition_prank(prank, PrankState.BLOCKED)
			return true
	
	# Missed block feedback
	if player.has_method("set_warning"):
		player.set_warning("บ่มีหยังให้ป้อง")
	return false

# --- EFFECT RESOLUTION ---
func _execute_prank_effect(prank: Prank):
	if prank.executed or prank.state != PrankState.ACTIVE:
		return
	
	prank.executed = true
	print("[PRANK EXECUTE] ID:%d | Target:%s | Skill:%s" % [prank.id, prank.target.name, prank.type])
	
	if prank.target.has_method("apply_prank"):
		prank.target.apply_prank(prank.type)

# --- UTILS ---
func _choose_skill():
	# Festival Charms — ธัมม์เทศกาล
	var common = ["Rice Yard Dust", "Boon Bang Fai", "Field Wind", "Screen Blur", "Pha Khao Ma"]
	var uncommon = ["Pull to Center", "Lane Swap"]
	var rare = ["Lane Block", "Wind Push"]
	var roll = randf()
	if roll < 0.6: return common[randi() % common.size()]
	elif roll < 0.9: return uncommon[randi() % uncommon.size()]
	return rare[randi() % rare.size()]

func get_random_skill():
	return _choose_skill()

func spawn_lane_block(target):
	var spawner = get_parent().get_node("ObstacleSpawner")
	if spawner and spawner.has_method("spawn_block_in_lane"):
		spawner.spawn_block_in_lane(target.lane, target.global_position.z)

func _check_distance_goal(_new_dist):
	if game_ended: return
	if p1.distance >= GOAL_DISTANCE or p2.distance >= GOAL_DISTANCE:
		game_ended = true
		_determine_winner_by_score()

func calculate_final_score(player_id: int) -> int:
	var player = p1 if player_id == 1 else p2
	if !player: return 0
	
	var kratips = player.kratips_collected if "kratips_collected" in player else 0
	var dist = player.distance if "distance" in player else 0.0
	var pens = player.penalties if "penalties" in player else 0
	
	# Total = (Kratib × 100) + Distance – Penalties
	return int((kratips * 100) + dist - pens)

func _determine_winner_by_score():
	var winner = "Draw"
	var p1_final = calculate_final_score(1)
	var p2_final = calculate_final_score(2)
	if p1_final > p2_final: winner = "Player 1"
	elif p2_final > p1_final: winner = "Player 2"
	elif p1.distance > p2.distance: winner = "Player 1"
	elif p2.distance > p1.distance: winner = "Player 2"
	game_over(winner)

func game_over(winner_text: String):
	var spawner = get_parent().get_node("ObstacleSpawner")
	if spawner: spawner.set_process(false)
	var players_root = get_parent().get_node("Players")
	if players_root:
		for child in players_root.get_children():
			child.set("finished", true)
			if child.has_method("set_process"): child.set_process(false)
	ui_gameover.show_result(winner_text, calculate_final_score(1), calculate_final_score(2), int(p1.distance), int(p2.distance))
