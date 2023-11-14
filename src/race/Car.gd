extends Destructible # Must be used on a RigidBody node! (not "just Spatial")
class_name Car
# Basic physics concept:
# 1. RigidBody locked in Axis (height and y rotation)
# 2. Applying forces on 4 specific points in the single body
# 3. For each point/wheel, watching over longitudinal and lateral forces separately (counter-impulse in lateral direction simulates friction etc)

export(float) var collision_fragility = 0.3684
export(float) var collision_mass_threshhold = 200 # mass required for RigidBody to apply collision damage
# possibly: apply damage from all bodies but scale it by weight (or momentum) 

export(float) var engine_power = 60.0
export(float) var reverse_power = 0.5 # cuts engine power in reverse
export(float) var transmission = 0.7

export(float) var base_linear_friction = 0.3
export(float) var base_angular_friction = 0.1
export(float) var lateral_resistance = 35.0
export(float) var heavy_resistance = 55.0 # for wheels marked as "carries_weight" (difference from lateral_resistance allows from max drifts)
export(float) var handbrake_resistance = 20 # lateral
export(float) var handbrake_heavy_resistance = 40 # lateral
export(float) var handbrake_power = 9.0 # longitudinal
export(float) var handbrake_friction = 0.1

export(float) var max_ammo = 120.0
export(float) var max_nitro = 100.0
export(float) var nitro_power = 25.0 # adds to engine power
export(float) var nitro_reverse = 0.5 # nitro_power when going backwards
export(float) var nitro_ignition = 0.3 # adds to transmission
export(float) var nitro_cost = 0.3
export(float) var nitro_damage = 0.04
export(float) var nitro_over_damage = 0.08 # punishment for using nitro when over "max speed w/o nitro"
export(float) var rocket_fuel_effect = 1.5
export(int) var max_mines = 8
export(float) var mine_reload = 1.8

export(float) var max_steering_angle = 40.0
export(float) var steering_speed = 0.05
export(bool) var instant_turn = false
export(bool) var instant_return = true

export(float) var wheelspin_threshhold = 0.11 # speed ratio to generate tts
export(float) var tyre_width = 5.0
export(Color) var smoke_color = Color("801a1a1a") # default; changes with some roads

export(int) var main_mat_index = 1 # which material on MeshInstance is the main one
export(Material) var exploded_material = preload("res://assets/materials/car_exploded.tres")
export(bool) var preexploded = false
export(float) var hue = 0.0
export(float) var normal_map_start = 0.8 # condition at/below which normal map shows
export(float) var normal_map_max = 0.5 # max normal map scale

export(int) var light_mat_index = 6 # which material on MeshInstance is for the reflectors
export(Material) var reflectors_on = preload("res://assets/materials/light_carOn.tres")
export(Material) var reflectors_off = preload("res://assets/materials/light_carOff.tres")

export(float) var start_offset_y = 0.0

enum InputType {LOCAL, BOT, REMOTE, NONE, MAX}
export(InputType) var input_type = InputType.LOCAL

export(float) var drag_coef = 0.2 # for calculating max speed (changes with friction etc.)
export(float) var wheel_mass_coef = 19.0 # set carefully

export(float) var bot_recovery_time_adjust = 1.0 # recovery+stuck time is speed-dependent -> instead of measuring speed (or changing from time-based to distance-based solution), let's just put a speed-coef on each car model (this obviously does not account for car-upgrades, debuffs etc)
export(float) var bot_stuck_velocity = 0.5

###

var MineScene:Resource = preload("res://src/race/weapons/Mine.tscn")

const TT_THRESHHOLD:float = 2.0
const HOLEMAGNET_TRESHHOLD:float = 3.0 # linear velocity
const DEFAULT_EXPLOSION_DELAY = 1.25 # used by trains (holes always override)

onready var max_speed:float = (engine_power+nitro_power)*drag_coef # used by gui
onready var max_speed_regular:float = engine_power*drag_coef

var lost_control:bool = false
var explosion_timer:float = 0.0
var in_water:bool = false
var magnet_force:float = 0.0
var magnet_position:Vector3 = Vector3.ZERO

var temp_lateral_adjust:float = 0.0 # for different types of roads
var temp_linear_friction:float = 0.0
var temp_angular_friction:float = 0.0
var temp_wheel_force_adjust:float = 1.0

var steer_angle:float = 0.0
var wheel_force:float = 0.0

var wheels:Dictionary = {} # node : translation
var wheel_power:float = 0.0
var wheel_nitro_power:float = 0.0
var mass_per_wheel:float = 0.0

