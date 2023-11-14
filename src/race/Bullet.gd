extends Area
class_name Bullet

export(String) var bullet_impact = "res://src/race/effects/BulletImpact.tscn"
export(String) var gory_impact = "res://src/race/effects/Blood.tscn"
export(float) var mass = 0.7

var velocity:Vector3 = Vector3.ZERO
var creator_car:RigidBody
var damage:float = 0.0

var be:Particles # for spawning
var BulletImpact:Resource
var GoryImpact:Resource

onready var last_pos:Vector3 = get_global_transform().origin # need "actual impact position" (Area has no CCD)

func _enter_tree() -> void:
	BulletImpact = load(bullet_impact)
	GoryImpact = load(gory_impact)

func _physics_process(delta:float) -> void:
	if creator_car.is_in_group("cars") && !Main.is_out_of_map(transform.origin, creator_car.get_parent()):
		last_pos = get_global_transform().origin
		look_at(transform.origin + velocity.normalized(), Vector3.UP)
		transform.origin += velocity * delta
	else:
		queue_free()

func _on_body_entered(body:PhysicsBody) -> void: # signal
	if body != creator_car:
		if body is PhysicalBone:
			hit(body.get_parent().get_parent().get_parent())
		else:
			hit(body)

func hit(target:Spatial) -> void:
	if target.is_in_group("destructibles") && !target.expired:
		target.receive_damage(damage)
		if target.expired:
			if target.is_in_group("ppl"):
				for c in target.skeleton.get_children():
					if c is PhysicalBone:
						c.apply_impulse(target.to_local(last_pos), velocity * mass)
						break
			else:
				target.apply_impulse(target.to_local(last_pos), velocity * mass)
	elif target is RigidBody:
		if !target.is_in_group("no_bullet_physics"):
			target.apply_impulse(target.to_local(last_pos), velocity * mass)
	call_deferred("create_impact_effect", target)
	queue_free()

func create_impact_effect(target:Spatial) -> void:
	if target is Person:
		be = GoryImpact.instance()
		be.transform = target.global_transform
		be.transform.origin = target.translation.linear_interpolate(last_pos, 0.5)
	else:
		be = BulletImpact.instance()
		be.transform = global_transform
		if target.is_in_group("cars"):
			be.transform.origin = get_global_transform().origin
		else:
			be.transform.origin = last_pos
	be.one_shot = true
	be.emitting = true
	for c in be.get_children():
		c.emitting = true
	if creator_car.is_in_group("cars"):
		creator_car.get_parent().add_child(be)
	else:
		get_tree().get_root().add_child(be)
	be = null
