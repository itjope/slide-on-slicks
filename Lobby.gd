extends Control

signal game_options(game_options)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var gameOptions = {
	laps = 5,
	practice = 0,
	qualifying = 0,
	tracks = 1
}

# Called when the node enters the scene tree for the first time.
func _ready():
	self.get_node("LapsSlider").connect("value_changed", self, "_on_laps_changed")
	self.get_node("QualifySlider").connect("value_changed", self, "_on_qualify_changed")
	self.get_node("PracticeSlider").connect("value_changed", self, "_on_practice_changed")
	self.get_node("TracksSlider").connect("value_changed", self, "_on_tracks_changed")
	self.get_node("StartGame").connect("pressed", self, "_on_start_game")
	
func _to_minutes_str(minutes):
	var value = str(minutes) + " minutes"
	if (minutes < 1):
		value = "Off"
	if (minutes == 1):
		value = str(minutes) + " minute"
	return value

func _to_laps_str(laps):
	var value = str(laps) + " laps"
	
	if (laps == 1):
		value = str(laps) + " lap"
	return value

func _on_laps_changed(laps):
	gameOptions.laps = laps
	self.get_node("LapsValueLabel").text = _to_laps_str(laps)


func _on_qualify_changed(laps):
	gameOptions.qualify = laps
	self.get_node("QualifyValueLabel").text = _to_minutes_str(laps)

func _on_practice_changed(laps):
	gameOptions.practice = laps
	self.get_node("PracticeValueLabel").text = _to_minutes_str(laps)

func _on_tracks_changed(tracks):
	gameOptions.tracks = tracks
	self.get_node("TracksValueLabel").text = str(tracks)
	
func _on_start_game():
	emit_signal("game_options", gameOptions)
