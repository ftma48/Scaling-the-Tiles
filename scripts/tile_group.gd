extends Node2D

var tiles: Array = []

func add_tile(tile: Area2D):
	if tile not in tiles:
		print("Adding tile:", tile) 
		tiles.append(tile)
		tile.reparent(self)
		tile.group = self

func remove_tile(tile: Area2D):
	if tile in tiles:
		print("Removing tile:", tile)
		tiles.erase(tile)
		tile.group = null
		var tiles_parent = get_tree().get_root().get_node("Main/Tiles")
		if tiles_parent:
			tile.reparent(tiles_parent)
		else:
			push_warning("Could not find 'Main/Tiles' to reparent tile!")
		if tiles.is_empty():
			queue_free()

func get_tiles():
	print("Tiles in group:", tiles.size())  # Debugging print to track the number of tiles in the group
	return tiles


func get_size() -> Vector2:
	if tiles.is_empty():
		return Vector2.ZERO
	
	var min := Vector2.INF
	var max := -Vector2.INF
	
	for t in tiles:
		var half = t.tile_size / 2
		var p = t.position  # LOCAL position relative to group
		min = min.min(p - half)
		max = max.max(p + half)
		
	return max - min

func get_bounds() -> Rect2:
	# Returns the bounding rectangle of all tiles relative to the group origin
	if tiles.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var min := Vector2.INF
	var max := -Vector2.INF
	
	for t in tiles:
		var half = t.tile_size / 2
		var p = t.position  # LOCAL position inside group
		min = min.min(p - half)
		max = max.max(p + half)
	
	return Rect2(min, max - min)
	
func get_global_bounds() -> Rect2:
	if tiles.is_empty():
		return Rect2(global_position, Vector2.ZERO)
		
	var min := Vector2.INF
	var max := -Vector2.INF
	
	for t in tiles:
		var half = t.tile_size / 2
		var global_p = t.global_position
		min = min.min(global_p - half)
		max = max.max(global_p + half)
	
	return Rect2(min, max - min)
