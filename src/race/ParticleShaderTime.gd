extends Particles
class_name ParticleShaderTime

export(bool) var imported_mesh = false

var time:float = 0.0

func _process(delta:float) -> void:
	time += delta
	if !imported_mesh:
		draw_pass_1.material.set_shader_param("time", time)
	else:
		draw_pass_1.surface_get_material(0).set_shader_param("time", time)
