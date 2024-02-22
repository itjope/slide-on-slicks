extends Node2D


@export var finishLine: Area2D
@export var checkpoints: Array[Area2D]

signal lap_completed(playerNick)
signal race_started
signal checkpoint_completed

var playerLaps = {}

var playerState = {
	lap = 0,
	checkpoint = 0,
}

func _ready():
	finishLine.body_entered.connect(_on_finnish_line_body_entered)
	for i in range(checkpoints.size()):
		var checkpoint = checkpoints[i]
		checkpoint.body_entered.connect(func(body): _on_checkpoint_body_entered(body, i))
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _on_finnish_line_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
	
	if not str(multiplayer.get_unique_id()) == body.name:
		return
		
	if playerState.lap < 1:
		race_started.emit()
	
	if playerState.checkpoint == checkpoints.size():
		playerState.checkpoint = 0
		lap_completed.emit(body.player_nick)
	
func _on_checkpoint_body_entered(body, checkpointIndex):
	if not body.is_class("CharacterBody2D"):
		return
	
	if not str(multiplayer.get_unique_id()) == body.name:
		return
		
	if playerState.checkpoint == checkpointIndex:
		playerState.checkpoint = checkpointIndex + 1
		checkpoint_completed.emit()
