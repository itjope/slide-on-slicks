extends CanvasLayer

var maxLaps = 3

var allPlayers = {}
var raceStart = null
var lapStart = null

signal race_start
signal race_end
signal race_stats(allPlayers)

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

		allPlayers[playerId]["laps"] = laps
		allPlayers[playerId]["finished"] = weHaveAWinner
		
		rpc("update_laps", allPlayers[playerId])
				
	if (is_race_over()):
		 rpc("race_is_over")

	emit_signal("race_stats", allPlayers)
		
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
		
func _on_Server_start_game(my_info, player_info):
	var myId = get_tree().get_network_unique_id()
	allPlayers[myId] = createPlayerEntry(my_info.name)

	for key in player_info.keys():
		allPlayers[key] = createPlayerEntry(player_info[key].name)
	emit_signal("race_stats", allPlayers)

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
	
remote func update_laps(player):
	var playerId = get_tree().get_rpc_sender_id()
	allPlayers[playerId] = player
	emit_signal("race_stats", allPlayers)
	
func _on_TrafficLight_green_light():
	race_start()
