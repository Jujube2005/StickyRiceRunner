extends Control

@onready var board_rect: TextureRect = $Board
@onready var title_rect: Label = $Board/TitleHeader
@onready var default_scale: Vector2 = board_rect.scale

@onready var p1_winner_tag: Label = $Board/P1Stats/WinnerTag
@onready var p1_dist_bar: TextureProgressBar = $Board/P1Stats/DistBar
@onready var p1_dist_val: Label = $Board/P1Stats/DistVal
@onready var p1_kratib_val: Label = $Board/P1Stats/KratibVal

@onready var p2_winner_tag: Label = $Board/P2Stats/WinnerTag
@onready var p2_dist_bar: TextureProgressBar = $Board/P2Stats/DistBar
@onready var p2_dist_val: Label = $Board/P2Stats/DistVal
@onready var p2_kratib_val: Label = $Board/P2Stats/KratibVal

@onready var p1_avatar: TextureRect = $Board/P1Stats/Avatar
@onready var p2_avatar: TextureRect = $Board/P2Stats/Avatar

var tex_p1_win = preload("res://assets/textures/UI/avatarPlayer/avatarP1_win.png")
var tex_p1_lose = preload("res://assets/textures/UI/avatarPlayer/avatarP1_lose.png")
var tex_p2_win = preload("res://assets/textures/UI/avatarPlayer/avatarP2_win.png")
var tex_p2_lose = preload("res://assets/textures/UI/avatarPlayer/avatarP2_lose.png")

@onready var btn_leaderbord: TextureButton = $Board/ButtonBox/BtnLeaderbord
@onready var btn_play: TextureButton = $Board/ButtonBox/BtnPlay
@onready var btn_menu: TextureButton = $Board/ButtonBox/BtnMenu

func _ready():
	hide()
	
	# Connect button pressed signals
	if btn_leaderbord: btn_leaderbord.pressed.connect(on_leaderboard_pressed)
	if btn_play: btn_play.pressed.connect(on_restart_pressed)
	if btn_menu: btn_menu.pressed.connect(on_menu_pressed)
	
	# Connect hover effects
	if btn_leaderbord: _setup_button_hover(btn_leaderbord)
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

var current_winner = ""
var current_p1_score = 0
var current_p2_score = 0
var current_p1_dist = 0
var current_p2_dist = 0

func show_result(winner_name: String, _p1_score: int, _p2_score: int, _p1_distance: int, _p2_distance: int):
	current_winner = winner_name
	current_p1_score = _p1_score
	current_p2_score = _p2_score
	current_p1_dist = _p1_distance
	current_p2_dist = _p2_distance
	
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

	var max_dist = max(p1_dist, p2_dist)
	var max_kratips = max(p1_kratips, p2_kratips)
	
	var leaderboard_script = preload("res://scenes/shared_scripts/leaderboard_screen.gd")
	var data = leaderboard_script.load_data()
	
	if max_dist > data.best_distance:
		data.best_distance = max_dist
	if max_kratips > data.most_silk:
		data.most_silk = max_kratips
	
	if winner_name == "Player 1":
		data.p1_wins += 1
	elif winner_name == "Player 2":
		data.p2_wins += 1
	
	var current_time = 0
	if gm and "elapsed_time" in gm:
		current_time = int(gm.elapsed_time)
	
	if current_time > 0 and winner_name != "":
		data.top_3_times.append(current_time)
		data.top_3_times.sort()
		if data.top_3_times.size() > 3:
			data.top_3_times = data.top_3_times.slice(0, 3)
		if current_time < data.best_time:
			data.best_time = current_time

	leaderboard_script.save_data(data)

	var goal_dist = 1000.0
	if gm:
		goal_dist = float(gm.get("GOAL_DISTANCE"))

	# Update stats labels & bars
	if p1_dist_bar:
		p1_dist_bar.value = clamp((float(p1_dist) / goal_dist) * 100.0, 0.0, 100.0)
	if p1_dist_val:
		p1_dist_val.text = "%dm" % p1_dist
	if p1_kratib_val:
		# Total = (Kratib × 100) + Distance
		p1_kratib_val.text = str((p1_kratips * 100) + p1_dist)

	if p2_dist_bar:
		p2_dist_bar.value = clamp((float(p2_dist) / goal_dist) * 100.0, 0.0, 100.0)
	if p2_dist_val:
		p2_dist_val.text = "%dm" % p2_dist
	if p2_kratib_val:
		# Total = (Kratib × 100) + Distance
		p2_kratib_val.text = str((p2_kratips * 100) + p2_dist)

	# Winner crowns configuration & Avatar switching
	if winner_name == "Player 1":
		if p1_winner_tag: p1_winner_tag.visible = true
		if p2_winner_tag: p2_winner_tag.visible = false
		if p1_avatar: p1_avatar.texture = tex_p1_win
		if p2_avatar: p2_avatar.texture = tex_p2_lose
	elif winner_name == "Player 2":
		if p1_winner_tag: p1_winner_tag.visible = false
		if p2_winner_tag: p2_winner_tag.visible = true
		if p1_avatar: p1_avatar.texture = tex_p1_lose
		if p2_avatar: p2_avatar.texture = tex_p2_win
	else:
		if p1_winner_tag: p1_winner_tag.visible = false
		if p2_winner_tag: p2_winner_tag.visible = false
		if p1_avatar: p1_avatar.texture = tex_p1_lose
		if p2_avatar: p2_avatar.texture = tex_p2_lose

	# Launch Podium Cutscene instead of showing board immediately
	var p1_char = "man"   # default — extend later per character selection
	var p2_char = "woman"
	var podium_script = load("res://cutscene/podium_cutscene.gd")
	var _podium_instance = podium_script.launch(
		get_tree(),
		winner_name,
		p1_char, p2_char,
		p1_kratips, p2_kratips,
		p1_dist, p2_dist,
		_show_board
	)

func _show_board() -> void:
	# Pop-in animation using the editor-defined scale
	board_rect.scale = default_scale * 0.9
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

func on_leaderboard_pressed():
	var leaderboard_scene = load("res://scenes/ui/leaderboard_screen.tscn")
	if leaderboard_scene:
		var leaderboard = leaderboard_scene.instantiate()
		get_parent().add_child(leaderboard)
		leaderboard.show_result(current_winner, current_p1_score, current_p2_score, current_p1_dist, current_p2_dist)
		hide()


func on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
