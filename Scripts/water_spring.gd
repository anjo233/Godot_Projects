extends Node2D


var velocity = 0

var force = 0

var height = 0

var target_height = 0

var index = 0

var motion_factor = 0.02

var collided_with = null

signal  splash

@onready var collision = $Area2D/CollisionShape2D

func water_update(spring_constant, dampening):
	
	height = position.y
	
	var x = height - target_height
	
	var loss = -dampening * velocity

	force = -spring_constant * x + loss
	
	velocity += force
	
	position.y += velocity
	

	
func initialize(x_position,id):
	height =position.y
	target_height=position.y
	velocity = 0
	position.x = x_position
	index = id


func set_collisition_width(value):
	
	var extents = collision.shape.get_extents()
	
	var new_extents = Vector2(value/2, extents.y)
	collision.shape.set_half_extents(new_extents)


func _on_area_2d_body_entered(body: Node2D) -> void:
	
	if body == collided_with:
		return 
	collided_with = body
	
	var speed = body.motion.y *motion_factor
	emit_signal("splash",index,speed)
