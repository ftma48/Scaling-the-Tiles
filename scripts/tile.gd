extends Area2D

var index = -1
var cell_index = -1

var tile_size = Vector2(100,100)

var dragging = false
var drag_offset = Vector2.ZERO

var connect = null
var connectedTile = null

var connected_tiles = []
var group = null 

@export var side_colours = {
	"north" = [],
	"east" = [],
	"south" = [],
	"west" = []
}

@onready var TileGroupScene = preload("res://scenes/tile_group.tscn")
@onready var sprite2d: Sprite2D  = $Sprite2D
@onready var collishape: CollisionShape2D = $CollisionShape2D
@onready var button: Button = $Button
@onready var edge1: Area2D = $edge1
@onready var edge1colli: CollisionShape2D = $edge1/CollisionShape2D

func debug_tile_state(prefix: String = ""):
	print("=== DEBUG TILE STATE " + prefix + " ===")
	print("Tile:", name)
	print(" Parent:", get_parent().name)
	print(" Parent in group?:", get_parent().is_in_group("tile_group"))
	print(" Local position:", position)
	print(" Global position:", global_position)
	print(" Global transform:", global_transform.origin)
	print(" Dragging:", dragging)
	print(" Connected Tile:", connectedTile if connectedTile else "None")
	print(" Connect target (global):", connect if connect else "None")
	print("==============================")

func init_tile(
	pos: Vector2,
	_tile_size: Vector2,
	side_clrs: Dictionary
):
	tile_size = _tile_size
	position = pos
	collishape.shape.set("size", tile_size)
	button.custom_minimum_size = tile_size
	side_colours = side_clrs
	
	'for x in range(1,5):
		var path = "edge" + str(x) + "/CollisionShape2D"
		var colli = get_node(path)
		var edge = colli.get_parent()
		
		colli.shape.set("size", tile_size/4)
		if x%2 == 0:
			edge.position.y = collishape.position.y
			if x>2:
				edge.position.x = collishape.position.x - (tile_size.x/2)
			else:
				edge.position.x = collishape.position.x + (tile_size.x/2)
		else:
			edge.position.x = collishape.position.x
			if x>2:
				edge.position.y = collishape.position.y + (tile_size.y/2)
			else:
				edge.position.y = collishape.position.y - (tile_size.y/2)'
	draw_triangles(side_colours, tile_size)

func _draw_edge_debug():
	for i in range(1, 5):
		var edge := get_node("edge%d" % i)
		var col := edge.get_node("CollisionShape2D")

		if col.shape is RectangleShape2D:
			var size = col.shape.size
			var pos = edge.position - (size / 2)

			draw_rect(
				Rect2(pos, size),
				Color(1, 0, 0, 0.15),   # translucent red fill
				true
			)
			draw_rect(
				Rect2(pos, size),
				Color(1, 0, 0, 0.8),    # red outline
				false
			)

func draw_triangles(side_colours: Dictionary, tile_size: Vector2):
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
		
		var edge_length = tile_size.x / clrs.size()
		var start = Vector2(-half.x, -half.y)
		match dir:
			"north":
				start = Vector2(-half.x, -half.y)
			"east":
				start = Vector2(half.x, -half.y)
			"south":
				start = Vector2(half.x, half.y)
			"west":
				start = Vector2(-half.x, half.y)
				
		var step = Vector2.ZERO
		if dir in ["north", "south"]:
			step = Vector2(edge_length, 0)
			if dir == "south":
				start.x = -half.x
				start.y = half.y
		else:
			step = Vector2(0, edge_length)
			if dir == "east":
				start.x = half.x
				start.y = -half.y
			elif dir == "west":
				start.x = -half.x
				start.y = -half.y
				
		for colour in clrs:
			var tri = Polygon2D.new()
			var a = start
			var b = start + step
			var c = center
			tri.polygon = [a, b, c]
			tri.color = colour
			triangles.add_child(tri)
			
			var outline = Line2D.new()
			outline.width = 2.0
			outline.default_color = Color.WHITE
			outline.points = [a, b, c, a]  
			triangles.add_child(outline)
			
			# create collision shape for this triangle
			var segment = Area2D.new()
			triangles.add_child(segment)
			
			var collision = CollisionShape2D.new()
			var square = RectangleShape2D.new()
			square.size = Vector2(tile_size.x/4, tile_size.y/4)
			collision.shape = square
			segment.add_child(collision)
			
			# metadata
			segment.set_meta("direction", dir)
			segment.set_meta("colour", colour)
			segment.set_meta("parent_tile", self)
			
			# signals
			segment.connect("area_entered", Callable(self, "_on_segment_area_entered"))
			segment.connect("area_exited", Callable(self, "_on_segment_area_exited"))

			
			var midpoint = (a + b) / 2
			segment.position = midpoint
			
			start += step

