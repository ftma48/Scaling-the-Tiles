extends Node2D

@onready var tiles = $Tiles
@onready var tile_scene = preload("res://scenes/tile.tscn")

var colours = ["red", "blue", "green", "yellow"]

var tile_size: Vector2 = Vector2(100,100)
var tile_size2: Vector2 = Vector2(100,100)

@onready var puzzleManager = $PuzzleManager

var side_clrs = {
		"north" = [colours.pick_random(), colours.pick_random()],
		"east" = [colours.pick_random(), colours.pick_random(),colours.pick_random()],
		"south" = [colours.pick_random()],
		"west" = [colours.pick_random()]
		}

func _ready():
	puzzleManager.tile_root = $Tiles
	var canvas := CanvasLayer.new()
	add_child(canvas)
	
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var author_btn := Button.new()
	author_btn.text = "Author Mode"
	author_btn.custom_minimum_size = Vector2(220, 64)
	vbox.add_child(author_btn)
	
	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(220, 64)
	vbox.add_child(play_btn)
	
	author_btn.pressed.connect(_on_author_pressed)
	play_btn.pressed.connect(_on_play_pressed)

func _on_author_pressed():
	clear_all_ui()
	puzzleManager.author_mode()

func _on_play_pressed():
	clear_all_ui()
	puzzleManager.play_mode()

func clear_all_ui():
	for child in get_children():
		if child is CanvasLayer:
			child.queue_free()
