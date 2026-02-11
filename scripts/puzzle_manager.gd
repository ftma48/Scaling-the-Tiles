extends Node
class_name PuzzleManager

var mode = "START"

@onready var tile_scene = preload("res://scenes/tile.tscn")
@onready var tile_root: Node2D

var colours = ["red", "blue", "green", "yellow"]
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

func play_mode():
	if has_node("PlayUI"):
		return
	
	get_parent().clear_all_ui()
	clear_ui()
	mode = "PLAY"
	
	var board := get_node("/root/Main/PuzzleBoard")
	board.show_board()
	
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
		load_puzzle(load("res://puzzles/puzzle_2026-01-26T10-56-35.tres"))
		_show_puzzle_controls()
	))
	
	vbox.add_child(_make_button("Puzzle 2", func():
		get_node("PlayUI").queue_free()
		load_puzzle(load("res://puzzles/puzzle_2026-01-26T11-06-01.tres"))
		_show_puzzle_controls()
	))
	
	vbox.add_child(_make_button("Puzzle 3", func():
		get_node("PlayUI").queue_free()
		load_puzzle(generated_puzzle)
		_show_puzzle_controls()
	))
	
	vbox.add_child(_make_button("generate puzzle", func():
		var puzzle_generator = get_tree().get_first_node_in_group("puzzle_generator")
		generated_puzzle = puzzle_generator.generate_puzzle()
	))
	
	vbox.add_child(_make_button("Back", _on_back_pressed))

func author_mode():
	if has_node("AuthorUI"):
		return
	
	get_parent().clear_all_ui()
	clear_ui()
	mode = "AUTHOR"
	
	var board := get_node("/root/Main/PuzzleBoard")
	board.show_board()
	
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
	vbox.add_child(_make_button("Edit Board", _on_edit_board_pressed))
	vbox.add_child(_make_button("Add Tile", _on_add_tile_pressed))
	vbox.add_child(_make_button("Save Puzzle", _on_save_puzzle_pressed))
	vbox.add_child(_make_button("Load Puzzle", _on_load_puzzle_pressed))
	vbox.add_child(_make_button("Solve Puzzle", _on_solve_puzzle_pressed))
	vbox.add_child(_make_button("Clear", _on_clear_pressed))
	
	duplicate_button = _make_button("Duplicate", _on_duplicate_pressed)
	vbox.add_child(duplicate_button)

	delete_button = _make_button("Delete", _on_delete_pressed)
	vbox.add_child(delete_button)
	
	vbox.add_child(_make_button("Back", _on_back_pressed))

func clear_ui():
	for child in get_children():
		if child is CanvasLayer:
			child.queue_free()

func _show_puzzle_controls():
	if not has_node("LeftPlayUI"):
		var left_canvas := CanvasLayer.new()
		left_canvas.name = "LeftPlayUI"
		add_child(left_canvas)
		
		var left_root := Control.new()
		left_root.anchor_left = 0
		left_root.anchor_top = 0
		left_root.offset_left = 10
		left_root.offset_top = 10
		left_canvas.add_child(left_root)
		
		var left_vbox := VBoxContainer.new()
		left_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		left_root.add_child(left_vbox)
		
		duplicate_button = _make_button("Duplicate", _on_duplicate_pressed)
		left_vbox.add_child(duplicate_button)

		delete_button = _make_button("Delete", _on_delete_pressed)
		left_vbox.add_child(delete_button)
		
		left_vbox.add_child(_make_button("Solve Puzzle", _on_solve_puzzle_pressed))
		left_vbox.add_child(_make_button("Back", _on_back_pressed))

func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn

func load_puzzle(puzzle: PuzzleData):
	clear_puzzle()
	current_puzzle = puzzle
	
	var board = get_node("/root/Main/PuzzleBoard")
	
	board_size = puzzle.board_size
	board_colours = puzzle.board_colours
	board.update_board_size(board_size)
	board.update_side_colours(board_colours)
	
	var seen := {}
	
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
	clear_puzzle()
	var puzzle = current_puzzle
	for tile_data in puzzle.tiles:
		spawn_tile(tile_data, false)

func _on_clear_pressed():
	clear_puzzle()

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
	get_parent().clear_all_ui()
	clear_ui()
	clear_puzzle()
	var mainMenu = get_tree().root.get_node("Main")
	mainMenu.clear_all_ui()
	mainMenu._ready() 

func remove_tile_from_puzzle(tile_to_remove: Node2D):
	tiles.erase(tile_to_remove)
	print("Tile removed from puzzle!")
