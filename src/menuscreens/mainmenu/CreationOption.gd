extends FocusButton
class_name CreationOption

enum Type {PORTRAIT, NAME, HUE, START, BACK, MAX}

export(Type) var type = Type.PORTRAIT
export(NodePath) var focus_path = null

onready var screen:Node = get_tree().get_root().get_node("MenuScreens")

var start_x_0:float = 0.0
var start_x_1:float = 0.0

var custom_float:float = -1 # used differently per type

func _enter_tree() -> void:
	match type:
		Type.HUE:
			start_x_0 = get_node("Marker").rect_position.x
			start_x_1 = get_node("Back").rect_size.x - (start_x_0*0.5)

func refresh() -> void:
	match type:
		Type.PORTRAIT:
			get_node("Pic").texture = screen.PORTRAITS[Main.ci.player_info[Main.ci.DriverInfo.PORTRAIT]]
		Type.NAME:
			get_node("LineEdit").text = Main.ci.player_info[Main.ci.DriverInfo.NAME]
		Type.HUE:
			if custom_float == -1:
				get_node("Marker").rect_position.x = start_x_0 + start_x_1*Main.ci.player_info[Main.ci.DriverInfo.HUE]
				get_node("Marker").color = Color.from_hsv(Main.shift_hue_to_target(Main.ci.player_info[Main.ci.DriverInfo.HUE]), get_node("Marker").color.s, get_node("Marker").color.v, get_node("Marker").color.a)
			else:
				get_node("Marker").rect_position.x = start_x_0 + start_x_1*custom_float
				get_node("Marker").color = Color.from_hsv(custom_float, get_node("Marker").color.s, get_node("Marker").color.v, get_node("Marker").color.a)
			get_tree().get_root().get_node("MenuScreens").color_creation_car()

func set_focus(f:bool) -> void:
	focused = f
	match type:
		Type.START:
			if f:
				self.text = "Start."
			else:
				self.text = "Start"
			return
		Type.BACK:
			if f:
				self.text = "Back."
			else:
				self.text = "Back"
			return
		Type.NAME:
			if f:
				if get_node("LineEdit").text == ". . .":
					get_node("LineEdit").clear()
					Main.ci.player_info[Main.ci.DriverInfo.NAME] = ""
				get_node("LineEdit").grab_focus()
			else:
				get_node("LineEdit").release_focus()
	if focus_path != null && has_node(focus_path):
		get_node(focus_path).visible = f

func _on_text_changed(new_text:String): # signal from LineEdit (if present, obviously); used by Type.NAME
	Main.ci.player_info[Main.ci.DriverInfo.NAME] = new_text
