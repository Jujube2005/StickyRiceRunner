extends Node

@export var kratip_scene: PackedScene
@export var player1: CharacterBody3D
@export var player2: CharacterBody3D

var lanes = [-3, 0, 3]

var spawn_z = -20
@export var spawn_interval = 10

var spawned_kratips = []

func _process(_delta):
	var lead_z = min(player1.global_position.z, player2.global_position.z)
	if lead_z < spawn_z + 80:
		spawn_kratip()
		_cleanup_old_kratips()

func spawn_kratip():
	var used_lanes = []
	for obstacle in get_tree().get_nodes_in_group("obstacle"):
		if abs(obstacle.global_position.z - spawn_z) < 0.5:
			used_lanes.append(obstacle.global_position.x)

	var free_lanes = []
	for lane_x in lanes:
		var blocked = false
		for used in used_lanes:
			if abs(used - lane_x) < 0.1:
				blocked = true
				break
		if not blocked:
			free_lanes.append(lane_x)

	if free_lanes.size() == 0:
		spawn_z -= spawn_interval
		return

	var lane_x = free_lanes[randi() % free_lanes.size()]
	var k = kratip_scene.instantiate()
	k.add_to_group("kratip")
	get_parent().add_child(k)
	# Set height clearly above the road (Road top is at Y=0)
	# Road mesh is 1m thick centered at Y=0.5, so road top is at Y=1.0 in local coords?
	# Wait, ground.tscn says:
	# [node name="RoadBase" type="MeshInstance3D" parent="."]
	# transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)
	# mesh = BoxMesh (size 9, 1, 20)
	# So road surface is at Y = 0.5 + 0.5 = 1.0 relative to Ground root.
	# Ground root is spawned at Y = -1.0 in ground_spawner.gd.
	# So road surface is at Y = -1.0 + 1.0 = 0.0 in World coordinates.
	
	k.global_position = Vector3(lane_x, 1.2, spawn_z)
	spawned_kratips.append(k)
	spawn_z -= spawn_interval

func _cleanup_old_kratips():
	var trail_z = max(player1.global_position.z, player2.global_position.z)
	var i = 0
	while i < spawned_kratips.size():
		var k = spawned_kratips[i]
		if is_instance_valid(k) and k.global_position.z > trail_z + 20:
			k.queue_free()
			spawned_kratips.remove_at(i)
		else:
			i += 1
