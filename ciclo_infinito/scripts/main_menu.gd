extends TextureRect

func _on_jogar_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/Teste_Mapa.tscn")
	pass

func _on_opcoes_button_pressed()-> void:
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")
	pass
	
func _on_creditos_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/creditos.tscn")
	pass

func _on_sair_button_pressed() -> void:
	get_tree().quit()
	pass

func _on_DiscordButton_pressed() -> void:
	OS.shell_open("https://discord.gg/9z4Mrfce")
	pass
