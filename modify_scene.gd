@tool
extends SceneTree

func _init():
	var packed_scene = ResourceLoader.load("res://cutscene/podium_cutscene.tscn")
	var root = packed_scene.instantiate()
	
	# 1. Add Spotlight behind 1st place
	var podium = root.get_node("Podium")
	var spotlight = TextureRect.new()
	spotlight.name = "Spotlight"
	spotlight.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/spotlight_01_a.png")
	spotlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spotlight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spotlight.modulate = Color(1, 1, 0.8, 0.6) # Yellowish
	spotlight.layout_mode = Control.LAYOUT_MODE_ANCHORS
	spotlight.anchor_left = 0.2
	spotlight.anchor_right = 0.8
	spotlight.anchor_top = -0.5
	spotlight.anchor_bottom = 0.8
	spotlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Insert it at index 0 so it's behind the characters
	podium.add_child(spotlight)
	spotlight.owner = root
	podium.move_child(spotlight, 0)
	
	# 2. Add Score Labels under each character slot
	for i in range(1, 4):
		var char_node = podium.get_node(str("Char", i, "st") if i == 1 else str("Char", i, "nd") if i == 2 else "Char3rd")
		var score_label = Label.new()
		score_label.name = "ScoreLabel"
		score_label.text = "Score: 0"
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Position under the character
		score_label.layout_mode = Control.LAYOUT_MODE_ANCHORS
		score_label.anchor_top = 1.05
		score_label.anchor_bottom = 1.15
		score_label.anchor_left = -0.5
		score_label.anchor_right = 1.5
		score_label.add_theme_font_size_override("font_size", 20 if i != 1 else 24)
		score_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2) if i == 1 else Color.WHITE)
		score_label.add_theme_color_override("font_outline_color", Color.BLACK)
		score_label.add_theme_constant_override("outline_size", 8)
		char_node.add_child(score_label)
		score_label.owner = root

	# 3. Add Confetti Particles
	var confetti = CPUParticles2D.new()
	confetti.name = "ConfettiParticles"
	confetti.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
	confetti.position = Vector2(960, -50) # Assuming 1920x1080
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(960, 10)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 20
	confetti.gravity = Vector2(0, 300)
	confetti.initial_velocity_min = 50
	confetti.initial_velocity_max = 200
	confetti.angular_velocity_min = -100
	confetti.angular_velocity_max = 100
	confetti.scale_amount_min = 0.05
	confetti.scale_amount_max = 0.15
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.RED)
	gradient.add_point(0.25, Color.GREEN)
	gradient.add_point(0.5, Color.BLUE)
	gradient.add_point(0.75, Color.YELLOW)
	gradient.add_point(1.0, Color.MAGENTA)
	confetti.color_initial_ramp = gradient
	confetti.amount = 150
	confetti.lifetime = 5.0
	confetti.emitting = false
	root.add_child(confetti)
	confetti.owner = root
	
	# 4. Add Stars Particles to Char1st
	var char1 = podium.get_node("Char1st")
	var stars = CPUParticles2D.new()
	stars.name = "StarsParticles"
	stars.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/star_01_a.png")
	stars.position = Vector2(char1.size.x/2, char1.size.y/2)
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	stars.emission_sphere_radius = 150
	stars.gravity = Vector2(0, -50)
	stars.scale_amount_min = 0.02
	stars.scale_amount_max = 0.1
	var star_grad = Gradient.new()
	star_grad.add_point(0.0, Color(1,1,1,0))
	star_grad.add_point(0.2, Color(1,1,0.5,1))
	star_grad.add_point(0.8, Color(1,1,0.5,1))
	star_grad.add_point(1.0, Color(1,1,1,0))
	stars.color_ramp = star_grad
	stars.amount = 20
	stars.lifetime = 2.0
	stars.emitting = false
	char1.add_child(stars)
	stars.owner = root
	
	# 5. Add Fireworks
	for pos in [Vector2(300, 800), Vector2(1620, 800)]:
		var fw = CPUParticles2D.new()
		fw.name = "FireworksLeft" if pos.x < 1000 else "FireworksRight"
		fw.texture = load("res://assets/textures/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
		fw.position = pos
		fw.direction = Vector2(0, -1)
		fw.spread = 15
		fw.gravity = Vector2(0, 400)
		fw.initial_velocity_min = 500
		fw.initial_velocity_max = 800
		fw.scale_amount_min = 0.05
		fw.scale_amount_max = 0.1
		var fw_grad = Gradient.new()
		fw_grad.add_point(0.0, Color(1,0.5,0.2,1))
		fw_grad.add_point(0.8, Color(1,0.2,0.2,1))
		fw_grad.add_point(1.0, Color(1,0,0,0))
		fw.color_ramp = fw_grad
		fw.amount = 50
		fw.lifetime = 1.5
		fw.explosiveness = 0.9
		fw.emitting = false
		fw.one_shot = true
		root.add_child(fw)
		fw.owner = root

	# 6. Champion Banner
	var banner = PanelContainer.new()
	banner.name = "ChampionBanner"
	banner.layout_mode = Control.LAYOUT_MODE_ANCHORS
	banner.anchor_left = 0.2
	banner.anchor_right = 0.8
	banner.anchor_top = 0.05
	banner.anchor_bottom = 0.2
	banner.modulate = Color(1, 1, 1, 0) # Hidden initially
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	banner.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	banner.add_child(vbox)
	vbox.owner = root
	
	var title = Label.new()
	title.name = "Title"
	title.text = "CHAMPION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	vbox.add_child(title)
	title.owner = root
	
	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Sticky Rice Runner"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	vbox.add_child(subtitle)
	subtitle.owner = root
	
	root.add_child(banner)
	banner.owner = root

	# 7. Navigation Buttons
	var old_btn = root.get_node("ContinueBtn")
	var hbox = HBoxContainer.new()
	hbox.name = "NavButtons"
	hbox.layout_mode = Control.LAYOUT_MODE_ANCHORS
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.offset_top = -100
	hbox.offset_bottom = -20
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.theme_override_constants = {"separation": 30}
	hbox.modulate = Color(1,1,1,0) # Hidden initially
	
	var btn1 = Button.new()
	btn1.name = "MenuBtn"
	btn1.text = "🏠 Main Menu"
	btn1.add_theme_font_size_override("font_size", 30)
	hbox.add_child(btn1)
	btn1.owner = root
	
	var btn2 = Button.new()
	btn2.name = "RestartBtn"
	btn2.text = "🔄 Play Again"
	btn2.add_theme_font_size_override("font_size", 30)
	hbox.add_child(btn2)
	btn2.owner = root
	
	var btn3 = Button.new()
	btn3.name = "ResultsBtn"
	btn3.text = "📊 View Results"
	btn3.add_theme_font_size_override("font_size", 30)
	hbox.add_child(btn3)
	btn3.owner = root
	
	root.add_child(hbox)
	hbox.owner = root
	
	if old_btn:
		old_btn.name = "OldContinueBtn"
		old_btn.visible = false

	var err = PackedScene.new()
	err.pack(root)
	ResourceSaver.save(err, "res://cutscene/podium_cutscene.tscn")
	print("Scene modified successfully!")
	quit()
