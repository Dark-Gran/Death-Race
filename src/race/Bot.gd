extends Reference
class_name Bot

const BOTPOINT_PRECISION:float = 0.19 # basic steering precision
const PICKUP_PRECISION:float = 0.3

const HALLUCINATION_TIME:int = int(Engine.iterations_per_second*0.25)

const STUCK_TIME:int = Engine.iterations_per_second
const RECOVERY_TIME:int = int(Engine.iterations_per_second*1.4)

const BACK_STUCK_COUNT:int = 5 # goes back one checkpoint on repeated stucks
const STUCK_COUNT_ADDITION:int = 20 # more stucks = another going back one checkpoint
const STUCK_SEPARATION:int = Engine.iterations_per_second*3 # separation of non-repeated stucks in frames

var BotSensors:PackedScene = preload("res://src/race/cars/BotSensors.tscn")
var car:Car = null

var target_botpoint:Checkpoint

var stuck_timer:int = 0 # going up
var recovery_timer:int = 0 # going down
var hallucination_timer:int = 0 # going down
var peace_timer:int = 0 # going up
var no_stuck_time:float = 0 # going up
var repeated_stuck_count:int = 0
var backed_on_stuck:bool = false

var detected:Dictionary = {} # PhysicsBody : bool
var losing_to_player:bool = false # set by Race

var current_route:int = 0 # current checkpoint route

# Personality
const NITRO_HEALTH_THRESH:float = 0.1 # stops using nitro when (condition <= max_condition*THRESH)

var engine_debuff:float = 1.0 # engine coef

var peace_time:int = Engine.iterations_per_second*3 # how long before he starts using ammo+nitro

var greedy:bool = false # wants Cash
var careless:bool = false # does not avoid Mushroom
var addict:bool = false # wants Mushroom
var hallucination_resistance:int = 10 # note: reconsider
var resource_top_up:float = 0.8 # does not need pickup until the resource amount is below the line

# SETUP

func setup(c:Car) -> void:
	car = c
	# Sensors
	if !car.has_node("BotSensors"):
		var bs:Spatial = BotSensors.instance()
		car.add_child(bs)
		bs.get_node("Around").connect("body_entered", self, "body_entered")
		bs.get_node("Around").connect("body_exited", self, "body_exited")
	for c in car.get_children():
		if c.is_in_group("guns"):
			c.get_node("BotCast").enabled = true
	# Base
	get_and_set_target_botpoint(0, 0)
	# Personality
	if c.driver_name != "" && CI.CHARACTERS.has(c.driver_name):
		engine_debuff = max(0.0, 1.0-CI.CHARACTERS[c.driver_name][CI.BotTraits.ENGINE_DEBUFF])
		addict = CI.CHARACTERS[c.driver_name][CI.BotTraits.ADDICT]
		greedy = CI.CHARACTERS[c.driver_name][CI.BotTraits.GREEDY]
		careless = CI.CHARACTERS[c.driver_name][CI.BotTraits.CASUAL_USER]
		resource_top_up = CI.CHARACTERS[c.driver_name][CI.BotTraits.RESOURCE_TOPUP]

# DETECTION

func body_entered(body:PhysicsBody) -> void: # signal
	if body != car && body.is_in_group("cars"): # || body is StaticBody
		detected[body] = true

func body_exited(body:PhysicsBody) -> void: # signal
	if body != car && body.is_in_group("cars"): # || body is StaticBody
		detected.erase(body)

# BOTPOINTS

func encountered_botpoint(id:int, route:int) -> void: # called by Car
	if id == target_botpoint.id:
		backed_on_stuck = false
		current_route = route
		get_and_set_target_botpoint(Main.inc_int_around(id, car.get_parent().botpoints-1), route)

func back_one_botpoint() -> void:
	backed_on_stuck = true
	var target_id:int = target_botpoint.id-1
	if target_id < 0:
		target_id = car.get_parent().botpoints-1
	get_and_set_target_botpoint(target_id, current_route)

