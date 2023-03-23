extends CharacterBody2D

var wheel_base = 14

var steering_angle_default = 40
var steering_angle_during_kryckan = 30
var steering_angle_during_acceleration = 20

var kryckan_slownown_factor = 0.2

var engine_power = 450
var friction = -0.0035
var drag = -0.007
var braking = -350
var max_speed = 1000
var max_speed_reverse = 300
var slip_speed = 190
var traction_fast = 0.0025
var traction_slow = 0.02
var traction_grass = 0.001
var steering_angle = steering_angle_default
var acceleration = Vector2.ZERO
var steer_direction
var gridPosition = Vector2.ZERO

enum race_states {GRID, STARTED}
var race_state = race_states.STARTED
var jumped_start = 0

enum surfaces {TARMAC, GRASS}
var surface = surfaces.TARMAC

@onready var animation_node_blue = $Smoothing2D/AnimatedSpriteBlue
@onready var animation_node_pink = $Smoothing2D/AnimatedSpritePink
@onready var animation_node = animation_node_blue
@onready var collision_shape = $CollisionShape2D
@onready var grass_particles_left = $GrassParticlesLeft
@onready var grass_particles_right = $GrassParticlesRight

@export var emit_grass_left = false
@export var emit_grass_right = false

func _ready():
	if not is_multiplayer_authority(): return
	animation_node = animation_node_pink
	animation_node_blue.visible = false
	animation_node.visible = true
	set_motion_mode(CharacterBody2D.MOTION_MODE_FLOATING)
	set_floor_snap_length(0.0)

func _input(event):
	if event.is_pressed() && event.as_text() == "N":
		for child in get_children():
			if child.get_class() == "PointLight2D":
				child.visible = !child.visible 

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
			steering_angle = steering_angle + 0.3
		else:
			steering_angle = steering_angle_default
	
	if Input.is_action_pressed("break"):
		acceleration = transform.x * braking
	
	if Input.is_action_pressed("kryckan"):
		steering_angle = steering_angle_during_kryckan
		acceleration = acceleration * kryckan_slownown_factor
	
	if jumped_start > 0:
		acceleration = acceleration * 0.5
		jumped_start = jumped_start - 1
		
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
	
	if surface == surfaces.GRASS:
		traction = traction_grass

	#if d >= 0:
	velocity = velocity.lerp(new_heading * velocity.length(), traction)
	#if d < 0:
		#velocity = -new_heading * min(velocity.length(), max_speed_reverse)
	rotation = new_heading.angle()

func set_grid(pos: Vector2):
	if not is_multiplayer_authority():
		return
	
	print_debug("set grid on player ", pos)
	gridPosition = pos
	set_global_position(pos)
	find_child("Smoothing2D").teleport()

func race_restart():
	if not is_multiplayer_authority():
		return
	race_state = race_states.GRID
	set_global_position(gridPosition)
	rotation = 0
	await get_tree().create_timer(6).timeout
	race_state = race_states.STARTED

func _process(delta):
	
	if velocity.length() > 10:
		var animationSpeed  = min(velocity.length() / 200, 1)
		animation_node.play("running", animationSpeed)

	else:
		animation_node.play("running", 0)
		if is_multiplayer_authority():
			emit_grass_left = false
			emit_grass_right = false
		
	grass_particles_left.emitting = emit_grass_left
	grass_particles_right.emitting = emit_grass_right

func _physics_process(delta):
	if not is_multiplayer_authority():
		move_and_slide()
		return
	
	if race_state == race_states.GRID: 
		velocity = Vector2.ZERO
		if Input.is_action_pressed("accelerate"):
			jumped_start = min(jumped_start + 1, 50)
		return
	
	acceleration = Vector2.ZERO
	get_input()
	apply_friction()
	calculate_steering(delta)
	velocity += acceleration * delta
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity = velocity * 0.90
		
	if surface == surfaces.GRASS:
		velocity = velocity * 0.96
	
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	



func _on_area_2d_area_entered(area: Area2D):
	if area.name == "Grass":
		surface = surfaces.GRASS
		for a in area.get_overlapping_areas():
			if a.name == "LeftWheels":
				emit_grass_left = true
			if a.name == "RightWheels":
				emit_grass_right= true


func _on_area_2d_area_exited(area):
	surface = surfaces.TARMAC
	emit_grass_left = false
	emit_grass_right = false
	
