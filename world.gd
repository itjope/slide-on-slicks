extends Node2D

@onready var mainMenu = $CanvasLayer/MainManu
@onready var addressEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/AddressEntry
@onready var playerNameEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/PlayerNameEntry
@onready var playerNameError = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/LabelPlayerNameError
@onready var dedicatedServerCheckbox = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/DedicatedServerCheckbox
@onready var serverAddressList = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/AddressList
@onready var splashImage = $CanvasLayer/SplashImage
@onready var networkNode = $Network
@onready var tracksNode = $tracks
@onready var raceInfoNode = $RaceInfo
@onready var raceCompleted = $RaceCompleted
@onready var raceCompletedGrid = $RaceCompleted/PanelContainer/MarginContainer/VBoxContainer/GridContainerRace
@onready var championshipGrid = $RaceCompleted/PanelContainer/MarginContainer/VBoxContainer/GridContainerChampionship
@onready var qualifyCompleted = $QualifyCompleted
@onready var qualifyCompletedGrid = $QualifyCompleted/PanelContainer/MarginContainer/VBoxContainer/GridContainerQualify

@onready var race_settings = $RaceSettings
@onready var pit_wrapper = $PitWrapper
@onready var rain_puddles = $RainPuddles
@onready var sun_canvas = $SunCanvas

# Race settings meny
@onready var raceMenu = $RaceSettings/RaceMenu
@onready var raceNumberOfLapsInput = $RaceSettings/RaceMenu/MarginContainer/VBoxContainer/NumerOfLapsInput
@onready var qualifyTimeInput = $RaceSettings/RaceMenu/MarginContainer/VBoxContainer/QualifyTimeInput
@onready var raceTrackList = $RaceSettings/RaceMenu/MarginContainer/VBoxContainer/TrackList

var Player = preload("res://player.tscn")
var start_lights = preload("res://start_lights.tscn")
var PitScene = preload("res://Pit.tscn")
var track_scenes = [{
	name = "Ettan",
	scene = preload("res://track1.tscn")
}, {
	name = "Olovs Oval",
	scene = preload("res://track2.tscn")
}]
var player_nodes = []
var PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
var gridPositions = []
var carColors = ["blue", "pink", "green", "yellow"]
var isServer = false
var isDedicatedServer = false
var trackNode: Node2D
var pit_node: Node2D
var pit_is_open: bool = false
var current_track_index:int = -1

enum weather_conditons {SUN, LIGHTRAIN, RAIN, WET}
var current_weather = weather_conditons.SUN
var weather_shift_timer = Timer.new()


var raceCompledPlayers = []
var qualifyCompledPlayers = []
var playerChampionshipPoints = {}
var positionToPoint = {
	1: 8,
	2: 6,
	3: 4,
	4: 3
}

var rain_tween = null

func _ready():
	if OS.is_debug_build():
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		playerNameEntry.text = "P" + str(randi() % 100)
	
	init_track(0)
	init_pit()
	for track in track_scenes:
		raceTrackList.add_item(track.name)
	raceTrackList.select(0)
	 
	update_grid_positions()
	
	if OS.get_cmdline_args().has("--server"):
		createServer()
	
	if multiplayer.is_server():
		add_child(weather_shift_timer)
		weather_shift_timer.connect("timeout", _on_weather_timeout)


		
func get_car_color():
	var car_color = "blue"
	for player in networkNode.get_children():
		if str(multiplayer.get_unique_id()) == player.name:
			car_color = player.car_animation_color
	return car_color
	
func init_pit():
	pit_node = PitScene.instantiate()
	pit_node.visible = false
	pit_node.pit_stop_completed.connect(pit_completed)
	pit_wrapper.add_child(pit_node)
	
func _on_weather_timeout():
	if current_weather == weather_conditons.WET:
		current_weather = weather_conditons.SUN
	else:
		current_weather += 1
	
	set_weather.rpc(current_weather)
	set_weather_timeout()
		
func pit_completed(tyre_type):
	pit_node.visible = false
	sun_canvas.visible = true
	toggle_pit()
	
	for player in networkNode.get_children():
		player.exit_pit(tyre_type)
	
