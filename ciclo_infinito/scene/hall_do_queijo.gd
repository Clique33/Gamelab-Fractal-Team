extends Node2D

@onready var pause_menu = $player/pause
@onready var mission_label = $CanvasLayer/ColorRect/Label
var missoes = [
	"Missao:\nFale com o José\nproximo aos elevadores\ndo Hall do Queijo",
	"Missao:\nEntre no elevador",
	"Missao:\nFale com o Pedro",
	"Missao:\nMate os monstros"
]
var indice_missao_atual = 0

func _ready():
	await get_tree().process_frame
	pause_menu.hide()
	_atualizar_texto_missao()

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
func _atualizar_texto_missao():
	if mission_label and indice_missao_atual < missoes.size():
		mission_label.text = "Missão: " + missoes[indice_missao_atual]
	else:
		mission_label.text = "Todas as missões concluídas!"
func proxima_missao():
	if indice_missao_atual < missoes.size() - 1:
		indice_missao_atual += 1
		_atualizar_texto_missao()
	else:
		print("🎉 Todas as missões foram completadas!")
func resetar_missoes():
	indice_missao_atual = 0
	_atualizar_texto_missao()
