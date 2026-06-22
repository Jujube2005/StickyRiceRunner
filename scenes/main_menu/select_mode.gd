extends Control

@onready var overlay = $Overlay
@onready var content = $Content
@onready var race_btn = %RaceBtn
@onready var endless_btn = %EndlessBtn
@onready var close_btn = %CloseBtn

func _ready():
	_animate_in()
	
	race_btn.pressed.connect(_on_race_pressed)
	endless_btn.pressed.connect(_on_endless_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	# Setup buttons for Single Player and Multiplayer modes
	endless_btn.disabled = false
	endless_btn.modulate = Color.WHITE
	
	var race_lbl = race_btn.get_node_or_null("Label")
	if race_lbl:
		race_lbl.text = "Single Player"
		
	var endless_lbl = endless_btn.get_node_or_null("Label")
	if endless_lbl:
		endless_lbl.text = "Multiplayer"

	_apply_button_hover(race_btn)
	_apply_button_hover(endless_btn)
	_apply_button_hover(close_btn)

func _apply_button_hover(btn: TextureButton):
	if btn.disabled:
		return
		
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	if btn.pivot_offset == Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0
	
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

func _animate_in():
	overlay.modulate.a = 0
	content.scale = Vector2(0.8, 0.8)
	content.modulate.a = 0
	
	var tween = create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(content, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, 0.3)

func _on_close_pressed():
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)

func _on_race_pressed():
	# Transition to game (Single Player Mode)
	_start_game("singleplayer")

func _on_endless_pressed():
	# Transition to game (Multiplayer Mode)
	_start_game("multiplayer")

func _start_game(mode: String):
	print("Starting game mode: ", mode)
	
	# Pass mode to GameConfig
	if ResourceLoader.has_cached("res://scenes/shared_scripts/game_config.gd"):
		GameConfig.game_mode = mode
	
	AudioManager.stop_music()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): 
		var error = get_tree().change_scene_to_file("res://scenes/main/main.tscn")
		if error != OK:
			print("Error loading game scene: ", error)
	)
