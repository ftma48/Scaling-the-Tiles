extends Node2D

@onready var tiles = $Tiles
@onready var tile_scene = preload("res://scenes/tile.tscn")
@onready var puzzleManager = $PuzzleManager
var main_menu_scene = preload("res://ui/MainMenu.tscn")

func _ready():
	puzzleManager.tile_root = $Tiles
	puzzleManager.request_main_menu.connect(_show_main_menu)
	_show_main_menu()

func _show_main_menu():
	clear_all_ui()
	
	var menu = main_menu_scene.instantiate()
	menu.name = "MainMenu"
	add_child(menu)
	
	menu.author_pressed.connect(_on_author_pressed)
	menu.play_pressed.connect(_on_play_pressed)

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
