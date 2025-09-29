extends CharacterBody2D
@onready var anim  = $animacoes #acontece somente quando o no e todos sesu filhos estiverem prontos
@export var move_speed = 240.00
@export var acceleration = 0.20
@export var friction  = 0.20
var last_facing = 'down'

func _physics_process(_dt):
	var input_vec = Vector2(
		Input.get_axis('run_left','run_right'),
		Input.get_axis('run_up','run_down')
	)
	
	if input_vec != Vector2.ZERO:
		var dir = input_vec.normalized()
		velocity.x = lerp(velocity.x, dir.x * move_speed,acceleration)
		velocity.y = lerp(velocity.y, dir.y * move_speed,acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0,friction)
		velocity.y = lerp(velocity.y, 0.0,friction)

	move_and_slide()
	_update_facing(input_vec)
	_play_movement_anim()
	
	
func _update_facing(input_vec):
	if input_vec == Vector2.ZERO:
		return
	if abs(input_vec.x) > abs(input_vec.y):
		if input_vec.x > 0.0:
			last_facing = 'right'
		else:
			last_facing = 'left'
	else:
		if input_vec.y > 0.0:
			last_facing = 'down'
		else:
			last_facing = 'up'


func _play_movement_anim():
	var moving = velocity.length() > 24.0 #baseado move speed
	var base
	if moving:
		base = 'run_'
	else:
		base = 'idle_'
	var animar_now = base + last_facing
	if anim.animation != animar_now:
		anim.play(animar_now)
