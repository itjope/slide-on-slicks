extends Node2D

var playerLaps = {}
# Called when the node enters the scene tree for the first time.
@onready var finishLine = $FinnishLine/CollisionShape2D
@onready var lapCounterLabel = $RaceInfo/LapCounter
@onready var lastLapTime = $RaceInfo/LastLapTime
@onready var sessionBestLapTime = $RaceInfo/SessionBestLapTime
@onready var purpleRect = $RaceInfo/PurpleRect
@onready var raceInfo = $RaceInfo


var raceState = {
	laps = 0
}
	

var playerState = {
	lapStartTime = 0,
	raceStartTime = 0,
	lap = 0,
	bestLap = 0,
	checkpoint = 0,
	lastLapTime = 0,
	raceTime = 0,
	name = ""
}
	

func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func resetLaps(laps: int):
	raceState.laps = laps
	
	playerState.lap = 1
	updateLabels()
		
	purpleRect.visible = false
	
func formatDuration(duration: int):
	var seconds = floor(duration / 1000)
	var ms = duration % 1000
	return str(seconds) + ":" + str(ms)
	
func updateLabels():
	# Lap counter
	lapCounterLabel.text = "LAP " + str(playerState.lap)
	if raceState.laps > 0: 
		lapCounterLabel.text += "/" + str(raceState.laps)
	
	if raceState.laps > 0 && playerState.lap > raceState.laps:
		lapCounterLabel.text = "FINISHED"
	
	# Duration
	var duration = playerState.lastLapTime
	
	# Last lap
	lastLapTime.text = "LAST LAP " + formatDuration(duration)
	
	# Session best lap
	sessionBestLapTime.text = "SESSION BEST " + formatDuration(playerState.bestLap)
	
	if playerState.lastLapTime == playerState.bestLap:
		purpleRect.visible = true
	
func _on_finnish_line_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
	
	if not str(multiplayer.get_unique_id()) == body.name:
		return
		
	playerState.name = body.player_nick
	raceInfo.visible = true
	
	if playerState.lap < 1:
		playerState.raceStartTime = Time.get_ticks_msec()
	
	if playerState.checkpoint == 2:
		var currentTime = Time.get_ticks_msec()
		var duration = currentTime - playerState.lapStartTime
		print_debug("ceckpoint2: ", currentTime, " : ", playerState.lapStartTime, " : ", duration)
		
		if duration < playerState.bestLap || playerState.bestLap == 0:
			playerState.bestLap = duration

		playerState.lastLapTime = duration
		playerState.lap += 1
		playerState.checkpoint = 0
		playerState.raceTime = currentTime - playerState.raceStartTime 
		
		updateLabels()
		
		playerState.lapStartTime = Time.get_ticks_msec()
	
	if raceState.laps > 0 && playerState.lap == raceState.laps + 1: 
		self.get_parent().get_parent().on_race_completed(playerState.duplicate())
		
func _on_checkpoint_1_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
		
	if not str(multiplayer.get_unique_id()) == body.name:
		return
	
	if playerState.checkpoint == 0:
		purpleRect.visible = false
		playerState.checkpoint = 1


func _on_checkpoint_2_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
	if not str(multiplayer.get_unique_id()) == body.name:
		return
	
	if playerState.checkpoint == 1:
		playerState.checkpoint = 2
