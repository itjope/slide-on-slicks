extends Node2D

var playerLaps = {}
# Called when the node enters the scene tree for the first time.
@onready var finishLine = $FinnishLine/CollisionShape2D
@onready var lapCounterLabel = $RaceInfo/LapCounter
@onready var lastLapTime = $RaceInfo/LastLapTime
@onready var sessionBestLapTime = $RaceInfo/SessionBestLapTime
@onready var purpleRect = $RaceInfo/PurpleRect
@onready var raceInfo = $RaceInfo

var lapStartTime: int = 0
	
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func resetLaps():
	for playerIndex in playerLaps:
		playerLaps[playerIndex].lap = 1
		updateLabels(playerIndex)
		
	purpleRect.visible = false
	
func updateLabels(playerId):
	var currentPlayer =  str(multiplayer.get_unique_id())
	if currentPlayer != playerId:
		return 
		
	if not playerLaps.has(currentPlayer):
		return
	
	# Lap counter
	lapCounterLabel.text = "LAP " + str(playerLaps[currentPlayer].lap)
	
	var duration = playerLaps[currentPlayer].lastLapTime
	
	# Last lap
	var seconds = floor(duration / 1000)
	var ms = duration % 1000
	lastLapTime.text = "LAST LAP " + str(seconds) + ":" + str(ms)
	
	# Session best lap
	seconds = floor(playerLaps[currentPlayer].sessionBestLapTime / 1000)
	ms = playerLaps[currentPlayer].sessionBestLapTime % 1000
	sessionBestLapTime.text = "SESSION BEST " + str(seconds) + ":" + str(ms)
	
	if playerLaps[currentPlayer].lastLapTime == playerLaps[currentPlayer].sessionBestLapTime:
		purpleRect.visible = true
	
func _on_finnish_line_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
		
	raceInfo.visible = true
	
	if not playerLaps.has(body.name):
		playerLaps[body.name] = {
			lap = 1,
			sessionBestLapTime = 0,
			lastLapTime = 0,
			checkpoint = 0
		}
		lapStartTime = Time.get_ticks_msec()
		return
	
	if playerLaps[body.name].checkpoint == 2:
		var currentTime = Time.get_ticks_msec()
		var duration = currentTime - lapStartTime
		lapStartTime = Time.get_ticks_msec()

		
		if duration < playerLaps[body.name].sessionBestLapTime || playerLaps[body.name].sessionBestLapTime == 0:
			playerLaps[body.name].sessionBestLapTime = duration

		playerLaps[body.name].lastLapTime = duration
		playerLaps[body.name].lap += 1
		playerLaps[body.name].checkpoint = 0
		
		updateLabels(body.name)

func _on_checkpoint_1_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
		
	if not playerLaps.has(body.name):
		return
	
	if playerLaps[body.name].checkpoint == 0:
		purpleRect.visible = false
		playerLaps[body.name].checkpoint = 1


func _on_checkpoint_2_body_entered(body):
	if not body.is_class("CharacterBody2D"):
		return
		
	if not playerLaps.has(body.name):
		return
	
	if playerLaps[body.name].checkpoint == 1:
		playerLaps[body.name].checkpoint = 2

