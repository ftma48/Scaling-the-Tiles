extends Node2D

var tiles: Array = []

func debug_group_state():
	print("--- DEBUG GROUP STATE ---")
	print("Group:", name)
	print(" Global pos:", global_position)
	print(" Children count:", get_child_count())
	for c in get_children():
		print(" -", c.name, "| Local pos:", c.position, "| Global pos:", c.global_position)
	print("--------------------------")

func add_tile(tile: Area2D):
	if not tile in tiles:
		tiles.append(tile)
		tile.reparent(self)
	debug_group_state()

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
	debug_group_state()
