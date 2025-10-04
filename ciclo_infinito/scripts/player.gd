extends CharacterBody2D

# ---------- NÓS ----------
@onready var anim: AnimatedSprite2D = $animacoes
@onready var dash_timer: Timer = $dash_timer
@onready var dash_cooldown: Timer = $dash_cooldown
@onready var attack_area: Area2D = $AttackArea

# ---------- MOVIMENTO ----------
@export var move_speed := 240.0
@export var acceleration := 0.20     # 0..1 quanto mais alto, mais "responsivo"
@export var friction := 0.20         # 0..1 quanto mais alto, freia mais rápido

# ---------- DASH ----------
@export var dash_speed := 0.0        # se ficar 0, seto 1.5x move_speed no _ready
var can_dash := true
var dash_dir := Vector2.ZERO

# ---------- ATAQUE / COMBO ----------
# Timings (ajuste ao feeling do jogo)
@export var attack1_lock_time := 0.22
@export var attack2_lock_time := 0.28
@export var hit1_active_time := 0.12
@export var hit2_active_time := 0.14
@export var combo_window := 0.20       # tempo pra apertar de novo e engatar o 2º hit
@export var attack_cooldown := 0.15    # pausa após terminar a sequência

# Offsets da hitbox por direção (pixels, relativo ao Player)
@export var hit_offset_right := Vector2(18, 0)
@export var hit_offset_left  := Vector2(-18, 0)
@export var hit_offset_up    := Vector2(0, -18)
@export var hit_offset_down  := Vector2(0, 18)

# ---------- FACING ----------
var last_facing := "down"      # visual do player (idle/run/dash)
var attack_facing := "down"    # direção travada no instante que inicia o ataque

# ---------- MINI-FSM ----------
enum State { MOVE, DASH, ATTACK }
var state: int = State.MOVE

# ---------- FLAGS DE ATAQUE / COMBO ----------
var is_attacking := false
var can_attack := true
var combo_step := 0                 # 0=nada, 1=attack1, 2=attack2
var combo_window_open := false
var combo_buffered := false         # recebeu input dentro da janela

# ==========================================================
# READY
# ==========================================================
func _ready() -> void:
	if dash_speed <= 0.0:
		dash_speed = move_speed * 1.5
	print("[READY] Player iniciado. dash_speed =", dash_speed)

	# Conexão de timers do dash
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not dash_cooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		dash_cooldown.timeout.connect(_on_dash_cooldown_timeout)

	# Garante hitbox desligada no início
	if is_instance_valid(attack_area):
		attack_area.monitoring = false
	else:
		push_warning("AttackArea não encontrado. Crie um Area2D chamado 'AttackArea' com um CollisionShape2D filho.")

# ==========================================================
# LOOP FÍSICO
# ==========================================================
func _physics_process(_dt: float) -> void:
	var input_vec := Vector2(
		Input.get_axis("run_left","run_right"),
		Input.get_axis("run_up","run_down")
	)

	# ---- INPUTS ----
	# Attack: proibido iniciar durante DASH
	if Input.is_action_just_pressed("attack"):
		if state == State.DASH:
			print("[ATTACK] Ignorado: está em DASH")
		elif state == State.ATTACK and combo_step == 1 and combo_window_open:
			combo_buffered = true
			print("[ATTACK] Combo input bufferado (Attack2) dentro da janela")
		elif can_attack:
			_start_attack1()

	# Dash: permitido apenas se não estiver atacando
	if Input.is_action_just_pressed("dash") and can_dash and state != State.DASH and state != State.ATTACK:
		_start_dash(input_vec)

	# ---- FSM ----
	match state:
		State.ATTACK:
			# Pode se mover durante o ataque (como solicitado)
			if input_vec != Vector2.ZERO:
				var dir := input_vec.normalized()
				velocity.x = lerp(velocity.x, dir.x * move_speed, acceleration)
				velocity.y = lerp(velocity.y, dir.y * move_speed, acceleration)
			else:
				velocity.x = lerp(velocity.x, 0.0, friction)
				velocity.y = lerp(velocity.y, 0.0, friction)

		State.DASH:
			velocity = dash_dir * dash_speed

		State.MOVE:
			if input_vec != Vector2.ZERO:
				var dir := input_vec.normalized()
				velocity.x = lerp(velocity.x, dir.x * move_speed, acceleration)
				velocity.y = lerp(velocity.y, dir.y * move_speed, acceleration)
			else:
				velocity.x = lerp(velocity.x, 0.0, friction)
				velocity.y = lerp(velocity.y, 0.0, friction)

	move_and_slide()

	# Atualiza facing só quando em MOVE (pra ataque fixar a direção escolhida)
	if state == State.MOVE:
		_update_facing(input_vec)

	# Mantém a hitbox sempre ancorada à frente do player
	_update_attack_area_anchor()

	# Animação com prioridade: ATTACK > DASH > RUN/IDLE
	_play_action_anim()

