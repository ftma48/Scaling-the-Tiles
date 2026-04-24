extends Area2D

# base data about the tile
var data: TileInfo
var tile_size = Vector2(100,100)
var side_colours = {
	"north" = [],
	"east" = [],
	"south" = [],
	"west" = []
}

# state machine used to control the drag + resize of tile
enum State { IDLE, DRAGGING, RESIZING }
var state = State.IDLE

var highlighted_pairs: Array = []  # array of [my_segment, other_segment] currently glowing

# resizing
var drag_offset = Vector2.ZERO
var handle_drag_offset := Vector2.ZERO
var handle_active = null

# selection
var is_selected = false
var tile_hover = false

# connecting
var connect = null
var connectedTile = null
var group = null
var absolute_tolerance = 5.0 
var relative_tolerance = 0.10
var snap_threshold = 60.0 # max distance between segment midpoints to allow snapping

@onready var TileGroupScene = preload("res://scenes/tile_group.tscn")
@onready var puzzleManager = get_node("/root/Main/PuzzleManager")
@onready var sprite2d: Sprite2D = $Sprite2D
@onready var collishape: CollisionShape2D = $CollisionShape2D
@onready var button: Button = $Button
@onready var connectSound: AudioStreamPlayer = null
@onready var disconnectSound: AudioStreamPlayer = null

func _ready():
	disconnectSound = get_tree().get_first_node_in_group("disconnect_sfx")
	connectSound = get_tree().get_first_node_in_group("connect_sfx")
	button.mouse_default_cursor_shape = Control.CURSOR_MOVE

func init_tile(
	myData: TileInfo,
	pos: Vector2,
	_tile_size: Vector2,
	side_clrs: Dictionary
):
	# initialise tile from data passed in 
	data = myData
	tile_size = _tile_size
	position = pos
	var rect := RectangleShape2D.new()
	rect.size = tile_size
	collishape.shape = rect
	update_button_size()
	button.z_index = 15
	side_colours = side_clrs
	draw_triangles(side_colours, tile_size)
	create_resize_handles()

func _process(_delta: float) -> void:
	# dragging
	match state:
		State.DRAGGING:
			if get_parent().is_in_group("tile_group"):
				get_parent().global_position = get_global_mouse_position() - drag_offset
			else:
				position = get_parent().to_local(get_global_mouse_position()) - drag_offset
			_update_highlights()
		State.RESIZING:
			if handle_active != null:
				_resize_tile_from_mouse(handle_active)
	
	_clamp_to_screen()


# dragging functions


func _on_button_button_down() -> void:
	# when player presses on the tile, change cursors shape, set state to dragging, set drag offset
	# if shift pressed, remove tile from group
	if Input.is_key_pressed(KEY_SHIFT):
		if get_parent().is_in_group("tile_group"):
			var grp = get_parent()
			if grp.has_method("remove_tile"):
				grp.remove_tile(self)
			disconnectSound.play()
			global_position += (tile_size * 0.1)
		return
	
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)
	state = State.DRAGGING
	if get_parent().is_in_group("tile_group"):
		drag_offset = get_global_mouse_position() - get_parent().global_position
	else:
		drag_offset = get_global_mouse_position() - global_position

func _on_button_button_up() -> void:
	# when player drops tile, set state to idle, and apply snap if one found
	state = State.IDLE
	set_cursor()
	_clear_all_highlights()
	
	var snap = _find_best_snap()
	if snap == null:
		return
	
	# check if bounding rect doesn't overlap other tiles in target group
	if not _is_position_valid(snap["target_position"], snap["other_tile"]):
		return
	
	_apply_snap_position(snap["target_position"])
	
	if snap["other_tile"] != null:
		_handle_tile_connection(snap["other_tile"])
		if puzzleManager.check_win_condition():
			print("PUZZLE SOLVED")
	else:
		connectSound.play()
	
	if snap["resize_needed"]:
		_snap_resize(snap["resize_length"], snap["resize_dir"])


