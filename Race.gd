extends CanvasLayer

var maxLaps = 3

var allPlayers = {}
var raceStart = null
var lapStart = null

signal race_start
signal race_end
signal race_stats(allPlayers)
signal show_lobby()

var startNewRaceButton = null

func _ready():
	# startNewRaceButton = self.get_node("RaceControl").get_node("StartNewRace")
	startNewRaceButton = $RaceControl/StartNewRace
	startNewRaceButton.connect("pressed", self, "_start_new_game")


func _start_new_game():
	startNewRaceButton.hide()
	emit_signal("show_lobby")
	

func _on_Track_finished_lap(body):	
	if (body.is_network_master()):		
		var playerId = int(body.get_name())
		# Lap Timing
		var currentTime = OS.get_ticks_msec()
		var lapTime = null
		if (lapStart):
			lapTime = currentTime - lapStart
		else:
			lapTime = currentTime - raceStart
		
		allPlayers[playerId].lapTimes.push_back(lapTime)

		lapStart = currentTime
		# Lap Timing end

		var laps = allPlayers[playerId].get("laps", 0) + 1
		var weHaveAWinner = we_have_a_winner() || laps == maxLaps
		var lastLap = laps == maxLaps - 1

		allPlayers[playerId]["laps"] = laps
		allPlayers[playerId]["finished"] = weHaveAWinner
		
		rpc("update_laps", allPlayers[playerId])

		$CheckeredFlag.visible = weHaveAWinner
		$WhiteFlag.visible = lastLap && !$CheckeredFlag.visible
					
	if (is_race_over()):
		 rpc("race_is_over")
		 startNewRaceButton.show()
		 
		
func we_have_a_winner():
	var weHaveAWinner = false
	for pId in allPlayers:
		weHaveAWinner = weHaveAWinner || allPlayers[pId]["finished"]
	return weHaveAWinner

func is_race_over():
	var race_end = true
	for pId in allPlayers:
		race_end = race_end && allPlayers[pId]["finished"]
	return race_end

remotesync func race_is_over():
	emit_signal("race_end")
		
func _on_Server_start_game(my_info, player_info, game_options):
	maxLaps = game_options.laps
	raceStart = null
	lapStart = null
	$CheckeredFlag.visible = false
	$WhiteFlag.visible = false
					
	var myId = get_tree().get_network_unique_id()
	allPlayers[myId] = createPlayerEntry(my_info.name)

	for key in player_info.keys():
		allPlayers[key] = createPlayerEntry(player_info[key].name)
	emit_signal("race_stats", allPlayers.values())

func createPlayerEntry(name):
	return {
		name = name,
		laps = 0,
		finished = false,
		lapTimes = []
	}

func race_start():
	raceStart = OS.get_ticks_msec()
	emit_signal("race_start")

func sortPlayers(p1, p2):
	if p1.laps != p2.laps:
		return clamp(p1.laps, 0, maxLaps) > clamp(p2.laps, 0, maxLaps)
		
	var i = 0
	var p1TotTime = 0
	while i < p1.lapTimes.size() && i < maxLaps:
		p1TotTime += p1.lapTimes[i]
		i+=1

	i = 0
	var p2TotTime = 0
	while i < p2.lapTimes.size() && i < maxLaps:
		p2TotTime += p2.lapTimes[i]
		i+=1

	return p1TotTime < p2TotTime

remotesync func update_laps(player):
	var playerId = get_tree().get_rpc_sender_id()
	allPlayers[playerId] = player
	
	var stats = allPlayers.values()
	stats.sort_custom(self, "sortPlayers")
	
	emit_signal("race_stats", stats)
	
func _on_TrafficLight_green_light():
	race_start()