func get_and_set_target_botpoint(id:int, route:int=0) -> void:
	target_botpoint = car.get_parent().get_checkpoint(id, true, route)
	if target_botpoint == null:
		target_botpoint = car.get_parent().get_checkpoint(id, true)

# UPDATE

func drive() -> void:
	if is_peaceful():
		peace_timer += 1
	
	#return
	
	if car != null && target_botpoint != null && !car.expired && !car.lost_control:
		# no handbrake atm
		car.handbrake_active = false
		#refresh_frictions()

		# STEERING
		var pos:Vector3 = Vector3(car.translation.x, 0.0, car.translation.z)
		
		var target_point:Vector3 = target_botpoint.translation
		var dot_coef:float = BOTPOINT_PRECISION
		
		var pickup:Pickup = get_pickup_nearby()
		if pickup != null && wants_pickup(pickup):
			target_point = pickup.translation
			if pickup.get_parent() is PickupSpawn:
				target_point += pickup.get_parent().translation
			dot_coef = PICKUP_PRECISION
		
		var dist:Vector3 = target_point-pos
		var dot:float = Vector3.RIGHT.rotated(Vector3.UP, car.rotation.y).dot(dist.normalized())
		
		if dot <= dot_coef && dot >= -dot_coef:
			car.steer_angle = 0.0
		elif dot > 0.0:
			car.steer_angle = car.max_steering_angle
		else:
			car.steer_angle = -car.max_steering_angle

		pickup = get_pickup_ahead()
		if car.steer_angle == 0.0 && (are_statics_ahead() || (pickup != null && hates_pickup(pickup))):
			if are_obstacles_ahead_side(false, pickup != null && hates_pickup(pickup)):
				car.steer_angle = car.max_steering_angle
			else:
				car.steer_angle = -car.max_steering_angle
		
		# ENGINE
		if !is_recovering():
			no_stuck_time += 1
			if no_stuck_time >= STUCK_SEPARATION:
				repeated_stuck_count = 0
			if are_trains_ahead():
				if car.linear_velocity.length() > 0.0:
					car.wheel_force = -car.wheel_power*engine_debuff
					car.steer_angle = 0.0
			else:
				car.wheel_force = car.wheel_power*engine_debuff
				if car.linear_velocity.length() <= car.bot_stuck_velocity:
					stuck_timer += 1
					if is_stuck():
						recovery_timer = RECOVERY_TIME*car.bot_recovery_time_adjust
						stuck_timer = 0
						if !backed_on_stuck:
							repeated_stuck_count += 1
							if (!backed_on_stuck && repeated_stuck_count >= BACK_STUCK_COUNT) || (backed_on_stuck && repeated_stuck_count >= BACK_STUCK_COUNT+STUCK_COUNT_ADDITION):
								back_one_botpoint()
				else:
					stuck_timer = 0
		else:
			no_stuck_time = 0
			car.wheel_force = -car.wheel_power*engine_debuff
			car.steer_angle = -car.steer_angle
			recovery_timer -= 1
		
		if car.wheel_force < 0:
			car.wheel_force *= car.reverse_power
		
		# HALLUCINATION
		
		if is_hallucinating():
			if hallucination_timer > 0:
				hallucination_timer -= 1
				if car.steer_angle != 0:
					car.steer_angle = -car.steer_angle
				else:
					var flip_coin:int = Main.rng.randi_range(0, 1)
					if flip_coin == 0:
						car.steer_angle = car.max_steering_angle
					else:
						car.steer_angle = -car.max_steering_angle
			else:
				var r:int = Main.rng.randi_range(0, hallucination_resistance)
				if r == 0:
					hallucination_timer = HALLUCINATION_TIME
		if !is_peaceful():
			# NITRO
			car.nitro_active = !is_recovering() && car.can_nitro() && car.steer_angle == 0.0 && car.condition > car.max_condition*NITRO_HEALTH_THRESH && (are_players_around() || losing_to_player)
			if car.nitro_active:
				if car.wheel_force > 0.0:
					car.wheel_force += car.wheel_nitro_power
				elif car.wheel_force < 0.0:
					car.wheel_force -= car.wheel_nitro_power*car.nitro_reverse

			# WEAPONS
			car.shooting = car.can_shoot() && are_targets_ahead()
			
			# MINES
			if car.can_mine() && are_targets_behind():
				car.lay_mine()

