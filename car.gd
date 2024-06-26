extends CharacterBody2D

@export var wheel_base = 17

@export var steering_angle_default = 30
var steering_angle_during_kryckan = 30
@export var steering_angle_during_acceleration = 20

var kryckan_slownown_factor = 0.2

@export var engine_power = 400
@export var friction = -0.005
@export var drag = -0.005
@export var braking = -350
@export var max_speed = 1000
var max_speed_reverse = 300
@export var slip_speed = 190
var tyre_wear_factors = [1.4, 1.2, 0.5, 1.2]
var fast_tractions_by_tyre = [0.0027, 0.0025, 0.0022, 0.0020]
var slow_tractions_by_tyre = [0.025, 0.022, 0.020, 0.018]
var tyre_wear_base_speed = 60

var tyre_wear_factor = 1
#var initial_traction_fast = 0.0025
var traction_fast = 0.0025
#var initial_traction_slow = 0.02
var traction_slow = 0.02
var traction_grass = 0.001
var steering_angle = steering_angle_default
var acceleration = Vector2.ZERO
var steer_direction
var gridPosition = Vector2.ZERO

enum race_states {GRID, STARTED, COMPLETED}
var race_state = race_states.STARTED
var jumped_start = 0

enum surfaces {TARMAC, GRASS, PIT}
var surface = surfaces.TARMAC

enum tyre_types {SOFT, MEDIUM, HARD, WET}
var current_tyre = tyre_types.MEDIUM

enum weather_conditons {SUN, LIGHTRAIN, RAIN, WET}
var current_weather = weather_conditons.SUN

var tyre_rim_colors = [
	Color(0.812, 0.22, 0.957, 0.667),
	Color(0.698, 0, 0.161, 0.686),
	Color(0.933, 0.839, 0.102, 0.6),
	Color(0.224, 0.354, 0.88, 0.667)
]

@onready var animation_node = $Smoothing2D/AnimatedSprite

@onready var collision_shape = $CollisionShape2D
@onready var grass_particles_left = $GrassParticlesLeft
@onready var grass_particles_right = $GrassParticlesRight
@onready var water_particles_left = $WaterParticlesLeft
@onready var water_particles_right = $WaterParticlesRight
@onready var player_nick_label = $PlayerNickLabel
@onready var audio_player = $AudioStreamPlayer2D
@onready var audio_listener = $AudioListener2D
@onready var tyre_rim_sprite = $Smoothing2D/TyreRimSprite


@export var emit_grass_left = false
@export var emit_grass_right = false

@export var emit_water_left = false
@export var emit_water_right = false

var inputs = {
	"steerLeft": false,
	"steerRight": false,
	"accelerate": false
}
var network_velocity = Vector2.ZERO
@export var network_position = position
@export var network_rotation = rotation
var player_nick = ""
var car_animation_color = "blue"
var tracktion_tween = null

signal tyre_health_changed(tyre_health, reset)
signal toggle_pit()

func _ready():
	if not is_multiplayer_authority(): return
	set_motion_mode(CharacterBody2D.MOTION_MODE_FLOATING)
	set_floor_snap_length(0.0)
	player_nick_label.text = player_nick
	audio_listener.make_current()
	update_tyre(current_tyre)
	tracktion_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tracktion_tween.parallel().tween_property(self, "traction_fast", 0, tyre_wear_base_speed)
	tracktion_tween.parallel().tween_property(self, "traction_slow", 0, tyre_wear_base_speed)
	tracktion_tween.pause()
	
func update_tyre(tyre):
	if tracktion_tween:
		tracktion_tween.stop()
		
	current_tyre = tyre
	tyre_wear_factor = tyre_wear_factors[tyre]
	traction_fast = fast_tractions_by_tyre[tyre]
	traction_slow = slow_tractions_by_tyre[tyre]
	tyre_rim_sprite.self_modulate = tyre_rim_colors[tyre]
	tyre_health_changed.emit(100, true)
	if tracktion_tween:
		tracktion_tween.set_speed_scale(tyre_wear_factor)
	
