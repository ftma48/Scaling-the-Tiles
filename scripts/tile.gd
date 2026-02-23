extends Area2D

var data: TileInfo
var tile_size = Vector2(100,100)
var dragging = false
var drag_offset = Vector2.ZERO

var side_colours = {
	"north" = [],
	"east" = [],
	"south" = [],
	"west" = []
}

var connect = null
var connectedTile = null
var group = null 
var is_selected = false
var tile_hover = false
var handle_dragging = false
var handle_drag_offset := Vector2.ZERO
var handle_active = null
var resizing = false
var snap_length = 0
var snap_dir = null
var not_equal = false

# snapping size tolerance
var absolute_tolerance = 5.0
var relative_tolerance = 0.10

@onready var TileGroupScene = preload("res://scenes/tile_group.tscn")
@onready var puzzleManager = get_node("/root/Main/PuzzleManager")
@onready var sprite2d: Sprite2D  = $Sprite2D
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
	# create tile according to tile data
	data = myData
	tile_size = _tile_size
	position = pos
	var rect := RectangleShape2D.new()
	rect.size = tile_size
	collishape.shape = rect
	button.custom_minimum_size = tile_size
	button.z_index = 15
	side_colours = side_clrs
	
	draw_triangles(side_colours, tile_size)
	create_resize_handles()

func create_resize_handles():
	# create 8 handles for resizing
	var handles = Node2D.new()
	handles.z_index = 10
	handles.name = "ResizeHandles"
	add_child(handles)
	
	var positions = {
		"north": Vector2(0, -tile_size.y/2),
		"south": Vector2(0, tile_size.y/2),
		"east": Vector2(tile_size.x/2, 0),
		"west": Vector2(-tile_size.x/2, 0),
		"ne": Vector2(tile_size.x/2, -tile_size.y/2),
		"nw": Vector2(-tile_size.x/2, -tile_size.y/2),
		"se": Vector2(tile_size.x/2, tile_size.y/2),
		"sw": Vector2(-tile_size.x/2, tile_size.y/2),
	}
	
	for dir in positions.keys():
		var handle = Area2D.new()
		handle.name = dir + "_handle"
		handles.add_child(handle)
		
		var shape = CollisionShape2D.new()
		var square = RectangleShape2D.new()
		square.size = Vector2(20,20)
		shape.shape = square
		handle.add_child(shape)
		
		#var rect_vis = ColorRect.new()
		#rect_vis.color = Color(0.25,0.25,0.25,0.25)
		#rect_vis.size = Vector2(20, 20)           
		#rect_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		#handle.add_child(rect_vis)
		#rect_vis.position = -rect_vis.size / 2      # center it on handle
		
		handle.position = positions[dir]
		handle.set_meta("direction", dir)
		handle.connect("input_event", Callable(self, "_on_handle_input").bind(handle))
		handle.mouse_entered.connect(_on_handle_mouse_entered.bind(handle))
		handle.mouse_exited.connect(_on_handle_mouse_exited)

func _on_handle_mouse_entered(handle):
	var dir = handle.get_meta("direction")
	
	match dir:
		"east", "west":
			Input.set_default_cursor_shape(Input.CURSOR_HSIZE)
		"north", "south":
			Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
		"ne", "sw":
			Input.set_default_cursor_shape(Input.CURSOR_BDIAGSIZE)
		"nw", "se":
			Input.set_default_cursor_shape(Input.CURSOR_FDIAGSIZE)

func _on_handle_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

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
		"east": Vector2(tile_size.x/2, 0),
		"west": Vector2(-tile_size.x/2, 0),
		"ne": Vector2(tile_size.x/2, -tile_size.y/2),
		"nw": Vector2(-tile_size.x/2, -tile_size.y/2),
		"se": Vector2(tile_size.x/2, tile_size.y/2),
		"sw": Vector2(-tile_size.x/2, tile_size.y/2),
	}
	for dir in positions.keys():
		var node_name = dir + "_handle"
		if handles.has_node(node_name):
			var h = handles.get_node(node_name)
			h.position = positions[dir]
		else:
			print("missing handle:", node_name)

