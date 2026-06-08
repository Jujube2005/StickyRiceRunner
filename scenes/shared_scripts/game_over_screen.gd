extends Control

var player1_model_scene: PackedScene
var player2_model_scene: PackedScene

@onready var winner_label = $WinnerLabel
@onready var final_score_label = $FinalScoreLabel
@onready var distance_label = $DistanceLabel
@onready var retry_button = $RetryButton

var backdrop: ColorRect
var result_card: PanelContainer
var split_box: HBoxContainer
var preview_frame: PanelContainer
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_root: Node3D
var preview_pivot: Node3D
var preview_camera: Camera3D
var preview_spin_tween: Tween

var info_box: VBoxContainer
var stats_grid: GridContainer
var menu_button: Button

var font_resource: Font = preload("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")

func _ready():
	player1_model_scene = load("res://assets/models/player/girlTmodel.glb")
	player2_model_scene = load("res://assets/models/player/manTmodel.glb")
	
	_build_layout()
	hide()
	
	# Wire up button signals
	if retry_button:
		retry_button.pressed.connect(on_restart_pressed)

func _build_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Clean up pre-existing children
	for node in [winner_label, final_score_label, distance_label, retry_button]:
		if node and node.get_parent():
			node.get_parent().remove_child(node)

	# 1. Dark Backdrop
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.09, 0.85)
	add_child(backdrop)

	# 2. Main Card
	result_card = PanelContainer.new()
	result_card.set_anchors_preset(Control.PRESET_CENTER)
	result_card.offset_left = -460
	result_card.offset_top = -240
	result_card.offset_right = 460
	result_card.offset_bottom = 240
	result_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.1, 0.16, 0.95)
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(1.0, 0.75, 0.1, 0.7)
	card_style.shadow_size = 25
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_style.set_corner_radius_all(24)
	card_style.set_content_margin_all(24)
	result_card.add_theme_stylebox_override("panel", card_style)
	add_child(result_card)

	# 3. Horizontal Split (Left: 3D model, Right: scoreboard/buttons)
	split_box = HBoxContainer.new()
	split_box.add_theme_constant_override("separation", 24)
	result_card.add_child(split_box)

	# --- Left Column: 3D Model Preview ---
	preview_frame = PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(380, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.12, 0.15, 0.23, 0.95)
	preview_style.border_width_left = 1
	preview_style.border_width_top = 1
	preview_style.border_width_right = 1
	preview_style.border_width_bottom = 1
	preview_style.border_color = Color(1, 1, 1, 0.08)
	preview_style.set_corner_radius_all(18)
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	split_box.add_child(preview_frame)

	preview_container = SubViewportContainer.new()
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview_container)

	preview_viewport = SubViewport.new()
	preview_viewport.disable_3d = false
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.size = Vector2i(380, 400)
	preview_container.add_child(preview_viewport)

	preview_root = Node3D.new()
	preview_viewport.add_child(preview_root)

	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.8
	environment.environment = env
	preview_root.add_child(environment)

	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 35, 0)
	key_light.light_energy = 1.3
	preview_root.add_child(key_light)

	var fill_light = OmniLight3D.new()
	fill_light.position = Vector3(0, 1.5, 2.0)
	fill_light.light_energy = 0.8
	fill_light.omni_range = 8.0
	preview_root.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0, 1.3, 2.8)
	preview_camera.current = true
	preview_camera.fov = 34.0
	preview_root.add_child(preview_camera)
	preview_camera.look_at(Vector3(0, 0.9, 0), Vector3.UP)

	preview_pivot = Node3D.new()
	preview_pivot.position = Vector3(0, -0.25, 0)
	preview_root.add_child(preview_pivot)

	# --- Right Column: Scores and Buttons ---
	info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 16)
	split_box.add_child(info_box)

	# Winner Title
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_box.add_child(winner_label)

	# Stats Comparison Grid
	stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 10)
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_child(stats_grid)

	# Action Buttons
	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 16)
	btn_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_child(btn_box)

	# Restart Button styling
	retry_button.text = "Play Again"
	retry_button.custom_minimum_size = Vector2(0, 50)
	retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1.0, 0.75, 0.1)
	btn_style.set_corner_radius_all(12)
	btn_style.set_content_margin_all(12)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(1.0, 0.83, 0.3)
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.85, 0.6, 0.05)
	retry_button.add_theme_stylebox_override("normal", btn_style)
	retry_button.add_theme_stylebox_override("hover", btn_hover)
	retry_button.add_theme_stylebox_override("pressed", btn_pressed)
	retry_button.add_theme_color_override("font_color", Color(0.06, 0.06, 0.1))
	retry_button.add_theme_font_size_override("font_size", 18)
	if font_resource:
		retry_button.add_theme_font_override("font", font_resource)
	btn_box.add_child(retry_button)

	# Menu Button creation
	menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "Main Menu"
	menu_button.custom_minimum_size = Vector2(0, 50)
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var menu_style = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.18, 0.22, 0.33)
	menu_style.set_corner_radius_all(12)
	menu_style.set_content_margin_all(12)
	var menu_hover = menu_style.duplicate()
	menu_hover.bg_color = Color(0.25, 0.3, 0.44)
	var menu_pressed = menu_style.duplicate()
	menu_pressed.bg_color = Color(0.12, 0.15, 0.24)
	menu_button.add_theme_stylebox_override("normal", menu_style)
	menu_button.add_theme_stylebox_override("hover", menu_hover)
	menu_button.add_theme_stylebox_override("pressed", menu_pressed)
	menu_button.add_theme_color_override("font_color", Color.WHITE)
	menu_button.add_theme_font_size_override("font_size", 18)
	if font_resource:
		menu_button.add_theme_font_override("font", font_resource)
	menu_button.pressed.connect(on_menu_pressed)
	btn_box.add_child(menu_button)

