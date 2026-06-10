extends SceneTree

func _init():
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file("res://assets/models/ground/road01.glb", gltf_state)
	if err == OK:
		var root = gltf_doc.generate_scene(gltf_state)
		if root:
			var meshes = root.find_children("*", "MeshInstance3D", true, false)
			var aabb = AABB()
			if meshes.size() > 0:
				aabb = meshes[0].get_aabb()
				for i in range(1, meshes.size()):
					aabb = aabb.merge(meshes[i].get_aabb())
			
			var f = FileAccess.open("res://mesh_size.txt", FileAccess.WRITE)
			f.store_string(str(aabb.size.x) + "," + str(aabb.size.y) + "," + str(aabb.size.z))
			f.close()
			root.free()
	quit()
