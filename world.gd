extends Node2D

@onready var mainMenu = $CanvasLayer/MainManu
@onready var addressEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/AddressEntry
@onready var playerNameEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/PlayerNameEntry
@onready var playerNameError = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/LabelPlayerNameError
@onready var dedicatedServerCheckbox = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/DedicatedServerCheckbox
@onready var networkNode = $Network
@onready var canvasModulate = $CanvasModulate
var Player = preload("res://player.tscn")
var start_lights = preload("res://start_lights.tscn")
var PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
var gridPositions = [Vector2(220, 335), Vector2(240, 360), Vector2(280, 335), Vector2(300, 360)]
var carColors = ["blue", "pink", "green", "yellow"]
var isServer = false

func _ready():
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	
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
	if event.is_pressed() && event.as_text() == "R":
		print_debug("restart")
		rpc("race_restart")
		race_restart()
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
func race_restart():
	print_debug("Race restart rpc")
	var lights = start_lights.instantiate()
	for player in networkNode.get_children():
		player.race_restart()
	add_child(lights)
	
	await get_tree().create_timer(6).timeout
	lights.queue_free()
	
	
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
	await get_tree().create_timer(0).timeout
	
	rpc("player_nick_update", str(multiplayer.get_unique_id()), playerNameEntry.text)
	if str(multiplayer.get_unique_id()) == node.name:
		node.set_nick(playerNameEntry.text) 
	
	
	rpc("set_car_color", node.name, node.car_animation_color)
	if isServer:
		var carColor = carColors[networkNode.get_child_count() - 1]
		node.car_animation_color = carColor
		for player in networkNode.get_children():
			rpc("set_car_color", player.name, player.car_animation_color)
		
	if isServer:
		var gridPos = networkNode.get_child_count() - 1
		rpc_id(int(str(node.name)), "set_grid_pos", node.name, gridPos)
		
		
	
