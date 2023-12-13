extends HBoxContainer

func _ready():	
	pass

func make_ability_buttons(abilities):
	var hotkey = 1
	for but_name in abilities:
		# make a new button
		var button = Button.new()
		button.add_theme_font_size_override("font_size", 25)
		# set the text
		button.text = str(but_name) + "\n" + str(hotkey)
		hotkey += 1
		# add it to the container
		add_child(button)
		# set the minimum size
		button.custom_minimum_size.x = 150
		button.custom_minimum_size.y = 100
		# connect the pressed signal
		#button.connect("pressed", self, "button_pressed") 
