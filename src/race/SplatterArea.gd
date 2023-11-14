extends Area
class_name SplatterArea

export(Wheel.TTType) var splatter_type = Wheel.TTType.BLOOD
export(float) var persistence = 0.25
export(float) var target_radius = 0.34
export(float) var grow_speed = 0.0003

func _on_area_entered(area) -> void: # signal
	if area is WheelArea:
		if area.wheel != null && area.wheel is Wheel:
			area.wheel.set_tt_type(splatter_type)
			area.wheel.tt_reset_time = persistence
			area.wheel.tt_reset_lock = true

func _on_area_exited(area) -> void: # signal
	if area is WheelArea:
		if area.wheel != null && area.wheel is Wheel:
			area.wheel.tt_reset_lock = false
