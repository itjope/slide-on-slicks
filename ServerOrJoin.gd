extends Control

signal join_server(opts)
signal start_server(opts)

func _ready():
	randomize()
	var number = 35
	while(number == 35): 
		number = randi() % 51 + 10

	self.get_node("PlayerNameInput").text = "squirmybroom" + str(number)

	$StartServer.connect("pressed", self, "_start_server")
	$JoinServer.connect("pressed", self, "_join_server")

func _on_ChooseCar_pressed():
	$ChooseCar/Car.frame = ($ChooseCar/Car.frame + 1) % 2

func getOptions():
	return {
		"playerName": $PlayerNameInput.text,
		"car": $ChooseCar/Car.frame,
		"server": $ServerInput.text
		 }

func _start_server():
	emit_signal("start_server", getOptions())

func _join_server():
	emit_signal("join_server", getOptions())
