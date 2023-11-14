extends Node
class_name Race

# Race > Track > Car
var current_track:Track
var current_id:int = 0 # track id
var current_track_res:Resource

const ZOOM_SPEED:float = 1.5
const ZOOM_COEF:float = 0.25 # how much is zoom affected by speed
const ZOOM_START_BONUS:float = 4.0 # extra zoom on race start
onready var camera:Camera = get_node("Viewports/Viewport/VC/Viewport/Camera")
onready var camera_height:float = camera.translation.y
onready var base_zoom:float = camera_height
onready var zoom:float = base_zoom

enum FinishTypes {FINISH, CARNAGE, TIMEOUT, TIMEOUT_LAST, MAX}
var finish_type:int = FinishTypes.FINISH

const HELP_FADE_SPEED:float = 3.0 # affects all CenterInfos (eg. Death)

const START_TIME:float = 4.0 # 4.0
var start_timer:float = 0.0 # going up
var race_started:bool = false

const END_TIMEOUT:float = 10.0
var end_time:float = 0.0
var last_to_drive:bool = false

var input_ready:bool = false
var current_load:String = ""
var current_load_ready:bool = false

var fresh:bool = true
var shown_welcome:bool = false

var player_finished:bool = false  # temp, ie. needs rework for eg. split screen
var player_dead:bool = false
var player_car:Car = null # clearly dropped the idea of multiplayer for now; if revived, change to "local_car"

# Drivers
var max_lap:int = 4
onready var Driver:PackedScene = preload("res://src/race/gui/Driver.tscn")
var drivers:Dictionary = {} # Car : DriverInfo
var fresh_drivers:bool = true

# Menu
onready var menu:Control = $Viewports/Menu/MainMenu
onready var menu_options:Control = $Viewports/Menu/Settings

# Cars (Spawn)

var cars:Array = []
var current_race:Array # "race" from out-of-race perspective, ie. list of driver names
var finished_cars:Array

var sabotauge:int = -1
var sabotauge_power:float = 0.0
var rocket_fueled_enemy:int = -1
var mined_enemy:int = -1

# SETUP

func _enter_tree() -> void:
	$Viewports/GUI/Debug/FPS.visible = false

func _ready() -> void:
	shown_welcome = Main.ci.campaign_stats[4]
	menu.visible = false
	menu_options.visible = false
	if Main.current_player_race >= 0 && Main.current_player_race < Main.current_maps.size():
		current_race = Main.current_races[Main.current_player_race]
		max_lap += Main.current_player_race
		current_id = Main.current_maps[Main.current_player_race][1]
		pick_sabotauge()
		pick_rocketfuels()
		pick_mined()
		load_cars()
	call_deferred("move_to_track", current_id)

func pick_sabotauge() -> void:
	if Main.ci.campaign_stats[10]:
		Main.ci.campaign_stats[10] = false
		sabotauge = Main.rng.randi_range(0, 3)
		while Main.is_player(current_race[sabotauge]):
			sabotauge = Main.rng.randi_range(0, 3)
		sabotauge_power = Main.rng.randf_range(CI.SABOTAUGE_BOT, CI.SABOTAUGE_TOP)

func pick_rocketfuels() -> void:
	var rf_chance:float = Main.rng.randf_range(0.0, 1.0)
	if rf_chance <= CI.ROCKET_FUEL_CHANCE:
		rocket_fueled_enemy = Main.rng.randi_range(0, 3)
		while Main.is_player(current_race[rocket_fueled_enemy]):
			rocket_fueled_enemy = Main.rng.randi_range(0, 3)

func pick_mined() -> void:
	var m_chance:float = Main.rng.randf_range(0.0, 1.0)
	if m_chance <= CI.MINES_CHANCE:
		mined_enemy = Main.rng.randi_range(0, 3)
		while Main.is_player(current_race[mined_enemy]):
			mined_enemy = Main.rng.randi_range(0, 3)

# CAR LOADING

