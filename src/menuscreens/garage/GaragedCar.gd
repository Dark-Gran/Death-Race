extends Spatial
class_name GaragedCar

export(int) var main_mat_index = 1 # which material on MeshInstance is the main one
export(Material) var exploded_material = preload("res://assets/materials/car_exploded.tres")
export(int) var light_mat_index = 6 # which material on MeshInstance is for the reflectors
export(Material) var reflectors_on = preload("res://assets/materials/light_carOn.tres")
export(Material) var reflectors_off = preload("res://assets/materials/light_carOff.tres")

export(float) var normal_map_start = 0.8 # condition at/below which normal map shows
export(float) var normal_map_max = 0.5 # max normal map scale

export(float) var start_offset_y = 0.0

var carlights_enabled:bool = true # "technical" limit

func _enter_tree():
	translation.y += start_offset_y

func set_reflectors(enable:bool) -> void:
	if enable:
		$MeshInstance.set_surface_material(light_mat_index, reflectors_on)
	else:
		$MeshInstance.set_surface_material(light_mat_index, reflectors_off)
	if carlights_enabled:
		$Reflectors.visible = enable

func set_carlights(enable:bool) -> void:
	carlights_enabled = enable
	$Reflectors.visible = carlights_enabled
