extends Control

# ──────────────────────────────────────────────────────
# CollectionMenu — uses wooden_sign / title_header / rarity card frames
# ──────────────────────────────────────────────────────

@onready var grid_container  = $Panel/GridContainer
@onready var title_label     = $Panel/TitleHeader/TitleLabel
@onready var subtitle_label  = $Panel/SubtitleBox/SubtitleLabel
@onready var counter_label   = $Panel/SubtitleBox/CounterLabel
@onready var progress_bar    = $Panel/SubtitleBox/TextureProgressBar
@onready var tick_icon       = $Panel/SubtitleBox/TextureProgressBar/TickIcon
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
	_populate_collection()
	close_btn.pressed.connect(func(): queue_free())
	LanguageManager.language_changed.connect(func(_l): _refresh_texts())
	
	if close_btn:
		var orig_scale = close_btn.scale
		var hover_scale = orig_scale * 1.15  # Scale up by 15%
		
		close_btn.mouse_entered.connect(func():
			var tw = create_tween()
			tw.tween_property(close_btn, "scale", hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		close_btn.mouse_exited.connect(func():
			var tw = create_tween()
			tw.tween_property(close_btn, "scale", orig_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)

func _refresh_texts():
	if title_label:
		title_label.text = LanguageManager.t("LBL_COLLECTION_TITLE")
	if subtitle_label:
		subtitle_label.text = LanguageManager.t("LBL_COLLECTION_SUBTITLE")
	_update_counter()

func _update_counter():
	var total    = CollectionManager.SILK_TABLE.size()
	var collected = 0
	for silk in CollectionManager.SILK_TABLE:
		if CollectionManager.has_collected(silk["id"]):
			collected += 1
	
	if counter_label:
		counter_label.text = "%d / %d" % [collected, total]
		
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = collected
		
		if tick_icon:
			# Calculate the ratio (0.0 to 1.0)
			var ratio = float(collected) / float(total) if total > 0 else 0.0
			# Calculate target X position inside the progress bar (local coordinates)
			var target_x = ratio * progress_bar.size.x - (tick_icon.size.x / 2.0)
			# Move the tick smoothly
			var tw = create_tween()
			tw.tween_property(tick_icon, "position:x", target_x, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Card grid ─────────────────────────────────────────
func _populate_collection():
	if grid_container:
		grid_container.hide() # We use the manually placed nodes now
		
	var manual_nodes = {
		"common": $Panel.get_node_or_null("Common"),
		"uncommon": $Panel.get_node_or_null("Uncommon"),
		"rare": $Panel.get_node_or_null("Rare"),
		"legendary": $Panel.get_node_or_null("Legendary")
	}

	for silk in CollectionManager.SILK_TABLE:
		var rarity = silk.get("rarity", "common").to_lower()
		var card_node = manual_nodes.get(rarity)
		if card_node:
			_fill_manual_card(card_node, silk)

	_update_counter()

# ── Fill Single Manual Card ───────────────────────────────────────
func _fill_manual_card(card_node: Control, silk: Dictionary):
	var silk_id = silk["id"]
	var tex_path = silk.get("texture", "")
	var silk_name = silk.get("name", "")
	var has_item = CollectionManager.has_collected(silk_id)
	
	# Clear previous children (if any were added)
	for c in card_node.get_children():
		c.queue_free()

	# ── Silk texture (center oval area) ──────
	if has_item and tex_path != "" and ResourceLoader.exists(tex_path):
		var silk_rect = TextureRect.new()
		silk_rect.texture = load(tex_path)
		silk_rect.layout_mode = 1
		# Move the silk down and adjust to the oval
		silk_rect.set_anchor(SIDE_LEFT,   0.12)
		silk_rect.set_anchor(SIDE_RIGHT,  0.88)
		silk_rect.set_anchor(SIDE_TOP,    0.18)
		silk_rect.set_anchor(SIDE_BOTTOM, 0.78)
		silk_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		silk_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_node.add_child(silk_rect)

	# ── Name label (bottom of card) ───────────
	var font_bold = load(FONT_BOLD)
	var name_lbl = Label.new()
	name_lbl.text = silk_name if has_item else ""
	
	# The parent is scaled by ~7.58. To prevent blurry text, we inverse-scale the label
	var p_scale = card_node.scale.x
	if p_scale <= 0.01: p_scale = 1.0
	var inv_scale = 1.0 / p_scale
	
	name_lbl.scale = Vector2(inv_scale, inv_scale)
	# Position at bottom 22% of the card
	name_lbl.position = Vector2(0, card_node.size.y * 0.78)
	# Set size to match the scaled dimensions so text wraps/aligns correctly
	name_lbl.size = Vector2(card_node.size.x * p_scale, card_node.size.y * 0.22 * p_scale)
	
	var ls_name = LabelSettings.new()
	ls_name.font       = font_bold
	ls_name.font_size  = 22  # Crisp 22px text
	ls_name.font_color = Color(1.0, 0.95, 0.8)
	ls_name.outline_size  = 5
	ls_name.outline_color = Color(0.15, 0.05, 0.0)
	name_lbl.label_settings = ls_name
	
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_node.add_child(name_lbl)

	# ── Hover scale animation ─────────────────
	if has_item:
		var original_scale = card_node.scale
		var hover_scale = original_scale * 1.06
		card_node.mouse_entered.connect(func():
			var tw = create_tween()
			tw.tween_property(card_node, "scale", hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		card_node.mouse_exited.connect(func():
			var tw = create_tween()
			tw.tween_property(card_node, "scale", original_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
