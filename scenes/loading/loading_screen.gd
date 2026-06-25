extends Control

# ============================================================
# Loading Screen with Shader Prewarming
# Instantiates all heavy scenes off-screen so the GPU compiles
# their shaders before gameplay begins → eliminates stutter.
# ============================================================

const NEXT_SCENE := "res://cutscene/opening_cutscene.tscn"

# All scenes that contain unique materials / shaders
const PREWARM_SCENES: Array[String] = [
	"res://scenes/ground/ground_zone1.tscn",
	"res://scenes/ground/ground_zone2.tscn",
	"res://scenes/ground/ground_zone3.tscn",
	"res://scenes/ground/ground_zone4.tscn",
	"res://scenes/obstacle/obstacle.tscn",
	"res://scenes/obstacle/obstacle_zone2.tscn",
	"res://scenes/obstacle/obstacle_zone3.tscn",
	"res://scenes/obstacle/obstacle_zone4.tscn",
	"res://scenes/player/players.tscn",
	"res://scenes/kratip/kratip.tscn",
	"res://scenes/skill_item/skill_item.tscn",
]

# Frames to keep each instance visible so GPU can compile shaders
const PREWARM_FRAMES := 3

@onready var progress_bar   : ProgressBar = $VBox/ProgressBar
@onready var status_label   : Label       = $VBox/StatusLabel
@onready var logo           : TextureRect = $Logo
@onready var fade_overlay   : ColorRect   = $FadeOverlay
@onready var tip_label      : Label       = $VBox/TipLabel

var _prewarm_root : Node3D
var _total   := 0
var _done    := 0
var _loading := false

const TIPS := [
	"กด S หรือ ↓ เพื่อสไลด์",
	"เก็บข้าวเหนียวเพื่อเพิ่มคะแนน",
	"สกิลจะเกิดขึ้นทุกๆ 3-5 วินาที",
	"ด่านที่ 4 ยาวที่สุดและยากที่สุด!",
	"วิ่งชนะถึงระยะ 2000 เมตรเพื่อชนะ",
]

func _ready():
	_total = PREWARM_SCENES.size()
	progress_bar.max_value = _total
	progress_bar.value = 0
	status_label.text = "กำลังโหลด..."
	tip_label.text = "💡 " + TIPS[randi() % TIPS.size()]

	# Fade in
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.6)
	await tween.finished

	# Wait a frame then start prewarming
	await get_tree().process_frame
	_start_prewarm()

func _start_prewarm():
	_loading = true

	# Create an offscreen SubViewport to render into (won't show on screen)
	_prewarm_root = Node3D.new()
	_prewarm_root.position = Vector3(0, -9999, 0)   # far below the world
	add_child(_prewarm_root)

	for i in range(PREWARM_SCENES.size()):
		var path = PREWARM_SCENES[i]
		status_label.text = "กำลังโหลด... (%d/%d)" % [i + 1, _total]

		if ResourceLoader.exists(path):
			var packed = load(path)
			if packed is PackedScene:
				var inst = packed.instantiate()
				_prewarm_root.add_child(inst)

		# Wait a few frames so GPU has time to compile shaders
		for _f in range(PREWARM_FRAMES):
			await get_tree().process_frame

		_done = i + 1
		progress_bar.value = _done

	status_label.text = "พร้อมแล้ว! ✓"

	# Clean up prewarm instances
	_prewarm_root.queue_free()

	await get_tree().create_timer(0.4).timeout
	_go_to_next_scene()

func _go_to_next_scene():
	# Fade out then change scene
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(NEXT_SCENE)
