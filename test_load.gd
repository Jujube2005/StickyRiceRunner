extends SceneTree
func _init():
	var scene = load("res://scenes/coin/coin.tscn")
	if scene:
		print("SUCCESS LOAD COIN")
	else:
		print("FAILED LOAD COIN")
	
	var col_scene = load("res://scenes/main_menu/collection_menu.tscn")
	if col_scene:
		print("SUCCESS LOAD COLLECTION")
	else:
		print("FAILED LOAD COLLECTION")
	quit()
