extends CharacterBody3D

signal score_changed(amount)
signal distance_changed(amount)
signal charge_changed(current, max)
signal skill_state_changed(is_ready, skill_name)
signal warning_changed(message)
signal skills_changed(new_skills)
signal kratip_count_changed(current: int, needed: int)  # For HUD kratip counter
signal obstacle_hit  # Emitted when player is stunned by obstacle — used for screen flash + camera shake
signal prank_flash(color: Color)  # Emitted on receiver when hit by a skill — per-skill color
signal screen_blackout(duration: float)  # Emitted to make the screen go black for a duration

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
var kratip_milestone_count := 0 # Kratips toward next silk (0-9, resets at 10)
var skills_used := 0            # Total skills used (for Endless results screen)
var penalties := 0

var slide_timer := 0.0
const SLIDE_DURATION := 0.7
var score := 0
var charges := 0
var can_charge := true
var effect_durations := {}

# --- ENDLESS MODE: ELEPHANT CHASE ---
var elephant_gap := 30.0          # Distance (m) between player and elephant
const ELEPHANT_START_GAP := 30.0
var obstacle_strikes: int = 0
var safe_run_timer: float = 0.0

# --- ENDLESS MODE: BUFFALO RIDE ---
var is_riding_buffalo := false
var buffalo_timer := 0.0
const BUFFALO_DURATION := 9.0
const BUFFALO_SPEED_BONUS := 8.0   # Extra forward speed while riding
var buffalo_hit_absorb := true # Ignore ONE obstacle collision while riding
var buffalo_model: Node3D = null

const SILK_PROTECTION_DURATION := 5.0
var silk_protection_timer := 0.0  # > 0 means silk protection is active

var prepared_skill := ""
var is_skill_ready := false
var is_rolling_skill := false
var skills: Array[String] = []

var shield_vfx : MeshInstance3D = null
var trail_vfx : CPUParticles3D = null          # Gold energy trail (silk protection)
var dust_trail_vfx : CPUParticles3D = null     # Dirt dust while running on ground
var speed_trail_vfx : CPUParticles3D = null    # Speed streak at high velocity
var energy_trail_vfx : CPUParticles3D = null   # Glow overlay during invincibility
var spawn_shield_vfx : MeshInstance3D = null   # Blue shield for spawn
var _was_on_floor := false                     # For landing detection
var _pending_spawn_shield_duration := 0.0      # Shield grant queued before _ready() finished
var anim_player : AnimationPlayer = null
var current_anim : String = ""

@export_group("Animations")
@export var anim_run : String = "run"
@export var anim_jump : String = "jump"
@export var anim_stun : String = "stun"
@export var anim_slide : String = "slide"
@export var anim_buffalo_ride : String = "buffalo_ride"

@export_group("Animation Files")
@export_file("*.glb") var model_file : String
@export_file("*.glb") var run_file : String
@export_file("*.glb") var jump_file : String
@export_file("*.glb") var stun_file : String
@export_file("*.glb") var slide_file : String
@export_file("*.glb") var buffalo_ride_file : String

@export_group("Model Offset")
# Y offset: compensates for GLB pivot not being at feet.
# manTmodel.glb (Blender rig) origin is at hip-center, so we pull it down.
# Adjust this value if the character still sinks or floats.
@export var model_offset := Vector3(0.0, 0.0, 0.0)
@export var model_y_offset : float = 0.0  # Fine-tune Y separately per character
@export var stun_model_y_offset : float = -0.5  # Negative value lowers the character when laying flat

var distance := 0.0
var start_z := 0.0
var _cached_skeleton : Skeleton3D = null
var _cached_spine_bone_idx := -2

@export var left_action : String
@export var right_action : String
@export var jump_action : String
@export var skill_action : String
@export var defend_action : String
@export var slide_action : String

@export var is_bot := false
var bot_think_timer := 0.0
var bot_jump_cooldown := 0.0

var game_manager : Node = null

var sfx_jump: AudioStreamPlayer
var sfx_slide: AudioStreamPlayer

