extends Node2D

const CHUNK_SIZE = 64  # This should match the server's chunk size

var user_token : String

var socket = WebSocketPeer.new()
var tile_map : TileMap
@onready var player = preload("res://player.tscn")
@onready var local_player : Node2D
var loaded_chunks = {}  # Dictionary to keep track of loaded chunks
var viewport_buffer = 1  # Buffer around the viewport to preload chunks
var viewport_size

var tab_targeting = false

# Dictionary to keep track of player nodes
var PLAYERS = {}

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

func initialize_player():
	socket.send_text(JSON.stringify({"action": "InitializePlayer"}))

func update_chunks(local_player):
	# note this need not be done every move. Server should be able to send when needed
	#print("updating chunks")
	var visible_tiles = get_visible_tiles(local_player)
	var visible_chunks = get_visible_chunks_from_tiles(visible_tiles)
	request_missing_chunks(visible_chunks)
	unload_distant_chunks(visible_chunks)
	
func get_visible_tiles(local_player) -> Array:
	var visible_tiles = []
	var screen_center = local_player.get_node("PlayerCamera").get_screen_center_position()
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
		
	if local_player and local_player.is_targeting:
		highlight_targetable_cells()
		if not tab_targeting:
			handle_targeting_mode()
			
	if local_player:
		local_player.update_ap(delta)

func handle_targeting_mode():
	var tile_pos = tile_map.mouse_tile_pos()
	local_player.cur_target = tile_pos
	var ability = local_player.cur_ability
	var ranges = local_player.ability_ranges
	var highlight_range = ranges[ability]["targeting_range"]
	var effect_range = ranges[ability]["effect_range"]
	highlight_tiles_around(tile_pos, highlight_range, effect_range)

func highlight_targetable_cells():
	clear_highlights(2)  # Ensure any previous highlights are cleared
	var player_pos = Vector2i(local_player.x, local_player.y)
	var highlight_range = local_player.ability_ranges[local_player.cur_ability]["targeting_range"]

	for x in range(-highlight_range, highlight_range + 1):
		for y in range(-highlight_range, highlight_range + 1):
			var tile_pos = player_pos + Vector2i(x, y)
			if chebyshev_distance(tile_pos, player_pos) <= highlight_range:
				# Assuming Vector2i(1, 0) is the atlas coordinate for in-range highlight
				highlight_tile(2, tile_pos, Vector2i(1, 0))
	
func highlight_tiles_around(center_tile, highlight_range, effect_range):
	# This function highlights the tiles around the center tile
	# effect_range is the range of the ability's effect
	# highlight_range is the range of the ability's targeting
	clear_highlights(1)  # Function to clear existing highlights
	var player_pos = Vector2i(local_player.x, local_player.y)
	var atlas_coords
	if chebyshev_distance(center_tile, player_pos) <= highlight_range:
		atlas_coords = Vector2i(1, 0) # green
	else:
		atlas_coords = Vector2i(0, 0) # red
	for x in range(-effect_range, effect_range + 1):
		for y in range(-effect_range, effect_range + 1):
			var tile_pos = center_tile + Vector2i(x, y)
			if chebyshev_distance(tile_pos, center_tile) <= highlight_range:
				pass
				highlight_tile(1, tile_pos, atlas_coords)  # Function to highlight a single tile
	
func highlight_tile(layer, tile_pos: Vector2i, atlas_coords, source_id=1):
	tile_map.set_cell(layer, tile_pos, source_id, atlas_coords)
	
func clear_highlights(layer, source_id=1):
	for cell in tile_map.get_used_cells_by_id(layer, source_id):
		# clear layer
		tile_map.set_cell(layer, cell, -1)  # Reset cell to clear highlight

func chebyshev_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	return max(abs(pos1.x - pos2.x), abs(pos1.y - pos2.y))

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

func handle_message(data):
	var response = JSON.parse_string(data)
	match response.action:
		"PlayerLoc":
			print(response)
			var player_id = response["player_id"]
			var x = response["x"]
			var y = response["y"]
			local_move_player(player_id, x, y)
		"PlayerHealth":
			print(response)
			var player_id = response["player_id"]
			var health = response["health"]
			set_health(player_id, health)
		"PlayerAP":
			print(response)
			var player_id = response["player_id"]
			var ap = response["ap"]
			PLAYERS[player_id].ap = ap
		"ChunkData":
			print(response["chunk_x"], response["chunk_y"])
			load_chunk(response)
		"PlayerAbilities":
			print(response)
			var abilities = response["abilities"]
			var hotkey_idx = 0
			for a in abilities:
				print(a["name"])
				local_player.abilities[a["name"]] = {
					"ap_cost": a["ap_cost"],
					"cooldown_in_ticks": a["cooldown_in_ticks"],
					"last_used_ts": a["last_used_ts"],
					"ability_range": a["ability_range"],
					"effect_range": a["effect_range"],
					"min_charges": a["min_charges"],
					"max_charges": a["max_charges"],
					"charges": a["charges"],
					"damage_amt": a["damage_amt"],
					"damage_type": a["damage_type"]
				}
				local_player.add_hotkey(hotkey_idx, a["name"])
				hotkey_idx += 1
			var hbox = get_node("./Control/CanvasLayer/HBoxContainer")
			hbox.make_ability_buttons(local_player.abilities)
		"InitializePlayer":
			print(response)
			var player_id = response["player_id"]
			var health = response["health"]
			spawn_player(player_id)
			set_health(player_id, health)
			local_player = PLAYERS[player_id]
			# set ap, ap_per_tick, ms_per_tick, health
			local_player.ap = response["action_points"]
			local_player.ap_per_tick = response["ap_per_tick"]
			local_player.ms_per_tick = response["ms_per_tick"]
			PLAYERS[player_id].move_to_tile(response["x"], response["y"])
			attach_camera(local_player)
			update_chunks(local_player)
			# spawn other players
			var other_players = response["other_players"]
			batch_spawn_players(other_players)
			
