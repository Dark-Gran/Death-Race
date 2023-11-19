extends Node
class_name MenuScreens
# One of two "main game-screens" (together with Race)
# = Acts as Main Menu but actually holds all non-race screens
# Also holds TT Viewports to speed up Race instancing

enum MenuScreenType {MAIN, RACE_PICK, SCOREBOARD, GARAGE, PHOTO, MAX}
var screen_focus:int = -1
var input_enabled:bool = false

# Main Menu
const PORTRAITS:Array = [
	preload("res://assets/portraits/00.png"),
	preload("res://assets/portraits/01.png"),
	preload("res://assets/portraits/02.png"),
	preload("res://assets/portraits/03.png"),
	preload("res://assets/portraits/04.png"),
	preload("res://assets/portraits/05.png"),
	preload("res://assets/portraits/06.png"),
	preload("res://assets/portraits/07.png"),
	preload("res://assets/portraits/08.png"),
	preload("res://assets/portraits/09.png"),
	preload("res://assets/portraits/10.png"),
	preload("res://assets/portraits/11.png")
]

enum MenuButtonType {CONTINUE, NEW, SAVE, LOAD, OPTIONS, QUIT, MAX}

onready var mm_yeahno:Control = $Viewports/GUI/Bordered/YeahNo
onready var mm_menu:Control = $Viewports/GUI/Bordered/MainMenu
onready var mm_spatial:Spatial = $Viewports/Viewport/MainMenu
onready var mm_options:Control = $Viewports/GUI/Bordered/Settings
onready var mm_creation:Control = $Viewports/GUI/Bordered/PlayerCreation
onready var mm_creation_car_color:Color = $Viewports/Viewport/MainMenu/CreationScene/Companion.get_surface_material(2).albedo_color
onready var mm_saves:Control = $Viewports/GUI/Bordered/Saves

var mm_set_to_save:bool = true
var mm_making_new_save:bool = true
var chosen_save_slot:bool = -1

var quitting:bool = false # yeahno set to quit

# Dialogs

onready var mm_dialog:Control = $Viewports/GUI/Bordered/Dialog

var dialog_queue:Array = []
var pending_kill_target:String = "" # kill quest offer present if not empty (in-future: QuestInfo? (new or merge with DialogInfo))

# Race Pick / Race Signup
onready var race_pick_ui:Control = $Viewports/GUI/Bordered/RacePick

# Scoreboard

onready var scoreboard_ui:Control = $Viewports/GUI/Bordered/Scoreboard

# Garage

onready var garage_ui:Control = $Viewports/GUI/Bordered/Garage
onready var garage_spatial:Spatial = $Viewports/Viewport/Garages

# Photo Scene
var ppl_focus:int = 0

# GENERAL

func _ready() -> void:
	var anim_player:AnimationPlayer = $Viewports/Viewport/Camera/AnimationPlayer
	anim_player.play("MainToCreation")
	anim_player.advance(0)
	anim_player.stop()
	refresh_dialog_portrait()
	get_tree().paused = false
	set_nonmain_visibility(false)
	mm_yeahno.visible = false
	mm_dialog.visible = false
	if Main.fresh_out_of_race:
		set_new_screen(MenuScreenType.SCOREBOARD)
		$Viewports/Viewport/Camera/AnimationPlayer.play("MainToCreation")
		$Viewports/Viewport/Camera/AnimationPlayer.advance(2)
	else:
		set_new_screen(MenuScreenType.MAIN)
	Main.loading_scene.toggle_loading_signs(false)

func set_new_screen(screen_type:int) -> void:
	if screen_type == MenuScreenType.PHOTO && !has_node("Viewports/Viewport/PhotoScene"):
		return
	
	if Main.is_int_in_range(screen_type, 0, MenuScreenType.MAX-1):
		# Hide previous
		if Main.is_int_in_range(screen_focus, 0, MenuScreenType.MAX-1):
			end_screen_focus()
		# Show new
		screen_focus = screen_type
		ini_screen_focus()
		apply_gfx_settings()
	input_enabled = true

func set_nonmain_visibility(v:bool) -> void:
	race_pick_ui.visible = v
	scoreboard_ui.visible = v
	garage_ui.visible = v
	garage_spatial.visible = v
	if has_node("Viewports/Viewport/PhotoScene"):
		get_node("Viewports/Viewport/PhotoScene").visible = v

