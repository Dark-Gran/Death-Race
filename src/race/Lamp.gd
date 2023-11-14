extends Spatial
class_name Lamp
# There is a limit for how many Lights may affect one Mesh.

export(bool) var active = true
export(int) var emitting = -1 # index of material on a MeshInstance node
export(float) var light_hue = -1

var light:Light

func _enter_tree() -> void:
	set_lights(active)
	if has_node("Light"):
		light = get_node("Light")
	elif has_node("MeshInstance/Light"):
		light = get_node("MeshInstance/Light")
	if light != null && light_hue >= 0:
		light.light_color = Color.from_hsv(light_hue, light.light_color.s, light.light_color.v, light.light_color.a)
		if emitting >= 0:
			var mc:Color = Color.from_hsv(light_hue, $MeshInstance.get_surface_material(emitting).albedo_color.s, $MeshInstance.get_surface_material(emitting).albedo_color.v, $MeshInstance.get_surface_material(emitting).albedo_color.a)
			$MeshInstance.get_surface_material(emitting).albedo_color = mc
			$MeshInstance.get_surface_material(emitting).emission = mc

func set_lights(enable:bool) -> void:
	if light != null:
		light.visible = enable
	if emitting >= 0:
		#for i in emitting:
		$MeshInstance.get_surface_material(emitting).emission_enabled = enable

func toggle_lights() -> void:
	if light != null:
		light.visible = !light.visible
	if emitting >= 0:
		#for i in emitting:
		$MeshInstance.get_surface_material(emitting).emission_enabled = !$MeshInstance.get_surface_material(emitting).emission_enabled

func set_active(a:bool) -> void:
	active = a

func set_shadows(enable:bool) -> void:
	if light != null && light.shadow_enabled != enable:
		light.shadow_enabled = enable
