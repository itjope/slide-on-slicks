extends Node2D

@onready var mainMenu = $CanvasLayer/MainManu
@onready var addressEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/AddressEntry
@onready var dedicatedServerCheckbox = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/DedicatedServerCheckbox
	
var Player = preload("res://player.tscn")
var PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
# Called when the node enters the scene tree for the first time.
func _ready():
	
	
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
	multiplayer.peer_connected.connect(addPlayer)
	multiplayer.peer_disconnected.connect(removePlayer)
	
	if not dedicatedServerCheckbox.is_pressed() && not args.has("--server"):
		addPlayer(multiplayer.get_unique_id())
	
	print("Server started")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_host_button_pressed():
	createServer()

func _on_join_button_pressed():
	mainMenu.hide()
	var error = enetPeer.create_client(addressEntry.text, PORT)
	if error != OK:
		OS.alert("Failed to connect!")

	multiplayer.multiplayer_peer = enetPeer
	
func addPlayer(peerId): 
	print_debug("addPlayer: ", peerId)
	var player = Player.instantiate()
	player.name = str(peerId)
	add_child(player)
	player.find_child("Smoothing2D").teleport()

func removePlayer(peerId): 
	print_debug("removePlayer: ", peerId)
	get_node(str(peerId)).queue_free()
