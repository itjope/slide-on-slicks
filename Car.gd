extends CharacterBody2D

var wheel_base = 25

var steering_angle_default = 30
var steering_angle_during_kryckan = 27
var steering_angle_during_acceleration = 17

var kryckan_slownown_factor = 0.2

var engine_power = 700
var friction = -0.0035
var drag = -0.005
var braking = -600
var max_speed = 1000
var max_speed_reverse = 200
var slip_speed = 300
var traction_fast = 0.002
var traction_slow = 0.02
var steering_angle = steering_angle_default
var acceleration = Vector2.ZERO
var steer_direction

func _ready(): 
	if not is_multiplayer_authority(): return
	set_motion_mode(CharacterBody2D.MOTION_MODE_FLOATING)
	set_floor_snap_length(0.0)
	
	
func _process(delta):
	pass
	
func apply_friction():
	if velocity.length() < 5:
		velocity = Vector2.ZERO
	var friction_force = velocity * friction
	var drag_force = velocity * velocity.length() * drag
	acceleration += drag_force + friction_force

func get_input():
	if not is_multiplayer_authority(): return
	
	var turn = 0
	
	if Input.is_action_pressed("steerRight"):
		turn += calculate_turn()
	if Input.is_action_pressed("steerLeft"):
		turn -= calculate_turn()
	if Input.is_action_pressed("accelerate"):
		steering_angle = steering_angle_during_acceleration
		acceleration = transform.x * engine_power
	else:
		if steering_angle < steering_angle_default: 
			steering_angle = steering_angle + 0.2
		else:
			steering_angle = steering_angle_default
	
	if Input.is_action_pressed("break"):
		acceleration = transform.x * braking
	
	if Input.is_action_pressed("kryckan"): 
		steering_angle = steering_angle_during_kryckan
		acceleration = acceleration * kryckan_slownown_factor

	steer_direction = turn * deg_to_rad(steering_angle)

func calculate_turn():
	var car_speed = velocity.length()
	if car_speed > max_speed:
		return 2
	elif car_speed == 0:
		return 1
	else:
		return (car_speed / max_speed) + 1

func calculate_steering(delta):
	var rear_wheel = position - transform.x * wheel_base/2.0
	var front_wheel = position + transform.x * wheel_base/2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(steer_direction) * delta
	var new_heading = (front_wheel - rear_wheel).normalized()
	var traction = traction_slow
	if velocity.length() > slip_speed:
		traction = traction_fast
	var d = new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = velocity.lerp(new_heading * velocity.length(), traction)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), max_speed_reverse)
	rotation = new_heading.angle()

func _physics_process(delta):
	if  not is_multiplayer_authority(): return
	acceleration = Vector2.ZERO
	get_input()
	apply_friction()
	calculate_steering(delta)
	velocity += acceleration * delta
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity = velocity * 0.90 
	
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	

