extends Control
class_name LoadingAnimation
#tool

const ROTATION_SPEED:float = 1.0

func _process(delta:float) -> void:
	if visible:
		var change:float = delta*ROTATION_SPEED
		$Gear.rotation = cut_angle_2PI($Gear.rotation+change)
		$Fill.material.set_shader_param("rotation", cut_angle_2PI($Fill.material.get_shader_param("rotation")-change))

func cut_angle_2PI(angle:float) -> float: # static/singleton candidate
	var cut:float = 2.0*PI
	if angle >= cut:
		angle -= cut
	elif angle <= -cut:
		angle += cut
	return angle
