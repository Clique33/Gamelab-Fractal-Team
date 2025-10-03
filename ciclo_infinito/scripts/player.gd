extends CharacterBody2D
#acesso aos nos 
#acontece somente  quando os nó e todos sesu filhos estiverem prontos
@onready var anim  = $animacoes 
@onready var dash_timer = $dash_timer
@onready var dash_cooldown = $dash_cooldown

#movimentação base
@export var move_speed = 240.00
@export var acceleration = 0.20
@export var friction  = 0.20

@export  var dash_speed = move_speed * 1.5
var is_dashing = false
var can_dash = true
var dash_dir = Vector2.ZERO

#variveis setadas em  00
var last_facing = 'down'

func _ready() -> void:
	#quando dash_timer acabar chame _on-dash_timer_timeout
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not dash_cooldown.timeout.is_connected(_on_dash_cooldown_timeout):
		dash_cooldown.timeout.connect(_on_dash_cooldown_timeout)
	


func _physics_process(_dt):
	var input_vec = Vector2(
		Input.get_axis('run_left','run_right'),
		Input.get_axis('run_up','run_down')
	)
	if Input.is_action_just_pressed('dash') and  can_dash and not  is_dashing:
		is_dashing = true
		can_dash = false
		if input_vec  != Vector2.ZERO:
			dash_dir = input_vec.normalized()
		else:
			#swith do godt
			match last_facing:
				"right": dash_dir = Vector2.RIGHT
				"left":  dash_dir = Vector2.LEFT
				"up":    dash_dir = Vector2.UP
				_:       dash_dir = Vector2.DOWN
		dash_timer.start()       
		dash_cooldown.start()    
		anim.play("dash_" + str(last_facing))  
		
	if is_dashing:
		velocity = dash_dir * dash_speed
		
	else:
		
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
	if is_dashing:
		return
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
	# prioridade pro dash
	if is_dashing:
		var dash_now = "dash_" + str(last_facing)
		if anim.animation != dash_now:
			anim.play(dash_now)
		return   
	var moving = velocity.length() > 24.0 #baseado move speed
	var base
	if moving:
		base = 'run_'
	else:
		base = 'idle_'
	var animar_now = base + last_facing
	if anim.animation != animar_now:
		anim.play(animar_now)
		

func _on_dash_timer_timeout():
	is_dashing = false

func _on_dash_cooldown_timeout():
	can_dash = true