func _ready():
	$edge1.set_meta("direction", "north")
	$edge2.set_meta("direction", "east")
	$edge3.set_meta("direction", "south")
	$edge4.set_meta("direction", "west")

func _draw():
	#_draw_edge_debug()
	pass

func _process(delta: float) -> void:
	queue_redraw()
	if dragging:
		if get_parent().is_in_group("tile_group"):
			var group = get_parent()
			# move the entire group with the mouse
			group.global_position = get_global_mouse_position() - drag_offset
		else:
			# move just this tile 
			var parent_space_mouse = get_parent().to_local(get_global_mouse_position())
			position = parent_space_mouse - drag_offset
	else:
		if connect != null:
			global_position = connect
			debug_tile_state("AFTER CONNECT SNAP")
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
	
func _on_button_button_down() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		# detach tile from its group
		if  get_parent().is_in_group("tile_group"):
			var group = get_parent()
			if group.has_method("remove_tile"):
				group.remove_tile(self)
				print("detached", self.name, "from", group.name)
				print("--- DEBUG DETACH ---")
				print("Tile:", self.name)
				print("New parent:", get_parent().name)
				print("--------------------")
				debug_tile_state("AFTER DETACHING")
			return
	
	dragging = true
	if get_parent().is_in_group("tile_group"):
		# calculate offset from the group's position instead of the tile
		var group = get_parent()
		drag_offset = get_global_mouse_position() - group.global_position
	else:
		drag_offset = get_global_mouse_position() - global_position

func _on_button_button_up() -> void:
	dragging = false

func _on_segment_area_entered(area: Area2D) -> void:
	if dragging:
		if area.has_meta("parent_tile") and area.has_meta("direction"):
			connectedTile = area.get_meta("parent_tile")
			var dir = area.get_meta("direction")
			
			var other_size = connectedTile.tile_size
			var this_size = tile_size
			var target_pos = connectedTile.global_position
			
			match dir:
				"north":
					target_pos.y -= (other_size.y/2 + this_size.y/2)
				"south":
					target_pos.y += (other_size.y/2 + this_size.y/2)
				"east":
					target_pos.x += (other_size.x/2 + this_size.x/2)
				"west":
					target_pos.x -= (other_size.x/2 + this_size.x/2)
			connect = target_pos

func _on_segment_area_exited(area: Area2D) -> void:
	connect = null
	if dragging:
		connectedTile = null

'func _on_edge_area_entered(area: Area2D) -> void:
	if dragging:
		connectedTile = area.get_parent()
		var dir = area.get_meta("direction")  # "north","east","south","west"
		
		var other_size = connectedTile.tile_size
		var this_size = tile_size
		var target_pos = connectedTile.global_position
		
		match dir:
			"north":
				target_pos.y -= (other_size.y/2 + this_size.y/2)
			"south":
				target_pos.y += (other_size.y/2 + this_size.y/2)
			"east":
				target_pos.x += (other_size.x/2 + this_size.x/2)
			"west":
				target_pos.x -= (other_size.x/2 + this_size.x/2)
		
		connect = target_pos 

func _on_edge_area_exited(area: Area2D) -> void:
	connect = null
	if dragging:
		connectedTile = area.get_parent()
		if self.is_ancestor_of(connectedTile):
			connectedTile.remove_child(self)
		else:
			self.remove_child(connectedTile)'
