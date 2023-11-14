extends Node2D
class_name GrowMask2D

export(float) var speed = 0.0001
export(float) var target_scale = 0.115

var finished:bool = false
var splatter_area:SplatterArea

func _physics_process(delta) -> void:
	if !finished:
		if scale.x < target_scale:
			scale.x += speed
			scale.y += speed
			if scale.x > target_scale:
				scale.x = target_scale
				scale.y = target_scale
		if is_instance_valid(splatter_area):
			if splatter_area.get_node("CollisionShape").shape.radius < splatter_area.target_radius:
				splatter_area.get_node("CollisionShape").shape.radius += splatter_area.grow_speed
				if splatter_area.get_node("CollisionShape").shape.radius > splatter_area.target_radius:
					splatter_area.get_node("CollisionShape").shape.radius = splatter_area.target_radius
		if scale.x == target_scale && scale.y == target_scale:
			if is_instance_valid(splatter_area):
				splatter_area.get_node("CollisionShape").shape.radius = splatter_area.target_radius
			finish()
			

func finish() -> void:
	finished = true
	queue_free()
