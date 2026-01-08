extends Node2D

var tiles: Array = []

func add_tile(tile: Area2D):
	if not tile in tiles:
		tiles.append(tile)
		tile.reparent(self)
func remove_tile(tile: Area2D):
	if tile in tiles:
		tiles.erase(tile)
		var tiles_parent = get_tree().get_root().get_node("Main/Tiles")
		if tiles_parent:
			tile.reparent(tiles_parent)
		else:
			push_warning("Could not find 'Main/Tiles' to reparent tile!")
		if tiles.is_empty():
			queue_free()

func get_size() -> Vector2:
	var min := Vector2.INF
	var max := -Vector2.INF
	
	for t in self.get_children():
		var half = t.tile_size / 2
		var p = t.global_position
		min = min.min(p - half)
		max = max.max(p + half)
		
	return max - min
