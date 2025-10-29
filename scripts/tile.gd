extends Area2D

var index = -1
var cell_index = -1

var dragging = false
var drag_offset = Vector2.ZERO

var connect = null

@onready var sprite2d: Sprite2D  = $Sprite2D
@onready var collishape: CollisionShape2D = $CollisionShape2D
@onready var button: Button = $Button
@onready var edge1: Area2D = $edge1
@onready var edge1colli: CollisionShape2D = $edge1/CollisionShape2D


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
		position = get_global_mouse_position() - drag_offset
	else:
		if connect != null:
			position = connect
			connect = null
	
func _on_button_button_down() -> void:
	dragging = true
	drag_offset = get_global_mouse_position() - global_position

func _on_button_button_up() -> void:
	dragging = false

func _on_edge_area_entered(area: Area2D) -> void:
	if dragging:
		connect = area.get_parent().position # position of other tile
		connect += area.position*2

func _on_edge_area_exited(area: Area2D) -> void:
	connect = null