func init_track(track_index: int): 
	if (track_index == current_track_index): 
		return
		
	for track in tracksNode.get_children():
		tracksNode.remove_child(track)
		track.queue_free()
	trackNode = track_scenes[track_index].scene.instantiate()
	tracksNode.add_child(trackNode)
	
	trackNode.lap_completed.connect(on_lap_completed)
	trackNode.race_started.connect(raceInfoNode.race_started)
	trackNode.checkpoint_completed.connect(raceInfoNode.checkpoint_completed)
	raceInfoNode.race_completed.connect(on_race_completed)
	raceInfoNode.qualify_completed.connect(on_qualify_completed)
	
	raceInfoNode.reset_session()
	
	current_track_index = track_index

func on_lap_completed(player_nick: String, player_name: String):
	raceInfoNode.lap_completed(player_nick, player_name)
	if pit_is_open:
		pit_node.car_color = get_car_color()
		pit_node.visible = true
		sun_canvas.visible = false
		for player in networkNode.get_children():
			player.enter_pit()

func createServer():
	print("Starting server...")
	isServer = true
	var args = OS.get_cmdline_args() 
	
	if args.has("--port"):
		var portIndex = args.find("--port")
		PORT = int(args[portIndex + 1])
	
	print("PORT: ", PORT)
	mainMenu.hide()
	splashImage.hide()
	enetPeer.create_server(PORT)
	
	multiplayer.multiplayer_peer = enetPeer
	multiplayer.peer_connected.connect(handleConnectedPlayer)
	multiplayer.peer_disconnected.connect(removePlayer)
	
	if not dedicatedServerCheckbox.is_pressed() && not args.has("--server"):
		addHostedPlayer(multiplayer.get_unique_id())
	else:
		isDedicatedServer = true
		
	print("Server started")

func update_grid_positions():
	for grid_node in trackNode.get_node("Grid").get_children():
		gridPositions.append(grid_node.global_position)

func _process(delta):
	if current_weather == weather_conditons.LIGHTRAIN or current_weather == weather_conditons.RAIN:
		rain_puddles.emitting = true
	else:
		rain_puddles.emitting = false
	
	if current_weather == weather_conditons.LIGHTRAIN:
		rain_puddles.amount = 7
	
	if current_weather == weather_conditons.RAIN:
		rain_puddles.amount = 100
		
func _on_host_button_pressed():
	if playerNameEntry.text == "":
		playerNameError.visible = true
	else:
		playerNameError.visible = false
		createServer()

func _on_join_button_pressed():
	if playerNameEntry.text == "":
		playerNameError.visible = true
	else:
		mainMenu.hide()
		splashImage.hide()
		var error = enetPeer.create_client(addressEntry.text, PORT)
		if error != OK:
			OS.alert("Failed to connect!")

		multiplayer.multiplayer_peer = enetPeer

@rpc("authority", "call_local", "reliable")
func set_weather(weather):
	if rain_tween:
		rain_tween.kill()
		
	current_weather = weather
	for player in networkNode.get_children():
		player.update_weather(weather)
		
	if current_weather == weather_conditons.LIGHTRAIN:
		rain_tween = get_tree().create_tween()
		rain_tween.tween_property(sun_canvas, "color", Color(0.834, 0.899, 0.994, 0.92), 3)
		rain_tween.play()
	
	if current_weather == weather_conditons.RAIN:
		rain_tween = get_tree().create_tween()
		rain_tween.tween_property(sun_canvas, "color", Color(0.671, 0.8, 0.988, 0.929), 3)
		rain_tween.play()
		
	if current_weather == weather_conditons.WET:
		rain_tween = get_tree().create_tween()
		rain_tween.tween_property(sun_canvas, "color", Color.WHITE, 3)
		rain_tween.play()

@rpc("any_peer", "call_local")
func set_grid_pos(peerId: String, pos: int):
	for player in networkNode.get_children():
		if player.name == peerId:
			player.set_grid(gridPositions[pos])
		
@rpc("any_peer", "call_local")
func set_car_color(peerId: String, color: String):
	for player in networkNode.get_children():
		if player.name == peerId:
			player.car_animation_color = color

func set_weather_timeout(): 
	weather_shift_timer.stop()
	#var from = 1 * 60 #minutes
	#var to = 5 * 60 #minutes
	var from = 10 #minutes
	var to = 20 #minutes
	
	#if current_weather == weather_conditons.LIGHTRAIN:
		#from = 10 #seconds
		#to = 1  * 60 #minutes
	#
	#if current_weather == weather_conditons.WET:
		#from = 10 #seconds
		#to = 30 #seconds
		
	var next_weather_in = randi() % (to - from + 1) + from
	weather_shift_timer.wait_time = next_weather_in
	weather_shift_timer.start()
	