# snapping functions


func _find_best_snap():
	# checks all tiles for tiles or board with overlapping segments that match with own segments
	if not has_node("Triangles"):
		return null
		
	var best = null
	var best_dist = INF
	
	var my_segments = _get_my_segments()
	
	for tile in puzzleManager.tiles:
		if tile == self:
			continue
		if not tile.has_node("Triangles"):
			continue
		# skip tiles in same group as self
		if get_parent().is_in_group("tile_group") and tile.get_parent() == get_parent():
			continue
		
		for other_seg in _get_tile_segments(tile):
			for my_seg in my_segments:
				if not _segments_match(my_seg, other_seg):
					continue
				
				var dist = my_seg.global_position.distance_to(other_seg.global_position)
				if dist < snap_threshold and dist < best_dist:
					best_dist = dist
					var seg_len = other_seg.get_meta("seg_length")
					var my_len = my_seg.get_meta("seg_length")
					var exact = seg_len == my_len
					var close = not exact and is_approximately_equal(seg_len, my_len)
					best = {
						"target_position": _calc_tile_snap_target(my_seg, other_seg),
						"other_tile": tile,
						"resize_needed": close,
						"resize_length": seg_len,
						"resize_dir": other_seg.get_meta("direction")
					}
	
	if best == null:
		var board_segs = _get_board_segments()
		for board_seg in board_segs:
			for my_seg in my_segments:
				if not _segments_match_board(my_seg, board_seg):
					continue
				
				var dist = my_seg.global_position.distance_to(board_seg.global_position)
				if dist < snap_threshold and dist < best_dist:
					best_dist = dist
					var board_snap = _calc_board_snap_target(my_seg, board_seg)
					if board_snap != null:
						best = board_snap
	
	return best

func _segments_match(my_seg: Area2D, other_seg: Area2D) -> bool:
	# given two tile segments, do they have the same colour and similar length and on opposite sides (e.g n/s or e/w)
	if not other_seg.has_meta("direction"):
		return false
	if other_seg.get_meta("colour") != my_seg.get_meta("colour"):
		return false
	if not _are_opposite(my_seg.get_meta("direction"), other_seg.get_meta("direction")):
		return false
	if not is_approximately_equal(my_seg.get_meta("seg_length"), other_seg.get_meta("seg_length")):
		return false
	return true

func _segments_match_board(my_seg: Area2D, board_seg: Area2D) -> bool:
	# given a board and tile segment, do they have the same colour and similar length and in same direction
	if not board_seg.has_meta("colour"):
		return false
	if board_seg.get_meta("colour") != my_seg.get_meta("colour"):
		return false
	# tile's north edge matches board's north edge, etc (same direction)
	if not board_seg.has_meta("direction"):
		return false
	if board_seg.get_meta("direction") != my_seg.get_meta("direction"):
		return false
	if not is_approximately_equal(my_seg.get_meta("seg_length"), board_seg.get_meta("seg_length")):
		return false
	return true

func _calc_tile_snap_target(my_seg: Area2D, other_seg: Area2D) -> Vector2:
	# move this tile so my_seg midpoint aligns with other_seg midpoint
	# then push flush so edges touch without overlapping
	var other_mid = other_seg.global_position
	var my_mid = my_seg.global_position
	var dir = other_seg.get_meta("direction")
	
	var target = global_position + (other_mid - my_mid)
	
	match dir:
		"north": target.y += 10.0  
		"south": target.y -= 10.0
		"east":  target.x -= 10.0
		"west":  target.x += 10.0
	
	return target

