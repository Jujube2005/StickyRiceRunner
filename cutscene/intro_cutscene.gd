extends Control
# =============================================================================
# IntroductionCutscene — Backdrop → Man intro → Woman intro with dialogue
# On finish: transitions to Main Menu
# Skip: press Enter, Space, or Escape
# =============================================================================

const NEXT_SCENE = "res://scenes/main_menu/main_menu.tscn"

const PATH_BACKDROP = "res://cutscene/opening/openscene7.png"
const PATH_MAN      = "res://cutscene/characters/man/man_intro.png"
const PATH_WOMAN    = "res://cutscene/characters/woman/woman_intro.png"

@onready var image_rect: TextureRect        = $BackdropRect
@onready var char_left: TextureRect         = $CharLeft
@onready var char_right: TextureRect        = $CharRight
@onready var overlay: ColorRect             = $Overlay
@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var dialogue_label: RichTextLabel  = $DialoguePanel/VBox/DialogueText
@onready var speaker_label: Label           = $DialoguePanel/VBox/SpeakerName
@onready var skip_label: Label              = $SkipLabel
@onready var tap_hint: Label                = $TapHint

var _player: Node
var _waiting_for_tap: bool = false

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
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
	skip_label.text  = "กด Enter / Space เพื่อข้าม"

	var timeline: Array[Dictionary] = _build_timeline()
	_player.finished.connect(_on_cutscene_finished)
	_player.play_timeline(timeline)

# ─────────────────────────────────────────────────────────────
func _build_timeline() -> Array[Dictionary]:
	var t: Array[Dictionary] = []

	# 1. Fade in backdrop
	t.append({ "action": "fade_in",  "duration": 0.6 })
	t.append({ "action": "show_image", "path": PATH_BACKDROP, "duration": 0.8, "zoom": 1.0 })
	t.append({ "action": "wait", "duration": 0.5 })

	# 2. Show Man on LEFT
	t.append({ "action": "show_char", "path": PATH_MAN, "side": "left", "duration": 0.5 })
	t.append({ "action": "wait", "duration": 0.3 })
	t.append({ "action": "play_sfx", "sfx_name": "skill_ready" })

	# 3. Man's dialogue
	t.append({
		"action": "show_dialogue",
		"speaker": "สมชาย",
		"text_th": "สวัสดีครับ! ผมชื่อสมชาย นักวิ่งจากอีสาน\nวันนี้เราจะมาแข่งวิ่งกันที่งานบุญบั้งไฟครับ!",
		"text_en": "Hello! My name is Somchai, a runner from Isan.\nToday we race at the Boon Bang Fai Festival!"
	})
	t.append({ "action": "wait", "duration": 3.5 })
	t.append({ "action": "hide_dialogue" })
	t.append({ "action": "wait", "duration": 0.3 })

	# 4. Hide Man
	t.append({ "action": "hide_char", "side": "left" })
	t.append({ "action": "wait", "duration": 0.5 })

	# 5. Show Woman on RIGHT
	t.append({ "action": "show_char", "path": PATH_WOMAN, "side": "right", "duration": 0.5 })
	t.append({ "action": "wait", "duration": 0.3 })
	t.append({ "action": "play_sfx", "sfx_name": "skill_ready" })

	# 6. Woman's dialogue
	t.append({
		"action": "show_dialogue",
		"speaker": "สมหญิง",
		"text_th": "สวัสดีค่ะ! ฉันชื่อสมหญิง ชาวนาจากทุ่งกว้าง\nมาพิสูจน์ความเร็วของเราสิ!",
		"text_en": "Hello! I'm Somying, a farmer from the open fields.\nLet's prove our speed!"
	})
	t.append({ "action": "wait", "duration": 3.5 })
	t.append({ "action": "hide_dialogue" })
	t.append({ "action": "wait", "duration": 0.3 })

	# 7. Hide Woman
	t.append({ "action": "hide_char", "side": "right" })
	t.append({ "action": "wait", "duration": 0.5 })

	# 8. Fade out → done
	t.append({ "action": "fade_out", "duration": 0.8 })

	return t

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