func _ready():
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	start_z = global_position.z
	_setup_shield_vfx()
	add_to_group("player")
	
	# Make shadow material unique so players jumping don't affect each other's shadow
	var ray = get_node_or_null("ShadowRay")
	if ray:
		var mesh = ray.get_node_or_null("BlobShadowMesh")
		if mesh and mesh.mesh and mesh.mesh.material:
			mesh.mesh.material = mesh.mesh.material.duplicate()
			
	lane = int(round(position.x / lane_distance))
	_setup_spawn_shield_vfx()
	_setup_trail_vfx()
	
	sfx_jump = AudioStreamPlayer.new()
	sfx_jump.stream = load("res://assets/audio/Jump.wav")
	add_child(sfx_jump)
	
	sfx_slide = AudioStreamPlayer.new()
	sfx_slide.stream = load("res://assets/audio/Slide.wav")
	add_child(sfx_slide)
	
	var shape_node = get_node_or_null("CollisionShape3D")
	if shape_node and shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate()
	
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
		if slide_file: _import_anim(slide_file, anim_slide)
		if buffalo_ride_file: _import_anim(buffalo_ride_file, anim_buffalo_ride)
		
		# Force active and play
		anim_player.active = true
		play_animation(anim_run)
	else:
		print("[ANIM] ERROR: Failed to even create an AnimationPlayer for ", name)
	
	# Auto-correct model Y so mesh feet sit exactly on the floor (Y=0 local)
	# This fixes the "character sinks into ground" issue caused by GLB pivot offset
	await get_tree().process_frame
	_auto_fix_model_y_offset()
	
	# Apply any spawn shield that was granted before _ready() finished
	if _pending_spawn_shield_duration > 0.0:
		grant_spawn_shield(_pending_spawn_shield_duration)
		_pending_spawn_shield_duration = 0.0

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
		
	if !ResourceLoader.exists(model_file):
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
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.1) # Golden translucent (fainter)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.0)
	mat.emission_energy_multiplier = 1.0
	shield_vfx.material_override = mat
	
	add_child(shield_vfx)
	shield_vfx.visible = false

func _setup_spawn_shield_vfx():
	spawn_shield_vfx = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.7
	sphere.height = 3.4
	spawn_shield_vfx.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from inside too
	mat.albedo_color = Color(0.15, 0.55, 1.0, 0.55) # Brighter blue, more opaque
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.emission_energy_multiplier = 3.5
	spawn_shield_vfx.material_override = mat
	spawn_shield_vfx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(spawn_shield_vfx)
	spawn_shield_vfx.visible = false

func _setup_trail_vfx():
	# ── Gold Energy Trail (toggled by silk protection) ──
	trail_vfx = CPUParticles3D.new()
	trail_vfx.amount = 20
	trail_vfx.lifetime = 0.4
	trail_vfx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail_vfx.emission_sphere_radius = 0.25
	trail_vfx.direction = Vector3(0, 0.3, 1)
	trail_vfx.spread = 25.0
	trail_vfx.gravity = Vector3(0, 1.5, 0)
	trail_vfx.initial_velocity_min = 0.5
	trail_vfx.initial_velocity_max = 1.2
	trail_vfx.scale_amount_min = 0.06
	trail_vfx.scale_amount_max = 0.14
	trail_vfx.color = Color(1.0, 0.82, 0.1, 0.9)
	trail_vfx.position = Vector3(0, 0.3, 0.5)
	add_child(trail_vfx)
	trail_vfx.emitting = false

	# ── Dust Trail (while running on ground) ──
	var _TEX := "res://assets/textures/brackeys_vfx_bundle/particles/opague/"
	dust_trail_vfx = CPUParticles3D.new()
	dust_trail_vfx.amount = 8
	dust_trail_vfx.lifetime = 0.55
	dust_trail_vfx.one_shot = false
	if ResourceLoader.exists(_TEX + "dirt_01.png"):
		VfxManager._set_tex(dust_trail_vfx, load(_TEX + "dirt_01.png"))
	dust_trail_vfx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust_trail_vfx.emission_sphere_radius = 0.18
	dust_trail_vfx.direction = Vector3(0, 0.5, 1)
	dust_trail_vfx.spread = 35.0
	dust_trail_vfx.gravity = Vector3(0, -0.5, 0)
	dust_trail_vfx.initial_velocity_min = 0.4
	dust_trail_vfx.initial_velocity_max = 1.0
	dust_trail_vfx.scale_amount_min = 0.14
	dust_trail_vfx.scale_amount_max = 0.28
	dust_trail_vfx.color = Color(0.78, 0.66, 0.46, 0.65)
	dust_trail_vfx.position = Vector3(0, 0.05, 0.35)
	add_child(dust_trail_vfx)
	dust_trail_vfx.emitting = false

	# ── Speed Trail (trace streak at high speed) ──
	speed_trail_vfx = CPUParticles3D.new()
	speed_trail_vfx.amount = 6
	speed_trail_vfx.lifetime = 0.25
	speed_trail_vfx.one_shot = false
	if ResourceLoader.exists(_TEX + "trace_01.png"):
		VfxManager._set_tex(speed_trail_vfx, load(_TEX + "trace_01.png"))
	speed_trail_vfx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	speed_trail_vfx.emission_sphere_radius = 0.15
	speed_trail_vfx.direction = Vector3(0, 0.1, 1)   # Shoot backward
	speed_trail_vfx.spread = 8.0
	speed_trail_vfx.gravity = Vector3.ZERO
	speed_trail_vfx.initial_velocity_min = 2.0
	speed_trail_vfx.initial_velocity_max = 4.5
	speed_trail_vfx.scale_amount_min = 0.08
	speed_trail_vfx.scale_amount_max = 0.18
	speed_trail_vfx.color = Color(0.55, 0.85, 1.0, 0.80)
	speed_trail_vfx.position = Vector3(0, 0.5, 0.4)
	add_child(speed_trail_vfx)
	speed_trail_vfx.emitting = false

	# ── Energy Trail Overlay (silk invincibility, stacked on trail_vfx) ──
	energy_trail_vfx = CPUParticles3D.new()
	energy_trail_vfx.amount = 14
	energy_trail_vfx.lifetime = 0.5
	energy_trail_vfx.one_shot = false
	if ResourceLoader.exists(_TEX + "light_01.png"):
		VfxManager._set_tex(energy_trail_vfx, load(_TEX + "light_01.png"))
	energy_trail_vfx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	energy_trail_vfx.emission_sphere_radius = 0.40
	energy_trail_vfx.direction = Vector3(0, 0.5, 0.5)
	energy_trail_vfx.spread = 45.0
	energy_trail_vfx.gravity = Vector3(0, 0.8, 0)
	energy_trail_vfx.initial_velocity_min = 0.6
	energy_trail_vfx.initial_velocity_max = 1.5
	energy_trail_vfx.scale_amount_min = 0.08
	energy_trail_vfx.scale_amount_max = 0.20
	energy_trail_vfx.color = Color(0.6, 1.0, 0.8, 0.85)
	energy_trail_vfx.position = Vector3(0, 0.8, 0)
	add_child(energy_trail_vfx)
	energy_trail_vfx.emitting = false