func draw_triangles(side_colours: Dictionary, tile_size: Vector2):
	var outline_colour
	if connect:
		outline_colour = Color.AQUA
	else:
		outline_colour = Color.WHITE
	var triangles = Node2D.new()
	triangles.name = "Triangles"
	add_child(triangles)
	var sides = {
		"north": Vector2(0, -1),
		"east": Vector2(1, 0),
		"south": Vector2(0, 1),
		"west": Vector2(-1, 0)
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
			var c = center
			tri.polygon = [a, b, c]
			tri.color = colour
			segment_group.add_child(tri)
			
			var outline = Line2D.new()
			outline.name = "Outline"
			outline.width = 2.0
			outline.default_color = outline_colour
			outline.points = [a, b, c, a]  
			segment_group.add_child(outline)
			
			# create collision shape for this triangle
			var segment = Area2D.new()
			segment_group.add_child(segment)
			
			var seg_length
			var collision = CollisionShape2D.new()
			var square = RectangleShape2D.new()
			if dir == "north" or dir == "south":
				seg_length = b.x-a.x
				square.size = Vector2(seg_length * 0.75, 10)
			else:
				seg_length = b.y-a.y
				square.size = Vector2(10, seg_length * 0.75)
			collision.shape = square
			segment.add_child(collision)
			
			# metadata
			segment.set_meta("direction", dir)
			segment.set_meta("colour", colour)
			segment.set_meta("parent_tile", self)
			segment.set_meta("seg_length", seg_length)
			
			# signals
			segment.connect("area_entered", Callable(self, "_on_segment_area_entered").bind(segment))
			segment.connect("area_exited", Callable(self, "_on_segment_area_exited").bind(segment))
			
			var midpoint = (a + b) / 2 + (sides[dir] * (square.size/3))
			segment.position = midpoint
			segment.set_meta("midpoint", midpoint)
			start += step

func update_triangles():
	if has_node("Triangles"):
		get_node("Triangles").free()
	draw_triangles(side_colours, tile_size)

func to_tile_data() -> TileInfo:
	var data = TileInfo.new()
	data.tile_size = tile_size
	data.start_position = global_position
	data.side_colours = side_colours.duplicate(true)
	return data

func _process(delta: float) -> void:
	if dragging:
		if get_parent().is_in_group("tile_group"):
			var group = get_parent()
			group.global_position = get_global_mouse_position() - drag_offset
		else:
			var parent_space_mouse = get_parent().to_local(get_global_mouse_position())
			position = parent_space_mouse - drag_offset
		#clamp_to_board()
	elif handle_dragging and handle_active != null:
		_resize_tile_from_mouse(handle_active)

func _on_button_button_down() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		# detach tile from its group
		if  get_parent().is_in_group("tile_group"):
			var group = get_parent()
			if group.has_method("remove_tile"):
				group.remove_tile(self)
			disconnectSound.play()
	
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)
	dragging = true
	if get_parent().is_in_group("tile_group"):
		# calculate offset from the group's position 
		var group = get_parent()
		drag_offset = get_global_mouse_position() - group.global_position
	else:
		drag_offset = get_global_mouse_position() - global_position

func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var selected
			if puzzleManager.selected_tile:
				selected = puzzleManager.selected_tile
			puzzleManager.set_selected_tile(self)
			is_selected = true
			_update_selection_visual()
			if selected:
				selected._update_selection_visual()

func _update_selection_visual() -> void:
	if not has_node("Triangles"):
		return
	
	var triangles = get_node("Triangles")
	for segment_group in triangles.get_children():
		if segment_group.has_node("Outline"):
			var line: Line2D = segment_group.get_node("Outline") 
			if puzzleManager.selected_tile == self:
				line.default_color = Color.GOLD
				line.width = 4.0
			else:
				line.default_color = Color.WHITE
				line.width = 2.0

func duplicate_tile():
	if get_parent().is_in_group("tile_group"):
		var group := get_parent()
		puzzleManager.duplicate_tilegroup(group)
	else:
		data = to_tile_data()
		puzzleManager.duplicate_tile(data)
	puzzleManager.set_selected_tile(null)
	_update_selection_visual()

