extends Control

# --- ASSETS ---
const TEX_SWITCH_ON   = preload("res://assets/textures/UI/Buttons/switch_on.png")
const TEX_SWITCH_OFF  = preload("res://assets/textures/UI/Buttons/switch_off.png")
const TEX_SLIDER_TRACK   = preload("res://assets/textures/UI/Buttons/HSliderTrac.png")
const TEX_SLIDER_RING    = preload("res://assets/textures/UI/Buttons/HSliderGrabber.png")
const TEX_SLIDER_COIN    = preload("res://assets/textures/UI/Buttons/HSliderIcon.png")
const TEX_BTN_ORANGE = preload("res://assets/textures/UI/Buttons/buttonOrange.png")
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
	lang_btn.hide()
	_setup_custom_language_dropdown()
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

var custom_lang_btn: TextureButton
var custom_lang_dropdown: TextureRect
var opt_eng: MarginContainer
var opt_thai: MarginContainer

func _setup_custom_language_dropdown():
	var parent = lang_btn.get_parent()
	
	# Main Button
	custom_lang_btn = TextureButton.new()
	custom_lang_btn.texture_normal = TEX_BTN_LANG
	custom_lang_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(custom_lang_btn)
	
	var main_lbl = Label.new()
	main_lbl.name = "MainLbl"
	main_lbl.text = "ENG" if LanguageManager.get_lang_index() == 0 else "THAI"
	main_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_lbl.label_settings = LabelSettings.new()
	main_lbl.label_settings.font = load("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")
	main_lbl.label_settings.font_size = 18
	custom_lang_btn.add_child(main_lbl)
	
	# Dropdown Container
	custom_lang_dropdown = TextureRect.new()
	custom_lang_dropdown.texture = TEX_BTN_LANG_DROP
	custom_lang_dropdown.hide()
	# Position it below the main button
	custom_lang_dropdown.position = Vector2(0, custom_lang_btn.texture_normal.get_size().y + 5)
	custom_lang_dropdown.z_index = 100
	custom_lang_btn.add_child(custom_lang_dropdown)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	custom_lang_dropdown.add_child(vbox)
	
	# Option Buttons
	opt_eng = _create_dropdown_option("ENG", 0)
	opt_thai = _create_dropdown_option("THAI", 1)
	vbox.add_child(opt_eng)
	vbox.add_child(opt_thai)
	
	_update_dropdown_visuals()
	
	custom_lang_btn.pressed.connect(func():
		custom_lang_dropdown.visible = !custom_lang_dropdown.visible
	)

func _create_dropdown_option(text: String, index: int) -> MarginContainer:
	var container = MarginContainer.new()
	container.custom_minimum_size = Vector2(100, 30)
	container.add_theme_constant_override("margin_left", 10)
	container.add_theme_constant_override("margin_right", 10)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	container.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = TEX_NOT_USE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(icon)
	
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.label_settings = LabelSettings.new()
	lbl.label_settings.font = load("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")
	lbl.label_settings.font_size = 18
	hbox.add_child(lbl)
	
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(btn)
	
	btn.pressed.connect(func():
		_on_lang_selected(index)
		custom_lang_dropdown.hide()
		custom_lang_btn.get_node("MainLbl").text = text
		_update_dropdown_visuals()
	)
	return container

func _update_dropdown_visuals():
	var current_lang = LanguageManager.get_lang_index()
	opt_eng.get_node("HBoxContainer/Icon").texture = TEX_CUR_USE if current_lang == 0 else TEX_NOT_USE
	opt_thai.get_node("HBoxContainer/Icon").texture = TEX_CUR_USE if current_lang == 1 else TEX_NOT_USE

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
