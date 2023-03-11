extends Node2D

@onready var mainMenu = $CanvasLayer/MainManu
@onready var addressEntry = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/AddressEntry
@onready var dedicatedServerCheckbox = $CanvasLayer/MainManu/MarginContainer/VBoxContainer/DedicatedServerCheckbox
	
var Player = preload("res://player.tscn")
const PORT = 9999
var enetPeer = ENetMultiplayerPeer.new()
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	pass


func _on_host_button_pressed():
	mainMenu.hide()
	enetPeer.create_server(PORT)
	multiplayer.multiplayer_peer = enetPeer
	multiplayer.peer_connected.connect(addPlayer)
	
	if not dedicatedServerCheckbox.is_pressed():
		addPlayer(multiplayer.get_unique_id())


func _on_join_button_pressed():
	mainMenu.hide()
	var error = enetPeer.create_client(addressEntry.text, PORT)
	if error != OK:
		OS.alert("Failed to connect!")

	multiplayer.multiplayer_peer = enetPeer
	
func addPlayer(peerId): 
	var player = Player.instantiate()
	player.name = str(peerId)
	add_child(player)
