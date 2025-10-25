extends Node2D

@onready var cells = $Cells
@onready var cell_scene = preload("res://scenes/cell.tscn")

@onready var tiles = $Tiles
@onready var tile_scene = preload("res://scenes/tile.tscn")

#var tile_size: Vector2 = Vector2.ZERO
var tile_size: Vector2 = Vector2(100,100)


func _ready():
	init_game()

func init_game():
	generate_tiles()
	draw_cells()

#create grid of size grid_size and fill it with cells
func draw_cells():
	for i in range(G.grid_size.x):
		for j in range(G.grid_size.y):
			add_cell(i, j)

func add_cell(i, j):
	#create cell in cell scene for each index in grid size
	var cell = cell_scene.instantiate()
	cells.add_child(cell)
	G.cells.append(cell)
	cell.position = Vector2(
		int(tile_size.x) * i,
		int(tile_size.y) * j
	)
	#create and index cells
	var idx = int(i * G.grid_size.x) + j
	cell.init_cell(idx, tile_size)

func generate_tiles():
	var image = Image.load_from_file("res://images/white square.png")
	var texture = ImageTexture.create_from_image(image)
	tile_size = Vector2(image.get_width(), image.get_height())
	
	for i in range(G.grid_size.x):
		for j in range(G.grid_size.y):
			var tile = tile_scene.instantiate()
			tiles.add_child(tile)
			G.tiles.append(tile)
			var region = Rect2(i * tile_size.x, j * tile_size.y, tile_size.x, tile_size.y)
			var pos
			var index = int(i * G.grid_size.x + j)
			
			randomize()
			if index < (G.grid_size.x * G.grid_size.y) / 2:
				pos = Vector2(
					randi_range(100, 200),
					randi_range(400, 700)
				)
			else:
				pos = Vector2(
					randi_range(700, 900),
					randi_range(200, 800)
				)
			
			tile.init_tile(
				index,
				texture,
				pos,
				tile_size
			)
