extends Control

@export var player: Node
@onready var score_label = $ScoreLabel
@onready var distance_label = $DistanceLabel
@onready var charge_label = $ChargeLabel
@onready var warning_label = $WarningLabel
@onready var skill_button = $SkillButton
@onready var defend_button = $DefendButton

var flash_rect: ColorRect
var charge_bar_container: HBoxContainer
var charge_segments: Array[ColorRect] = []
var hud_panel: PanelContainer
var warning_node: Control
var warning_label_large: Label
var debug_panel: PanelContainer

func _ready():
	# Hide old basic labels
	score_label.visible = false
	distance_label.visible = false
	charge_label.visible = false
	warning_label.visible = false
	
	# Create Modern HUD
	_setup_modern_hud()
	_setup_warning_system()
	
	player.score_changed.connect(update_score)
	player.distance_changed.connect(update_distance)
	player.charge_changed.connect(update_charge)
	player.warning_changed.connect(update_warning)
	skill_button.pressed.connect(_on_skill_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	update_score(player.score)
	update_distance(player.distance)
	update_charge(player.charges, player.MAX_CHARGES)
	
	# Hide manual buttons
	skill_button.visible = false
	defend_button.visible = false
	
	# Create flash effect rect
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	
	# Styled Bot Toggle Button in a Debug Panel
	_setup_debug_menu()

func _input(event):
	var pressed_debug_action = InputMap.has_action("ui_f3") and event.is_action_pressed("ui_f3")
	var pressed_f3_key = event is InputEventKey and event.keycode == KEY_F3 and event.pressed
	if pressed_debug_action or pressed_f3_key:
		if debug_panel:
			debug_panel.visible = !debug_panel.visible

func _setup_modern_hud():
	# Main Container for HUD (Anchored to Right)
	hud_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(15)
	hud_panel.add_theme_stylebox_override("panel", style)
	
	# Set anchors to top-right
	hud_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_panel.offset_left = -270
	hud_panel.offset_top = 20
	hud_panel.offset_right = -20
	hud_panel.offset_bottom = 140
	add_child(hud_panel)
	
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	hud_panel.add_child(v_box)
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 22
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	
	# Score (Right Aligned)
	var score_h_box = HBoxContainer.new()
	score_h_box.alignment = BoxContainer.ALIGNMENT_END
	v_box.add_child(score_h_box)
	
	score_label = Label.new()
	score_label.label_settings = label_settings
	score_h_box.add_child(score_label)
	
	var s_icon = Label.new()
	s_icon.text = " 🏆"
	s_icon.label_settings = label_settings
	score_h_box.add_child(s_icon)
	
	# Distance (Right Aligned)
	var dist_h_box = HBoxContainer.new()
	dist_h_box.alignment = BoxContainer.ALIGNMENT_END
	v_box.add_child(dist_h_box)
	
	distance_label = Label.new()
	var dist_settings = label_settings.duplicate()
	dist_settings.font_size = 18
	distance_label.label_settings = dist_settings
	dist_h_box.add_child(distance_label)
	
	var d_icon = Label.new()
	d_icon.text = " 🏃"
	d_icon.label_settings = label_settings
	dist_h_box.add_child(d_icon)
	
	# Segmented Charge Bar
	var charge_v_box = VBoxContainer.new()
	v_box.add_child(charge_v_box)
	
	var c_label = Label.new()
	c_label.text = "ENERGY / KRATIP"
	c_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var c_settings = label_settings.duplicate()
	c_settings.font_size = 12
	c_label.label_settings = c_settings
	charge_v_box.add_child(c_label)
	
	charge_bar_container = HBoxContainer.new()
	charge_bar_container.alignment = BoxContainer.ALIGNMENT_END
	charge_bar_container.custom_minimum_size.y = 15
	charge_bar_container.add_theme_constant_override("separation", 4)
	charge_v_box.add_child(charge_bar_container)
	
	for i in range(5):
		var segment = ColorRect.new()
		segment.custom_minimum_size = Vector2(44, 12)
		segment.color = Color(0.2, 0.2, 0.2, 0.8)
		charge_bar_container.add_child(segment)
		charge_segments.append(segment)

func _setup_warning_system():
	warning_node = Control.new()
	warning_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning_node.anchor_left = 0.5
	warning_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_node.z_index = 20
	get_parent().call_deferred("add_child", warning_node)
	
	warning_label_large = Label.new()
	var w_settings = LabelSettings.new()
	w_settings.font_size = 22 # Smaller size
	w_settings.font_color = Color.RED
	w_settings.outline_size = 6
	w_settings.outline_color = Color.BLACK
	warning_label_large.label_settings = w_settings
	warning_label_large.set_anchors_preset(Control.PRESET_CENTER)
	warning_label_large.offset_left = -220
	warning_label_large.offset_top = -120
	warning_label_large.offset_right = 220
	warning_label_large.offset_bottom = -20
	warning_label_large.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label_large.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label_large.text = ""
	warning_label_large.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warning_label_large.grow_vertical = Control.GROW_DIRECTION_BOTH
	warning_node.add_child(warning_label_large)
	warning_node.visible = false

func _setup_debug_menu():
	debug_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	debug_panel.add_theme_stylebox_override("panel", style)
	
	debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.offset_left = -160
	debug_panel.offset_top = 220
	debug_panel.offset_right = -20
	debug_panel.offset_bottom = 280
	add_child(debug_panel)
	
	var v_box = VBoxContainer.new()
	debug_panel.add_child(v_box)
	
	var d_title = Label.new()
	d_title.text = "DEBUG (F3)"
	d_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box.add_child(d_title)
	
	var bot_btn = Button.new()
	bot_btn.text = "Enable Bot"
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.6, 0.3)
	bot_btn.add_theme_stylebox_override("normal", btn_style)
	v_box.add_child(bot_btn)
	
	bot_btn.pressed.connect(func():
		player.is_bot = !player.is_bot
		bot_btn.text = "Disable Bot" if player.is_bot else "Enable Bot"
		btn_style.bg_color = Color(0.8, 0.2, 0.2) if player.is_bot else Color(0.1, 0.6, 0.3)
	)
	
	# Hide by default in build (optional, but here we just hide initially for clean UI)
	debug_panel.visible = false

