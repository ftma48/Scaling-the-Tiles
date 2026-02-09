extends CanvasLayer

@onready var ui_manager := get_parent()
@onready var puzzle_manager := get_tree().get_first_node_in_group("PuzzleManager")
