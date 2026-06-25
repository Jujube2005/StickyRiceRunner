extends WorldEnvironment

# Zone fog colors matching the ground dirt palette
# Zone 1: Warm dusty brown  (default)
# Zone 2: Reddish warm
# Zone 3: Cool grey mist
# Zone 4: Soft green haze

const FOG_ZONE1 := Color(0.85, 0.75, 0.50, 1) # Brown / dusty
const FOG_ZONE2 := Color(0.80, 0.58, 0.38, 1) # Reddish warm
const FOG_ZONE3 := Color(0.65, 0.67, 0.70, 1) # Cool grey mist
const FOG_ZONE4 := Color(0.28, 0.52, 0.28, 1) # Soft green haze

# Distance thresholds (must match ground_spawner.gd)
const Z1_START := 0.0
const Z2_START := 500.0
const Z3_START := 1000.0
const Z4_START := 1500.0
const BLEND_RANGE := 150.0

var _player: Node3D = null

func _ready():
	# Ensure fog is on
	if environment:
		environment.fog_enabled = true
		environment.fog_density = 0.003
		environment.fog_depth_begin = 30.0
		environment.fog_depth_end   = 200.0
		environment.fog_light_color = FOG_ZONE1
		environment.fog_sky_affect  = 0.5

func _process(_delta):
	if not environment:
		return

	# Lazy-find player
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return

	var dist = abs(_player.global_position.z - _player.get_meta("start_z", 0.0)) \
		if _player.has_meta("start_z") \
		else abs(_player.global_position.z)

	var target_color: Color

	if dist >= Z4_START:
		var t = clamp((dist - Z4_START) / BLEND_RANGE, 0.0, 1.0)
		target_color = FOG_ZONE3.lerp(FOG_ZONE4, t)
	elif dist >= Z3_START:
		var t = clamp((dist - Z3_START) / BLEND_RANGE, 0.0, 1.0)
		target_color = FOG_ZONE2.lerp(FOG_ZONE3, t)
	elif dist >= Z2_START:
		var t = clamp((dist - Z2_START) / BLEND_RANGE, 0.0, 1.0)
		target_color = FOG_ZONE1.lerp(FOG_ZONE2, t)
	else:
		target_color = FOG_ZONE1

	# Smooth lerp so fog doesn't snap
	environment.fog_light_color = environment.fog_light_color.lerp(target_color, 0.05)
