extends "res://model.gd"

@onready var sprite : Sprite2D = $Player/Sprite2D

var server_position: Vector2
var actor_name: String

var is_player: bool = false
var _player_target: Vector2

func update(new_model: Dictionary):
	super.update(new_model)
	
	var ientity = new_model["instanced_entity"]
	server_position = Vector2(float(ientity["x"]), float(ientity["y"]))
	actor_name = ientity["entity"]["name"]
