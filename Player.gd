extends Node2D

var tile_map : TileMap

var x
var y

# Called when the node enters the scene tree for the first time.
func _ready():
	tile_map = get_node("/root/Root/TileMap")
	scale = Vector2(3,3)

func move_to_tile(x_coord, y_coord):
	x = x_coord
	y = y_coord
	var map_coord = Vector2i(x_coord, y_coord)
	var local_pixel_coords = tile_map.map_to_local(map_coord)
	var global_pixel_coords = tile_map.to_global(local_pixel_coords)
	position = global_pixel_coords

func map_coords():
	return Vector2i(x, y)
