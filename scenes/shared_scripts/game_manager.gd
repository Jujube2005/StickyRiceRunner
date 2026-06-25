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
signal race_start_cooldown_changed(remaining: float)
signal zone_changed(new_zone: int)

# --- CONFIGURATION ---
var current_zone: int = 1

@export var player_scene: PackedScene = preload("res://scenes/player/players.tscn")
@export var skill_cooldown_min := 3.0
@export var skill_cooldown_max := 5.0
@export var dodge_window := 1.5
const GOAL_DISTANCE = 2000

# --- ENDLESS MODE ---
const ELEPHANT_START_GAP := 20.0
const ELEPHANT_GAIN_RATE := 1.5      # m/s the elephant gains while player runs normally
const ELEPHANT_RECOVER_RATE := 3.0  # m/s the player recovers distance from elephant while buffalo-riding
const ELEPHANT_CRASH_PENALTY := 5.0 # Metres elephant gains per obstacle crash
const ELEPHANT_SKILL_PENALTY := 3.0 # Metres elephant gains when hit by a prank skill
const BUFFALO_GAP_BOOST := 12.0     # Instant gap increase when buffalo ride starts

var elephant_gap_p1 := ELEPHANT_START_GAP
var elephant_gap_p2 := ELEPHANT_START_GAP

# Global speed scale, increases over distance for Endless difficulty
var global_speed_scale := 1.0
const SPEED_SCALE_STEP := 0.15  # Extra multiplier added per difficulty band

# Elephant visual followers
var _elephant_p1 : Node = null
var _elephant_p2 : Node = null

# --- STATE ---
var p1 = null
var p2 = null
@onready var ui_gameover = get_node("../UI/GameOverPanel")

var active_pranks: Array[Prank] = []
var prank_id_counter = 0
var skill_cooldown_timer = 0.0
var game_ended = false
var elapsed_time = 0.0
var countdown_active = true

func _ready():
	ui_gameover.visible = false
	skill_cooldown_timer = 3.0 # Race start cooldown
	_spawn_players()

	AudioManager.play_music_by_name("musicInGame")

	countdown_active = true
	_freeze_players(true)
	_start_countdown()
	
	# In Endless mode, spawn elephant chasers
	if GameConfig.race_mode == "endless":
		_spawn_elephants()

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
	p1.slide_action = "p1_slide"
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
	p2.slide_action = "p2_slide"
	p2.game_manager = self
	p2.position = Vector3(3, 0, 0)
	players_node.add_child(p2)
	
	# Handle single player mode
	if ResourceLoader.has_cached("res://scenes/shared_scripts/game_config.gd"):
		if GameConfig.game_mode == "singleplayer":
			p2.is_bot = true
	
	# Connect signals
	p1.distance_changed.connect(_check_distance_goal)
	p2.distance_changed.connect(_check_distance_goal)
	
	# Grant spawn shield (3s invincibility)
	if p1.has_method("grant_spawn_shield"): p1.grant_spawn_shield(3.0)
	if p2.has_method("grant_spawn_shield"): p2.grant_spawn_shield(3.0)
	
	# Update Camera targets if they exist
	var cam_p1 = get_tree().current_scene.find_child("CameraP1", true, false)
	if cam_p1: 
		cam_p1.target = p1
		cam_p1.set_cull_mask_value(3, false) # P1 camera does not see Layer 3
	
	var cam_p2 = get_tree().current_scene.find_child("CameraP2", true, false)
	if cam_p2: 
		cam_p2.target = p2
		cam_p2.set_cull_mask_value(2, false) # P2 camera does not see Layer 2
	
	# Inform HUD about new players
	var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
	if hud and hud.has_method("_ready"):
		hud._ready() # Re-run ready to find players

func _freeze_players(freeze: bool):
	if p1 and p1.has_method("set_process"):
		p1.set_process(!freeze)
		p1.set_physics_process(!freeze)
		if freeze and p1.has_method("set"):
			p1.set("finished", true)
		else:
			p1.set("finished", false)
	if p2 and p2.has_method("set_process"):
		p2.set_process(!freeze)
		p2.set_physics_process(!freeze)
		if freeze and p2.has_method("set"):
			p2.set("finished", true)
		else:
			p2.set("finished", false)

