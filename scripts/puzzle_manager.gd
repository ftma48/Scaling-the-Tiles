extends Node
class_name PuzzleManager

var mode = "START"

@onready var tile_scene = preload("res://scenes/tile.tscn")
@onready var tile_root: Node2D
var play_ui_scene = preload("res://ui/PlayUI.tscn")
var author_ui_scene = preload("res://ui/AuthorUI.tscn")
var puzzle_controls_scene = preload("res://ui/PuzzleControls.tscn")
var default_tile_data = preload("res://resources/default_tile_data.tres")

var current_puzzle: PuzzleData
var tiles := []
var selected_tile: Node2D

var duplicate_button
var delete_button

var only_unique = true
var board_size
var board_colours
var generated_puzzle
signal request_main_menu

func play_mode():
	if has_node("PlayUI"):
		return
	
	clear_ui()
	mode = "PLAY"
	
	var ui = play_ui_scene.instantiate()
	add_child(ui)
	
	ui.puzzle_selected.connect(_on_play_puzzle_selected)
	ui.generate_pressed.connect(_on_generate_pressed)
	ui.back_pressed.connect(_on_back_pressed)

func _on_play_puzzle_selected(index):
	var ui = get_node_or_null("PlayUI")
	if ui:
		ui.queue_free()
	
	
	match index:
		1: load_puzzle(load("res://puzzles/puzzle_2026-01-26T10-56-35.tres"))
		2: load_puzzle(load("res://puzzles/puzzle_2026-01-26T11-06-01.tres"))
		3: load_puzzle(generated_puzzle)
	
	var board := get_node("/root/Main/PuzzleBoard")
	board.show_board()
	
	_show_puzzle_controls()

func _on_generate_pressed():
	var popup = preload("res://ui/DifficultyPopup.tscn").instantiate()
	add_child(popup)
	
	popup.difficulty_selected.connect(func(level):
		popup.queue_free()
		_generate_with_difficulty(level)
	)

func _generate_with_difficulty(level):
	var puzzle_generator = get_tree().get_first_node_in_group("puzzle_generator")
	match level:
		"easy":
			generated_puzzle = puzzle_generator.generate_puzzle(Vector2i(5,5), Vector2(100,100), 4, 3)
		"medium":
			generated_puzzle = puzzle_generator.generate_puzzle(Vector2i(7,7), Vector2(60,60), 4, 4)
		"hard":
			generated_puzzle = puzzle_generator.generate_puzzle(Vector2i(10,10), Vector2(50,50), 3, 5)

func author_mode():
	if has_node("AuthorUI"):
		return
	
	clear_ui()
	mode = "AUTHOR"
	
	var board := get_node("/root/Main/PuzzleBoard")
	board.show_board()
	
	var ui = author_ui_scene.instantiate()
	add_child(ui)
	
	ui.edit_board.connect(_on_edit_board_pressed)
	ui.add_tile.connect(_on_add_tile_pressed)
	ui.save.connect(_on_save_puzzle_pressed)
	ui.load.connect(_on_load_puzzle_pressed)
	ui.solve.connect(_on_solve_puzzle_pressed)
	ui.clear.connect(_on_clear_pressed)
	ui.duplicate.connect(_on_duplicate_pressed)
	ui.delete.connect(_on_delete_pressed)
	ui.back.connect(_on_back_pressed)

func clear_ui():
	for child in get_children():
		if child is CanvasLayer:
			child.queue_free()

func _show_puzzle_controls():
	if has_node("PuzzleControls"):
		return
	
	var controls = puzzle_controls_scene.instantiate()
	controls.name = "PuzzleControls"
	add_child(controls)
	
	# connect signals
	controls.solve.connect(_on_solve_puzzle_pressed)
	controls.reset.connect(_on_reset_pressed)
	controls.duplicate.connect(_on_duplicate_pressed)
	controls.delete.connect(_on_delete_pressed)
	controls.back.connect(_on_back_pressed)
	
	duplicate_button = controls.duplicate_button
	delete_button = controls.delete_button
	
	_update_selection_ui()

func load_puzzle(puzzle: PuzzleData, solved: bool = false):
	clear_puzzle()
	current_puzzle = puzzle
	
	var board = get_node("/root/Main/PuzzleBoard")
	
	board_size = puzzle.board_size
	board_colours = puzzle.board_colours
	board.update_board_size(board_size)
	board.update_side_colours(board_colours)
	
	var seen := {}
	
	if solved:
		for tile_data in puzzle.tiles:
			spawn_tile(tile_data, false)
	else:
		if only_unique:
			for tile_data in puzzle.tiles:
				var sig = _side_colours_signature(tile_data.side_colours)
				if seen.has(sig):
					continue
				seen[sig] = true
				spawn_tile(tile_data, true)
		else:
			for tile_data in puzzle.tiles:
				spawn_tile(tile_data, true)


func spawn_tile(data, randomise):
	var tile = tile_scene.instantiate()
	tile_root.add_child(tile)
	tiles.append(tile)
	
	if not randomise:
		print("spawning tile, not randomising position")
		tile.init_tile(
			data,
			data.start_position,
			data.tile_size,
			data.side_colours
		)
	else:
		var puzzle_board := get_node("/root/Main/PuzzleBoard")
		var tray = puzzle_board.get_piece_tray_rect()

		var tile_size := Vector2(120, 120)
		var padding := Vector2(20, 20)

		# How many tiles already spawned into the tray
		var index := tiles.size()

		var columns := int((tray.size.x - padding.x) / (tile_size.x + padding.x))
		columns = max(columns, 1)

		var col := index % columns
		var row := index / columns

		var pos := Vector2(
			tray.position.x + padding.x + col * (tile_size.x + padding.x) + tile_size.x / 2,
			tray.position.y + padding.y + row * (tile_size.y + padding.y) + tile_size.y / 2
		)

		tile.init_tile(
			data,
			pos,
			Vector2(120,120),
			data.side_colours
		)

