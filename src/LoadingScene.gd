extends Node
class_name LoadingScene # Serves as the Main Scene (first to load, persists along others)
# Handles scene switches, loading-animation and general input (eg. fullscreen toggle)

const VIEWPORTS_TT:Resource = preload("res://src/race/ViewportsTT.tscn")

var current_scene:Node = null
var scene_load:String = ""
var bonus_loads:Array = []

var load_count:int = 0
var loaded_bonus_count:int = 0
 
func _ready() -> void:
	queue_new_scene("res://src/menuscreens/MenuScreens.tscn")
	add_bonus_load("res://src/race/Race.tscn")
	load_count = 2
	#if !Main.file_exists(Main.get_save_slot_path(0)): # Preloading track means the RacePick will disappear so fast that the player won't see bot names when skipping after player-signup
	#	add_bonus_load(Race.get_track_path(1), true)
	#	load_count += 1
	get_tree().get_root().call_deferred("add_child", VIEWPORTS_TT.instance())

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen

func queue_new_scene(path:String, p_to_front:bool=true) -> void:
	scene_load = path
	Main.loader.queue_resource(scene_load, p_to_front)

func add_bonus_load(path:String, p_to_front:bool=false) -> void:
	bonus_loads.append(path)
	Main.loader.queue_resource(path, p_to_front)

func go_to_scene(path:String) -> void:
	scene_load = path
	if Main.loader.is_ready(scene_load):
		set_new_scene(Main.loader.get_resource(path))
	else:
		Main.loader.queue_resource(path, true)

func _process(delta:float) -> void:
	if has_node("Logo"):
		$Logo.fade(delta)
	$Curtain.fade(delta)
	var marked:PoolStringArray = []
	var progress:float = loaded_bonus_count
	for b in bonus_loads:
		if Main.loader.is_ready(b):
			marked.append(b)
			progress += 1
			loaded_bonus_count += 1
		else:
			progress += Main.loader.get_progress(b)
	for m in marked:
		bonus_loads.erase(m)
	if scene_load != "":
		if Main.loader.is_ready(scene_load):
			progress += 1
			if bonus_loads.size() == 0:
				if !has_node("Logo") || $Logo.can_finish:
					set_new_scene(Main.loader.get_resource(scene_load))
					if has_node("Logo"):
						$Logo.kill()
				else:
					toggle_loading_signs(false, false)
				load_count = 0
		else:
			progress += Main.loader.get_progress(scene_load)
	if scene_load != "" || bonus_loads.size() != 0:
		if has_node("LoadingAnimation") && get_node("LoadingAnimation").visible:
			if load_count > 0:
				progress = progress / load_count
			else:
				progress = 1.0
			set_loading_progress(progress)

func set_new_scene(scene_resource:Resource) -> void:
	toggle_loading_signs(true, true, false, true)
	scene_load = ""
	if current_scene != null:
		current_scene.free()
	current_scene = scene_resource.instance()
	get_tree().get_root().add_child(current_scene)
	get_tree().get_root().move_child(current_scene, 0)
	get_tree().set_current_scene(current_scene)

func toggle_loading_signs(enable:bool, curtain:bool=true, reset:bool=false, no_fade:bool=false) -> void:
	if has_node("LoadingAnimation") && $LoadingAnimation.visible != enable:
		$LoadingAnimation.visible = enable 
		if reset:
			$LoadingAnimation.reset()
	if curtain && has_node("Curtain"):
		if enable:
			if no_fade:
				$Curtain.visible = true
				$Curtain.modulate.a = 1.0
			else:
				$Curtain.fade_type = CanvasItemFade.FadeType.IN
		else:
			if no_fade:
				$Curtain.visible = false
				$Curtain.modulate.a = 0.0
			else:
				$Curtain.fade_type = CanvasItemFade.FadeType.OUT
		if !no_fade:
			$Curtain.restart()

func set_loading_progress(progress:float) -> void:
	if has_node("LoadingAnimation"):
		$LoadingAnimation/Fill.value = progress
