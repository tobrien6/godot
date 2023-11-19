extends Node2D

var socket = WebSocketPeer.new()
var tile_map : TileMap
var player_id = "1"  # This should be uniquely generated for each player in a real game
var loc = Vector2(0,0)

# Define a mapping from the server's integer identifiers to the TileSet atlas coordinates
var server_id_to_atlas_coords = {
	1: Vector2i(5, 1),  # Grass
	5: Vector2i(3, 0),  # Tree
	# Add other tiles as needed
}

func _ready():
	print("ready")
	tile_map = $TileMap  # Assign your TileMap node here
	tile_map.scale = Vector2(4,4)  # Scale the tilemap by 2x
	# Scale the character sprite
	var character = $Player  # Make sure this path is correct to your character node
	character.scale = Vector2(4,4)  # This assumes the character node contains the sprite
	socket.connect_to_url("ws://localhost:6789")
	
	"""
	var os_size = OS.window_size
	var tile_size = Vector2(16, 16)  # Replace with your actual tile size
	var num_horizontal_tiles = os_size.x / tile_size.x
	var num_vertical_tiles = os_size.y / tile_size.y

	# Adjust the camera's zoom level to show more or fewer tiles based on screen size
	var camera = Camera2D.new()
	camera.zoom = Vector2(num_horizontal_tiles / base_num_horizontal_tiles, num_vertical_tiles / base_num_vertical_tiles)
	add_child(camera)

	# Load or create tiles based on the calculated number
	load_tiles(num_horizontal_tiles, num_vertical_tiles)
	"""

func load_tiles(num_horizontal_tiles, num_vertical_tiles):
	# Your tile loading or generating logic here
	pass

func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			if socket.was_string_packet():
				handle_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.

func create_new_player():
	print("creating player")
	var message = {"action": "CreateNewPlayer", "player_id": player_id}
	socket.send_text(JSON.stringify(message))
	print("creating player msg sent")

func request_map():
	var message = {"action": "RequestMap",
				   "player_id": player_id,
				   "cur_loc": [loc.x, loc.y]}
	socket.send_text(JSON.stringify(message))

func handle_message(data):
	var response = JSON.parse_string(data)
	print("response: " + str(response))
	match response.action:
		"PlayerMoved":
			loc = Vector2(response["result"]["x"], response["result"]["y"])
		"MapData":
			# update tilemap node
			load_map(response.map_data)

func load_map(map_data):
	# Assuming map_data is an array of dictionaries with keys 'x', 'y', and 'type'
	# and 'layer' is the layer of the TileMap where you want to set the tiles
	var layer = 0
	for tile_data in map_data:
		var atlas_coords = server_id_to_atlas_coords[int(tile_data.type)]
		var coords = Vector2i(tile_data.x, tile_data.y)

		# Assuming the source_id for your atlas is 0, which is common if you have a single atlas
		var source_id = 0

		# Set the cell on the TileMap
		$TileMap.set_cell(layer, coords, source_id, atlas_coords)

func update_map(diff):
	for change in diff:
		var tile_index = 0  # Replace with your logic to determine new tile index
		tile_map.set_cell(change.x, change.y, tile_index)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.get_key_label() == KEY_C:
			create_new_player()
		if event.get_key_label() == KEY_M:
			request_map()
		if event.get_key_label() == KEY_UP:
			var tile_xy = Vector2(loc.x, loc.y - 1)
			send_move_command(tile_xy)
		elif event.get_key_label() == KEY_DOWN:
			var tile_xy = Vector2(loc.x, loc.y + 1)
			send_move_command(tile_xy)
		elif event.get_key_label() == KEY_LEFT:
			var tile_xy = Vector2(loc.x - 1, loc.y)
			send_move_command(tile_xy)
		elif event.get_key_label() == KEY_RIGHT:
			var tile_xy = Vector2(loc.x + 1, loc.y)
			send_move_command(tile_xy)

func send_move_command(tile_xy):
	print("sending move command")
	var message = {
		"action": "MovePlayerToTile",
		"player_id": player_id,
		"tile_xy": [tile_xy.x, tile_xy.y]
	}
	socket.send_text(JSON.stringify(message))
