extends Control
# =============================================================================
# IntroductionCutscene — Backdrop → Man intro → Woman intro with dialogue
# On finish: transitions to Main Menu
# Skip: press Enter, Space, or Escape
# =============================================================================

const NEXT_SCENE = "res://scenes/main_menu/main_menu.tscn"

const PATH_BACKDROP  = "res://cutscene/opening/openscene5.png"
const PATH_MAN       = "res://cutscene/characters/man/man_intro.png"
const PATH_WOMAN     = "res://cutscene/characters/woman/woman_intro.png"
const PATH_NAME_MAN  = "res://cutscene/opening/name_man.png"
const PATH_NAME_WOMAN = "res://cutscene/opening/name_woman.png"

@onready var image_rect: TextureRect        = $BackdropRect
@onready var char_left: TextureRect         = $CharLeft
@onready var char_right: TextureRect        = $CharRight
@onready var overlay: ColorRect             = $Overlay
@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var dialogue_label: RichTextLabel  = $DialoguePanel/VBox/DialogueText
@onready var speaker_label: Label           = $DialoguePanel/VBox/SpeakerName
@onready var skip_label: Label              = $SkipLabel
@onready var tap_hint: Label                = $TapHint
@onready var name_overlay: TextureRect      = $NameOverlay

var _player: Node
var _waiting_for_tap: bool = false

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	# Center the characters and make them huge
	char_left.set_anchors_preset(PRESET_FULL_RECT)
	char_left.offset_left = 0
	char_left.offset_top = 0
	char_left.offset_right = 0
	char_left.offset_bottom = 0
	char_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	char_right.set_anchors_preset(PRESET_FULL_RECT)
	char_right.offset_left = 0
	char_right.offset_top = 0
	char_right.offset_right = 0
	char_right.offset_bottom = 0
	char_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# speaker_label stays inside DialoguePanel (not repositioned)
	speaker_label.visible = false
	name_overlay.visible = false

	var cp_script = load("res://cutscene/cutscene_player.gd")
	_player = cp_script.new()
	_player.name = "CutscenePlayer"
	add_child(_player)

	_player.setup(image_rect, overlay, char_left, char_right, dialogue_panel, dialogue_label, speaker_label)

	# Initial state
	overlay.color    = Color(0, 0, 0, 1.0)
	overlay.visible  = true
	char_left.visible  = false
	char_right.visible = false
	dialogue_panel.visible = false
	tap_hint.visible = false
	skip_label.text  = "Press Enter / Space to skip"

	var timeline: Array[Dictionary] = _build_timeline()
	_player.finished.connect(_on_cutscene_finished)
	_player.custom_action.connect(_on_custom_action)
	_player.play_timeline(timeline)

# ─────────────────────────────────────────────────────────────
func _build_timeline() -> Array[Dictionary]:
	var t: Array[Dictionary] = []

	# 1. Fade in backdrop
	t.append({ "action": "fade_in",    "duration": 0.6 })
	t.append({ "action": "show_image", "path": PATH_BACKDROP, "duration": 0.8, "zoom": 1.0 })
	t.append({ "action": "wait",       "duration": 0.4 })

	# 2. Show Man
	t.append({ "action": "show_char", "path": PATH_MAN, "side": "left", "duration": 0.5 })
	t.append({ "action": "wait",      "duration": 0.2 })

	# 3. Show Man's name with brush wipe
	t.append({ "action": "show_name_image", "path": PATH_NAME_MAN })
	t.append({ "action": "wait", "duration": 2.5 })

	# 4. Hide name + Man
	t.append({ "action": "hide_name_image" })
	t.append({ "action": "wait", "duration": 0.3 })
	t.append({ "action": "hide_char", "side": "left" })
	t.append({ "action": "wait", "duration": 0.5 })

	# 5. Show Woman
	t.append({ "action": "show_char", "path": PATH_WOMAN, "side": "right", "duration": 0.5 })
	t.append({ "action": "wait", "duration": 0.2 })

	# 6. Show Woman's name with brush wipe
	t.append({ "action": "show_name_image", "path": PATH_NAME_WOMAN })
	t.append({ "action": "wait", "duration": 2.5 })

	# 7. Hide name + Woman
	t.append({ "action": "hide_name_image" })
	t.append({ "action": "wait", "duration": 0.3 })
	t.append({ "action": "hide_char", "side": "right" })
	t.append({ "action": "wait", "duration": 0.5 })

	# 8. Fade out
	t.append({ "action": "fade_out", "duration": 0.8 })

	return t

# ─────────────────────────────────────────────────────────────
# Show name image with brush wipe effect
func _show_name_with_brush(path: String) -> void:
	if not name_overlay:
		return
	if ResourceLoader.exists(path):
		name_overlay.texture = load(path)
	name_overlay.modulate.a = 1.0
	name_overlay.scale = Vector2.ONE
	name_overlay.visible = true

	var mat = ShaderMaterial.new()
	mat.shader = load("res://cutscene/brush_wipe.gdshader")
	mat.set_shader_parameter("cutoff", 0.0)
	name_overlay.material = mat

	var tween = create_tween()
	var update_shader = func(val: float):
		if mat:
			mat.set_shader_parameter("cutoff", val)
	tween.tween_method(update_shader, 0.0, 1.0, 1.8)
	await tween.finished
	name_overlay.material = null

# Handle custom actions from CutscenePlayer
func _on_custom_action(action: Dictionary) -> void:
	match action.get("action", ""):
		"show_name_image":
			_show_name_with_brush(action.get("path", ""))
		"hide_name_image":
			if name_overlay:
				var tween = create_tween()
				tween.tween_property(name_overlay, "modulate:a", 0.0, 0.4)
				await tween.finished
				name_overlay.visible = false
				name_overlay.modulate.a = 1.0

# ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_skip()
	if event is InputEventMouseButton and event.pressed:
		_skip()

func _skip() -> void:
	if _player:
		_player.request_skip()

func _on_cutscene_finished() -> void:
	overlay.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.6)
	await tween.finished
	get_tree().change_scene_to_file(NEXT_SCENE)
