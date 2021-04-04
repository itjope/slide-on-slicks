extends CanvasLayer

signal finished_lap(body)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var prev_checkpoint = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Checkpoints_body_shape_entered(body_id, body, body_shape, area_shape):
	var cur = area_shape
	var prev = prev_checkpoint.get(body_id)
	var last = get_node("Checkpoints").get_child_count()-1
	
	if (prev == last && cur == 0):
		print("finished_lap: " + str(body))
		emit_signal("finished_lap", body)	
		prev_checkpoint[body_id] = cur
	elif (prev + 1 == cur):
		prev_checkpoint[body_id] = cur
