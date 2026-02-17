extends CanvasLayer

signal author_pressed
signal play_pressed

func _ready():
	%AuthorButton.pressed.connect(author_pressed.emit)
	%PlayButton.pressed.connect(play_pressed.emit)
