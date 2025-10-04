# res://player/Character.gd
extends CharacterBody2D                                   # Por quê: precisamos de física 2D com velocity.

@onready var anim: AnimatedSprite2D = $animacoes          # Por quê: controlador de anima baseado em SpriteFrames.
@onready var dash_timer: Timer = $dash_timer              # Por quê: delimita quanto tempo o dash dura.
@onready var dash_cooldown: Timer = $dash_cooldown        # Por quê: recarga entre dashes.

@export var move_speed: float = 240.0                     # Por quê: velocidade alvo ao se mover.
@export var acceleration: float = 0.20                    # Por quê: suavidade ao acelerar (lerp).
@export var friction: float = 0.20                        # Por quê: suavidade ao frear (lerp).

@export var dash_speed: float = move_speed * 1.5          # Por quê: dash mais rápido que a corrida.
var is_dashing: bool = false                              # Por quê: priorizar dash sobre outras ações.
var can_dash: bool = true                                 # Por quê: respeitar cooldown.
var dash_dir: Vector2 = Vector2.ZERO                      # Por quê: direção do dash fica fixa até acabar.

@export var attack_cooldown_after: float = 0.02           # Por quê: pequeno respiro pós-ataque (sensação responsiva).
@export var attack_speed_scale1: float = 1.8              # Por quê: acelerar ataque 1.
@export var attack_speed_scale2: float = 1.8              # Por quê: acelerar ataque 2.
@export var min_attack_duration: float = 0.04             # Por quê: evita duração zero caso FPS/frames ruins.

var is_attacking: bool = false                            # Por quê: evitar reentrar no ataque.
var attack_stage: int = 0                                 # Por quê: 0=nenhum, 1=attack1, 2=attack2.
var combo_buffered: bool = false                          # Por quê: buffer para encadear o segundo golpe.
var _attack_end_timer: SceneTreeTimer = null              # Por quê: finalizar ataque por tempo (independe de sinais).

var last_facing: String = "down"                          # Por quê: direção cardinal usada na anima atual.
var pending_facing: String = ""                           # Por quê: direção desejada durante attack1, aplicada no 2.

func _ready() -> void:
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):  # Por quê: evita conectar 2x.
		dash_timer.timeout.connect(_on_dash_timer_timeout)           # Por quê: fim do dash quando timer expira.
	if not dash_cooldown.timeout.is_connected(_on_dash_cooldown_timeout): # Por quê: evita duplicidade.
		dash_cooldown.timeout.connect(_on_dash_cooldown_timeout)     # Por quê: libera novo dash ao fim do cooldown.
	_force_attack_anims_no_loop()                                    # Por quê: ataques não devem loopar.

func _force_attack_anims_no_loop() -> void:
	# Por quê: você garantiu que esses nomes existem; então já forçamos loop=false sem checar.
	for dir in ["left","right","up","down"]:
		anim.sprite_frames.set_animation_loop("attack1_%s" % dir, false)  # Por quê: garantir término.
		anim.sprite_frames.set_animation_loop("attack2_%s" % dir, false)  # Por quê: garantir término.

