extends Control

@onready var p1_distance_bar = $TopLeft/DistanceMeter/TextureProgressBar
@onready var p1_distance = $TopLeft/DistanceSign/Label
@onready var p1_leader_label = $TopLeft/LeaderLabel

@onready var p2_distance_bar = $TopRight/DistanceMeter/TextureProgressBar
@onready var p2_distance = $TopRight/DistanceSign/Label
@onready var p2_leader_label = $TopRight/LeaderLabel

var p1_current_percent: float = 0.0
var p2_current_percent: float = 0.0


@onready var p1_warning = $TopLeft/WarningLabel
@onready var p2_warning = $TopRight/WarningLabel

@onready var p1_slot1_btn = $BottomControls/P1Skills/Slot1
@onready var p1_slot2_btn = $BottomControls/P1Skills/Slot2
@onready var p2_slot1_btn = $BottomControls/P2Skills/Slot1
@onready var p2_slot2_btn = $BottomControls/P2Skills/Slot2

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
	
	# Initial setup
	if player1:
		update_slots_ui(player1, p1_slot1_btn, p1_slot2_btn, "F", "G")
	if player2:
		update_slots_ui(player2, p2_slot1_btn, p2_slot2_btn, "K", "L")
		
	# Hide leader indicators initially
	if p1_leader_label: p1_leader_label.visible = false
	if p2_leader_label: p2_leader_label.visible = false

func _safe_connect(node: Node, sig_name: String, callable: Callable):
	if node and !node.is_connected(sig_name, callable):
		node.connect(sig_name, callable)

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

func _process(delta):
	var goal_dist = 1000.0
	if game_manager:
		goal_dist = float(game_manager.get("GOAL_DISTANCE"))
		
	var p1_target_percent = 0.0
	var p2_target_percent = 0.0
	
	# Update P1 Data
	if player1:
		var p1_dist = player1.get("distance") if "distance" in player1 else 0.0
		p1_target_percent = clamp((p1_dist / goal_dist) * 100.0, 0.0, 100.0)
		p1_distance.text = "%dm / %dm" % [int(p1_dist), int(goal_dist)]
	
	# Update P2 Data
	if player2:
		var p2_dist = player2.get("distance") if "distance" in player2 else 0.0
		p2_target_percent = clamp((p2_dist / goal_dist) * 100.0, 0.0, 100.0)
		p2_distance.text = "%dm / %dm" % [int(p2_dist), int(goal_dist)]
		
	# Smoothly interpolate progress bar values
	p1_current_percent = lerp(p1_current_percent, p1_target_percent, 5.0 * delta)
	p2_current_percent = lerp(p2_current_percent, p2_target_percent, 5.0 * delta)
	
	if p1_distance_bar:
		p1_distance_bar.value = p1_current_percent
	if p2_distance_bar:
		p2_distance_bar.value = p2_current_percent
		
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

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				if player1: player1.debug_add_charge(1)
				if player2: player2.debug_add_charge(1)
				print("[DEBUG] F1: Add 1 Charge to both players")
			KEY_F2:
				if player1: player1.debug_add_charge(5)
				if player2: player2.debug_add_charge(5)
				print("[DEBUG] F2: Add 5 Charges to both players")
			KEY_F3:
				if player1: player1.debug_set_distance(player1.distance + 100)
				if player2: player2.debug_set_distance(player2.distance + 100)
				print("[DEBUG] F3: Skip 100m distance")
			KEY_F4:
				if player1: player1.debug_set_distance(950)
				if player2: player2.debug_set_distance(950)
				print("[DEBUG] F4: Jump to 950m (Near Finish)")
			KEY_F5:
				if player1 and player1.has_method("add_skill"):
					var scene = get_tree().current_scene
					var gm = scene.find_child("GameManager", true, false)
					var s1 = gm.get_random_skill() if gm else "Slow Floor"
					var s2 = gm.get_random_skill() if gm else "Shield"
					player1.add_skill(s1)
					player1.add_skill(s2)
					print("[DEBUG] F5: Added random skills to Player 1: ", s1, ", ", s2)
			KEY_F6:
				if player2 and player2.has_method("add_skill"):
					var scene = get_tree().current_scene
					var gm = scene.find_child("GameManager", true, false)
					var s1 = gm.get_random_skill() if gm else "Lane Swap"
					var s2 = gm.get_random_skill() if gm else "Shield"
					player2.add_skill(s1)
					player2.add_skill(s2)
					print("[DEBUG] F6: Added random skills to Player 2: ", s1, ", ", s2)

