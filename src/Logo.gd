extends CanvasItemFade
class_name Logo
# Controlled from LoadingScene

func skip() -> void: # override
	if Main.loading_scene.bonus_loads.size() == 0:
		visible = false
		call_deferred("set_can_finish", true)
	else:
		set_can_finish(true)
