extends Spatial
class_name PickupSpawn

export(Pickup.PickupType) var pickup_type = Pickup.PickupType.MAX # max -> random
export(Pickup.PickupType) var force_first = Pickup.PickupType.MAX # max -> no force
export(float) var respawn_time = 27.0
export(float) var radius = 2.95 # CollisionShape children serve only as an in-editor aid
export(float) var power = -1 # pickup power override

const Ammo:PackedScene = preload("res://src/race/pickups/Ammo.tscn")
const Cash:PackedScene = preload("res://src/race/pickups/Cash.tscn")
const Mushroom:PackedScene = preload("res://src/race/pickups/Mushroom.tscn")
const Nitro:PackedScene = preload("res://src/race/pickups/Nitro.tscn")
const Repair:PackedScene = preload("res://src/race/pickups/Repair.tscn")

# 0 Health, 1 Nitro, 2 Ammo, 3 Cash, 4 Mushroom
const Spawn_Chances:Array = [20, 50, 80, 90, 100] # int only atm; no need to end at 100 (but percentages are comfortable)

var respawn_timer:float = 0.0

func _enter_tree() -> void:
	if force_first == Pickup.PickupType.MAX:
		spawn_next()
	else:
		spawn(force_first)

func spawn_next() -> void:
	var type:int = pickup_type
	if type == Pickup.PickupType.MAX:
		type = get_random_type()
	spawn(type)

func spawn(type:int) -> void:
	var inst:Pickup
	match type:
		Pickup.PickupType.HEALTH:
			inst = Repair.instance()
		Pickup.PickupType.NITRO:
			inst = Nitro.instance()
		Pickup.PickupType.AMMO:
			inst = Ammo.instance()
		Pickup.PickupType.CASH:
			inst = Cash.instance()
		Pickup.PickupType.MUSHROOM:
			inst = Mushroom.instance()
	if inst != null:
		var pos:Vector2 = get_random_point_in_circle(radius)
		inst.translate(Vector3(pos.x, 0.0, pos.y))
		if power > -1:
			inst.power = power
		add_child(inst)

# UPDATE

func _physics_process(delta:float):
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			spawn_next()

func picked_up(pickup:Pickup): # called by Pickup
	respawn_timer = respawn_time

# RANDOMS

func get_random_type() -> int:
	var dice_roll:int = Main.rng.randi_range(0, Spawn_Chances[Spawn_Chances.size()-1])
	for ix in Spawn_Chances.size()-1:
		if dice_roll < Spawn_Chances[ix]:
			return ix
	return 0

func get_random_point_in_circle(rad:float) -> Vector2: # candidate for moving to Main (the moment it's used outside this class)
	var r:float = rad * sqrt(Main.rng.randf_range(0, 1))
	var theta:float = Main.rng.randf_range(0, 1) * 2 * PI
	var x:float = r * cos(theta) # center 0, 0
	var y:float = r * sin(theta)
	return Vector2(x, y)
