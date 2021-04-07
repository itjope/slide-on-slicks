extends Control

var allPlayers = {}
var raceStart = null
var lapStart = null
var purple = Color(0.85, 0, 1, 1)
var white = Color(1, 1, 1, 1)
func _ready():
	pass

func on_finished_lap(body):
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

		if (allPlayers[playerId].has("laps")):
			allPlayers[playerId].laps = allPlayers[playerId].laps + 1
		else:
			allPlayers[playerId].laps = 1
		rpc("update_laps", allPlayers[playerId])
	render()
	
func on_start_game(my_info, player_info):
	raceStart = OS.get_ticks_msec()
	var myId = get_tree().get_network_unique_id()
	allPlayers[myId] = createPlayerEntry(my_info.name)

	for key in player_info.keys():
		allPlayers[key] = createPlayerEntry(player_info[key].name)
	render()

remote func update_laps(player):
	var playerId = get_tree().get_rpc_sender_id()
	allPlayers[playerId] = player
	render()

func createPlayerEntry(name):
	return {
		name = name,
		laps = 0,
		lapTimes = []
	}
func createGridChild(text, color = white):
	var label = Label.new()
	label.text = text
	label.add_color_override("font_color", color)
	return label

func clearGrid(grid):
	for child in grid.get_children():
		child.queue_free()

func sortByLaps(a, b):
	return a.laps > b.laps

func msToDuration(duration):
	var milliseconds = duration % 1000
	var seconds = (duration / 1000 ) % 60
	var minutes = (duration / (1000 * 60)) % 60
	var hours = (duration / (1000 * 60 * 60)) % 24
	if (hours < 10):
		 hours = "0" + str(hours)
	
	if (minutes < 10):
		minutes = "0" + str(minutes)
	
	if (seconds < 10): 
		seconds = "0" + str(seconds);
	
	return str(minutes) + ":" + str(seconds) + "." + str(milliseconds) 

func dictToArr(dict):
	var arr = []
	for key in dict.keys():
		arr.push_back(dict[key])
	return arr

func getFastestLap(playersDict): 
	var fastestLap = {
		lapTime = null,
		name = null,
		lap = null
	}
	var players = dictToArr(playersDict)
	for player in players:
		var lapCounter = 1
		for lapTime in player.lapTimes:
			if fastestLap.lapTime == null || lapTime < fastestLap.lapTime:
				fastestLap.lapTime = lapTime
				fastestLap.name = player.name
				fastestLap.lap = lapCounter
			lapCounter += 1
	return fastestLap

func render(): 
	var grid = self.get_node("TimingGrid")
	clearGrid(grid)
	var fastestLap = getFastestLap(allPlayers)
	
	# Headings
	grid.add_child(createGridChild("Player"))
	grid.add_child(createGridChild("Lap"))
	grid.add_child(createGridChild("Time"))
	
	# Sort players by number of laps
	var players = dictToArr(allPlayers)
	players.sort_custom(self, "sortByLaps")

	# Add players to grid
	for player in players:
		grid.add_child(createGridChild(player.name))
		
		if (player.has("laps")):
			grid.add_child(createGridChild(str(player.laps)))
		else:
			grid.add_child(createGridChild("0"))

		var lastLapTime = player.lapTimes.back()
		if (lastLapTime):
			var color = purple if lastLapTime <= fastestLap.lapTime else white
			grid.add_child(createGridChild(msToDuration(lastLapTime), color))
		else:
			grid.add_child(createGridChild(""))
	
	# Create empty row
	for _i in range(3):
		grid.add_child(createGridChild(""))

	if (fastestLap.name && fastestLap.lapTime):
		grid.add_child(createGridChild("Fastest Lap"))
		grid.add_child(createGridChild(""))
		grid.add_child(createGridChild(""))
		grid.add_child(createGridChild(fastestLap.name))
		grid.add_child(createGridChild(str(fastestLap.lap)))

		grid.add_child(createGridChild(msToDuration(fastestLap.lapTime)))	
	
			

	
