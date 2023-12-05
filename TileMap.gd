extends TileMap


# Called when the node enters the scene tree for the first time.
func _ready():
	set_layer_modulate(1, Color(1, 1, 1, 0.2)) # make highlight options layer transparent
	set_layer_modulate(2, Color(1, 1, 1, 0.1)) # make highlighted layer less transparent


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func mouse_tile_pos():
	var mouse_pos = get_global_mouse_position()
	var local_pos = to_local(mouse_pos)
	return local_to_map(local_pos)