func load_cars() -> void: # called by _ready()
	cars.clear()
	for driver_name in current_race:
		if Main.is_player(driver_name):
			cars.append(load("res://src/race/cars/"+CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.RESOURCE]+".tscn").instance())
		else:
			cars.append(load("res://src/race/cars/"+CI.CARS[Main.ci.bot_infos[driver_name][CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.RESOURCE]+".tscn").instance())

func spawn_cars() -> void:  # called by instance_track()
	for n in cars.size(): # expects cars to be sorted by score (ie. first goes to start1)
		current_track.add_child(setup_car_instance(cars[n], n, Main.is_player(current_race[n])))

func setup_car_instance(car:Car, index:int, is_player_car:bool) -> Car:
	car.translation = current_track.to_global(current_track.get_node("StartPositions").translation+current_track.get_node("StartPositions").get_child(index).translation)
	car.rotation = current_track.get_node("StartPositions").get_child(index).rotation
	var driver_info:Dictionary
	if is_player_car:
		driver_info = Main.ci.player_info
		# Mines
		if Main.ci.campaign_stats[8]:
			Main.ci.campaign_stats[8] = false
			car.mines = car.max_mines
		# Rocket Fuel
		if Main.ci.campaign_stats[9]:
			Main.ci.campaign_stats[9] = false
			car.has_rocket_fuel = true
		# Player Only
		player_car = car
	else:
		driver_info = Main.ci.bot_infos[current_race[index]]
		# Mines
		if index == mined_enemy:
			car.mines = car.max_mines
		# Rocket Fuel
		if index == rocket_fueled_enemy:
			car.has_rocket_fuel = true
		# Bot Only
		car.input_type = Car.InputType.BOT
	# Shared
	car.driver_name = driver_info[CI.DriverInfo.NAME]
	car.hue = driver_info[CI.DriverInfo.HUE]
	car.condition = driver_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION]
	car.max_condition = CI.CARS[driver_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.HITPOINTS]+CI.ARMOR_UPGRADE_POWER*driver_info[CI.DriverInfo.CARS][0][CI.CarSlot.ARMOR]
	car.lateral_resistance += CI.TYRES_UPGRADE_POWER*driver_info[CI.DriverInfo.CARS][0][CI.CarSlot.TYRES]
	car.heavy_resistance += CI.TYRES_UPGRADE_POWER*driver_info[CI.DriverInfo.CARS][0][CI.CarSlot.TYRES]
	car.engine_power += CI.ENGINE_UPGRADE_POWER*driver_info[CI.DriverInfo.CARS][0][CI.CarSlot.ENGINE]
	if index == sabotauge:
		car.condition -= car.max_condition*sabotauge_power
	return car

# TRACK LOADING

static func get_track_path(id:int) -> String:
	var path:String = "res://src/race/tracks/Track_" # 000.tscn
	var idstr:String = String(id)
	match idstr.length():
		1:
			idstr = "00"+idstr
		2:
			idstr = "0"+idstr
	return path+idstr+".tscn"

func move_to_track(id:int) -> void:
	var path:String = get_track_path(id)
	if Main.loader.queue_resource(path, true):
		current_load = path
		current_id = id
		current_load_ready = Main.loader.is_ready(current_load)
		if !current_load_ready:
			Main.loading_scene.toggle_loading_signs(true, current_track == null)
			Main.loading_scene.load_count = 1
		if current_track != null:
			current_track.ready = false
		input_ready = false # visible = true
		get_tree().paused = !(player_dead || player_finished)

func check_load() -> void: # called by _process
	if current_load_ready:
		current_track_res = Main.loader.get_resource(current_load)
		instance_track(current_track_res)
	else:
		Main.loading_scene.set_loading_progress(Main.loader.get_progress(current_load))
		current_load_ready = Main.loader.is_ready(current_load)

func instance_track(res:Resource) -> void:
	if current_track != null:
		unload_track()
	current_track = current_track_res.instance()
	current_track.weather = Track.Weather.values()[Main.current_maps[Main.current_player_race][2]]
	$Viewports/Viewport.add_child(current_track)
	spawn_cars()
	call_deferred("load_track")

