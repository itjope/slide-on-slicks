extends Node2D

@onready var tyre_soft = $TyrePurple
@onready var tyre_medium = $TyreRed
@onready var tyre_hard = $TyreYellow
@onready var tyre_wet = $TyreBlue
@onready var car = $Car

var tyres: Array[Dictionary] = []
enum tyre_types {SOFT, MEDIUM, HARD, WET}
var selected_tyre = tyre_types.MEDIUM
var is_input_enabled = false

signal pit_stop_completed(tyre_type)
 
# Called when the node enters the scene tree for the first time.
func _ready():
	tyres = [{
		node = tyre_soft,
		type = tyre_types.SOFT,
		}, {
		node = tyre_medium,
		type = tyre_types.MEDIUM,
		},
		{
		node = tyre_hard,
		type = tyre_types.HARD,
		},
		{
		node = tyre_wet,
		type = tyre_types.WET,
	}]
	render_tyres()
	
func render_tyres():
	for tyre in tyres:
		var tyre_node: Sprite2D = tyre.node
		if tyre.type == selected_tyre:
			if is_input_enabled:
				tyre_node.modulate = Color(1, 1, 1, 1)
			else:
				tyre_node.modulate = Color(1, 1, 1, 0.5)
			var tyre_tween = get_tree().create_tween()
			tyre_tween.set_ease(Tween.EASE_IN_OUT)
			tyre_tween.tween_property(tyre_node, "scale",  Vector2(0.55, 0.55), 0.1)
		else: 
			var tyre_tween = get_tree().create_tween()
			tyre_tween.set_ease(Tween.EASE_IN_OUT)
			tyre_tween.tween_property(tyre_node, "scale",  Vector2(0.5, 0.5), 0.1)
			tyre_node.modulate = Color(1, 1, 1, 0.5)
			
func select_tyre(offset: int): 
	var tyre_index = 0
	var next_index = 0
	for tyre in tyres:
		if tyre.type == selected_tyre:
			next_index = tyre_index + offset
			if next_index < 0:
				next_index = len(tyres) - 1
			if next_index == len(tyres):
				next_index = 0
			break
		tyre_index += 1
	selected_tyre = tyres[next_index].type

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not is_input_enabled:
		return 
	if Input.is_action_just_pressed("steerRight"):
		select_tyre(1)
		render_tyres()
	if Input.is_action_just_pressed("steerLeft"):
		select_tyre(-1)
		render_tyres()
	if Input.is_action_just_pressed("enter"):
		print_debug("ENTER", selected_tyre)
		pit_stop_completed.emit(selected_tyre)

func _on_visibility_changed():
	if not get_tree() or not car: 
		return
	if visible:
		car.play("yellow", -0.5)
		car.global_position = Vector2(-30, 340)		
		var car_tween = get_tree().create_tween()
		car_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		car_tween.tween_property(car, "position", Vector2(340, 340), 1)
		car_tween.tween_callback(func(): 
			car.play("yellow", 0)
			is_input_enabled = true
			render_tyres()
		)
	else:
		is_input_enabled = false
		render_tyres()
