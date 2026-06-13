extends Control


const TEX_SLIDER_TRACK = preload("res://assets/textures/UI/Buttons/HSliderTrac.png")
const TEX_SLIDER_RING = preload("res://assets/textures/UI/Buttons/HSliderGrabber.png")
const TEX_SLIDER_COIN = preload("res://assets/textures/UI/Buttons/HSliderIcon.png")

@onready var board_rect: TextureRect   = $Board
@onready var master_slider: HSlider    = $Board/Content/Master/MasterSlider
@onready var music_slider: HSlider     = $Board/Content/Music/MusicSlider
@onready var sfx_slider: HSlider       = $Board/Content/SFX/SFXSlider

@onready var btn_ok: TextureButton     = $Board/ButtonBox/BtnOk
@onready var btn_close: TextureButton  = $Board/ButtonBox/BtnClose

var default_scale: Vector2

func _ready():
	default_scale = board_rect.scale
	_setup_visuals()
	_load_settings()
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	btn_ok.pressed.connect(_on_close_pressed)
	btn_close.pressed.connect(_on_menu_pressed)
	
	_setup_button_hover(btn_ok)
	_setup_button_hover(btn_close)

	_animate_in()

func _setup_visuals():
	for slider in [master_slider, music_slider, sfx_slider]:
		var style_track = StyleBoxTexture.new()
		style_track.texture = TEX_SLIDER_TRACK
		style_track.expand_margin_top = 18.0
		style_track.expand_margin_bottom = 18.0
		
		var style_fill = StyleBoxTexture.new()
		style_fill.texture = TEX_SLIDER_RING
		style_fill.expand_margin_top = 14.0
		style_fill.expand_margin_bottom = 14.0
		
		slider.add_theme_stylebox_override("slider", style_track)
		slider.add_theme_stylebox_override("grabber_area", style_fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", style_fill)
		slider.add_theme_icon_override("grabber", TEX_SLIDER_COIN)
		slider.add_theme_icon_override("grabber_highlight", TEX_SLIDER_COIN)

	
func _setup_button_hover(btn: TextureButton):
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

func _load_settings():
	master_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	)
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))


func _animate_in():
	board_rect.scale = default_scale * 0.85
	board_rect.modulate.a = 0.0
	self.modulate.a = 0.0
	show()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(board_rect, "modulate:a", 1.0, 0.25)
	tween.tween_property(board_rect, "scale", default_scale, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_master_changed(value: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_changed(value: float):
	var bus = AudioServer.get_bus_index("Music")
	if bus != -1: AudioServer.set_bus_volume_db(bus, linear_to_db(value))

func _on_sfx_changed(value: float):
	var bus = AudioServer.get_bus_index("SFX")
	if bus != -1: AudioServer.set_bus_volume_db(bus, linear_to_db(value))


func _on_close_pressed():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(board_rect, "scale", default_scale * 0.85, 0.2)
	await tween.finished
	get_tree().paused = false
	queue_free()

func _on_menu_pressed():
	# Close the setting and change scene to Main Menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
