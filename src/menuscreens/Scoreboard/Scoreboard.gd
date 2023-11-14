extends Control
#class_name Scoreboard

const DS:Resource = preload("res://src/menuscreens/scoreboard/DriverScore.tscn")
const O:Resource = preload("res://src/menuscreens/scoreboard/Outcome.tscn")

var page:int = 0
var scorelist:Array = []
var fresh:bool = true
var no_last_race:bool = false
var bonus_cash:int = 0
var forfeited_cash:int = 0

func ini() -> void: # called from MenuScreens
	if fresh:
		fresh = false
		if Main.current_races.size() > 0:
			no_last_race = false
			Main.current_races = finish_races(Main.current_races, Main.current_player_race, Main.player_race_outcome)
			Main.ci.campaign_stats[0] += 1
			prep_rewards(true)
			ini_scorelist()
			apply_point_rewards()
			save_score_positions()
			Main.save_campaign_info()
			ini_scores()
			ini_outcomes()
			ini_payroll()
			set_page(0)
		else:
			no_last_race = true
			ini_scorelist()
			ini_scores()
			ini_outcomes()
			ini_payroll()
			set_page(1)
	else:
		set_page(1)

func prep_rewards(save_cash_and_condition:bool=true) -> void:
	# Check all races
	for t in Main.current_races.size():
		for d in Main.current_races[t].size():
			if Main.is_player(Main.current_races[t][d]):
				Main.ci.player_info[CI.DriverInfo.LAST_REWARD_POINTS] = get_race_reward(t, d, false)
			else:
				Main.ci.bot_infos[Main.current_races[t][d]][CI.DriverInfo.LAST_REWARD_POINTS] = get_race_reward(t, d, false)
	# Check player race
	var all_but_player_are_dead:bool = true # "reaper"
	var target_not_player_are_dead:bool = true # "kill quest"
	if Main.player_race_outcome.size() == 0:
		all_but_player_are_dead = false
		target_not_player_are_dead = false
	else:
		for cei in Main.player_race_outcome:
			cei.reward_cash = get_race_reward(Main.current_player_race, cei.position)
			cei.reward_points = get_race_reward(Main.current_player_race, cei.position, false)
			if !Main.is_player(cei.driver_name):
				if cei.position > -2:
					all_but_player_are_dead = false
					if cei.driver_name == Main.current_kill_target:
						target_not_player_are_dead = false
					Main.ci.bot_infos[cei.driver_name][CI.DriverInfo.LAST_REWARD_POINTS] = cei.reward_points
				else:
					Main.ci.bot_infos[cei.driver_name][CI.DriverInfo.LAST_REWARD_POINTS] = 0
			else:
				if cei.position < 0 || cei.position == 3 || Main.player_lapped:
					Main.ci.player_info[CI.DriverInfo.LAST_REWARD_POINTS] = 0
					if cei.grabbed_cash > 0:
						forfeited_cash = cei.grabbed_cash
						cei.grabbed_cash = 0
					if cei.position < 0 || cei.position == 3:
						all_but_player_are_dead = false
						if cei.position < 0:
							target_not_player_are_dead = false
					if cei.position == -2:
						get_tree().get_root().get_node("MenuScreens").new_dialog(
							"Geezes man. Fuckin' look at it. Obviously, you lost everything you grabbed on the way.\nWhat? Well I didn't take it! Geesh."
						)
						all_but_player_are_dead = false
					elif cei.position == -1 || cei.position == -3:
						get_tree().get_root().get_node("MenuScreens").new_dialog(
							"What the fuck man? What happened? Did you just bail?\nFuck man, thanks a lot. You ain't gettin shit for this, and hopefully my bookie won't kill me..."
						)
					elif cei.position == 3:
						get_tree().get_root().get_node("MenuScreens").new_dialog(
							"What the hell was that?\nYou do know it's a race, right? I'm only losing money on this kind of shit. And so are you, actually."
						)
					if Main.player_lapped:
						get_tree().get_root().get_node("MenuScreens").new_dialog(
							"You fuckin' know what getting fuckin' lapped fuckin' is?\nIt means that I ain't makin' no fuckin' mony, and the same goes for fuckin' you."
						)
				if save_cash_and_condition:
					# Apply Cash+Condition
					if Main.is_player(cei.driver_name):
						Main.ci.player_info[CI.DriverInfo.CASH] += cei.reward_cash+cei.grabbed_cash
						if Main.ci.player_info[CI.DriverInfo.CASH] < 0:
							Main.ci.player_info[CI.DriverInfo.CASH] = 0
							print("Player below zero cash!") # in-future: dialog or mechanic
						Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] = cei.condition
	if !Main.player_lapped && all_but_player_are_dead:
		bonus_cash = CI.REAPER_REWARDS[Main.current_player_race]
		Main.ci.player_info[CI.DriverInfo.CASH] += CI.REAPER_REWARDS[Main.current_player_race]
		get_tree().get_root().get_node("MenuScreens").new_dialog(
			"Daaaamn yo!\nI don't know how you did that, but everybody blew up - just like those ratings!\nHere's your cut, friend..."
		)
	if Main.current_kill_target != "":
		Main.current_kill_target = ""
		if target_not_player_are_dead:
			bonus_cash += CI.KILL_REWARDS[Main.current_player_race]
			Main.ci.player_info[CI.DriverInfo.CASH] += CI.KILL_REWARDS[Main.current_player_race]
			get_tree().get_root().get_node("MenuScreens").new_dialog(
				"It's nice to have someone you can count on.\nI've got you a little something, for your trouble..."
			)
		else:
			get_tree().get_root().get_node("MenuScreens").new_dialog(
				"Well. Guess you forgot.\n'Cause you wouldn't fuck me over on purpose, would you?\nYeah. What I thought."
			)

