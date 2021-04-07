extends AnimatedSprite

signal green_light

func _on_Timer_timeout():
	if (frame == 2):
		emit_signal("green_light")
		frame += 1
	elif (frame == 3):
		$Timer.stop()
		visible = false
	else:
		frame += 1


func _on_Server_start_game(my_info, player_info):
	visible = true
	$Timer.start()
