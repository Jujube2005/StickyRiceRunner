extends Control

# --- NODES ---
@onready var panel = $Panel
@onready var overlay = $Overlay
@onready var back_btn = %BackBtn

func _ready():
	_animate_in()
	_update_texts()
	back_btn.pressed.connect(_on_close_pressed)
	LanguageManager.language_changed.connect(func(_l): _update_texts())

func _update_texts():
	if has_node("%TitleLabel"):
		%TitleLabel.text = LanguageManager.t("LBL_HOW_TO_PLAY")
	# Update description labels if they exist
	for child in get_tree().get_nodes_in_group("how_to_desc"):
		child.text = LanguageManager.t("LBL_HTP_DESC")

func _animate_in():
	overlay.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0
	
	var tween = create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _on_close_pressed():
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
