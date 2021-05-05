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

var last_time = null
var last_position = null
var last_rotation = null
var new_time = null
var new_position = null
var new_rotation = null
var interpolation_time = null
var interpolation_idx = null
var latency = null
var timer = 0

func _ready():
    if not is_network_master():
        remove_child($Camera2D)
    get_parent().get_parent().get_node("Race").connect("race_start", self, "_on_race_start")
    get_parent().get_parent().get_node("Race").connect("race_end", self, "_on_race_end")
    new_position = position
    new_rotation = rotation

func _physics_process(delta):
    timer = timer + delta
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
        rpc_unreliable("update_position_rotation", position, rotation, timer)

    else:
        if latency == null or latency == 0 or latency < delta :
            position = new_position
            rotation = new_rotation
        else:
            interpolation_idx = clamp(interpolation_idx + (delta / latency), 0, 1)
            position = last_position.linear_interpolate(new_position, interpolation_idx)
            rotation = lerp(last_rotation, new_rotation, interpolation_idx)


    #else:
    #velocity = move_and_slide(velocity)
    # var peer = get_tree().get_network_peer()

    # get_node("../Server").send_player_position(self.position)
    #print(collision)
    # velocity = collision.collider_velocity


puppet func update_position_rotation(pos, rot, time):
        last_position = position
        last_rotation = rotation
        last_time = new_time

        new_position = pos
        new_rotation = rot
        new_time = OS.get_ticks_usec()

        if new_time != null and last_time != null:
            latency = (new_time - last_time) / 1000000.0
            interpolation_idx = 0.0
    


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
