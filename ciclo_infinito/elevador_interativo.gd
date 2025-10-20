extends Area2D

# --- Variável para a Cena de Destino ---
# Arraste seu arquivo de cena (ex: "nivel_2.tscn") para esta 
# variável no Inspetor do Godot.
@export var target_scene: PackedScene

# (Opcional) A label para "Pressione E"
@onready var label_interação: Label = $LabelInteração

var player_in_area = false

func _ready() -> void:
	# Se você não quiser um texto de "Pressione E", pode apagar
	# as linhas que mencionam 'label_interação'
	label_interação.visible = false

func _process(delta) -> void:
	# Se o jogador está na área E pressionar o botão de interagir
	if player_in_area and Input.is_action_just_pressed("interact"):
		mudar_de_cena()

func mudar_de_cena():
	if target_scene == null:
		print("ERRO: A cena de destino (Target Scene) não foi definida no inspetor!")
		return
	
	get_tree().change_scene_to_packed(target_scene)


# --- Sinais de Detecção ---
# Conecte os sinais 'body_entered' e 'body_exited' desta Area2D 
# a estas funções.

func _on_body_entered(body: Node2D) -> void:
	# Usando grupos, que é mais seguro
	print("---ALGO ENTROU NO ELEVADOR!---")
	print("Nome do corpo detectado: ", body.name)
	
	if body.is_in_group("player"): 
		print("... e é o jogador!")
		player_in_area = true
		label_interação.text = "Pressione 'E' para usar"
		label_interação.visible = true
	else:
		print("... mas NÃO é o jogador. Grupo do corpo: ", body.get_groups())

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		label_interação.visible = false