var velocity:Vector3 = self.linear_velocity
var forward_velocity:Vector3 = Vector3.ZERO
var speed_ratio:float = 0.0

var body_state:PhysicsDirectBodyState

var main_material:Material
var carlights_enabled:bool = true # "technical" limit

var reflectors_active:bool = false

var handbrake_active:bool = false
var nitro_active:bool = false
var shooting:bool = false

var ammo:float = max_ammo
var nitro:float = max_nitro
var cash:int = 0
var hallucination:float = 0.0
var mines:int = 0
var mine_cooldown:float = 0.0

var has_rocket_fuel:bool = false

var current_lap:int = 0
var current_checkpoint:int = 0
var next_checkpoint:Checkpoint
var checkpoint_distance:float = 0.0
var finished:bool = false # optim: create is_finished() that works with final_position!=-1 instead
var final_position:int = -1

var gui:Control # car gui, therefore: GUI/Basic/Stats

var bot:Reference
var B:GDScript = load("res://src/race/Bot.gd")

var driver_name:String = ""

func _enter_tree() -> void:
	if input_type == InputType.BOT:
		bot = B.new()
	# Driving prep
	reset_temp_frictions()
	max_steering_angle = deg2rad(max_steering_angle)
	var num_of_wheels:float = 0.0
	var wheels_with_drive:float = 0.0
	for c in get_children():
		if c.is_in_group("wheels"):
			num_of_wheels += 1.0
			wheels[c] = c.translation
			if c.drive:
				wheels_with_drive += 1.0
			get_node(c.ttsmoke).switch_color(smoke_color)
			get_node(c.ttsmoke).visible = true
	wheel_power = engine_power / wheels_with_drive
	if has_rocket_fuel:
		nitro_power *= rocket_fuel_effect
	wheel_nitro_power = nitro_power / wheels_with_drive
	mass_per_wheel = (self.mass / num_of_wheels) * wheel_mass_coef
	# Coloring
	main_material = $MeshInstance.get_surface_material(main_mat_index)
	main_material.albedo_color = Color.from_hsv(hue, main_material.albedo_color.s, main_material.albedo_color.v, main_material.albedo_color.a)

func _integrate_forces(state:PhysicsDirectBodyState) -> void:
	body_state = state

func _ready() -> void:
	refresh_frictions()
	refresh_damage_signs()
	# GUI
	if input_type == InputType.LOCAL:
		gui = get_tree().get_root().get_node("Race/Viewports/GUI/Bordered/Basic/Bottom/Stats")
		gui.get_node("Speed/Container/Bar").max_value = max_speed
		gui.get_node("Health/Container/Bar").max_value = max_condition
		gui.get_node("Health/Container/Bar").value = condition
		gui.get_node("Nitro/Container/Bar").max_value = max_nitro
		gui.get_node("Nitro/Container/Bar").value = nitro
		gui.get_node("Ammo/Container/Bar").max_value = max_ammo
		gui.get_node("Ammo/Container/Bar").value = ammo
		refresh_mine_count()

func refresh_frictions() -> void:
	var nd_linear:float
	var nd_angular:float
	if handbrake_active:
		nd_linear = handbrake_friction
		nd_angular = handbrake_friction
	else:
		nd_linear = base_linear_friction
		nd_angular = base_angular_friction
	nd_linear += temp_linear_friction
	nd_angular += temp_angular_friction
	if nd_linear < -0.0:
		nd_linear = -0.0
	if nd_angular < -0.0:
		nd_angular = -0.0
	self.linear_damp = nd_linear
	self.angular_damp = nd_angular

func reset() -> void:
	ammo = max_ammo
	nitro = max_nitro
	hallucination = 0.0
	current_checkpoint = 0
	next_checkpoint = get_parent().get_checkpoint(get_parent().get_next_checkpoint_id(current_checkpoint), false)
	refresh_checkpoint_distance()
	current_lap = 0
	update_view_shaders(false)
	reset_gui_icons()
	reset_temp_frictions()
	if bot != null:
		bot.setup(self)

func reset_gui_icons() -> void:
	if gui != null:
		for c in gui.get_children():
			#if c.has_node("Container"):
			for cc in c.get_node("Container").get_children():
				if cc is CarStatIcon:
					if cc.rare:
						cc.set_color(CarStatIcon.IconColor.INVISIBLE)
					else:
						cc.set_color(CarStatIcon.IconColor.WHITE)
		refresh_damage_signs()
		refresh_gui_panel("Nitro", nitro, nitro_active, can_nitro())
		refresh_gui_panel("Ammo", ammo, shooting, can_shoot())

