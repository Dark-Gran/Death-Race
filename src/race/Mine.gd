extends Area
class_name Mine

export(float) var damage = 25.0
export(float) var push = 5000.0

var Explosion:Resource = preload("res://src/race/effects/MineExplosion.tscn")
const MineSplatter:PackedScene = preload("res://src/race/effects/MineSplatter.tscn")

func _on_body_entered(body:Node):
	if body.is_in_group("cars"):
		body.receive_damage(damage)
		var dir:Vector3 = body.global_transform.origin-global_transform.origin
		dir.y = 0.0
		body.apply_central_impulse(dir.normalized()*push)
		# Explosion effect
		var e = Explosion.instance()
		e.transform = global_transform
		e.transform.origin.y += 0.5
		e.one_shot = true
		e.emitting = true
		get_parent().add_child(e)
		# Mine splatter
		var tiles:Array = Wheel.get_tt_tiles(global_transform.origin, get_parent())
		for tile in tiles:
			new_mine_splatter(global_transform.origin, tile)
		# finish
		queue_free()

func new_mine_splatter(pos:Vector3, tile:int) -> void:
	var splatter:Sprite = MineSplatter.instance()
	splatter.rotation = Main.rng.randf_range(0.0, PI*2.0)
	splatter.transform.origin = Wheel.vector3_to_tt(pos, tile, get_parent())
	get_tree().get_root().get_node("ViewportsTT//ViewportTT_"+String(tile)).add_child(splatter)
