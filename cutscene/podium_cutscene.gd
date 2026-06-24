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
signal main_menu_pressed
signal restart_pressed

var confetti_node: CPUParticles2D
var fireworks_left: CPUParticles2D
var fireworks_right: CPUParticles2D
var stars_node: CPUParticles2D
var spotlight_node: TextureRect
var champion_banner: Control
var new_btn_container: HBoxContainer

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
	_build_celebration_effects()

	# Shrink podium size and anchor to bottom center
	get_tree().process_frame.connect(func():
		var center_bottom = Vector2(size.x / 2.0, size.y)
		podium_bg.pivot_offset = center_bottom
		$Podium.pivot_offset = center_bottom
		
		# Make podium smaller
		var shrink_scale = Vector2(0.55, 0.55) 
		podium_bg.scale = shrink_scale
		$Podium.scale = shrink_scale
		
		podium_bg.position.y += 80  
		$Podium.position.y -= 42
		
		# Make characters larger relative to the podium
		var char_scale = Vector2(10.0, 10.0)
		for c in [char_1st, char_2nd, char_3rd]:
			c.pivot_offset = Vector2(c.size.x / 2.0, c.size.y)
			c.scale = char_scale
			c.position.y += 15 
		
		# Specific vertical offsets to fine-tune feet placement
		char_1st.position.y -= 25 
		
		var spread_offset = 150
		var side_offset_2nd = 100 
		var side_offset_3rd = 175 
		
		char_2nd.position.y += side_offset_2nd
		label_2nd.position.y += side_offset_2nd
		rank_label_2nd.position.y += side_offset_2nd
		
		char_2nd.position.x -= spread_offset
		label_2nd.position.x -= spread_offset
		rank_label_2nd.position.x -= spread_offset
		
		char_3rd.position.y += side_offset_3rd
		label_3rd.position.y += side_offset_3rd
		rank_label_3rd.position.y += side_offset_3rd
		
		char_3rd.position.x += spread_offset
		label_3rd.position.x += spread_offset
		rank_label_3rd.position.x += spread_offset
	, CONNECT_ONE_SHOT)

	# Hide all chars initially
	for c in [char_1st, char_2nd, char_3rd]:
		c.visible = false
	for l in [label_1st, label_2nd, label_3rd, rank_label_1st, rank_label_2nd, rank_label_3rd]:
		l.visible = false

	# continue_btn.pressed.connect(_on_continue_pressed)

	# Start sequence
	AudioManager.play_music_by_name("musicEnd")
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
	title_label.text = ""

	var tween = create_tween()
	tween.tween_property(podium_bg, "modulate:a", 1.0, 1.0)
	await tween.finished

	# Determine ranking
	var ranking = _calculate_ranking()
	AudioManager.play_sfx("charge_full")

	# Spawn characters one by one with pop animation
	await get_tree().create_timer(0.3).timeout
	_spawn_character(char_3rd, label_3rd, rank_label_3rd, ranking[2], 0.4)
	await get_tree().create_timer(0.5).timeout
	_spawn_character(char_2nd, label_2nd, rank_label_2nd, ranking[1], 0.4)
	await get_tree().create_timer(0.5).timeout
	_spawn_character(char_1st, label_1st, rank_label_1st, ranking[0], 0.4)
	AudioManager.play_sfx("skill_pickup")

	await get_tree().create_timer(1.0).timeout

	# Show new buttons
	new_btn_container.visible = true
	new_btn_container.modulate.a = 0.0
	var btn_tween = create_tween()
	btn_tween.tween_property(new_btn_container, "modulate:a", 1.0, 0.4)

