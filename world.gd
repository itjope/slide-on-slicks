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
@onready var canvasModulate = $CanvasModulate
@onready var raceCompleted = $RaceCompleted
@onready var raceCompletedGrid = $RaceCompleted/PanelContainer/MarginContainer/VBoxContainer/GridContainer

# Race settings meny
@onready var raceMenu = $RaceSettings/RaceMenu
@onready var raceNumberOfLapsInput = $RaceSettings/RaceMenu/MarginContainer/VBoxContainer/NumerOfLapsInput

var Player = preload("res://player.tscn")
var start_lights = preload("res://start_lights.tscn")
var PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
var gridPositions = [Vector2(220, 335), Vector2(240, 360), Vector2(280, 335), Vector2(300, 360)]
var carColors = ["blue", "pink", "green", "yellow"]
var isServer = false

var raceCompledPlayers = []

func _ready():
	if OS.is_debug_build():
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		playerNameEntry.text = "P" + str(randi() % 100)
	
	if OS.get_cmdline_args().has("--server"):
		createServer()
		
	
	

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

func _process(delta):
	pass

func _input(event):
	if (mainMenu.visible): return
	
	if event.is_pressed() && event.as_text() == "N":
		canvasModulate.visible = !canvasModulate.visible
		
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
	

@rpc("any_peer")
func set_grid_pos(peerId: String, pos: int):
	for player in networkNode.get_children():
		if player.name == peerId:
			player.set_grid(gridPositions[pos])
		
@rpc("any_peer")
func set_car_color(peerId: String, color: String):
	print_debug("set_car_color ", multiplayer.get_unique_id(), " ", peerId, " ", color)
	for player in networkNode.get_children():
		if player.name == peerId:
			player.car_animation_color = color

@rpc("any_peer")
func race_restart(numberOfLaps: int):
	raceNumberOfLapsInput.text = str(numberOfLaps)
	raceCompledPlayers.clear()
	var lights = start_lights.instantiate()
	for player in networkNode.get_children():
		player.race_restart()
	
	for track in tracksNode.get_children():
		track.resetLaps(numberOfLaps)
		
	add_child(lights)
	raceCompleted.hide()
	
	await get_tree().create_timer(6).timeout
	lights.queue_free()
	
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
		p += 1
		
		raceCompletedGrid.add_child(labelPoistion)
		raceCompletedGrid.add_child(labelName)
	
@rpc("any_peer")
func player_nick_update(peerId: String, nick: String):	
	for player in networkNode.get_children():
		if player.name == peerId:
			player.set_nick(nick) 

func handleConnectedPlayer(peerId):
	var player = addPlayer(peerId)

func addHostedPlayer(peerId):
	var gridPos = networkNode.get_child_count()
	var player = addPlayer(peerId)
	player.set_grid(gridPositions[gridPos])
			
func addPlayer(peerId): 
	print_debug("addPlayer: ", peerId)
	
	var player = Player.instantiate()
	player.name = str(peerId)
	
	networkNode.add_child(player)
	player.find_child("Smoothing2D").teleport()
	
	return player

func removePlayer(peerId): 
	print_debug("removePlayer: ", peerId)
	get_node("Network").get_node(str(peerId)).queue_free()


func _on_network_child_entered_tree(node):
	await get_tree().create_timer(4).timeout
	
	rpc("player_nick_update", str(multiplayer.get_unique_id()), playerNameEntry.text)
	if str(multiplayer.get_unique_id()) == node.name:
		node.set_nick(playerNameEntry.text) 
	
	
	rpc("set_car_color", node.name, node.car_animation_color)
	if isServer:
		var carColor = carColors[networkNode.get_child_count() - 1]
		node.car_animation_color = carColor
		var carColorIndex = 0
		for player in networkNode.get_children():
			carColorIndex += 1;
			if carColorIndex >= networkNode.get_child_count():
				carColorIndex = 0
			carColor = carColors[carColorIndex]
			rpc("set_car_color", player.name, carColor)
		
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
	rpc("race_restart", numberOfLaps)
	race_restart(numberOfLaps)
	


func _on_link_button_pressed():
	raceMenu.show()
	
func on_race_completed(playerState):
	rpc("race_completed", playerState)
	race_completed(playerState)
	raceCompleted.show()


func _on_start_new_race_pressed():
	var numberOfLaps = raceNumberOfLapsInput.text.to_int();
	rpc("race_restart", numberOfLaps)
	race_restart(numberOfLaps)
	
