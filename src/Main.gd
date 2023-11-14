extends Node # SINGLETON
# Owns ResLoader and handles utilities and GFX+CI ("local save" - possibly move to LoadingScene)
# Holds reference to LoadingScene (the actual "main/master scene"; for main in other sense, see MenuScreens)

const DEBUG_ENABLED:bool = false
const CHEATS_ENABLED:bool = true

const SAVE_KEY:PoolByteArray = PoolByteArray([80, 65, 36, 36, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
const RATIO_2D_TO_3D:float = 10.0 # Deprecated
const HUE_SHIFT:float = 0.05 # countering disproportion between "cars in most environments" and gui
const HUE_TARGET:float = 0.0
const HUE_OPPOSITE:float = 0.7

const MAJOR_DAMAGE:float = 0.65 # % to show dmg on car
const CRITICAL_DAMAGE:float = 0.35 # % to show crit dmg on car

###

onready var loading_scene:Node = get_tree().get_root().get_node("LoadingScene")

var rng:RandomNumberGenerator = RandomNumberGenerator.new()

var window_focused:bool = true
var quit_now:bool = false

var RL:GDScript = preload("res://src/ResLoader.gd")
var loader:ResLoader

# CampaignInfo and similar ("(current) game-info that is needed accross all screens")
# (or rename CampaignInfo into something like "Game Manager" (and move to Loading Scene?) and put everything in)
# (also subclass RaceInfo could come in handy (would eliminate current_races vs current_maps)
var ci:Reference
var CI:GDScript = preload("res://src/CampaignInfo.gd")
var fresh_out_of_race:bool = false
var current_races:Array = [] # holds race infos for Race launch and "simulations" (tier : driver list)
var current_maps:Array = [] # holds map infos for current_races (tier : map info)
var current_player_race:int = -1 # holds race index of player's race
var player_race_outcome:Array = []
var died_in_water:bool = false
var player_lapped:bool = false
var current_kill_target:String = "" # driver name for Kill quest
var last_round_maps:Array = [] # against repetition

class CarEndInfo:
	var driver_name:String = ""
	var position:int = -1
	var condition:float = 1.0
	var reward_points:int = 0
	var reward_cash:int = 0
	var grabbed_cash:int = 0

# ci.player_info + ci.bot_infos save

var new_game_slot:int = -1
var current_save_slot:int = -1

# gfx settings
const GFX_MAX_MSAA:int = Viewport.MSAA_8X
const GFX_SSAO_BRIGHTNESS:float = 0.1
enum GFXOverall {VERY_LOW, LOW, MEDIUM, HIGH, VERY_HIGH, MAX}
var gfx_settings:Array = [
	GFXOverall.MEDIUM, # overall
	Viewport.MSAA_2X, # msaa
	true, # ssao
	2, # shadow_filter
	true, # glow
	2, # grass
	0 # low disable
]

var gfx_config:ConfigFile = ConfigFile.new()

var show_fps:bool = false

# INITIALIZATION

func _enter_tree() -> void:
	get_tree().set_auto_accept_quit(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	load_gfx_settings()

func _ready() -> void:
	loader = RL.new()
	get_tree().get_root().call_deferred("add_child", loader)
	loader.start()
	call_deferred("create_fresh_campaign_info")

func create_fresh_campaign_info() -> void:
	ci = CI.new()

func create_campaign_info(player_portrait:int, player_name:String, player_hue:float) -> void:
	create_fresh_campaign_info()
	ci.player_info[CI.DriverInfo.PORTRAIT] = player_portrait
	ci.player_info[CI.DriverInfo.NAME] = player_name
	ci.player_info[CI.DriverInfo.HUE] = player_hue

func save_campaign_info() -> void:
	if new_game_slot >= 0:
		current_save_slot = new_game_slot
		new_game_slot = -1
	save_to_slot(current_save_slot)

func save_to_slot(save_slot:int) -> void:
	if save_slot >= 0:
		var config:ConfigFile = ConfigFile.new()
		config.set_value("CAMPAIGN", "STATS", ci.campaign_stats)
		config.set_value("CAMPAIGN", "PLAYER", ci.player_info)
		config.set_value("CAMPAIGN", "BOTS", ci.bot_infos)
		#config.save(get_save_slot_path(save_slot))
		var err:int = config.save_encrypted(get_save_slot_path(save_slot), SAVE_KEY)
		if err == OK:
			if get_tree().get_root().has_node("MenuScreens"):
				get_tree().get_root().get_node("MenuScreens").new_info_sign("Save Successful")

func load_from_slot(save_slot:int) -> bool:
	var config:ConfigFile = ConfigFile.new()
	#var err:int = config.load(get_save_slot_path(save_slot))
	var err:int = config.load_encrypted(get_save_slot_path(save_slot), SAVE_KEY)
	if err == OK:
		clear_race_data()
		ci.campaign_stats = config.get_value("CAMPAIGN", "STATS")
		ci.player_info = config.get_value("CAMPAIGN", "PLAYER")
		ci.bot_infos = config.get_value("CAMPAIGN", "BOTS")
		current_save_slot = save_slot
		return true
	return false

func clear_race_data() -> void:
	fresh_out_of_race = false
	current_races = []
	current_maps = []
	current_player_race = -1
	player_race_outcome = []
	died_in_water = false
	player_lapped = false

# LOADER EXIT

func quit_request() -> void:
	#if loading_scene != null && loading_scene.has_node("LoadingAnimation"):
	#	loading_scene.get_node("LoadingAnimation").free()
	if loader.thread.is_active():
		quit_now = true
		loader.exit()
	else:
		get_tree().quit()

func loader_thread_ended() -> void:
	if quit_now:
		loader.thread.wait_to_finish()
		get_tree().quit()

# WINDOW

func _notification(what:int) -> void:
	match what:
		MainLoop.NOTIFICATION_WM_FOCUS_OUT:
			window_focused = false
		MainLoop.NOTIFICATION_WM_FOCUS_IN:
			window_focused = true
		MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
			quit_request()
		#MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST: # mobile
		#	quit_request()

# GFX SETTINGS (TOGGLES)

func load_gfx_settings() -> void:
	var err:int = gfx_config.load("user://deathrace_gfx.cfg")
	if err == OK:
		gfx_settings[0] = int(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[0]))) # overall
		gfx_settings[1] = int(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[1]))) # msaa
		gfx_settings[2] = bool(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[2]))) # ssao
		gfx_settings[3] = int(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[3]))) # shadow_filter
		gfx_settings[4] = bool(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[4]))) # glow
		gfx_settings[5] = int(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[5]))) # grass
		gfx_settings[6] = int(gfx_config.get_value("GFX", String(GFXOption.OptionType.keys()[6]))) # low_disable

