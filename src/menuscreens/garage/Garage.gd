extends Control
class_name Garage
# atm only one garage slot, altho CI.DriverInfo.GARAGE_SLOTS already exists

enum GarageMode {GARAGE, CAR_SHOP, UNDERGROUND, MAX}
var mode:int = GarageMode.GARAGE

var camera:Camera
var spatial:Spatial
var menu_screens:Node

var shop_car:int = 0
var shop_hue:float = 0.0
var show_car_guns:bool = true

var buying:bool = false

func ini(menu_screens:Node, camera:Camera=null, spatial:Spatial=null) -> void: # called from MenuScreens
	self.spatial = spatial
	self.camera = camera
	self.menu_screens = menu_screens
	respawn_car()
	set_mode(GarageMode.GARAGE)

func menu_input(event:InputEvent) -> void:
	match mode:
		GarageMode.GARAGE:
			if event.is_action("ui_left"):
				if $Main.focus != 6:
					$Main.set_focus(6)
				else:
					engage_main_garage(6)
			elif event.is_action("ui_right"):
				$Main.set_focus(7)
			$Main.menu_input(event)
		GarageMode.CAR_SHOP:
			if Main.CHEATS_ENABLED && event.is_action("reload"):
				Main.ci.player_info[CI.DriverInfo.CASH] += 10000
				refresh()
				return
			
			if !$CarShop.engage_with_arrows.has($CarShop.focus) && (event.is_action("ui_left") || event.is_action("ui_right")):
				if event.is_action("ui_left"):
					engage_car_shop($CarShop.esc_index)
				else:
					$CarShop.set_focus(0)
			else:
				$CarShop.menu_input(event)
		GarageMode.UNDERGROUND:
			$Underground.menu_input(event)

func refresh() -> void: # called from set_mode()
	$Main.visible = mode == GarageMode.GARAGE
	$CarShop.visible = mode == GarageMode.CAR_SHOP
	$Underground.visible = mode == GarageMode.UNDERGROUND
	match mode:
		GarageMode.GARAGE:
			refresh_main_garage()
			if Main.ci.campaign_stats[4] && !Main.ci.campaign_stats[7] && menu_screens != null && menu_screens.screen_focus == MenuScreens.MenuScreenType.GARAGE:
				menu_screens.new_dialog("Welcome to the shop.\nBetter fix up your car here before the next race.\nAlso you SHOULD BUY a new set of TYRES - I can tell the next track is going to be a bit more slippery.")
				Main.ci.campaign_stats[7] = true
		GarageMode.CAR_SHOP:
			$CarShop.set_focus(0)
			refresh_car_shop()
		GarageMode.UNDERGROUND:
			refresh_underground()
	# Cash
	$Cash.text = "Cash: "+String(Main.ci.player_info[CI.DriverInfo.CASH])+"$"

func engage(menu_name:String, f:int, forward:bool=true) -> void:
	match menu_name:
		"Main":
			engage_main_garage(f, forward)
		"CarShop":
			engage_car_shop(f, forward)
		"Underground":
			engage_underground(f, forward)

# MAIN GARAGE 2D

func changed_focus(menu_name:String, new_f:int) -> void: # called before set_focus() actually executes
	match menu_name:
		"Main":
			var car_slot:Dictionary = Main.ci.player_info[CI.DriverInfo.CARS][0]
			var car_tier:int = CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.TIER]
			if new_f == 0 || $Main.focus == 0:
				$Main.buttons.get_child(0).current_text = get_upgrade_text(CI.CarSlot.ENGINE, car_slot[CI.CarSlot.ENGINE], car_tier, new_f == 0)
			if new_f == 1 || $Main.focus == 1:
				$Main.buttons.get_child(1).current_text = get_upgrade_text(CI.CarSlot.TYRES, car_slot[CI.CarSlot.TYRES], car_tier, new_f == 1)
			if new_f == 2 || $Main.focus == 2:
				$Main.buttons.get_child(2).current_text = get_upgrade_text(CI.CarSlot.ARMOR, car_slot[CI.CarSlot.ARMOR], car_tier, new_f == 2)

