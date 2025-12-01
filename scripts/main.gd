extends Node2D

@onready var tiles = $Tiles
@onready var tile_scene = preload("res://scenes/tile.tscn")

var colours = ["red", "blue", "green", "yellow"]

var tile_size: Vector2 = Vector2(100,100)
var tile_size2: Vector2 = Vector2(100,100)

var side_clrs = {
		"north" = [colours.pick_random(), colours.pick_random()],
		"east" = [colours.pick_random()],
		"south" = [colours.pick_random()],
		"west" = [colours.pick_random()]
		}
		

func _ready():
	init_game()

func init_game():
	generate_tiles()

func generate_tiles():
	tile_size = Vector2(120,120)
	tile_size2 = Vector2(60,60)	
	for i in range(0,4):
		var tile = tile_scene.instantiate()
		tiles.add_child(tile)
		G.tiles.append(tile)
		var pos
		randomize()
		pos = Vector2(
				randi_range(100, 900),
				randi_range(100, 900)
			)
			
		var side_colours = {
		"north" = [colours.pick_random(), colours.pick_random()],
		"east" = [colours.pick_random()],
		"south" = [colours.pick_random()],
		"west" = [colours.pick_random()]
		}
		
		tile.init_tile(
			pos,
			tile_size,
			side_colours
		)
		
	for i in range(0,4):
		var tile = tile_scene.instantiate()
		tiles.add_child(tile)
		G.tiles.append(tile)
		var pos
		randomize()
		pos = Vector2(
				randi_range(100, 900),
				randi_range(100, 900)
			)
			
		var side_colours = {
		"north" = [colours.pick_random(), colours.pick_random()],
		"east" = [colours.pick_random()],
		"south" = [colours.pick_random()],
		"west" = [colours.pick_random()]
		}
		
		tile.init_tile(
			pos,
			tile_size2,
			side_colours
		)
