extends CanvasLayer

signal edit_board
signal add_tile
signal save
signal load
signal solve
signal clear
signal duplicate
signal delete
signal back

func _ready():
	%EditBoardButton.pressed.connect(edit_board.emit)
	%AddTileButton.pressed.connect(add_tile.emit)
	%SaveButton.pressed.connect(save.emit)
	%LoadButton.pressed.connect(load.emit)
	%SolveButton.pressed.connect(solve.emit)
	%ClearButton.pressed.connect(clear.emit)
	%DuplicateButton.pressed.connect(duplicate.emit)
	%DeleteButton.pressed.connect(delete.emit)
	%BackButton.pressed.connect(back.emit)
