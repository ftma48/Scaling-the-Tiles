extends Node2D
class_name PuzzleBoard

@export var board_size := Vector2(900, 600)
@export var edge_thickness := 20
@export var tray_ratio = 0.2 
var tray_height_px := 160.0

var edge_segments_container: Node2D 
var side_colours := {}

func _ready():
	z_index = -10
	hide_board()
	var viewport_size = get_viewport_rect().size
	var board_zone_height = viewport_size.y * 0.66
	global_position = Vector2(
	viewport_size.x / 2,
	board_zone_height / 2
	)
	_create_edge_segments()  
	queue_redraw()

func show_board():
	visible = true
	set_process(true)
	set_physics_process(true)

func hide_board():
	visible = false
	set_process(false)
	set_physics_process(false)

func update_board_size(new_size: Vector2):
	board_size = new_size
	_clear_edge_segments()  
	_create_edge_segments() 
	queue_redraw()

func update_side_colours(new_colours: Dictionary):
	side_colours = new_colours
	_clear_edge_segments()
	_create_edge_segments()
	queue_redraw()

func _draw():
	var rect := Rect2(-board_size / 2, board_size)
	draw_rect(rect, Color.WHITE, false, 2)
	_draw_coloured_edges()
	_draw_piece_tray()

func _draw_coloured_edges():
	var half := board_size / 2

	for dir in side_colours.keys():
		var colours = side_colours[dir]
		if colours.is_empty():
			continue

		var seg_len: float
		var start: Vector2
		var step: Vector2
		var centered_start: Vector2

		match dir:
			"north":
				seg_len = board_size.x / colours.size()
				start = Vector2(-half.x, -half.y - (edge_thickness))
				centered_start =  start + Vector2(seg_len * 0.01, 0)
				step = Vector2(seg_len, 0)
			"south":
				seg_len = board_size.x / colours.size()
				start = Vector2(-half.x, half.y )
				centered_start =  start + Vector2(seg_len * 0.01, 0)
				step = Vector2(seg_len, 0)
			"east":
				seg_len = board_size.y / colours.size()
				start = Vector2(half.x, -half.y)
				centered_start =  start + Vector2(0, seg_len * 0.01)
				step = Vector2(0, seg_len)
			"west":
				seg_len = board_size.y / colours.size()
				start = Vector2(-half.x - (edge_thickness), -half.y)
				centered_start =  start + Vector2(0, seg_len * 0.01)
				step = Vector2(0, seg_len)

		for colour in colours:
			var size := (
				Vector2(seg_len * 0.98, edge_thickness)
				if dir in ["north", "south"]
				else Vector2(edge_thickness, seg_len * 0.98)
			)
			
			var r := Rect2(centered_start, size)
			draw_rect(r, ColourPalette.get_colour(colour))
			start += step
			centered_start += step

func get_board_origin() -> Vector2:
	return global_position - board_size / 2

func _create_edge_segments():
	if edge_segments_container:
		edge_segments_container.queue_free()
		
	edge_segments_container = Node2D.new()
	add_child(edge_segments_container)
	edge_segments_container.name = "EdgeSegments"
	
	var half := board_size / 2

	for dir in side_colours.keys():
		var colours = side_colours[dir]
		if colours.is_empty():
			continue

		var seg_len = (
			board_size.x
			if dir in ["north", "south"]
			else board_size.y
		) / colours.size()

		var start := Vector2.ZERO
		var step := Vector2.ZERO
		var normal := Vector2.ZERO

		match dir:
			"north":
				start = Vector2(-half.x, -half.y)
				step = Vector2(seg_len, 0)
				normal = Vector2(0, -1)
			"south":
				start = Vector2(-half.x, half.y)
				step = Vector2(seg_len, 0)
				normal = Vector2(0, 1)
			"east":
				start = Vector2(half.x, -half.y)
				step = Vector2(0, seg_len)
				normal = Vector2(1, 0)
			"west":
				start = Vector2(-half.x, -half.y)
				step = Vector2(0, seg_len)
				normal = Vector2(-1, 0)
		
		for colour in colours:
			var area := Area2D.new()
			edge_segments_container.add_child(area)
			
			var outline := Line2D.new()
			outline.name = "Outline"
			outline.width = 2.0
			outline.default_color = Color.WHITE
			outline.visible = false
			area.add_child(outline)
			
			
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = (
				Vector2(seg_len * 0.9, edge_thickness)
				if dir in ["north", "south"]
				else Vector2(edge_thickness, seg_len * 0.9)
			)
			shape.shape = rect
			area.add_child(shape)
			
			var half_rect = rect.size / 2
			outline.points = [
				Vector2(-half_rect.x, -half_rect.y),
				Vector2( half_rect.x, -half_rect.y),
				Vector2( half_rect.x,  half_rect.y),
				Vector2(-half_rect.x,  half_rect.y),
				Vector2(-half_rect.x, -half_rect.y)
			]
			
			area.position = start + step / 2 + normal * (edge_thickness / 2)
			
			area.set_meta("direction", dir)
			area.set_meta("colour", colour)
			area.set_meta("seg_length", seg_len)
			area.set_meta("parent_board", self)
			
			start += step

func _clear_edge_segments():
	if edge_segments_container:
		edge_segments_container.queue_free()  # Removes the previous segments and their collision shapes

func _draw_piece_tray():
	var viewport_size := get_viewport_rect().size
	var local_top_left := to_local(Vector2(0, viewport_size.y - tray_height_px))
	draw_rect(Rect2(local_top_left, Vector2(viewport_size.x, tray_height_px)), Color(0.1, 0.1, 0.1, 1.0), true)


func update_tray_height(tile_height: float, row_count: int):
	var padding := 20.0
	var viewport_height = get_viewport_rect().size.y
	
	var desired = padding + row_count * (tile_height + padding)
	var min_height = padding + tile_height + padding  # always at least one row
	var max_height = viewport_height * 0.4
	
	tray_height_px = clamp(desired, min_height, max_height)
	
	var available_height = viewport_height - tray_height_px
	global_position.y = available_height / 2
	
	queue_redraw()


func get_piece_tray_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(Vector2(0, viewport_size.y - tray_height_px), Vector2(viewport_size.x, tray_height_px))
