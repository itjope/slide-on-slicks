extends Control

func _ready():
	randomize()
	var number = 35
	while(number == 35): 
		number = randi() % 51 + 10

	self.get_node("PlayerNameInput").text = "squirmybroom" + str(number)