func _on_pause_pressed():
	get_tree().paused = !get_tree().paused

func _on_settings_pressed():
	pass

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
		slot1_btn.modulate = Color.WHITE
		if skill_name == "Shield":
			slot1_btn.texture_normal = preload("res://assets/textures/UI/Buttons/skill_shield.png")
			slot1_btn.self_modulate = Color(0.2, 0.9, 0.4) # green-ish
		else:
			slot1_btn.texture_normal = preload("res://assets/textures/UI/Buttons/skill_bangfai.png")
			slot1_btn.self_modulate = get_skill_color(skill_name)
		
		var label = slot1_btn.get_node("NameLabel")
		label.text = get_skill_display_name(skill_name)
		label.visible = true
	else:
		slot1_btn.disabled = true
		slot1_btn.modulate = Color(0.3, 0.3, 0.3, 0.6) # dimmed
		slot1_btn.self_modulate = Color.WHITE
		slot1_btn.texture_normal = preload("res://assets/textures/UI/Buttons/skill_bangfai.png")
		var label = slot1_btn.get_node("NameLabel")
		label.text = ""
		label.visible = false
		
	# Update Slot 2
	var s2_active = skills_list.size() > 1 and skills_list[1] != ""
	if s2_active:
		var skill_name = skills_list[1]
		slot2_btn.disabled = false
		slot2_btn.modulate = Color.WHITE
		if skill_name == "Shield":
			slot2_btn.texture_normal = preload("res://assets/textures/UI/Buttons/skill_shield.png")
			slot2_btn.self_modulate = Color(0.2, 0.9, 0.4) # green-ish
		else:
			slot2_btn.texture_normal = preload("res://assets/textures/UI/Buttons/skill_bangfai.png")
			slot2_btn.self_modulate = get_skill_color(skill_name)
		
		var label = slot2_btn.get_node("NameLabel")
		label.text = get_skill_display_name(skill_name)
		label.visible = true
	else:
		slot2_btn.disabled = true
		slot2_btn.modulate = Color(0.3, 0.3, 0.3, 0.6) # dimmed
		slot2_btn.self_modulate = Color.WHITE
		slot2_btn.texture_normal = preload("res://assets/textures/UI/Buttons/skill_shield.png")
		var label = slot2_btn.get_node("NameLabel")
		label.text = ""
		label.visible = false

func get_skill_color(skill_name: String) -> Color:
	match skill_name:
		"Slow Floor":
			return Color(0.1, 0.5, 1.0) # Blue
		"Lane Swap":
			return Color(0.8, 0.2, 0.9) # Purple
		"Slow Speed":
			return Color(0.0, 0.9, 1.0) # Cyan
		"Screen Blur":
			return Color(0.4, 0.4, 0.4) # Dark Gray
		"Pull to Center":
			return Color(1.0, 0.4, 0.7) # Pink
		"Invert Controls":
			return Color(1.0, 0.1, 0.1) # Red
		"Lane Block":
			return Color(1.0, 0.8, 0.0) # Gold/Yellow
		"Wind Push":
			return Color(0.8, 0.8, 0.9) # Ice/Wind Gray
		"Transformation Debuff":
			return Color(1.0, 0.5, 0.0) # Orange
		_:
			return Color.WHITE

func get_skill_display_name(skill_name: String) -> String:
	match skill_name:
		"Slow Floor": return "Slow"
		"Lane Swap": return "Swap"
		"Slow Speed": return "Stumble"
		"Screen Blur": return "Blur"
		"Pull to Center": return "Pull"
		"Invert Controls": return "Invert"
		"Lane Block": return "Block"
		"Wind Push": return "Wind"
		"Transformation Debuff": return "Morph"
		"Shield": return "Shield"
		_: return skill_name