func refresh_main_garage() -> void:
	var car_slot:Dictionary = Main.ci.player_info[CI.DriverInfo.CARS][0]
	var car_tier:int = CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.TIER]
	var car_max_condition:float = CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.HITPOINTS]+car_slot[CI.CarSlot.ARMOR]*CI.ARMOR_UPGRADE_POWER
	var car_damage:float = car_max_condition-car_slot[CI.CarSlot.CONDITION]
	# Head
	$Main/Name.text = car_slot[CI.CarSlot.NAME].to_upper()
	$Main/Condition.text = "Condition: "+String(floor((car_slot[CI.CarSlot.CONDITION]/car_max_condition)*100.0))+"%"
	# Engine
	$Main.buttons.get_child(0).current_text = get_upgrade_text(CI.CarSlot.ENGINE, car_slot[CI.CarSlot.ENGINE], car_tier, $Main.buttons.get_child(0).focused)
	# Tyres
	$Main.buttons.get_child(1).current_text = get_upgrade_text(CI.CarSlot.TYRES, car_slot[CI.CarSlot.TYRES], car_tier, $Main.buttons.get_child(1).focused)
	# Armor
	$Main.buttons.get_child(2).current_text = get_upgrade_text(CI.CarSlot.ARMOR, car_slot[CI.CarSlot.ARMOR], car_tier, $Main.buttons.get_child(2).focused)
	# Repair
	if car_slot[CI.CarSlot.CONDITION] == car_max_condition:
		$Main.buttons.get_child(3).disabled = true
		$Main.buttons.get_child(3).current_text = ""
		if $Main.focus == 3:
			$Main.set_focus(-1)
	else:
		$Main.buttons.get_child(3).disabled = false
		$Main.buttons.get_child(3).current_text = "Repair: "
		var repair_power:float = CI.REPAIR_POWER*car_max_condition
		if repair_power > car_damage:
			repair_power = car_damage
		if can_afford(get_repair_price(repair_power, car_slot[CI.CarSlot.NAME], car_max_condition)):
			$Main.buttons.get_child(3).current_text += String(round((repair_power/car_max_condition)*100.0))+"% ("+String(get_repair_price(repair_power, car_slot[CI.CarSlot.NAME], car_max_condition))+"$)"
		else:
			var affordable_repair:float = get_affordable_repair(Main.ci.player_info[CI.DriverInfo.CASH], car_slot[CI.CarSlot.NAME], car_max_condition)
			$Main.buttons.get_child(3).current_text += String(round((affordable_repair/car_max_condition)*100.0))+"% ("+String(get_repair_price(affordable_repair, car_slot[CI.CarSlot.NAME], car_max_condition))+"$)"
	for b in 4:
		$Main.buttons.get_child(b).refresh()

func get_upgrade_text(type:int, level:int, car_tier:int, show_price:bool=false) -> String:
	var txt:String
	match type:
		CI.CarSlot.ENGINE:
			txt = "Engine"
		CI.CarSlot.TYRES:
			txt = "Tyres"
		CI.CarSlot.ARMOR:
			txt = "Armor"
	txt += ": "+Main.int_to_roman(level+1)
	if !is_upgrade_available(type, level, car_tier):
		txt += " (Max)"
	elif show_price:
		txt += " (Upgrade for "+String(get_upgrade_price(type, level, car_tier))+"$)"
	return txt

func engage_main_garage(f:int, forward:bool=true) -> void:
	var car_slot:Dictionary = Main.ci.player_info[CI.DriverInfo.CARS][0]
	var car_tier:int = CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.TIER]
	var car_max_condition:float = CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.HITPOINTS]+car_slot[CI.CarSlot.ARMOR]*CI.ARMOR_UPGRADE_POWER
	var car_damage:float = car_max_condition-car_slot[CI.CarSlot.CONDITION]
	var price:int
	match f:
		0: # Engine
			price = get_upgrade_price(CI.CarSlot.ENGINE, car_slot[CI.CarSlot.ENGINE], car_tier)
			if is_upgrade_available(CI.CarSlot.ENGINE, car_slot[CI.CarSlot.ENGINE], car_tier) && can_afford(price):
				buy_upgrade(CI.CarSlot.ENGINE, price)
		1: # Tyres
			price = get_upgrade_price(CI.CarSlot.TYRES, car_slot[CI.CarSlot.TYRES], car_tier)
			if is_upgrade_available(CI.CarSlot.TYRES, car_slot[CI.CarSlot.TYRES], car_tier) && can_afford(price):
				buy_upgrade(CI.CarSlot.TYRES, price)
		2: # Armor
			price = get_upgrade_price(CI.CarSlot.ARMOR, car_slot[CI.CarSlot.ARMOR], car_tier)
			if is_upgrade_available(CI.CarSlot.ARMOR, car_slot[CI.CarSlot.ARMOR], car_tier) && can_afford(price):
				buy_upgrade(CI.CarSlot.ARMOR, price)
		3: # Repair
			if !$Main.buttons.get_child(3).disabled:
				var repair_power:float = CI.REPAIR_POWER*car_max_condition
				if repair_power > car_damage:
					repair_power = car_damage
				var repair_price:float = get_repair_price(repair_power, car_slot[CI.CarSlot.NAME], car_max_condition)
				if can_afford(repair_price):
					buy_repair(repair_power, car_max_condition, repair_price)
				else:
					var affordable_repair:float = get_affordable_repair(Main.ci.player_info[CI.DriverInfo.CASH], car_slot[CI.CarSlot.NAME], car_max_condition)
					buy_repair(affordable_repair, car_max_condition, Main.ci.player_info[CI.DriverInfo.CASH])
		4: # Car Shop
			set_mode(GarageMode.CAR_SHOP)
			if camera != null:
				camera.get_node("AnimationPlayer").play_backwards("MainToCreation")
		5: # Underground Market
			set_mode(GarageMode.UNDERGROUND)
		6: # Scoreboard
			if Main.current_races != null && menu_screens != null:
				menu_screens.set_new_screen(MenuScreens.MenuScreenType.SCOREBOARD)
		7: # NEW ROUND
			if menu_screens != null:
				if Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] > 0.0:
					menu_screens.mm_making_new_save = false
					menu_screens.input_enabled = false
					var anim_player:AnimationPlayer = camera.get_node("AnimationPlayer")
					anim_player.play("MainToCreation")
					anim_player.advance(0)
					anim_player.stop()
					menu_screens.set_new_screen(MenuScreens.MenuScreenType.RACE_PICK)
				else:
					menu_screens.new_info_sign("Car Needs Repairs!")
		8: # To Main Menu
			if menu_screens != null:
				camera.get_node("AnimationPlayer").play_backwards("MainToCreation")
				menu_screens.set_new_screen(MenuScreens.MenuScreenType.MAIN)