func load_track() -> void:
	if current_track != null && player_car != null:
		if fresh:
			fresh = false
		get_tree().call_group("cars", "reset")
		current_track.refresh_weather()
		for v in get_tree().get_root().get_node("ViewportsTT").get_children():
			Main.free_children(v)
		for n in current_track.tt_columns*current_track.tt_rows:
			if $Viewports/Viewport/Track/Ground.has_node("FloorTT_"+String(n)):
				get_tree().get_root().get_node("ViewportsTT/ViewportTT_"+String(n)).set_clear_mode(Viewport.CLEAR_MODE_ONLY_NEXT_FRAME)
				get_tree().get_root().get_node("ViewportsTT/ViewportTT_"+String(n)).set_update_mode(Viewport.UPDATE_ALWAYS)
				get_node("Viewports/Viewport/Track/Ground/FloorTT_"+String(n)).material_override.albedo_texture = get_tree().get_root().get_node("ViewportsTT/ViewportTT_"+String(n)).get_texture()
		camera.rotation.y = 0.0
		camera.translation.y = camera_height + player_car.translation.y
		base_zoom = camera.translation.y
		rotate_track(deg2rad(Main.current_maps[Main.current_player_race][3])) # todo
		update_camera(0.01666667)
		get_tree().paused = false
		current_load = ""
		apply_gfx_settings()
		call_deferred("load_finish")
	else:
		print("Track or Player are null!")

func rotate_track(rot:float) -> void:
	$Viewports/Viewport/VC/Viewport/Camera.rotate_y(rot)
	for p in get_tree().get_nodes_in_group("pickups"):
		if !(p.get_parent() is PickupSpawn):
			p.rotate_y(rot)
	get_tree().call_group("pickup_spawns", "rotate_y", rot)

func load_finish() -> void:
	get_tree().call_group("ttfloors", "set_visible", true)
	start_timer = 0.0
	ini_racing_lights()
	zoom = base_zoom+ZOOM_START_BONUS
	camera.translation.y = zoom
	setup_drivers()

func unload_track() -> void:
	current_track = null
	player_finished = false
	player_dead = false
	race_started = false
	input_ready = false
	clear_drivers()
	if get_node_or_null("Viewports/Viewport/Track") != null:
		$Viewports/Viewport/Track.free()
	for v in get_children():
		if v.is_in_group("ttviewports"):
			for c in v.get_children():
				c.queue_free()

func switch_track(forward:bool) -> void:
	if forward:
		move_to_track(current_id+1)
	else:
		move_to_track(current_id-1)

func apply_gfx_settings() -> void:
	Main.apply_show_fps($Viewports/GUI/Debug/FPS)
	Main.apply_ssao(current_track.get_node("WorldEnvironment").environment)
	Main.apply_glow(current_track.get_node("WorldEnvironment").environment)
	Main.apply_msaa($Viewports/Viewport/VC/Viewport, false)
	Main.apply_shadow_filter()
	Main.apply_grass()
	Main.apply_low_disable()

# RACE GUI

class DriverInfo:
	var name:String
	var position:int = 0
	var driver_gui:Node2D

const DriverPositionY:float = 74.0

func clear_drivers() -> void:
	for d in drivers.values():
		d.driver_gui.free()
	drivers.clear()
	fresh_drivers = true

func setup_drivers() -> void:
	# Create
	var n:float = 0.0
	for car in cars:
		if car.has_driver():
			n += 1.0
			drivers[car] = DriverInfo.new()
			drivers[car].name = car.driver_name
			var d:Node2D = Driver.instance()
			$Viewports/GUI/Bordered/Basic/Drivers.add_child(d)
			drivers[car].driver_gui = d
	# Set Values
	for car in drivers:
		drivers[car].driver_gui.get_node("Name").text = drivers[car].name
		drivers[car].driver_gui.get_node("Bar").max_value = car.max_condition
		if Main.ci.bot_infos.has(drivers[car].name):
			drivers[car].driver_gui.get_node("Portrait").texture = CI.PORTRAITS_RINGED[Main.ci.bot_infos[drivers[car].name][CI.DriverInfo.PORTRAIT]]
		else:
			drivers[car].driver_gui.get_node("Portrait").texture = CI.PORTRAITS_RINGED[Main.ci.player_info[CI.DriverInfo.PORTRAIT]]
		# color
		var color:Color = Color.from_hsv(Main.shift_hue_to_target(car.main_material.albedo_color.h), 1.0, 1.0, 1.0)
		drivers[car].driver_gui.get_node("PortraitRing").modulate = color
		drivers[car].driver_gui.get_node("Name").modulate = color
		drivers[car].driver_gui.get_node("Bar").modulate = color
		drivers[car].driver_gui.get_node("Lap").modulate = color

