extends Node
class_name UIManager

enum Mode {
	START,
	AUTHOR,
	PLAY
}

@onready var start_ui: CanvasLayer = $StartUI
@onready var author_ui: CanvasLayer = $AuthorUI
@onready var play_ui: CanvasLayer = $PlayUI