func delete_tile():
	if get_parent().is_in_group("tile_group"):
		var group = get_parent()
		if group.has_method("remove_tile"):
			group.remove_tile(self)
	
	puzzleManager.remove_tile_from_puzzle(self)
	queue_free()
	
	puzzleManager.set_selected_tile(null)
	_update_selection_visual()

func set_cursor():
	if dragging:
		Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)
	elif tile_hover:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _apply_snap_position(target_global: Vector2):
	if get_parent().is_in_group("tile_group"):
		var group = get_parent()
		var offset = global_position - group.global_position
		group.global_position = target_global - offset
	else:
		global_position = target_global

func _on_button_button_up() -> void:
	dragging = false
	set_cursor()
	var targroup
	# check if tile is set to connect to something
	if connect != null:
		# check if its connecting to a tile
		if connectedTile != null:
			
			# set new position, save global transform
			_apply_snap_position(connect)
			var old_global = global_transform
			
			if connectedTile.get_parent().is_in_group("tile_group") and not self.get_parent().is_in_group("tile_group"):
				# add self to other group 
				targroup = connectedTile.get_parent()
				targroup.add_tile(self)
				global_transform = old_global
				connectSound.play()
			elif self.get_parent().is_in_group("tile_group") and not connectedTile.get_parent().is_in_group("tile_group"):
				targroup = get_parent()
				targroup.add_tile(connectedTile)
				global_transform = old_global
				connectSound.play()
			elif self.get_parent().is_in_group("tile_group") and  connectedTile.get_parent().is_in_group("tile_group"):
				merge_with_group(connectedTile.get_parent(),self.get_parent())
			else:
				targroup = TileGroupScene.instantiate()
				targroup.add_to_group("tile_group")
				var parent = connectedTile.get_parent()
				parent.add_child(targroup)
				targroup.global_position = connectedTile.global_position
				targroup.add_tile(connectedTile)
				targroup.add_tile(self)
			if not_equal:
				_snap_resize(snap_length, snap_dir)
			
		else:
			_apply_snap_position(connect)
			print("connecting to board")
			connectSound.play()  
			
			var board := get_tree().get_first_node_in_group("puzzle_board")
			if board and board.edge_segments_container:
				for seg in board.edge_segments_container.get_children():
					if seg.has_node("Outline"):
						var line = seg.get_node("Outline")
						line.default_color = Color.WHITE
						line.width = 2.0
						line.visible = false
		
		# reset snapping state
		connect = null
		connectedTile = null
		not_equal = false
		snap_dir = null
		snap_length = 0

func merge_with_group(source_group: Node2D, target_group: Node2D):
	var tiles_to_move = source_group.get_tiles().duplicate()
	for tile in tiles_to_move:
		source_group.remove_tile(tile)  
		target_group.add_tile(tile)     
		
	#TODO adjust group position 

func clamp_to_board():
	var board := get_tree().get_first_node_in_group("puzzle_board")
	if board == null:
		return
	
	if get_parent().is_in_group("tile_group"):
		var group = get_parent()
		var bounds = group.get_global_bounds()
		var offset = group.global_position - bounds.position  
		
		var board_min = board.global_position - board.board_size / 2
		var board_max = board.global_position + board.board_size / 2
		
		# compute clamped top-left so the bottom-right also stays inside the board
		var clamped_x = clamp(bounds.position.x, board_min.x, board_max.x - bounds.size.x)
		var clamped_y = clamp(bounds.position.y, board_min.y, board_max.y - bounds.size.y)
		
		group.global_position = Vector2(clamped_x, clamped_y) + offset
	else:
		var half = tile_size / 2
		var board_min = board.global_position - board.board_size / 2 + half
		var board_max = board.global_position + board.board_size / 2 - half
		
		global_position = Vector2(
			clamp(global_position.x, board_min.x, board_max.x),
			clamp(global_position.y, board_min.y, board_max.y)
		)


