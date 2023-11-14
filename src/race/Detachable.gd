extends Destructible  # Must be used on a RigidBody node! (not "just Spatial")
class_name Detachable

const DETACH_MASS:float = 0.25 # % of mass

export(float) var resistance_factor = 40.0
export(bool) var extinguishable = false # only for those with Fire
export(bool) var fragile = false # breakability by ragdolls
export(String) var after_effect = ""
export(Vector3) var offset_origin = Vector3.ZERO # moves center of mass on detach()

var AfterEffect:Resource
var ae:Node

func _enter_tree() -> void:
	add_to_group("detachables")
	if after_effect != "":
		AfterEffect = load(after_effect)

func _on_body_entered(body:PhysicsBody) -> void: # Area signal
	if !expired:
		if (body is RigidBody && body.mass >= DETACH_MASS*self.mass) || (fragile && body is PhysicalBone):
			var force:Vector3
			if body is RigidBody:
				force = body.linear_velocity
			elif body is PhysicalBone:
				force = body.get_parent().get_parent().get_parent().chest_bone.get_global_transform().origin-body.get_parent().get_parent().get_parent().last_chest_pos
			var impulse:Vector3 = -force.normalized()*self.mass*resistance_factor
			force *= body.mass
			if abs(impulse.length()) > abs(force.length()):
				impulse = -force
			body.apply_central_impulse(impulse)
			expire()

func detach() -> void:
	# Disable no more needed
	$Area.queue_free()
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		$AnimationPlayer.queue_free()
	if has_node("Fire") && extinguishable:
		$Fire.queue_free()
	# Physics
	self.mode = RigidBody.MODE_RIGID
	call("set_collision_layer_bit", 1, true)
	call("set_collision_mask_bit", 1, true)
	call("set_collision_layer_bit", 2, true)
	call("set_collision_mask_bit", 2, true)
	# Fix Center of Mass
	if offset_origin != Vector3.ZERO:
		var o:Vector3 = offset_origin.rotated(Vector3.UP, rotation.z)
		for c in get_children():
			if c is MeshInstance || c is CollisionShape:
				c.translate(offset_origin)
		translate(-offset_origin)
	# Effect behind
	if AfterEffect != null:
		ae = AfterEffect.instance()
		if has_node("AfterEffectPosition"):
			ae.transform = $AfterEffectPosition.global_transform
		else:
			ae.transform = global_transform
		get_parent().add_child(ae)

func expire() -> void:
	.expire()
	detach()
