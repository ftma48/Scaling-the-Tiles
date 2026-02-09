extends Resource
class_name PuzzleData

@export var puzzle_name: String
@export var tiles: Array
@export var board_size: Vector2
@export var board_colours: Dictionary = {
	"north": ["red", "green"],
	"south": ["red", "blue"],
	"east":  ["red", "green"],
	"west":  ["red", "blue"],
}
