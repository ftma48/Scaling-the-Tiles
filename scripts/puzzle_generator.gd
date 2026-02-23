extends Node
class_name PuzzleGenerator

@export var base_colours := ["red", "blue", "green", "yellow"]
@export var unit_grid_size := Vector2i(6, 6)
@export var unit_world_size := Vector2(100, 100)
@export var solution_origin := Vector2(0, 0)
@export var seed := 0

@export var min_tile_size := Vector2i(1, 1)
@export var max_depth := 4
@export var split_stop_chance := 0.25

var colours := []
var tile_regions: Array[Rect2i] = []
var generated_tiles: Array[TileInfo] = []
var rng := RandomNumberGenerator.new()
var vertical_boundaries := []
var horizontal_boundaries := []

func generate_puzzle(unit_grid: Vector2i, unit_world: Vector2, colour_num: int, depth: int):
	unit_grid_size = unit_grid
	unit_world_size = unit_world
	colours = base_colours.slice(0, colour_num)
	max_depth = depth
	_init_rng()
	var board := get_node("/root/Main/PuzzleBoard")
	solution_origin = board.global_position
	
	_init_unit_boundaries()
	_assign_boundary_colours()
	
	_partition_into_tiles()
	_debug_print_regions()
	
	_generate_tiles()
	_debug_print_tiles()
	
	var id = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var puzzle = build_puzzle_data()
	ResourceSaver.save(puzzle, "res://puzzles/generated_puzzle_%s.tres" % id)
	return puzzle

func _init_rng():
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

func _init_unit_boundaries():
	vertical_boundaries.clear()
	horizontal_boundaries.clear()

	# vertical boundaries: (width + 1) x height
	for x in range(unit_grid_size.x + 1):
		var column := []
		for y in range(unit_grid_size.y):
			column.append(null)
		vertical_boundaries.append(column)

	# horizontal boundaries: width x (height + 1)
	for x in range(unit_grid_size.x):
		var column := []
		for y in range(unit_grid_size.y + 1):
			column.append(null)
		horizontal_boundaries.append(column)

func _assign_boundary_colours():
	for x in range(vertical_boundaries.size()):
		for y in range(vertical_boundaries[x].size()):
			vertical_boundaries[x][y] = _random_colour()

	for x in range(horizontal_boundaries.size()):
		for y in range(horizontal_boundaries[x].size()):
			horizontal_boundaries[x][y] = _random_colour()

func _random_colour() -> String:
	return colours[rng.randi_range(0, colours.size() - 1)]

func _debug_print_boundaries():
	print("--- Vertical Boundaries ---")
	for y in range(unit_grid_size.y):
		var row := []
		for x in range(unit_grid_size.x + 1):
			row.append(vertical_boundaries[x][y])
		print(row)

	print("--- Horizontal Boundaries ---")
	for y in range(unit_grid_size.y + 1):
		var row := []
		for x in range(unit_grid_size.x):
			row.append(horizontal_boundaries[x][y])
		print(row)

func _partition_into_tiles():
	print("STARTING BSP")
	tile_regions.clear()
	var root = Rect2i(0, 0, unit_grid_size.x, unit_grid_size.y)
	_bsp_split(root, 0)

func _bsp_split(region: Rect2i, depth: int):
	# recursive function splits grid into two repeatedly
	if _should_stop(region, depth):
		print("ENDING SPLIT")
		tile_regions.append(region)
		return
	
	var split = _choose_split(region)
	if split == null:
		print("ENDING SPLIT")
		tile_regions.append(region)
		return
	
	print("SPLIT ", depth, " COMPLETE, MOVING TO NEXT")
	_bsp_split(split.a, depth + 1)
	_bsp_split(split.b, depth + 1)

func _should_stop(region: Rect2i, depth: int) -> bool:
	# determines whether bsp should end based on depth of recursion, remaining area size, and rng
	if depth >= max_depth:
		print("DEPTH EXCEEDED")
		return true
	
	var can_split_h = region.size.y >= min_tile_size.y * 2
	var can_split_v = region.size.x >= min_tile_size.x * 2
	
	if not can_split_h and not can_split_v:
		print("REGIONS TOO SMALL")
		return true
	
	if depth > 1:
		return rng.randf() < split_stop_chance 
	
	return false

func _choose_split(region: Rect2i):
	# choose axis to split along, favouring the longer one
	var can_split_h = region.size.y >= min_tile_size.y * 2
	var can_split_v = region.size.x >= min_tile_size.x * 2
	
	var split_vertical = false
	
	if can_split_h and can_split_v:
		if region.size.x > region.size.y:
			split_vertical = rng.randf() < 0.7
		else:
			split_vertical = rng.randf() < 0.3
	elif can_split_v:
		split_vertical = true
	elif can_split_h:
		split_vertical = false
	else:
		return null
		
	if split_vertical:
		print("SPLITTING VERTICALLY")
		var min_x = min_tile_size.x
		var max_x = region.size.x - min_tile_size.x
		var split_x = rng.randi_range(min_x, max_x)
		
		var a = Rect2i(region.position, Vector2i(split_x, region.size.y))
		var b = Rect2i(region.position + Vector2i(split_x, 0), Vector2i(region.size.x - split_x, region.size.y))
		return { "a": a, "b": b }
	else:
		print("SPLITTING HORIZONTALLY")
		var min_y = min_tile_size.y
		var max_y = region.size.y - min_tile_size.y
		var split_y = rng.randi_range(min_y, max_y)

		var a = Rect2i(region.position, Vector2i(region.size.x, split_y))
		var b = Rect2i(region.position + Vector2i(0, split_y), Vector2i(region.size.x, region.size.y - split_y))
		return { "a": a, "b": b }

