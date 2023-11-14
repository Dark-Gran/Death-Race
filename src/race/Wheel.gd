extends Spatial
class_name Wheel # Primarily to make TTs and capture velocity, everything driving-related resides in Car

export(bool) var drive = false
export(bool) var steer = false
export(bool) var carries_weight = false # eg. on the engine side; recommended for steering wheels

export(String) var oppX_wheel # opposing wheel on X axis (used for Curb collisions)
export(String) var ttsmoke

onready var car:Node = get_parent()
onready var track:Track = car.get_parent()

onready var last_pos:Vector3 = get_global_transform().origin
onready var linear_velocity:Vector3 = Vector3.ZERO

const MAX_LINE_POINTS:int = 100
const TILE_OUTDRAW:float = 1.0
const COLOR_BLOOD:Color = Color(0.04, 0, 0, 0.8)
enum TTType {TYRE, BLOOD, MAX}

var tt_type:int = TTType.TYRE
var hit_areas:Dictionary = {} # HitArea : bool
var tt_reset_time:float = 0.0
var tt_reset_lock:bool = false

class TT extends Reference:
	var line:Line2D = null
	var tile:int = 0

var tts:Array = [TT.new(), TT.new(), TT.new(), TT.new()]

func _physics_process(delta:float) -> void:
	linear_velocity = get_global_transform().origin-last_pos
	last_pos = get_global_transform().origin
	if tt_type != TTType.TYRE && !tt_reset_lock:
		if tt_reset_time > 0.0:
			tt_reset_time -= delta
		else:
			tt_type = TTType.TYRE

func update_tt(point) -> void: # called by Car
	if point != null:
		var tiles:Array = get_tt_tiles(point, track)
		for tile in tiles:
			var tt_ix:int = find_tt(tile)
			if tt_ix == -1:
				new_tt(tile)
		for n in tts.size():
			if tts[n].line != null:
				if tts[n].line.get_point_count() > MAX_LINE_POINTS:
					var last_point:Vector2 = tts[n].line.get_points()[tts[n].line.get_point_count()-1]
					kill_tt_line(tts[n])
					new_tt_line(n, tts[n].tile)
					tts[n].line.add_point(last_point) # possibly: get multiple previous points for maximum alpha-smoothness
				add_tt_point(point, tts[n])
	else:
		end_tt()

func find_tt(tile:int) -> int:
	for n in tts.size():
		if tts[n].line != null && tts[n].tile == tile:
			return n
	return -1

func add_tt_point(point:Vector3, tt:TT) -> void:
	tt.line.add_point(vector3_to_tt(point, tt.tile, track))

func new_tt(tile:int) -> void:
	var tt_ix:int = -1
	for n in tts.size():
		if tts[n].line == null:
			tt_ix = n
			break
	if tt_ix != -1:
		new_tt_line(tt_ix, tile)

func new_tt_line(tt_ix:int, tile:int) -> void:
	if get_tree().get_root().get_node("ViewportsTT/ViewportTT_"+String(tile)) != null:
		tts[tt_ix].line = Line2D.new()
		# line visuals
		tts[tt_ix].line.antialiased = true
		tts[tt_ix].line.width = car.tyre_width
		match tt_type:
			TTType.BLOOD:
				tts[tt_ix].line.default_color = COLOR_BLOOD
			_: # TTType.TYRE
				tts[tt_ix].line.default_color = track.tt_color
		# save line
		get_tree().get_root().get_node("ViewportsTT/ViewportTT_"+String(tile)).add_child(tts[tt_ix].line)
		tts[tt_ix].tile = tile

func end_tt() -> void:
	for tt in tts:
		if tt.line != null:
			kill_tt_line(tt)

func kill_tt_line(tt:TT) -> void:
	tt.line.free()
	tt.line = null

func set_tt_type(type:int) -> void:
	if type < TTType.MAX:
		if tt_type != type:
			end_tt()
			tt_type = type

# UTILITIES

static func get_tt_tiles(point:Vector3, tr:Track) -> Array:
	var tiles:Array = []
	var tile:int
	var x:float = point.x-TILE_OUTDRAW
	var z:float = point.z-TILE_OUTDRAW
	for c in 3:
		for r in 3:
			tile = get_tt_tile(x, z, tr)
			while tile >= tr.tt_columns * tr.tt_rows:
				tile -= 1
			if tile < 0:
				tile = 0
			if !tiles.has(tile):
				tiles.append(tile)
			x += TILE_OUTDRAW
		z += TILE_OUTDRAW
		x = point.x-TILE_OUTDRAW
	return tiles

static func get_tt_tile(x:float, z:float, tr:Track) -> int:
	return floor(x/tr.tile_size) + (floor(z/tr.tile_size) * tr.tt_columns)

static func vector3_to_tt(point:Vector3, tile:int, tr:Track) -> Vector2:
	var tile_column:int = tile
	while tile_column >= tr.tt_columns:
		tile_column -= tr.tt_columns
	return Vector2((point.x - tile_column * tr.tile_size)*tr.tile_size, (point.z - floor(tile / tr.tt_columns) * tr.tile_size)*tr.tile_size)