func _physics_process(_dt: float) -> void:
	# Input analógico de movimento.
	var input_vec: Vector2 = Vector2(
		Input.get_axis("run_left","run_right"),
		Input.get_axis("run_up","run_down")
	)

	# Ataque (não trava andar).
	if Input.is_action_just_pressed("attack"):
		if not is_attacking and not is_dashing:             # Por quê: não inicia se já atacando ou dashing.
			_start_attack(1)                                # Por quê: primeiro golpe da cadeia.
		elif is_attacking and attack_stage == 1:            # Por quê: se já no 1, permite encadear.
			combo_buffered = true                           # Por quê: marca pedido de segundo golpe.

	# Dash (pode durante ataque → cancela o ataque atual).
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		if is_attacking: _cancel_attack()                   # Por quê: dash-cancel dá mobilidade e fuga.
		is_dashing = true                                   # Por quê: entra em dash.
		can_dash = false                                    # Por quê: consome dash atual.
		dash_dir = input_vec.normalized() if input_vec != Vector2.ZERO else _dir_from_facing(last_facing) # Por quê: direção fiel ao input.
		dash_timer.start()                                  # Por quê: janela do dash.
		dash_cooldown.start()                               # Por quê: inicia recarga.
		anim.speed_scale = 1.0                              # Por quê: normaliza velocidade da anima do dash.
		anim.play("dash_" + str(last_facing))               # Por quê: feedback visual imediato.

	# Movimento: dash > andar (mesmo atacando não freia).
	if is_dashing:
		velocity = dash_dir * dash_speed                    # Por quê: velocidade fixa durante dash.
	else:
		if input_vec != Vector2.ZERO:                       # Por quê: há input de movimento.
			var dir: Vector2 = input_vec.normalized()       # Por quê: separa direção de magnitude.
			velocity.x = lerp(velocity.x, dir.x * move_speed, acceleration) # Por quê: aceleração suave no X.
			velocity.y = lerp(velocity.y, dir.y * move_speed, acceleration) # Por quê: aceleração suave no Y.
		else:
			velocity.x = lerp(velocity.x, 0.0, friction)    # Por quê: freio suave no X.
			velocity.y = lerp(velocity.y, 0.0, friction)    # Por quê: freio suave no Y.

	move_and_slide()                                        # Por quê: aplica velocity com colisões.
	_update_facing(input_vec)                               # Por quê: atualiza direção ou bufferiza durante ataque.
	_play_movement_anim()                                   # Por quê: decide qual anima tocar.

func _update_facing(input_vec: Vector2) -> void:
	# Virar durante ataque: só guarda a intenção (não troca a anima atual).
	if is_attacking:
		if input_vec == Vector2.ZERO: return               # Por quê: sem input, nada a fazer.
		var new_face := _cardinal_from_input(input_vec)    # Por quê: resolve direções diagonais em cardinais.
		if new_face != "": pending_facing = new_face       # Por quê: aplicaremos no começo do ataque 2.
		return                                             # Por quê: não muda last_facing no meio do golpe.
	# Fora de ataque: vira normalmente.
	if input_vec == Vector2.ZERO: return                   # Por quê: parado mantém direção anterior.
	last_facing = _cardinal_from_input(input_vec)          # Por quê: vira de fato.

func _cardinal_from_input(v: Vector2) -> String:
	# Por quê: escolhe a direção dominante (evita diagonal).
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"            # Por quê: decide horizontal.
	else:
		return "down" if v.y > 0.0 else "up"               # Por quê: decide vertical.

func _play_movement_anim() -> void:
	if is_dashing:
		var dn := "dash_" + str(last_facing)               # Por quê: nome de anima de dash padronizado.
		if anim.animation != dn: anim.play(dn)             # Por quê: evita restart desnecessário.
		return                                              # Por quê: dash tem prioridade.
	if is_attacking:
		var an := _current_attack_anim_name()               # Por quê: "attackX_dir" do estágio atual.
		if anim.animation != an: anim.play(an)              # Por quê: troca apenas ao entrar no golpe.
		return                                              # Por quê: não tocar idle/run durante ataque.
	var moving := velocity.length() > 24.0                  # Por quê: limiar simples para “andando”.
	var mn := ("run_" if moving else "idle_") + last_facing # Por quê: compõe nome da anima base.
	if anim.animation != mn: anim.play(mn)                  # Por quê: evita reiniciar em loop.

