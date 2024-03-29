extends CanvasLayer

@onready var lapCounterLabel = $LapCounter
@onready var lastLapTime = $LastLapTime
@onready var sessionBestLapTime = $SessionBestLapTime
@onready var purpleRect = $PurpleRect
@onready var tyre_health_label = $TyreHealth
@onready var tyre_temp_label = $TyreTemp

signal race_completed(playerState)


var raceState = {
	laps = 0
}

var playerState = {
	lapStartTime = 0,
	raceStartTime = 0,
	lap = 0,
	bestLap = 0,
	lastLapTime = 0,
	raceTime = 0,
	name = ""
}

var tyre_temp = 100

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func resetLaps(laps: int):
	raceState.laps = laps
	
	playerState.lap = 1
	updateLabels()
		
	purpleRect.visible = false
	
func reset_session():
	playerState.bestLap = 0
	playerState.lastLapTime = 0
	
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

func lap_completed(playerNick): 
	var currentTime = Time.get_ticks_msec()
	var duration = currentTime - playerState.lapStartTime
		
	playerState.name = playerNick
	
	if duration < playerState.bestLap || playerState.bestLap == 0:
		playerState.bestLap = duration

	playerState.lastLapTime = duration
	playerState.lap += 1
	playerState.raceTime = currentTime - playerState.raceStartTime 
	
	updateLabels()
	
	playerState.lapStartTime = Time.get_ticks_msec()
	
	if raceState.laps > 0 && playerState.lap == raceState.laps + 1: 
		race_completed.emit(playerState.duplicate())
	
func checkpoint_completed():
	purpleRect.visible = false
	
func race_started():
	playerState.raceStartTime = Time.get_ticks_msec()
	self.visible = true
	
func set_tyre_health(tyre_health, reset):
	if (reset):
		tyre_temp = 100
	else:
		var tyre_precent = min(ceil(tyre_health * 100), 100)
		tyre_temp = max(tyre_temp, ceil(tyre_health * 100))
		tyre_health_label.text = "TYRES " + str(tyre_precent) + "%"
		tyre_temp_label.text = str(tyre_temp) + "°C"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