# ─────────────────────────────────────────────────────────────
# Returns array of 3 Dictionaries: [1st, 2nd, 3rd]
# Each has: { char_key, display_name, emotion }
func _calculate_ranking() -> Array[Dictionary]:
	var p1_entry = {
		"char_key": p1_character,
		"display_name": LanguageManager.t("LBL_PLAYER1"),
		"is_winner": (winner_name == "Player 1"),
		"score": (p1_kratips * 100) + p1_distance
	}
	var p2_entry = {
		"char_key": p2_character,
		"display_name": LanguageManager.t("LBL_PLAYER2"),
		"is_winner": (winner_name == "Player 2"),
		"score": (p2_kratips * 100) + p2_distance
	}
	var npc_entry = {
		"char_key": "npc",
		"display_name": "NPC_Z",
		"is_winner": false,
		"score": 0
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
	duration: float
) -> void:
	var path = _get_char_texture_path(data["char_key"], data["is_winner"])
	if path != "" and ResourceLoader.exists(path):
		char_rect.texture = load(path)
	else:
		# Placeholder when no asset is available
		char_rect.texture = null

	name_label.text  = data["display_name"]
	# rank_badge.text is no longer set since badge_text argument was removed

	# Custom scale multiplier to fix empty space in image files
	var base_scale = Vector2(2.0, 2.0) # Adjust character size here!
	var target_scale = base_scale
	if data["char_key"] == "woman":
		target_scale = base_scale * 1.05 
		char_rect.position.y += 20 
	elif data["char_key"] == "npc":
		target_scale = base_scale * 1.15 
		
	# Scale from bottom center so feet stay planted
	char_rect.pivot_offset = Vector2(char_rect.size.x / 2.0, char_rect.size.y)

	# Pop-in animation
	char_rect.scale   = Vector2(0.1, 0.1)
	char_rect.visible = true
	name_label.visible  = false # ซ่อนชื่อ
	rank_badge.visible  = false # ซ่อนเหรียญ

	var tween = create_tween().set_parallel(true)
	tween.tween_property(char_rect, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(rank_badge, "modulate:a", 1.0, duration * 0.5)
	
	if data["is_winner"]:
		spotlight_node.visible = true
		stars_node.emitting = true
		confetti_node.emitting = true
		fireworks_left.emitting = true
		fireworks_right.emitting = true
		champion_banner.visible = true
		create_tween().tween_property(champion_banner, "modulate:a", 1.0, 0.5)

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

func _on_show_leaderboard_pressed() -> void:
	var board_scene = load("res://scenes/ui/leaderboard_screen.tscn")
	if board_scene:
		var instance = board_scene.instantiate()
		add_child(instance)
		instance.show_result(winner_name, p1_kratips, p2_kratips, p1_distance, p2_distance)

func _on_menu_pressed() -> void:
	overlay.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.5)
	await tween.finished
	main_menu_pressed.emit()

func _on_restart_pressed() -> void:
	overlay.visible = true
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.5)
	await tween.finished
	restart_pressed.emit()

func _on_results_pressed() -> void:
	_on_continue_pressed()

