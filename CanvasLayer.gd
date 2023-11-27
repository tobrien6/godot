extends CanvasLayer

func _ready():
	setup_login_form()
	setup_register_form()

func setup_login_form():
	var login_form = Control.new()
	login_form.name = "LoginForm"
	add_child(login_form)
	
	var username_input = LineEdit.new()
	username_input.name = "UsernameInput"
	username_input.rect_min_size = Vector2(200, 30)
	username_input.placeholder_text = "Username"
	login_form.add_child(username_input)

	var password_input = LineEdit.new()
	password_input.name = "PasswordInput"
	password_input.rect_min_size = Vector2(200, 30)
	password_input.placeholder_text = "Password"
	password_input.secret = true  # Hides the password input
	login_form.add_child(password_input)

	var submit_button = Button.new()
	submit_button.name = "SubmitButton"
	submit_button.text = "Login"
	submit_button.rect_min_size = Vector2(200, 30)
	login_form.add_child(submit_button)

func setup_register_form():
	var register_form = Control.new()
	register_form.name = "RegisterForm"
	add_child(register_form)
	
	var username_input = LineEdit.new()
	username_input.name = "NewUsernameInput"
	username_input.rect_min_size = Vector2(200, 30)
	username_input.placeholder_text = "New Username"
	register_form.add_child(username_input)

	var password_input = LineEdit.new()
	password_input.name = "NewPasswordInput"
	password_input.rect_min_size = Vector2(200, 30)
	password_input.placeholder_text = "New Password"
	password_input.secret = true  # Hides the password input
	register_form.add_child(password_input)

	var submit_button = Button.new()
	submit_button.name = "RegisterButton"
	submit_button.text = "Register"
	submit_button.rect_min_size = Vector2(200, 30)
	register_form.add_child(submit_button)