func refresh_drivers() -> void:
	# update
	var n:Array = []
	for car in drivers:
		drivers[car].driver_gui.get_node("Bar").value = car.condition
		drivers[car].driver_gui.get_node("Lap").text = String(car.current_lap+1)+"\n /\n  "+String(max_lap)
		n.append(car)
	# sort
	n.sort_custom(Car, "compare")
	var ix:int = 1
	var behind_player:bool = false
	for c in n:
		# inform bots whether they losing to the player
		if c.input_type == Car.InputType.LOCAL || c.input_type == Car.InputType.REMOTE:
			behind_player = true
		elif c.input_type == Car.InputType.BOT:
			if c.bot != null:
				c.bot.losing_to_player = behind_player
		# move guis according to positions
		if drivers[c].position != ix:
			var dg:Node2D = drivers[c].driver_gui
			if !c.finished:
				drivers[c].position = ix
			if fresh_drivers:
				dg.position.y = (drivers[c].position-1) * DriverPositionY
			else:
				var tween:Tween = dg.get_node("Tween")
				tween.interpolate_property(dg, "position:y",
					dg.position.y, (drivers[c].position-1)*DriverPositionY, 0.5,
					Tween.TRANS_SINE, Tween.EASE_IN_OUT)
				tween.start()
		ix += 1
	if fresh_drivers:
		fresh_drivers = false
		Main.loading_scene.toggle_loading_signs(false)	

# UPDATE

func _input(event:InputEvent) -> void: # Non-car input
	if !event.is_pressed():
		if current_track != null && input_ready && current_track.ready:
			# Debug
			if Main.DEBUG_ENABLED:
				if event.is_action("camera"):
					rotate_track(deg2rad(5.0))
			# Regular
			if event.is_action("toggle_fps"): # fps
				Main.toggle_show_fps()
				Main.apply_show_fps($Viewports/GUI/Debug/FPS)
			elif $Viewports/CenterInfo/Tutorial.visible:
				if event.is_action("handbrake"):
					toggle_help()
			elif event.is_action("help"):
					toggle_help()
			elif $Viewports/CenterInfo/Tutorial.visible ||$Viewports/CenterInfo/Help.visible || $Viewports/CenterInfo/Death.visible || $Viewports/CenterInfo/Finish.visible:
				if event.is_action("handbrake") || event.is_action("pause") || event.is_action("help") || (menu.visible && event.is_action("ui_select")):
					toggle_help()
			elif event.is_action("pause") && !menu_options.visible:
				if shown_welcome:
					toggle_menu()
			elif menu.visible:
				menu.menu_input(event)
			elif menu_options.visible:
				menu_options.menu_input(event)

func _physics_process(delta:float) -> void:
	if current_track != null:
		if !input_ready:
			input_ready = current_track.ready
		if drivers.size() > 0:
			refresh_drivers()
		if current_track.ready:
			if !player_finished && last_to_drive:
				end_time -= delta
				if end_time <= 0.0:
					timeout()
	free_emitters()
	if $Viewports/GUI/Debug/FPS.visible:
		$Viewports/GUI/Debug/FPS.text = " "+String(Performance.get_monitor(Performance.TIME_FPS))
		if Engine.get_target_fps() != 0:
			$Viewports/GUI/Debug/FPS.text += " ("+String(Engine.get_target_fps())+")"

func free_emitters() -> void:
	for emitter in get_tree().get_nodes_in_group("oneshot_emitters"):
		if !emitter.emitting:
			emitter.queue_free()

func _process(delta:float) -> void:
	if current_load != "":
		check_load()
		return

	if !$Viewports/GUI/Bordered/Basic/Bottom/TrackInfo/InfoSign.completed:
		$Viewports/GUI/Bordered/Basic/Bottom/TrackInfo/InfoSign.fade(delta)
	if !menu_options.get_node("HowToFPS").completed:
		menu_options.get_node("HowToFPS").fade(delta)

	if current_track != null && current_track.ready:
		update_camera(delta)
		# Start Timer
		if !race_started:
			if shown_welcome && !$Viewports/CenterInfo/Tutorial.visible && !$Viewports/CenterInfo/Help.visible && !menu.visible && !menu_options.visible:
				if start_timer >= START_TIME:
					race_started = true
					$Viewports/RacingLights/Timer.start()
					get_tree().call_group("afterstart_timers", "start")
				start_timer += delta
				refresh_racing_lights()
		else:
			if $Viewports/RacingLights.visible && $Viewports/RacingLights/Timer.time_left <= 0:
				Main.modulate_alpha($Viewports/RacingLights, -delta)
		# CenterInfo fade-in
		if $Viewports/CenterInfo.get_child(0).modulate.a < 1.0:
			for c in $Viewports/CenterInfo.get_children():
				if c.visible && c.modulate.a < 1.0:
					Main.modulate_alpha(c, delta*HELP_FADE_SPEED)

