extends Control


const TEX_SLIDER_TRACK = preload("res://assets/textures/UI/Buttons/HSliderTrac.png")
const TEX_SLIDER_RING = preload("res://assets/textures/UI/Buttons/HSliderGrabber.png")
const TEX_SLIDER_SILK = preload("res://assets/textures/UI/Buttons/HSliderIcon.png")

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
	
	var grabber_tex = GradientTexture2D.new()
	grabber_tex.width = 28
	grabber_tex.height = 28
	grabber_tex.fill = GradientTexture2D.FILL_RADIAL
	grabber_tex.fill_from = Vector2(0.5, 0.5)
	grabber_tex.fill_to = Vector2(0.95, 0.5)
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.8, 0.9, 1.0])
	grad.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,1), Color(1,1,1,0)])
	grabber_tex.gradient = grad

	master_slider.add_theme_icon_override("grabber", grabber_tex)
	master_slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	music_slider.add_theme_icon_override("grabber", grabber_tex)
	music_slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	sfx_slider.add_theme_icon_override("grabber", grabber_tex)
	sfx_slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	btn_ok.pressed.connect(_on_close_pressed)
	btn_close.pressed.connect(_on_menu_pressed)
	
	_setup_button_hover(btn_ok)
	_setup_button_hover(btn_close)

	_animate_in()

func _setup_visuals():
	pass

	
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
	music_slider.value = db_to_linear(AudioManager._music_volume_db)
	sfx_slider.value = db_to_linear(AudioManager._sfx_volume_db)


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
	AudioManager.set_music_volume(value)
	var bus = AudioServer.get_bus_index("Music")
	if bus != -1: AudioServer.set_bus_volume_db(bus, linear_to_db(value))

func _on_sfx_changed(value: float):
	AudioManager.set_sfx_volume(value)
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
