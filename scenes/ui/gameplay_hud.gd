extends Control

@onready var p1_distance_bar = $TopLeft/DistanceMeter/TextureProgressBar
@onready var p1_distance = $TopLeft/DistanceSign/Label
@onready var p1_leader_label = $TopLeft/LeaderLabel

@onready var p2_distance_bar = $TopRight/DistanceMeter/TextureProgressBar
@onready var p2_distance = $TopRight/DistanceSign/Label
@onready var p2_leader_label = $TopRight/LeaderLabel

@onready var coin_popup_anchor: Control = $CoinPopupAnchor

var p1_current_percent: float = 0.0
var p2_current_percent: float = 0.0


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
			
	# Connect kratip count signals
	if player1 and player1.has_signal("kratip_count_changed"):
		player1.kratip_count_changed.connect(_on_p1_kratip_changed)
	if player2 and player2.has_signal("kratip_count_changed"):
		player2.kratip_count_changed.connect(_on_p2_kratip_changed)
	
	# Create Kratip Labels dynamically
	p1_kratip_label = _create_kratip_label($TopLeft/KratibIcon)
	p2_kratip_label = _create_kratip_label($TopRight/KratibIcon)
	
	# Initial setup
	if player1:
		update_slots_ui(player1, p1_slot1_btn, p1_slot2_btn, "F", "G")
		_on_p1_kratip_changed(0, 10)
	if player2:
		update_slots_ui(player2, p2_slot1_btn, p2_slot2_btn, "K", "L")
		_on_p2_kratip_changed(0, 10)
		
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

func _on_p1_kratip_changed(current: int, needed: int):
	if p1_kratip_label:
		p1_kratip_label.text = str(current) + "/" + str(needed)

func _on_p2_kratip_changed(current: int, needed: int):
	if p2_kratip_label:
		p2_kratip_label.text = str(current) + "/" + str(needed)

func _create_kratip_label(parent_node: Control) -> Label:
	if !parent_node: return null
	var lbl = Label.new()
	lbl.name = "CountLabel"
	
	var ls = LabelSettings.new()
	ls.font_size = 20
	if font_resource: ls.font = font_resource
	ls.font_color = Color.WHITE
	ls.outline_size = 4
	ls.outline_color = Color.BLACK
	lbl.label_settings = ls
	
	# Position to the right of the kratip icon
	lbl.position = Vector2(parent_node.size.x + 5, parent_node.size.y / 2.0 - 15)
	parent_node.add_child(lbl)
	return lbl

