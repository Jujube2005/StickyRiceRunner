extends SceneTree
func _init():
    var anim = load('res://assets/animation/run.glb')
    if anim:
        var scene = anim.instantiate()
        var ap = scene.find_child('AnimationPlayer', true, false)
        if ap:
            var lib = ap.get_animation_library('')
            var list = lib.get_animation_list()
            print('Anims: ', list)
            if list.size() > 0:
                var a = lib.get_animation(list[0])
                if a:
                    for i in range(min(5, a.get_track_count())):
                        print('Track ', i, ': ', a.track_get_path(i))
    quit()
