extends Spatial
class_name Destructible

export(float) var condition = 3.0
export(bool) var expired = false

onready var max_condition:float

func _enter_tree() -> void:
	add_to_group("destructibles")

func _ready() -> void:
	if expired || condition <= 0.0:
		expire()

func receive_damage(dmg:float) -> void:
	if dmg > 0.0:
		condition -= dmg
		if condition <= 0.0:
			expire()

func expire() -> void:
	expired = true