func refresh_gui_panel(panel_name:String, value:float, query_positive:bool, query_neutral:bool) -> void:
	gui.get_node(panel_name+"/Container/Bar").value = value
	if query_positive:
		gui.get_node(panel_name+"/Container/Icon").set_color(CarStatIcon.IconColor.GREEN)
	elif query_neutral:
		gui.get_node(panel_name+"/Container/Icon").set_color(CarStatIcon.IconColor.WHITE)
	else: # if it's not positive nor neutral, it is negative
		gui.get_node(panel_name+"/Container/Icon").set_color(CarStatIcon.IconColor.ORANGE)

func refresh_mine_count() -> void:
	get_tree().get_root().get_node("Race/Viewports/MineCount").text = String(mines)
	if mines <= 0:
		get_tree().get_root().get_node("Race/Viewports/MineCount").visible = false

func refresh_damage_signs() -> void:
	if !expired:
		Main.refresh_damage_visuals_on_car(self, condition, max_condition, normal_map_start, normal_map_max, main_material, in_water)
		# GUI
		if gui != null:
			if condition <= max_condition*Main.MAJOR_DAMAGE:
				gui.get_node("Health/Container/Icon").set_color(CarStatIcon.IconColor.ORANGE)
			else:
				gui.get_node("Health/Container/Icon").set_color(CarStatIcon.IconColor.WHITE)

# INPUT

func continuous_input() -> void:
	if lost_control || expired || !get_tree().get_root().get_node("Race").race_started:
		handbrake_active = true
		nitro_active = false
		shooting = false
		if finished:
			steer_angle = 0.0
	else:
		match input_type:
			InputType.LOCAL:
				# Handbrake
				if handbrake_active != Input.is_action_pressed("handbrake"):
					handbrake_active = Input.is_action_pressed("handbrake")
					refresh_frictions()
				# Nitro
				nitro_active = Input.is_action_pressed("nitro") && can_nitro()
				# Engine
				if Input.is_action_pressed("forward"):
					wheel_force = wheel_power
					if nitro_active:
						wheel_force += wheel_nitro_power
				elif Input.is_action_pressed("backward"):
					wheel_force = -wheel_power*reverse_power
					if nitro_active:
						wheel_force -= wheel_nitro_power*nitro_reverse
				else:
					wheel_force = 0.0
				# Steering
				if Input.is_action_pressed("left"):
					steer_angle = max_steering_angle
				elif Input.is_action_pressed("right"):
					steer_angle = -max_steering_angle
				else:
					steer_angle = 0.0
				# Weapons
				shooting = Input.is_action_pressed("shoot") && can_shoot()
				# Mine
				if Input.is_action_just_pressed("mine") && !Input.is_action_pressed("toggle_fullscreen"):
					if can_mine():
						lay_mine()
						refresh_mine_count()
				# Misc
				if Input.is_action_just_pressed("reflectors"):
					toggle_reflectors()
			InputType.BOT:
				if bot != null:
					bot.drive()
	# refresh gui
	if gui != null:
		if handbrake_active:
			gui.get_node("StatusIconPanel/Container/Handbrake").set_color(CarStatIcon.IconColor.RED)
		else:
			gui.get_node("StatusIconPanel/Container/Handbrake").set_color(CarStatIcon.IconColor.WHITE)
		refresh_gui_panel("Nitro", nitro, nitro_active, can_nitro())
		refresh_gui_panel("Ammo", ammo, shooting, can_shoot())

# UPDATE

func update_forward_velocity() -> void:
	forward_velocity = Main.get_longitudinal_velocity(velocity, rotation.y)
	speed_ratio = abs(forward_velocity.length()/max_speed)

func apply_transmission() -> void: # not just transmission, but the entire "missing torque/power solution"
	var t:float = transmission
	if nitro_active:
		if has_rocket_fuel:
			t += nitro_ignition * rocket_fuel_effect
		else:
			t += nitro_ignition
	var transmission_effect:float = t + (speed_ratio*(1.0-t))
	transmission_effect = clamp(transmission_effect, 0.0, 1.0)
	t = clamp(transmission, 0.0, 1.0)
	if speed_ratio < t:
		transmission_effect += t-speed_ratio
	if speed_ratio < wheelspin_threshhold:
		transmission_effect += t-speed_ratio
	wheel_force *= transmission_effect

