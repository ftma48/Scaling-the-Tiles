extends Node

var cells = []
var tiles = []
var dragging = false #global dragging, to avoid dragging multiple pieces

var grid_size = Vector2i(
	3,3
)

func find_cell(index: int):
	for cell in cells:
		if cell.index == index:
			return cell
