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

# --- Ataque (anima + colisão) ---
@export var attack_cooldown_after: float = 0.02
@export var attack_speed_scale1: float = 1.8
@export var attack_speed_scale2: float = 1.8
@export var min_attack_duration: float = 0.04

@export var attack_hitbox_time1: float = 0.10
@export var attack_hitbox_time2: float = 0.12

# >>> tamanhos maiores + avanço <<<
@export var hitbox_size1: Vector2 = Vector2(36, 20)
@export var hitbox_size2: Vector2 = Vector2(44, 22)
@export var hitbox_forward_extend: float = 8.0
@export var hitbox_offset: float = 16.0

@export var hitbox_collision_layer: int = 0b0001
@export var hitbox_collision_mask: int = 0b0010

signal attack_hit(target: Node, stage: int)

var is_attacking: bool = false
var attack_stage: int = 0
var combo_buffered: bool = false
var _attack_end_timer: SceneTreeTimer = null

var last_facing: String = "down"
var pending_facing: String = ""

var _attack_hitbox: Area2D = null
var _already_hit := {}

func _ready() -> void:
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not dash_cooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		dash_cooldown.timeout.connect(_on_dash_cooldown_timeout)
	_force_attack_anims_no_loop()

func _force_attack_anims_no_loop() -> void:
	for dir in ["left","right","up","down"]:
		anim.sprite_frames.set_animation_loop("attack1_%s" % dir, false)
		anim.sprite_frames.set_animation_loop("attack2_%s" % dir, false)

func _physics_process(_dt: float) -> void:
	var input_vec: Vector2 = Vector2(
		Input.get_axis("run_left","run_right"),
		Input.get_axis("run_up","run_down")
	)

	# Ataque
	if Input.is_action_just_pressed("attack"):
		if not is_attacking and not is_dashing:
			_start_attack(1)
		elif is_attacking and attack_stage == 1:
			combo_buffered = true

	# Dash (com cancel)
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		if is_attacking:
			_cancel_attack()
		is_dashing = true
		can_dash = false
		dash_dir = input_vec.normalized() if input_vec != Vector2.ZERO else _dir_from_facing(last_facing)
		dash_timer.start()
		dash_cooldown.start()
		anim.speed_scale = 1.0
		anim.play("dash_" + str(last_facing))

	# Movimento
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
	_update_facing(input_vec)
	_play_movement_anim()

func _update_facing(input_vec: Vector2) -> void:
	if is_attacking:
		if input_vec == Vector2.ZERO:
			return
		var new_face := _cardinal_from_input(input_vec)
		if new_face != "":
			pending_facing = new_face
		return
	if input_vec == Vector2.ZERO:
		return
	last_facing = _cardinal_from_input(input_vec)

func _cardinal_from_input(v: Vector2) -> String:
	# <<< CORRIGIDO: bloco multi-linha, sem 'else' após 'return' na mesma linha >>>
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0.0 else "left"
	else:
		return "down" if v.y > 0.0 else "up"

func _play_movement_anim() -> void:
	if is_dashing:
		var dn := "dash_" + str(last_facing)
		if anim.animation != dn:
			anim.play(dn)
		return
	if is_attacking:
		var an := _current_attack_anim_name()
		if anim.animation != an:
			anim.play(an)
		return
	var moving := velocity.length() > 24.0
	var mn := ("run_" if moving else "idle_") + last_facing
	if anim.animation != mn:
		anim.play(mn)

func _start_attack(stage: int) -> void:
	is_attacking = true
	attack_stage = stage
	if stage == 1:
		combo_buffered = false
	else:
		if pending_facing != "":
			last_facing = pending_facing
		pending_facing = ""

	var name: String = _current_attack_anim_name()
	anim.sprite_frames.set_animation_loop(name, false)
	anim.speed_scale = (attack_speed_scale1 if stage == 1 else attack_speed_scale2)
	anim.play(name)
	anim.frame = 0

	if stage == 1:
		_spawn_attack_hitbox(stage, attack_hitbox_time1)
	else:
		_spawn_attack_hitbox(stage, attack_hitbox_time2)

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
		_start_attack(2)
	else:
		is_attacking = false
		attack_stage = 0
		anim.speed_scale = 1.0
		pending_facing = ""

func _cancel_attack() -> void:
	is_attacking = false
	attack_stage = 0
	anim.speed_scale = 1.0
	pending_facing = ""
	if _attack_end_timer != null and _attack_end_timer.timeout.is_connected(_on_attack_end_timeout):
		_attack_end_timer.timeout.disconnect(_on_attack_end_timeout)
	_attack_end_timer = null

func _current_attack_anim_name() -> String:
	return ("attack%d_" % attack_stage) + str(last_facing)

# --------------- HITBOX ---------------

func _spawn_attack_hitbox(stage: int, lifetime: float) -> void:
	_despawn_attack_hitbox()
	_already_hit.clear()

	var hb := Area2D.new()
	hb.name = "AttackHitbox"
	hb.collision_layer = hitbox_collision_layer
	hb.collision_mask  = hitbox_collision_mask

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _compute_hitbox_size(stage)
	col.shape = shape
	hb.add_child(col)
	add_child(hb)

	var dir := _dir_from_facing(last_facing)
	hb.position = dir * _compute_hitbox_offset(stage)

	_attack_hitbox = hb
	hb.body_entered.connect(func(b: Node): _on_attack_hit(b))
	hb.area_entered.connect(func(a: Area2D): _on_attack_hit(a))

	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(func(): _despawn_attack_hitbox())

func _compute_hitbox_size(stage: int) -> Vector2:
	var base: Vector2 = (hitbox_size1 if stage == 1 else hitbox_size2)
	if last_facing == "left" or last_facing == "right":
		return Vector2(base.x + hitbox_forward_extend, base.y) # alonga no X
	else:
		return Vector2(base.x, base.y + hitbox_forward_extend) # alonga no Y

func _compute_hitbox_offset(stage: int) -> float:
	return hitbox_offset + (hitbox_forward_extend * 0.5)     # empurra meia extensão extra pra frente

func _on_attack_hit(target: Node) -> void:
	var id := target.get_instance_id()
	if _already_hit.has(id):
		return
	_already_hit[id] = true
	emit_signal("attack_hit", target, attack_stage)           # use esse sinal p/ aplicar dano fora, se quiser

func _despawn_attack_hitbox() -> void:
	if is_instance_valid(_attack_hitbox):
		_attack_hitbox.queue_free()
		_attack_hitbox = null

# --------------- DASH ---------------

func _dir_from_facing(dir_name: String) -> Vector2:
	match dir_name:
		"right": return Vector2.RIGHT
		"left":  return Vector2.LEFT
		"up":    return Vector2.UP
		_:       return Vector2.DOWN

func _on_dash_timer_timeout() -> void: is_dashing = false
func _on_dash_cooldown_timeout() -> void: can_dash = true
