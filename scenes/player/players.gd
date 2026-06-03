extends CharacterBody3D

signal score_changed(amount)
signal distance_changed(amount)
signal charge_changed(current, max)
signal skill_state_changed(is_ready, skill_name)
signal warning_changed(message)

const BASE_FORWARD_SPEED = 10.0
const MAX_FORWARD_SPEED = 35.0
const SPEED_SCALE_FACTOR = 0.015 # Increase 1.0 speed every ~66m

const JUMP_FORCE = 9.0
const GRAVITY = 30.0
const MAX_CHARGES = 5

var lane = 0
var lane_distance = 3.0

var alive = true
var stun_timer := 0.0
var score = 0
var charges := 0
var can_charge := true
var effect_durations := {}

var prepared_skill := ""
var is_skill_ready := false
var is_rolling_skill := false

var shield_vfx : MeshInstance3D = null

var distance := 0.0
var start_z := 0.0

@export var left_action : String
@export var right_action : String
@export var jump_action : String
@export var skill_action : String
@export var defend_action : String

@export var is_bot := false
var bot_think_timer := 0.0
var bot_jump_cooldown := 0.0

var game_manager : Node = null

func _ready():
	start_z = global_position.z
	_setup_shield_vfx()
	if get_tree().current_scene != null:
		var scene_root = get_tree().current_scene
		if scene_root and scene_root.has_node("GameManager"):
			game_manager = scene_root.get_node("GameManager")

func _setup_shield_vfx():
	shield_vfx = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	shield_vfx.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.3) # Golden translucent
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.0)
	mat.emission_energy_multiplier = 2.0
	shield_vfx.material_override = mat
	
	add_child(shield_vfx)
	shield_vfx.visible = false

func _physics_process(delta):
	var new_distance = int(abs(global_position.z - start_z))

	if new_distance != distance:
		distance = new_distance
		emit_signal("distance_changed", distance)

	if stun_timer > 0:
		stun_timer -= delta
		velocity.z = 0
		if !is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		# Visual feedback for stun (shaking/dizzy)
		$Model.rotation.y += delta * 20.0
		return

	if !alive:
		return

	_update_effects(delta)

	var speed_factor = 1.0
	if _has_effect("slow_speed"):
		speed_factor *= 0.7
	if _has_effect("transformation"):
		speed_factor *= 0.65
		
	# Visual feedback for transformation/debuffs
	if _has_effect("transformation"):
		$Model.scale = Vector3(0.4, 0.4, 0.4)
		$Model.rotation.y += delta * 15.0 # Spin while small
	else:
		$Model.scale = Vector3(1.0, 1.0, 1.0)
		$Model.rotation.y = PI
		
	# Visual feedback for screen blur / confusion
	if _has_effect("screen_blur") or _has_effect("invert_controls"):
		$Model.position.x += randf_range(-0.2, 0.2)
		$Model.position.y += randf_range(0.0, 0.2)
	else:
		$Model.position.x = 0
		$Model.position.y = 0

	# Flash or shake when hit by something
	if _has_effect("slow_speed") or _has_effect("slow_floor") or _has_effect("wind_push"):
		$Model.rotation.z = sin(Engine.get_frames_drawn() * 0.5) * 0.2
	else:
		$Model.rotation.z = 0

	# Calculate dynamic speed based on distance
	var current_speed = min(BASE_FORWARD_SPEED + (distance * SPEED_SCALE_FACTOR), MAX_FORWARD_SPEED)
	velocity.z = -current_speed * speed_factor

	if !is_on_floor():
		velocity.y -= GRAVITY * delta

	if !is_bot:
		if jump_action != "" and Input.is_action_just_pressed(jump_action) and is_on_floor() and !_has_effect("disable_jump"):
			velocity.y = JUMP_FORCE

		if skill_action != "" and Input.is_action_just_pressed(skill_action) and charges >= MAX_CHARGES:
			request_skill()
		
		if defend_action != "" and Input.is_action_just_pressed(defend_action) and charges >= 1:
			try_defend()

	var move_dir = 0

	if is_bot:
		bot_think_timer -= delta
		bot_jump_cooldown -= delta
		
		# Bot manual skill/defend logic
		if charges >= MAX_CHARGES:
			# Random delay for bot to use skill
			if randf() < 0.02: # Check every physics frame (~1% chance per frame)
				request_skill()
		
		if bot_think_timer <= 0:
			bot_think_timer = 0.05
			
			var lane_scores = { -1: 0.0, 0: 0.0, 1: 0.0 }
			var bot_curr_speed = abs(velocity.z)
			var look_ahead_dist = max(35.0, bot_curr_speed * 2.5)
			var kratip_bonus = 18.0
			
			# Evaluate each lane
			for l in [-1, 0, 1]:
				var l_x = l * lane_distance
				var nearest_high_obs_dist = look_ahead_dist
				var nearest_low_obs_dist = look_ahead_dist
				
				for obs in get_tree().get_nodes_in_group("obstacle"):
					if abs(obs.global_position.x - l_x) < 1.0:
						var dist_z = global_position.z - obs.global_position.z
						if dist_z > 0 and dist_z < look_ahead_dist:
							if obs.is_in_group("high_obstacle"):
								nearest_high_obs_dist = min(nearest_high_obs_dist, dist_z)
							else:
								nearest_low_obs_dist = min(nearest_low_obs_dist, dist_z)
				
				# High obstacles are dangerous, Low obstacles are jumpable (less penalty)
				lane_scores[l] = nearest_high_obs_dist + (nearest_low_obs_dist * 0.5)
				
				# Bonus for kratips
				for k in get_tree().get_nodes_in_group("kratip"):
					if abs(k.global_position.x - l_x) < 1.0:
						var dist_z = global_position.z - k.global_position.z
						if dist_z > 0 and dist_z < 25.0:
							lane_scores[l] += (25.0 - dist_z) / 25.0 * kratip_bonus
			
			lane_scores[lane] += 5.0 # Stronger preference to stay in lane
			
			var best_lane = lane
			var max_score = -999.0
			for l in lane_scores:
				if lane_scores[l] > max_score:
					max_score = lane_scores[l]
					best_lane = l
			
			if best_lane < lane: move_dir = -1
			elif best_lane > lane: move_dir = 1
			
			# Smart Jump Logic
			if is_on_floor() and bot_jump_cooldown <= 0:
				var my_lane_x = lane * lane_distance
				for obs in get_tree().get_nodes_in_group("low_obstacle"):
					if abs(obs.global_position.x - my_lane_x) < 1.0:
						var dist_z = global_position.z - obs.global_position.z
						# Jump when close to a low obstacle
						var jump_range = max(3.5, bot_curr_speed * 0.35)
						if dist_z > 0 and dist_z < jump_range:
							velocity.y = JUMP_FORCE
							bot_jump_cooldown = 0.7
							break

	if !is_bot:
		if left_action != "" and Input.is_action_just_pressed(left_action):
			move_dir -= 1

		if right_action != "" and Input.is_action_just_pressed(right_action):
			move_dir += 1

	if _has_effect("invert_controls"):
		move_dir *= -1

	lane += move_dir

	lane = clamp(lane, -1, 1)

	var target_x = lane * lane_distance
	var lerp_speed = 2.5 if _has_effect("slow_floor") else 10.0
	position.x = lerp(position.x, target_x, lerp_speed * delta)

	if _has_effect("wind_push"):
		position.x += randf_range(-2.0, 2.0) * delta

	move_and_slide()

	if position.y < -10:
		# No death, so teleport back to lane 0 surface
		position.y = 2.0
		position.x = 0.0
		stun(2.0)