func _sync_model_to_body():
	# Always keep the Model node at the correct local offset.
	# The CharacterBody3D origin is at its FEET (capsule bottom) after move_and_slide,
	# so we only apply the designer-tuned model_offset here, not global Y.
	var model_node = get_node_or_null("Model")
	if model_node:
		model_node.position.x = model_offset.x
		var target_y = model_offset.y + model_y_offset
		if slide_timer > 0:
			target_y -= 0.8
		if is_riding_buffalo:
			target_y += 0.8 # Lift player up to sit on buffalo
		model_node.position.y = target_y
		model_node.position.z = model_offset.z

func _process(_delta):
	_update_blob_shadow()


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
		if anim_player:
			anim_player.speed_scale = 1.0
		play_animation(anim_stun)
		
		# Stun: lay flat (-90°) — lift model up to prevent sinking
		# Stun: lay flat (90°) unless waiting for the final elephant catch
		if GameConfig.race_mode == "endless" and obstacle_strikes >= 3 and alive:
			$Model.rotation.x = 0.0
		else:
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

	if silk_protection_timer > 0:
		silk_protection_timer -= delta
		if silk_protection_timer <= 0:
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
			
			if spawn_shield_vfx and spawn_shield_vfx.visible:
				var fade_tween = create_tween()
				fade_tween.tween_property(spawn_shield_vfx, "scale", Vector3(1.6, 1.6, 1.6), 0.2)
				fade_tween.parallel().tween_property(spawn_shield_vfx, "material_override:albedo_color:a", 0.0, 0.2)
				fade_tween.tween_callback(func(): 
					spawn_shield_vfx.visible = false
					spawn_shield_vfx.scale = Vector3.ONE
					spawn_shield_vfx.material_override.albedo_color.a = 0.4
				)
				
			# Also stop the trail when silk protection ends
				if trail_vfx:
					trail_vfx.emitting = false

	var speed_factor = 1.0
	if _has_effect("slow_speed"):
		speed_factor *= 0.7
		
	$Model.scale = Vector3(1.0, 1.0, 1.0)
	if game_manager and game_manager.get("countdown_active") == true:
		$Model.rotation.y = 0.0
	else:
		$Model.rotation.y = PI
		
	# Pin model to body every frame (fixes sinking)
	_sync_model_to_body()
	
	# Flash or shake when hit by Field Wind
	if _has_effect("wind_push"):
		# Strong random shaking (left/right)
		var shake_t = Engine.get_frames_drawn() * 1.2
		$Model.rotation.z = sin(shake_t) * 0.35 + randf_range(-0.08, 0.08)
		$Model.position.x = model_offset.x + sin(shake_t * 1.7) * 0.25
	elif _has_effect("slow_floor"):
		$Model.rotation.z = sin(Engine.get_frames_drawn() * 0.5) * 0.15
	else:
		$Model.rotation.z = 0

	# --- ENDLESS: Buffalo Ride timer ---
	if is_riding_buffalo:
		buffalo_timer -= delta
		if buffalo_timer <= 0.0:
			_end_buffalo_ride()
	elif GameConfig.race_mode == "endless" and alive and stun_timer <= 0.0:
		# Recover strikes if running safely
		safe_run_timer += delta
		if safe_run_timer >= 12.0 and obstacle_strikes > 0:
			obstacle_strikes -= 1
			safe_run_timer = 0.0

	# Calculate dynamic speed based on distance (+ global speed scale + buffalo bonus)
	var gm_speed_scale := 1.0
	if game_manager and "global_speed_scale" in game_manager:
		gm_speed_scale = float(game_manager.get("global_speed_scale"))
	var buffalo_bonus: float = BUFFALO_SPEED_BONUS if is_riding_buffalo else 0.0
	var current_speed: float = min((BASE_FORWARD_SPEED + (distance * SPEED_SCALE_FACTOR)) * gm_speed_scale + buffalo_bonus, MAX_FORWARD_SPEED)
	velocity.z = -current_speed * speed_factor

	# ── Speed trail: when going fast (e.g. > 130% base speed) ──
	if speed_trail_vfx:
		var want_speed: bool = current_speed > (BASE_FORWARD_SPEED * 1.3) and alive
		if speed_trail_vfx.emitting != want_speed:
			speed_trail_vfx.emitting = want_speed

	# ── Energy trail: when silk protection is active ──
	if energy_trail_vfx:
		var want_energy: bool = silk_protection_timer > 0 and alive
		if energy_trail_vfx.emitting != want_energy:
			energy_trail_vfx.emitting = want_energy

	if slide_timer > 0:
		slide_timer -= delta
		if slide_timer <= 0:
			_end_slide()

	# Animation handling for normal state
	if is_on_floor():
		if slide_timer > 0:
			play_animation(anim_slide)
			if anim_player:
				anim_player.speed_scale = 1.0
		elif is_riding_buffalo:
			play_animation(anim_buffalo_ride)
			if anim_player and current_anim == anim_buffalo_ride:
				anim_player.speed_scale = 1.0
		else:
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
			if slide_timer > 0:
				_end_slide()
			velocity.y = JUMP_FORCE
			sfx_jump.play()

		if slide_action != "" and Input.is_action_just_pressed(slide_action) and is_on_floor() and slide_timer <= 0:
			_start_slide()
			sfx_slide.play()

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
			
			# Smart Jump & Slide Logic
			if is_on_floor() and bot_jump_cooldown <= 0:
				var my_lane_x = lane * lane_distance
				var performed_action = false
				
				# 1. Slide for High Obstacles
				if slide_timer <= 0:
					for obs in get_tree().get_nodes_in_group("high_obstacle"):
						if abs(obs.global_position.x - my_lane_x) < 1.0:
							var dist_z = global_position.z - obs.global_position.z
							var slide_range = max(4.0, bot_curr_speed * 0.4)
							if dist_z > 0 and dist_z < slide_range:
								_start_slide()
								sfx_slide.play()
								bot_jump_cooldown = 0.8
								performed_action = true
								break
				
				# 2. Jump for Low Obstacles
				if not performed_action and slide_timer <= 0:
					for obs in get_tree().get_nodes_in_group("low_obstacle"):
						if abs(obs.global_position.x - my_lane_x) < 1.0:
							var dist_z = global_position.z - obs.global_position.z
							var jump_range = max(3.5, bot_curr_speed * 0.35)
							if dist_z > 0 and dist_z < jump_range:
								velocity.y = JUMP_FORCE
								sfx_jump.play()
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

	# ── Landing detection ──
	var now_on_floor := is_on_floor()
	if now_on_floor and !_was_on_floor and velocity.y < -1.5:
		VfxManager.spawn("landing_dust", global_position + Vector3(0, 0.05, 0))
	_was_on_floor = now_on_floor

	# ── Dust trail: only while running on ground, not stunned ──
	if dust_trail_vfx:
		var want_dust: bool = now_on_floor and velocity.length() > 2.0 and stun_timer <= 0 and alive
		if dust_trail_vfx.emitting != want_dust:
			dust_trail_vfx.emitting = want_dust

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
			
		stun(1.5)
		grant_spawn_shield(3.0)