func save_gfx_settings() -> void:
	var config:ConfigFile = ConfigFile.new()
	for n in gfx_settings.size():
		config.set_value("GFX", GFXOption.OptionType.keys()[n], gfx_settings[n])
	var err:int = config.save("user://deathrace_gfx.cfg")
	if err == OK:
		if get_tree().get_root().has_node("MenuScreens"):
			get_tree().get_root().get_node("MenuScreens").new_info_sign("GFX Saved & Applied")

func get_next_overall(settings:Array, step:int=1) -> Array:
	if settings[0] >= 0 && settings[0] < GFXOverall.MAX:
		settings[0] = inc_int_around(settings[0], GFXOverall.MAX-1, step)
	else:
		settings[0] = GFXOverall.HIGH
	match settings[0]:
		GFXOverall.VERY_LOW:
			settings = [
				settings[0], # overall
				Viewport.MSAA_DISABLED, # msaa
				false, # ssao
				0, # shadow_filter
				false, # glow
				0, # grass
				3 # low disable
			]
		GFXOverall.LOW:
			settings = [
				settings[0],
				Viewport.MSAA_DISABLED,
				false,
				0,
				false,
				1,
				2
			]
		GFXOverall.MEDIUM:
			settings = [
				settings[0],
				Viewport.MSAA_2X,
				true,
				2,
				true,
				2,
				0
			]
		GFXOverall.HIGH:
			settings = [
				settings[0],
				Viewport.MSAA_4X,
				true,
				3,
				true,
				2,
				0
			]
		GFXOverall.VERY_HIGH:
			settings = [
				settings[0],
				Viewport.MSAA_8X,
				true,
				3,
				true,
				2,
				0
			]
	return settings

func get_next_msaa(settings:Array, step:int=1) -> Array:
	settings[GFXOption.OptionType.MSAA] = inc_int_around(settings[GFXOption.OptionType.MSAA], GFX_MAX_MSAA, step)
	return settings

func apply_msaa(viewport:Viewport, out_of_race:bool=true) -> void:
	var new_msaa = gfx_settings[GFXOption.OptionType.MSAA]
	if out_of_race && gfx_settings[GFXOption.OptionType.MSAA] != GFX_MAX_MSAA:
		 new_msaa += 1
	if viewport.msaa != new_msaa:
		viewport.msaa = new_msaa

func get_next_ssao(settings:Array) -> Array:
	settings[GFXOption.OptionType.SSAO] = !settings[GFXOption.OptionType.SSAO]
	return settings

