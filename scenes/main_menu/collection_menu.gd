extends Control

@onready var grid_container = $Panel/ScrollContainer/GridContainer
@onready var title_label = $Panel/TitleLabel

var font_resource: Font = preload("res://assets/textures/UI/Font/Mitr/Mitr-Bold.ttf")

func _ready():
	_setup_ui()
	_populate_collection()
	$Panel/CloseBtn.pressed.connect(func(): queue_free())

func _setup_ui():
	# Title
	var ls = LabelSettings.new()
	ls.font_size = 36
	if font_resource: ls.font = font_resource
	ls.font_color = Color(1.0, 0.8, 0.2)
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
	style.border_color = Color(1.0, 0.7, 0.1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	$Panel.add_theme_stylebox_override("panel", style)

func _populate_collection():
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()
		
	var all_coins = CollectionManager.COIN_TABLE
	
	for coin in all_coins:
		var item = _create_coin_item(coin["id"], coin["name"])
		grid_container.add_child(item)

func _create_coin_item(coin_id: String, coin_name: String) -> Control:
	var count = CollectionManager.get_count(coin_id)
	var has_collected = count > 0
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(180, 220)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Icon background
	var icon_bg = Panel.new()
	icon_bg.custom_minimum_size = Vector2(120, 120)
	icon_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 60
	bg_style.corner_radius_top_right = 60
	bg_style.corner_radius_bottom_left = 60
	bg_style.corner_radius_bottom_right = 60
	icon_bg.add_theme_stylebox_override("panel", bg_style)
	
	# Label "?" if not collected
	var icon_lbl = Label.new()
	icon_lbl.text = "✓" if has_collected else "?"
	var ls_icon = LabelSettings.new()
	ls_icon.font_size = 60
	if font_resource: ls_icon.font = font_resource
	if has_collected:
		if "เงิน" in coin_name: ls_icon.font_color = Color(0.8, 0.8, 0.9)
		elif "ทอง" in coin_name: ls_icon.font_color = Color(1.0, 0.8, 0.0)
		elif "หายาก" in coin_name: ls_icon.font_color = Color(1.0, 0.4, 0.8)
		else: ls_icon.font_color = Color(0.9, 0.6, 0.1)
	else:
		ls_icon.font_color = Color(0.4, 0.4, 0.4)
	icon_lbl.label_settings = ls_icon
	icon_lbl.set_anchors_preset(Control.PRESET_CENTER)
	icon_bg.add_child(icon_lbl)
	
	vbox.add_child(icon_bg)
	
	# Name Label
	var name_lbl = Label.new()
	name_lbl.text = coin_name if has_collected else "???"
	var ls_name = LabelSettings.new()
	ls_name.font_size = 18
	if font_resource: ls_name.font = font_resource
	ls_name.font_color = Color.WHITE if has_collected else Color(0.5, 0.5, 0.5)
	name_lbl.label_settings = ls_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(180, 50)
	vbox.add_child(name_lbl)
	
	# Count Label
	var count_lbl = Label.new()
	count_lbl.text = LanguageManager.t("LBL_AMOUNT") + str(count) if has_collected else LanguageManager.t("LBL_NOT_FOUND")
	var ls_count = LabelSettings.new()
	ls_count.font_size = 14
	if font_resource: ls_count.font = font_resource
	ls_count.font_color = Color(0.8, 0.8, 0.8)
	count_lbl.label_settings = ls_count
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_lbl)
	
	return vbox