func _calc_board_snap_target(my_seg: Area2D, board_seg: Area2D):
	# move this tile so my_seg midpoint aligns with other_seg midpoint
	# then push flush so edges touch without overlapping
	var board = board_seg.get_meta("parent_board")
	var dir = board_seg.get_meta("direction")
	var board_half = board.board_size / 2
	var tile_half = tile_size / 2

	var board_mid = board_seg.global_position
	var my_mid = my_seg.global_position
	var target = global_position + (board_mid - my_mid)

	match dir:
		"north":
			target.y = board.global_position.y - board_half.y + tile_half.y
		"south":
			target.y = board.global_position.y + board_half.y - tile_half.y
		"west":
			target.x = board.global_position.x - board_half.x + tile_half.x
		"east":
			target.x = board.global_position.x + board_half.x - tile_half.x
			
	var seg_len = board_seg.get_meta("seg_length")
	var my_len = my_seg.get_meta("seg_length")
	
	return {
		"target_position": target,
		"other_tile": null,
		"resize_needed": is_approximately_equal(seg_len, my_len) and seg_len != my_len,
		"resize_length": seg_len,
		"resize_dir": dir
	}

func _is_position_valid(target_global: Vector2, snap_target_tile) -> bool:
	var half = tile_size / 2
	var snapped_rect = Rect2(target_global - half, tile_size)
	var margin = 4.0
	
	for tile in puzzleManager.tiles:
		if tile == self:
			continue
		if tile == snap_target_tile:
			continue
		
		var other_half = tile.tile_size / 2
		var other_rect = Rect2(tile.global_position - other_half, tile.tile_size)
		var shrunk = other_rect.grow(-margin)
		
		if snapped_rect.intersects(shrunk):
			return false
		
		# check colour conflicts with any tile that would be adjacent
		if not _colours_compatible_with(tile, target_global):
			return false
	
	return true

func _colours_compatible_with(other_tile, my_target_global: Vector2) -> bool:
	var my_segments = _get_my_segments()
	var other_segments = _get_tile_segments(other_tile)
	var proximity = 40.0
	
	for my_seg in my_segments:
		var my_global_pos = my_target_global + (my_seg.global_position - global_position)
		for other_seg in other_segments:
			if not _are_opposite(my_seg.get_meta("direction"), other_seg.get_meta("direction")):
				continue
			if my_global_pos.distance_to(other_seg.global_position) > proximity:
				continue
			# segments are touching and opposite — both colour AND length must match
			if my_seg.get_meta("colour") != other_seg.get_meta("colour"):
				return false
			if not is_approximately_equal(my_seg.get_meta("seg_length"), other_seg.get_meta("seg_length")):
				return false
	
	return true

# highlighting 

func _update_highlights():
	var my_segments = _get_my_segments()
	var new_pairs: Array = []

	# check tiles
	for tile in puzzleManager.tiles:
		if tile == self:
			continue
		if not tile.has_node("Triangles"):
			continue
		if get_parent().is_in_group("tile_group") and tile.get_parent() == get_parent():
			continue
		for other_seg in _get_tile_segments(tile):
			for my_seg in my_segments:
				if _segments_match(my_seg, other_seg):
					var dist = my_seg.global_position.distance_to(other_seg.global_position)
					if dist < snap_threshold:
						new_pairs.append([my_seg, other_seg])

	# check board
	for board_seg in _get_board_segments():
		for my_seg in my_segments:
			if _segments_match_board(my_seg, board_seg):
				var dist = my_seg.global_position.distance_to(board_seg.global_position)
				if dist < snap_threshold:
					new_pairs.append([my_seg, board_seg])

	# clear old highlights not in new set
	for pair in highlighted_pairs:
		var still_valid = false
		for new_pair in new_pairs:
			if new_pair[0] == pair[0] and new_pair[1] == pair[1]:
				still_valid = true
				break
		if not still_valid:
			_set_segment_glow(pair[0], false)
			_set_segment_glow(pair[1], false)

	# apply new highlights
	for pair in new_pairs:
		_set_segment_glow(pair[0], true)
		_set_segment_glow(pair[1], true)

	highlighted_pairs = new_pairs

