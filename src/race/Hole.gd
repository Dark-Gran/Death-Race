extends Area
class_name Hole
# MONITORING FOR WHEELAREAS
# (unmonitorable)

export(float) var explosion_delay = 1.25
export(float) var magnet_force = 0.05
export(bool) var water = false

var cars:Dictionary = {} # Car : int

func _on_area_entered(area:Area) -> void: # signal
	if area is WheelArea:
		if !area.get_parent().lost_control && cars.has(area.get_parent()):
			cars[area.get_parent()] += 1
			if cars[area.get_parent()] >= 2:
				area.get_parent().fall_in_hole(explosion_delay, magnet_force, to_global($Magnet.translation), water)
		else:
			cars[area.get_parent()] = 1

func _on_area_exited(area) -> void:
	if area is WheelArea:
		if !area.get_parent().lost_control && cars.has(area.get_parent()):
			cars[area.get_parent()] -= 1
			if cars[area.get_parent()] < 0:
				cars[area.get_parent()] = 0
