extends KinematicBody2D

var wheel_base = 70
var steering_angle = 15
var engine_power = 1600
var friction = -0.7
var drag = -0.001
var braking = -820
var max_speed = 1000
var max_speed_reverse = 250
var slip_speed = 280
var traction_fast = 0.01
var traction_slow = 0.25

var acceleration = Vector2.ZERO
var velocity = Vector2.ZERO
var steer_direction

var race_started = false
var race_ended = false

func _ready():
	if not is_network_master():
		remove_child($Camera2D)
	get_parent().get_parent().get_node("Race").connect("race_start", self, "_on_race_start")
	get_parent().get_parent().get_node("Race").connect("race_end", self, "_on_race_end")

func _physics_process(delta):
	if is_network_master():
		acceleration = Vector2.ZERO
		get_input()
		apply_friction()
		calculate_steering(delta)
		velocity += acceleration * delta
		var collision = move_and_collide(velocity * delta)
		# velocity = velocity.normalized()
		if (collision):
			velocity = velocity.bounce(collision.normal)
		rpc_unreliable("update_position_rotation", position, rotation)


	#else:
	#velocity = move_and_slide(velocity)
	# var peer = get_tree().get_network_peer()

	# get_node("../Server").send_player_position(self.position)
	#print(collision)
	# velocity = collision.collider_velocity


puppet func update_position_rotation(pos, rot):
		position = pos
		rotation = rot

func apply_friction():
	if velocity.length() < 5:
		velocity = Vector2.ZERO
	var friction_force = velocity * friction
	var drag_force = velocity * velocity.length() * drag
	acceleration += drag_force + friction_force

func get_input():

	var turn = 0

	if is_network_master() && race_started && !race_ended:
		if Input.is_action_pressed("steer_right"):
			turn += calculate_turn()
		if Input.is_action_pressed("steer_left"):
			turn -= calculate_turn()
		if Input.is_action_pressed("accelerate"):
			acceleration = transform.x * engine_power
		if Input.is_action_pressed("brake"):
			acceleration = transform.x * braking

	steer_direction = turn * deg2rad(steering_angle)

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
		velocity = velocity.linear_interpolate(new_heading * velocity.length(), traction)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), max_speed_reverse)
	rotation = new_heading.angle()

func _on_race_start():
	race_ended = false
	race_started = true

func _on_race_end():
	race_ended = true
