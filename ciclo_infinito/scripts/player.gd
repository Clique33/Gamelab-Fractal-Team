# res://player/Character.gd
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $animacoes           # Animador 2D (SpriteFrames).
@onready var dash_timer: Timer = $dash_timer               # Janela do dash.
@onready var dash_cooldown: Timer = $dash_cooldown         # Recarga do dash.

@export var move_speed: float = 240.0                      # Corrida.
@export var acceleration: float = 0.20                     # Aceleração (lerp).
@export var friction: float = 0.20                         # Desaceleração (lerp).

@export var dash_speed: float = move_speed * 1.5           # Velocidade do dash.
var is_dashing: bool = false                               # Por quê: bloquear durante dash.
var can_dash: bool = true                                  # Por quê: respeitar cooldown.
var dash_dir: Vector2 = Vector2.ZERO                       # Por quê: direção fixa do dash.

# ---- Somente animação de ataque (acelerado) ----
@export var attack_cooldown_after: float = 0.02            # Por quê: respiro menor → resposta mais rápida.
@export var attack_speed_scale1: float = 1.8               # Por quê: acelera o attack1 (↑ = mais rápido).
@export var attack_speed_scale2: float = 1.8               # Por quê: acelera o attack2.
@export var min_attack_duration: float = 0.04              # Por quê: evita 0s se fps/frames forem ruins.

var is_attacking: bool = false                             # Por quê: travar entrada/controle.
var attack_stage: int = 0                                  # 0=none, 1=attack1, 2=attack2.
var combo_buffered: bool = false                           # Por quê: permitir chain 1→2.
var _attack_end_timer: SceneTreeTimer = null               # Por quê: terminar ataque por tempo.

var last_facing: String = "down"                           # Por quê: resolve direção sem input.

func _ready() -> void:
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout): dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not dash_cooldown.timeout.is_connected(_on_dash_cooldown_timeout): dash_cooldown.timeout.connect(_on_dash_cooldown_timeout)
	_ensure_attack_anims()                                  # Por quê: força ataques sem loop.

func _ensure_attack_anims() -> void:
	for dir in ["left","right","up","down"]:
		for a in ["attack1_%s" % dir, "attack2_%s" % dir]:
			if anim.sprite_frames.has_animation(a):
				anim.sprite_frames.set_animation_loop(a, false)   # Por quê: não travar em loop.
			else:
				push_warning("FALTA anim '%s' no AnimatedSprite2D" % a)

func _physics_process(delta: float) -> void:
	var input_vec: Vector2 = Vector2(
		Input.get_axis("run_left","run_right"),
		Input.get_axis("run_up","run_down")
	)

	# Ataque
	if Input.is_action_just_pressed("attack"):
		if not is_attacking and not is_dashing:
			_start_attack(1)                                     # Por quê: inicia cadeia.
		elif is_attacking and attack_stage == 1:
			combo_buffered = true                                # Por quê: buffer para o 2º.

	# Dash (não cancela ataque)
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing and not is_attacking:
		is_dashing = true
		can_dash = false
		dash_dir = input_vec.normalized() if input_vec != Vector2.ZERO else _dir_from_facing(last_facing)
		dash_timer.start()
		dash_cooldown.start()
		anim.play("dash_" + str(last_facing))

	# Movimento
	if is_dashing:
		velocity = dash_dir * dash_speed
	elif is_attacking:
		velocity.x = lerp(velocity.x, 0.0, 0.6)                  # Por quê: sensação de peso no golpe.
		velocity.y = lerp(velocity.y, 0.0, 0.6)
	else:
		if input_vec != Vector2.ZERO:
			var dir: Vector2 = input_vec.normalized()
			velocity.x = lerp(velocity.x, dir.x * move_speed, acceleration)
			velocity.y = lerp(velocity.y, dir.y * move_speed, acceleration)
		else:
			velocity.x = lerp(velocity.x, 0.0, friction)
			velocity.y = lerp(velocity.y, 0.0, friction)

	move_and_slide()
	_update_facing(input_vec)
	_play_movement_anim()

func _update_facing(input_vec: Vector2) -> void:
	if is_dashing or is_attacking: return                    # Por quê: não virar durante ações.
	if input_vec == Vector2.ZERO: return
	if abs(input_vec.x) > abs(input_vec.y):
		last_facing = "right" if input_vec.x > 0.0 else "left"
	else:
		last_facing = "down" if input_vec.y > 0.0 else "up"

func _play_movement_anim() -> void:
	if is_dashing:
		var dn: String = "dash_" + str(last_facing)
		if anim.animation != dn: anim.play(dn)
		return
	if is_attacking:
		var an: String = _current_attack_anim_name()
		if anim.animation != an and anim.sprite_frames.has_animation(an): anim.play(an)  # Por quê: não reiniciar toda hora.
		return
	var moving: bool = velocity.length() > 24.0
	var mn: String = ("run_" if moving else "idle_") + last_facing
	if anim.animation != mn: anim.play(mn)

func _start_attack(stage: int) -> void:
	is_attacking = true
	attack_stage = stage
	if stage == 1: combo_buffered = false                   # Por quê: recomeça a cadeia.
	var name: String = _current_attack_anim_name()
	if not anim.sprite_frames.has_animation(name):
		push_warning("Animação não encontrada: %s" % name); is_attacking = false; attack_stage = 0; return
	anim.sprite_frames.set_animation_loop(name, false)
	# → Acelera a animação aqui
	anim.speed_scale = (attack_speed_scale1 if stage == 1 else attack_speed_scale2)  # Por quê: controle direto de velocidade.
	anim.play(name)
	anim.frame = 0
	_schedule_attack_end(name)                               # Por quê: termina garantido pelo tempo.

func _schedule_attack_end(anim_name: String) -> void:
	if _attack_end_timer != null:
		_attack_end_timer.timeout.disconnect(_on_attack_end_timeout)
	var frames: int = anim.sprite_frames.get_frame_count(anim_name)         # Frames da anima.
	var fps: float = anim.sprite_frames.get_animation_speed(anim_name)      # FPS da anima.
	var base: float = float(frames) / (fps if fps > 0.0 else 1.0)           # Duração base (s).
	var scale: float = attack_speed_scale1 if attack_stage == 1 else attack_speed_scale2
	var dur_anim: float = max(min_attack_duration, base / max(0.01, scale)) # Por quê: divide pela velocidade.
	var duration: float = dur_anim + attack_cooldown_after                   # Por quê: adicionar respiro.
	_attack_end_timer = get_tree().create_timer(duration)
	_attack_end_timer.timeout.connect(_on_attack_end_timeout)

func _on_attack_end_timeout() -> void:
	if is_attacking and attack_stage == 1 and combo_buffered:
		_start_attack(2)                                             # Por quê: chain rápido para 2º golpe.
	else:
		is_attacking = false
		attack_stage = 0
		# Opcional: voltar speed_scale ao normal para outras anims.
		anim.speed_scale = 1.0

func _current_attack_anim_name() -> String:
	return ("attack%d_" % attack_stage) + str(last_facing)

func _dir_from_facing(dir_name: String) -> Vector2:
	match dir_name:
		"right": return Vector2.RIGHT
		"left":  return Vector2.LEFT
		"up":    return Vector2.UP
		_:       return Vector2.DOWN

func _on_dash_timer_timeout() -> void: is_dashing = false
func _on_dash_cooldown_timeout() -> void: can_dash = true
