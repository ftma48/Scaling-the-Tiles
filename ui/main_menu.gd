extends CanvasLayer

signal author_pressed
signal play_pressed
signal settings_pressed

func _ready():
	%AuthorButton.pressed.connect(author_pressed.emit)
	%PlayButton.pressed.connect(play_pressed.emit)
	%SettingsButton.pressed.connect(settings_pressed.emit)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
