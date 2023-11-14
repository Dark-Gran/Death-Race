extends Spatial
class_name Track

const BOUND:float = 10.0 # used to kill bullets leaving the map

var ready:bool = false

# TYRE TRACKS
export(int) var tt_columns = 2
export(int) var tt_rows = 2
export(Color) var tt_color = Color(0.01, 0.01, 0.01, 0.8)
export(float) var tile_size = 50.0

# GROUND ATTRIBUTES
export(float) var linear_friction = 0.0 # default car friction adjust (eg. main road's friction)
export(float) var angular_friction = 0.0
export(float) var lateral_friction = 0.0

# GENERAL
export(int) var checkpoints = 6
export(int) var botpoints = 20

onready var map_size:float = tile_size*tt_columns

onready var pstate:PhysicsDirectSpaceState = get_world().direct_space_state

# WEATHER
enum Weather {AFTERNOON_GOLD, NIGHT_RED, AFTERNOON_ORANGE, NIGHT_ORANGE, AFTERNOON_WHITE, NIGHT_WHITE, MAX}
var weather:int = Weather.NIGHT_ORANGE

const afternoon_gold:Environment = preload("res://assets/env/afternoon_gold.tres")
const afternoon_orange:Environment = preload("res://assets/env/afternoon_orange.tres")
const afternoon_white:Environment = preload("res://assets/env/afternoon_white.tres")
const night_red:Environment = preload("res://assets/env/night_red.tres")
const night_orange:Environment = preload("res://assets/env/night_orange.tres")
const night_white:Environment = preload("res://assets/env/night_white.tres")

func _ready() -> void:
	get_tree().call_group("oneshot_emitters", "set_one_shot", true) # for oneshot_emitters that supplement particle precompiler
	get_tree().call_group("ttsmokes", "set_visible", true)
	call_deferred("set_ready", true)

func refresh_weather() -> void:
	var env:Environment
	#$WorldLight.rotation_degrees = Vector3(-128.551, -36.925, 0.0)
	match (weather):
		Weather.AFTERNOON_GOLD:
			env = afternoon_gold
			$WorldLight.light_energy = 0.6
			$WorldLight.shadow_color = Color(0.4, 0.4, 0.4, 1.0)
			set_lights(false)
			set_car_reflectors(false)
		Weather.NIGHT_RED:
			env = night_red
			$WorldLight.light_energy = 0.1
			$WorldLight.shadow_color = Color.black
			set_lights(true)
			set_car_reflectors(true)
		Weather.AFTERNOON_ORANGE:
			env = afternoon_orange
			$WorldLight.light_energy = 0.6
			$WorldLight.shadow_color = Color(0.4, 0.4, 0.4, 1.0)
			set_lights(false)
			set_car_reflectors(false)
		Weather.NIGHT_ORANGE:
			env = night_orange
			$WorldLight.light_energy = 0.1
			$WorldLight.shadow_color = Color.black
			set_lights(true)
			set_car_reflectors(true)
		Weather.AFTERNOON_WHITE:
			env = afternoon_white
			$WorldLight.light_energy = 0.6
			$WorldLight.shadow_color = Color(0.4, 0.4, 0.4, 1.0)
			set_lights(false)
			set_car_reflectors(false)
		Weather.NIGHT_WHITE:
			env = night_white
			$WorldLight.light_energy = 0.2
			$WorldLight.shadow_color = Color.black
			set_lights(true)
			set_car_reflectors(true)
	if env != null:
		$WorldEnvironment.set_environment(env)
		$WorldLight.light_color = env.background_sky.sun_color

func set_lights(enable:bool) -> void:
	get_tree().call_group("lamps", "set_lights", enable)
	get_tree().call_group("lamps", "set_active", enable)

func set_car_reflectors(enable:bool) -> void:
	get_tree().call_group("cars", "set_reflectors", enable)

func get_checkpoint(id:int, botpoint:bool, route:int=0) -> Checkpoint:
	for c in $Checkpoints.get_children():
		if c.botpoint == botpoint && c.id == id && c.route == route:
			return c
	return null

func get_next_checkpoint_id(id:int) -> int:
	id += 1
	if id > checkpoints-1:
		id = 0
	return id

func set_ready(r:bool) -> void:
	ready = r

func increment_enum(e:int, enum_max:int, decrement:bool=false) -> int: # static/singleton candidate
	if !decrement:
		e += 1
	else:
		e -= 1
	if e == enum_max:
		e = 0
	elif e < 0:
		e = enum_max-1
	return e
