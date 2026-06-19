extends Control
# =============================================================================
# PodiumCutscene — Post-race ending podium ceremony
#
# Usage: call show_podium(winner_name, p1_char, p2_char) before adding to tree,
# or set variables before _ready() by using the static helper:
#   PodiumCutscene.launch(get_tree(), winner_name, p1_char, p2_char, on_done_callback)
#
# Character types: "man" | "woman"
# winner_name: "Player 1" | "Player 2" | ""  (empty = draw)
# =============================================================================

const PATH_END_SCENE = "res://cutscene/ending/end_scene.png"
const PATH_PODIUM_BG = "res://cutscene/ending/podium_bg.png"

const CHAR_PATHS = {
	"man_happy":   "res://cutscene/characters/man/man_happy.png",
	"man_sad":     "res://cutscene/characters/man/man_sad.png",
	"woman_happy": "res://cutscene/characters/woman/woman_happy.png",
	"woman_sad":   "res://cutscene/characters/woman/woman_sad.png",
	# NPC fallback
	"npc_sad":     "res://cutscene/characters/npc/npc_lose.png",
}

# ── Data passed in from caller ──────────────────────────────
var winner_name: String  = "Player 1"
var p1_character: String = "man"    # "man" or "woman"
var p2_character: String = "woman"
var p1_kratips: int      = 0
var p2_kratips: int      = 0
var p1_distance: int     = 0
var p2_distance: int     = 0

# Called when cutscene ends and player presses Continue
signal cutscene_ended

# ── Nodes ────────────────────────────────────────────────────
@onready var bg_rect: TextureRect          = $BgRect
@onready var podium_bg: TextureRect        = $PodiumBg
@onready var char_1st: TextureRect         = $Podium/Char1st
@onready var char_2nd: TextureRect         = $Podium/Char2nd
@onready var char_3rd: TextureRect         = $Podium/Char3rd
@onready var label_1st: Label              = $Podium/Label1st
@onready var label_2nd: Label              = $Podium/Label2nd
@onready var label_3rd: Label              = $Podium/Label3rd
@onready var rank_label_1st: Label         = $Podium/RankBadge1st
@onready var rank_label_2nd: Label         = $Podium/RankBadge2nd
@onready var rank_label_3rd: Label         = $Podium/RankBadge3rd
@onready var overlay: ColorRect            = $Overlay
@onready var continue_btn: Button          = $ContinueBtn
@onready var title_label: Label            = $TitleLabel

var _phase: int = 0  # 0 = end_scene, 1 = podium

func _ready() -> void:
	overlay.color   = Color(0, 0, 0, 1.0)
	overlay.visible = true
	podium_bg.visible = false
	continue_btn.visible = false

	# Shrink podium size and anchor to bottom center
	get_tree().process_frame.connect(func():
		var center_bottom = Vector2(size.x / 2.0, size.y)
		podium_bg.pivot_offset = center_bottom
		$Podium.pivot_offset = center_bottom
		
		var shrink_scale = Vector2(0.7, 0.7) # Adjust this value (e.g. 0.7 = 70% size)
		podium_bg.scale = shrink_scale
		$Podium.scale = shrink_scale
		
		podium_bg.position.y += 80
		$Podium.position.y -= 85
		
		var side_offset = 95
		var spread_offset = 150 # ขยับซ้ายขวาออกไปอี
		
		char_2nd.position.y += side_offset
		label_2nd.position.y += side_offset
		rank_label_2nd.position.y += side_offset
		
		char_2nd.position.x -= spread_offset
		label_2nd.position.x -= spread_offset
		rank_label_2nd.position.x -= spread_offset
		
		char_3rd.position.y += side_offset
		label_3rd.position.y += side_offset
		rank_label_3rd.position.y += side_offset
		
		char_3rd.position.x += spread_offset
		label_3rd.position.x += spread_offset
		rank_label_3rd.position.x += spread_offset
	, CONNECT_ONE_SHOT)

	# Hide all chars initially
	for c in [char_1st, char_2nd, char_3rd]:
		c.visible = false
	for l in [label_1st, label_2nd, label_3rd, rank_label_1st, rank_label_2nd, rank_label_3rd]:
		l.visible = false

	continue_btn.pressed.connect(_on_continue_pressed)

	# Start sequence
	_run_sequence()

