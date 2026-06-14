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
var skill_pulse_tween: Tween

# Theme Colors
const COLOR_LOCKED = Color(0.4, 0.4, 0.4, 0.6)
const COLOR_PREPARE = Color(0.1, 0.7, 1.0) # Bright Blue (Sky)
const COLOR_READY = Color(1.0, 0.6, 0.0)    # Gold/Orange (Fire)
const COLOR_DEFEND = Color(0.2, 0.7, 0.3)   # Green (Protective)

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
	player.skill_state_changed.connect(_on_skill_state_changed)
	
	if player.game_manager:
		player.game_manager.global_cooldown_changed.connect(_on_global_cooldown_changed)
	
	skill_button.pressed.connect(_on_skill_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	# Phase 1 feedback signals
	if player.has_signal("obstacle_hit"):
		player.obstacle_hit.connect(func(): _flash_screen(Color(1, 0, 0, 0.15)))
	if player.has_signal("prank_flash"):
		player.prank_flash.connect(func(color: Color): _flash_screen(color))
	
	update_score(player.score)
	update_distance(player.distance)
	update_charge(player.charges, player.MAX_CHARGES)
	
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
	hud_panel.offset_bottom = 160
	hud_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hud_panel)
	
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 8)
	v_box.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_panel.add_child(v_box)
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 22
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	label_settings.shadow_size = 2
	label_settings.shadow_color = Color(0, 0, 0, 0.5)
	
	# Score (Right Aligned)
	var score_h_box = HBoxContainer.new()
	score_h_box.alignment = BoxContainer.ALIGNMENT_END
	score_h_box.mouse_filter = Control.MOUSE_FILTER_PASS
	v_box.add_child(score_h_box)
	
	score_label = Label.new()
	score_label.label_settings = label_settings
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_h_box.add_child(score_label)
	
	# Distance (Right Aligned)
	var dist_h_box = HBoxContainer.new()
	dist_h_box.alignment = BoxContainer.ALIGNMENT_END
	dist_h_box.mouse_filter = Control.MOUSE_FILTER_PASS
	v_box.add_child(dist_h_box)
	
	distance_label = Label.new()
	var dist_settings = label_settings.duplicate()
	dist_settings.font_size = 18
	distance_label.label_settings = dist_settings
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dist_h_box.add_child(distance_label)
	
	# Segmented Charge Bar
	var charge_v_box = VBoxContainer.new()
	charge_v_box.mouse_filter = Control.MOUSE_FILTER_PASS
	v_box.add_child(charge_v_box)
	
	var c_label = Label.new()
	c_label.text = LanguageManager.t("UI_STAMINA_KRATIP")
	c_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c_settings = label_settings.duplicate()
	c_settings.font_size = 12
	c_label.label_settings = c_settings
	charge_v_box.add_child(c_label)
	
	charge_bar_container = HBoxContainer.new()
	charge_bar_container.alignment = BoxContainer.ALIGNMENT_END
	charge_bar_container.custom_minimum_size.y = 15
	charge_bar_container.add_theme_constant_override("separation", 4)
	charge_bar_container.mouse_filter = Control.MOUSE_FILTER_PASS
	charge_v_box.add_child(charge_bar_container)
	
	for i in range(5):
		var segment = ColorRect.new()
		segment.custom_minimum_size = Vector2(44, 12)
		segment.color = Color(0.2, 0.2, 0.2, 0.8)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		charge_bar_container.add_child(segment)
		charge_segments.append(segment)
		
	# Action Buttons Container
	var btn_h_box = HBoxContainer.new()
	btn_h_box.add_theme_constant_override("separation", 10)
	btn_h_box.alignment = BoxContainer.ALIGNMENT_END # Align right for P2
	btn_h_box.mouse_filter = Control.MOUSE_FILTER_PASS
	v_box.add_child(btn_h_box)
	
	# Reparent and style buttons
	if skill_button.get_parent(): skill_button.get_parent().remove_child(skill_button)
	if defend_button.get_parent(): defend_button.get_parent().remove_child(defend_button)
	
	btn_h_box.add_child(skill_button)
	btn_h_box.add_child(defend_button)
	
	# Common Button Styling
	for btn in [skill_button, defend_button]:
		btn.custom_minimum_size = Vector2(110, 45)
		btn.visible = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pivot_offset = btn.custom_minimum_size / 2
		
	skill_button.text = LanguageManager.t("BTN_USE_SKILL")
	defend_button.text = LanguageManager.t("BTN_DEFEND")
	
	_update_button_visuals()

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
	warning_label_large.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	
	_update_button_visuals()

func _update_button_visuals():
	if !skill_button or !defend_button: return
	
	# Stop previous animation if any
	if skill_pulse_tween:
		skill_pulse_tween.kill()
		skill_button.scale = Vector2.ONE
		skill_button.self_modulate = Color.WHITE
	
	# Skill Button Logic
	var is_cooldown = false
	if player.game_manager:
		is_cooldown = player.game_manager.skill_cooldown_timer > 0
		
	if player.charges >= player.MAX_CHARGES and !is_cooldown:
		skill_button.disabled = false
		if player.is_rolling_skill:
			skill_button.text = LanguageManager.t("BTN_ROLLING")
			skill_button.disabled = true
			_apply_button_style(skill_button, COLOR_PREPARE.lightened(0.3))
			_start_rolling_animation()
		elif player.is_skill_ready:
			skill_button.text = LanguageManager.t("BTN_USE_SKILL")
			skill_button.modulate = Color.WHITE
			_apply_button_style(skill_button, COLOR_READY)
			_start_pulse_animation(skill_button)
		else:
			skill_button.text = LanguageManager.t("BTN_SKILL_READY")
			skill_button.modulate = Color.WHITE
			_apply_button_style(skill_button, COLOR_PREPARE)
	else:
		skill_button.disabled = true
		if is_cooldown:
			skill_button.text = LanguageManager.t("BTN_WAIT")
		else:
			skill_button.text = LanguageManager.t("BTN_NOT_READY")
		skill_button.modulate = Color.WHITE
		_apply_button_style(skill_button, COLOR_LOCKED)
		
	# Defend Button Logic
	defend_button.text = LanguageManager.t("BTN_DEFEND")
	if player.charges >= 1:
		defend_button.disabled = false
		defend_button.modulate = Color.WHITE
		_apply_button_style(defend_button, COLOR_DEFEND)
	else:
		defend_button.disabled = true
		defend_button.modulate = Color.WHITE
		_apply_button_style(defend_button, COLOR_LOCKED)

