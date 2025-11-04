extends Node2D

@onready var cells = $Cells
@onready var cell_scene = preload("res://scenes/cell.tscn")

@onready var tiles = $Tiles
@onready var tile_scene = preload("res://scenes/tile.tscn")

var colours = ["red", "blue", "green", "yellow"]

var tile_size: Vector2 = Vector2(100,100)

func _ready():
	init_game()

func init_game():
	generate_tiles()

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
			pos = Vector2(
					randi_range(100, 900),
					randi_range(100, 900)
				)
				
			var side_colours = {
			"north" = [colours.pick_random(), colours.pick_random(), colours.pick_random(), colours.pick_random()],
			"east" = [colours.pick_random()],
			"south" = [colours.pick_random()],
			"west" = [colours.pick_random()]
			}
			
			tile.init_tile(
				index,
				texture,
				pos,
				tile_size,
				side_colours
			)
