extends Node

# --- SIGNALS ---
signal language_changed(locale: String)

# --- STATE ---
var current_locale: String = "th"

# --- TRANSLATION TABLE ---
const TRANSLATIONS: Dictionary = {
	"en": {
		# Main Menu
		"BTN_PLAY": "PLAY",
		"BTN_SETTINGS": "SETTINGS",
		"BTN_HOW_TO": "HOW TO",
		"BTN_QUIT": "QUIT",
		# Settings section headers
		"HDR_AUDIO": "AUDIO",
		"HDR_LANGUAGE": "LANGUAGE",
		"HDR_DISPLAY": "DISPLAY",
		# Settings labels
		"LBL_MASTER_VOL": "Master Volume",
		"LBL_MUSIC_VOL": "Music Volume",
		"LBL_SFX_VOL": "SFX Volume",
		"LBL_LANGUAGE": "Language",
		"LBL_FULLSCREEN": "Full screen",
		"BTN_BACK": "BACK",
		"BTN_OK": "OK",
		"LBL_SETTINGS_TITLE": "Settings",
		# Game Over
		"LBL_CHAMPION": "CHAMPION",
		"LBL_FINAL_RESULT": "FINAL RESULT",
		"LBL_P1_WINS": "PLAYER 1 WINS!",
		"LBL_P2_WINS": "PLAYER 2 WINS!",
		"LBL_DRAW": "DRAW!",
		"LBL_SCORE": "Score  P1 %d  vs  P2 %d",
		"LBL_DISTANCE": "Distance  %dm  /  %dm",
		"BTN_PLAY_AGAIN": "Play Again",
		"LBL_WINNER": "WINNER",
		"LBL_PLAYER1": "PLAYER 1",
		"LBL_PLAYER2": "PLAYER 2",
		"LBL_STICKY_RICE": "STICKY RICE",
		# Pause
		"LBL_PAUSED": "PAUSED",
		"LBL_RICE_BREAK": "Rice Break!",
		# How To Play
		"LBL_HOW_TO_PLAY": "How To Play",
		"LBL_HTP_MOVE": "MOVE",
		"LBL_HTP_JUMP": "JUMP",
		"LBL_HTP_SKILL": "Use Skill",
		"LBL_HTP_DESC": "Collect Sticky Rice Baskets to use your skill.",
		# Collection
		"LBL_COLLECTION_TITLE": "Sacred Items",
		# HUD warnings
		"HUD_ROLLING_SKILL": "Rolling Charm...",
		"HUD_GOT_SKILL": "Got: ",
		"HUD_BLOCKED": "Pha Khao Ma blocked!",
		"HUD_SHIELD_READY": "Pha Khao Ma ready!",
		# New UI & Warnings
		"BTN_COLLECTION": "Collection",
		"LBL_AMOUNT": "Amount: ",
		"LBL_NOT_FOUND": "Not Found",
		"LBL_UNLOCK": "Unlocked: ",
		"UI_STAMINA_KRATIP": "Stamina / Kratip",
		"BTN_ROLLING": "Rolling...",
		"BTN_USE_SKILL": "Use Skill!",
		"BTN_SKILL_READY": "Skill Ready",
		"BTN_WAIT": "Wait...",
		"BTN_NOT_READY": "Not Ready",
		"BTN_DEFEND": "Defend",
		"WARN_WARNING": "WARNING\n",
		"WARN_INCOMING": " Incoming!",
		"WARN_SKILL_READY_RELEASE": "Skill Ready!\n",
		"WARN_BLOCKED": "Blocked!",
		"WARN_HIT": "Hit!",
		"WARN_NOTHING_TO_BLOCK": "Nothing to block",
		"WARN_PKM_PROTECT": "Luang Phor Koon Protects!",
		"WARN_PKM_DEFLECT": "Luang Phor Koon Deflects!",
		"WARN_OBTAINED": "Got: ",
		"WARN_USED": "Used: ",
		"WARN_COOLDOWN": "Cooldown...",
		# Skill names
		"SKILL_RICE_YARD_DUST": "Rice Yard Dust",
		"SKILL_BOON_BANG_FAI": "Boon Bang Fai",
		"SKILL_FIELD_WIND": "Field Wind",
		"SKILL_SCREEN_BLUR": "Screen Blur",
		"SKILL_PHA_KHAO_MA": "Pha Khao Ma",
		"SKILL_LANE_SWAP": "Lane Swap",
		"SKILL_PULL_TO_CENTER": "Pull to Center",
		"SKILL_LANE_BLOCK": "Lane Block",
		"SKILL_WIND_PUSH": "Wind Push",
		# Version
		"VERSION_LABEL": "Version 0.1 By Hungry Sleep",
	},
	"th": {
		# Main Menu
		"BTN_PLAY": "เล่น",
		"BTN_SETTINGS": "ตั้งค่า",
		"BTN_HOW_TO": "วิธีเล่น",
		"BTN_QUIT": "ออกจากเกม",
		# Settings section headers
		"HDR_AUDIO": "เสียง",
		"HDR_LANGUAGE": "ภาษา",
		"HDR_DISPLAY": "หน้าจอ",
		# Settings labels
		"LBL_MASTER_VOL": "ระดับเสียงหลัก",
		"LBL_MUSIC_VOL": "เสียงดนตรี",
		"LBL_SFX_VOL": "เสียงเอฟเฟกต์",
		"LBL_LANGUAGE": "ภาษา",
		"LBL_FULLSCREEN": "เต็มจอ",
		"BTN_BACK": "กลับ",
		"BTN_OK": "ตกลง",
		"LBL_SETTINGS_TITLE": "ตั้งค่า",
		# Game Over
		"LBL_CHAMPION": "แชมเปี้ยน",
		"LBL_FINAL_RESULT": "ผลสุดท้าย",
		"LBL_P1_WINS": "ผู้เล่น 1 ชนะ!",
		"LBL_P2_WINS": "ผู้เล่น 2 ชนะ!",
		"LBL_DRAW": "เสมอ!",
		"LBL_SCORE": "คะแนน  P1 %d  vs  P2 %d",
		"LBL_DISTANCE": "ระยะทาง  %dm  /  %dm",
		"BTN_PLAY_AGAIN": "เล่นอีกครั้ง",
		"LBL_WINNER": "ผู้ชนะ",
		"LBL_PLAYER1": "ผู้เล่น 1",
		"LBL_PLAYER2": "ผู้เล่น 2",
		"LBL_STICKY_RICE": "ข้าวเหนียว",
		# Pause
		"LBL_PAUSED": "หยุดชั่วคราว",
		"LBL_RICE_BREAK": "พักดื่มน้ำ!",
		# How To Play
		"LBL_HOW_TO_PLAY": "วิธีเล่น",
		"LBL_HTP_MOVE": "เดิน/วิ่ง",
		"LBL_HTP_JUMP": "กระโดด",
		"LBL_HTP_SKILL": "ใช้สกิล",
		"LBL_HTP_DESC": "เก็บกระติ๊บข้าวเพื่อใช้สกิลของคุณ",
		# Collection
		"LBL_COLLECTION_TITLE": "ของขลังสะสม",
		# HUD warnings
		"HUD_ROLLING_SKILL": "ลุ้นเครื่องรางเทศกาล...",
		"HUD_GOT_SKILL": "ได้: ",
		"HUD_BLOCKED": "ผ้าขาวม้าป้องกันได้!",
		"HUD_SHIELD_READY": "ผ้าขาวม้าพร้อมแล้ว!",
		# New UI & Warnings
		"BTN_COLLECTION": "ของขลังสะสม",
		"LBL_AMOUNT": "จำนวน: ",
		"LBL_NOT_FOUND": "ยังไม่มี",
		"LBL_UNLOCK": "ปลดล็อก: ",
		"UI_STAMINA_KRATIP": "แฮงดี / กระติ๊บข้าว",
		"BTN_ROLLING": "ลุ้นบั้งไฟ...",
		"BTN_USE_SKILL": "จุดบั้งไฟ!",
		"BTN_SKILL_READY": "เตรียมบั้งไฟ",
		"BTN_WAIT": "รอคอยจังหวะ",
		"BTN_NOT_READY": "ยังบ่พร้อม",
		"BTN_DEFEND": "ตั้งรับ",
		"WARN_WARNING": "ระวัง\n",
		"WARN_INCOMING": " กำลังมา!",
		"WARN_SKILL_READY_RELEASE": "บั้งไฟพร้อมปล่อย!\n",
		"WARN_BLOCKED": "ป้องได้แล้ว!",
		"WARN_HIT": "ป้องกันบ่ทัน!",
		"WARN_NOTHING_TO_BLOCK": "บ่มีหยังให้ป้อง",
		"WARN_PKM_PROTECT": "หลวงพ่อคูณคุ้มครอง!",
		"WARN_PKM_DEFLECT": "หลวงพ่อคูณปัดเป่า!",
		"WARN_OBTAINED": "เก็บได้: ",
		"WARN_USED": "ใช้สกิล: ",
		"WARN_COOLDOWN": "คูลดาวน์...",
		# Skill names
		"SKILL_RICE_YARD_DUST": "ฝุ่นลาน",
		"SKILL_BOON_BANG_FAI": "บั้งไฟ",
		"SKILL_FIELD_WIND": "ลมทุ่ง",
		"SKILL_SCREEN_BLUR": "หมอกควัน",
		"SKILL_PHA_KHAO_MA": "ผ้าขาวม้า",
		"SKILL_LANE_SWAP": "สลับเลน",
		"SKILL_PULL_TO_CENTER": "ดึงกลาง",
		"SKILL_LANE_BLOCK": "กีดขวาง",
		"SKILL_WIND_PUSH": "ลมผลัก",
		# Version
		"VERSION_LABEL": "Version 0.1 โดย Hungry Sleep",
	}
}

