extends CanvasLayer

# Signals to emit on authentication outcomes
signal login_success(token)
signal auth_failure(message)

var password_input_register
var username_input_register
var username_input_login
var password_input_login

var http_request : HTTPRequest

func _ready():
	setup_forms()
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_request_completed)
	
	# Connect the signal to a local method
	connect("login_success", Callable(self, "_on_user_logged_in"))

func setup_forms():
	var center_container = CenterContainer.new()  # This will center its child horizontally and vertically
	center_container.custom_minimum_size = Vector2(1200, 600)  # Adjust the size as needed	
	add_child(center_container)
	
	center_container.anchor_left = 0  # Anchor to the left edge of the parent (or the window if it's a top-level node)
	center_container.anchor_top = 0  # Anchor to the top edge of the parent
	center_container.anchor_right = 1  # Anchor to the right edge of the parent
	center_container.anchor_bottom = 1 

	var hbox = HBoxContainer.new()  # This will arrange its children horizontally
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = 1
	hbox.add_theme_constant_override("separation", 10)
	center_container.add_child(hbox)

	# Set up the login form
	var login_vbox = setup_login_form()
	hbox.add_child(login_vbox)

	# Set up the registration form
	var register_vbox = setup_register_form()
	hbox.add_child(register_vbox)

	# Adjust the spacing between the HBoxContainer's children
	#hbox.custom_constants_separation = 50  # Adjust the separation as needed

func setup_login_form():
	var login_vbox = VBoxContainer.new()
	login_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	username_input_login = LineEdit.new()	
	username_input_login.name = "UsernameInput"
	username_input_login.custom_minimum_size = Vector2(600, 90)  # Increase size
	username_input_login.placeholder_text = "Username"
	username_input_login.add_theme_font_size_override("font_size", 30)
	login_vbox.add_child(username_input_login)

	password_input_login = LineEdit.new()
	password_input_login.name = "PasswordInput"
	password_input_login.custom_minimum_size = Vector2(600, 90)  # Increase size
	password_input_login.placeholder_text = "Password"
	password_input_login.add_theme_font_size_override("font_size", 30)
	password_input_login.secret = true
	login_vbox.add_child(password_input_login)

	var submit_button = Button.new()
	submit_button.connect("pressed", Callable(self, "_on_login_pressed"))
	submit_button.name = "SubmitButton"
	submit_button.text = "Login"
	submit_button.add_theme_font_size_override("font_size", 30)
	submit_button.custom_minimum_size = Vector2(600, 90)  # Increase size
	login_vbox.add_child(submit_button)

	return login_vbox

func setup_register_form():
	var register_vbox = VBoxContainer.new()
	register_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	username_input_register = LineEdit.new()
	username_input_register.name = "NewUsernameInput"
	username_input_register.custom_minimum_size = Vector2(600, 90)  # Increase size
	username_input_register.placeholder_text = "New Username"
	username_input_register.add_theme_font_size_override("font_size", 30)
	register_vbox.add_child(username_input_register)

	password_input_register = LineEdit.new()	
	password_input_register.name = "NewPasswordInput"
	password_input_register.custom_minimum_size = Vector2(600, 90)  # Increase size
	password_input_register.placeholder_text = "New Password"
	password_input_register.add_theme_font_size_override("font_size", 30)
	password_input_register.secret = true
	register_vbox.add_child(password_input_register)

	var submit_button = Button.new()
	submit_button.connect("pressed", Callable(self, "_on_register_pressed"))
	submit_button.name = "RegisterButton"
	submit_button.text = "Register"
	submit_button.add_theme_font_size_override("font_size", 30)
	submit_button.custom_minimum_size = Vector2(600, 90)  # Increase size
	register_vbox.add_child(submit_button)

	return register_vbox

func _on_login_pressed():
	var username = username_input_login.text
	var password = password_input_login.text
	var auth_info = {
		"username": username,
		"password": password
	}
	send_auth_request("/login", auth_info)

func _on_register_pressed():
	var username = username_input_register.text
	var password = password_input_register.text
	var auth_info = {
		"username": username,
		"password": password
	}
	send_auth_request("/register", auth_info)

func send_auth_request(endpoint, auth_info):
	var url = "http://127.0.0.1:5000" + endpoint
	var body = JSON.stringify(auth_info)
	
	# Perform the HTTP POST request
	var error = http_request.request(
		url,
		["Content-Type: application/json"], # Custom headers
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		print("An error occurred when trying to send the request. Error: " + str(error))
		return

func _on_request_completed(_result, _response_code, _headers, body):
	# Handle the response
	var response_text = body.get_string_from_utf8()
	var data = JSON.parse_string(response_text)
	print(data)
	if data.has("token"):
		emit_signal("login_success", data.token)
	else:
		emit_signal("auth_failure", data.message)

func _on_user_logged_in(token):
	# This method is called when the signal is emitted

	# Instance the new scene
	var new_scene = load("res://root.tscn").instantiate()

	# Set the token on the new scene
	# Assuming the new scene has a script with a property called 'user_token'
	new_scene.user_token = token

	# Save a reference to the old scene
	var old_scene = get_tree().current_scene

	# Change to the new scene by setting the current_scene property
	#get_tree().current_scene = new_scene
	get_tree().root.add_child(new_scene)

	# Now remove the old scene
	if old_scene:
		old_scene.queue_free()
