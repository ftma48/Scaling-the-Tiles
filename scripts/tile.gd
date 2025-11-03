extends Area2D

var index = -1
var cell_index = -1

var dragging = false
var drag_offset = Vector2.ZERO

var connect = null
var connectedTile = null

var connected_tiles = []
var group = null 

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
	_index: int,
	texture: ImageTexture,
	pos: Vector2,
	tile_size: Vector2
):
	index = _index
	sprite2d.texture = texture
	position = pos
	collishape.shape.set("size", tile_size)
	button.custom_minimum_size = tile_size
	for x in range(1,5):
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
				edge.position.y = collishape.position.y - (tile_size.y/2)


@export var sideColours = {
	"north" = ["red"],
	"east" = ["blue"],
	"south" = ["green"],
	"west" = ["yellow"]
}

func _ready():
	var northColour = sideColours["north"] 
	var eastColour = sideColours["east"]
	var southColour = sideColours["south"]
	var westColour = sideColours["west"]
	
	$edge1.set_meta("direction", "north")
	$edge2.set_meta("direction", "east")
	$edge3.set_meta("direction", "south")
	$edge4.set_meta("direction", "west")

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

func _on_edge_area_entered(area: Area2D) -> void:
	if dragging:
		connectedTile = area.get_parent()
		# Compute snap position in global space
		var edge_global_pos = area.global_position
		var connected_tile_global_pos = connectedTile.global_position

		# The vector from the connected tile to its edge
		var edge_vector = edge_global_pos - connected_tile_global_pos

		# Mirror that vector across to find where this tile should go (in global space)
		connect = edge_global_pos + edge_vector

func _on_edge_area_exited(area: Area2D) -> void:
	connect = null
	if dragging:
		connectedTile = area.get_parent()
		if self.is_ancestor_of(connectedTile):
			connectedTile.remove_child(self)
		else:
			self.remove_child(connectedTile)
