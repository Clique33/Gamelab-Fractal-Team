extends Control

@onready var volume_slider: HSlider = $MarginContainer/HBoxContainerGeral/volume_slider
@onready var volume_label: Label = $MarginContainer/HBoxContainerGeral/Volume

func _ready() -> void:
	# Define limites do slider em decibéis
	volume_slider.min_value = -80.0
	volume_slider.max_value = 0.0
	volume_slider.step = 0.1

	# Define valor inicial com base no bus Master (bus 0)
	var current_db = AudioServer.get_bus_volume_db(0)
	volume_slider.value = current_db
	_update_label(current_db)

	# Conecta o sinal do slider
	volume_slider.value_changed.connect(_on_volume_changed)

func _on_volume_changed(value: float) -> void:
	# Ajusta o volume do bus Master
	AudioServer.set_bus_volume_db(0, value)
	_update_label(value)

func _update_label(db_value: float) -> void:
	# Converte dB para porcentagem aproximada
	var amp = pow(10.0, db_value / 20.0)
	var percent = int(round(amp * 100.0))
	volume_label.text = "Volume: %d%%" % clamp(percent, 0, 100)
