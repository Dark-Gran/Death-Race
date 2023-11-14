extends TextButton # Must be used on a Label Node
class_name GFXOption
# "setup option" aka settings

enum OptionType {OVERALL, MSAA, SSAO, SHADOW_FILTER, GLOW, GRASS, LOW_END, APPLY, EXIT, MAX}

export(OptionType) var option_type = OptionType.OVERALL

func _enter_tree():
	refresh_with_params(get_parent().get_parent().gfx_settings)

func refresh_with_params(settings:Array) -> void:
	match option_type:
		OptionType.OVERALL:
			current_text = "Overall: "
			match settings[option_type]:
				0:
					current_text += "VERY LOW"
				1:
					current_text += "LOW"
				2:
					current_text += "MEDIUM (Recommended)"
				3:
					current_text += "HIGH"
				4:
					current_text += "VERY HIGH"
				_:
					current_text += "CUSTOM"
		OptionType.MSAA:
			current_text = "MSAA: "
			match settings[option_type]:
				0:
					current_text += "Disabled"
				1:
					current_text += "x2"
				2:
					current_text += "x4"
				3:
					current_text += "x8"
		OptionType.SSAO:
			current_text = "SSAO: "
			if settings[option_type]:
				current_text += "On"
			else:
				current_text += "Off"
		OptionType.SHADOW_FILTER:
			current_text = "Shadows: "
			match settings[option_type]:
				0:
					current_text += "Very Low"
				1:
					current_text += "Low"
				2:
					current_text += "Medium"
				3:
					current_text += "High"
		OptionType.GLOW:
			current_text = "Glow: "
			if settings[option_type]:
				current_text += "On"
			else:
				current_text += "Off"
		OptionType.GRASS:
			current_text = "Grass: "
			match settings[option_type]:
				0:
					current_text += "Disabled"
				1:
					current_text += "Low"
				2:
					current_text += "High"
		OptionType.LOW_END:
			current_text = "Low-End Disable:"
			match settings[option_type]:
				0:
					current_text += " None"
				1:
					current_text += "\nCar Reflector Shadows"
				2:
					current_text += "\nCar Lights and Shells"
				3:
					current_text += "\nCar Lights, Shells, and Dynamic Shadows"
	refresh()