func is_upgrade_available(type:int, current_upgrade:int, car_tier:int) -> bool:
	match type:
		CI.CarSlot.TYRES:
			return current_upgrade < car_tier || (car_tier == 0 && current_upgrade == 0)
		_:
			return current_upgrade < car_tier

func buy_upgrade(type:int, price:int) -> void:
	Main.ci.player_info[CI.DriverInfo.CASH] -= price
	Main.ci.player_info[CI.DriverInfo.CARS][0][type] += 1
	if type == CI.CarSlot.ARMOR:
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] += CI.ARMOR_UPGRADE_POWER
	refresh()

func get_upgrade_price(type:int, level:int, car_tier:int) -> int:
	return CI.UPGRADE_PRICE*(level+1)*(car_tier+1)

func buy_repair(repair_power:float, car_max_condition:float, price:int) -> void:
	Main.ci.player_info[CI.DriverInfo.CASH] -= price
	Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] += repair_power
	if Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] > car_max_condition:
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] = car_max_condition
	refresh()
	if spatial.get_node("Main/CarSlot").get_child_count() > 0:
		refresh_damage_visuals(spatial.get_node("Main/CarSlot").get_child(0), Main.ci.player_info[CI.DriverInfo.CARS][0])

func get_repair_price(amount:float, car_name:String, car_max_condition:float) -> int:
	return int(round((amount/car_max_condition)*(CI.REPAIR_PRICE*CI.CARS[car_name][CI.CarInfo.PRICE])))

func get_affordable_repair(cash:int, car_name:String, car_max_condition:float) -> float:
	return round((cash / (CI.REPAIR_PRICE*CI.CARS[car_name][CI.CarInfo.PRICE]))*car_max_condition)

func can_afford(price:int) -> bool:
	return Main.ci.player_info[CI.DriverInfo.CASH] >= price

func set_mode(m:int) -> void:
	mode = m
	refresh()

# MAIN GARAGE 3D

func respawn_car() -> void:
	if spatial != null:
		for c in spatial.get_node("Main/CarSlot").get_children():
			c.queue_free()
		var car:GaragedCar = load("res://src/menuscreens/garage/cars_garaged/"+CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.RESOURCE]+".tscn").instance()
		# Color
		var car_slot:Dictionary = Main.ci.player_info[CI.DriverInfo.CARS][0]
		color_car(car, Main.ci.player_info[CI.DriverInfo.HUE], CI.CARS.keys()[shop_car][CI.CarSlot.NAME] == "Companion")
		# Condition
		refresh_damage_visuals(car, car_slot)
		# Finish
		spatial.get_node("Main/CarSlot").add_child(car)

