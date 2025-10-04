extends CharacterBody2D
#acesso aos nos 
#acontece somente  quando os nó e todos sesu filhos estiverem prontos
@onready var anim  = $animacoes 
@onready var dash_timer = $dash_timer
@onready var dash_cooldown = $dash_cooldown
@export var dash_duracao  = 0.2

@onready var area_attack = $attack_area

#movimentação base
@export var move_speed = 240.00
@export var acceleration = 0.20
@export var friction  = 0.20

@export  var dash_speed = move_speed * 1.5
var is_dashing = false
var can_dash = true
var dash_dir = Vector2.ZERO
#var direction
enum State {IDLE, RUN, ATTACK,DASH}
var current_state = State.IDLE

var next_direction = Vector2(0,1)

func _ready():
	dash_timer.wait_time = dash_duracao
	dash_timer.one_shot = true
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)

	area_attack.get_node("attack_colison").disabled = true

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_idle_state()
		State.RUN:
			_run_state(delta)
		State.ATTACK:
			_attack_state()
		State.DASH:
			_dash_state()
	move_and_slide()
	update_animation()
	
func get_input_direction():
	return Input.get_vector("run_left","run_right","run_up","run_down")
		

func _idle_state():
	velocity = Vector2.ZERO
	if get_input_direction() != Vector2.ZERO:
		current_state = State.RUN
	elif Input.is_action_just_pressed("attack"):
		current_state = State.ATTACK
	elif Input.is_action_just_pressed("dash"):
		current_state = State.DASH
		

func _run_state(delta):
	var input_direction = get_input_direction()
	if input_direction == Vector2.ZERO:
		current_state = State.IDLE
		return
	
	next_direction = input_direction
	velocity = input_direction.normalized() * move_speed
	
	if Input.is_action_just_pressed("attack"):
		current_state = State.ATTACK
	elif Input.is_action_just_pressed("dash"):
		current_state = State.DASH

func _attack_state():
	velocity = Vector2.ZERO
	area_attack.get_node("attack_colison").disabled = true
	
func _on_animation_finished() -> void:
	if current_state == State.ATTACK:
		area_attack.get_node("attack_colison").disabled = true
	
	if get_input_direction() != Vector2.ZERO:
		current_state = State.RUN
	else:
		current_state = State.IDLE
	
	
func _dash_state():
	if dash_timer.is_stopped():
		dash_timer.start()
		
		var dash_direction = next_direction
		
		if get_input_direction() != Vector2.ZERO:
			dash_direction = get_input_direction()
		
		velocity = dash_direction.normalized()  * dash_speed #* move_speed


func _on_dash_timer_timeout() -> void:
	$player_colision.disabled = false
	
	velocity = Vector2.ZERO
	if  get_input_direction() != Vector2.ZERO:
		current_state = State.RUN
	else:
		current_state = State.IDLE
		
func update_animation():
	var anim_name = ""
	var direction_str = get_direction_string(next_direction)
	
	match current_state:
		State.IDLE:
			anim_name = "idle_" + direction_str
		State.RUN:
			anim_name = "run_" + direction_str
		State.ATTACK:
			anim_name = "attack1_" + direction_str
		State.DASH:
			anim_name = "dash_" + direction_str
	if anim.animation != anim_name:
		anim.play(anim_name)
			
func get_direction_string(next_direction):
	if abs(next_direction.x) > abs(next_direction.y):
		return "right"  if next_direction.x > 0 else "left"
	else:
		return "down"  if next_direction.y > 0 else "up"
	
func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("inimigos"):
		print("dano feito") # Replace with function body.
