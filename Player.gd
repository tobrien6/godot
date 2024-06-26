extends Node2D

var tile_map : TileMap
var root : Node2D

var x
var y

var is_targeting = false

var cur_ability = ""
var cur_target : Vector2i

var tab_target_index = -1
var legal_targets = []

var abilities = {}

var health = 100
var ap : float
var ap_per_tick : float
var ms_per_tick : float
var ms_since_last_tick = 0.0

var ability_ranges = {
	"stab": {"targeting_range": 1, "effect_range": 0},
	"fireball": {"targeting_range": 10, "effect_range": 1}
}

var hotkeys = [KEY_1, KEY_2, KEY_3, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
var ability_hotkeys = {}

@onready var health_bar = $HealthBar

# Called when the node enters the scene tree for the first time.
func _ready():
	tile_map = get_node("/root/Root/TileMap")
	root = get_node("/root/Root/")
	scale = Vector2(3,3)
	health_bar.max_value = 100  # Assuming max health is 100
	health_bar.value = health  # Assuming 'health' is the current health of the player

func _process(delta):
	update_ap(delta)
	update_health_bar()

func update_health_bar():
	health_bar.value = health

func update_ap(delta):
	# note this only updates per tick, while server is continuous
	var ms = delta * 1000
	ms_since_last_tick += ms
	if ms_since_last_tick >= ms_per_tick:
		ap += ap_per_tick
		ms_since_last_tick = ms_since_last_tick - ms_per_tick
		
func get_ap():
	if ap:
		return ap
	else:
		return 0

func add_hotkey(i, name):
	ability_hotkeys[hotkeys[i]] = name

func is_within_range(pos: Vector2i, range: int):
	if chebyshev_distance(Vector2i(x, y), pos) <= range:
		return true
	else:
		return false

func chebyshev_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	return max(abs(pos1.x - pos2.x), abs(pos1.y - pos2.y))

func move_to_tile(x_coord, y_coord):
	x = x_coord
	y = y_coord
	var map_coord = Vector2i(x_coord, y_coord)
	var local_pixel_coords = tile_map.map_to_local(map_coord)
	var global_pixel_coords = tile_map.to_global(local_pixel_coords)
	position = global_pixel_coords

func pos():
	return Vector2i(x, y)
	
func cur_targeting_range():
	if cur_ability != "":
		return ability_ranges[cur_ability]["targeting_range"]
	else:
		return 0
	
func update_legal_targets():
	var entities = root.PLAYERS.values()
	print(entities)
	legal_targets = get_sorted_entities_by_distance(entities, pos(), cur_targeting_range())
	tab_target_index = -1  # Reset target index

func cycle_through_targets():
	if legal_targets.size() == 0:
		return null

	tab_target_index += 1
	if tab_target_index >= legal_targets.size():
		update_legal_targets()
		tab_target_index = 0

	cur_target = legal_targets[tab_target_index].pos()
	return cur_target
				
func get_entities_within_range(entities, center: Vector2i, range: int) -> Array:
	var entities_in_range = []
	for entity in entities:
		if chebyshev_distance(center, entity.pos()) <= range:
			entities_in_range.append(entity)
	return entities_in_range

func get_sorted_entities_by_distance(entities, center: Vector2i, range: int) -> Array:
	var lambda = func compare_by_distance(a, b) -> int:
		var distance_a = chebyshev_distance(center, a.pos())
		var distance_b = chebyshev_distance(center, b.pos())
		return distance_a - distance_b

	var wr = get_entities_within_range(entities, center, range)
	wr.sort_custom(lambda)
	return wr
