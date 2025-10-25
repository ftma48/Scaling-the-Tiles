extends Area2D

var index = -1

@onready var sprite2d: Sprite2D  = $Sprite2D
@onready var collishape: CollisionShape2D = $CollisionShape2D

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
