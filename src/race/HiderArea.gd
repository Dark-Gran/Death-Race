extends Area # Hides its parent when a body is overlapping
class_name HiderArea

func _physics_process(delta:float) -> void:
	if get_parent() is Particles:
		get_parent().emitting = get_overlapping_bodies().size() == 0
	else:
		get_parent().visible = get_overlapping_bodies().size() == 0
