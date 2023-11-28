extends Node2D

const CHUNK_SIZE = 64  # This should match the server's chunk size

var user_token : String

var socket = WebSocketPeer.new()
var tile_map : TileMap
@onready var player_scene = preload("res://player.tscn")
@onready var local_player : Node2D
var loaded_chunks = {}  # Dictionary to keep track of loaded chunks
var viewport_buffer = 1  # Buffer around the viewport to preload chunks
var viewport_size

# Dictionary to keep track of player nodes
var players = {}

# Define a mapping from the server's integer identifiers to the TileSet atlas coordinates
var server_id_to_atlas_coords = {
	1: Vector2i(5, 1),  # Grass
	5: Vector2i(3, 0),  # Tree
	# Add other tiles as needed
}

func get_chunk_coords(global_coords):
	# Convert global coordinates to chunk coordinates based on the chunk size
	return Vector2(floor(global_coords.x / CHUNK_SIZE), floor(global_coords.y / CHUNK_SIZE))

func _ready():
	tile_map = $TileMap  
	tile_map.scale = Vector2(3,3)  # Scale the tilemap by 2x
	viewport_size = get_viewport_rect().size
	socket.connect_to_url("ws://localhost:6789")
	var state = socket.get_ready_state()
	while state == WebSocketPeer.STATE_CONNECTING:
		state = socket.get_ready_state() 
		socket.poll()
	socket.send_text(JSON.stringify({"token": user_token}))
	initialize_player()
	update_chunks()

func initialize_player():
	socket.send_text(JSON.stringify({"action": "InitializePlayer"}))

func update_chunks():
	# note this need not be done every move. Server should be able to send when needed
	#print("updating chunks")
	var visible_tiles = get_visible_tiles()
	var visible_chunks = get_visible_chunks_from_tiles(visible_tiles)
	request_missing_chunks(visible_chunks)
	unload_distant_chunks(visible_chunks)
	
func get_visible_tiles() -> Array:
	var visible_tiles = []
	var camera = $Player/Camera2D  # Adjust the path to your Camera2D node
	var screen_center = camera.get_screen_center_position()
	var half_screen_size = viewport_size / 2

	# Convert screen space to the TileMap's local space
	var top_left_local = tile_map.to_local(screen_center - half_screen_size)
	var bottom_right_local = tile_map.to_local(screen_center + half_screen_size)

	# Use the local coordinates to get the map coordinates
	var top_left = tile_map.local_to_map(top_left_local)
	var bottom_right = tile_map.local_to_map(bottom_right_local)
	"""
	# Calculate the top-left and bottom-right corners of the visible area
	var top_left = tile_map.local_to_map(screen_center - half_screen_size)
	var bottom_right = tile_map.local_to_map(screen_center + half_screen_size)
	"""
	#print(top_left, bottom_right)
	#print(screen_center)

	# Iterate over the tiles in the visible area
	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var tile = Vector2(x, y)
			visible_tiles.append(tile)

	return visible_tiles
	
func get_visible_chunks_from_tiles(visible_tiles):
	var chunks = {}
	# Note this is inefficient, only needs to look at bounds
	for tile in visible_tiles:
		var chunk_coords = get_chunk_coords(tile)
		chunks[chunk_coords] = true
	return chunks.keys()

func request_missing_chunks(visible_chunks)	:
	for chunk_coords in visible_chunks:
		if not loaded_chunks.has(chunk_coords):
			request_chunk(chunk_coords)
			loaded_chunks[chunk_coords] = "requested"
			
func unload_distant_chunks(visible_chunks):
	var chunks_to_unload = []
	for loaded_chunk in loaded_chunks.keys():
		if not visible_chunks.has(loaded_chunk):
			chunks_to_unload.append(loaded_chunk)
	
	for chunk_coords in chunks_to_unload:
		unload_chunk(chunk_coords)
		loaded_chunks.erase(chunk_coords)
		
func request_chunk(chunk_coords):
	# Send a request to the server for the chunk at chunk_coords
	print("requesting chunk: " + str(chunk_coords))
	var message = {
		"action": "GetChunk",
		"x": chunk_coords.x,
		"y": chunk_coords.y
	}
	socket.send_text(JSON.stringify(message))
	
func unload_chunk(chunk_coords):
	# Unload the chunk at chunk_coords from the TileMap
	# This would involve clearing the tiles from the tile map that correspond to this chunk
	# ...
	pass

