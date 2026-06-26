extends Control

var player1_model_scene: PackedScene
var player2_model_scene: PackedScene

var tex_title_header = preload("res://assets/textures/UI/Buttons/title_header.png")
var tex_gold_frame = preload("res://assets/textures/UI/Buttons/goldFrame.png")
var tex_wood_sign = preload("res://assets/textures/UI/Buttons/wooden_sign.png")
var tex_icon_trophy = preload("res://assets/textures/UI/Buttons/icon_smallTrophy.png")
var tex_icon_run = preload("res://assets/textures/UI/Buttons/icon_run.png")
var tex_btn_restart = preload("res://assets/textures/UI/Buttons/btn_restart.png")
var tex_menu = preload("res://assets/textures/UI/Buttons/menu.png")
var tex_p1 = preload("res://assets/textures/UI/Buttons/P1.png")
var tex_p2 = preload("res://assets/textures/UI/Buttons/P2.png")
var tex_p1_wins = preload("res://assets/textures/UI/Buttons/P1WINS.png")
var tex_p2_wins = preload("res://assets/textures/UI/Buttons/P2WINS.png")

var backdrop: ColorRect
var content_box: VBoxContainer
var section_label: Label
var winner_banner: TextureRect
var winner_text_rect: TextureRect

# Race UI
var race_container: TextureRect
var race_p1_score: Label
var race_p2_score: Label

# Endless UI
var endless_best_container: TextureRect
var endless_best_label: Label
var endless_run_container: TextureRect
var endless_run_label: Label

var retry_button: TextureButton
var menu_button: TextureButton

func _ready():
	player1_model_scene = load("res://assets/models/player/girlTmodel.glb")
	player2_model_scene = load("res://assets/models/player/manTmodel.glb")
	
	_build_layout()
	hide()

