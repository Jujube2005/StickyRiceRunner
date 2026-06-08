extends Control

@onready var winner_label = $WinnerLabel
@onready var final_score_label = $FinalScoreLabel
@onready var distance_label = $DistanceLabel
@onready var retry_button = $RetryButton

var font_resource: Font = preload("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")

var board_rect: TextureRect
var title_rect: TextureRect

var p1_stats_node: Control
var p1_avatar: TextureRect
var p1_name_label: Label
var p1_winner_tag: Label
var p1_dist_bar: TextureProgressBar
var p1_dist_val: Label
var p1_kratib_icon: TextureRect
var p1_kratib_val: Label

var p2_stats_node: Control
var p2_avatar: TextureRect
var p2_name_label: Label
var p2_winner_tag: Label
var p2_dist_bar: TextureProgressBar
var p2_dist_val: Label
var p2_kratib_icon: TextureRect
var p2_kratib_val: Label

var btn_restart: TextureButton
var btn_play: TextureButton
var btn_menu: TextureButton

func _ready():
	_build_layout()
	hide()

func _build_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Clean up pre-existing default nodes from tree
	for node in [winner_label, final_score_label, distance_label, retry_button]:
		if node and node.get_parent():
			node.get_parent().remove_child(node)

	# 1. Dark Backdrop overlay
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.09, 0.75)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 2. Board Background Texture Rect (613x823)
	board_rect = TextureRect.new()
	board_rect.texture = load("res://assets/textures/UI/Buttons/board_bg.png")
	board_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board_rect.set_anchors_preset(Control.PRESET_CENTER)
	board_rect.offset_left = -306.5
	board_rect.offset_top = -411.5
	board_rect.offset_right = 306.5
	board_rect.offset_bottom = 411.5
	board_rect.pivot_offset = Vector2(306.5, 411.5)
	board_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(board_rect)

	# 3. Title Header Image (869x237)
	title_rect = TextureRect.new()
	title_rect.texture = load("res://assets/textures/UI/Buttons/title_header.png")
	title_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_rect.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_rect.offset_left = -434.5
	title_rect.offset_top = -70.0
	title_rect.offset_right = 434.5
	title_rect.offset_bottom = 167.0
	title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_rect.add_child(title_rect)

	# 4. Label Styles
	var player_label_settings = LabelSettings.new()
	player_label_settings.font = font_resource
	player_label_settings.font_size = 22
	player_label_settings.font_color = Color(1.0, 1.0, 1.0)
	player_label_settings.outline_size = 6
	player_label_settings.outline_color = Color(0.25, 0.15, 0.05)

	var text_label_settings = LabelSettings.new()
	text_label_settings.font = font_resource
	text_label_settings.font_size = 18
	text_label_settings.font_color = Color(0.35, 0.22, 0.1)

	# --- Player 1 Layout ---
	p1_stats_node = Control.new()
	p1_stats_node.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p1_stats_node.offset_left = 60.0
	p1_stats_node.offset_top = 220.0
	p1_stats_node.offset_right = -60.0
	p1_stats_node.offset_bottom = 400.0
	board_rect.add_child(p1_stats_node)

	p1_avatar = TextureRect.new()
	p1_avatar.texture = load("res://assets/textures/UI/Buttons/avatar_yellow.png")
	p1_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p1_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p1_avatar.size = Vector2(90, 90)
	p1_avatar.position = Vector2(0, 10)
	p1_stats_node.add_child(p1_avatar)

	p1_name_label = Label.new()
	p1_name_label.text = "PLAYER 1"
	p1_name_label.label_settings = player_label_settings
	p1_name_label.size = Vector2(150, 35)
	p1_name_label.position = Vector2(110, 5)
	p1_stats_node.add_child(p1_name_label)

	p1_winner_tag = Label.new()
	p1_winner_tag.text = "👑 WINNER"
	var win_settings = LabelSettings.new()
	win_settings.font = font_resource
	win_settings.font_size = 20
	win_settings.font_color = Color(1.0, 0.84, 0.0) # Gold
	win_settings.outline_size = 6
	win_settings.outline_color = Color(0.25, 0.15, 0.05)
	p1_winner_tag.label_settings = win_settings
	p1_winner_tag.size = Vector2(120, 35)
	p1_winner_tag.position = Vector2(230, 5)
	p1_winner_tag.visible = false
	p1_stats_node.add_child(p1_winner_tag)

	p1_dist_bar = TextureProgressBar.new()
	p1_dist_bar.texture_under = load("res://assets/textures/UI/Buttons/rice_bar_orange.png")
	p1_dist_bar.texture_progress = load("res://assets/textures/UI/Buttons/progress_fill_orange.png")
	p1_dist_bar.nine_patch_stretch = true
	p1_dist_bar.size = Vector2(220, 30)
	p1_dist_bar.position = Vector2(110, 45)
	p1_dist_bar.max_value = 100.0
	p1_stats_node.add_child(p1_dist_bar)

	p1_dist_val = Label.new()
	p1_dist_val.text = "0m"
	p1_dist_val.label_settings = text_label_settings
	p1_dist_val.size = Vector2(100, 30)
	p1_dist_val.position = Vector2(350, 45)
	p1_stats_node.add_child(p1_dist_val)

	p1_kratib_icon = TextureRect.new()
	p1_kratib_icon.texture = load("res://assets/textures/UI/Buttons/icon_katib.png")
	p1_kratib_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p1_kratib_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p1_kratib_icon.size = Vector2(40, 40)
	p1_kratib_icon.position = Vector2(110, 90)
	p1_stats_node.add_child(p1_kratib_icon)

	p1_kratib_val = Label.new()
	p1_kratib_val.text = "0"
	p1_kratib_val.label_settings = text_label_settings
	p1_kratib_val.size = Vector2(100, 40)
	p1_kratib_val.position = Vector2(160, 90)
	p1_stats_node.add_child(p1_kratib_val)

	# --- Player 2 Layout ---
	p2_stats_node = Control.new()
	p2_stats_node.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p2_stats_node.offset_left = 60.0
	p2_stats_node.offset_top = 450.0
	p2_stats_node.offset_right = -60.0
	p2_stats_node.offset_bottom = 630.0
	board_rect.add_child(p2_stats_node)

	p2_avatar = TextureRect.new()
	p2_avatar.texture = load("res://assets/textures/UI/Buttons/avatar_green.png")
	p2_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p2_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p2_avatar.size = Vector2(90, 90)
	p2_avatar.position = Vector2(0, 10)
	p2_stats_node.add_child(p2_avatar)

	p2_name_label = Label.new()
	p2_name_label.text = "PLAYER 2"
	p2_name_label.label_settings = player_label_settings
	p2_name_label.size = Vector2(150, 35)
	p2_name_label.position = Vector2(110, 5)
	p2_stats_node.add_child(p2_name_label)

	p2_winner_tag = Label.new()
	p2_winner_tag.text = "👑 WINNER"
	p2_winner_tag.label_settings = win_settings
	p2_winner_tag.size = Vector2(120, 35)
	p2_winner_tag.position = Vector2(230, 5)
	p2_winner_tag.visible = false
	p2_stats_node.add_child(p2_winner_tag)

	p2_dist_bar = TextureProgressBar.new()
	p2_dist_bar.texture_under = load("res://assets/textures/UI/Buttons/rice_bar_green.png")
	p2_dist_bar.texture_progress = load("res://assets/textures/UI/Buttons/progress_fill_green.png")
	p2_dist_bar.nine_patch_stretch = true
	p2_dist_bar.size = Vector2(220, 30)
	p2_dist_bar.position = Vector2(110, 45)
	p2_dist_bar.max_value = 100.0
	p2_stats_node.add_child(p2_dist_bar)

	p2_dist_val = Label.new()
	p2_dist_val.text = "0m"
	p2_dist_val.label_settings = text_label_settings
	p2_dist_val.size = Vector2(100, 30)
	p2_dist_val.position = Vector2(350, 45)
	p2_stats_node.add_child(p2_dist_val)

	p2_kratib_icon = TextureRect.new()
	p2_kratib_icon.texture = load("res://assets/textures/UI/Buttons/icon_katib.png")
	p2_kratib_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p2_kratib_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p2_kratib_icon.size = Vector2(40, 40)
	p2_kratib_icon.position = Vector2(110, 90)
	p2_stats_node.add_child(p2_kratib_icon)

	p2_kratib_val = Label.new()
	p2_kratib_val.text = "0"
	p2_kratib_val.label_settings = text_label_settings
	p2_kratib_val.size = Vector2(100, 40)
	p2_kratib_val.position = Vector2(160, 90)
	p2_stats_node.add_child(p2_kratib_val)

	# --- Bottom Action Buttons ---
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 25)
	btn_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_box.offset_left = -220.0
	btn_box.offset_top = -120.0
	btn_box.offset_right = 220.0
	btn_box.offset_bottom = -20.0
	board_rect.add_child(btn_box)

	# 1. Restart Button
	btn_restart = TextureButton.new()
	btn_restart.texture_normal = load("res://assets/textures/UI/Buttons/btn_restart.png")
	btn_restart.custom_minimum_size = Vector2(80, 80)
	btn_restart.ignore_texture_size = true
	btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_restart.pressed.connect(on_restart_pressed)
	_setup_button_hover(btn_restart)
	btn_box.add_child(btn_restart)

	# 2. Play/Continue Button
	btn_play = TextureButton.new()
	btn_play.texture_normal = load("res://assets/textures/UI/Buttons/btn_play.png")
	btn_play.custom_minimum_size = Vector2(95, 95)
	btn_play.ignore_texture_size = true
	btn_play.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_play.pressed.connect(on_restart_pressed)
	_setup_button_hover(btn_play)
	btn_box.add_child(btn_play)

	# 3. Menu Button
	btn_menu = TextureButton.new()
	btn_menu.texture_normal = load("res://assets/textures/UI/Buttons/btn_menu.png")
	btn_menu.custom_minimum_size = Vector2(80, 80)
	btn_menu.ignore_texture_size = true
	btn_menu.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_menu.pressed.connect(on_menu_pressed)
	_setup_button_hover(btn_menu)
	btn_box.add_child(btn_menu)

