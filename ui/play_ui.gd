extends CanvasLayer

signal puzzle_selected(index)
signal generate_pressed
signal back_pressed

# path references to puzzles?

func _ready():
	%Puzzle1Button.pressed.connect(func(): puzzle_selected.emit(1))
	%Puzzle2Button.pressed.connect(func(): puzzle_selected.emit(2))
	%Puzzle3Button.pressed.connect(func(): puzzle_selected.emit(3))
	%GenerateButton.pressed.connect(func(): generate_pressed.emit())
	%BackButton.pressed.connect(func(): back_pressed.emit())
