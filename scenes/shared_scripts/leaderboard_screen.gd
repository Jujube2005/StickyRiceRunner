extends Control

@onready var race_ui: Control = %RaceUI
@onready var race_header_label: Label = %RaceHeaderLabel
@onready var race_winner_container: TextureRect = %RaceWinnerContainer
@onready var race_winner_tag: TextureRect = %RaceWinnerTag
@onready var race_avatar: TextureRect = %RaceAvatar
@onready var val_p1_wins: Label = %ValP1Wins
@onready var val_p2_wins: Label = %ValP2Wins

@onready var endless_ui: Control = %EndlessUI
@onready var endless_header_label: Label = %EndlessHeaderLabel
@onready var endless_winner_container: TextureRect = %EndlessWinnerContainer
@onready var endless_winner_tag: TextureRect = %EndlessWinnerTag
@onready var endless_avatar: TextureRect = %EndlessAvatar
@onready var val_dist_best: Label = %ValDistBest
@onready var val_run: Label = %ValRun

@onready var btn_restart: TextureButton = get_node_or_null("%BtnRestart")
@onready var btn_menu: TextureButton = get_node_or_null("%BtnMenu")
@onready var btn_restart_endless: TextureButton = get_node_or_null("%BtnRestartEndless")
@onready var btn_menu_endless: TextureButton = get_node_or_null("%BtnMenuEndless")

var tex_p1_tag = preload("res://assets/textures/UI/Buttons/P1WINS.png")
var tex_p2_tag = preload("res://assets/textures/UI/Buttons/P2WINS.png")
var tex_p1_avatar = preload("res://assets/textures/UI/Buttons/icon_player1Win.png")
var tex_p2_avatar = preload("res://assets/textures/UI/Buttons/icon_player2Win.png")

var default_scale: Vector2 = Vector2.ONE
const SAVE_PATH = "user://leaderboard_data.json"

static func load_data() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text = file.get_as_text()
		if text != "":
			var res = JSON.parse_string(text)
			if res is Dictionary:
				return res
	return { "best_distance": 0, "best_time": 999999, "most_silk": 0, "p1_wins": 0, "p2_wins": 0, "top_3_times": [] }

static func save_data(data: Dictionary):
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _ready():
	hide()
	default_scale = scale
	if btn_restart: btn_restart.pressed.connect(on_restart_pressed)
	if btn_menu: btn_menu.pressed.connect(on_menu_pressed)
	if btn_restart_endless: btn_restart_endless.pressed.connect(on_restart_pressed)
	if btn_menu_endless: btn_menu_endless.pressed.connect(on_menu_pressed)
	if btn_restart: _setup_button_hover(btn_restart)
	if btn_menu: _setup_button_hover(btn_menu)
	if btn_restart_endless: _setup_button_hover(btn_restart_endless)
	if btn_menu_endless: _setup_button_hover(btn_menu_endless)

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
	var data = load_data()
	var is_endless = GameConfig.race_mode == "endless"
	
	if is_endless:
		if race_ui: race_ui.hide()
		if endless_ui: 
			endless_ui.show()
			endless_ui.position = Vector2.ZERO
		
		if endless_header_label: endless_header_label.text = "Endless Result"
			
		if _p1_distance > data.best_distance:
			data.best_distance = _p1_distance
			save_data(data)
			
		if val_dist_best: val_dist_best.text = "%d m" % data.best_distance
		if val_run: val_run.text = "%d m" % _p1_distance
		
		if winner_name == "Player 1":
			if endless_winner_tag: endless_winner_tag.texture = tex_p1_tag
			if endless_avatar: endless_avatar.texture = tex_p1_avatar
		elif winner_name == "Player 2":
			if endless_winner_tag: endless_winner_tag.texture = tex_p2_tag
			if endless_avatar: endless_avatar.texture = tex_p2_avatar
		else:
			if endless_winner_tag: endless_winner_tag.texture = null
			if endless_avatar: endless_avatar.texture = null
			if endless_winner_container: endless_winner_container.hide()
		
	else:
		if endless_ui: endless_ui.hide()
		if race_ui: 
			race_ui.show()
			race_ui.position = Vector2.ZERO
		
		if race_header_label: race_header_label.text = "Race Result"
		
		if val_p1_wins: val_p1_wins.text = str(_p1_score)
		if val_p2_wins: val_p2_wins.text = str(_p2_score)
		
		if winner_name == "Player 1":
			if race_winner_tag: race_winner_tag.texture = tex_p1_tag
			if race_avatar: race_avatar.texture = tex_p1_avatar
			data.p1_wins += 1
		elif winner_name == "Player 2":
			if race_winner_tag: race_winner_tag.texture = tex_p2_tag
			if race_avatar: race_avatar.texture = tex_p2_avatar
			data.p2_wins += 1
		else:
			if race_winner_tag: race_winner_tag.texture = null
			if race_avatar: race_avatar.texture = null
			
		save_data(data)

	scale = default_scale * 0.8
	modulate.a = 0.0
	show()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", default_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