func apply_ssao(env:Environment) -> void:
	if env != null:
		if env.ssao_enabled != gfx_settings[GFXOption.OptionType.SSAO]:
			env.ssao_enabled = gfx_settings[GFXOption.OptionType.SSAO]
			if gfx_settings[GFXOption.OptionType.SSAO]:
				env.adjustment_brightness += GFX_SSAO_BRIGHTNESS
			else:
				env.adjustment_brightness -= GFX_SSAO_BRIGHTNESS

func get_next_shadow_filter(settings:Array, step:int=1) -> Array:
	settings[GFXOption.OptionType.SHADOW_FILTER] = inc_int_around(settings[GFXOption.OptionType.SHADOW_FILTER], 3, step)
	return settings

func apply_shadow_filter() -> void:
	var mem:int = 4096
	var filter:int = 0
	match gfx_settings[GFXOption.OptionType.SHADOW_FILTER]:
		0:
			mem = 2048
		2:
			filter = 1
		3:
			filter = 2
	if ProjectSettings.get_setting("rendering/quality/shadow_atlas/size") != mem:
		ProjectSettings.set_setting("rendering/quality/shadow_atlas/size", mem)
	if ProjectSettings.get_setting("rendering/quality/directional_shadow/size") != mem:
		ProjectSettings.set_setting("rendering/quality/directional_shadow/size", mem)
	# missing mobile mem settings atm
	if ProjectSettings.get_setting("rendering/quality/shadows/filter_mode") != filter:
		ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", filter)

func get_next_glow(settings:Array) -> Array:
	settings[GFXOption.OptionType.GLOW] = !settings[GFXOption.OptionType.GLOW]
	return settings

func apply_glow(env:Environment) -> void:
	if env.glow_enabled != gfx_settings[GFXOption.OptionType.GLOW]:
		env.glow_enabled = gfx_settings[GFXOption.OptionType.GLOW]

func get_next_grass(settings:Array, step:int=1) -> Array:
	settings[GFXOption.OptionType.GRASS] = inc_int_around(settings[GFXOption.OptionType.GRASS], 2, step)
	return settings

func apply_grass() -> void:
	match gfx_settings[GFXOption.OptionType.GRASS]:
		0: # Disabled
			get_tree().call_group("grass_low", "set_visible", false)
			get_tree().call_group("grass", "set_visible", false)
		1: # Low
			get_tree().call_group ("grass_low", "set_visible", true)
			get_tree().call_group("grass", "set_visible", false)
		2: # Normal
			get_tree().call_group("grass_low", "set_visible", false)
			get_tree().call_group("grass", "set_visible", true)

func get_next_low_disable(settings:Array, step:int=1) -> Array:
	settings[GFXOption.OptionType.LOW_END] = inc_int_around(settings[GFXOption.OptionType.LOW_END], 3, step)
	return settings

func apply_low_disable() -> void:
	match gfx_settings[GFXOption.OptionType.LOW_END]:
		0: # None
			get_tree().call_group("cars", "set_reflector_shadows", true)
			get_tree().call_group("cars", "set_carlights", true)
			get_tree().call_group("garaged_cars", "set_carlights", true)
			get_tree().call_group("guns", "set_shells_enabled", true)
			get_tree().call_group("lamps", "set_shadows", true)
		1: # ReflectorShadows
			get_tree().call_group("cars", "set_reflector_shadows", false)
			get_tree().call_group("cars", "set_carlights", true)
			get_tree().call_group("garaged_cars", "set_carlights", true)
			get_tree().call_group("guns", "set_shells_enabled", true)
			get_tree().call_group("lamps", "set_shadows", true)
		2: # Reflectors+Shells
			get_tree().call_group("cars", "set_reflector_shadows", false)
			get_tree().call_group("cars", "set_carlights", false)
			get_tree().call_group("garaged_cars", "set_carlights", false)
			get_tree().call_group("guns", "set_shells_enabled", false)
			get_tree().call_group("lamps", "set_shadows", true)
		3: # Reflectors+Shells+DynamicShadows
			get_tree().call_group("cars", "set_reflector_shadows", false)
			get_tree().call_group("cars", "set_carlights", false)
			get_tree().call_group("garaged_cars", "set_carlights", false)
			get_tree().call_group("guns", "set_shells_enabled", false)
			get_tree().call_group("lamps", "set_shadows", false)

func toggle_show_fps() -> void:
	show_fps = !show_fps

func apply_show_fps(fps:Control) -> void:
	fps.visible = show_fps

# MISC

