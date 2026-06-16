extends Control

@onready var grid_container = $Panel/ScrollContainer/GridContainer
@onready var title_label = $Panel/TitleLabel

var font_resource: Font = preload("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")

func _ready():
	_setup_ui()
	_populate_collection()
	$Panel/CloseBtn.pressed.connect(func(): queue_free())
	LanguageManager.language_changed.connect(func(_l): 
		title_label.text = LanguageManager.t("LBL_COLLECTION_TITLE")
	)

func _setup_ui():
	# Title
	var ls = LabelSettings.new()
	ls.font_size = 36
	if font_resource: ls.font = font_resource
	ls.font_color = Color(0.85, 0.5, 1.0)
	ls.outline_size = 6
	ls.outline_color = Color.BLACK
	title_label.label_settings = ls
	title_label.text = LanguageManager.t("BTN_COLLECTION")
	
	# Panel background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.85, 0.5, 1.0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	$Panel.add_theme_stylebox_override("panel", style)

func _populate_collection():
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()
		
	var all_silks = CollectionManager.SILK_TABLE
	
	for silk in all_silks:
		var item = _create_silk_item(silk["id"], silk["name"], silk.get("texture", ""), silk.get("rarity", "common"))
		grid_container.add_child(item)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":  return Color(0.4, 0.85, 0.4)   # green
		"rare":      return Color(0.4, 0.6, 1.0)     # blue
		"legendary": return Color(1.0, 0.75, 0.1)    # gold
		_:           return Color(0.9, 0.9, 0.9)     # common — white/grey

func _create_silk_item(silk_id: String, silk_name: String, tex_path: String, rarity: String) -> Control:
	var count = CollectionManager.get_count(silk_id)
	var has_item = count > 0
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(180, 240)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Icon background
	var icon_bg = Panel.new()
	icon_bg.custom_minimum_size = Vector2(120, 120)
	icon_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.1, 0.2, 0.85) if has_item else Color(0.15, 0.15, 0.15, 0.8)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = _rarity_color(rarity) if has_item else Color(0.3, 0.3, 0.3)
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	icon_bg.add_theme_stylebox_override("panel", bg_style)
	
	if has_item and tex_path != "" and ResourceLoader.exists(tex_path):
		# Show silk texture as preview
		var tex_rect = TextureRect.new()
		tex_rect.texture = load(tex_path)
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(100, 100)
		icon_bg.add_child(tex_rect)
	else:
		# Show "?" if not collected
		var icon_lbl = Label.new()
		icon_lbl.text = "?" if !has_item else "🧵"
		var ls_icon = LabelSettings.new()
		ls_icon.font_size = 56
		if font_resource: ls_icon.font = font_resource
		ls_icon.font_color = _rarity_color(rarity) if has_item else Color(0.4, 0.4, 0.4)
		icon_lbl.label_settings = ls_icon
		icon_lbl.set_anchors_preset(Control.PRESET_CENTER)
		icon_bg.add_child(icon_lbl)
	
	vbox.add_child(icon_bg)
	
	# Rarity badge
	var rarity_lbl = Label.new()
	var rarity_map = {
		"common": "Common", "uncommon": "Uncommon", "rare": "Rare", "legendary": "Legendary"
	}
	rarity_lbl.text = rarity_map.get(rarity, rarity) if has_item else ""
	var ls_rarity = LabelSettings.new()
	ls_rarity.font_size = 13
	if font_resource: ls_rarity.font = font_resource
	ls_rarity.font_color = _rarity_color(rarity)
	ls_rarity.outline_size = 3
	ls_rarity.outline_color = Color.BLACK
	rarity_lbl.label_settings = ls_rarity
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_lbl)
	
	# Name Label
	var name_lbl = Label.new()
	name_lbl.text = silk_name if has_item else "???"
	var ls_name = LabelSettings.new()
	ls_name.font_size = 18
	if font_resource: ls_name.font = font_resource
	ls_name.font_color = Color.WHITE if has_item else Color(0.5, 0.5, 0.5)
	name_lbl.label_settings = ls_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(180, 50)
	vbox.add_child(name_lbl)
	
	# Count Label
	var count_lbl = Label.new()
	count_lbl.text = LanguageManager.t("LBL_AMOUNT") + str(count) if has_item else LanguageManager.t("LBL_NOT_FOUND")
	var ls_count = LabelSettings.new()
	ls_count.font_size = 14
	if font_resource: ls_count.font = font_resource
	ls_count.font_color = Color(0.8, 0.8, 0.8)
	count_lbl.label_settings = ls_count
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_lbl)
	
	return vbox
