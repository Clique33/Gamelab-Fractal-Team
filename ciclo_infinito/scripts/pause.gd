extends Control

@onready var resume_button = $MarginContainer/VBoxContainer/MenuPrincipal/resumebutton
@onready var options_button = $MarginContainer/VBoxContainer/MenuPrincipal/optionsbutton
@onready var quit_button = $MarginContainer/VBoxContainer/MenuPrincipal/quitbutton
@onready var menu_principal = $MarginContainer/VBoxContainer/MenuPrincipal
@onready var menu_opcoes = $MarginContainer/VBoxContainer/MenuOpcoes
@onready var volume_slider = $MarginContainer/VBoxContainer/MenuOpcoes/HBoxContainer/VolumeSlider
@onready var fullscreen_button = $MarginContainer/VBoxContainer/MenuOpcoes/VBoxContainer/FullScreenButton
@onready var back_button = $MarginContainer/VBoxContainer/MenuOpcoes/VBoxContainer/BackButton

func _ready():
	menu_principal.show()
	menu_opcoes.hide()
	hide()
	resume_button.pressed.connect(_on_resumebutton_pressed)
	options_button.pressed.connect(_on_optionsbutton_pressed)
	quit_button.pressed.connect(_on_quitbutton_pressed)
	fullscreen_button.pressed.connect(_on_fullscreenbutton_pressed)
	back_button.pressed.connect(_on_backbutton_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)

	volume_slider.min_value = -80.0
	volume_slider.max_value = 0.0
	volume_slider.step = 0.5
	volume_slider.value = AudioServer.get_bus_volume_db(0)

func _process(delta):
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()

func _pause_game():
	get_tree().paused = true
	show()
	menu_principal.show()
	menu_opcoes.hide()

func _resume_game():
	get_tree().paused = false
	hide()

func _on_resumebutton_pressed():
	_resume_game()

func _on_optionsbutton_pressed():
	menu_principal.hide()
	menu_opcoes.show()

func _on_backbutton_pressed():
	menu_opcoes.hide()
	menu_principal.show()

func _on_quitbutton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")

func _on_fullscreenbutton_pressed():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_volume_changed(value: float):
	AudioServer.set_bus_volume_db(0, value)