func update_score(value):
	score_label.text = "P2: " + str(value)
	var tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1)

func update_distance(value):
	distance_label.text = str(value) + " / 1000 m"

func update_charge(current, max_val):
	# Update segments (Right to left logic: segments[4] is far left, segments[0] is far right? 
	# No, HBox adds left to right. For P2 UI, let's fill from right to left for consistency with fill_mode)
	for i in range(charge_segments.size()):
		var idx = (charge_segments.size() - 1) - i # Reverse index
		var segment = charge_segments[idx]
		if i < current:
			segment.color = Color(1.0, 0.8, 0.2)
		else:
			segment.color = Color(0.2, 0.2, 0.2, 0.8)
	
	if current >= max_val:
		_pulse_charge_segments()

func _pulse_charge_segments():
	var tween = create_tween().set_loops(3)
	for segment in charge_segments:
		tween.parallel().tween_property(segment, "modulate", Color(2, 2, 2), 0.2)
	for segment in charge_segments:
		tween.parallel().tween_property(segment, "modulate", Color(1, 1, 1), 0.2)

func update_warning(text):
	if text == "":
		warning_node.visible = false
		return
		
	warning_label_large.text = text
	warning_node.visible = true
	
	# Scale animation
	warning_label_large.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(warning_label_large, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
	
	if text.ends_with(" incoming!"):
		warning_label_large.label_settings.font_color = Color.RED
		warning_label_large.text = "⚠️ WARNING ⚠️\n" + text.to_upper()
		_pulse_warning()
		_flash_screen(Color(1, 0, 0, 0.3))
	elif text == "Prank blocked!":
		warning_label_large.label_settings.font_color = Color.GREEN
		_flash_screen(Color(0, 1, 0, 0.3))
	else:
		warning_label_large.label_settings.font_color = Color.YELLOW
		_flash_screen(Color(1, 0, 0, 0.4))

func _pulse_warning():
	var tween = create_tween().set_loops(4)
	tween.tween_property(warning_label_large, "modulate:a", 0.3, 0.15)
	tween.tween_property(warning_label_large, "modulate:a", 1.0, 0.15)

func _flash_screen(color):
	if flash_rect:
		flash_rect.color = color
		var tween = create_tween()
		tween.tween_property(flash_rect, "color:a", 0, 0.5)

func _on_skill_pressed():
	player.request_skill()

func _on_defend_pressed():
	player.try_defend()
