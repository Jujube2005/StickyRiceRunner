extends Control

@onready var board_rect: TextureRect = $Board
@onready var title_rect: TextureRect = $Board/TitleHeader
@onready var default_scale: Vector2 = board_rect.scale

@onready var p1_winner_tag: Label = $Board/P1Stats/WinnerTag
@onready var p1_dist_bar: TextureProgressBar = $Board/P1Stats/DistBar
@onready var p1_dist_val: Label = $Board/P1Stats/DistVal
@onready var p1_kratib_val: Label = $Board/P1Stats/KratibVal

@onready var p2_winner_tag: Label = $Board/P2Stats/WinnerTag
@onready var p2_dist_bar: TextureProgressBar = $Board/P2Stats/DistBar
@onready var p2_dist_val: Label = $Board/P2Stats/DistVal
@onready var p2_kratib_val: Label = $Board/P2Stats/KratibVal

@onready var btn_restart: TextureButton = $Board/ButtonBox/BtnRestart
@onready var btn_play: TextureButton = $Board/ButtonBox/BtnPlay
@onready var btn_menu: TextureButton = $Board/ButtonBox/BtnMenu

func _ready():
	hide()
	
	# Connect button pressed signals
	if btn_restart: btn_restart.pressed.connect(on_restart_pressed)
	if btn_play: btn_play.pressed.connect(on_restart_pressed)
	if btn_menu: btn_menu.pressed.connect(on_menu_pressed)
	
	# Connect hover effects
	if btn_restart: _setup_button_hover(btn_restart)
	if btn_play: _setup_button_hover(btn_play)
	if btn_menu: _setup_button_hover(btn_menu)

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

	# Update stats labels & bars
	if p1_dist_bar:
		p1_dist_bar.value = clamp((float(p1_dist) / goal_dist) * 100.0, 0.0, 100.0)
	if p1_dist_val:
		p1_dist_val.text = "%dm" % p1_dist
	if p1_kratib_val:
		p1_kratib_val.text = str((p1_kratips * 10) + p1_dist)

	if p2_dist_bar:
		p2_dist_bar.value = clamp((float(p2_dist) / goal_dist) * 100.0, 0.0, 100.0)
	if p2_dist_val:
		p2_dist_val.text = "%dm" % p2_dist
	if p2_kratib_val:
		p2_kratib_val.text = str((p2_kratips * 10) + p2_dist)

	# Winner crowns configuration
	if winner_name == "Player 1":
		if p1_winner_tag: p1_winner_tag.visible = true
		if p2_winner_tag: p2_winner_tag.visible = false
	elif winner_name == "Player 2":
		if p1_winner_tag: p1_winner_tag.visible = false
		if p2_winner_tag: p2_winner_tag.visible = true
	else:
		if p1_winner_tag: p1_winner_tag.visible = false
		if p2_winner_tag: p2_winner_tag.visible = false

	# Play pop-in animation using the editor-defined scale
	board_rect.scale = default_scale * 0.9
	board_rect.modulate.a = 0.0
	self.modulate.a = 0.0
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(board_rect, "modulate:a", 1.0, 0.3)
	tween.tween_property(board_rect, "scale", default_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_restart_pressed():
	get_tree().reload_current_scene()

func on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
