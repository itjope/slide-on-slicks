extends Node2D

func _ready():
	$Track.connect("finished_lap", self, "_on_finished_lap")
	$Server.connect("start_game", self, "_on_start_game")

func _on_finished_lap(body):
	$Race/RaceInfo.on_finished_lap(body)
	
func _on_start_game(my_info, player_info):
	$Race/RaceInfo.on_start_game(my_info, player_info)
