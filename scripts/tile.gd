extends Area2D

var epsilon = 25

var tile_size = Vector2(100,100)

var dragging = false
var drag_offset = Vector2.ZERO

var connect = null
var connectedTile = null

var connected_tiles = []
var group = null 

var side_colours = {
	"north" = [],
	"east" = [],
	"south" = [],
	"west" = []
}

var handle_dragging = false
var handle_drag_offset := Vector2.ZERO
var handle_active = null
var resizing = false
var snap_length = 0
var snap_dir = null
var not_equal = false


@onready var TileGroupScene = preload("res://scenes/tile_group.tscn")
@onready var sprite2d: Sprite2D  = $Sprite2D
@onready var collishape: CollisionShape2D = $CollisionShape2D
@onready var button: Button = $Button
@onready var connectSound: AudioStreamPlayer = get_node_or_null("../../connectSfx")
@onready var disconnectSound: AudioStreamPlayer = get_node_or_null("../../disconnectSfx")

func init_tile(
	pos: Vector2,
	_tile_size: Vector2,
	side_clrs: Dictionary
):
	print(connectSound)
	tile_size = _tile_size
	position = pos
	# Ensure a unique shape resource per tile
	var rect := RectangleShape2D.new()
	rect.size = tile_size
	collishape.shape = rect
	button.custom_minimum_size = tile_size
	side_colours = side_clrs
	draw_triangles(side_colours, tile_size)
	create_resize_handles()

func create_resize_handles():
	var handles = Node2D.new()
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
		
		handle.position = positions[dir]
		handle.set_meta("direction", dir)
		handle.connect("input_event", Callable(self, "_on_handle_input").bind(handle))

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
		print("Drawing", clrs.size(), "segments on", dir)
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
			
			print("Calculated segment length:", edge_length)
			
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
			# move the entire group with the mouse
			group.global_position = get_global_mouse_position() - drag_offset
		else:
			# move just this tile 
			var parent_space_mouse = get_parent().to_local(get_global_mouse_position())
			position = parent_space_mouse - drag_offset
		clamp_to_board()
	elif handle_dragging and handle_active != null:
		var parent = handle_active.get_parent()
		var mouse_local = parent.to_local(get_global_mouse_position())
		handle_active.position = mouse_local - handle_drag_offset
		_resize_tile(handle_active)

func _on_button_button_down() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		# detach tile from its group
		if  get_parent().is_in_group("tile_group"):
			var group = get_parent()
			if group.has_method("remove_tile"):
				group.remove_tile(self)
			disconnectSound.play()
	
	dragging = true
	if get_parent().is_in_group("tile_group"):
		# calculate offset from the group's position instead of the tile
		var group = get_parent()
		drag_offset = get_global_mouse_position() - group.global_position
	else:
		drag_offset = get_global_mouse_position() - global_position

func _on_button_button_up() -> void:
	dragging = false
	if connect != null and connectedTile != null:
		global_position = connect
		connected_tiles.append(connectedTile)
		var old_global = global_transform
		group = null
		if connectedTile.get_parent().is_in_group("tile_group"):
			group = connectedTile.get_parent()
		else:
			group = TileGroupScene.instantiate()
			group.add_to_group("tile_group")
			var parent = connectedTile.get_parent()
			parent.add_child(group)
			group.global_position = connectedTile.global_position
			group.add_tile(connectedTile)
		group.add_tile(self)
		global_transform = old_global
		connect = null
		connectSound.play()
		if not_equal:
			_snap_resize(snap_length, snap_dir)

func clamp_to_board():
	var board := get_tree().get_first_node_in_group("puzzle_board")
	if board == null:
		return
	
	var half
	if get_parent().is_in_group("tile_group"):
		group = get_parent()
		half = group.get_size() / 2
		var min = board.global_position - board.board_size / 2 + half
		var max = board.global_position + board.board_size / 2 - half
		
		group.global_position = group.global_position.clamp(min, max)
	else:
		half = tile_size / 2
		var min = board.global_position - board.board_size / 2 + half
		var max = board.global_position + board.board_size / 2 - half
		
		global_position = global_position.clamp(min, max)

func _on_segment_area_entered(area: Area2D, my_segment: Area2D) -> void:
	if dragging:
		if area.has_meta("parent_tile") and area.has_meta("direction") and is_approximately_equal(area.get_meta("seg_length"), my_segment.get_meta("seg_length"), epsilon):
			print("other: ", area.get_meta("colour"), " me: ", my_segment.get_meta("colour"))
			if area.get_meta("colour") == my_segment.get_meta("colour"):
				connectedTile = area.get_meta("parent_tile")
				var dir = area.get_meta("direction")
				
				var other_mid = area.global_position
				var my_mid = my_segment.global_position
				var target_pos = other_mid
				
				var other_size = connectedTile.tile_size
				var this_size = tile_size
				
				var delta = other_mid - my_mid
				connect = global_position + (other_mid - my_mid) 
				
				var line = area.get_parent().get_node("Outline")
				var line2 = my_segment.get_parent().get_node("Outline")
				line.default_color = Color.AQUA
				line.width = 4.0
				line2.default_color = Color.AQUA
				line2.width = 4.0
				
				snap_length = area.get_meta("seg_length")
				snap_dir = dir
				if not area.get_meta("seg_length") == my_segment.get_meta("seg_length"):
					not_equal = true
				print("Snapping to segment with length:", area.get_meta("seg_length"))
				print("My segment length:", my_segment.get_meta("seg_length"))
				print("My segment global position:", my_segment.global_position)
				print("Other segment global position:", area.global_position)


func _on_segment_area_exited(area: Area2D, my_segment: Area2D) -> void:
	connect = null
	if dragging:
		connectedTile = null
		
	if area.get_parent().has_node("Outline"):
		var line = area.get_parent().get_node("Outline")
		line.default_color = Color.WHITE
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
			handle_dragging = false
			handle_active = null
			resizing = false
			update_resize_handles()

func _resize_tile(handle: Area2D):
	var dir = handle.get_meta("direction")
	var pos = handle.position
	var new_size = tile_size
	
	match dir:
		"east":
			new_size.x = pos.x * 2
		"west":
			new_size.x = abs(pos.x) * 2
		"north":
			new_size.y = abs(pos.y) * 2
		"south":
			new_size.y = pos.y * 2
		"ne", "nw", "se", "sw":
			new_size.x = abs(pos.x) * 2
			new_size.y = abs(pos.y) * 2
	
	# enforce minimum size
	new_size.x = max(new_size.x, 50)
	new_size.y = max(new_size.y, 50)
	# apply new size
	tile_size = new_size
	collishape.shape.set("size", tile_size)
	button.custom_minimum_size = tile_size
	
	update_triangles()

func _snap_resize(other_segment_length, dir):
	var my_count = side_colours[dir].size()
	var new_size = tile_size
	match dir:
		"north", "south":
			new_size.x = other_segment_length * my_count / 2
		"east", "west":
			new_size.y = other_segment_length * my_count / 2
	
	
	# apply new size
	tile_size = new_size
	collishape.shape.set("size", tile_size)
	button.custom_minimum_size = tile_size
	update_resize_handles()
	update_triangles()	
	
	print("Resizing tile on", dir)
	print("Target segment length:", other_segment_length)
	print("My segment count:", my_count)
	print("New tile size:", tile_size)
	# reset flags
	not_equal = false
	snap_dir = null
	snap_length = 0

func is_approximately_equal(num1, num2, epsilon):
	var diff = abs(num1 - num2)
	if diff < epsilon:
		return true
	else:
		return false
