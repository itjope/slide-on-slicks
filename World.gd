extends Node2D

func _ready():
	print("ready")
	get_tree().connect('connected_to_server', self, 'on_connected_to_server')
	var peer = NetworkedMultiplayerENet.new()
	var result = peer.create_client('127.0.0.1', 5000)
	if result == OK:
		get_tree().set_network_peer(peer)
		print("Connecting to server...")
		return true
	else:
		return false
	

func on_connected_to_server():
	print("Connected to server.")
