extends CanvasLayer

@onready var lapCounterLabel = $LapCounter
@onready var lastLapTime = $LastLapTime
@onready var sessionBestLapTime = $SessionBestLapTime
@onready var purpleRect = $PurpleRect
@onready var tyre_health_label = $TyreHealth
@onready var tyre_temp_label = $TyreTemp
@onready var qualify_time_label = $QualifyTime

signal race_completed(playerState)
signal qualify_completed(playerState)


var raceState = {
	laps = 0,
	qualify = 0,
	qualify_remaining = 0,
	qualify_start_time = 0
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
	
func start_qualify(qualify_time: int):
	print_debug("start qualify: ", qualify_time)
	
	raceState.qualify = (qualify_time * 60) * 1000
	raceState.qualify_start_time = Time.get_ticks_msec()
	raceState.qualify_remaining = raceState.qualify
	resetLaps(0)
	reset_session()
	updateLabels()
	 
func reset_session():
	playerState.bestLap = 0
	playerState.lastLapTime = 0
	
	
func formatDuration(duration: int):
	var seconds = floor(duration / 1000)
	var ms = duration % 1000
	return str(seconds) + ":" + str(ms).pad_zeros(3)
	
func formatQualifyDuration(duration: int):
	var totalSeconds = duration / 1000
	var minutes = totalSeconds / 60
	var seconds = totalSeconds % 60
	return str(minutes) + ":" + str(seconds).pad_zeros(2)
	
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
	lastLapTime.text = "LAST " + formatDuration(duration)
	
	# Session best lap
	sessionBestLapTime.text = "BEST " + formatDuration(playerState.bestLap)
	
	if playerState.lap > 1 && playerState.lastLapTime == playerState.bestLap:
		purpleRect.visible = true
	
	if raceState.qualify == 0:
		qualify_time_label.hide()

func update_qualify_time():
	if raceState.qualify > 0:
		qualify_time_label.visible = true
		qualify_time_label.text = "QUALIFY " + formatQualifyDuration(raceState.qualify_remaining)
	else: 
		qualify_time_label.visible = false
	
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
	
	if raceState.qualify == 0 && raceState.laps > 0 && playerState.lap == raceState.laps + 1: 
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
	if raceState.qualify > 0 && raceState.qualify_remaining >= 0:
		var current_time = Time.get_ticks_msec()
		var diff = current_time - raceState.qualify_start_time
		raceState.qualify_remaining = raceState.qualify - diff #- 50000
		update_qualify_time()
	if raceState.qualify > 0 && raceState.qualify_remaining < 1:
		raceState.qualify = 0
		qualify_completed.emit(playerState.duplicate())
	
	
