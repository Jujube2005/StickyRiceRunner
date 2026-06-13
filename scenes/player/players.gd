extends CharacterBody3D

signal score_changed(amount)
signal distance_changed(amount)
signal charge_changed(current, max)
signal skill_state_changed(is_ready, skill_name)
signal warning_changed(message)
signal skills_changed(new_skills)
signal kratip_count_changed(current: int, needed: int)  # For HUD kratip counter

const BASE_FORWARD_SPEED = 10.0
const MAX_FORWARD_SPEED = 35.0
const SPEED_SCALE_FACTOR = 0.015 # Increase 1.0 speed every ~66m

const JUMP_FORCE = 8.5
const GRAVITY = 30.0
const MAX_CHARGES = 5

var lane = 0
var lane_distance = 3.0

var alive = true
var finished = false
var stun_timer := 0.0
var kratips_collected := 0      # Total kratips (for scoring)
var kratip_milestone_count := 0 # Kratips toward next coin (0-9, resets at 10)
var penalties := 0
var score := 0
var charges := 0
var can_charge := true
var effect_durations := {}

const COIN_PROTECTION_DURATION := 5.0
var coin_protection_timer := 0.0  # > 0 means protection is active

var prepared_skill := ""
var is_skill_ready := false
var is_rolling_skill := false
var skills: Array[String] = []

var shield_vfx : MeshInstance3D = null
var anim_player : AnimationPlayer = null
var current_anim : String = ""

@export_group("Animations")
@export var anim_run : String = "run"
@export var anim_jump : String = "jump"
@export var anim_stun : String = "stun"

@export_group("Animation Files")
@export_file("*.glb") var model_file : String
@export_file("*.glb") var run_file : String
@export_file("*.glb") var jump_file : String
@export_file("*.glb") var stun_file : String

@export_group("Model Offset")
# Y offset: compensates for GLB pivot not being at feet.
# manTmodel.glb (Blender rig) origin is at hip-center, so we pull it down.
# Adjust this value if the character still sinks or floats.
@export var model_offset := Vector3(0.0, 0.0, 0.0)
@export var model_y_offset : float = 0.0  # Fine-tune Y separately per character
@export var stun_model_y_offset : float = 0.35  # Extra Y lift when laying flat (stun), prevents sinking

var distance := 0.0
var start_z := 0.0
var _cached_skeleton : Skeleton3D = null
var _cached_spine_bone_idx := -2

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
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	start_z = global_position.z
	_setup_shield_vfx()
	
	# Dynamically locate GameManager as fallback
	if !game_manager and get_tree() and get_tree().current_scene:
		game_manager = get_tree().current_scene.find_child("GameManager", true, false)
	
	# Auto-assign files based on character type if not set
	_auto_assign_files()
	
	# Load the actual character model
	_load_model()
	
	# Wait for a frame to ensure model is fully in the tree and ready
	await get_tree().process_frame
	
	# In Godot 4.x, GLB imports often don't include an AnimationPlayer 
	# if the GLB itself doesn't have animations. We need to create one.
	anim_player = _find_animation_player()
	
	if !anim_player:
		print("[ANIM] No AnimationPlayer found in GLB, creating a new one for ", name)
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		add_child(anim_player)
	
	if anim_player:
		print("[ANIM] Using AnimationPlayer at: ", anim_player.get_path())
		
		# Find skeleton for retargeting
		var skeleton = find_child("Skeleton3D", true, false)
		if !skeleton: skeleton = find_child("GeneralSkeleton", true, false)
		
		if skeleton:
			anim_player.root_node = anim_player.get_path_to(skeleton.get_parent())
			print("[ANIM] Linked AnimationPlayer to Skeleton parent: ", skeleton.get_parent().name)
		
		_setup_animations()
		
		# Import animations from files
		if run_file: _import_anim(run_file, anim_run)
		if jump_file: _import_anim(jump_file, anim_jump)
		if stun_file: _import_anim(stun_file, anim_stun)
		
		# Force active and play
		anim_player.active = true
		play_animation(anim_run)
	else:
		print("[ANIM] ERROR: Failed to even create an AnimationPlayer for ", name)
	
	# Auto-correct model Y so mesh feet sit exactly on the floor (Y=0 local)
	# This fixes the "character sinks into ground" issue caused by GLB pivot offset
	await get_tree().process_frame
	_auto_fix_model_y_offset()

