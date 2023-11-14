extends Spatial
class_name HingedCrate

var touching_car:bool = false
var touching_wall:bool = false

func _enter_tree() -> void: # make tops ignore each other
	for c in get_children():
		if c.is_in_group("tops"):
			for c2 in get_children():
				if c2 != c && c2.is_in_group("tops"):
					c.add_collision_exception_with(c2)

# Drop hinges when clipping (because of the Momentum vs Opposing Mass issue)
# Highly imperfect (acts even when the clipping is not enough to go through the wall, and also does not account for more objects between the car and the wall) but currently sufficient

func _physics_process(delta:float) -> void:
	if touching_car && touching_wall:
		destroy_hinges()

func destroy_hinges() -> void:
	for c in $CrateBody.get_children():
		if c.is_in_group("hinges"):
			c.free()
	$CrateBody.contact_monitor = false

func _on_body_entered(body:PhysicsBody) -> void: # signal
	if body.is_in_group("cars"):
		touching_car = true
	elif body is StaticBody && !body.is_in_group("floors"):
		touching_wall = true

func _on_body_exited(body:PhysicsBody) -> void: # signal
	if body.is_in_group("cars"):
		touching_car = false
	elif body is StaticBody && !body.is_in_group("floors"):
		touching_wall = false
