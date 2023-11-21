class_name  Player
extends CharacterBody2D

enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	HURT,
	DYING,
	SIDESLIP,
}



const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.ATTACK_1, State.ATTACK_2,State.ATTACK_3,
	State.HURT,State.DYING,]
const RUN_SPEED := 150
const JUMP_VELOCITY := -320.0
const WALL_JUMP_VELOCITY := Vector2(380,-300)
const AIR_ACCELERATION := RUN_SPEED / 0.1
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const KNOCKBACK_AMOUNT := 512.0

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var is_combo_requested := false
var sideslip_action := false
var pending_damage: Damage


@export var can_combo := false


@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: Node = $StateMachine
@onready var stats: Node = $Stats
@onready var invincible_timer: Timer = $InvincibleTimer



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
		
	if event.is_action_released("jump"):
		jump_request_timer.stop() 
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true	

func tick_physics(state:State, delta: float) -> void:
	#无敌时间
	if invincible_timer.time_left > 0:
		if sideslip_action:
			graphics.modulate.a = 1
		else:
			graphics.modulate.a = sin(Time.get_ticks_msec()/30) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1	
	match state:
		State.IDLE:
			move(default_gravity, delta)
		
		State.RUNNING:
			move(default_gravity, delta)
		
		State.JUMP:
			# 判断是否为切换状态的第一帧，以便于消除重力对起跳时的高度影响
			move(0.0 if is_first_tick else default_gravity, delta)
		State.FALL:
			move(default_gravity, delta)
			
		State.LANDING:
			stand(default_gravity, delta)
			
		State.WALL_SLIDING:
			move(default_gravity / 3, delta)
			graphics.scale.x = get_wall_normal().x
		
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity, delta)
		
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)
		
		State.HURT, State.DYING:
			stand(default_gravity, delta)	
		
		#设置滑铲移动参数
		State.SIDESLIP:
			move(default_gravity, delta)
			
	is_first_tick = false
	
			
func move(gravity:float, delta: float) -> void:
	var direction := Input.get_axis("move_left","move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
			
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else 1
	
	move_and_slide()
	
func stand(gravity: float, delta: float) -> void:
	
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()
	
	
	
func die() -> void:
	get_tree().reload_current_scene()
	
	
func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()
	
	
func get_next_state(state: State) -> int:
	if stats.health == 0: 
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
		
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
		
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var direction := Input.get_axis("move_left","move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING
			if Input.is_action_just_pressed("sideslip"):
				sideslip_action = true
				return State.SIDESLIP
			
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE
			if Input.is_action_just_pressed("sideslip"):
				sideslip_action = true
				return State.SIDESLIP
				
		State.JUMP:
			if velocity.y>= 0:
				return State.FALL
				
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
				
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
				
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0 and not is_first_tick:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
				
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
				
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE
				
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_requested else State.IDLE
				
		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		#设置滑铲切换
		State.SIDESLIP:
			if not animation_player.is_playing():
				sideslip_action = false
				invincible_timer.stop()
				return State.IDLE
				
	return StateMachine.KEEP_CURRENT
	
	
func transition_state(from: State, to: State) -> void:
	print("[%s] %s => %s" %[
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	
	match to:
		State.IDLE:
			animation_player.play("idle")
			
		State.RUNNING:
			animation_player.play("running")
			
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
				
		State.LANDING:
			animation_player.play("landing")
			
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
			
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity= WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
			
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false
		
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
		
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false
			
		State.HURT:
			animation_player.play("hurt")
			stats.health -= pending_damage.amount
			
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			pending_damage = null
			invincible_timer.start()
			
			
		State.DYING:
			animation_player.play("die")
			invincible_timer.stop()
		
		State.SIDESLIP:
			animation_player.play("sideslip")
			invincible_timer.start()
	

	is_first_tick = true
			


func _on_hurbox_hurt(hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
	
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
