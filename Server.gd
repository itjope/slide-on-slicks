extends Node

const PORT        = 5000
const MAX_PLAYERS = 4

func _ready():
	var server = NetworkedMultiplayerENet.new()
	server.create_server(PORT, MAX_PLAYERS)
	get_tree().set_network_peer(server)
	get_tree().connect("network_peer_connected",    self, "_client_connected"   )
	get_tree().connect("network_peer_disconnected", self, "_client_disconnected")

func _client_connected(id):
	print('Client ' + str(id) + ' connected to Server')

	# var newClient = load("res://remote_client.tscn").instance()
	# newClient.set_name(str(id))     # spawn players with their respective names
	#get_tree().get_root().add_child(newClient)

func _client_disconnected(id):
	print('Client ' + str(id) + ' disconnected')

	# var newClient = load("res://remote_client.tscn").instance()
	# newClient.set_name(str(id))     # spawn players with their respective names
	#get_tree().get_root().add_child(newClient)






# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