func _process(delta):
	# this websocket polling might not be necessary if we define a
	#  callback like network.Connect("data_received", this, "_DataReceived");
	socket.poll()
	viewport_size = get_viewport_rect().size # this should be a callback on size change
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
	
	# Movement
	"""
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		send_move_command(player.map_coords() + Vector2i(0, -1))
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		send_move_command(player.map_coords() + Vector2i(0, 1))
	elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		send_move_command(player.map_coords() + Vector2i(-1, 0))
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		send_move_command(player.map_coords() + Vector2i(1, 0))
	elif Input.is_key_pressed(KEY_E):
		send_move_command(player.map_coords() + Vector2i(1, 1))
	elif Input.is_key_pressed(KEY_Q):
		send_move_command(player.map_coords() + Vector2i(-1, 1))
	elif Input.is_key_pressed(KEY_C):
		send_move_command(player.map_coords() + Vector2i(1, -1))
	elif Input.is_key_pressed(KEY_Z):
		send_move_command(player.map_coords() + Vector2i(-1, -1))
	"""

func spawn_player(player_id):
	var new_player = Player.instance() # Assuming you have a Player scene to instance
	new_player.set_name("Player_" + str(player_id)) # Set a unique name to the player node using their player_id
	add_child(new_player)
	players[player_id] = new_player

func handle_message(data):
	var response = JSON.parse_string(data)
	#print(response)
	match response.action:
		"PlayerMoved":
			print(response)
			var player_id = response["player_id"]
			var x = response["x"]
			var y = response["y"]
			if not players.has(player_id):
				# Spawn the player node for the other player
				spawn_player(player_id)
				players[player_id].move_to_tile(x, y)
			else:
				players[player_id].move_to_tile(response["x"], response["y"])
		"ChunkData":
			#print("received new chunk")
			print(response["chunk_x"], response["chunk_y"])
			load_chunk(response)
		# ... (handle other actions)
		"InitializePlayer":
			print(response)
			var player_id = response["player_id"]
			spawn_player(player_id)
			local_player = players[player_id]
			players[player_id].move_to_tile(response["x"], response["y"])
		
func load_chunk(chunk_data):
	# Assuming chunk_data contains 'tiles' that is a nested list of tile data
	# and 'chunk_coords' which is the position of the chunk
	var layer = 0
	var source_id = 0
	var chunk_x = chunk_data.chunk_x
	var chunk_y = chunk_data.chunk_y
	#print(chunk_x, chunk_y)
	for x in range(len(chunk_data.tiles)):
		for y in range(len(chunk_data.tiles[x])):
			var tile = chunk_data.tiles[x][y]
			var atlas_coords = server_id_to_atlas_coords[int(tile)]
			# Convert local chunk tile coordinates to global tilemap coordinates
			var tilemap_coords = Vector2(x + chunk_x * CHUNK_SIZE, y + chunk_y * CHUNK_SIZE)
			tile_map.set_cell(layer, tilemap_coords, source_id, atlas_coords)


# NEED TO CREATE NEW TILE_POSITION ATTRIBUTE FOR PLAYER OBJECT
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.get_key_label() == KEY_UP or event.get_key_label() == KEY_W:
			send_move_command(local_player.map_coords() + Vector2i(0, -1))
		elif event.get_key_label() == KEY_DOWN or event.get_key_label() == KEY_S:
			send_move_command(local_player.map_coords() + Vector2i(0, 1))
		elif event.get_key_label() == KEY_LEFT or event.get_key_label() == KEY_A:
			send_move_command(local_player.map_coords() + Vector2i(-1, 0))
		elif event.get_key_label() == KEY_RIGHT or event.get_key_label() == KEY_D:
			send_move_command(local_player.map_coords() + Vector2i(1, 0))
		elif event.get_key_label() == KEY_E:
			send_move_command(local_player.map_coords() + Vector2i(1, -1))
		elif event.get_key_label() == KEY_Q:
			send_move_command(local_player.map_coords() + Vector2i(-1, -1))
		elif event.get_key_label() == KEY_C:
			send_move_command(local_player.map_coords() + Vector2i(1, 1))
		elif event.get_key_label() == KEY_Z:
			send_move_command(local_player.map_coords() + Vector2i(-1, 1))


func send_move_command(tile_xy):
	# update map if need be
	update_chunks()
	#print("sending move command" + str(tile_xy))
	var message = {
		"action": "MovePlayerToTile",
		"tile_xy": [tile_xy.x, tile_xy.y]
	}
	socket.send_text(JSON.stringify(message))
