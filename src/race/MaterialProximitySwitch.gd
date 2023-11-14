extends Spatial
class_name MaterialProximitySwitch # expects MeshInstance as a child

export(Array) var materials_a = []
export(Array) var materials_b = []
export(bool) var is_set_to_a = true

var m_a:Array = []
var m_b:Array = []

func _enter_tree() -> void:
	for s in materials_a:
		m_a.append(load("res://assets/materials/"+s+".tres"))
	for s in materials_b:
		m_b.append(load("res://assets/materials/"+s+".tres"))

func _on_body_entered(body) -> void: # signal from child Area
	if body.is_in_group("cars") && body.input_type == Car.InputType.LOCAL:
		toggle_materials()
		
func _on_body_exited(body) -> void: # signal from child Area
	if body.is_in_group("cars") && body.input_type == Car.InputType.LOCAL:
		toggle_materials()
		
func toggle_materials() -> void:
	if is_set_to_a:
		set_materials(m_b)
	else:
		set_materials(m_a)
	is_set_to_a = !is_set_to_a

func set_materials(materials:Array) -> void:
	for n in materials.size():
		$MeshInstance.set_surface_material(n, materials[n])
