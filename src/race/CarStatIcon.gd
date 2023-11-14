extends TextureRect
class_name CarStatIcon

const BASE_ALPHA:float = 0.5

enum IconColor {WHITE, GREEN, ORANGE, RED, INVISIBLE, MAX}
export(IconColor) var color = IconColor.WHITE

export(bool) var rare = false

func _enter_tree() -> void:
	if rare:
		color = IconColor.INVISIBLE
	colorize(color)

func set_color(icon_color:int) -> void:
	if icon_color < IconColor.MAX:
		color = icon_color
		colorize(color)

func colorize(icon_color:int) -> void:
	match icon_color:
		IconColor.WHITE:
			modulate = Color(1.0, 1.0, 1.0, BASE_ALPHA)
		IconColor.GREEN:
			modulate = Color.darkgreen
		IconColor.ORANGE:
			modulate = Color.darkorange
		IconColor.RED:
			modulate = Color.red
		IconColor.INVISIBLE:
			modulate.a = 0.0
