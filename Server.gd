extends Node

const PORT        = 5000
const ServerOrJoin = preload("res://ServerOrJoin.tscn")
const PlayerLobby = preload("res://Lobby.tscn")

var player_info = {}
var my_info = { name = "Player 1" }
var serverOrJoin = ServerOrJoin.instance()
var lobby = PlayerLobby.instance()

signal start_game(my_info, player_info)

func _ready():
	
	
	self.add_child(serverOrJoin)
	serverOrJoin.get_node("StartServer").connect("pressed", self, "_start_server")
	serverOrJoin.get_node("JoinServer").connect("pressed", self, "_start_client")
	lobby.connect("game_options", self, "start")

	for child in self.get_children():
		print(child.get_name())
	
	
	# var opponentScene = load("res://Opponent.tscn")
	# var opponent = opponentScene.instance()
	# opponent.set_position(Vector2(1950, 1000))
	# world.add_child(opponent)
	
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")


func _start_server():
	_serverOrJoinCompleted()
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(PORT, 4)
	get_tree().network_peer = peer
	
	
	
	
func _serverOrJoinCompleted():
	my_info.name = serverOrJoin.get_node("PlayerNameInput").text
	lobby.get_node("Players").add_item(my_info.name)
	
	serverOrJoin.hide()
	self.add_child(lobby)

func _start_client():
	var peer = NetworkedMultiplayerENet.new()
	var serverInputValue = serverOrJoin.get_node("ServerInput").text
	var serverHost = serverInputValue.split(":")[0]
	var serverPort = serverInputValue.split(":")[1]
	peer.create_client(serverHost, PORT)
	get_tree().network_peer = peer
	_serverOrJoinCompleted()
	


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

# func on_connected_to_server():
# 	print("Connected to server.")
	
# 	self.get_node("Label").text = "connected"
# 	var car = Car.instance()
# 	get_parent().add_child(car)

# func send_player_position(position):
# 	rpc_unreliable("on_player_update", position)

# remote func on_all_players_update(playerPositions):
# 	for ps in playerPositions:
# 		#
# 		#self.get_node("Label").text = "opponent"
# 		for pos in playerPositions.values():
# 			# self.get_node("Opponent1").set_position(playerPositions)
# 			print(pos)
