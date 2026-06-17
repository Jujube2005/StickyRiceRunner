extends SceneTree

func _init():
	var packed_scene = load("res://assets/models/box/box.glb")
	if packed_scene:
		var instance = packed_scene.instantiate()
		print_tree(instance, "")
	else:
		print("Could not load box.glb")
	quit()

func print_tree(node, indent):
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_tree(child, indent + "  ")