func _physics_process(delta:float) -> void:
	# INPUT
	continuous_input()
	# RACE POSITION MEASURING
	refresh_checkpoint_distance()
	# SPEED MONITOR
	velocity = self.linear_velocity
	update_forward_velocity()
	var speed:float = forward_velocity.length()
	if gui != null:
		#print(String(speed)+" / "+String(max_speed_regular))
		gui.get_node("Speed/Container/Bar").value = speed
		if !lost_control && !expired:
			if nitro_active:
				if speed > max_speed_regular:
					gui.get_node("Speed/Container/Icon").set_color(CarStatIcon.IconColor.RED)
				else:
					gui.get_node("Speed/Container/Icon").set_color(CarStatIcon.IconColor.ORANGE)
			else:
				gui.get_node("Speed/Container/Icon").set_color(CarStatIcon.IconColor.WHITE)
	# DRIVING
	var wheel_position:Vector3
	if !lost_control:
		if nitro_active:
			change_nitro(-nitro_cost)
		if wheel_force != 0.0:
			if nitro_active:
				if speed > max_speed_regular:
					if has_rocket_fuel:
						receive_damage(nitro_over_damage*rocket_fuel_effect)
					else:
						receive_damage(nitro_over_damage)
				else:
					if has_rocket_fuel:
						receive_damage(nitro_damage*rocket_fuel_effect)
					else:
						receive_damage(nitro_damage)
			apply_transmission()
			wheel_force *= temp_wheel_force_adjust
		var impulse:Vector3
		var lateral_velocity:Vector3
		var longitudinal_velocity:Vector3
		for w in wheels.keys():
			wheel_position = wheels[w].rotated(Vector3.UP, rotation.y)
			lateral_velocity = Main.get_lateral_velocity(w.linear_velocity, w.rotation.y+rotation.y)
			longitudinal_velocity = Main.get_longitudinal_velocity(w.linear_velocity, w.rotation.y+rotation.y)
			# 1. STEERING & ENGINE
			# Steering
			if w.steer:
				if w.rotation.y != steer_angle:
					if abs(w.rotation.y-steer_angle) > steering_speed && !((steer_angle != 0 && instant_turn) || ((steer_angle == 0 || (steer_angle > 0 && w.rotation.y < 0) || (steer_angle < 0 && w.rotation.y > 0)) && instant_return)):
						if steer_angle > 0 || (steer_angle == 0 && w.rotation.y < 0):
							w.rotation.y += steering_speed
						else:
							w.rotation.y -= steering_speed
					else:
						if (steer_angle > 0 && w.rotation.y < 0) || (steer_angle < 0 && w.rotation.y > 0):
							w.rotation.y = 0
						else:
							w.rotation.y = steer_angle
			# Engine
			if w.drive:
				impulse = wheel_force*Vector3.BACK.rotated(Vector3.UP, w.rotation.y+rotation.y)
				call("apply_impulse", wheel_position, impulse)
			# 2. LATERAL & LONGITUDINAL RESISTANCES
			# Lateral
			var max_impulse:float = lateral_resistance
			if handbrake_active:
				if w.carries_weight:
					max_impulse = handbrake_heavy_resistance
				else:
					max_impulse = handbrake_resistance
			elif w.carries_weight:
				max_impulse = heavy_resistance
			max_impulse += temp_lateral_adjust
			if max_impulse < 0.0:
				max_impulse = 0.0
			impulse = mass_per_wheel * -lateral_velocity
			if impulse.length()-max_impulse >= TT_THRESHHOLD*max_impulse || (wheel_force > 0 && speed_ratio < wheelspin_threshhold && w.drive) || (handbrake_active && w.drive && (w.linear_velocity.length()>0.01 || (w.drive && nitro_active))) || w.tt_reset_time > 0.0:
				w.update_tt(wheel_position+translation)
				if w.tt_type == Wheel.TTType.TYRE && has_node(w.ttsmoke):
					get_node(w.ttsmoke).set_emitting(w.linear_velocity.length()>0.01 || nitro_active || (wheel_force > 0 && speed_ratio < wheelspin_threshhold))
			else:
				w.update_tt(null)
				if has_node(w.ttsmoke):
					get_node(w.ttsmoke).set_emitting(w.drive && input_type == InputType.LOCAL && Input.is_action_pressed("nitro") && handbrake_active)
			if impulse.length() > max_impulse:
				impulse *= max_impulse / impulse.length()
			call("apply_impulse", wheel_position, impulse)
			# Longitudinal
			if handbrake_active:
				max_impulse = handbrake_power
				impulse = mass_per_wheel * -longitudinal_velocity
				if impulse.length() > max_impulse:
					impulse *= max_impulse / impulse.length()
				call("apply_impulse", wheel_position, impulse)
	# LOST CONTROL
	else:
		if !expired:
			# ooc tts
			for w in wheels.keys():
				if velocity.length() >= 1.0:
					wheel_position = wheels[w].rotated(Vector3.UP, rotation.y)
					w.update_tt(wheel_position+translation)
					if explosion_timer == 0:
						if w.tt_type == Wheel.TTType.TYRE && has_node(w.ttsmoke):
							get_node(w.ttsmoke).set_emitting(true)
				elif explosion_timer <= 0:
					if has_node(w.ttsmoke):
						get_node(w.ttsmoke).set_emitting(false)
			if !finished:
				# hole magnet
				if explosion_timer <= 0:
					expire()
				else:
					explosion_timer -= delta
					if magnet_force > 0.0:
						if velocity.length() < HOLEMAGNET_TRESHHOLD:
							call("apply_central_impulse", translation.direction_to(magnet_position)*self.mass*magnet_force)
	# WEAPONS
	if shooting:
		for c in get_children():
			if c.is_in_group("guns"):
				c.shoot()
	# MINES
	if mine_cooldown > 0.0:
		mine_cooldown -= delta
	# OTHER
	if hallucination > 0.0:
		hallucinate(-delta)
	set_nitro_effect(nitro_active)