func apply_point_rewards() -> void:
	for t in Main.current_races.size():
		for d in Main.current_races[t].size():
			if Main.is_player(Main.current_races[t][d]):
				Main.ci.player_info[CI.DriverInfo.SCORE] += Main.ci.player_info[CI.DriverInfo.LAST_REWARD_POINTS]
				Main.ci.player_info[CI.DriverInfo.LAST_REWARD_POINTS] = 0
			else:
				Main.ci.bot_infos[Main.current_races[t][d]][CI.DriverInfo.SCORE] += Main.ci.bot_infos[Main.current_races[t][d]][CI.DriverInfo.LAST_REWARD_POINTS]
				Main.ci.bot_infos[Main.current_races[t][d]][CI.DriverInfo.LAST_REWARD_POINTS] = 0

func save_score_positions() -> void:
	sort_scorelist(false)
	for i in scorelist.size():
		if Main.ci.bot_infos.has(scorelist[i].driver_name):
			Main.ci.bot_infos[scorelist[i].driver_name][CI.DriverInfo.SCORE_POSITION] = i
		else:
			Main.ci.player_info[CI.DriverInfo.SCORE_POSITION] = i

func get_race_reward(t:int, p:int, cash:bool=true) -> int:
	var rewarr:Array = CI.RACE_REWARDS_CASH
	if !cash:
		rewarr = CI.RACE_REWARDS_POINTS
	if p >= 0 && p < rewarr[t].size():
		return rewarr[t][p]
	return 0

# SCORES (LEFT SIDE)

class ScoreInfo:
	var driver_name:String = ""
	var prereward_score:int = 0
	var reward:int = 0
	var current_score:int = 0
	
	func ini(driver_name:String, prereward_score:int, reward:int) -> void:
		self.driver_name = driver_name
		self.prereward_score = prereward_score
		self.reward = reward
		current_score = prereward_score+reward

	static func sort_score_info_pre(a:ScoreInfo, b:ScoreInfo) -> bool:
		return a.prereward_score > b.prereward_score

	static func sort_score_info(a:ScoreInfo, b:ScoreInfo) -> bool:
		return a.current_score > b.current_score

func ini_scorelist() -> void: # Prepare Data
	scorelist.clear()
	var si:ScoreInfo = ScoreInfo.new()
	si.ini(Main.ci.player_info[CI.DriverInfo.NAME], int(Main.ci.player_info[CI.DriverInfo.SCORE]), int(Main.ci.player_info[CI.DriverInfo.LAST_REWARD_POINTS]))
	scorelist.append(si)
	for b in Main.ci.bot_infos:
		if Main.ci.bot_infos[b][CI.DriverInfo.NAME] != Main.ci.campaign_stats[2]:
			si = ScoreInfo.new()
			si.ini(Main.ci.bot_infos[b][CI.DriverInfo.NAME], int(Main.ci.bot_infos[b][CI.DriverInfo.SCORE]), int(Main.ci.bot_infos[b][CI.DriverInfo.LAST_REWARD_POINTS]))
			scorelist.append(si)