func _run_sequence() -> void:
	# Phase 1: Show end_scene
	bg_rect.texture = load(PATH_END_SCENE)
	title_label.text = ""
	_fade_in(0.8)
	await get_tree().create_timer(2.5).timeout

	# Phase 2: Fade in Podium smoothly over end_scene
	podium_bg.texture = load(PATH_PODIUM_BG)
	podium_bg.visible = true
	podium_bg.modulate.a = 0.0
	title_label.text = "🏆 " + LanguageManager.t("LBL_FINAL_RESULT") + " 🏆"

	var tween = create_tween()
	tween.tween_property(podium_bg, "modulate:a", 1.0, 1.0)
	await tween.finished

	# Determine ranking
	var ranking = _calculate_ranking()
	AudioManager.play_sfx("charge_full")

	# Spawn characters one by one with pop animation
	await get_tree().create_timer(0.3).timeout
	_spawn_character(char_3rd, label_3rd, rank_label_3rd, ranking[2], "🥉", 0.4)
	await get_tree().create_timer(0.5).timeout
	_spawn_character(char_2nd, label_2nd, rank_label_2nd, ranking[1], "🥈", 0.4)
	await get_tree().create_timer(0.5).timeout
	_spawn_character(char_1st, label_1st, rank_label_1st, ranking[0], "🥇", 0.4)
	AudioManager.play_sfx("skill_pickup")

	await get_tree().create_timer(1.0).timeout

	# Show continue button
	continue_btn.visible = true
	continue_btn.modulate.a = 0.0
	var btn_tween = create_tween()
	btn_tween.tween_property(continue_btn, "modulate:a", 1.0, 0.4)

# ─────────────────────────────────────────────────────────────
# Returns array of 3 Dictionaries: [1st, 2nd, 3rd]
# Each has: { char_key, display_name, emotion }
func _calculate_ranking() -> Array[Dictionary]:
	var p1_entry = {
		"char_key": p1_character,
		"display_name": LanguageManager.t("LBL_PLAYER1"),
		"is_winner": (winner_name == "Player 1"),
	}
	var p2_entry = {
		"char_key": p2_character,
		"display_name": LanguageManager.t("LBL_PLAYER2"),
		"is_winner": (winner_name == "Player 2"),
	}
	var npc_entry = {
		"char_key": "npc",
		"display_name": "NPC_Z",
		"is_winner": false,
	}

	var first: Dictionary
	var second: Dictionary
	var third: Dictionary = npc_entry

	if winner_name == "Player 1":
		first  = p1_entry
		second = p2_entry
	elif winner_name == "Player 2":
		first  = p2_entry
		second = p1_entry
	else:
		# Draw — both share glory, NPC still 3rd
		first  = p1_entry
		second = p2_entry

	return [first, second, third]

func _get_char_texture_path(char_key: String, is_winner: bool) -> String:
	var emotion = "happy" if is_winner else "sad"
	var key = char_key + "_" + emotion
	return CHAR_PATHS.get(key, "")

func _spawn_character(
	char_rect: TextureRect,
	name_label: Label,
	rank_badge: Label,
	data: Dictionary,
	badge_text: String,
	duration: float
) -> void:
	var path = _get_char_texture_path(data["char_key"], data["is_winner"])
	if path != "" and ResourceLoader.exists(path):
		char_rect.texture = load(path)
	else:
		# Placeholder when no asset is available
		char_rect.texture = null

	name_label.text  = data["display_name"]
	rank_badge.text  = badge_text

	# Pop-in animation
	char_rect.scale   = Vector2(0.1, 0.1)
	char_rect.visible = true
	name_label.visible  = true
	rank_badge.visible  = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(char_rect, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(rank_badge, "modulate:a", 1.0, duration * 0.5)
	await tween.finished

# ─────────────────────────────────────────────────────────────
func _fade_in(duration: float) -> void:
	overlay.visible = true
	overlay.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration)
	await tween.finished
	overlay.visible = false

func _fade_out(duration: float) -> void:
	overlay.visible = true
	overlay.color.a = 0.0
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, duration)
	await tween.finished

func _on_continue_pressed() -> void:
	# Fade out and emit signal for caller to show the game-over board
	overlay.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.5)
	await tween.finished
	cutscene_ended.emit()

# ─────────────────────────────────────────────────────────────
# Static helper to launch from game_over_screen
static func launch(
	scene_tree: SceneTree,
	p_winner: String,
	p_p1_char: String,
	p_p2_char: String,
	p_p1_kratips: int,
	p_p2_kratips: int,
	p_p1_dist: int,
	p_p2_dist: int,
	on_ended: Callable
) -> Node:
	var scene = load("res://cutscene/podium_cutscene.tscn")
	var instance = scene.instantiate()
	instance.winner_name  = p_winner
	instance.p1_character = p_p1_char
	instance.p2_character = p_p2_char
	instance.p1_kratips   = p_p1_kratips
	instance.p2_kratips   = p_p2_kratips
	instance.p1_distance  = p_p1_dist
	instance.p2_distance  = p_p2_dist
	instance.cutscene_ended.connect(on_ended)
	scene_tree.current_scene.add_child(instance)
	return instance
