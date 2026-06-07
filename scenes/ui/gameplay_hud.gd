extends Control

@onready var p1_rice_bar = $TopLeft/RiceBar/TextureProgressBar
@onready var p1_distance = $TopLeft/DistanceSign/Label

@onready var p2_rice_bar = $TopRight/RiceBar/TextureProgressBar
@onready var p2_distance = $TopRight/DistanceSign/Label

@onready var p1_warning = $TopLeft/WarningLabel
@onready var p2_warning = $TopRight/WarningLabel

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
	var p1_rocket = $BottomControls/P1Skills/SkillRocket
	var p1_shield = $BottomControls/P1Skills/SkillShield
	if p1_rocket: p1_rocket.pressed.connect(_on_p1_skill_rocket_pressed)
	if p1_shield: p1_shield.pressed.connect(_on_p1_skill_shield_pressed)
	
	# P2 Skills
	var p2_rocket = $BottomControls/P2Skills/SkillRocket
	var p2_shield = $BottomControls/P2Skills/SkillShield
	if p2_rocket: p2_rocket.pressed.connect(_on_p2_skill_rocket_pressed)
	if p2_shield: p2_shield.pressed.connect(_on_p2_skill_shield_pressed)
	
	# Initial setup
	if player1:
		p1_rice_bar.max_value = player1.get("MAX_CHARGES") if "MAX_CHARGES" in player1 else 3
	if player2:
		p2_rice_bar.max_value = player2.get("MAX_CHARGES") if "MAX_CHARGES" in player2 else 3

func _process(_delta):
	# Update P1 Data
	if player1:
		var p1_val = player1.get("charges") if "charges" in player1 else 0
		p1_rice_bar.value = p1_val
		
		p1_distance.text = str(int(player1.get("distance") if "distance" in player1 else 0)) + "m"
		if p1_warning:
			var msg = player1.get("warning_message") if "warning_message" in player1 else ""
			p1_warning.text = msg
			p1_warning.visible = msg != ""
	
	# Update P2 Data
	if player2:
		var p2_val = player2.get("charges") if "charges" in player2 else 0
		p2_rice_bar.value = p2_val
		
		p2_distance.text = str(int(player2.get("distance") if "distance" in player2 else 0)) + "m"
		if p2_warning:
			var msg = player2.get("warning_message") if "warning_message" in player2 else ""
			p2_warning.text = msg
			p2_warning.visible = msg != ""

func _on_pause_pressed():
	# Implement pause logic or emit signal
	get_tree().paused = !get_tree().paused

func _on_settings_pressed():
	# Implement settings menu opening
	pass

func _on_p1_skill_rocket_pressed():
	if player1 and player1.has_method("try_skill"):
		player1.try_skill("rocket")

func _on_p1_skill_shield_pressed():
	if player1 and player1.has_method("try_defend"):
		player1.try_defend()

func _on_p2_skill_rocket_pressed():
	if player2 and player2.has_method("try_skill"):
		player2.try_skill("rocket")

func _on_p2_skill_shield_pressed():
	if player2 and player2.has_method("try_defend"):
		player2.try_defend()
