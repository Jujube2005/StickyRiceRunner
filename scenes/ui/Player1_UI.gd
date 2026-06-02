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

func _setup_modern_hud():
	# Main Container for HUD
	hud_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4) # Semi-transparent black
	style.set_corner_radius_all(10)
	style.set_content_margin_all(15)
	hud_panel.add_theme_stylebox_override("panel", style)
	hud_panel.position = Vector2(20, 20)
	hud_panel.size = Vector2(250, 120)
	add_child(hud_panel)
	
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	hud_panel.add_child(v_box)
	
	# Score & Distance with better font settings
	var score_h_box = HBoxContainer.new()
	v_box.add_child(score_h_box)
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 22
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	label_settings.shadow_size = 2
	label_settings.shadow_color = Color(0, 0, 0, 0.5)
	
	var s_icon = Label.new()
	s_icon.text = "🏆 "
	s_icon.label_settings = label_settings
	score_h_box.add_child(s_icon)
	
	# Redirect existing labels to the new UI structure
	score_label = Label.new()
	score_label.label_settings = label_settings
	score_h_box.add_child(score_label)
	
	var dist_h_box = HBoxContainer.new()
	v_box.add_child(dist_h_box)
	
	var d_icon = Label.new()
	d_icon.text = "🏃 "
	d_icon.label_settings = label_settings
	dist_h_box.add_child(d_icon)
	
	distance_label = Label.new()
	var dist_settings = label_settings.duplicate()
	dist_settings.font_size = 18
	distance_label.label_settings = dist_settings
	dist_h_box.add_child(distance_label)
	
	# Segmented Charge Bar
	var charge_v_box = VBoxContainer.new()
	v_box.add_child(charge_v_box)
	
	var c_label = Label.new()
	c_label.text = "ENERGY / KRATIP"
	var c_settings = label_settings.duplicate()
	c_settings.font_size = 12
	c_label.label_settings = c_settings
	charge_v_box.add_child(c_label)
	
	charge_bar_container = HBoxContainer.new()
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
	warning_node.anchor_right = 0.5
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

func update_score(value):
	score_label.text = "P1: " + str(value)
	var tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1)

func update_distance(value):
	distance_label.text = str(value) + " m"

func update_charge(current, max_val):
	for i in range(charge_segments.size()):
		var segment = charge_segments[i]
		if i < current:
			segment.color = Color(1.0, 0.8, 0.2) # Golden
			var tween = create_tween()
			tween.tween_property(segment, "scale", Vector2(1.1, 1.1), 0.05)
			tween.tween_property(segment, "scale", Vector2(1.0, 1.0), 0.05)
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