func _clear_all_highlights():
	for pair in highlighted_pairs:
		_set_segment_glow(pair[0], false)
		_set_segment_glow(pair[1], false)
	highlighted_pairs.clear()

func _set_segment_glow(seg, glow: bool):
	if not is_instance_valid(seg):
		return
	var parent = seg.get_parent()
	if parent and parent.has_node("Outline"):
		var line: Line2D = parent.get_node("Outline")
		if glow:
			line.default_color = Color.AQUA
			line.width = 4.0
		else:
			line.default_color = Color.WHITE
			line.width = 2.0

# =====================================================================
# SEGMENT HELPERS
# =====================================================================

func _get_my_segments() -> Array:
	var result = []
	if not has_node("Triangles"):
		return result
	for seg_group in get_node("Triangles").get_children():
		for child in seg_group.get_children():
			if child is Area2D:
				result.append(child)
	return result

func _get_tile_segments(tile) -> Array:
	var result = []
	if not tile.has_node("Triangles"):
		return result
	for seg_group in tile.get_node("Triangles").get_children():
		for child in seg_group.get_children():
			if child is Area2D:
				result.append(child)
	return result

func _get_board_segments() -> Array:
	var result = []
	var board = get_tree().get_first_node_in_group("puzzle_board")
	if board == null or board.edge_segments_container == null:
		return result
	for seg in board.edge_segments_container.get_children():
		if seg is Area2D:
			result.append(seg)
	return result

# =====================================================================
# SNAP APPLICATION
# =====================================================================

func _apply_snap_position(target_global: Vector2):
	if get_parent().is_in_group("tile_group"):
		var grp = get_parent()
		var offset = global_position - grp.global_position
		grp.global_position = target_global - offset
	else:
		global_position = target_global

func _handle_tile_connection(other_tile):
	var old_global = global_transform

	if other_tile.get_parent().is_in_group("tile_group") \
	and not self.get_parent().is_in_group("tile_group"):
		var targroup = other_tile.get_parent()
		targroup.add_tile(self)
		global_transform = old_global

	elif self.get_parent().is_in_group("tile_group") \
	and not other_tile.get_parent().is_in_group("tile_group"):
		var targroup = get_parent()
		targroup.add_tile(other_tile)
		global_transform = old_global

	elif self.get_parent().is_in_group("tile_group") \
	and other_tile.get_parent().is_in_group("tile_group"):
		merge_with_group(other_tile.get_parent(), self.get_parent())

	else:
		var targroup = TileGroupScene.instantiate()
		targroup.add_to_group("tile_group")
		var parent = other_tile.get_parent()
		parent.add_child(targroup)
		targroup.global_position = other_tile.global_position
		targroup.add_tile(other_tile)
		targroup.add_tile(self)

	connectSound.play()

func merge_with_group(source_group: Node2D, target_group: Node2D):
	var tiles_to_move = source_group.get_tiles().duplicate()
	for tile in tiles_to_move:
		source_group.remove_tile(tile)
		target_group.add_tile(tile)

func _snap_resize(other_segment_length, dir):
	match dir:
		"north": dir = "south"
		"south": dir = "north"
		"east":  dir = "west"
		"west":  dir = "east"

	var my_count = side_colours[dir].size()
	var new_size = tile_size

	match dir:
		"north", "south":
			new_size.x = other_segment_length * my_count
		"east", "west":
			new_size.y = other_segment_length * my_count

	tile_size = new_size
	collishape.shape.set("size", tile_size)
	update_button_size()
	update_resize_handles()
	update_triangles()

# =====================================================================
# RESIZE HANDLES
# =====================================================================