func _update_effects(delta):
	for effect in effect_durations.keys():
		effect_durations[effect] -= delta

	var expired = []
	for effect in effect_durations.keys():
		if effect_durations[effect] <= 0:
			expired.append(effect)

	for effect in expired:
		effect_durations.erase(effect)

func _has_effect(effect_name):
	return effect_durations.has(effect_name)

func add_score(amount):
	score += amount
	emit_signal("score_changed", score)
	print(name, "score:", score)

func die() -> void:
	# Redirect die to stun if it's from obstacle, 
	# but keep it for falling out of bounds for now or just stun.
	# The requirement says "No death", so let's just stun.
	stun(2.0)

func stun(duration: float = 2.0):
	stun_timer = duration
	velocity.z = 0
	# Visual feedback: Scale pulse
	var tween = create_tween()
	tween.tween_property($Model, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
	tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

func add_charge(amount):
	if !can_charge:
		return
	charges = clamp(charges + amount, 0, MAX_CHARGES)
	emit_signal("charge_changed", charges, MAX_CHARGES)

func deduct_charges(amount):
	charges = max(charges - amount, 0)
	if charges < MAX_CHARGES:
		is_skill_ready = false
		prepared_skill = ""
	emit_signal("charge_changed", charges, MAX_CHARGES)

func reset_charges():
	charges = 0
	is_skill_ready = false
	prepared_skill = ""
	emit_signal("charge_changed", charges, MAX_CHARGES)

func _prepare_skill():
	if is_rolling_skill: return
	
	is_rolling_skill = true
	emit_signal("skill_state_changed", false, "ROLLING")
	emit_signal("warning_changed", "🎆 ลุ้นบั้งไฟ...")
	
	# Build anticipation
	var roll_timer = get_tree().create_timer(1.2)
	await roll_timer.timeout
	
	if game_manager and game_manager.has_method("get_random_skill"):
		prepared_skill = game_manager.get_random_skill()
		is_skill_ready = true
		is_rolling_skill = false
		emit_signal("skill_state_changed", true, prepared_skill)
		emit_signal("warning_changed", "พร้อมแล้ว: " + prepared_skill)

func request_skill():
	if charges < MAX_CHARGES:
		return
	if !is_skill_ready:
		_prepare_skill()
		return
	if game_manager:
		game_manager.request_skill(self, prepared_skill)
		is_skill_ready = false
		prepared_skill = ""
		emit_signal("skill_state_changed", false, "")

func try_defend():
	if charges < 1:
		return
	
	deduct_charges(1)
	_show_shield_vfx()
	
	if game_manager:
		game_manager.try_block_prank(self)

func _show_shield_vfx():
	if !shield_vfx: return
	
	shield_vfx.visible = true
	shield_vfx.scale = Vector3.ZERO
	
	var tween = create_tween()
	# Pop in
	tween.tween_property(shield_vfx, "scale", Vector3(1.2, 1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(shield_vfx, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	
	# Pulse effect while active
	var pulse_tween = create_tween().set_loops(6)
	pulse_tween.tween_property(shield_vfx, "scale", Vector3(1.05, 1.05, 1.05), 0.2)
	pulse_tween.tween_property(shield_vfx, "scale", Vector3(1.0, 1.0, 1.0), 0.2)
	
	# Fade out after some time (matching block duration if implemented, else fixed)
	await get_tree().create_timer(2.0).timeout
	
	pulse_tween.kill()
	var fade_tween = create_tween()
	fade_tween.tween_property(shield_vfx, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
	fade_tween.parallel().tween_property(shield_vfx, "material_override:albedo_color:a", 0.0, 0.2)
	fade_tween.tween_callback(func(): 
		shield_vfx.visible = false
		shield_vfx.scale = Vector3.ONE
		shield_vfx.material_override.albedo_color.a = 0.3
	)

func apply_prank(skill_name):
	match skill_name:
		"Slow Floor":
			effect_durations["slow_floor"] = 4.0
		"Lane Swap":
			lane = -1 if lane >= 0 else 1 # Actual swap
		"Slow Speed":
			effect_durations["slow_speed"] = 4.0
		"Screen Blur":
			effect_durations["screen_blur"] = 4.0
		"Pull to Center":
			lane = 0
			velocity.y = 5.0 # Hop when pulled
		"Knockback":
			global_position.z += 6.0
			velocity.y = 5.0 # Hop when knocked back
		"Invert Controls":
			effect_durations["invert_controls"] = 4.5
		"Lane Block":
			if game_manager:
				game_manager.spawn_lane_block(self)
		"Wind Push":
			effect_durations["wind_push"] = 3.0
		"Transformation Debuff":
			effect_durations["transformation"] = 4.0
			effect_durations["disable_jump"] = 4.0
		_:
			pass

func on_prank_state_updated(prank):
	# Map PrankState to UI Warnings
	# PrankState { QUEUED, PREPARED, ARMED, ACTIVE, BLOCKED, FINISHED, CANCELLED }
	match prank.state:
		1: # PREPARED (not used in this simplified flow yet, but for consistency)
			pass
		2: # ARMED
			set_warning(prank.type + " กำลังมา!")
		4: # BLOCKED
			set_warning("ป้องได้แล้ว!")
			# Auto-clear block message
			get_tree().create_timer(1.5).timeout.connect(func(): if charges >= 0: clear_warning("ป้องได้แล้ว!"))
		3: # ACTIVE (Failed to block)
			set_warning("ป้องกันบ่ทัน")
			# Auto-clear fail message
			get_tree().create_timer(1.5).timeout.connect(func(): if charges >= 0: clear_warning("ป้องกันบ่ทัน"))

func set_warning(text):
	emit_signal("warning_changed", text)
	
	# Bot auto-defend logic
	if is_bot and text.ends_with(" incoming!") and charges >= 1:
		# Small delay for bot to respond
		get_tree().create_timer(randf_range(0.2, 0.5)).timeout.connect(func(): if charges >= 1: try_defend())
	
	# Visual feedback for warning/blocking
	if text == "ป้องได้แล้ว!":
		# Pulse green-ish or just jump
		var tween_block = create_tween()
		tween_block.tween_property($Model, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
		tween_block.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	elif text != "":
		# Warning pulse
		var tween_warn = create_tween()
		tween_warn.tween_property($Model, "position:y", 0.5, 0.1)
		tween_warn.tween_property($Model, "position:y", 0.0, 0.1)

func clear_warning(message_to_clear = ""):
	emit_signal("warning_changed", "CLEAR:" + message_to_clear)

# --- DEBUG FUNCTIONS ---
func debug_set_distance(value: float):
	# Move the player's Z position to simulate the distance
	global_position.z = start_z - value
	distance = int(value)
	emit_signal("distance_changed", distance)

func debug_add_charge(amount: int):
	add_charge(amount)
