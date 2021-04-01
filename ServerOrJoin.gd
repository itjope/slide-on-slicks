extends Control

func _ready():
	randomize()
	var randomNumber = str(randi() % 51 + 10)
	self.get_node("PlayerNameInput").text = "SquirmyBroom" + randomNumber