# PICKUPS

func wants_pickup(p:Pickup) -> bool:
	match p.type:
		Pickup.PickupType.HEALTH:
			return car.condition < car.max_condition*resource_top_up
		Pickup.PickupType.NITRO:
			return car.nitro < car.max_nitro*resource_top_up
		Pickup.PickupType.AMMO:
			return car.ammo < car.max_ammo*resource_top_up
		Pickup.PickupType.CASH:
			return greedy
		Pickup.PickupType.MUSHROOM:
			return addict
	return false

func hates_pickup(p:Pickup) -> bool:
	return !addict && !careless && p.type == Pickup.PickupType.MUSHROOM

func get_pickup_nearby() -> Pickup:
	if car.get_node("BotSensors/Ahead").monitoring: # debugging safety
		for a in car.get_node("BotSensors/Ahead").get_overlapping_areas():
			if a is Pickup:
				return a
	return null

func get_pickup_ahead() -> Pickup:
	for bc in car.get_node("BotSensors").get_children():
		if bc is RayCast && bc.get_collider() != null && bc.get_collider() is Pickup:
			return bc.get_collider()
	return null

# UTILITIES

func are_statics_ahead() -> bool:
	for bc in car.get_node("BotSensors").get_children():
		if bc is RayCast && bc.get_collider() != null && (bc.get_collider() is StaticBody || bc.get_collider() is Hole):
			return true
	return false

func are_trains_ahead() -> bool:
	for bc in car.get_node("BotSensors").get_children():
		if bc is RayCast && bc.get_collider() != null && (bc.get_collider().is_in_group("trains")):
			return true
	return false

func are_obstacles_ahead_side(left:bool, pickups_too:bool) -> bool:
	if left:
		return car.get_node("BotSensors/BotCastLeft").get_collider() != null && (car.get_node("BotSensors/BotCastLeft").get_collider() is StaticBody || car.get_node("BotSensors/BotCastLeft").get_collider() is Hole || (pickups_too && car.get_node("BotSensors/BotCastLeft").get_collider() is Pickup))
	else:
		return car.get_node("BotSensors/BotCastRight").get_collider() != null && (car.get_node("BotSensors/BotCastRight").get_collider() is StaticBody || car.get_node("BotSensors/BotCastRight").get_collider() is Hole || (pickups_too && car.get_node("BotSensors/BotCastRight").get_collider() is Pickup))

func are_targets_ahead() -> bool:
	for c in car.get_children():
		if c.is_in_group("guns"):
			return c.get_node("BotCast").get_collider() != null && is_enemy_car(c.get_node("BotCast").get_collider())
	return false

func are_targets_behind() -> bool:
	return car.get_node("BotSensors/BotCastBack").get_collider() != null && is_enemy_car(car.get_node("BotSensors/BotCastBack").get_collider())

func is_enemy_car(collider:Object) -> bool:
	return collider.is_in_group("cars") && !collider.expired && collider.input_type != Car.InputType.NONE

func are_players_around() -> bool:
	for b in detected:
		if b.is_in_group("cars"):
			if b.input_type == Car.InputType.LOCAL || b.input_type == Car.InputType.REMOTE:
				return true
	return false

func is_recovering() -> bool:
	return recovery_timer > 0

func is_stuck() -> bool:
	return stuck_timer >= STUCK_TIME*car.bot_recovery_time_adjust

func is_hallucinating() -> bool:
	return car.hallucination > 0.0

func is_peaceful() -> bool:
	return peace_timer<peace_time
