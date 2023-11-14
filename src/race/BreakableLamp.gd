extends Lamp
class_name BreakableLamp

export(bool) var broken = false

export(float) var rate = 2.0 # in seconds; 0 = no flicking
export(float) var rate_random = 2.0
export(float) var flicking_length = 0.208 # single flicking session
export(float) var fl_random = 2.0
export(float) var flick_rate = 0.041 # single flick
export(float) var fr_random = 5.0

export(float) var max_shake = 3.0 # set in degrees but turns to radians on enter
export(float) var min_shake_rat = 0.35 # based off max_shake; ensures visible shaking
export(float) var break_treshhold = 5000.0 # collision force needed for breaking
export(float) var break_angle = 8.0 # set in degrees but turns to radians on enter
export(float) var break_speed_boost = 1.5
export(Array) var connected_bodies = [] # body NodePath (rotates its child MeshInstance); for Stoplight addons

const SHAKE_SPEED:float = 0.01
const SHAKE_SPEED_CUT:float = 0.3
const SHAKE_CUT:float = 0.5

var orig_rot:Vector3 = rotation
var base_rot:Vector3 = rotation

var shaking:bool = false
var target_shake:float = 0.0
var target_x:float = 0.0
var target_z:float = 0.0
var x_rat:float = 0.5
var z_rat:float = 0.5
var shake_direction:Vector3 = Vector3.ZERO
var shake_speed:float = SHAKE_SPEED
var shake_speed_x:float = SHAKE_SPEED*x_rat
var shake_speed_z:float = SHAKE_SPEED*z_rat

var flicking:bool = false
var main_time:int = 0
var flick_time:int = 0

var main_limit:int # "actual rate"
var flick_limit:int # "actual flick-length"
var flick:int # "actual flick-rate"

func _enter_tree() -> void:
	# Shaking
	max_shake = deg2rad(max_shake)
	break_angle = deg2rad(break_angle)
	# Flicking
	main_limit = round(rate * Engine.iterations_per_second)
	flick_limit = round(flicking_length * Engine.iterations_per_second)
	flick = round(flick_rate * Engine.iterations_per_second)
	apply_randoms()

func apply_randoms() -> void:
	if rate_random > 1:
		main_limit *= Main.rng.randf_range(1, rate_random)
	if fl_random > 1:
		flick_limit *= Main.rng.randf_range(1, fl_random)
	if fr_random > 1:
		flick *= Main.rng.randf_range(1, fr_random)

func receive_hit(coll_norm:Vector3, dmg:float) -> void: # receives dmg in form of applied force
	shake_direction = Vector3(-coll_norm.x, 0.0, -coll_norm.z).rotated(Vector3.UP, -rotation.y+PI*0.5).normalized()
	var dmg_rat:float = 1.0
	if dmg < break_treshhold:
		dmg_rat = dmg / break_treshhold
		if dmg_rat < min_shake_rat:
			dmg_rat = min_shake_rat
	target_shake = max_shake * dmg_rat
	shake_speed = SHAKE_SPEED * dmg_rat
	if dmg >= break_treshhold && !broken:
		base_rot.x = orig_rot.x + shake_direction.x * break_angle
		base_rot.z = orig_rot.z + shake_direction.z * break_angle
		target_shake -= deg2rad(1.0)
		shake_speed *= break_speed_boost
		broken = true
		flicking = true
	refresh_target_rotations()
	refresh_shake_speeds()
	shaking = true

func refresh_target_rotations() -> void:
	target_x = target_shake*shake_direction.x
	target_z = target_shake*shake_direction.z
	if target_x != 0 && target_z != 0:
		x_rat = abs(target_x)/(abs(target_x)+abs(target_z))
		z_rat = abs(target_z)/(abs(target_x)+abs(target_z))
	else:
		x_rat = 0.5
		z_rat = 0.5
	target_x += base_rot.x
	target_z += base_rot.z

func refresh_shake_speeds() -> void:
	shake_speed_x = shake_speed * x_rat
	shake_speed_z = shake_speed * z_rat

func _physics_process(delta:float) -> void:
	# Shaking
	if shaking:
		refresh_shake_speeds()
		if (shake_speed_x > 0.0 && abs($MeshInstance.rotation.x-target_x) > SHAKE_SPEED) || (shake_speed_z > 0.0 && abs($MeshInstance.rotation.z-target_z) > SHAKE_SPEED):
			if $MeshInstance.rotation.x < target_x:
				$MeshInstance.rotation.x += shake_speed_x
			elif $MeshInstance.rotation.x > target_x:
				$MeshInstance.rotation.x -= shake_speed_x
			if $MeshInstance.rotation.z < target_z:
				$MeshInstance.rotation.z += shake_speed_z
			elif $MeshInstance.rotation.z > target_z:
				$MeshInstance.rotation.z -= shake_speed_z
		elif target_shake != 0.0:
			target_shake *= -SHAKE_CUT
			refresh_target_rotations()
			shake_speed *= SHAKE_SPEED_CUT
			refresh_shake_speeds()
			if abs(target_shake) <= SHAKE_SPEED:
				target_shake = 0.0
		else:
			$MeshInstance.rotation.x = base_rot.x
			$MeshInstance.rotation.z = base_rot.z
			shaking = false
		update_attached()
	# Flicking
	if active && broken && ($MeshInstance.has_node("Light") || emitting >= 0):
		if !flicking:
			if rate != 0:
				if main_time >= main_limit:
					main_time = 0
					flicking = true
				else:
					main_time += 1
		else:
			if flick_time % flick == 0:
				toggle_lights()
			flick_time += 1
			if flick_time >= flick_limit:
				flick_time = 0
				flicking = false
				set_lights(active)
				apply_randoms()

func update_attached() -> void:
	var rot:Vector3
	for np in connected_bodies:
		if get_node_or_null(np) != null:
			rot = Vector3($MeshInstance.rotation.x, 0.0, $MeshInstance.rotation.z).rotated(Vector3.UP, rotation.y-get_node(np).rotation.y)
			get_node(np).get_node("MeshInstance").rotation.x = rot.x
			get_node(np).get_node("MeshInstance").rotation.z = rot.z
