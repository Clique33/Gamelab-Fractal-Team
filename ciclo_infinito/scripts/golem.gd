# File: res://scripts/golem.gd
extends CharacterBody2D
@export_category("objects")

@export var sprite: Sprite2D = null
@export var anim: AnimationPlayer = null

@export var move_speed: float = 100.0
@export var accel: float = 0.18
@export var stop_distance: float = 20.0   # Por que: não “cola” no player

var player_ref: Node2D = null
var _last_facing: String = "down"

@export var max_health: float = 30.0
var current_health: float = max_health

func _ready() -> void:
	# Fallbacks se esquecer de arrastar no Inspector
	if sprite == null and has_node("texture"):
		sprite = $texture
	if anim == null and has_node("AnimationPlayer"):
		anim = $AnimationPlayer

	# (Opcional) garantir animação inicial
	_play_anim("idle_down")

func _physics_process(_delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		_stop()
		return

	var to_player := player_ref.global_position - global_position
	var dist := to_player.length()

	if dist <= stop_distance:
		_stop()
		return

	var desired := to_player.normalized() * move_speed
	velocity = velocity.lerp(desired, accel)
	move_and_slide()
	_update_animation_from_velocity()

func _stop() -> void:
	velocity = velocity.lerp(Vector2.ZERO, accel)
	move_and_slide()
	_update_animation_idle()

# --- Detecção (conecte os sinais do Area2D: body_entered / body_exited) ---
func _on_detectionarea_body_entered(body: Node2D) -> void:
	# Use grupo "player" no Player (Project -> Node -> Groups) OU nomeie a cena como "player"
	if body.is_in_group("player") or body.name.to_lower() == "player":
		player_ref = body

func _on_detectionarea_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null

# --- Animação ---
func _update_animation_from_velocity() -> void:
	if velocity == Vector2.ZERO:
		_update_animation_idle()
		return
	var dir := _dir_string_from_vector(velocity)
	_last_facing = dir
	_play_anim("walk_%s" % dir)

func _update_animation_idle() -> void:
	_play_anim("idle_%s" % _last_facing)

func _play_anim(name: String) -> void:
	if anim == null:
		return
	if anim.current_animation != name and anim.has_animation(name):
		anim.play(name)

func _dir_string_from_vector(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"
	else:
		return "down" if v.y > 0.0 else "up"

func take_damage(damage: float, hit_direction: Vector2) -> void:
	current_health -= damage
	print("Inimigo recebeu dano de ", damage, ". Vida restante: ", current_health)
	
	# Exemplo simples de Knockback
	var knockback_force: float = 300.0
	velocity = hit_direction * knockback_force
	
	if current_health <= 0:
		die()
		
func die():
	# Coloque aqui a lógica de morte (animação, pontuação, etc.)
	print("Inimigo foi derrotado!")
	queue_free()
