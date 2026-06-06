extends Control

# --- NODES ---
@onready var background = $Background
@onready var logo = $Logo
@onready var menu_container = $MenuContainer
@onready var button_list = $MenuContainer/ButtonList
@onready var version_label = $VersionLabel

# --- ASSETS ---
const FONT_BOLD = "res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf"
const FONT_REGULAR = "res://assets/textures/UI/Font/Mitr/Mitr-Regular.ttf"

const TEX_BOX_MENU = "res://assets/textures/UI/Buttons/boxMenu.png"
const TEX_BTN_ORANGE = "res://assets/textures/UI/Buttons/buttonOrange.png"
const TEX_BTN_YELLOW = "res://assets/textures/UI/Buttons/buttonYellow.png"

func _ready():
	_setup_ui_styles()
	_animate_entrance()
	
	# Connect Signals
	$MenuContainer/ButtonList/PlayBtn.pressed.connect(_on_play_pressed)
	$MenuContainer/ButtonList/QuitBtn.pressed.connect(_on_quit_pressed)
	$MenuContainer/ButtonList/SettingsBtn.pressed.connect(_on_settings_pressed)
	$MenuContainer/ButtonList/HowToBtn.pressed.connect(_on_how_to_pressed)

func _setup_ui_styles():
	# Ensure Logo does not block mouse clicks even if it overlaps
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Font for Version Label
	version_label.label_settings = LabelSettings.new()
	version_label.label_settings.font = load(FONT_REGULAR)
	version_label.label_settings.font_size = 14
	version_label.label_settings.font_color = Color(1, 1, 1, 0.6)
	
	# Setup Menu Container Style using boxMenu.png
	var menu_style = StyleBoxTexture.new()
	menu_style.texture = load(TEX_BOX_MENU)
	# Set margins for 9-patch scaling if needed, otherwise keep default
	menu_style.content_margin_left = 30
	menu_style.content_margin_right = 30
	menu_style.content_margin_top = 30
	menu_style.content_margin_bottom = 30
	menu_container.add_theme_stylebox_override("panel", menu_style)
	
	# Button Styles
	for btn in button_list.get_children():
		if btn is Button:
			_apply_button_theme(btn)

func _apply_button_theme(btn: Button):
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", load(FONT_BOLD))
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.8))
	
	# Style Normal (Orange)
	var style_normal = StyleBoxTexture.new()
	style_normal.texture = load(TEX_BTN_ORANGE)
	
	# Style Hover (Yellow)
	var style_hover = StyleBoxTexture.new()
	style_hover.texture = load(TEX_BTN_YELLOW)
	
	# Style Pressed (Slightly darker/shifted)
	var style_pressed = style_normal.duplicate()
	style_pressed.modulate_color = Color(0.8, 0.8, 0.8)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	btn.mouse_entered.connect(func(): _animate_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _animate_button_hover(btn, false))

# --- ANIMATIONS ---
func _animate_entrance():
	# Fade in logo and slide
	var logo_final_pos = logo.position
	logo.modulate.a = 0
	logo.position.y -= 20
	var tween = create_tween().set_parallel()
	tween.tween_property(logo, "modulate:a", 1.0, 0.8)
	tween.tween_property(logo, "position", logo_final_pos, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Slide menu box
	var menu_final_pos = menu_container.position
	menu_container.position.x = -300
	var tween_menu = create_tween()
	tween_menu.tween_property(menu_container, "position", menu_final_pos, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(0.3)

func _animate_button_hover(btn: Button, is_hover: bool):
	var tween = create_tween()
	if is_hover:
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.2)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

# --- CALLBACKS ---
func _on_play_pressed():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main/main.tscn"))

func _on_settings_pressed():
	var settings_scene = load("res://scenes/main_menu/settings_menu.tscn")
	var settings_instance = settings_scene.instantiate()
	add_child(settings_instance)

func _on_how_to_pressed():
	print("How to clicked")

func _on_quit_pressed():
	get_tree().quit()
