extends Node2D

@onready var pause_menu = $player/pause

func _ready():
	pause_menu.hide()

func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()

func _pause_game():
	get_tree().paused = true
	pause_menu.show()

func _resume_game():
	get_tree().paused = false
	pause_menu.hide()