func update_weather(weather):
	current_weather = weather
	if surface == surfaces.TARMAC and (current_weather == weather_conditons.WET or current_weather == weather_conditons.RAIN) :
		emit_water_left = true
		emit_water_right = true
	
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
	steering_angle = steering_angle_default
	if velocity.length() > 190:
		steering_angle -= 15
	inputs.steerRight = Input.is_action_pressed("steerRight")
	inputs.steerLeft = Input.is_action_pressed("steerLeft")
	inputs.accelerate = Input.is_action_pressed("accelerate")
	
	if Input.is_action_just_pressed("steerLeft") or Input.is_action_just_pressed("steerRight"):
		if not current_weather == weather_conditons.LIGHTRAIN and not current_weather == weather_conditons.RAIN and not current_weather == weather_conditons.WET and current_tyre == tyre_types.WET:
			tracktion_tween.set_speed_scale(2)
		else:
			tracktion_tween.set_speed_scale(tyre_wear_factor)
		
		tracktion_tween.play()
	
	if Input.is_action_just_released("steerLeft") or Input.is_action_just_released("steerRight"):
		tracktion_tween.pause()
	
	if Input.is_action_pressed("steerRight"):
		turn += calculate_turn()
	if Input.is_action_pressed("steerLeft"):
		turn -= calculate_turn()
	if Input.is_action_pressed("accelerate"):
		audio_player.set_pitch_scale(min(1, audio_player.get_pitch_scale() + 0.05))
		steering_angle = steering_angle_during_acceleration
		acceleration = transform.x * engine_power
		
	#else:
		audio_player.set_pitch_scale(max(0.2, audio_player.get_pitch_scale() - 0.02))
		#if steering_angle < steering_angle_default: 
		#	steering_angle = steering_angle + 0.3
		#else:
		#	steering_angle = steering_angle_default
	
	if Input.is_action_pressed("break"):
		acceleration = transform.x * braking
	
	if Input.is_action_pressed("kryckan"):
		steering_angle = steering_angle_during_kryckan
		acceleration = acceleration * kryckan_slownown_factor
		
	if Input.is_action_just_pressed("togglePit"):
		toggle_pit.emit()
	
	if jumped_start > 0:
		acceleration = acceleration * 0.5
	
	if current_weather == weather_conditons.RAIN or current_weather == weather_conditons.WET:
		if current_tyre != tyre_types.WET:
			if velocity.length() > 120:
				steering_angle = 15
			
			if velocity.length() > 170:
				steering_angle = 3
		
	steer_direction = turn * deg_to_rad(steering_angle)

func get_input2():
	var turn = 0
	
	if inputs.steerRight:
		turn += calculate_turn()
	if inputs.steerLeft:
		turn -= calculate_turn()
	if inputs.accelerate:
		steering_angle = steering_angle_during_acceleration
		acceleration = transform.x * engine_power
		
	else:
		if steering_angle < steering_angle_default: 
			steering_angle = steering_angle + 0.3
		else:
			steering_angle = steering_angle_default
	
		
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

	velocity = velocity.lerp(new_heading * velocity.length(), traction)

	rotation = new_heading.angle()

func set_grid(pos: Vector2):
	if not is_multiplayer_authority():
		return
	
	gridPosition = pos
	set_global_position(pos)
	rotation = 0
	network_position.x = pos.x
	network_position.y = pos.y
	network_rotation = rotation
	find_child("Smoothing2D").teleport()

func set_nick(nick: String):
	player_nick = nick
	player_nick_label.text = nick
	
func enter_pit(): 
	if not is_multiplayer_authority():
		return
	surface = surfaces.PIT
	collision_shape.disabled = true
	animation_node.self_modulate = Color(1, 1, 1, 0.4)

	
func exit_pit(tyre):
	if not is_multiplayer_authority():
		return
	surface = surfaces.TARMAC
	update_tyre(tyre)
	await get_tree().create_timer(1).timeout
	collision_shape.disabled = false
	animation_node.self_modulate = Color(1, 1, 1, 1)
	
