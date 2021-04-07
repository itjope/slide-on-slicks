extends TileMap

const Car = preload("res://Car.tscn")

signal finished_lap(body)

var prev_checkpoint = {}

class MyCustomSorter:
	static func sort(a, b):
		return a["id"] < b["id"]

func _on_Checkpoints_body_shape_entered(body_id, body, _body_shape, area_shape):
	var cur = area_shape
	var prev = prev_checkpoint.get(body_id, 0)
	var last = get_node("Checkpoints").get_child_count()-1
	
	if (prev == last && cur == 0):
		print("finished_lap: " + str(body))
		emit_signal("finished_lap", body)	
		prev_checkpoint[body_id] = cur
	elif (prev + 1 == cur):
		prev_checkpoint[body_id] = cur


func _on_Server_start_game(my_info, player_info):
	var start_positions = []
	
	for up in get_used_cells_by_id(3):
		start_positions.append({"pos": (map_to_world(up) + cell_size / 2), "angle": deg2rad(-90)})

	for down in get_used_cells_by_id(4):
		start_positions.append({"pos": (map_to_world(down) + cell_size / 2), "angle": deg2rad(90)})

	for right in get_used_cells_by_id(5):
		start_positions.append({"pos": (map_to_world(right) + cell_size / 2), "angle": deg2rad(0)})

	for left in get_used_cells_by_id(6):
		start_positions.append({"pos": (map_to_world(left) + cell_size / 2), "angle": deg2rad(180)})

	var selfPeerID = get_tree().get_network_unique_id()
	var car = Car.instance()
	car.position=start_positions[0]["pos"]
	car.rotation=start_positions[0]["angle"]
	car.set_name(str(selfPeerID))
	car.set_network_master(selfPeerID)
	get_parent().add_child(car)
	get_parent().get_node("Race").get_node("ControlPanel").start(car)

	var cars = [{"id": selfPeerID, "car": car}]

	for p in player_info:
		var remoteCar = Car.instance()
		remoteCar.set_name(str(p))
		remoteCar.set_network_master(p)
		get_parent().add_child(remoteCar)
		cars.append({"id": p, "car": remoteCar})
				
	cars.sort_custom(MyCustomSorter, "sort")
	
	var pos = 0
	for c in cars:
		c["car"].position = start_positions[pos]["pos"]
		c["car"].rotation = start_positions[pos]["angle"]
		pos += 1
