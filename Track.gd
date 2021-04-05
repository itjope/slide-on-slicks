extends TileMap

signal finished_lap(body)
signal start_positions(positions)

var prev_checkpoint = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	var start_positions = []
	
	for up in get_used_cells_by_id(3):
		start_positions.append({"pos": (map_to_world(up) + cell_size / 2), "angle": deg2rad(-90)})

	for down in get_used_cells_by_id(4):
		start_positions.append({"pos": (map_to_world(down) + cell_size / 2), "angle": deg2rad(90)})

	for right in get_used_cells_by_id(5):
		start_positions.append({"pos": (map_to_world(right) + cell_size / 2), "angle": deg2rad(0)})

	for left in get_used_cells_by_id(6):
		start_positions.append({"pos": (map_to_world(left) + cell_size / 2), "angle": deg2rad(180)})

	print("start_positions=" + str(start_positions))
	emit_signal("start_positions", start_positions)


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
