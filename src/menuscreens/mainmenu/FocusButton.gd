extends Node
class_name FocusButton

export(bool) var disabled = false

var focused:bool = false

func refresh() -> void:
	pass

func set_focus(f:bool) -> void:
	focused = f
	refresh()
