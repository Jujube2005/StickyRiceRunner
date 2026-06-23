extends Control

@onready var p1_distance_bar = $TopLeft/DistanceMeter/TextureProgressBar  # kept hidden
@onready var p1_distance = $TopLeft/DistanceSign/Label
@onready var p1_leader_label = $TopLeft/LeaderLabel

@onready var p2_distance_bar = $TopRight/DistanceMeter/TextureProgressBar  # kept hidden
@onready var p2_distance = $TopRight/DistanceSign/Label
@onready var p2_leader_label = $TopRight/LeaderLabel

@onready var p1_rice_bar = $TopLeft/DistanceMeter/RiceSegmentBar
@onready var p2_rice_bar = $TopRight/DistanceMeter/RiceSegmentBar

@onready var silk_popup_anchor: Control = $SilkPopupAnchor


@onready var p1_warning = $TopLeft/WarningLabel
@onready var p2_warning = $TopRight/WarningLabel

@onready var p1_slot1_btn = $BottomControls/P1Skills/Slot1
@onready var p1_slot2_btn = $BottomControls/P1Skills/Slot2
@onready var p2_slot1_btn = $BottomControls/P2Skills/Slot1
@onready var p2_slot2_btn = $BottomControls/P2Skills/Slot2

var p1_kratip_label: Label = null
var p2_kratip_label: Label = null

var font_resource: Font = preload("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")

var player1 = null
var player2 = null
var game_manager = null

func _ready():
	# Configure emoji fallback font
	var emoji_font = SystemFont.new()
	emoji_font.font_names = PackedStringArray(["Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji", "Android Emoji", "Emoji"])
	if font_resource:
		font_resource.fallbacks.append(emoji_font)

	game_manager = get_tree().current_scene.find_child("GameManager", true, false)
	# Find players in the scene
	player1 = get_tree().current_scene.find_child("Player1", true, false)
	player2 = get_tree().current_scene.find_child("Player2", true, false)
	
	# Connect signals safely
	_safe_connect($CenterTop/PauseBtn, "pressed", _on_pause_pressed)
	_safe_connect($CenterTop/SettingsBtn, "pressed", _on_settings_pressed)
	
	# Setup slot buttons programmatically (add key and name labels)
	if p1_slot1_btn and !p1_slot1_btn.has_node("KeyLabel"): _setup_slot_button(p1_slot1_btn, "F")
	if p1_slot2_btn and !p1_slot2_btn.has_node("KeyLabel"): _setup_slot_button(p1_slot2_btn, "G")
	if p2_slot1_btn and !p2_slot1_btn.has_node("KeyLabel"): _setup_slot_button(p2_slot1_btn, "K")
	if p2_slot2_btn and !p2_slot2_btn.has_node("KeyLabel"): _setup_slot_button(p2_slot2_btn, "L")
	
	# Setup Hover Effects
	_setup_button_hover($CenterTop/PauseBtn)
	_setup_button_hover($CenterTop/SettingsBtn)
	_setup_button_hover(p1_slot1_btn)
	_setup_button_hover(p1_slot2_btn)
	_setup_button_hover(p2_slot1_btn)
	_setup_button_hover(p2_slot2_btn)
	
	# P1 Skills
	if p1_slot1_btn: _safe_connect(p1_slot1_btn, "pressed", _on_p1_slot1_pressed)
	if p1_slot2_btn: _safe_connect(p1_slot2_btn, "pressed", _on_p1_slot2_pressed)
	
	# P2 Skills
	if p2_slot1_btn: _safe_connect(p2_slot1_btn, "pressed", _on_p2_slot1_pressed)
	if p2_slot2_btn: _safe_connect(p2_slot2_btn, "pressed", _on_p2_slot2_pressed)
	
	# Connect warning signals
	if player1 and player1.has_signal("warning_changed"):
		if !player1.warning_changed.is_connected(_on_p1_warning_changed):
			player1.warning_changed.connect(_on_p1_warning_changed)
	
	if player2 and player2.has_signal("warning_changed"):
		if !player2.warning_changed.is_connected(_on_p2_warning_changed):
			player2.warning_changed.connect(_on_p2_warning_changed)
		
	# Connect skills changed signals
	if player1 and player1.has_signal("skills_changed"):
		if !player1.skills_changed.is_connected(_on_p1_skills_changed):
			player1.skills_changed.connect(_on_p1_skills_changed)
		
	if player2 and player2.has_signal("skills_changed"):
		if !player2.skills_changed.is_connected(_on_p2_skills_changed):
			player2.skills_changed.connect(_on_p2_skills_changed)
			
	# Connect kratip count signals — update label AND rice bar
	if player1 and player1.has_signal("kratip_count_changed"):
		player1.kratip_count_changed.connect(_on_p1_kratip_changed)
		player1.kratip_count_changed.connect(func(cur: int, _max: int): update_rice_bar(1, cur))
	if player2 and player2.has_signal("kratip_count_changed"):
		player2.kratip_count_changed.connect(_on_p2_kratip_changed)
		player2.kratip_count_changed.connect(func(cur: int, _max: int): update_rice_bar(2, cur))
	
	# Connect screen_blackout signal — only darken the hit player's half
	if player1 and player1.has_signal("screen_blackout"):
		if !player1.screen_blackout.is_connected(_on_p1_screen_blackout):
			player1.screen_blackout.connect(_on_p1_screen_blackout)
	if player2 and player2.has_signal("screen_blackout"):
		if !player2.screen_blackout.is_connected(_on_p2_screen_blackout):
			player2.screen_blackout.connect(_on_p2_screen_blackout)
	
	# Create Kratip Labels dynamically
	p1_kratip_label = _create_kratip_label($TopLeft/KratibIcon)
	p2_kratip_label = _create_kratip_label($TopRight/KratibIcon)
	
	# Initial setup
	if player1:
		update_slots_ui(player1, p1_slot1_btn, p1_slot2_btn, "F", "G")
		_on_p1_kratip_changed(0, 10)
		update_rice_bar(1, 0)
	if player2:
		update_slots_ui(player2, p2_slot1_btn, p2_slot2_btn, "K", "L")
		_on_p2_kratip_changed(0, 10)
		update_rice_bar(2, 0)
		
	# Hide leader indicators initially
	if p1_leader_label: p1_leader_label.visible = false
	if p2_leader_label: p2_leader_label.visible = false
	
	if game_manager and game_manager.has_signal("race_start_cooldown_changed"):
		_safe_connect(game_manager, "race_start_cooldown_changed", _on_race_start_cooldown_changed)

