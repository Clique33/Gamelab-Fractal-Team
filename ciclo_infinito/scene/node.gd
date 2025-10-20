extends Node
@onready var enemies: Label = $"../player/enemies"


@export var label_contador: Label

# Contador de inimigos mortos
var inimigos_mortos: int = 0

# Total de inimigos que precisamos matar para vencer
var total_inimigos: int = 0

func _ready() -> void:
	total_inimigos = get_child_count()
	
	print("Nível iniciado com ", total_inimigos, " inimigos.")

	
	_atualizar_label()

	if total_inimigos == 0:
		print("Aviso: Nenhum inimigo encontrado como filho.")
		if label_contador:
			label_contador.text = "Inimigos mortos: N/A" # Caso não tenha inimigos
		vitoria()
		return

	for inimigo in get_children():
		if not inimigo.has_signal("golem_defeated"):
			print("Erro: O nó ", inimigo.name, " não tem o sinal 'golem_defeated'!")
			total_inimigos -= 1
		else:
			inimigo.golem_defeated.connect(_on_inimigo_derrotado)
			

	_atualizar_label() 

	if total_inimigos <= 0:
		print("Nenhum inimigo válido encontrado. Vitória.")
		vitoria()
	
	set_process(false)

func _on_inimigo_derrotado() -> void:
	inimigos_mortos += 1
	print("Um inimigo morreu! Contagem: ", inimigos_mortos, " / ", total_inimigos)
	
	
	_atualizar_label()
	
	if inimigos_mortos == total_inimigos:
		vitoria()


func _atualizar_label() -> void:
	if label_contador != null:
		# O formato %s é substituído pelas variáveis na ordem
		label_contador.text = "Inimigos mortos: %s / %s" % [inimigos_mortos, total_inimigos]
		
func vitoria() -> void:
	print("🎉 Vitória! Todos os inimigos foram derrotados!")
	get_tree().change_scene_to_file("res://scene/Death_scree.tscn")
