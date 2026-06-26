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

const SAVE_PATH = "user://leaderboard_data.json"

static func load_data() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text = file.get_as_text()
		var res = JSON.parse_string(text)
		if res is Dictionary:
			if not res.has("top_3_times"): res["top_3_times"] = []
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

func show_result(winner_name: String, _p1_score: int, _p2_score: int, _p1_distance: int, _p2_distance: int):
	var data = load_data()
	
	# Format Best Time
	var time_text = "--:--"
	if data.best_time < 999999:
		var bt = int(data.best_time)
		var mins = bt / 60
		var secs = bt % 60
		time_text = "%02d:%02d" % [mins, secs]
	
	if val_dist: val_dist.text = "%dm" % data.best_distance
	if val_time: val_time.text = time_text
	if val_silk: val_silk.text = "%d" % data.most_silk
	
	if val_p1_wins: val_p1_wins.text = str(data.p1_wins)
	if val_p2_wins: val_p2_wins.text = str(data.p2_wins)

	# Format Top 3 Times
	var time1st = get_node_or_null("Board/Paper/VBox/Top3Wrapper/Top3/Time1st/Panel/Label")
	var time2nd = get_node_or_null("Board/Paper/VBox/Top3Wrapper/Top3/Time2nd/Panel/Label")
	var time3rd = get_node_or_null("Board/Paper/VBox/Top3Wrapper/Top3/Time3rd/Panel/Label")
	
	var t1 = "--:--"
	var t2 = "--:--"
	var t3 = "--:--"
	var times = data.top_3_times
	if times.size() > 0:
		var t = int(times[0])
		t1 = "%02d:%02d" % [t / 60, t % 60]
	if times.size() > 1:
		var t = int(times[1])
		t2 = "%02d:%02d" % [t / 60, t % 60]
	if times.size() > 2:
		var t = int(times[2])
		t3 = "%02d:%02d" % [t / 60, t % 60]

	if time1st: time1st.text = t1
	if time2nd: time2nd.text = t2
	if time3rd: time3rd.text = t3

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
