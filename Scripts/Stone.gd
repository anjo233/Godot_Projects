extends CharacterBody2D



var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var max_speed = 450

func _physics_process(delta: float) -> void:
	
	
	
	velocity.y += default_gravity  * delta
	move_and_slide()
	

func initialize(pos):
	global_position = pos