func ini_screen_focus() -> void:
	match screen_focus:
		MenuScreenType.MAIN:
			mm_options.visible = false
			mm_creation.visible = false
			mm_saves.visible = false
			mm_menu.visible = true
			mm_spatial.visible = true
			refresh_save_buttons()
		MenuScreenType.RACE_PICK:
			race_pick_ui.ini_race_pick()
			race_pick_ui.visible = true
			mm_spatial.visible = true
			garage_spatial.visible = true
			garage_ui.hide_shop_car()
			$Viewports/Viewport/Camera/AnimationPlayer.play_backwards("MainToCreation")
		MenuScreenType.SCOREBOARD:
			mm_menu.visible = false
			mm_spatial.visible = false
			var fresh:bool = scoreboard_ui.fresh
			scoreboard_ui.ini()
			if fresh:
				garage_ui.ini(self, $Viewports/Viewport/Camera, garage_spatial)
			scoreboard_ui.visible = true
			garage_spatial.visible = true
		MenuScreenType.GARAGE:
			if garage_ui.spatial == null:
				garage_ui.ini(self, $Viewports/Viewport/Camera, garage_spatial)
			else:
				garage_ui.refresh()
			garage_ui.visible = true
			garage_spatial.visible = true
			
		MenuScreenType.PHOTO:
			if has_node("Viewports/Viewport/PhotoScene"):
				$Viewports/Viewport/PhotoScene.visible = true
				$Viewports/Viewport/PhotoScene/Camera.current = true
				$Viewports/Viewport/PhotoScene/Scene/Ppl.get_child(ppl_focus).visible = true

func refresh_save_buttons() -> void:
	mm_menu.buttons.get_child(MenuButtonType.CONTINUE).disabled = Main.current_save_slot < 0
	mm_menu.buttons.get_child(MenuButtonType.SAVE).disabled = Main.current_save_slot < 0
	mm_menu.buttons.get_child(MenuButtonType.SAVE).visible = Main.current_save_slot >= 0
	if Main.current_save_slot < 0:
		mm_menu.buttons.get_child(MenuButtonType.CONTINUE).current_text = ""
		if mm_menu.focus == MenuButtonType.CONTINUE || mm_menu.focus == MenuButtonType.SAVE:
			mm_menu.set_focus(-1)
	else:
		mm_menu.buttons.get_child(MenuButtonType.CONTINUE).current_text = "Continue"
	mm_menu.buttons.get_child(MenuButtonType.CONTINUE).refresh()

func apply_gfx_settings() -> void:
	var env:Environment = $Viewports/Viewport/WorldEnvironment.environment
	Main.apply_show_fps($Viewports/GUI/Debug/FPS)
	Main.apply_ssao(env)
	Main.apply_glow(env)
	Main.apply_msaa($Viewports/Viewport)
	Main.apply_shadow_filter()
	Main.apply_grass()
	Main.apply_low_disable()

func end_screen_focus() -> void:
	match screen_focus:
		MenuScreenType.MAIN:
			mm_menu.visible = false
			mm_options.visible = false
			mm_creation.visible = false
			#mm_spatial.visible = false
		MenuScreenType.RACE_PICK:
			race_pick_ui.visible = false
			#if mm_making_new_save:
			#	mm_spatial.visible = false
			#else:
			#	garage_spatial.visible = false
		MenuScreenType.SCOREBOARD:
			scoreboard_ui.visible = false
			#mm_spatial.visible = false
		MenuScreenType.GARAGE:
			garage_ui.visible = false
			garage_spatial.visible = false
			mm_spatial.visible = true
		MenuScreenType.PHOTO:
			$Viewports/Viewport/PhotoScene.visible = false

