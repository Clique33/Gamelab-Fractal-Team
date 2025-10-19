extends Control

@onready var volume_slider: HSlider = $MarginContainer/HBoxContainerGeral/volume_slider
@onready var volume_label: Label = $MarginContainer/HBoxContainerGeral/Volume

func _ready() -> void:
	volume_slider.min_value = -80.0
	volume_slider.max_value = 0.0
	volume_slider.step = 0.1

	var current_db = AudioServer.get_bus_volume_db(0)
	volume_slider.value = current_db
	_update_label(current_db)

	volume_slider.value_changed.connect(_on_volume_changed)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	_update_label(value)

func _update_label(db_value: float) -> void:
	var amp = pow(10.0, db_value / 20.0)
	var percent = int(round(amp * 100.0))
	volume_label.text = "Volume: %d%%" % clamp(percent, 0, 100)


func _on_voltar_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")
	pass


func _on_alternar_tela_cheia_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	pass
