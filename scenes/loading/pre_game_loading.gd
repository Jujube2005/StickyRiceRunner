extends Control

# ============================================================
# Pre-Game Loading Screen
# Uses Godot's threaded ResourceLoader to load main.tscn in
# the background while showing a progress bar to the player.
# GameConfig.game_mode / race_mode must be set before this
# scene is entered.
# ============================================================

const GAME_SCENE := "res://scenes/main/main.tscn"

const TIPS := [
	"กด S หรือ ↓ เพื่อสไลด์",
	"เก็บข้าวเหนียวเพื่อเพิ่มคะแนน",
	"สกิลจะเกิดขึ้นทุกๆ 3-5 วินาที",
	"ด่านที่ 4 ยาวที่สุดและยากที่สุด!",
	"วิ่งชนะถึงระยะ 2000 เมตรเพื่อชนะ",
	"หลีกเลี่ยงสิ่งกีดขวางเพื่อรอดชีวิต",
	"ใช้สกิลให้เป็นประโยชน์ในช่วงวิกฤต",
]

@onready var progress_bar  : ProgressBar = $VBox/ProgressBar
@onready var status_label  : Label       = $VBox/StatusLabel
@onready var tip_label     : Label       = $VBox/TipLabel
@onready var logo          : TextureRect = $Logo
@onready var fade_overlay  : ColorRect   = $FadeOverlay

var _loading_done   := false
var _scene_resource : PackedScene = null

func _ready() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value     = 0.0
	status_label.text      = "กำลังโหลดเกม..."
	tip_label.text         = "💡 " + TIPS[randi() % TIPS.size()]

	# Fade in from black
	fade_overlay.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.5)
	await tw.finished

	# Kick off background loading
	ResourceLoader.load_threaded_request(GAME_SCENE)

func _process(_delta: float) -> void:
	if _loading_done:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				progress_bar.value = progress[0]
			status_label.text = "กำลังโหลดเกม... (%d%%)" % int((progress[0] if progress.size() > 0 else 0.0) * 100)

		ResourceLoader.THREAD_LOAD_LOADED:
			_loading_done = true
			progress_bar.value = 1.0
			status_label.text  = "พร้อมแล้ว! ✓"
			_scene_resource    = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
			await get_tree().create_timer(0.35).timeout
			_launch_game()

		ResourceLoader.THREAD_LOAD_FAILED:
			_loading_done = true
			status_label.text = "โหลดเกมล้มเหลว กรุณาลองใหม่"
			push_error("[PreGameLoading] Failed to load: " + GAME_SCENE)

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_done = true
			status_label.text = "ไม่พบไฟล์เกม"
			push_error("[PreGameLoading] Invalid resource: " + GAME_SCENE)

func _launch_game() -> void:
	# Fade to black then switch scene
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.45)
	await tw.finished

	if _scene_resource:
		get_tree().change_scene_to_packed(_scene_resource)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)
