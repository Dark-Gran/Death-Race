extends Area
class_name Checkpoint

export(int) var id = 0
export(bool) var botpoint = false
export(int) var route = 0 # for botpoints

func _on_body_entered(body) -> void: # signal
	if body.is_in_group("cars"):
		body.encountered_checkpoint(id, botpoint, route)
