extends CanvasItem
class_name CanvasItemFade
# Modulates alpha until fade_type is completed (or skipped if skippable)

export(NodePath) var canvas_item = null # leave null for "self"; Warning: Missing CanvasItem class check
export(float) var speed_in = 0.8
export(float) var speed_out = 1.2
export(float) var delay_start = 0.1
export(float) var delay_mid = 0.7
export(float) var delay_end = 0.1
export(bool) var skippable = false # jumps to the end on skip when true
export(Array) var skip_binds = []
export(bool) var die_on_end = true # frees itself when finished
export(bool) var set_start_alpha = true # "fixes" alpha at start (turn off for fading-out objects that are already alpha-modulated)
export(bool) var set_visibility = true # affects visibility on both ends
export(bool) var precompleted = false

enum FadeType {IN, OUT, IN_AND_OUT, OUT_AND_IN, MAX}
export(FadeType) var fade_type = FadeType.IN_AND_OUT

var target:CanvasItem

var going_in:bool = true
var current_delay:float = delay_start
var delay_active:bool = delay_start > 0.0
var delay_timer:float = 0.0
var can_finish:bool = false # completed or asked for skip
var completed:bool = false # did we actually do all the fade (= w/o skip)

func _enter_tree() -> void:
	if canvas_item == null || get_node_or_null(canvas_item) == null:
		target = self
	else:
		target = get_node(canvas_item)
	if precompleted:
		can_finish = true
		completed = true

func _ready() -> void:
	if !precompleted:
		ini()

func ini() -> void:
	match fade_type:
		FadeType.IN:
			going_in = true
			if set_visibility:
				target.visible = true
			if set_start_alpha:
				target.modulate.a = 0.0
		FadeType.OUT:
			going_in = false
			target.visible = true
			if set_start_alpha:
				target.modulate.a = 1.0
		FadeType.IN_AND_OUT:
			going_in = true
			if set_visibility:
				target.visible = true
			if set_start_alpha:
				target.modulate.a = 0.0
		FadeType.OUT_AND_IN:
			going_in = false
			if set_visibility:
				target.visible = true
			if set_start_alpha:
				target.modulate.a = 1.0

func restart() -> void:
	current_delay = delay_start
	delay_active = delay_start > 0.0
	delay_timer = 0.0
	can_finish = false
	completed = false
	#set_start_alpha = true
	ini()

func fade(delta:float) -> void: # call from _physics_process()
	if visible && !completed:
		var skip:bool = false
		for sb in skip_binds:
			if Input.is_action_pressed(sb):
				skip = true
				break
		if skip && !can_finish:
			skip()
		if delay_active:
			delay_timer += delta
			if delay_timer >= current_delay:
				delay_active = false
				delay_timer = 0
		else:
			if !completed:
				if going_in:
					target.modulate.a += speed_in*delta
					if target.modulate.a >= 1:
						going_in = false
						match fade_type:
							FadeType.IN:
								complete()
							FadeType.IN_AND_OUT:
								mid_delay()
							FadeType.OUT_AND_IN:
								complete()
				else:
					target.modulate.a -= speed_out*delta
					if target.modulate.a <= 0:
						going_in = true
						match fade_type:
							FadeType.OUT:
								complete()
							FadeType.IN_AND_OUT:
								complete()
							FadeType.OUT_AND_IN:
								mid_delay()
			elif die_on_end:
				kill()

func mid_delay() -> void:
	if delay_mid > 0.0:
		delay_active = true
		current_delay = delay_mid

func complete() -> void:
	match fade_type:
		FadeType.IN:
			target.modulate.a = 1.0
		FadeType.OUT:
			if set_visibility:
				target.visible = false
			target.modulate.a = 0.0
		FadeType.IN_AND_OUT:
			if set_visibility:
				target.visible = false
			target.modulate.a = 0.0
		FadeType.OUT_AND_IN:
			target.modulate.a = 1.0
	completed = true
	set_can_finish(true)
	delay_active = true # ie. always at least 1 frame delay to ensure updates
	current_delay = delay_end

func skip() -> void:
	set_can_finish(true)
	if skippable:
		complete()

func set_can_finish(f:bool) -> void:
	can_finish = f

func kill() -> void:
	queue_free()