func show_coin_fly_in(player_name: String, coin_name: String, is_new: bool):
	# Use anchor node position set in .tscn editor
	var start_pos: Vector2
	if coin_popup_anchor:
		start_pos = coin_popup_anchor.global_position
	else:
		start_pos = Vector2(size.x / 2.0, size.y / 2.0)
	
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
		
	# Create cinematic coin label
	var coin_lbl = Label.new()
	coin_lbl.text = "🪙 " + coin_name
	var ls = LabelSettings.new()
	ls.font_size = 40
	if font_resource: ls.font = font_resource
	ls.font_color = Color(1.0, 0.8, 0.1)
	ls.outline_size = 8
	ls.outline_color = Color.BLACK
	coin_lbl.label_settings = ls
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(coin_lbl)
	
	# Wait 1 frame for Godot to calculate label size
	await get_tree().process_frame
	
	# Position centered on the anchor using pivot
	coin_lbl.pivot_offset = coin_lbl.size / 2.0
	coin_lbl.global_position = start_pos - coin_lbl.size / 2.0
	coin_lbl.scale = Vector2.ZERO
	
	var tween = create_tween()
	# Pop in center
	tween.tween_property(coin_lbl, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.8) # Wait to let player see it
	
	# Fly to target
	tween.tween_property(coin_lbl, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(coin_lbl, "scale", Vector2(0.3, 0.3), 0.5)
	
	# Trigger unlock popup if new, and delete the fly-in label
	tween.tween_callback(func(): 
		coin_lbl.queue_free()
		if is_new:
			show_coin_unlock(coin_name)
	)

func show_coin_unlock(coin_name: String):
	var popup = Label.new()
	popup.text = "🎉 ปลดล็อก: " + coin_name + "!"
	var ls = LabelSettings.new()
	ls.font_size = 28
	if font_resource: ls.font = font_resource
	ls.font_color = Color(1.0, 0.8, 0.1)
	ls.outline_size = 6
	ls.outline_color = Color.BLACK
	popup.label_settings = ls
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(popup)
	
	# Wait 1 frame for label size
	await get_tree().process_frame
	
	# Use anchor node for position if available
	var anchor_pos: Vector2
	if coin_popup_anchor:
		anchor_pos = coin_popup_anchor.global_position
	else:
		anchor_pos = Vector2(size.x / 2.0, 120)
	
	popup.pivot_offset = popup.size / 2.0
	popup.global_position = anchor_pos - popup.size / 2.0
	
	var tween = create_tween()
	tween.tween_property(popup, "global_position:y", anchor_pos.y - popup.size.y / 2.0 - 40.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)

func _process(delta):
	var p1_target_percent = 0.0
	var p2_target_percent = 0.0
	
	if player1:
		p1_distance.text = str(int(player1.distance)) + "m"
		p1_target_percent = (player1.kratip_milestone_count / 10.0) * 100.0
		
	if player2:
		p2_distance.text = str(int(player2.distance)) + "m"
		p2_target_percent = (player2.kratip_milestone_count / 10.0) * 100.0
		
	p1_current_percent = lerp(p1_current_percent, p1_target_percent, 10.0 * delta)
	p2_current_percent = lerp(p2_current_percent, p2_target_percent, 10.0 * delta)
	
	if p1_distance_bar: p1_distance_bar.value = p1_current_percent
	if p2_distance_bar: p2_distance_bar.value = p2_current_percent
		
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
					var s1 = gm.get_random_skill() if gm else "Rice Yard Dust"
					var s2 = gm.get_random_skill() if gm else "Pha Khao Ma"
					player1.add_skill(s1)
					player1.add_skill(s2)
					print("[DEBUG] F5: Added random skills to Player 1: ", s1, ", ", s2)
			KEY_F6:
				if player2 and player2.has_method("add_skill"):
					var scene = get_tree().current_scene
					var gm = scene.find_child("GameManager", true, false)
					var s1 = gm.get_random_skill() if gm else "Boon Bang Fai"
					var s2 = gm.get_random_skill() if gm else "Pha Khao Ma"
					player2.add_skill(s1)
					player2.add_skill(s2)
					print("[DEBUG] F6: Added random skills to Player 2: ", s1, ", ", s2)

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
		slot1_btn.modulate = Color.WHITE
		
		var icon_path = _get_skill_icon_path(skill_name)
		var custom_tex = _load_texture_safe(icon_path, "")
		var icon_node = slot1_btn.get_node_or_null("SkillIcon")
		
		if skill_name == "Pha Khao Ma":
			slot1_btn.texture_normal = _load_texture_safe("res://assets/textures/UI/Buttons/skill_shield.png")
			slot1_btn.self_modulate = Color(0.9, 0.7, 0.1) if custom_tex == null else Color.WHITE
		else:
			slot1_btn.texture_normal = _load_texture_safe("res://assets/textures/UI/Buttons/skill_bangfai.png")
			slot1_btn.self_modulate = get_skill_color(skill_name) if custom_tex == null else Color.WHITE
			
		if icon_node:
			if custom_tex != null:
				icon_node.texture = custom_tex
				icon_node.visible = true
			else:
				icon_node.visible = false
		
		var label = slot1_btn.get_node("NameLabel")
		label.text = get_skill_display_name(skill_name)
		label.visible = true
	else:
		slot1_btn.disabled = true
		slot1_btn.modulate = Color(0.3, 0.3, 0.3, 0.6) # dimmed
		slot1_btn.self_modulate = Color.WHITE
		slot1_btn.texture_normal = _load_texture_safe("res://assets/textures/UI/Buttons/skill_bangfai.png")
		var icon_node = slot1_btn.get_node_or_null("SkillIcon")
		if icon_node: icon_node.visible = false
		var label = slot1_btn.get_node("NameLabel")
		label.text = ""
		label.visible = false
		
	# Update Slot 2
	var s2_active = skills_list.size() > 1 and skills_list[1] != ""
	if s2_active:
		var skill_name = skills_list[1]
		slot2_btn.disabled = false
		slot2_btn.modulate = Color.WHITE
		
		var icon_path = _get_skill_icon_path(skill_name)
		var custom_tex = _load_texture_safe(icon_path, "")
		var icon_node = slot2_btn.get_node_or_null("SkillIcon")
		
		if skill_name == "Pha Khao Ma":
			slot2_btn.texture_normal = _load_texture_safe("res://assets/textures/UI/Buttons/skill_shield.png")
			slot2_btn.self_modulate = Color(0.9, 0.7, 0.1) if custom_tex == null else Color.WHITE
		else:
			slot2_btn.texture_normal = _load_texture_safe("res://assets/textures/UI/Buttons/skill_bangfai.png")
			slot2_btn.self_modulate = get_skill_color(skill_name) if custom_tex == null else Color.WHITE
			
		if icon_node:
			if custom_tex != null:
				icon_node.texture = custom_tex
				icon_node.visible = true
			else:
				icon_node.visible = false
		
		var label = slot2_btn.get_node("NameLabel")
		label.text = get_skill_display_name(skill_name)
		label.visible = true
	else:
		slot2_btn.disabled = true
		slot2_btn.modulate = Color(0.3, 0.3, 0.3, 0.6) # dimmed
		slot2_btn.self_modulate = Color.WHITE
		slot2_btn.texture_normal = _load_texture_safe("res://assets/textures/UI/Buttons/skill_shield.png")
		var icon_node = slot2_btn.get_node_or_null("SkillIcon")
		if icon_node: icon_node.visible = false
		var label = slot2_btn.get_node("NameLabel")
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

func _load_texture_safe(path: String, fallback_path: String = "res://assets/textures/UI/Buttons/box_orange.png") -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			return tex
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		var fall = load(fallback_path)
		if fall:
			return fall
	return null