func _input(event:InputEvent) -> void:
	if input_enabled:
		var arrows_on_hue:bool = ((screen_focus == MenuScreenType.GARAGE && garage_ui.visible && garage_ui.get_node("CarShop").focus == 1) || (screen_focus == MenuScreenType.MAIN && mm_creation.visible && mm_creation.focus == 2)) && (event.is_action("ui_left") || event.is_action("ui_right")) # bit ugly fix (giving hue-arrows exception from "released event only")
		if event.is_pressed():
			if event is InputEventMouseButton: # mouse
				new_info_sign("Keyboard Only")
			elif arrows_on_hue:
				if screen_focus == MenuScreenType.GARAGE:
					garage_ui.get_node("CarShop").menu_input(event)
				else:
					mm_creation.menu_input(event)
		else:
			if event.is_action("toggle_fps"): # fps
				Main.toggle_show_fps()
				Main.apply_show_fps($Viewports/GUI/Debug/FPS)
			
			if mm_dialog.visible:
				if mm_dialog.buttons.visible:
					mm_dialog.menu_input(event)
				elif event.is_action("ui_select") || event.is_action("ui_cancel"):
					if dialog_queue.size() == 0:
						mm_dialog.visible = false
						if screen_focus == MenuScreenType.RACE_PICK:
							if !race_pick_ui.player_signed && Main.ci.campaign_stats[4]:
								race_pick_ui.get_node("Timer").start()
					else:
						show_next_dialog()
				return
			
			if mm_yeahno.visible:
				mm_yeahno.menu_input(event)
				return
			
			match screen_focus:
				# MAIN MENU
				MenuScreenType.MAIN:
					if event.is_action("reload") && Main.DEBUG_ENABLED:
						set_new_screen(MenuScreenType.PHOTO)
					else:
						if mm_menu.visible:
							mm_menu.menu_input(event)
						elif mm_options.visible:
							mm_options.menu_input(event)
						elif mm_creation.visible:
							if !arrows_on_hue:
								mm_creation.menu_input(event)
						elif mm_saves.visible:
							mm_saves.menu_input(event)
				# RACE PICK
				MenuScreenType.RACE_PICK:
					if race_pick_ui.player_signed:
						if event.is_action("ui_select") || event.is_action("ui_cancel"):
							race_pick_ui.engage(-1)
					else:
						race_pick_ui.menu_input(event)
				# SCOREBOARD
				MenuScreenType.SCOREBOARD:
					if (event.is_action("ui_down")
					|| event.is_action("ui_select")
					|| event.is_action("ui_accept")
					|| event.is_action("ui_right")
					|| event.is_action("ui_cancel")):
						scoreboard_ui.engage()
					elif event.is_action("ui_up") || event.is_action("ui_left"):
						scoreboard_ui.engage(false)
				# GARAGE
				MenuScreenType.GARAGE:
					garage_ui.menu_input(event)
				# PHOTO SCENE
				MenuScreenType.PHOTO:
					if event.is_action("ui_cancel") || event.is_action("reload"):
						set_new_screen(MenuScreenType.MAIN)
					elif event.is_action("ui_up"): # up
						$Viewports/Viewport/PhotoScene/Scene/Ppl.get_child(ppl_focus).visible = false
						ppl_focus = Main.inc_int_around(ppl_focus, $Viewports/Viewport/PhotoScene/Scene/Ppl.get_child_count()-1)
						$Viewports/Viewport/PhotoScene/Scene/Ppl.get_child(ppl_focus).visible = true
					elif event.is_action("ui_down"): # down
						$Viewports/Viewport/PhotoScene/Scene/Ppl.get_child(ppl_focus).visible = false
						ppl_focus = Main.inc_int_around(ppl_focus, $Viewports/Viewport/PhotoScene/Scene/Ppl.get_child_count()-1, -1)
						$Viewports/Viewport/PhotoScene/Scene/Ppl.get_child(ppl_focus).visible = true

func _physics_process(delta:float) -> void:
	if $Viewports/GUI/Debug/FPS.visible:
		$Viewports/GUI/Debug/FPS.text = " "+String(Performance.get_monitor(Performance.TIME_FPS))

func _process(delta:float) -> void:
	if !$Viewports/GUI/Bordered/InfoSign.completed:
		$Viewports/GUI/Bordered/InfoSign.fade(delta)
	if !$Viewports/GUI/Bordered/Settings/HowToFPS.completed:
		$Viewports/GUI/Bordered/Settings/HowToFPS.fade(delta)

# MAIN MENU (MENU+OPTIONS+CREATION)

func new_info_sign(txt:String) -> void:
	$Viewports/GUI/Bordered/InfoSign.text = txt
	$Viewports/GUI/Bordered/InfoSign.restart()

func engage(menu_name:String, f:int, forward:bool=true) -> void:
	match menu_name:
		"MainMenu":
			engage_mm(f)
		"GFXSettings":
			match f: # for full list (which leads here), see GFXMenu.engage()
				8: # Exit
					go_options(true)
		"PlayerCreation":
			engage_creation(f, forward)
		"Saves":
			engage_saves(f)
		"YeahNo":
			if f == mm_yeahno.esc_index:
				go_quit(true)
			else:
				if quitting:
					Main.quit_request()
				elif garage_ui.buying:
					garage_ui.buy_car(garage_ui.shop_car)
		"Dialog":
			engage_dialog(f, forward)

