extends Node
# =============================================================================
# UIClickSound — Autoload
# ฟัง SceneTree.node_added และ connect ปุ่มทุกตัวโดยอัตโนมัติ
# เพิ่ม Autoload ใน Project Settings → Autoload ชื่อ "UIClickSound"
# =============================================================================

func _ready() -> void:
	# Hook ทุก node ที่ถูกเพิ่มในอนาคต
	get_tree().node_added.connect(_on_node_added)
	# Hook ทุก node ที่มีอยู่แล้วในซีนแรก
	_scan_tree(get_tree().root)

func _on_node_added(node: Node) -> void:
	_try_connect(node)

func _scan_tree(root: Node) -> void:
	for child in root.get_children():
		_try_connect(child)
		_scan_tree(child)

func _try_connect(node: Node) -> void:
	if node is BaseButton:
		# ป้องกันการ connect ซ้ำ
		if not node.pressed.is_connected(_play_click):
			node.pressed.connect(_play_click)

func _play_click() -> void:
	AudioManager.play_sfx("ui_click")