func race_restart():
	race_state = race_states.GRID
	rotation = 0
	player_nick_label.text = player_nick
	player_nick_label.visible = true
	
	if is_multiplayer_authority():
		set_global_position(gridPosition)
		update_tyre(current_tyre)
		
	await get_tree().create_timer(4).timeout
	player_nick_label.visible = false
	await get_tree().create_timer(2).timeout
	race_state = race_states.STARTED
	
		
func _process(delta):
	if velocity.length() > 10:
		var animationSpeed  = min(velocity.length() / 200, 1)
		animation_node.play(car_animation_color, animationSpeed * -1)
	else:
		animation_node.play(car_animation_color, 0)
		if is_multiplayer_authority():
			emit_grass_left = false
			emit_grass_right = false
			emit_water_left = false
			emit_water_right = false
			
	if is_multiplayer_authority():	
		if velocity.length() > 100 and (current_weather == weather_conditons.RAIN or current_weather == weather_conditons.WET) :
			emit_water_left = !emit_grass_left
			emit_water_right = !emit_grass_right
		else: 
			emit_water_left = false
			emit_water_right = false
			
	grass_particles_left.emitting = emit_grass_left
	grass_particles_right.emitting = emit_grass_right
	water_particles_left.emitting = emit_water_left
	water_particles_right.emitting = emit_water_right
	
	if is_multiplayer_authority():
		tyre_health_changed.emit(traction_slow / slow_tractions_by_tyre[current_tyre], false)
	
	if not is_multiplayer_authority():
		# TODO: Use a better way to calculate weight
		audio_player.set_pitch_scale(1)
		var weight = min(1, delta * 100)
		velocity = lerp(acceleration * delta, network_velocity * delta, weight)
	

func predict(delta):
	var lerp_w = 0.5
	position.x = lerp(position.x, network_position.x, lerp_w)
	position.y = lerp(position.y, network_position.y, lerp_w)
	rotation = lerp(rotation, network_rotation, 1)
	
	get_input2()
	apply_friction()
	calculate_steering(delta)
	
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity = velocity * 0.90
	
	if surface == surfaces.GRASS:
		velocity = velocity * 0.96
	
func _physics_process(delta):
	if not is_multiplayer_authority():
		if race_state == race_states.STARTED: 
			predict(delta)
		else:
			predict(delta)
			velocity = Vector2.ZERO
		return
	
	
	if race_state == race_states.GRID: 
		velocity = Vector2.ZERO
		network_velocity = velocity
		network_position.y = position.y
		network_position.x = position.x
		network_rotation = rotation
		
		if Input.is_action_just_pressed("togglePit"):
			toggle_pit.emit()
			
		if Input.is_action_pressed("accelerate"):
			jumped_start = min(jumped_start + 2, 50)
		else: 
			jumped_start = max(jumped_start - 1, 0)
		return
	elif surface == surfaces.PIT:
		velocity = Vector2.ZERO
		return
	else:
		jumped_start = max(jumped_start - 1, 0)
		
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
	
	network_velocity = velocity
	network_position.y = position.y
	network_position.x = position.x
	network_rotation = rotation
	
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _on_area_2d_area_entered(area: Area2D):
	if not is_multiplayer_authority():
		return
	if area.name == "Grass":
		for a in area.get_overlapping_areas():
			if a.name == "LeftWheels":
				emit_grass_left = true
			if a.name == "RightWheels":
				emit_grass_right = true
	
func _on_right_weel_area_exited(area):
	if not is_multiplayer_authority():
		return
	if area.name == "Grass":
		emit_grass_right = false
		emit_grass_left = false

func _on_left_wheel_area_exited(area):
	if not is_multiplayer_authority():
		return
	if area.name == "Grass":
		emit_grass_left = false
		emit_grass_right = false

func _on_all_wheels_area_entered(area):
	if not is_multiplayer_authority():
		return
	if area.name == "Grass":
		surface = surfaces.GRASS

func _on_all_wheels_area_exited(area):
	if not is_multiplayer_authority():
		return
	if area.name == "Grass":
		surface = surfaces.TARMAC