func new_info_sign(txt:String) -> void: # we really should share InfoSign between Race and MenuScreens (duplicity)
	$Viewports/GUI/Bordered/Basic/Bottom/TrackInfo/InfoSign.text = txt
	$Viewports/GUI/Bordered/Basic/Bottom/TrackInfo/InfoSign.restart()

func update_camera(delta:float) -> void:
	var target_zoom = base_zoom + player_car.linear_velocity.length()*ZOOM_COEF
	zoom = lerp(zoom, target_zoom, ZOOM_SPEED*delta)
	camera.translation = Vector3(player_car.translation.x, zoom, player_car.translation.z)

# RACING LIGHTS

func ini_racing_lights() -> void:
	$Viewports/RacingLights.visible = true
	$Viewports/RacingLights.modulate.a = 1.0
	set_racing_lights(0)

func set_racing_lights(phase:int) -> void:
	match phase:
		0:
			$Viewports/RacingLights/Background/Red.visible = true
			$Viewports/RacingLights/Background/Orange.visible = false
			$Viewports/RacingLights/Background/Green.visible = false
		1:
			$Viewports/RacingLights/Background/Red.visible = true
			$Viewports/RacingLights/Background/Orange.visible = true
			$Viewports/RacingLights/Background/Green.visible = false
		2:
			$Viewports/RacingLights/Background/Red.visible = false
			$Viewports/RacingLights/Background/Orange.visible = true
			$Viewports/RacingLights/Background/Green.visible = false
		3:
			$Viewports/RacingLights/Background/Red.visible = false
			$Viewports/RacingLights/Background/Orange.visible = false
			$Viewports/RacingLights/Background/Green.visible = true

func refresh_racing_lights() -> void:
	var rem:float = START_TIME-start_timer
	if rem <= 0:
		set_racing_lights(3)
	elif rem < 1:
		set_racing_lights(2)
	elif rem < 2:
		set_racing_lights(1)
	#else:
	#	set_racing_lights(0)

func check_player_lapped(car:Car) -> void:
	if !Main.player_lapped && car.current_lap > player_car.current_lap && car.current_checkpoint >= player_car.current_checkpoint:
		Main.player_lapped = true

# END SCREENS

func car_finish(car:Car) -> void:
	if car.finished && !car.expired:
		if !player_dead && car.input_type == Car.InputType.LOCAL:
			player_finished = true
			$Viewports/EndScreenTimer.start()
		car.final_position = finished_cars.size()
		finished_cars.append(car.driver_name)
	if car != player_car:
		check_if_last_to_drive()

func player_death() -> void: # temp, ie. needs rework for eg. split screen
	if !player_finished:
		player_dead = true
		$Viewports/EndScreenTimer.start()

func check_for_carnage() -> void:  # end race when all (but player) dead
	if are_all_but_player_dead():
		carnage()
	elif !player_dead:
		check_if_last_to_drive()

func carnage() -> void:
	finish_type = FinishTypes.CARNAGE
	player_car.finished = true
	car_finish(player_car)
	player_car.lose_control()

func check_if_last_to_drive() -> void: # timeout(end) race when all (but player) dead or finished
	if !last_to_drive && is_player_last_to_drive():
		last_to_drive = true
		end_time = END_TIMEOUT

func timeout() -> void:
	player_car.finished = true
	player_finished = true
	player_car.final_position = finished_cars.size()
	print(finished_cars.size())
	if player_car.final_position >= 3:
		finish_type = FinishTypes.TIMEOUT_LAST
	else:
		finish_type = FinishTypes.TIMEOUT
	finished_cars.append(player_car.driver_name)
	show_end_screen()
	player_car.lose_control()

func is_player_last_to_drive() -> bool:
	for car in cars:
		if car != player_car:
			if !car.finished && car.final_position != -2:
				return false
	return !player_dead

