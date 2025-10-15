extends CanvasLayer
func _on_jogar_novamente_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/player.tscn")
	pass
