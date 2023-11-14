extends Area
class_name Pickup

enum PickupType {HEALTH, NITRO, AMMO, CASH, MUSHROOM, MAX}
export(PickupType) var type = PickupType.NITRO
export(float) var power = 50.0
export(String) var pickedup_effect = "res://src/race/pickups/PickedUp.tscn"
export(float) var fade_speed = 3.5

var picked_up:bool = false

var PickedUp:Resource
var pu:Particles

func _enter_tree() -> void:
	PickedUp = load(pickedup_effect)

func _on_body_entered(body) -> void:
	if !picked_up:
		if body is Car:
			if !body.expired:
				match type:
					PickupType.HEALTH:
						body.change_health(body.max_condition*power)
					PickupType.NITRO:
						body.change_nitro(power)
					PickupType.AMMO:
						body.change_ammo(power)
					PickupType.CASH:
						body.change_cash(power)
					PickupType.MUSHROOM:
						body.hallucinate(power)
				picked_up = true
				call_deferred("picked_up")

func picked_up() -> void:
	# Create picked-up effect
	pu = PickedUp.instance()
	pu.transform = global_transform
	pu.transform.origin = $MeshInstance.global_transform.origin
	pu.one_shot = true
	pu.emitting = true
	get_parent().add_child(pu)
	# "Smooth finish"
	$PickupParticles.emitting = false
	$PickupParticles.speed_scale *= 2.0
	$QueueFreeTimer.start()
	$AnimationPlayer.play("FadeAway")
	$AnimationPlayer.playback_speed = fade_speed
	# Disable function
	if has_node("CollisionShape"):
		$CollisionShape.free()
	if get_parent().is_in_group("pickup_spawns"):
		get_parent().picked_up(self)
