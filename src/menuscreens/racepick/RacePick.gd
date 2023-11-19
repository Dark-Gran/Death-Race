extends FocusMenu
class_name RacePick

const MAP_PORTRAITS:Array = [
	preload("res://assets/map_portraits/1.png"),
	preload("res://assets/map_portraits/2.png"),
	preload("res://assets/map_portraits/3.png"),
	preload("res://assets/map_portraits/4.png"),
	preload("res://assets/map_portraits/5.png"),
	preload("res://assets/map_portraits/6.png")
	#preload("res://assets/map_portraits/5.png")
]

const MAPS:Array = [
	["Uptown: Night", 1, 3, -45, [0]], # 0name, 1track id, 2weather, 3rotation, 4tiers
	["Countryside: Day", 2, 0, 0, [0, 1]],
	["Silver City: Night", 3, 5, -5, [1]],
	["Uptown: Day", 1, 2, 225, [0]],
	["Countryside: Night", 2, 1, 90, [0, 1]],
	["Silver City: Day", 3, 4, 175, [1]]
	#["Forest: Day", 4, 0, 0, [0]]
]

var picked_maps:Array = []

const DRIVER_NAME:Resource = preload("res://src/menuscreens/racepick/DriverName.tscn")
const MAX_DRIVERS:int = 4

const SIGNUP_SPEED:float = 0.8 # Frequency of sign up rolls
const SIGNUP_CHANCE:float = 0.5

onready var total_drivers:int = CI.BOT_NAMES.size()

var races:Array = []
var signed_up:Array = [] # list of already signed up
var player_signed:bool = false
var player_race:int = -1

var first_round_skip_warning:bool = false
var second_player_race_forced:bool = false # track2 force

func _enter_tree() -> void:
	$Timer.wait_time = SIGNUP_SPEED

func menu_input(event:InputEvent) -> void:
	if $Info.visible:
		if event.is_action("ui_select") || event.is_action("ui_cancel"):
			Main.fresh_out_of_race = true
			if get_tree().get_root().has_node("MenuScreens"):
				get_tree().get_root().get_node("MenuScreens/Viewports/GUI/Bordered/Scoreboard").fresh = true
				get_tree().get_root().get_node("MenuScreens").set_new_screen(MenuScreens.MenuScreenType.SCOREBOARD)
			else:
				Main.loading_scene.load_count = 1
				Main.loading_scene.toggle_loading_signs(true)
				Main.loading_scene.queue_new_scene("res://src/menuscreens/MenuScreens.tscn") # pass
	elif event.is_action("ui_cancel"):
		if !Main.ci.campaign_stats[4] && races[0].size() == 3 && !first_round_skip_warning && get_tree().get_root().has_node("MenuScreens"):
			first_round_skip_warning = true
			get_tree().get_root().get_node("MenuScreens").new_dialog("Last spot in the race!\nSure, you can sit this one out, but... I mean, seriously, these fuckers ain't that hard anyway...\nOr are you chicken?")
		else:
			signup_roll(1.0)
	else:
		.menu_input(event)
	if Main.CHEATS_ENABLED:
		if event.is_action("reload"):
			ini_race_pick()

func ini_race_pick(bot_speed:float=1.0) -> void: # called from MenuScreens
	$Info.visible = false
	$Info/NoSignUp.visible = false
	player_signed = false
	picked_maps.clear()
	signed_up.clear()
	races.clear()
	second_player_race_forced = Main.ci.campaign_stats[6]
	Main.clear_race_data()
	# Refresh Options
	for t in buttons.get_child_count():
		var r:RaceOption = buttons.get_child(t)
		if !r.disabled:
			races.append([])
			r.get_node("Tier").text = "Tier "+Main.int_to_roman(t+1)
			var map_index:int
			if t == 0 && (!Main.ci.campaign_stats[4] || !second_player_race_forced):
				if !Main.ci.campaign_stats[4]:
					map_index = 0
				else:
					second_player_race_forced = true
					map_index = 1
			else:
				map_index = get_random_map_index()
				while picked_maps.has(map_index) || !MAPS[map_index][4].has(t) || Main.last_round_maps.has(map_index): # WARNING: obviously this will get stuck if not enough maps
					map_index = get_random_map_index()
			var map:Array = MAPS[map_index]
			picked_maps.append(map_index)
			r.map_index = map_index
			r.get_node("Name").text = map[0]
			if map[1] >= 1 && map[1] <= MAP_PORTRAITS.size():
				r.get_node("Pic").texture = MAP_PORTRAITS[map_index]
		for d in r.get_node("List").get_child_count():
			r.get_node("List").get_child(d).queue_free()
	# Start Sign-Up
	set_focus(0)
	if !Main.ci.campaign_stats[6] || !Main.ci.campaign_stats[4]: # Tutorial
		while races[1].size() < MAX_DRIVERS:
			sign_random_bot_to_race(1)
		if !Main.ci.campaign_stats[4]:
			if Main.ci.campaign_stats[0] == 0 && get_tree().get_root().has_node("MenuScreens"):
				get_tree().get_root().get_node("MenuScreens").new_dialog("Hello there.\nWant to make some buck, huh?\nWell you'd better go for the lowest race - the rest is full anyway.")
		else:
			$Timer.start()
	else:
		$Timer.start()

