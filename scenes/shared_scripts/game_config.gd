extends Node

var game_mode: String = "multiplayer" # "singleplayer" or "multiplayer"
var race_mode: String = "race"        # "race" or "endless"

# Save Data
var total_kratips: int = 0
var best_distance: float = 0.0
var best_score: int = 0

const SAVE_PATH = "user://sticky_rice_save.dat"

func _ready():
	load_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"total_kratips": total_kratips,
			"best_distance": best_distance,
			"best_score": best_score
		}
		file.store_var(data)
		file.close()

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				total_kratips = data.get("total_kratips", 0)
				best_distance = data.get("best_distance", 0.0)
				best_score = data.get("best_score", 0)
			file.close()
