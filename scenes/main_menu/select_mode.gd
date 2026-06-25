extends Control

# ─── State ───────────────────────────────────────────
enum Step { PLAYER_MODE, GAME_MODE }
var current_step := Step.PLAYER_MODE
var chosen_player_mode := ""  # "singleplayer" or "multiplayer"

# ─── Step 1 nodes ────────────────────────────────────
@onready var overlay = $Overlay
@onready var content = $Content
@onready var close_btn = %CloseBtn
@onready var prew_btn = %PrewBtn

# Step 1 — existing buttons repurposed
@onready var race_btn = %RaceBtn    # → Single Player
@onready var endless_btn = %EndlessBtn  # → Multiplayer

# Step 2 — created at runtime
var step2_container : Control = null
var header_label : Label = null
var _modes_default_x: float = 0.0

func _ready():
	var modes_node = content.find_child("Modes", true, false)
	if modes_node:
		_modes_default_x = modes_node.position.x

	_setup_step1()
	_animate_in()
	close_btn.pressed.connect(_on_close_pressed)
	prew_btn.pressed.connect(_go_back_to_step1)

# ────────────────────────────────────────────────────
# STEP 1: Choose Player Mode
# ────────────────────────────────────────────────────
func _setup_step1():
	# Relabel buttons
	var race_lbl = race_btn.get_node_or_null("Label")
	if race_lbl:
		race_lbl.text = "1 Player"

	var endless_lbl = endless_btn.get_node_or_null("Label")
	if endless_lbl:
		endless_lbl.text = "2 Players"

	endless_btn.disabled = false
	endless_btn.modulate = Color.WHITE

	# Update header
	header_label = content.find_child("Label", true, false)
	if header_label:
		header_label.text = "PLAYER MODE"

	race_btn.pressed.connect(_on_player_mode_selected.bind("singleplayer"))
	endless_btn.pressed.connect(_on_player_mode_selected.bind("multiplayer"))

	_apply_button_hover(race_btn)
	_apply_button_hover(endless_btn)
	_apply_button_hover(close_btn)
	_apply_button_hover(prew_btn)

func _on_player_mode_selected(mode: String):
	chosen_player_mode = mode
	_transition_to_step2()

