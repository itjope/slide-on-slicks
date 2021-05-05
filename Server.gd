extends Node

const PORT        = 5000

var player_info = {}

var my_info = { name = "Player 1", "car": 0 }
var serverOrJoin = null
var lobby = null

signal start_game(my_info, player_info, opts)

func _ready():
	serverOrJoin = $ServerOrJoin
	lobby = $Lobby
#	serverOrJoin.get_node("StartServer").connect("pressed", self, "_start_server")
#	serverOrJoin.get_node("JoinServer").connect("pressed", self, "_start_client")

	serverOrJoin.connect("start_server", self, "_start_server")
	serverOrJoin.connect("join_server", self, "_start_client")

	lobby.connect("game_options", self, "start")

	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

func _start_server(opts):
	_serverOrJoinCompleted(opts)

	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(PORT, 4)
	get_tree().network_peer = peer
	
#	my_info.name = serverOrJoin.get_node("PlayerNameInput").text
#	lobby.get_node("Players").add_item(my_info.name)
	
	self.add_child(lobby)

func _start_client(opts):
	var peer = NetworkedMultiplayerENet.new()
	var serverInputValue = opts.server
	var serverHost = serverInputValue.split(":")[0]
	var serverPort = serverInputValue.split(":")[1]
	peer.create_client(serverHost, PORT)
	get_tree().network_peer = peer
	_serverOrJoinCompleted(opts)
	
func _serverOrJoinCompleted(opts):
	my_info.name = opts.playerName
	my_info.car = opts.car
	lobby.get_node("Players").add_item(my_info.name)
	
	serverOrJoin.hide()
	lobby.show()
	self.add_child(lobby)
	

func start(gameOptions):
	for p in player_info:
		rpc_id(p, "start_game", gameOptions)

	start_game(gameOptions)

remote func start_game(gameOptions):	
	emit_signal("start_game", my_info, player_info, gameOptions)
	lobby.hide()


func _player_connected(id):
	print("Player connected")
	rpc_id(id, "register_player", my_info)

func _player_disconnected(id):
	player_info.erase(id) 

func _connected_ok():
	pass 

func _server_disconnected():
	pass 

func _connected_fail():
	pass 



remote func register_player(info):
	var id = get_tree().get_rpc_sender_id()
	lobby.get_node("Players").add_item(info.name)
	player_info[id] = info


func _on_Race_show_lobby():
	lobby.show()
	
