extends Spatial
class_name ParticleColorSwitcher
# Switches between two particle emitters (to avoid recoloring already emitted particles)
# Note: If more types of particle switchers become necessary, base class with a general "_switch" method for overriding should be considered
# (Avoided until needed, despite being a general convention, because of Godots preferences)

onready var active_smoke:Particles = $Smoke1

func set_emitting(enable:bool) -> void:
	if enable:
		active_smoke.emitting = true
	else:
		$Smoke1.emitting = enable
		$Smoke2.emitting = enable

func switch_color(new_color:Color) -> void:
	var new_smoke:Particles
	if $Smoke1 == active_smoke:
		new_smoke = $Smoke2
	else:
		new_smoke = $Smoke1
	if active_smoke != null:
		active_smoke.emitting = false
	set_active(new_smoke)
	active_smoke.material_override.albedo_color = new_color

func set_active(smoke:Particles) -> void:
	active_smoke = smoke
