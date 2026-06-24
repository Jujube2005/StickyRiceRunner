extends Control
# =============================================================================
# OpeningCutscene — openscene1 → openscene6 with smooth zoom-in
# On finish: transitions to IntroductionCutscene
# Skip: press Enter, Space, or Escape
# =============================================================================

const NEXT_SCENE = "res://cutscene/intro_cutscene.tscn"

const OPENING_IMAGES: Array[String] = [
	"res://cutscene/opening/openscene1.png",
	"res://cutscene/opening/openscene2.png",
	"res://cutscene/opening/openscene3.png",
	"res://cutscene/opening/openscene4.png",
]

# Duration each panel is shown (seconds)
const PANEL_DURATION: float = 3.0
# Zoom scale reached by end of each panel
const PANEL_ZOOM: float = 1.08
# Fade duration between panels
const FADE_DURATION: float = 3.2

@onready var image_rect: TextureRect     = $ImageRect
@onready var overlay: ColorRect          = $Overlay
@onready var skip_label: Label           = $SkipLabel
@onready var cutscene_player_node: Node  = $CutscenePlayerNode

var _player: Node  # CutscenePlayer instance

func _ready() -> void:
	# Instantiate the CutscenePlayer script onto the helper node
	var cp_script = load("res://cutscene/cutscene_player.gd")
	_player = cp_script.new()
	_player.name = "CutscenePlayer"
	add_child(_player)

	# Build the timeline
	_player.setup(image_rect, overlay, null, null, null, null)

	# Start fully black
	overlay.color = Color(0, 0, 0, 1.0)
	overlay.visible = true

	skip_label.text = "Press Enter / Space to skip"
	skip_label.visible = true

	var timeline: Array[Dictionary] = []
	timeline.append({ "action": "play_music", "music_name": "musicMainMenu" })

	timeline.append({
		"action": "fade_in",
		"duration": 0.5
	})

	for i in OPENING_IMAGES.size():
		if i == 0:
			timeline.append({
				"action": "show_image",
				"path": OPENING_IMAGES[i],
				"duration": PANEL_DURATION,
				"zoom": PANEL_ZOOM
			})
		else:
			timeline.append({
				"action": "brush_wipe_image",
				"path": OPENING_IMAGES[i],
				"duration": PANEL_DURATION,
				"fade_time": FADE_DURATION,
				"zoom": PANEL_ZOOM
			})

	timeline.append({
		"action": "fade_out",
		"duration": 0.5
	})

	_player.finished.connect(_on_cutscene_finished)
	_player.play_timeline(timeline)

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
	# Fade to black then change scene
	overlay.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(NEXT_SCENE)
