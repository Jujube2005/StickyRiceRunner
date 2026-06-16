extends Control

# ──────────────────────────────────────────────────────
# CollectionMenu — uses wooden_sign / title_header / rarity card frames
# ──────────────────────────────────────────────────────

@onready var grid_container  = $Panel/GridContainer
@onready var title_label     = $Panel/TitleHeader/TitleLabel
@onready var subtitle_label  = $Panel/SubtitleBox/SubtitleLabel
@onready var counter_label   = $Panel/SubtitleBox/CounterLabel
@onready var close_btn       = $Panel/CloseBtn

# ── Assets ────────────────────────────────────────────
const FONT_BOLD   = "res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf"
const FONT_MEDIUM = "res://assets/textures/UI/Font/Mitr/Mitr-Medium.ttf"

# Card frame textures per rarity
const CARD_FRAMES := {
	"common":    "res://assets/textures/UI/Buttons/Common.png",
	"uncommon":  "res://assets/textures/UI/Buttons/Uncommon.png",
	"rare":      "res://assets/textures/UI/Buttons/Rare.png",
	"legendary": "res://assets/textures/UI/Buttons/Legendary.png",
}

func _ready():
	_setup_labels()
	_populate_collection()
	close_btn.pressed.connect(func(): queue_free())
	LanguageManager.language_changed.connect(func(_l): _refresh_texts())

# ── Label setup ───────────────────────────────────────
func _setup_labels():
	var font_bold   = load(FONT_BOLD)
	var font_medium = load(FONT_MEDIUM)

	# "COLLECTION" title on the header banner
	var ls_title = LabelSettings.new()
	ls_title.font        = font_bold
	ls_title.font_size   = 34
	ls_title.font_color  = Color(1.0, 0.92, 0.6)   # warm gold
	ls_title.outline_size  = 6
	ls_title.outline_color = Color(0.25, 0.1, 0.0)
	title_label.label_settings = ls_title
	title_label.text = LanguageManager.t("LBL_COLLECTION_TITLE")

	# Subtitle "สะสมผ้าไหม"
	var ls_sub = LabelSettings.new()
	ls_sub.font        = font_bold
	ls_sub.font_size   = 22
	ls_sub.font_color  = Color(0.25, 0.1, 0.0)
	subtitle_label.label_settings = ls_sub
	subtitle_label.text = LanguageManager.t("LBL_COLLECTION_SUBTITLE")

	# Counter "X / 4"
	var ls_count = LabelSettings.new()
	ls_count.font        = font_bold
	ls_count.font_size   = 20
	ls_count.font_color  = Color(0.25, 0.1, 0.0)
	counter_label.label_settings = ls_count

	_refresh_texts()

func _refresh_texts():
	title_label.text    = LanguageManager.t("LBL_COLLECTION_TITLE")
	subtitle_label.text = LanguageManager.t("LBL_COLLECTION_SUBTITLE")
	_update_counter()

func _update_counter():
	var total    = CollectionManager.SILK_TABLE.size()
	var collected = 0
	for silk in CollectionManager.SILK_TABLE:
		if CollectionManager.has_collected(silk["id"]):
			collected += 1
	counter_label.text = "%d / %d" % [collected, total]

# ── Card grid ─────────────────────────────────────────
func _populate_collection():
	for child in grid_container.get_children():
		child.queue_free()

	for silk in CollectionManager.SILK_TABLE:
		var card = _create_card(silk["id"], silk["name"], silk.get("texture", ""), silk.get("rarity", "common"))
		grid_container.add_child(card)

	_update_counter()

# ── Single card ───────────────────────────────────────
func _create_card(silk_id: String, silk_name: String, tex_path: String, rarity: String) -> Control:
	var has_item = CollectionManager.has_collected(silk_id)
	var font_bold = load(FONT_BOLD)

	# ── Outer container ──────────────────────
	var container = Control.new()
	container.custom_minimum_size = Vector2(190, 240)

	# ── Card frame (rarity image) ─────────────
	var frame_path = CARD_FRAMES.get(rarity, CARD_FRAMES["common"])
	var card_frame = TextureRect.new()
	card_frame.texture = load(frame_path)
	card_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Locked cards: greyscale + darker
	if not has_item:
		card_frame.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	container.add_child(card_frame)

	# ── Silk texture (center oval area) ──────
	if has_item and tex_path != "" and ResourceLoader.exists(tex_path):
		var silk_rect = TextureRect.new()
		silk_rect.texture = load(tex_path)
		silk_rect.layout_mode = 1
		silk_rect.set_anchor(SIDE_LEFT,   0.12)
		silk_rect.set_anchor(SIDE_RIGHT,  0.88)
		silk_rect.set_anchor(SIDE_TOP,    0.08)
		silk_rect.set_anchor(SIDE_BOTTOM, 0.72)
		silk_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		silk_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(silk_rect)
	else:
		# Show "?" when locked
		var q_lbl = Label.new()
		q_lbl.text = "?"
		q_lbl.layout_mode = 1
		q_lbl.set_anchor(SIDE_LEFT,   0.0)
		q_lbl.set_anchor(SIDE_RIGHT,  1.0)
		q_lbl.set_anchor(SIDE_TOP,    0.05)
		q_lbl.set_anchor(SIDE_BOTTOM, 0.7)
		var ls_q = LabelSettings.new()
		ls_q.font       = font_bold
		ls_q.font_size  = 64
		ls_q.font_color = Color(0.6, 0.6, 0.6, 0.7)
		q_lbl.label_settings = ls_q
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		container.add_child(q_lbl)

	# ── Name label (bottom of card) ───────────
	var name_lbl = Label.new()
	name_lbl.text = silk_name if has_item else "???"
	name_lbl.layout_mode = 1
	name_lbl.set_anchor(SIDE_LEFT,   0.0)
	name_lbl.set_anchor(SIDE_RIGHT,  1.0)
	name_lbl.set_anchor(SIDE_TOP,    0.76)
	name_lbl.set_anchor(SIDE_BOTTOM, 1.0)
	var ls_name = LabelSettings.new()
	ls_name.font       = font_bold
	ls_name.font_size  = 17
	ls_name.font_color = Color(1.0, 0.95, 0.8) if has_item else Color(0.5, 0.5, 0.5)
	ls_name.outline_size  = 4
	ls_name.outline_color = Color(0.15, 0.05, 0.0)
	name_lbl.label_settings = ls_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(name_lbl)

	# ── Hover scale animation ─────────────────
	if has_item:
		container.mouse_entered.connect(func():
			var tw = create_tween()
			tw.tween_property(container, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		container.mouse_exited.connect(func():
			var tw = create_tween()
			tw.tween_property(container, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)

	return container