# ────────────────────────────────────────────────────
# STEP 2: Choose Game Mode (Race / Endless)
# ────────────────────────────────────────────────────
func _transition_to_step2():
	current_step = Step.GAME_MODE
	prew_btn.visible = true

	# Animate Step 1 out (slide left)
	var modes_node = content.find_child("Modes", true, false)
	if modes_node:
		var out_tween = create_tween()
		out_tween.tween_property(modes_node, "position:x", _modes_default_x - 500.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		out_tween.parallel().tween_property(modes_node, "modulate:a", 0.0, 0.18)
		await out_tween.finished
		modes_node.visible = false
		modes_node.modulate.a = 1.0
		modes_node.position.x = _modes_default_x

	# Update header
	if header_label:
		if chosen_player_mode == "singleplayer":
			header_label.text = "GAME MODE"
		else:
			header_label.text = "GAME MODE"

	_build_step2_buttons()

func _build_step2_buttons():
	var modes_node = content.find_child("Modes", true, false)
	if !modes_node:
		return

	if is_instance_valid(race_btn) and race_btn.get_parent() == modes_node:
		modes_node.remove_child(race_btn)
	if is_instance_valid(endless_btn) and endless_btn.get_parent() == modes_node:
		modes_node.remove_child(endless_btn)

	for child in modes_node.get_children():
		child.queue_free()

	await get_tree().process_frame

	# ── Race button ──
	var race2 = _make_mode_button("Race\nMode", "🏁")
	modes_node.add_child(race2)
	race2.pressed.connect(_start_game.bind("race"))
	_apply_button_hover(race2)

	# ── Endless Survival Battle button — 2 Players only ──
	if chosen_player_mode == "multiplayer":
		var endless2 = _make_mode_button("Endless\nSurvival\nBattle", "♾️")
		modes_node.add_child(endless2)
		endless2.pressed.connect(_start_game.bind("endless"))
		_apply_button_hover(endless2)


	# Animate Step 2 in (slide from right)
	modes_node.position.x = _modes_default_x + 500.0
	modes_node.modulate.a = 0.0
	modes_node.visible = true

	var in_tween = create_tween()
	in_tween.tween_property(modes_node, "position:x", _modes_default_x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	in_tween.parallel().tween_property(modes_node, "modulate:a", 1.0, 0.2)

func _make_mode_button(label_text: String, _icon: String) -> TextureButton:
	var font_res = load("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")
	var popup_tex = load("res://assets/textures/UI/Buttons/popup_paused.png")
	var play_tex  = load("res://assets/textures/UI/Buttons/btn_play.png")

	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(320, 320)
	btn.texture_normal = popup_tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE

	# Text label — perfectly centered horizontally
	var text_lbl = Label.new()
	text_lbl.text = label_text
	text_lbl.anchor_left  = 0.5; text_lbl.anchor_right  = 0.5
	text_lbl.anchor_top   = 0.5; text_lbl.anchor_bottom = 0.5
	text_lbl.offset_left  = -150; text_lbl.offset_right  = 150
	text_lbl.offset_top   = -107; text_lbl.offset_bottom =  19
	text_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text_lbl.grow_vertical   = Control.GROW_DIRECTION_BOTH
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	if font_res:
		text_lbl.add_theme_font_override("font", font_res)
	text_lbl.add_theme_font_size_override("font_size", 46)
	text_lbl.add_theme_color_override("font_color", Color(0.99, 0.96, 0.89, 1))
	text_lbl.add_theme_color_override("font_outline_color", Color(0.29, 0.16, 0.07, 1))
	text_lbl.add_theme_constant_override("outline_size", 18)
	text_lbl.add_theme_constant_override("line_spacing", -20)
	btn.add_child(text_lbl)

	# Play icon — perfectly centered horizontally
	var play_icon = TextureRect.new()
	play_icon.texture = play_tex
	play_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	play_icon.stretch_mode = TextureRect.STRETCH_SCALE
	play_icon.anchor_left  = 0.5; play_icon.anchor_right  = 0.5
	play_icon.anchor_top   = 1.0; play_icon.anchor_bottom = 1.0
	play_icon.offset_left  = -50; play_icon.offset_right  =  50
	play_icon.offset_top   = -112; play_icon.offset_bottom = -12
	play_icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	play_icon.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	play_icon.scale = Vector2(0.771, 0.771)
	btn.add_child(play_icon)

	return btn

func _go_back_to_step1():
	chosen_player_mode = ""
	current_step = Step.PLAYER_MODE
	prew_btn.visible = false

	var modes_node = content.find_child("Modes", true, false)
	if modes_node:
		# Slide out right
		var out_tween = create_tween()
		out_tween.tween_property(modes_node, "position:x", _modes_default_x + 500.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		out_tween.parallel().tween_property(modes_node, "modulate:a", 0.0, 0.15)
		await out_tween.finished

		# Clear step2 buttons
		for child in modes_node.get_children():
			child.queue_free()
		await get_tree().process_frame

		# Restore step1 buttons
		modes_node.add_child(race_btn)
		modes_node.add_child(endless_btn)

		if header_label:
			header_label.text = "PLAYER MODE"

		# Slide back in from left
		modes_node.position.x = _modes_default_x - 500.0
		modes_node.modulate.a = 0.0
		modes_node.visible = true
		var in_tween = create_tween()
		in_tween.tween_property(modes_node, "position:x", _modes_default_x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		in_tween.parallel().tween_property(modes_node, "modulate:a", 1.0, 0.2)

# ────────────────────────────────────────────────────
# HELPERS
# ────────────────────────────────────────────────────
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

func _start_game(game_mode_type: String):
	print("Player mode: ", chosen_player_mode, " | Game mode: ", game_mode_type)

	# Store both in GameConfig
	GameConfig.game_mode = chosen_player_mode  # "singleplayer" or "multiplayer"
	GameConfig.race_mode = game_mode_type       # "race" or "endless"

	AudioManager.stop_music()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		var error = get_tree().change_scene_to_file("res://scenes/main/main.tscn")
		if error != OK:
			print("Error loading game scene: ", error)
	)
