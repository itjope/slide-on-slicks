extends Node2D

@onready var mainMenu = $CanvasLayer/MainManu
@onready var addressEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/AddressEntry
@onready var dedicatedServerCheckbox = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/DedicatedServerCheckbox
@onready var networkNode = $Network
@onready var canvasModulate = $CanvasModulate
var Player = preload("res://player.tscn")
var start_lights = preload("res://start_lights.tscn")
var PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
var gridPositions = [Vector2(25, 325), Vector2(25, 350), Vector2(75, 325), Vector2(75, 350)]
# Called when the node enters the scene tree for the first time.
func _ready():
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	
	if OS.get_cmdline_args().has("--server"):
		createServer()
		

func createServer():
	print("Starting server...")
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _input(event):
	if event.is_pressed() && event.as_text() == "R":
		print_debug("restart")
		rpc("race_restart")
		race_restart()
	if event.is_pressed() && event.as_text() == "N":
		canvasModulate.visible = !canvasModulate.visible
		
func _on_host_button_pressed():
	createServer()

func _on_join_button_pressed():
	mainMenu.hide()
	var error = enetPeer.create_client(addressEntry.text, PORT)
	if error != OK:
		OS.alert("Failed to connect!")

	multiplayer.multiplayer_peer = enetPeer

@rpc("any_peer")
func set_grid_pos(pos: int):
	print_debug("set_grid_pos ", pos)
	for player in networkNode.get_children():
		player.set_grid(gridPositions[pos])
		
@rpc("any_peer")
func race_restart():
	print_debug("Race restart rpc")
	var lights = start_lights.instantiate()
	for player in networkNode.get_children():
		player.race_restart()
	add_child(lights)
	await get_tree().create_timer(6).timeout
	lights.queue_free()
	

func handleConnectedPlayer(peerId):
	var gridPos = networkNode.get_child_count()
	var player = addPlayer(peerId)
	
	# Hacky, hacky - rpc call is not triggered if run directly after the node gets added
	await get_tree().create_timer(0).timeout
	
	rpc_id(peerId, "set_grid_pos", gridPos)

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
