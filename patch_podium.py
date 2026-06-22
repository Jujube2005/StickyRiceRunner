import sys

with open('cutscene/podium_cutscene.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add signals and variables
new_vars = """
# Called when cutscene ends and player presses Continue
signal cutscene_ended
signal main_menu_pressed
signal restart_pressed

var confetti_node: CPUParticles2D
var fireworks_left: CPUParticles2D
var fireworks_right: CPUParticles2D
var stars_node: CPUParticles2D
var spotlight_node: TextureRect
var champion_banner: PanelContainer
var new_btn_container: HBoxContainer
var score_labels: Array[Label] = []
"""
content = content.replace("# Called when cutscene ends and player presses Continue\nsignal cutscene_ended", new_vars.strip())

# 2. Update _ready to call build effects
ready_patch = """
	continue_btn.visible = false
	_build_celebration_effects()
"""
content = content.replace("continue_btn.visible = false", ready_patch.strip())

# 3. Remove continue_btn.pressed connection
content = content.replace("\tcontinue_btn.pressed.connect(_on_continue_pressed)\n", "")

# 4. Update _run_sequence to show new buttons instead of continue_btn
new_btn_show = """
	# Show new buttons
	new_btn_container.visible = true
	new_btn_container.modulate.a = 0.0
	var btn_tween = create_tween()
	btn_tween.tween_property(new_btn_container, "modulate:a", 1.0, 0.4)
"""
content = content.replace("""
	# Show continue button
	continue_btn.visible = true
	continue_btn.modulate.a = 0.0
	var btn_tween = create_tween()
	btn_tween.tween_property(continue_btn, "modulate:a", 1.0, 0.4)
""".strip(), new_btn_show.strip())

# 5. Update _calculate_ranking to include score
ranking_patch_p1 = """
	var p1_entry = {
		"char_key": p1_character,
		"display_name": LanguageManager.t("LBL_PLAYER1"),
		"is_winner": (winner_name == "Player 1"),
		"score": (p1_kratips * 100) + p1_distance
	}
"""
content = content.replace("""
	var p1_entry = {
		"char_key": p1_character,
		"display_name": LanguageManager.t("LBL_PLAYER1"),
		"is_winner": (winner_name == "Player 1"),
	}
""".strip(), ranking_patch_p1.strip())

ranking_patch_p2 = """
	var p2_entry = {
		"char_key": p2_character,
		"display_name": LanguageManager.t("LBL_PLAYER2"),
		"is_winner": (winner_name == "Player 2"),
		"score": (p2_kratips * 100) + p2_distance
	}
"""
content = content.replace("""
	var p2_entry = {
		"char_key": p2_character,
		"display_name": LanguageManager.t("LBL_PLAYER2"),
		"is_winner": (winner_name == "Player 2"),
	}
""".strip(), ranking_patch_p2.strip())

ranking_patch_npc = """
	var npc_entry = {
		"char_key": "npc",
		"display_name": "NPC_Z",
		"is_winner": false,
		"score": 0
	}
"""
content = content.replace("""
	var npc_entry = {
		"char_key": "npc",
		"display_name": "NPC_Z",
		"is_winner": false,
	}
""".strip(), ranking_patch_npc.strip())


# 6. Update _spawn_character to show score and play effects if winner
spawn_patch = """
	# Pop-in animation
	char_rect.scale   = Vector2(0.1, 0.1)
	char_rect.visible = true
	name_label.visible  = false # ซ่อนชื่อ
	rank_badge.visible  = false # ซ่อนเหรียญ
	
	# Show score
	var slot_index = 0
	if char_rect == char_2nd: slot_index = 1
	elif char_rect == char_3rd: slot_index = 2
	
	if slot_index < score_labels.size():
		var slabel = score_labels[slot_index]
		if data["char_key"] != "npc":
			slabel.text = str(data["score"])
		else:
			slabel.text = "" # Hide NPC score
		
		# Show score label and animate it
		slabel.modulate.a = 0.0
		slabel.visible = true
		create_tween().tween_property(slabel, "modulate:a", 1.0, duration)

	if data["is_winner"]:
		spotlight_node.visible = true
		stars_node.emitting = true
		confetti_node.emitting = true
		fireworks_left.emitting = true
		fireworks_right.emitting = true
		champion_banner.visible = true
		create_tween().tween_property(champion_banner, "modulate:a", 1.0, 0.5)

"""
content = content.replace("""
	# Pop-in animation
	char_rect.scale   = Vector2(0.1, 0.1)
	char_rect.visible = true
	name_label.visible  = false # ซ่อนชื่อ
	rank_badge.visible  = false # ซ่อนเหรียญ
""".strip(), spawn_patch.strip())

# 7. Add new functions at the end
new_funcs = """

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
	spotlight_node.layout_mode = Control.LAYOUT_MODE_ANCHORS
	spotlight_node.anchor_left = 0.35
	spotlight_node.anchor_right = 0.65
	spotlight_node.anchor_top = -0.5
	spotlight_node.anchor_bottom = 0.75
	spotlight_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight_node.visible = false
	$Podium.add_child(spotlight_node)
	$Podium.move_child(spotlight_node, 0)
	
	# Score Labels
	for char_node in [char_1st, char_2nd, char_3rd]:
		var slabel = Label.new()
		slabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slabel.layout_mode = Control.LAYOUT_MODE_ANCHORS
		slabel.anchor_top = 1.05
		slabel.anchor_bottom = 1.2
		slabel.anchor_left = -0.5
		slabel.anchor_right = 1.5
		slabel.add_theme_font_size_override("font_size", 30)
		slabel.add_theme_color_override("font_color", Color(1, 0.8, 0.2) if char_node == char_1st else Color.WHITE)
		slabel.add_theme_color_override("font_outline_color", Color.BLACK)
		slabel.add_theme_constant_override("outline_size", 10)
		slabel.visible = false
		char_node.add_child(slabel)
		score_labels.append(slabel)

	# Confetti
	confetti_node = CPUParticles2D.new()
	confetti_node.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
	confetti_node.position = Vector2(960, -50)
	confetti_node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti_node.emission_rect_extents = Vector2(960, 10)
	confetti_node.direction = Vector2(0, 1)
	confetti_node.spread = 20
	confetti_node.gravity = Vector2(0, 300)
	confetti_node.initial_velocity_min = 50
	confetti_node.initial_velocity_max = 200
	confetti_node.angular_velocity_min = -100
	confetti_node.angular_velocity_max = 100
	confetti_node.scale_amount_min = 0.05
	confetti_node.scale_amount_max = 0.15
	var grad = Gradient.new()
	grad.add_point(0.0, Color.RED)
	grad.add_point(0.25, Color.GREEN)
	grad.add_point(0.5, Color.BLUE)
	grad.add_point(0.75, Color.YELLOW)
	grad.add_point(1.0, Color.MAGENTA)
	confetti_node.color_initial_ramp = grad
	confetti_node.amount = 150
	confetti_node.lifetime = 5.0
	confetti_node.emitting = false
	add_child(confetti_node)

	# Stars
	stars_node = CPUParticles2D.new()
	stars_node.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/star_01_a.png")
	stars_node.position = Vector2(char_1st.size.x/2, char_1st.size.y/2)
	stars_node.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	stars_node.emission_sphere_radius = 180
	stars_node.gravity = Vector2(0, -50)
	stars_node.scale_amount_min = 0.03
	stars_node.scale_amount_max = 0.1
	var star_grad = Gradient.new()
	star_grad.add_point(0.0, Color(1,1,1,0))
	star_grad.add_point(0.2, Color(1,1,0.5,1))
	star_grad.add_point(0.8, Color(1,1,0.5,1))
	star_grad.add_point(1.0, Color(1,1,1,0))
	stars_node.color_ramp = star_grad
	stars_node.amount = 30
	stars_node.lifetime = 2.0
	stars_node.emitting = false
	char_1st.add_child(stars_node)

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
	champion_banner = PanelContainer.new()
	champion_banner.layout_mode = Control.LAYOUT_MODE_ANCHORS
	champion_banner.anchor_left = 0.2
	champion_banner.anchor_right = 0.8
	champion_banner.anchor_top = 0.05
	champion_banner.anchor_bottom = 0.2
	champion_banner.modulate = Color(1, 1, 1, 0)
	champion_banner.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	champion_banner.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	champion_banner.add_child(vbox)
	
	var title = Label.new()
	title.text = "CHAMPION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 70)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Sticky Rice Runner"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	vbox.add_child(subtitle)
	
	add_child(champion_banner)

	# Buttons
	new_btn_container = HBoxContainer.new()
	new_btn_container.layout_mode = Control.LAYOUT_MODE_ANCHORS
	new_btn_container.anchor_top = 1.0
	new_btn_container.anchor_bottom = 1.0
	new_btn_container.anchor_left = 0.0
	new_btn_container.anchor_right = 1.0
	new_btn_container.offset_top = -120
	new_btn_container.offset_bottom = -40
	new_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	new_btn_container.theme_override_constants = {"separation": 50}
	new_btn_container.visible = false
	
	var m_btn = Button.new()
	m_btn.text = " 🏠 Main Menu "
	m_btn.add_theme_font_size_override("font_size", 36)
	m_btn.pressed.connect(_on_menu_pressed)
	new_btn_container.add_child(m_btn)
	
	var r_btn = Button.new()
	r_btn.text = " 🔄 Play Again "
	r_btn.add_theme_font_size_override("font_size", 36)
	r_btn.pressed.connect(_on_restart_pressed)
	new_btn_container.add_child(r_btn)
	
	var res_btn = Button.new()
	res_btn.text = " 📊 View Results "
	res_btn.add_theme_font_size_override("font_size", 36)
	res_btn.pressed.connect(_on_results_pressed)
	new_btn_container.add_child(res_btn)
	
	add_child(new_btn_container)

"""
content += new_funcs

with open('cutscene/podium_cutscene.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch applied successfully")