func _on_Timer_timeout(): # signal
	signup_roll()

func signup_roll(force_chance:float=-1.0) -> void:
	for t in races.size(): # Roll for each race
		if races[t].size() < MAX_DRIVERS:
			var roll:float = Main.rng.randf_range(0.0, 1.0)
			var chance:float = SIGNUP_CHANCE
			if force_chance >= 0.0:
				chance = force_chance
			if roll <= chance: # Time for sign-up
				var force_bot_tier:int = -1
				if !Main.ci.campaign_stats[4] && t == 0 && races[t].size() < 3:
					force_bot_tier = 0
				sign_random_bot_to_race(t, force_bot_tier)

func sign_random_bot_to_race(t:int, force_bot_tier:int=-1) -> void:
	var race:Array = races[t]
	# Get candidates
	var candidates:Array = []
	var race_tiers:Array
	match t:
		0:
			race_tiers = [0, 1]
		1:
			race_tiers = [1, 2, 3]
		2:
			race_tiers = [2, 3, 4]
	for i in range(race_tiers[0], CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]+1):
		if !race_tiers.has(i):
			race_tiers.append(i)
	var plr_over_1:bool = CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER] > 1 # disables "ensure race 0 always gets filled" when player opens races for higher tiers
	for bot_name in CI.BOT_NAMES:
		if !signed_up.has(bot_name) && bot_name != Main.ci.campaign_stats[2]:
			var bot_tier:int = CI.CARS[Main.ci.bot_infos[bot_name][CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
			# Check if valid
			if race_tiers.has(bot_tier) && (force_bot_tier == -1 || force_bot_tier == bot_tier):
				var scared_off:bool = false
				for d_name in race:
					var d_tier:int
					var is_plr:bool = false
					if CI.CHARACTERS.has(d_name):
						d_tier = CI.CARS[Main.ci.bot_infos[d_name][CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
					else:
						d_tier = CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
						is_plr = true
					if d_tier-bot_tier > 1:
						if !plr_over_1 && !(is_plr && d_tier >= 2 && t == 0): # = kinda madness after player reaches tier 2; required because not enough bots
							scared_off = true
							break
				if !scared_off:
					if plr_over_1 || t == 0 || bot_tier != 1: # ensure race 0 always gets filled (= tier1s allowed into other races only after at least 2 are in race 0 already)
						candidates.append(bot_name)
					else:
						var sufficiently_filled:bool = false
						if player_signed && player_race == 0:
							sufficiently_filled = is_tier_in_race(races[0], 1)
						else:
							sufficiently_filled = is_tier_in_race(races[0], 1, 2)
						if sufficiently_filled:
							candidates.append(bot_name)
	# Signup random candidate
	if candidates.size() > 0:
		var candidates_weighted:Array
		var info:Vector2
		var total_weight:float = 0.0
		for n in candidates.size():
			var home_position:int = total_drivers - Main.ci.bot_infos[candidates[n]][CI.DriverInfo.BASE_SKILL]
			var score_position_weight:float = max(0.0, float(Main.ci.bot_infos[candidates[n]][CI.DriverInfo.SCORE_POSITION] - home_position))
			var add_up:float = 1.0 + score_position_weight
			if add_up < 0.01:
				add_up = 0.01
			total_weight += add_up
			info = Vector2(n, total_weight)
			candidates_weighted.append(info)
		var random_w:float = Main.rng.randf_range(0.0, total_weight)
		for c in candidates_weighted:
			if random_w <= c.y:
				signup(candidates[c.x], t)
				break

func signup(driver_name:String, race_index:int) -> void:
	if race_index >= 0 && race_index < races.size():
		signed_up.append(driver_name)
		races[race_index].append(driver_name)
		var dn:Label = DRIVER_NAME.instance() # if slow: pre-instance/create all and just work with visibility
		dn.text = driver_name
		buttons.get_child(race_index).get_node("List").add_child(dn)
		check_for_end()

func skip_all_rolls() -> void:
	while !are_all_races_full():
		signup_roll(1.0)

func engage(f:int, forward:bool=true) -> void:
	if !are_all_races_full():
		if !player_signed:
			if f >= 0 && f < races.size() && races[f].size() < MAX_DRIVERS:
				if f == 1 && CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER] == 0 && !Main.ci.campaign_stats[5] && get_tree().get_root().has_node("MenuScreens"):
					$Timer.stop()
					Main.ci.campaign_stats[5] = true
					get_tree().get_root().get_node("MenuScreens").new_dialog("Whoa there, hold your horses!\nYou might wanna think about getting a better car first. I mean, you can signup anyway, I won't stop you... but you've been warned.")
				else:
					player_signed = true
					player_race = f
					signup(Main.ci.player_info[CI.DriverInfo.NAME], f)
					for b in buttons.get_children():
						b.disabled = true
					set_focus(-1)
					if !Main.ci.campaign_stats[4]:
						$Timer.start()
		else:
			skip_all_rolls()

func end_signup() -> void:
	$Timer.stop()
	set_focus(-1)
	# Prepare data
	Main.last_round_maps = picked_maps.duplicate()
	Main.current_races.clear()
	for r in races:
		Main.current_races.append(sort_drivers_by_score(r))
	Main.current_maps.clear()
	for option in buttons.get_children():
		Main.current_maps.append(MAPS[option.map_index])
		Main.current_player_race = player_race
	call_deferred("go_skip_or_race")

func go_skip_or_race() -> void:
	# No Sign-Up -> Skip
	if !player_signed:
		$Info.visible = true
		$Info/NoSignUp.visible = true
		set_focus(-1)
		if get_tree().get_root().has_node("MenuScreens"):
			get_tree().get_root().get_node("MenuScreens/Viewports/Viewport/Camera/AnimationPlayer").play("MainToCreation")
	# Player Signed-Up -> Enter Race
	elif player_race >= 0 && player_race < races.size():
		if second_player_race_forced:
			Main.ci.campaign_stats[6] = second_player_race_forced
		var quest_chance:float = CI.QUEST_CHANCE
		if Main.ci.campaign_stats[0] == 0:
			enter_race()
		elif Main.ci.campaign_stats[0] == 1:
			new_kill_quest(races[player_race])
		else:
			var q:float = Main.rng.randf_range(0.0, 1.0)
			if q <= CI.QUEST_CHANCE:
				new_kill_quest(races[player_race])
			else:
				enter_race()

func enter_race() -> void:
	if get_tree().get_root().has_node("MenuScreens"):
		get_tree().get_root().get_node("MenuScreens").input_enabled = false
	# Load Race
	Main.loading_scene.load_count = 3
	Main.loading_scene.toggle_loading_signs(true)
	Main.loading_scene.add_bonus_load(Race.get_track_path(MAPS[buttons.get_child(player_race).map_index][1]), true)
	Main.loading_scene.queue_new_scene("res://src/race/Race.tscn", false)

# RACE QUESTS

func new_kill_quest(plr_race:Array) -> void:
	var ri:int = Main.rng.randi_range(0, 2)
	if plr_race[ri] == Main.ci.player_info[CI.DriverInfo.NAME]:
		ri += 1
	if get_tree().get_root().has_node("MenuScreens"):
		get_tree().get_root().get_node("MenuScreens").new_quest(CI.QuestType.KILL, [plr_race[ri]])

# UTILITIES

func sort_drivers_by_score(race:Array) -> Array:
	var arr:Array
	var score:int
	for n in race.size():
		if Main.is_player(race[n]):
			score = Main.ci.player_info[CI.DriverInfo.SCORE]
		else:
			score = Main.ci.bot_infos[race[n]][CI.DriverInfo.SCORE]
		arr.append(Vector2(n, score))
	if Main.ci.campaign_stats[4]:
		arr.sort_custom(self, "sort_vector2_y")
	else:
		arr.sort_custom(self, "sort_vector2_y_inverted")
	var result:Array
	for a in arr:
		result.append(race[a.x])
	return result

func sort_vector2_y(a:Vector2, b:Vector2) -> bool:
	return a.y < b.y

func sort_vector2_y_inverted(a:Vector2, b:Vector2) -> bool:
	return a.y > b.y

func check_for_end() -> void:
	if are_all_races_full():
		end_signup()
	
func are_all_races_full() -> bool:
	for r in races:
		if r.size() < MAX_DRIVERS:
			return false
	return true

func get_random_map_index() -> int:
	var i:int = Main.rng.randi_range(0, MAPS.size()-1)
	return i

func is_tier_in_race(race:Array, tier:int, how_many_times:int=1) -> bool:
	var presence:int = 0
	for d_name in race:
		var d_tier:int
		if CI.CHARACTERS.has(d_name):
			d_tier = CI.CARS[Main.ci.bot_infos[d_name][CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
		else:
			d_tier = CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
		if d_tier == tier:
			presence += 1
	return presence >= how_many_times