func _build_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.08, 0.82)
	add_child(backdrop)

	content_box = VBoxContainer.new()
	content_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content_box.position -= Vector2(300, 300)
	content_box.custom_minimum_size = Vector2(600, 600)
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_box.add_theme_constant_override("separation", 15)
	add_child(content_box)

	# 1. Header
	var header = TextureRect.new()
	header.texture = tex_title_header
	header.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	content_box.add_child(header)
	
	section_label = Label.new()
	section_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var section_settings = LabelSettings.new()
	section_settings.font_size = 28
	section_settings.font_color = Color.WHITE
	section_settings.outline_size = 6
	section_settings.outline_color = Color(0.3, 0.15, 0.0)
	section_label.label_settings = section_settings
	header.add_child(section_label)

	# 2. Winner Banner
	winner_banner = TextureRect.new()
	winner_banner.texture = tex_gold_frame
	winner_banner.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	content_box.add_child(winner_banner)
	
	winner_text_rect = TextureRect.new()
	winner_text_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	winner_text_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	winner_banner.add_child(winner_text_rect)

	# 3. Race Container
	race_container = TextureRect.new()
	race_container.texture = tex_wood_sign
	race_container.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	content_box.add_child(race_container)
	
	var race_vbox = VBoxContainer.new()
	race_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	race_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	race_container.add_child(race_vbox)
	
	var score_title = Label.new()
	score_title.text = "SCORE"
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st_settings = LabelSettings.new()
	st_settings.font_size = 24
	st_settings.outline_size = 4
	st_settings.outline_color = Color.BLACK
	score_title.label_settings = st_settings
	race_vbox.add_child(score_title)
	
	var race_hbox = HBoxContainer.new()
	race_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	race_hbox.add_theme_constant_override("separation", 40)
	race_vbox.add_child(race_hbox)
	
	var p1_box = HBoxContainer.new()
	var p1_icon = TextureRect.new()
	p1_icon.texture = tex_p1
	p1_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	p1_box.add_child(p1_icon)
	race_p1_score = Label.new()
	race_p1_score.label_settings = st_settings
	p1_box.add_child(race_p1_score)
	race_hbox.add_child(p1_box)
	
	var p2_box = HBoxContainer.new()
	race_p2_score = Label.new()
	race_p2_score.label_settings = st_settings
	p2_box.add_child(race_p2_score)
	var p2_icon = TextureRect.new()
	p2_icon.texture = tex_p2
	p2_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	p2_box.add_child(p2_icon)
	race_hbox.add_child(p2_box)

	# 4. Endless Containers
	endless_best_container = TextureRect.new()
	endless_best_container.texture = tex_wood_sign
	endless_best_container.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	content_box.add_child(endless_best_container)
	
	var eb_vbox = VBoxContainer.new()
	eb_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	endless_best_container.add_child(eb_vbox)
	
	var eb_title_box = HBoxContainer.new()
	eb_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var eb_icon = TextureRect.new()
	eb_icon.texture = tex_icon_trophy
	eb_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	eb_title_box.add_child(eb_icon)
	var eb_title = Label.new()
	eb_title.text = "Best Distance"
	eb_title.label_settings = st_settings
	eb_title_box.add_child(eb_title)
	eb_vbox.add_child(eb_title_box)
	
	endless_best_label = Label.new()
	endless_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var val_settings = LabelSettings.new()
	val_settings.font_size = 28
	val_settings.outline_size = 4
	val_settings.outline_color = Color.BLACK
	endless_best_label.label_settings = val_settings
	eb_vbox.add_child(endless_best_label)
	
	endless_run_container = TextureRect.new()
	endless_run_container.texture = tex_wood_sign
	endless_run_container.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	content_box.add_child(endless_run_container)
	
	var er_vbox = VBoxContainer.new()
	er_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	er_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	endless_run_container.add_child(er_vbox)
	
	var er_title_box = HBoxContainer.new()
	er_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var er_icon = TextureRect.new()
	er_icon.texture = tex_icon_run
	er_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	er_title_box.add_child(er_icon)
	var er_title = Label.new()
	er_title.text = "This Run"
	er_title.label_settings = st_settings
	er_title_box.add_child(er_title)
	er_vbox.add_child(er_title_box)
	
	endless_run_label = Label.new()
	endless_run_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	endless_run_label.label_settings = val_settings
	er_vbox.add_child(endless_run_label)

	# 5. Buttons
	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	content_box.add_child(btn_box)
	
	retry_button = TextureButton.new()
	retry_button.texture_normal = tex_btn_restart
	retry_button.pressed.connect(_on_retry_pressed)
	btn_box.add_child(retry_button)
	
	menu_button = TextureButton.new()
	menu_button.texture_normal = tex_menu
	menu_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	btn_box.add_child(menu_button)
	
	_add_hover_anim(retry_button)
	_add_hover_anim(menu_button)

func _add_hover_anim(btn: Control):
	btn.mouse_entered.connect(func():
		var tw = create_tween()
		btn.pivot_offset = btn.size / 2.0
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		btn.pivot_offset = btn.size / 2.0
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func show_result(winner_name: String, p1_score: int, p2_score: int, p1_distance: int, p2_distance: int, p1_kratips: int = 0, p2_kratips: int = 0, p1_skills: int = 0, p2_skills: int = 0):
	var winner_id = "draw"
	if winner_name == "Player 1": winner_id = "p1"
	elif winner_name == "Player 2": winner_id = "p2"

	if winner_id == "p1":
		winner_text_rect.texture = tex_p1_wins
		winner_banner.visible = true
	elif winner_id == "p2":
		winner_text_rect.texture = tex_p2_wins
		winner_banner.visible = true
	else:
		winner_banner.visible = false

	if GameConfig.race_mode == "endless":
		section_label.text = "Endless Result"
		race_container.visible = false
		endless_best_container.visible = true
		endless_run_container.visible = true
		
		endless_best_label.text = str(int(GameConfig.best_distance)) + " m"
		endless_run_label.text = str(max(p1_distance, p2_distance)) + " m"
	else:
		section_label.text = "Race Result"
		race_container.visible = true
		endless_best_container.visible = false
		endless_run_container.visible = false
		
		race_p1_score.text = str(p1_score)
		race_p2_score.text = str(p2_score)

	self.modulate.a = 0
	self.scale = Vector2(0.9, 0.9)
	self.pivot_offset = size / 2.0
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_retry_pressed():
	get_tree().reload_current_scene()
