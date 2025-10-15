# File: res://scripts/golem.gd
extends CharacterBody2D

@export_category("objects")
@export var sprite: Sprite2D = null
@export var anim: AnimationPlayer = null

@export_category("Movement")
@export var move_speed: float = 100.0
@export var accel: float = 0.18
@export var stop_distance: float = 40.0 # Aumentei um pouco para dar espaço ao ataque

# --- NOVO: Variáveis de Ataque ---
@export_category("Combat")
@export var attack_damage: float = 15.0 # Dano que o Golem causa
@export var attack_cooldown: float = 1.5 # Tempo entre os ataques
var can_attack: bool = true
# ------------------------------------

@export_category("Health")
@export var max_health: float = 50.0
var current_health: float

var player_ref: Node2D = null
var _last_facing: String = "down"

# --- NOVO: Referência para o Timer ---
@onready var attack_cooldown_timer: Timer = $AttackCooldown
# ------------------------------------

func _ready() -> void:
	current_health = max_health # Inicializa a vida
	attack_cooldown_timer.wait_time = attack_cooldown # Configura o timer com o valor exportado
	
	if sprite == null and has_node("texture"):
		sprite = $texture
	if anim == null and has_node("AnimationPlayer"):
		anim = $AnimationPlayer
	_play_anim("idle_down")


func _physics_process(_delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		_stop()
		return

	var to_player := player_ref.global_position - global_position
	var dist := to_player.length()

	# Se estiver longe, se aproxima do jogador
	if dist > stop_distance:
		var desired := to_player.normalized() * move_speed
		velocity = velocity.lerp(desired, accel)
		move_and_slide()
		_update_animation_from_velocity()
	# Se estiver perto o suficiente para atacar
	else:
		_stop() # Para de se mover
		# --- NOVO: Lógica de Ataque ---
		if can_attack:
			attack()
		# -----------------------------

# Esta é a função que o ataque do jogador vai chamar
func take_damage(damage: float, hit_direction: Vector2) -> void:
	current_health -= damage
	print("Inimigo recebeu dano de ", damage, ". Vida restante: ", current_health)
	
	var knockback_force: float = 300.0
	velocity = hit_direction * knockback_force
	
	if current_health <= 0:
		die()

func die():
	print("Inimigo foi derrotado!")
	queue_free()

# --- NOVA FUNÇÃO DE ATAQUE ---
func attack() -> void:
	can_attack = false # Impede ataques múltiplos
	attack_cooldown_timer.start() # Inicia o cooldown
	
	print("Golem ataca!")
	# Opcional: Tocar uma animação de ataque aqui
	# _play_anim("attack_%s" % _last_facing)

	# Verifica quais corpos estão na área de ataque
	var bodies_in_area = $AttackArea.get_overlapping_bodies()
	# --- DIAGNÓSTICO ---
	if bodies_in_area.is_empty():
		print("  -> ERRO: A AttackArea do Golem está vazia. Nenhum corpo detectado.")
		return # Sai da função, pois não há nada para atacar

	print("  -> Corpos detectados na AttackArea: ", bodies_in_area.size())
	for body in bodies_in_area:
		# Vamos inspecionar cada corpo que encontramos
		print("    - Inspecionando corpo: '", body.name, "' do tipo ", body.get_class())
		
		if body.has_method("take_damage"):
			print("      -> SUCESSO! O corpo '", body.name, "' tem a função take_damage. Aplicando dano.")
			var hit_direction = (body.global_position - global_position).normalized()
			body.take_damage(attack_damage, hit_direction)
		else:
			print("      -> AVISO: O corpo '", body.name, "' foi detectado, mas não tem a função take_damage.")
	# --- FIM DO DIAGNÓSTICO ---
	
	for body in bodies_in_area:
		# Se o corpo for o jogador (tendo a função take_damage)
		if body.has_method("take_damage"):
			# Calcula a direção do golpe (do golem para o jogador)
			var hit_direction = (body.global_position - global_position).normalized()
			# Chama a função de dano no jogador
			body.take_damage(attack_damage, hit_direction)

# --- NOVO: Sinal do Timer de Cooldown ---
func _on_attack_cooldown_timeout() -> void:
	can_attack = true # Permite que o golem ataque novamente
# -----------------------------------------

func _stop() -> void:
	velocity = velocity.lerp(Vector2.ZERO, accel)
	move_and_slide()
	_update_animation_idle()

func _on_detectionarea_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.to_lower() == "player":
		player_ref = body

func _on_detectionarea_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null

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