func _start_countdown():
	var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
	if hud and hud.has_method("show_countdown"):
		hud.show_countdown(3, func(): _on_countdown_finished())
	else:
		# ถ้าไม่มี HUD ให้รอ 3 วิแล้วเริ่มเลย
		get_tree().create_timer(3.0).timeout.connect(_on_countdown_finished)

func _on_countdown_finished():
	countdown_active = false
	_freeze_players(false)


func _process(delta):
	if game_ended: return
	if countdown_active: return
	
	elapsed_time += delta
	
	# Update Global Cooldown
	if skill_cooldown_timer > 0:
		skill_cooldown_timer -= delta
		if elapsed_time <= 5.0:
			emit_signal("race_start_cooldown_changed", skill_cooldown_timer)
		if skill_cooldown_timer <= 0:
			emit_signal("global_cooldown_changed", false)

	# Update Prank State Machine
	_update_pranks(delta)
	
	# Endless Mode exclusive logic
	if GameConfig.race_mode == "endless":
		_update_endless(delta)

# ─── ENDLESS MODE LOGIC ───────────────────────────────────────────

func _spawn_elephants() -> void:
	"""Create one ElephantChaser per player in Endless Mode."""
	var elephant_script: Script = load("res://scenes/chaser/elephant_chaser.gd")
	if elephant_script == null:
		push_warning("[GameManager] elephant_chaser.gd not found!")
		return
	
	if is_instance_valid(p1):
		_elephant_p1 = Node3D.new()
		_elephant_p1.set_script(elephant_script)
		_elephant_p1.set("target_player", p1)
		get_parent().add_child(_elephant_p1)
	
	if is_instance_valid(p2):
		_elephant_p2 = Node3D.new()
		_elephant_p2.set_script(elephant_script)
		_elephant_p2.set("target_player", p2)
		get_parent().add_child(_elephant_p2)


func _update_endless(delta: float) -> void:
	if not is_instance_valid(p1) or not is_instance_valid(p2): return
	
	# Update difficulty: speed scale based on max distance
	var max_dist := max(p1.distance, p2.distance)
	_update_difficulty(max_dist)
	
	# Update zone transitions (reuse same thresholds, but endless has no finish)
	_check_endless_zone(max_dist)
	
	# Update elephant gaps
	_update_elephant_gap(p1, "elephant_gap_p1", delta)
	_update_elephant_gap(p2, "elephant_gap_p2", delta)
	
	# Check if elephant caught either player
	if elephant_gap_p1 <= 0.0 and not p1.get("finished"):
		_player_caught_by_elephant(p1)
	elif elephant_gap_p2 <= 0.0 and not p2.get("finished"):
		_player_caught_by_elephant(p2)


func _update_difficulty(max_dist: float) -> void:
	"""Gradually increase global_speed_scale as distance increases."""
	if max_dist < 1000:
		global_speed_scale = 1.0
	elif max_dist < 2000:
		global_speed_scale = 1.0 + SPEED_SCALE_STEP          # 1.15×
	elif max_dist < 3000:
		global_speed_scale = 1.0 + SPEED_SCALE_STEP * 2.0    # 1.30×
	else:
		global_speed_scale = 1.0 + SPEED_SCALE_STEP * 3.0    # 1.45×


func _check_endless_zone(max_dist: float) -> void:
	"""Zone transitions every 1000m in Endless Mode."""
	var new_zone := current_zone
	if max_dist >= 3000: new_zone = 4
	elif max_dist >= 2000: new_zone = 3
	elif max_dist >= 1000: new_zone = 2
	if new_zone != current_zone:
		current_zone = new_zone
		emit_signal("zone_changed", current_zone)
		print("[ENDLESS] Zone ", current_zone)


func _update_elephant_gap(player: Node, gap_var: String, delta: float) -> void:
	"""Reduce or increase a player's elephant gap based on their state."""
	var gap := float(get(gap_var))
	if gap <= 0.0: return  # Already caught
	
	if player.get("is_riding_buffalo"):
		# Buffalo ride: elephant FALLS BEHIND
		gap += ELEPHANT_RECOVER_RATE * delta
		gap = min(gap, ELEPHANT_START_GAP * 2.0)  # Cap at 2x start gap
	else:
		# Normal running: elephant slowly gains
		gap -= ELEPHANT_GAIN_RATE * delta
	
	# Sync to player so the ElephantChaser can read it
	player.set("elephant_gap", gap)
	set(gap_var, gap)


