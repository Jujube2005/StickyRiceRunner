extends Area3D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body) -> void:
	var node_body := body as Node
	if node_body and node_body.has_method("stun"):
		node_body.call("stun", 2.0)
		queue_free()
