extends Node

# ============================================================
# CollectionManager — Autoload Singleton
# Handles persistent saving/loading of collected Luang Por Khoon coins.
# Save path: user://collection.json
# ============================================================

signal coin_unlocked(coin_id: String)   # Fires when a brand-new coin type is collected

const SAVE_PATH = "user://collection.json"

# All coin definitions with weighted rarity
# weight: higher = more common
const COIN_TABLE : Array = [
	{ "id": "lp_khoon_standard",  "name": "เหรียญหลวงพ่อคูณ รุ่นมาตรฐาน",  "weight": 50 },
	{ "id": "lp_khoon_silver",    "name": "เหรียญหลวงพ่อคูณ เนื้อเงิน",      "weight": 30 },
	{ "id": "lp_khoon_gold",      "name": "เหรียญหลวงพ่อคูณ เนื้อทอง",       "weight": 15 },
	{ "id": "lp_khoon_rare",      "name": "เหรียญหลวงพ่อคูณ รุ่นหายาก",      "weight":  5 },
]

# { coin_id: count }
var collection : Dictionary = {}

func _ready():
	load_collection()

# ─── Public API ──────────────────────────────────────────────

func roll_random_coin() -> Dictionary:
	"""Pick a random coin from COIN_TABLE using weighted RNG."""
	var total_weight := 0
	for entry in COIN_TABLE:
		total_weight += entry["weight"]
	var roll := randi() % total_weight
	var cumulative := 0
	for entry in COIN_TABLE:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry
	return COIN_TABLE[0]  # fallback

func add_coin(coin_id: String) -> bool:
	"""Record a collected coin. Returns true if this is the first time this type was collected."""
	var is_new: bool = not collection.has(coin_id) or collection[coin_id] == 0
	if !collection.has(coin_id):
		collection[coin_id] = 0
	collection[coin_id] += 1
	save_collection()
	if is_new:
		emit_signal("coin_unlocked", coin_id)
	return is_new

func get_count(coin_id: String) -> int:
	return collection.get(coin_id, 0)

func get_coin_info(coin_id: String) -> Dictionary:
	for entry in COIN_TABLE:
		if entry["id"] == coin_id:
			return entry
	return {}

func has_collected(coin_id: String) -> bool:
	return collection.get(coin_id, 0) > 0

# ─── Persistence ─────────────────────────────────────────────

func save_collection():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(collection))
		file.close()

func load_collection():
	if !FileAccess.file_exists(SAVE_PATH):
		collection = {}
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var result = JSON.parse_string(text)
		if result is Dictionary:
			collection = result
		else:
			collection = {}