func create_resize_handles():
	var handles = Node2D.new()
	handles.z_index = 20
	handles.name = "ResizeHandles"
	add_child(handles)

	var positions = {
		"north": Vector2(0, -tile_size.y/2),
		"south": Vector2(0, tile_size.y/2),
		"east":  Vector2(tile_size.x/2, 0),
		"west":  Vector2(-tile_size.x/2, 0),
		"ne":    Vector2(tile_size.x/2, -tile_size.y/2),
		"nw":    Vector2(-tile_size.x/2, -tile_size.y/2),
		"se":    Vector2(tile_size.x/2, tile_size.y/2),
		"sw":    Vector2(-tile_size.x/2, tile_size.y/2),
	}

	for dir in positions.keys():
		var handle = Area2D.new()
		handle.name = dir + "_handle"
		handles.add_child(handle)

		var shape = CollisionShape2D.new()
		var square = RectangleShape2D.new()
		square.size = _get_handle_size(dir)
		shape.shape = square
		handle.add_child(shape)

		handle.position = positions[dir]
		handle.set_meta("direction", dir)
		handle.connect("input_event", Callable(self, "_on_handle_input").bind(handle))
		handle.mouse_entered.connect(_on_handle_mouse_entered.bind(handle))
		handle.mouse_exited.connect(_on_handle_mouse_exited)

func _get_handle_size(dir: String) -> Vector2:
	var thickness = 20.0
	match dir:
		"north", "south": return Vector2(tile_size.x * 0.8, thickness)
		"east",  "west":  return Vector2(thickness, tile_size.y * 0.8)
		"ne", "nw", "se", "sw": return Vector2(thickness * 1.5, thickness * 1.5)
	return Vector2(thickness, thickness)

func _get_anchor_local(dir: String) -> Vector2:
	var half = tile_size / 2
	match dir:
		"east":  return Vector2(-half.x, 0)
		"west":  return Vector2( half.x, 0)
		"north": return Vector2(0,  half.y)
		"south": return Vector2(0, -half.y)
		"ne":    return Vector2(-half.x,  half.y)
		"nw":    return Vector2( half.x,  half.y)
		"se":    return Vector2(-half.x, -half.y)
		"sw":    return Vector2( half.x, -half.y)
	return Vector2.ZERO

func update_resize_handles():
	if not has_node("ResizeHandles"):
		return
	var handles = get_node("ResizeHandles")
	var positions = {
		"north": Vector2(0, -tile_size.y/2),
		"south": Vector2(0, tile_size.y/2),
		"east":  Vector2(tile_size.x/2, 0),
		"west":  Vector2(-tile_size.x/2, 0),
		"ne":    Vector2(tile_size.x/2, -tile_size.y/2),
		"nw":    Vector2(-tile_size.x/2, -tile_size.y/2),
		"se":    Vector2(tile_size.x/2, tile_size.y/2),
		"sw":    Vector2(-tile_size.x/2, tile_size.y/2),
	}
	for dir in positions.keys():
		var node_name = dir + "_handle"
		if handles.has_node(node_name):
			var h = handles.get_node(node_name)
			h.position = positions[dir]
			for child in h.get_children():
				if child is CollisionShape2D:
					child.shape.size = _get_handle_size(dir)

func _on_handle_input(viewport, event, shape_idx, handle):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.IDLE:
				state = State.RESIZING
				handle_active = handle
				var mouse_local = handle.get_parent().to_local(get_global_mouse_position())
				handle_drag_offset = mouse_local - handle.position
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			state = State.IDLE
			handle_active = null
			update_resize_handles()

func _on_handle_mouse_entered(handle):
	var dir = handle.get_meta("direction")
	match dir:
		"east",  "west":  Input.set_default_cursor_shape(Input.CURSOR_HSIZE)
		"north", "south": Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
		"ne",    "sw":    Input.set_default_cursor_shape(Input.CURSOR_BDIAGSIZE)
		"nw",    "se":    Input.set_default_cursor_shape(Input.CURSOR_FDIAGSIZE)

