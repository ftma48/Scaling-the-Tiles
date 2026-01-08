extends Node2D
class_name PuzzleBoard

@export var board_size := Vector2(900, 600)

func _ready():
	var viewport_size = get_viewport_rect().size
	global_position = viewport_size / 2

	queue_redraw()

func _draw():
	var rect := Rect2(-board_size / 2, board_size)
	draw_rect(rect, Color.WHITE, false, 2)
