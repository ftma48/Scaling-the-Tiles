extends Node

class_name PuzzleManager

var mode = "START"

@onready var tile_scene = preload("res://scenes/tile.tscn")
@onready var tile_root: Node2D
@onready var puzzle_board = preload("res://scenes/puzzle_board.gd")

var colours = ["red", "blue", "green", "yellow"]
#var tile_size: Vector2 = Vector2(100,100)

var default_tile_data = preload("res://resources/default_tile_data.tres")

var current_puzzle: PuzzleData
var tiles := []

func play_mode():
	if has_node("PlayUI"):
		return
	
	get_parent().clear_all_ui()
	mode = "PLAY"
	
	var canvas := CanvasLayer.new()
	canvas.name = "PlayUI"
	add_child(canvas)
	
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	vbox.add_child(_make_button("Puzzle 1", func():
		get_node("PlayUI").queue_free()
		load_puzzle(load("res://puzzles/puzzle_2025-12-18T22-13-07.tres"))
	))
	
	vbox.add_child(_make_button("Puzzle 2", func():
		get_node("PlayUI").queue_free()
		load_puzzle(current_puzzle)
	))
	
	vbox.add_child(_make_button("Puzzle 3", func():
		get_node("PlayUI").queue_free()
		load_puzzle(current_puzzle)
	))

func author_mode():
	if has_node("AuthorUI"):
		return
	
	get_parent().clear_all_ui()
	
	mode = "AUTHOR"
	
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
	var popup := Window.new()
	popup.title = "Create Tile"
	popup.size = Vector2(320, 260)
	popup.position = get_viewport().get_visible_rect().size / 2 - Vector2(popup.size / 2)
	add_child(popup)
	
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 10
	root.offset_right = -10
	root.offset_bottom = -10
	popup.add_child(root)
	
	var size_label := Label.new()
	size_label.text = "Tile Size"
	root.add_child(size_label)
	
	var size_row := HBoxContainer.new()
	root.add_child(size_row)
	
	var x_input := LineEdit.new()
	x_input.placeholder_text = "width"
	size_row.add_child(x_input)
	
	var y_input := LineEdit.new()
	y_input.placeholder_text = "height"
	size_row.add_child(y_input)
	
	var colour_label := Label.new()
	colour_label.text = "Side Colours"
	root.add_child(colour_label)
	
	var sides := []
	for side in ["north", "east", "south", "west"]:
		var input := LineEdit.new()
		input.placeholder_text = side
		root.add_child(input)
		sides.append(input)
	
	var button_row := HBoxContainer.new()
	root.add_child(button_row)
	
	var confirm := Button.new()
	confirm.text = "Confirm"
	button_row.add_child(confirm)
	
	var cancel := Button.new()
	cancel.text = "Cancel"
	button_row.add_child(cancel)
	
	confirm.pressed.connect(func():
		var tile_size := Vector2(
			float(x_input.text),
			float(y_input.text)
		)
		
		var side_colours: Dictionary = {
			"north": _parse_colour_list(sides[0].text),
			"east":  _parse_colour_list(sides[1].text),
			"south": _parse_colour_list(sides[2].text),
			"west":  _parse_colour_list(sides[3].text)
		}
		
		var data = TileInfo.new()
		data.tile_size = tile_size
		data.start_position = Vector2(500,500)
		data.side_colours = side_colours.duplicate(true)
		
		spawn_tile(data.duplicate(true))
		
		popup.queue_free()
	)
	
	cancel.pressed.connect(func():
		popup.queue_free()
	)
	
	popup.popup_centered()

func _parse_colour_list(text: String) -> Array:
	var result: Array = []
	for item in text.split(",", false):
		var cleaned := item.strip_edges()
		if cleaned != "":
			result.append(cleaned)
	return result

func _on_save_puzzle_pressed():
	var id = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var puzzle = export_current_puzzle(id)
	ResourceSaver.save(puzzle, "res://puzzles/puzzle_%s.tres" % id)
	print("puzzle saved")

func _on_load_puzzle_pressed():
	load_puzzle(load("res://puzzles/puzzle_2025-12-18T22-13-07.tres"))

func _on_clear_pressed():
	clear_puzzle()
