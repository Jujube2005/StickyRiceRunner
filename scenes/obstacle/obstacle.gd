extends Area3D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body) -> void:
	var node_body := body as Node
	if node_body and node_body.has_method("die"):
		node_body.call("die")
		queue_free()