func _update_effects(delta):
	for effect in effect_durations.keys():
		effect_durations[effect] -= delta

	var expired = []
	for effect in effect_durations.keys():
		if effect_durations[effect] <= 0:
			expired.append(effect)

	for effect in expired:
		effect_durations.erase(effect)

func _start_slide():
	slide_timer = SLIDE_DURATION
	var shape_node = get_node_or_null("CollisionShape3D")
	if shape_node and shape_node.shape is CapsuleShape3D:
		shape_node.shape.height = 0.9
		shape_node.position.y = 0.45

func _end_slide():
	slide_timer = 0.0
	var shape_node = get_node_or_null("CollisionShape3D")
	if shape_node and shape_node.shape is CapsuleShape3D:
		shape_node.shape.height = 1.8047
		shape_node.position.y = 0.9244

func _has_effect(effect_name):
	return effect_durations.has(effect_name)

func _update_blob_shadow():
	var ray = get_node_or_null("ShadowRay")
	if ray:
		var mesh = ray.get_node_or_null("BlobShadowMesh")
		if mesh:
			if ray.is_colliding():
				var model_node = get_node_or_null("Model")
				if model_node:
					mesh.global_position = Vector3(model_node.global_position.x, ray.get_collision_point().y + 0.05, model_node.global_position.z)
				else:
					mesh.global_position = Vector3(global_position.x, ray.get_collision_point().y + 0.05, global_position.z)
				mesh.visible = true
				
				# Fade shadow based on distance to ground (max fade at 3 units up)
				var dist = global_position.y - mesh.global_position.y
				var alpha = clamp(1.0 - (dist / 3.0), 0.0, 1.0) * 0.8
				if mesh.mesh and mesh.mesh.material:
					mesh.mesh.material.albedo_color.a = alpha
			else:
				mesh.visible = false

