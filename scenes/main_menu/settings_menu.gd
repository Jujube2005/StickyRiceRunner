extends Control

# --- ASSETS ---
const TEX_SWITCH_ON   = preload("res://assets/textures/UI/Buttons/switch_on.png")
const TEX_SWITCH_OFF  = preload("res://assets/textures/UI/Buttons/switch_off.png")
const TEX_SLIDER_TRACK   = preload("res://assets/textures/UI/Buttons/HSliderTrac.png")
const TEX_SLIDER_RING    = preload("res://assets/textures/UI/Buttons/HSliderGrabber.png")
const TEX_SLIDER_COIN    = preload("res://assets/textures/UI/Buttons/HSliderIcon.png")
const TEX_BTN_ORANGE = preload("res://assets/textures/UI/Buttons/buttonOrange.png")
const TEX_BTN_BOX    = preload("res://assets/textures/UI/Buttons/box.png")
const TEX_BTN_LANG   = preload("res://assets/textures/UI/Buttons/btn_lang.png")
const TEX_BTN_LANG_DROP = preload("res://assets/textures/UI/Buttons/btn_lang_dropdown.png")
const TEX_CUR_USE    = preload("res://assets/textures/UI/Buttons/cur_use.png")
const TEX_NOT_USE    = preload("res://assets/textures/UI/Buttons/not_use.png")

# --- NODES ---
@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider
@onready var fullscreen_switch = %FullscreenSwitch
@onready var lang_btn = %LangBtn
@onready var back_btn = %BackBtn
@onready var audio_header = %AudioHeader
@onready var language_header = %LanguageHeader
@onready var display_header = %DisplayHeader
@onready var panel = $Panel
@onready var overlay = $Overlay

func _ready():
	_load_current_settings()
	_animate_in()
	_update_label_texts()
	
	# Connect Signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_switch.toggled.connect(_on_fullscreen_toggled)
	lang_btn.item_selected.connect(_on_lang_selected)
	back_btn.pressed.connect(_on_close_pressed)
	LanguageManager.language_changed.connect(func(_l): _update_label_texts())
	
	
	var empty_img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty_img.fill(Color(0, 0, 0, 0))
	var empty_tex = ImageTexture.create_from_image(empty_img)
	lang_btn.add_theme_icon_override("arrow", empty_tex)
	
	# Dropdown Popup
	get_tree().root.gui_embed_subwindows = true
	var popup = lang_btn.get_popup()
	popup.transparent = true
	popup.transparent_bg = true
	var popup_style = StyleBoxTexture.new()
	popup_style.texture = TEX_BTN_LANG_DROP
	popup_style.texture_margin_left = 10
	popup_style.texture_margin_right = 10
	popup_style.texture_margin_top = 10
	popup_style.texture_margin_bottom = 10
	popup_style.content_margin_left = 15
	popup_style.content_margin_right = 15
	popup_style.content_margin_top = 10
	popup_style.content_margin_bottom = 10
	
	var lang_btn_style = StyleBoxTexture.new()
	lang_btn_style.texture = TEX_BTN_LANG
	lang_btn_style.texture_margin_left = 10
	lang_btn_style.texture_margin_right = 10
	lang_btn_style.texture_margin_top = 10
	lang_btn_style.texture_margin_bottom = 10
	
	lang_btn.add_theme_stylebox_override("normal", lang_btn_style)
	lang_btn.add_theme_stylebox_override("pressed", lang_btn_style)
	lang_btn.add_theme_stylebox_override("hover", lang_btn_style)
	lang_btn.add_theme_stylebox_override("focus", lang_btn_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(1, 1, 1, 0.2)
	hover_style.corner_radius_top_left = 5
	hover_style.corner_radius_top_right = 5
	hover_style.corner_radius_bottom_left = 5
	hover_style.corner_radius_bottom_right = 5
	
	popup.add_theme_stylebox_override("panel", popup_style)
	popup.add_theme_stylebox_override("hover", hover_style)
	popup.add_theme_icon_override("radio_checked", TEX_CUR_USE)
	popup.add_theme_icon_override("radio_unchecked", TEX_NOT_USE)
	popup.add_theme_font_override("font", load("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf"))
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", Color.WHITE)
	popup.add_theme_color_override("font_hover_color", Color.YELLOW)
	popup.add_theme_constant_override("v_separation", 15)
	
	# Setup Switch Initial Image
	_update_switch_visual(fullscreen_switch.button_pressed)

func _load_current_settings():
	# Audio
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1: music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1: sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	
	# Fullscreen
	fullscreen_switch.button_pressed = ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))
	
	# Language dropdown
	lang_btn.selected = LanguageManager.get_lang_index()

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
	var locale = "en" if index == 0 else "th"
	LanguageManager.set_language(locale)

func _update_label_texts():
	# Section headers
	if audio_header:    audio_header.text    = "AUDIO"
	if language_header: language_header.text = "LANGUAGE"
	if display_header:  display_header.text  = "DISPLAY"
	
	# Row labels
	var content = %Content
	if !content: return
	var label_map = {
		"Master": "LBL_MASTER_VOL",
		"Music":  "LBL_MUSIC_VOL",
		"SFX":    "LBL_SFX_VOL",
		"Screen": "LBL_FULLSCREEN",
	}
	for row_name in label_map:
		var row = content.get_node_or_null(row_name)
		if row:
			var lbl = row.get_node_or_null("Label")
			if lbl:
				lbl.text = LanguageManager.t(label_map[row_name])

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
