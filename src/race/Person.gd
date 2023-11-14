extends Destructible
class_name Person

const ANIMATION_BLEND:float = 0.15
const GoryImpact:PackedScene = preload("res://src/race/effects/Blood.tscn")

const SPLATTER_OFFSET_Y:float = 0.02
const BloodSplatter:PackedScene = preload("res://src/race/effects/BloodSplatter.tscn")
const BloodArea:PackedScene = preload("res://src/race/effects/SplatterArea.tscn")

export(float) var collision_fragility = 0.02

enum Pose {CHEER_0, CHEER_1, STAND_0, BUM_0, WOUNDED, DANCE_F_0, SIT_CIG, MAX}
export(Pose) var pose = Pose.CHEER_0

export(bool) var fan = true

var speed:float = 1.0 # for animations

const BLOOD_TRACK_PERSISTENCE:float = 0.1

const BLEED_DELAY:float = 0.5
const BLEED_MOVE_TOLERANCE:float = 0.1
onready var skeleton = get_child(0).get_node("Skeleton")
onready var chest_bone = skeleton.get_node("Physical Bone Chest")
onready var last_chest_pos:Vector3 = chest_bone.get_global_transform().origin
var idle_time:float = 0.0
var bled:bool = false
var last_splatter:GrowMask2D = null

func _enter_tree() -> void:
	set_pose(pose)
	$AnimationPlayer.advance(Main.rng.randf_range(0.0, 1.0))

func _physics_process(delta:float) -> void:
	if !expired:
		if fan && pose != Pose.WOUNDED:
			var direction_to_closest:Vector3 = Vector3.ZERO
			var lowest_distance:float = -1.0
			for car in get_tree().get_nodes_in_group("cars"):
				if !car.expired && car.input_type != Car.InputType.NONE:
					var distance:float = translation.distance_to(car.translation)
					if lowest_distance < 0.0 || distance < lowest_distance:
						lowest_distance = distance
						direction_to_closest = car.translation-translation
			var look_angle:float = lerp_angle(rotation.y, atan2(direction_to_closest.x, direction_to_closest.z), 1)
			if lowest_distance > 0.0:
				rotation.y = look_angle
	else:
		if !bled || last_splatter != null:
			if last_chest_pos.distance_to(chest_bone.get_global_transform().origin) <= BLEED_MOVE_TOLERANCE:
				idle_time += delta
			else:
				last_chest_pos = chest_bone.get_global_transform().origin
				idle_time = 0.0
				if last_splatter != null:
					last_splatter.finish()
					last_splatter = null
			if !bled:
				if idle_time >= BLEED_DELAY:
					spawn_blood_splatter(chest_bone.translation)
					bled = true

func _on_body_entered(body:PhysicsBody) -> void: # signal
	if !(body is StaticBody) && (!(body is RigidBody) || body.linear_velocity.length() > 0.0):
		if body.is_in_group("cars"):
			expire()
		var coll_norm:Vector3 = (translation-body.translation).normalized()
		var dmg:float = body.mass*collision_fragility
		if body is PhysicalBone:
			dmg *= 2.0
		else:
			dmg *= (coll_norm.dot(body.linear_velocity)*coll_norm).length() # actually the original velocity is already overwritten by physics reaction
		receive_damage(dmg)
	if body.is_in_group("cars"):
		spawn_blood(global_transform, translation.linear_interpolate(body.translation, 0.08))
	elif body is StaticBody:
		spawn_blood(global_transform, translation)
	else:
		spawn_blood(global_transform, translation.linear_interpolate(body.translation, 0.4))

func spawn_blood(tf:Transform, pos:Vector3) -> void:
	var gp:Particles = GoryImpact.instance()
	gp.transform = tf
	gp.transform.origin = pos
	gp.one_shot = true
	gp.emitting = true
	for c in gp.get_children():
		c.emitting = true
	get_parent().add_child(gp)

func spawn_blood_splatter(pos:Vector3) -> void:
	var tiles:Array = Wheel.get_tt_tiles(pos, get_parent())
	for tile in tiles:
		new_blood_splatter(pos, tile)

func new_blood_splatter(pos:Vector3, tile:int) -> void:
	# 3D
	var area:SplatterArea = BloodArea.instance()
	area.transform.origin = pos
	get_parent().add_child(area)
	# 2D
	var splatter:GrowMask2D = BloodSplatter.instance()
	splatter.rotation = Main.rng.randf_range(0.0, PI*2.0)
	splatter.transform.origin = Wheel.vector3_to_tt(pos, tile, get_parent())
	splatter.splatter_area = area
	get_tree().get_root().get_node("ViewportsTT//ViewportTT_"+String(tile)).add_child(splatter)
	last_splatter = splatter

func receive_damage(dmg:float) -> void:
	.receive_damage(dmg)
	if !expired:
		set_pose(Pose.WOUNDED)

func expire() -> void:
	.expire()
	skeleton.get_node("PersonalSpace").queue_free()
	activate_ragdoll()

func activate_ragdoll() -> void:
	$AnimationPlayer.stop()
	var attachements:Array = []
	for c in skeleton.get_children():
		if c is PhysicalBone:
			activate_basic_collisions(c)
	skeleton.physical_bones_start_simulation()

func activate_basic_collisions(body:PhysicsBody) -> void: # static/singleton candidate
	body.set_collision_layer_bit(0, true)
	body.set_collision_mask_bit(0, true)
	body.set_collision_layer_bit(1, true)
	body.set_collision_mask_bit(1, true)
	body.set_collision_layer_bit(2, true)
	body.set_collision_mask_bit(2, true)

func set_pose(p:int) -> void:
	pose = p
	match p:
		Pose.CHEER_0:
			speed = 0.95
		Pose.CHEER_1:
			speed = 1.15
		Pose.DANCE_F_0:
			speed = 1.5
		_:
			speed = 1.0
	$AnimationPlayer.play(get_animation_name(p), ANIMATION_BLEND, speed)

func get_animation_name(p:int) -> String:
	var ani:String = "_rest"
	match p:
		Pose.CHEER_0:
			ani = "cheer_0 -loop"
		Pose.CHEER_1:
			ani = "cheer_1 -loop"
		Pose.STAND_0:
			ani = "stand_0 -loop"
		Pose.BUM_0:
			ani = "bum_0 -loop"
		Pose.WOUNDED:
			ani = "wounded -loop"
		Pose.DANCE_F_0:
			ani = "dance_woman_0 -loop"
		Pose.SIT_CIG:
			ani = "sit_cigarette -loop"
	return ani