func refresh_damage_visuals(car:Node, car_slot_info:Dictionary) -> void:
	var main_material:Material = car.get_node("MeshInstance").get_surface_material(car.main_mat_index)
	var max_condition:float = CI.CARS[car_slot_info[CI.CarSlot.NAME]][CI.CarInfo.HITPOINTS]+Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.ARMOR]*CI.ARMOR_UPGRADE_POWER
	Main.refresh_damage_visuals_on_car(car, Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION], max_condition, car.normal_map_start, car.normal_map_max, main_material, Main.died_in_water)

func color_car(car:GaragedCar, hue:float, is_companion:bool=false) -> void:
	var car_color:Color = car.get_node("MeshInstance").get_surface_material(car.main_mat_index).albedo_color
	car.get_node("MeshInstance").get_surface_material(car.main_mat_index).albedo_color = Color.from_hsv(hue, car_color.s, car_color.v, car_color.a)
	if is_companion: # in-future: main_mat_index as array
		car.get_node("MeshInstance").get_surface_material(6).albedo_color = car_color

# CAR SHOP

func refresh_car_shop() -> void:
	shop_hue = Main.ci.player_info[CI.DriverInfo.HUE]
	# 2D
	var car_name:String = CI.CARS.keys()[shop_car]
	$CarShop/Buttons/Name.current_text = car_name.to_upper()
	$CarShop/Buttons/Hue.custom_float = shop_hue
	$CarShop/Buttons/Price.current_text = "Price: "+String(CI.CARS[car_name][CI.CarInfo.PRICE])+"$\n(-"+String(get_car_sell_price(Main.ci.player_info[CI.DriverInfo.CARS][0]))+"$ = "+String(get_final_car_price(car_name, Main.ci.player_info[CI.DriverInfo.CARS][0]))+"$)"
	for b in $CarShop.buttons.get_children():
		b.refresh()
	# 3D
	color_car(spatial.get_node("CarShop/CarSlot").get_child(shop_car), shop_hue, CI.CARS.keys()[shop_car][CI.CarSlot.NAME] == "Companion")
	spatial.get_node("CarShop/CarSlot").get_child(shop_car).visible = true
	if get_tree().get_root().has_node("MenuScreens"):
		get_tree().get_root().get_node("MenuScreens/Viewports/Viewport/MainMenu").visible = false

func engage_car_shop(f:int, forward:bool=true) -> void:
	match f:
		0: # Name
			if forward:
				set_shop_car(Main.inc_int_around(shop_car, CI.CARS.keys().size()-1))
			else:
				set_shop_car(Main.inc_int_around(shop_car, CI.CARS.keys().size()-1, -1))
		1: # Hue
			if forward:
				if shop_hue < 1.0:
					shop_hue = Main.inc_float_around(shop_hue, 1.0, 0.01)
			else:
				if shop_hue > 0.0:
					shop_hue = Main.inc_float_around(shop_hue, 1.0, -0.01)
			$CarShop/Buttons/Hue.custom_float = shop_hue
			$CarShop/Buttons/Hue.refresh()
			color_car(spatial.get_node("CarShop/CarSlot").get_child(shop_car), shop_hue, CI.CARS.keys()[shop_car][CI.CarSlot.NAME] == "Companion")
		3: # Buy
			if can_afford(get_final_car_price(CI.CARS.keys()[shop_car], Main.ci.player_info[CI.DriverInfo.CARS][0])):
				buying = true
				menu_screens.get_node("Viewports/GUI/Bordered/YeahNo").visible = true
				menu_screens.get_node("Viewports/GUI/Bordered/YeahNo/Label").text = "For ReaL?"
				menu_screens.get_node("Viewports/GUI/Bordered/YeahNo").set_focus(menu_screens.get_node("Viewports/GUI/Bordered/YeahNo").esc_index)
			else:
				menu_screens.new_info_sign("Not Enough Cash")
		4: # Guns
			set_show_car_guns(!show_car_guns)
		5: # Esc
			#set_show_car_guns(true)
			for c in spatial.get_node("Main/CarSlot").get_children():
				c.get_node("Gun").visible = true
			$CarShop.set_focus(0)
			set_mode(GarageMode.GARAGE)
			if camera != null:
				camera.get_node("AnimationPlayer").play("MainToCreation")

func set_show_car_guns(scg:bool) -> void:
	show_car_guns = scg
	get_tree().call_group("garaged_guns", "set_visible", scg)
	if scg:
		$CarShop/Buttons/Guns.current_text = "Show Weapons: ON"
	else:
		$CarShop/Buttons/Guns.current_text = "Show Weapons: OFF"
	$CarShop/Buttons/Guns.refresh()

func set_shop_car(sc:int) -> void:
	spatial.get_node("CarShop/CarSlot").get_child(shop_car).visible = false
	shop_car = sc
	refresh_car_shop()