func engage_mm(f:int) -> void:
	match f:
		MenuButtonType.CONTINUE:
			mm_making_new_save = false
			if Main.current_save_slot >= 0:
				set_new_screen(MenuScreenType.GARAGE)
				garage_ui.get_node("Main").set_focus(7)
				$Viewports/Viewport/Camera/AnimationPlayer.play("MainToCreation")
		MenuButtonType.NEW:
			mm_making_new_save = true
			mm_set_to_save = true
			if is_save_slot_empty(0):
				Main.new_game_slot = 0
				go_creation()
			else:
				go_saves()
		MenuButtonType.SAVE:
			mm_making_new_save = false
			mm_set_to_save = true
			go_saves()
		MenuButtonType.LOAD:
			mm_making_new_save = false
			mm_set_to_save = false
			go_saves()
		MenuButtonType.OPTIONS:
			go_options()
		MenuButtonType.QUIT:
			mm_menu.set_focus(-1)
			quitting = true
			mm_yeahno.set_focus(mm_yeahno.esc_index)
			mm_yeahno.get_node("Label").text = "Quit?"
			go_quit()

func go_quit(go_back:bool=false) -> void:
	mm_yeahno.visible = !go_back
	if go_back:
		quitting = false
		garage_ui.buying = false
		mm_yeahno.set_focus(-1)

func go_options(go_back:bool=false) -> void: # see GFXMenu
	mm_menu.visible = go_back
	mm_options.visible = !go_back
	if mm_options.visible:
		if mm_options.get_node("HowToFPS").completed:
			mm_options.get_node("HowToFPS").restart()
	else:
		mm_options.reset()
		mm_options.set_focus(-1)

# PLAYER CREATION

func go_creation(go_back:bool=false) -> void:
	if is_save_slot_empty(0):
		mm_menu.visible = go_back
	else:
		mm_saves.visible = go_back
	mm_creation.visible = !go_back
	if mm_creation.visible:
		refresh_creation()
		$Viewports/Viewport/Camera/AnimationPlayer.play("MainToCreation")
	else:
		Main.new_game_slot = -1
		mm_creation.set_focus(-1)
		$Viewports/Viewport/Camera/AnimationPlayer.play_backwards("MainToCreation")

func engage_creation(c:int, forward:bool=true) -> void:
	match c:
		CreationOption.Type.PORTRAIT:
			if forward:
				Main.ci.player_info[CI.DriverInfo.PORTRAIT] = Main.inc_int_around(Main.ci.player_info[CI.DriverInfo.PORTRAIT], PORTRAITS.size()-1)
			else:
				Main.ci.player_info[CI.DriverInfo.PORTRAIT] = Main.inc_int_around(Main.ci.player_info[CI.DriverInfo.PORTRAIT], PORTRAITS.size()-1, -1)
			mm_creation.buttons.get_child(c).refresh()
		CreationOption.Type.HUE:
			if forward :
				if Main.ci.player_info[CI.DriverInfo.HUE] < 1.0:
					Main.ci.player_info[CI.DriverInfo.HUE] = Main.inc_float_around(Main.ci.player_info[CI.DriverInfo.HUE], 1.0, 0.01)
			else:
				if Main.ci.player_info[CI.DriverInfo.HUE] > 0.0:
					Main.ci.player_info[CI.DriverInfo.HUE] = Main.inc_float_around(Main.ci.player_info[CI.DriverInfo.HUE], 1.0, -0.01)
			mm_creation.buttons.get_child(c).refresh()
			#print(Main.ci.player_info[CI.DriverInfo.HUE])
		CreationOption.Type.BACK:
			go_creation(true)
		CreationOption.Type.START:
			if is_valid_name(Main.ci.player_info[Main.ci.DriverInfo.NAME]):
				if CI.CHARACTERS.has(Main.ci.player_info[Main.ci.DriverInfo.NAME]):
					new_info_sign("Name Taken")
					mm_creation.buttons.get_child(1).get_node("LineEdit").text = ""
					mm_creation.set_focus(1)
				else:
					input_enabled = false
					Main.create_campaign_info(Main.ci.player_info[CI.DriverInfo.PORTRAIT], Main.ci.player_info[CI.DriverInfo.NAME], Main.ci.player_info[CI.DriverInfo.HUE])
					for b in Main.ci.bot_infos:
						if Main.ci.bot_infos[b][CI.DriverInfo.PORTRAIT] == Main.ci.player_info[CI.DriverInfo.PORTRAIT]:
							Main.ci.campaign_stats[2] = Main.ci.bot_infos[b][CI.DriverInfo.NAME]
					if Main.ci.player_info[CI.DriverInfo.PORTRAIT] == Main.ci.campaign_stats[3]:
						Main.ci.campaign_stats[3] = 0
						refresh_dialog_portrait()
					set_new_screen(MenuScreenType.RACE_PICK)
					mm_making_new_save = false
			else:
				new_info_sign("Please Enter Name")
				mm_creation.buttons.get_child(1).get_node("LineEdit").text = ""
				mm_creation.set_focus(1)

