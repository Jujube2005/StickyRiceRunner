extends Control
# =============================================================================
# CreditsMenu — Scrolling credits scene
# Opens as an overlay on top of MainMenu
# =============================================================================

const FONT_BOLD    = "res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf"
const FONT_REGULAR = "res://assets/textures/UI/Font/Mitr/Mitr-Regular.ttf"

const CREDITS_TEXT = """[center][b]CREDITS[/b][/center]


[center][b]VISUAL EFFECTS SYSTEM[/b][/center]
[center]Marinho
(MIT License)[/center]

[center]Brackeys VFX Bundle
Brackeys[/center]


[center][b]PARTICLE SYSTEM[/b][/center]
[center]Godot Visual Effects Repository
https://github.com/marinho/godot-visual-effects[/center]


[center][b]ADDITIONAL EFFECTS / TEXTURES[/b][/center]
[center]Godot Visual Effects Repository
https://github.com/marinho/godot-visual-effects[/center]


[center][b]UI DESIGN[/b][/center]
[center]CraftPix
https://craftpix.net[/center]


[center][b]3D MODELING[/b][/center]

[center][b]Props & Environment[/b][/center]
[center]Random Box — Multipainkiller Studio
Balloon — eventdesignws
Ambulance — eventdesignws
Speakers — eventdesignws
Hurdle — kennedynikki4
Rock — azzajess
Big Rock — Andrei.D
Firewood — Igor Snitzer
Street Food — chongdashu
Metal Garbage Bin — Alexander Korn
Catawba Earthenware Jar — RLA Archaeology[/center]

[center][b]Environment Structures[/b][/center]
[center]Ruined Ancient Temple (Khmer Architecture A 05) — Mega 3D
House (Korat) — nuichanida
Old Spirit House — Whatpixneyh
Isan Thai House (Hernkeay) — suchartstudio[/center]

[center][b]Nature Assets[/b][/center]
[center]Banana Tree — Robi pabianto
Jungle Tree — KirillSeO
Water Buffalo — kenchoo
Haystack — ljungman
Haystack — Spacyy[/center]


[center][b]SPECIAL THANKS[/b][/center]
[center]All asset creators
Open-source contributors
Indie game development community[/center]


[center][b]DISCLAIMER[/b][/center]
[center]All assets are used under their respective licenses
(MIT / CC0 / free distribution).
Please respect original creators.[/center]


[center][color=gold][b]THANK YOU FOR PLAYING[/b][/color][/center]
"""

# Scroll speed (pixels per second)
const SCROLL_SPEED: float = 60.0

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var credits_label: RichTextLabel      = $ScrollContainer/CreditsLabel
@onready var close_btn: TextureButton          = $CloseBtn
@onready var overlay_bg: ColorRect             = $OverlayBg

var _scrolling: bool = true
var _scroll_target: float = 0.0

func _ready() -> void:
	# Fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

	# Set up fonts
	credits_label.add_theme_font_override("normal_font", load(FONT_REGULAR))
	credits_label.add_theme_font_override("bold_font", load(FONT_BOLD))
	credits_label.add_theme_font_size_override("normal_font_size", 18)
	credits_label.add_theme_font_size_override("bold_font_size", 22)
	credits_label.add_theme_color_override("default_color", Color.WHITE)
	credits_label.bbcode_enabled = true
	credits_label.text = CREDITS_TEXT
	credits_label.fit_content = true

	# Start scroll from top
	scroll_container.scroll_vertical = 0
	_scroll_target = 0.0

	# Close button
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_on_close_pressed)
	close_btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(close_btn, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK)
	)
	close_btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(close_btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK)
	)

func _process(delta: float) -> void:
	if not _scrolling:
		return
	_scroll_target += SCROLL_SPEED * delta
	scroll_container.scroll_vertical = int(_scroll_target)

	# Auto-stop at the bottom
	var max_scroll = max(0, credits_label.get_combined_minimum_size().y - scroll_container.size.y)
	if _scroll_target >= max_scroll:
		_scrolling = false

func _input(event: InputEvent) -> void:
	# Allow manual drag / wheel
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scrolling = false  # Stop auto-scroll when user scrolls manually
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_on_close_pressed()

func _on_close_pressed() -> void:
	_scrolling = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
