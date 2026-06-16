extends Node

# ============================================================
# CollectionManager — Autoload Singleton
# Handles persistent saving/loading of collected Silk.
# Save path: user://collection.json
# ============================================================

signal silk_unlocked(silk_id: String)   # Fires when a brand-new silk type is collected

const SAVE_PATH = "user://collection.json"

# All silk definitions with weighted rarity
# weight: higher = more common
const SILK_TABLE : Array = [
	{ "id": "silk_basic",    "name": "ผ้าไหม พื้นบ้าน", "texture": "res://assets/textures/Silk/silk.png",         "rarity": "common",    "weight": 50 },
	{ "id": "silk_praewa",   "name": "ผ้าไหม แพรวา",    "texture": "res://assets/textures/Silk/silk_praewa.png",  "rarity": "uncommon",  "weight": 30 },
	{ "id": "silk_mudmee",   "name": "ผ้าไหม มัดหมี่",   "texture": "res://assets/textures/Silk/silk_mudmee.png",  "rarity": "rare",      "weight": 15 },
	{ "id": "silk_yokthong", "name": "ผ้าไหม ยกทอง",    "texture": "res://assets/textures/Silk/silk_yokthong.png","rarity": "legendary", "weight":  5 },
]

# Old coin ID → new silk ID migration map
const COIN_MIGRATION : Dictionary = {
	"lp_khoon_standard": "silk_basic",
	"lp_khoon_silver":   "silk_praewa",
	"lp_khoon_gold":     "silk_mudmee",
	"lp_khoon_rare":     "silk_yokthong",
	"silk_punbaan":      "silk_basic",  # rename from early dev
}

# { silk_id: count }
var collection : Dictionary = {}

func _ready():
	load_collection()

# ─── Public API ──────────────────────────────────────────────

func roll_random_silk() -> Dictionary:
	"""Pick a random silk from SILK_TABLE using weighted RNG."""
	var total_weight := 0
	for entry in SILK_TABLE:
		total_weight += entry["weight"]
	var roll := randi() % total_weight
	var cumulative := 0
	for entry in SILK_TABLE:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry
	return SILK_TABLE[0]  # fallback

func add_silk(silk_id: String) -> bool:
	"""Record a collected silk. Returns true if this is the first time this type was collected."""
	var is_new: bool = not collection.has(silk_id) or collection[silk_id] == 0
	if !collection.has(silk_id):
		collection[silk_id] = 0
	collection[silk_id] += 1
	save_collection()
	if is_new:
		emit_signal("silk_unlocked", silk_id)
	return is_new

func get_count(silk_id: String) -> int:
	return collection.get(silk_id, 0)

func get_silk_info(silk_id: String) -> Dictionary:
	for entry in SILK_TABLE:
		if entry["id"] == silk_id:
			return entry
	return {}

func has_collected(silk_id: String) -> bool:
	return collection.get(silk_id, 0) > 0

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
	_migrate_old_coins()

func _migrate_old_coins():
	"""Convert old coin keys (lp_khoon_*) to new silk keys."""
	var migrated := false
	for old_id in COIN_MIGRATION.keys():
		if collection.has(old_id):
			var new_id : String = COIN_MIGRATION[old_id]
			var old_count : int = collection[old_id]
			if !collection.has(new_id):
				collection[new_id] = 0
			collection[new_id] += old_count
			collection.erase(old_id)
			migrated = true
			print("[CollectionManager] Migrated '%s' (%d) → '%s'" % [old_id, old_count, new_id])
	if migrated:
		save_collection()
		print("[CollectionManager] Save migration complete.")