# ==========================================================
# DASH
# ==========================================================
func _start_dash(input_vec: Vector2) -> void:
	state = State.DASH
	can_dash = false

	if input_vec != Vector2.ZERO:
		dash_dir = input_vec.normalized()
	else:
		match last_facing:
			"right": dash_dir = Vector2.RIGHT
			"left":  dash_dir = Vector2.LEFT
			"up":    dash_dir = Vector2.UP
			_:       dash_dir = Vector2.DOWN

	print("[DASH] Iniciando dash. Direção =", dash_dir)

	dash_timer.start()
	dash_cooldown.start()

	var dash_now := "dash_" + str(last_facing)
	if anim.animation != dash_now:
		print("[ANIM] Tocando animação:", dash_now)
		anim.play(dash_now)

func _on_dash_timer_timeout() -> void:
	print("[DASH] Dash terminou → voltando para MOVE")
	if state == State.DASH:
		state = State.MOVE

func _on_dash_cooldown_timeout() -> void:
	can_dash = true
	print("[DASH] Cooldown resetado → pode dash novamente")

# ==========================================================
# ATTACK / COMBO
# ==========================================================
func _start_attack1() -> void:
	# Travar direção do ataque no momento do input
	attack_facing = last_facing
	state = State.ATTACK
	is_attacking = true
	can_attack = false
	combo_step = 1
	combo_buffered = false

	_position_attack_area()
	_enable_hitbox_for(hit1_active_time)

	var a := "attack1_" + attack_facing
	if anim.animation != a:
		print("[ATTACK] Iniciando Attack1, anim:", a)
		anim.play(a)

	# Abre a janela do combo e agenda o fim do lock
	_open_combo_window()
	_end_attack1_after_lock()

func _open_combo_window() -> void:
	combo_window_open = true
	await get_tree().create_timer(combo_window).timeout
	combo_window_open = false

	# Se recebeu input dentro da janela, engata o 2º golpe
	if combo_step == 1 and combo_buffered:
		_start_attack2()

func _end_attack1_after_lock() -> void:
	await get_tree().create_timer(attack1_lock_time).timeout
	# Se não encadeou para o 2º, termina a sequência
	if combo_step == 1:
		_finish_attack_sequence()

func _start_attack2() -> void:
	combo_step = 2

	_position_attack_area()
	_enable_hitbox_for(hit2_active_time)

	var a := "attack2_" + attack_facing
	if anim.animation != a:
		print("[ATTACK] Iniciando Attack2, anim:", a)
		anim.play(a)

	# fim do lock do ataque 2 → encerra sequência
	await get_tree().create_timer(attack2_lock_time).timeout
	_finish_attack_sequence()

func _finish_attack_sequence() -> void:
	is_attacking = false
	combo_step = 0
	state = State.MOVE
	print("[ATTACK] Sequência finalizada → entrando em cooldown")

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	print("[ATTACK] Cooldown finalizado → pode atacar novamente")

# Liga a hitbox por uma janela curta
func _enable_hitbox_for(dur: float) -> void:
	if not is_instance_valid(attack_area):
		return
	attack_area.monitoring = true
	print("[HITBOX] ON por ", dur, "s")
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(attack_area):
		attack_area.monitoring = false
		print("[HITBOX] OFF")

# Posiciona a AttackArea pra frente do player conforme a direção do ataque
func _position_attack_area() -> void:
	if not is_instance_valid(attack_area):
		return
	match attack_facing:
		"right": attack_area.position = hit_offset_right
		"left":  attack_area.position = hit_offset_left
		"up":    attack_area.position = hit_offset_up
		_:       attack_area.position = hit_offset_down

# Mantém a AttackArea ancorada à frente do player
# (durante ATTACK usa a direção travada; fora dele usa o last_facing)
func _update_attack_area_anchor() -> void:
	if not is_instance_valid(attack_area):
		return
	var facing := attack_facing if state == State.ATTACK else last_facing
	match facing:
		"right": attack_area.position = hit_offset_right
		"left":  attack_area.position = hit_offset_left
		"up":    attack_area.position = hit_offset_up
		_:       attack_area.position = hit_offset_down

# ==========================================================
# VISUAL
# ==========================================================
func _update_facing(input_vec: Vector2) -> void:
	if input_vec == Vector2.ZERO:
		return
	if abs(input_vec.x) > abs(input_vec.y):
		last_facing = "right" if input_vec.x > 0.0 else "left"
	else:
		last_facing = "down" if input_vec.y > 0.0 else "up"
	print("[FACING] Direção atual:", last_facing)

func _play_action_anim() -> void:
	# 1) ATTACK tem prioridade máxima
	if state == State.ATTACK:
		var atk_now := ("attack2_" if combo_step == 2 else "attack1_") + attack_facing
		if anim.animation != atk_now:
			print("[ANIM] Tocando animação:", atk_now)
			anim.play(atk_now)
		return

	# 2) DASH
	if state == State.DASH:
		var dash_now := "dash_" + str(last_facing)
		if anim.animation != dash_now:
			print("[ANIM] Tocando animação:", dash_now)
			anim.play(dash_now)
		return

	# 3) MOVE (run/idle)
	var moving := velocity.length() > 24.0
	var base := "run_" if moving else "idle_"
	var anim_now := base + last_facing
	if anim.animation != anim_now:
		print("[ANIM] Tocando animação:", anim_now)
		anim.play(anim_now)
