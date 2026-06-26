extends Control

@onready var header_label: Label = %HeaderLabel

@onready var winner_container: TextureRect = %WinnerContainer
@onready var winner_tag: TextureRect = %WinnerTag
@onready var avatar: TextureRect = %Avatar

@onready var race_score_panel: TextureRect = %RaceScorePanel
@onready var val_p1_wins: Label = %ValP1Wins
@onready var val_p2_wins: Label = %ValP2Wins

@onready var endless_vbox: VBoxContainer = %EndlessVBox
@onready var val_dist_best: Label = %ValDistBest
@onready var val_run: Label = %ValRun
@onready var val_kratip: Label = %ValKratip

@onready var btn_restart: TextureButton = %BtnRestart
@onready var btn_menu: TextureButton = %BtnMenu

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
	return {
		"best_distance": 0,
		"best_time": 999999,
		"most_silk": 0,
		"p1_wins": 0,
		"p2_wins": 0,
		"top_3_times": []
	}

static func save_data(data: Dictionary):
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _ready():
	hide()
	default_scale = scale
	
	if btn_restart: btn_restart.pressed.connect(on_restart_pressed)
	if btn_menu: btn_menu.pressed.connect(on_menu_pressed)
	
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

func show_result(winner_name: String, _p1_score: int, _p2_score: int, _p1_distance: int, _p2_distance: int):
	var data = load_data()
	
	# Determine mode
	var is_endless = GameConfig.race_mode == "endless"
	
	if is_endless:
		if header_label: header_label.text = "Endless Result"
		if winner_container: winner_container.hide()
		if race_score_panel: race_score_panel.hide()
		if endless_vbox: endless_vbox.show()
		
		# Retrieve kratips from player if possible
		var kratips_this_run = 0
		var main_node = get_tree().root.get_node_or_null("Main/GameManager")
		if main_node and main_node.get("p1") and is_instance_valid(main_node.p1):
			kratips_this_run = main_node.p1.kratips_collected
			
		# Update Best Distance
		if _p1_distance > data.best_distance:
			data.best_distance = _p1_distance
			save_data(data)
			
		if val_dist_best: val_dist_best.text = "%d m" % data.best_distance
		if val_run: val_run.text = "%d m" % _p1_distance
		if val_kratip: val_kratip.text = "%d" % kratips_this_run
		
	else:
		if header_label: header_label.text = "Race Result"
		if winner_container: winner_container.show()
		if race_score_panel: race_score_panel.show()
		if endless_vbox: endless_vbox.hide()
		
		if val_p1_wins: val_p1_wins.text = str(_p1_score)
		if val_p2_wins: val_p2_wins.text = str(_p2_score)
		
		if winner_name == "Player 1":
			if winner_tag: winner_tag.texture = tex_p1_tag
			if avatar: avatar.texture = tex_p1_avatar
			data.p1_wins += 1
		elif winner_name == "Player 2":
			if winner_tag: winner_tag.texture = tex_p2_tag
			if avatar: avatar.texture = tex_p2_avatar
			data.p2_wins += 1
		else:
			if winner_tag: winner_tag.texture = null
			if avatar: avatar.texture = null
			
		save_data(data)

	# Play pop-in animation
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
