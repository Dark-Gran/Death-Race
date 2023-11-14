extends FocusMenu
class_name GFXMenu

var gfx_settings:Array = Main.gfx_settings.duplicate()

func reset() -> void:
	gfx_settings = Main.gfx_settings.duplicate()
	refresh_options()

func engage(f:int, forward:bool=true) -> void:
	var step:int = 1
	if !forward:
		step = -1
	var custom_settings:bool = gfx_settings[0] >= 0 && gfx_settings[0] < Main.GFXOverall.MAX
	match f:
		GFXOption.OptionType.APPLY:
			Main.gfx_settings = gfx_settings.duplicate()
			Main.save_gfx_settings()
			if screen_name != null && get_tree().get_root().has_node(screen_name):
				get_tree().get_root().get_node(screen_name).apply_gfx_settings()
			return
		GFXOption.OptionType.EXIT:
			.engage(f, forward)
			return
		GFXOption.OptionType.OVERALL:
			gfx_settings = Main.get_next_overall(gfx_settings, step)
			refresh_options()
			return
		GFXOption.OptionType.MSAA:
			gfx_settings = Main.get_next_msaa(gfx_settings, step)
		GFXOption.OptionType.SSAO:
			gfx_settings = Main.get_next_ssao(gfx_settings)
		GFXOption.OptionType.SHADOW_FILTER:
			gfx_settings = Main.get_next_shadow_filter(gfx_settings, step)
		GFXOption.OptionType.GLOW:
			gfx_settings = Main.get_next_glow(gfx_settings)
		GFXOption.OptionType.GRASS:
			gfx_settings = Main.get_next_grass(gfx_settings, step)
		GFXOption.OptionType.LOW_END:
			gfx_settings = Main.get_next_low_disable(gfx_settings, step)
	buttons.get_child(f).refresh_with_params(gfx_settings)
	gfx_settings[0] = -1
	buttons.get_child(GFXOption.OptionType.OVERALL).refresh_with_params(gfx_settings)

func refresh_options() -> void:
	for o in buttons.get_children():
		o.refresh_with_params(gfx_settings)
