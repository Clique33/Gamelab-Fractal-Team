extends Node2D

@onready var pause_menu = $player/Camera2D/pause_menu

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			get_tree().paused= false
			pause_menu.hide()
		else:
			get_tree().paused = true
			pause_menu.show()
