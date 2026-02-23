extends CanvasLayer

signal difficulty_selected(level)

@onready var easy_button = $Panel/VBoxContainer/Easy
@onready var medium_button = $Panel/VBoxContainer/Medium
@onready var hard_button = $Panel/VBoxContainer/Hard
@onready var cancel_button = $Panel/VBoxContainer/Cancel

func _ready():
	easy_button.pressed.connect(func(): difficulty_selected.emit("easy"))
	medium_button.pressed.connect(func(): difficulty_selected.emit("medium"))
	hard_button.pressed.connect(func(): difficulty_selected.emit("hard"))
	cancel_button.pressed.connect(queue_free)
