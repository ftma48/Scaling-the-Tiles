extends Area2D

var index = -1

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
