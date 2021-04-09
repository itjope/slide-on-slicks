extends Node2D

func _ready():
	$Track.connect("finished_lap", self, "_on_finished_lap")
	$Server.connect("start_game", self, "_on_start_game")
	$Race.connect("race_start", self, "_on_race_start")
