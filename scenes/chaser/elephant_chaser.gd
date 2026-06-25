extends Node3D

## ElephantChaser — Visual-only elephant that follows its assigned player.
## The actual gap is managed by GameManager; this scene just renders
## the elephant at the correct distance so the player can see it.
## Set target_player before adding to the tree.

@export var target_player : Node3D = null

var _base_mesh : MeshInstance3D = null
var anim_player: AnimationPlayer = null

func _ready() -> void:
	var elephant_scene: PackedScene = load("res://assets/models/elephant/elephant.glb")
	if elephant_scene:
		var elephant_model: Node3D = elephant_scene.instantiate()
		elephant_model.position = Vector3(0, 0, 0)
		elephant_model.scale = Vector3(0.5, 0.5, 0.5)
		elephant_model.rotation_degrees.y = 270 # User requested 270
		add_child(elephant_model)
		
		# Find and play the first available animation
		anim_player = elephant_model.find_child("AnimationPlayer", true, false)
		if anim_player:
			var anim_list = anim_player.get_animation_list()
			for anim_name in anim_list:
				if anim_name != "RESET":
					var anim = anim_player.get_animation(anim_name)
					if anim:
						anim.loop_mode = Animation.LOOP_LINEAR
					anim_player.play(anim_name)
					break
	else:
		_base_mesh = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(3.0, 4.0, 5.0)
		_base_mesh.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.45, 0.50, 1.0)
		mat.roughness = 0.9
		_base_mesh.material_override = mat
		_base_mesh.position = Vector3(0, 2.0, 0)
		add_child(_base_mesh)

	# Label removed

func _process(_delta: float) -> void:
	if not is_instance_valid(target_player):
		return

	var gap: float = 20.0
	if "elephant_gap" in target_player:
		gap = float(target_player.get("elephant_gap"))
	gap = max(gap, 0.0)

	# Positive Z = behind the player in Godot's right-hand system
	var p_pos: Vector3 = target_player.global_position
	global_position = Vector3(p_pos.x, 0.0, p_pos.z + gap)

	# The gap determines Z position behind the player. No text updates needed now.