func _start_attack(stage: int) -> void:
	is_attacking = true                                     # Por quê: entra no estado de ataque.
	attack_stage = stage                                    # Por quê: define qual golpe tocar.
	if stage == 1:
		combo_buffered = false                               # Por quê: limpa o pedido do segundo golpe.
	else:
		if pending_facing != "": last_facing = pending_facing # Por quê: aplica direção desejada no ataque 2.
		pending_facing = ""                                   # Por quê: limpa o buffer depois de usar.

	var name: String = _current_attack_anim_name()          # Por quê: "attack1_dir" ou "attack2_dir".
	anim.sprite_frames.set_animation_loop(name, false)      # Por quê: garante que termine.
	anim.speed_scale = (attack_speed_scale1 if stage == 1 else attack_speed_scale2) # Por quê: velocidade do golpe.
	anim.play(name)                                         # Por quê: toca a anima do golpe.
	anim.frame = 0                                          # Por quê: recomeça do primeiro frame.
	_schedule_attack_end(name)                              # Por quê: agenda fim por tempo.

func _schedule_attack_end(anim_name: String) -> void:
	# Por quê: garante que só um timer controla o fim do golpe.
	if _attack_end_timer != null:
		_attack_end_timer.timeout.disconnect(_on_attack_end_timeout)  # Por quê: evita callbacks duplicados.
	# Cálculo de duração = frames / fps ajustado por speed_scale + cooldown.
	var frames: int = anim.sprite_frames.get_frame_count(anim_name)   # Por quê: comprimento da anima.
	var fps: float = anim.sprite_frames.get_animation_speed(anim_name)# Por quê: taxa da anima.
	var base: float = float(frames) / (fps if fps > 0.0 else 1.0)     # Por quê: duração nominal (s).
	var scale: float = attack_speed_scale1 if attack_stage == 1 else attack_speed_scale2 # Por quê: encurtar pelo speed.
	var dur_anim: float = max(min_attack_duration, base / max(0.01, scale))              # Por quê: nunca zero.
	var duration: float = dur_anim + attack_cooldown_after                                 # Por quê: respiro final.
	_attack_end_timer = get_tree().create_timer(duration)                                  # Por quê: one-shot preciso.
	_attack_end_timer.timeout.connect(_on_attack_end_timeout)                              # Por quê: encadear/terminar.

func _on_attack_end_timeout() -> void:
	# Por quê: se pediu chain no ataque 1, entra no 2; senão encerra estado.
	if is_attacking and attack_stage == 1 and combo_buffered:
		_start_attack(2)                                  # Por quê: segundo golpe já usa pending_facing.
	else:
		is_attacking = false                               # Por quê: libera os ataques.
		attack_stage = 0                                   # Por quê: sai do estado.
		anim.speed_scale = 1.0                             # Por quê: normaliza velocidade.
		pending_facing = ""                                # Por quê: limpa buffer remanescente.

func _cancel_attack() -> void:
	# Por quê: dash-cancel aborta o golpe em execução com segurança.
	is_attacking = false                                   # Por quê: sai do estado de ataque.
	attack_stage = 0                                       # Por quê: reseta estágio.
	anim.speed_scale = 1.0                                 # Por quê: normaliza velocidade de anima.
	pending_facing = ""                                    # Por quê: não carrega direção após cancelamento.
	if _attack_end_timer != null:                          # Por quê: evita timeout tardio.
		if _attack_end_timer.timeout.is_connected(_on_attack_end_timeout):
			_attack_end_timer.timeout.disconnect(_on_attack_end_timeout)
		_attack_end_timer = null                           # Por quê: remove timer.

func _current_attack_anim_name() -> String:
	return ("attack%d_" % attack_stage) + str(last_facing) # Por quê: convenção única de nomes.

func _dir_from_facing(dir_name: String) -> Vector2:
	# Por quê: útil para dash quando não há input (usa direção atual).
	match dir_name:
		"right": return Vector2.RIGHT
		"left":  return Vector2.LEFT
		"up":    return Vector2.UP
		_:       return Vector2.DOWN

func _on_dash_timer_timeout() -> void: is_dashing = false  # Por quê: fim da janela do dash.
func _on_dash_cooldown_timeout() -> void: can_dash = true  # Por quê: libera novo dash.