func refresh_damage_visuals_on_car(car:Node, condition:float, max_condition:float, normal_map_start:float, normal_map_max:float, main_material:Material, in_water:bool) -> void:
	car.set_reflectors(condition != 0.0)
	# Fire & Smoke
	if condition == 0.0: # EXPLODED
		var mat:Material = car.exploded_material.duplicate()
		mat.albedo_color = Color.from_hsv(main_material.albedo_color.h, car.exploded_material.albedo_color.s, car.exploded_material.albedo_color.v, car.exploded_material.albedo_color.a)
		for c in car.get_children():
			if c is MeshInstance:
				c.material_override = mat
		car.get_node("MajorDamage").emitting = false
		car.get_node("CriticalDamage").emitting = false
		if !in_water:
			car.get_node("FinalDamage").emitting = true
	else: # NON-EXPLODED
		car.get_node("FinalDamage").emitting = false
		for c in car.get_children():
			if c is MeshInstance:
				c.material_override = null
		if condition <= max_condition*Main.CRITICAL_DAMAGE:
			car.get_node("CriticalDamage").emitting = true
			car.get_node("MajorDamage").emitting = false
		else:
			car.get_node("CriticalDamage").emitting = false
			if condition <= max_condition*Main.MAJOR_DAMAGE:
				car.get_node("MajorDamage").emitting = true
			else:
				car.get_node("MajorDamage").emitting = false
		# Normal Map
		if condition > max_condition*normal_map_start:
			main_material.normal_scale = 0.0
		else:
			if max_condition == 0 || condition == 0:
				main_material.normal_scale = normal_map_max
			else:
				main_material.normal_scale = normal_map_max * (1-condition/max_condition)

# UTILITIES

func get_save_slot_path(slot:int) -> String:
	return "user://deathrace_save_"+String(slot)+".cfg"

func file_exists(path:String) -> bool:
	var f:File = File.new()
	return f.file_exists(path)

func inc_int_around(input:int, to:int, step:int=1, from:int=0) -> int: # goes to "to" and then back to "from"
	if input >= to && step > 0:
		return from
	elif input <= from && step < 0:
		return to
	else:
		return input+step

func inc_float_around(input:float, to:float, step:float=1.0, from:float=0.0) -> float:
	if input >= to && step > 0.0:
		return from
	elif input <= from && step < 0.0:
		return to
	else:
		return input+step

func is_int_in_range(q:int, a:int, b:int) -> bool:
	return q >= a && q <= b

func is_float_in_range(q:float, a:float, b:float) -> bool:
	return q >= a && q <= b

func get_lateral_velocity(linear_velocity:Vector3, rotation:float) -> Vector3:
	var current_right_normal:Vector3 = Vector3.RIGHT.rotated(Vector3.UP, rotation)
	return current_right_normal.dot(linear_velocity)*current_right_normal

func get_longitudinal_velocity(linear_velocity:Vector3, rotation:float) -> Vector3:
	var current_forward_normal:Vector3 = Vector3.BACK.rotated(Vector3.UP, rotation)
	return current_forward_normal.dot(linear_velocity)*current_forward_normal

func is_out_of_map(position:Vector3, track:Track) -> bool: # used by bullets; should be reworked to more generic "out of bounds"
	return position.x < -track.BOUND || position.z < -track.BOUND|| position.x > track.map_size+track.BOUND || position.z > track.map_size+track.BOUND

func get_all_children(node:Node) -> Array:
	var arr:Array = Array()
	for n in node.get_children():
		arr.append(n)
		if n.get_child_count() > 0:
			arr.append_array(get_all_children(n))
	return arr

func free_children(node:Node, queue:bool=false) -> void:
	var children:Array = node.get_children()
	for i in children:
		if queue:
			i.queue_free()
		else:
			i.free()

func modulate_alpha(node:Node, amount:float, hide_on_end:bool=true) -> void: # See CanvasItemFade for more complexity
	node.modulate.a += amount
	if node.modulate.a <= 0.0 && hide_on_end:
		node.visible = false

func is_player(driver_name:String) -> bool:
	return !CI.CHARACTERS.has(driver_name)

func int_to_roman(n:int) -> String:
	match n:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
	return ""

func shift_hue_to_target(h:float) -> float:
	# less shift near opposite hue
	var shift:float = HUE_SHIFT
	if abs(HUE_OPPOSITE-h) < 0.1:
		shift *= abs(HUE_OPPOSITE-h) * 10
	# keep the 0-1 loop intact
	if h+shift > 1.0:
		h -= 1.0
	# shift in direction of target hue
	var new_h:float = h
	if abs(HUE_TARGET-h) <= shift:
		new_h = HUE_TARGET
	elif h < HUE_TARGET || h-HUE_TARGET > 0.5:
		new_h = h+shift
	else:
		new_h = h-shift
	return new_h
