extends StaticBody2D
@onready var caixa_de_dialogo: Label = $Area2D/CanvasLayer/CaixaDeDialogo
@onready var texto_dialogo: Label = $Area2D/CanvasLayer/TextoDialogo
@onready var label_interação: Label = $Area2D/LabelInteraçao


var player_in_area = false
var falando = false
var pode_avancar = false
var fala_index = 0

var falas = ["Escrever um blá, blá , bla´, aqui." , "Se quiser, pode escrever mais um blá blá blá aqui também."
, "Ou pode apenas apagar todas as linhas e deixar apenas uma, mas não se esqueça de por a vírgula depois das aspas a cada frase." 
]

func _ready() -> void:
	caixa_de_dialogo.visible = false
	texto_dialogo.visible = false
	label_interação.visible = false


func _process(delta) -> void:
	if player_in_area and not falando and Input.is_action_just_pressed("interact"):
		iniciar_dialogo()
	elif falando and pode_avancar and Input.is_action_just_pressed("interact"):
		proxima_fala()


func iniciar_dialogo():
	falando = true
	label_interação.visible = false
	caixa_de_dialogo.visible = true
	texto_dialogo.visible = true
	fala_index = 0
	proxima_fala()


func proxima_fala():
	if fala_index < falas.size():
		pode_avancar = false
		texto_dialogo.text = ""
		var texto = falas[fala_index]
		fala_index += 1
		mostrar_texto_com_efeito(texto)
	else:
		encerrar_dialogo()


func mostrar_texto_com_efeito(texto: String):
	await get_tree().create_timer(0.1).timeout
	for letra in texto:
		texto_dialogo.text += letra
		await get_tree().create_timer(0.02).timeout
	pode_avancar = true


func encerrar_dialogo():
	falando = false
	pode_avancar = false
	caixa_de_dialogo.visible = false
	texto_dialogo.visible = false


#func _on_body_entered(body: Node2D) -> void:
	#if body.name == "player":
		#player_in_area = true
		#label_interação.text = "Pressione 'E' para interagir"
		#label_interação.visible = true
		

#func _on_body_exited(body: Node2D) -> void:
	#if body.name == "player":
		#player_in_area = false
		#label_interação.visible = false
		#if falando:
			#encerrar_dialogo()
		

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player_in_area = true
		label_interação.text = "Pressione 'E' para interagir"
		label_interação.visible = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "player":
		player_in_area = false
		label_interação.visible = false
		if falando:
			encerrar_dialogo()
		