func _start_rolling_animation():
	var tween = create_tween().set_loops(10)
	var random_emoji = ["🏮", "🎆", "✨", "🔥", "🚀"]
	tween.tween_callback(func(): 
		skill_button.text = LanguageManager.t("BTN_ROLLING")
	).set_delay(0.1)

func _apply_button_style(btn: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.border_width_bottom = 4
	style.border_color = color.darkened(0.3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = color.darkened(0.2)
	disabled_style.bg_color.a = 0.5
	btn.add_theme_stylebox_override("disabled", disabled_style)

func _start_pulse_animation(btn: Button):
	skill_pulse_tween = create_tween().set_loops()
	skill_pulse_tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_SINE)
	skill_pulse_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	# Also pulse the color/glow
	skill_pulse_tween.parallel().tween_property(btn, "self_modulate", Color(1.5, 1.5, 1.5), 0.5)
	skill_pulse_tween.parallel().tween_property(btn, "self_modulate", Color(1, 1, 1), 0.5)

func _pulse_charge_segments():
	var tween = create_tween().set_loops(3)
	for segment in charge_segments:
		tween.parallel().tween_property(segment, "modulate", Color(2, 2, 2), 0.2)
	for segment in charge_segments:
		tween.parallel().tween_property(segment, "modulate", Color(1, 1, 1), 0.2)

func update_warning(text):
	if text == "" or text.begins_with("CLEAR:"):
		if text.begins_with("CLEAR:"):
			var target_msg = text.get_slice(":", 1)
			if target_msg != "" and !warning_label_large.text.contains(target_msg):
				return # Don't clear if current text is different
		
		warning_node.visible = false
		return
		
	warning_label_large.text = text
	warning_node.visible = true
	
	# Scale animation
	warning_label_large.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(warning_label_large, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
	
	if text.ends_with(LanguageManager.t("WARN_INCOMING")):
		warning_label_large.label_settings.font_color = Color.RED
		warning_label_large.text = LanguageManager.t("WARN_WARNING") + text.to_upper()
		_pulse_warning()
		_flash_screen(Color(1, 0, 0, 0.3))
	elif text.begins_with(LanguageManager.t("HUD_GOT_SKILL")):
		warning_label_large.label_settings.font_color = Color.GOLD
		var skill_name = text.trim_prefix(LanguageManager.t("HUD_GOT_SKILL")).to_upper()
		warning_label_large.text = LanguageManager.t("WARN_SKILL_READY_RELEASE") + "[" + skill_name + "]"
		_flash_screen(Color(1, 0.8, 0, 0.4))
		# Extra reveal animation
		var tween_reveal = create_tween()
		tween_reveal.tween_property(warning_label_large, "scale", Vector2(1.5, 1.5), 0.2)
		tween_reveal.tween_property(warning_label_large, "scale", Vector2(1.0, 1.0), 0.1)
	elif text == LanguageManager.t("WARN_BLOCKED"):
		warning_label_large.label_settings.font_color = Color.GREEN
		warning_label_large.text = LanguageManager.t("WARN_BLOCKED")
		_flash_screen(Color(0, 1, 0, 0.3))
	elif text == LanguageManager.t("WARN_HIT"):
		warning_label_large.label_settings.font_color = Color.ORANGE_RED
		warning_label_large.text = LanguageManager.t("WARN_HIT")
		_flash_screen(Color(1, 0.3, 0, 0.4))
		# Shake animation
		var tween_shake = create_tween()
		for i in range(4):
			tween_shake.tween_property(warning_label_large, "position:x", warning_label_large.position.x + 10, 0.05)
			tween_shake.tween_property(warning_label_large, "position:x", warning_label_large.position.x - 10, 0.05)
		tween_shake.tween_property(warning_label_large, "position:x", warning_label_large.position.x, 0.05)
	elif text == LanguageManager.t("WARN_NOTHING_TO_BLOCK"):
		warning_label_large.label_settings.font_color = Color.LIGHT_GRAY
		warning_label_large.text = LanguageManager.t("WARN_NOTHING_TO_BLOCK")
		_flash_screen(Color(0.5, 0.5, 0.5, 0.1))
	else:
		warning_label_large.label_settings.font_color = Color.YELLOW
		_flash_screen(Color(1, 1, 0, 0.2)) # Yellow flash for info

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
	_animate_button_press(skill_button)
	player.request_skill()

func _animate_button_press(btn: Button):
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.07).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)

func _on_skill_state_changed(_is_ready, _skill_name):
	_update_button_visuals()

func _on_global_cooldown_changed(_active):
	_update_button_visuals()

func _on_defend_pressed():
	player.try_defend()