func add_score(amount):
	# Called by kratip.gd on collect — routes through add_kratip
	add_kratip(amount)

func add_kratip(amount: int = 1):
	kratips_collected += amount
	kratip_milestone_count += amount
	_calculate_total_score()
	emit_signal("kratip_count_changed", kratip_milestone_count, 10)
	# Collectible sparkle effect
	_spawn_collect_sparkle()

func _spawn_collect_sparkle():
	VfxManager.spawn("kratip_pickup", global_position + Vector3(0, 1.0, 0))
	
	# Every 10 kratips → action depends on game mode
	if kratip_milestone_count >= 10:
		kratip_milestone_count = 0
		emit_signal("kratip_count_changed", 0, 10)
		AudioManager.play_sfx("pickup")
		
		if GameConfig.race_mode == "endless":
			# ENDLESS MODE: Ride a Buffalo!
			start_buffalo_ride()
		else:
			# RACE MODE: Grant Pha Khao Ma shield
			var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
			if hud and hud.has_method("show_shield_unlock"):
				hud.show_shield_unlock(self.name)
			grant_silk_protection()

func start_buffalo_ride() -> void:
	"""Activate Buffalo Ride: speed boost + elephant gap recovery + one obstacle hit absorb."""
	obstacle_strikes = 0  # Reset strikes
	safe_run_timer = 0.0
	
	if is_riding_buffalo:
		# Refresh timer if already riding
		buffalo_timer = BUFFALO_DURATION
		return
	
	is_riding_buffalo = true
	buffalo_timer = BUFFALO_DURATION
	buffalo_hit_absorb = true
	
	if buffalo_model == null:
		var b_scene = load("res://assets/models/buffalo/buffalorun.glb")
		if b_scene:
			buffalo_model = b_scene.instantiate()
			buffalo_model.rotation_degrees.y = 180 # Face backwards relative to Z+ (forward in Godot is -Z)
			buffalo_model.scale = Vector3(1.5, 1.5, 1.5) # Reset to larger scale (1.5x)
			add_child(buffalo_model) # Add to CharacterBody3D instead of Model to avoid mesh scaling issues
			var anims = buffalo_model.find_children("*", "AnimationPlayer", true)
			if anims.size() > 0:
				var anim = anims[0]
				var list = anim.get_animation_list()
				if list.size() > 0:
					var a = anim.get_animation(list[0])
					if a: a.loop_mode = Animation.LOOP_LINEAR
					anim.play(list[0])
	
	if buffalo_model:
		buffalo_model.visible = true
	
	# Elephant gains distance boost — give player breathing room
	if game_manager and game_manager.has_method("on_buffalo_ride_started"):
		game_manager.on_buffalo_ride_started(self)
	
	# Notify HUD
	var hud = get_tree().current_scene.find_child("GameplayHUD", true, false)
	if hud and hud.has_method("show_buffalo_ride"):
		hud.show_buffalo_ride(self.name, BUFFALO_DURATION)
	
	# Warning text
	var msg := "🐃 BUFFALO RIDE!"
	set_warning(msg)
	get_tree().create_timer(2.0).timeout.connect(clear_warning.bind(msg))
	
	AudioManager.play_sfx("skill_use")  # Placeholder; replace with buffalo SFX