@rpc("any_peer", "call_local")
func race_restart(numberOfLaps: int, track_index: int, qualify_time: int):
	init_track(track_index)
	update_grid_positions()
	
	raceNumberOfLapsInput.text = str(numberOfLaps)
	raceTrackList.select(track_index)
	raceCompledPlayers.clear()
	var lights = start_lights.instantiate()
	for player in networkNode.get_children():
		player.race_restart()
	
	raceInfoNode.resetLaps(numberOfLaps)
	trackNode.reset_session()
	
	if qualify_time > 0:
		raceInfoNode.start_qualify(qualify_time)
		
	add_child(lights)
	raceCompleted.hide()
	qualifyCompleted.hide()
	
	await get_tree().create_timer(6).timeout
	lights.queue_free()
	
	if multiplayer.is_server():
		set_weather.rpc(current_weather)
		if weather_shift_timer.is_stopped():
			set_weather_timeout()
			
	if not isDedicatedServer:
		send_player_nick_update()
	
@rpc("any_peer")
func race_completed(playerState):
	var i = 0
	for player in raceCompledPlayers:
		if player.name == playerState.name:
			raceCompledPlayers.remove_at(i)
		i += 1
	
	raceCompledPlayers.append(playerState)
	raceCompledPlayers.sort_custom(func(a, b): 
		return a.raceTime < b.raceTime
	)
	
	for c in raceCompletedGrid.get_children():
		raceCompletedGrid.remove_child(c)
		c.queue_free()
	
	var p = 1
	for player in raceCompledPlayers:
		var labelPoistion = Label.new()
		labelPoistion.text = "#" + str(p)
		var labelName = Label.new()
		labelName.text = player.nick
		
		if (player.name == playerState.name):
			if (not playerChampionshipPoints.has(playerState.name)):
				playerChampionshipPoints[playerState.name] = {
					points = 0,
					name = playerState.name,
					nick = playerState.nick
				}
			
			playerChampionshipPoints[playerState.name].merge({
				points = playerChampionshipPoints[playerState.name].points + positionToPoint[p]
			}, true)
		var labelPoints = Label.new()
		labelPoints.text = str(positionToPoint[p]) + "p"
		
		raceCompletedGrid.add_child(labelPoistion)
		raceCompletedGrid.add_child(labelName)
		raceCompletedGrid.add_child(labelPoints)
		
		p += 1
	
	var champPoints = playerChampionshipPoints.values()
	champPoints.sort_custom(func(a, b): 
		return a.points > b.points
	)
	
	
	for c in championshipGrid.get_children():
		championshipGrid.remove_child(c)
		c.queue_free()
	
	var cp = 1
	for player in champPoints:
		
		var labelPoistion = Label.new()
		labelPoistion.text = "#" + str(cp)
		var labelName = Label.new()
		labelName.text = player.nick
		var labelPoints = Label.new()
		labelPoints.text = str(player.points) + "p"
		labelPoints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT		
		
		championshipGrid.add_child(labelPoistion)
		championshipGrid.add_child(labelName)
		championshipGrid.add_child(labelPoints)
		
		cp += 1
	
	if multiplayer.is_server():
		weather_shift_timer.stop()

func formatDuration(duration: int):
	var seconds = floor(duration / 1000)
	var ms = duration % 1000
	return str(seconds) + ":" + str(ms).pad_zeros(3)

@rpc("any_peer", "call_local")
func qualify_completed(playerState):
	if isDedicatedServer:
		print_debug("quali completed as dedicated server")
		return
		
	print_debug("quali completed", playerState.name)
	var i = 0
	for player in qualifyCompledPlayers:
		if player.name == playerState.name:
			qualifyCompledPlayers.remove_at(i)
		i += 1
	
	qualifyCompledPlayers.append(playerState)
	
	qualifyCompledPlayers.sort_custom(func(a, b): 
		if a.bestLap == 0:
			return false
		else:
			return a.bestLap < b.bestLap
	)
	
	for c in qualifyCompletedGrid.get_children():
		qualifyCompletedGrid.remove_child(c)
		c.queue_free()
	
	var p = 1
	for player in qualifyCompledPlayers:
		var labelPoistion = Label.new()
		labelPoistion.text = "#" + str(p)
		var labelName = Label.new()
		labelName.text = player.nick
		
		var labelTime = Label.new()
		labelTime.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		labelTime.text = formatDuration(player.bestLap)
		
		qualifyCompletedGrid.add_child(labelPoistion)
		qualifyCompletedGrid.add_child(labelName)
		qualifyCompletedGrid.add_child(labelTime)
		
		p += 1
		

	
