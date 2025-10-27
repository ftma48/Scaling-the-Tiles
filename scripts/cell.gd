extends Area2D

var index = -1
var occupied = false #to check whether a tile is occupying the cell

@onready var sprite2d: Sprite2D  = $Sprite2D
@onready var collishape: CollisionShape2D = $CollisionShape2D

func init_cell(
	_index: int,
	tile_size: Vector2
):
	index = _index

	#set size for the cell based on tile size
	sprite2d.texture.set("width", tile_size.x)
	sprite2d.scale = Vector2(1, tile_size.y)
	
	#update shape of collider
	collishape.shape.set("size", tile_size)

func is_free():
	return not occupied

func occupy():
	occupied = true

func unoccupy():
	occupied = false
