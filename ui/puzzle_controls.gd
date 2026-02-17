extends CanvasLayer

@onready var duplicate_button = %DuplicateButton
@onready var delete_button = %DeleteButton

signal solve
signal reset
signal duplicate
signal delete
signal back

func _ready():
	%SolveButton.pressed.connect(solve.emit)
	%ResetButton.pressed.connect(reset.emit)
	%DuplicateButton.pressed.connect(duplicate.emit)
	%DeleteButton.pressed.connect(delete.emit)
	%BackButton.pressed.connect(back.emit)
