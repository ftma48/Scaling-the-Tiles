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
var duplicate_group_button
var delete_button

var only_unique = true
var board_size
var board_colours
var generated_puzzle
signal request_main_menu
signal puzzle_solved

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
		1: load_puzzle(load("res://puzzles/puzzle_2026-03-06T20-30-39.tres"))
		2: load_puzzle(load("res://puzzles/puzzle_2026-03-06T20-35-58.tres"))
		3: load_puzzle(load("res://puzzles/ambiguous_puzzle_medium.tres"))
	
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
		"easy":   generated_puzzle = puzzle_generator.generate_puzzle(Vector2i(5,5),  Vector2(130,130), 4, 3, 4)
		"medium": generated_puzzle = puzzle_generator.generate_puzzle(Vector2i(7,7),  Vector2(100,100), 4, 5, 3)
		"hard": generated_puzzle = puzzle_generator.generate_puzzle(Vector2i(10,10), Vector2(70,70), 5, 7, 3, 2)
	
	var ui = get_node_or_null("PlayUI")
	if ui:
		ui.queue_free()
	
	load_puzzle(generated_puzzle)
	
	var board := get_node("/root/Main/PuzzleBoard")
	board.show_board()
	
	_show_puzzle_controls()

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
	controls.duplicategroup.connect(_on_duplicate_group_pressed)
	controls.delete.connect(_on_delete_pressed)
	controls.back.connect(_on_back_pressed)
	
	duplicate_button = controls.duplicate_button
	duplicate_group_button = controls.duplicate_group_button
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
	
	if not solved:
		# calculate tile count first, then update tray before spawning
		var seen := {}
		var tiles_to_spawn := []
		for tile_data in puzzle.tiles:
			var sig = _side_colours_signature(tile_data.side_colours)
			if only_unique and seen.has(sig):
				continue
			seen[sig] = true
			tiles_to_spawn.append(tile_data)
		
		var tile_height := current_puzzle.unit_size.y if current_puzzle.unit_size != Vector2.ZERO else 100.0
		var tile_width := current_puzzle.unit_size.x if current_puzzle.unit_size != Vector2.ZERO else 100.0
		var padding := 20.0
		var viewport_width := get_viewport().get_visible_rect().size.x
		var columns := int((viewport_width - padding) / (tile_width + padding))
		columns = max(columns, 1)
		var row_count = ceil(tiles_to_spawn.size() / float(columns))
		board.update_tray_height(tile_height, row_count)
		
		for tile_data in tiles_to_spawn:
			spawn_tile(tile_data, true)
	else:
		for tile_data in puzzle.tiles:
			spawn_tile(tile_data, false)

func spawn_tile(data, randomise):
	var tile = tile_scene.instantiate()
	tile_root.add_child(tile)
	tiles.append(tile)
	
	if not randomise:
		var puzzle_board = get_node("/root/Main/PuzzleBoard")
		var board_origin = puzzle_board.get_board_origin()

		tile.init_tile(
			data,
			board_origin + data.start_position,
			data.tile_size,
			data.side_colours
		)
	else:
		var puzzle_board := get_node("/root/Main/PuzzleBoard")
		var tray = puzzle_board.get_piece_tray_rect()
		
		var tile_size := Vector2(120, 120)
		var padding := Vector2(20, 20)
		
		var index := tiles.size() - 1
		
		var columns := int((tray.size.x - padding.x) / (tile_size.x + padding.x))
		columns = max(columns, 1)
		
		var col := index % columns
		var row := index / columns
		
		var pos := Vector2(
			tray.position.x + padding.x + col * (tile_size.x + padding.x) + tile_size.x / 2,
			tray.position.y + padding.y + row * (tile_size.y + padding.y) + tile_size.y / 2
		)
		
		var unit_size = current_puzzle.unit_size if current_puzzle.unit_size != Vector2.ZERO else Vector2(100, 100)

		tile.init_tile(
			data,
			pos,
			unit_size,
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
	
	if duplicate_group_button:
		var in_group = selected_tile != null and selected_tile.get_parent().is_in_group("tile_group")
		duplicate_group_button.disabled = not in_group

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		
		if selected_tile != null:
			set_selected_tile(null)

func duplicate_tile(data):
	var copy = data.duplicate(true)
	copy.start_position += Vector2(40, 40)
	spawn_tile(copy, false)

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
		tiles.append(new_tile)
	set_selected_tile(null)

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
	
	var board := get_node("/root/Main/PuzzleBoard")
	var board_origin = board.get_board_origin()
	
	for tile in tiles:
		var data = tile.to_tile_data()
		data.start_position = data.start_position - board_origin  # make relative
		puzzle.tiles.append(data)
		
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
	load_puzzle(load("res://puzzles/puzzle_2026-01-26T10-56-35.tres"))

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

func _on_duplicate_group_pressed():
	if selected_tile and selected_tile.get_parent().is_in_group("tile_group"):
		duplicate_tilegroup(selected_tile.get_parent())
	else:
		print("No grouped tile selected.")

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

func check_win_condition() -> bool:
	var board := get_node("/root/Main/PuzzleBoard")
	if board == null or board.edge_segments_container == null:
		return false
	
	var board_segments = board.edge_segments_container.get_children()
	if board_segments.is_empty():
		return false
	
	for board_seg in board_segments:
		if not board_seg is Area2D:
			continue
		
		var b_dir = board_seg.get_meta("direction")
		var b_colour = board_seg.get_meta("colour")
		var b_len = board_seg.get_meta("seg_length")
		var b_pos = board_seg.global_position
		
		var matched = false
		
		for tile in tiles:
			if not tile.has_node("Triangles"):
				continue
			for seg_group in tile.get_node("Triangles").get_children():
				for child in seg_group.get_children():
					if not child is Area2D:
						continue
					if child.get_meta("direction") != b_dir:
						continue
					if child.get_meta("colour") != b_colour:
						continue
					if not tile.is_approximately_equal(child.get_meta("seg_length"), b_len):
						continue
					if child.global_position.distance_to(b_pos) > 20.0:
						continue
					matched = true
					break
				if matched:
					break
			if matched:
				break
		
		if not matched:
			return false
	
	print("PUZZLE SOLVED!")
	emit_signal("puzzle_solved")
	return true
