extends Control

var player1_model_scene: PackedScene
var player2_model_scene: PackedScene

@onready var winner_label = $WinnerLabel
@onready var final_score_label = $FinalScoreLabel
@onready var distance_label = $DistanceLabel
@onready var retry_button = $RetryButton

var backdrop: ColorRect
var result_card: PanelContainer
var content_box: VBoxContainer
var preview_frame: PanelContainer
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_root: Node3D
var preview_pivot: Node3D
var preview_camera: Camera3D
var section_label: Label
var preview_spin_tween: Tween

func _ready():
	# Load models at runtime to avoid parser errors with preload
	player1_model_scene = load("res://assets/models/player/girlTmodel.glb")
	player2_model_scene = load("res://assets/models/player/manTmodel.glb")
	
	_build_layout()
	hide()
	retry_button.pressed.connect(_on_retry_pressed)

func _build_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	for node in [winner_label, final_score_label, distance_label, retry_button]:
		if node.get_parent():
			node.get_parent().remove_child(node)

	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.08, 0.82)
	add_child(backdrop)

	result_card = PanelContainer.new()
	result_card.set_anchors_preset(Control.PRESET_CENTER)
	result_card.offset_left = -260
	result_card.offset_top = -250
	result_card.offset_right = 260
	result_card.offset_bottom = 250
	result_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.1, 0.16, 0.95)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.95, 0.8, 0.2, 0.65)
	card_style.shadow_size = 20
	card_style.shadow_color = Color(0, 0, 0, 0.35)
	card_style.set_corner_radius_all(24)
	card_style.set_content_margin_all(28)
	result_card.add_theme_stylebox_override("panel", card_style)
	add_child(result_card)

	content_box = VBoxContainer.new()
	content_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_box.add_theme_constant_override("separation", 14)
	result_card.add_child(content_box)

	section_label = Label.new()
	section_label.text = LanguageManager.t("LBL_CHAMPION")
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var section_settings = LabelSettings.new()
	section_settings.font_size = 16
	section_settings.font_color = Color(0.83, 0.87, 0.98, 0.9)
	section_settings.outline_size = 2
	section_settings.outline_color = Color(0, 0, 0, 0.25)
	section_label.label_settings = section_settings
	content_box.add_child(section_label)

	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_box.add_child(winner_label)

	preview_frame = PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(0, 220)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.11, 0.14, 0.22, 0.95)
	preview_style.border_width_left = 1
	preview_style.border_width_top = 1
	preview_style.border_width_right = 1
	preview_style.border_width_bottom = 1
	preview_style.border_color = Color(1, 1, 1, 0.08)
	preview_style.set_corner_radius_all(18)
	preview_style.set_content_margin_all(12)
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	content_box.add_child(preview_frame)

	preview_container = SubViewportContainer.new()
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview_container)

	preview_viewport = SubViewport.new()
	preview_viewport.disable_3d = false
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.size = Vector2i(420, 320)
	preview_container.add_child(preview_viewport)

	preview_root = Node3D.new()
	preview_viewport.add_child(preview_root)

	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.58)
	env.ambient_light_energy = 0.65
	environment.environment = env
	preview_root.add_child(environment)

	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 35, 0)
	key_light.light_energy = 1.15
	preview_root.add_child(key_light)

	var fill_light = OmniLight3D.new()
	fill_light.position = Vector3(0, 1.5, 1.8)
	fill_light.light_energy = 0.7
	fill_light.omni_range = 8.0
	preview_root.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0, 1.2, 3.2)
	preview_camera.current = true
	preview_camera.fov = 33.0
	preview_root.add_child(preview_camera)
	preview_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

	preview_pivot = Node3D.new()
	preview_pivot.position = Vector3(0, -0.2, 0)
	preview_root.add_child(preview_pivot)

	_configure_info_label(final_score_label, 24, Color(1, 1, 1))
	_configure_info_label(distance_label, 18, Color(0.82, 0.87, 0.96))
	content_box.add_child(final_score_label)
	content_box.add_child(distance_label)

	retry_button.text = LanguageManager.t("BTN_PLAY_AGAIN")
	retry_button.custom_minimum_size = Vector2(0, 54)
	retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var retry_style = StyleBoxFlat.new()
	retry_style.bg_color = Color(0.97, 0.78, 0.2)
	retry_style.set_corner_radius_all(14)
	retry_style.set_content_margin_all(14)
	var retry_hover = retry_style.duplicate()
	retry_hover.bg_color = Color(1.0, 0.84, 0.32)
	var retry_pressed = retry_style.duplicate()
	retry_pressed.bg_color = Color(0.86, 0.67, 0.12)
	retry_button.add_theme_stylebox_override("normal", retry_style)
	retry_button.add_theme_stylebox_override("hover", retry_hover)
	retry_button.add_theme_stylebox_override("pressed", retry_pressed)
	retry_button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	retry_button.add_theme_font_size_override("font_size", 22)
	content_box.add_child(retry_button)

func _configure_info_label(label: Label, font_size: int, color: Color):
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info_settings = LabelSettings.new()
	info_settings.font_size = font_size
	info_settings.font_color = color
	info_settings.outline_size = 4
	info_settings.outline_color = Color(0, 0, 0, 0.5)
	label.label_settings = info_settings

func show_result(winner_name: String, p1_score: int, p2_score: int, p1_distance: int, p2_distance: int):
	var winner_id = "draw"
	var title_text = "DRAW!"
	var title_color = Color(0.86, 0.91, 1.0)

	if winner_name == "Player 1":
		winner_id = "p1"
		title_text = LanguageManager.t("LBL_P1_WINS")
		title_color = Color(0.98, 0.83, 0.2)
	elif winner_name == "Player 2":
		winner_id = "p2"
		title_text = LanguageManager.t("LBL_P2_WINS")
		title_color = Color(0.98, 0.83, 0.2)

	var title_text_draw = LanguageManager.t("LBL_DRAW")
	if winner_id == "draw":
		title_text = title_text_draw

	section_label.text = LanguageManager.t("LBL_CHAMPION") if winner_id != "draw" else LanguageManager.t("LBL_FINAL_RESULT")
	var title_settings = LabelSettings.new()
	title_settings.font_size = 42
	title_settings.font_color = title_color
	title_settings.outline_size = 8
	title_settings.outline_color = Color.BLACK
	winner_label.label_settings = title_settings
	winner_label.text = title_text

	final_score_label.text = LanguageManager.t("LBL_SCORE") % [p1_score, p2_score]
	distance_label.text = LanguageManager.t("LBL_DISTANCE") % [p1_distance, p2_distance]
	_show_winner_model(winner_id)

	self.modulate.a = 0
	self.scale = Vector2(0.94, 0.94)
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		preview_spin_tween.tween_property(preview_pivot, "rotation:y", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		push_error("Could not load winner model for: " + winner_id)

func _on_retry_pressed():
	get_tree().reload_current_scene()
