extends Detachable # Lamp boiler
class_name DetachableLamp

var parklamp_On:Material = preload("res://assets/materials/light_plampOn.tres")
var parklamp_Off:Material = preload("res://assets/materials/light_plampOff.tres")

# LAMP BOILER

export(bool) var active = true
export(int) var emitting = 0
export(float) var light_hue = -1

func _enter_tree() -> void:
	set_lights(active)
	if light_hue >= 0:
		$Light.light_color = Color.from_hsv(light_hue, $Light.light_color.s, $Light.light_color.v, $Light.light_color.a)
		#if emitting >= 0:
		#	$MeshInstance.get_surface_material(emitting).albedo_color = Color.from_hsv(light_hue, $MeshInstance.get_surface_material(emitting).albedo_color.s, $MeshInstance.get_surface_material(emitting).albedo_color.v, $MeshInstance.get_surface_material(emitting).albedo_color.a)

func set_active(a:bool) -> void:
	active = a

# LAMP OVERRIDES

func detach() -> void:
	set_lights(false)
	.detach()

func toggle_lights() -> void:
	if emitting >= 0:
		for i in emitting:
			if !$Light.visible:
				$MeshInstance.set_surface_material(i, parklamp_On)
			else:
				$MeshInstance.set_surface_material(i, parklamp_Off)
	$Light.visible = !$Light.visible

func set_lights(enable:bool) -> void:
	$Light.visible = enable
	if emitting >= 0:
		for i in emitting:
			if enable:
				$MeshInstance.set_surface_material(i, parklamp_On)
			else:
				$MeshInstance.set_surface_material(i, parklamp_Off)