func _grow_rectangle_from(start_x: int, start_y: int, occupied) -> Rect2i:
	var max_width := unit_grid_size.x - start_x
	var max_height := unit_grid_size.y - start_y

	# Random desired size
	var width := rng.randi_range(1, max_width)
	var height := rng.randi_range(1, max_height)

	# Clamp to free space
	width = _max_free_width(start_x, start_y, width, occupied)
	height = _max_free_height(start_x, start_y, width, height, occupied)

	return Rect2i(start_x, start_y, width, height)

func _max_free_width(x: int, y: int, desired: int, occupied) -> int:
	var w := 0
	for dx in range(desired):
		if x + dx >= unit_grid_size.x:
			break
		if occupied[x + dx][y]:
			break
		w += 1
	return max(w, 1)

func _max_free_height(x: int, y: int, width: int, desired: int, occupied) -> int:
	var h := 0
	for dy in range(desired):
		if y + dy >= unit_grid_size.y:
			break
		
		for dx in range(width):
			if occupied[x + dx][y + dy]:
				return max(h, 1)
		
		h += 1
	
	return max(h, 1)

func _mark_region(region: Rect2i, occupied):
	for dx in range(region.size.x):
		for dy in range(region.size.y):
			occupied[region.position.x + dx][region.position.y + dy] = true

func _debug_print_regions():
	print("--- Tile Regions ---")
	for r in tile_regions:
		print("pos:", r.position, " size:", r.size)

func _generate_tiles():
	generated_tiles.clear()
	
	for region in tile_regions:
		var tile = _build_tile_from_region(region)
		generated_tiles.append(tile)

func _build_tile_from_region(region: Rect2i) -> TileInfo:
	var tile := TileInfo.new()
	
	tile.tile_size = Vector2(region.size) * unit_world_size
	
	var board_size := Vector2(unit_grid_size) * unit_world_size
	var board_top_left := solution_origin - board_size * 0.5
	
	var tile_top_left := board_top_left + Vector2(region.position) * unit_world_size
	tile.start_position = tile_top_left + tile.tile_size * 0.5
	
	tile.side_colours = {
		"north": _edge_segments_north(region),
		"east":  _edge_segments_east(region),
		"south": _edge_segments_south(region),
		"west":  _edge_segments_west(region)
	}
	
	return tile


func _edge_segments_north(region: Rect2i) -> Array:
	var colours := []
	var y := region.position.y
	
	for x in range(region.position.x, region.position.x + region.size.x):
		colours.append(horizontal_boundaries[x][y])
	
	return colours

func _edge_segments_south(region: Rect2i) -> Array:
	var colours := []
	var y := region.position.y + region.size.y
	
	for x in range(region.position.x, region.position.x + region.size.x):
		colours.append(horizontal_boundaries[x][y])
	
	return colours

func _edge_segments_west(region: Rect2i) -> Array:
	var colours := []
	var x := region.position.x
	
	for y in range(region.position.y, region.position.y + region.size.y):
		colours.append(vertical_boundaries[x][y])
	
	return colours

func _edge_segments_east(region: Rect2i) -> Array:
	var colours := []
	var x := region.position.x + region.size.x
	
	for y in range(region.position.y, region.position.y + region.size.y):
		colours.append(vertical_boundaries[x][y])
	
	return colours

func _frame_north() -> Array:
	var colours := []
	for x in range(unit_grid_size.x):
		colours.append(horizontal_boundaries[x][0])
	return colours

func _frame_south() -> Array:
	var colours := []
	var y := unit_grid_size.y
	for x in range(unit_grid_size.x):
		colours.append(horizontal_boundaries[x][y])
	return colours

func _frame_west() -> Array:
	var colours := []
	for y in range(unit_grid_size.y):
		colours.append(vertical_boundaries[0][y])
	return colours

func _frame_east() -> Array:
	var colours := []
	var x := unit_grid_size.x
	for y in range(unit_grid_size.y):
		colours.append(vertical_boundaries[x][y])
	return colours

func _debug_print_tiles():
	print("--- Generated Tiles ---")
	for i in range(generated_tiles.size()):
		var t := generated_tiles[i]
		print("Tile", i)
		print(" size:", t.tile_size)
		print("  N:", t.side_colours["north"])
		print("  E:", t.side_colours["east"])
		print("  S:", t.side_colours["south"])
		print("  W:", t.side_colours["west"])

func build_puzzle_data() -> PuzzleData:
	var puzzle := PuzzleData.new()
	puzzle.puzzle_name = "generated_%s" % Time.get_datetime_string_from_system()
	puzzle.tiles = generated_tiles.duplicate(true)
	
	puzzle.board_size = Vector2(unit_grid_size) * unit_world_size
	
	puzzle.board_colours = {
		"north": _frame_north(),
		"south": _frame_south(),
		"west":  _frame_west(),
		"east":  _frame_east()
	}
	
	return puzzle
