extends CharacterBody2D
@onready var acesanimated = $AnimatedSprite2D
@export var move_speed:float = 150.0
@export var acceleration = 0.2
@export var friction = 0.2 
var ultdir = "down"


func _physics_process(_delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_axis("run_left","run_right"),
		Input.get_axis("run_up","run_down")
	)
	#andar e a minha direção
	if dir != Vector2.ZERO:
		var andar = dir.normalized()
		velocity.x = lerp(velocity.x,move_speed * andar.x, acceleration) 
		velocity.y = lerp(velocity.y,move_speed * andar.y, acceleration)
	else:
		velocity.x = lerp(velocity.x , 0.0 , friction)
		velocity.y = lerp(velocity.y , 0.0 , friction)

	move_and_slide()
	verificardir(dir)
	animated()
func verificardir(dir):
	
	if dir == Vector2.ZERO:
		return
	if abs(dir.x) > abs(dir.y):
		if dir.x < 0:
			ultdir = "left"
		else:
			ultdir = "right"
	else:
		if dir.y>0:
			ultdir = "down"
		else:
			ultdir = "up"

	 
func animated():
	var mover = velocity.length() > 1.0
	var base
	if mover:
		base = "run_"
	else:
		base = "idle_"
	var animacao = base + ultdir
	if acesanimated.animation != animacao:
	 
		acesanimated.play(animacao)
	
	
	