func sort_scorelist(prereward:bool=true) -> void:
	if prereward:
		scorelist.sort_custom(ScoreInfo, "sort_score_info_pre")
	else:
		scorelist.sort_custom(ScoreInfo, "sort_score_info")

func ini_scores() -> void: # Create GUI
	if $Halves/Left/ScorePage/Scores.get_child_count() == 0:
		var driver_score:Control = DS.instance()
		$Halves/Left/ScorePage/Scores.add_child(driver_score) # 1 for player
		for c in CI.CHARACTERS.size()-1: # and rest is bots
			driver_score = DS.instance()
			$Halves/Left/ScorePage/Scores.add_child(driver_score)

func refresh_scores(show_change:bool=true) -> void: # Data to GUI
	for i in $Halves/Left/ScorePage/Scores.get_child_count():
		var ds:Control = $Halves/Left/ScorePage/Scores.get_child(i)
		ds.get_node("Name").text = scorelist[i].driver_name
		if Main.ci.bot_infos.has(scorelist[i].driver_name):
			ds.get_node("PortraitRing/Portrait").texture = CI.PORTRAITS_RINGED[Main.ci.bot_infos[scorelist[i].driver_name][CI.DriverInfo.PORTRAIT]]
		else:
			ds.get_node("PortraitRing/Portrait").texture = CI.PORTRAITS_RINGED[Main.ci.player_info[CI.DriverInfo.PORTRAIT]]
		if show_change:
			ds.get_node("Score").text = String(scorelist[i].prereward_score)
			if scorelist[i].reward != 0:
				ds.get_node("ScoreChange").text = "+"+String(scorelist[i].reward)
			else:
				ds.get_node("ScoreChange").text = ""
		else:
			ds.get_node("Score").text = String(scorelist[i].current_score)
			ds.get_node("ScoreChange").text = ""

# OUTCOME PAGES (RIGHT SIDE)

func set_page(p:int) -> void:
	page = p
	ini_page(p)

func ini_page(page:int) -> void:
	$Halves/Left/RoundCount.text = "Rounds: "+String(Main.ci.campaign_stats[0])
	var is_page1:bool = page==0
	$Halves/Right/Page1.visible = is_page1
	$Halves/Right/Page2.visible = !is_page1
	sort_scorelist(is_page1)
	if !Main.ci.campaign_stats[1] && scorelist[0].driver_name == Main.ci.player_info[CI.DriverInfo.NAME]:
		if get_tree().get_root().has_node("MenuScreens"):
			get_tree().get_root().get_node("MenuScreens").new_dialog("Fuck, you've made it!\nDid not see this coming. Most just die or get married, whatever the reason.\nWell, congratz! You're my hero. Seriously. Call me.")
		Main.ci.campaign_stats[1] = true
		Main.save_campaign_info()
	refresh_scores(is_page1)

func ini_outcomes() -> void:
	if $Halves/Right/Page1/Outcomes.get_child_count() == 0:
		var r:Array
		var o:Control
		for t in Main.current_races.size():
			r = Main.current_races[t]
			o = O.instance()
			o.get_node("Label").text = "Tier "+Main.int_to_roman(t+1)+": "+Main.current_maps[t][0]
			var d:String
			for n in r.size():
				d = r[n]
				o.get_child(n+1).get_node("Name").text = d
			$Halves/Right/Page1/Outcomes.add_child(o)