func is_valid_name(plr_name:String) -> bool:
	return plr_name != "" && plr_name != ". . ."

func refresh_creation() -> void:
	color_creation_car()
	for c in mm_creation.buttons.get_children():
		c.refresh()

func color_creation_car() -> void:
	mm_creation_car_color = Color.from_hsv(Main.ci.player_info[CI.DriverInfo.HUE], mm_creation_car_color.s, mm_creation_car_color.v, mm_creation_car_color.a)
	$Viewports/Viewport/MainMenu/CreationScene/Companion.get_surface_material(2).albedo_color = mm_creation_car_color
	$Viewports/Viewport/MainMenu/CreationScene/Companion.get_surface_material(6).albedo_color = mm_creation_car_color

# SAVES

func is_save_slot_empty(i:int) -> bool: # singleton/static candidate
	return !Main.file_exists(Main.get_save_slot_path(i))

func go_saves(go_back:bool=false) -> void:
	if mm_set_to_save && !mm_making_new_save:
		Main.save_to_slot(Main.current_save_slot)
		return # ie. choosing save slot during campaign not allowed
	
	mm_menu.visible = go_back
	mm_saves.visible = !go_back
	# Label
	if mm_saves.visible:
		var s:String = ""
		if mm_set_to_save:
			if mm_making_new_save:
				s = "Create New Save:"
			else:
				s = "Save Game:"
		else:
			s = "Load Game:"
		mm_saves.get_node("Label").text = s
	else:
		mm_saves.set_focus(-1)
	# Slots
	for i in mm_saves.buttons.get_child_count():
		if mm_saves.buttons.get_child(i).is_in_group("saveslots"):
			if !is_save_slot_empty(i):
				mm_saves.buttons.get_child(i).current_text = " SAVE "+String(i+1)
			else:
				mm_saves.buttons.get_child(i).current_text = " Empty"
			mm_saves.buttons.get_child(i).refresh()

func engage_saves(f:int) -> void:
	if f == mm_saves.esc_index:
		go_saves(true)
	else:
		if mm_set_to_save:
			if mm_making_new_save:
				Main.new_game_slot = f
				mm_saves.set_focus(-1)
				go_creation()
			else:
				Main.save_to_slot(f)
				go_saves(true)
		else:
			if Main.load_from_slot(f):
				refresh_save_buttons()
				garage_ui.respawn_car()
				mm_menu.set_focus(MenuButtonType.CONTINUE)
				go_saves(true)

# DIALOG (QUEST BASE)

class DialogInfo:
	var txt:String = ""
	var show_buttons:bool = false

func new_dialog(txt:String, show_buttons:bool=false) -> void:
	if mm_dialog.visible:
		var di:DialogInfo = DialogInfo.new()
		di.txt = txt
		di.show_buttons = show_buttons
		dialog_queue.append(di)
	else:
		show_dialog(txt, show_buttons)

func show_next_dialog() -> void:
	show_dialog(dialog_queue[0].txt, dialog_queue[0].show_buttons)
	dialog_queue.remove(0)

func show_dialog(txt:String, show_buttons:bool=false) -> void:
	mm_dialog.visible = true
	mm_dialog.get_node("Info/Txt").text = txt
	mm_dialog.buttons.visible = show_buttons
	for b in mm_dialog.buttons.get_children():
		b.disabled = !show_buttons

func new_quest(type:int, params:Array) -> void:
	match type:
		CI.QuestType.KILL:
			if params.size() == 1:
				pending_kill_target = params[0]
				new_dialog(
					"Hey, friend.\nHow about some extra buck?\nJust make sure "+String(pending_kill_target)+" never finishes the race...",
					true
				)

func engage_dialog(f:int, forward:bool=false) -> void: # when buttons used
	mm_dialog.visible = false
	if f == 0:
		if pending_kill_target != "":
			Main.current_kill_target = pending_kill_target
	else:
		pending_kill_target = ""		
	if screen_focus == MenuScreenType.RACE_PICK:
		race_pick_ui.enter_race()

func refresh_dialog_portrait() -> void:
	$Viewports/GUI/Bordered/Dialog/Info/Pic.texture = PORTRAITS[Main.ci.campaign_stats[3]]
