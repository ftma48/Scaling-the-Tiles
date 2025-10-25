extends Node

var cells = []
var tiles = []

enum DIFFICULTY {
	EASY,
	MEDIUM,
	HARD
}
const DIFFICULTY_VALUES = {
	DIFFICULTY.EASY: 3,
	DIFFICULTY.MEDIUM: 4,
	DIFFICULTY.HARD: 5
}

var chosen_difficulty = DIFFICULTY.EASY

var grid_size = Vector2i(
	3,3
)