# ROADS

func reset_temp_frictions() -> void:
	temp_linear_friction = get_parent().linear_friction
	temp_angular_friction = get_parent().angular_friction
	temp_lateral_adjust = get_parent().lateral_friction
	temp_wheel_force_adjust = 1.0

func wheel_hit(wa:WheelArea, a:HitArea) -> void: # called by WheelArea
	wa.wheel.hit_areas[a] = true
	if a.hit_force_enter != 0.0:
		apply_force_from_area(wa, a, true)
	if a.linear_friction != 0.0 || a.angular_friction != 0.0 || a.lateral_friction != 0:
		temp_linear_friction += a.linear_friction
		temp_angular_friction += a.angular_friction
		temp_lateral_adjust += a.lateral_friction
		refresh_frictions()
	if a.wheel_force_boost != 0.0:
		temp_wheel_force_adjust += a.wheel_force_boost
	if a.smoke_color != null:
		get_node(wa.wheel.ttsmoke).switch_color(a.smoke_color)

func wheel_hit_exit(wa:WheelArea, a:HitArea) -> void: # called by WheelArea
	wa.wheel.hit_areas.erase(a)
	if a.hit_force_exit != 0.0:
		apply_force_from_area(wa, a, false)
	if a.linear_friction != 0.0 || a.angular_friction != 0.0 || a.lateral_friction != 0 || a.wheel_force_boost != 0.0:
		if all_wheels_out_of_areas():
			reset_temp_frictions()
		else:
			temp_linear_friction -= a.linear_friction
			temp_angular_friction -= a.angular_friction
			temp_lateral_adjust -= a.lateral_friction
			temp_wheel_force_adjust -= a.wheel_force_boost
		refresh_frictions()
	if a.smoke_color != null:
		get_node(wa.wheel.ttsmoke).switch_color(smoke_color)

func apply_force_from_area(wa:WheelArea, a:HitArea, enter:bool) -> void:
	var wheel:Wheel = wa.wheel
	var wheel_position:Vector3 = wheels[wheel].rotated(Vector3.UP, rotation.y)
	# get collision normal
	var pquery:PhysicsShapeQueryParameters = PhysicsShapeQueryParameters.new()
	pquery.set_shape(wa.get_node("CollisionShape").shape)
	pquery.collide_with_areas = true
	pquery.collide_with_bodies = false
	pquery.set_collision_mask(0b10)
	pquery.transform = pquery.transform.rotated(Vector3.UP, rotation.y)
	pquery.transform.origin = translation+wheel_position
	var rest_info:Dictionary = get_parent().pstate.get_rest_info(pquery)
	if !rest_info.empty():
		# adjust collision normal
		var coll_norm:Vector3 = Vector3(abs(rest_info["normal"].x), 0.0, abs(rest_info["normal"].z)).normalized()
		if (rest_info["point"].z < translation.z && !get_node(wheel.oppX_wheel).hit_areas.has(a)) || (rest_info["point"].z > translation.z && get_node(wheel.oppX_wheel).hit_areas.has(a)):
			coll_norm.z = -coll_norm.z
		if (rest_info["point"].x < translation.x && !get_node(wheel.oppX_wheel).hit_areas.has(a)) || (rest_info["point"].x > translation.x && get_node(wheel.oppX_wheel).hit_areas.has(a)):
			coll_norm.x = -coll_norm.x
		# get direction
		var vel:Vector3 = Vector3(wheel.linear_velocity.x, 0.0, wheel.linear_velocity.z)
		var dot:float = coll_norm.dot(vel.normalized())
		var impulse:Vector3
		if dot > 0.95 || dot < 0.001:
			impulse = -vel.normalized()
		else:
			impulse = -coll_norm
		# apply impulse
		if impulse.length() > vel.length():
			impulse *= vel.length() / impulse.length()
		impulse *= mass_per_wheel
		if enter:
			impulse *= a.hit_force_enter
		else:
			impulse *= a.hit_force_exit
		call("apply_impulse", wheel_position, impulse)