func _side_colours_signature(sc: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		",".join(sc.get("north", [])),
		",".join(sc.get("east", [])),
		",".join(sc.get("south", [])),
		",".join(sc.get("west", []))
	]

func set_selected_tile(tile: Node2D):
	var previous = selected_tile
	selected_tile = tile
	
	# Update previous tile visual
	if previous and previous.has_method("_update_selection_visual"):
		previous._update_selection_visual()
	
	# Update new tile visual
	if selected_tile and selected_tile.has_method("_update_selection_visual"):
		selected_tile._update_selection_visual()
	
	_update_selection_ui()

func _update_selection_ui():
	var disabled := selected_tile == null
	
	if duplicate_button:
		duplicate_button.disabled = disabled
	
	if delete_button:
		delete_button.disabled = disabled

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		
		if selected_tile != null:
			set_selected_tile(null)

func duplicate_tile(data):
	spawn_tile(data, false)

func duplicate_tilegroup(group: Node2D):
	var new_group := preload("res://scenes/tile_group.tscn").instantiate()
	new_group.add_to_group("tile_group")
	tile_root.add_child(new_group)

	var offset := Vector2(40, 40)
	new_group.global_position = group.global_position + offset

	for tile in group.tiles:
		var data = tile.to_tile_data()
		data.start_position = tile.global_position - group.global_position
		var new_tile := tile_scene.instantiate()
		new_group.add_child(new_tile)
		new_tile.init_tile(
			data,
			data.start_position,
			data.tile_size,
			data.side_colours.duplicate(true)
		)
		new_group.add_tile(new_tile)

func clear_puzzle():
	for t in tiles:
		t.queue_free()
	tiles.clear()

func export_current_puzzle(name: String) -> PuzzleData:
	var puzzle = PuzzleData.new()
	puzzle.puzzle_name = name
	puzzle.tiles = []
	
	puzzle.board_size = board_size
	puzzle.board_colours = board_colours
	
	for tile in tiles:
		puzzle.tiles.append(tile.to_tile_data())
	
	return puzzle

func clear():
	clear_puzzle()

func _on_edit_board_pressed():
	var popup := Window.new()
	popup.title = "Edit Board"
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
	
	# Board size input
	var size_label := Label.new()
	size_label.text = "Board Size"
	root.add_child(size_label)
	
	var size_row := HBoxContainer.new()
	root.add_child(size_row)
	
	var width_input := LineEdit.new()
	width_input.placeholder_text = "width"
	size_row.add_child(width_input)
	
	var height_input := LineEdit.new()
	height_input.placeholder_text = "height"
	size_row.add_child(height_input)
	
	# Board color inputs for north, east, south, and west
	var colour_label := Label.new()
	colour_label.text = "Board Colours"
	root.add_child(colour_label)
	
	var sides := []
	for side in ["north", "east", "south", "west"]:
		var input := LineEdit.new()
		input.placeholder_text = side
		root.add_child(input)
		sides.append(input)
	
	# Button row
	var button_row := HBoxContainer.new()
	root.add_child(button_row)
	
	var confirm := Button.new()
	confirm.text = "Confirm"
	button_row.add_child(confirm)
	
	var cancel := Button.new()
	cancel.text = "Cancel"
	button_row.add_child(cancel)
	
	confirm.pressed.connect(func():
		board_size = Vector2(
			float(width_input.text),
			float(height_input.text)
		)
		
		board_colours = {
			"north": _parse_colour_list(sides[0].text),
			"east":  _parse_colour_list(sides[1].text),
			"south": _parse_colour_list(sides[2].text),
			"west":  _parse_colour_list(sides[3].text)
		}
		
		update_board(board_size, board_colours)
		
		popup.queue_free()
	)
	
	cancel.pressed.connect(func():
		popup.queue_free()
	)
	
	popup.popup_centered()

func update_board(board_size: Vector2, board_colours: Dictionary):
	var board = get_node("/root/Main/PuzzleBoard")  
	board.update_board_size(board_size)
	board.update_side_colours(board_colours)

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
		
		spawn_tile(data.duplicate(true), false)
		
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
	load_puzzle(load("res://puzzles/puzzle_2026-01-26T11-06-01.tres"))

func _on_solve_puzzle_pressed():
	load_puzzle(current_puzzle, true)

func _on_clear_pressed():
	clear_puzzle()

func _on_reset_pressed():
	load_puzzle(current_puzzle)

func _on_duplicate_pressed():
	if selected_tile:
		selected_tile.duplicate_tile()
	else:
		print("No tile selected to duplicate.")

func _on_delete_pressed():
	if selected_tile:
		selected_tile.delete_tile()
		tiles
	else:
		print("No tile selected to delete.")

func _on_back_pressed():
	var board := get_node("/root/Main/PuzzleBoard")
	board.hide_board()
	
	clear_ui()
	clear_puzzle()
	
	request_main_menu.emit()

func remove_tile_from_puzzle(tile_to_remove: Node2D):
	tiles.erase(tile_to_remove)
	print("Tile removed from puzzle!")
