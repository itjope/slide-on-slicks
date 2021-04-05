extends Control

var allPlayers = {}

func _ready():
	pass

func on_finished_lap(body):
	if (body.is_network_master()):
		var playerId = int(body.get_name())
		if (allPlayers[playerId].has("laps")):
			allPlayers[playerId].laps = allPlayers[playerId].laps + 1
		else:
			allPlayers[playerId].laps = 1
		rpc("update_laps", allPlayers[playerId])
	render()
	
func on_start_game(my_info, player_info):
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
		laps = 0
	}
func createGridChild(text):
	var label = Label.new()
	label.text = text
	return label

func clearGrid(grid):
	for child in grid.get_children():
		child.queue_free()

func sortByLaps(a, b):
	return a.laps > b.laps

func render(): 
	var grid = self.get_node("TimingGrid")
	clearGrid(grid)
	
	# Headings
	grid.add_child(createGridChild("Player"))
	grid.add_child(createGridChild("Laps"))
	
	# Sort players by number of laps
	var players = []
	for key in allPlayers.keys():
		players.push_back(allPlayers[key])
	players.sort_custom(self, "sortByLaps")

	# Add players to grid
	for player in players:
		grid.add_child(createGridChild(player.name))
		if (player.has("laps")):
			grid.add_child(createGridChild(str(player.laps)))
		else:
			grid.add_child(createGridChild("0"))

		
