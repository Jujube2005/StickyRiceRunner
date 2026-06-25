extends WorldEnvironment

# Zone fog colors matching each zone's atmosphere
const FOG_ZONE1 := Color(0.85, 0.75, 0.50, 1) # Warm dusty brown
const FOG_ZONE2 := Color(0.80, 0.58, 0.38, 1) # Reddish warm
const FOG_ZONE3 := Color(0.65, 0.67, 0.70, 1) # Cool grey mist
const FOG_ZONE4 := Color(0.28, 0.52, 0.28, 1) # Soft green haze

# Zone fog density — higher = thicker fog / shorter visible distance
const DENSITY_ZONE1 := 0.018
const DENSITY_ZONE2 := 0.020
const DENSITY_ZONE3 := 0.022
const DENSITY_ZONE4 := 0.025

const Z2_START := 500.0
const Z3_START := 1000.0
const Z4_START := 1500.0
const BLEND_RANGE := 150.0

var _player: Node3D = null

func _ready():
	if not environment:
		return
	# Fog base settings (Godot 4 valid properties only)
	environment.fog_enabled      = true
	environment.fog_light_color  = FOG_ZONE1
	environment.fog_density      = DENSITY_ZONE1
	environment.fog_sky_affect   = 0.8
	environment.fog_aerial_perspective = 0.5

func _process(_delta):
	if not environment:
		return

	# Lazy-find player
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return

	var dist: float = 0.0
	if _player.has_method("get") and "distance" in _player:
		dist = float(_player.get("distance"))
	else:
		dist = abs(_player.global_position.z)

	var target_color: Color
	var target_density: float

	if dist >= Z4_START:
		var t = clamp((dist - Z4_START) / BLEND_RANGE, 0.0, 1.0)
		target_color   = FOG_ZONE3.lerp(FOG_ZONE4, t)
		target_density = lerp(DENSITY_ZONE3, DENSITY_ZONE4, t)
	elif dist >= Z3_START:
		var t = clamp((dist - Z3_START) / BLEND_RANGE, 0.0, 1.0)
		target_color   = FOG_ZONE2.lerp(FOG_ZONE3, t)
		target_density = lerp(DENSITY_ZONE2, DENSITY_ZONE3, t)
	elif dist >= Z2_START:
		var t = clamp((dist - Z2_START) / BLEND_RANGE, 0.0, 1.0)
		target_color   = FOG_ZONE1.lerp(FOG_ZONE2, t)
		target_density = lerp(DENSITY_ZONE1, DENSITY_ZONE2, t)
	else:
		target_color   = FOG_ZONE1
		target_density = DENSITY_ZONE1

	# Smooth transition
	environment.fog_light_color = environment.fog_light_color.lerp(target_color, 0.04)
	environment.fog_density     = lerp(environment.fog_density, target_density, 0.04)