func _setup_button_hover(btn: TextureButton):
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

func show_result(winner_name: String, _p1_score: int, _p2_score: int, _p1_distance: int, _p2_distance: int):
	# Find GameManager in scene
	var scene_root = get_tree().current_scene
	var gm = scene_root.find_child("GameManager", true, false)

	var p1_kratips = 0
	var p1_dist = 0
	var p2_kratips = 0
	var p2_dist = 0

	if gm:
		if gm.p1:
			p1_kratips = gm.p1.kratips_collected
			p1_dist = int(gm.p1.distance)
		if gm.p2:
			p2_kratips = gm.p2.kratips_collected
			p2_dist = int(gm.p2.distance)

	var goal_dist = 1000.0
	if gm:
		goal_dist = float(gm.get("GOAL_DISTANCE"))

	# Update stats elements
	if p1_dist_bar:
		p1_dist_bar.value = clamp((float(p1_dist) / goal_dist) * 100.0, 0.0, 100.0)
	if p1_dist_val:
		p1_dist_val.text = "%dm" % p1_dist
	if p1_kratib_val:
		p1_kratib_val.text = str(p1_kratips)

	if p2_dist_bar:
		p2_dist_bar.value = clamp((float(p2_dist) / goal_dist) * 100.0, 0.0, 100.0)
	if p2_dist_val:
		p2_dist_val.text = "%dm" % p2_dist
	if p2_kratib_val:
		p2_kratib_val.text = str(p2_kratips)

	# Winner configuration
	if winner_name == "Player 1":
		p1_winner_tag.visible = true
		p2_winner_tag.visible = false
	elif winner_name == "Player 2":
		p1_winner_tag.visible = false
		p2_winner_tag.visible = true
	else:
		p1_winner_tag.visible = false
		p2_winner_tag.visible = false

	# Play pop-in animations
	board_rect.scale = Vector2(0.9, 0.9)
	board_rect.modulate.a = 0.0
	self.modulate.a = 0.0
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(board_rect, "modulate:a", 1.0, 0.3)
	tween.tween_property(board_rect, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_restart_pressed():
	get_tree().reload_current_scene()

func on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
