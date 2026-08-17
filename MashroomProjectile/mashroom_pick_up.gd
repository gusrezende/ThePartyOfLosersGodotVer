extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("pick_up_mushroom"):
			body.pick_up_mushroom()
		queue_free()
