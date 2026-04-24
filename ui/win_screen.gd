extends CanvasLayer

signal back_pressed

func _ready():
	%Home.pressed.connect(back_pressed.emit)
