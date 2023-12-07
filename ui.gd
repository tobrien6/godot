extends HBoxContainer

func _ready():	
	"""
	# Loop through each Button child
	for button in get_children():
		if button is Button:  # Make sure it's a Button
			# Set the minimum size to the desired width and current height
			button.custom_minimum_size.x = 100  # Replace 100 with your desired width
			# If you want to also set a specific height, you can do so:
			# button.rect_min_size.y = 50  # Replace 50 with your desired height
	"""
	# make a variable for the local player
	
"""
for a in abilities:
	local_player.abilities[name] = {
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
	# make a variable for the node with path CanvasLayer/HBoxContainer
	var hbox = get_node("CanvasLayer/HBoxContainer")
	hbox.make_ability_buttons(local_player.abilities)
"""


func make_ability_buttons(abilities):
	var hotkey = 1
	for name in abilities:
		var ability = abilities[name]
		# make a new button
		var button = Button.new()
		button.add_theme_font_size_override("font_size", 25)
		# set the text
		button.text = str(name) + "\n" + str(hotkey)
		hotkey += 1
		# add it to the container
		add_child(button)
		# set the minimum size
		button.custom_minimum_size.x = 150
		button.custom_minimum_size.y = 100
		# connect the pressed signal
		#button.connect("pressed", self, "button_pressed") 
