# res://player/Character.gd
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $animacoes
@onready var dash_timer: Timer = $dash_timer
@onready var dash_cooldown: Timer = $dash_cooldown

@export var move_speed: float = 240.0
@export var acceleration: float = 0.20
@export var friction: float = 0.20

@export var dash_speed: float = move_speed * 1.5
var is_dashing: bool = false
var can_dash: bool = true
var dash_dir: Vector2 = Vector2.ZERO

# Ataque rápido (só anima)
@export var attack_cooldown_after: float = 0.02
@export var attack_speed_scale1: float = 1.8
@export var attack_speed_scale2: float = 1.8
@export var min_attack_duration: float = 0.04

var is_attacking: bool = false
var attack_stage: int = 0            # 0=nenhum, 1=attack1, 2=attack2
var combo_buffered: bool = false
var _attack_end_timer: SceneTreeTimer = null

var last_facing: String = "down"     # direção usada para tocar a anima atual
var pending_facing: String = ""      # direção desejada coletada durante o ataque (aplicada no próximo golpe)

func _ready() -> void:
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not dash_cooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		dash_cooldown.timeout.connect(_on_dash_cooldown_timeout)
	_ensure_attack_anims()

func _ensure_attack_anims() -> void:
	for dir in ["left","right","up","down"]:
		for a in ["attack1_%s" % dir, "attack2_%s" % dir]:
			if anim.sprite_frames.has_animation(a):
				anim.sprite_frames.set_animation_loop(a, false)
			else:
				push_warning("FALTA anim '%s' no AnimatedSprite2D" % a)

func _physics_process(delta: float) -> void:
	var input_vec: Vector2 = Vector2(
		Input.get_axis("run_left","run_right"),
		Input.get_axis("run_up","run_down")
	)

	# Ataque (não bloqueia andar)
	if Input.is_action_just_pressed("attack"):
		if not is_attacking and not is_dashing:
			_start_attack(1)
		elif is_attacking and attack_stage == 1:
			combo_buffered = true

	# Dash (permite dash-cancel)
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		if is_attacking:
			_cancel_attack()                         # dash-cancel
		is_dashing = true
		can_dash = false
		dash_dir = input_vec.normalized() if input_vec != Vector2.ZERO else _dir_from_facing(last_facing)
		dash_timer.start()
		dash_cooldown.start()
		anim.speed_scale = 1.0
		anim.play("dash_" + str(last_facing))

	# Movimento: dash > andar (mesmo atacando)
	if is_dashing:
		velocity = dash_dir * dash_speed
	else:
		if input_vec != Vector2.ZERO:
			var dir: Vector2 = input_vec.normalized()
			velocity.x = lerp(velocity.x, dir.x * move_speed, acceleration)
			velocity.y = lerp(velocity.y, dir.y * move_speed, acceleration)
		else:
			velocity.x = lerp(velocity.x, 0.0, friction)
			velocity.y = lerp(velocity.y, 0.0, friction)

	move_and_slide()
	_update_facing(input_vec)        # agora também preenche pending_facing durante o ataque
	_play_movement_anim()

func _update_facing(input_vec: Vector2) -> void:
	# Virar durante ataque: só bufferiza; não troca a anima em execução.
	if is_attacking:
		if input_vec == Vector2.ZERO: return
		var new_face := _cardinal_from_input(input_vec)
		if new_face != "":
			pending_facing = new_face   # ← será aplicada no começo do próximo golpe
		return
	# Fora de ataque: muda de fato.
	if input_vec == Vector2.ZERO: return
	last_facing = _cardinal_from_input(input_vec)

func _cardinal_from_input(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"
	else:
		return "down" if v.y > 0.0 else "up"

func _play_movement_anim() -> void:
	if is_dashing:
		var dn: String = "dash_" + str(last_facing)
		if anim.animation != dn: anim.play(dn)
		return
	if is_attacking:
		var an: String = _current_attack_anim_name()
		if anim.animation != an and anim.sprite_frames.has_animation(an): anim.play(an) # não reinicia toda hora
		return
	var moving: bool = velocity.length() > 24.0
	var mn: String = ("run_" if moving else "idle_") + last_facing
	if anim.animation != mn: anim.play(mn)

func _start_attack(stage: int) -> void:
	is_attacking = true
	attack_stage = stage
	if stage == 1:
		combo_buffered = false
	else:
		# Ao entrar no ataque 2, aplica a direção que foi “guardada” durante o ataque 1.
		if pending_facing != "":
			last_facing = pending_facing
		pending_facing = ""  # limpa o buffer após usar

	var name: String = _current_attack_anim_name()
	if not anim.sprite_frames.has_animation(name):
		push_warning("Animação não encontrada: %s" % name); is_attacking = false; attack_stage = 0; return

	anim.sprite_frames.set_animation_loop(name, false)
	anim.speed_scale = (attack_speed_scale1 if stage == 1 else attack_speed_scale2)
	anim.play(name)
	anim.frame = 0
	_schedule_attack_end(name)

func _schedule_attack_end(anim_name: String) -> void:
	if _attack_end_timer != null:
		_attack_end_timer.timeout.disconnect(_on_attack_end_timeout)
	var frames: int = anim.sprite_frames.get_frame_count(anim_name)
	var fps: float = anim.sprite_frames.get_animation_speed(anim_name)
	var base: float = float(frames) / (fps if fps > 0.0 else 1.0)
	var scale: float = attack_speed_scale1 if attack_stage == 1 else attack_speed_scale2
	var dur_anim: float = max(min_attack_duration, base / max(0.01, scale))
	var duration: float = dur_anim + attack_cooldown_after
	_attack_end_timer = get_tree().create_timer(duration)
	_attack_end_timer.timeout.connect(_on_attack_end_timeout)

func _on_attack_end_timeout() -> void:
	if is_attacking and attack_stage == 1 and combo_buffered:
		_start_attack(2)                     # agora sai na pending_facing coletada
	else:
		is_attacking = false
		attack_stage = 0
		anim.speed_scale = 1.0
		pending_facing = ""                  # limpa qualquer buffer remanescente

func _cancel_attack() -> void:
	is_attacking = false
	attack_stage = 0
	anim.speed_scale = 1.0
	pending_facing = ""                      # não carrega direção ao cancelar
	if _attack_end_timer != null:
		if _attack_end_timer.timeout.is_connected(_on_attack_end_timeout):
			_attack_end_timer.timeout.disconnect(_on_attack_end_timeout)
		_attack_end_timer = null

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
