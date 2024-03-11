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
#@onready var trackNode = $tracks/track1
@onready var raceInfoNode = $RaceInfo
@onready var raceCompleted = $RaceCompleted
@onready var raceCompletedGrid = $RaceCompleted/PanelContainer/MarginContainer/VBoxContainer/GridContainerRace
@onready var championshipGrid = $RaceCompleted/PanelContainer/MarginContainer/VBoxContainer/GridContainerChampionship
@onready var race_settings = $RaceSettings
@onready var pit_wrapper = $PitWrapper
@onready var rain_puddles = $RainPuddles
@onready var sun_canvas = $SunCanvas

# Race settings meny
@onready var raceMenu = $RaceSettings/RaceMenu
@onready var raceNumberOfLapsInput = $RaceSettings/RaceMenu/MarginContainer/VBoxContainer/NumerOfLapsInput
@onready var raceTrackList = $RaceSettings/RaceMenu/MarginContainer/VBoxContainer/TrackList

var Player = preload("res://player.tscn")
var start_lights = preload("res://start_lights.tscn")
var PitScene = preload("res://pit.tscn")
var track_scenes = [{
	name = "Ettan",
	scene = preload("res://track1.tscn")
}, {
	name = "Olovs Oval",
	scene = preload("res://track2.tscn")
}]
var PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
var gridPositions = []
var carColors = ["blue", "pink", "green", "yellow"]
var isServer = false
var trackNode: Node2D
var pit_node: Node2D
var pit_is_open: bool = false
var current_track_index:int = -1

enum weather_conditons {SUN, LIGHTRAIN, RAIN, WET}
var current_weather = weather_conditons.SUN
var weather_shift_timer = Timer.new()

var raceCompledPlayers = []
var playerChampionshipPoints = {}
var positionToPoint = {
	1: 8,
	2: 6,
	3: 4,
	4: 3
}
var rain_tween = null

func _ready():
	#if OS.is_debug_build():
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
	
	raceInfoNode.reset_session()
	
	current_track_index = track_index

func on_lap_completed(player_nick: String):
	raceInfoNode.lap_completed(player_nick)
	if pit_is_open:
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

@rpc("any_peer")
func set_grid_pos(peerId: String, pos: int):
	for player in networkNode.get_children():
		if player.name == peerId:
			player.set_grid(gridPositions[pos])
		
@rpc("any_peer")
func set_car_color(peerId: String, color: String):
	for player in networkNode.get_children():
		if player.name == peerId:
			player.car_animation_color = color

func set_weather_timeout():
	weather_shift_timer.stop()
	var from = 2 * 60 #minutes
	var to = 7 * 60 #minutes
	
	if current_weather == weather_conditons.LIGHTRAIN:
		from = 20 #seconds
		to = 1  * 60 #minutes
	
	if current_weather == weather_conditons.WET:
		from = 30 #seconds
		to = 2  * 60 #minutes
		
		
	var next_weather_in = randi() % (to - from + 1) + from
	weather_shift_timer.wait_time = next_weather_in
	weather_shift_timer.start()
	
@rpc("any_peer")
func race_restart(numberOfLaps: int, track_index: int):
	init_track(track_index)
	update_grid_positions()
	
	raceNumberOfLapsInput.text = str(numberOfLaps)
	raceTrackList.select(track_index)
	raceCompledPlayers.clear()
	var lights = start_lights.instantiate()
	for player in networkNode.get_children():
		player.race_restart()
	
	raceInfoNode.resetLaps(numberOfLaps)
		
	add_child(lights)
	raceCompleted.hide()
	
	await get_tree().create_timer(6).timeout
	lights.queue_free()
	
	if multiplayer.is_server():
		set_weather_timeout()
		
		
	
@rpc("any_peer")
func race_completed(playerState):
	var i = 0
	for player in raceCompledPlayers:
		if player.name == playerState.name:
			raceCompledPlayers.erase_at(0)
		i += 1
	
	raceCompledPlayers.append(playerState)
	raceCompledPlayers.sort_custom(func(a, b): a.raceTime - b.raceTime)
	
	for c in raceCompletedGrid.get_children():
		raceCompletedGrid.remove_child(c)
		c.queue_free()
	
	var p = 1
	for player in raceCompledPlayers:
		var labelPoistion = Label.new()
		labelPoistion.text = "#" + str(p)
		var labelName = Label.new()
		labelName.text = player.name
		
		if (player.name == playerState.name):
			if (not playerChampionshipPoints.has(playerState.name)):
				playerChampionshipPoints[playerState.name] = {
					points = 0,
					name = playerState.name
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
	champPoints.sort_custom(func(a, b): a.points - b.points)
	
	
	for c in championshipGrid.get_children():
		championshipGrid.remove_child(c)
		c.queue_free()
	
	var cp = 1
	for player in champPoints:
		
		var labelPoistion = Label.new()
		labelPoistion.text = "#" + str(cp)
		var labelName = Label.new()
		labelName.text = player.name
		var labelPoints = Label.new()
		labelPoints.text = str(player.points) + "p"
		
		championshipGrid.add_child(labelPoistion)
		championshipGrid.add_child(labelName)
		championshipGrid.add_child(labelPoints)
		
		cp += 1
	
	if multiplayer.is_server():
		weather_shift_timer.stop()
	
@rpc("any_peer")
func player_nick_update(peerId: String, nick: String):	
	for player in networkNode.get_children():
		if player.name == peerId:
			player.set_nick(nick) 

func handleConnectedPlayer(peerId):
	var player = addPlayer(peerId)

func addHostedPlayer(peerId):
	#var gridPos = networkNode.get_child_count() - 1
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


func _on_network_child_entered_tree(node: Node2D):
	node.visible = false
	await get_tree().create_timer(2).timeout
	node.visible = true
	race_settings.visible = true
	
	rpc("player_nick_update", str(multiplayer.get_unique_id()), playerNameEntry.text)
	if str(multiplayer.get_unique_id()) == node.name:
		node.set_nick(playerNameEntry.text)
		node.connect("tyre_health_changed", raceInfoNode.set_tyre_health)
		node.connect("toggle_pit", toggle_pit)
	
	
	rpc("set_car_color", node.name, node.car_animation_color)
	if isServer:
		var carColor = carColors[networkNode.get_child_count() - 1]
		node.car_animation_color = carColor
		var carColorIndex = 0
		for player in networkNode.get_children():
			if carColorIndex >= networkNode.get_child_count():
				carColorIndex = 0
			carColor = carColors[carColorIndex]
			rpc("set_car_color", player.name, carColor)
			carColorIndex += 1
		
	if isServer:
		var gridPos = networkNode.get_child_count() - 1
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
	var selected_track_index = 0
	
	for selected_track in raceTrackList.get_selected_items():
		selected_track_index = selected_track
		
	rpc("race_restart", numberOfLaps, selected_track_index)
	race_restart(numberOfLaps, selected_track_index)
	


func _on_link_button_pressed():
	raceMenu.show()
	
func on_race_completed(playerState):
	rpc("race_completed", playerState)
	race_completed(playerState)
	raceCompleted.show()
	
func _on_start_new_race_pressed():
	raceCompleted.hide()
	raceMenu.show()