# TRACK CHECKPOINTS

func encountered_checkpoint(id:int, botpoint:bool, route:int) -> void: # called by Checkpoint
	if botpoint:
		if bot != null:
			bot.encountered_botpoint(id, route)
	else:
		var max_check:int = get_parent().checkpoints-1
		if id <= max_check:
			if (id > current_checkpoint && id-current_checkpoint == 1) || (current_checkpoint == max_check && id == 0):
				current_checkpoint = id
				next_checkpoint = get_parent().get_checkpoint(get_parent().get_next_checkpoint_id(current_checkpoint), false)
				checkpoint_distance = translation.distance_to(next_checkpoint.translation)
				if current_checkpoint == 0:
					if current_lap+1 >= get_tree().get_root().get_node("Race").max_lap:
						finish_race()
					else:
						current_lap += 1
						if input_type == InputType.LOCAL && current_lap+1 >= get_tree().get_root().get_node("Race").max_lap:
							get_tree().get_root().get_node("Race").new_info_sign("Final Lap!")
	if input_type != InputType.LOCAL:
		get_tree().get_root().get_node("Race").check_player_lapped(self)

func refresh_checkpoint_distance() -> void:
	if next_checkpoint != null:
		checkpoint_distance = translation.distance_to(next_checkpoint.translation)

func finish_race() -> void:
	print("Race Finished!")
	finished = true
	get_tree().get_root().get_node("Race").car_finish(self)
	lose_control()

# DAMAGE AND DESTRUCTION

func receive_damage(dmg:float) -> void:
	if !finished:
		.receive_damage(dmg)
		if gui != null:
			gui.get_node("Health/Container/Bar").value = condition
		refresh_damage_signs()

func expire() -> void:
	.expire()
	if !finished:
		final_position = -2
	wheel_force = 0.0
	steer_angle = 0.0
	for w in wheels:
		if has_node(w.ttsmoke):
			get_node(w.ttsmoke).set_emitting(false)
	if bot != null:
		bot = null
		if has_node("BotSensors"):
			get_node_or_null("BotSensors").queue_free() # null will never occur, called to avoid IDE warning
		for c in get_children():
			if c.is_in_group("guns"):
				c.get_node("BotCast").enabled = false
	if !lost_control:
		lose_control()
	explode()
	if input_type == InputType.BOT:
		get_tree().get_root().get_node("Race").check_for_carnage()

func fall_in_hole(explosion_delay:float, magnet_force:float, magnet_position:Vector3, water:bool) -> void:
	if !finished:
		final_position = -2
	self.explosion_timer = explosion_delay
	self.magnet_force = magnet_force
	self.magnet_position = magnet_position
	self.in_water = water
	if input_type == InputType.LOCAL:
		Main.died_in_water = water
	lose_control()

func lose_control() -> void:
	lost_control = true
	nitro_active = false
	shooting = false
	if gui != null:
		refresh_gui_panel("Nitro", nitro, nitro_active, can_nitro())
		refresh_gui_panel("Ammo", ammo, shooting, can_shoot())
		gui.get_node("StatusIconPanel/Container/Handbrake").set_color(CarStatIcon.IconColor.RED)
		if !finished:
			gui.get_node("Speed/Container/Icon").set_color(CarStatIcon.IconColor.ORANGE)
			gui.get_node("StatusIconPanel/Container/Traction").set_color(CarStatIcon.IconColor.ORANGE)
	# physics
	self.linear_damp = 0.5
	self.angular_damp = 0.5
	self.can_sleep = true
	self.axis_lock_linear_y = false
	self.axis_lock_angular_x = false
	self.axis_lock_angular_z = false
	self.gravity_scale = 1.0
	call("set_collision_layer_bit", 0, true)
	call("set_collision_mask_bit", 0, true)