func _on_handle_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _resize_tile_from_mouse(handle: Area2D):
	var dir = handle.get_meta("direction")
	var anchor_local = _get_anchor_local(dir)
	var anchor_global = to_global(anchor_local)
	var mouse_local = to_local(get_global_mouse_position())
	var new_size = tile_size

	match dir:
		"east":          new_size.x = max(mouse_local.x - anchor_local.x, 50)
		"west":          new_size.x = max(anchor_local.x - mouse_local.x, 50)
		"north":         new_size.y = max(anchor_local.y - mouse_local.y, 50)
		"south":         new_size.y = max(mouse_local.y - anchor_local.y, 50)
		"ne","nw","se","sw":
			new_size.x = max(abs(mouse_local.x - anchor_local.x), 50)
			new_size.y = max(abs(mouse_local.y - anchor_local.y), 50)

	tile_size = new_size
	collishape.shape.size = tile_size
	update_button_size()

	var new_anchor_global = to_global(_get_anchor_local(dir))
	global_position += anchor_global - new_anchor_global

	update_triangles()
	update_resize_handles()

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and not event.pressed:
		if state == State.RESIZING:
			state = State.IDLE
			handle_active = null

# =====================================================================
# DRAWING
# =====================================================================

func draw_triangles(side_colours: Dictionary, tile_size: Vector2):
	var outline_colour = Color.AQUA if connect else Color.WHITE
	var triangles = Node2D.new()
	triangles.name = "Triangles"
	add_child(triangles)

	var sides = {
		"north": Vector2(0, -1),
		"east":  Vector2(1, 0),
		"south": Vector2(0, 1),
		"west":  Vector2(-1, 0)
	}
	var half = tile_size / 2
	var center = Vector2.ZERO

	for dir in sides.keys():
		var clrs = side_colours[dir]
		if clrs.size() == 0:
			continue

		var edge_length := 0.0
		var start := Vector2.ZERO
		var step := Vector2.ZERO

		match dir:
			"north":
				edge_length = tile_size.x / clrs.size()
				start = Vector2(-half.x, -half.y)
				step = Vector2(edge_length, 0)
			"south":
				edge_length = tile_size.x / clrs.size()
				start = Vector2(-half.x, half.y)
				step = Vector2(edge_length, 0)
			"east":
				edge_length = tile_size.y / clrs.size()
				start = Vector2(half.x, -half.y)
				step = Vector2(0, edge_length)
			"west":
				edge_length = tile_size.y / clrs.size()
				start = Vector2(-half.x, -half.y)
				step = Vector2(0, edge_length)

		for colour in clrs:
			var segment_group = Node2D.new()
			triangles.add_child(segment_group)

			var tri = Polygon2D.new()
			tri.name = "Polygon2D"
			var a = start
			var b = start + step
			tri.polygon = [a, b, center]
			tri.color = ColourPalette.get_colour(colour)
			segment_group.add_child(tri)

			var outline = Line2D.new()
			outline.name = "Outline"
			outline.width = 2.0
			outline.default_color = outline_colour
			outline.points = [a, b, center, a]
			segment_group.add_child(outline)

			var segment = Area2D.new()
			segment_group.add_child(segment)

			var seg_length: float
			var collision = CollisionShape2D.new()
			var square = RectangleShape2D.new()
			if dir == "north" or dir == "south":
				seg_length = b.x - a.x
				square.size = Vector2(seg_length * 0.75, 10)
			else:
				seg_length = b.y - a.y
				square.size = Vector2(10, seg_length * 0.75)
			collision.shape = square
			segment.add_child(collision)

			segment.set_meta("direction", dir)
			segment.set_meta("colour", colour)
			segment.set_meta("parent_tile", self)
			segment.set_meta("seg_length", seg_length)

			var midpoint = (a + b) / 2 + (sides[dir] * (square.size / 3))
			segment.position = midpoint
			segment.set_meta("midpoint", midpoint)

			start += step

