extends Control

@onready var board_rect: TextureRect = $Board

@onready var winner_tag: TextureRect = %WinnerTag
@onready var avatar: TextureRect = %Avatar

@onready var val_dist: Label = %ValDist
@onready var val_time: Label = %ValTime
@onready var val_silk: Label = %ValSilk
@onready var val_p1_wins: Label = %ValP1Wins
@onready var val_p2_wins: Label = %ValP2Wins

@onready var btn_restart: TextureButton = %BtnRestart
@onready var btn_menu: TextureButton = %BtnMenu

var tex_p1_tag = preload("res://assets/textures/UI/Buttons/P1WINS.png")
var tex_p2_tag = preload("res://assets/textures/UI/Buttons/P2WINS.png")
var tex_p1_avatar = preload("res://assets/textures/UI/Buttons/icon_player1Win.png")
var tex_p2_avatar = preload("res://assets/textures/UI/Buttons/icon_player2Win.png")

var default_scale: Vector2 = Vector2.ONE

func _ready():
	hide()
	default_scale = board_rect.scale
	
	# Connect button pressed signals
	if btn_restart: btn_restart.pressed.connect(on_restart_pressed)
	if btn_menu: btn_menu.pressed.connect(on_menu_pressed)
	
	# Connect hover effects
	if btn_restart: _setup_button_hover(btn_restart)
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

func show_result(winner_name: String, _p1_score: int, _p2_score: int, p1_distance: int, p2_distance: int):
	var scene_root = get_tree().current_scene
	var gm = scene_root.find_child("GameManager", true, false)

	var p1_kratips = 0
	var p2_kratips = 0
	
	# Try to get data from GameManager
	if gm:
		if gm.p1: p1_kratips = gm.p1.kratips_collected
		if gm.p2: p2_kratips = gm.p2.kratips_collected

	var max_dist = max(p1_distance, p2_distance)
	var max_kratips = max(p1_kratips, p2_kratips)
	
	# Format Best Time (Dummy data for now unless we have a game timer)
	var time_text = "--:--"
	if gm and "elapsed_time" in gm:
		var total_secs = int(gm.elapsed_time)
		var mins = total_secs / 60
		var secs = total_secs % 60
		time_text = "%02d:%02d" % [mins, secs]
	
	if val_dist: val_dist.text = "%dm" % max_dist
	if val_time: val_time.text = time_text
	if val_silk: val_silk.text = "%d" % max_kratips
	
	# Example data for P1/P2 Wins (In a real game, save these in an Autoload/GlobalData)
	if val_p1_wins: val_p1_wins.text = "1" if winner_name == "Player 1" else "0"
	if val_p2_wins: val_p2_wins.text = "1" if winner_name == "Player 2" else "0"

	# Champion Section Update
	if winner_name == "Player 1":
		if winner_tag: winner_tag.texture = tex_p1_tag
		if avatar: avatar.texture = tex_p1_avatar
	elif winner_name == "Player 2":
		if winner_tag: winner_tag.texture = tex_p2_tag
		if avatar: avatar.texture = tex_p2_avatar
	else:
		# Draw / Tie fallback
		if winner_tag: winner_tag.texture = null
		if avatar: avatar.texture = null

	# Play pop-in animation
	board_rect.scale = default_scale * 0.8
	board_rect.modulate.a = 0.0
	self.modulate.a = 0.0
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(board_rect, "modulate:a", 1.0, 0.3)
	tween.tween_property(board_rect, "scale", default_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
