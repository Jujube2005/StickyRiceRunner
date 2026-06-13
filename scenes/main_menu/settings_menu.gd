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
@onready var settings_title = %SettingsTitle
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
	
	# Setup Switch Initial Image
	_update_switch_visual(fullscreen_switch.button_pressed)

func _load_current_settings():
	# Audio
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	music_slider.value = db_to_linear(AudioManager._music_volume_db)
	sfx_slider.value = db_to_linear(AudioManager._sfx_volume_db)
	
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
	AudioManager.set_music_volume(value)
	var bus = AudioServer.get_bus_index("Music")
	if bus != -1: AudioServer.set_bus_volume_db(bus, linear_to_db(value))

func _on_sfx_volume_changed(value):
	AudioManager.set_sfx_volume(value)
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
var _dropdown_canvas: CanvasLayer
var opt_eng: MarginContainer
var opt_thai: MarginContainer

func _setup_custom_language_dropdown():
	var parent = lang_btn.get_parent()
	
	# ---- Main Button ----
	custom_lang_btn = TextureButton.new()
	custom_lang_btn.texture_normal = TEX_BTN_LANG
	custom_lang_btn.ignore_texture_size = true
	custom_lang_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	custom_lang_btn.custom_minimum_size = Vector2(120, 40)
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
	main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_lang_btn.add_child(main_lbl)
	
	# ---- Dropdown Panel on CanvasLayer (always on top, not clipped) ----
	_dropdown_canvas = CanvasLayer.new()
	_dropdown_canvas.layer = 200
	add_child(_dropdown_canvas)
	
	var dropdown_panel = TextureRect.new()
	dropdown_panel.name = "DropdownPanel"
	dropdown_panel.texture = TEX_BTN_LANG_DROP
	dropdown_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dropdown_panel.stretch_mode = TextureRect.STRETCH_SCALE
	dropdown_panel.size = Vector2(130, 90)
	dropdown_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dropdown_panel.hide()
	_dropdown_canvas.add_child(dropdown_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	dropdown_panel.add_child(vbox)
	
	opt_eng = _create_dropdown_option("ENG", 0, dropdown_panel)
	opt_thai = _create_dropdown_option("THAI", 1, dropdown_panel)
	vbox.add_child(opt_eng)
	vbox.add_child(opt_thai)
	
	_update_dropdown_visuals()
	
	# Toggle dropdown on button press
	custom_lang_btn.pressed.connect(func():
		var dp = _dropdown_canvas.get_node("DropdownPanel")
		if dp.visible:
			dp.hide()
		else:
			# Position below the main button in screen space
			var btn_rect = custom_lang_btn.get_global_rect()
			dp.global_position = Vector2(btn_rect.position.x, btn_rect.position.y + btn_rect.size.y + 4)
			dp.show()
	)

func _create_dropdown_option(text: String, index: int, dropdown_panel: TextureRect) -> MarginContainer:
	var container = MarginContainer.new()
	container.custom_minimum_size = Vector2(110, 36)
	container.add_theme_constant_override("margin_left", 12)
	container.add_theme_constant_override("margin_right", 12)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	container.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = TEX_NOT_USE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)
	
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.label_settings = LabelSettings.new()
	lbl.label_settings.font = load("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")
	lbl.label_settings.font_size = 18
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)
	
	# Transparent clickable overlay
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(btn)
	
	btn.pressed.connect(func():
		_on_lang_selected(index)
		dropdown_panel.hide()
		custom_lang_btn.get_node("MainLbl").text = text
		_update_dropdown_visuals()
	)
	return container

func _update_dropdown_visuals():
	if not opt_eng or not opt_thai:
		return
	var current_lang = LanguageManager.get_lang_index()
	opt_eng.get_node("HBoxContainer/Icon").texture = TEX_CUR_USE if current_lang == 0 else TEX_NOT_USE
	opt_thai.get_node("HBoxContainer/Icon").texture = TEX_CUR_USE if current_lang == 1 else TEX_NOT_USE

func _update_label_texts():
	# Title
	if settings_title: settings_title.text = LanguageManager.t("LBL_SETTINGS_TITLE")
	# Section headers
	if audio_header:    audio_header.text    = LanguageManager.t("HDR_AUDIO")
	if language_header: language_header.text = LanguageManager.t("HDR_LANGUAGE")
	if display_header:  display_header.text  = LanguageManager.t("HDR_DISPLAY")
	# Also update custom lang button label
	if custom_lang_btn and custom_lang_btn.has_node("MainLbl"):
		var idx = LanguageManager.get_lang_index()
		custom_lang_btn.get_node("MainLbl").text = "ENG" if idx == 0 else "THAI"
	
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
