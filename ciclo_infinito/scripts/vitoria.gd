extends CanvasLayer


func _on_jogar_novamente_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/HallDoQueijo.tscn")
	pass 


func _on_menu_iniciar_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")
	pass