func explode() -> void:
	if condition > 0.0:
		condition = 0.0
		if gui != null:
			gui.get_node("Health/Container/Bar").value = condition
	set_reflectors(false)
	var mat:Material = exploded_material.duplicate()
	mat.albedo_color = Color.from_hsv(main_material.albedo_color.h, exploded_material.albedo_color.s, exploded_material.albedo_color.v, exploded_material.albedo_color.a)
	for c in get_children():
		if c is MeshInstance:
			c.material_override = mat
	$CriticalDamage.emitting = false
	if !preexploded && !in_water:
		$FinalDamage.emitting = true
	if gui != null:
		gui.get_node("Health/Container/Icon").set_color(CarStatIcon.IconColor.RED)
		gui.get_node("Nitro/Container/Icon").set_color(CarStatIcon.IconColor.ORANGE)
		gui.get_node("Ammo/Container/Icon").set_color(CarStatIcon.IconColor.ORANGE)
		gui.get_node("StatusIconPanel/Container/Handbrake").set_color(CarStatIcon.IconColor.WHITE)
		gui.get_node("StatusIconPanel/Container/Battery").set_color(CarStatIcon.IconColor.RED)
		gui.get_node("StatusIconPanel/Container/Oil").set_color(CarStatIcon.IconColor.RED)
		gui.get_node("StatusIconPanel/Container/Cooling").set_color(CarStatIcon.IconColor.RED)
		gui.get_node("StatusIconPanel/Container/Brakes").set_color(CarStatIcon.IconColor.RED)
		gui.get_node("StatusIconPanel/Container/CatalyticConverter").set_color(CarStatIcon.IconColor.ORANGE)
		gui.get_node("StatusIconPanel/Container/Transmission").set_color(CarStatIcon.IconColor.ORANGE)
	if input_type == InputType.LOCAL: # temp, ie. needs rework for eg. split screen
		get_tree().get_root().get_node("Race").player_death()

func _on_body_entered(body:PhysicsBody) -> void: # signal
	if !expired && !lost_control:
		# COLLISION DAMAGE
		if body is StaticBody || (body is RigidBody && (body.mode == RigidBody.MODE_STATIC || body.mass >= collision_mass_threshhold)) || body.is_in_group("cars"):
			var coll_norm:Vector3 = body_state.get_contact_local_normal(0)
			var coll_force:Vector3 = Vector3.ZERO
			for i in body_state.get_contact_count():
				coll_force += body_state.get_contact_impulse(i) * body_state.get_contact_local_normal(i)
			var vel:Vector3 = velocity
			if body.is_in_group("cars"):
				vel -= body.velocity
				forward_force_to_lamps(coll_norm, coll_force.length()) # forwards only in a distance of 1 car (seems sufficient in like 99,9% of cases tho)
			var dmg:float = abs(coll_norm.dot(vel.normalized())*vel.length())
			if body.is_in_group("breakables"):
				body.receive_hit(coll_norm, coll_force.length())
			receive_damage(dmg*collision_fragility)
		# BLOOD TTS
		elif body is PhysicalBone:
			if body.get_parent().get_parent().get_parent().is_in_group("ppl"):
				body.get_parent().get_parent().get_parent().spawn_blood(body.global_transform, body.translation)
				if body.translation.y <= to_global(wheels.values()[0]).y:
					var wheel = get_closest_wheel(body.translation)
					if wheel != null:
						wheel.set_tt_type(Wheel.TTType.BLOOD)
						wheel.tt_reset_time = body.get_parent().get_parent().get_parent().BLOOD_TRACK_PERSISTENCE
		# TRAINS etc
		elif body is KinematicBody:
			if body.is_in_group("trains"):
				self.explosion_timer = DEFAULT_EXPLOSION_DELAY
				receive_damage(condition*0.5)
				lose_control()

func forward_force_to_lamps(coll_norm:Vector3, dmg:float) -> void:
	for i in body_state.get_contact_count():
		if body_state.get_contact_collider_object(i) is BreakableLamp:
			body_state.get_contact_collider_object(i).receive_hit(coll_norm, dmg)

# ABILITIES & PICKUPS

func set_reflectors(enable:bool) -> void:
	if !enable || (!expired && input_type != InputType.NONE):
		reflectors_active = enable
		if enable:
			$MeshInstance.set_surface_material(light_mat_index, reflectors_on)
		else:
			$MeshInstance.set_surface_material(light_mat_index, reflectors_off)
		if carlights_enabled:
			$Reflectors.visible = enable
		if gui != null:
			if enable:
				gui.get_node("StatusIconPanel/Container/Reflectors").set_color(CarStatIcon.IconColor.GREEN)
			else:
				gui.get_node("StatusIconPanel/Container/Reflectors").set_color(CarStatIcon.IconColor.WHITE)

