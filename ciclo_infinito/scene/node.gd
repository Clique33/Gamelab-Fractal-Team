extends Node

var total_inimigos: int = 0
var validar_vitoria: int = 0

func _ready() -> void:
	set_process(true) 
	
func _process(delta: float) -> void:
	total_inimigos = get_child_count()
	
	if validar_vitoria == total_inimigos:
		vitoria()
		
func vitoria() -> void:
	get_tree().change_scene_to_file("res://scene/Death_scree.tscn")
	set_process(false) 
	print("🎉 Vitória! Todos os inimigos foram derrotados!")
	