func _find_animation_player() -> AnimationPlayer:
	# 1. Direct search
	var ap = find_child("AnimationPlayer", true, false)
	if ap: return ap
	
	# 2. Search in Model node specifically
	var model_node = get_node_or_null("Model")
	if model_node:
		ap = model_node.find_child("AnimationPlayer", true, false)
		if ap: return ap
	
	# 3. List search
	var all_aps = find_children("*", "AnimationPlayer", true, false)
	if all_aps.size() > 0:
		return all_aps[0]
		
	return null

func _print_hierarchy(node: Node, indent: String = ""):
	print(indent, "- ", node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		_print_hierarchy(child, indent + "  ")
	
	if get_tree().current_scene != null:
		var scene_root = get_tree().current_scene
		if scene_root and scene_root.has_node("GameManager"):
			game_manager = scene_root.get_node("GameManager")

func _load_model():
	if !model_file:
		return
		
	if !FileAccess.file_exists(model_file):
		print("[MODEL] File not found: ", model_file)
		return
		
	var res = load(model_file)
	if res:
		var model_instance = res.instantiate()
		var model_node = get_node("Model")
		if model_node:
			# Clear existing models immediately
			for child in model_node.get_children():
				model_node.remove_child(child)
				child.queue_free()
			model_node.add_child(model_instance)
			print("[MODEL] Loaded ", model_file, " into ", name)

func _auto_fix_model_y_offset():
	# Only auto-fix if the designer hasn't set a manual override
	if model_y_offset != 0.0:
		print("[MODEL] model_y_offset already set to ", model_y_offset, " — skipping auto-fix")
		return
	
	var model_node = get_node_or_null("Model")
	if !model_node:
		return
	
	# Collect combined AABB from all mesh instances (in Model's local space)
	var combined_aabb : AABB
	var has_mesh := false
	var meshes = model_node.find_children("*", "MeshInstance3D", true, false)
	
	for mi in meshes:
		if mi.mesh == null:
			continue
		# Get the mesh AABB transformed into Model node local space
		var local_aabb = model_node.global_transform.inverse() * (mi.global_transform * mi.mesh.get_aabb())
		if !has_mesh:
			combined_aabb = local_aabb
			has_mesh = true
		else:
			combined_aabb = combined_aabb.merge(local_aabb)
	
	if !has_mesh:
		print("[MODEL] No meshes found for Y auto-fix on ", name)
		return
	
	# The bottom of the mesh in Model-local space
	var mesh_bottom_y = combined_aabb.position.y
	
	# We want mesh_bottom_y + model_y_offset = 0 (feet at floor)
	# So: model_y_offset = -mesh_bottom_y
	model_y_offset = -mesh_bottom_y
	print("[MODEL] Auto Y-offset for ", name, ": mesh_bottom=", mesh_bottom_y, " → model_y_offset=", model_y_offset)



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

func _sync_model_to_body():
	# Always keep the Model node at the correct local offset.
	# The CharacterBody3D origin is at its FEET (capsule bottom) after move_and_slide,
	# so we only apply the designer-tuned model_offset here, not global Y.
	var model_node = get_node_or_null("Model")
	if model_node:
		model_node.position.x = model_offset.x
		model_node.position.y = model_offset.y + model_y_offset
		model_node.position.z = model_offset.z

func _physics_process(delta):
	var new_distance = int(abs(global_position.z - start_z))

	if new_distance != distance:
		distance = new_distance
		_calculate_total_score() # Recalculate score based on distance
		emit_signal("distance_changed", distance)

	if stun_timer > 0:
		stun_timer -= delta
		velocity.z = 0
		if !is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		
		# Play stun animation
		play_animation(anim_stun)
		
		# Stun: lay flat (-90°) — lift model up to prevent sinking
		# Stun: lay flat (90°) — lift model up to prevent sinking
		$Model.rotation.x = deg_to_rad(90)
		var model_node = get_node_or_null("Model")
		if model_node:
			model_node.position.x = model_offset.x
			model_node.position.y = model_offset.y + model_y_offset + stun_model_y_offset
			model_node.position.z = model_offset.z
		return
	elif current_anim == anim_stun:
		# Just finished stun — reset orientation
		$Model.rotation.x = 0.0
		play_animation(anim_run)

	if !alive:
		return

	if finished:
		velocity.z = 0
		if !is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		if anim_player:
			anim_player.active = false
		return

	_update_effects(delta)

	if coin_protection_timer > 0:
		coin_protection_timer -= delta
		if coin_protection_timer <= 0:
			if shield_vfx and shield_vfx.visible:
				# Use fade-out logic similar to try_defend's shield
				var fade_tween = create_tween()
				fade_tween.tween_property(shield_vfx, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
				fade_tween.parallel().tween_property(shield_vfx, "material_override:albedo_color:a", 0.0, 0.2)
				fade_tween.tween_callback(func(): 
					shield_vfx.visible = false
					shield_vfx.scale = Vector3.ONE
					shield_vfx.material_override.albedo_color.a = 0.3
				)

	var speed_factor = 1.0
	if _has_effect("slow_speed"):
		speed_factor *= 0.7
		
	$Model.scale = Vector3(1.0, 1.0, 1.0)
	$Model.rotation.y = PI
		
	# Pin model to body every frame (fixes sinking)
	_sync_model_to_body()
	
	# Visual feedback for screen blur / confusion (X offset only, Y managed by sync)
	if _has_effect("screen_blur"):
		$Model.position.x = model_offset.x + randf_range(-0.2, 0.2)

	# Flash or shake when hit by something
	if _has_effect("slow_speed") or _has_effect("slow_floor") or _has_effect("wind_push"):
		$Model.rotation.z = sin(Engine.get_frames_drawn() * 0.5) * 0.2
	else:
		$Model.rotation.z = 0

	# Calculate dynamic speed based on distance
	var current_speed = min(BASE_FORWARD_SPEED + (distance * SPEED_SCALE_FACTOR), MAX_FORWARD_SPEED)
	velocity.z = -current_speed * speed_factor

	# Animation handling for normal state
	if is_on_floor():
		play_animation(anim_run)
		if anim_player and current_anim == anim_run:
			anim_player.speed_scale = abs(velocity.z) / BASE_FORWARD_SPEED
	else:
		play_animation(anim_jump)
		if anim_player:
			anim_player.speed_scale = 1.0

	# Apply forward lean to spine bone during running
	if current_anim == anim_run:
		if _cached_skeleton == null:
			_cached_skeleton = find_child("Skeleton3D", true, false)
			if !_cached_skeleton:
				_cached_skeleton = find_child("GeneralSkeleton", true, false)
		
		if _cached_skeleton:
			if _cached_spine_bone_idx == -2:
				_cached_spine_bone_idx = _cached_skeleton.find_bone("Spine")
				if _cached_spine_bone_idx == -1:
					_cached_spine_bone_idx = _cached_skeleton.find_bone("Spine1")
				if _cached_spine_bone_idx == -1:
					_cached_spine_bone_idx = _cached_skeleton.find_bone("Chest")
			
			if _cached_spine_bone_idx != -1:
				var current_rot = _cached_skeleton.get_bone_pose_rotation(_cached_spine_bone_idx)
				var rot_offset = Quaternion(Vector3.RIGHT, deg_to_rad(-12.0))
				_cached_skeleton.set_bone_pose_rotation(_cached_spine_bone_idx, current_rot * rot_offset)

	if !is_on_floor():
		velocity.y -= GRAVITY * delta

	if !is_bot:
		if jump_action != "" and Input.is_action_just_pressed(jump_action) and is_on_floor() and !_has_effect("disable_jump"):
			velocity.y = JUMP_FORCE

		if skill_action != "" and Input.is_action_just_pressed(skill_action):
			use_skill_at_slot(0)
		
		if defend_action != "" and Input.is_action_just_pressed(defend_action):
			use_skill_at_slot(1)

	var move_dir = 0

	if is_bot:
		bot_think_timer -= delta
		bot_jump_cooldown -= delta
		
		# Bot manual skill logic with dual-slot system
		if skills.size() > 0 and randf() < 0.005: # ~0.3% chance per frame (~once every 5 seconds)
			var chosen_slot = -1
			for i in range(skills.size()):
				if skills[i] != "Shield" and skills[i] != "":
					chosen_slot = i
					break
			if chosen_slot != -1:
				use_skill_at_slot(chosen_slot)
		
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


	lane += move_dir

	lane = clamp(lane, -1, 1)

	var target_x = lane * lane_distance
	var lerp_speed = 2.5 if _has_effect("slow_floor") else 10.0
	position.x = lerp(position.x, target_x, lerp_speed * delta)

	if _has_effect("wind_push"):
		position.x += randf_range(-2.0, 2.0) * delta

	move_and_slide()
	# (Model Y is always synced via _sync_model_to_body — no global Y override needed)

	if position.y < -10:
		# Teleport back to lane 0 surface
		position.y = 2.0
		position.x = 0.0
		
		# Catch up to the other player to prevent falling into an infinite void loop
		# which would permanently freeze the road spawner!
		var other_player = null
		if name == "Player1" and get_tree().current_scene:
			other_player = get_tree().current_scene.find_child("Player2", true, false)
		elif name == "Player2" and get_tree().current_scene:
			other_player = get_tree().current_scene.find_child("Player1", true, false)
			
		if is_instance_valid(other_player) and global_position.z > other_player.global_position.z + 10.0:
			global_position.z = other_player.global_position.z + 10.0
			
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
	# Called by kratip.gd on collect — routes through add_kratip
	add_kratip(amount)

func add_kratip(amount: int = 1):
	kratips_collected += amount
	kratip_milestone_count += amount
	_calculate_total_score()
	emit_signal("kratip_count_changed", kratip_milestone_count, 10)
	
	# Every 10 kratips → grant Luang Por Khoon coin directly
	if kratip_milestone_count >= 10:
		kratip_milestone_count = 0
		emit_signal("kratip_count_changed", 0, 10)
		
		# Roll random coin
		var coin_data = CollectionManager.roll_random_coin()
		var is_new = CollectionManager.add_coin(coin_data["id"])
		
		# SFX
		AudioManager.play_sfx("pickup")
		
		# Tell HUD to show cinematic fly-in
		var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
		if hud and hud.has_method("show_coin_fly_in"):
			hud.show_coin_fly_in(self.name, coin_data["name"], is_new)
			
		# Grant protection (delay slightly to match fly-in animation)
		get_tree().create_timer(0.6).timeout.connect(grant_coin_protection)

func grant_coin_protection():
	"""Grant or refresh the 5-second collision-immunity from a Luang Por Khoon coin."""
	coin_protection_timer = COIN_PROTECTION_DURATION
	var warn_msg = LanguageManager.t("WARN_PKM_PROTECT")
	set_warning(warn_msg)
	get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
	_show_shield_vfx()

func add_penalty(amount):
	penalties += amount
	_calculate_total_score()
	print(name, " penalty: ", amount, " | Total Penalties: ", penalties)

func _calculate_total_score():
	# Total = (Kratib × 100) + Distance – Penalties
	score = (kratips_collected * 100) + int(distance) - penalties
	emit_signal("score_changed", score)

func die() -> void:
	# If coin-protection is active, block the hit entirely
	if coin_protection_timer > 0.0:
		var warn_msg = LanguageManager.t("WARN_BLOCKED")
		set_warning(warn_msg)
		get_tree().create_timer(1.2).timeout.connect(clear_warning.bind(warn_msg))
		# Light flash instead of stun
		var tween = create_tween()
		tween.tween_property($Model, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
		tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		return
	# Normal crash
	add_penalty(100) # Crashing penalty
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
	# Handle skill charges (Removed 5-Kratip milestone check)
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
	emit_signal("warning_changed", LanguageManager.t("HUD_ROLLING_SKILL"))
	
	# Build anticipation
	var roll_timer = get_tree().create_timer(1.2)
	await roll_timer.timeout
	
	if game_manager and game_manager.has_method("get_random_skill"):
		prepared_skill = game_manager.get_random_skill()
		is_skill_ready = true
		is_rolling_skill = false
		emit_signal("skill_state_changed", true, prepared_skill)
		emit_signal("warning_changed", LanguageManager.t("HUD_GOT_SKILL") + LanguageManager.skill_name(prepared_skill))

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

func add_skill(skill_name: String) -> bool:
	if skills.size() < 2:
		skills.append(skill_name)
		emit_signal("skills_changed", skills)
		var warn_msg = LanguageManager.t("WARN_OBTAINED") + skill_name
		set_warning(warn_msg)
		# clear message
		get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
		return true
	return false

func use_skill_at_slot(slot_index: int):
	if slot_index < skills.size():
		var skill_name = skills[slot_index]
		if skill_name != "":
			var success = false
			if game_manager:
				success = game_manager.request_skill(self, skill_name)
			else:
				success = true
			
			if success:
				print(name, " using skill: ", skill_name, " from slot ", slot_index)
				skills.remove_at(slot_index)
				emit_signal("skills_changed", skills)
				# Play per-skill SFX
				match skill_name:
					"Boon Bang Fai":        AudioManager.play_sfx("skill_bang_fai")
					"Rice Yard Dust":       AudioManager.play_sfx("skill_dust")
					"Field Wind", "Wind Push": AudioManager.play_sfx("skill_wind")
					_:                      AudioManager.play_sfx("skill_use")
				# VFX
				#VfxManager.spawn("skill_use", global_position)
				var warn_msg = LanguageManager.t("WARN_USED") + skill_name
				set_warning(warn_msg)
				
				get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
			else:
				print(name, " skill ", skill_name, " is on global cooldown!")
				var warn_msg = LanguageManager.t("WARN_COOLDOWN")
				set_warning(warn_msg)
				get_tree().create_timer(1.0).timeout.connect(clear_warning.bind(warn_msg))

func apply_prank(skill_name):
	# Coin protection blocks opponent skills entirely
	if coin_protection_timer > 0.0:
		var warn_msg = LanguageManager.t("WARN_PKM_DEFLECT")
		set_warning(warn_msg)
		get_tree().create_timer(1.2).timeout.connect(clear_warning.bind(warn_msg))
		# Light flash instead of taking debuff
		var tween = create_tween()
		tween.tween_property($Model, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
		tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		return
		
	match skill_name:
		"Rice Yard Dust":
			# ฝุ่นลานข้าว — ช้าลงทั้งเสี๚ระยะการเปลี่ยนเลน
			effect_durations["slow_floor"] = 4.0
		"Lane Swap":
			lane = -1 if lane >= 0 else 1
		"Boon Bang Fai":
			# บั้งไฟ — ทำให้สะดุ้งชั่วคราว
			effect_durations["slow_speed"] = 4.0
		"Screen Blur":
			# หมอกควัน — ชั่วคราวมองไม่ชัด
			effect_durations["screen_blur"] = 4.0
		"Pull to Center":
			# ดึงกลาง
			lane = 0
			velocity.y = 5.0
		"Knockback":
			global_position.z += 6.0
			velocity.y = 5.0
		"Invert Controls":
			# กลับทาง
			effect_durations["invert_controls"] = 4.5
		"Lane Block":
			# กีดขวาง
			if game_manager:
				game_manager.spawn_lane_block(self)
		"Field Wind":
			# ลมทุ่ง — ผลักซ้ายขวา
			effect_durations["wind_push"] = 3.0
		"Wind Push":
			# Legacy alias
			effect_durations["wind_push"] = 3.0
		_:
			pass

func on_prank_state_updated(prank):
	# Map PrankState to UI Warnings
	# PrankState { QUEUED, PREPARED, ARMED, ACTIVE, BLOCKED, FINISHED, CANCELLED }
	match prank.state:
		1: # PREPARED (not used in this simplified flow yet, but for consistency)
			pass
		2: # ARMED
			set_warning(prank.type + LanguageManager.t("WARN_INCOMING"))
		4: # BLOCKED
			var warn_msg = LanguageManager.t("WARN_BLOCKED")
			set_warning(warn_msg)
			get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
		3: # ACTIVE (Failed to block)
			var warn_msg = LanguageManager.t("WARN_HIT")
			set_warning(warn_msg)
			get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))

func set_warning(text):
	emit_signal("warning_changed", text)
	
	# Bot auto-defend logic (uses Pha Khao Ma skill in slot if available)
	if is_bot and LanguageManager.t("WARN_INCOMING") in text:
		var shield_slot = -1
		for i in range(skills.size()):
			if skills[i] == "Pha Khao Ma":
				shield_slot = i
				break
		if shield_slot != -1:
			var slot_to_use = shield_slot
			get_tree().create_timer(randf_range(0.2, 0.5)).timeout.connect(_bot_use_shield_delayed.bind(slot_to_use))
	
	# Visual feedback for warning/blocking
	if text == LanguageManager.t("WARN_BLOCKED"):
		# Pulse green-ish or just jump
		var tween_block = create_tween()
		tween_block.tween_property($Model, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
		tween_block.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	elif text != "":
		# Warning pulse (bounce slightly up from rest Y)
		var tween_warn = create_tween()
		var rest_y = model_offset.y + model_y_offset
		tween_warn.tween_property($Model, "position:y", rest_y + 0.2, 0.1)
		tween_warn.tween_property($Model, "position:y", rest_y, 0.1)

func clear_warning(_message_to_clear = ""):
	emit_signal("warning_changed", "")

func _bot_use_shield_delayed(slot_to_use: int):
	if slot_to_use < skills.size() and skills[slot_to_use] == "Pha Khao Ma":
		use_skill_at_slot(slot_to_use)

# --- Animation Helpers ---

func _setup_animations():
	if !anim_player: return
	
	# Ensure we have a default library and it's unique
	if anim_player.has_animation_library(""):
		var old_lib = anim_player.get_animation_library("")
		anim_player.remove_animation_library("")
		anim_player.add_animation_library("", old_lib.duplicate())
	else:
		anim_player.add_animation_library("", AnimationLibrary.new())

func _auto_assign_files():
	# Simple check: if we have "man" in the name, use man animations
	var is_male = "man" in name.to_lower() or (get_parent() and "Player1" in name)
	
	if is_male:
		if !model_file: model_file = "res://assets/models/player/manTmodel.glb"
		if !run_file: run_file = "res://assets/animation/Running.glb"
		if !jump_file: jump_file = "res://assets/animation/jump.glb"
		if !stun_file: stun_file = "res://assets/animation/Stun.glb"
	else:
		if !model_file: model_file = "res://assets/models/player/girlTmodel.glb"
		if !run_file: run_file = "res://assets/animation/Running.glb"
		if !jump_file: jump_file = "res://assets/animation/jump.glb"
		if !stun_file: stun_file = "res://assets/animation/Stun.glb"

func _import_anim(path: String, target_name: String):
	if !FileAccess.file_exists(path): 
		print("[ANIM] File not found: ", path)
		return
		
	var res = load(path)
	if res is PackedScene:
		var scene = res.instantiate()
		var ap = scene.find_child("AnimationPlayer", true, false)
		if ap:
			# Get the default library from the animation file
			var lib = ap.get_animation_library("")
			if lib:
				var anim_names = lib.get_animation_list()
				var source_name = ""
				for n in anim_names:
					if n != "RESET":
						source_name = n
						break
				
				if source_name != "":
					var anim = lib.get_animation(source_name).duplicate()
					
					# Simplified Retargeting: Just ensure tracks point to bones correctly
					_apply_anim_to_player(anim, target_name)
					print("[ANIM] Imported ", target_name, " from ", path)
		scene.free()

func _apply_anim_to_player(anim: Animation, target_name: String):
	var lib = anim_player.get_animation_library("")
	if lib:
		if lib.has_animation(target_name):
			lib.remove_animation(target_name)
		
		var skeleton = find_child("GeneralSkeleton", true, false)
		if !skeleton: skeleton = find_child("Skeleton3D", true, false)
		
		if !skeleton:
			print("[ANIM] ERROR: No skeleton found during apply for ", name)
			return

		# Clean up track paths to be relative to the root_node (Skeleton parent)
		var tracks_fixed = 0
		var tracks_to_remove = []
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			var p_lower = path.to_lower()
			
			# Root Motion Removal for jump animation
			if target_name == anim_jump:
				if p_lower.ends_with(":position") or p_lower.ends_with(":location"):
					if "hips" in p_lower or "metarig" in p_lower or "armature" in p_lower or "root" in p_lower:
						tracks_to_remove.append(i)
						continue

			if ":" in path:
				var parts = path.split(":")
				# Mixamo/Godot 4 track pattern: "Node/Path:BoneName" or "Node/Path:BoneName:property"
				var bone_name = ""
				var property = ""
				
				if parts.size() >= 2:
					bone_name = parts[1]
					if parts.size() >= 3:
						property = parts[2]
					
					# Clean bone name
					bone_name = bone_name.replace("mixamorig:", "").replace("Armature|", "")
					
					# Construct correct Godot 4 skeleton track path
					var new_path = skeleton.name + ":" + bone_name
					if property != "" and property != "position" and property != "rotation" and property != "scale" and property != "quaternion":
						# If property is something else, append it, otherwise Godot handles transform properties automatically
						new_path += ":" + property
					
					anim.track_set_path(i, NodePath(new_path))
					tracks_fixed += 1
				else:
					tracks_to_remove.append(i)
			else:
				tracks_to_remove.append(i)
		
		# Remove invalid/unresolved tracks (like metarig node tracks) in reverse order
		tracks_to_remove.reverse()
		for i in tracks_to_remove:
			anim.remove_track(i)
		
		lib.add_animation(target_name, anim)
		if target_name == anim_run:
			anim.loop_mode = Animation.LOOP_LINEAR
		
		print("[ANIM] Applied ", target_name, " to ", name, " (fixed ", tracks_fixed, " tracks)")

func _retarget_animation(anim: Animation, anim_name: String = ""):
	if !anim: return
	
	# Find our skeleton
	var skeleton = find_child("GeneralSkeleton", true, false)
	if !skeleton:
		skeleton = find_child("Skeleton3D", true, false)
	
	if !skeleton: 
		# If still not found, search for any Skeleton3D
		var all_skeletons = find_children("*", "Skeleton3D", true, false)
		if all_skeletons.size() > 0:
			skeleton = all_skeletons[0]
	
	if !skeleton:
		print("[ANIM] No skeleton found for ", name)
		return
	
	var skeleton_path = get_path_to(skeleton)
	var bones = []
	for b in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_name(b))
	
	# Mapping from common Mixamo/Blender source names to target names
	var bone_map = {
		"Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "UpperChest", 
		"Neck": "Neck", "Head": "Head",
		"LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm", "LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
		"RightShoulder": "RightShoulder", "RightArm": "RightUpperArm", "RightForeArm": "RightLowerArm", "RightHand": "RightHand",
		"LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg", "LeftFoot": "LeftFoot",
		"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg", "RightFoot": "RightFoot",
		"spine": "Spine", "spine.001": "Chest", "spine.002": "UpperChest", "spine.003": "Neck", "spine.004": "Head",
		"shoulder.L": "LeftShoulder", "upper_arm.L": "LeftUpperArm", "forearm.L": "LeftLowerArm", "hand.L": "LeftHand",
		"shoulder.R": "RightShoulder", "upper_arm.R": "RightUpperArm", "forearm.R": "RightLowerArm", "hand.R": "RightHand",
		"thigh.L": "LeftUpperLeg", "shin.L": "LeftLowerLeg", "foot.L": "LeftFoot",
		"thigh.R": "RightUpperLeg", "shin.R": "RightLowerLeg", "foot.R": "RightFoot"
	}

	var tracks_to_remove = []
	for i in range(anim.get_track_count()):
		var path = anim.track_get_path(i)
		var path_str = str(path)
		var p_lower = path_str.to_lower()

		# 0. Root Motion Removal (Fix backward jumping and rotation bugs)
		if p_lower.ends_with(":position") or p_lower.ends_with(":location"):
			if "hips" in p_lower or "metarig" in p_lower or "armature" in p_lower or "root" in p_lower:
				if anim_name == anim_run:
					tracks_to_remove.append(i)
					continue
		
		# 1. Extract potential bone name from track path
		var found_bone = ""
		var property = ""
		
		if ":" in path_str:
			var parts = path_str.split(":")
			
			# Search each part for a bone match
			for part in parts:
				var clean_part = part.replace("mixamorig:", "").replace("Armature|", "")
				
				# Try direct match
				for b in bones:
					if b.to_lower() == clean_part.to_lower():
						found_bone = b
						break
				if found_bone != "": break
				
				# Try mapping
				if bone_map.has(clean_part):
					var mapped = bone_map[clean_part]
					for b in bones:
						if b.to_lower() == mapped.to_lower():
							found_bone = b
							break
				if found_bone != "": break
			
			if found_bone != "":
				# Check if the last part is a property
				var last_part = parts[parts.size() - 1]
				if last_part.to_lower() in ["position", "rotation", "scale", "quaternion", "location"]:
					property = last_part
				
				var new_path = str(skeleton_path) + ":" + found_bone
				if property != "" and property != found_bone:
					new_path += ":" + property
				
				anim.track_set_path(i, NodePath(new_path))
			else:
				tracks_to_remove.append(i)
		else:
			# Node track
			tracks_to_remove.append(i)
	
	# Remove tracks from end to start
	tracks_to_remove.reverse()
	for i in tracks_to_remove:
		anim.remove_track(i)
	
	if anim_player.has_method("clear_caches"):
		anim_player.clear_caches()
	
	# Force an update of the animation mixer
	if anim_player.has_method("force_update_cache"):
		anim_player.force_update_cache()

func play_animation(anim_name: String, custom_blend: float = 0.15):
	if !anim_player: return
	
	if current_anim == anim_name and anim_player.is_playing():
		return
	
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name, custom_blend)
		current_anim = anim_name
		print("[ANIM] Playing: ", anim_name, " on ", name)
	else:
		# Check all libraries
		var found = false
		for lib_name in anim_player.get_animation_library_list():
			var full_name = anim_name if lib_name == "" else lib_name + "/" + anim_name
			if anim_player.has_animation(full_name):
				anim_player.play(full_name, custom_blend)
				current_anim = anim_name
				found = true
				print("[ANIM] Playing from lib: ", full_name, " on ", name)
				break
		
		if !found:
			print("[ANIM] WARNING: Animation not found: ", anim_name, " in ", name)


# --- DEBUG FUNCTIONS ---
func debug_set_distance(value: float):
	# Move the player's Z position to simulate the distance
	global_position.z = start_z - value
	distance = int(value)
	emit_signal("distance_changed", distance)

func debug_add_charge(amount: int):
	add_charge(amount)
