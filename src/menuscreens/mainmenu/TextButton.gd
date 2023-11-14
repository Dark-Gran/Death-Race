extends FocusButton # Must be used on a Label Node
class_name TextButton

export(String) var current_text = ""
export(String) var focus_symbol = "."
export(bool) var hide_text_on_focus = false

func _enter_tree() -> void:
	self.text = current_text

func refresh() -> void:
	if focused:
		if hide_text_on_focus:
			self.text = focus_symbol
		else:
			self.text = current_text+focus_symbol
		self.modulate = Color.red
	else:
		self.text = current_text
		self.modulate = Color.white