func _end_buffalo_ride() -> void:
	"""Deactivate Buffalo Ride — return to normal speed."""
	is_riding_buffalo = false
	buffalo_timer = 0.0
	buffalo_hit_absorb = false
	
	if buffalo_model:
		buffalo_model.visible = false
	
	var msg := "🐘 Elephant resumes!"
	set_warning(msg)
	get_tree().create_timer(2.0).timeout.connect(clear_warning.bind(msg))

func grant_silk_protection():
	"""Grant or refresh the 5-second collision-immunity from a silk collectible."""
	silk_protection_timer = SILK_PROTECTION_DURATION
	var warn_msg = LanguageManager.t("WARN_PKM_PROTECT")
	set_warning(warn_msg)
	get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
	_show_shield_vfx()
	# Activate golden trail during silk protection
	if trail_vfx:
		trail_vfx.emitting = true

func grant_spawn_shield(duration: float = 3.0):
	# If VFX node isn't ready yet (called before _ready finishes), queue it
	if spawn_shield_vfx == null:
		_pending_spawn_shield_duration = duration
		silk_protection_timer = duration  # Still apply protection even if VFX not ready
		return
	silk_protection_timer = duration
	_show_spawn_shield_vfx()

func add_penalty(amount):
	penalties += amount
	_calculate_total_score()
	print(name, " penalty: ", amount, " | Total Penalties: ", penalties)

func _calculate_total_score():
	# Total = (Kratib × 100) + Distance – Penalties
	score = (kratips_collected * 100) + int(distance) - penalties
	emit_signal("score_changed", score)

func die() -> void:
	# --- ENDLESS MODE: Buffalo hit absorb blocks ONE collision ---
	if GameConfig.race_mode == "endless" and is_riding_buffalo and buffalo_hit_absorb:
		buffalo_hit_absorb = false  # Consume the one-hit absorb
		var warn_msg := "🐃 Buffalo absorbs the hit!"
		set_warning(warn_msg)
		get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
		emit_signal("prank_flash", Color(0.6, 0.3, 0.0, 0.35))
		return
	
	# Silk protection (both modes)
	if silk_protection_timer > 0.0:
		var warn_msg = LanguageManager.t("WARN_BLOCKED")
		set_warning(warn_msg)
		get_tree().create_timer(1.2).timeout.connect(clear_warning.bind(warn_msg))
		var tween = create_tween()
		tween.tween_property($Model, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
		tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		if spawn_shield_vfx and spawn_shield_vfx.visible:
			VfxManager.spawn("spawn_shield_hit", global_position + Vector3(0, 1.0, 0))
		return
	
	# Normal crash — increment strikes in Endless Mode
	if GameConfig.race_mode == "endless":
		obstacle_strikes += 1
		safe_run_timer = 0.0
		if game_manager and game_manager.has_method("on_player_crash"):
			game_manager.on_player_crash(self)
	
	if is_riding_buffalo:
		_end_buffalo_ride()
	
	add_penalty(100)
	stun(1.5)

func stun(duration: float = 1.5):
	stun_timer = duration
	velocity.z = 0
	# Visual feedback: Scale pulse
	var tween = create_tween()
	tween.tween_property($Model, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
	tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	# Obstacle hit feedback: screen flash (red) + camera shake
	emit_signal("obstacle_hit")
	AudioManager.play_sfx("obstacle_hit")
	VfxManager.spawn("obstacle_hit", global_position + Vector3(0, 1.0, 0))
	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.15, 0.20)

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
		AudioManager.play_sfx("skill_ready")

func request_skill():
	if charges < MAX_CHARGES:
		return
	if !is_skill_ready:
		_prepare_skill()
		return
	if game_manager:
		game_manager.request_skill(self, prepared_skill)
		AudioManager.play_sfx("skill_use")  # Caster SFX
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
		shield_vfx.material_override.albedo_color.a = 0.1
	)

