extends CanvasLayer

signal race_start

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _on_TrafficLight_green_light():
	emit_signal("race_start")
