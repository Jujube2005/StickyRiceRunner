extends Control

# --- ASSETS ---
const TEX_SWITCH_ON = preload("res://assets/textures/UI/Buttons/switch_on.png")
const TEX_SWITCH_OFF = preload("res://assets/textures/UI/Buttons/switch_off.png")
const TEX_SLIDER_TRACK = preload("res://assets/textures/UI/Buttons/HSliderTrac.png")
const TEX_SLIDER_GRABBER = preload("res://assets/textures/UI/Buttons/HSliderGrabber.png")
const TEX_BTN_ORANGE = preload("res://assets/textures/UI/Buttons/buttonOrange.png")
const TEX_BTN_YELLOW = preload("res://assets/textures/UI/Buttons/buttonYellow.png")

# --- NODES ---
@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider
@onready var fullscreen_switch = %FullscreenSwitch
@onready var lang_btn = %LangBtn
@onready var back_btn = %BackBtn
@onready var ok_btn = %OkBtn
@onready var panel = $Panel
@onready var overlay = $Overlay

func _ready():
	_setup_visuals()
	_load_current_settings()
	_animate_in()
	
	# Connect Signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_switch.toggled.connect(_on_fullscreen_toggled)
	lang_btn.item_selected.connect(_on_lang_selected)
	back_btn.pressed.connect(_on_close_pressed)
	ok_btn.pressed.connect(_on_close_pressed)

func _setup_visuals():
	# Setup Sliders Style
	for slider in [master_slider, music_slider, sfx_slider]:
		var style_track = StyleBoxTexture.new()
		style_track.texture = TEX_SLIDER_TRACK
		# Make the track thick as per Figma
		style_track.expand_margin_top = 20
		style_track.expand_margin_bottom = 20
		
		# Set the slider stylebox
		slider.add_theme_stylebox_override("slider", style_track)
		slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new()) # Hide the default grabber area
		slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
		
		# Add grabber icons
		slider.add_theme_icon_override("grabber", TEX_SLIDER_GRABBER)
		slider.add_theme_icon_override("grabber_highlight", TEX_SLIDER_GRABBER)
	
	# Setup Switch Initial Image
	_update_switch_visual(fullscreen_switch.button_pressed)
	
	# Setup Labels 
	for hbox in $Panel/Content.get_children():
		var label_btn = hbox.get_node("Label")
		if label_btn:
			var style = StyleBoxTexture.new()
			style.texture = TEX_BTN_ORANGE
			style.content_margin_left = 25
			style.content_margin_right = 25
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			label_btn.add_theme_stylebox_override("normal", style)
			label_btn.add_theme_stylebox_override("hover", style)
			label_btn.add_theme_stylebox_override("pressed", style)
			label_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var lang_style = StyleBoxTexture.new()
	lang_style.texture = TEX_BTN_ORANGE
	lang_style.content_margin_left = 20
	lang_style.content_margin_right = 40
	lang_btn.add_theme_stylebox_override("normal", lang_style)
	lang_btn.add_theme_stylebox_override("hover", lang_style)
	lang_btn.add_theme_stylebox_override("pressed", lang_style)
	lang_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var empty_img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var empty_tex = ImageTexture.create_from_image(empty_img)
	lang_btn.add_theme_icon_override("arrow", empty_tex)
	
	# Dropdown Popup
	var popup = lang_btn.get_popup()
	var popup_style = StyleBoxTexture.new()
	popup_style.texture = TEX_BTN_ORANGE
	popup_style.modulate_color = Color(0.8, 0.8, 0.8) # Slightly darker for the list
	popup_style.content_margin_left = 10
	popup_style.content_margin_right = 10
	popup_style.content_margin_top = 10
	popup_style.content_margin_bottom = 10
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(1, 1, 1, 0.2)
	hover_style.corner_radius_top_left = 5
	hover_style.corner_radius_top_right = 5
	hover_style.corner_radius_bottom_left = 5
	hover_style.corner_radius_bottom_right = 5
	
	popup.add_theme_stylebox_override("panel", popup_style)
	popup.add_theme_stylebox_override("hover", hover_style)
	popup.add_theme_font_override("font", load("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf"))
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", Color.WHITE)
	popup.add_theme_color_override("font_hover_color", Color.YELLOW)
	popup.add_theme_constant_override("v_separation", 10)

func _load_current_settings():
	# Audio
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	# (Assuming you have Music and SFX buses, else fallback to Master)
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1: music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1: sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	
	# Fullscreen
	fullscreen_switch.button_pressed = ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))

func _update_switch_visual(is_on: bool):
	fullscreen_switch.texture_normal = TEX_SWITCH_ON if is_on else TEX_SWITCH_OFF

# --- SIGNAL HANDLERS ---
func _on_master_volume_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_volume_changed(value):
	var bus = AudioServer.get_bus_index("Music")
	if bus != -1: AudioServer.set_bus_volume_db(bus, linear_to_db(value))

func _on_sfx_volume_changed(value):
	var bus = AudioServer.get_bus_index("SFX")
	if bus != -1: AudioServer.set_bus_volume_db(bus, linear_to_db(value))

func _on_fullscreen_toggled(is_on: bool):
	_update_switch_visual(is_on)
	if is_on:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED

func _on_lang_selected(index: int):
	# Handle language change here
	print("Selected language index: ", index)
	# Example: TranslationServer.set_locale("th" if index == 0 else "en")

func _animate_in():
	overlay.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0
	
	var tween = create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _on_close_pressed():
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
