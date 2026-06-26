extends SceneTree
func _init():
    var scene = load("res://assets/models/buffalo/buffalorun.glb")
    var node = scene.instantiate()
    print("CHILDREN:")
    for c in node.get_children():
        print("- ", c.name, " (", c.get_class(), ")")
        if c is AnimationPlayer:
            print("  Animations: ", c.get_animation_list())
    quit()