func ini_payroll() -> void: # "           "
	var payroll:Control = $Halves/Right/Page2/Payroll
	if no_last_race:
		payroll.visible = false
	else:
		payroll.visible = true
		var plr_cei:Main.CarEndInfo
		for cei in Main.player_race_outcome:
			if cei.driver_name == Main.ci.player_info[CI.DriverInfo.NAME]:
				plr_cei = cei
				break
		var no_rewards:bool = false
		# Set
		payroll.get_node("Tier").text = "Tier: "+Main.int_to_roman(Main.current_player_race+1)
		payroll.get_node("Position").text = "Position: "
		if Main.current_player_race < 0 || Main.player_lapped || plr_cei == null || plr_cei.position < 0 || plr_cei.position > 3:
			if Main.current_player_race < 0:
				payroll.get_node("Summary").text = "    NO PARTICIPATION!" # yes, so tired that we are using spaces to correct gui
			else:
				payroll.get_node("Summary").text = "            FAIL!"
			payroll.get_node("Position").text += "n/a"
			payroll.get_node("RacePay").text = "Reward: 0$"
			payroll.get_node("Cash").text = "Grabbed Cash: 0$ ("+String(forfeited_cash)+"$ Forfeited)"
			payroll.get_node("Bonus").text = "Bonus Rewards: 0$"
			payroll.get_node("Total").text = "Total Gain: 0$"
		else:
			payroll.get_node("Summary").text = "           PAYDAY"
			payroll.get_node("Position").text += string_me_position(plr_cei.position+1)
			payroll.get_node("RacePay").text = "Reward: "+String(plr_cei.reward_cash)+"$"
			payroll.get_node("Cash").text = "Grabbed Cash: "+String(plr_cei.grabbed_cash)+"$"
			payroll.get_node("Bonus").text = "Bonus Rewards: "+String(bonus_cash)+"$"
			payroll.get_node("Total").text = "Total Gain: "+String(plr_cei.reward_cash+plr_cei.grabbed_cash+bonus_cash)+"$"

# INPUT

func engage(forward:bool=true) -> void:
	match page:
		0:
			if forward:
				set_page(1)
		1:
			if forward:
				leave()
			elif !no_last_race:
				set_page(0)

func leave() -> void:
	if get_tree().get_root().has_node("MenuScreens"):
		get_tree().get_root().get_node("MenuScreens").set_new_screen(MenuScreens.MenuScreenType.GARAGE)

# LAST RACE RELATED

func finish_races(races:Array, player_race_index:int=-1, player_race_outcome:Array=[]) -> Array: # simulation + reward prep
	# Finish-off races
	for i in races.size():
		races[i] = sort_drivers_by_skill(races[i])
	var r:Array
	player_race_outcome.sort_custom(self, "compare_cei_position")
	for n in races.size():
		# r.clear()
		if n == player_race_index:
			for cei in player_race_outcome:
				r.append(cei.driver_name)
			races[n] = r.duplicate()
			break  # atm only player race gets special attention, the rest is sorted by "skill value"
	# End
	return races

func compare_cei_position(a:Main.CarEndInfo, b:Main.CarEndInfo) -> bool: # stops working when placed in Main.CarEndInfo (<= cannot be called by sort_custom()?)
		return negative_position_to_last(a.position) < negative_position_to_last(b.position)

func negative_position_to_last(p:int) -> int:
	if p == -1:
		return 4
	elif p == -3:
		return 5
	elif p == -2:
		return 6
	return p

func sort_drivers_by_skill(race:Array) -> Array: # singleton/static candidate
	var arr:Array
	var skill:float
	for n in race.size():
		if Main.is_player(race[n]):
			skill = Main.ci.player_info[CI.DriverInfo.BASE_SKILL]
		else:
			skill = Main.ci.bot_infos[race[n]][CI.DriverInfo.BASE_SKILL]
		arr.append(Vector2(n, skill))
	arr.sort_custom(self, "sort_vector2_y")
	var result:Array
	for a in arr:
		result.append(race[a.x])
	return result

func sort_vector2_y(a:Vector2, b:Vector2) -> bool:
	return a.y > b.y

func died_in_player_race(driver_index:int, player_race_outcome:Array) -> bool:
	return player_race_outcome[driver_index].position==-2

# UTILITIES

func string_me_position(pos:int) -> String: # singleton/static candidate; imprecise name tho
	if pos <= 0:
		pos = 4
	var s:String = String(pos)
	match pos:
		1:
			s += "st"
		2:
			s += "nd"
		3:
			s += "rd"
		_:
			s += "th"
	return s