func _build_celebration_effects() -> void:
	# Spotlight
	spotlight_node = TextureRect.new()
	spotlight_node.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/spotlight_01_a.png")
	spotlight_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spotlight_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spotlight_node.modulate = Color(1, 1, 0.8, 0.7)
	spotlight_node.layout_mode = 1
	spotlight_node.anchor_left = 0.35
	spotlight_node.anchor_right = 0.65
	spotlight_node.anchor_top = -0.5
	spotlight_node.anchor_bottom = 0.75
	spotlight_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight_node.visible = false
	$Podium.add_child(spotlight_node)
	$Podium.move_child(spotlight_node, 0)
	
	# Confetti (Paper fireworks from corners)
	var cf_setup = func(cf: CPUParticles2D, pos: Vector2, dir: Vector2):
		cf.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
		cf.position = pos
		cf.direction = dir
		cf.spread = 30
		cf.gravity = Vector2(0, 600)
		cf.initial_velocity_min = 800
		cf.initial_velocity_max = 1400
		cf.angular_velocity_min = -200
		cf.angular_velocity_max = 200
		cf.scale_amount_min = 0.05
		cf.scale_amount_max = 0.15
		var grad = Gradient.new()
		grad.add_point(0.0, Color.RED)
		grad.add_point(0.25, Color.GREEN)
		grad.add_point(0.5, Color.BLUE)
		grad.add_point(0.75, Color.YELLOW)
		grad.add_point(1.0, Color.MAGENTA)
		cf.color_initial_ramp = grad
		cf.amount = 100
		cf.lifetime = 3.0
		cf.explosiveness = 0.8
		cf.emitting = false
		cf.one_shot = true
		add_child(cf)

	confetti_node = CPUParticles2D.new()
	cf_setup.call(confetti_node, Vector2(100, 1080), Vector2(1, -1.5))
	
	var confetti_right = CPUParticles2D.new()
	cf_setup.call(confetti_right, Vector2(1820, 1080), Vector2(-1, -1.5))
	stars_node = confetti_right # Repurpose stars_node to trigger right confetti

	# Fireworks
	var fw_setup = func(fw: CPUParticles2D, pos: Vector2):
		fw.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
		fw.position = pos
		fw.direction = Vector2(0, -1)
		fw.spread = 15
		fw.gravity = Vector2(0, 400)
		fw.initial_velocity_min = 600
		fw.initial_velocity_max = 900
		fw.scale_amount_min = 0.05
		fw.scale_amount_max = 0.1
		var fw_g = Gradient.new()
		fw_g.add_point(0.0, Color(1,0.5,0.2,1))
		fw_g.add_point(0.8, Color(1,0.2,0.2,1))
		fw_g.add_point(1.0, Color(1,0,0,0))
		fw.color_ramp = fw_g
		fw.amount = 60
		fw.lifetime = 1.5
		fw.explosiveness = 0.9
		fw.emitting = false
		fw.one_shot = true
		add_child(fw)
		
	fireworks_left = CPUParticles2D.new()
	fw_setup.call(fireworks_left, Vector2(300, 800))
	fireworks_right = CPUParticles2D.new()
	fw_setup.call(fireworks_right, Vector2(1620, 800))

	# Banner
	var tex_rect = TextureRect.new()
	var banner_tex: Texture2D = null
	var b_img = Image.load_from_file("res://cutscene/ending/championtext.png")
	if b_img:
		banner_tex = ImageTexture.create_from_image(b_img)
	if banner_tex:
		tex_rect.texture = banner_tex
	
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	champion_banner = tex_rect
	champion_banner.layout_mode = 1
	champion_banner.anchor_left = 0.0
	champion_banner.anchor_right = 1.0
	champion_banner.anchor_top = 0.0
	champion_banner.anchor_bottom = 0.35 # ลดขนาดรูปลง (จาก 0.50)
	champion_banner.offset_top = -50     # เลื่อนขึ้น (ค่าติดลบยิ่งขึ้นบน)
	champion_banner.offset_bottom = -50  # เลื่อนขอบล่างขึ้นด้วย
	champion_banner.modulate = Color(1, 1, 1, 0)
	champion_banner.visible = false
	
	add_child(champion_banner)

	# Buttons
	new_btn_container = HBoxContainer.new()
	new_btn_container.layout_mode = 1
	new_btn_container.anchor_top = 1.0
	new_btn_container.anchor_bottom = 1.0
	new_btn_container.anchor_left = 0.0
	new_btn_container.anchor_right = 1.0
	new_btn_container.offset_top = -120
	new_btn_container.offset_bottom = -40
	new_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	new_btn_container.add_theme_constant_override("separation", 50)
	new_btn_container.visible = false
	
	var board_btn = TextureButton.new()
	if ResourceLoader.exists("res://assets/textures/UI/Buttons/leaderbord.png"):
		board_btn.texture_normal = load("res://assets/textures/UI/Buttons/leaderbord.png")
	else:
		board_btn.texture_normal = load("res://assets/textures/UI/Buttons/icon_smallTrophy.png")
	board_btn.ignore_texture_size = true
	board_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	board_btn.custom_minimum_size = Vector2(80, 80)
	board_btn.pressed.connect(_on_show_leaderboard_pressed)
	new_btn_container.add_child(board_btn)
	
	add_child(new_btn_container)
