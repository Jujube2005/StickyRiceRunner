extends Node

# =============================================================================
# VfxManager — Autoload for spawning particle effect scenes
# =============================================================================

const VFX_SCENES := {
	"kratib_pickup":  "res://scenes/effects/kratib_pickup_vfx.tscn",
	"obstacle_hit":   "res://scenes/effects/obstacle_hit_vfx.tscn",
	"skill_use":      "res://scenes/effects/skill_use_vfx.tscn",
	"shield_block":   "res://scenes/effects/shield_block_vfx.tscn",
}

var _loaded: Dictionary = {}

func _ready():
	for key in VFX_SCENES:
		var path: String = VFX_SCENES[key]
		if ResourceLoader.exists(path):
			_loaded[key] = load(path)
		else:
			push_warning("[VFX] Scene not found: " + path)

# Spawn a VFX at world position.
# parent_node: if null, attaches to current scene root.
func spawn(effect_name: String, world_pos: Vector3, parent_node: Node = null) -> void:
	if not _loaded.has(effect_name):
		push_warning("[VFX] Unknown effect: " + effect_name)
		return

	var vfx: CPUParticles3D = _loaded[effect_name].instantiate()
	var target: Node = parent_node if parent_node else get_tree().current_scene
	target.add_child(vfx)
	vfx.global_position = world_pos
	vfx.emitting = true

	# Auto-free after particles finish
	var lifetime: float = vfx.lifetime if "lifetime" in vfx else 2.0
	get_tree().create_timer(lifetime + 0.3).timeout.connect(func():
		if is_instance_valid(vfx):
			vfx.queue_free()
	)
