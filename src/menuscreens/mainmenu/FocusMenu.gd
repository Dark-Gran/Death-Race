extends Control
class_name FocusMenu

export(String) var menu_name = "MainMenu"
export(String) var screen_name = "Race"
export(Array) var engage_with_arrows = []
export(bool) var focus_sides = false
export(int) var esc_index = -1 # _focus_, not a child's index
export(bool) var engage_on_esc = true # false: only navigates focus; true: engages if already focused on
export(bool) var signal_focus_change = false

onready var buttons:Control = get_node("Buttons")

var focus:int = -1

func set_focus(f:int) -> void:
	if signal_focus_change:
		if screen_name != null && get_tree().get_root().has_node(screen_name) && get_tree().get_root().get_node(screen_name).has_method("changed_focus"):
			get_tree().get_root().get_node(screen_name).changed_focus(menu_name, f)
	if focus >= 0 && focus <= buttons.get_child_count()-1:
		buttons.get_child(focus).set_focus(false)
	if f >= 0 && f <= buttons.get_child_count()-1:
		buttons.get_child(f).set_focus(true)
	focus = f

func get_new_focus(f:int, max_f:int, down:bool=true) -> int:
	var new_f
	var step:int = 1
	if down:
		if f < 0 || f > max_f:
			f = 0
		else:
			f = Main.inc_int_around(f, max_f)
	else:
		step = -1
		if f < 0 || f > max_f:
			f = max_f
		else:
			f = Main.inc_int_around(f, max_f, step)
	if buttons.get_child(f) is FocusButton && !buttons.get_child(f).disabled:
		return f
	else:
		new_f = Main.inc_int_around(f, max_f, step)
		while buttons.get_child(new_f).disabled && new_f != f:
			new_f = Main.inc_int_around(new_f, max_f, step)
		return new_f

func menu_input(event:InputEvent) -> void:
	if event.is_action("ui_up") || event.is_action("ui_down"): # up & down
		set_focus(get_new_focus(focus, buttons.get_child_count()-1, event.is_action("ui_down")))
	elif event.is_action("ui_select") && !Input.is_action_pressed("mine"): # enter
		if focus < 0:
			var i:int = 0
			while !buttons.get_child(i) is FocusButton || buttons.get_child(i).disabled:
				i += 1
			set_focus(i)
		else:
			engage(focus)
	elif event.is_action("ui_left") || event.is_action("ui_right"): # left & right
		if engage_with_arrows.has(focus):
			engage(focus, event.is_action("ui_right"))
		elif focus_sides:
			set_focus(get_new_focus(focus, buttons.get_child_count()-1, event.is_action("ui_right")))
	elif event.is_action("ui_cancel"): # esc
		if focus == esc_index && esc_index >= 0:
			if engage_on_esc:
				engage(focus)
			else:
				set_focus(-1)
		else:
			set_focus(esc_index)

func menu_input_with_params(event:InputEvent, params:Array) -> void: # Unused atm (GFXMenu that works with params does not need the injection because it holds them)
	menu_input(event)
	if focus >= 0 && focus < buttons.get_child_count() && buttons.get_child(focus).has_method("refresh_with_params"):
		buttons.get_child(focus).refresh_with_params(params)

func engage(f:int, forward:bool=true) -> void:
	if screen_name != null && get_tree().get_root().has_node(screen_name):
		get_tree().get_root().get_node(screen_name).engage(menu_name, f, forward)
