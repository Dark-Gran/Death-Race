extends FocusButton
class_name RaceOption

var map_index:int = -1

func refresh() -> void:
	$Tier/Focus.visible = focused