func set_health(player_id, health):
	PLAYERS[player_id].health = health
			
func spawn_player(player_id):
	var new_player = player.instantiate() # Assuming you have a Player scene to instance
	new_player.set_name("Player_" + str(player_id)) # Set a unique name to the player node using their player_id
	add_child(new_player)
	PLAYERS[player_id] = new_player
			
func local_move_player(player_id, x, y):
	if not PLAYERS.has(player_id):
		# Spawn the player node for the other player
		spawn_player(player_id)
		PLAYERS[player_id].move_to_tile(x, y)
	else:
		PLAYERS[player_id].move_to_tile(x, y)
			
func batch_spawn_players(player_list):
	for p in player_list:
		var player_id = p["player_id"]
		var x = p["x"]
		var y = p["y"]
		var health = p["health"]
		local_move_player(player_id, x, y)
		set_health(player_id, health)

func attach_camera(local_player):
	var camera = Camera2D.new()
	camera.enabled = true  # Make this camera the active camera for the viewport
	camera.name = "PlayerCamera" 
	camera.position = Vector2(0, 0)
	camera.position_smoothing_enabled = true
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	local_player.add_child(camera)

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
			send_move_command(local_player.pos() + Vector2i(0, -1))
		elif event.get_key_label() == KEY_DOWN or event.get_key_label() == KEY_S:
			send_move_command(local_player.pos() + Vector2i(0, 1))
		elif event.get_key_label() == KEY_LEFT or event.get_key_label() == KEY_A:
			send_move_command(local_player.pos() + Vector2i(-1, 0))
		elif event.get_key_label() == KEY_RIGHT or event.get_key_label() == KEY_D:
			send_move_command(local_player.pos() + Vector2i(1, 0))
		elif event.get_key_label() == KEY_E:
			send_move_command(local_player.pos() + Vector2i(1, -1))
		elif event.get_key_label() == KEY_Q:
			send_move_command(local_player.pos() + Vector2i(-1, -1))
		elif event.get_key_label() == KEY_C:
			send_move_command(local_player.pos() + Vector2i(1, 1))
		elif event.get_key_label() == KEY_Z:
			send_move_command(local_player.pos() + Vector2i(-1, 1))
			
		elif event.get_key_label() in local_player.ability_hotkeys.keys():
			var key = event.get_key_label()
			var mouse_pos = tile_map.mouse_tile_pos()
			var ability = local_player.ability_hotkeys[key]
			var ability_range = local_player.ability_ranges[ability]["targeting_range"]
			if local_player.is_targeting == true and local_player.cur_ability == ability:
				var target
				if local_player.is_within_range(mouse_pos, ability_range):
					# if mouse is on range, use that as target
					target = mouse_pos
				else:
					# if there are one or more entities in range target the closest and 
					# allow tab to switch between them
					pass
				
				var message = {
					"action": "UseTargetedAbility",
					"ability_name": ability,
					"x": local_player.cur_target[0],
					"y": local_player.cur_target[1]
				}
				socket.send_text(JSON.stringify(message))
				local_player.is_targeting = false
				clear_highlights(1)
				clear_highlights(2)
				clear_highlights(3, 2)
			else:
				local_player.is_targeting = true
				local_player.cur_ability = ability
				local_player.update_legal_targets()
				print("targeting")

		elif event.get_key_label() == KEY_TAB:
			tab_targeting = true
			if local_player.is_targeting:
				clear_highlights(3, 2) # clear previous target cell highlight
				var next_target = local_player.cycle_through_targets()
				print(next_target)
				highlight_tile(3, next_target, Vector2i(1,0), 2)
				var ranges = local_player.ability_ranges
				var ability = local_player.cur_ability
				var highlight_range = ranges[ability]["targeting_range"]
				var effect_range = ranges[ability]["effect_range"]
				highlight_tiles_around(next_target, highlight_range, effect_range)
				
		elif event.get_key_label() == KEY_ESCAPE:
			if local_player and local_player.is_targeting == true:
				print("exiting targeting")
				local_player.is_targeting = false
				local_player.cur_ability = ""
				tab_targeting = false
				clear_highlights(1)
				clear_highlights(2)
				clear_highlights(3, 2) # clear previous target cell highlight
				
				
				
func send_move_command(tile_xy):
	# update map if need be
	update_chunks(local_player)
	#print("sending move command" + str(tile_xy))
	var message = {
		"action": "MovePlayerToTile",
		"tile_xy": [tile_xy.x, tile_xy.y]
	}
	socket.send_text(JSON.stringify(message))