func are_all_but_player_dead() -> bool: # currently does not consider possibility of more than 1 player
	for car in cars:
		if car.input_type == Car.InputType.BOT:
			if !car.expired:
				return false
	return !player_dead

func show_end_screen() -> void: # signal from EndScreenTimer
	if player_dead:
		show_death_screen()
	else:
		show_finish_screen()

func show_death_screen() -> void:
	$Viewports/CenterInfo/Help.visible = false
	$Viewports/CenterInfo/Death.visible = true

func show_finish_screen() -> void:
	$Viewports/CenterInfo/Help.visible = false
	$Viewports/CenterInfo/Finish.visible = true
	$Viewports/CenterInfo/Finish/Finish.visible = finish_type == FinishTypes.FINISH
	$Viewports/CenterInfo/Finish/Carnage.visible = finish_type == FinishTypes.CARNAGE
	$Viewports/CenterInfo/Finish/Timeout.visible = finish_type == FinishTypes.TIMEOUT
	$Viewports/CenterInfo/Finish/TimeoutLast.visible = finish_type == FinishTypes.TIMEOUT_LAST

func hide_CenterInfo() -> void:
	for c in $Viewports/CenterInfo.get_children():
		c.visible = false

func toggle_help() -> void:
	if !$Viewports/CenterInfo/Finish.visible && !$Viewports/CenterInfo/Death.visible:
		if race_started && !menu.visible && !menu_options.visible:
			get_tree().paused = !get_tree().paused
		if $Viewports/CenterInfo/Tutorial.visible:
			$Viewports/CenterInfo/Tutorial.visible = false
		elif $Viewports/CenterInfo/Help.visible:
			$Viewports/CenterInfo/Help.visible = false
		else:
			$Viewports/CenterInfo/Help.modulate.a = 1.0
			$Viewports/CenterInfo/Help.visible = true
	else:
		end_race()

func _on_TutorialTimer_timeout() -> void: # called by StartTimer (delaying "Start Screen")
	if !shown_welcome:
		shown_welcome = true
		Main.ci.campaign_stats[4] = true
		if shown_welcome:
			$Viewports/CenterInfo/Tutorial.modulate.a = 0.0
			$Viewports/CenterInfo/Tutorial.visible = true
	if has_node("Viewports/TutorialTimer"):
		$Viewports/TutorialTimer.queue_free()

# RACE END

func concede() -> void:
	player_car.final_position = -3
	end_race()

func end_race() -> void:
	save_race_outcome()
	Main.loading_scene.load_count = 1
	Main.loading_scene.toggle_loading_signs(true)
	Main.loading_scene.queue_new_scene("res://src/menuscreens/MenuScreens.tscn")

func save_race_outcome() -> void:
	Main.fresh_out_of_race = true
	Main.player_race_outcome.clear()
	cars.sort_custom(Car, "compare")
	var car:Car
	for car_ix in cars.size():
		car = cars[car_ix]
		var cei:Main.CarEndInfo = Main.CarEndInfo.new()
		# general
		if car.final_position != -1:
			cei.position = car.final_position
		else:
			cei.position = car_ix
		cei.driver_name = car.driver_name
		cei.condition = max(0.0, car.condition)
		cei.grabbed_cash = car.cash
		# end
		Main.player_race_outcome.append(cei)

# (MAIN) MENU

func toggle_menu() -> void:
	if race_started:
		get_tree().paused = !get_tree().paused
	menu.visible = !menu.visible
	if !menu.visible:
		menu.set_focus(-1)
	menu_options.visible = false

func toggle_menu_options() -> void:
	menu.visible = !menu.visible
	menu_options.visible = !menu_options.visible
	if menu_options.visible:
		if menu_options.get_node("HowToFPS").completed:
			menu_options.get_node("HowToFPS").restart()
	else:
		menu_options.reset()
		menu_options.set_focus(-1)

func engage(menu_name:String, f:int, forward:bool=true) -> void:
	match menu_name:
		"MainMenu":
			match f:
				0: # Resume
					toggle_menu()
				1: # Options
					toggle_menu_options()
				2: # Help
					toggle_help()
				3: # Concede
					concede()
		"GFXSettings":
			match f:
				8: # Exit
					toggle_menu_options()