# Map skill string → translation key
const SKILL_KEY_MAP: Dictionary = {
	"Rice Yard Dust": "SKILL_RICE_YARD_DUST",
	"Boon Bang Fai":  "SKILL_BOON_BANG_FAI",
	"Field Wind":     "SKILL_FIELD_WIND",
	"Wind Push":      "SKILL_WIND_PUSH",
	"Screen Blur":    "SKILL_SCREEN_BLUR",
	"Pha Khao Ma":   "SKILL_PHA_KHAO_MA",
	"Lane Swap":      "SKILL_LANE_SWAP",
	"Pull to Center": "SKILL_PULL_TO_CENTER",
	"Lane Block":     "SKILL_LANE_BLOCK",
}

func _ready():
	_load_locale()

# --- PUBLIC API ---

# Translate a key, fallback to key itself if not found
func t(key: String) -> String:
	var lang = TRANSLATIONS.get(current_locale, TRANSLATIONS["th"])
	return lang.get(key, key)

# Translate a skill's internal name
func skill_name(skill_internal: String) -> String:
	var key = SKILL_KEY_MAP.get(skill_internal, "")
	if key == "":
		return skill_internal
	return t(key)

# Get locale index for OptionButton (0 = EN, 1 = TH)
func get_lang_index() -> int:
	return 0 if current_locale == "en" else 1

func set_language(locale: String):
	if locale == current_locale:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	_save_locale()
	language_changed.emit(locale)
	print("[Lang] Locale set to: ", locale)

# --- PRIVATE ---

func _save_locale():
	var config = ConfigFile.new()
	# Load existing to preserve other settings
	config.load("user://settings.cfg")
	config.set_value("settings", "locale", current_locale)
	config.save("user://settings.cfg")

func _load_locale():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_locale = config.get_value("settings", "locale", "th")
	else:
		current_locale = "th"
	TranslationServer.set_locale(current_locale)
	print("[Lang] Locale loaded: ", current_locale)
