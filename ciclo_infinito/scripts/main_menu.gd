extends TextureRect

func _on_jogar_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/Teste_Mapa.tscn")
	pass

func _on_creditos_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/Creditos.tscn")
	pass