func update_triangles():
	if has_node("Triangles"):
		get_node("Triangles").free()
	draw_triangles(side_colours, tile_size)

# =====================================================================
# SELECTION
# =====================================================================

func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var previous = puzzleManager.selected_tile
			puzzleManager.set_selected_tile(self)
			is_selected = true
			_update_selection_visual()
			if previous:
				previous._update_selection_visual()

func _update_selection_visual() -> void:
	if not has_node("Triangles"):
		return
	for segment_group in get_node("Triangles").get_children():
		if segment_group.has_node("Outline"):
			var line: Line2D = segment_group.get_node("Outline")
			if puzzleManager.selected_tile == self:
				line.default_color = Color.GOLD
				line.width = 4.0
			else:
				line.default_color = Color.WHITE
				line.width = 2.0

func duplicate_tile():
	data = to_tile_data()
	puzzleManager.duplicate_tile(data)
	puzzleManager.set_selected_tile(null)
	_update_selection_visual()

func delete_tile():
	if get_parent().is_in_group("tile_group"):
		var grp = get_parent()
		if grp.has_method("remove_tile"):
			grp.remove_tile(self)
	puzzleManager.remove_tile_from_puzzle(self)
	queue_free()
	puzzleManager.set_selected_tile(null)

# =====================================================================
# UTILITY
# =====================================================================

func to_tile_data() -> TileInfo:
	var d = TileInfo.new()
	d.tile_size = tile_size
	d.start_position = global_position
	d.side_colours = side_colours.duplicate(true)
	return d

func update_button_size():
	var margin = 20.0
	var btn_size = tile_size - Vector2(margin * 2, margin * 2)
	button.custom_minimum_size = btn_size
	button.size = btn_size
	button.position = -btn_size / 2

func set_cursor():
	if state == State.DRAGGING:
		Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)
	elif tile_hover:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_button_mouse_entered() -> void:
	tile_hover = true
	set_cursor()

func _on_button_mouse_exited() -> void:
	tile_hover = false
	set_cursor()

func _clamp_to_screen():
	if get_parent().is_in_group("tile_group"):
		return
	
	var screen := get_viewport().get_visible_rect()
	var half = tile_size / 2
	
	global_position.x = clamp(global_position.x, screen.position.x + half.x, screen.end.x - half.x)
	global_position.y = clamp(global_position.y, screen.position.y + half.y, screen.end.y - half.y)

func is_approximately_equal(num1, num2) -> bool:
	var diff = abs(num1 - num2)
	var allowed = max(relative_tolerance * max(abs(num1), abs(num2)), absolute_tolerance)
	return diff <= allowed

func _are_opposite(dir1: String, dir2: String) -> bool:
	return (
		(dir1 == "north" and dir2 == "south") or
		(dir1 == "south" and dir2 == "north") or
		(dir1 == "east"  and dir2 == "west")  or
		(dir1 == "west"  and dir2 == "east")
	)

func clamp_to_board():
	var board := get_tree().get_first_node_in_group("puzzle_board")
	if board == null:
		return
	if get_parent().is_in_group("tile_group"):
		var grp = get_parent()
		var bounds = grp.get_global_bounds()
		var offset = grp.global_position - bounds.position
		var board_min = board.global_position - board.board_size / 2
		var board_max = board.global_position + board.board_size / 2
		var clamped_x = clamp(bounds.position.x, board_min.x, board_max.x - bounds.size.x)
		var clamped_y = clamp(bounds.position.y, board_min.y, board_max.y - bounds.size.y)
		grp.global_position = Vector2(clamped_x, clamped_y) + offset
	else:
		var half = tile_size / 2
		var board_min = board.global_position - board.board_size / 2 + half
		var board_max = board.global_position + board.board_size / 2 - half
		global_position = Vector2(
			clamp(global_position.x, board_min.x, board_max.x),
			clamp(global_position.y, board_min.y, board_max.y)
		)