@rpc("any_peer", "call_local")
func player_nick_update(peerId: String, nick: String):	
	for player in networkNode.get_children():
		if player.name == peerId:
			player.set_nick(nick) 

func handleConnectedPlayer(peerId):
	var player = addPlayer(peerId)
	set_weather.rpc(current_weather)

func addHostedPlayer(peerId):
	var player = addPlayer(peerId)
	player.set_grid(gridPositions[0])
			
func addPlayer(peerId): 
	var player = Player.instantiate()
	player.name = str(peerId)
	networkNode.add_child(player)
	player.find_child("Smoothing2D").teleport()
	
	return player

func toggle_pit(): 
	pit_is_open = !pit_is_open
	trackNode.toggle_pit()

func removePlayer(peerId): 
	get_node("Network").get_node(str(peerId)).queue_free()
	
func send_player_nick_update():
	rpc("player_nick_update", str(multiplayer.get_unique_id()), playerNameEntry.text)
	
@rpc("any_peer")
func client_connected(): 
	send_player_nick_update()
	
func _on_network_child_entered_tree(node: Node2D):
	if is_multiplayer_authority() && not isDedicatedServer:
		rpc_id(int(str(node.name)), "client_connected")
	
	_on_player_node_ready(node)
	
func _on_player_node_ready(node):
	player_nodes.append(node)
	node.visible = false
	await get_tree().create_timer(1).timeout
	node.visible = true
	race_settings.visible = true
	
	send_player_nick_update()
	if str(multiplayer.get_unique_id()) == node.name:
		node.connect("tyre_health_changed", raceInfoNode.set_tyre_health)
		node.connect("toggle_pit", toggle_pit)
	
	if isServer:
		var carColor = carColors[len(player_nodes) - 1]
		node.car_animation_color = carColor
		var carColorIndex = 0
		for player in player_nodes:
			if carColorIndex >= len(player_nodes):
				carColorIndex = 0
			carColor = carColors[carColorIndex]
			rpc("set_car_color", player.name, carColor)
			carColorIndex += 1
		
	if isServer:
		var gridPos = len(player_nodes) - 1
		rpc_id(int(str(node.name)), "set_grid_pos", node.name, gridPos)
	
func _on_address_list_item_selected(index):
	if index == 0:
		addressEntry.text = "46.246.39.82"
		addressEntry.visible = false
	else:
		addressEntry.visible = true
		addressEntry.text = "localhost"

func _on_start_race_button_pressed():
	raceMenu.hide()
	var numberOfLaps = raceNumberOfLapsInput.text.to_int();
	var qualifyTime = qualifyTimeInput.text.to_int();
	var selected_track_index = 0
	
	for selected_track in raceTrackList.get_selected_items():
		selected_track_index = selected_track
		
	rpc("race_restart", numberOfLaps, selected_track_index, qualifyTime)

func _on_link_button_pressed():
	raceMenu.show()
	
func on_race_completed(playerState):
	rpc("race_completed", playerState)
	race_completed(playerState)
	raceCompleted.show()
	
func on_qualify_completed(playerState):
	if isDedicatedServer:
		return
	
	#playerState.node_name = str(multiplayer.get_unique_id())
	rpc("qualify_completed", playerState)
	qualifyCompleted.show()
	
func _on_start_new_race_pressed():
	raceCompleted.hide()
	raceMenu.show()

func _on_qualify_start_race_pressed():
	qualifyCompleted.hide()
	var grid_pos = 0
	for player in qualifyCompledPlayers:
		rpc_id(int(str(player.name)), "set_grid_pos", player.name, grid_pos)
		grid_pos += 1
	
	var numberOfLaps = raceNumberOfLapsInput.text.to_int();
	var qualifyTime = 0;
	var selected_track_index = 0
	
	for selected_track in raceTrackList.get_selected_items():
		selected_track_index = selected_track
		
	rpc("race_restart", numberOfLaps, selected_track_index, qualifyTime)


func _on_network_child_exiting_tree(node):
	player_nodes.erase(node)