func _on_segment_area_entered(area: Area2D, my_segment: Area2D) -> void:
	if dragging:
		var is_tile := area.has_meta("parent_tile")
		var is_board := area.has_meta("parent_board")
		
		if not (is_tile or is_board):
			return
		
		# if area encountered belongs to a board or tile segment, 
		# is approximately the same length, and is the same colour, set
		# 'connect' to the position tile will snap to.
		if is_tile and area.has_meta("direction") and is_approximately_equal(area.get_meta("seg_length"), my_segment.get_meta("seg_length")):
			if area.get_meta("colour") == my_segment.get_meta("colour"):
				connectedTile = area.get_meta("parent_tile")
				var dir = area.get_meta("direction")
				
				var other_mid = area.global_position
				var my_mid = my_segment.global_position
				var target_pos = other_mid
				var other_size = connectedTile.tile_size
				var this_size = tile_size
				
				var delta = other_mid - my_mid
				var offset := Vector2.ZERO
				match dir:
					"north":
						offset = Vector2(0, 5)
					"south":
						offset = Vector2(0, -5)
					"east":
						offset = Vector2(-5, 0)
					"west":
						offset = Vector2(5, 0)
				
				connect = global_position + (other_mid - my_mid) + offset
				
				# make segments glow when connectable
				var line = area.get_parent().get_node("Outline")
				var line2 = my_segment.get_parent().get_node("Outline")
				line.default_color = Color.AQUA
				line.width = 4.0
				line2.default_color = Color.AQUA
				line2.width = 4.0
				
				# if segments are not exactly equal, set 'not_equal' ready for resize
				snap_length = area.get_meta("seg_length")
				snap_dir = dir
				if not area.get_meta("seg_length") == my_segment.get_meta("seg_length"):
					not_equal = true
		
		if is_board:
			print("board detected")
			_snap_to_board(area, my_segment)

func _snap_to_board(board_segment: Area2D, my_segment: Area2D) -> void:
	if not dragging:
		return
	
	var board_len = board_segment.get_meta("seg_length")
	var my_len = my_segment.get_meta("seg_length")
	print("DEBUG: board seg_len =", board_len, "my seg_len =", my_len, "diff =", abs(board_len - my_len))
	print("board colour: " , board_segment.get_meta("colour") , " seg colour: " , my_segment.get_meta("colour"))
	
	# colour must match
	if board_segment.get_meta("colour") != my_segment.get_meta("colour"):
		print("colour mismatch")
		return
	print("colours match.")

	# segment length must roughly match
	if not is_approximately_equal(board_len, my_len):
		print("lengths mismatch, skipping snap")
		return
	print("lengths match.")
	
	var board = board_segment.get_meta("parent_board")
	var dir = board_segment.get_meta("direction")
	var board_half = board.board_size / 2
	var tile_half = tile_size / 2

	# now we snap to the position of the detected segment 
	var target = board_segment.global_position
	
	var line = board_segment.get_node("Outline")
	line.default_color = Color.AQUA
	line.visible = true
	line.width = 4.0
	
	var my_line = my_segment.get_parent().get_node("Outline")
	my_line.default_color = Color.AQUA
	my_line.width = 4.0
	
	# adjust based on the segment's direction
	match dir:
		"north":
			target.y = board.global_position.y - board_half.y + tile_half.y
		"south":
			target.y = board.global_position.y + board_half.y - tile_half.y
		"west":
			target.x = board.global_position.x - board_half.x + tile_half.x
		"east":
			target.x = board.global_position.x + board_half.x - tile_half.x

	connect = target
	print("DEBUG: connect set for segment at ", connect)

func _on_segment_area_exited(area: Area2D, my_segment: Area2D) -> void:
	# reset connect variables
	connect = null
	connectedTile = null
	
	# set outline colours back to default
	if area.get_parent().has_node("Outline"):
		var line = area.get_parent().get_node("Outline")
		line.default_color = Color.WHITE
		line.width = 2.0
	if area.has_node("Outline"):
		var line = area.get_node("Outline")
		line.visible = false
		line.width = 2.0
	if my_segment.get_parent().has_node("Outline"):
		var line2 = my_segment.get_parent().get_node("Outline")
		line2.default_color = Color.WHITE
		line2.width = 2.0

