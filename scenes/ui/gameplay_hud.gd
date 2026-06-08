extends Control

@onready var p1_rice_bar = $TopLeft/RiceBar/TextureProgressBar
@onready var p1_distance = $TopLeft/DistanceSign/Label

@onready var p2_rice_bar = $TopRight/RiceBar/TextureProgressBar
@onready var p2_distance = $TopRight/DistanceSign/Label

@onready var p1_warning = $TopLeft/WarningLabel
@onready var p2_warning = $TopRight/WarningLabel

@onready var p1_rocket_btn = $BottomControls/P1Skills/SkillRocket
@onready var p1_shield_btn = $BottomControls/P1Skills/SkillShield
@onready var p2_rocket_btn = $BottomControls/P2Skills/SkillRocket
@onready var p2_shield_btn = $BottomControls/P2Skills/SkillShield

var player1 = null
var player2 = null

func _ready():
	# Find players in the scene
	player1 = get_tree().current_scene.find_child("Player1", true, false)
	player2 = get_tree().current_scene.find_child("Player2", true, false)
	
	# Connect signals if needed (e.g. for skills)
	$CenterTop/PauseBtn.pressed.connect(_on_pause_pressed)
	$CenterTop/SettingsBtn.pressed.connect(_on_settings_pressed)
	
	# P1 Skills
	if p1_rocket_btn: p1_rocket_btn.pressed.connect(_on_p1_skill_rocket_pressed)
	if p1_shield_btn: p1_shield_btn.pressed.connect(_on_p1_skill_shield_pressed)
	
	# P2 Skills
	if p2_rocket_btn: p2_rocket_btn.pressed.connect(_on_p2_skill_rocket_pressed)
	if p2_shield_btn: p2_shield_btn.pressed.connect(_on_p2_skill_shield_pressed)
	
	# Connect warning signals
	if player1 and player1.has_signal("warning_changed"):
		player1.warning_changed.connect(func(msg): 
			if p1_warning:
				p1_warning.text = msg
				p1_warning.visible = msg != ""
		)
	
	if player2 and player2.has_signal("warning_changed"):
		player2.warning_changed.connect(func(msg): 
			if p2_warning:
				p2_warning.text = msg
				p2_warning.visible = msg != ""
		)
	
	# Initial setup
	if player1:
		p1_rice_bar.max_value = player1.get("MAX_CHARGES") if "MAX_CHARGES" in player1 else 5
	if player2:
		p2_rice_bar.max_value = player2.get("MAX_CHARGES") if "MAX_CHARGES" in player2 else 5

func _process(_delta):
	# Update P1 Data
	if player1:
		var p1_val = player1.get("charges") if "charges" in player1 else 0
		var p1_max = player1.get("MAX_CHARGES") if "MAX_CHARGES" in player1 else 5
		p1_rice_bar.value = p1_val
		
		# Update buttons state
		if p1_rocket_btn:
			p1_rocket_btn.disabled = p1_val < p1_max
			p1_rocket_btn.modulate = Color.WHITE if !p1_rocket_btn.disabled else Color(0.5, 0.5, 0.5, 0.7)
		if p1_shield_btn:
			p1_shield_btn.disabled = p1_val < 1
			p1_shield_btn.modulate = Color.WHITE if !p1_shield_btn.disabled else Color(0.5, 0.5, 0.5, 0.7)
		
		p1_distance.text = str(int(player1.get("distance") if "distance" in player1 else 0)) + "m"
	
	# Update P2 Data
	if player2:
		var p2_val = player2.get("charges") if "charges" in player2 else 0
		var p2_max = player2.get("MAX_CHARGES") if "MAX_CHARGES" in player2 else 5
		p2_rice_bar.value = p2_val
		
		# Update buttons state
		if p2_rocket_btn:
			p2_rocket_btn.disabled = p2_val < p2_max
			p2_rocket_btn.modulate = Color.WHITE if !p2_rocket_btn.disabled else Color(0.5, 0.5, 0.5, 0.7)
		if p2_shield_btn:
			p2_shield_btn.disabled = p2_val < 1
			p2_shield_btn.modulate = Color.WHITE if !p2_shield_btn.disabled else Color(0.5, 0.5, 0.5, 0.7)
		
		p2_distance.text = str(int(player2.get("distance") if "distance" in player2 else 0)) + "m"

func _on_pause_pressed():
	# Implement pause logic or emit signal
	get_tree().paused = !get_tree().paused

func _on_settings_pressed():
	# Implement settings menu opening
	pass

func _on_p1_skill_rocket_pressed():
	if player1 and player1.has_method("request_skill"):
		player1.request_skill()

func _on_p1_skill_shield_pressed():
	if player1 and player1.has_method("try_defend"):
		player1.try_defend()

func _on_p2_skill_rocket_pressed():
	if player2 and player2.has_method("request_skill"):
		player2.request_skill()

func _on_p2_skill_shield_pressed():
	if player2 and player2.has_method("try_defend"):
		player2.try_defend()
