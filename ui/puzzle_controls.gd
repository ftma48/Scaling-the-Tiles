extends CanvasLayer

@onready var duplicate_button = %DuplicateTileButton
@onready var duplicate_group_button = %DuplicateGroupButton
@onready var delete_button = %DeleteButton

signal solve
signal reset
signal duplicate
signal delete
signal back
signal duplicategroup

func _ready():
	%SolveButton.pressed.connect(solve.emit)
	%ResetButton.pressed.connect(reset.emit)
	%DuplicateTileButton.pressed.connect(duplicate.emit)
	%DuplicateGroupButton.pressed.connect(duplicategroup.emit)
	%DeleteButton.pressed.connect(delete.emit)
	%BackButton.pressed.connect(back.emit)