func _show_spawn_shield_vfx():
	if !spawn_shield_vfx: return
	
	spawn_shield_vfx.visible = true
	spawn_shield_vfx.scale = Vector3.ZERO
	spawn_shield_vfx.material_override.albedo_color.a = 0.55
	
	var tween = create_tween()
	# Pop in with bounce
	tween.tween_property(spawn_shield_vfx, "scale", Vector3(1.3, 1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(spawn_shield_vfx, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	
	# Pulse effect — loops for ~3 seconds (6 loops × 0.5s)
	var pulse_tween = create_tween().set_loops(6)
	pulse_tween.tween_property(spawn_shield_vfx, "scale", Vector3(1.08, 1.08, 1.08), 0.25)
	pulse_tween.tween_property(spawn_shield_vfx, "scale", Vector3(1.0, 1.0, 1.0), 0.25)
	
	# Auto-hide after shield duration expires (fade out)
	var shield_duration = silk_protection_timer
	var delay_tw = create_tween()
	delay_tw.tween_callback(func():
		if is_instance_valid(spawn_shield_vfx) and spawn_shield_vfx.visible:
			var fade = create_tween()
			fade.tween_property(spawn_shield_vfx, "material_override:albedo_color:a", 0.0, 0.4)
			fade.parallel().tween_property(spawn_shield_vfx, "scale", Vector3(1.4, 1.4, 1.4), 0.4)
			fade.tween_callback(func():
				if is_instance_valid(spawn_shield_vfx):
					spawn_shield_vfx.visible = false
					spawn_shield_vfx.scale = Vector3.ONE
					spawn_shield_vfx.material_override.albedo_color.a = 0.55
			)
	).set_delay(max(shield_duration - 0.4, 0.1))

func add_skill(skill_name: String) -> bool:
	if skills.size() < 2:
		skills.append(skill_name)
	else:
		skills[1] = skill_name # Replace the second skill slot
		
	emit_signal("skills_changed", skills)
	var warn_msg = LanguageManager.t("WARN_OBTAINED") + skill_name
	set_warning(warn_msg)
	# clear message
	get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
	return true

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
				skills_used += 1
				print(name, " using skill: ", skill_name, " from slot ", slot_index)
				skills.remove_at(slot_index)
				emit_signal("skills_changed", skills)
				# Play per-skill SFX + VFX
				VfxManager.spawn("shockwave", global_position)
				match skill_name:
					"Boon Bang Fai":
						AudioManager.play_sfx("skill_bang_fai")
						VfxManager.spawn("skill_bang_fai", global_position + Vector3(0, 1.0, 0))
					"Rice Yard Dust":
						AudioManager.play_sfx("skill_dust")
						VfxManager.spawn("skill_dust", global_position + Vector3(0, 0.5, 0))
					"Field Wind", "Wind Push":
						AudioManager.play_sfx("skill_wind")
						VfxManager.spawn("skill_wind", global_position + Vector3(0, 1.0, 0))
					_:
						AudioManager.play_sfx("skill_use")
						VfxManager.spawn("skill_use", global_position + Vector3(0, 1.0, 0))
				
				# ── Visual projectile: flies from this player to the opponent ──
				# Purely cosmetic — apply_prank() timing is unchanged (fired by GameManager)
				var _proj_target : Node3D = get_tree().current_scene.find_child(
					"Player2" if name == "Player1" else "Player1", true, false) as Node3D
				if is_instance_valid(_proj_target):
					SkillProjectileManager.launch(self, _proj_target, skill_name)
				
				var warn_msg = LanguageManager.t("WARN_USED") + skill_name
				set_warning(warn_msg)
				
				get_tree().create_timer(1.5).timeout.connect(clear_warning.bind(warn_msg))
			else:
				print(name, " skill ", skill_name, " is on global cooldown!")
				var warn_msg = LanguageManager.t("WARN_COOLDOWN")
				set_warning(warn_msg)
				get_tree().create_timer(1.0).timeout.connect(clear_warning.bind(warn_msg))

func apply_prank(skill_name):
	# Silk protection blocks opponent skills entirely
	if silk_protection_timer > 0.0:
		var warn_msg = LanguageManager.t("WARN_PKM_DEFLECT")
		set_warning(warn_msg)
		get_tree().create_timer(1.2).timeout.connect(clear_warning.bind(warn_msg))
		# Shield deflect: green flash + scale pop
		emit_signal("prank_flash", Color(0.0, 1.0, 0.3, 0.35))
		AudioManager.play_sfx("shield_block")
		var tween = create_tween()
		tween.tween_property($Model, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
		tween.tween_property($Model, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
		
		if spawn_shield_vfx and spawn_shield_vfx.visible:
			VfxManager.spawn("spawn_shield_hit", global_position + Vector3(0, 1.0, 0))
		else:
			VfxManager.spawn("shield_block", global_position + Vector3(0, 1.0, 0))
		return
	
	VfxManager.spawn("skill_hit_generic", global_position + Vector3(0, 1.0, 0))
	
	# Per-skill SFX + flash color (Receiver side only)
	match skill_name:
		"Rice Yard Dust":
			# ฝุ่นลานข้าว — ช้าลง
			effect_durations["slow_floor"] = 4.0
			AudioManager.play_sfx("skill_dust")
			emit_signal("prank_flash", Color(1.0, 0.9, 0.0, 0.25))  # 🟡 เหลือง
		"Lane Swap":
			lane = -1 if lane >= 0 else 1
			AudioManager.play_sfx("skill_use")
			emit_signal("prank_flash", Color(1.0, 0.9, 0.0, 0.25))  # 🟡 เหลือง
		"Boon Bang Fai":
			# บั้งไฟ — ล้มลงเหมือนชนสิ่งกีดขวาง
			AudioManager.play_sfx("skill_bang_fai")
			emit_signal("prank_flash", Color(1.0, 0.4, 0.0, 0.45))  # 🔴 แดงส้ม
			stun(1.5)
		"Screen Blur":
			# หมอกควัน — วงกลมเบลอขอบ (vignette ฝั่งผู้เล่นที่โดน)
			AudioManager.play_sfx("skill_wind")
			emit_signal("prank_flash", Color(0.0, 0.0, 0.1, 0.35))  # ⚫ flash เบา
			emit_signal("screen_blackout", 4.0)
		"Pull to Center":
			# ดึงกลาง
			lane = 0
			velocity.y = 5.0
			AudioManager.play_sfx("skill_use")
			emit_signal("prank_flash", Color(0.6, 0.0, 1.0, 0.30))  # 🟣 ม่วง
		"Knockback":
			global_position.z += 6.0
			velocity.y = 5.0
			AudioManager.play_sfx("skill_use")
			emit_signal("prank_flash", Color(0.6, 0.0, 1.0, 0.30))  # 🟣 ม่วง
		"Invert Controls":
			# กลับทาง
			effect_durations["invert_controls"] = 4.5
			AudioManager.play_sfx("skill_use")
			emit_signal("prank_flash", Color(1.0, 0.9, 0.0, 0.25))  # 🟡 เหลือง
		"Field Wind", "Wind Push":
			# ลมทุ่ง — ตัวสั่นแรง
			effect_durations["wind_push"] = 4.0
			AudioManager.play_sfx("skill_wind")
			emit_signal("prank_flash", Color(0.4, 0.9, 1.0, 0.30))  # 🔵 ฟ้าลม
			var tornado_res = load("res://assets/textures/brackeys_vfx_bundle/particles/hurricane/hurricane.tscn")
			if tornado_res:
				var tornado = tornado_res.instantiate()
				add_child(tornado)
				tornado.position = Vector3(0, 0.5, 0)
				tornado.scale = Vector3(4.0, 4.0, 4.0)
				if "visibility_aabb" in tornado:
					tornado.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
				# Auto free after 4.0s (duration of wind_push)
				var tw = tornado.create_tween()
				tw.tween_callback(tornado.queue_free).set_delay(4.0)
		_:
			AudioManager.play_sfx("skill_use")
			emit_signal("prank_flash", Color(0.6, 0.0, 1.0, 0.30))

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
		if !slide_file: slide_file = "res://assets/animation/Slide.glb"
	else:
		if !model_file: model_file = "res://assets/models/player/girlTmodel.glb"
		if !run_file: run_file = "res://assets/animation/Running.glb"
		if !jump_file: jump_file = "res://assets/animation/jump.glb"
		if !stun_file: stun_file = "res://assets/animation/Stun.glb"
		if !slide_file: slide_file = "res://assets/animation/Slide.glb"

		# 🧨 SAFETY CHECK ใส่ตรงนี้ ใส่เพิ่มมา
	if model_file and ResourceLoader.exists(model_file):
		print("MODEL OK:", model_file)
	else:
		push_error("Missing model file: " + str(model_file))
		return

func _import_anim(path: String, target_name: String):
	if !ResourceLoader.exists(path): 
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
			
			# Root Motion Removal
			if target_name == anim_jump or target_name == anim_buffalo_ride:
				var is_pos = p_lower.ends_with(":position") or p_lower.ends_with(":location")
				var is_rot = p_lower.ends_with(":rotation") or p_lower.ends_with(":quaternion")
				if is_pos or is_rot:
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
