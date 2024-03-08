extends Node2D

@onready var tyre_soft = $TyrePurple
@onready var tyre_medium = $TyreRed
@onready var tyre_hard = $TyreYellow
@onready var tyre_wet = $TyreBlue

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
			tyre_node.modulate = Color(1, 1, 1, 1)
			tyre_node.scale = Vector2(0.55, 0.55)
		else: 
			tyre_node.modulate = Color(1, 1, 1, 0.5)
			tyre_node.scale = Vector2(0.5, 0.5)
			
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
	if visible:
		await get_tree().create_timer(1).timeout
		is_input_enabled = true
	else:
		is_input_enabled = false