func _safe_connect(node: Node, sig_name: String, callable: Callable):
	if node and !node.is_connected(sig_name, callable):
		node.connect(sig_name, callable)

func show_countdown(count: int, on_done: Callable):
	"""แสดงนับถอยหลัง 3-2-1-GO! กลางจอระหว่างผู้เล่น 1 และ 2"""
	await get_tree().process_frame
	
	var cx = size.x / 2.0  # จุดกึ่งกลาง = แนวแบ่ง P1/P2
	var cy = size.y / 2.0
	var panel_w = 220.0
	var panel_h = 260.0
	
	# --- Panel พื้นหลังกลม ---
	var panel = ColorRect.new()
	panel.name = "CountdownPanel"
	panel.color = Color(0.05, 0.05, 0.1, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 200
	panel.size = Vector2(panel_w, panel_h)
	panel.position = Vector2(cx - panel_w / 2.0, cy - panel_h / 2.0)
	add_child(panel)
	
	# Fade panel เข้า
	var bg_tw = create_tween()
	bg_tw.tween_property(panel, "color:a", 0.82, 0.25)
	
	# --- Label ตัวเลข ---
	var lbl = Label.new()
	var ls = LabelSettings.new()
	ls.font_size = 180
	if font_resource: ls.font = font_resource
	ls.font_color = Color(1.0, 0.92, 0.3)
	ls.outline_size = 12
	ls.outline_color = Color(0.5, 0.15, 0.0)
	ls.shadow_size = 6
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	ls.shadow_offset = Vector2(3, 5)
	lbl.label_settings = ls
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(panel_w, panel_h)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	lbl.pivot_offset = Vector2(panel_w / 2.0, panel_h / 2.0)
	panel.add_child(lbl)
	
	# --- นับ 3, 2, 1 ---
	var numbers = [str(count), str(count - 1), str(count - 2)]
	var colors = [
		Color(1.0, 0.35, 0.25),  # 3 - แดงส้ม
		Color(1.0, 0.85, 0.1),   # 2 - ทอง
		Color(0.3, 1.0, 0.45),   # 1 - เขียว
	]
	
	for i in range(numbers.size()):
		lbl.text = numbers[i]
		ls.font_color = colors[i]
		lbl.scale = Vector2(2.2, 2.2)
		lbl.modulate.a = 0.0
		
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
		tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		
		await get_tree().create_timer(0.62).timeout
		
		var out_tw = create_tween()
		out_tw.tween_property(lbl, "modulate:a", 0.0, 0.18)
		await out_tw.finished
		await get_tree().create_timer(0.04).timeout
	
	# --- GO! ---
	lbl.text = "GO!"
	ls.font_color = Color(0.25, 1.0, 0.45)
	ls.font_size = 160
	lbl.scale = Vector2(0.4, 0.4)
	lbl.modulate.a = 0.0
	
	var go_tw = create_tween()
	go_tw.set_parallel(true)
	go_tw.tween_property(lbl, "modulate:a", 1.0, 0.1)
	go_tw.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await go_tw.finished
	
	# เรียก callback ให้เกมเริ่ม
	on_done.call()
	
	# Fade ออก
	await get_tree().create_timer(0.45).timeout
	var final_tw = create_tween()
	final_tw.set_parallel(true)
	final_tw.tween_property(lbl, "modulate:a", 0.0, 0.35)
	final_tw.tween_property(panel, "color:a", 0.0, 0.45)
	await final_tw.finished
	panel.queue_free()

func _on_race_start_cooldown_changed(remaining: float):
	var cd_label = get_node_or_null("CenterTop/CooldownLabel")
	
	if remaining <= 0:
		if cd_label:
			var tw = create_tween()
			tw.tween_property(cd_label, "modulate:a", 0.0, 0.3)
			tw.tween_callback(cd_label.queue_free)
		return
	
	if !cd_label:
		cd_label = Label.new()
		cd_label.name = "CooldownLabel"
		var ls = LabelSettings.new()
		ls.font_size = 48
		if font_resource: ls.font = font_resource
		ls.font_color = Color(1.0, 0.3, 0.3)
		ls.outline_size = 8
		ls.outline_color = Color.BLACK
		cd_label.label_settings = ls
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.position = Vector2(0, 100)
		cd_label.size = Vector2(size.x, 80)
		$CenterTop.add_child(cd_label)
	
	cd_label.text = "SKILLS READY IN " + str(ceil(remaining))

func _on_p1_screen_blackout(duration: float):
	_show_half_vignette(duration, false)  # false = left half (Player 1)

func _on_p2_screen_blackout(duration: float):
	_show_half_vignette(duration, true)   # true  = right half (Player 2)

func _show_half_vignette(duration: float, is_right_half: bool):
	"""Thick fog/clouds overlay on one player's half."""
	var overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	add_child(overlay)
	await get_tree().process_frame
	
	var half_w = size.x / 2.0
	overlay.size    = Vector2(half_w, size.y)
	overlay.position = Vector2(half_w if is_right_half else 0.0, 0.0)
	
	# Add smoke/cloud particles
	var offset_x = 350 if is_right_half else -350
	var particles = CPUParticles2D.new()
	particles.position = Vector2((half_w / 2.0) + offset_x, size.y)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(half_w / 2.0, 20)
	particles.direction = Vector2(0, -1)
	particles.spread = 20.0
	particles.gravity = Vector2(0, -150)
	particles.initial_velocity_min = 25.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.lifetime = 1.5
	particles.amount = 20
	particles.emitting = true
	
	var tex_path = "res://assets/textures/brackeys_vfx_bundle/particles/opague/smoke_04.png"
	if ResourceLoader.exists(tex_path):
		particles.texture = load(tex_path)
		var mat = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Use texture grayscale as alpha for soft cloud blending
	COLOR = vec4(COLOR.rgb, tex.r * COLOR.a);
}
"""
		mat.shader = shader
		particles.material = mat
		
	var gradient = Gradient.new()
	# Use add_point to create the gradient safely
	# default gradient has points at 0 and 1
	gradient.set_color(0, Color(0.8, 0.8, 0.85, 0.0))
	gradient.set_color(1, Color(0.8, 0.8, 0.85, 0.0))
	gradient.add_point(0.2, Color(0.85, 0.85, 0.9, 1.0))
	gradient.add_point(0.8, Color(0.85, 0.85, 0.9, 1.0))
	particles.color_ramp = gradient
	
	overlay.add_child(particles)
	
	# Stop emitting after duration, then queue_free after particles finish
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(particles):
			particles.emitting = false
			get_tree().create_timer(2.6).timeout.connect(overlay.queue_free)
	)

func show_skill_flash(is_right_half: bool, skill_color: Color):
	"""Brief half-screen color flash when a skill projectile hits the target player.
	Called by SkillProjectileManager._trigger_screen_flash()."""
	var overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 120
	add_child(overlay)
	
	# Wait one frame so the Control size is resolved
	await get_tree().process_frame
	
	var half_w = size.x / 2.0
	overlay.size     = Vector2(half_w, size.y)
	overlay.position = Vector2(half_w if is_right_half else 0.0, 0.0)
	# Start fully transparent
	overlay.color    = Color(skill_color.r, skill_color.g, skill_color.b, 0.0)
	
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.52, 0.06)   # sharp flash in
	tween.tween_property(overlay, "color:a", 0.0,  0.26)   # fade out
	tween.tween_callback(overlay.queue_free)

func _on_p1_warning_changed(msg):
	if p1_warning:
		p1_warning.text = msg
		p1_warning.visible = msg != ""

func _on_p2_warning_changed(msg):
	if p2_warning:
		p2_warning.text = msg
		p2_warning.visible = msg != ""
	
func _on_p1_skills_changed(_new_skills):
	update_slots_ui(player1, p1_slot1_btn, p1_slot2_btn, "F", "G")

func _on_p2_skills_changed(_new_skills):
	update_slots_ui(player2, p2_slot1_btn, p2_slot2_btn, "K", "L")

func _on_p1_kratip_changed(current: int, needed: int):
	if p1_kratip_label:
		p1_kratip_label.text = str(current) + "/" + str(needed)

func _on_p2_kratip_changed(current: int, needed: int):
	if p2_kratip_label:
		p2_kratip_label.text = str(current) + "/" + str(needed)

func _create_kratip_label(_parent_node: Control) -> Label:
	# User requested to remove kratip counting numbers
	return null
func show_silk_fly_in(player_name: String, silk_name: String, silk_tex_path: String, is_new: bool):
	# Start position = center of the player's own half-screen
	var half_w = size.x / 2.0
	var start_pos: Vector2
	if player_name == "Player1":
		start_pos = Vector2(half_w / 2.0, size.y / 2.0)        # center of left half
	else:
		start_pos = Vector2(half_w + half_w / 2.0, size.y / 2.0) # center of right half
	
	# Determine target pos based on player
	var target_pos = Vector2.ZERO
	if player_name == "Player1":
		if has_node("TopLeft/KratibIcon"):
			target_pos = $TopLeft/KratibIcon.global_position
		else:
			target_pos = Vector2(80, 80)
	else:
		if has_node("TopRight/KratibIcon"):
			target_pos = $TopRight/KratibIcon.global_position
		else:
			target_pos = Vector2(size.x - 80, 80)
	
	# ── Build popup: image on top, name below ──
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 6)
	
	# Silk texture image
	if silk_tex_path != "" and ResourceLoader.exists(silk_tex_path):
		var tex_rect = TextureRect.new()
		tex_rect.texture = load(silk_tex_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(120, 120)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(tex_rect)
	
	# Silk name label
	var silk_lbl = Label.new()
	silk_lbl.text = silk_name
	var ls = LabelSettings.new()
	ls.font_size = 36
	if font_resource: ls.font = font_resource
	ls.font_color = Color(0.95, 0.8, 1.0)
	ls.outline_size = 7
	ls.outline_color = Color.BLACK
	silk_lbl.label_settings = ls
	silk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(silk_lbl)
	
	add_child(container)
	
	# Wait 1 frame for Godot to calculate sizes
	await get_tree().process_frame
	
	# Center on anchor, animate from zero scale
	container.pivot_offset = container.size / 2.0
	container.global_position = start_pos - container.size / 2.0
	container.scale = Vector2.ZERO
	
	var tween = create_tween()
	# Pop in
	tween.tween_property(container, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.9) # Hold so player can read it
	
	# Fly to target kratip icon
	tween.tween_property(container, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(container, "scale", Vector2(0.25, 0.25), 0.5)
	
	# Cleanup + show unlock popup if brand new
	tween.tween_callback(func(): 
		container.queue_free()
		if is_new:
			show_silk_unlock(player_name, silk_name, silk_tex_path)
	)

func show_silk_unlock(player_name: String, silk_name: String, silk_tex_path: String = ""):
	var popup = VBoxContainer.new()
	popup.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_theme_constant_override("separation", 4)
	
	# Small thumbnail
	if silk_tex_path != "" and ResourceLoader.exists(silk_tex_path):
		var thumb = TextureRect.new()
		thumb.texture = load(silk_tex_path)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(72, 72)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		popup.add_child(thumb)
	
	# Unlock text
	var lbl = Label.new()
	lbl.text = LanguageManager.t("LBL_UNLOCK") + silk_name + "!"
	var ls = LabelSettings.new()
	ls.font_size = 26
	if font_resource: ls.font = font_resource
	ls.font_color = Color(0.95, 0.8, 1.0)
	ls.outline_size = 6
	ls.outline_color = Color.BLACK
	lbl.label_settings = ls
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_child(lbl)
	
	add_child(popup)
	
	# Wait 1 frame for size
	await get_tree().process_frame
	
	# Anchor at center of the player's own half-screen
	var half_w = size.x / 2.0
	var anchor_pos: Vector2
	if player_name == "Player1":
		anchor_pos = Vector2(half_w / 2.0, size.y / 2.0)
	else:
		anchor_pos = Vector2(half_w + half_w / 2.0, size.y / 2.0)
	
	popup.pivot_offset = popup.size / 2.0
	popup.global_position = anchor_pos - popup.size / 2.0
	popup.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(popup, "global_position:y", anchor_pos.y - popup.size.y / 2.0 - 30.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.2)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)

func _process(delta):
	if player1:
		p1_distance.text = str(int(player1.distance)) + "m"
		
	if player2:
		p2_distance.text = str(int(player2.distance)) + "m"
		
	# Compare distances and update LEADING indicators
	if player1 and player2:
		var p1_dist = player1.get("distance") if "distance" in player1 else 0.0
		var p2_dist = player2.get("distance") if "distance" in player2 else 0.0
		
		if p1_dist > p2_dist:
			if p1_leader_label: p1_leader_label.visible = true
			if p2_leader_label: p2_leader_label.visible = false
		elif p2_dist > p1_dist:
			if p1_leader_label: p1_leader_label.visible = false
			if p2_leader_label: p2_leader_label.visible = true
		else:
			if p1_leader_label: p1_leader_label.visible = false
			if p2_leader_label: p2_leader_label.visible = false
	else:
		if p1_leader_label: p1_leader_label.visible = false
		if p2_leader_label: p2_leader_label.visible = false

func update_rice_bar(player_num: int, count: int) -> void:
	## Called event-based via kratip_count_changed signal.
	## Updates only the affected player's RiceSegmentBar.
	if player_num == 1:
		if p1_rice_bar and p1_rice_bar.has_method("set_value"):
			p1_rice_bar.set_value(count)
	else:
		if p2_rice_bar and p2_rice_bar.has_method("set_value"):
			p2_rice_bar.set_value(count)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1:
				if player1: player1.add_kratip(1)
				if player2: player2.add_kratip(1)
				print("[DEBUG] 1: Add 1 Kratip to both players")
			KEY_2:
				if player1: player1.add_kratip(5)
				if player2: player2.add_kratip(5)
				print("[DEBUG] 2: Add 5 Kratips to both players")
			KEY_3:
				if player1: player1.debug_set_distance(player1.distance + 100)
				if player2: player2.debug_set_distance(player2.distance + 100)
				print("[DEBUG] 3: Skip 100m distance")
			KEY_4:
				if player1: player1.debug_set_distance(950)
				if player2: player2.debug_set_distance(950)
				print("[DEBUG] 4: Jump to 950m (Near Finish)")
			KEY_5:
				if player1 and player1.has_method("add_skill"):
					var scene = get_tree().current_scene
					var gm = scene.find_child("GameManager", true, false)
					var s1 = gm.get_random_skill() if gm else "Rice Yard Dust"
					var s2 = gm.get_random_skill() if gm else "Pha Khao Ma"
					player1.add_skill(s1)
					player1.add_skill(s2)
					print("[DEBUG] 5: Added random skills to Player 1: ", s1, ", ", s2)
			KEY_6:
				if player2 and player2.has_method("add_skill"):
					var scene = get_tree().current_scene
					var gm = scene.find_child("GameManager", true, false)
					var s1 = gm.get_random_skill() if gm else "Boon Bang Fai"
					var s2 = gm.get_random_skill() if gm else "Pha Khao Ma"
					player2.add_skill(s1)
					player2.add_skill(s2)
					print("[DEBUG] 6: Added random skills to Player 2: ", s1, ", ", s2)
			KEY_9:
				if player2:
					player2.is_bot = !player2.is_bot
					print("[DEBUG] 9: Player 2 Bot is now: ", player2.is_bot)

func _on_pause_pressed():
	var pause_panel = get_tree().current_scene.find_child("PausePanel", true, false)
	if pause_panel and pause_panel.has_method("show_pause"):
		get_tree().paused = true
		pause_panel.show_pause()
	else:
		get_tree().paused = !get_tree().paused

func _on_settings_pressed():
	# Prevent opening multiple times
	if get_tree().current_scene.find_child("SettingsPopup", true, false):
		return
	var settings_scene = preload("res://scenes/ui/settings_popup.tscn")
	var settings = settings_scene.instantiate()
	get_parent().add_child(settings)  # Add to UI CanvasLayer
	get_tree().paused = true

func _on_p1_slot1_pressed():
	if player1 and player1.has_method("use_skill_at_slot"):
		player1.use_skill_at_slot(0)

func _on_p1_slot2_pressed():
	if player1 and player1.has_method("use_skill_at_slot"):
		player1.use_skill_at_slot(1)

func _on_p2_slot1_pressed():
	if player2 and player2.has_method("use_skill_at_slot"):
		player2.use_skill_at_slot(0)

func _on_p2_slot2_pressed():
	if player2 and player2.has_method("use_skill_at_slot"):
		player2.use_skill_at_slot(1)

# --- Slot UI Helpers ---

func _setup_button_hover(btn: BaseButton):
	if !btn: return
	get_tree().process_frame.connect(func(): btn.pivot_offset = btn.size / 2.0, CONNECT_ONE_SHOT)
	var orig_scale = btn.scale
	var hover_scale = orig_scale * 1.15
	btn.mouse_entered.connect(func():
		if btn.disabled: return
		var tw = create_tween()
		tw.tween_property(btn, "scale", hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", orig_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _setup_slot_button(btn: TextureButton, key_text: String):
	if !btn: return
	
	# Key Label
	var key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = "[" + key_text + "]"
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 14
	if font_resource:
		label_settings.font = font_resource
	label_settings.font_color = Color(1.0, 0.9, 0.3) # Gold key text
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	
	key_label.label_settings = label_settings
	key_label.position = Vector2(8, 6)
	btn.add_child(key_label)
	
	# Skill Icon (inside the frame)
	var icon = TextureRect.new()
	icon.name = "SkillIcon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Padding so it sits inside the button frame
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	btn.move_child(icon, 0)
	icon.visible = false
	
	# Name Label (Skill Name)
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = ""
	
	var name_settings = LabelSettings.new()
	name_settings.font_size = 12
	if font_resource:
		name_settings.font = font_resource
	name_settings.font_color = Color.WHITE
	name_settings.outline_size = 4
	name_settings.outline_color = Color.BLACK
	
	name_label.label_settings = name_settings
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -26
	name_label.offset_bottom = -2
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(name_label)
	name_label.visible = false

func update_slots_ui(player, slot1_btn, slot2_btn, _key1_text, _key2_text):
	if !player or !slot1_btn or !slot2_btn: return
	
	var skills_list = player.skills if "skills" in player else []
	
	# Update Slot 1
	var s1_active = skills_list.size() > 0 and skills_list[0] != ""
	if s1_active:
		var skill_name = skills_list[0]
		slot1_btn.disabled = false
		slot1_btn.modulate = Color(1.2, 1.2, 1.2, 1.0) # สว่างขึ้น (เรืองแสง)
		slot1_btn.self_modulate = get_skill_color(skill_name) * 1.5
		
		var icon_path = _get_skill_icon_path(skill_name)
		var custom_tex = _load_texture_safe(icon_path, "")
		var icon_node = slot1_btn.get_node_or_null("SkillIcon")
		
		if icon_node:
			if custom_tex != null:
				icon_node.texture = custom_tex
				icon_node.visible = true
				icon_node.modulate = Color(1.1, 1.1, 1.1) # ให้ไอคอนสว่างด้วย
			else:
				icon_node.visible = false
		
		var label = slot1_btn.get_node_or_null("NameLabel")
		if label:
			label.text = get_skill_display_name(skill_name)
			label.visible = true
	else:
		slot1_btn.disabled = true
		slot1_btn.modulate = Color(0.3, 0.3, 0.3, 0.6)
		slot1_btn.self_modulate = Color.WHITE
		var icon_node = slot1_btn.get_node_or_null("SkillIcon")
		if icon_node: icon_node.visible = false
		var label = slot1_btn.get_node_or_null("NameLabel")
		if label:
			label.text = ""
			label.visible = false
		
	# Update Slot 2
	var s2_active = skills_list.size() > 1 and skills_list[1] != ""
	if s2_active:
		var skill_name = skills_list[1]
		slot2_btn.disabled = false
		slot2_btn.modulate = Color(1.2, 1.2, 1.2, 1.0) # สว่างขึ้น
		slot2_btn.self_modulate = get_skill_color(skill_name) * 1.5
		
		var icon_path = _get_skill_icon_path(skill_name)
		var custom_tex = _load_texture_safe(icon_path, "")
		var icon_node = slot2_btn.get_node_or_null("SkillIcon")
		
		if icon_node:
			if custom_tex != null:
				icon_node.texture = custom_tex
				icon_node.visible = true
				icon_node.modulate = Color(1.1, 1.1, 1.1)
			else:
				icon_node.visible = false
		
		var label = slot2_btn.get_node_or_null("NameLabel")
		if label:
			label.text = get_skill_display_name(skill_name)
			label.visible = true
	else:
		slot2_btn.disabled = true
		slot2_btn.modulate = Color(0.3, 0.3, 0.3, 0.6)
		slot2_btn.self_modulate = Color.WHITE
		var icon_node = slot2_btn.get_node_or_null("SkillIcon")
		if icon_node: icon_node.visible = false
		var label = slot2_btn.get_node_or_null("NameLabel")
		if label:
			label.text = ""
			label.visible = false

func get_skill_color(skill_name: String) -> Color:
	match skill_name:
		"Rice Yard Dust":
			return Color(0.8, 0.5, 0.1)  # สีส้ม — ฝุ่นดิน
		"Boon Bang Fai":
			return Color(1.0, 0.3, 0.0)  # แดงส้ม — บั้งไฟ
		"Lane Swap":
			return Color(0.8, 0.2, 0.9)  # ม่วง — สลับเลน
		"Screen Blur":
			return Color(0.4, 0.4, 0.4)  # เทา — หมอกควัน
		"Pull to Center":
			return Color(1.0, 0.4, 0.7)  # ชมพู — ดึงกลาง
		"Lane Block":
			return Color(1.0, 0.8, 0.0)  # ทอง — กีดขวาง
		"Field Wind", "Wind Push":
			return Color(0.3, 0.8, 0.2)  # เขียว — ลมทุ่ง
		"Pha Khao Ma":
			return Color(0.9, 0.7, 0.1)  # ทองลาย — ผ้าขาวม้า
		_:
			return Color.WHITE

func get_skill_display_name(skill_name: String) -> String:
	return LanguageManager.skill_name(skill_name)

func _get_skill_icon_path(skill_name: String) -> String:
	var safe_name = skill_name.to_lower().replace(" ", "_")
	return "res://assets/textures/UI/Skills/skill_" + safe_name + ".png"

func _load_texture_safe(path: String, fallback_path: String = "") -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			return tex
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		var fall = load(fallback_path)
		if fall:
			return fall
	return null