func hide_shop_car() -> void:
	if spatial != null:
		spatial.get_node("CarShop/CarSlot").get_child(shop_car).visible = false

func buy_car(sc:int) -> void:
	var car_name:String = CI.CARS.keys()[shop_car]
	if CI.CARS.has(car_name):
		# update player
		Main.ci.player_info[CI.DriverInfo.CASH] -= get_final_car_price(car_name, Main.ci.player_info[CI.DriverInfo.CARS][0])
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME] = car_name
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.ENGINE] = 0
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.TYRES] = 0
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.ARMOR] = 0
		Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.CONDITION] = CI.CARS[car_name][CI.CarInfo.HITPOINTS]
		Main.ci.player_info[CI.DriverInfo.HUE] = shop_hue
		# update menus
		menu_screens.go_quit(true)
		respawn_car()
		set_mode(GarageMode.GARAGE)
		if camera != null:
			camera.get_node("AnimationPlayer").play("MainToCreation")

func get_car_sell_price(car_slot:Dictionary) -> int:
	return int(floor(CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.PRICE] * CI.SELL_PRICE * ( car_slot[CI.CarSlot.CONDITION] / (CI.CARS[car_slot[CI.CarSlot.NAME]][CI.CarInfo.HITPOINTS] + car_slot[CI.CarSlot.ARMOR]*CI.ARMOR_UPGRADE_POWER) )))

func get_final_car_price(car_name:String, car_slot:Dictionary={}) -> int: # sub old car price
	if car_slot.size() == 0:
		return CI.CARS[car_name][CI.CarInfo.PRICE]
	else:
		return CI.CARS[car_name][CI.CarInfo.PRICE] - get_car_sell_price(car_slot)

# UNDERGROUND MARKET

func refresh_underground() -> void:
	var car_tier:int = CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
	# Mines
	$Underground.buttons.get_child(0).current_text = "Mines ("
	if Main.ci.campaign_stats[8]:
		$Underground.buttons.get_child(0).current_text += "BOUGHT)"
	else:
		$Underground.buttons.get_child(0).current_text += String(CI.MINES_PRICE*(car_tier+1))+"$)"
	# Rocket Fuel
	$Underground.buttons.get_child(1).current_text = "Rocket Fuel ("
	if Main.ci.campaign_stats[9]:
		$Underground.buttons.get_child(1).current_text += "BOUGHT)"
	else:
		$Underground.buttons.get_child(1).current_text += String(CI.ROCKET_FUEL_PRICE*(car_tier+1))+"$)"
	# Sabotauge
	$Underground.buttons.get_child(2).current_text = "Order Sabotauge ("
	if Main.ci.campaign_stats[10]:
		$Underground.buttons.get_child(2).current_text += "BOUGHT)"
	else:
		$Underground.buttons.get_child(2).current_text += String(CI.SABOTAUGE_PRICE*(car_tier+1))+"$)"
	# refresh all
	for b in 3:
		$Underground.buttons.get_child(b).refresh()

func engage_underground(f:int, forward:bool=true) -> void:
	var car_tier:int = CI.CARS[Main.ci.player_info[CI.DriverInfo.CARS][0][CI.CarSlot.NAME]][CI.CarInfo.TIER]
	match f:
		0: # Mines
			if !Main.ci.campaign_stats[8]:
				if can_afford(CI.MINES_PRICE*(car_tier+1)):
					Main.ci.player_info[CI.DriverInfo.CASH] -= CI.MINES_PRICE*(car_tier+1)
					Main.ci.campaign_stats[8] = true
					refresh()
				else:
					menu_screens.new_info_sign("Not Enough Cash")
		1: # Rocket Fuel
			if !Main.ci.campaign_stats[9]:
				if can_afford(CI.ROCKET_FUEL_PRICE*(car_tier+1)):
					Main.ci.player_info[CI.DriverInfo.CASH] -= CI.ROCKET_FUEL_PRICE*(car_tier+1)
					Main.ci.campaign_stats[9] = true
					refresh()
				else:
					menu_screens.new_info_sign("Not Enough Cash")
		2: # Sabotauge
			if !Main.ci.campaign_stats[10]:
				if can_afford(CI.SABOTAUGE_PRICE*(car_tier+1)):
					Main.ci.player_info[CI.DriverInfo.CASH] -= CI.SABOTAUGE_PRICE*(car_tier+1)
					Main.ci.campaign_stats[10] = true
					refresh()
				else:
					menu_screens.new_info_sign("Not Enough Cash")
		3: # Weapons (disabled)
			pass
		4: # Back
			$Underground.set_focus(-1)
			set_mode(GarageMode.GARAGE)
