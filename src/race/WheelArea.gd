extends Area
class_name WheelArea

export(NodePath) var wheel_path
onready var wheel:Wheel = get_node(wheel_path)

func _on_area_entered(area:Area) -> void: # signal
	if !get_parent().expired:
		if area is HitArea:
			get_parent().wheel_hit(self, area)

func _on_area_exited(area) -> void: # signal
	if !get_parent().expired:
		if area is HitArea:
			get_parent().wheel_hit_exit(self, area)