func _on_handle_input(viewport, event, shape_idx, handle):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			handle_dragging = true
			handle_active = handle
			var parent = handle.get_parent()
			var mouse_local = parent.to_local(get_global_mouse_position())
			handle_drag_offset = mouse_local - handle.position
			resizing = true
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			handle_dragging = false
			handle_active = null
			resizing = false
			update_resize_handles()

func _resize_tile_from_mouse(handle: Area2D):
	var dir = handle.get_meta("direction")

	# anchor BEFORE resize
	var anchor_local = _get_anchor_local(dir)
	var anchor_global = to_global(anchor_local)

	var mouse_local = to_local(get_global_mouse_position())
	var new_size = tile_size

	match dir:
		"east":
			new_size.x = max((mouse_local.x - anchor_local.x), 50)
		"west":
			new_size.x = max((anchor_local.x - mouse_local.x), 50)
		"north":
			new_size.y = max((anchor_local.y - mouse_local.y), 50)
		"south":
			new_size.y = max((mouse_local.y - anchor_local.y), 50)
		"ne", "nw", "se", "sw":
			new_size.x = max(abs(mouse_local.x - anchor_local.x), 50)
			new_size.y = max(abs(mouse_local.y - anchor_local.y), 50)

	# apply
	tile_size = new_size
	collishape.shape.size = tile_size
	button.custom_minimum_size = tile_size

	# restore anchor
	var new_anchor_local = _get_anchor_local(dir)
	var new_anchor_global = to_global(new_anchor_local)
	global_position += anchor_global - new_anchor_global

	update_triangles()
	update_resize_handles()


func _resize_tile(handle: Area2D):
	var dir = handle.get_meta("direction")

	# anchor BEFORE resize
	var anchor_local = _get_anchor_local(dir)
	var anchor_global = to_global(anchor_local)

	var pos = handle.position
	var new_size = tile_size

	match dir:
		"east":
			new_size.x = max(pos.x * 2, 50)
		"west":
			new_size.x = max(abs(pos.x) * 2, 50)
		"north":
			new_size.y = max(abs(pos.y) * 2, 50)
		"south":
			new_size.y = max(pos.y * 2, 50)
		"ne", "nw", "se", "sw":
			new_size.x = max(abs(pos.x) * 2, 50)
			new_size.y = max(abs(pos.y) * 2, 50)

	# apply size
	tile_size = new_size
	collishape.shape.size = tile_size
	button.custom_minimum_size = tile_size

	# restore anchor position
	var new_anchor_local = _get_anchor_local(dir)
	var new_anchor_global = to_global(new_anchor_local)
	global_position += anchor_global - new_anchor_global

	update_triangles()
	update_resize_handles()

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and not event.pressed:
		handle_dragging = false
		handle_active = null
		resizing = false


func _snap_resize(other_segment_length, dir):
	match dir:
		"north":
			dir = "south"
		"south":
			dir = "north"
		"east":
			dir = "west"
		"west":
			dir = "east"
	
	var my_count = side_colours[dir].size()
	var new_size = tile_size
	
	match dir:
		"north", "south":
			new_size.x = other_segment_length * my_count
		"east", "west":
			new_size.y = other_segment_length * my_count
	
	# apply new size
	tile_size = new_size
	collishape.shape.set("size", tile_size)
	button.custom_minimum_size = tile_size
	update_resize_handles()
	update_triangles()	
	
	# reset flags
	not_equal = false
	snap_dir = null
	snap_length = 0

func is_approximately_equal(num1, num2):
	var diff = abs(num1 - num2)
	var allowed = max(relative_tolerance * max(abs(num1), abs(num2)), absolute_tolerance)
	return diff <= allowed

func _on_button_mouse_entered() -> void:
	tile_hover = true
	set_cursor()

func _on_button_mouse_exited() -> void:
	tile_hover = false
	set_cursor()
