extends Node

class_name PuzzleManager

enum Mode { PLAY, AUTHOR }
var mode: Mode = Mode.PLAY

@onready var tile_scene = preload("res://scenes/tile.tscn")
@onready var tile_root: Node2D = get_parent().get_node("Tiles")

var colours = ["red", "blue", "green", "yellow"]
#var tile_size: Vector2 = Vector2(100,100)

var default_tile_data = preload("res://resources/default_tile_data.tres")

var current_puzzle: PuzzleData
var tiles := []

func author_mode():
	if has_node("AuthorUI"):
		return
	
	var canvas := CanvasLayer.new()
	canvas.name = "AuthorUI"
	add_child(canvas)
	
	var root := Control.new()
	root.anchor_right = 0
	root.anchor_bottom = 0
	root.offset_left = 10
	root.offset_top = 10
	canvas.add_child(root)
	# Layout
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(vbox)
	# Buttons
	vbox.add_child(_make_button("Add Tile", _on_add_tile_pressed))
	vbox.add_child(_make_button("Save Puzzle", _on_save_puzzle_pressed))
	vbox.add_child(_make_button("Load Puzzle", _on_load_puzzle_pressed))
	vbox.add_child(_make_button("Clear", _on_clear_pressed))

func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn

func load_puzzle(puzzle: PuzzleData):
	clear_puzzle()
	current_puzzle = puzzle
	for tile_data in puzzle.tiles:
		spawn_tile(tile_data)

func spawn_tile(data):
	var tile = tile_scene.instantiate()
	tile_root.add_child(tile)
	tiles.append(tile)
	
	tile.init_tile(
		data.start_position,
		data.tile_size,
		data.side_colours
	)

func clear_puzzle():
	for t in tiles:
		t.queue_free()
	tiles.clear()

func export_current_puzzle(name: String) -> PuzzleData:
	var puzzle = PuzzleData.new()
	puzzle.puzzle_name = name
	puzzle.tiles = []
	
	for tile in tiles:
		puzzle.tiles.append(tile.to_tile_data())
	
	return puzzle

func clear():
	clear_puzzle()

func _on_add_tile_pressed():
	spawn_tile(default_tile_data.duplicate(true))

func _on_save_puzzle_pressed():
	var id = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var puzzle = export_current_puzzle(id)
	ResourceSaver.save(puzzle, "res://puzzles/puzzle_%s.tres" % id)
	print("puzzle saved")

func _on_load_puzzle_pressed():
	load_puzzle(load("res://puzzles/puzzle_2025-12-18T22-13-07.tres"))

func _on_clear_pressed():
	clear_puzzle()
