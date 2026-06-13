extends Control

@onready var board_rect: TextureRect = $Board
@onready var btn_resume: TextureButton = $Board/ButtonBox/BtnResume
@onready var btn_restart: TextureButton = $Board/ButtonBox/BtnRestart
@onready var btn_menu: TextureButton = $Board/ButtonBox/BtnMenu

var default_scale: Vector2

func _ready():
	hide()
	default_scale = board_rect.scale

	if btn_resume:  btn_resume.pressed.connect(_on_resume_pressed)
	if btn_restart: btn_restart.pressed.connect(_on_restart_pressed)
	if btn_menu:    btn_menu.pressed.connect(_on_menu_pressed)

	if btn_resume:  _setup_button_hover(btn_resume)
	if btn_restart: _setup_button_hover(btn_restart)
	if btn_menu:    _setup_button_hover(btn_menu)

func _setup_button_hover(btn: TextureButton):
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

func show_pause():
	board_rect.scale = default_scale * 0.85
	board_rect.modulate.a = 0.0
	self.modulate.a = 0.0
	show()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(board_rect, "modulate:a", 1.0, 0.25)
	tween.tween_property(board_rect, "scale", default_scale, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_resume_pressed():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(board_rect, "scale", default_scale * 0.85, 0.2)
	await tween.finished
	get_tree().paused = false
	hide()

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
