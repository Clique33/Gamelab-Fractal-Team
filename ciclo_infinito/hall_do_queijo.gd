extends Node2D

@onready var pause_menu = $player/pause
@onready var mission_label = $CanvasLayer/ColorRect/Label

func _ready():
	await get_tree().process_frame
	pause_menu.hide()
	if mission_label:
		mission_label.text = "Missão: \nFale com José 
		próximo aos elevadores
		no Hall do Queijo"

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

func atualizar_missao(novo_texto: String):
	mission_label.text = novo_texto