func show_result(winner_name: String, _p1_score: int, _p2_score: int, _p1_distance: int, _p2_distance: int):
	# Look up GameManager dynamically
	var scene_root = get_tree().current_scene
	var gm = scene_root.find_child("GameManager", true, false)
	
	# Fetch detailed stats
	var p1_kratips = 0
	var p1_dist = 0
	var p1_penalties = 0
	var p1_total = 0
	
	var p2_kratips = 0
	var p2_dist = 0
	var p2_penalties = 0
	var p2_total = 0
	
	if gm:
		if gm.p1:
			p1_kratips = gm.p1.kratips_collected
			p1_dist = int(gm.p1.distance)
			p1_penalties = gm.p1.penalties
			if gm.has_method("calculate_final_score"):
				p1_total = gm.calculate_final_score(1)
			else:
				p1_total = gm.p1.score
				
		if gm.p2:
			p2_kratips = gm.p2.kratips_collected
			p2_dist = int(gm.p2.distance)
			p2_penalties = gm.p2.penalties
			if gm.has_method("calculate_final_score"):
				p2_total = gm.calculate_final_score(2)
			else:
				p2_total = gm.p2.score
	
	# Determine winner styling
	var winner_id = "draw"
	var title_text = "DRAW!"
	var title_color = Color(0.85, 0.9, 1.0)

	if winner_name == "Player 1":
		winner_id = "p1"
		title_text = "PLAYER 1 WINS!"
		title_color = Color(1.0, 0.8, 0.1)
	elif winner_name == "Player 2":
		winner_id = "p2"
		title_text = "PLAYER 2 WINS!"
		title_color = Color(1.0, 0.8, 0.1)

	# Update Winner Label
	var title_settings = LabelSettings.new()
	title_settings.font_size = 36
	if font_resource:
		title_settings.font = font_resource
	title_settings.font_color = title_color
	title_settings.outline_size = 8
	title_settings.outline_color = Color.BLACK
	winner_label.label_settings = title_settings
	winner_label.text = title_text

	# Clear Stats Grid
	for child in stats_grid.get_children():
		child.queue_free()

	# Populate stats breakdown comparison
	var headers = ["METRIC", "PLAYER 1", "PLAYER 2"]
	for h in headers:
		var lbl = _create_stat_label(h, true, Color(1, 0.85, 0.4) if h != "METRIC" else Color(0.7, 0.7, 0.8))
		stats_grid.add_child(lbl)

	var rows = [
		["Kratips Count", str(p1_kratips) + " (x10)", str(p2_kratips) + " (x10)"],
		["Distance Run", str(p1_dist) + " m", str(p2_dist) + " m"],
		["Penalties", "-" + str(p1_penalties), "-" + str(p2_penalties)],
		["Final Score", str(p1_total), str(p2_total)]
	]

	for row in rows:
		var is_total = row[0] == "Final Score"
		var color = Color(1.0, 0.9, 0.3) if is_total else Color.WHITE
		for val in row:
			var font_color = Color(0.95, 0.95, 1.0) if val == row[0] and !is_total else color
			if val == row[0] and is_total:
				font_color = Color(1.0, 0.85, 0.2)
			var lbl = _create_stat_label(val, is_total, font_color)
			stats_grid.add_child(lbl)

	# Trigger winner 3D preview model
	_show_winner_model(winner_id)

	# Pop-in animations
	self.modulate.a = 0
	self.scale = Vector2(0.95, 0.95)
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_stat_label(text: String, is_bold: bool, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	settings.font_size = 18 if is_bold else 15
	if font_resource:
		settings.font = font_resource
	settings.font_color = color
	settings.outline_size = 4 if is_bold else 2
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	return label

func _show_winner_model(winner_id: String):
	for child in preview_pivot.get_children():
		child.queue_free()

	if winner_id == "draw":
		preview_frame.visible = false
		return

	preview_frame.visible = true
	preview_pivot.rotation.y = PI
	if preview_spin_tween:
		preview_spin_tween.kill()

	var model_scene: PackedScene = player1_model_scene if winner_id == "p1" else player2_model_scene
	if model_scene:
		var model = model_scene.instantiate()
		preview_pivot.add_child(model)
		preview_spin_tween = create_tween()
		preview_spin_tween.tween_property(preview_pivot, "rotation:y", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		push_error("Could not load winner model for: " + winner_id)

func on_restart_pressed():
	get_tree().reload_current_scene()

func on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