func toggle_reflectors() -> void:
	set_reflectors(!reflectors_active)

func change_health(amount:float) -> void:
	if amount < 0.0:
		receive_damage(-amount)
	else:
		condition += amount
		if condition > max_condition:
			condition = max_condition
		if gui != null:
			gui.get_node("Health/Container/Bar").value = condition
		refresh_damage_signs()

func change_nitro(amount:float) -> void:
	nitro += amount
	nitro = clamp(nitro, 0.0, max_nitro)
	#refresh_gui_nitro() # being refreshed constantly with continuous input

func change_ammo(amount:float) -> void:
	ammo += amount
	ammo = clamp(ammo, 0.0, max_ammo)
	#refresh_gui_ammo() # being refreshed constantly with continuous input

func change_cash(amount:float) -> void:
	var c:int = int(round(amount*(Main.current_player_race+1)))
	cash += c
	if input_type == InputType.LOCAL && c != 0:
		get_tree().get_root().get_node("Race").new_info_sign("+"+String(c)+"$")

func hallucinate(amount:float) -> void:
	hallucination += amount
	if hallucination < 0.0:
		hallucination = 0.0
	if gui != null:
		if amount > 0.0:
			update_view_shaders(true)
		elif hallucination == 0.0:
			update_view_shaders(false)

func update_view_shaders(hallucinating:bool) -> void:
	get_tree().get_root().get_node("Race/Viewports").get_material().set_shader_param("hallucinating", hallucinating)
	get_tree().get_root().get_node("Race/Viewports/Viewport/VC").get_material().set_shader_param("hallucinating", hallucinating)

func set_nitro_effect(emit:bool):
	if has_rocket_fuel && has_node("Nitro2"):
		$Nitro2.visible = true
		if $Nitro2.emitting != emit:
			$Nitro2.emitting = emit
	else:
		$Nitro.visible = true
		if $Nitro.emitting != emit:
			$Nitro.emitting = emit

func lay_mine() -> void:
	mines -= 1
	mine_cooldown = mine_reload
	# spawn
	var m:Mine = MineScene.instance()
	m.transform = $MineSpawn.global_transform
	get_parent().add_child(m)
	m = null

# GFX SETTINGS

func set_carlights(enable:bool) -> void:
	carlights_enabled = enable
	if carlights_enabled:
		$Reflectors.visible = reflectors_active
	else:
		$Reflectors.visible = false

func set_reflector_shadows(enable:bool) -> void:
	for light in $Reflectors.get_children():
		if light is Light && light.shadow_enabled != enable:
			light.shadow_enabled = enable

# UTILITIES

func get_closest_wheel(pos:Vector3) -> Wheel:
	var closest_wheel:Wheel = null
	var lowest_distance:float = -1.0
	for w in wheels.keys():
		var distance:float = pos.distance_to(w.get_global_transform().origin)
		if lowest_distance < 0.0 || distance < lowest_distance:
			lowest_distance = distance 
			closest_wheel = w
	return closest_wheel

func get_wheel_count_in_area(a:HitArea) -> int:
	var n:int = 0
	for w in wheels:
		if w.hit_areas.has(a):
			n += 1
	return n

func all_wheels_out_of_areas() -> bool:
	for w in wheels:
		if w.hit_areas.size() != 0:
			return false
	return true

func can_shoot() -> bool:
	for c in get_children():
		if c.is_in_group("guns"):
			if c.ammo_cost <= ammo:
				return true
	return false

func can_nitro() -> bool:
	return nitro > 0.0

func can_mine() -> bool:
	return mines > 0 && mine_cooldown <= 0.0

func has_driver() -> bool: # more like "should have a driver"
	return input_type == InputType.LOCAL || input_type == InputType.REMOTE || input_type == InputType.BOT

static func compare(a:Car, b:Car) -> bool:
	if a.finished == b.finished:
		if a.expired == b.expired:
			if a.current_lap == b.current_lap:
				if a.current_checkpoint == b.current_checkpoint:
					return a.checkpoint_distance < b.checkpoint_distance
				else:
					return a.current_checkpoint > b.current_checkpoint
			else:
				return a.current_lap > b.current_lap
		else:
			return b.expired
	else:
		return a.finished