func on_player_crash(player: Node) -> void:
	"""Called when a player hits an obstacle in Endless Mode. Elephant gains distance."""
	if GameConfig.race_mode != "endless": return
	if player == p1:
		elephant_gap_p1 = max(elephant_gap_p1 - ELEPHANT_CRASH_PENALTY, 0.0)
		p1.set("elephant_gap", elephant_gap_p1)
	elif player == p2:
		elephant_gap_p2 = max(elephant_gap_p2 - ELEPHANT_SKILL_PENALTY, 0.0)
		p2.set("elephant_gap", elephant_gap_p2)


func on_buffalo_ride_started(player: Node) -> void:
	"""Called when a player collects 10 Kratips and mounts the Buffalo."""
	if GameConfig.race_mode != "endless": return
	if player == p1:
		elephant_gap_p1 = min(elephant_gap_p1 + BUFFALO_GAP_BOOST, ELEPHANT_START_GAP * 2.0)
		p1.set("elephant_gap", elephant_gap_p1)
		print("[ENDLESS] P1 Buffalo Ride! Elephant gap: ", elephant_gap_p1)
	elif player == p2:
		elephant_gap_p2 = min(elephant_gap_p2 + BUFFALO_GAP_BOOST, ELEPHANT_START_GAP * 2.0)
		p2.set("elephant_gap", elephant_gap_p2)
		print("[ENDLESS] P2 Buffalo Ride! Elephant gap: ", elephant_gap_p2)


func _player_caught_by_elephant(caught_player: Node) -> void:
	"""One player was caught. End the game."""
	if game_ended: return
	game_ended = true
	
	print("[ENDLESS] CAUGHT: ", caught_player.name, " at ", int(caught_player.distance), "m")
	
	# Freeze the caught player in stun
	if caught_player.has_method("stun"):
		caught_player.stun(99.0)  # Long stun = "caught" animation
	
	# Determine winner by distance
	var winner := "Draw"
	if caught_player == p1 and is_instance_valid(p2):
		winner = "Player 2"  # P2 survived longer
	elif caught_player == p2 and is_instance_valid(p1):
		winner = "Player 1"  # P1 survived longer
	
	game_over(winner)

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
	new_prank.timer = dodge_window
	_transition_prank(new_prank, PrankState.ARMED)
	_show_dodge_warning(new_prank)
	return true

func _show_dodge_warning(prank: Prank):
	if is_instance_valid(prank.target):
		VfxManager.spawn("incoming_warning", prank.target.global_position)



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
	var common = ["Rice Yard Dust", "Boon Bang Fai", "Field Wind", "Screen Blur"]
	var uncommon = ["Pull to Center", "Lane Swap"]
	var rare = ["Wind Push"]
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
	# Endless Mode handles its own zone transitions and end conditions
	if GameConfig.race_mode == "endless": return
	
	var max_dist = max(p1.distance, p2.distance)
	
	# Check Zone Transitions (Race Mode: every 500m of the 2000m goal)
	var new_zone = current_zone
	if max_dist >= GOAL_DISTANCE * (3.0 / 4.0):
		new_zone = 4
	elif max_dist >= GOAL_DISTANCE * (2.0 / 4.0):
		new_zone = 3
	elif max_dist >= GOAL_DISTANCE * (1.0 / 4.0):
		new_zone = 2
		
	if new_zone != current_zone:
		current_zone = new_zone
		emit_signal("zone_changed", current_zone)
		print("[GAME MANAGER] Transitioned to Zone ", current_zone)
	
	if max_dist >= GOAL_DISTANCE:
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
	AudioManager.stop_music()
	var spawner = get_parent().get_node_or_null("ObstacleSpawner")
	if spawner: spawner.set_process(false)
	var players_root = get_parent().get_node_or_null("Players")
	if players_root:
		for child in players_root.get_children():
			child.set("finished", true)
			if child.has_method("set_process"): child.set_process(false)
	ui_gameover.show_result(winner_text, calculate_final_score(1), calculate_final_score(2), int(p1.distance), int(p2.distance))
