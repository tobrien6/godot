extends HBoxContainer


func _ready():
	# Set the marginst
	offset_bottom = -5 # This will add space to the bottom

	# Loop through each Button child
	for button in get_children():
		if button is Button:  # Make sure it's a Button
			# Set the minimum size to the desired width and current height
			button.custom_minimum_size.x = 100  # Replace 100 with your desired width
			# If you want to also set a specific height, you can do so:
			# button.rect_min_size.y = 50  # Replace 50 with your desired height
